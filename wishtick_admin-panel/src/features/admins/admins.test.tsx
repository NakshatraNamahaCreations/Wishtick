import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AdminsPage } from './AdminsPage';
import { AuthContext, type AuthState } from '@/features/auth/auth-types';
import type { AdminView } from '@/lib/api/schemas';

function makeAdmin(overrides: Partial<AdminView> = {}): AdminView {
  return {
    id: 'a1',
    email: 'ops@wishtick.com',
    name: 'Ops Lead',
    roles: ['super_admin'],
    permissions: ['admins:manage'],
    status: 'active',
    totpEnabled: true,
    ipAllowlist: [],
    lastLoginAt: '2026-07-21T09:00:00.000Z',
    createdAt: '2026-01-01T00:00:00.000Z',
    ...overrides,
  };
}

function jsonOk(data: unknown, status = 200) {
  return new Response(JSON.stringify({ success: true, data }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function jsonErr(code: string, message: string, status: number) {
  return new Response(JSON.stringify({ success: false, error: { code, message } }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function renderPage(admins: AdminView[], selfId = 'a1', fetchImpl?: ReturnType<typeof vi.fn>) {
  vi.stubGlobal('fetch', fetchImpl ?? vi.fn().mockResolvedValue(jsonOk(admins)));

  const auth = {
    admin: makeAdmin({ id: selfId }),
    isAuthenticated: true,
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
  return render(
    <QueryClientProvider client={client}>
      <AuthContext.Provider value={auth}>
        <MemoryRouter>
          <AdminsPage />
        </MemoryRouter>
      </AuthContext.Provider>
    </QueryClientProvider>,
  );
}

afterEach(() => vi.unstubAllGlobals());

describe('self-lockout protection', () => {
  it('disables the Disable button on your own account', async () => {
    renderPage([makeAdmin({ id: 'a1', name: 'Ops Lead' })], 'a1');
    await screen.findByText('Ops Lead');

    // Absent-or-disabled beats letting someone discover the rule via a 403.
    const disableButton = screen.getByRole('button', { name: /disable/i });
    expect(disableButton).toBeDisabled();
  });

  it('allows disabling somebody else', async () => {
    renderPage(
      [makeAdmin({ id: 'a1' }), makeAdmin({ id: 'a2', name: 'Mod Two', email: 'mod@x.com' })],
      'a1',
    );
    await screen.findByText('Mod Two');

    const buttons = screen.getAllByRole('button', { name: /disable/i });
    expect(buttons.some((button) => !(button as HTMLButtonElement).disabled)).toBe(true);
  });

  it('warns before you strip your own super-admin role', async () => {
    const user = userEvent.setup();
    renderPage([makeAdmin({ id: 'a1', roles: ['super_admin'] })], 'a1');
    await screen.findByText('Ops Lead');

    await user.click(screen.getByRole('button', { name: /^edit$/i }));
    const dialog = await screen.findByRole('dialog');

    // At least one role is required, so super-admin can only be dropped after
    // another role is added — which is the real flow an operator would take.
    await user.click(within(dialog).getByRole('checkbox', { name: /support/i }));
    await user.click(within(dialog).getByRole('checkbox', { name: /super admin/i }));

    expect(dialog).toHaveTextContent(/cannot remove your own super-admin role/i);
  });

  it('surfaces the last-super-admin refusal as guidance, not a raw error', async () => {
    const user = userEvent.setup();
    const fetchMock = vi.fn().mockImplementation((_url: string, init?: RequestInit) => {
      if (init?.method === 'PATCH') {
        return Promise.resolve(
          jsonErr('ADMIN_FORBIDDEN', 'This is the last active super-admin.', 409),
        );
      }
      return Promise.resolve(
        jsonOk([makeAdmin({ id: 'a1' }), makeAdmin({ id: 'a2', name: 'Other', email: 'o@x.com' })]),
      );
    });
    renderPage([], 'a1', fetchMock);
    await screen.findByText('Other');

    const disableButtons = screen.getAllByRole('button', { name: /disable/i });
    await user.click(disableButtons.find((b) => !(b as HTMLButtonElement).disabled)!);
    const dialog = await screen.findByRole('dialog');
    await user.click(within(dialog).getByRole('button', { name: /disable account/i }));

    expect(await screen.findByText(/promote another admin to super-admin first/i)).toBeInTheDocument();
  });
});

describe('IP allowlist', () => {
  it('rejects CIDR, which would silently match nothing and lock the admin out', async () => {
    const user = userEvent.setup();
    renderPage([makeAdmin({ id: 'a1' })], 'a1');
    await screen.findByText('Ops Lead');

    await user.click(screen.getByRole('button', { name: /add admin/i }));
    const dialog = await screen.findByRole('dialog');
    await user.type(within(dialog).getByLabelText(/ip allowlist/i), '10.0.0.0/8');

    expect(dialog).toHaveTextContent(/CIDR ranges are not supported/i);
    expect(dialog).toHaveTextContent(/lock this admin out/i);
  });
});

describe('offboarding', () => {
  it('explains that accounts are disabled, never deleted', async () => {
    renderPage([makeAdmin()], 'a1');
    expect(await screen.findByText(/there is no delete/i)).toBeInTheDocument();
    expect(screen.getByText(/orphan every audit entry/i)).toBeInTheDocument();
  });

  it('states that a password reset ends every session', async () => {
    const user = userEvent.setup();
    renderPage([makeAdmin({ id: 'a1' })], 'a1');
    await screen.findByText('Ops Lead');

    await user.click(screen.getByRole('button', { name: /reset password/i }));
    const dialog = await screen.findByRole('dialog');
    expect(dialog).toHaveTextContent(/every session .* ends immediately/i);
    expect(dialog).toHaveTextContent(/never written to the audit log/i);
  });
});

describe('creating an admin', () => {
  it('sends the chosen roles', async () => {
    const user = userEvent.setup();
    const fetchMock = vi.fn().mockImplementation((_url: string, init?: RequestInit) => {
      if (init?.method === 'POST') return Promise.resolve(jsonOk(makeAdmin(), 201));
      return Promise.resolve(jsonOk([makeAdmin({ id: 'a1' })]));
    });
    renderPage([], 'a1', fetchMock);
    await screen.findByText('Ops Lead');

    await user.click(screen.getByRole('button', { name: /add admin/i }));
    const dialog = await screen.findByRole('dialog');
    await user.type(within(dialog).getByLabelText(/^email$/i), 'new@wishtick.com');
    await user.type(within(dialog).getByLabelText(/^name$/i), 'New Admin');
    await user.type(within(dialog).getByLabelText(/^password$/i), 'a-long-enough-pass');
    await user.click(within(dialog).getByRole('button', { name: /create admin/i }));

    await waitFor(() => {
      const post = fetchMock.mock.calls.find((c) => (c[1] as RequestInit)?.method === 'POST');
      expect(post).toBeDefined();
      const body = JSON.parse((post?.[1] as RequestInit).body as string) as { roles: string[] };
      expect(body.roles).toEqual(['moderator']);
    });
  });
});
