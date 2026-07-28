import clsx from 'clsx';
import { Pill } from '@/components/ui';
import type { ReportStatus } from '@/lib/api/schemas';
import { severityBucket } from './moderation-copy';

/** Presentational components for moderation. Constants live in moderation-copy.ts. */

const SEVERITY_BAR: Record<string, string> = {
  crit: 'bg-crit',
  warn: 'bg-warn',
  info: 'bg-info',
  muted: 'bg-muted-soft',
};

const SEVERITY_TEXT: Record<string, string> = {
  crit: 'text-crit',
  warn: 'text-warn',
  info: 'text-info',
  muted: 'text-muted',
};

export function SeverityIndicator({ severity }: { severity: number }) {
  const { label, tone } = severityBucket(severity);
  return (
    <span
      className={clsx('inline-flex items-center gap-2 text-sm font-bold', SEVERITY_TEXT[tone])}
      title={`${label} — severity ${severity}`}
    >
      <span className={clsx('h-5 w-1 shrink-0 rounded-sm', SEVERITY_BAR[tone])} />
      <span className="tnum">{severity}</span>
      <span className="text-xs font-semibold">{label}</span>
    </span>
  );
}

export function ReportStatusPill({ status }: { status: ReportStatus }) {
  switch (status) {
    case 'open':
      return <Pill tone="info">Open</Pill>;
    case 'reviewing':
      return <Pill tone="warn">Reviewing</Pill>;
    case 'resolved':
      return <Pill tone="good">Resolved</Pill>;
    case 'dismissed':
      return <Pill tone="neutral">Dismissed</Pill>;
  }
}
