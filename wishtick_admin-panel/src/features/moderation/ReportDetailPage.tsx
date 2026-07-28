import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ConfirmDialog } from '@/components/ConfirmDialog';
import { Icon } from '@/components/Icon';
import { Button, Field, LoadingState, Panel, Pill } from '@/components/ui';
import { useAuth } from '@/features/auth/use-auth';
import { formatDateTime, relativeTime } from '@/features/users/user-format';
import { ApiError, ErrorCode, messageFor } from '@/lib/api/errors';
import { moderationApi } from '@/lib/api/moderation';
import type { ModerationAction, ModerationTarget } from '@/lib/api/schemas';
import { ReportStatusPill, SeverityIndicator } from './moderation-display';
import { REMOVE_CONSEQUENCE, STATE_LABEL, TARGET_LABEL } from './moderation-copy';

const ACTION_TITLE: Record<ModerationAction, string> = {
  approve: 'Approve this content?',
  remove: 'Remove this content?',
  flag: 'Flag for a second look?',
  escalate: 'Escalate this report?',
};

export function ReportDetailPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { can } = useAuth();

  const [pending, setPending] = useState<ModerationAction | null>(null);
  const [reason, setReason] = useState('');

  const canAct = can('moderation:act');

  // The report itself comes from the queue; the target is a second call.
  const queueQuery = useQuery({
    queryKey: ['moderation-report', id],
    queryFn: async ({ signal }) => {
      // No GET /reports/:id exists — find it across statuses. Documented gap.
      for (const status of ['open', 'reviewing', 'resolved', 'dismissed'] as const) {
        const page = await moderationApi.queue({ status, limit: 200 }, signal);
        const found = page.items.find((report) => report._id === id);
        if (found) return found;
      }
      return null;
    },
  });

  const targetQuery = useQuery({
    queryKey: ['moderation-target', id],
    queryFn: ({ signal }) => moderationApi.target(id, signal),
  });

  const mutation = useMutation({
    mutationFn: (action: ModerationAction) => moderationApi.act(id, action, reason || undefined),
    onSuccess: async () => {
      setPending(null);
      setReason('');
      await queryClient.invalidateQueries({ queryKey: ['moderation-queue'] });
      await queryClient.invalidateQueries({ queryKey: ['moderation-report', id] });
      await queryClient.invalidateQueries({ queryKey: ['moderation-target', id] });
    },
  });

  if (queueQuery.isPending || targetQuery.isPending) {
    return <LoadingState label="Loading report" />;
  }

  const report = queueQuery.data;
  const target = targetQuery.data;

  if (targetQuery.isError || !report || !target) {
    const notFound =
      targetQuery.error instanceof ApiError &&
      targetQuery.error.is(ErrorCode.REPORT_NOT_FOUND);
    return (
      <Panel>
        <div className="px-2 py-10 text-center">
          <p className="font-display text-xl font-bold tracking-tight">
            {notFound || !report ? 'Report not found' : 'Could not load this report'}
          </p>
          <p className="mx-auto mt-2 max-w-md text-sm text-muted">
            {notFound || !report
              ? 'It may have been handled and removed from every queue.'
              : 'Something went wrong fetching the reported content.'}
          </p>
          <Link
            to="/moderation"
            className="mt-6 inline-flex rounded-pill bg-accent px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-accent-hover"
          >
            Back to the queue
          </Link>
        </div>
      </Panel>
    );
  }

  const isTerminal = report.status === 'resolved' || report.status === 'dismissed';

  return (
    <>
      <div className="flex flex-col gap-3">
        <button
          type="button"
          onClick={() => void navigate('/moderation')}
          className="flex w-fit items-center gap-1.5 text-sm font-medium text-muted transition-colors hover:text-accent-text"
        >
          <Icon name="chevronLeft" className="h-4 w-4" />
          Moderation queue
        </button>

        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="min-w-0">
            <h1 className="font-display text-[27px] font-bold tracking-tight text-balance">
              {report.reason}
            </h1>
            <p className="mt-1 text-sm text-muted">
              {TARGET_LABEL[report.targetType]} · reported {relativeTime(report.createdAt)}
              {report.source === 'auto' && ' · auto-flagged'}
            </p>
          </div>
          <div className="flex items-center gap-2">
            <SeverityIndicator severity={report.severity} />
            <ReportStatusPill status={report.status} />
          </div>
        </div>
      </div>

      {report.detail && (
        <Panel title="What the reporter said">
          <p className="mt-3 whitespace-pre-wrap break-words text-sm leading-relaxed">
            {report.detail}
          </p>
        </Panel>
      )}

      {/* ── The content being judged — the whole point of this screen ── */}
      <ContentPreview target={target} />

      {isTerminal && (
        <div className="rounded-nav bg-surface-2 px-4 py-3 text-xs leading-relaxed text-muted">
          <b className="font-semibold text-ink">Already handled.</b>{' '}
          {report.resolution ?? 'No resolution recorded.'}
          {report.handledAt && ` · ${formatDateTime(report.handledAt)}`}
        </div>
      )}

      {/* ── Actions ── */}
      {canAct && !isTerminal && (
        <Panel title="Decide">
          <div className="mt-4 grid grid-cols-1 gap-2 sm:grid-cols-2">
            <Button variant="ghost" onClick={() => setPending('approve')}>
              Approve — no action
            </Button>
            <Button variant="danger" onClick={() => setPending('remove')}>
              Remove content
            </Button>
            <Button variant="ghost" onClick={() => setPending('flag')}>
              Flag for a second look
            </Button>
            <Button variant="ghost" onClick={() => setPending('escalate')}>
              Escalate
            </Button>
          </div>
          <p className="mt-3 text-xs leading-relaxed text-muted">
            Every decision is recorded in the audit log with your name, and the content owner is
            notified where appropriate.
          </p>
        </Panel>
      )}

      {!canAct && !isTerminal && (
        <div className="rounded-nav bg-info-wash px-4 py-3 text-xs leading-relaxed text-info">
          You can view the queue but not act on it. Deciding a report needs the{' '}
          <code className="font-mono">moderation:act</code> permission.
        </div>
      )}

      {/* ── Confirmations ── */}
      <ConfirmDialog
        open={pending !== null}
        title={pending ? ACTION_TITLE[pending] : ''}
        destructive={pending === 'remove'}
        confirmLabel={
          pending === 'remove'
            ? 'Remove it'
            : pending === 'approve'
              ? 'Approve'
              : pending === 'flag'
                ? 'Flag it'
                : 'Escalate'
        }
        busy={mutation.isPending}
        error={mutation.error}
        consequence={<Consequence action={pending} target={target} />}
        onCancel={() => {
          setPending(null);
          setReason('');
          mutation.reset();
        }}
        onConfirm={() => pending && mutation.mutate(pending)}
      >
        <Field
          label="Reason (optional)"
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          maxLength={500}
          placeholder="Recorded as the resolution"
          hint="Stored on the report and in the audit log. Max 500 characters."
        />
      </ConfirmDialog>

      {mutation.isError && pending === null && (
        <div className="rounded-nav bg-crit-wash px-4 py-3 text-sm text-crit">
          {messageFor(mutation.error)}
        </div>
      )}
    </>
  );
}

/** Renders the reported content, whatever type it is. */
function ContentPreview({ target }: { target: ModerationTarget }) {
  if (!target.exists) {
    return (
      <Panel title="Reported content">
        <div className="mt-4 rounded-nav border border-dashed border-hairline bg-surface-2 px-5 py-8 text-center">
          <p className="text-sm font-bold">This content no longer exists</p>
          <p className="mx-auto mt-1 max-w-md text-xs leading-relaxed text-muted">
            It was deleted after being reported. The report is still open and can be resolved —
            there is just nothing left to review.
          </p>
          <p className="mt-3 font-mono text-[11px] text-muted-soft">{target.targetId}</p>
        </div>
      </Panel>
    );
  }

  const extras = Object.entries(target.fields).filter(
    ([, value]) => value !== null && value !== '',
  );

  return (
    <Panel
      title="Reported content"
      subtitle={target.createdAt ? `Created ${formatDateTime(target.createdAt)}` : undefined}
      action={
        target.state ? (
          <Pill tone="warn">{STATE_LABEL[target.state] ?? target.state}</Pill>
        ) : undefined
      }
    >
      <div className="mt-4 flex flex-col gap-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-wider text-muted-soft">
            {TARGET_LABEL[target.targetType]}
          </p>
          {target.title && <p className="mt-1 font-display text-lg font-bold">{target.title}</p>}
        </div>

        {target.body ? (
          // The actual reported words, verbatim and unstyled — a moderator is
          // judging these, so they must not be reformatted or truncated.
          <blockquote className="whitespace-pre-wrap break-words rounded-nav border-l-4 border-accent bg-surface-2 px-4 py-3 text-sm leading-relaxed">
            {target.body}
          </blockquote>
        ) : (
          <p className="text-sm text-muted">This content type carries no text.</p>
        )}

        {target.mediaUrl && (
          <div className="rounded-nav border border-hairline bg-surface-2 px-4 py-3">
            <p className="text-xs font-semibold uppercase tracking-wider text-muted-soft">Media</p>
            <p className="mt-1 break-all font-mono text-xs">{target.mediaUrl}</p>
          </div>
        )}

        {extras.length > 0 && (
          <dl className="grid grid-cols-1 gap-x-8 gap-y-3 border-t border-hairline pt-4 sm:grid-cols-2">
            {extras.map(([key, value]) => (
              <div key={key} className="flex flex-col gap-0.5">
                <dt className="text-xs font-semibold uppercase tracking-wider text-muted-soft">
                  {key.replace(/([A-Z])/g, ' $1').replace(/^./, (c) => c.toUpperCase())}
                </dt>
                <dd className="break-words text-sm">{String(value)}</dd>
              </div>
            ))}
          </dl>
        )}

        {target.authorId && (
          <div className="border-t border-hairline pt-4">
            <p className="text-xs font-semibold uppercase tracking-wider text-muted-soft">
              Posted by
            </p>
            <Link
              to={`/users/${target.authorId}`}
              className="mt-1 inline-flex items-center gap-1.5 font-mono text-xs text-accent-text hover:underline"
            >
              {target.authorId}
              <Icon name="chevronRight" className="h-3.5 w-3.5" />
            </Link>
          </div>
        )}
      </div>
    </Panel>
  );
}

/** States exactly what the chosen action will do to this specific target. */
function Consequence({
  action,
  target,
}: {
  action: ModerationAction | null;
  target: ModerationTarget;
}) {
  if (!action) return null;

  if (action === 'remove') {
    return (
      <>
        <p>{REMOVE_CONSEQUENCE[target.targetType]}</p>
        {!target.exists && (
          <p className="mt-2">
            The content is already gone, so nothing is taken down — the report is simply marked
            resolved.
          </p>
        )}
        {target.state && (
          <p className="mt-2">
            It is already <b className="text-ink">{target.state}</b>, so the takedown will be a
            no-op. The report still resolves.
          </p>
        )}
      </>
    );
  }

  if (action === 'approve') {
    return (
      <>
        The content stays up and the report is <b className="text-ink">dismissed</b>. Use this when
        the report was unfounded.
      </>
    );
  }

  if (action === 'flag') {
    return (
      <>
        The report moves to <b className="text-ink">reviewing</b> and stays in the queue for
        another moderator. Nothing happens to the content.
      </>
    );
  }

  return (
    <>
      Severity increases by <b className="text-ink">5</b> and the report moves to{' '}
      <b className="text-ink">reviewing</b>, pushing it to the top of the queue. Nothing happens to
      the content.
    </>
  );
}
