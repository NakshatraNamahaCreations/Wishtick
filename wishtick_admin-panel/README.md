# Wishtick Admin Panel

Operator console for the Wishtick platform. Consumes the admin API in [`../wishtick_backend`](../wishtick_backend).

- **[sprints.md](sprints.md)** — delivery plan and what shipped in each sprint
- **[backend_api.md](backend_api.md)** — every endpoint, with real request/response shapes
- **[design-system.md](design-system.md)** — design tokens, component specs, responsive rules

**Status: all six sprints complete.** Auth, users, moderation, analytics, audit, and admin management are live.

---

## Setup

```bash
npm install
cp .env.example .env      # point VITE_API_BASE_URL at your backend
npm run dev               # http://localhost:5173
```

The backend must be running and must list this origin in its `CORS_ORIGINS`.

**First sign-in** needs a seeded admin. In the backend:

```bash
npm run seed:admin              # creates the bootstrap super-admin from .env
npm run seed:moderation         # demo users, content, and reports
npm run seed:analytics          # 30 days of events + a real rollup backfill
```

| Script | Does |
|---|---|
| `npm run dev` | Dev server with HMR |
| `npm run build` | Typecheck + production build |
| `npm run test` | Vitest, including axe accessibility checks |
| `npm run lint` | ESLint, zero warnings tolerated |
| `npm run typecheck` | `tsc --noEmit` |
| `npm run verify:csp` | Static CSP + build-compatibility check (needs a build first) |
| `npm run verify:bundle` | Bundle budget (needs a build first) |
| `npm run verify:contrast` | WCAG AA contrast across both themes |
| **`npm run verify`** | **All of the above, in order — the CI gate** |

---

## Architecture

```
src/
  app/          Router (lazy routes), providers, error boundary
  components/   Shared UI primitives, app shell, focus trap
  features/
    auth/       Login, TOTP enrolment, session
    users/      List, detail, suspend/reactivate/force-logout
    moderation/ Queue, report detail, act
    analytics/  Overview, acquisition, engagement
    audit/      Filterable audit trail
    admins/     Create, edit, disable, reset password
  lib/api/      Client, schemas, endpoint wrappers, token store
  test/         Shared a11y harness
scripts/        Build-output verification
```

### Rules this codebase holds to

**Nothing calls `fetch` except [`lib/api/client.ts`](src/lib/api/client.ts).** One envelope unwrap, one error normalization, one place that attaches auth headers.

**Every response is Zod-parsed at the boundary.** A backend shape change fails loudly as a `SchemaError` at the seam instead of surfacing as `undefined` three components deep.

**No raw hex in components.** Everything reads a token from [`styles/index.css`](src/styles/index.css), so light and dark both work without per-component effort.

**Permission checks in the UI are cosmetic.** The sidebar hides what you can't use and routes render a 403, but the server is the authority and returns `ADMIN_FORBIDDEN` regardless.

**Every capped list says so.** `<TruncationNotice>` wherever the API limits a result set. A capped list rendered silently reads as complete.

**Every destructive action states its real consequence**, not "are you sure?" — removing a user *suspends the account*; removing a wish *triggers a reel re-render*.

**Every screen works on a phone.** Full-bleed frame, drawer nav below `md`, tables become stacked cards, touch targets ≥ 44px.

---

## Security

### Content Security Policy

A strict CSP ships in [`index.html`](index.html): `script-src 'self'`, no `unsafe-inline`, no `unsafe-eval`, `object-src 'none'`. `npm run verify:csp` checks both that the policy stays strict and that the build contains nothing it would block.

**A `<meta>` CSP cannot set `frame-ancestors`, `report-to`, or `sandbox`** — those are header-only. Serve these from the host as well:

```
Content-Security-Policy: frame-ancestors 'none'
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
Referrer-Policy: no-referrer
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

`style-src` keeps `'unsafe-inline'` because React writes element `style` attributes (chart bar widths). A style attribute cannot execute script; removing it would need nonce-per-render and buy nothing.

### Theme

The panel is **pinned to light mode** via `data-theme="light"` on `<html>` in [`index.html`](index.html). It is set on the static document rather than from React, so the right palette applies before first paint — setting it after hydration shows a flash of the OS theme on every load.

`color-scheme: light` rides along with that token block, which matters for the native `<input type="date">` pickers in Analytics and Audit: without it they render in the OS theme and look broken against a light page.

The dark palette is intact and still contrast-verified. To follow the OS again, remove the attribute; to offer a toggle, write `"light"` or `"dark"` to it at runtime. `npm run verify:csp` asserts the attribute is present so a revert cannot slip through silently.

### Token storage

`sessionStorage`, deliberately. The backend issues a bearer token with a **2-hour life and no refresh endpoint**, which rules out the usual answers: in-memory means a page refresh logs the operator out mid-incident, and `localStorage` persists across tabs and restarts.

It is still XSS-readable. **The CSP above is the mitigation** — that is why it is not optional. The properly secure answer is an httpOnly cookie, which needs a backend change.

The token is never placed in a URL, a query parameter, or a log line.

---

## Things about this API that shape the code

Full detail in [backend_api.md](backend_api.md). The ones that most affect the frontend:

**No refresh token.** Sessions are a hard 2 hours. `AuthProvider` warns at T-5min and bounces to login on expiry, preserving the attempted destination. There is no silent-refresh interceptor because there is nothing to call.

**`ADMIN_TOTP_REQUIRED` is a state transition, not an error.** The server accepts the password, then asks for a second factor. The login form reveals a code field and keeps the credentials.

**`setupRequired: true` still issues a working token.** The client-side gate in [`routes.tsx`](src/app/routes.tsx) is the *only* thing enforcing 2FA enrolment.

**Analytics figures are cached 5 minutes server-side with no invalidation after a rollup.** A stale empty result is indistinguishable from "no data" — this was observed live, not theorised. The UI shows an "as of" time and names the cache as a possible cause of an empty result.

**A missing analytics rollup reads as `0`.** The dashboard warns when every active-user figure is zero rather than presenting it as fact.

---

## Verification status

What is actually checked, and what is not:

| Area | Status |
|---|---|
| Types, lint, unit + component tests | ✅ `npm run verify` |
| Accessibility (axe, WCAG 2.1 A/AA, critical + serious) | ✅ automated across all six screens + open dialog |
| Keyboard: focus trap, Escape, focus restore | ✅ asserted in tests |
| CSP strictness + build compatibility | ✅ `npm run verify:csp` |
| Bundle budget + code splitting | ✅ `npm run verify:bundle` |
| API contract against the live backend | ✅ driven end-to-end per sprint |
| Colour contrast (WCAG AA; AAA on nav) | ✅ `npm run verify:contrast` — every ratio computed from the tokens, across all three theme blocks, plus token-parity between them |
| **CSP enforcement by a real browser** | ⚠️ **not verified** — the static check proves the policy and the build agree, not that a browser blocks an injected script |
| **Screen readers** (NVDA / VoiceOver) | ⚠️ **not tested** |
| **Cross-browser** (Firefox, Safari) | ⚠️ **not tested** — developed against Chromium |

The three warnings need a real browser and, for screen readers, a human. They are the remaining launch checklist, not silently-assumed passes.

Contrast moved from "not automated" to verified after the initial palette was measured and **19 pairs failed AA** — the greys and semantic hues were tuned by eye and looked fine to me on a good monitor. That is precisely the class of defect that needs a number rather than a judgement.
