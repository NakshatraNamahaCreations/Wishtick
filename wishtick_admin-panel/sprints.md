# Wishtick Admin Panel — Sprint Plan

Frontend delivery plan for the operator console that sits on top of the Sprint 11 admin API in [`wishtick_backend`](../wishtick_backend). The API surface it consumes is documented endpoint-by-endpoint in [backend_api.md](backend_api.md).

**Stack:** React 19 + TypeScript · Vite · TanStack Query (server state) · TanStack Table (grids) · React Router · Tailwind CSS + shadcn/ui · Recharts · Zod · React Hook Form.

**Cadence:** 6 sprints × 2 weeks ≈ 12 weeks, sized for one frontend developer. Sprint 1 carries the foundation and is the one not to compress — every later sprint is a screen on top of the API client and auth shell it establishes.

Each sprint ends with: merged code, passing CI (lint + typecheck + unit + e2e), a deployed preview build, and every new screen exercised against the real backend rather than only against mocks.

---

## The constraint that shapes this plan

**The backend admin API is already built and shipped.** This is not a greenfield contract — Sprint 11 of the backend is complete, and the panel consumes what exists. Two consequences run through everything below:

1. **No screen may assume an endpoint that is not in [backend_api.md](backend_api.md).** Eleven gaps are documented there. The two that actually block work are called out as prerequisites in Sprint 3.
2. **The server is the authority on permissions.** The panel hides controls the operator cannot use, but every route re-checks server-side and returns `ADMIN_FORBIDDEN`. Client-side permission logic is cosmetic and must never be the only gate.

---

## Architecture Decisions (locked before Sprint 1)

| Concern | Decision |
|---|---|
| Framework | React 19 + TypeScript, Vite. No SSR — an admin panel behind a login has no SEO or first-paint argument for it, and CSR keeps deployment a static bundle |
| Routing | React Router with a permission-aware route guard; unknown/forbidden routes render a 403 screen, never a blank page |
| Server state | TanStack Query. No Redux — nearly all state here is server state, and a cache with invalidation is the actual problem to solve |
| Client state | React state + context. Global stores are not warranted at this size |
| API client | One typed fetch wrapper that unwraps `data`, normalizes `error.code`, and attaches `Authorization` + `X-Request-Id`. **Nothing calls `fetch` directly** |
| Response validation | Zod schemas per endpoint, parsed at the client boundary. A backend shape change fails loudly at the seam instead of as `undefined` three components deep |
| Token storage | `sessionStorage`. See [the token decision](#the-token-decision) below — it is a real tradeoff, not a default |
| Tables | TanStack Table (headless) + custom cells. Server-side pagination for users; client-side only for lists the API returns whole |
| Charts | Recharts. Sufficient for counts and time series; no D3 hand-rolling |
| Forms | React Hook Form + Zod resolver, sharing the constraint values (lengths, patterns) with the backend DTOs |
| Styling | Tailwind + shadcn/ui — components live in the repo and are editable, so accessibility fixes do not wait on an upstream release |
| Visual language | Locked in [design-system.md](design-system.md) — tokens for color, radius, elevation, and type, derived from the approved reference direction. **No raw hex in component code**; everything references a token so both themes come for free |
| Errors | One error boundary per route + a typed `error.code` → message map. Unknown codes fall back to `error.message`, never a raw stack |
| Testing | Vitest + Testing Library, MSW for network mocking, Playwright for the auth and moderation flows end to end |
| CI | install → lint → typecheck → unit → build → Playwright → deploy preview |

### The token decision

The backend issues a **bearer token with a 2-hour life and no refresh endpoint**. That rules out the usual answers and leaves a genuine tradeoff:

- **In-memory only** is the most XSS-resistant, but a page refresh logs the operator out. With a 2h ceiling and no silent refresh, that is hostile during an incident.
- **`localStorage`** survives reload but persists across tabs and browser restarts, and is readable by any injected script.
- **`sessionStorage`** — chosen. Survives reload, dies with the tab, is not shared across tabs.

`sessionStorage` is still XSS-readable; the mitigation is a strict CSP with no inline scripts and no third-party origins, enforced in Sprint 6. **The properly secure answer is an httpOnly cookie**, which needs the backend to set one — recorded as a recommendation in [Backend recommendations](#backend-recommendations), not assumed here.

---

## Sprint 1 — Foundation, API Client & Admin Auth

**Goal:** An operator can log in with 2FA and land on an empty but correctly-guarded shell.

This is the sprint everything else rests on. The auth flow here is more intricate than a typical login because of TOTP enrolment and the hard session ceiling — build it properly now rather than patching it in Sprint 5.

### Deliverables

- Repo scaffold: Vite + React + TS, ESLint + Prettier, strict `tsconfig`, path aliases, CI pipeline green.
- **Design tokens from [design-system.md](design-system.md)** wired into the Tailwind theme, with self-hosted Poppins (the geometric face is a substantial part of the approved look — a system-font fallback is visibly a different voice). Both light and dark defined at the token layer before any screen is built; retrofitting a second theme after six sprints of components is far more expensive than defining it once here.
- The shared primitives every later sprint consumes: shell, sidebar, KPI card, panel, pill, severity indicator, table, **truncation notice**, and gap card.
- **Typed API client**: unwraps the `{ success, data }` envelope, maps `{ success: false, error: { code, message } }` to a typed `ApiError`, attaches `Authorization` and a generated `X-Request-Id`, and surfaces `requestId` on every error for support correlation.
- Zod schemas for every response the panel consumes, parsed at the boundary.
- **Login flow**, including the two non-obvious states:
  - `ADMIN_TOTP_REQUIRED` is a **state transition, not an error** — re-present the form with a TOTP field, preserving the entered credentials. Making an operator retype their password because they were asked for a second factor is the single most common way this flow is built wrong.
  - `setupRequired: true` issues a working token but must **hard-gate the app** into TOTP enrolment. The server does not enforce this; the panel does.
- **TOTP enrolment**: QR render of `keyUri` client-side, copyable `secret` fallback, confirm via `POST /admin/auth/totp/enable`.
- **Session expiry handling**: a 401 anywhere routes to login with a "your session expired" notice and preserves the attempted destination. Warn at T-5min. Because there is no refresh token, **any unsaved form state must survive the bounce** — the moderation and suspend forms depend on this.
- App shell: nav driven by the `permissions[]` array, 403 screen, error boundaries, loading and empty states as first-class components.
- `GET /admin/auth/me` on boot to validate a restored token; cache `name` from the login response, since `me` does not return it.

### Exit criteria

- Full cycle green in Playwright against a real backend: login → TOTP challenge → enrol → reload (session restored) → logout (token denylisted, next call 401).
- A `moderator` token renders no analytics nav; deep-linking to `/analytics` renders 403 rather than an empty chart.
- Every 4xx/5xx renders a human message plus a copyable `requestId`; no raw stack or `[object Object]` reaches the screen.
- Session expiry mid-form does not lose typed input.

---

## Sprint 2 — User Management

**Goal:** Support can find any user, understand their account, and act on it.

The highest-value sprint — this is what support uses daily, and the API backs it fully.

### Deliverables

- **User list**: server-side pagination against `GET /admin/users` (`page`/`limit`, default 25, cap 100), debounced `search` across email/phone/name, `status` filter, sorted newest-first. URL-synced state so a filtered view is shareable.
- **User detail**: the flat `UserAdminView` plus the `counts` block (5 keys) and `activity` (≤10 entries).
  - `activity` is a 5-gifts + 5-wishlists sample, not a timeline. **Label it "Recent activity"** and state the limit in the UI — implying completeness during an incident investigation is worse than showing nothing.
  - `acquisition` is `null` for pre-attribution users; render "unknown", not "organic".
- **Actions**, each behind `users:manage`, each with a confirmation step:
  - Suspend — requires a reason (≤500). Warn plainly that this kills live sessions and disconnects sockets.
  - Reactivate.
  - Force-logout — distinct from suspend; the copy must make clear the account stays active.
- Optimistic-free mutations: these are consequential and rare, so wait for the server and invalidate the query. Optimism buys nothing and risks showing a suspension that did not happen.
- `NOT_FOUND` on a malformed id renders "user not found", not a crash.

### Exit criteria

- Search by partial email, phone, and name each return the expected user; regex metacharacters in the query are handled (server escapes them — assert the client does not double-escape).
- Suspending a user reflects `status: suspended` and the reason without a manual refresh.
- A `support` operator sees the action buttons; an `analyst` (who has `users:view` but not `users:manage`) sees the same detail page **read-only**, with actions absent rather than disabled-and-mysterious.
- Pagination holds across filter changes without stranding the operator on an empty page 9.

---

## Sprint 3 — Moderation Queue ✅ COMPLETE

**Goal:** A moderator can triage reports and act on content.

**Status: ✅ COMPLETE.** The two blocking gaps were closed in `wishtick_backend` first, then the screen was built on top.

**Backend work done to unblock it:**
- **`GET /admin/moderation/reports/:id/target`** — resolves a report's target into a normalized envelope (`title`, `body`, `mediaUrl`, `authorId`, `state`, `fields`) across all six types, so one component renders any of them. A missing target returns `exists: false` with a 200, not a 404 — content gets deleted after being reported and the report still needs resolving.
- **Queue pagination** — `page` + `limit` are now forwarded and the response carries `total`. This was a **breaking change** to the response shape (bare array → `{items,total,page,limit}`), which brings it in line with `GET /admin/users`; the backend e2e test was updated alongside it.
- **`npm run seed:moderation`** — realistic demo data (5 users, 5 pieces of content, 6 reports across every type and severity, one deliberately dangling) so the queue can actually be driven. Refuses to run with `NODE_ENV=production`.

### Deliverables

- **Queue view** with status as tabs — Open / Reviewing / Resolved / Dismissed. The API applies exactly one status per request and defaults to `open`; there is no combined view, so tabs match the API rather than fighting it.
- `type` filter across the six target types.
- Sort is server-fixed (severity desc, then oldest first) — present it, do not offer client-side re-sorting that silently reorders only the loaded page.
- **Severity as a number, not an enum**: 1–4 at intake, unbounded after escalation (+5 each). Bucket it visually (low/medium/high/critical) with the raw number available.
- **Content preview panel** per target type, from the new endpoint.
- **Act dialog** — `approve` / `remove` / `flag` / `escalate` with an optional reason (≤500) that becomes the audit `resolution`.
  - Per-type consequences shown explicitly before confirming. A moderator should know that removing a message soft-deletes it, removing a wishlist archives it, removing an event cancels it, and **removing a user suspends the account**.
  - **Removing a wish from a released reel triggers a background recompile.** Say so — the video is not instantly gone, and an operator who believes it is will report a bug.
- `REPORT_ALREADY_HANDLED` (409) is a real race — another moderator acted first. Refresh the entry and show what happened rather than a generic failure.
- `reviewing` reports remain actionable; only `resolved`/`dismissed` are terminal.

### Exit criteria

- A moderator can read the reported content, act, and see the entry move tabs without a manual refresh.
- Every action's consequence copy matches the backend's actual per-type behavior, verified against the real API.
- Two moderators acting on one report: the loser gets a clear "already handled" state, not an error toast.
- Removing a wish from a released reel surfaces the recompile as in-progress.

---

## Sprint 4 — Analytics Dashboards ✅ COMPLETE

**Goal:** Operators can see platform health without asking an engineer for a query.

**Status: ✅ COMPLETE.** 46 tests green, lint/typecheck/build clean, and every number verified against a direct recount on live data.

**The cache hazard is not theoretical — it was observed.** After seeding 88 signups and running the real rollup, `GET /admin/analytics/acquisition` returned **`[]`** while a direct aggregation over `metric_daily` returned 5 sources totalling 88. The 300s Redis entry had been written before the rollup and there is no invalidation, so the endpoint served a stale empty for five minutes. Flushing the key made both agree exactly. The acquisition-empty warning now names a stale cache as one of three indistinguishable causes, because it is the one that actually happened.

**Deviations from the plan, and why:**
- **No Recharts.** The plan named it, but the two datasets the API returns are categorical totals — 5 acquisition sources and 7 engagement counts — and **there is no time-series endpoint to plot**. A library would add ~100KB to draw bars a div can draw, and would need extra wiring to read our tokens. Charts are CSS, matching the approved prototype. Revisit when a daily-series endpoint exists.
- **The overview defaults to yesterday, not today.** The rollup lags, so today is routinely the emptiest bucket; defaulting there would make a working dashboard look broken on first load.
- **A zero bar still renders a visible sliver.** An absent bar and a zero bar would otherwise be pixel-identical.
- **`npm run seed:analytics` boots the Nest context** and calls the real `AnalyticsService.rollupDay()` per day rather than writing `metric_daily` directly — hand-written pre-aggregates would make the dashboard agree with a fiction instead of with the real aggregation. It doubles as the ops recipe for backfilling after the worker has been down (`rollupRecent()` only covers yesterday and today).

### Deliverables

- **Overview**: `dau` / `wau` / `mau` / `totalUsers` for a single day. It is a **snapshot, not a range** — the endpoint takes `to ?? from` and returns one bucket. A date picker, not a range picker.
- **Acquisition**: bar chart over a date range, sorted by signups descending. Sources: `whatsapp`, `invite`, `referral`, `organic`, `group_gift`.
- **Engagement**: the **seven** metrics the API actually returns — `wishlistsCreated`, `eventsCreated`, `giftsCreated`, `giftsFulfilled`, `groupGiftsCreated`, `reelsCreated`, `reelsReleased`.
  - ⚠ The product spec lists roughly fifteen engagement metrics; eight do not exist (items added, invites created, chat activity, gifts reserved/purchased separately, offline gifts, reels shared, public vs private usage). **Build for seven.** Listing the others as "coming soon" is a promise the frontend cannot keep alone — record them in [Backend recommendations](#backend-recommendations) instead.
- Date-range control shared by acquisition and engagement, defaulting to the last 30 days, `YYYY-MM-DD` **UTC**. Label the timezone; an operator in IST reading "today" as local will misread every number.
- **Cache-honesty affordances** — the two things that make this dashboard trustworthy:
  - All three endpoints are Redis-cached 300s with **no invalidation after a rollup**. Show an "as of" timestamp and a manual refresh. Never imply live data.
  - A missing rollup reads as **`0`, indistinguishable from a genuine zero**. An all-zero day is more likely a rollup that did not run than a platform with no activity — surface that as a warning rather than rendering a flat line as fact.
- CSV export of the current view, client-side from loaded data.

### Exit criteria

- Numbers match a direct API call for the same range; no client-side arithmetic invents a figure the backend did not return.
- Changing the range refetches and the "as of" timestamp updates.
- An all-zero engagement day renders the data-quality warning, not a confident empty chart.
- Charts are readable at 1280px and degrade to stacked cards on narrow screens.

---

## Sprint 5 — Audit Log & Admin Management ✅ COMPLETE

**Goal:** Actions are reviewable, and super admins can onboard operators.

**Status: ✅ COMPLETE.** 61 frontend tests, 169 backend unit tests, lint/typecheck/build clean on both, and 16/16 checks green against the live backend.

**Backend work done to unblock it:**
- **Audit pagination + filters** — `page`, `limit`, `action`, `actorAdminId`, and an inclusive `from`/`to` UTC day range, plus `GET /admin/audit/actions` for the filter list. Response changed from a bare array to `{items,total,page,limit}`; the e2e test moved with it. `actorAdminId` was previously accepted by the service but absent from the DTO, so the whitelist rejected it with a 400 — the filter existed and was unreachable.
- **`PATCH /admin/admins/:id`** and **`POST /admin/admins/:id/password`** — role changes, disable, IP allowlist, and password reset. Both audited; the password is never written to the log.
- **Three lockout guards, server-side:** you cannot disable your own account, cannot remove your own super-admin role, and the last active super-admin cannot be disabled or demoted. Any of those would leave nobody able to administer the platform, recoverable only by a manual database write.
- **Disable ends sessions.** Setting `status: disabled` stamps `tokensInvalidBefore` so live tokens die immediately, rather than surviving up to 2h.

**Decisions worth knowing:**
- **There is still no delete, deliberately.** Removing an admin row would orphan every audit entry naming them — `actorEmail` is denormalized precisely so the trail outlives the account. Offboarding is disable.
- **The UI mirrors each server guard rather than discovering it via a 403** — self-disable is a disabled button with a tooltip, self-demotion shows an inline warning, and the last-super-admin 409 renders as guidance ("promote another admin first"), not a raw error.
- **CIDR in the IP allowlist is rejected client-side with an explanation.** The server matches exact strings, so `10.0.0.0/8` would match nothing and lock the admin out of every address it was meant to permit.

### Deliverables

- **Audit viewer**: `GET /admin/audit` with `targetType` / `targetId` filters and `limit` (default 100, cap 500).
  - **Render the `diff` array as a readable before/after** — `{ field, before, after }` per changed field. This is the sprint's actual value; a raw JSON dump is not an audit trail anyone will read.
  - `actorEmail` is denormalized and survives admin deletion — show it rather than resolving `actorAdminId`.
  - ⚠ **No pagination, no date filter, no actor filter.** `actorAdminId` is not on the DTO, so sending it is a 400. State the ceiling in the UI ("showing the most recent 500") rather than implying completeness. "What did this admin do last week" is not answerable — do not build a UI that pretends otherwise.
  - Deep-link from a user detail page to that user's audit entries via `targetType=user&targetId=<id>`, which the API *does* support and is the most useful real path.
- **Admin management** (`admins:manage`): list, and a create form (email, password ≥12, name ≤120, ≥1 role, optional IP allowlist).
  - Role picker showing the resulting permission set, read from the same matrix the server uses.
  - IP allowlist is **exact-match, no CIDR** — validate per-entry and say so. An operator entering `10.0.0.0/8` would silently lock themselves out.
  - ⚠ **Create and list only.** There is no edit, disable, delete, or password reset endpoint. The UI must not show controls for them; an offboarding runbook covers the gap until the backend adds it.

### Exit criteria

- A suspend action performed in Sprint 2 appears in the audit view with a legible `status: active → suspended` diff.
- Creating an admin with a duplicate email surfaces the 409 as a field-level error, not a toast.
- The audit view states its 500-entry ceiling wherever a result set is truncated.
- A non-super-admin sees no admin-management nav and 403s on the deep link.

---

## Sprint 6 — Hardening, Accessibility & Launch ✅ COMPLETE

**Goal:** Ship it without surprises.

**Status: ✅ COMPLETE.** 71 tests green, and `npm run verify` now runs the whole gate in one command: typecheck → lint → tests → build → CSP → bundle budget.

**Accessibility is asserted, not claimed.** axe-core runs against every rendered screen plus an open dialog, scoped to WCAG 2.1 A/AA at critical + serious impact. It found nothing — but axe cannot see behaviour, and the dialogs **were not trapping focus**: Tab walked straight out of a modal into the page behind. `aria-modal` tells assistive tech the rest is inert; only a trap makes that true for the keyboard. Fixed with a shared `useFocusTrap`, now covering both the confirm dialogs and the mobile nav drawer, and pinned by tests that Tab 12 times forwards and backwards and assert focus is still inside.

**Two findings worth recording:**
- **The first CSP check reported a false positive.** My regex found `<script>` inside the policy's own explanatory comment. Comments are stripped before scanning now — worth knowing because a check that cries wolf gets ignored, and one that reports a phantom problem is as bad as one that misses a real one.
- **`Retry-After` was being discarded.** A 429 rendered as "too many attempts" with no indication of how long to wait, which is not an actionable error. The client now reads the header and the message says the actual number of seconds.

**Deviations from the plan, and why:**
- **No virtualized table rows.** The plan lists it, but the API caps pages at 25–100 rows and there is no infinite scroll. Virtualization would add a dependency and a whole class of scroll bugs to solve a problem that cannot occur.
- **`style-src` keeps `'unsafe-inline'`.** React writes element `style` attributes for chart bar widths. A style attribute cannot execute script; removing it would require nonce-per-render for no security gain. Called out in the README rather than left as an unexplained hole.
- **Auth screens are not lazily loaded.** Everything behind the shell is, but splitting the login page would add a round trip to the very first paint.

**Explicitly not verified** — these need a real browser or a human, and are listed in the README rather than assumed:
colour contrast (jsdom has no layout engine, so axe cannot compute it), CSP enforcement by a browser (the static check proves the policy and build agree, not that a browser honours it), screen readers, and Firefox/Safari.

### Deliverables

- **Security**: strict CSP with no inline scripts and no third-party origins (the mitigation the `sessionStorage` decision depends on), dependency audit, no tokens in logs or URLs, no PII in analytics or error reporting.
- **Accessibility**: keyboard-navigable tables and dialogs, focus management on route change and modal open, visible focus rings, labelled form controls, AA contrast, screen-reader pass on the moderation act dialog and every destructive confirmation.
- **Resilience**: offline and backend-down states, retry with backoff on idempotent GETs only, a global 429 handler honouring `Retry-After`, and one place that renders `requestId` for support.
- **Performance**: route-level code splitting, bundle budget, virtualized rows on the user table, no chart re-render on unrelated state changes.
- **Ops**: environment config for API host and CORS origin, source maps to the error tracker, README covering setup, roles, and the known gaps.
- Cross-browser pass (Chrome, Firefox, Safari) at 1280px and 1440px.

### Exit criteria

- ✅ Axe reports zero critical or serious issues on every route — automated across all six screens and an open dialog.
- ✅ Every destructive action is reachable and confirmable by keyboard alone — focus trap, Escape, and focus restore all asserted.
- ⚠️ CSP: the policy is verified strict and the build verified compatible (`npm run verify:csp`). **Browser enforcement of an injected script is not covered** — that needs a real browser.
- ✅ Cold-load bundle under budget: entry chunk 107kb gzipped against a 130kb ceiling, 17 lazily-loaded route chunks all under 20kb. Row virtualization was dropped deliberately — see above.

---

## Dependency Map

```
S1 Foundation + Auth + API client
      │
      ├─► S2 User Management ──────────────┐
      │                                    │
      ├─► S3 Moderation  ⚠ blocked on      ├─► S6 Hardening + Launch
      │      backend content-resolution    │
      │      + queue pagination            │
      │                                    │
      ├─► S4 Analytics ────────────────────┤
      │                                    │
      └─► S5 Audit + Admin Management ─────┘
```

**Critical path:** S1 → S2. Everything else hangs off the API client and auth shell.

**Parallelizable:** S4 and S5 are independent of S2 and S3 and can be reordered freely — which is exactly the escape hatch if Sprint 3's backend prerequisites slip. **If they slip, run S4 and S5 first and take S3 last** rather than idling or shipping a blind moderation screen.

---

## Cross-Cutting Standards (every sprint)

- **Definition of done:** merged, lint + typecheck + unit green, Playwright covering the sprint's primary flow, preview deployed, and the screens driven against the **real backend** — not only MSW mocks. Sprint 9 of the backend plan is a standing reminder that "all tests green" and "it works against the real thing" are different claims.
- **Nothing calls `fetch` directly.** One client, one envelope unwrap, one error normalization.
- **Every list states its limits.** If the API caps at 50 or 500, the UI says so. Silent truncation reads as completeness and is the failure mode most likely to cause a wrong operational decision.
- **Every screen works on a phone.** Full-bleed frame, drawer nav below `md`, tables become stacked cards, touch targets ≥ 44px, tested at 375px. Operators triage from wherever they are — a screen that needs a desktop is a screen that waits. Rules in [design-system.md](design-system.md#responsive--a-requirement-not-a-nice-to-have).
- **Every destructive action is confirmed, states its real consequence, and is audited server-side.**
- **Permission checks are cosmetic client-side and authoritative server-side.** Never rely on a hidden button as a control.
- **No endpoint is invented.** If a screen needs data the API does not return, it goes to [Backend recommendations](#backend-recommendations) — it does not get faked, stubbed, or hardcoded.
- **Empty, loading, and error states are designed for every screen**, not added after QA finds them.

---

## Backend Recommendations

Frontend-blocking work, ranked. Full detail in [backend_api.md](backend_api.md#known-gaps).

| Priority | Ask | Why |
|---|---|---|
| **P0** | Content-resolution endpoint for a report target | Sprint 3 cannot ship without it. Moderating blind is not an acceptable fallback |
| **P0** | Forward `limit` + add pagination to the moderation queue | A backlog >50 is invisible today |
| **P1** | Pagination + date/actor filters on the audit log | Makes Sprint 5 a real audit tool rather than a recent-events list |
| **P1** | Admin update / disable / password-reset endpoints | No offboarding or role change is possible through the UI |
| **P2** | The eight missing engagement metrics | Most of the intended dashboard cannot be built |
| **P2** | httpOnly cookie auth, or a refresh token | Would remove the `sessionStorage` XSS exposure and the 2h hard logout |
| **P2** | `name` + `status` on `GET /admin/auth/me` | Removes a client-side cache workaround |
| **P3** | Logout-all endpoint (`tokensInvalidBefore` is DB-write only) | Cannot revoke a compromised admin's sessions from the UI |
| **P3** | CIDR support on the IP allowlist | Exact-match is unusable for office ranges or VPN pools |
| **P3** | Distinguish "rollup missing" from a genuine zero | The dashboard cannot currently tell an operator which one they are looking at |

---

## Risk Register

| Risk | Impact | Mitigation |
|---|---|---|
| Sprint 3's backend prerequisites slip | Moderation unshippable | S4/S5 are independent — reorder and take S3 last. Do **not** ship a blind moderation screen |
| 2h session with no refresh frustrates operators mid-incident | Panel gets bypassed for direct DB access, losing the audit trail | Expiry warning at T-5min, form state preserved across the bounce, and push the cookie/refresh recommendation |
| Analytics cache staleness misread as real numbers | An operational decision made on 5-minute-old data | "As of" timestamp, manual refresh, all-zero warning |
| Silent truncation (queue 50, audit 500) read as completeness | A backlog or an action is missed entirely | Every capped list states its cap in the UI |
| `sessionStorage` token exposed by XSS | Admin session hijack | Strict CSP, no inline scripts, no third-party origins; recommend httpOnly cookies |
| Backend response shape drifts | Silent `undefined` deep in the UI | Zod parse at the client boundary fails loudly at the seam |
| Permission logic drifts from the server matrix | Buttons that 403, or hidden capability | Mirror the role→permission matrix in one module, asserted against a fixture copied from the backend |

---

## Explicitly Out of Scope

Bulk user actions, CSV import, admin-initiated password resets for users, direct content editing (moderation is approve/remove/flag/escalate — not rewriting user content), real-time queue updates over websockets (poll on focus instead), i18n, mobile-first layouts (desktop-optimized; usable but not designed for phones), custom report builders, and any write path to the audit log — it is append-only by design and the panel must never appear to edit it.
