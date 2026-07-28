import { useAuth } from '@/features/auth/use-auth';
import { Icon } from './Icon';

/**
 * Warns before the hard 2-hour cutoff.
 *
 * There is no refresh endpoint, so this is a countdown to a real logout — not a
 * prompt we can silently resolve. The only useful thing an operator can do is
 * finish or save what they're doing, so that's what it says.
 */
export function SessionBanner() {
  const { expiringSoon } = useAuth();
  if (!expiringSoon) return null;

  return (
    <div
      role="status"
      className="flex items-start gap-2.5 rounded-nav bg-warn-wash px-4 py-3 text-xs leading-relaxed text-warn"
    >
      <Icon name="clock" className="mt-px h-4 w-4 shrink-0" />
      <span>
        <b className="font-bold">Your session ends in under 5 minutes.</b> Admin sessions last 2
        hours and cannot be extended — finish or save what you&rsquo;re working on, then sign in
        again.
      </span>
    </div>
  );
}
