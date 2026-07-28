/** Outlined 1.8px-stroke icon set, per design-system.md. Never filled. */

export type IconName =
  | 'dashboard'
  | 'users'
  | 'shield'
  | 'chart'
  | 'document'
  | 'person'
  | 'logout'
  | 'clock'
  | 'menu'
  | 'close'
  | 'search'
  | 'chevronLeft'
  | 'chevronRight'
  | 'filter';

const PATHS: Record<IconName, React.ReactNode> = {
  dashboard: (
    <>
      <rect x="3" y="3" width="7" height="7" rx="2" />
      <rect x="14" y="3" width="7" height="7" rx="2" />
      <rect x="3" y="14" width="7" height="7" rx="2" />
      <rect x="14" y="14" width="7" height="7" rx="2" />
    </>
  ),
  users: (
    <>
      <circle cx="9" cy="8" r="3.2" />
      <path d="M3.5 19c0-3 2.5-5 5.5-5s5.5 2 5.5 5" />
      <path d="M16 11.2A3 3 0 0 0 16 5.4" />
      <path d="M18.5 19c0-2.2-1-3.9-2.5-4.7" />
    </>
  ),
  shield: (
    <>
      <path d="M12 3l7.5 3.2v5c0 4.4-3 8.2-7.5 9.6C7.5 19.4 4.5 15.6 4.5 11.2v-5z" />
      <path d="M12 8.5v4" />
      <circle cx="12" cy="15.6" r="0.9" fill="currentColor" stroke="none" />
    </>
  ),
  chart: (
    <>
      <path d="M4 19V9" />
      <path d="M10 19V5" />
      <path d="M16 19v-7" />
      <path d="M21 19H3" />
    </>
  ),
  document: (
    <>
      <path d="M6 3.5h9l4 4v13H6z" />
      <path d="M14.5 3.5v4.5H19" />
      <path d="M9 12.5h6" />
      <path d="M9 16h4" />
    </>
  ),
  person: (
    <>
      <circle cx="12" cy="8" r="3.4" />
      <path d="M5 20c0-3.6 3.1-6.4 7-6.4s7 2.8 7 6.4" />
    </>
  ),
  logout: (
    <>
      <path d="M15 4.5H6.5v15H15" />
      <path d="M18.5 12H10" />
      <path d="M15.5 8.5L19 12l-3.5 3.5" />
    </>
  ),
  clock: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7.5V12l3 1.8" />
    </>
  ),
  menu: (
    <>
      <path d="M4 7h16" />
      <path d="M4 12h16" />
      <path d="M4 17h16" />
    </>
  ),
  close: (
    <>
      <path d="M6 6l12 12" />
      <path d="M18 6L6 18" />
    </>
  ),
  search: (
    <>
      <circle cx="11" cy="11" r="6.5" />
      <path d="M16 16l4 4" />
    </>
  ),
  chevronLeft: <path d="M14.5 6L9 12l5.5 6" />,
  chevronRight: <path d="M9.5 6l5.5 6-5.5 6" />,
  filter: (
    <>
      <path d="M4 6h16" />
      <path d="M7 12h10" />
      <path d="M10 18h4" />
    </>
  ),
};

export function Icon({ name, className }: { name: IconName; className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={className}
    >
      {PATHS[name]}
    </svg>
  );
}
