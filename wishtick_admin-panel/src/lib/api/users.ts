import { api } from './client';
import {
  userDetailSchema,
  userAdminViewSchema,
  userListSchema,
  type UserDetail,
  type UserAdminView,
  type UserList,
} from './schemas';

/** Typed wrappers over `/admin/users`. */

export interface ListUsersParams {
  search?: string;
  /** `active | suspended | deleted` */
  status?: string;
  page?: number;
  /** Server clamps to 1–100; default 25. */
  limit?: number;
}

export const usersApi = {
  /** `GET /admin/users` — offset pagination, newest first. */
  list(params: ListUsersParams, signal?: AbortSignal): Promise<UserList> {
    return api.get('/admin/users', {
      schema: userListSchema,
      query: {
        search: params.search || undefined,
        status: params.status || undefined,
        page: params.page,
        limit: params.limit,
      },
      signal,
    });
  },

  /** `GET /admin/users/:id` — UserAdminView spread flat, plus counts + activity. */
  detail(id: string, signal?: AbortSignal): Promise<UserDetail> {
    return api.get(`/admin/users/${encodeURIComponent(id)}`, {
      schema: userDetailSchema,
      signal,
    });
  },

  /** `POST /admin/users/:id/suspend` — kills sessions and live sockets. */
  suspend(id: string, reason: string): Promise<UserAdminView> {
    return api.post(`/admin/users/${encodeURIComponent(id)}/suspend`, {
      body: { reason },
      schema: userAdminViewSchema,
    });
  },

  /** `POST /admin/users/:id/reactivate` */
  reactivate(id: string): Promise<UserAdminView> {
    return api.post(`/admin/users/${encodeURIComponent(id)}/reactivate`, {
      schema: userAdminViewSchema,
    });
  },

  /**
   * `POST /admin/users/:id/force-logout` — invalidates every session WITHOUT
   * suspending. The account stays active and they can sign straight back in.
   */
  forceLogout(id: string): Promise<UserAdminView> {
    return api.post(`/admin/users/${encodeURIComponent(id)}/force-logout`, {
      schema: userAdminViewSchema,
    });
  },
};
