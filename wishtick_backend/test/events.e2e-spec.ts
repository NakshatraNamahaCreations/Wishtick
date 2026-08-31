import { randomUUID } from 'node:crypto';
import request from 'supertest';
import type { INestApplication } from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { Types, type Model } from 'mongoose';
import { ErrorCode } from 'src/common/errors/error-codes';
import { EVENT_REMINDER_JOB } from 'src/modules/events/event-reminders.service';
import { Event, type EventDocument } from 'src/modules/events/schemas/event.schema';
import { WishlistVisibility } from 'src/modules/wishlists/wishlist.types';
import { createTestApp, V1, type TestApp } from './utils/test-app';

const PASSWORD = 'correct-horse-battery-staple';
/** A 1x1 PNG â the smallest thing the media pipeline will accept as real bytes. */
const PNG_BYTES = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);
const IN_A_MONTH = (): string => new Date(Date.now() + 30 * 24 * 60 * 60 * 1_000).toISOString();
/**
 * A syntactically valid user id with no account behind it.
 *
 * Used where a test only needs the invite row to exist — bulk dedupe, the
 * published-state guard — and signing up 50 real accounts would cost more than
 * the assertion is worth. Inviting an id that resolves to nobody is allowed on
 * purpose: the guest list renders the row without a name rather than rejecting
 * a batch of 50 because one WishMate deleted their account mid-request.
 */
const newObjectId = (): string => new Types.ObjectId().toString();

interface Envelope<T> {
  success: boolean;
  data: T;
  error?: { code: string; message: string; details?: unknown };
}

interface EventView {
  id: string;
  status: string;
  share?: { slug: string; url: string };
  rsvpCounts?: { attending: number; invited: number; yes: number; no: number };
}

interface Actor {
  token: string;
  userId: string;
  email: string;
}

describe('Events & invites (e2e)', () => {
  let ctx: TestApp;
  let app: INestApplication;
  let eventModel: Model<EventDocument>;
  let seq = 0;

  const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

  const newUser = async (name = 'Aarav Sharma'): Promise<Actor> => {
    const email = `ev${++seq}.${Date.now()}@example.com`;
    const res = await request(app.getHttpServer())
      .post(`${V1}/auth/signup`)
      .send({ email, password: PASSWORD, name })
      .expect(201);
    const body = res.body as Envelope<{ user: { id: string }; tokens: { accessToken: string } }>;
    return { token: body.data.tokens.accessToken, userId: body.data.user.id, email };
  };

  const createEvent = async (
    host: Actor,
    over: Record<string, unknown> = {},
  ): Promise<EventView> => {
    const res = await request(app.getHttpServer())
      .post(`${V1}/events`)
      .set(auth(host.token))
      .send({
        title: 'Big Party',
        type: 'birthday',
        startsAt: IN_A_MONTH(),
        timezone: 'Asia/Kolkata',
        ...over,
      })
      .expect(201);
    return (res.body as Envelope<EventView>).data;
  };

  const publish = async (host: Actor, id: string): Promise<EventView> => {
    const res = await request(app.getHttpServer())
      .post(`${V1}/events/${id}/publish`)
      .set(auth(host.token))
      .expect(200);
    return (res.body as Envelope<EventView>).data;
  };

  beforeAll(async () => {
    ctx = await createTestApp();
    app = ctx.app;
    eventModel = app.get<Model<EventDocument>>(getModelToken(Event.name));
  }, 120_000);

  afterAll(async () => {
    await ctx.close();
  });

  beforeEach(async () => {
    await ctx.reset();
  });

  // ── Templates ─────────────────────────────────────────────────────────────

  describe('invite templates', () => {
    it('serves 3 designs with 6 variants each, without authentication', async () => {
      const res = await request(app.getHttpServer()).get(`${V1}/invite-templates`).expect(200);
      const { templates } = (res.body as Envelope<{ templates: { variants: unknown[] }[] }>).data;
      expect(templates).toHaveLength(3);
      for (const t of templates) expect(t.variants).toHaveLength(6);
    });

    it('filters templates by event type', async () => {
      const res = await request(app.getHttpServer())
        .get(`${V1}/invite-templates?eventType=anniversary`)
        .expect(200);
      const { templates } = (res.body as Envelope<{ templates: { id: string }[] }>).data;
      expect(templates.some((t) => t.id === 'romantic')).toBe(true);
    });
  });

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  describe('event lifecycle', () => {
    it('creates a draft, publishes it, and schedules three reminders', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      expect(event.status).toBe('draft');
      // A draft schedules nothing.
      expect(ctx.scheduler.jobsNamed(EVENT_REMINDER_JOB)).toHaveLength(0);

      const published = await publish(host, event.id);
      expect(published.status).toBe('published');

      const reminders = ctx.scheduler.jobsNamed(EVENT_REMINDER_JOB);
      expect(reminders).toHaveLength(3);
      // Colon-free ids — BullMQ rejects a colon, and the fake enforces it.
      for (const r of reminders) expect(r.opts.jobId).not.toContain(':');
    });

    it('refuses to publish an event in the past', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      // Backdate it directly — the DTO blocks a past date on create.
      await eventModel.updateOne(
        { _id: event.id },
        { $set: { startsAt: new Date(Date.now() - 1_000) } },
      );
      const res = await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/publish`)
        .set(auth(host.token))
        .expect(400);
      expect((res.body as Envelope<never>).error?.code).toBe(ErrorCode.EVENT_DATE_IN_PAST);
    });

    it('answers 404 — not 403 — for a non-host', async () => {
      const host = await newUser();
      const stranger = await newUser();
      const event = await createEvent(host);
      await request(app.getHttpServer())
        .get(`${V1}/events/${event.id}`)
        .set(auth(stranger.token))
        .expect(404);
    });

    it('cancels an event and clears its reminders', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);
      expect(ctx.scheduler.jobsNamed(EVENT_REMINDER_JOB)).toHaveLength(3);

      const cancelled = (
        await request(app.getHttpServer())
          .delete(`${V1}/events/${event.id}`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<EventView>;
      expect(cancelled.data.status).toBe('cancelled');
      // Reminding people about a cancelled party is worse than not reminding.
      expect(ctx.scheduler.jobsNamed(EVENT_REMINDER_JOB)).toHaveLength(0);
    });

    it('rejects attaching a wishlist you do not own', async () => {
      const host = await newUser();
      const other = await newUser();
      const theirList = (
        await request(app.getHttpServer())
          .post(`${V1}/wishlists`)
          .set(auth(other.token))
          .send({ title: 'Not yours' })
          .expect(201)
      ).body as Envelope<{ id: string }>;

      const res = await request(app.getHttpServer())
        .post(`${V1}/events`)
        .set(auth(host.token))
        .send({
          title: 'X',
          type: 'birthday',
          startsAt: IN_A_MONTH(),
          timezone: 'Asia/Kolkata',
          wishlistIds: [theirList.data.id],
        })
        .expect(403);
      expect((res.body as Envelope<never>).error?.code).toBe(ErrorCode.WISHLIST_NOT_LINKABLE);
    });
  });

  // ── Exit criterion: reminders reschedule on a date change ─────────────────

  describe('reminder rescheduling', () => {
    it('reschedules every reminder when the date moves, orphaning none', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);

      const before = ctx.scheduler.jobsNamed(EVENT_REMINDER_JOB);
      const beforeDelays = before.map((j) => j.opts.delay);

      // Move the event two weeks closer.
      const newDate = new Date(Date.now() + 16 * 24 * 60 * 60 * 1_000).toISOString();
      await request(app.getHttpServer())
        .patch(`${V1}/events/${event.id}`)
        .set(auth(host.token))
        .send({ startsAt: newDate })
        .expect(200);

      const after = ctx.scheduler.jobsNamed(EVENT_REMINDER_JOB);
      // Still exactly three — no orphans left pointing at the old date.
      expect(after).toHaveLength(3);
      expect(ctx.scheduler.removed.length).toBeGreaterThanOrEqual(3);

      // And the delays actually changed — the bug this guards is silently
      // keeping the old schedule.
      const afterDelays = after.map((j) => j.opts.delay);
      expect(afterDelays).not.toEqual(beforeDelays);

      // The queued jobs carry the NEW start time, so a stale one would no-op.
      for (const job of after) {
        expect((job.data as { startsAtIso: string }).startsAtIso).toBe(
          new Date(newDate).toISOString(),
        );
      }
    });
  });

  // ── Exit criterion: bulk dedupe + guest RSVP ──────────────────────────────

  describe('bulk invites', () => {
    it('invites 50 recipients, collapsing duplicates, and reconciles the RSVP count', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);

      // 50 unique WishMates, plus 5 duplicates (the same person tapped twice)
      // and the host themselves, who cannot be a guest at their own party.
      const unique = Array.from({ length: 50 }, () => ({ userId: newObjectId() }));
      const recipients = [...unique, ...unique.slice(0, 5), { userId: host.userId }];

      const res = await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients })
        .expect(200);

      const result = (
        res.body as Envelope<{ created: unknown[]; duplicates: number; skipped: number }>
      ).data;
      expect(result.created).toHaveLength(50);
      expect(result.duplicates).toBe(5);
      expect(result.skipped).toBe(1);

      // The guest list holds exactly 50, not 55 — the database dedupe held.
      const invites = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}/invites`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<unknown[]>;
      expect(invites.data).toHaveLength(50);

      // Nothing was emailed or texted: an invitation reaches a WishMate in the
      // app, and this is the assertion that would catch a delivery channel
      // creeping back in.
      expect(ctx.mailer.sent.filter((m) => m.subject.includes('Big Party'))).toHaveLength(0);
      expect(ctx.sms.sent).toHaveLength(0);

      // A second identical request adds nobody.
      const again = await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: unique })
        .expect(200);
      expect(
        (again.body as Envelope<{ created: unknown[]; duplicates: number }>).data.created,
      ).toHaveLength(0);
      expect((again.body as Envelope<{ duplicates: number }>).data.duplicates).toBe(50);
    }, 30_000);

    it('lets a guest RSVP without an account, and the count reflects plus-ones', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);

      const priya = await newUser('Priya Nair');
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: priya.userId }] })
        .expect(200);

      // The invitee opens their link — no auth header.
      const inviteToken = await InviteTokenHelper.only(app, host.token, event.id);

      const view = await request(app.getHttpServer())
        .get(`${V1}/public/invites/${inviteToken}`)
        .expect(200);
      // The greeting comes from their own account now, not from something the
      // host typed when addressing the invite.
      expect((view.body as Envelope<{ invitee: { name: string } }>).data.invitee.name).toBe(
        'Priya Nair',
      );

      await request(app.getHttpServer())
        .post(`${V1}/public/invites/${inviteToken}/rsvp`)
        .send({ response: 'yes', plusOnes: 2, message: 'Bringing the kids' })
        .expect(200);

      const counts = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<EventView>;
      // 1 yes + 2 plus-ones = 3 attending.
      expect(counts.data.rsvpCounts).toMatchObject({ yes: 1, attending: 3, invited: 1 });
    });

    it('revokes an invite so its token stops working', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);
      const guest = await newUser();
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: guest.userId }] })
        .expect(200);
      const inviteToken = await InviteTokenHelper.only(app, host.token, event.id);

      const invites = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}/invites`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<{ id: string }[]>;

      await request(app.getHttpServer())
        .delete(`${V1}/events/${event.id}/invites/${invites.data[0].id}`)
        .set(auth(host.token))
        .expect(204);

      await request(app.getHttpServer()).get(`${V1}/public/invites/${inviteToken}`).expect(404);
    });

    it('refuses to invite before the event is published', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      const res = await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: newObjectId() }] })
        .expect(409);
      expect((res.body as Envelope<never>).error?.code).toBe(ErrorCode.EVENT_NOT_PUBLISHED);
    });
  });

  // ── Exit criterion: event-only wishlist opens exactly to accepted invitees ─

  describe('venue, person and relation (257:733, 257:755)', () => {
    it('round-trips the fields the create flow marks required', async () => {
      const host = await newUser();
      const created = (
        await request(app.getHttpServer())
          .post(`${V1}/events`)
          .set(auth(host.token))
          .send({
            title: "Rahul & Priya's Anniversary",
            type: 'anniversary',
            startsAt: new Date(Date.now() + 86_400_000).toISOString(),
            timezone: 'Asia/Kolkata',
            venue: 'Mysore Socials',
            personName: 'Priya',
            relation: 'partner_wife',
          })
          .expect(201)
      ).body as Envelope<{ id: string; venue: string; personName: string; relation: string }>;

      expect(created.data.venue).toBe('Mysore Socials');
      expect(created.data.personName).toBe('Priya');
      expect(created.data.relation).toBe('partner_wife');

      const moved = (
        await request(app.getHttpServer())
          .patch(`${V1}/events/${created.data.id}`)
          .set(auth(host.token))
          .send({ venue: 'The Grand Ballroom' })
          .expect(200)
      ).body as Envelope<{ venue: string; personName: string }>;

      expect(moved.data.venue).toBe('The Grand Ballroom');
      // Untouched fields survive a partial update.
      expect(moved.data.personName).toBe('Priya');
    });

    it('shows the venue to the invitee — the gap that made an invite all time and no place', async () => {
      const host = await newUser();
      const event = (
        await request(app.getHttpServer())
          .post(`${V1}/events`)
          .set(auth(host.token))
          .send({
            title: 'Housewarming',
            type: 'generic',
            startsAt: new Date(Date.now() + 86_400_000).toISOString(),
            timezone: 'Asia/Kolkata',
            venue: 'Mysore Socials',
          })
          .expect(201)
      ).body as Envelope<{ id: string }>;
      await publish(host, event.data.id);

      const invited = (
        await request(app.getHttpServer())
          .post(`${V1}/events/${event.data.id}/invites`)
          .set(auth(host.token))
          .send({ recipients: [{ userId: newObjectId() }] })
          .expect(200)
      ).body as Envelope<{ created: { id: string }[] }>;

      const link = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.data.id}/invites/${invited.data.created[0].id}/link`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<{ url: string }>;
      const token = link.data.url.split('/').pop()!;

      const publicView = (
        await request(app.getHttpServer()).get(`${V1}/public/invites/${token}`).expect(200)
      ).body as Envelope<{ event: { venue: string | null } }>;

      expect(publicView.data.event.venue).toBe('Mysore Socials');
    });
  });

  describe('guest details (4096:162)', () => {
    it('every guest carries the date they were added', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);
      const rohan = await newUser('Rohan');
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: rohan.userId }] })
        .expect(200);

      const list = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}/invites`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<{ person: { displayName: string | null } | null; createdAt: string }[]>;

      // "Added on" has no other source: an invite with no createdAt renders a
      // dash where the design shows a timestamp.
      expect(list.data[0].createdAt).toEqual(expect.any(String));
      expect(Number.isNaN(Date.parse(list.data[0].createdAt))).toBe(false);

      // And the row knows whose it is. The invite itself carries only a user
      // id now, so without the identity lookup every guest row is a blank
      // name — a guest list that lists nobody.
      expect(list.data[0].person?.displayName).toBe('Rohan');
    });
  });

  describe('uploaded invitation (2248:70)', () => {
    /** Presign â PUT the real bytes â confirm, for one purpose. */
    const uploadMedia = async (actor: Actor, purpose: string): Promise<string> => {
      const ticket = (
        await request(app.getHttpServer())
          .post(`${V1}/media/upload-url`)
          .set(auth(actor.token))
          .send({ purpose, contentType: 'image/png' })
          .expect(201)
      ).body as Envelope<{ mediaId: string; uploadUrl: string }>;

      const url = new URL(ticket.data.uploadUrl);
      await request(app.getHttpServer())
        .put(url.pathname + url.search)
        .set('Content-Type', 'image/png')
        .send(PNG_BYTES)
        .expect(200);

      await request(app.getHttpServer())
        .post(`${V1}/media/confirm`)
        .set(auth(actor.token))
        .send({ mediaId: ticket.data.mediaId })
        .expect(201);

      return ticket.data.mediaId;
    };

    it("carries the host's own artwork all the way to the invitee", async () => {
      const host = await newUser();
      const event = await createEvent(host);
      const mediaId = await uploadMedia(host, 'event_invite');

      const patched = (
        await request(app.getHttpServer())
          .patch(`${V1}/events/${event.id}`)
          .set(auth(host.token))
          .send({ inviteMediaId: mediaId })
          .expect(200)
      ).body as Envelope<{ inviteMediaUrl: string | null }>;

      expect(patched.data.inviteMediaUrl).toEqual(expect.any(String));

      await publish(host, event.id);
      const invited = (
        await request(app.getHttpServer())
          .post(`${V1}/events/${event.id}/invites`)
          .set(auth(host.token))
          .send({ recipients: [{ userId: newObjectId() }] })
          .expect(200)
      ).body as Envelope<{ created: { id: string }[] }>;

      const link = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}/invites/${invited.data.created[0].id}/link`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<{ url: string }>;
      const token = link.data.url.split('/').pop()!;

      const publicView = (
        await request(app.getHttpServer()).get(`${V1}/public/invites/${token}`).expect(200)
      ).body as Envelope<{ event: { inviteMediaUrl: string | null } }>;

      expect(publicView.data.event.inviteMediaUrl).toBe(patched.data.inviteMediaUrl);
    });

    it('refuses a cover image passed off as an invitation', async () => {
      // event_invite is the only purpose that admits GIF, MP4 and PDF, so
      // accepting any ready media here would smuggle those types in.
      const host = await newUser();
      const event = await createEvent(host);
      const coverId = await uploadMedia(host, 'event_cover');

      const res = await request(app.getHttpServer())
        .patch(`${V1}/events/${event.id}`)
        .set(auth(host.token))
        .send({ inviteMediaId: coverId })
        .expect(400);

      expect((res.body as Envelope<unknown>).error?.code).toBe(ErrorCode.MEDIA_TYPE_NOT_ALLOWED);
    });

    it("refuses somebody else's upload", async () => {
      const host = await newUser();
      const stranger = await newUser();
      const event = await createEvent(host);
      const theirs = await uploadMedia(stranger, 'event_invite');

      await request(app.getHttpServer())
        .patch(`${V1}/events/${event.id}`)
        .set(auth(host.token))
        .send({ inviteMediaId: theirs })
        .expect(404);
    });
  });

  describe('guest list export (4096:206)', () => {
    const seedGuests = async (): Promise<{ host: Actor; eventId: string }> => {
      const host = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);
      const [rohan, sona] = [await newUser('Rohan'), await newUser('Sona')];
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: rohan.userId }, { userId: sona.userId }] })
        .expect(200);
      return { host, eventId: event.id };
    };

    it('produces a CSV with a header and one row per guest', async () => {
      const { host, eventId } = await seedGuests();

      const res = await request(app.getHttpServer())
        .get(`${V1}/events/${eventId}/invites/export?format=csv`)
        .set(auth(host.token))
        .expect(200);

      expect(res.headers['content-type']).toContain('text/csv');
      expect(res.headers['content-disposition']).toContain('attachment;');
      expect(res.headers['content-disposition']).toContain('guest-list.csv');

      const text = res.text ?? res.body.toString();
      const lines = text.trim().split(String.fromCharCode(13, 10));
      expect(lines[0]).toContain('"Name"');
      expect(lines).toHaveLength(3);
      expect(lines[1]).toContain('"Rohan"');
      // Nobody has replied yet, so nobody is counted as attending.
      expect(lines[1]).toContain('"No reply"');
    });

    it('quotes a formula so a spreadsheet cannot execute a guest’s name', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);
      // The name is the guest's own, so the injection now arrives through
      // somebody's account rather than through what the host typed — which is
      // if anything the more likely way for one to reach the export.
      const attacker = await newUser('=cmd|calc!A1');
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: attacker.userId }] })
        .expect(200);

      const res = await request(app.getHttpServer())
        .get(`${V1}/events/${event.id}/invites/export?format=csv`)
        .set(auth(host.token))
        .expect(200);

      const text = res.text ?? res.body.toString();
      // Prefixed with an apostrophe: Excel then treats it as text, not a
      // formula to run.
      expect(text).toContain(`"'=cmd|calc!A1"`);
      expect(text).not.toContain('"=cmd|calc!A1"');
    });

    it('produces a real xlsx and a real pdf', async () => {
      const { host, eventId } = await seedGuests();

      const xlsx = await request(app.getHttpServer())
        .get(`${V1}/events/${eventId}/invites/export?format=xlsx`)
        .set(auth(host.token))
        .buffer()
        .parse((res, cb) => {
          const chunks: Buffer[] = [];
          res.on('data', (c: Buffer) => chunks.push(c));
          res.on('end', () => cb(null, Buffer.concat(chunks)));
        })
        .expect(200);
      // A zip container — every xlsx is one, and "PK" is its magic number.
      expect((xlsx.body as Buffer).subarray(0, 2).toString()).toBe('PK');

      const pdf = await request(app.getHttpServer())
        .get(`${V1}/events/${eventId}/invites/export?format=pdf`)
        .set(auth(host.token))
        .buffer()
        .parse((res, cb) => {
          const chunks: Buffer[] = [];
          res.on('data', (c: Buffer) => chunks.push(c));
          res.on('end', () => cb(null, Buffer.concat(chunks)));
        })
        .expect(200);
      expect((pdf.body as Buffer).subarray(0, 5).toString()).toBe('%PDF-');
      expect(pdf.headers['content-type']).toContain('application/pdf');
    });

    it('defaults to PDF, as the sheet pre-selects', async () => {
      const { host, eventId } = await seedGuests();

      const res = await request(app.getHttpServer())
        .get(`${V1}/events/${eventId}/invites/export`)
        .set(auth(host.token))
        .expect(200);

      expect(res.headers['content-type']).toContain('application/pdf');
    });

    it('is host-only — a guest list is not public information', async () => {
      const { eventId } = await seedGuests();
      const stranger = await newUser();

      await request(app.getHttpServer())
        .get(`${V1}/events/${eventId}/invites/export?format=csv`)
        .set(auth(stranger.token))
        .expect(404);
    });

    it('rejects a format it does not produce', async () => {
      const { host, eventId } = await seedGuests();

      await request(app.getHttpServer())
        .get(`${V1}/events/${eventId}/invites/export?format=docx`)
        .set(auth(host.token))
        .expect(400);
    });
  });

  describe('event_only wishlist access', () => {
    it('opens an event-only wishlist to an invitee only after they RSVP yes', async () => {
      const host = await newUser();
      const guest = await newUser();

      // An event_only wishlist with one item.
      const wishlist = (
        await request(app.getHttpServer())
          .post(`${V1}/wishlists`)
          .set(auth(host.token))
          .send({ title: 'Gift ideas', visibility: WishlistVisibility.EVENT_ONLY })
          .expect(201)
      ).body as Envelope<{ id: string }>;
      await request(app.getHttpServer())
        .post(`${V1}/wishlists/${wishlist.data.id}/items`)
        .set(auth(host.token))
        .send({ title: 'A telescope' })
        .expect(201);

      // Attaching the wishlist to the event sets the wishlist's eventId, which
      // is what AccessPolicyService reads to resolve EVENT_ONLY. No manual
      // surgery — the link is maintained by the service.
      const event = await createEvent(host, { wishlistIds: [wishlist.data.id] });
      await publish(host, event.id);

      // Before any invite: the guest cannot see the list.
      await request(app.getHttpServer())
        .get(`${V1}/wishlists/${wishlist.data.id}`)
        .set(auth(guest.token))
        .expect(404);

      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: guest.userId }] })
        .expect(200);

      // Invited but not replied → still no access. An unanswered invite is not
      // attendance.
      await request(app.getHttpServer())
        .get(`${V1}/wishlists/${wishlist.data.id}`)
        .set(auth(guest.token))
        .expect(404);

      const inviteToken = await InviteTokenHelper.only(app, host.token, event.id);
      await request(app.getHttpServer())
        .post(`${V1}/public/invites/${inviteToken}/rsvp`)
        .set(auth(guest.token))
        .send({ response: 'yes' })
        .expect(200);

      // Now the event-only list opens for them.
      const view = await request(app.getHttpServer())
        .get(`${V1}/wishlists/${wishlist.data.id}`)
        .set(auth(guest.token))
        .expect(200);
      expect((view.body as Envelope<{ access: { canGift: boolean } }>).data.access.canGift).toBe(
        true,
      );

      // Declining takes it away again.
      await request(app.getHttpServer())
        .post(`${V1}/public/invites/${inviteToken}/rsvp`)
        .set(auth(guest.token))
        .send({ response: 'no' })
        .expect(200);
      await request(app.getHttpServer())
        .get(`${V1}/wishlists/${wishlist.data.id}`)
        .set(auth(guest.token))
        .expect(404);
    }, 30_000);
  });

  // ── Invite linking on signup ──────────────────────────────────────────────

  /**
   * Joining a public event from its share link (`/e/<slug>`).
   *
   * The link names nobody, so identity is the session — which is what lets one
   * URL sit in a group chat. Everything after the join is the existing invite
   * machinery, so these tests care mostly about who is turned away.
   */
  describe('deleting events (multi-select)', () => {
    const bulkDelete = (actor: Actor, ids: string[]) =>
      request(app.getHttpServer())
        .post(`${V1}/events/bulk-delete`)
        .set(auth(actor.token))
        .send({ ids });

    it('removes the events and everything hanging off them', async () => {
      const host = await newUser();
      const guest = await newUser();
      const keep = await createEvent(host);
      const drop = await createEvent(host);
      await publish(host, drop.id);
      await request(app.getHttpServer())
        .post(`${V1}/events/${drop.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: guest.userId }] })
        .expect(200);

      const res = await bulkDelete(host, [drop.id]).expect(200);
      expect((res.body as Envelope<{ deleted: number }>).data.deleted).toBe(1);

      // Gone, not cancelled — the host asked for it to be removed.
      await request(app.getHttpServer())
        .get(`${V1}/events/${drop.id}`)
        .set(auth(host.token))
        .expect(404);

      // The invite went with it. A row pointing at an event that no longer
      // exists would sit in the guest's list forever with nothing to open.
      const invited = await request(app.getHttpServer())
        .get(`${V1}/events/invited`)
        .set(auth(guest.token))
        .expect(200);
      expect((invited.body as Envelope<{ id: string }[]>).data).toHaveLength(0);

      // And the one that was not selected is untouched.
      await request(app.getHttpServer())
        .get(`${V1}/events/${keep.id}`)
        .set(auth(host.token))
        .expect(200);
    });

    it('deletes several at once', async () => {
      const host = await newUser();
      const ids = [
        (await createEvent(host)).id,
        (await createEvent(host)).id,
        (await createEvent(host)).id,
      ];

      const res = await bulkDelete(host, ids).expect(200);
      expect((res.body as Envelope<{ deleted: number }>).data.deleted).toBe(3);

      const mine = await request(app.getHttpServer())
        .get(`${V1}/events/mine`)
        .set(auth(host.token))
        .expect(200);
      expect((mine.body as Envelope<unknown[]>).data).toHaveLength(0);
    });

    it('skips what the caller does not host rather than failing the batch', async () => {
      const host = await newUser();
      const stranger = await newUser();
      const mine = await createEvent(host);
      const theirs = await createEvent(stranger);

      const res = await bulkDelete(host, [mine.id, theirs.id]).expect(200);

      // One deleted, one silently skipped. Refusing the whole request over a
      // row that went stale would leave the host unable to clear anything.
      expect((res.body as Envelope<{ deleted: number }>).data.deleted).toBe(1);
      await request(app.getHttpServer())
        .get(`${V1}/events/${theirs.id}`)
        .set(auth(stranger.token))
        .expect(200);
    });

    it('frees a wishlist the event was holding rather than orphaning it', async () => {
      const host = await newUser();
      const wishlist = (
        await request(app.getHttpServer())
          .post(`${V1}/wishlists`)
          .set(auth(host.token))
          .send({ title: 'Gift ideas', visibility: WishlistVisibility.EVENT_ONLY })
          .expect(201)
      ).body as Envelope<{ id: string }>;
      const event = await createEvent(host, {
        wishlistIds: [wishlist.data.id],
      });

      await bulkDelete(host, [event.id]).expect(200);

      const after = await request(app.getHttpServer())
        .get(`${V1}/wishlists/${wishlist.data.id}`)
        .set(auth(host.token))
        .expect(200);

      // Still the host's, and no longer pointing at anything. A dangling
      // eventId leaves the list stuck in a visibility that can never resolve —
      // EVENT_ONLY admits accepted invitees of an event that is gone, so it is
      // permanently invisible to everyone but its owner while still claiming
      // to belong to a party.
      expect((after.body as Envelope<{ eventId: string | null }>).data.eventId).toBeNull();
    });

    it('refuses more ids than a multi-select could produce', async () => {
      const host = await newUser();
      await bulkDelete(
        host,
        Array.from({ length: 51 }, () => newObjectId()),
      ).expect(400);
    });
  });

  describe('group gifts on an invitation (291:1008)', () => {
    /// A wishlist with one priced item, attached to the event.
    const wishlistOn = async (
      host: Actor,
      eventId: string,
    ): Promise<{ wishlistId: string; itemId: string }> => {
      const wishlist = (
        await request(app.getHttpServer())
          .post(`${V1}/wishlists`)
          .set(auth(host.token))
          .send({ title: 'Gift ideas', visibility: WishlistVisibility.PUBLIC })
          .expect(201)
      ).body as Envelope<{ id: string }>;
      const item = (
        await request(app.getHttpServer())
          .post(`${V1}/wishlists/${wishlist.data.id}/items`)
          .set(auth(host.token))
          .send({ title: 'A telescope', price: { amountMinor: 500000 } })
          .expect(201)
      ).body as Envelope<{ id: string }>;
      await request(app.getHttpServer())
        .patch(`${V1}/events/${eventId}`)
        .set(auth(host.token))
        .send({ wishlistIds: [wishlist.data.id] })
        .expect(200);
      return { wishlistId: wishlist.data.id, itemId: item.data.id };
    };

    const startGroupGift = (gifter: Actor, itemId: string, title: string) =>
      request(app.getHttpServer())
        .post(`${V1}/items/${itemId}/group-gift`)
        .set(auth(gifter.token))
        .set({ 'Idempotency-Key': randomUUID() })
        .send({ title, targetAmountMinor: 500000 });

    it('a gift started on the event’s wishlist shows on the invitation', async () => {
      const host = await newUser();
      const gifter = await newUser();
      const guest = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);
      const { itemId } = await wishlistOn(host, event.id);

      await startGroupGift(gifter, itemId, 'Telescope fund').expect(201);

      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: guest.userId }] })
        .expect(200);
      const token = await InviteTokenHelper.only(app, host.token, event.id);

      const view = (
        await request(app.getHttpServer()).get(`${V1}/public/invites/${token}`).expect(200)
      ).body as Envelope<{ groupGifts: { id: string; title: string }[] }>;

      // The row `291:1008` draws. Title and id only — the amounts and who has
      // paid stay behind the group's own endpoint.
      expect(view.data.groupGifts).toHaveLength(1);
      expect(view.data.groupGifts[0].title).toBe('Telescope fund');
      expect(Object.keys(view.data.groupGifts[0]).sort()).toEqual(['id', 'title']);
    });

    it('an event with no group gift lists none rather than omitting the field', async () => {
      const host = await newUser();
      const guest = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: guest.userId }] })
        .expect(200);
      const token = await InviteTokenHelper.only(app, host.token, event.id);

      const view = (
        await request(app.getHttpServer()).get(`${V1}/public/invites/${token}`).expect(200)
      ).body as Envelope<{ groupGifts: unknown[] }>;

      expect(view.data.groupGifts).toEqual([]);
    });

    it('a gift on a list attached to no event belongs to no event', async () => {
      const host = await newUser();
      const gifter = await newUser();
      const guest = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);

      // A wishlist that is never attached — the item is giftable, the group is
      // real, but it is not for this party.
      const wishlist = (
        await request(app.getHttpServer())
          .post(`${V1}/wishlists`)
          .set(auth(host.token))
          .send({ title: 'Unrelated', visibility: WishlistVisibility.PUBLIC })
          .expect(201)
      ).body as Envelope<{ id: string }>;
      const item = (
        await request(app.getHttpServer())
          .post(`${V1}/wishlists/${wishlist.data.id}/items`)
          .set(auth(host.token))
          .send({ title: 'A kettle', price: { amountMinor: 500000 } })
          .expect(201)
      ).body as Envelope<{ id: string }>;
      await startGroupGift(gifter, item.data.id, 'Kettle fund').expect(201);

      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: guest.userId }] })
        .expect(200);
      const token = await InviteTokenHelper.only(app, host.token, event.id);

      const view = (
        await request(app.getHttpServer()).get(`${V1}/public/invites/${token}`).expect(200)
      ).body as Envelope<{ groupGifts: unknown[] }>;

      expect(view.data.groupGifts).toEqual([]);
    });

    it('a cancelled group drops off the invitation', async () => {
      const host = await newUser();
      const gifter = await newUser();
      const guest = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);
      const { itemId } = await wishlistOn(host, event.id);
      const gift = (await startGroupGift(gifter, itemId, 'Telescope fund').expect(201))
        .body as Envelope<{ id: string }>;

      await request(app.getHttpServer())
        .post(`${V1}/group-gifts/${gift.data.id}/cancel`)
        .set(auth(gifter.token))
        .expect(200);

      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: guest.userId }] })
        .expect(200);
      const token = await InviteTokenHelper.only(app, host.token, event.id);

      const view = (
        await request(app.getHttpServer()).get(`${V1}/public/invites/${token}`).expect(200)
      ).body as Envelope<{ groupGifts: unknown[] }>;

      // Still linked to the event, but not something an invitee can join —
      // and a row inviting them to would be worse than no row.
      expect(view.data.groupGifts).toEqual([]);
    });

    it('detaching the wishlist afterwards leaves the gift where it was', async () => {
      const host = await newUser();
      const gifter = await newUser();
      const guest = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);
      const { itemId } = await wishlistOn(host, event.id);
      await startGroupGift(gifter, itemId, 'Telescope fund').expect(201);

      // The list moves off the event. The group people have already committed
      // to belongs to the party it was started for — deriving the link on read
      // would silently take it away.
      await request(app.getHttpServer())
        .patch(`${V1}/events/${event.id}`)
        .set(auth(host.token))
        .send({ wishlistIds: [] })
        .expect(200);

      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ userId: guest.userId }] })
        .expect(200);
      const token = await InviteTokenHelper.only(app, host.token, event.id);

      const view = (
        await request(app.getHttpServer()).get(`${V1}/public/invites/${token}`).expect(200)
      ).body as Envelope<{ groupGifts: { title: string }[] }>;

      expect(view.data.groupGifts).toHaveLength(1);
      expect(view.data.groupGifts[0].title).toBe('Telescope fund');
    });
  });

  describe('join by share link', () => {
    const publicEvent = async (host: Actor, over: Record<string, unknown> = {}) => {
      const event = await createEvent(host, { visibility: 'public', ...over });
      if (over.status !== 'draft') await publish(host, event.id);
      const full = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<EventView & { share?: { slug: string } }>;
      return { id: event.id, slug: full.data.share!.slug };
    };

    const join = (guest: Actor, slug: string) =>
      request(app.getHttpServer()).post(`${V1}/events/by-slug/${slug}/join`).set(auth(guest.token));

    it('mints an invite whose token the existing RSVP flow accepts', async () => {
      const host = await newUser();
      const guest = await newUser();
      const event = await publicEvent(host);

      const joined = (await join(guest, event.slug).expect(201)).body as Envelope<{
        token: string;
      }>;
      const token = joined.data.token;

      // The whole point of returning a token: nothing new is needed to answer.
      const view = await request(app.getHttpServer())
        .get(`${V1}/public/invites/${token}`)
        .expect(200);
      expect(view.body.data.event.title).toBe('Big Party');

      await request(app.getHttpServer())
        .post(`${V1}/public/invites/${token}/rsvp`)
        .send({ response: 'yes' })
        .expect(200);

      const counts = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<EventView>;
      expect(counts.data.rsvpCounts).toMatchObject({ yes: 1, invited: 1 });
    });

    it('is idempotent — a link tapped twice is one guest, not two', async () => {
      const host = await newUser();
      const guest = await newUser();
      const event = await publicEvent(host);

      const first = (await join(guest, event.slug).expect(201)).body as Envelope<{ token: string }>;
      const second = (await join(guest, event.slug).expect(201)).body as Envelope<{
        token: string;
      }>;

      // A second row would split the RSVP: answer on one, the host sees the
      // other still pending.
      expect(second.data.token).toBe(first.data.token);

      const invites = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}/invites`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<unknown[]>;
      expect(invites.data).toHaveLength(1);
    });

    it('keeps an answer already given when the link is reopened', async () => {
      const host = await newUser();
      const guest = await newUser();
      const event = await publicEvent(host);

      const token = (
        (await join(guest, event.slug).expect(201)).body as Envelope<{ token: string }>
      ).data.token;
      await request(app.getHttpServer())
        .post(`${V1}/public/invites/${token}/rsvp`)
        .send({ response: 'yes' })
        .expect(200);

      // Reopened after an install, say. Re-minting would silently drop the yes.
      await join(guest, event.slug).expect(201);

      const view = await request(app.getHttpServer())
        .get(`${V1}/public/invites/${token}`)
        .expect(200);
      expect(view.body.data.invitee.rsvp).toBe('yes');
    });

    it('refuses a private event — there the host decides who comes', async () => {
      const host = await newUser();
      const guest = await newUser();
      const event = await publicEvent(host, { visibility: 'private' });

      const res = await join(guest, event.slug).expect(404);
      expect(res.body.error.code).toBe('EVENT_NOT_FOUND');
    });

    it('lets an invite_only event in — it is defined as reachable by link', async () => {
      const host = await newUser();
      const guest = await newUser();
      const event = await publicEvent(host, { visibility: 'invite_only' });

      await join(guest, event.slug).expect(201);
    });

    it('refuses a draft, so an unsent party cannot be gate-crashed', async () => {
      const host = await newUser();
      const guest = await newUser();
      const draft = await createEvent(host, { visibility: 'public' });
      const full = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${draft.id}`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<EventView & { share?: { slug: string } }>;

      const res = await join(guest, full.data.share!.slug).expect(404);
      expect(res.body.error.code).toBe('EVENT_NOT_FOUND');
    });

    it('refuses the host their own link', async () => {
      const host = await newUser();
      const event = await publicEvent(host);

      const res = await join(host, event.slug).expect(400);
      expect(res.body.error.code).toBe('CANNOT_INVITE_HOST');
    });

    it('will not undo a revoke — the host took that access away on purpose', async () => {
      const host = await newUser();
      const guest = await newUser();
      const event = await publicEvent(host);
      await join(guest, event.slug).expect(201);

      const invites = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}/invites`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<{ id: string }[]>;
      await request(app.getHttpServer())
        .delete(`${V1}/events/${event.id}/invites/${invites.data[0].id}`)
        .set(auth(host.token))
        .expect(204);

      const res = await join(guest, event.slug).expect(404);
      expect(res.body.error.code).toBe('EVENT_NOT_FOUND');
    });

    it('answers 404 for a slug that never existed', async () => {
      const guest = await newUser();
      const res = await join(guest, 'nosuchslug123456').expect(404);
      expect(res.body.error.code).toBe('EVENT_NOT_FOUND');
    });
  });
});

/**
 * Pulls an invite token out of the host's own copyable link.
 *
 * Invitations are not emailed any more — they are addressed to a WishMate, who
 * finds theirs in the app — so there is no mailbox to read one out of. The
 * host-only link endpoint is the remaining way to get at a specific invitee's
 * token, and using it here means the tests exercise the same path the share
 * sheet does.
 */
class InviteTokenHelper {
  static async forInvite(
    app: INestApplication,
    hostToken: string,
    eventId: string,
    inviteId: string,
  ): Promise<string> {
    const res = await request(app.getHttpServer())
      .get(`${V1}/events/${eventId}/invites/${inviteId}/link`)
      .set({ Authorization: `Bearer ${hostToken}` })
      .expect(200);
    return (res.body as Envelope<{ url: string }>).data.url.split('/').pop()!;
  }

  /** The token for the event's only invite — the common single-guest case. */
  static async only(app: INestApplication, hostToken: string, eventId: string): Promise<string> {
    const list = await request(app.getHttpServer())
      .get(`${V1}/events/${eventId}/invites`)
      .set({ Authorization: `Bearer ${hostToken}` })
      .expect(200);
    const invites = (list.body as Envelope<{ id: string }[]>).data;
    if (invites.length !== 1) throw new Error(`Expected one invite, found ${invites.length}`);
    return InviteTokenHelper.forInvite(app, hostToken, eventId, invites[0].id);
  }
}
