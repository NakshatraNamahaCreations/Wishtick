import { useQueries } from '@tanstack/react-query';
import { useState } from 'react';
import { BarChart, MetricBars, type BarDatum } from '@/components/Charts';
import { Icon } from '@/components/Icon';
import { Button, LoadingState, Panel, QueryError } from '@/components/ui';
import { analyticsApi, daysAgo, utcDay } from '@/lib/api/analytics';
import { downloadCsv } from './csv';
import {
  ENGAGEMENT_LABELS,
  MISSING_ENGAGEMENT_METRICS,
  orderEngagement,
} from './engagement-labels';

/** The rollup lags, so "today" is often the emptiest day. Default to yesterday. */
const DEFAULT_SNAPSHOT = daysAgo(1);

export function AnalyticsPage() {
  const [snapshotDate, setSnapshotDate] = useState(DEFAULT_SNAPSHOT);
  const [from, setFrom] = useState(daysAgo(30));
  const [to, setTo] = useState(utcDay(new Date()));
  const [fetchedAt, setFetchedAt] = useState<Date>(() => new Date());

  const [overviewQuery, acquisitionQuery, engagementQuery] = useQueries({
    queries: [
      {
        queryKey: ['analytics-overview', snapshotDate],
        queryFn: ({ signal }: { signal: AbortSignal }) =>
          analyticsApi.overview(snapshotDate, signal),
      },
      {
        queryKey: ['analytics-acquisition', from, to],
        queryFn: ({ signal }: { signal: AbortSignal }) =>
          analyticsApi.acquisition(from, to, signal),
      },
      {
        queryKey: ['analytics-engagement', from, to],
        queryFn: ({ signal }: { signal: AbortSignal }) =>
          analyticsApi.engagement(from, to, signal),
      },
    ],
  });

  async function refreshAll() {
    await Promise.all([
      overviewQuery.refetch(),
      acquisitionQuery.refetch(),
      engagementQuery.refetch(),
    ]);
    setFetchedAt(new Date());
  }

  const overview = overviewQuery.data;
  const acquisition = acquisitionQuery.data ?? [];
  const engagement = engagementQuery.data ?? {};

  const engagementRows: BarDatum[] = orderEngagement(engagement).map(([key, value]) => ({
    label: ENGAGEMENT_LABELS[key] ?? key,
    value,
  }));

  const acquisitionRows: BarDatum[] = acquisition.map((row) => ({
    label: row.source.replace(/_/g, ' '),
    value: row.signups,
  }));

  // A rollup that never ran and a genuinely quiet day are indistinguishable on
  // the wire — both read as 0. Say so rather than presenting zeros as fact.
  const overviewAllZero =
    overview !== undefined && overview.dau === 0 && overview.wau === 0 && overview.mau === 0;
  const acquisitionEmpty = acquisitionQuery.isSuccess && acquisition.length === 0;

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-[27px] font-bold tracking-tight">Analytics</h1>
          <p className="mt-1 text-sm text-muted">
            All dates are <b className="text-ink">UTC</b>. Figures come from the nightly rollup,
            not live counters.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <span className="inline-flex items-center gap-2 rounded-pill border border-hairline px-4 py-2 text-xs text-muted">
            <Icon name="clock" className="h-4 w-4" />
            As of{' '}
            <b className="tnum font-semibold text-ink">
              {fetchedAt.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })}
            </b>
          </span>
          <Button variant="ghost" onClick={() => void refreshAll()}>
            Refresh
          </Button>
        </div>
      </div>

      {/* Server-side Redis cache with no invalidation after a rollup. */}
      <p className="rounded-nav bg-info-wash px-4 py-3 text-xs leading-relaxed text-info">
        These figures are cached for <b className="font-semibold">5 minutes</b> on the server and
        are not invalidated when a rollup runs — a refresh may return the same numbers until the
        cache expires.
      </p>

      {/* ── Overview: a single-day snapshot, not a range ── */}
      <Panel
        title="Platform overview"
        subtitle="A single day — the endpoint returns one bucket, not a range"
        action={
          <label className="flex items-center gap-2 text-xs text-muted">
            <span className="sr-only sm:not-sr-only">Snapshot day</span>
            <input
              type="date"
              value={snapshotDate}
              max={utcDay(new Date())}
              onChange={(event) => setSnapshotDate(event.target.value)}
              aria-label="Snapshot day"
              className="min-h-[44px] rounded-pill border border-field bg-surface px-4 text-sm text-ink focus:outline-none focus-visible:border-accent sm:min-h-0 sm:py-2"
            />
          </label>
        }
      >
        {overviewQuery.isPending ? (
          <LoadingState />
        ) : overviewQuery.isError ? (
          <div className="mt-4">
            <QueryError context="Could not load the overview." error={overviewQuery.error} />
          </div>
        ) : (
          <>
            <div className="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
              <StatTile label="Daily active" value={overview?.dau ?? 0} />
              <StatTile label="Weekly active" value={overview?.wau ?? 0} />
              <StatTile label="Monthly active" value={overview?.mau ?? 0} />
              <StatTile label="Total users" value={overview?.totalUsers ?? 0} live />
            </div>

            {overviewAllZero && (
              <p className="mt-4 flex items-start gap-2.5 rounded-nav bg-warn-wash px-4 py-3 text-xs leading-relaxed text-warn">
                <Icon name="clock" className="mt-px h-4 w-4 shrink-0" />
                <span>
                  <b className="font-bold">Every active-user figure is zero for this day.</b> The
                  API cannot distinguish &ldquo;the rollup did not run&rdquo; from &ldquo;nobody
                  was active&rdquo; — a missing metric reads as <code className="font-mono">0</code>
                  . Check that the analytics-rollup job ran for {snapshotDate} before treating this
                  as real.
                </span>
              </p>
            )}

            <p className="mt-4 text-xs leading-relaxed text-muted">
              Active-user counts come from the rollup for {snapshotDate}.{' '}
              <b className="text-ink">Total users</b> is a live count of non-deleted accounts, so
              it does not move with the snapshot date.
            </p>
          </>
        )}
      </Panel>

      {/* ── Range control, shared by the two range endpoints ── */}
      <Panel title="Date range" subtitle="Applies to acquisition and engagement. End date inclusive.">
        <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-end">
          <label className="flex flex-1 flex-col gap-1.5">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted-soft">
              From
            </span>
            <input
              type="date"
              value={from}
              max={to}
              onChange={(event) => setFrom(event.target.value)}
              className="min-h-[44px] rounded-nav border border-field bg-surface px-4 text-sm text-ink focus:outline-none focus-visible:border-accent"
            />
          </label>
          <label className="flex flex-1 flex-col gap-1.5">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted-soft">
              To
            </span>
            <input
              type="date"
              value={to}
              min={from}
              max={utcDay(new Date())}
              onChange={(event) => setTo(event.target.value)}
              className="min-h-[44px] rounded-nav border border-field bg-surface px-4 text-sm text-ink focus:outline-none focus-visible:border-accent"
            />
          </label>
          <div className="flex gap-2">
            {[7, 30, 90].map((days) => (
              <button
                key={days}
                type="button"
                onClick={() => {
                  setFrom(daysAgo(days));
                  setTo(utcDay(new Date()));
                }}
                className="min-h-[44px] rounded-pill border border-hairline px-4 text-sm font-semibold transition-colors hover:border-accent hover:text-accent-text sm:min-h-0 sm:py-2"
              >
                {days}d
              </button>
            ))}
          </div>
        </div>
      </Panel>

      {/* ── Acquisition ── */}
      <Panel
        title="Acquisition"
        subtitle={`Signups by source · ${from} → ${to}`}
        action={
          <Button
            variant="ghost"
            onClick={() =>
              downloadCsv(
                `acquisition-${from}-to-${to}.csv`,
                ['source', 'signups'],
                acquisition.map((row) => [row.source, row.signups]),
              )
            }
            disabled={acquisition.length === 0}
          >
            Export CSV
          </Button>
        }
      >
        <div className="mt-5">
          {acquisitionQuery.isPending ? (
            <LoadingState />
          ) : acquisitionQuery.isError ? (
            <QueryError context="Could not load acquisition data." error={acquisitionQuery.error} />
          ) : (
            <>
              <BarChart data={acquisitionRows} emptyLabel="No signups recorded in this range" />
              {acquisitionEmpty && (
                <p className="mt-4 rounded-nav bg-warn-wash px-4 py-3 text-xs leading-relaxed text-warn">
                  <b className="font-bold">No rows at all</b> — an empty result, not zeros. Three
                  things produce this and the API cannot tell them apart: nobody signed up in this
                  range, attribution was never rolled up for these days, or{' '}
                  <b className="font-bold">a stale 5-minute cache entry</b> is being served from
                  before the rollup ran. If a rollup just completed, wait for the cache to expire
                  before trusting an empty result.
                </p>
              )}
            </>
          )}
        </div>
      </Panel>

      {/* ── Engagement ── */}
      <Panel
        title="Engagement"
        subtitle={`${from} → ${to}`}
        action={
          <Button
            variant="ghost"
            onClick={() =>
              downloadCsv(
                `engagement-${from}-to-${to}.csv`,
                ['metric', 'value'],
                orderEngagement(engagement).map(([key, value]) => [
                  ENGAGEMENT_LABELS[key] ?? key,
                  value,
                ]),
              )
            }
            disabled={engagementRows.length === 0}
          >
            Export CSV
          </Button>
        }
      >
        <div className="mt-5">
          {engagementQuery.isPending ? (
            <LoadingState />
          ) : engagementQuery.isError ? (
            <QueryError context="Could not load engagement data." error={engagementQuery.error} />
          ) : engagementRows.length === 0 ? (
            <p className="py-8 text-center text-sm text-muted">No engagement data in range.</p>
          ) : (
            <MetricBars data={engagementRows} />
          )}
        </div>

        {/*
          The product spec lists roughly fifteen engagement metrics; the endpoint
          returns seven. Naming the absent ones is more useful than silently
          showing a shorter list that reads as complete.
        */}
        <details className="mt-5 rounded-nav bg-surface-2 px-4 py-3">
          <summary className="cursor-pointer text-xs font-semibold text-muted">
            Why are there only {engagementRows.length} metrics?
          </summary>
          <p className="mt-2 text-xs leading-relaxed text-muted">
            These are every metric the endpoint returns. The following are in the product spec but
            have no backing data yet — they need backend work, not a UI change:
          </p>
          <ul className="mt-2 flex flex-wrap gap-1.5">
            {MISSING_ENGAGEMENT_METRICS.map((metric) => (
              <li
                key={metric}
                className="rounded-pill bg-surface px-2.5 py-1 text-[11px] text-muted-soft"
              >
                {metric}
              </li>
            ))}
          </ul>
        </details>
      </Panel>
    </>
  );
}

function StatTile({ label, value, live = false }: { label: string; value: number; live?: boolean }) {
  return (
    <div className="rounded-card border border-hairline bg-surface-2 px-4 py-4">
      <p className="tnum font-display text-2xl font-bold tracking-tight">
        {value.toLocaleString()}
      </p>
      <p className="mt-1 text-xs text-muted">{label}</p>
      {live && <p className="mt-0.5 text-[10px] uppercase tracking-wide text-muted-soft">Live</p>}
    </div>
  );
}
