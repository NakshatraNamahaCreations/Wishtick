import { api } from './client';
import {
  acquisitionListSchema,
  engagementSchema,
  overviewSchema,
  type AcquisitionRow,
  type Engagement,
  type Overview,
} from './schemas';

/**
 * Typed wrappers over `/admin/analytics`.
 *
 * All three are Redis-cached for 300s server-side with NO invalidation after a
 * rollup, so figures can lag by up to five minutes — including today's. The UI
 * must show an "as of" time rather than implying live data.
 */
export const analyticsApi = {
  /**
   * `GET /admin/analytics/overview` — a SINGLE-DAY snapshot, not a range.
   * The handler uses `to ?? from`, so passing one date is the whole contract.
   */
  overview(date: string | undefined, signal?: AbortSignal): Promise<Overview> {
    return api.get('/admin/analytics/overview', {
      schema: overviewSchema,
      query: { to: date },
      signal,
    });
  },

  /** `GET /admin/analytics/acquisition` — signups per source, `to` inclusive. */
  acquisition(from: string, to: string, signal?: AbortSignal): Promise<AcquisitionRow[]> {
    return api.get('/admin/analytics/acquisition', {
      schema: acquisitionListSchema,
      query: { from, to },
      signal,
    });
  },

  /** `GET /admin/analytics/engagement` — exactly seven counts today. */
  engagement(from: string, to: string, signal?: AbortSignal): Promise<Engagement> {
    return api.get('/admin/analytics/engagement', {
      schema: engagementSchema,
      query: { from, to },
      signal,
    });
  },
};

/** `YYYY-MM-DD` in UTC — the only format the analytics endpoints accept. */
export function utcDay(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function daysAgo(n: number): string {
  return utcDay(new Date(Date.now() - n * 86_400_000));
}
