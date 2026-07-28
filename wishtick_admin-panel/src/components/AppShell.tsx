import clsx from 'clsx';
import { useCallback, useEffect, useRef, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import type { AdminPermission } from '@/lib/api/schemas';
import { useAuth } from '@/features/auth/use-auth';
import { Icon, type IconName } from './Icon';
import { OfflineBanner } from './OfflineBanner';
import { SessionBanner } from './SessionBanner';
import { useFocusTrap } from './use-focus-trap';

interface NavEntry {
  to: string;
  label: string;
  icon: IconName;
  /** Undefined = visible to any authenticated admin. */
  permission?: AdminPermission;
}

/**
 * Nav is filtered by permission so operators don't see doors they can't open.
 * This is COSMETIC ONLY — every route re-checks, and the server is the real
 * authority (it returns ADMIN_FORBIDDEN regardless of what we render).
 */
const PRIMARY_NAV: NavEntry[] = [
  { to: '/', label: 'Dashboard', icon: 'dashboard' },
  { to: '/users', label: 'Users', icon: 'users', permission: 'users:view' },
  { to: '/moderation', label: 'Moderation', icon: 'shield', permission: 'moderation:view' },
  { to: '/analytics', label: 'Analytics', icon: 'chart', permission: 'analytics:view' },
  { to: '/audit', label: 'Audit Log', icon: 'document', permission: 'audit:view' },
  { to: '/admins', label: 'Admins', icon: 'person', permission: 'admins:manage' },
];

/**
 * Full-bleed application frame.
 *
 * Desktop: a fixed sidebar beside a scrolling main column, filling the viewport.
 * Mobile:  the sidebar becomes an off-canvas drawer behind a hamburger, because
 *          a wrapped horizontal nav eats the top third of a phone screen before
 *          any content appears.
 *
 * Height is `h-dvh`, not `h-screen` — on mobile browsers `100vh` sits behind the
 * collapsing address bar, which cuts off the bottom of the page.
 */
export function AppShell() {
  const { admin, can, logout } = useAuth();
  const location = useLocation();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const toggleRef = useRef<HTMLButtonElement>(null);
  const drawerRef = useRef<HTMLDivElement>(null);

  const visible = PRIMARY_NAV.filter((entry) => !entry.permission || can(entry.permission));

  // Navigating closes the drawer — otherwise it covers the page you just opened.
  useEffect(() => {
    setDrawerOpen(false);
  }, [location.pathname]);

  const closeDrawer = useCallback(() => setDrawerOpen(false), []);
  useFocusTrap(drawerRef, drawerOpen, closeDrawer);

  const initials =
    admin?.name
      ?.split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? '')
      .join('') || 'AD';

  const navContent = (
    <>
      <div className="flex items-center gap-2.5 border-b border-hairline px-2 pb-5">
        <span className="grid h-8 w-8 shrink-0 place-items-center rounded-[9px] bg-accent text-base font-bold text-white">
          W
        </span>
        <span className="font-display text-[19px] font-bold tracking-tight">Wishtick</span>
      </div>

      <nav className="flex flex-col gap-0.5" aria-label="Main">
        {visible.map((entry) => (
          <NavLink
            key={entry.to}
            to={entry.to}
            end={entry.to === '/'}
            className={({ isActive }) =>
              clsx(
                'flex items-center gap-3 rounded-nav px-3.5 py-3 md:py-2.5',
                'text-[15px] transition-colors md:text-[14.5px]',
                isActive
                  ? 'bg-accent-wash font-semibold text-accent-text'
                  : 'font-medium text-nav-idle hover:bg-surface-2 hover:text-ink',
              )
            }
          >
            <Icon name={entry.icon} className="h-[19px] w-[19px] shrink-0" />
            {entry.label}
          </NavLink>
        ))}
      </nav>

      <div className="mt-auto flex flex-col gap-0.5 pt-4">
        <button
          type="button"
          onClick={() => void logout()}
          className="flex items-center gap-3 rounded-nav px-3.5 py-3 text-[15px] font-medium text-nav-idle transition-colors hover:bg-surface-2 hover:text-ink md:py-2.5 md:text-[14.5px]"
        >
          <Icon name="logout" className="h-[19px] w-[19px] shrink-0" />
          Sign out
        </button>
      </div>
    </>
  );

  return (
    <div className="grid h-dvh grid-cols-1 overflow-hidden bg-ground md:grid-cols-[260px_1fr]">
      {/* Visible only on focus — lets a keyboard user skip the nav entirely. */}
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-[60] focus:rounded-pill focus:bg-accent focus:px-4 focus:py-2 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to main content
      </a>
      {/* ── Sidebar: static on desktop ── */}
      <aside className="hidden flex-col gap-6 border-r border-hairline bg-surface p-[18px] pt-[26px] md:flex">
        {navContent}
      </aside>

      {/* ── Sidebar: drawer on mobile ── */}
      {drawerOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <button
            type="button"
            aria-label="Close menu"
            onClick={() => setDrawerOpen(false)}
            className="absolute inset-0 bg-black/50"
          />
          <div
            ref={drawerRef}
            role="dialog"
            aria-modal="true"
            aria-label="Main menu"
            className="absolute inset-y-0 left-0 flex w-[276px] max-w-[85vw] flex-col gap-6 overflow-y-auto border-r border-hairline bg-surface p-[18px] pt-[26px] shadow-pop"
          >
            {navContent}
          </div>
        </div>
      )}

      {/* ── Main ── */}
      <div className="flex min-w-0 flex-col overflow-hidden">
        <header className="flex shrink-0 items-center justify-between gap-3 border-b border-hairline bg-surface px-4 py-3 md:px-7 md:py-4">
          <div className="flex min-w-0 items-center gap-3">
            <button
              ref={toggleRef}
              type="button"
              onClick={() => setDrawerOpen(true)}
              aria-label="Open menu"
              aria-expanded={drawerOpen}
              className="grid h-10 w-10 shrink-0 place-items-center rounded-nav border border-hairline text-muted transition-colors hover:text-accent-text md:hidden"
            >
              <Icon name="menu" className="h-5 w-5" />
            </button>
            <p className="truncate text-[13px] text-muted">{admin?.email}</p>
          </div>

          <div className="flex shrink-0 items-center gap-2.5 rounded-pill border border-hairline bg-surface py-1.5 pl-1.5 pr-1.5 sm:pr-3">
            <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-accent text-[12.5px] font-bold text-white">
              {initials}
            </span>
            {/* Name and role are the first thing to go on a narrow screen —
                the avatar alone still identifies who is signed in. */}
            <span className="hidden flex-col leading-tight sm:flex">
              <span className="text-[13px] font-semibold">{admin?.name}</span>
              <span className="text-[11px] capitalize text-muted">
                {admin?.roles.map((r) => r.replace(/_/g, ' ')).join(', ')}
              </span>
            </span>
          </div>
        </header>

        <main
          id="main"
          tabIndex={-1}
          className="flex flex-1 flex-col gap-5 overflow-y-auto p-4 outline-none md:gap-[22px] md:p-7"
        >
          <OfflineBanner />
          <SessionBanner />
          <Outlet />
        </main>
      </div>
    </div>
  );
}
