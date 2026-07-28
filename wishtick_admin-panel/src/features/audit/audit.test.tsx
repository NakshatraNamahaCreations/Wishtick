import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AuditPage } from './AuditPage';

function entry(overrides: Record<string, unknown> = {}) {
  return {
    _id: 'e1',
    actorAdminId: 'a1',
    actorEmail: 'ops@wishtick.com',
    action: 'user.suspend',
    targetType: 'user',
    targetId: 'u1',
    diff: [{ field: 'status', before: 'active', after: 'suspended' }],
    meta: { reason: 'spam' },
    ip: '203.0.113.7',
    createdAt: '2026-07-21T09:00:00.000Z',
    ...overrides,
  };
}

function jsonOk(data: unknown) {
  return new Response(JSON.stringify({ success: true, data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

function mockApi(items: unknown[], total = items.length) {
  return vi.fn().mockImplementation((url: string) => {
    if (String(url).includes('/audit/actions'))
      return Promise.resolve(jsonOk(['user.suspend', 'admin.update']));
    return Promise.resolve(jsonOk({ items, total, page: 1, limit: 25 }));
  });
}

function renderPage(items: unknown[], total?: number) {
  vi.stubGlobal('fetch', mockApi(items, total));
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter initialEntries={['/audit']}>
        <AuditPage />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

afterEach(() => vi.unstubAllGlobals());

describe('the diff', () => {
  it('renders before and after as readable values, not JSON', async () => {
    renderPage([entry()]);
    expect(await screen.findByText('active')).toBeInTheDocument();
    expect(screen.getByText('suspended')).toBeInTheDocument();
    expect(screen.getByText('status')).toBeInTheDocument();
  });

  it('renders an array change as a list rather than [object Object]', async () => {
    renderPage([
      entry({
        action: 'admin.update',
        targetType: 'admin',
        diff: [{ field: 'roles', before: ['moderator'], after: ['support', 'analyst'] }],
      }),
    ]);
    expect(await screen.findByText('moderator')).toBeInTheDocument();
    expect(screen.getByText('support, analyst')).toBeInTheDocument();
    expect(screen.queryByText(/object Object/)).not.toBeInTheDocument();
  });

  it('renders a null before as an em dash, not "null"', async () => {
    renderPage([entry({ diff: [{ field: 'suspendedReason', before: null, after: 'spam' }] })]);
    expect(await screen.findByText('—')).toBeInTheDocument();
  });

  it('shows an empty array as (none) rather than nothing at all', async () => {
    renderPage([entry({ diff: [{ field: 'ipAllowlist', before: [], after: ['1.2.3.4'] }] })]);
    expect(await screen.findByText('(none)')).toBeInTheDocument();
  });
});

describe('provenance', () => {
  it('shows the denormalized actor email, which survives admin deletion', async () => {
    renderPage([entry()]);
    expect(await screen.findByText('ops@wishtick.com')).toBeInTheDocument();
  });

  it('states that the log is append-only', async () => {
    renderPage([entry()]);
    expect(
      await screen.findByText(/nothing here can be edited or deleted/i),
    ).toBeInTheDocument();
  });
});

describe('tolerating what Mongo actually returns', () => {
  it('renders an entry with no `meta` key at all', async () => {
    // Verbatim shape from the live API. Mongoose's `minimize` (on by default)
    // strips empty objects before saving, so an entry recorded without meta has
    // NO `meta` key on the wire — not `{}`. Requiring it made the whole page
    // fail to load: five of the first six real documents were shaped this way.
    const withoutMeta = {
      _id: '6a5f6be66315b34622275c80',
      actorAdminId: '6a5f4f653b79aa3063d9d0db',
      actorEmail: 'admin@wishtick.com',
      action: 'admin.update',
      targetType: 'admin',
      targetId: '6a5f4f653b79aa3063d9d0db',
      diff: [{ field: 'name', before: 'Bootstrap Super Admin', after: 'Super Admin' }],
      ip: '127.0.0.1',
      createdAt: '2026-07-21T12:53:58.239Z',
      __v: 0,
    };
    renderPage([withoutMeta]);

    // Assert on the diff values, which are unique to the entry — the action
    // name also appears as an <option> in the filter dropdown.
    expect(await screen.findByText('Bootstrap Super Admin')).toBeInTheDocument();
    expect(screen.getByText('Super Admin')).toBeInTheDocument();
    expect(screen.getByText('admin@wishtick.com')).toBeInTheDocument();
  });

  it('renders an entry with no `diff` either', async () => {
    const bare = {
      _id: 'e2',
      actorAdminId: 'a1',
      actorEmail: 'ops@wishtick.com',
      action: 'admin.create',
      targetType: 'admin',
      targetId: 'a2',
      ip: null,
      createdAt: '2026-07-21T09:00:00.000Z',
    };
    renderPage([bare]);
    // No diff rows to key off, so assert on the entry's actor line.
    expect(await screen.findByText('ops@wishtick.com')).toBeInTheDocument();
  });
});

describe('empty state', () => {
  it('says no entries match the filters rather than implying none exist', async () => {
    renderPage([], 0);
    expect(await screen.findByText(/no entries match these filters/i)).toBeInTheDocument();
  });
});
