import { Pill } from '@/components/ui';

/** Presentational components for user records. Formatters live in user-format.ts. */

export function StatusPill({ status }: { status: string }) {
  switch (status) {
    case 'active':
      return <Pill tone="good">Active</Pill>;
    case 'suspended':
      return <Pill tone="crit">Suspended</Pill>;
    case 'deleted':
      return <Pill tone="neutral">Deleted</Pill>;
    default:
      return <Pill tone="neutral">{status}</Pill>;
  }
}

/**
 * Attribution is null for anyone created before it was wired up. That is
 * "we don't know", not "organic" — conflating them would silently inflate the
 * organic bucket with the entire pre-attribution user base.
 */
export function AcquisitionLabel({
  acquisition,
}: {
  acquisition: { source: string; ref: string | null } | null;
}) {
  if (!acquisition) return <span className="text-muted-soft">Unknown</span>;
  return (
    <span className="capitalize">
      {acquisition.source.replace(/_/g, ' ')}
      {acquisition.ref && <span className="ml-1 text-muted-soft">· {acquisition.ref}</span>}
    </span>
  );
}
