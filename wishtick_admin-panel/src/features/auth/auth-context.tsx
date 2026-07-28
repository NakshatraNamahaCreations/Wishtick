import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { setUnauthorizedHandler } from '@/lib/api/client';
import { authApi, type LoginInput } from '@/lib/api/endpoints';
import { ApiError } from '@/lib/api/errors';
import { isExpired, msUntilExpiry, tokenStore, type StoredSession } from '@/lib/api/token-store';
import type { AdminPermission, LoginResponse } from '@/lib/api/schemas';
import { AuthContext, type AuthState, type SessionEndReason } from './auth-types';

/** Warn this long before the token dies. */
const EXPIRY_WARNING_MS = 5 * 60 * 1000;

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<StoredSession | null>(() => {
    const stored = tokenStore.read();
    if (!stored || isExpired(stored)) {
      if (stored) tokenStore.clear();
      return null;
    }
    return stored;
  });
  const [isBootstrapping, setBootstrapping] = useState(session !== null);
  const [mustEnrolTotp, setMustEnrolTotp] = useState(false);
  const [expiringSoon, setExpiringSoon] = useState(false);
  const [endedReason, setEndedReason] = useState<SessionEndReason | null>(null);

  const endSession = useCallback((reason: SessionEndReason) => {
    tokenStore.clear();
    setSession(null);
    setMustEnrolTotp(false);
    setExpiringSoon(false);
    setEndedReason(reason);
  }, []);

  // A 401 from anywhere means the token is dead. Registered once; no caller
  // has to remember to handle it.
  useEffect(() => {
    setUnauthorizedHandler(() => endSession('rejected'));
    return () => setUnauthorizedHandler(null);
  }, [endSession]);

  // Validate a restored token before trusting it. Without this, a reload with a
  // revoked token renders the whole shell and then 401s on first data fetch.
  const bootstrapped = useRef(false);
  useEffect(() => {
    if (bootstrapped.current || !session) {
      setBootstrapping(false);
      return;
    }
    bootstrapped.current = true;

    const controller = new AbortController();
    authApi
      .me(controller.signal)
      .then(() => setBootstrapping(false))
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === 'AbortError') return;
        // The 401 path already ended the session via the handler above.
        if (!(error instanceof ApiError && error.status === 401)) {
          endSession('rejected');
        }
        setBootstrapping(false);
      });

    return () => controller.abort();
  }, [session, endSession]);

  // Hard expiry + advance warning. The backend has no refresh endpoint, so this
  // is a countdown to a real logout, not a prompt we can silently resolve.
  useEffect(() => {
    if (!session) return;

    const remaining = msUntilExpiry(session);
    if (remaining <= 0) {
      endSession('expired');
      return;
    }

    setExpiringSoon(remaining <= EXPIRY_WARNING_MS);

    const timers: ReturnType<typeof setTimeout>[] = [];
    if (remaining > EXPIRY_WARNING_MS) {
      timers.push(setTimeout(() => setExpiringSoon(true), remaining - EXPIRY_WARNING_MS));
    }
    timers.push(setTimeout(() => endSession('expired'), remaining));

    return () => timers.forEach(clearTimeout);
  }, [session, endSession]);

  const login = useCallback(async (input: LoginInput): Promise<LoginResponse> => {
    const result = await authApi.login(input);

    const next: StoredSession = {
      token: result.accessToken,
      expiresAt: Date.now() + result.expiresInSeconds * 1000,
      admin: result.admin,
    };
    tokenStore.write(next);

    setSession(next);
    setEndedReason(null);
    setBootstrapping(false);
    bootstrapped.current = true;
    // 2FA enrolment is not enforced: the server issues a working token password-only
    // (it only demands a TOTP code at login for an admin who has *already* enabled
    // one), so we never force the setup screen. `setupRequired` is ignored on purpose.
    setMustEnrolTotp(false);

    return result;
  }, []);

  const logout = useCallback(async () => {
    try {
      await authApi.logout();
    } catch {
      // Best-effort: a failed logout still ends the session locally. Leaving
      // the operator signed in because the network blipped is the worse outcome.
    }
    endSession('logout');
  }, [endSession]);

  const markTotpEnrolled = useCallback(() => {
    setMustEnrolTotp(false);
    setSession((current) => {
      if (!current) return current;
      const updated: StoredSession = {
        ...current,
        admin: { ...current.admin, totpEnabled: true },
      };
      tokenStore.write(updated);
      return updated;
    });
  }, []);

  const can = useCallback(
    (permission: AdminPermission) => session?.admin.permissions.includes(permission) ?? false,
    [session],
  );

  const value = useMemo<AuthState>(
    () => ({
      admin: session?.admin ?? null,
      isAuthenticated: session !== null,
      isBootstrapping,
      mustEnrolTotp,
      expiringSoon,
      endedReason,
      login,
      logout,
      markTotpEnrolled,
      can,
    }),
    [
      session,
      isBootstrapping,
      mustEnrolTotp,
      expiringSoon,
      endedReason,
      login,
      logout,
      markTotpEnrolled,
      can,
    ],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
