import { useCallback, useRef, type ReactNode } from 'react';
import { Button, ErrorNotice } from './ui';
import { useFocusTrap } from './use-focus-trap';
import { ApiError, messageFor } from '@/lib/api/errors';

/**
 * Confirmation for a consequential action.
 *
 * The body states what will actually happen — "this ends their sessions and
 * disconnects them immediately" — never "are you sure?". An operator who does
 * not know the consequence cannot meaningfully consent to it.
 */
export function ConfirmDialog({
  open,
  title,
  consequence,
  confirmLabel,
  destructive = false,
  busy = false,
  error,
  children,
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  consequence: ReactNode;
  confirmLabel: string;
  destructive?: boolean;
  busy?: boolean;
  error?: unknown;
  children?: ReactNode;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const panelRef = useRef<HTMLDivElement>(null);

  // Escape is ignored mid-flight: dismissing a dialog while its request is in
  // the air would leave the operator unsure whether the action took effect.
  const handleEscape = useCallback(() => {
    if (!busy) onCancel();
  }, [busy, onCancel]);

  useFocusTrap(panelRef, open, handleEscape);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center sm:items-center">
      <button
        type="button"
        aria-label="Cancel"
        onClick={() => !busy && onCancel()}
        className="absolute inset-0 bg-black/50"
      />
      {/* Sheet on mobile, centred dialog on desktop. */}
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="confirm-title"
        className="relative w-full max-w-md rounded-t-card border border-hairline bg-surface p-6 shadow-pop sm:rounded-card"
      >
        <h2 id="confirm-title" className="font-display text-xl font-bold tracking-tight">
          {title}
        </h2>
        <div className="mt-2 text-sm leading-relaxed text-muted">{consequence}</div>

        {children && <div className="mt-4">{children}</div>}

        {error != null && (
          <div className="mt-4">
            <ErrorNotice requestId={error instanceof ApiError ? error.requestId : undefined}>
              {messageFor(error)}
            </ErrorNotice>
          </div>
        )}

        <div className="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button variant="ghost" onClick={onCancel} disabled={busy}>
            Cancel
          </Button>
          <Button
            variant={destructive ? 'danger' : 'primary'}
            onClick={onConfirm}
            loading={busy}
          >
            {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}
