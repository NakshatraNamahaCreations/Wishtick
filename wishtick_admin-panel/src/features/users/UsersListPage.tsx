import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Column, DataTable, Pagination } from '@/components/DataTable';
import { Icon } from '@/components/Icon';
import { ErrorNotice, Panel } from '@/components/ui';
import { usersApi } from '@/lib/api/users';
import type { UserAdminView } from '@/lib/api/schemas';
import { AcquisitionLabel, StatusPill } from './user-display';
import { displayName, formatDate } from './user-format';

const STATUSES = [
  { value: '', label: 'All statuses' },
  { value: 'active', label: 'Active' },
  { value: 'suspended', label: 'Suspended' },
  { value: 'deleted', label: 'Deleted' },
];

const LIMIT = 25;

export function UsersListPage() {
  const navigate = useNavigate();
  // URL-synced so a filtered view is shareable and survives a reload — which
  // matters when someone is pasting a link into an incident thread.
  const [params, setParams] = useSearchParams();

  const search = params.get('search') ?? '';
  const status = params.get('status') ?? '';
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);

  const [searchInput, setSearchInput] = useState(search);

  // Debounce typing into the URL rather than firing a request per keystroke.
  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchInput === search) return;
      setParams(
        (current) => {
          const next = new URLSearchParams(current);
          if (searchInput) next.set('search', searchInput);
          else next.delete('search');
          next.delete('page'); // A new search starts at page 1.
          return next;
        },
        { replace: true },
      );
    }, 350);
    return () => clearTimeout(timer);
  }, [searchInput, search, setParams]);

  const query = useQuery({
    queryKey: ['users', { search, status, page }],
    queryFn: ({ signal }) => usersApi.list({ search, status, page, limit: LIMIT }, signal),
    // Keeps the previous page on screen while the next loads, instead of
    // flashing an empty table between pages.
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

  const columns: Column<UserAdminView>[] = [
    {
      key: 'user',
      header: 'User',
      mobileLabel: null, // Already the card headline.
      render: (user) => (
        <div className="min-w-0">
          <div className="truncate font-semibold">{displayName(user)}</div>
          <div className="truncate text-xs text-muted">{user.email ?? user.phone ?? '—'}</div>
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (user) => <StatusPill status={user.status} />,
    },
    {
      key: 'verified',
      header: 'Verified',
      render: (user) => {
        const badges = [
          user.emailVerified ? 'Email' : null,
          user.phoneVerified ? 'Phone' : null,
        ].filter(Boolean);
        return badges.length ? (
          <span className="text-xs text-muted">{badges.join(' · ')}</span>
        ) : (
          <span className="text-xs text-muted-soft">Neither</span>
        );
      },
    },
    {
      key: 'acquisition',
      header: 'Source',
      render: (user) => (
        <span className="text-xs">
          <AcquisitionLabel acquisition={user.acquisition} />
        </span>
      ),
    },
    {
      key: 'created',
      header: 'Joined',
      render: (user) => <span className="tnum text-xs text-muted">{formatDate(user.createdAt)}</span>,
    },
  ];

  return (
    <>
      <div>
        <h1 className="font-display text-[27px] font-bold tracking-tight">Users</h1>
        <p className="mt-1 text-sm text-muted">
          Search across email, phone, and name. Newest accounts first.
        </p>
      </div>

      <Panel>
        <div className="flex flex-col gap-3 sm:flex-row">
          <div className="relative flex-1">
            <Icon
              name="search"
              className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-soft"
            />
            <input
              type="search"
              value={searchInput}
              onChange={(event) => setSearchInput(event.target.value)}
              placeholder="Search email, phone, or name"
              aria-label="Search users"
              className="min-h-[44px] w-full rounded-pill border border-field bg-surface py-2 pl-11 pr-4 text-sm text-ink placeholder:text-muted-soft focus:outline-none focus-visible:border-accent"
            />
          </div>

          <select
            value={status}
            onChange={(event) => updateParam('status', event.target.value)}
            aria-label="Filter by status"
            className="min-h-[44px] rounded-pill border border-field bg-surface px-4 text-sm text-ink focus:outline-none focus-visible:border-accent sm:w-44"
          >
            {STATUSES.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>

        <div className="mt-5">
          {query.isError ? (
            <ErrorNotice>{'Could not load users. Try again.'}</ErrorNotice>
          ) : (
            <>
              <DataTable
                rows={query.data?.items ?? []}
                columns={columns}
                rowKey={(user) => user.id}
                primary={(user) => (
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate">{displayName(user)}</div>
                      <div className="truncate text-xs font-normal text-muted">
                        {user.email ?? user.phone ?? '—'}
                      </div>
                    </div>
                    <StatusPill status={user.status} />
                  </div>
                )}
                onRowClick={(user) => void navigate(`/users/${user.id}`)}
                isLoading={query.isPending}
                emptyTitle={search || status ? 'No users match those filters' : 'No users yet'}
                emptyBody={
                  search || status
                    ? 'Try a shorter search term, or clear the status filter.'
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
