import request from 'supertest';
import type { INestApplication } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { randomUUID } from 'node:crypto';
import { GIFT_FULFILLED, type GiftLifecycleEvent } from 'src/common/events/domain-events';
import { AuthService } from 'src/modules/auth/auth.service';
import { WishlistVisibility } from 'src/modules/wishlists/wishlist.types';
import { createTestApp, V1, type TestApp } from './utils/test-app';

interface Envelope<T> {
  success: boolean;
  data: T;
  error?: { code: string; message: string };
}
interface Actor {
  token: string;
  userId: string;
  email: string;
  name: string;
}

describe('Notifications (e2e)', () => {
  let ctx: TestApp;
  let app: INestApplication;
  let authService: AuthService;
  let emitter: EventEmitter2;
  let seq = 0;

  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });
  const delay = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));
  /** Let the fire-and-forget listener enqueue, then run the queued jobs. */
  const settle = async (): Promise<void> => {
    await delay(150);
    await ctx.drainNotifications();
  };

  const newUser = async (): Promise<Actor> => {
    const name = `User ${++seq}`;
    const email = `notif${seq}.${Date.now()}@example.com`;
    const { user, tokens } = await authService.signup(
      { email, password: 'correct-horse-battery-staple', name },
      { ip: '127.0.0.1', userAgent: 'e2e' },
    );
    return { token: tokens.accessToken, userId: user.id, email, name };
  };

  /** A gifter fulfils a gift on an owner's item; returns the lifecycle ids. */
  const fulfilledGift = async (owner: Actor, gifter: Actor): Promise<GiftLifecycleEvent> => {
    const wl = (
      await request(app.getHttpServer())
        .post(`${V1}/wishlists`)
        .set(auth(owner.token))
        .send({ title: 'Gift me', visibility: WishlistVisibility.PUBLIC })
        .expect(201)
    ).body as Envelope<{ id: string }>;
    const item = (
      await request(app.getHttpServer())
        .post(`${V1}/wishlists/${wl.data.id}/items`)
        .set(auth(owner.token))
        .send({ title: 'Headphones', price: { amountMinor: 249900 } })
        .expect(201)
    ).body as Envelope<{ id: string }>;
    const gift = (
      await request(app.getHttpServer())
        .post(`${V1}/items/${item.data.id}/reserve`)
        .set(auth(gifter.token))
        .set('Idempotency-Key', randomUUID())
        .send({})
        .expect(201)
    ).body as Envelope<{ id: string }>;
    await request(app.getHttpServer())
      .post(`${V1}/gifts/${gift.data.id}/purchase`)
      .set(auth(gifter.token))
      .send({})
      .expect(200);
    await request(app.getHttpServer())
      .post(`${V1}/gifts/${gift.data.id}/fulfill`)
      .set(auth(gifter.token))
      .send({})
      .expect(200);
    return {
      giftId: gift.data.id,
      itemId: item.data.id,
      gifterId: gifter.userId,
      recipientId: owner.userId,
      wishlistId: wl.data.id,
    };
  };

  const notifications = (actor: Actor) =>
    request(app.getHttpServer()).get(`${V1}/notifications`).set(auth(actor.token));

  beforeAll(async () => {
    ctx = await createTestApp();
    app = ctx.app;
    authService = app.get(AuthService);
    emitter = app.get(EventEmitter2);
  }, 120_000);

  afterEach(async () => {
    await ctx.reset();
  });

  afterAll(async () => {
    await ctx.close();
  });

  // ── Exit criterion: fanout, exactly-once ────────────────────────────────────

  describe('fanout', () => {
    it('produces exactly one in-app + one email for a fulfilled gift, and nothing twice on retry', async () => {
      const owner = await newUser();
      const gifter = await newUser();
      await settle(); // flush the signup WELCOME notifications first
      ctx.mailer.reset();
      const event = await fulfilledGift(owner, gifter);
      await settle();

      // One in-app for the recipient.
      const inApp = (await notifications(owner).expect(200)).body as Envelope<{ type: string }[]>;
      const fulfilled = inApp.data.filter((n) => n.type === 'gift_fulfilled');
      expect(fulfilled).toHaveLength(1);

      // One email to the recipient.
      const emails = ctx.mailer.sent.filter((m) => m.to === owner.email);
      expect(emails).toHaveLength(1);
      expect(emails[0].subject).toContain('gift arrived');

      // Re-fire the same event: the durable ledger makes the retry a no-op.
      emitter.emit(GIFT_FULFILLED, event);
      await settle();
      const inApp2 = (await notifications(owner).expect(200)).body as Envelope<{ type: string }[]>;
      expect(inApp2.data.filter((n) => n.type === 'gift_fulfilled')).toHaveLength(1);
      expect(ctx.mailer.sent.filter((m) => m.to === owner.email)).toHaveLength(1);
    });
  });

  // ── Exit criterion: quiet hours defer (never drop) ──────────────────────────

  describe('quiet hours', () => {
    it('defers the email to after the window but still lands the in-app', async () => {
      const owner = await newUser();
      const gifter = await newUser();
      await settle(); // flush WELCOME while quiet hours are still off
      ctx.mailer.reset();

      // A window that certainly contains "now" (UTC), so the email must defer.
      const hour = new Date().getUTCHours();
      await request(app.getHttpServer())
        .patch(`${V1}/notifications/preferences`)
        .set(auth(owner.token))
        .send({
          timezone: 'UTC',
          quietHours: { enabled: true, startHour: hour, endHour: (hour + 2) % 24 },
        })
        .expect(200);

      await fulfilledGift(owner, gifter);
      await settle();

      // No email went out...
      expect(ctx.mailer.sent.filter((m) => m.to === owner.email)).toHaveLength(0);
      // ...but the in-app landed immediately...
      const inApp = (await notifications(owner).expect(200)).body as Envelope<{ type: string }[]>;
      expect(inApp.data.some((n) => n.type === 'gift_fulfilled')).toBe(true);
      // ...and the email was deferred, not dropped — a delayed job is waiting.
      const deferred = ctx.notifications.added.filter((j) => (j.opts.delay ?? 0) > 0);
      expect(deferred.length).toBeGreaterThan(0);
    });
  });

  // ── Exit criterion: unsubscribe suppresses within one request ───────────────

  describe('unsubscribe', () => {
    it('suppresses the category email on the very next dispatch', async () => {
      const owner = await newUser();
      const gifter = await newUser();
      const pref = (
        await request(app.getHttpServer())
          .get(`${V1}/notifications/preferences`)
          .set(auth(owner.token))
          .expect(200)
      ).body as Envelope<{ unsubscribeToken: string }>;

      await settle(); // flush WELCOME first
      ctx.mailer.reset();

      // One-click unsubscribe from the gifts category (as an email footer would).
      await request(app.getHttpServer())
        .get(`${V1}/notifications/unsubscribe/${pref.data.unsubscribeToken}?category=gifts`)
        .expect(200);

      await fulfilledGift(owner, gifter);
      await settle();

      // No gifts email...
      expect(ctx.mailer.sent.filter((m) => m.to === owner.email)).toHaveLength(0);
      // ...but the in-app is unaffected by an email unsubscribe.
      const inApp = (await notifications(owner).expect(200)).body as Envelope<{ type: string }[]>;
      expect(inApp.data.some((n) => n.type === 'gift_fulfilled')).toBe(true);
    });
  });

  // ── Exit criterion: thank-you renders with names, editable before send ──────

  describe('thank-you notes', () => {
    it('drafts a note with the right names and event context, editable before it sends', async () => {
      const owner = await newUser();
      const gifter = await newUser();
      await fulfilledGift(owner, gifter);
      await settle();

      // The recipient (owner) has a drafted thank-you note.
      const notes = (
        await request(app.getHttpServer()).get(`${V1}/thank-you`).set(auth(owner.token)).expect(200)
      ).body as Envelope<{ id: string; context: { gifterName: string }; body: string }[]>;
      expect(notes.data).toHaveLength(1);
      const note = notes.data[0];
      // The note names the gifter (its addressee), the item, and reads as the owner.
      expect(note.context.gifterName).toBe(gifter.name);
      expect(note.body).toContain(gifter.name);
      expect(note.body).toContain('Headphones');
      expect(note.body).toContain(owner.name);

      // Edit before sending.
      await request(app.getHttpServer())
        .patch(`${V1}/thank-you/${note.id}`)
        .set(auth(owner.token))
        .send({ body: 'Custom thanks — you are the best!' })
        .expect(200);

      ctx.mailer.reset();
      await request(app.getHttpServer())
        .post(`${V1}/thank-you/${note.id}/send-now`)
        .set(auth(owner.token))
        .expect(200);
      await settle();

      // The gifter receives the edited note by email.
      const toGifter = ctx.mailer.sent.filter((m) => m.to === gifter.email);
      expect(toGifter).toHaveLength(1);
      expect(toGifter[0].text).toContain('Custom thanks');

      // A stranger cannot manage someone else's note.
      const stranger = await newUser();
      await request(app.getHttpServer())
        .get(`${V1}/thank-you/${note.id}`)
        .set(auth(stranger.token))
        .expect(403);
    });
  });

  // ── Bounce suppression + read receipts + dashboard ──────────────────────────

  describe('suppression, reads, dashboard', () => {
    it('suppresses a bounced address and rejects a forged bounce secret', async () => {
      const owner = await newUser();
      const gifter = await newUser();

      await request(app.getHttpServer())
        .post(`${V1}/webhooks/notifications/bounce`)
        .set('x-bounce-secret', 'wrong')
        .send({ type: 'bounce', email: owner.email })
        .expect(401);

      await request(app.getHttpServer())
        .post(`${V1}/webhooks/notifications/bounce`)
        .set('x-bounce-secret', 'test-bounce-secret')
        .send({ type: 'bounce', email: owner.email })
        .expect(200);

      await fulfilledGift(owner, gifter);
      ctx.mailer.reset();
      await settle();
      // The bounced recipient gets no email; the in-app is unaffected.
      expect(ctx.mailer.sent.filter((m) => m.to === owner.email)).toHaveLength(0);
    });

    it('marks notifications read and lights up the dashboard section', async () => {
      const owner = await newUser();
      const gifter = await newUser();
      await fulfilledGift(owner, gifter);
      await settle();

      const list = (await notifications(owner).expect(200)).body as Envelope<{ id: string }[]>;
      expect(list.data.length).toBeGreaterThanOrEqual(1);

      const dash = (
        await request(app.getHttpServer())
          .get(`${V1}/dashboard/summary`)
          .set(auth(owner.token))
          .expect(200)
      ).body as Envelope<{ sections: Record<string, { available: boolean; badge: number }> }>;
      expect(dash.data.sections.notifications.available).toBe(true);
      expect(dash.data.sections.notifications.badge).toBeGreaterThanOrEqual(1);

      await request(app.getHttpServer())
        .post(`${V1}/notifications/read-all`)
        .set(auth(owner.token))
        .expect(200);
      const after = (await notifications(owner).expect(200)).body as Envelope<{ read: boolean }[]>;
      expect(after.data.every((n) => n.read)).toBe(true);
    });
  });
});
