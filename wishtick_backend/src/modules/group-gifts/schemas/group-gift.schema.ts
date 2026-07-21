import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, SchemaTypes, Types } from 'mongoose';
import {
  ContributionStatus,
  GroupGiftStatus,
  GroupGiftVisibility,
  OverfundPolicy,
} from '../group-gift.types';

export type GroupGiftDocument = HydratedDocument<GroupGift>;

/**
 * One entry in a group gift's audit trail — the funding-status transitions.
 *
 * Like a single gift's history, this exists because a group gift is
 * money-adjacent: "when did it fund, who started the purchase, when was it
 * cancelled" is the question a support ticket or a refund dispute asks.
 */
@Schema({ _id: false })
export class GroupGiftHistoryEntry {
  @Prop({ type: String, enum: Object.values(GroupGiftStatus), required: true })
  status!: GroupGiftStatus;

  @Prop({ type: Date, required: true })
  at!: Date;

  /** Who or what caused it: a userId, or 'system:funded', 'system:reconcile'. */
  @Prop({ type: String, required: true })
  by!: string;

  @Prop({ type: String, default: null })
  note!: string | null;
}

export const GroupGiftHistoryEntrySchema = SchemaFactory.createForClass(GroupGiftHistoryEntry);

/**
 * The public share link for a group gift — mirrors the wishlist ShareLink so the
 * passcode/expiry semantics are identical. Owned by the group gift, not shared
 * across modules, so the two can diverge without coupling.
 */
@Schema({ _id: false })
export class GroupGiftShareLink {
  @Prop({ type: String, required: true })
  slug!: string;

  /** SHA-256 of the passcode, or null for an open link. */
  @Prop({ type: String, default: null })
  passcodeHash!: string | null;

  @Prop({ type: Date, default: null })
  expiresAt!: Date | null;

  @Prop({ type: Date, default: Date.now })
  rotatedAt!: Date;
}

export const GroupGiftShareLinkSchema = SchemaFactory.createForClass(GroupGiftShareLink);

@Schema({ collection: 'group_gifts', timestamps: true })
export class GroupGift {
  _id!: Types.ObjectId;

  @Prop({ type: SchemaTypes.ObjectId, ref: 'WishlistItem', required: true })
  itemId!: Types.ObjectId;

  /** Denormalized from the item so `/group-gifts` and access checks are one read. */
  @Prop({ type: SchemaTypes.ObjectId, ref: 'Wishlist', required: true })
  wishlistId!: Types.ObjectId;

  /** Who started it and may purchase/cancel it. */
  @Prop({ type: SchemaTypes.ObjectId, ref: 'User', required: true })
  initiatorId!: Types.ObjectId;

  /** The wishlist owner — the recipient. Denormalized for the received view. */
  @Prop({ type: SchemaTypes.ObjectId, ref: 'User', required: true })
  recipientId!: Types.ObjectId;

  /**
   * The holder `Gift` (type = group) that claims the item.
   *
   * The group gift itself does not touch item status — it drives this gift
   * through GiftStatusService, exactly as a single reservation would. The
   * holder's unique `(itemId, active)` index is what makes a group gift and a
   * single reservation mutually exclusive on one item.
   */
  @Prop({ type: SchemaTypes.ObjectId, ref: 'Gift', required: true })
  giftId!: Types.ObjectId;

  /** Integer minor units, consistent with item.price.amountMinor. */
  @Prop({ type: Number, required: true })
  targetAmountMinor!: number;

  /**
   * A denormalized cache of the confirmed-contribution sum.
   *
   * NOT the source of truth — the sum of `confirmed` Contribution docs is. The
   * nightly reconciler re-sums and alerts on any drift. It lives here so
   * progress is one read, and it is only ever mutated by `$inc` inside the
   * contribution transaction so concurrent writers cannot lose an update.
   */
  @Prop({ type: Number, default: 0 })
  collectedAmountMinor!: number;

  @Prop({ type: String, default: 'INR', uppercase: true })
  currency!: string;

  @Prop({ type: Date, default: null })
  deadline!: Date | null;

  @Prop({ type: String, enum: Object.values(GroupGiftStatus), default: GroupGiftStatus.OPEN })
  status!: GroupGiftStatus;

  @Prop({ type: String, enum: Object.values(OverfundPolicy), default: OverfundPolicy.CAP })
  overfundPolicy!: OverfundPolicy;

  @Prop({
    type: String,
    enum: Object.values(GroupGiftVisibility),
    default: GroupGiftVisibility.HIDDEN_FROM_OWNER,
  })
  visibility!: GroupGiftVisibility;

  /**
   * Named members: users who joined or who contributed non-anonymously.
   *
   * An anonymous-only contributor is deliberately NOT here, so no participant
   * projection built from this list can leak them. `contributorCount` still
   * counts them — a headcount is not an identity.
   */
  @Prop({ type: [SchemaTypes.ObjectId], ref: 'User', default: [] })
  participantIds!: Types.ObjectId[];

  /** Distinct confirmed contributors, anonymous included. The "42 people chipped in" stat. */
  @Prop({ type: Number, default: 0 })
  contributorCount!: number;

  /** The group-gift chat (Sprint 8). Null until then. */
  @Prop({ type: SchemaTypes.ObjectId, ref: 'Chat', default: null })
  chatId!: Types.ObjectId | null;

  @Prop({ type: GroupGiftShareLinkSchema, required: true })
  share!: GroupGiftShareLink;

  /** Content-addressed progress-bar OG card, refreshed as the total moves. */
  @Prop({ type: String, default: null })
  ogImageUrl!: string | null;

  /** The initiator's pitch, shown on the share card. */
  @Prop({ type: String, default: null, maxlength: 280 })
  message!: string | null;

  @Prop({ type: [GroupGiftHistoryEntrySchema], default: [] })
  history!: GroupGiftHistoryEntry[];

  createdAt!: Date;
  updatedAt!: Date;
}

export const GroupGiftSchema = SchemaFactory.createForClass(GroupGift);

// Public share lookups resolve by slug; unique so a slug maps to one group gift.
GroupGiftSchema.index({ 'share.slug': 1 }, { unique: true });
// One item's group gift, and the initiator's / recipient's lists.
GroupGiftSchema.index({ itemId: 1 });
GroupGiftSchema.index({ initiatorId: 1, createdAt: -1 });
GroupGiftSchema.index({ recipientId: 1, createdAt: -1 });
// Deadline sweeps (a later sprint) and status filters.
GroupGiftSchema.index({ status: 1, deadline: 1 });

/** Which contribution statuses count toward the collected total — the reconciler's filter. */
export const COUNTED_CONTRIBUTION_STATUSES = [ContributionStatus.CONFIRMED];
