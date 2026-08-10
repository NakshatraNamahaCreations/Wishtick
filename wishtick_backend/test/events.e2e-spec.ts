import request from 'supertest';
import type { INestApplication } from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import type { Model } from 'mongoose';
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

  const newUser = async (): Promise<Actor> => {
    const email = `ev${++seq}.${Date.now()}@example.com`;
    const res = await request(app.getHttpServer())
      .post(`${V1}/auth/signup`)
      .send({ email, password: PASSWORD, name: 'Aarav Sharma' })
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

      // 50 unique guests, plus 5 duplicates (same address again) and 2 junk
      // entries with no contact — the shape of a real contact-list paste.
      const unique = Array.from({ length: 50 }, (_, i) => ({ email: `guest${i}@example.com` }));
      const recipients = [
        ...unique,
        ...unique.slice(0, 5),
        { name: 'No contact' },
        { name: 'Also nothing' },
      ];

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
      expect(result.skipped).toBe(2);

      // The guest list holds exactly 50, not 55 — the database dedupe held.
      const invites = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}/invites`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<unknown[]>;
      expect(invites.data).toHaveLength(50);

      // 50 emails went out, one per guest.
      expect(ctx.mailer.sent.filter((m) => m.subject.includes('Big Party'))).toHaveLength(50);

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

      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ email: 'priya@example.com', name: 'Priya' }] })
        .expect(200);

      // The invitee opens their emailed link — no auth header.
      const inviteToken = InviteTokenHelper.fromLastEmail(ctx);

      const view = await request(app.getHttpServer())
        .get(`${V1}/public/invites/${inviteToken}`)
        .expect(200);
      expect((view.body as Envelope<{ invitee: { name: string } }>).data.invitee.name).toBe(
        'Priya',
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
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ email: 'gone@example.com' }] })
        .expect(200);
      const inviteToken = InviteTokenHelper.fromLastEmail(ctx);

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
        .send({ recipients: [{ email: 'early@example.com' }] })
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
          .send({ recipients: [{ email: 'guest@example.com' }] })
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
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ email: 'added.on@example.com', name: 'Rohan' }] })
        .expect(200);

      const list = (
        await request(app.getHttpServer())
          .get(`${V1}/events/${event.id}/invites`)
          .set(auth(host.token))
          .expect(200)
      ).body as Envelope<{ name: string | null; createdAt: string }[]>;

      // "Added on" has no other source: an invite with no createdAt renders a
      // dash where the design shows a timestamp.
      expect(list.data[0].createdAt).toEqual(expect.any(String));
      expect(Number.isNaN(Date.parse(list.data[0].createdAt))).toBe(false);
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
          .send({ recipients: [{ email: 'guest.upload@example.com' }] })
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
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({
          recipients: [
            { email: 'rohan@example.com', name: 'Rohan' },
            { email: 'sona@example.com', name: 'Sona' },
          ],
        })
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
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({
          recipients: [{ email: 'x@example.com', name: '=cmd|calc!A1' }],
        })
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

      // Invite the guest by their account email.
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ email: guest.email }] })
        .expect(200);

      // Invited but not replied → still no access. An unanswered invite is not
      // attendance.
      await request(app.getHttpServer())
        .get(`${V1}/wishlists/${wishlist.data.id}`)
        .set(auth(guest.token))
        .expect(404);

      const inviteToken = InviteTokenHelper.fromLastEmail(ctx);
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

  describe('linking invites on signup', () => {
    it('attaches an invite sent before the guest had an account', async () => {
      const host = await newUser();
      const event = await createEvent(host);
      await publish(host, event.id);

      const futureGuestEmail = `future.${Date.now()}@example.com`;
      await request(app.getHttpServer())
        .post(`${V1}/events/${event.id}/invites`)
        .set(auth(host.token))
        .send({ recipients: [{ email: futureGuestEmail }] })
        .expect(200);

      // They sign up later with that email.
      const signup = await request(app.getHttpServer())
        .post(`${V1}/auth/signup`)
        .send({ email: futureGuestEmail, password: PASSWORD })
        .expect(201);
      const guestToken = (signup.body as Envelope<{ tokens: { accessToken: string } }>).data.tokens
        .accessToken;

      // The listener runs asynchronously; give it a beat.
      await new Promise((r) => setTimeout(r, 200));

      const invited = await request(app.getHttpServer())
        .get(`${V1}/events/invited`)
        .set(auth(guestToken))
        .expect(200);
      expect((invited.body as Envelope<{ id: string }[]>).data.some((e) => e.id === event.id)).toBe(
        true,
      );
    });
  });
});

/** Pulls an invite token out of the invite email the fake mailer captured. */
class InviteTokenHelper {
  static fromLastEmail(ctx: TestApp): string {
    const mail = ctx.mailer.last;
    if (!mail) throw new Error('No invite email was sent');
    const match = /\/i\/([A-Za-z0-9_-]+)/.exec(mail.text);
    if (!match) throw new Error(`No invite token in email: ${mail.text.slice(0, 120)}`);
    return match[1];
  }
}
