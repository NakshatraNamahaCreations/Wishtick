import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { UsersListPage } from './UsersListPage';
import { tokenStore } from '@/lib/api/token-store';

function makeUser(overrides: Record<string, unknown> = {}) {
  return {
    id: 'u1',
    email: 'asha@example.com',
    phone: null,
    name: 'Asha R',
    status: 'active',
    roles: ['user'],
    suspendedReason: null,
    emailVerified: true,
    phoneVerified: false,
    acquisition: { source: 'whatsapp', ref: null, capturedAt: '2026-03-02T08:00:00.000Z' },
    lastLoginAt: '2026-07-20T21:14:00.000Z',
    createdAt: '2026-03-02T08:00:00.000Z',
    ...overrides,
  };
}

function jsonOk(data: unknown) {
  return new Response(JSON.stringify({ success: true, data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

function renderList(initialUrl = '/users') {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter initialEntries={[initialUrl]}>
        <Routes>
          <Route path="/users" element={<UsersListPage />} />
          <Route path="/users/:id" element={<div>detail page</div>} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
  tokenStore.clear();
});

describe('the users list', () => {
  it('renders users returned by the API', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        jsonOk({ items: [makeUser()], total: 1, page: 1, limit: 25 }),
      ),
    );

    renderList();

    expect(await screen.findAllByText('Asha R')).not.toHaveLength(0);
    expect(screen.getAllByText('Active').length).toBeGreaterThan(0);
  });

  it('reads filters from the URL so a filtered view is shareable', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonOk({ items: [], total: 0, page: 2, limit: 25 }));
    vi.stubGlobal('fetch', fetchMock);

    renderList('/users?search=asha&status=suspended&page=2');

    await waitFor(() => expect(fetchMock).toHaveBeenCalled());

    const url = new URL(fetchMock.mock.calls[0]?.[0] as string);
    expect(url.searchParams.get('search')).toBe('asha');
    expect(url.searchParams.get('status')).toBe('suspended');
    expect(url.searchParams.get('page')).toBe('2');
  });

  it('debounces typing rather than firing a request per keystroke', async () => {
    const user = userEvent.setup();
    const fetchMock = vi
      .fn()
      .mockResolvedValue(jsonOk({ items: [], total: 0, page: 1, limit: 25 }));
    vi.stubGlobal('fetch', fetchMock);

    renderList();
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(1));

    await user.type(screen.getByLabelText(/search users/i), 'asha');

    // Still one call immediately after four keystrokes.
    expect(fetchMock).toHaveBeenCalledTimes(1);

    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(2), { timeout: 2000 });
  });

  it('distinguishes "no results for this filter" from "no users at all"', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(jsonOk({ items: [], total: 0, page: 1, limit: 25 })),
    );

    renderList('/users?search=nobody');

    expect(await screen.findByText(/no users match those filters/i)).toBeInTheDocument();
  });

  it('shows an unattributed user as Unknown, never as organic', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        jsonOk({
          items: [makeUser({ acquisition: null })],
          total: 1,
          page: 1,
          limit: 25,
        }),
      ),
    );

    renderList();

    expect(await screen.findAllByText('Unknown')).not.toHaveLength(0);
    expect(screen.queryByText(/organic/i)).not.toBeInTheDocument();
  });
});
