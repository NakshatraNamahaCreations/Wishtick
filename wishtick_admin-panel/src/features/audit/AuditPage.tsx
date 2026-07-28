import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'react-router-dom';
import { Pagination } from '@/components/DataTable';
import { Icon } from '@/components/Icon';
import { LoadingState, Panel, Pill, QueryError } from '@/components/ui';
import { auditApi } from '@/lib/api/admins';
import type { AuditEntry } from '@/lib/api/schemas';
import { daysAgo, utcDay } from '@/lib/api/analytics';
import { formatDateTime, relativeTime } from '@/features/users/user-format';

const LIMIT = 25;

/** Colour by blast radius, not by domain — a suspension is not a role change. */
function actionTone(action: string): 'crit' | 'warn' | 'good' | 'info' | 'neutral' {
  if (action.includes('suspend') || action.includes('remove')) return 'crit';
  if (action.includes('password') || action.includes('force_logout')) return 'warn';
  if (action.includes('reactivate') || action.includes('approve')) return 'good';
  if (action.includes('create') || action.includes('update')) return 'info';
  return 'neutral';
}

export function AuditPage() {
  const [params, setParams] = useSearchParams();

  const action = params.get('action') ?? '';
  const targetType = params.get('targetType') ?? '';
  const targetId = params.get('targetId') ?? '';
  const from = params.get('from') ?? daysAgo(30);
  const to = params.get('to') ?? utcDay(new Date());
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);

  const actionsQuery = useQuery({
    queryKey: ['audit-actions'],
    queryFn: ({ signal }) => auditApi.actions(signal),
    staleTime: 5 * 60_000,
  });

  const query = useQuery({
    queryKey: ['audit', { action, targetType, targetId, from, to, page }],
    queryFn: ({ signal }) =>
      auditApi.list({ action, targetType, targetId, from, to, page, limit: LIMIT }, signal),
    placeholderData: keepPreviousData,
  });

  function updateParam(key: string, value: string) {
    setParams((current) => {
      const next = new URLSearchParams(current);
      if (value) next.set(key, value);
      else next.delete(key);
      if (key !== 'page') next.delete('page');
      return next;
    });
  }

  const filtered = Boolean(action || targetType || targetId);

  return (
    <>
      <div>
        <h1 className="font-display text-[27px] font-bold tracking-tight">Audit log</h1>
        <p className="mt-1 text-sm text-muted">
          Every admin action, newest first. Append-only — nothing here can be edited or deleted.
        </p>
      </div>

      <Panel title="Filters">
        <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <label className="flex flex-col gap-1.5">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted-soft">
              Action
            </span>
            <select
              value={action}
              onChange={(event) => updateParam('action', event.target.value)}
              className="min-h-[44px] rounded-nav border border-field bg-surface px-3 text-sm text-ink focus:outline-none focus-visible:border-accent"
            >
              <option value="">All actions</option>
              {(actionsQuery.data ?? []).map((name) => (
                <option key={name} value={name}>
                  {name}
                </option>
              ))}
            </select>
          </label>

          <label className="flex flex-col gap-1.5">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted-soft">
              Target type
            </span>
            <select
              value={targetType}
              onChange={(event) => updateParam('targetType', event.target.value)}
              className="min-h-[44px] rounded-nav border border-field bg-surface px-3 text-sm text-ink focus:outline-none focus-visible:border-accent"
            >
              <option value="">All types</option>
              {['user', 'admin', 'report', 'wishlist', 'event', 'message'].map((type) => (
                <option key={type} value={type}>
                  {type}
                </option>
              ))}
            </select>
          </label>

          <label className="flex flex-col gap-1.5">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted-soft">
              From
            </span>
            <input
              type="date"
              value={from}
              max={to}
              onChange={(event) => updateParam('from', event.target.value)}
              className="min-h-[44px] rounded-nav border border-field bg-surface px-3 text-sm text-ink focus:outline-none focus-visible:border-accent"
            />
          </label>

          <label className="flex flex-col gap-1.5">
            <span className="text-xs font-semibold uppercase tracking-wider text-muted-soft">
              To
            </span>
            <input
              type="date"
              value={to}
              min={from}
              max={utcDay(new Date())}
              onChange={(event) => updateParam('to', event.target.value)}
              className="min-h-[44px] rounded-nav border border-field bg-surface px-3 text-sm text-ink focus:outline-none focus-visible:border-accent"
            />
          </label>
        </div>

        {targetId && (
          <div className="mt-3 flex flex-wrap items-center gap-2 rounded-nav bg-accent-wash px-4 py-2.5">
            <span className="text-xs text-accent-text">
              Filtered to target <code className="font-mono">{targetId}</code>
            </span>
            <button
              type="button"
              onClick={() => updateParam('targetId', '')}
              className="text-xs font-semibold text-accent-text underline-offset-2 hover:underline"
            >
              Clear
            </button>
          </div>
        )}

        <p className="mt-3 text-xs text-muted">
          Dates are UTC and the end date is inclusive.
          {filtered && (
            <>
              {' '}
              <button
                type="button"
                onClick={() => setParams(new URLSearchParams())}
                className="font-semibold text-accent-text underline-offset-2 hover:underline"
              >
                Reset all filters
              </button>
            </>
          )}
        </p>
      </Panel>

      <Panel
        title="Entries"
        subtitle={query.data ? `${query.data.total.toLocaleString()} matching` : undefined}
      >
        <div className="mt-4">
          {query.isPending ? (
            <LoadingState label="Loading audit trail" />
          ) : query.isError ? (
            <QueryError context="Could not load the audit log." error={query.error} />
          ) : query.data.items.length === 0 ? (
            <p className="py-10 text-center text-sm text-muted">
              No entries match these filters.
            </p>
          ) : (
            <ul className="flex flex-col gap-3">
              {query.data.items.map((entry) => (
                <AuditRow key={entry._id} entry={entry} onFilterTarget={updateParam} />
              ))}
            </ul>
          )}

          {query.data && (
            <Pagination
              page={query.data.page}
              limit={query.data.limit}
              total={query.data.total}
              onPageChange={(next) => updateParam('page', String(next))}
            />
          )}
        </div>
      </Panel>
    </>
  );
}

function AuditRow({
  entry,
  onFilterTarget,
}: {
  entry: AuditEntry;
  onFilterTarget: (key: string, value: string) => void;
}) {
  return (
    <li className="rounded-card border border-hairline bg-surface p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex min-w-0 flex-wrap items-center gap-2">
          <Pill tone={actionTone(entry.action)}>{entry.action}</Pill>
          <span className="text-sm text-muted">
            on <b className="text-ink">{entry.targetType}</b>
          </span>
          {entry.targetId && (
            <button
              type="button"
              onClick={() => onFilterTarget('targetId', entry.targetId ?? '')}
              title="Filter to this target"
              className="max-w-[220px] truncate font-mono text-[11px] text-accent-text hover:underline"
            >
              {entry.targetId}
            </button>
          )}
        </div>
        <span
          className="tnum shrink-0 text-xs text-muted"
          title={formatDateTime(entry.createdAt)}
        >
          {relativeTime(entry.createdAt)}
        </span>
      </div>

      {/*
        The diff is the whole value of this screen. A raw JSON dump is not an
        audit trail anyone will read — this renders one line per changed field.
      */}
      {entry.diff.length > 0 && (
        <ul className="mt-3 flex flex-col gap-1.5 border-t border-hairline pt-3">
          {entry.diff.map((change) => (
            <li key={change.field} className="flex flex-wrap items-baseline gap-2 text-sm">
              <span className="font-medium text-muted">{change.field}</span>
              <span className="min-w-0 break-all rounded bg-crit-wash px-1.5 py-0.5 font-mono text-xs text-crit line-through">
                {formatValue(change.before)}
              </span>
              <Icon name="chevronRight" className="h-3 w-3 shrink-0 text-muted-soft" />
              <span className="min-w-0 break-all rounded bg-good-wash px-1.5 py-0.5 font-mono text-xs text-good">
                {formatValue(change.after)}
              </span>
            </li>
          ))}
        </ul>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 border-t border-hairline pt-3 text-xs text-muted">
        {/* Denormalized, so the trail survives the admin being deleted. */}
        <span>
          by <b className="text-ink">{entry.actorEmail}</b>
        </span>
        {entry.ip && <span className="font-mono">{entry.ip}</span>}
        {Object.keys(entry.meta).length > 0 && (
          <span className="truncate">
            {Object.entries(entry.meta)
              .map(([key, value]) => `${key}: ${String(value)}`)
              .join(' · ')}
          </span>
        )}
      </div>
    </li>
  );
}

/** Compact, readable rendering of a diff value — never `[object Object]`. */
function formatValue(value: unknown): string {
  if (value === null || value === undefined) return '—';
  if (typeof value === 'string') return value === '' ? '(empty)' : value;
  if (typeof value === 'boolean' || typeof value === 'number') return String(value);
  if (Array.isArray(value)) return value.length === 0 ? '(none)' : value.map(String).join(', ');
  return JSON.stringify(value);
}
