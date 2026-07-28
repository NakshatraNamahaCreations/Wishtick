import { api } from './client';
import {
  adminViewSchema,
  auditActionsSchema,
  auditPageSchema,
  type AdminRole,
  type AdminView,
  type AuditPage,
} from './schemas';

/** Typed wrappers over admin management and the audit trail. */

export interface CreateAdminInput {
  email: string;
  password: string;
  name: string;
  roles: AdminRole[];
  ipAllowlist?: string[];
}

export interface UpdateAdminInput {
  name?: string;
  roles?: AdminRole[];
  status?: 'active' | 'disabled';
  ipAllowlist?: string[];
}

export const adminsApi = {
  /** `GET /admin/admins` — a bare array, no pagination. */
  list(signal?: AbortSignal): Promise<AdminView[]> {
    return api.get('/admin/admins', { schema: adminViewSchema.array(), signal });
  },

  /** `POST /admin/admins` */
  create(input: CreateAdminInput): Promise<AdminView> {
    return api.post('/admin/admins', {
      body: {
        ...input,
        // The DTO is whitelisted, so an empty array is fine but undefined must
        // be omitted entirely rather than sent as null.
        ...(input.ipAllowlist?.length ? { ipAllowlist: input.ipAllowlist } : {}),
      },
      schema: adminViewSchema,
    });
  },

  /** `PATCH /admin/admins/:id` — name, roles, status, or IP allowlist. */
  update(id: string, input: UpdateAdminInput): Promise<AdminView> {
    return api.patch(`/admin/admins/${encodeURIComponent(id)}`, {
      body: input,
      schema: adminViewSchema,
    });
  },

  /** `POST /admin/admins/:id/password` — also ends every session they hold. */
  resetPassword(id: string, password: string): Promise<AdminView> {
    return api.post(`/admin/admins/${encodeURIComponent(id)}/password`, {
      body: { password },
      schema: adminViewSchema,
    });
  },
};

export interface AuditParams {
  targetType?: string;
  targetId?: string;
  action?: string;
  actorAdminId?: string;
  /** Inclusive UTC day bounds, `YYYY-MM-DD`. */
  from?: string;
  to?: string;
  page?: number;
  /** Server clamps to 1–500; default 50. */
  limit?: number;
}

export const auditApi = {
  /** `GET /admin/audit` — newest first. */
  list(params: AuditParams, signal?: AbortSignal): Promise<AuditPage> {
    return api.get('/admin/audit', {
      schema: auditPageSchema,
      query: {
        targetType: params.targetType || undefined,
        targetId: params.targetId || undefined,
        action: params.action || undefined,
        actorAdminId: params.actorAdminId || undefined,
        from: params.from || undefined,
        to: params.to || undefined,
        page: params.page,
        limit: params.limit,
      },
      signal,
    });
  },

  /** `GET /admin/audit/actions` — distinct action names, for the filter. */
  actions(signal?: AbortSignal): Promise<string[]> {
    return api.get('/admin/audit/actions', { schema: auditActionsSchema, signal });
  },
};
