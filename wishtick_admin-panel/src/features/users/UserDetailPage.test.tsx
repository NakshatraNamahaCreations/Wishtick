import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { UserDetailPage } from './UserDetailPage';
import { AuthContext, type AuthState } from '@/features/auth/auth-types';
import type { AdminPermission } from '@/lib/api/schemas';

const DETAIL = {
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
  lastLoginAt: '2026-07-20T21:14:00.000Z',
  createdAt: '2026-03-02T08:00:00.000Z',
  counts: { wishlists: 4, events: 2, giftsGiven: 7, giftsReceived: 3, reels: 1 },
  activity: [{ type: 'gift', at: '2026-07-19T10:00:00.000Z', summary: 'Gift fulfilled' }],
};

function jsonOk(data: unknown) {
  return new Response(JSON.stringify({ success: true, data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

function renderDetail(permissions: AdminPermission[]) {
  const auth = {
    admin: null,
    isAuthenticated: true,
    isBootstrapping: false,
    mustEnrolTotp: false,
    expiringSoon: false,
    endedReason: null,
    login: vi.fn(),
    logout: vi.fn(),
    markTotpEnrolled: vi.fn(),
    can: (permission: AdminPermission) => permissions.includes(permission),
  } as unknown as AuthState;

  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });

  return render(
    <QueryClientProvider client={client}>
      <AuthContext.Provider value={auth}>
        <MemoryRouter initialEntries={['/users/u1']}>
          <Routes>
            <Route path="/users/:id" element={<UserDetailPage />} />
            <Route path="/users" element={<div>list page</div>} />
          </Routes>
        </MemoryRouter>
      </AuthContext.Provider>
    </QueryClientProvider>,
  );
}

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(jsonOk(DETAIL)));
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('permission gating', () => {
  it('offers actions to an admin with users:manage', async () => {
    renderDetail(['users:view', 'users:manage']);
    expect(await screen.findByRole('button', { name: /suspend account/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /force sign-out/i })).toBeInTheDocument();
  });

  it('hides them from a read-only admin and says why', async () => {
    renderDetail(['users:view']);
    await screen.findByText('Asha R');

    expect(screen.queryByRole('button', { name: /suspend account/i })).not.toBeInTheDocument();
    // Absent, not disabled-and-mysterious — with an explanation.
    expect(screen.getByText(/read-only access/i)).toBeInTheDocument();
  });
});

describe('suspending', () => {
  it('states the real consequence rather than "are you sure?"', async () => {
    const user = userEvent.setup();
    renderDetail(['users:view', 'users:manage']);

    await user.click(await screen.findByRole('button', { name: /suspend account/i }));

    const dialog = await screen.findByRole('dialog');
    expect(dialog).toHaveTextContent(/signed out of every device/i);
    expect(dialog).toHaveTextContent(/not be able to sign in again/i);
  });

  it('sends the reason to the suspend endpoint', async () => {
    const user = userEvent.setup();
    const fetchMock = vi.fn().mockResolvedValue(jsonOk(DETAIL));
    vi.stubGlobal('fetch', fetchMock);

    renderDetail(['users:view', 'users:manage']);
    await user.click(await screen.findByRole('button', { name: /suspend account/i }));

    await user.type(screen.getByLabelText(/reason/i), 'Repeated harassment');
    // Scope to the dialog — the page's trigger button carries the same label.
    const dialog = screen.getByRole('dialog');
    await user.click(within(dialog).getByRole('button', { name: /^suspend account$/i }));

    await waitFor(() => {
      const suspendCall = fetchMock.mock.calls.find((call) =>
        String(call[0]).includes('/suspend'),
      );
      expect(suspendCall).toBeDefined();
      const body = JSON.parse((suspendCall?.[1] as RequestInit).body as string) as {
        reason: string;
      };
      expect(body.reason).toBe('Repeated harassment');
    });
  });
});

describe('honesty about the activity list', () => {
  it('warns that recent activity is a sample, not a full history', async () => {
    renderDetail(['users:view']);
    expect(await screen.findByText(/a sample, not a full history/i)).toBeInTheDocument();
  });
});

describe('force sign-out', () => {
  it('makes clear the account stays active', async () => {
    const user = userEvent.setup();
    renderDetail(['users:view', 'users:manage']);

    await user.click(await screen.findByRole('button', { name: /force sign-out/i }));

    const dialog = await screen.findByRole('dialog');
    expect(dialog).toHaveTextContent(/stays/i);
    expect(dialog).toHaveTextContent(/sign straight back in/i);
  });
});
