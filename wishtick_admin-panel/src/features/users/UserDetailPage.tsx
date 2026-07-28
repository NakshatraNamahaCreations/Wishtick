import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ConfirmDialog } from '@/components/ConfirmDialog';
import { Icon } from '@/components/Icon';
import { Button, Field, LoadingState, Panel, Pill } from '@/components/ui';
import { useAuth } from '@/features/auth/use-auth';
import { ApiError, ErrorCode } from '@/lib/api/errors';
import { usersApi } from '@/lib/api/users';
import { AcquisitionLabel, StatusPill } from './user-display';
import { displayName, formatDateTime, relativeTime } from './user-format';

type PendingAction = 'suspend' | 'reactivate' | 'force-logout' | null;

export function UserDetailPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { can } = useAuth();

  const [pending, setPending] = useState<PendingAction>(null);
  const [reason, setReason] = useState('');

  const canManage = can('users:manage');

  const query = useQuery({
    queryKey: ['user', id],
    queryFn: ({ signal }) => usersApi.detail(id, signal),
  });

  const mutation = useMutation({
    mutationFn: async (action: Exclude<PendingAction, null>) => {
      if (action === 'suspend') return usersApi.suspend(id, reason);
      if (action === 'reactivate') return usersApi.reactivate(id);
      return usersApi.forceLogout(id);
    },
    onSuccess: async () => {
      setPending(null);
      setReason('');
      // Both the detail and any cached list page are now stale.
      await queryClient.invalidateQueries({ queryKey: ['user', id] });
      await queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });

  if (query.isPending) return <LoadingState label="Loading user" />;

  if (query.isError) {
    const notFound = query.error instanceof ApiError && query.error.is(ErrorCode.NOT_FOUND);
    return (
      <Panel>
        <div className="px-2 py-10 text-center">
          <p className="font-display text-xl font-bold tracking-tight">
            {notFound ? 'User not found' : 'Could not load this user'}
          </p>
          <p className="mx-auto mt-2 max-w-md text-sm text-muted">
            {notFound
              ? 'That account does not exist, or the id in the URL is malformed.'
              : 'Something went wrong fetching this account.'}
          </p>
          <Link
            to="/users"
            className="mt-6 inline-flex rounded-pill bg-accent px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-accent-hover"
          >
            Back to users
          </Link>
        </div>
      </Panel>
    );
  }

  const user = query.data;
  const isSuspended = user.status === 'suspended';
  const isDeleted = user.status === 'deleted';

  return (
    <>
      <div className="flex flex-col gap-3">
        <button
          type="button"
          onClick={() => void navigate('/users')}
          className="flex w-fit items-center gap-1.5 text-sm font-medium text-muted transition-colors hover:text-accent-text"
        >
          <Icon name="chevronLeft" className="h-4 w-4" />
          Users
        </button>

        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="min-w-0">
            <h1 className="font-display text-[27px] font-bold tracking-tight text-balance">
              {displayName(user)}
            </h1>
            <p className="mt-1 truncate text-sm text-muted">{user.email ?? user.phone ?? '—'}</p>
          </div>
          <StatusPill status={user.status} />
        </div>
      </div>

      {isSuspended && user.suspendedReason && (
        <div className="rounded-nav bg-crit-wash px-4 py-3 text-sm leading-relaxed text-crit">
          <b className="font-bold">Suspended:</b> {user.suspendedReason}
        </div>
      )}

      {/* ── Actions ── */}
      {canManage && !isDeleted && (
        <Panel title="Actions">
          <div className="mt-4 flex flex-col gap-2 sm:flex-row sm:flex-wrap">
            {isSuspended ? (
              <Button onClick={() => setPending('reactivate')}>Reactivate account</Button>
            ) : (
              <Button variant="danger" onClick={() => setPending('suspend')}>
                Suspend account
              </Button>
            )}
            <Button variant="ghost" onClick={() => setPending('force-logout')}>
              Force sign-out
            </Button>
          </div>
          <p className="mt-3 text-xs leading-relaxed text-muted">
            Every action here is recorded in the audit log with your name and a before/after diff.
          </p>
        </Panel>
      )}

      {!canManage && (
        <div className="rounded-nav bg-info-wash px-4 py-3 text-xs leading-relaxed text-info">
          You have read-only access to users. Suspending or signing out an account needs the{' '}
          <code className="font-mono">users:manage</code> permission.
        </div>
      )}

      {/* ── Account ── */}
      <Panel title="Account">
        <dl className="mt-4 grid grid-cols-1 gap-x-8 gap-y-4 sm:grid-cols-2">
          <DetailRow label="Email">
            {user.email ?? '—'}
            {user.email && (
              <Pill tone={user.emailVerified ? 'good' : 'warn'}>
                {user.emailVerified ? 'Verified' : 'Unverified'}
              </Pill>
            )}
          </DetailRow>
          <DetailRow label="Phone">
            {user.phone ?? '—'}
            {user.phone && (
              <Pill tone={user.phoneVerified ? 'good' : 'warn'}>
                {user.phoneVerified ? 'Verified' : 'Unverified'}
              </Pill>
            )}
          </DetailRow>
          <DetailRow label="Roles">{user.roles.join(', ') || '—'}</DetailRow>
          <DetailRow label="Acquired via">
            <AcquisitionLabel acquisition={user.acquisition} />
          </DetailRow>
          <DetailRow label="Joined">{formatDateTime(user.createdAt)}</DetailRow>
          <DetailRow label="Last login">{formatDateTime(user.lastLoginAt)}</DetailRow>
          <DetailRow label="User ID">
            <code className="break-all font-mono text-xs text-muted">{user.id}</code>
          </DetailRow>
        </dl>
      </Panel>

      {/* ── Counts ── */}
      <Panel title="Activity totals">
        <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <CountTile label="Wishlists" value={user.counts.wishlists} />
          <CountTile label="Events" value={user.counts.events} />
          <CountTile label="Gifts given" value={user.counts.giftsGiven} />
          <CountTile label="Gifts received" value={user.counts.giftsReceived} />
          <CountTile label="Reels" value={user.counts.reels} />
        </div>
      </Panel>

      {/* ── Recent activity ── */}
      <Panel
        title="Recent activity"
        subtitle="Latest gifts given and wishlists created"
      >
        {user.activity.length === 0 ? (
          <p className="mt-4 text-sm text-muted">No recorded activity.</p>
        ) : (
          <ul className="mt-4 flex flex-col">
            {user.activity.map((entry, index) => (
              <li
                key={`${entry.type}-${entry.at}-${index}`}
                className="flex items-start justify-between gap-4 border-b border-hairline py-3 last:border-b-0"
              >
                <div className="flex min-w-0 items-start gap-3">
                  <Pill tone={entry.type === 'gift' ? 'info' : 'neutral'}>{entry.type}</Pill>
                  <span className="min-w-0 break-words text-sm">{entry.summary}</span>
                </div>
                <span className="tnum shrink-0 text-xs text-muted">{relativeTime(entry.at)}</span>
              </li>
            ))}
          </ul>
        )}

        {/*
          This is a 5-gifts + 5-wishlists sample, not a timeline. Gifts received,
          events, and reels appear in the totals above but never here, and there
          is no pagination. Saying so matters — an operator investigating an
          older incident would otherwise read an empty list as "nothing happened".
        */}
        <p className="mt-4 flex items-start gap-2.5 rounded-nav bg-warn-wash px-4 py-3 text-xs leading-relaxed text-warn">
          <Icon name="clock" className="mt-px h-4 w-4 shrink-0" />
          <span>
            <b className="font-bold">A sample, not a full history.</b> The API returns at most 10
            entries — the 5 most recent gifts given and 5 most recent wishlists. Gifts received,
            events, and reels are counted above but never listed here, and there is no way to page
            further back.
          </span>
        </p>
      </Panel>

      {/* ── Confirmations ── */}
      <ConfirmDialog
        open={pending === 'suspend'}
        title="Suspend this account?"
        consequence={
          <>
            <b className="text-ink">{displayName(user)}</b> will be signed out of every device
            immediately, any live connection will be dropped, and they will not be able to sign in
            again until an admin reactivates them.
          </>
        }
        confirmLabel="Suspend account"
        destructive
        busy={mutation.isPending}
        error={mutation.error}
        onCancel={() => {
          setPending(null);
          setReason('');
          mutation.reset();
        }}
        onConfirm={() => mutation.mutate('suspend')}
      >
        <Field
          label="Reason"
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          maxLength={500}
          required
          placeholder="Repeated harassment in wishlist chat"
          hint="Recorded in the audit log and shown on this account. Max 500 characters."
        />
      </ConfirmDialog>

      <ConfirmDialog
        open={pending === 'reactivate'}
        title="Reactivate this account?"
        consequence={
          <>
            <b className="text-ink">{displayName(user)}</b> will be able to sign in again straight
            away. Their existing sessions stay invalid, so they will need to log in fresh.
          </>
        }
        confirmLabel="Reactivate"
        busy={mutation.isPending}
        error={mutation.error}
        onCancel={() => {
          setPending(null);
          mutation.reset();
        }}
        onConfirm={() => mutation.mutate('reactivate')}
      />

      <ConfirmDialog
        open={pending === 'force-logout'}
        title="Sign this account out everywhere?"
        consequence={
          <>
            Every session for <b className="text-ink">{displayName(user)}</b> is invalidated and
            live connections drop. The account stays <b className="text-ink">active</b> — they can
            sign straight back in. Use this for a suspected stolen session, not as a punishment.
          </>
        }
        confirmLabel="Force sign-out"
        busy={mutation.isPending}
        error={mutation.error}
        onCancel={() => {
          setPending(null);
          mutation.reset();
        }}
        onConfirm={() => mutation.mutate('force-logout')}
      />
    </>
  );
}

function DetailRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <dt className="text-xs font-semibold uppercase tracking-wider text-muted-soft">{label}</dt>
      <dd className="flex flex-wrap items-center gap-2 break-words text-sm">{children}</dd>
    </div>
  );
}

function CountTile({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-nav border border-hairline bg-surface-2 px-4 py-3">
      <p className="tnum font-display text-xl font-bold">{value.toLocaleString()}</p>
      <p className="mt-0.5 text-xs text-muted">{label}</p>
    </div>
  );
}
