/**
 * Internal domain events, published on the EventEmitter.
 *
 * They live in `common` so a publisher and a subscriber never have to import
 * each other's module. AuthService emits USER_REGISTERED without knowing that
 * events and wishlists listen for it — which is what lets those modules link
 * their pending invites on signup without auth depending on them (auth is
 * upstream of both, and a direct call would be a cycle).
 */
export const USER_REGISTERED = 'user.registered';

export interface UserRegisteredEvent {
  userId: string;
  email?: string;
  phone?: string;
  /** Acquisition source captured at signup (whatsapp|invite|referral|...). */
  source?: string;
}

/**
 * A group gift reached its target. Emitted the moment `collectedAmount` crosses
 * `targetAmount`, once, from inside the same critical section that recorded the
 * contribution that tipped it over. Sprint 8 (chat) posts a system message and
 * Sprint 9 (notifications) fans out to the participants — both subscribe here
 * rather than coupling to the gifting module.
 */
export const GROUP_GIFT_FUNDED = 'group_gift.funded';

export interface GroupGiftFundedEvent {
  groupGiftId: string;
  itemId: string;
  wishlistId: string;
  initiatorId: string;
  targetAmountMinor: number;
  collectedAmountMinor: number;
  currency: string;
  contributorCount: number;
}

/**
 * A confirmed contribution landed on a group gift. Carries no PII beyond the
 * contributor id (subscribers redact for anonymous ones); Sprint 8 renders it as
 * a "someone chipped in" system message.
 */
export const GROUP_GIFT_CONTRIBUTION_RECEIVED = 'group_gift.contribution_received';

export interface GroupGiftContributionReceivedEvent {
  groupGiftId: string;
  contributionId: string;
  contributorId: string;
  amountMinor: number;
  anonymous: boolean;
  collectedAmountMinor: number;
  targetAmountMinor: number;
}

/**
 * The nightly reconciler found `collectedAmount` disagreeing with the sum of
 * confirmed contributions. This should never fire; when it does it is a data
 * bug, so it is loud on purpose.
 */
export const GROUP_GIFT_DRIFT_DETECTED = 'group_gift.drift_detected';

export interface GroupGiftDriftDetectedEvent {
  groupGiftId: string;
  cachedAmountMinor: number;
  summedAmountMinor: number;
  driftMinor: number;
}

/** Someone joined a group gift as a member. The chat posts a "user joined" note. */
export const GROUP_GIFT_JOINED = 'group_gift.joined';

export interface GroupGiftJoinedEvent {
  groupGiftId: string;
  userId: string;
}

/** A funded group gift was purchased by its initiator. */
export const GROUP_GIFT_PURCHASED = 'group_gift.purchased';

export interface GroupGiftPurchasedEvent {
  groupGiftId: string;
  itemId: string;
  initiatorId: string;
}

/** A group gift was delivered. Terminal success. */
export const GROUP_GIFT_FULFILLED = 'group_gift.fulfilled';

export interface GroupGiftFulfilledEvent {
  groupGiftId: string;
  itemId: string;
}

/**
 * A participant lost access to a wishlist. The chat gateway force-disconnects
 * them from the wishlist's chat so they cannot receive further messages, and the
 * REST history re-checks access so they cannot read past ones.
 */
export const WISHLIST_PARTICIPANT_REVOKED = 'wishlist.participant_revoked';

export interface WishlistParticipantRevokedEvent {
  wishlistId: string;
  userId: string;
}

/**
 * Single-gift lifecycle. Emitted post-commit from GiftingService so Sprint 9
 * notifications can email the right party — the gifter on reserve, the recipient
 * on fulfil (which also kicks off the thank-you note). Each carries every id a
 * subscriber needs so it never has to read back into the gifting module.
 */
export interface GiftLifecycleEvent {
  giftId: string;
  itemId: string;
  gifterId: string;
  recipientId: string;
  wishlistId: string;
}

export const GIFT_RESERVED = 'gift.reserved';
export const GIFT_PURCHASED = 'gift.purchased';
export const GIFT_FULFILLED = 'gift.fulfilled';

/**
 * A time-locked reel finished compiling and is now released to its recipient.
 * Emitted after the collection flips to `released`; Sprint 9 notifications email
 * and in-app the recipient, closing the birthday loop.
 */
export const REEL_RELEASED = 'reel.released';

export interface ReelReleasedEvent {
  reelId: string;
  recipientId: string;
  wishCount: number;
  reelMediaUrl: string | null;
}

/**
 * A time-locked memory capsule opened (`2078:357`). Emitted after the capsule
 * flips to `unlocked`, whether by the scheduled job or by the host opening it
 * early.
 *
 * The audience is the host and the contributors, NOT the recipient: a capsule
 * is made *for* a named person who frequently has no account — that is the
 * whole point of it — so there is nobody else to notify.
 */
export const MEMORY_UNLOCKED = 'memory.unlocked';

export interface MemoryUnlockedEvent {
  capsuleId: string;
  hostId: string;
  contributorIds: string[];
  title: string;
  wishCount: number;
}

/**
 * A user was suspended or force-logged-out by an admin. Their access is already
 * revoked at the guard layer (status + tokensInvalidBefore); the chat gateway
 * additionally drops their live sockets so a websocket cannot outlive the ban.
 */
export const USER_FORCE_DISCONNECT = 'user.force_disconnect';

export interface UserForceDisconnectEvent {
  userId: string;
  reason: string;
}

/**
 * A user reported content, or an auto-flag hook raised it. Promoted here from the
 * chat module's old bare string so the moderation listener and chat share a type.
 */
export const CONTENT_FLAGGED = 'content.flagged';

export interface ContentFlaggedEvent {
  targetType: string;
  targetId: string;
  reason: string;
  senderId: string | null;
}
