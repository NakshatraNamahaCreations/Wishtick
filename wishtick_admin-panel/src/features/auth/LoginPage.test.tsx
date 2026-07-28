import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider } from './auth-context';
import { LoginPage } from './LoginPage';
import { tokenStore } from '@/lib/api/token-store';

function renderLogin() {
  return render(
    <MemoryRouter initialEntries={['/login']}>
      <AuthProvider>
        <LoginPage />
      </AuthProvider>
    </MemoryRouter>,
  );
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

const ADMIN = {
  id: 'a1',
  email: 'ops@wishtick.com',
  name: 'Ops Lead',
  roles: ['super_admin'],
  permissions: ['users:view'],
  status: 'active',
  totpEnabled: true,
  ipAllowlist: [],
  lastLoginAt: null,
  createdAt: '2026-01-01T00:00:00.000Z',
};

afterEach(() => {
  vi.unstubAllGlobals();
  tokenStore.clear();
});

describe('the TOTP challenge', () => {
  it('treats ADMIN_TOTP_REQUIRED as a step forward, keeping the credentials', async () => {
    const user = userEvent.setup();
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        jsonResponse(
          { success: false, error: { code: 'ADMIN_TOTP_REQUIRED', message: 'A 2FA code is required' } },
          401,
        ),
      ),
    );

    renderLogin();

    await user.type(screen.getByLabelText(/email/i), 'ops@wishtick.com');
    await user.type(screen.getByLabelText('Password'), 'hunter2hunter2');
    await user.click(screen.getByRole('button', { name: /sign in/i }));

    // The code field appears...
    const codeField = await screen.findByLabelText(/authentication code/i);
    expect(codeField).toBeInTheDocument();

    // ...the credentials survive, so nobody retypes a password to add a code...
    expect(screen.getByLabelText(/email/i)).toHaveValue('ops@wishtick.com');
    expect(screen.getByLabelText('Password')).toHaveValue('hunter2hunter2');

    // ...and it is NOT presented as an error.
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });

  it('clears only the code when the code itself is wrong', async () => {
    const user = userEvent.setup();
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(
        jsonResponse(
          { success: false, error: { code: 'ADMIN_TOTP_REQUIRED', message: 'required' } },
          401,
        ),
      )
      .mockResolvedValueOnce(
        jsonResponse(
          { success: false, error: { code: 'ADMIN_TOTP_INVALID', message: 'Invalid 2FA code' } },
          401,
        ),
      );
    vi.stubGlobal('fetch', fetchMock);

    renderLogin();
    await user.type(screen.getByLabelText(/email/i), 'ops@wishtick.com');
    await user.type(screen.getByLabelText('Password'), 'hunter2hunter2');
    await user.click(screen.getByRole('button', { name: /sign in/i }));

    const codeField = await screen.findByLabelText(/authentication code/i);
    await user.type(codeField, '000000');
    await user.click(screen.getByRole('button', { name: /verify and sign in/i }));

    await screen.findByRole('alert');
    expect(screen.getByLabelText(/authentication code/i)).toHaveValue('');
    expect(screen.getByLabelText('Password')).toHaveValue('hunter2hunter2');
  });
});

describe('failed sign-in', () => {
  it('explains a bad credential in operator language', async () => {
    const user = userEvent.setup();
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        jsonResponse(
          { success: false, error: { code: 'ADMIN_CREDENTIALS_INVALID', message: 'Invalid credentials' } },
          401,
        ),
      ),
    );

    renderLogin();
    await user.type(screen.getByLabelText(/email/i), 'ops@wishtick.com');
    await user.type(screen.getByLabelText('Password'), 'wrong');
    await user.click(screen.getByRole('button', { name: /sign in/i }));

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent(/do not match/i);
  });
});

describe('a successful sign-in', () => {
  it('stores the session with an absolute expiry derived from expiresInSeconds', async () => {
    const user = userEvent.setup();
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        jsonResponse({
          success: true,
          data: {
            accessToken: 'tok-abc',
            expiresInSeconds: 7200,
            admin: ADMIN,
            setupRequired: false,
          },
        }),
      ),
    );

    renderLogin();
    await user.type(screen.getByLabelText(/email/i), 'ops@wishtick.com');
    await user.type(screen.getByLabelText('Password'), 'hunter2hunter2');
    await user.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      const stored = tokenStore.read();
      expect(stored?.token).toBe('tok-abc');
      // ~2h out, not a raw duration.
      expect(stored!.expiresAt).toBeGreaterThan(Date.now() + 7_000_000);
    });
  });
});
