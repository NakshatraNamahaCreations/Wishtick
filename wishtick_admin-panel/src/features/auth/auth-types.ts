import { createContext } from 'react';
import type { LoginInput } from '@/lib/api/endpoints';
import type { AdminPermission, AdminView, LoginResponse } from '@/lib/api/schemas';

/**
 * Context and types live apart from the provider component so that file can
 * export only components — otherwise React Fast Refresh silently stops working
 * for the whole auth tree.
 */

export type SessionEndReason = 'expired' | 'logout' | 'rejected';

export interface AuthState {
  admin: AdminView | null;
  isAuthenticated: boolean;
  /** True until the stored session has been validated against the server. */
  isBootstrapping: boolean;
  /**
   * The server issues a working token even when 2FA is not yet enrolled and
   * does NOT restrict it. Gating the app is the panel's job.
   */
  mustEnrolTotp: boolean;
  /** Fires ~5 min out so the operator can save work before the hard cutoff. */
  expiringSoon: boolean;
  /** Set when a session ended, so the login screen can explain why. */
  endedReason: SessionEndReason | null;
  login: (input: LoginInput) => Promise<LoginResponse>;
  logout: () => Promise<void>;
  /** Called after TOTP enrolment succeeds, to lift the gate. */
  markTotpEnrolled: () => void;
  can: (permission: AdminPermission) => boolean;
}

export const AuthContext = createContext<AuthState | null>(null);
