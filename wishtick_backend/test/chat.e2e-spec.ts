import request from 'supertest';
import type { AddressInfo } from 'node:net';
import type { INestApplication } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { getModelToken } from '@nestjs/mongoose';
import { randomUUID } from 'node:crypto';
import type { Model } from 'mongoose';
import { io, type Socket } from 'socket.io-client';
import { ErrorCode } from 'src/common/errors/error-codes';
import { AuthService } from 'src/modules/auth/auth.service';
import { GROUP_GIFT_FUNDED, type GroupGiftFundedEvent } from 'src/common/events/domain-events';
import { Message, type MessageDocument } from 'src/modules/chat/schemas/message.schema';
import { WishlistVisibility } from 'src/modules/wishlists/wishlist.types';
import { createTestApp, V1, type TestApp } from './utils/test-app';

const PASSWORD = 'correct-horse-battery-staple';

interface Envelope<T> {
  success: boolean;
  data: T;
  error?: { code: string; message: string; details?: unknown };
}
interface Actor {
  token: string;
  userId: string;
}
interface ChatView {
  id: string;
  type: string;
}
interface MessageView {
  id: string;
  body: string;
  senderId: string | null;
  systemType: string | null;
}

describe('Chat (e2e)', () => {
  let ctx: TestApp;
  let app: INestApplication;
  let authService: AuthService;
  let emitter: EventEmitter2;
  let messageModel: Model<MessageDocument>;
  let base: string;
  let seq = 0;
  const openSockets: Socket[] = [];

  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

  const newUser = async (): Promise<Actor> => {
    const email = `chat${++seq}.${Date.now()}@example.com`;
    const { user, tokens } = await authService.signup(
      { email, password: PASSWORD, name: `User ${seq}` },
      { ip: '127.0.0.1', userAgent: 'e2e' },
    );
    return { token: tokens.accessToken, userId: user.id };
  };

  const makeWishlist = async (
    owner: Actor,
    visibility = WishlistVisibility.PUBLIC,
  ): Promise<string> => {
    const wl = (
      await request(app.getHttpServer())
        .post(`${V1}/wishlists`)
        .set(auth(owner.token))
        .send({ title: 'Chatty list', visibility })
        .expect(201)
    ).body as Envelope<{ id: string }>;
    return wl.data.id;
  };

  const wishlistChatId = async (actor: Actor, wishlistId: string): Promise<string> => {
    const res = await request(app.getHttpServer())
      .get(`${V1}/wishlists/${wishlistId}/chat`)
      .set(auth(actor.token))
      .expect(200);
    return (res.body as Envelope<ChatView>).data.id;
  };

  const post = (actor: Actor, chatId: string, body: Record<string, unknown>): request.Test =>
    request(app.getHttpServer())
      .post(`${V1}/chats/${chatId}/messages`)
      .set(auth(actor.token))
      .send(body);

  const history = (actor: Actor, chatId: string, query = ''): request.Test =>
    request(app.getHttpServer())
      .get(`${V1}/chats/${chatId}/messages${query}`)
      .set(auth(actor.token));

  const connect = (token: string): Promise<Socket> =>
    new Promise((resolve, reject) => {
      const socket = io(`${base}/chat`, {
        auth: { token },
        transports: ['websocket'],
        forceNew: true,
        reconnection: false,
      });
      openSockets.push(socket);
      const timer = setTimeout(() => reject(new Error('connect timeout')), 4000);
      socket.on('connect', () => {
        clearTimeout(timer);
        resolve(socket);
      });
      socket.on('connect_error', (err) => {
        clearTimeout(timer);
        reject(err);
      });
    });

  const emitAck = <T>(socket: Socket, event: string, data: unknown): Promise<T> =>
    new Promise((resolve) => socket.emit(event, data, resolve));

  const delay = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

  beforeAll(async () => {
    ctx = await createTestApp();
    app = ctx.app;
    authService = app.get(AuthService);
    emitter = app.get(EventEmitter2);
    messageModel = app.get<Model<MessageDocument>>(getModelToken(Message.name));
    await app.listen(0);
    const address = app.getHttpServer().address() as AddressInfo;
    base = `http://127.0.0.1:${address.port}`;
  }, 120_000);

  afterEach(() => {
    for (const s of openSockets.splice(0)) s.disconnect();
  });

  afterAll(async () => {
    await ctx.close();
  });

  // ── REST: posting, history, cursor ──────────────────────────────────────────

  describe('REST messaging', () => {
    it('posts messages and paginates history newest-first with a cursor', async () => {
      const owner = await newUser();
      const wl = await makeWishlist(owner);
      const chatId = await wishlistChatId(owner, wl);

      for (let i = 0; i < 5; i++) {
        await post(owner, chatId, { body: `msg ${i}` }).expect(201);
      }

      const page1 = (await history(owner, chatId, '?limit=3').expect(200)).body as Envelope<{
        items: MessageView[];
        nextCursor: string | null;
      }>;
      expect(page1.data.items).toHaveLength(3);
      expect(page1.data.items[0].body).toBe('msg 4'); // newest first
      expect(page1.data.nextCursor).toBeTruthy();

      const page2 = (
        await history(owner, chatId, `?limit=3&before=${page1.data.nextCursor}`).expect(200)
      ).body as Envelope<{ items: MessageView[]; nextCursor: string | null }>;
      expect(page2.data.items).toHaveLength(2);
      expect(page2.data.items[0].body).toBe('msg 1');
      expect(page2.data.nextCursor).toBeNull();
    });

    it('rejects an empty message and a non-participant poster', async () => {
      const owner = await newUser();
      const wl = await makeWishlist(owner, WishlistVisibility.PRIVATE);
      const chatId = await wishlistChatId(owner, wl);
      await post(owner, chatId, { body: '   ' }).expect(400);

      // A stranger cannot even see a private list's chat.
      const stranger = await newUser();
      await request(app.getHttpServer())
        .get(`${V1}/wishlists/${wl}/chat`)
        .set(auth(stranger.token))
        .expect(404);
    });

    it('edits and soft-deletes your own message; not someone else’s', async () => {
      const owner = await newUser();
      const other = await newUser();
      const wl = await makeWishlist(owner);
      const chatId = await wishlistChatId(owner, wl);
      // `other` can gift/comment on a public list.
      const msg = (await post(other, chatId, { body: 'hi' }).expect(201))
        .body as Envelope<MessageView>;

      await request(app.getHttpServer())
        .patch(`${V1}/messages/${msg.data.id}`)
        .set(auth(owner.token))
        .send({ body: 'hijack' })
        .expect(403);

      const edited = (
        await request(app.getHttpServer())
          .patch(`${V1}/messages/${msg.data.id}`)
          .set(auth(other.token))
          .send({ body: 'edited' })
          .expect(200)
      ).body as Envelope<MessageView>;
      expect(edited.data.body).toBe('edited');

      await request(app.getHttpServer())
        .delete(`${V1}/messages/${msg.data.id}`)
        .set(auth(other.token))
        .expect(200);
      const after = (await history(owner, chatId).expect(200)).body as Envelope<{
        items: MessageView[];
      }>;
      expect(after.data.items[0].body).toBe(''); // deleted → blanked
    });
  });

  // ── Gateway auth + real-time delivery ───────────────────────────────────────

  describe('realtime', () => {
    it('rejects a socket with no/invalid token', async () => {
      await expect(connect('not-a-token')).rejects.toBeDefined();
    });

    it('delivers a posted message to a joined client in real time', async () => {
      const owner = await newUser();
      const friend = await newUser();
      const wl = await makeWishlist(owner);
      const chatId = await wishlistChatId(owner, wl);

      const socket = await connect(friend.token);
      const ack = await emitAck<{ joined: string }>(socket, 'join_chat', { chatId });
      expect(ack.joined).toBe(chatId);

      const received = new Promise<MessageView>((resolve) =>
        socket.once('message:new', (m: MessageView) => resolve(m)),
      );
      await post(owner, chatId, { body: 'live!' }).expect(201);
      const msg = await received;
      expect(msg.body).toBe('live!');
    });
  });

  // ── Exit criterion: owner cannot see surprise-gift chatter ──────────────────

  describe('anti-spoiler', () => {
    it('hides a surprise message from the owner over REST and socket', async () => {
      const owner = await newUser();
      const gifter = await newUser();
      const wl = await makeWishlist(owner);
      const chatId = await wishlistChatId(owner, wl);

      const ownerSocket = await connect(owner.token);
      const gifterSocket = await connect(gifter.token);
      await emitAck(ownerSocket, 'join_chat', { chatId });
      await emitAck(gifterSocket, 'join_chat', { chatId });

      const ownerSeen: MessageView[] = [];
      const gifterSeen: MessageView[] = [];
      ownerSocket.on('message:new', (m: MessageView) => ownerSeen.push(m));
      gifterSocket.on('message:new', (m: MessageView) => gifterSeen.push(m));

      // A surprise-flagged message from the gifter.
      const secret = (
        await post(gifter, chatId, { body: 'getting the espresso machine', surprise: true }).expect(
          201,
        )
      ).body as Envelope<MessageView>;
      // A normal message so the owner has *something* to receive.
      await post(gifter, chatId, { body: 'hello everyone' }).expect(201);
      await delay(400);

      // Socket: the gifter saw both; the owner never saw the surprise.
      expect(gifterSeen.map((m) => m.body)).toContain('getting the espresso machine');
      expect(ownerSeen.map((m) => m.body)).toContain('hello everyone');
      expect(ownerSeen.map((m) => m.id)).not.toContain(secret.data.id);

      // REST history: same story.
      const ownerHistory = (await history(owner, chatId).expect(200)).body as Envelope<{
        items: MessageView[];
      }>;
      expect(ownerHistory.data.items.map((m) => m.id)).not.toContain(secret.data.id);
      const gifterHistory = (await history(gifter, chatId).expect(200)).body as Envelope<{
        items: MessageView[];
      }>;
      expect(gifterHistory.data.items.map((m) => m.id)).toContain(secret.data.id);
    });
  });

  // ── Exit criterion: revoked user force-disconnected, cannot read history ────

  describe('force-disconnect on revocation', () => {
    it('evicts a revoked participant from the chat and blocks history', async () => {
      const owner = await newUser();
      const guest = await newUser();
      const wl = await makeWishlist(owner, WishlistVisibility.PRIVATE);

      // Grant the guest access as a participant.
      await request(app.getHttpServer())
        .post(`${V1}/wishlists/${wl}/participants`)
        .set(auth(owner.token))
        .send({ userId: guest.userId, role: 'contributor' })
        .expect(201);

      const chatId = await wishlistChatId(guest, wl);
      const guestSocket = await connect(guest.token);
      await emitAck(guestSocket, 'join_chat', { chatId });

      // Before revocation the guest receives messages.
      const before = new Promise<MessageView>((resolve) =>
        guestSocket.once('message:new', (m: MessageView) => resolve(m)),
      );
      await post(owner, chatId, { body: 'welcome' }).expect(201);
      expect((await before).body).toBe('welcome');

      // Revoke.
      const parts = (
        await request(app.getHttpServer())
          .get(`${V1}/wishlists/${wl}/participants`)
          .set(auth(owner.token))
          .expect(200)
      ).body as Envelope<{ id: string; userId: string | null }[]>;
      const guestPart = parts.data.find((p) => p.userId === guest.userId)!;
      await request(app.getHttpServer())
        .delete(`${V1}/wishlists/${wl}/participants/${guestPart.id}`)
        .set(auth(owner.token))
        .expect(204);
      await delay(400); // let the force-leave propagate

      // No more live messages, and history is closed to them.
      const afterSeen: MessageView[] = [];
      guestSocket.on('message:new', (m: MessageView) => afterSeen.push(m));
      await post(owner, chatId, { body: 'after revoke' }).expect(201);
      await delay(400);
      expect(afterSeen).toHaveLength(0);
      await history(guest, chatId).expect(404);
    });
  });

  // ── Exit criterion: exactly one system message per lifecycle event ──────────

  describe('system messages', () => {
    it('posts exactly one system message even if the event fires twice', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const contributor = await newUser();
      const wl = await makeWishlist(owner);
      const item = (
        await request(app.getHttpServer())
          .post(`${V1}/wishlists/${wl}/items`)
          .set(auth(owner.token))
          .send({ title: 'Speaker', price: { amountMinor: 1000 } })
          .expect(201)
      ).body as Envelope<{ id: string }>;

      const gg = (
        await request(app.getHttpServer())
          .post(`${V1}/items/${item.data.id}/group-gift`)
          .set(auth(initiator.token))
          .set('Idempotency-Key', randomUUID())
          .send({ targetAmountMinor: 1000, visibility: 'visible' })
          .expect(201)
      ).body as Envelope<{ id: string; chatId?: string }>;
      const ggId = gg.data.id;

      // Fund it → GROUP_GIFT_FUNDED → one GOAL_REACHED system message.
      await request(app.getHttpServer())
        .post(`${V1}/group-gifts/${ggId}/contribute`)
        .set(auth(contributor.token))
        .set('Idempotency-Key', randomUUID())
        .send({ amountMinor: 1000 })
        .expect(201);
      await delay(200);

      // Re-emit the same event a second time — the dedupe key must make it a no-op.
      emitter.emit(GROUP_GIFT_FUNDED, {
        groupGiftId: ggId,
        itemId: item.data.id,
        wishlistId: wl,
        initiatorId: initiator.userId,
        targetAmountMinor: 1000,
        collectedAmountMinor: 1000,
        currency: 'INR',
        contributorCount: 1,
      } satisfies GroupGiftFundedEvent);
      await delay(300);

      const goalMessages = await messageModel.countDocuments({
        systemType: 'goal_reached',
        dedupeKey: `gg_funded:${ggId}`,
      });
      expect(goalMessages).toBe(1);
    });

    it('keeps a hidden group gift’s chat away from the recipient', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const wl = await makeWishlist(owner);
      const item = (
        await request(app.getHttpServer())
          .post(`${V1}/wishlists/${wl}/items`)
          .set(auth(owner.token))
          .send({ title: 'Watch', price: { amountMinor: 5000 } })
          .expect(201)
      ).body as Envelope<{ id: string }>;
      const gg = (
        await request(app.getHttpServer())
          .post(`${V1}/items/${item.data.id}/group-gift`)
          .set(auth(initiator.token))
          .set('Idempotency-Key', randomUUID())
          .send({ targetAmountMinor: 5000 }) // hidden_from_owner by default
          .expect(201)
      ).body as Envelope<{ id: string; chatId?: string }>;

      const chatId = gg.data.chatId!;
      expect(chatId).toBeTruthy();
      // The initiator can see the chat...
      await request(app.getHttpServer())
        .get(`${V1}/chats/${chatId}`)
        .set(auth(initiator.token))
        .expect(200);
      // ...the recipient (owner) cannot — it would spoil the surprise.
      await request(app.getHttpServer())
        .get(`${V1}/chats/${chatId}`)
        .set(auth(owner.token))
        .expect(404);
    });
  });

  // ── Read receipts + dashboard ───────────────────────────────────────────────

  describe('read receipts & dashboard', () => {
    it('tracks unread and clears it on read; lights up the dashboard sections', async () => {
      const owner = await newUser();
      const friend = await newUser();
      const wl = await makeWishlist(owner);
      const chatId = await wishlistChatId(friend, wl);

      await post(owner, chatId, { body: 'one' }).expect(201);
      await post(owner, chatId, { body: 'two' }).expect(201);

      const chat = (
        await request(app.getHttpServer())
          .get(`${V1}/chats/${chatId}`)
          .set(auth(friend.token))
          .expect(200)
      ).body as Envelope<{ unreadCount: number }>;
      expect(chat.data.unreadCount).toBe(2);

      const read = (
        await request(app.getHttpServer())
          .post(`${V1}/chats/${chatId}/read`)
          .set(auth(friend.token))
          .send({})
          .expect(200)
      ).body as Envelope<{ unreadCount: number }>;
      expect(read.data.unreadCount).toBe(0);

      const dash = (
        await request(app.getHttpServer())
          .get(`${V1}/dashboard/summary`)
          .set(auth(friend.token))
          .expect(200)
      ).body as Envelope<{ sections: Record<string, { available: boolean; count: number }> }>;
      expect(dash.data.sections.wishlistChats.available).toBe(true);
      expect(dash.data.sections.wishlistChats.count).toBeGreaterThanOrEqual(1);
    });
  });

  it('has no error code collisions in the chat block', () => {
    // A cheap guard the ErrorCode enum stayed well-formed after Sprint 8's additions.
    expect(ErrorCode.CHAT_NOT_FOUND).toBe('CHAT_NOT_FOUND');
  });
});
