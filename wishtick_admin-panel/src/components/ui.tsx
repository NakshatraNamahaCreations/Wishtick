import clsx from 'clsx';
import { useState } from 'react';
import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from 'react';
import { ApiError, messageFor } from '@/lib/api/errors';

/**
 * Shared primitives from design-system.md.
 *
 * Everything reads design tokens through Tailwind — no raw hex here, so both
 * themes come for free.
 */

// ── Button ───────────────────────────────────────────────────────────────────

type ButtonVariant = 'primary' | 'ghost' | 'danger';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  loading?: boolean;
  icon?: ReactNode;
}

const BUTTON_STYLES: Record<ButtonVariant, string> = {
  primary: 'bg-accent text-white hover:bg-accent-hover disabled:hover:bg-accent',
  ghost: 'border border-hairline bg-surface text-ink hover:border-accent hover:text-accent-text',
  danger: 'bg-crit text-white hover:opacity-90',
};

export function Button({
  variant = 'primary',
  loading = false,
  icon,
  children,
  className,
  disabled,
  ...rest
}: ButtonProps) {
  return (
    <button
      {...rest}
      disabled={disabled || loading}
      className={clsx(
        'inline-flex items-center justify-center gap-2 rounded-pill px-5 py-3',
        'text-sm font-semibold transition-colors',
        'disabled:cursor-not-allowed disabled:opacity-60',
        BUTTON_STYLES[variant],
        className,
      )}
    >
      {loading ? <Spinner /> : icon}
      {children}
    </button>
  );
}

function Spinner() {
  return (
    <span
      aria-hidden="true"
      className="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"
    />
  );
}

// ── Field ────────────────────────────────────────────────────────────────────

interface FieldProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  hint?: string;
}

export function Field({ label, error, hint, id, className, type, ...rest }: FieldProps) {
  const inputId = id ?? `field-${label.toLowerCase().replace(/\s+/g, '-')}`;
  const describedBy = error ? `${inputId}-error` : hint ? `${inputId}-hint` : undefined;

  // A password field gets a reveal toggle. `revealed` swaps the input type so the
  // browser's own password manager still recognises it when hidden.
  const [revealed, setRevealed] = useState(false);
  const isPassword = type === 'password';
  const inputType = isPassword && revealed ? 'text' : type;

  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={inputId} className="text-sm font-medium text-ink">
        {label}
      </label>
      <div className="relative">
        <input
          {...rest}
          type={inputType}
          id={inputId}
          aria-invalid={error ? true : undefined}
          aria-describedby={describedBy}
          className={clsx(
            'w-full rounded-nav border bg-surface px-4 py-3 text-[15px] text-ink',
            'placeholder:text-muted-soft',
            'transition-colors focus:outline-none focus-visible:border-accent',
            isPassword && 'pr-11',
            error ? 'border-crit' : 'border-field',
            className,
          )}
        />
        {isPassword && (
          <button
            type="button"
            onClick={() => setRevealed((v) => !v)}
            aria-label={revealed ? 'Hide password' : 'Show password'}
            aria-pressed={revealed}
            className="absolute inset-y-0 right-0 grid w-11 place-items-center rounded-r-nav text-muted transition-colors hover:text-ink focus:outline-none focus-visible:text-accent"
          >
            {revealed ? <EyeOffGlyph /> : <EyeGlyph />}
          </button>
        )}
      </div>
      {hint && !error && (
        <p id={`${inputId}-hint`} className="text-xs text-muted">
          {hint}
        </p>
      )}
      {error && (
        <p id={`${inputId}-error`} role="alert" className="text-xs font-medium text-crit">
          {error}
        </p>
      )}
    </div>
  );
}

function EyeGlyph() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className="h-[18px] w-[18px]"
    >
      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}

function EyeOffGlyph() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className="h-[18px] w-[18px]"
    >
      <path d="M10.6 6.1A9.8 9.8 0 0 1 12 6c6.5 0 10 7 10 7a13.2 13.2 0 0 1-2.3 3.1M6.5 7.9A13.2 13.2 0 0 0 2 12s3.5 7 10 7a9.5 9.5 0 0 0 4-.8" />
      <path d="M3 3l18 18" />
    </svg>
  );
}

// ── Panel ────────────────────────────────────────────────────────────────────

export function Panel({
  title,
  subtitle,
  action,
  children,
  className,
}: {
  title?: string;
  subtitle?: string;
  action?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section
      className={clsx(
        'rounded-card border border-hairline bg-surface p-[22px] shadow-card',
        className,
      )}
    >
      {(title || action) && (
        <header className="mb-1 flex flex-wrap items-center justify-between gap-3">
          <div>
            {title && (
              <h2 className="font-display text-[17.5px] font-bold tracking-tight">{title}</h2>
            )}
            {subtitle && <p className="mt-0.5 text-xs text-muted">{subtitle}</p>}
          </div>
          {action}
        </header>
      )}
      {children}
    </section>
  );
}

// ── Status pill ──────────────────────────────────────────────────────────────

type PillTone = 'good' | 'info' | 'warn' | 'crit' | 'neutral';

const PILL_STYLES: Record<PillTone, string> = {
  good: 'bg-good-wash text-good',
  info: 'bg-info-wash text-info',
  warn: 'bg-warn-wash text-warn',
  crit: 'bg-crit-wash text-crit',
  neutral: 'bg-surface-2 text-muted',
};

export function Pill({ tone = 'neutral', children }: { tone?: PillTone; children: ReactNode }) {
  return (
    <span
      className={clsx(
        'inline-flex items-center gap-1.5 rounded-pill px-3 py-1',
        'text-xs font-semibold',
        PILL_STYLES[tone],
      )}
    >
      {children}
    </span>
  );
}

// ── Notices ──────────────────────────────────────────────────────────────────

/**
 * States the exact limit whenever the API caps a result set.
 *
 * A capped list rendered silently reads as complete, and an operator acting on
 * that belief is the failure mode this panel most needs to avoid.
 */
export function TruncationNotice({ children }: { children: ReactNode }) {
  return (
    <p className="mt-4 flex items-start gap-2.5 rounded-nav bg-warn-wash px-4 py-3 text-xs leading-relaxed text-warn">
      <InfoGlyph />
      <span>{children}</span>
    </p>
  );
}

/**
 * Error state for a failed query.
 *
 * Routes the real error through `messageFor` instead of a hardcoded string.
 * That distinction matters: a hardcoded "Could not load X" reads identically
 * whether the server is down, the operator lacks permission, or the response
 * shape drifted — and the last of those is a bug the message should name.
 * `context` says which panel failed, since the mapped message does not.
 */
export function QueryError({ context, error }: { context: string; error: unknown }) {
  return (
    <ErrorNotice requestId={error instanceof ApiError ? error.requestId : undefined}>
      <span className="block font-semibold">{context}</span>
      {messageFor(error)}
    </ErrorNotice>
  );
}

export function ErrorNotice({
  children,
  requestId,
}: {
  children: ReactNode;
  requestId?: string;
}) {
  return (
    <div
      role="alert"
      className="flex items-start gap-2.5 rounded-nav bg-crit-wash px-4 py-3 text-sm leading-relaxed text-crit"
    >
      <InfoGlyph />
      <span>
        {children}
        {requestId && (
          <span className="mt-1 block font-mono text-[11px] opacity-80">
            Reference: {requestId}
          </span>
        )}
      </span>
    </div>
  );
}

/**
 * Marks a designed slot whose endpoint does not exist yet. Deliberately not a
 * skeleton — it must not look like data that is about to arrive.
 */
export function GapCard({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="mt-4 rounded-nav border border-dashed border-hairline bg-surface-2 px-5 py-6 text-center">
      <p className="text-sm font-bold text-ink">{title}</p>
      <p className="mx-auto mt-1 max-w-md text-xs leading-relaxed text-muted">{children}</p>
    </div>
  );
}

function InfoGlyph() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      aria-hidden="true"
      className="mt-px h-4 w-4 shrink-0"
    >
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7.5v5" strokeLinecap="round" />
      <circle cx="12" cy="16.2" r="0.9" fill="currentColor" stroke="none" />
    </svg>
  );
}

// ── Empty / loading ──────────────────────────────────────────────────────────

export function EmptyState({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="px-5 py-12 text-center">
      <p className="text-sm font-semibold text-ink">{title}</p>
      {children && <p className="mx-auto mt-1 max-w-sm text-xs text-muted">{children}</p>}
    </div>
  );
}

export function LoadingState({ label = 'Loading' }: { label?: string }) {
  return (
    <div className="flex items-center justify-center gap-3 px-5 py-12 text-sm text-muted">
      <span
        aria-hidden="true"
        className="h-4 w-4 animate-spin rounded-full border-2 border-muted-soft border-t-transparent"
      />
      {label}…
    </div>
  );
}
