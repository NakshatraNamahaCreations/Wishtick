import { afterEach, describe, expect, it, vi } from 'vitest';
import { z } from 'zod';
import { request, setUnauthorizedHandler } from './client';
import { ApiError, NetworkError, SchemaError, messageFor } from './errors';
import { tokenStore } from './token-store';

const schema = z.object({ id: z.string() });

function mockFetch(body: unknown, init: { status?: number; headers?: Record<string, string> } = {}) {
  const response = new Response(JSON.stringify(body), {
    status: init.status ?? 200,
    headers: { 'Content-Type': 'application/json', ...init.headers },
  });
  const spy = vi.fn().mockResolvedValue(response);
  vi.stubGlobal('fetch', spy);
  return spy;
}

afterEach(() => {
  vi.unstubAllGlobals();
  setUnauthorizedHandler(null);
  tokenStore.clear();
});

describe('the success envelope', () => {
  it('unwraps `data` rather than returning the envelope', async () => {
    mockFetch({ success: true, data: { id: 'abc' }, timestamp: 'x' });
    await expect(request('/thing', { schema })).resolves.toEqual({ id: 'abc' });
  });

  it('rejects a payload that does not match the schema', async () => {
    mockFetch({ success: true, data: { id: 42 } });
    await expect(request('/thing', { schema })).rejects.toBeInstanceOf(SchemaError);
  });
});

describe('the error envelope', () => {
  it('reads error.code — not a top-level errorCode', async () => {
    mockFetch(
      { success: false, error: { code: 'ADMIN_TOTP_REQUIRED', message: 'A 2FA code is required' } },
      { status: 401 },
    );

    const error = await request('/admin/auth/login', { schema, skipAuth: true }).catch(
      (e: unknown) => e,
    );

    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).code).toBe('ADMIN_TOTP_REQUIRED');
    expect((error as ApiError).status).toBe(401);
  });

  it('carries details through for field-level validation errors', async () => {
    mockFetch(
      {
        success: false,
        error: {
          code: 'VALIDATION_FAILED',
          message: 'Request validation failed',
          details: { fields: ['email must be an email'] },
        },
      },
      { status: 400 },
    );

    const error = (await request('/x', { schema }).catch((e: unknown) => e)) as ApiError;
    expect(error.details).toEqual({ fields: ['email must be an email'] });
  });

  it('falls back to HTTP_<status> when the body is not the expected shape', async () => {
    mockFetch('<html>502</html>', { status: 502 });
    const error = (await request('/x', { schema }).catch((e: unknown) => e)) as ApiError;
    expect(error.code).toBe('HTTP_502');
  });

  it('surfaces the requestId so support can correlate it', async () => {
    mockFetch(
      { success: false, error: { code: 'INTERNAL_ERROR', message: 'boom' } },
      { status: 500, headers: { 'X-Request-Id': 'req-123' } },
    );
    const error = (await request('/x', { schema }).catch((e: unknown) => e)) as ApiError;
    expect(error.requestId).toBe('req-123');
  });

  it('reports an unreachable server as a NetworkError, not a crash', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('failed')));
    await expect(request('/x', { schema })).rejects.toBeInstanceOf(NetworkError);
  });
});

describe('headers', () => {
  it('attaches the bearer token and a request id', async () => {
    tokenStore.write({
      token: 'tok-1',
      expiresAt: Date.now() + 60_000,
      admin: { permissions: [] } as never,
    });
    const spy = mockFetch({ success: true, data: { id: 'a' } });

    await request('/x', { schema });

    const headers = (spy.mock.calls[0]?.[1] as RequestInit).headers as Record<string, string>;
    expect(headers.Authorization).toBe('Bearer tok-1');
    expect(headers['X-Request-Id']).toBeTruthy();
  });

  it('omits the token on login, which is an open route', async () => {
    tokenStore.write({
      token: 'tok-1',
      expiresAt: Date.now() + 60_000,
      admin: { permissions: [] } as never,
    });
    const spy = mockFetch({ success: true, data: { id: 'a' } });

    await request('/admin/auth/login', { schema, skipAuth: true });

    const headers = (spy.mock.calls[0]?.[1] as RequestInit).headers as Record<string, string>;
    expect(headers.Authorization).toBeUndefined();
  });
});

describe('401 handling', () => {
  it('notifies the auth layer exactly once so no caller has to', async () => {
    const onUnauthorized = vi.fn();
    setUnauthorizedHandler(onUnauthorized);
    mockFetch(
      { success: false, error: { code: 'ADMIN_UNAUTHENTICATED', message: 'ended' } },
      { status: 401 },
    );

    await request('/x', { schema }).catch(() => undefined);

    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });

  it('does not fire on a failed login — there was no session to lose', async () => {
    const onUnauthorized = vi.fn();
    setUnauthorizedHandler(onUnauthorized);
    mockFetch(
      { success: false, error: { code: 'ADMIN_CREDENTIALS_INVALID', message: 'nope' } },
      { status: 401 },
    );

    await request('/admin/auth/login', { schema, skipAuth: true }).catch(() => undefined);

    expect(onUnauthorized).not.toHaveBeenCalled();
  });
});

describe('operator-facing copy', () => {
  it('maps a known code to guidance rather than echoing the server', () => {
    const error = new ApiError({
      code: 'ADMIN_TOTP_INVALID',
      message: 'Invalid 2FA code',
      status: 401,
    });
    expect(messageFor(error)).toContain('30 seconds');
  });

  it('falls back to the server message for an unmapped code', () => {
    const error = new ApiError({ code: 'HTTP_418', message: 'I am a teapot', status: 418 });
    expect(messageFor(error)).toBe('I am a teapot');
  });
});
