/**
 * Provider-neutral product shape.
 *
 * Every adapter normalizes into this, so the rest of the app never learns which
 * affiliate network a product came from. That is what makes swapping or adding
 * a network a change confined to one file.
 */
export interface NormalizedProduct {
  provider: string;
  /** The provider's own id. Unique only within that provider. */
  externalId: string;
  title: string;
  description: string | null;
  imageUrls: string[];
  /** The merchant's page. */
  productUrl: string;
  /** The monetized link, when the network gives us one. */
  affiliateUrl: string | null;
  /** Minor units. Never a float — see the note on ItemPrice. */
  amountMinor: number | null;
  currency: string;
  merchant: string | null;
  /** Our gift-category taxonomy key, mapped from the provider's own category. */
  category: string | null;
  inStock: boolean;
  /** Anything network-specific worth keeping for reconciliation or payouts. */
  affiliateMeta: Record<string, unknown>;
}

export interface ProductSearchQuery {
  q?: string;
  category?: string;
  minPriceMinor?: number;
  maxPriceMinor?: number;
  page: number;
  pageSize: number;
}

export interface ProductSearchResult {
  items: NormalizedProduct[];
  page: number;
  pageSize: number;
  /** Providers rarely give an exact count; null means "unknown", not zero. */
  totalEstimate: number | null;
  hasMore: boolean;
}

export interface ProviderCategory {
  key: string;
  label: string;
}

/** How a search response reached the caller. Surfaced so clients can say so. */
export enum ResultFreshness {
  /** Straight from the provider. */
  LIVE = 'live',
  /** Cached and still inside the fresh window. */
  CACHED = 'cached',
  /**
   * Cached, past the fresh window, served because the provider is unavailable.
   * The alternative is a 5xx, and a slightly old price beats a broken page.
   */
  STALE = 'stale',
}
