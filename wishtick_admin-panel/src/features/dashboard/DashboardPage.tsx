import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { Icon } from '@/components/Icon';
import { LoadingState, Panel, Pill, QueryError } from '@/components/ui';
import { useAuth } from '@/features/auth/use-auth';
import { analyticsApi, daysAgo } from '@/lib/api/analytics';
import { moderationApi } from '@/lib/api/moderation';

/**
 * Landing screen.
 *
 * Metrics are real now that Sprint 4 wired the analytics endpoints. It reads
 * yesterday's bucket rather than today's, because the rollup lags and today is
 * routinely the emptiest day — defaulting there makes a working dashboard look
 * broken on every morning load.
 */
export function DashboardPage() {
  const { admin, can } = useAuth();
  const firstName = admin?.name?.split(/\s+/)[0] ?? 'there';
  const snapshot = daysAgo(1);

  const today = new Date().toLocaleDateString(undefined, {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  const overviewQuery = useQuery({
    queryKey: ['analytics-overview', snapshot],
    queryFn: ({ signal }) => analyticsApi.overview(snapshot, signal),
    enabled: can('analytics:view'),
  });

  const queueQuery = useQuery({
    queryKey: ['moderation-queue', { status: 'open', type: '', page: 1 }],
    queryFn: ({ signal }) => moderationApi.queue({ status: 'open', limit: 1 }, signal),
    enabled: can('moderation:view'),
  });

  const overview = overviewQuery.data;
  const allZero =
    overview !== undefined && overview.dau === 0 && overview.wau === 0 && overview.mau === 0;

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-5">
        <div>
          <p className="mb-1 text-[13.5px] text-muted">{today}</p>
          <h1 className="font-display text-[30px] font-bold tracking-tight text-balance">
            Welcome back, {firstName}
          </h1>
        </div>
      </div>

      {/* ── What needs attention, before what merely happened ── */}
      {can('moderation:view') && (
        <Panel
          title="Needs attention"
          action={
            <Link
              to="/moderation"
              className="inline-flex items-center gap-1.5 rounded-pill border border-hairline px-4 py-2 text-sm font-semibold text-accent-text transition-colors hover:border-accent"
            >
              Open queue
              <Icon name="chevronRight" className="h-4 w-4" />
            </Link>
          }
        >
          <div className="mt-4">
            {queueQuery.isPending ? (
              <LoadingState />
            ) : queueQuery.isError ? (
              <QueryError context="Could not load the moderation queue." error={queueQuery.error} />
            ) : queueQuery.data.total === 0 ? (
              <p className="text-sm text-muted">
                Nothing waiting for review. New reports appear here automatically.
              </p>
            ) : (
              <p className="text-sm">
                <b className="tnum font-display text-2xl font-bold">{queueQuery.data.total}</b>{' '}
                <span className="text-muted">
                  open {queueQuery.data.total === 1 ? 'report' : 'reports'} waiting for review.
                </span>
              </p>
            )}
          </div>
        </Panel>
      )}

      {/* ── Platform metrics ── */}
      {can('analytics:view') && (
        <Panel
          title="Platform metrics"
          subtitle={`Active users for ${snapshot} (UTC)`}
          action={
            <Link
              to="/analytics"
              className="inline-flex items-center gap-1.5 rounded-pill border border-hairline px-4 py-2 text-sm font-semibold text-accent-text transition-colors hover:border-accent"
            >
              Full analytics
              <Icon name="chevronRight" className="h-4 w-4" />
            </Link>
          }
        >
          {overviewQuery.isPending ? (
            <LoadingState />
          ) : overviewQuery.isError ? (
            <div className="mt-4">
              <QueryError context="Could not load platform metrics." error={overviewQuery.error} />
            </div>
          ) : (
            <>
              <div className="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
                <StatTile label="Daily active" value={overview?.dau ?? 0} />
                <StatTile label="Weekly active" value={overview?.wau ?? 0} />
                <StatTile label="Monthly active" value={overview?.mau ?? 0} />
                <StatTile label="Total users" value={overview?.totalUsers ?? 0} live />
              </div>

              {allZero && (
                <p className="mt-4 flex items-start gap-2.5 rounded-nav bg-warn-wash px-4 py-3 text-xs leading-relaxed text-warn">
                  <Icon name="clock" className="mt-px h-4 w-4 shrink-0" />
                  <span>
                    <b className="font-bold">Every active-user figure is zero.</b> A rollup that
                    never ran and a genuinely quiet day both read as{' '}
                    <code className="font-mono">0</code> — check the analytics-rollup job before
                    treating this as real.
                  </span>
                </p>
              )}
            </>
          )}
        </Panel>
      )}

      {/* ── Access ── */}
      <Panel title="Your access" subtitle="Recomputed by the server on every request">
        <div className="mt-4 flex flex-col gap-4">
          <div>
            <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-muted-soft">
              Roles
            </p>
            <div className="flex flex-wrap gap-2">
              {admin?.roles.map((role) => (
                <Pill key={role} tone="info">
                  {role.replace(/_/g, ' ')}
                </Pill>
              ))}
            </div>
          </div>

          <div>
            <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-muted-soft">
              Permissions
            </p>
            <div className="flex flex-wrap gap-2">
              {admin?.permissions.map((permission) => (
                <Pill key={permission}>{permission}</Pill>
              ))}
            </div>
          </div>

          <div className="flex flex-wrap gap-2 border-t border-hairline pt-4">
            <Pill tone={admin?.totpEnabled ? 'good' : 'crit'}>
              {admin?.totpEnabled ? 'Two-factor enabled' : 'Two-factor not set up'}
            </Pill>
            {admin?.ipAllowlist.length ? (
              <Pill tone="warn">IP allowlist active ({admin.ipAllowlist.length})</Pill>
            ) : null}
          </div>
        </div>
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
