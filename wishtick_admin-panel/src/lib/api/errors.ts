/**
 * The backend's error contract.
 *
 * Every 4xx/5xx body is `{ success: false, error: { code, message, details? } }`.
 * Note it is `error.code`, NOT a top-level `errorCode`, and there is no
 * `statusCode` in the body — the status lives only on the status line.
 */

/** Codes the admin panel can actually receive. Backend treats these as append-only. */
export const ErrorCode = {
  // Admin auth
  ADMIN_UNAUTHENTICATED: 'ADMIN_UNAUTHENTICATED',
  ADMIN_FORBIDDEN: 'ADMIN_FORBIDDEN',
  ADMIN_NOT_FOUND: 'ADMIN_NOT_FOUND',
  ADMIN_CREDENTIALS_INVALID: 'ADMIN_CREDENTIALS_INVALID',
  ADMIN_TOTP_REQUIRED: 'ADMIN_TOTP_REQUIRED',
  ADMIN_TOTP_INVALID: 'ADMIN_TOTP_INVALID',
  ADMIN_TOTP_ALREADY_ENABLED: 'ADMIN_TOTP_ALREADY_ENABLED',
  ADMIN_IP_NOT_ALLOWED: 'ADMIN_IP_NOT_ALLOWED',
  ADMIN_DISABLED: 'ADMIN_DISABLED',
  // Moderation
  REPORT_NOT_FOUND: 'REPORT_NOT_FOUND',
  REPORT_ALREADY_HANDLED: 'REPORT_ALREADY_HANDLED',
  // Generic
  VALIDATION_FAILED: 'VALIDATION_FAILED',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  RATE_LIMITED: 'RATE_LIMITED',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  SUSPECT_INPUT_REJECTED: 'SUSPECT_INPUT_REJECTED',
} as const;

export type ErrorCodeValue = (typeof ErrorCode)[keyof typeof ErrorCode];

/**
 * `error.code` is typed `ErrorCode | string` on the wire — unmapped statuses
 * fall back to the literal `HTTP_<status>`. Never switch on it without a
 * default branch.
 */
export type WireErrorCode = ErrorCodeValue | (string & {});

export class ApiError extends Error {
  readonly code: WireErrorCode;
  readonly status: number;
  readonly details?: unknown;
  /** Correlates to the server log. Always surface this to the operator. */
  readonly requestId?: string;
  /** Seconds from a 429's `Retry-After`, when the server sent one. */
  readonly retryAfterSeconds?: number;

  constructor(args: {
    code: WireErrorCode;
    message: string;
    status: number;
    details?: unknown;
    requestId?: string;
    retryAfterSeconds?: number;
  }) {
    super(args.message);
    this.name = 'ApiError';
    this.code = args.code;
    this.status = args.status;
    this.details = args.details;
    this.requestId = args.requestId;
    this.retryAfterSeconds = args.retryAfterSeconds;
  }

  is(code: WireErrorCode): boolean {
    return this.code === code;
  }
}

/** Thrown when a response body does not match its Zod schema. */
export class SchemaError extends Error {
  readonly issues: unknown;
  readonly path: string;

  constructor(path: string, issues: unknown) {
    super(`Response from ${path} did not match the expected shape`);
    this.name = 'SchemaError';
    this.path = path;
    this.issues = issues;
  }
}

/** Thrown when the request never reached the server. */
export class NetworkError extends Error {
  constructor(message = 'Could not reach the server') {
    super(message);
    this.name = 'NetworkError';
  }
}

/**
 * Operator-facing copy. Says what went wrong and what to do — never an
 * apology, never a raw code.
 */
const MESSAGES: Partial<Record<string, string>> = {
  [ErrorCode.ADMIN_CREDENTIALS_INVALID]: 'That email and password do not match.',
  [ErrorCode.ADMIN_TOTP_INVALID]: 'That code is not valid. Codes expire every 30 seconds.',
  [ErrorCode.ADMIN_TOTP_ALREADY_ENABLED]: 'Two-factor authentication is already set up.',
  [ErrorCode.ADMIN_IP_NOT_ALLOWED]:
    'Your IP address is not on the allowlist for this account. Contact a super admin.',
  [ErrorCode.ADMIN_DISABLED]: 'This admin account has been disabled.',
  [ErrorCode.ADMIN_FORBIDDEN]: 'Your role does not have permission for this action.',
  [ErrorCode.ADMIN_UNAUTHENTICATED]: 'Your session has ended. Sign in to continue.',
  [ErrorCode.ADMIN_NOT_FOUND]: 'That admin account no longer exists.',
  [ErrorCode.REPORT_NOT_FOUND]: 'That report no longer exists.',
  [ErrorCode.REPORT_ALREADY_HANDLED]:
    'Another moderator already handled this report. Refresh to see what they did.',
  [ErrorCode.VALIDATION_FAILED]: 'Some fields need fixing before this can be saved.',
  [ErrorCode.NOT_FOUND]: 'We could not find what you were looking for.',
  [ErrorCode.CONFLICT]: 'That already exists.',
  [ErrorCode.RATE_LIMITED]: 'Too many attempts. Wait a moment and try again.',
  [ErrorCode.INTERNAL_ERROR]: 'Something went wrong on the server. Try again shortly.',
  [ErrorCode.SUSPECT_INPUT_REJECTED]: 'That input contained characters the server rejects.',
};

/** Prefers our copy, falls back to the server's message, then a generic line. */
export function messageFor(error: unknown): string {
  if (error instanceof ApiError) {
    // A rate limit is only actionable if we say how long to wait.
    if (error.status === 429 && error.retryAfterSeconds) {
      return `Too many attempts. Try again in ${error.retryAfterSeconds} second${
        error.retryAfterSeconds === 1 ? '' : 's'
      }.`;
    }
    return MESSAGES[error.code] ?? error.message ?? 'Something went wrong.';
  }
  if (error instanceof NetworkError) {
    return 'Could not reach the server. Check your connection and try again.';
  }
  if (error instanceof SchemaError) {
    return 'The server returned data in an unexpected format. This is a bug — please report it.';
  }
  return 'Something went wrong.';
}

/** Field-level messages from a 400, for attaching to form inputs. */
export function fieldErrorsFrom(error: unknown): string[] {
  if (!(error instanceof ApiError) || !error.is(ErrorCode.VALIDATION_FAILED)) return [];
  const details = error.details;
  if (details && typeof details === 'object' && 'fields' in details) {
    const fields = details.fields;
    if (Array.isArray(fields)) return fields.filter((f): f is string => typeof f === 'string');
  }
  return [];
}
