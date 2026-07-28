import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { ConfirmDialog } from '@/components/ConfirmDialog';
import { Icon } from '@/components/Icon';
import { Button, Field, LoadingState, Panel, Pill, QueryError } from '@/components/ui';
import { useAuth } from '@/features/auth/use-auth';
import { formatDateTime } from '@/features/users/user-format';
import { ApiError, fieldErrorsFrom, messageFor } from '@/lib/api/errors';
import { adminsApi } from '@/lib/api/admins';
import type { AdminRole, AdminView } from '@/lib/api/schemas';

const ROLES: { value: AdminRole; label: string; grants: string }[] = [
  { value: 'super_admin', label: 'Super admin', grants: 'Everything, including managing admins' },
  { value: 'moderator', label: 'Moderator', grants: 'Moderation queue + act, view users, audit' },
  { value: 'support', label: 'Support', grants: 'View + manage users, view moderation, audit' },
  { value: 'analyst', label: 'Analyst', grants: 'Analytics and read-only users' },
];

type Dialog =
  | { kind: 'create' }
  | { kind: 'edit'; admin: AdminView }
  | { kind: 'password'; admin: AdminView }
  | { kind: 'disable'; admin: AdminView }
  | null;

export function AdminsPage() {
  const queryClient = useQueryClient();
  const { admin: currentAdmin } = useAuth();
  const [dialog, setDialog] = useState<Dialog>(null);

  const query = useQuery({
    queryKey: ['admins'],
    queryFn: ({ signal }) => adminsApi.list(signal),
  });

  const close = () => setDialog(null);
  const invalidate = () => void queryClient.invalidateQueries({ queryKey: ['admins'] });

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-[27px] font-bold tracking-tight">Admins</h1>
          <p className="mt-1 text-sm text-muted">
            Operator accounts. Every change here is recorded in the{' '}
            <Link to="/audit?targetType=admin" className="text-accent-text hover:underline">
              audit log
            </Link>
            .
          </p>
        </div>
        <Button onClick={() => setDialog({ kind: 'create' })}>Add admin</Button>
      </div>

      <Panel>
        {query.isPending ? (
          <LoadingState label="Loading admins" />
        ) : query.isError ? (
          <QueryError context="Could not load admins." error={query.error} />
        ) : (
          <ul className="flex flex-col gap-3">
            {query.data.map((admin) => {
              const isSelf = admin.id === currentAdmin?.id;
              const disabled = admin.status !== 'active';
              return (
                <li
                  key={admin.id}
                  className="rounded-card border border-hairline bg-surface p-4"
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-semibold">{admin.name}</span>
                        {isSelf && <Pill tone="info">You</Pill>}
                        {disabled && <Pill tone="crit">Disabled</Pill>}
                        {!admin.totpEnabled && <Pill tone="warn">2FA not set up</Pill>}
                      </div>
                      <p className="mt-0.5 truncate text-sm text-muted">{admin.email}</p>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      <Button variant="ghost" onClick={() => setDialog({ kind: 'edit', admin })}>
                        Edit
                      </Button>
                      <Button
                        variant="ghost"
                        onClick={() => setDialog({ kind: 'password', admin })}
                      >
                        Reset password
                      </Button>
                      {!disabled && (
                        <Button
                          variant="danger"
                          onClick={() => setDialog({ kind: 'disable', admin })}
                          // The server refuses self-disable with a 403; disabling
                          // the control makes the rule visible instead of letting
                          // someone discover it by hitting an error.
                          disabled={isSelf}
                          title={isSelf ? 'You cannot disable your own account' : undefined}
                        >
                          Disable
                        </Button>
                      )}
                    </div>
                  </div>

                  <div className="mt-3 flex flex-wrap gap-1.5 border-t border-hairline pt-3">
                    {admin.roles.map((role) => (
                      <Pill key={role}>{role.replace(/_/g, ' ')}</Pill>
                    ))}
                  </div>

                  <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted">
                    <span>
                      Last login{' '}
                      {admin.lastLoginAt ? formatDateTime(admin.lastLoginAt) : 'never'}
                    </span>
                    {admin.ipAllowlist.length > 0 && (
                      <span>IP allowlist: {admin.ipAllowlist.join(', ')}</span>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}

        <p className="mt-4 flex items-start gap-2.5 rounded-nav bg-info-wash px-4 py-3 text-xs leading-relaxed text-info">
          <Icon name="clock" className="mt-px h-4 w-4 shrink-0" />
          <span>
            <b className="font-bold">There is no delete.</b> Admin accounts are disabled, never
            removed — deleting one would orphan every audit entry that names them. A disabled
            account cannot sign in and its live sessions end immediately.
          </span>
        </p>
      </Panel>

      {dialog?.kind === 'create' && <CreateDialog onClose={close} onDone={invalidate} />}
      {dialog?.kind === 'edit' && (
        <EditDialog admin={dialog.admin} onClose={close} onDone={invalidate} />
      )}
      {dialog?.kind === 'password' && (
        <PasswordDialog admin={dialog.admin} onClose={close} onDone={invalidate} />
      )}
      {dialog?.kind === 'disable' && (
        <DisableDialog admin={dialog.admin} onClose={close} onDone={invalidate} />
      )}
    </>
  );
}

// ── Create ────────────────────────────────────────────────────────────────────

function CreateDialog({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [roles, setRoles] = useState<AdminRole[]>(['moderator']);
  const [allowlist, setAllowlist] = useState('');

  const mutation = useMutation({
    mutationFn: () =>
      adminsApi.create({
        email,
        name,
        password,
        roles,
        ipAllowlist: parseAllowlist(allowlist),
      }),
    onSuccess: () => {
      onDone();
      onClose();
    },
  });

  const conflict = mutation.error instanceof ApiError && mutation.error.status === 409;

  return (
    <ConfirmDialog
      open
      title="Add an admin"
      consequence="They can sign in immediately with this password, and will be required to set up two-factor authentication on first login."
      confirmLabel="Create admin"
      busy={mutation.isPending}
      error={conflict ? undefined : mutation.error}
      onCancel={onClose}
      onConfirm={() => mutation.mutate()}
    >
      <div className="flex flex-col gap-3">
        <Field
          label="Email"
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          error={conflict ? 'An admin with this email already exists.' : undefined}
          required
        />
        <Field
          label="Name"
          value={name}
          onChange={(event) => setName(event.target.value)}
          maxLength={120}
          required
        />
        <Field
          label="Password"
          type="password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          minLength={12}
          hint="At least 12 characters."
          error={fieldErrorsFrom(mutation.error).find((f) => f.includes('password'))}
          required
        />
        <RolePicker roles={roles} onChange={setRoles} />
        <AllowlistField value={allowlist} onChange={setAllowlist} />
      </div>
    </ConfirmDialog>
  );
}

// ── Edit ──────────────────────────────────────────────────────────────────────

function EditDialog({
  admin,
  onClose,
  onDone,
}: {
  admin: AdminView;
  onClose: () => void;
  onDone: () => void;
}) {
  const { admin: currentAdmin } = useAuth();
  const isSelf = admin.id === currentAdmin?.id;

  const [name, setName] = useState(admin.name);
  const [roles, setRoles] = useState<AdminRole[]>(admin.roles);
  const [allowlist, setAllowlist] = useState(admin.ipAllowlist.join(', '));

  const mutation = useMutation({
    mutationFn: () =>
      adminsApi.update(admin.id, {
        name,
        roles,
        ipAllowlist: parseAllowlist(allowlist) ?? [],
      }),
    onSuccess: () => {
      onDone();
      onClose();
    },
  });

  // Mirrors the server rule so it is visible before submitting, not after a 403.
  const removingOwnSuperAdmin =
    isSelf && admin.roles.includes('super_admin') && !roles.includes('super_admin');

  return (
    <ConfirmDialog
      open
      title={`Edit ${admin.name}`}
      consequence={
        <>
          Role changes take effect on their <b className="text-ink">next request</b> — permissions
          are recomputed server-side every time, so there is no need for them to sign in again.
        </>
      }
      confirmLabel="Save changes"
      busy={mutation.isPending}
      error={mutation.error}
      onCancel={onClose}
      onConfirm={() => mutation.mutate()}
    >
      <div className="flex flex-col gap-3">
        <Field
          label="Name"
          value={name}
          onChange={(event) => setName(event.target.value)}
          maxLength={120}
        />
        <RolePicker roles={roles} onChange={setRoles} />
        {removingOwnSuperAdmin && (
          <p className="rounded-nav bg-crit-wash px-4 py-3 text-xs leading-relaxed text-crit">
            You cannot remove your own super-admin role — it would lock you out of this screen.
            The server refuses this too.
          </p>
        )}
        <AllowlistField value={allowlist} onChange={setAllowlist} />
      </div>
    </ConfirmDialog>
  );
}

// ── Password ──────────────────────────────────────────────────────────────────

function PasswordDialog({
  admin,
  onClose,
  onDone,
}: {
  admin: AdminView;
  onClose: () => void;
  onDone: () => void;
}) {
  const [password, setPassword] = useState('');
  const mutation = useMutation({
    mutationFn: () => adminsApi.resetPassword(admin.id, password),
    onSuccess: () => {
      onDone();
      onClose();
    },
  });

  return (
    <ConfirmDialog
      open
      title={`Reset password for ${admin.name}`}
      consequence={
        <>
          Every session <b className="text-ink">{admin.email}</b> holds ends immediately, and they
          will need this new password to sign back in. Their two-factor setup is unchanged. The
          password itself is never written to the audit log.
        </>
      }
      confirmLabel="Reset password"
      destructive
      busy={mutation.isPending}
      error={mutation.error}
      onCancel={onClose}
      onConfirm={() => mutation.mutate()}
    >
      <Field
        label="New password"
        type="password"
        value={password}
        onChange={(event) => setPassword(event.target.value)}
        minLength={12}
        hint="At least 12 characters. Share it through a secure channel, not email."
        required
      />
    </ConfirmDialog>
  );
}

// ── Disable ───────────────────────────────────────────────────────────────────

function DisableDialog({
  admin,
  onClose,
  onDone,
}: {
  admin: AdminView;
  onClose: () => void;
  onDone: () => void;
}) {
  const mutation = useMutation({
    mutationFn: () => adminsApi.update(admin.id, { status: 'disabled' }),
    onSuccess: () => {
      onDone();
      onClose();
    },
  });

  const lastSuperAdmin =
    mutation.error instanceof ApiError && mutation.error.status === 409;

  return (
    <ConfirmDialog
      open
      title={`Disable ${admin.name}?`}
      consequence={
        <>
          <b className="text-ink">{admin.email}</b> is signed out everywhere immediately and cannot
          sign in again until re-enabled. Their audit history is kept — this is how you offboard an
          admin, since accounts are never deleted.
        </>
      }
      confirmLabel="Disable account"
      destructive
      busy={mutation.isPending}
      error={lastSuperAdmin ? undefined : mutation.error}
      onCancel={onClose}
      onConfirm={() => mutation.mutate()}
    >
      {lastSuperAdmin && (
        <p className="rounded-nav bg-crit-wash px-4 py-3 text-xs leading-relaxed text-crit">
          {messageFor(mutation.error)} Promote another admin to super-admin first, otherwise nobody
          can administer the platform.
        </p>
      )}
    </ConfirmDialog>
  );
}

// ── Shared inputs ─────────────────────────────────────────────────────────────

function RolePicker({
  roles,
  onChange,
}: {
  roles: AdminRole[];
  onChange: (roles: AdminRole[]) => void;
}) {
  function toggle(role: AdminRole) {
    // At least one role is required by the DTO, so never allow emptying it.
    const next = roles.includes(role) ? roles.filter((r) => r !== role) : [...roles, role];
    if (next.length > 0) onChange(next);
  }

  return (
    <fieldset className="flex flex-col gap-2">
      <legend className="mb-1 text-sm font-medium text-ink">Roles</legend>
      {/* Unchecking the last role is a silent no-op otherwise — say so. */}
      <p className="-mt-1 mb-1 text-xs text-muted">
        At least one role is required. To swap roles, add the new one first.
      </p>
      {ROLES.map((role) => (
        <label
          key={role.value}
          className="flex cursor-pointer items-start gap-3 rounded-nav border border-hairline p-3 transition-colors hover:border-accent"
        >
          <input
            type="checkbox"
            checked={roles.includes(role.value)}
            onChange={() => toggle(role.value)}
            className="mt-0.5 h-4 w-4 shrink-0 accent-[color:var(--accent)]"
          />
          <span className="min-w-0">
            <span className="block text-sm font-semibold">{role.label}</span>
            <span className="block text-xs text-muted">{role.grants}</span>
          </span>
        </label>
      ))}
    </fieldset>
  );
}

function AllowlistField({
  value,
  onChange,
}: {
  value: string;
  onChange: (value: string) => void;
}) {
  const entries = parseAllowlist(value) ?? [];
  // Exact string match server-side — a CIDR block would silently never match,
  // locking the account out of every address it was meant to permit.
  const cidr = entries.filter((entry) => entry.includes('/'));

  return (
    <div className="flex flex-col gap-1.5">
      <Field
        label="IP allowlist (optional)"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder="203.0.113.7, 198.51.100.4"
        hint="Comma-separated. Leave empty to allow any address."
        error={
          cidr.length > 0
            ? `CIDR ranges are not supported — ${cidr.join(', ')} would match nothing and lock this admin out. List each address individually.`
            : undefined
        }
      />
    </div>
  );
}

function parseAllowlist(value: string): string[] | undefined {
  const entries = value
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
  return entries.length > 0 ? entries : undefined;
}
