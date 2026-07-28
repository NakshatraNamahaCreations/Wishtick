import { api } from './client';
import {
  authenticatedAdminSchema,
  loginResponseSchema,
  okSchema,
  totpSetupSchema,
  type LoginResponse,
  type TotpSetup,
  type AuthenticatedAdmin,
} from './schemas';

/** Typed wrappers over the admin API. One function per endpoint, no ad-hoc calls. */

export interface LoginInput {
  email: string;
  password: string;
  /** Only sent once the server has asked for it. */
  totp?: string;
}

export const authApi = {
  /** `POST /admin/auth/login` — open, throttled 10/60s. */
  login(input: LoginInput): Promise<LoginResponse> {
    return api.post('/admin/auth/login', {
      body: {
        email: input.email,
        password: input.password,
        // Omit entirely rather than sending an empty string: the DTO is
        // whitelisted and forbids unknown/invalid props.
        ...(input.totp ? { totp: input.totp } : {}),
      },
      schema: loginResponseSchema,
      skipAuth: true,
    });
  },

  /** `GET /admin/auth/me` — no permission required. Note: no name/status. */
  me(signal?: AbortSignal): Promise<AuthenticatedAdmin> {
    return api.get('/admin/auth/me', { schema: authenticatedAdminSchema, signal });
  },

  /** `POST /admin/auth/logout` — denylists the current jti. */
  logout(): Promise<{ ok: true }> {
    return api.post('/admin/auth/logout', { schema: okSchema });
  },

  /** `POST /admin/auth/totp/setup` — returns a pending secret + otpauth URI. */
  setupTotp(): Promise<TotpSetup> {
    return api.post('/admin/auth/totp/setup', { schema: totpSetupSchema });
  },

  /** `POST /admin/auth/totp/enable` — confirms the pending secret. */
  enableTotp(token: string): Promise<{ ok: true }> {
    return api.post('/admin/auth/totp/enable', { body: { token }, schema: okSchema });
  },
};
