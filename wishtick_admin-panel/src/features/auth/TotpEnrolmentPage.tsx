import { useEffect, useState, type FormEvent } from 'react';
import QRCode from 'qrcode';
import { Button, ErrorNotice, Field, LoadingState } from '@/components/ui';
import { authApi } from '@/lib/api/endpoints';
import { ApiError, messageFor } from '@/lib/api/errors';
import type { TotpSetup } from '@/lib/api/schemas';
import { useAuth } from './use-auth';

/**
 * Mandatory 2FA enrolment.
 *
 * The server issues a fully working token when `setupRequired` is true and does
 * NOT restrict it — so nothing server-side stops an un-enrolled admin from
 * using the API. Gating the app here is the only enforcement that exists.
 */
export function TotpEnrolmentPage() {
  const { markTotpEnrolled, logout, admin } = useAuth();

  const [setup, setSetup] = useState<TotpSetup | null>(null);
  const [qrDataUrl, setQrDataUrl] = useState<string | null>(null);
  const [setupError, setSetupError] = useState<unknown>(null);
  const [code, setCode] = useState('');
  const [confirmError, setConfirmError] = useState<unknown>(null);
  const [submitting, setSubmitting] = useState(false);

  // Begin enrolment. Calling setup twice just overwrites the pending secret,
  // so a retry is safe.
  useEffect(() => {
    let cancelled = false;

    authApi
      .setupTotp()
      .then(async (result) => {
        if (cancelled) return;
        setSetup(result);
        // Rendered locally — the secret never goes to a third-party QR service.
        const dataUrl = await QRCode.toDataURL(result.keyUri, {
          width: 200,
          margin: 1,
          color: { dark: '#14141A', light: '#FFFFFF' },
        });
        if (!cancelled) setQrDataUrl(dataUrl);
      })
      .catch((error: unknown) => {
        if (!cancelled) setSetupError(error);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  async function handleConfirm(event: FormEvent) {
    event.preventDefault();
    setSubmitting(true);
    setConfirmError(null);

    try {
      await authApi.enableTotp(code);
      markTotpEnrolled();
    } catch (error) {
      setConfirmError(error);
      setCode('');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-full items-center justify-center bg-ground px-5 py-10">
      <div className="w-full max-w-[480px]">
        <div className="mb-7 flex items-center gap-3">
          <span className="grid h-10 w-10 place-items-center rounded-[10px] bg-accent text-lg font-bold text-white">
            W
          </span>
          <span className="font-display text-xl font-bold tracking-tight">Wishtick Admin</span>
        </div>

        <div className="rounded-card border border-hairline bg-surface p-7 shadow-shell">
          <h1 className="font-display text-2xl font-bold tracking-tight">
            Set up two-factor authentication
          </h1>
          <p className="mt-1.5 text-sm leading-relaxed text-muted">
            Required before {admin?.name ? `${admin.name} can` : 'you can'} use the admin panel.
            Scan this with Google Authenticator, 1Password, or any TOTP app.
          </p>

          {setupError != null ? (
            <div className="mt-6">
              <ErrorNotice
                requestId={setupError instanceof ApiError ? setupError.requestId : undefined}
              >
                {messageFor(setupError)}
              </ErrorNotice>
            </div>
          ) : !setup ? (
            <LoadingState label="Generating your secret" />
          ) : (
            <>
              <div className="mt-6 flex flex-col items-center gap-4 rounded-card bg-surface-2 p-6">
                {qrDataUrl ? (
                  <img
                    src={qrDataUrl}
                    alt="QR code for two-factor authentication setup"
                    width={200}
                    height={200}
                    className="rounded-nav bg-white p-2"
                  />
                ) : (
                  <div className="h-[200px] w-[200px] animate-pulse rounded-nav bg-hairline" />
                )}

                <div className="w-full text-center">
                  <p className="text-xs text-muted">Can&rsquo;t scan? Enter this key manually:</p>
                  <code className="mt-1.5 block break-all rounded-nav border border-hairline bg-surface px-3 py-2 font-mono text-xs tracking-wide text-ink">
                    {setup.secret}
                  </code>
                </div>
              </div>

              <form
                onSubmit={(event) => void handleConfirm(event)}
                className="mt-6 flex flex-col gap-4"
              >
                <Field
                  label="Enter the 6-digit code to confirm"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  pattern="\d{6}"
                  maxLength={6}
                  required
                  placeholder="000000"
                  value={code}
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  className="tnum tracking-[0.3em]"
                />

                {confirmError != null && (
                  <ErrorNotice
                    requestId={
                      confirmError instanceof ApiError ? confirmError.requestId : undefined
                    }
                  >
                    {messageFor(confirmError)}
                  </ErrorNotice>
                )}

                <Button type="submit" loading={submitting} disabled={code.length !== 6}>
                  Confirm and continue
                </Button>
              </form>
            </>
          )}

          <button
            type="button"
            onClick={() => void logout()}
            className="mt-5 text-xs font-medium text-muted underline-offset-2 hover:text-accent-text hover:underline"
          >
            Sign out instead
          </button>
        </div>
      </div>
    </main>
  );
}
