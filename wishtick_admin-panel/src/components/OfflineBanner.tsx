import { useEffect, useState } from 'react';
import { Icon } from './Icon';

/**
 * Connection status.
 *
 * `navigator.onLine` only knows whether the machine has a network interface —
 * it says nothing about whether the backend is reachable. So the copy is
 * deliberately about the browser's view, not a claim about the server.
 */
export function OfflineBanner() {
  const [online, setOnline] = useState(() =>
    typeof navigator === 'undefined' ? true : navigator.onLine,
  );

  useEffect(() => {
    const goOnline = () => setOnline(true);
    const goOffline = () => setOnline(false);
    window.addEventListener('online', goOnline);
    window.addEventListener('offline', goOffline);
    return () => {
      window.removeEventListener('online', goOnline);
      window.removeEventListener('offline', goOffline);
    };
  }, []);

  if (online) return null;

  return (
    <div
      role="status"
      aria-live="polite"
      className="flex items-start gap-2.5 rounded-nav bg-crit-wash px-4 py-3 text-xs leading-relaxed text-crit"
    >
      <Icon name="clock" className="mt-px h-4 w-4 shrink-0" />
      <span>
        <b className="font-bold">You are offline.</b> Nothing will load or save until the
        connection returns. Anything you have typed stays on screen.
      </span>
    </div>
  );
}
