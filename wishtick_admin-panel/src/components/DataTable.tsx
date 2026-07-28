import clsx from 'clsx';
import type { ReactNode } from 'react';
import { EmptyState, LoadingState } from './ui';

/**
 * One dataset, two presentations.
 *
 * Below `md` a table is the wrong shape — horizontal scrolling hides exactly
 * the columns that carry the decision, so each row renders as a stacked card
 * instead. Same data, same order, no second source of truth.
 */

export interface Column<T> {
  key: string;
  header: string;
  /** Desktop cell. */
  render: (row: T) => ReactNode;
  /**
   * Mobile label. Omit to hide this column on the card entirely — use for
   * columns whose value is already carried by `primary`.
   */
  mobileLabel?: string | null;
  className?: string;
}

interface DataTableProps<T> {
  rows: T[];
  columns: Column<T>[];
  rowKey: (row: T) => string;
  /** The card's headline on mobile — what an operator scans for. */
  primary: (row: T) => ReactNode;
  onRowClick?: (row: T) => void;
  isLoading?: boolean;
  emptyTitle?: string;
  emptyBody?: ReactNode;
}

export function DataTable<T>({
  rows,
  columns,
  rowKey,
  primary,
  onRowClick,
  isLoading = false,
  emptyTitle = 'Nothing to show',
  emptyBody,
}: DataTableProps<T>) {
  if (isLoading) return <LoadingState />;
  if (rows.length === 0) return <EmptyState title={emptyTitle}>{emptyBody}</EmptyState>;

  return (
    <>
      {/* ── Mobile: one card per row ── */}
      <ul className="flex flex-col gap-3 md:hidden">
        {rows.map((row) => {
          const content = (
            <>
              <div className="mb-3 font-semibold">{primary(row)}</div>
              <dl className="flex flex-col gap-2">
                {columns
                  .filter((column) => column.mobileLabel !== null)
                  .map((column) => (
                    <div key={column.key} className="flex items-start justify-between gap-3">
                      <dt className="shrink-0 text-xs text-muted">
                        {column.mobileLabel ?? column.header}
                      </dt>
                      <dd className="min-w-0 text-right text-sm">{column.render(row)}</dd>
                    </div>
                  ))}
              </dl>
            </>
          );

          return (
            <li key={rowKey(row)}>
              {onRowClick ? (
                <button
                  type="button"
                  onClick={() => onRowClick(row)}
                  className="w-full rounded-card border border-hairline bg-surface p-4 text-left transition-colors hover:border-accent"
                >
                  {content}
                </button>
              ) : (
                <div className="rounded-card border border-hairline bg-surface p-4">{content}</div>
              )}
            </li>
          );
        })}
      </ul>

      {/* ── Desktop: a real table ── */}
      <div className="hidden overflow-x-auto md:block">
        <table className="w-full border-collapse">
          <thead>
            <tr>
              {columns.map((column) => (
                <th
                  key={column.key}
                  scope="col"
                  className={clsx(
                    'whitespace-nowrap border-b border-hairline pb-3 pr-4 text-left',
                    'text-xs font-semibold uppercase tracking-wider text-muted-soft',
                    column.className,
                  )}
                >
                  {column.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr
                key={rowKey(row)}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                className={clsx(
                  'border-b border-hairline last:border-b-0',
                  onRowClick && 'cursor-pointer transition-colors hover:bg-surface-2',
                )}
              >
                {columns.map((column) => (
                  <td
                    key={column.key}
                    className={clsx('py-4 pr-4 align-middle text-sm', column.className)}
                  >
                    {column.render(row)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

/** Offset pagination, matching the API's page/limit/total contract. */
export function Pagination({
  page,
  limit,
  total,
  onPageChange,
}: {
  page: number;
  limit: number;
  total: number;
  onPageChange: (page: number) => void;
}) {
  const lastPage = Math.max(1, Math.ceil(total / limit));
  if (total === 0) return null;

  const first = (page - 1) * limit + 1;
  const last = Math.min(page * limit, total);

  return (
    <div className="mt-5 flex flex-col items-center justify-between gap-3 border-t border-hairline pt-4 sm:flex-row">
      <p className="tnum text-xs text-muted">
        {first}–{last} of {total.toLocaleString()}
      </p>
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={() => onPageChange(page - 1)}
          disabled={page <= 1}
          className="min-h-[44px] rounded-pill border border-hairline px-4 text-sm font-semibold transition-colors hover:border-accent hover:text-accent-text disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:border-hairline disabled:hover:text-ink sm:min-h-0 sm:py-2"
        >
          Previous
        </button>
        <span className="tnum px-1 text-xs text-muted">
          {page} / {lastPage}
        </span>
        <button
          type="button"
          onClick={() => onPageChange(page + 1)}
          disabled={page >= lastPage}
          className="min-h-[44px] rounded-pill border border-hairline px-4 text-sm font-semibold transition-colors hover:border-accent hover:text-accent-text disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:border-hairline disabled:hover:text-ink sm:min-h-0 sm:py-2"
        >
          Next
        </button>
      </div>
    </div>
  );
}
