import type { AdminView } from './schemas';

/**
 * Session storage for the admin token.
 *
 * WHY sessionStorage — the backend issues a bearer token with a 2h life and
 * NO refresh endpoint (see backend_api.md). That rules out the usual answers:
 *
 *   - in-memory only  → most XSS-resistant, but a page refresh logs the
 *                       operator out mid-incident. Hostile with no silent refresh.
 *   - localStorage    → survives reload but persists across tabs and restarts.
 *   - sessionStorage  → survives reload, dies with the tab. Chosen.
 *
 * sessionStorage is still XSS-readable. The mitigation is the strict CSP in
 * Sprint 6. The properly secure answer is an httpOnly cookie, which needs a
 * backend change — tracked as P2 in the backend recommendations.
 */

const TOKEN_KEY = 'wishtick.admin.token';
const EXPIRY_KEY = 'wishtick.admin.expiresAt';
const ADMIN_KEY = 'wishtick.admin.profile';

export interface StoredSession {
  token: string;
  /** Epoch ms. */
  expiresAt: number;
  /**
   * Cached from the login response. `GET /admin/auth/me` returns neither
   * `name` nor `status`, so without this the display name is lost on reload.
   */
  admin: AdminView;
}

function safeGet(key: string): string | null {
  try {
    return window.sessionStorage.getItem(key);
  } catch {
    return null;
  }
}

function safeSet(key: string, value: string): void {
  try {
    window.sessionStorage.setItem(key, value);
  } catch {
    /* Private mode or storage disabled — the session simply won't survive reload. */
  }
}

function safeRemove(key: string): void {
  try {
    window.sessionStorage.removeItem(key);
  } catch {
    /* no-op */
  }
}

export const tokenStore = {
  read(): StoredSession | null {
    const token = safeGet(TOKEN_KEY);
    const expiresAtRaw = safeGet(EXPIRY_KEY);
    const adminRaw = safeGet(ADMIN_KEY);
    if (!token || !expiresAtRaw || !adminRaw) return null;

    const expiresAt = Number(expiresAtRaw);
    if (!Number.isFinite(expiresAt)) return null;

    try {
      return { token, expiresAt, admin: JSON.parse(adminRaw) as AdminView };
    } catch {
      return null;
    }
  },

  write(session: StoredSession): void {
    safeSet(TOKEN_KEY, session.token);
    safeSet(EXPIRY_KEY, String(session.expiresAt));
    safeSet(ADMIN_KEY, JSON.stringify(session.admin));
  },

  clear(): void {
    safeRemove(TOKEN_KEY);
    safeRemove(EXPIRY_KEY);
    safeRemove(ADMIN_KEY);
  },

  /** The raw token for the Authorization header, or null. */
  token(): string | null {
    return safeGet(TOKEN_KEY);
  },
};

/** Milliseconds until expiry; negative once past. */
export function msUntilExpiry(session: StoredSession, now = Date.now()): number {
  return session.expiresAt - now;
}

export function isExpired(session: StoredSession, now = Date.now()): boolean {
  return msUntilExpiry(session, now) <= 0;
}
