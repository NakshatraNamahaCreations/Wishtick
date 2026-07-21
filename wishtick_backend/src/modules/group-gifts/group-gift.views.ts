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

export interface GroupGiftView {
  id: string;
  itemId: string;
  wishlistId: string;
  status: string;
  targetAmountMinor: number;
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
    targetAmountMinor: gift.targetAmountMinor,
    collectedAmountMinor: gift.collectedAmountMinor,
    currency: gift.currency,
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
