import type { ReportTargetType } from '@/lib/api/schemas';

/** Constants and pure helpers for moderation. Components live in moderation-display.tsx. */

/**
 * Severity is an unbounded number, not an enum: base 1, +2 for a user target,
 * +1 for message/wish, +1 when auto-flagged — then +5 per escalation. So it is
 * bucketed for scanning, with the raw number always shown alongside.
 */
export function severityBucket(severity: number): {
  label: string;
  tone: 'crit' | 'warn' | 'info' | 'muted';
} {
  if (severity >= 5) return { label: 'Critical', tone: 'crit' };
  if (severity >= 3) return { label: 'High', tone: 'warn' };
  if (severity === 2) return { label: 'Medium', tone: 'info' };
  return { label: 'Low', tone: 'muted' };
}

export const TARGET_LABEL: Record<ReportTargetType, string> = {
  message: 'Chat message',
  wish: 'Reel wish',
  reel: 'Birthday reel',
  wishlist: 'Wishlist',
  event: 'Event',
  user: 'User account',
};

/**
 * What `remove` actually does, per type — shown before confirming.
 *
 * A moderator who does not know that removing a user *suspends the account*, or
 * that removing a wish from a released reel triggers a re-render, cannot
 * meaningfully consent to the action they are about to take.
 */
export const REMOVE_CONSEQUENCE: Record<ReportTargetType, string> = {
  message: 'The message is soft-deleted and disappears from the chat for everyone.',
  wish: 'The wish is rejected and excluded from the reel. If the reel has already been released, this queues a re-render — the video will not update instantly.',
  reel: 'The compiled video is taken down. The collection and its wishes are kept, so the initiator can regenerate it.',
  wishlist: 'The wishlist is archived and disappears from public and shared views.',
  event: 'The event is cancelled. Invitees keep the record but it is no longer live.',
  user: 'This SUSPENDS the account. Every session ends immediately, live connections drop, and they cannot sign in until an admin reactivates them.',
};

/** Human label for a lifecycle state that means a takedown already happened. */
export const STATE_LABEL: Record<string, string> = {
  deleted: 'Already deleted',
  archived: 'Already archived',
  cancelled: 'Already cancelled',
  rejected: 'Already rejected',
  suspended: 'Account suspended',
  'media removed': 'Video already taken down',
};
