import { useState, type FormEvent } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { Button, ErrorNotice, Field } from '@/components/ui';
import { ApiError, ErrorCode, messageFor } from '@/lib/api/errors';
import { useAuth } from './use-auth';

/**
 * Admin sign-in.
 *
 * The subtlety: `ADMIN_TOTP_REQUIRED` is a STATE TRANSITION, not a failure.
 * The server accepts the password, then asks for a second factor. Treating it
 * as an error — clearing the form and showing red text — is the most common
 * way this flow is built wrong, and it makes operators retype their password
 * every single sign-in.
 */
export function LoginPage() {
  const { login, isAuthenticated, endedReason } = useAuth();
  const location = useLocation();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [totp, setTotp] = useState('');
  const [needsTotp, setNeedsTotp] = useState(false);
  const [error, setError] = useState<unknown>(null);
  const [submitting, setSubmitting] = useState(false);

  if (isAuthenticated) {
    const from = (location.state as { from?: string } | null)?.from ?? '/';
    return <Navigate to={from} replace />;
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);

    try {
      await login({ email, password, ...(needsTotp && totp ? { totp } : {}) });
      // Success — AuthProvider flips isAuthenticated and the redirect above runs.
    } catch (caught) {
      if (caught instanceof ApiError && caught.is(ErrorCode.ADMIN_TOTP_REQUIRED)) {
        // Not an error. Keep the credentials, reveal the code field.
        setNeedsTotp(true);
        setError(null);
      } else {
        if (caught instanceof ApiError && caught.is(ErrorCode.ADMIN_TOTP_INVALID)) {
          setTotp('');
        }
        setError(caught);
      }
    } finally {
      setSubmitting(false);
    }
  }

  const expiryNotice =
    endedReason === 'expired'
      ? 'Your session reached its 2-hour limit. Sign in to continue.'
      : endedReason === 'rejected'
        ? 'Your session ended. Sign in to continue.'
        : null;

  return (
    <main className="flex min-h-full items-center justify-center bg-ground px-5 py-10">
      <div className="w-full max-w-[420px]">
        <div className="mb-7 flex items-center gap-3">
          <span className="grid h-10 w-10 place-items-center rounded-[10px] bg-accent text-lg font-bold text-white">
            W
          </span>
          <span className="font-display text-xl font-bold tracking-tight">Wishtick Admin</span>
        </div>

        <div className="rounded-card border border-hairline bg-surface p-7 shadow-shell">
          <h1 className="font-display text-2xl font-bold tracking-tight">
            {needsTotp ? 'Enter your code' : 'Sign in'}
          </h1>
          <p className="mt-1.5 text-sm text-muted">
            {needsTotp
              ? 'Open your authenticator app and enter the current 6-digit code.'
              : 'Operator access to the Wishtick platform.'}
          </p>

          {expiryNotice && !error && (
            <p className="mt-5 rounded-nav bg-info-wash px-4 py-3 text-xs leading-relaxed text-info">
              {expiryNotice}
            </p>
          )}

          <form
            onSubmit={(event) => void handleSubmit(event)}
            className="mt-6 flex flex-col gap-4"
          >
            <Field
              label="Email"
              type="email"
              autoComplete="username"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              // Locked once we're on the code step: the server already accepted
              // these, and editing them silently invalidates the pending code.
              disabled={needsTotp}
            />

            <Field
              label="Password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={needsTotp}
            />

            {needsTotp && (
              <Field
                label="Authentication code"
                inputMode="numeric"
                autoComplete="one-time-code"
                pattern="\d{6}"
                maxLength={6}
                required
                autoFocus
                placeholder="000000"
                hint="Six digits, refreshed every 30 seconds."
                value={totp}
                onChange={(e) => setTotp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                className="tnum tracking-[0.3em]"
              />
            )}

            {error != null && (
              <ErrorNotice
                requestId={error instanceof ApiError ? error.requestId : undefined}
              >
                {messageFor(error)}
              </ErrorNotice>
            )}

            <Button type="submit" loading={submitting} className="mt-1 w-full">
              {needsTotp ? 'Verify and sign in' : 'Sign in'}
            </Button>

            {needsTotp && (
              <button
                type="button"
                onClick={() => {
                  setNeedsTotp(false);
                  setTotp('');
                  setError(null);
                }}
                className="text-xs font-medium text-muted underline-offset-2 hover:text-accent-text hover:underline"
              >
                Use a different account
              </button>
            )}
          </form>
        </div>
      </div>
    </main>
  );
}
