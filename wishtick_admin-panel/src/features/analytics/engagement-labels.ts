/** Labels and ordering for the engagement metrics. */

/**
 * The seven keys the endpoint actually returns, in a deliberate reading order:
 * creation first, then the outcomes those creations lead to.
 */
export const ENGAGEMENT_ORDER = [
  'wishlistsCreated',
  'giftsCreated',
  'giftsFulfilled',
  'eventsCreated',
  'groupGiftsCreated',
  'reelsCreated',
  'reelsReleased',
] as const;

export const ENGAGEMENT_LABELS: Record<string, string> = {
  wishlistsCreated: 'Wishlists created',
  giftsCreated: 'Gifts created',
  giftsFulfilled: 'Gifts fulfilled',
  eventsCreated: 'Events created',
  groupGiftsCreated: 'Group gifts created',
  reelsCreated: 'Reels created',
  reelsReleased: 'Reels released',
};

/**
 * In the spec, absent from the API. Listed so the dashboard can say what is
 * missing instead of presenting seven metrics as the complete picture.
 */
export const MISSING_ENGAGEMENT_METRICS = [
  'Invites created',
  'Items added',
  'Items fulfilled',
  'Public vs private wishlist usage',
  'Wishlist chat activity',
  'Group-gift chat activity',
  'Gifts reserved / purchased (separately)',
  'Offline gifts completed',
  'Reels submitted / shared',
];

/**
 * Known keys first in reading order, then anything the backend adds later —
 * so a new metric shows up rather than being silently dropped.
 */
export function orderEngagement(engagement: Record<string, number>): [string, number][] {
  const known = ENGAGEMENT_ORDER.filter((key) => key in engagement).map(
    (key) => [key, engagement[key] ?? 0] as [string, number],
  );
  const extra = Object.entries(engagement).filter(
    (entry) => !(ENGAGEMENT_ORDER as readonly string[]).includes(entry[0]),
  );
  return [...known, ...extra];
}
