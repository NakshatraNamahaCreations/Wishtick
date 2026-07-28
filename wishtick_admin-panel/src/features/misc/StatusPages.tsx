import { Link } from 'react-router-dom';
import { Panel } from '@/components/ui';
import type { AdminPermission } from '@/lib/api/schemas';

/** Which role grants what — so a 403 tells the operator who to ask. */
const GRANTED_BY: Record<AdminPermission, string> = {
  'admins:manage': 'Super admin',
  'users:view': 'Super admin, moderator, support, or analyst',
  'users:manage': 'Super admin or support',
  'moderation:view': 'Super admin, moderator, or support',
  'moderation:act': 'Super admin or moderator',
  'analytics:view': 'Super admin or analyst',
  'audit:view': 'Super admin, moderator, or support',
};

export function ForbiddenPage({ permission }: { permission: AdminPermission }) {
  return (
    <Panel>
      <div className="px-2 py-10 text-center">
        <p className="font-display text-2xl font-bold tracking-tight">
          You don&rsquo;t have access to this
        </p>
        <p className="mx-auto mt-2 max-w-md text-sm leading-relaxed text-muted">
          This page needs the <code className="font-mono text-[13px] text-ink">{permission}</code>{' '}
          permission, which your roles don&rsquo;t include. It&rsquo;s granted by:{' '}
          <b className="text-ink">{GRANTED_BY[permission]}</b>. Ask a super admin if you need it.
        </p>
        <Link
          to="/"
          className="mt-6 inline-flex rounded-pill bg-accent px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-accent-hover"
        >
          Back to dashboard
        </Link>
      </div>
    </Panel>
  );
}

export function NotFoundPage() {
  return (
    <Panel>
      <div className="px-2 py-10 text-center">
        <p className="font-display text-2xl font-bold tracking-tight">Page not found</p>
        <p className="mx-auto mt-2 max-w-md text-sm text-muted">
          That route doesn&rsquo;t exist in the admin panel.
        </p>
        <Link
          to="/"
          className="mt-6 inline-flex rounded-pill bg-accent px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-accent-hover"
        >
          Back to dashboard
        </Link>
      </div>
    </Panel>
  );
}
