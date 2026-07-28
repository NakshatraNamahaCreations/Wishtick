import { keepPreviousData, useQuery } from '@tanstack/react-query';
import clsx from 'clsx';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Column, DataTable, Pagination } from '@/components/DataTable';
import { Panel, QueryError } from '@/components/ui';
import { moderationApi } from '@/lib/api/moderation';
import type { Report, ReportStatus, ReportTargetType } from '@/lib/api/schemas';
import { relativeTime } from '@/features/users/user-format';
import { ReportStatusPill, SeverityIndicator } from './moderation-display';
import { TARGET_LABEL } from './moderation-copy';

/**
 * The API applies exactly one status per request and defaults to `open` — there
 * is no combined view — so status is tabs rather than a filter, matching the
 * shape of the endpoint instead of fighting it.
 */
const TABS: { value: ReportStatus; label: string }[] = [
  { value: 'open', label: 'Open' },
  { value: 'reviewing', label: 'Reviewing' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'dismissed', label: 'Dismissed' },
];

const TYPES: { value: string; label: string }[] = [
  { value: '', label: 'All types' },
  { value: 'user', label: 'User accounts' },
  { value: 'message', label: 'Chat messages' },
  { value: 'wish', label: 'Reel wishes' },
  { value: 'reel', label: 'Birthday reels' },
  { value: 'wishlist', label: 'Wishlists' },
  { value: 'event', label: 'Events' },
];

const LIMIT = 25;

export function ModerationQueuePage() {
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();

  const status = (params.get('status') ?? 'open') as ReportStatus;
  const type = params.get('type') ?? '';
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);

  const query = useQuery({
    queryKey: ['moderation-queue', { status, type, page }],
    queryFn: ({ signal }) =>
      moderationApi.queue(
        {
          status,
          type: (type || undefined) as ReportTargetType | undefined,
          page,
          limit: LIMIT,
        },
        signal,
      ),
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

  const columns: Column<Report>[] = [
    {
      key: 'severity',
      header: 'Severity',
      render: (report) => <SeverityIndicator severity={report.severity} />,
    },
    {
      key: 'target',
      header: 'Target',
      mobileLabel: null,
      render: (report) => (
        <div className="min-w-0">
          <div className="font-semibold">{TARGET_LABEL[report.targetType]}</div>
          <div className="truncate font-mono text-[11px] text-muted-soft">{report.targetId}</div>
        </div>
      ),
    },
    {
      key: 'reason',
      header: 'Reason',
      render: (report) => (
        <div className="min-w-0">
          <div className="truncate">{report.reason}</div>
          {report.source === 'auto' && (
            <span className="text-[11px] font-semibold uppercase tracking-wide text-muted-soft">
              Auto-flagged
            </span>
          )}
        </div>
      ),
    },
    {
      key: 'age',
      header: 'Reported',
      render: (report) => (
        <span className="tnum whitespace-nowrap text-xs text-muted">
          {relativeTime(report.createdAt)}
        </span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (report) => <ReportStatusPill status={report.status} />,
    },
  ];

  return (
    <>
      <div>
        <h1 className="font-display text-[27px] font-bold tracking-tight">Moderation</h1>
        <p className="mt-1 text-sm text-muted">
          Highest severity first, then longest waiting — the server&rsquo;s own ordering.
        </p>
      </div>

      <Panel>
        {/* Status tabs — one request per tab, because the API allows one status. */}
        <div
          role="tablist"
          aria-label="Report status"
          className="-mx-1 flex gap-1 overflow-x-auto pb-1"
        >
          {TABS.map((tab) => {
            const active = tab.value === status;
            return (
              <button
                key={tab.value}
                role="tab"
                aria-selected={active}
                onClick={() => updateParam('status', tab.value)}
                className={clsx(
                  'min-h-[44px] shrink-0 rounded-pill px-4 text-sm font-semibold transition-colors sm:min-h-0 sm:py-2',
                  active
                    ? 'bg-accent-wash text-accent-text'
                    : 'text-muted hover:bg-surface-2 hover:text-ink',
                )}
              >
                {tab.label}
              </button>
            );
          })}
        </div>

        <div className="mt-4">
          <select
            value={type}
            onChange={(event) => updateParam('type', event.target.value)}
            aria-label="Filter by content type"
            className="min-h-[44px] w-full rounded-pill border border-field bg-surface px-4 text-sm text-ink focus:outline-none focus-visible:border-accent sm:w-56"
          >
            {TYPES.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>

        <div className="mt-5">
          {query.isError ? (
            <QueryError context="Could not load the moderation queue." error={query.error} />
          ) : (
            <>
              <DataTable
                rows={query.data?.items ?? []}
                columns={columns}
                rowKey={(report) => report._id}
                primary={(report) => (
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate">{TARGET_LABEL[report.targetType]}</div>
                      <div className="truncate text-xs font-normal text-muted">
                        {report.reason}
                      </div>
                    </div>
                    <SeverityIndicator severity={report.severity} />
                  </div>
                )}
                onRowClick={(report) => void navigate(`/moderation/${report._id}`)}
                isLoading={query.isPending}
                emptyTitle={
                  status === 'open' ? 'Nothing waiting for review' : `No ${status} reports`
                }
                emptyBody={
                  status === 'open'
                    ? 'The queue is clear. New reports appear here automatically.'
                    : undefined
                }
              />

              {query.data && (
                <Pagination
                  page={query.data.page}
                  limit={query.data.limit}
                  total={query.data.total}
                  onPageChange={(next) => updateParam('page', String(next))}
                />
              )}
            </>
          )}
        </div>
      </Panel>
    </>
  );
}
