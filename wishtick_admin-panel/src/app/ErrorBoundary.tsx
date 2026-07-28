import { Component, type ErrorInfo, type ReactNode } from 'react';
import { SchemaError } from '@/lib/api/errors';

interface State {
  error: Error | null;
}

/**
 * Last line of defence. A raw stack must never reach an operator's screen —
 * but a SchemaError is a real bug worth naming precisely, because it means the
 * backend changed shape underneath us.
 */
export class ErrorBoundary extends Component<{ children: ReactNode }, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    console.error('Unhandled error', error, info.componentStack);
  }

  render(): ReactNode {
    const { error } = this.state;
    if (!error) return this.props.children;

    const isSchema = error instanceof SchemaError;

    return (
      <div className="grid min-h-full place-items-center bg-ground px-5 py-10">
        <div className="w-full max-w-md rounded-card border border-hairline bg-surface p-7 text-center shadow-shell">
          <h1 className="font-display text-xl font-bold tracking-tight">Something broke</h1>
          <p className="mt-2 text-sm leading-relaxed text-muted">
            {isSchema
              ? 'The server returned data in a shape the panel does not recognise. This is a bug — the API contract changed. Please report it.'
              : 'The panel hit an unexpected error. Reloading usually clears it.'}
          </p>
          {isSchema && (
            <p className="mt-3 rounded-nav bg-surface-2 px-3 py-2 font-mono text-[11px] text-muted">
              {(error).path}
            </p>
          )}
          <button
            type="button"
            onClick={() => window.location.reload()}
            className="mt-6 inline-flex rounded-pill bg-accent px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-accent-hover"
          >
            Reload the panel
          </button>
        </div>
      </div>
    );
  }
}
