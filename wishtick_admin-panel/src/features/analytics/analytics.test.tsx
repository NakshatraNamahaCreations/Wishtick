import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AnalyticsPage } from './AnalyticsPage';
import { toCsv } from './csv';
import { ENGAGEMENT_ORDER, orderEngagement } from './engagement-labels';

const SEVEN = {
  wishlistsCreated: 12,
  eventsCreated: 3,
  giftsCreated: 20,
  giftsFulfilled: 14,
  groupGiftsCreated: 2,
  reelsCreated: 1,
  reelsReleased: 1,
};

function jsonOk(data: unknown) {
  return new Response(JSON.stringify({ success: true, data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

function mockApi(overrides: {
  overview?: Record<string, number | string>;
  acquisition?: unknown[];
  engagement?: Record<string, number>;
}) {
  const overview = overrides.overview ?? {
    date: '2026-07-20',
    dau: 5,
    wau: 12,
    mau: 30,
    totalUsers: 42,
  };
  return vi.fn().mockImplementation((url: string) => {
    const u = String(url);
    if (u.includes('/analytics/overview')) return Promise.resolve(jsonOk(overview));
    if (u.includes('/analytics/acquisition'))
      return Promise.resolve(jsonOk(overrides.acquisition ?? [{ source: 'whatsapp', signups: 9 }]));
    if (u.includes('/analytics/engagement'))
      return Promise.resolve(jsonOk(overrides.engagement ?? SEVEN));
    return Promise.resolve(jsonOk({}));
  });
}

function renderPage() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter>
        <AnalyticsPage />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

afterEach(() => vi.unstubAllGlobals());

describe('CSV export', () => {
  it('quotes fields so a comma in a label cannot shift columns', () => {
    const csv = toCsv(['source', 'signups'], [['whatsapp, direct', 9]]);
    expect(csv).toBe('"source","signups"\r\n"whatsapp, direct","9"');
  });

  it('doubles inner quotes rather than breaking the field', () => {
    expect(toCsv(['a'], [['say "hi"']])).toContain('"say ""hi"""');
  });
});

describe('engagement ordering', () => {
  it('presents the seven known metrics in reading order', () => {
    const ordered = orderEngagement(SEVEN).map(([key]) => key);
    expect(ordered).toEqual([...ENGAGEMENT_ORDER]);
  });

  it('surfaces a metric the backend adds later rather than dropping it', () => {
    const ordered = orderEngagement({ ...SEVEN, itemsAdded: 7 }).map(([key]) => key);
    expect(ordered).toContain('itemsAdded');
    // Known ones still lead.
    expect(ordered[0]).toBe('wishlistsCreated');
  });
});

describe('cache honesty', () => {
  it('always states that figures are cached and not invalidated by a rollup', async () => {
    vi.stubGlobal('fetch', mockApi({}));
    renderPage();
    expect(await screen.findByText(/not invalidated when a rollup runs/i)).toBeInTheDocument();
  });

  it('warns when every active-user figure is zero, since that is ambiguous', async () => {
    vi.stubGlobal(
      'fetch',
      mockApi({ overview: { date: '2026-07-20', dau: 0, wau: 0, mau: 0, totalUsers: 42 } }),
    );
    renderPage();

    expect(
      await screen.findByText(/cannot distinguish .* rollup did not run/i),
    ).toBeInTheDocument();
  });

  it('does not cry wolf when there is genuine activity', async () => {
    vi.stubGlobal('fetch', mockApi({}));
    renderPage();
    await screen.findByText(/platform overview/i);
    expect(screen.queryByText(/rollup did not run/i)).not.toBeInTheDocument();
  });

  it('names the stale cache as a cause when acquisition comes back empty', async () => {
    // Exactly what happened live: 88 signups in the data, [] on the wire.
    vi.stubGlobal('fetch', mockApi({ acquisition: [] }));
    renderPage();
    expect(await screen.findByText(/stale 5-minute cache entry/i)).toBeInTheDocument();
  });
});

describe('honesty about missing metrics', () => {
  it('names the engagement metrics the API does not return', async () => {
    vi.stubGlobal('fetch', mockApi({}));
    renderPage();
    expect(await screen.findByText(/why are there only 7 metrics/i)).toBeInTheDocument();
    expect(screen.getByText('Items added')).toBeInTheDocument();
    expect(screen.getByText('Wishlist chat activity')).toBeInTheDocument();
  });
});

describe('the overview is a snapshot, not a range', () => {
  it('labels total users as live, since it ignores the snapshot date', async () => {
    vi.stubGlobal('fetch', mockApi({}));
    renderPage();
    expect(await screen.findByText(/does not move with the snapshot date/i)).toBeInTheDocument();
  });
});
