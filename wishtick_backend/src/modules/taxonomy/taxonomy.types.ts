/**
 * Every user-selectable option in onboarding is a taxonomy row, not a client
 * constant. Adding an interest must not require an app release, and analytics
 * (Sprint 11) needs a stable key to group by rather than free text.
 */
export enum TaxonomyKind {
  INTEREST = 'interest',
  COLOR = 'color',
  CLOTHING_SIZE = 'clothing_size',
  SHOE_SIZE = 'shoe_size',
  GIFT_CATEGORY = 'gift_category',
  LIFESTYLE = 'lifestyle',
  OCCASION = 'occasion',
  EVENT_TYPE = 'event_type',
}

export interface TaxonomyOption {
  key: string;
  label: string;
  /** Colors carry `hex`; sizes carry `system`. Kind-specific and optional. */
  meta?: Record<string, string>;
}

/** Shape of GET /onboarding/options. */
export type TaxonomyOptions = Record<TaxonomyKind, TaxonomyOption[]>;
