/**
 * The funding lifecycle of a group gift.
 *
 * This is a *separate* axis from the holder `Gift`'s status (which tracks the
 * item: reserved → purchased → fulfilled). A group gift stays `open` while it
 * collects, `funded` once it hits target, then drives the holder through
 * purchase and fulfilment. The two are related but distinct — one is "how much
 * money have we gathered", the other is "what has happened to the item".
 */
export enum GroupGiftStatus {
  /** Collecting contributions. The only status that accepts new money. */
  OPEN = 'open',
  /** Target reached; contributions closed. Awaiting purchase. */
  FUNDED = 'funded',
  /** The initiator is buying it (transient). */
  PURCHASING = 'purchasing',
  /** Bought — the holder gift is now `purchased` and the item with it. */
  PURCHASED = 'purchased',
  /** Delivered. Terminal success. */
  FULFILLED = 'fulfilled',
  /** Called off before purchase; if money was collected it passed through refunding. */
  CANCELLED = 'cancelled',
  /** Cancelled with contributions outstanding; refund records are being settled. */
  REFUNDING = 'refunding',
}

export enum ContributionStatus {
  /** Reserved for a future payment integration: money promised, not yet captured. */
  PLEDGED = 'pledged',
  /** Money is in. Only confirmed contributions count toward the total. */
  CONFIRMED = 'confirmed',
  /** Returned after a cancellation. Excluded from the collected total. */
  REFUNDED = 'refunded',
}

/**
 * What happens when a contribution would push the total past the target.
 *
 * The plan is explicit that over-target money is never *silently* accepted, so
 * there is no "just take it" option — a group either caps the contribution to
 * the remaining amount (landing exactly on target) or rejects it outright.
 */
export enum OverfundPolicy {
  /** Trim the contribution to the remaining amount so the total lands on target. */
  CAP = 'cap',
  /** Reject any contribution that would exceed the target. */
  REJECT = 'reject',
}

/**
 * Whether the wishlist owner may know this group gift exists — same semantics as
 * a single gift's visibility, so the owner-masking projection is shared.
 */
export enum GroupGiftVisibility {
  HIDDEN_FROM_OWNER = 'hidden_from_owner',
  VISIBLE = 'visible',
}

/**
 * The funding state machine, as an allow-list — read by GroupGiftService and
 * nothing else decides a legal move. Mirrors the GIFT_TRANSITIONS pattern.
 *
 *   open       → funded | cancelled | refunding
 *   funded     → purchasing | purchased | cancelled | refunding
 *   purchasing → purchased | funded            (funded = purchase aborted)
 *   purchased  → fulfilled
 *   refunding  → cancelled                     (once refund records are written)
 *   fulfilled / cancelled → (terminal)
 */
export const GROUP_GIFT_TRANSITIONS: Record<GroupGiftStatus, GroupGiftStatus[]> = {
  [GroupGiftStatus.OPEN]: [
    GroupGiftStatus.FUNDED,
    GroupGiftStatus.CANCELLED,
    GroupGiftStatus.REFUNDING,
  ],
  [GroupGiftStatus.FUNDED]: [
    GroupGiftStatus.PURCHASING,
    GroupGiftStatus.PURCHASED,
    GroupGiftStatus.CANCELLED,
    GroupGiftStatus.REFUNDING,
  ],
  [GroupGiftStatus.PURCHASING]: [GroupGiftStatus.PURCHASED, GroupGiftStatus.FUNDED],
  [GroupGiftStatus.PURCHASED]: [GroupGiftStatus.FULFILLED],
  [GroupGiftStatus.FULFILLED]: [],
  [GroupGiftStatus.CANCELLED]: [],
  [GroupGiftStatus.REFUNDING]: [GroupGiftStatus.CANCELLED],
};

/** A group gift in one of these no longer holds its item (the holder gift is cancelled). */
export const INACTIVE_GROUP_GIFT_STATUSES: GroupGiftStatus[] = [
  GroupGiftStatus.CANCELLED,
  GroupGiftStatus.REFUNDING,
];

/** Statuses in which the group gift still accepts new contributions. */
export const CONTRIBUTABLE_GROUP_GIFT_STATUSES: GroupGiftStatus[] = [GroupGiftStatus.OPEN];
