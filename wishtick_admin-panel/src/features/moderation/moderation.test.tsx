import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ReportDetailPage } from './ReportDetailPage';
import { severityBucket, REMOVE_CONSEQUENCE } from './moderation-copy';
import { AuthContext, type AuthState } from '@/features/auth/auth-types';
import type { AdminPermission } from '@/lib/api/schemas';

function report(overrides: Record<string, unknown> = {}) {
  return {
    _id: 'r1',
    reporterId: 'u9',
    source: 'user',
    targetType: 'message',
    targetId: 'm1',
    reason: 'Abusive language',
    detail: 'Repeated abuse in the event chat.',
    status: 'open',
    severity: 3,
    resolution: null,
    handledBy: null,
    handledAt: null,
    createdAt: '2026-07-20T10:00:00.000Z',
    updatedAt: '2026-07-20T10:00:00.000Z',
    ...overrides,
  };
}

function target(overrides: Record<string, unknown> = {}) {
  return {
    targetType: 'message',
    targetId: 'm1',
    exists: true,
    title: 'Chat message',
    body: 'You are worthless and nobody wants you here.',
    mediaUrl: null,
    authorId: 'u5',
    state: null,
    createdAt: '2026-07-20T09:00:00.000Z',
    fields: { kind: 'text', chatId: 'c1' },
    ...overrides,
  };
}

function jsonOk(data: unknown) {
  return new Response(JSON.stringify({ success: true, data }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** Routes the two calls the detail page makes: the queue, then the target. */
function mockApi(reportDoc: unknown, targetDoc: unknown) {
  return vi.fn().mockImplementation((url: string) => {
    if (String(url).includes('/target')) return Promise.resolve(jsonOk(targetDoc));
    if (String(url).includes('/moderation/queue')) {
      const isOpen = String(url).includes('status=open');
      return Promise.resolve(
        jsonOk({ items: isOpen ? [reportDoc] : [], total: isOpen ? 1 : 0, page: 1, limit: 200 }),
      );
    }
    return Promise.resolve(jsonOk({}));
  });
}

function renderDetail(permissions: AdminPermission[]) {
  const auth = {
    admin: null,
    isAuthenticated: true,
    isBootstrapping: false,
    mustEnrolTotp: false,
    expiringSoon: false,
    endedReason: null,
    login: vi.fn(),
    logout: vi.fn(),
    markTotpEnrolled: vi.fn(),
    can: (permission: AdminPermission) => permissions.includes(permission),
  } as unknown as AuthState;

  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });

  return render(
    <QueryClientProvider client={client}>
      <AuthContext.Provider value={auth}>
        <MemoryRouter initialEntries={['/moderation/r1']}>
          <Routes>
            <Route path="/moderation/:id" element={<ReportDetailPage />} />
            <Route path="/moderation" element={<div>queue</div>} />
          </Routes>
        </MemoryRouter>
      </AuthContext.Provider>
    </QueryClientProvider>,
  );
}

afterEach(() => vi.unstubAllGlobals());

describe('severity bucketing', () => {
  it('maps the server formula onto scannable buckets', () => {
    expect(severityBucket(1).label).toBe('Low');
    expect(severityBucket(2).label).toBe('Medium');
    expect(severityBucket(3).label).toBe('High'); // user target, or auto-flagged message
    expect(severityBucket(4).label).toBe('High');
    // Escalation adds 5, so anything at or above it is unbounded and critical.
    expect(severityBucket(8).label).toBe('Critical');
  });
});

describe('the content preview', () => {
  it('shows the reported words so the moderator is not judging an id', async () => {
    vi.stubGlobal('fetch', mockApi(report(), target()));
    renderDetail(['moderation:view', 'moderation:act']);

    expect(
      await screen.findByText('You are worthless and nobody wants you here.'),
    ).toBeInTheDocument();
  });

  it('says so plainly when the content was deleted after being reported', async () => {
    vi.stubGlobal(
      'fetch',
      mockApi(report(), target({ exists: false, title: null, body: null })),
    );
    renderDetail(['moderation:view', 'moderation:act']);

    expect(await screen.findByText(/no longer exists/i)).toBeInTheDocument();
  });
});

describe('remove consequences', () => {
  it('warns that removing a user suspends the account', async () => {
    const user = userEvent.setup();
    vi.stubGlobal(
      'fetch',
      mockApi(
        report({ targetType: 'user', targetId: 'u5', severity: 3 }),
        target({ targetType: 'user', title: 'Rohit Shah', body: null }),
      ),
    );
    renderDetail(['moderation:view', 'moderation:act']);

    await user.click(await screen.findByRole('button', { name: /remove content/i }));

    const dialog = await screen.findByRole('dialog');
    expect(dialog).toHaveTextContent(/SUSPENDS the account/i);
    expect(dialog).toHaveTextContent(/cannot sign in until an admin reactivates/i);
  });

  it('warns that removing a wish triggers a reel re-render rather than an instant change', () => {
    // Pinned as a constant test because this consequence is invisible in the UI
    // until the moment of confirmation, and it is the one that surprises people.
    expect(REMOVE_CONSEQUENCE.wish).toMatch(/re-render/i);
    expect(REMOVE_CONSEQUENCE.wish).toMatch(/not update instantly/i);
  });

  it('notes that a takedown on already-removed content is a no-op', async () => {
    const user = userEvent.setup();
    vi.stubGlobal('fetch', mockApi(report(), target({ state: 'deleted' })));
    renderDetail(['moderation:view', 'moderation:act']);

    await user.click(await screen.findByRole('button', { name: /remove content/i }));

    const dialog = await screen.findByRole('dialog');
    expect(dialog).toHaveTextContent(/no-op/i);
  });
});

describe('permission gating', () => {
  it('hides the decision panel from a view-only moderator', async () => {
    vi.stubGlobal('fetch', mockApi(report(), target()));
    renderDetail(['moderation:view']);

    // The body text is unique; "Chat message" appears as both label and title.
    await screen.findByText('You are worthless and nobody wants you here.');
    expect(screen.queryByRole('button', { name: /remove content/i })).not.toBeInTheDocument();
    expect(screen.getByText(/not act on it/i)).toBeInTheDocument();
  });
});

describe('acting on a report', () => {
  it('sends the chosen action and reason', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi(report(), target());
    vi.stubGlobal('fetch', fetchMock);
    renderDetail(['moderation:view', 'moderation:act']);

    await user.click(await screen.findByRole('button', { name: /remove content/i }));
    const dialog = await screen.findByRole('dialog');
    await user.type(within(dialog).getByLabelText(/reason/i), 'Confirmed abuse');
    await user.click(within(dialog).getByRole('button', { name: /remove it/i }));

    await waitFor(() => {
      const actCall = fetchMock.mock.calls.find((call) => String(call[0]).includes('/act'));
      expect(actCall).toBeDefined();
      const body = JSON.parse((actCall?.[1] as RequestInit).body as string) as {
        action: string;
        reason: string;
      };
      expect(body.action).toBe('remove');
      expect(body.reason).toBe('Confirmed abuse');
    });
  });
});
