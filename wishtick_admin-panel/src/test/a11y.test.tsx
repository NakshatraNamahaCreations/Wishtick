import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { expectNoA11yViolations } from './a11y';
import { AuthContext, type AuthState } from '@/features/auth/auth-types';
import { LoginPage } from '@/features/auth/LoginPage';
import { UsersListPage } from '@/features/users/UsersListPage';
import { ModerationQueuePage } from '@/features/moderation/ModerationQueuePage';
import { AnalyticsPage } from '@/features/analytics/AnalyticsPage';
import { AuditPage } from '@/features/audit/AuditPage';
import { AdminsPage } from '@/features/admins/AdminsPage';
import type { ReactNode } from 'react';

const ADMIN = {
  id: 'a1',
  email: 'ops@wishtick.com',
  name: 'Ops Lead',
  roles: ['super_admin'],
  permissions: [
    'admins:manage',
    'users:view',
    'users:manage',
    'moderation:view',
    'moderation:act',
    'analytics:view',
    'audit:view',
  ],
  status: 'active',
  totpEnabled: true,
  ipAllowlist: [],
  lastLoginAt: '2026-07-21T09:00:00.000Z',
  createdAt: '2026-01-01T00:00:00.000Z',
};

function jsonOk(data: unknown) {
  return new Response(JSON.stringify({ success: true, data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** One mock covering every endpoint the screens under test call. */
function mockAllApis() {
  return vi.fn().mockImplementation((url: string) => {
    const u = String(url);
    if (u.includes('/admin/users')) {
      return Promise.resolve(
        jsonOk({
          items: [
            {
              id: 'u1',
              email: 'asha@example.com',
              phone: null,
              name: 'Asha R',
              status: 'active',
              roles: ['user'],
              suspendedReason: null,
              emailVerified: true,
              phoneVerified: false,
              acquisition: null,
              lastLoginAt: null,
              createdAt: '2026-03-02T08:00:00.000Z',
            },
          ],
          total: 1,
          page: 1,
          limit: 25,
        }),
      );
    }
    if (u.includes('/moderation/queue')) {
      return Promise.resolve(
        jsonOk({
          items: [
            {
              _id: 'r1',
              reporterId: 'u1',
              source: 'user',
              targetType: 'message',
              targetId: 'm1',
              reason: 'Abusive language',
              detail: null,
              status: 'open',
              severity: 3,
              resolution: null,
              handledBy: null,
              handledAt: null,
              createdAt: '2026-07-20T10:00:00.000Z',
              updatedAt: '2026-07-20T10:00:00.000Z',
            },
          ],
          total: 1,
          page: 1,
          limit: 25,
        }),
      );
    }
    if (u.includes('/analytics/overview'))
      return Promise.resolve(jsonOk({ date: '2026-07-20', dau: 5, wau: 12, mau: 30, totalUsers: 42 }));
    if (u.includes('/analytics/acquisition'))
      return Promise.resolve(jsonOk([{ source: 'whatsapp', signups: 9 }]));
    if (u.includes('/analytics/engagement'))
      return Promise.resolve(
        jsonOk({
          wishlistsCreated: 3,
          eventsCreated: 1,
          giftsCreated: 2,
          giftsFulfilled: 1,
          groupGiftsCreated: 0,
          reelsCreated: 0,
          reelsReleased: 0,
        }),
      );
    if (u.includes('/audit/actions')) return Promise.resolve(jsonOk(['user.suspend']));
    if (u.includes('/admin/audit'))
      return Promise.resolve(
        jsonOk({
          items: [
            {
              _id: 'e1',
              actorAdminId: 'a1',
              actorEmail: 'ops@wishtick.com',
              action: 'user.suspend',
              targetType: 'user',
              targetId: 'u1',
              diff: [{ field: 'status', before: 'active', after: 'suspended' }],
              meta: {},
              ip: null,
              createdAt: '2026-07-21T09:00:00.000Z',
            },
          ],
          total: 1,
          page: 1,
          limit: 25,
        }),
      );
    if (u.includes('/admin/admins')) return Promise.resolve(jsonOk([ADMIN]));
    return Promise.resolve(jsonOk({}));
  });
}

function Providers({
  children,
  authenticated = true,
}: {
  children: ReactNode;
  authenticated?: boolean;
}) {
  const auth = {
    admin: authenticated ? ADMIN : null,
    isAuthenticated: authenticated,
    isBootstrapping: false,
    mustEnrolTotp: false,
    expiringSoon: false,
    endedReason: null,
    login: vi.fn(),
    logout: vi.fn(),
    markTotpEnrolled: vi.fn(),
    can: () => true,
  } as unknown as AuthState;

  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return (
    <QueryClientProvider client={client}>
      <AuthContext.Provider value={auth}>
        <MemoryRouter>{children}</MemoryRouter>
      </AuthContext.Provider>
    </QueryClientProvider>
  );
}

afterEach(() => vi.unstubAllGlobals());

describe('accessibility — zero critical or serious violations', () => {
  const screens: [string, ReactNode][] = [
    ['Users', <UsersListPage key="u" />],
    ['Moderation queue', <ModerationQueuePage key="m" />],
    ['Analytics', <AnalyticsPage key="an" />],
    ['Audit log', <AuditPage key="au" />],
    ['Admins', <AdminsPage key="ad" />],
  ];

  for (const [name, element] of screens) {
    it(`${name} has no critical or serious violations`, async () => {
      vi.stubGlobal('fetch', mockAllApis());
      const { container } = render(<Providers>{element}</Providers>);
      // Let the first data render land, so the check covers real content.
      await screen.findAllByRole('heading');
      await expectNoA11yViolations(container);
    });
  }

  it('Login has no critical or serious violations', async () => {
    vi.stubGlobal('fetch', mockAllApis());
    // Signed out, or the page redirects away and renders nothing.
    const { container } = render(
      <Providers authenticated={false}>
        <LoginPage />
      </Providers>,
    );
    await screen.findByRole('heading', { name: /sign in/i });
    await expectNoA11yViolations(container);
  });

  it('a destructive confirmation dialog is accessible once open', async () => {
    const user = userEvent.setup();
    vi.stubGlobal('fetch', mockAllApis());
    const { container } = render(
      <Providers>
        <AdminsPage />
      </Providers>,
    );

    await screen.findByText('Ops Lead');
    await user.click(screen.getByRole('button', { name: /reset password/i }));
    await screen.findByRole('dialog');

    await expectNoA11yViolations(container);
  });
});

describe('keyboard operability', () => {
  it('every destructive action is reachable and dismissible by keyboard alone', async () => {
    const user = userEvent.setup();
    vi.stubGlobal('fetch', mockAllApis());
    render(
      <Providers>
        <AdminsPage />
      </Providers>,
    );

    await screen.findByText('Ops Lead');
    await user.click(screen.getByRole('button', { name: /reset password/i }));
    const dialog = await screen.findByRole('dialog');

    // Focus lands inside the dialog, not left behind on the page.
    expect(dialog.contains(document.activeElement)).toBe(true);

    // Escape closes it without a mouse.
    await user.keyboard('{Escape}');
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('Tab cannot walk out of an open dialog', async () => {
    const user = userEvent.setup();
    vi.stubGlobal('fetch', mockAllApis());
    render(
      <Providers>
        <AdminsPage />
      </Providers>,
    );

    await screen.findByText('Ops Lead');
    await user.click(screen.getByRole('button', { name: /reset password/i }));
    const dialog = await screen.findByRole('dialog');

    // Tab well past the dialog's own control count; focus must still be inside.
    // aria-modal tells assistive tech the rest is inert — only a trap makes
    // that true for the keyboard, and axe cannot detect the difference.
    for (let i = 0; i < 12; i++) await user.tab();
    expect(dialog.contains(document.activeElement)).toBe(true);

    // And backwards.
    for (let i = 0; i < 12; i++) await user.tab({ shift: true });
    expect(dialog.contains(document.activeElement)).toBe(true);
  });

  it('returns focus to the page when the dialog closes', async () => {
    const user = userEvent.setup();
    vi.stubGlobal('fetch', mockAllApis());
    render(
      <Providers>
        <AdminsPage />
      </Providers>,
    );

    await screen.findByText('Ops Lead');
    const trigger = screen.getByRole('button', { name: /reset password/i });
    await user.click(trigger);
    await screen.findByRole('dialog');
    await user.keyboard('{Escape}');

    // Focus goes back to what opened it, not to the top of the document.
    expect(document.activeElement).toBe(trigger);
  });
});
