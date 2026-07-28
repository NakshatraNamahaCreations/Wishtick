import type { z } from 'zod';
import { ApiError, NetworkError, SchemaError } from './errors';
import { tokenStore } from './token-store';

/**
 * The one place that talks to the network.
 *
 * Nothing else in the app calls `fetch`. This unwraps the `{ success, data }`
 * envelope, normalizes every failure into an ApiError, attaches auth and a
 * request id, and parses the payload through a Zod schema.
 */

const RAW_BASE = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000';
/** The backend mounts everything under the global prefix + URI version. */
export const API_BASE = `${RAW_BASE.replace(/\/+$/, '')}/api/v1`;

/**
 * Notified whenever the server rejects our token, so the auth layer can bounce
 * to login. The client itself must not know about the router.
 */
type UnauthorizedHandler = () => void;
let onUnauthorized: UnauthorizedHandler | null = null;

export function setUnauthorizedHandler(handler: UnauthorizedHandler | null): void {
  onUnauthorized = handler;
}

function newRequestId(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
  return `req-${Date.now()}-${Math.floor(Math.random() * 1e9)}`;
}

interface RequestOptions<TSchema extends z.ZodType> {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  body?: unknown;
  schema: TSchema;
  query?: Record<string, string | number | undefined>;
  /** Login is the only route with no token. */
  skipAuth?: boolean;
  signal?: AbortSignal;
}

function buildUrl(path: string, query?: RequestOptions<z.ZodType>['query']): string {
  const url = new URL(`${API_BASE}${path}`);
  if (query) {
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined && value !== '') url.searchParams.set(key, String(value));
    }
  }
  return url.toString();
}

/** Pulls `error.code` / `error.message` out of a failure body, tolerating garbage. */
function parseErrorBody(
  body: unknown,
  status: number,
): { code: string; message: string; details?: unknown } {
  if (body && typeof body === 'object' && 'error' in body) {
    const err = body.error;
    if (err && typeof err === 'object') {
      const e = err as { code?: unknown; message?: unknown; details?: unknown };
      return {
        code: typeof e.code === 'string' ? e.code : `HTTP_${status}`,
        message: typeof e.message === 'string' ? e.message : `Request failed (${status})`,
        details: e.details,
      };
    }
  }
  return { code: `HTTP_${status}`, message: `Request failed (${status})` };
}

export async function request<TSchema extends z.ZodType>(
  path: string,
  options: RequestOptions<TSchema>,
): Promise<z.infer<TSchema>> {
  const { method = 'GET', body, schema, query, skipAuth = false, signal } = options;

  const headers: Record<string, string> = {
    Accept: 'application/json',
    'X-Request-Id': newRequestId(),
  };

  if (body !== undefined) headers['Content-Type'] = 'application/json';

  if (!skipAuth) {
    const token = tokenStore.token();
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  // Fail fast when the browser already knows there is no network — a fetch
  // that will never leave the machine should not look like a server problem.
  if (typeof navigator !== 'undefined' && navigator.onLine === false) {
    throw new NetworkError('You appear to be offline');
  }

  let response: Response;
  try {
    response = await fetch(buildUrl(path, query), {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal,
    });
  } catch (cause) {
    if (cause instanceof DOMException && cause.name === 'AbortError') throw cause;
    throw new NetworkError();
  }

  const requestId = response.headers.get('X-Request-Id') ?? undefined;

  let payload: unknown = null;
  const text = await response.text();
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = null;
    }
  }

  if (!response.ok) {
    const { code, message, details } = parseErrorBody(payload, response.status);

    // A rejected token means the session is over. Tell the auth layer once,
    // here, so no caller has to remember to handle it.
    if (response.status === 401 && !skipAuth) onUnauthorized?.();

    const retryAfter = Number(response.headers.get('Retry-After'));

    throw new ApiError({
      code,
      message,
      status: response.status,
      details,
      requestId,
      ...(Number.isFinite(retryAfter) && retryAfter > 0
        ? { retryAfterSeconds: Math.ceil(retryAfter) }
        : {}),
    });
  }

  // Success envelope: the handler's return value sits whole at `data`.
  const data =
    payload && typeof payload === 'object' && 'data' in payload
      ? payload.data
      : payload;

  const parsed = schema.safeParse(data);
  if (!parsed.success) {
    throw new SchemaError(path, parsed.error.issues);
  }
  return parsed.data as z.infer<TSchema>;
}

export const api = {
  get: <T extends z.ZodType>(path: string, opts: Omit<RequestOptions<T>, 'method' | 'body'>) =>
    request(path, { ...opts, method: 'GET' }),
  post: <T extends z.ZodType>(path: string, opts: Omit<RequestOptions<T>, 'method'>) =>
    request(path, { ...opts, method: 'POST' }),
  patch: <T extends z.ZodType>(path: string, opts: Omit<RequestOptions<T>, 'method'>) =>
    request(path, { ...opts, method: 'PATCH' }),
};
