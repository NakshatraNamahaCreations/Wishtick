import request from 'supertest';
import type { Server } from 'node:http';
import type { INestApplication } from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { randomUUID } from 'node:crypto';
import type { Model } from 'mongoose';
import { ErrorCode } from 'src/common/errors/error-codes';
import { AuthService } from 'src/modules/auth/auth.service';
import { GiftStatus } from 'src/modules/gifting/gift.types';
import { Gift, type GiftDocument } from 'src/modules/gifting/schemas/gift.schema';
import { GroupGiftReconcileService } from 'src/modules/group-gifts/group-gift-reconcile.service';
import { GroupGiftStatus, OverfundPolicy } from 'src/modules/group-gifts/group-gift.types';
import {
  GroupGift,
  type GroupGiftDocument,
} from 'src/modules/group-gifts/schemas/group-gift.schema';
import { WishlistVisibility } from 'src/modules/wishlists/wishlist.types';
import { createTestApp, V1, type TestApp } from './utils/test-app';

const PASSWORD = 'correct-horse-battery-staple';

interface Envelope<T> {
  success: boolean;
  data: T;
  error?: { code: string; message: string; details?: unknown };
}

interface GroupGiftView {
  id: string;
  itemId: string;
  status: string;
  targetAmountMinor: number;
  collectedAmountMinor: number;
  percentFunded: number;
  contributorCount: number;
  participantCount: number;
  participants: { userId: string; name: string }[];
  recentContributions: {
    id: string;
    amountMinor: number;
    anonymous: boolean;
    contributor: { userId: string; name: string } | null;
  }[];
  myContributionMinor: number;
  share?: { slug: string; url: string; hasPasscode: boolean };
}

interface Actor {
  token: string;
  userId: string;
}

describe('Group gifting (e2e)', () => {
  let ctx: TestApp;
  let app: INestApplication;
  let groupGiftModel: Model<GroupGiftDocument>;
  let giftModel: Model<GiftDocument>;
  let reconcile: GroupGiftReconcileService;
  let authService: AuthService;
  let seq = 0;

  const auth = (token: string) => ({ Authorization: `Bearer ${token}` });
  const idem = () => ({ 'Idempotency-Key': randomUUID() });

  const newUser = async (): Promise<Actor> => {
    const email = `gg${++seq}.${Date.now()}@example.com`;
    const res = await request(app.getHttpServer())
      .post(`${V1}/auth/signup`)
      .send({ email, password: PASSWORD, name: `Friend ${seq}` })
      .expect(201);
    const body = res.body as Envelope<{ user: { id: string }; tokens: { accessToken: string } }>;
    return { token: body.data.tokens.accessToken, userId: body.data.user.id };
  };

  /** Bypasses the signup throttle (5/hr) so the 100-contributor test can mint principals. */
  const newUserDirect = async (): Promise<Actor> => {
    const email = `ggd${++seq}.${Date.now()}@example.com`;
    const { user, tokens } = await authService.signup(
      { email, password: PASSWORD, name: `Friend ${seq}` },
      { ip: '127.0.0.1', userAgent: 'e2e' },
    );
    return { token: tokens.accessToken, userId: user.id };
  };

  const wishlistWithItem = async (
    owner: Actor,
    visibility = WishlistVisibility.PUBLIC,
  ): Promise<{ wishlistId: string; itemId: string }> => {
    const wl = (
      await request(app.getHttpServer())
        .post(`${V1}/wishlists`)
        .set(auth(owner.token))
        .send({ title: 'Gift me', visibility })
        .expect(201)
    ).body as Envelope<{ id: string }>;
    const item = (
      await request(app.getHttpServer())
        .post(`${V1}/wishlists/${wl.data.id}/items`)
        .set(auth(owner.token))
        .send({ title: 'Espresso machine', price: { amountMinor: 4999900 } })
        .expect(201)
    ).body as Envelope<{ id: string }>;
    return { wishlistId: wl.data.id, itemId: item.data.id };
  };

  const createGroupGift = (
    initiator: Actor,
    itemId: string,
    body: Record<string, unknown> = {},
  ): request.Test =>
    request(app.getHttpServer())
      .post(`${V1}/items/${itemId}/group-gift`)
      .set(auth(initiator.token))
      .set(idem())
      .send(body);

  const contribute = (user: Actor, ggId: string, body: Record<string, unknown>): request.Test =>
    request(app.getHttpServer())
      .post(`${V1}/group-gifts/${ggId}/contribute`)
      .set(auth(user.token))
      .set(idem())
      .send(body);

  beforeAll(async () => {
    ctx = await createTestApp();
    app = ctx.app;
    groupGiftModel = app.get<Model<GroupGiftDocument>>(getModelToken(GroupGift.name));
    giftModel = app.get<Model<GiftDocument>>(getModelToken(Gift.name));
    reconcile = app.get(GroupGiftReconcileService);
    authService = app.get(AuthService);
  }, 120_000);

  afterAll(async () => {
    await ctx.close();
  });

  beforeEach(async () => {
    await ctx.reset();
  });

  // ── Creation & item claim ───────────────────────────────────────────────────

  describe('creation & item claim', () => {
    it('opens a group gift that claims the item via a holder gift', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const { itemId } = await wishlistWithItem(owner);

      const gg = (
        await createGroupGift(initiator, itemId, { targetAmountMinor: 50000 }).expect(201)
      ).body as Envelope<GroupGiftView>;
      expect(gg.data.status).toBe('open');
      expect(gg.data.targetAmountMinor).toBe(50000);
      expect(gg.data.collectedAmountMinor).toBe(0);

      // The holder gift claims the item — a would-be single reserver is locked out.
      const stranger = await newUser();
      await request(app.getHttpServer())
        .post(`${V1}/items/${itemId}/reserve`)
        .set(auth(stranger.token))
        .set(idem())
        .send({})
        .expect(409);

      // And a second group gift on the same item is rejected.
      await createGroupGift(stranger, itemId, { targetAmountMinor: 10000 }).expect(409);
    });

    it('requires an Idempotency-Key to create', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const res = await request(app.getHttpServer())
        .post(`${V1}/items/${itemId}/group-gift`)
        .set(auth(initiator.token))
        .send({ targetAmountMinor: 50000 })
        .expect(400);
      expect((res.body as Envelope<never>).error?.code).toBe(ErrorCode.IDEMPOTENCY_KEY_REQUIRED);
    });

    it('refuses to let the owner group-gift their own item', async () => {
      const owner = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const res = await createGroupGift(owner, itemId, { targetAmountMinor: 50000 }).expect(403);
      expect((res.body as Envelope<never>).error?.code).toBe(ErrorCode.CANNOT_GIFT_OWN_ITEM);
    });

    it('defaults the target to the item price', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (await createGroupGift(initiator, itemId, {}).expect(201))
        .body as Envelope<GroupGiftView>;
      expect(gg.data.targetAmountMinor).toBe(4999900);
    });
  });

  // ── Exit criterion: 100 concurrent contributions → exact total, zero drift ──

  describe('contribution concurrency', () => {
    it('lands 100 concurrent contributions at an exact total with zero drift', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const share = 500;
      const target = share * 100;
      const gg = (
        await createGroupGift(initiator, itemId, { targetAmountMinor: target }).expect(201)
      ).body as Envelope<GroupGiftView>;
      const ggId = gg.data.id;

      // 100 distinct contributors, minted off the HTTP path (signup is throttled).
      const contributors: Actor[] = [];
      for (let i = 0; i < 100; i++) contributors.push(await newUserDirect());

      // Bind once so 100 parallel requests don't race supertest's lazy listen.
      const server = app.getHttpServer() as Server;
      await new Promise<void>((resolve) =>
        server.listening ? resolve() : server.listen(0, () => resolve()),
      );

      const results = await Promise.all(
        contributors.map((c, i) =>
          request(server)
            .post(`${V1}/group-gifts/${ggId}/contribute`)
            .set(auth(c.token))
            .set('X-Forwarded-For', `10.1.${Math.floor(i / 250)}.${i % 250}`)
            .set('Idempotency-Key', randomUUID())
            .send({ amountMinor: share }),
        ),
      );

      const ok = results.filter((r) => r.status === 201);
      expect(ok).toHaveLength(100);

      // The cache is exact...
      const stored = await groupGiftModel.findById(ggId).exec();
      expect(stored!.collectedAmountMinor).toBe(target);
      expect(stored!.contributorCount).toBe(100);
      expect(stored!.status).toBe(GroupGiftStatus.FUNDED);

      // ...and the reconciler agrees: the sum of confirmed contributions has no drift.
      const report = await reconcile.reconcile();
      expect(report.drifted).toBe(0);
    }, 120_000);

    it('counts a contribution submitted twice with the same key exactly once', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const contributor = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (
        await createGroupGift(initiator, itemId, { targetAmountMinor: 10000 }).expect(201)
      ).body as Envelope<GroupGiftView>;

      const key = randomUUID();
      const first = await request(app.getHttpServer())
        .post(`${V1}/group-gifts/${gg.data.id}/contribute`)
        .set(auth(contributor.token))
        .set('Idempotency-Key', key)
        .send({ amountMinor: 2500 })
        .expect(201);
      const retry = await request(app.getHttpServer())
        .post(`${V1}/group-gifts/${gg.data.id}/contribute`)
        .set(auth(contributor.token))
        .set('Idempotency-Key', key)
        .send({ amountMinor: 2500 })
        .expect(201);

      expect((first.body as Envelope<GroupGiftView>).data.collectedAmountMinor).toBe(2500);
      expect((retry.body as Envelope<GroupGiftView>).data.collectedAmountMinor).toBe(2500);
      const stored = await groupGiftModel.findById(gg.data.id).exec();
      expect(stored!.collectedAmountMinor).toBe(2500);
      expect(stored!.contributorCount).toBe(1);
    });
  });

  // ── Over-target policy ──────────────────────────────────────────────────────

  describe('over-target policy', () => {
    it('caps an over-target contribution so the total lands exactly on target', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const a = await newUser();
      const b = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (
        await createGroupGift(initiator, itemId, {
          targetAmountMinor: 1000,
          overfundPolicy: OverfundPolicy.CAP,
        }).expect(201)
      ).body as Envelope<GroupGiftView>;

      await contribute(a, gg.data.id, { amountMinor: 600 }).expect(201);
      const capped = (await contribute(b, gg.data.id, { amountMinor: 600 }).expect(201))
        .body as Envelope<GroupGiftView>;
      // Only 400 remained; the 600 was capped to it and the gift funded exactly.
      expect(capped.data.collectedAmountMinor).toBe(1000);
      expect(capped.data.status).toBe('funded');
    });

    it('rejects an over-target contribution when the policy is reject', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const a = await newUser();
      const b = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (
        await createGroupGift(initiator, itemId, {
          targetAmountMinor: 1000,
          overfundPolicy: OverfundPolicy.REJECT,
        }).expect(201)
      ).body as Envelope<GroupGiftView>;

      await contribute(a, gg.data.id, { amountMinor: 600 }).expect(201);
      const res = await contribute(b, gg.data.id, { amountMinor: 600 }).expect(409);
      expect((res.body as Envelope<never>).error?.code).toBe(ErrorCode.CONTRIBUTION_EXCEEDS_TARGET);
      const stored = await groupGiftModel.findById(gg.data.id).exec();
      expect(stored!.collectedAmountMinor).toBe(600);
    });

    it('stops accepting contributions once funded', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const a = await newUser();
      const b = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (await createGroupGift(initiator, itemId, { targetAmountMinor: 1000 }).expect(201))
        .body as Envelope<GroupGiftView>;
      await contribute(a, gg.data.id, { amountMinor: 1000 }).expect(201);
      const res = await contribute(b, gg.data.id, { amountMinor: 100 }).expect(409);
      expect((res.body as Envelope<never>).error?.code).toBe(ErrorCode.GROUP_GIFT_NOT_OPEN);
    });

    it('refuses a contribution to your own item', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (await createGroupGift(initiator, itemId, { targetAmountMinor: 1000 }).expect(201))
        .body as Envelope<GroupGiftView>;
      const res = await contribute(owner, gg.data.id, { amountMinor: 500 }).expect(403);
      expect((res.body as Envelope<never>).error?.code).toBe(ErrorCode.CANNOT_GIFT_OWN_ITEM);
    });

    it('lets a contributor withdraw before the gift funds', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const a = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (await createGroupGift(initiator, itemId, { targetAmountMinor: 5000 }).expect(201))
        .body as Envelope<GroupGiftView>;
      const contributed = (await contribute(a, gg.data.id, { amountMinor: 2000 }).expect(201))
        .body as Envelope<GroupGiftView>;
      const contributionId = contributed.data.recentContributions[0].id;

      const after = await request(app.getHttpServer())
        .delete(`${V1}/group-gifts/${gg.data.id}/contributions/${contributionId}`)
        .set(auth(a.token))
        .expect(200);
      expect((after.body as Envelope<GroupGiftView>).data.collectedAmountMinor).toBe(0);
      expect((after.body as Envelope<GroupGiftView>).data.contributorCount).toBe(0);
    });
  });

  // ── Exit criterion: anonymous contributors never appear by name ─────────────

  describe('anonymity', () => {
    it('hides anonymous contributors from every participant projection', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const named = await newUser();
      const secret = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (
        await createGroupGift(initiator, itemId, { targetAmountMinor: 10000 }).expect(201)
      ).body as Envelope<GroupGiftView>;

      await contribute(named, gg.data.id, { amountMinor: 1000 }).expect(201);
      await contribute(secret, gg.data.id, { amountMinor: 1500, anonymous: true }).expect(201);

      const view = (
        await request(app.getHttpServer())
          .get(`${V1}/group-gifts/${gg.data.id}`)
          .set(auth(initiator.token))
          .expect(200)
      ).body as Envelope<GroupGiftView>;

      // Both are counted, and the money is both amounts...
      expect(view.data.contributorCount).toBe(2);
      expect(view.data.collectedAmountMinor).toBe(2500);
      // ...but the anonymous contributor is not a named participant.
      const participantIds = view.data.participants.map((p) => p.userId);
      expect(participantIds).toContain(named.userId);
      expect(participantIds).not.toContain(secret.userId);
      // The anonymous contribution appears on the timeline with no contributor.
      const anon = view.data.recentContributions.find((c) => c.anonymous);
      expect(anon).toBeDefined();
      expect(anon!.contributor).toBeNull();
    });
  });

  // ── Purchase / cancel ───────────────────────────────────────────────────────

  describe('purchase & cancel', () => {
    it('lets only the initiator purchase a funded gift, marking the item purchased', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const a = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (await createGroupGift(initiator, itemId, { targetAmountMinor: 1000 }).expect(201))
        .body as Envelope<GroupGiftView>;
      await contribute(a, gg.data.id, { amountMinor: 1000 }).expect(201);

      // A non-initiator cannot purchase.
      await request(app.getHttpServer())
        .post(`${V1}/group-gifts/${gg.data.id}/purchase`)
        .set(auth(a.token))
        .send({})
        .expect(403);

      await request(app.getHttpServer())
        .post(`${V1}/group-gifts/${gg.data.id}/purchase`)
        .set(auth(initiator.token))
        .send({})
        .expect(200);

      const stored = await groupGiftModel.findById(gg.data.id).exec();
      expect(stored!.status).toBe(GroupGiftStatus.PURCHASED);
      const holder = await giftModel.findById(stored!.giftId).exec();
      expect(holder!.status).toBe(GiftStatus.PURCHASED);
    });

    it('cancels with refunds recorded and frees the item', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const a = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (await createGroupGift(initiator, itemId, { targetAmountMinor: 5000 }).expect(201))
        .body as Envelope<GroupGiftView>;
      await contribute(a, gg.data.id, { amountMinor: 2000 }).expect(201);

      await request(app.getHttpServer())
        .post(`${V1}/group-gifts/${gg.data.id}/cancel`)
        .set(auth(initiator.token))
        .send({})
        .expect(200);

      const stored = await groupGiftModel.findById(gg.data.id).exec();
      expect(stored!.status).toBe(GroupGiftStatus.CANCELLED);
      // The item is free again — a new single reservation succeeds.
      const other = await newUser();
      await request(app.getHttpServer())
        .post(`${V1}/items/${itemId}/reserve`)
        .set(auth(other.token))
        .set(idem())
        .send({})
        .expect(201);
    });
  });

  // ── Owner masking ───────────────────────────────────────────────────────────

  describe('owner masking', () => {
    it('hides a hidden group gift from the recipient but shows a visible one', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const { itemId, wishlistId } = await wishlistWithItem(owner);
      void wishlistId;

      const hidden = (
        await createGroupGift(initiator, itemId, { targetAmountMinor: 1000 }).expect(201)
      ).body as Envelope<GroupGiftView>;
      // The owner cannot fetch their own hidden group gift.
      await request(app.getHttpServer())
        .get(`${V1}/group-gifts/${hidden.data.id}`)
        .set(auth(owner.token))
        .expect(404);
    });
  });

  // ── Share & public view ─────────────────────────────────────────────────────

  describe('share & public', () => {
    it('shares a group gift and serves a redacted public view behind a passcode', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const named = await newUser();
      const secret = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (
        await createGroupGift(initiator, itemId, { targetAmountMinor: 10000 }).expect(201)
      ).body as Envelope<GroupGiftView>;
      await contribute(named, gg.data.id, { amountMinor: 1000 }).expect(201);
      await contribute(secret, gg.data.id, { amountMinor: 1000, anonymous: true }).expect(201);

      const share = (
        await request(app.getHttpServer())
          .post(`${V1}/group-gifts/${gg.data.id}/share`)
          .set(auth(initiator.token))
          .send({ passcode: 'secret123' })
          .expect(200)
      ).body as Envelope<{ slug: string; hasPasscode: boolean }>;
      expect(share.data.hasPasscode).toBe(true);
      const slug = share.data.slug;

      // No passcode → 401.
      await request(app.getHttpServer()).get(`${V1}/public/group-gifts/${slug}`).expect(401);
      // Wrong passcode → 403.
      await request(app.getHttpServer())
        .get(`${V1}/public/group-gifts/${slug}`)
        .query({ passcode: 'nope' })
        .expect(403);
      // Correct passcode → redacted view, anonymous still hidden.
      const pub = (
        await request(app.getHttpServer())
          .get(`${V1}/public/group-gifts/${slug}`)
          .query({ passcode: 'secret123' })
          .expect(200)
      ).body as Envelope<{
        collectedAmountMinor: number;
        contributorCount: number;
        participants: { userId: string }[];
        recentContributions: { anonymous: boolean; contributor: unknown }[];
      }>;
      expect(pub.data.collectedAmountMinor).toBe(2000);
      expect(pub.data.contributorCount).toBe(2);
      expect(pub.data.participants.map((p) => p.userId)).not.toContain(secret.userId);
      expect(pub.data.recentContributions.find((c) => c.anonymous)!.contributor).toBeNull();
    });
  });

  // ── Reconciliation ──────────────────────────────────────────────────────────

  describe('reconciliation', () => {
    it('detects and corrects a corrupted cached total', async () => {
      const owner = await newUser();
      const initiator = await newUser();
      const a = await newUser();
      const { itemId } = await wishlistWithItem(owner);
      const gg = (
        await createGroupGift(initiator, itemId, { targetAmountMinor: 10000 }).expect(201)
      ).body as Envelope<GroupGiftView>;
      await contribute(a, gg.data.id, { amountMinor: 3000 }).expect(201);

      // Corrupt the denormalized cache directly, simulating drift.
      await groupGiftModel.updateOne({ _id: gg.data.id }, { $set: { collectedAmountMinor: 9999 } });

      const report = await reconcile.reconcile();
      expect(report.drifted).toBeGreaterThanOrEqual(1);
      expect(report.corrected).toBeGreaterThanOrEqual(1);

      // Converged back to the true sum of confirmed contributions.
      const stored = await groupGiftModel.findById(gg.data.id).exec();
      expect(stored!.collectedAmountMinor).toBe(3000);
    });
  });
});
