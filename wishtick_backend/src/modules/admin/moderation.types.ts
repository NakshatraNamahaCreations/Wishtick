export enum ReportTargetType {
  WISH = 'wish',
  REEL = 'reel',
  MESSAGE = 'message',
  WISHLIST = 'wishlist',
  EVENT = 'event',
  USER = 'user',
}

export enum ReportStatus {
  OPEN = 'open',
  REVIEWING = 'reviewing',
  RESOLVED = 'resolved',
  DISMISSED = 'dismissed',
}

export enum ReportSource {
  /** A user hit "report". */
  USER = 'user',
  /** An auto-flag hook (profanity, future media safety) raised it. */
  AUTO = 'auto',
}

/** The actions a moderator can take on a report/target. */
export enum ModerationAction {
  /** The content is fine — dismiss the report, leave it up. */
  APPROVE = 'approve',
  /** Take the content down (soft-hide / regenerate / suspend as appropriate). */
  REMOVE = 'remove',
  /** Leave it up but keep it flagged for a second look. */
  FLAG = 'flag',
  /** Bump severity for a senior reviewer. */
  ESCALATE = 'escalate',
}

/** Higher = reviewed sooner. Auto-flagged content and reports on people rank up. */
export function severityFor(targetType: ReportTargetType, source: ReportSource): number {
  let severity = 1;
  if (targetType === ReportTargetType.USER) severity += 2;
  if (targetType === ReportTargetType.MESSAGE || targetType === ReportTargetType.WISH)
    severity += 1;
  if (source === ReportSource.AUTO) severity += 1;
  return severity;
}
