import type { UserDocument } from 'src/modules/users/schemas/user.schema';
import type { ContributionDocument } from './schemas/contribution.schema';
import type { GroupGiftDocument } from './schemas/group-gift.schema';

/** A named member of the group gift. Anonymous contributors never appear here. */
export interface ParticipantView {
  userId: string;
  name: string;
}

/** One contribution on the timeline. `contributor` is null when it was anonymous. */
export interface ContributionView {
  id: string;
  amountMinor: number;
  message: string | null;
  anonymous: boolean;
  createdAt: Date;
  contributor: ParticipantView | null;
}

export interface GroupGiftShareView {
  slug: string;
  url: string;
  hasPasscode: boolean;
  expiresAt: Date | null;
}

/** A non-item cost folded into the group's total (`4007:568`). */
export interface GroupGiftChargeView {
  id: string;
  label: string;
  amountMinor: number;
  addedBy: string;
  addedAt: Date;
}

/** An additional item beyond the primary one (`4007:720`). */
export interface GroupGiftLineView {
  id: string;
  itemId: string;
  amountMinor: number | null;
  addedAt: Date;
}

export interface GroupGiftView {
  id: string;
  itemId: string;
  wishlistId: string;
  status: string;
  /** The host's name for it, e.g. "Siya's birthday gift". */
  title: string;
  /** Where members send their share. Wishtick never holds the money. */
  hostUpiId: string | null;
  contributionMode: string;
  /** The chips the host offers on the contribute sheet. Minor units. */
  suggestedAmountsMinor: number[];
  /** The Grand Total: every gift plus every charge. What the group collects. */
  targetAmountMinor: number;
  /** The charges' share of the target, so the summary need not re-add them. */
  chargesTotalMinor: number;
  charges: GroupGiftChargeView[];
  lines: GroupGiftLineView[];
  collectedAmountMinor: number;
  currency: string;
  percentFunded: number;
  contributorCount: number;
  participantCount: number;
  deadline: Date | null;
  overfundPolicy: string;
  visibility: string;
  message: string | null;
  ogImageUrl: string | null;
  chatId: string | null;
  createdAt: Date;
  participants: ParticipantView[];
  recentContributions: ContributionView[];
  myContributionMinor: number;
  /** Present only for the initiator/manager. */
  share?: GroupGiftShareView;
}

/** The redacted public share view — no owner PII, no wishlist internals. */
export interface PublicGroupGiftView {
  status: string;
  targetAmountMinor: number;
  collectedAmountMinor: number;
  currency: string;
  percentFunded: number;
  contributorCount: number;
  deadline: Date | null;
  message: string | null;
  ogImageUrl: string | null;
  participants: ParticipantView[];
  recentContributions: ContributionView[];
}

const displayName = (user: UserDocument | undefined): string => user?.name?.trim() || 'A friend';

/** Clamp to [0,100]; a capped over-target group never shows more than 100%. */
const percent = (collected: number, target: number): number =>
  target <= 0 ? 0 : Math.min(100, Math.round((collected / target) * 100));

/**
 * Builds a contribution timeline entry, withholding the contributor's identity
 * when the contribution was anonymous. This is the single place that decides
 * whether a name is revealed, so no projection can accidentally leak one.
 */
const toContributionView = (
  c: ContributionDocument,
  users: Map<string, UserDocument>,
): ContributionView => ({
  id: c._id.toString(),
  amountMinor: c.amountMinor,
  message: c.message,
  anonymous: c.anonymous,
  createdAt: c.createdAt,
  contributor: c.anonymous
    ? null
    : { userId: c.userId.toString(), name: displayName(users.get(c.userId.toString())) },
});

const toParticipants = (
  gift: GroupGiftDocument,
  users: Map<string, UserDocument>,
): ParticipantView[] =>
  gift.participantIds.map((id) => ({
    userId: id.toString(),
    name: displayName(users.get(id.toString())),
  }));

export function toGroupGiftView(input: {
  gift: GroupGiftDocument;
  users: Map<string, UserDocument>;
  recentContributions: ContributionDocument[];
  myContributionMinor: number;
  canManage: boolean;
  shareBaseUrl: string;
}): GroupGiftView {
  const { gift, users, recentContributions, myContributionMinor, canManage, shareBaseUrl } = input;
  const view: GroupGiftView = {
    id: gift._id.toString(),
    itemId: gift.itemId.toString(),
    wishlistId: gift.wishlistId.toString(),
    status: gift.status,
    title: gift.title,
    hostUpiId: gift.hostUpiId,
    contributionMode: gift.contributionMode,
    suggestedAmountsMinor: gift.suggestedAmountsMinor,
    // The Grand Total off the summary screen. Charges are agreed before the
    // first contribution, so this *is* the target rather than something on top
    // of it — see GroupGiftService.recomputeTarget.
    targetAmountMinor: gift.targetAmountMinor,
    chargesTotalMinor: gift.charges.reduce((sum, charge) => sum + charge.amountMinor, 0),
    charges: gift.charges.map((charge) => ({
      id: charge._id.toString(),
      label: charge.label,
      amountMinor: charge.amountMinor,
      addedBy: charge.addedBy.toString(),
      addedAt: charge.addedAt,
    })),
    lines: gift.lines.map((line) => ({
      id: line._id.toString(),
      itemId: line.itemId.toString(),
      amountMinor: line.amountMinor,
      addedAt: line.addedAt,
    })),
    collectedAmountMinor: gift.collectedAmountMinor,
    currency: gift.currency,
    // Progress stays measured against the *target* the group set, not the true
    // cost: a charge added at checkout must not make an already-full bar look
    // like it went backwards. The shortfall shows up in the balance instead.
    percentFunded: percent(gift.collectedAmountMinor, gift.targetAmountMinor),
    contributorCount: gift.contributorCount,
    participantCount: gift.participantIds.length,
    deadline: gift.deadline,
    overfundPolicy: gift.overfundPolicy,
    visibility: gift.visibility,
    message: gift.message,
    ogImageUrl: gift.ogImageUrl,
    chatId: gift.chatId ? gift.chatId.toString() : null,
    createdAt: gift.createdAt,
    participants: toParticipants(gift, users),
    recentContributions: recentContributions.map((c) => toContributionView(c, users)),
    myContributionMinor,
  };
  if (canManage) {
    view.share = {
      slug: gift.share.slug,
      url: `${shareBaseUrl}/g/${gift.share.slug}`,
      hasPasscode: gift.share.passcodeHash !== null,
      expiresAt: gift.share.expiresAt,
    };
  }
  return view;
}

export function toPublicGroupGiftView(input: {
  gift: GroupGiftDocument;
  users: Map<string, UserDocument>;
  recentContributions: ContributionDocument[];
}): PublicGroupGiftView {
  const { gift, users, recentContributions } = input;
  return {
    status: gift.status,
    targetAmountMinor: gift.targetAmountMinor,
    collectedAmountMinor: gift.collectedAmountMinor,
    currency: gift.currency,
    percentFunded: percent(gift.collectedAmountMinor, gift.targetAmountMinor),
    contributorCount: gift.contributorCount,
    deadline: gift.deadline,
    message: gift.message,
    ogImageUrl: gift.ogImageUrl,
    participants: toParticipants(gift, users),
    recentContributions: recentContributions.map((c) => toContributionView(c, users)),
  };
}
