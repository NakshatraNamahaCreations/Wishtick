import clsx from 'clsx';

/**
 * Chart primitives.
 *
 * Deliberately CSS, not a charting library. The two datasets the API returns
 * are categorical totals — 5 acquisition sources and 7 engagement counts — with
 * no time series behind either (there is no endpoint that returns one). A
 * library would add ~100KB to render bars we can draw with a div, and would not
 * theme from our tokens without extra wiring. Revisit if a daily-series
 * endpoint lands.
 */

/** Distinguishable in both themes and for common colour-vision deficiencies. */
export const CATEGORY_COLORS = [
  '#6C4DEF',
  '#3B82F6',
  '#0EA5A5',
  '#F59E0B',
  '#A855F7',
  '#EC4899',
] as const;

export interface BarDatum {
  label: string;
  value: number;
}

/**
 * Vertical bars for categorical comparison. Falls back to a readable state when
 * every value is zero, rather than rendering a flat baseline that looks broken.
 */
export function BarChart({ data, emptyLabel }: { data: BarDatum[]; emptyLabel?: string }) {
  const max = Math.max(...data.map((d) => d.value), 0);

  if (data.length === 0) {
    return (
      <p className="py-10 text-center text-sm text-muted">{emptyLabel ?? 'No data in range'}</p>
    );
  }

  return (
    <div>
      <div
        className="grid items-end gap-3 border-b border-hairline pb-0.5"
        style={{ gridTemplateColumns: `repeat(${data.length}, minmax(0, 1fr))`, height: '220px' }}
      >
        {data.map((datum, index) => {
          const color = CATEGORY_COLORS[index % CATEGORY_COLORS.length];
          // Zero must render as a visible sliver, not nothing — an absent bar
          // and a zero bar would otherwise look identical.
          const pct = max > 0 ? Math.max((datum.value / max) * 100, 1.5) : 1.5;
          return (
            <div
              key={datum.label}
              className="flex h-full flex-col items-center justify-end gap-2"
            >
              <span
                className="tnum rounded-pill px-2.5 py-0.5 text-xs font-bold text-white"
                style={{ backgroundColor: color }}
              >
                {datum.value.toLocaleString()}
              </span>
              <div
                className="w-full max-w-[54px] rounded-t-[10px]"
                style={{ height: `${pct}%`, backgroundColor: color }}
              />
            </div>
          );
        })}
      </div>
      <div
        className="mt-3 grid gap-3"
        style={{ gridTemplateColumns: `repeat(${data.length}, minmax(0, 1fr))` }}
      >
        {data.map((datum) => (
          <span
            key={datum.label}
            title={datum.label}
            className="truncate text-center text-xs capitalize text-muted"
          >
            {datum.label}
          </span>
        ))}
      </div>
    </div>
  );
}

/** Horizontal progress rows — better than bars when labels are long. */
export function MetricBars({ data }: { data: BarDatum[] }) {
  const max = Math.max(...data.map((d) => d.value), 0);

  return (
    <div className="flex flex-col gap-4">
      {data.map((datum) => {
        const pct = max > 0 ? (datum.value / max) * 100 : 0;
        return (
          <div key={datum.label} className="flex flex-col gap-1.5">
            <div className="flex items-baseline justify-between gap-3">
              <span className="text-sm text-muted">{datum.label}</span>
              <span className="tnum text-[15px] font-bold">{datum.value.toLocaleString()}</span>
            </div>
            <div className="h-2 overflow-hidden rounded-pill bg-surface-2">
              <div
                className={clsx('h-full rounded-pill', pct > 0 ? 'bg-accent' : '')}
                style={{ width: `${pct}%` }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
}
