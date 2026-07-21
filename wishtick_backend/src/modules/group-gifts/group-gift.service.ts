import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { customAlphabet } from 'nanoid';
import { Connection, Model, Types } from 'mongoose';
import { AppException } from 'src/common/errors/app.exception';
import { ErrorCode } from 'src/common/errors/error-codes';
import {
  GROUP_GIFT_CONTRIBUTION_RECEIVED,
  GROUP_GIFT_FULFILLED,
  GROUP_GIFT_FUNDED,
  GROUP_GIFT_JOINED,
  GROUP_GIFT_PURCHASED,
  type GroupGiftContributionReceivedEvent,
  type GroupGiftFulfilledEvent,
  type GroupGiftFundedEvent,
  type GroupGiftJoinedEvent,
  type GroupGiftPurchasedEvent,
} from 'src/common/events/domain-events';
import type { AppConfig } from 'src/config/configuration';
import { LockService } from 'src/infra/redis/lock.service';
import { GiftStatusService } from 'src/modules/gifting/gift-status.service';
import { GiftingService } from 'src/modules/gifting/gifting.service';
import { GiftMode, GiftStatus, GiftType } from 'src/modules/gifting/gift.types';
import { AccessPolicyService } from 'src/modules/wishlists/access/access-policy.service';
import {
  WishlistItem,
  type WishlistItemDocument,
} from 'src/modules/wishlists/schemas/wishlist-item.schema';
import { WishlistItemStatus } from 'src/modules/wishlists/wishlist.types';
import { WishlistsService } from 'src/modules/wishlists/wishlists.service';
import type { OpenGraphPreview } from 'src/modules/wishlists/wishlist.views';
import { UsersService } from 'src/modules/users/users.service';
import type { UserDocument } from 'src/modules/users/schemas/user.schema';
import { ChatService } from 'src/modules/chat/chat.service';
import { GroupGiftPreviewService } from './group-gift-preview.service';
import type {
  ContributeDto,
  CreateGroupGiftDto,
  GroupGiftActionDto,
  ShareGroupGiftDto,
} from './dto/group-gift.dto';
import {
  toGroupGiftView,
  toPublicGroupGiftView,
  type GroupGiftShareView,
  type GroupGiftView,
  type PublicGroupGiftView,
} from './group-gift.views';
import {
  CONTRIBUTABLE_GROUP_GIFT_STATUSES,
  ContributionStatus,
  GROUP_GIFT_TRANSITIONS,
  GroupGiftStatus,
  GroupGiftVisibility,
  OverfundPolicy,
} from './group-gift.types';
import { Contribution, type ContributionDocument } from './schemas/contribution.schema';
import { GroupGift, type GroupGiftDocument } from './schemas/group-gift.schema';

// Same unambiguous 16-char alphabet as wishlist/event share slugs.
const generateSlug = customAlphabet('23456789abcdefghijkmnpqrstuvwxyz', 16);

/** How many recent contributions the timeline carries. */
const TIMELINE_LIMIT = 20;

/** Thrown inside the contribute transaction when the durable idempotency key already exists. */
class DuplicateContributionSignal extends Error {}

/** What the contribute transaction captures for the post-commit event emission. */
interface ContributionOutcome {
  contributionId: string;
  effectiveAmount: number;
  newCollected: number;
  funded: boolean;
}

@Injectable()
export class GroupGiftService {
  private readonly logger = new Logger(GroupGiftService.name);
  private readonly shareBaseUrl: string;

  constructor(
    @InjectModel(GroupGift.name) private readonly groupGiftModel: Model<GroupGiftDocument>,
    @InjectModel(Contribution.name) private readonly contributionModel: Model<ContributionDocument>,
    @InjectModel(WishlistItem.name) private readonly itemModel: Model<WishlistItemDocument>,
    @InjectConnection() private readonly connection: Connection,
    private readonly status: GiftStatusService,
    private readonly gifting: GiftingService,
    private readonly locks: LockService,
    private readonly access: AccessPolicyService,
    private readonly wishlists: WishlistsService,
    private readonly users: UsersService,
    private readonly preview: GroupGiftPreviewService,
    private readonly chat: ChatService,
    private readonly emitter: EventEmitter2,
    private readonly config: ConfigService<AppConfig, true>,
  ) {
    this.shareBaseUrl = this.config.get('app.webAppUrl', { infer: true }).replace(/\/$/, '');
  }

  // ── Create: claims the item via a holder gift ───────────────────────────────

  /**
   * Starts a group gift on an item. Claims the item exactly as a single
   * reservation would — same lock key, same unique `(itemId, active)` index —
   * by creating a holder gift (type = group). The GroupGift then tracks funding;
   * the holder tracks the item. This is why a group gift and a single
   * reservation can never both hold one item.
   */
  async create(itemId: string, userId: string, dto: CreateGroupGiftDto): Promise<GroupGiftView> {
    const item = await this.gifting.loadGiftableItem(itemId, userId);

    const target = dto.targetAmountMinor ?? item.price?.amountMinor ?? null;
    if (!target || target <= 0) {
      throw new AppException(
        ErrorCode.CONTRIBUTION_AMOUNT_INVALID,
        'A group gift needs a positive target; the item has no price to default to',
        400,
      );
    }
    const maxTarget = this.config.get('groupGifting.maxTargetMinor', { infer: true });
    if (target > maxTarget) {
      throw new AppException(
        ErrorCode.CONTRIBUTION_AMOUNT_INVALID,
        `Target exceeds the maximum of ${maxTarget} minor units`,
        400,
      );
    }
    const deadline = this.parseDeadline(dto.deadline);
    const visibility = dto.visibility ?? GroupGiftVisibility.HIDDEN_FROM_OWNER;

    const gift = await this.locks.withBestEffortLock(
      `gift-item:${itemId}`,
      async () => {
        const session = await this.connection.startSession();
        try {
          let created!: GroupGiftDocument;
          await session.withTransaction(async () => {
            // Re-read the item inside the transaction — the same check-then-act
            // the single reserve does, so an item claimed a millisecond ago is
            // seen as taken. The holder's unique index is still the backstop.
            const fresh = await this.itemModel.findById(item._id).session(session).exec();
            if (!fresh || fresh.archivedAt) {
              throw new AppException(ErrorCode.WISHLIST_ITEM_NOT_FOUND, 'Item not found', 404);
            }
            if (fresh.status !== WishlistItemStatus.AVAILABLE) {
              throw new AppException(
                ErrorCode.ITEM_NOT_AVAILABLE,
                'This item is already spoken for',
                409,
                { status: fresh.status },
              );
            }
            const holder = await this.status.createReservation(
              {
                item: fresh,
                gifterId: new Types.ObjectId(userId),
                recipientId: fresh.ownerId,
                mode: GiftMode.ONLINE,
                visibility,
                expiresAt: null,
                type: GiftType.GROUP,
                amountMinorOverride: target,
              },
              session,
            );

            const now = new Date();
            const [doc] = await this.groupGiftModel.create(
              [
                {
                  itemId: item._id,
                  wishlistId: item.wishlistId,
                  initiatorId: new Types.ObjectId(userId),
                  recipientId: item.ownerId,
                  giftId: holder._id,
                  targetAmountMinor: target,
                  collectedAmountMinor: 0,
                  currency: item.price?.currency ?? 'INR',
                  deadline,
                  status: GroupGiftStatus.OPEN,
                  overfundPolicy: dto.overfundPolicy ?? OverfundPolicy.CAP,
                  visibility,
                  // The initiator is a named member from the start.
                  participantIds: [new Types.ObjectId(userId)],
                  contributorCount: 0,
                  message: dto.message ?? null,
                  share: {
                    slug: generateSlug(),
                    passcodeHash: null,
                    expiresAt: null,
                    rotatedAt: now,
                  },
                  history: [{ status: GroupGiftStatus.OPEN, at: now, by: userId, note: 'created' }],
                },
              ],
              { session },
            );
            created = doc;
          });
          return created;
        } finally {
          await session.endSession();
        }
      },
      { ttlMs: 5_000, retries: 5, retryDelayMs: 60 },
    );

    await this.wishlists.recount(gift.wishlistId);
    // Render an initial share card off the request path.
    void this.preview.refresh(gift).catch(() => undefined);
    // Provision the group-gift chat and record its id on the gift.
    try {
      const chatDoc = await this.chat.provisionForGroupGift(gift._id.toString(), userId);
      await this.groupGiftModel.updateOne({ _id: gift._id }, { $set: { chatId: chatDoc._id } });
      gift.chatId = chatDoc._id;
    } catch (err) {
      this.logger.error(
        `Failed to provision chat for group gift ${gift._id.toString()}: ${
          err instanceof Error ? err.message : String(err)
        }`,
      );
    }
    this.logger.log(`Group gift ${gift._id.toString()} opened on item ${itemId} by ${userId}`);
    return this.assembleView(gift, userId);
  }

  // ── Join: become a named member without contributing ────────────────────────

  async join(groupGiftId: string, userId: string): Promise<GroupGiftView> {
    const gift = await this.loadOrFail(groupGiftId);
    await this.authorizeParticipation(gift, userId);
    if (
      [GroupGiftStatus.CANCELLED, GroupGiftStatus.REFUNDING, GroupGiftStatus.FULFILLED].includes(
        gift.status,
      )
    ) {
      throw new AppException(ErrorCode.GROUP_GIFT_CLOSED, 'This group gift is closed', 409);
    }
    const res = await this.groupGiftModel
      .updateOne({ _id: gift._id }, { $addToSet: { participantIds: new Types.ObjectId(userId) } })
      .exec();
    // Only announce a genuinely new member, so a repeat "join" is silent.
    if (res.modifiedCount === 1) {
      this.emitter.emit(GROUP_GIFT_JOINED, {
        groupGiftId,
        userId,
      } satisfies GroupGiftJoinedEvent);
    }
    const refreshed = await this.loadOrFail(groupGiftId);
    return this.assembleView(refreshed, userId);
  }

  // ── Contribute: the concurrency-critical path ───────────────────────────────

  /**
   * Records a contribution. THE money-critical path, defended like the reserve:
   *
   *  1. **Best-effort lock** on `group-gift:{id}` serializes the common case.
   *  2. **A transaction** re-reads the current total and does the capping + the
   *     `$inc` atomically; two contributions to the same gift write the same
   *     document, so the second conflict-retries against the updated total —
   *     that is what makes 100 concurrent contributions sum exactly, even if the
   *     lock is bypassed.
   *  3. **A unique `(groupGiftId, idempotencyKey)` index** is the durable
   *     guarantee a retried contribution is counted once, behind the 24h HTTP
   *     interceptor.
   */
  async contribute(
    groupGiftId: string,
    userId: string,
    idempotencyKey: string,
    dto: ContributeDto,
  ): Promise<GroupGiftView> {
    const min = this.config.get('groupGifting.minContributionMinor', { infer: true });
    if (!Number.isInteger(dto.amountMinor) || dto.amountMinor < min) {
      throw new AppException(
        ErrorCode.CONTRIBUTION_AMOUNT_INVALID,
        `A contribution must be a whole number of at least ${min} minor units`,
        400,
      );
    }

    const gift = await this.loadOrFail(groupGiftId);
    await this.authorizeParticipation(gift, userId);

    // Fast path for a durable replay (Redis flushed between retries): the row is
    // already there, so return the current state without re-running anything.
    const existing = await this.contributionModel
      .findOne({ groupGiftId: gift._id, idempotencyKey })
      .exec();
    if (existing) {
      const refreshed = await this.loadOrFail(groupGiftId);
      return this.assembleView(refreshed, userId);
    }

    let outcome: ContributionOutcome | undefined;
    try {
      outcome = await this.locks.withBestEffortLock<ContributionOutcome | undefined>(
        `group-gift:${groupGiftId}`,
        async () => {
          const session = await this.connection.startSession();
          try {
            let captured: ContributionOutcome | undefined;
            await session.withTransaction(async () => {
              const gg = await this.groupGiftModel.findById(gift._id).session(session).exec();
              if (!gg)
                throw new AppException(ErrorCode.GROUP_GIFT_NOT_FOUND, 'Group gift not found', 404);
              if (!CONTRIBUTABLE_GROUP_GIFT_STATUSES.includes(gg.status)) {
                throw new AppException(
                  ErrorCode.GROUP_GIFT_NOT_OPEN,
                  'This group gift is no longer accepting contributions',
                  409,
                  { status: gg.status },
                );
              }
              if (gg.deadline && gg.deadline.getTime() <= Date.now()) {
                throw new AppException(
                  ErrorCode.GROUP_GIFT_CLOSED,
                  'The collection has closed',
                  409,
                );
              }

              const remaining = gg.targetAmountMinor - gg.collectedAmountMinor;
              if (remaining <= 0) {
                throw new AppException(
                  ErrorCode.GROUP_GIFT_NOT_OPEN,
                  'Target already reached',
                  409,
                );
              }
              let amount = dto.amountMinor;
              if (amount > remaining) {
                if (gg.overfundPolicy === OverfundPolicy.REJECT) {
                  throw new AppException(
                    ErrorCode.CONTRIBUTION_EXCEEDS_TARGET,
                    `Only ${remaining} minor units remain; this group rejects over-target contributions`,
                    409,
                    { remaining },
                  );
                }
                amount = remaining; // CAP: land exactly on target.
              }

              const now = new Date();
              let contribution: ContributionDocument;
              try {
                [contribution] = await this.contributionModel.create(
                  [
                    {
                      groupGiftId: gg._id,
                      userId: new Types.ObjectId(userId),
                      amountMinor: amount,
                      status: ContributionStatus.CONFIRMED,
                      anonymous: dto.anonymous ?? false,
                      message: dto.message ?? null,
                      idempotencyKey,
                    },
                  ],
                  { session },
                );
              } catch (err) {
                if (GroupGiftService.isDuplicateKey(err)) throw new DuplicateContributionSignal();
                throw err;
              }

              // First confirmed contribution by this user? Then they are a new contributor.
              const prior = await this.contributionModel
                .countDocuments({
                  groupGiftId: gg._id,
                  userId: new Types.ObjectId(userId),
                  status: ContributionStatus.CONFIRMED,
                  _id: { $ne: contribution._id },
                })
                .session(session);

              const newCollected = gg.collectedAmountMinor + amount;
              const funded = newCollected >= gg.targetAmountMinor;

              const update: Record<string, unknown> = { $inc: { collectedAmountMinor: amount } };
              const inc = update.$inc as Record<string, number>;
              if (prior === 0) inc.contributorCount = 1;
              if (!(dto.anonymous ?? false)) {
                update.$addToSet = { participantIds: new Types.ObjectId(userId) };
              }
              if (funded) {
                update.$set = { status: GroupGiftStatus.FUNDED };
                update.$push = {
                  history: {
                    status: GroupGiftStatus.FUNDED,
                    at: now,
                    by: 'system:funded',
                    note: null,
                  },
                };
              }
              await this.groupGiftModel.updateOne({ _id: gg._id }, update, { session }).exec();

              captured = {
                contributionId: contribution._id.toString(),
                effectiveAmount: amount,
                newCollected,
                funded,
              };
            });
            return captured;
          } finally {
            await session.endSession();
          }
        },
        { ttlMs: 5_000, retries: 15, retryDelayMs: 40 },
      );
    } catch (err) {
      // A durable-key collision that slipped past the pre-check is an idempotent
      // no-op, not a failure — return the current state.
      if (!(err instanceof DuplicateContributionSignal)) throw err;
    }

    if (outcome) {
      // Announce, outside the transaction. Subscribers (Sprint 8/9) redact anonymity.
      this.emitter.emit(GROUP_GIFT_CONTRIBUTION_RECEIVED, {
        groupGiftId,
        contributionId: outcome.contributionId,
        contributorId: userId,
        amountMinor: outcome.effectiveAmount,
        anonymous: dto.anonymous ?? false,
        collectedAmountMinor: outcome.newCollected,
        targetAmountMinor: gift.targetAmountMinor,
      } satisfies GroupGiftContributionReceivedEvent);

      if (outcome.funded) {
        this.emitter.emit(GROUP_GIFT_FUNDED, {
          groupGiftId,
          itemId: gift.itemId.toString(),
          wishlistId: gift.wishlistId.toString(),
          initiatorId: gift.initiatorId.toString(),
          targetAmountMinor: gift.targetAmountMinor,
          collectedAmountMinor: outcome.newCollected,
          currency: gift.currency,
          contributorCount: 0,
        } satisfies GroupGiftFundedEvent);
        this.logger.log(
          `Group gift ${groupGiftId} funded (${outcome.newCollected}/${gift.targetAmountMinor})`,
        );
      }
    }

    const refreshed = await this.loadOrFail(groupGiftId);
    return this.assembleView(refreshed, userId);
  }

  // ── Withdraw a contribution before the gift funds ───────────────────────────

  async removeContribution(
    groupGiftId: string,
    contributionId: string,
    userId: string,
  ): Promise<GroupGiftView> {
    if (!Types.ObjectId.isValid(contributionId)) {
      throw new AppException(ErrorCode.CONTRIBUTION_NOT_FOUND, 'Contribution not found', 404);
    }
    const gift = await this.loadOrFail(groupGiftId);

    await this.locks.withBestEffortLock(
      `group-gift:${groupGiftId}`,
      async () => {
        const session = await this.connection.startSession();
        try {
          await session.withTransaction(async () => {
            const contribution = await this.contributionModel
              .findById(contributionId)
              .session(session)
              .exec();
            if (
              !contribution ||
              contribution.groupGiftId.toString() !== groupGiftId ||
              contribution.status !== ContributionStatus.CONFIRMED
            ) {
              throw new AppException(
                ErrorCode.CONTRIBUTION_NOT_FOUND,
                'Contribution not found',
                404,
              );
            }
            if (contribution.userId.toString() !== userId) {
              throw new AppException(
                ErrorCode.NOT_THE_CONTRIBUTOR,
                'You can only withdraw your own contribution',
                403,
              );
            }
            const gg = await this.groupGiftModel.findById(gift._id).session(session).exec();
            if (!gg || gg.status !== GroupGiftStatus.OPEN) {
              throw new AppException(
                ErrorCode.GROUP_GIFT_NOT_OPEN,
                'Contributions can only be withdrawn while the gift is still open',
                409,
              );
            }

            const now = new Date();
            contribution.status = ContributionStatus.REFUNDED;
            contribution.refundedAt = now;
            contribution.refundRef = `withdraw-${contribution._id.toString()}`;
            await contribution.save({ session });

            // Fewer confirmed contributions may drop the contributor count.
            const stillHas = await this.contributionModel
              .countDocuments({
                groupGiftId: gg._id,
                userId: contribution.userId,
                status: ContributionStatus.CONFIRMED,
              })
              .session(session);

            const update: Record<string, unknown> = {
              $inc: { collectedAmountMinor: -contribution.amountMinor },
            };
            if (stillHas === 0) (update.$inc as Record<string, number>).contributorCount = -1;
            await this.groupGiftModel.updateOne({ _id: gg._id }, update, { session }).exec();
          });
        } finally {
          await session.endSession();
        }
      },
      { ttlMs: 5_000, retries: 10, retryDelayMs: 40 },
    );

    const refreshed = await this.loadOrFail(groupGiftId);
    return this.assembleView(refreshed, userId);
  }

  // ── Purchase / fulfil / cancel (initiator) ──────────────────────────────────

  async purchase(
    groupGiftId: string,
    userId: string,
    dto: GroupGiftActionDto,
  ): Promise<GroupGiftView> {
    const view = await this.driveHolder(groupGiftId, userId, {
      requireStatus: GroupGiftStatus.FUNDED,
      toGroupStatus: GroupGiftStatus.PURCHASED,
      holderTo: GiftStatus.PURCHASED,
      note: dto.note ?? null,
    });
    this.emitter.emit(GROUP_GIFT_PURCHASED, {
      groupGiftId,
      itemId: view.itemId,
      initiatorId: userId,
    } satisfies GroupGiftPurchasedEvent);
    return view;
  }

  async fulfill(
    groupGiftId: string,
    userId: string,
    dto: GroupGiftActionDto,
  ): Promise<GroupGiftView> {
    const view = await this.driveHolder(groupGiftId, userId, {
      requireStatus: GroupGiftStatus.PURCHASED,
      toGroupStatus: GroupGiftStatus.FULFILLED,
      holderTo: GiftStatus.FULFILLED,
      note: dto.note ?? null,
    });
    this.emitter.emit(GROUP_GIFT_FULFILLED, {
      groupGiftId,
      itemId: view.itemId,
    } satisfies GroupGiftFulfilledEvent);
    return view;
  }

  /**
   * Cancels a group gift. Frees the item (holder → cancelled) and, if money was
   * collected, routes through `refunding`: every confirmed contribution is
   * marked refunded with an immutable audit reference. Real PSP settlement is a
   * later sprint; here the refund is recorded, not charged back.
   */
  async cancel(
    groupGiftId: string,
    userId: string,
    dto: GroupGiftActionDto,
  ): Promise<GroupGiftView> {
    const gift = await this.loadOrFail(groupGiftId);
    if (gift.initiatorId.toString() !== userId) {
      throw new AppException(ErrorCode.NOT_THE_INITIATOR, 'Only the initiator can cancel', 403);
    }
    if (
      ![GroupGiftStatus.OPEN, GroupGiftStatus.FUNDED, GroupGiftStatus.PURCHASING].includes(
        gift.status,
      )
    ) {
      throw new AppException(
        ErrorCode.INVALID_GROUP_GIFT_TRANSITION,
        `A ${gift.status} group gift cannot be cancelled`,
        409,
      );
    }

    await this.locks.withBestEffortLock(
      `group-gift:${groupGiftId}`,
      async () => {
        const session = await this.connection.startSession();
        try {
          await session.withTransaction(async () => {
            const gg = await this.groupGiftModel.findById(gift._id).session(session).exec();
            if (!gg)
              throw new AppException(ErrorCode.GROUP_GIFT_NOT_FOUND, 'Group gift not found', 404);

            // Free the item.
            await this.status.transitionById(gg.giftId, GiftStatus.CANCELLED, `user:${userId}`, {
              note: dto.note ?? 'group gift cancelled',
              session,
            });

            const now = new Date();
            const hasMoney = gg.collectedAmountMinor > 0;
            if (hasMoney) {
              // Record refunds against every confirmed contribution — the audit trail.
              await this.contributionModel
                .updateMany(
                  { groupGiftId: gg._id, status: ContributionStatus.CONFIRMED },
                  {
                    $set: {
                      status: ContributionStatus.REFUNDED,
                      refundedAt: now,
                      refundRef: `cancel-${gg._id.toString()}`,
                    },
                  },
                  { session },
                )
                .exec();
              this.pushStatus(
                gg,
                GroupGiftStatus.REFUNDING,
                `user:${userId}`,
                'cancelled with contributions',
              );
              this.pushStatus(gg, GroupGiftStatus.CANCELLED, 'system:refunded', 'refunds recorded');
            } else {
              this.pushStatus(gg, GroupGiftStatus.CANCELLED, `user:${userId}`, dto.note ?? null);
            }
            await gg.save({ session });
          });
        } finally {
          await session.endSession();
        }
      },
      { ttlMs: 5_000, retries: 10, retryDelayMs: 40 },
    );

    await this.wishlists.recount(gift.wishlistId);
    const refreshed = await this.loadOrFail(groupGiftId);
    return this.assembleView(refreshed, userId);
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  async get(groupGiftId: string, userId: string): Promise<GroupGiftView> {
    const gift = await this.loadOrFail(groupGiftId);
    // The recipient must not discover a surprise through the group-gift endpoint.
    if (
      gift.recipientId.toString() === userId &&
      gift.visibility === GroupGiftVisibility.HIDDEN_FROM_OWNER
    ) {
      throw new AppException(ErrorCode.GROUP_GIFT_NOT_FOUND, 'Group gift not found', 404);
    }
    // Anyone else needs at least view access to the wishlist.
    if (gift.initiatorId.toString() !== userId) {
      const wishlist = await this.wishlists.findOrFail(gift.wishlistId.toString());
      const decision = await this.access.resolve(wishlist, { userId });
      if (!decision.canView) {
        throw new AppException(ErrorCode.GROUP_GIFT_NOT_FOUND, 'Group gift not found', 404);
      }
    }
    return this.assembleView(gift, userId);
  }

  // ── Share ────────────────────────────────────────────────────────────────────

  async configureShare(
    groupGiftId: string,
    userId: string,
    dto: ShareGroupGiftDto,
  ): Promise<GroupGiftShareView> {
    const gift = await this.loadOrFail(groupGiftId);
    if (gift.initiatorId.toString() !== userId) {
      throw new AppException(
        ErrorCode.NOT_THE_INITIATOR,
        'Only the initiator can manage the link',
        403,
      );
    }
    if (dto.rotate) {
      gift.share.slug = generateSlug();
      gift.share.rotatedAt = new Date();
    }
    if (dto.passcode !== undefined) {
      gift.share.passcodeHash = dto.passcode
        ? AccessPolicyService.hashPasscode(dto.passcode)
        : null;
    }
    if (dto.expiresAt !== undefined) {
      if (dto.expiresAt === null) {
        gift.share.expiresAt = null;
      } else {
        const when = new Date(dto.expiresAt);
        if (when.getTime() <= Date.now()) {
          throw new AppException(ErrorCode.VALIDATION_FAILED, 'Expiry must be in the future', 400);
        }
        gift.share.expiresAt = when;
      }
    }
    await gift.save();
    return {
      slug: gift.share.slug,
      url: `${this.shareBaseUrl}/g/${gift.share.slug}`,
      hasPasscode: gift.share.passcodeHash !== null,
      expiresAt: gift.share.expiresAt,
    };
  }

  /** Resolves a public share link, applying passcode/expiry gates. */
  async getPublicBySlug(slug: string, passcode?: string): Promise<PublicGroupGiftView> {
    const gift = await this.groupGiftModel.findOne({ 'share.slug': slug }).exec();
    if (!gift) throw new AppException(ErrorCode.SHARE_LINK_INVALID, 'Link not found', 404);
    if (gift.share.expiresAt && gift.share.expiresAt.getTime() <= Date.now()) {
      throw new AppException(ErrorCode.SHARE_LINK_EXPIRED, 'This link has expired', 410);
    }
    if (gift.share.passcodeHash) {
      if (!passcode) {
        throw new AppException(
          ErrorCode.SHARE_PASSCODE_REQUIRED,
          'This link needs a passcode',
          401,
        );
      }
      if (!AccessPolicyService.passcodeMatches(passcode, gift.share.passcodeHash)) {
        throw new AppException(ErrorCode.SHARE_PASSCODE_INVALID, 'Incorrect passcode', 403);
      }
    }
    const { users, recentContributions } = await this.resolveViewData(gift);
    return toPublicGroupGiftView({ gift, users, recentContributions });
  }

  /**
   * Open Graph metadata for an unfurler. Ensures the progress card reflects the
   * current total (rendered lazily, content-addressed) so a freshly-posted link
   * shows real progress, not a stale snapshot.
   */
  async getPublicPreview(slug: string, passcode?: string): Promise<OpenGraphPreview> {
    const gift = await this.groupGiftModel.findOne({ 'share.slug': slug }).exec();
    if (!gift) throw new AppException(ErrorCode.SHARE_LINK_INVALID, 'Link not found', 404);
    if (gift.share.expiresAt && gift.share.expiresAt.getTime() <= Date.now()) {
      throw new AppException(ErrorCode.SHARE_LINK_EXPIRED, 'This link has expired', 410);
    }
    if (
      gift.share.passcodeHash &&
      !AccessPolicyService.passcodeMatches(passcode ?? '', gift.share.passcodeHash)
    ) {
      // A preview must not become a passcode oracle: same generic 404 either way.
      throw new AppException(ErrorCode.SHARE_LINK_INVALID, 'Link not found', 404);
    }
    const image = await this.preview.refresh(gift);
    return {
      title: gift.message?.trim() || 'A group gift on Wishtick',
      description: `${gift.collectedAmountMinor} of ${gift.targetAmountMinor} ${gift.currency} raised`,
      image,
      url: `${this.shareBaseUrl}/g/${gift.share.slug}`,
      type: 'website',
      siteName: 'Wishtick',
    };
  }

  // ── Internals ────────────────────────────────────────────────────────────────

  /**
   * Enforces the funding state machine, moving `gift` (a loaded doc) to a new
   * status and appending history. Does not save — the caller does, inside its
   * transaction.
   */
  private pushStatus(
    gift: GroupGiftDocument,
    to: GroupGiftStatus,
    by: string,
    note: string | null,
  ): void {
    if (gift.status === to) return;
    if (!GROUP_GIFT_TRANSITIONS[gift.status].includes(to)) {
      throw new AppException(
        ErrorCode.INVALID_GROUP_GIFT_TRANSITION,
        `A ${gift.status} group gift cannot become ${to}`,
        409,
        { from: gift.status, to, allowed: GROUP_GIFT_TRANSITIONS[gift.status] },
      );
    }
    gift.status = to;
    gift.history.push({ status: to, at: new Date(), by, note });
  }

  private async driveHolder(
    groupGiftId: string,
    userId: string,
    opts: {
      requireStatus: GroupGiftStatus;
      toGroupStatus: GroupGiftStatus;
      holderTo: GiftStatus;
      note: string | null;
    },
  ): Promise<GroupGiftView> {
    const gift = await this.loadOrFail(groupGiftId);
    if (gift.initiatorId.toString() !== userId) {
      throw new AppException(ErrorCode.NOT_THE_INITIATOR, 'Only the initiator can do this', 403);
    }

    await this.locks.withBestEffortLock(
      `group-gift:${groupGiftId}`,
      async () => {
        const session = await this.connection.startSession();
        try {
          await session.withTransaction(async () => {
            const gg = await this.groupGiftModel.findById(gift._id).session(session).exec();
            if (!gg)
              throw new AppException(ErrorCode.GROUP_GIFT_NOT_FOUND, 'Group gift not found', 404);
            if (gg.status !== opts.requireStatus) {
              throw new AppException(
                ErrorCode.INVALID_GROUP_GIFT_TRANSITION,
                `Expected a ${opts.requireStatus} group gift, found ${gg.status}`,
                409,
              );
            }
            await this.status.transitionById(gg.giftId, opts.holderTo, `user:${userId}`, {
              note: opts.note ?? undefined,
              session,
            });
            this.pushStatus(gg, opts.toGroupStatus, `user:${userId}`, opts.note);
            await gg.save({ session });
          });
        } finally {
          await session.endSession();
        }
      },
      { ttlMs: 5_000, retries: 10, retryDelayMs: 40 },
    );

    const refreshed = await this.loadOrFail(groupGiftId);
    return this.assembleView(refreshed, userId);
  }

  private async loadOrFail(groupGiftId: string): Promise<GroupGiftDocument> {
    if (!Types.ObjectId.isValid(groupGiftId)) {
      throw new AppException(ErrorCode.GROUP_GIFT_NOT_FOUND, 'Group gift not found', 404);
    }
    const gift = await this.groupGiftModel.findById(groupGiftId).exec();
    if (!gift) throw new AppException(ErrorCode.GROUP_GIFT_NOT_FOUND, 'Group gift not found', 404);
    return gift;
  }

  /**
   * The gifting authorization, applied to participation: the caller must be able
   * to gift the wishlist, and the owner cannot contribute to their own gift.
   */
  private async authorizeParticipation(gift: GroupGiftDocument, userId: string): Promise<void> {
    if (gift.recipientId.toString() === userId) {
      throw new AppException(
        ErrorCode.CANNOT_GIFT_OWN_ITEM,
        'You cannot contribute to a gift for yourself',
        403,
      );
    }
    const wishlist = await this.wishlists.findOrFail(gift.wishlistId.toString());
    const decision = await this.access.resolve(wishlist, { userId });
    if (!decision.canView) {
      throw new AppException(ErrorCode.GROUP_GIFT_NOT_FOUND, 'Group gift not found', 404);
    }
    if (!decision.canGift) {
      throw new AppException(ErrorCode.FORBIDDEN, 'You cannot gift from this wishlist', 403);
    }
  }

  private parseDeadline(raw?: string): Date | null {
    if (!raw) return null;
    const when = new Date(raw);
    if (Number.isNaN(when.getTime()) || when.getTime() <= Date.now()) {
      throw new AppException(
        ErrorCode.GROUP_GIFT_DEADLINE_INVALID,
        'The deadline must be a valid future date',
        400,
      );
    }
    return when;
  }

  private async resolveViewData(
    gift: GroupGiftDocument,
  ): Promise<{ users: Map<string, UserDocument>; recentContributions: ContributionDocument[] }> {
    const recentContributions = await this.contributionModel
      .find({ groupGiftId: gift._id, status: ContributionStatus.CONFIRMED })
      .sort({ createdAt: -1 })
      .limit(TIMELINE_LIMIT)
      .exec();

    // Resolve only the ids we might name: participants + non-anonymous contributors.
    const ids = new Set<string>(gift.participantIds.map((id) => id.toString()));
    for (const c of recentContributions) {
      if (!c.anonymous) ids.add(c.userId.toString());
    }
    const userDocs = await this.users.findManyByIds([...ids]);
    const users = new Map(userDocs.map((u) => [u._id.toString(), u]));
    return { users, recentContributions };
  }

  private async assembleView(gift: GroupGiftDocument, userId: string): Promise<GroupGiftView> {
    const { users, recentContributions } = await this.resolveViewData(gift);
    const mine = await this.contributionModel
      .aggregate<{ total: number }>([
        {
          $match: {
            groupGiftId: gift._id,
            userId: new Types.ObjectId(userId),
            status: ContributionStatus.CONFIRMED,
          },
        },
        { $group: { _id: null, total: { $sum: '$amountMinor' } } },
      ])
      .exec();
    return toGroupGiftView({
      gift,
      users,
      recentContributions,
      myContributionMinor: mine[0]?.total ?? 0,
      canManage: gift.initiatorId.toString() === userId,
      shareBaseUrl: this.shareBaseUrl,
    });
  }

  private static isDuplicateKey(err: unknown): boolean {
    return (err as { code?: number })?.code === 11000;
  }
}
