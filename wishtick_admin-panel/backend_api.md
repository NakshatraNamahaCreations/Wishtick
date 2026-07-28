# Wishtick Admin Panel — Backend API Reference

Every endpoint the admin panel consumes, as **actually implemented** in [`wishtick_backend`](../wishtick_backend) as of Sprint 11. This is documentation of shipped code, not a proposal — each shape below was read from the controller, DTO, and service that produce it.

Where the API is missing something the panel needs, it is called out inline as **⚠ Gap** and collected in [Known Gaps](#known-gaps). Those gaps drive the sprint plan in [sprints.md](sprints.md); do not design screens around endpoints that do not exist.

---

## Conventions

### Base URL

```
{API_HOST}/api/v1
```

`api` comes from `API_PREFIX` (default `api`); `v1` is URI versioning with `defaultVersion: '1'`. The only unprefixed, unversioned routes are `/health` and `/ready`.

Swagger UI (non-production only, when `SWAGGER_ENABLED`): `{API_HOST}/api/docs` — note **no `v1`**.

### Success envelope

Every successful response is wrapped by a global interceptor. The handler's return value lands whole at `data`:

```json
{
  "success": true,
  "data": { },
  "requestId": "3f6c1a2e-...",
  "timestamp": "2026-07-21T10:00:00.000Z"
}
```

The API client must unwrap `data` in one place. Two routes bypass the envelope (`GET /r/:itemId` redirect, local media download) — neither is used by the admin panel.

### Error envelope

```json
{
  "success": false,
  "error": {
    "code": "ADMIN_TOTP_REQUIRED",
    "message": "A 2FA code is required",
    "details": { "fields": ["email must be an email"] }
  },
  "requestId": "3f6c1a2e-...",
  "timestamp": "2026-07-21T10:00:00.000Z",
  "path": "/api/v1/admin/auth/login"
}
```

Three things that catch clients out:

- The field is **`error.code`**, not `errorCode`.
- There is **no `statusCode` in the body** — the status is only on the HTTP status line.
- `details` is **omitted entirely** when absent, never `null`.

`path` is `req.originalUrl`, so it includes the query string.

### Headers

**Request**

| Header | When | Notes |
|---|---|---|
| `Authorization: Bearer <accessToken>` | Every route except `POST /admin/auth/login` | Admin token; see [Auth](#authentication) |
| `Content-Type: application/json` | Every request with a body | |
| `X-Request-Id` | Optional | Echoed back. Honoured only if non-empty and ≤128 chars, else the server generates a UUID |
| `Idempotency-Key` | **Not used by any admin route** | Only gifting/contribution endpoints are `@Idempotent()` |

**Response**

| Header | Notes |
|---|---|
| `X-Request-Id` | Always set, on success and error. Log it — it correlates to server logs |
| `X-RateLimit-Limit` / `-Remaining` / `-Reset` | Stock `@nestjs/throttler` defaults |
| `Retry-After` | On `429` only |

**CORS** allows exactly `Content-Type`, `Authorization`, `X-Request-Id`, `Idempotency-Key`, exposes `X-Request-Id`, and permits `GET POST PATCH PUT DELETE OPTIONS` with `credentials: true`. The panel's origin must be in `CORS_ORIGINS` on the server.

### Global input rules

- `ValidationPipe` runs `whitelist + forbidNonWhitelisted + transform`. **Any property not declared on the DTO is a 400**, not a silent drop — do not send extra fields.
- A `NoSqlInjectionGuard` runs *before* auth and rejects any request whose body or query contains a key starting with `$`, with `SUSPECT_INPUT_REJECTED` / 400. A `$` inside a *value* is fine.
- Global rate limit is 100 requests / 60s, Redis-backed and shared across pods, unless a route overrides it.

### Dates

All `Date` fields serialize as ISO-8601 UTC strings. Analytics day buckets are `YYYY-MM-DD` **UTC** strings and are compared lexicographically.

---

## Authentication

Admin tokens are **a separate audience from user tokens**: `wishtick-admin` vs `wishtick-app`. Passport rejects an audience mismatch before any handler runs, so a user JWT can never reach an `/admin` route — it is a 401, never a 403 or a validation error.

| Property | Value |
|---|---|
| Scheme | `Authorization: Bearer <accessToken>` |
| Audience | `wishtick-admin` (`ADMIN_JWT_AUDIENCE`) |
| Issuer | `wishtick` (`JWT_ISSUER`) — shared with user tokens |
| Secret | `ADMIN_JWT_ACCESS_SECRET`, falling back to `JWT_ACCESS_SECRET` |
| Lifetime | **2 hours** (`ADMIN_ACCESS_TTL_HOURS`, default `2`) → `expiresInSeconds: 7200` |
| Refresh | **None — there is no refresh endpoint** |

**⚠ Gap — no refresh token.** The session simply dies at 2h and the admin must log in again, re-entering their TOTP code. The panel must detect `401` mid-session, preserve unsaved work, and route to login. Do not build a silent-refresh interceptor; there is nothing to call.

Revocation works two ways: a per-session `jti` denylist in Redis (what `logout` writes), and a `tokensInvalidBefore` timestamp on the admin document compared against the token's millisecond `ims` claim. **No endpoint sets `tokensInvalidBefore`** — logout-all is currently a manual DB write.

### Permission model

Routes assert a **permission**, never a role, so the mapping can change without touching a guard. Permissions are recomputed from the live database row on every request, so a role change takes effect immediately without reissuing the token.

| Role | Permissions |
|---|---|
| `super_admin` | all seven |
| `moderator` | `moderation:view`, `moderation:act`, `users:view`, `audit:view` |
| `support` | `users:view`, `users:manage`, `moderation:view`, `audit:view` |
| `analyst` | `analytics:view`, `users:view` |

Permissions: `admins:manage`, `users:view`, `users:manage`, `moderation:view`, `moderation:act`, `analytics:view`, `audit:view`.

The panel should drive navigation and control visibility off the `permissions[]` array returned by `login` / `me` — but treat that as **cosmetic only**. The server is the authority and returns `ADMIN_FORBIDDEN` / 403 regardless.

### Auth failure matrix

| Scenario | `error.code` | HTTP |
|---|---|---|
| Missing / malformed / expired / bad-signature token | `ADMIN_UNAUTHENTICATED` | 401 |
| A **user** token on an admin route | `ADMIN_UNAUTHENTICATED` | 401 |
| Token after logout (jti denylisted) | `ADMIN_UNAUTHENTICATED` | 401 |
| Admin row missing / invalid id | `ADMIN_NOT_FOUND` | 404 |
| Admin disabled | `ADMIN_DISABLED` | 403 |
| Request IP not in the admin's allowlist | `ADMIN_IP_NOT_ALLOWED` | 403 |
| Authenticated but lacks the route's permission | `ADMIN_FORBIDDEN` | 403 |

---

# Endpoints

## Admin auth

### `POST /admin/auth/login`

Open (no token). Rate limited to **10 / 60s**.

**Body**

```json
{
  "email": "ops@wishtick.com",
  "password": "correct-horse-battery",
  "totp": "482915"
}
```

| Field | Type | Rules |
|---|---|---|
| `email` | string | required, valid email, trimmed + lowercased server-side |
| `password` | string | required, 1–128 chars |
| `totp` | string | optional; **required once 2FA is enabled**; exactly 6 digits |

**`200` response**

```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOi...",
    "expiresInSeconds": 7200,
    "setupRequired": false,
    "admin": {
      "id": "665f1c...",
      "email": "ops@wishtick.com",
      "name": "Ops Lead",
      "roles": ["super_admin"],
      "permissions": ["admins:manage", "users:view", "users:manage",
                      "moderation:view", "moderation:act", "analytics:view", "audit:view"],
      "status": "active",
      "totpEnabled": true,
      "ipAllowlist": [],
      "lastLoginAt": "2026-07-21T09:58:00.000Z",
      "createdAt": "2026-01-04T12:00:00.000Z"
    }
  }
}
```

`setupRequired` is exactly `!totpEnabled`. When `true`, a **token is still issued** — the server does not restrict it. Enforcing "you must enrol now" is the panel's job: on `setupRequired: true`, route straight to TOTP enrolment and refuse to render the rest of the app.

**Errors** — note the evaluation order, which is observable:

| Condition | `error.code` | HTTP |
|---|---|---|
| Unknown email, or admin not `active` | `ADMIN_CREDENTIALS_INVALID` | 401 |
| IP not in allowlist | `ADMIN_IP_NOT_ALLOWED` | 403 |
| Wrong password | `ADMIN_CREDENTIALS_INVALID` | 401 |
| 2FA enabled, `totp` missing | `ADMIN_TOTP_REQUIRED` | 401 |
| 2FA enabled, `totp` wrong | `ADMIN_TOTP_INVALID` | 401 |
| >10 attempts in 60s | `RATE_LIMITED` | 429 |

The login form must handle `ADMIN_TOTP_REQUIRED` as a **state transition, not an error** — re-present the same credentials with a TOTP field rather than making the admin retype everything.

> The IP check runs *before* the password check, so a wrong-IP request returns `ADMIN_IP_NOT_ALLOWED` even with a bad password. Minor information disclosure; noted so the panel does not treat it as a bug.

### `GET /admin/auth/me`

Requires a valid token. **No permission required.**

**`200` response** — this is `AuthenticatedAdmin`, **not** the fuller `AdminView` from login:

```json
{
  "success": true,
  "data": {
    "id": "665f1c...",
    "email": "ops@wishtick.com",
    "roles": ["super_admin"],
    "permissions": ["admins:manage", "users:view"],
    "jti": "9c2e-..."
  }
}
```

⚠ It carries `jti` but has **no `name`, `status`, `totpEnabled`, `ipAllowlist`, `lastLoginAt`, `createdAt`**. If the panel needs the display name after a page reload, cache the `admin` object from the login response — `me` will not give it back.

### `POST /admin/auth/logout`

Requires a valid token. No body. Denylists the current `jti` for a full session length.

**`200`** → `{ "success": true, "data": { "ok": true } }`

### `POST /admin/auth/totp/setup`

Requires a valid token. No body. Generates and stores a **pending** secret.

**`200` response**

```json
{
  "success": true,
  "data": {
    "secret": "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP",
    "keyUri": "otpauth://totp/Wishtick%20Admin%3Aops@wishtick.com?secret=...&issuer=Wishtick+Admin&algorithm=SHA1&digits=6&period=30"
  }
}
```

Render `keyUri` as a QR code client-side and show `secret` as copyable fallback text. TOTP is SHA-1, 6 digits, 30s period, ±1 step of skew accepted.

**Errors:** `ADMIN_TOTP_ALREADY_ENABLED` / 409 if already enrolled. Calling setup twice overwrites the pending secret — safe to retry.

### `POST /admin/auth/totp/enable`

Requires a valid token. Confirms the pending secret.

**Body** — `{ "token": "482915" }` (exactly 6 digits)

**`200`** → `{ "success": true, "data": { "ok": true } }`

**Errors:** `ADMIN_TOTP_ALREADY_ENABLED` / 409; `ADMIN_TOTP_INVALID` / 401 (wrong code, **or setup was never called**).

---

## Admin management

### `POST /admin/admins` — permission `admins:manage`

**Body**

```json
{
  "email": "mod@wishtick.com",
  "password": "at-least-twelve-chars",
  "name": "Moderator One",
  "roles": ["moderator"],
  "ipAllowlist": ["203.0.113.7"]
}
```

| Field | Type | Rules |
|---|---|---|
| `email` | string | required, valid email, lowercased |
| `password` | string | required, **12–128 chars** |
| `name` | string | required, ≤120, trimmed |
| `roles` | string[] | required, **≥1**, each of `super_admin\|moderator\|support\|analyst` |
| `ipAllowlist` | string[] | optional; **exact string match, no CIDR** |

**`201`** → `data` is an `AdminView` (same shape as `login.admin`).

Writes an audit entry `admin.create`.

**Errors:** `VALIDATION_FAILED` / 400; `CONFLICT` / 409 on a duplicate email; `ADMIN_FORBIDDEN` / 403.

### `GET /admin/admins` — permission `admins:manage`

No query parameters.

**`200`** → `data` is a **bare array** of `AdminView`. No pagination, no total.

**✅ Fixed (Sprint 5)** — see `PATCH /admin/admins/:id` and `POST /admin/admins/:id/password` below.

There is still **no delete**, deliberately: removing an admin row would orphan every audit entry naming them. Offboarding is `status: "disabled"`, which ends live sessions and blocks sign-in.

### `PATCH /admin/admins/:id` — permission `admins:manage`

Body (all optional): `name` (≤120), `roles` (≥1 of the four), `status` (`active|disabled`), `ipAllowlist` (string[], **exact match, no CIDR**).

**`200`** → the updated `AdminView`. Audited as `admin.update` with a per-field diff.

Two refusals exist to prevent locking everyone out, and both are enforced server-side:

| Condition | `error.code` | HTTP |
|---|---|---|
| Disabling **your own** account | `ADMIN_FORBIDDEN` | 403 |
| Removing **your own** super-admin role | `ADMIN_FORBIDDEN` | 403 |
| Disabling or demoting the **last active super-admin** | `ADMIN_FORBIDDEN` | 409 |

Setting `status: disabled` also stamps `tokensInvalidBefore`, so live sessions end immediately rather than surviving until the 2h token expiry.

### `POST /admin/admins/:id/password` — permission `admins:manage`

Body: `password` (12–128). **`200`** → the updated `AdminView`.

Ends every session that admin holds (`tokensInvalidBefore`) — leaving old tokens valid after a credential reset would mean a compromised session survives the action taken to stop it. Two-factor enrolment is unchanged. Audited as `admin.password_reset`; **the password itself is never written to the log.**

---

## User management

### `GET /admin/users` — permission `users:view`

**Query**

| Param | Type | Rules |
|---|---|---|
| `search` | string | optional, ≤200. Case-insensitive substring across `email`, `phone`, `name` (regex-escaped, unanchored) |
| `status` | string | optional, a `UserStatus` — `active\|suspended\|deleted` |
| `page` | int | optional, ≥1, **default 1** |
| `limit` | int | optional, 1–100, **default 25** |

**`200` response**

```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "665aa1...",
        "email": "user@example.com",
        "phone": null,
        "name": "Asha R",
        "status": "active",
        "roles": ["user"],
        "suspendedReason": null,
        "emailVerified": true,
        "phoneVerified": false,
        "acquisition": { "source": "whatsapp", "ref": "inv_88", "capturedAt": "2026-03-02T08:00:00.000Z" },
        "lastLoginAt": "2026-07-20T21:14:00.000Z",
        "createdAt": "2026-03-02T08:00:00.000Z"
      }
    ],
    "total": 1284,
    "page": 1,
    "limit": 25
  }
}
```

Offset pagination, sorted **`createdAt` descending**. `page`/`limit` echo the clamped values. `emailVerified` / `phoneVerified` are booleans derived from timestamps — the raw `…VerifiedAt` values are not exposed. `acquisition` is `null` for users created before attribution was wired.

### `GET /admin/users/:id` — permission `users:view`

**`200` response** — the `UserAdminView` fields are spread **flat at the top level**; there is no `profile` wrapper:

```json
{
  "success": true,
  "data": {
    "id": "665aa1...",
    "email": "user@example.com",
    "phone": null,
    "name": "Asha R",
    "status": "active",
    "roles": ["user"],
    "suspendedReason": null,
    "emailVerified": true,
    "phoneVerified": false,
    "acquisition": { "source": "whatsapp", "ref": "inv_88", "capturedAt": "..." },
    "lastLoginAt": "...",
    "createdAt": "...",
    "counts": {
      "wishlists": 4,
      "events": 2,
      "giftsGiven": 7,
      "giftsReceived": 3,
      "reels": 1
    },
    "activity": [
      { "type": "gift",     "at": "2026-07-19T10:00:00.000Z", "summary": "Gift fulfilled" },
      { "type": "wishlist", "at": "2026-07-02T09:00:00.000Z", "summary": "Wishlist \"Birthday 2026\"" }
    ]
  }
}
```

`counts` has exactly those five keys. `activity` is at most **10** entries — the 5 most recent gifts *given* plus the 5 most recent wishlists, merged and sorted by `at` descending. `type` is `gift` or `wishlist` only.

**⚠ Gap — `activity` is not a real timeline.** Gifts *received*, events, and reels appear in `counts` but never in `activity`; there is no pagination and no date filter. It is a five-and-five sample, adequate for "what has this person been doing lately" and not for support triage of an older incident. Label it in the UI as *Recent activity*, not *History*.

**Errors:** `NOT_FOUND` / 404 — for both a malformed id and a missing user. Note this is the generic code, **not** an admin-prefixed one.

### `POST /admin/users/:id/suspend` — permission `users:manage`

**Body** — `{ "reason": "Repeated harassment in wishlist chat" }` (required, ≤500, trimmed)

**`200`** → `data` is the updated `UserAdminView` (`status: "suspended"`, `suspendedReason` set).

Suspension kills every session and disconnects live sockets cross-instance, and writes an audit entry with a `status` diff. The user's next request is refused.

### `POST /admin/users/:id/reactivate` — permission `users:manage`

No body. **`200`** → updated `UserAdminView`. Audited.

### `POST /admin/users/:id/force-logout` — permission `users:manage`

No body. Invalidates every session and disconnects sockets **without** suspending the account. **`200`** → updated `UserAdminView`. Audited (diffs `tokensInvalidBefore`).

All three share the same `NOT_FOUND` / 404 behavior as the detail route.

---

## Moderation

### Reference enums

| Enum | Values |
|---|---|
| `ReportTargetType` | `wish`, `reel`, `message`, `wishlist`, `event`, `user` |
| `ReportStatus` | `open`, `reviewing`, `resolved`, `dismissed` |
| `ReportSource` | `user`, `auto` |
| `ModerationAction` | `approve`, `remove`, `flag`, `escalate` |

**Severity is a plain number, not an enum.** At intake: base `1`, `+2` if the target is a `user`, `+1` if it is a `message` or `wish`, `+1` if the source is `auto` — so 1–4. `escalate` adds `5` each time, so it is unbounded. Render it as a number or bucket it in the UI; do not assume a fixed scale.

### `GET /admin/moderation/queue` — permission `moderation:view`

**Query**

| Param | Type | Notes |
|---|---|---|
| `type` | `ReportTargetType` | optional |
| `status` | `ReportStatus` | optional — **defaults to `open`** |
| `page` | int | optional, ≥1, default 1 |
| `limit` | int | optional, 1–200, default 50 |

**`200`** → `data` is a **paginated envelope**, matching `GET /admin/users`:

```json
{
  "success": true,
  "data": [
    {
      "_id": "6670aa...",
      "reporterId": "665aa1...",
      "source": "user",
      "targetType": "message",
      "targetId": "6660bb...",
      "reason": "harassment",
      "detail": "Repeated abuse after being asked to stop",
      "status": "open",
      "severity": 2,
      "resolution": null,
      "handledBy": null,
      "handledAt": null,
      "createdAt": "2026-07-20T18:22:00.000Z",
      "updatedAt": "2026-07-20T18:22:00.000Z",
      "__v": 0
    }
  ]
}
```

Note the raw Mongoose document: **`_id`, not `id`**, and `__v` is present. There is no DTO projection here, unlike the user endpoints.

Sorted **`severity` descending, then `createdAt` ascending** — worst first, then oldest.

**✅ Fixed (Sprint 3).** The queue is now paginated — `page` + `limit` are forwarded and the response carries `total`, so a backlog beyond the first page is reachable. This was a breaking change to the response shape (bare array → `{items,total,page,limit}`); the backend e2e test was updated with it.

**⚠ Gap — one status at a time, never "all".** `status` defaults to `open` and is always applied, so there is no way to fetch a combined view. The panel must render status as tabs (Open / Reviewing / Resolved / Dismissed) and fire one request per tab.

**✅ Fixed (Sprint 3)** — see `GET /admin/moderation/reports/:id/target` below. A queue entry still carries only `targetType` + `targetId`; resolving it into readable content is a second call.

### `GET /admin/moderation/reports/:id/target` — permission `moderation:view`

The reported content itself, normalized across all six target types so one UI component renders any of them.

**`200` response**

```json
{
  "success": true,
  "data": {
    "targetType": "message",
    "targetId": "6660bb2e...",
    "exists": true,
    "title": "Chat message",
    "body": "You are worthless and nobody wants you here.",
    "mediaUrl": null,
    "authorId": "665aa1c4...",
    "state": null,
    "createdAt": "2026-07-20T09:00:00.000Z",
    "fields": { "kind": "text", "chatId": "6640aa...", "edited": false, "attachments": 0 }
  }
}
```

| Field | Meaning |
|---|---|
| `exists` | **`false` when the document is gone** — hard-deleted after being reported, or a malformed id. Not an error: the report is still actionable, there is just nothing to preview |
| `title` | Headline — a wishlist/event title, or a type label where there is none |
| `body` | The reported words, where the type has any. Render verbatim |
| `state` | `deleted` \| `archived` \| `cancelled` \| `rejected` \| `suspended`, or `null`. **Non-null means a takedown already happened**, so a second `remove` is a no-op |
| `authorId` | The account that produced the content — link it to the user detail page |
| `fields` | Type-specific extras, safe to render as a label/value list |

Per type, `body` carries: the message text, the wish text, the wishlist description, the event description. Reels and users have no body — reels carry `mediaUrl`, users carry their record in `fields`.

**Errors:** `REPORT_NOT_FOUND` / 404 for a malformed or unknown **report** id. A missing *target* is `exists: false` with a 200.

### `POST /admin/moderation/reports/:id/act` — permission `moderation:act`

**Body**

```json
{ "action": "remove", "reason": "Violates community guidelines" }
```

| Field | Type | Rules |
|---|---|---|
| `action` | enum | required — `approve\|remove\|flag\|escalate` |
| `reason` | string | optional, ≤500, trimmed. Becomes `resolution` |

**`200`** → `data` is the single updated report document.

**What each action does**

| Action | Resulting `status` | Severity | Default `resolution` |
|---|---|---|---|
| `approve` | `dismissed` | unchanged | `Content approved — no action` |
| `remove` | `resolved` | unchanged | `Content removed` |
| `flag` | `reviewing` | unchanged | `Flagged for a second look` |
| `escalate` | `reviewing` | **+5** | `Escalated` |

**`remove` performs a per-type takedown** and notifies the content owner (`CONTENT_REMOVED`):

| Target | Effect |
|---|---|
| `message` | Soft delete — sets `deletedAt` |
| `wish` | Sets `moderationStatus: rejected`; **if its reel is already `released`, flips it to `releasing` and re-enqueues compilation** |
| `reel` | Clears `reelMediaUrl` (video taken down, record kept) |
| `wishlist` | Sets `archivedAt` |
| `event` | Sets `status: cancelled` |
| `user` | Suspends the account via the same path as `POST /users/:id/suspend` — **no `CONTENT_REMOVED` notification**, since suspend does its own |

Removing a wish from a released reel is therefore **not instant** — it triggers a background recompile. The UI should say so rather than implying the video is already gone.

**Errors**

| Condition | `error.code` | HTTP |
|---|---|---|
| Malformed or unknown report id | `REPORT_NOT_FOUND` | 404 |
| Report already `resolved` or `dismissed` | `REPORT_ALREADY_HANDLED` | 409 |

`reviewing` is **not** blocked — a flagged or escalated report can be acted on again. A missing target document is a silent no-op: the report still resolves. `INVALID_MODERATION_TARGET` exists in the error enum but is never thrown.

Every action writes an audit entry `moderation.<action>` with a before/after diff.

---

## Analytics

All three are permission `analytics:view`, and all three are **Redis-cached for 300s** (`ANALYTICS_CACHE_TTL_SECONDS`). There is no invalidation after a rollup, so figures can lag by up to five minutes — **including today's**. Show a "as of" timestamp rather than implying live data.

Dashboards read the `MetricDaily` pre-aggregate, never the raw event stream. A missing rollup reads as **`0`**, not an error and not `null` — so "the rollup did not run" and "nothing happened" are indistinguishable to the client. Flag suspicious all-zero days in the UI.

### `GET /admin/analytics/overview`

**Query:** `from`, `to` — both optional, `YYYY-MM-DD`. The handler uses `to ?? from`, defaulting to **today (UTC)**. It is a single-day snapshot, not a range.

**`200` response**

```json
{
  "success": true,
  "data": {
    "date": "2026-07-21",
    "dau": 412,
    "wau": 2180,
    "mau": 7640,
    "totalUsers": 18422
  }
}
```

`totalUsers` is a live count of non-deleted users; the other three come from the rollup.

### `GET /admin/analytics/acquisition`

**Query:** `from`, `to` — optional `YYYY-MM-DD`. Defaults: `from` = 30 days ago, `to` = today. `to` is inclusive.

**`200`** → `data` is a **bare array**, sorted by `signups` descending:

```json
{
  "success": true,
  "data": [
    { "source": "whatsapp", "signups": 812 },
    { "source": "invite",   "signups": 430 },
    { "source": "organic",  "signups": 221 }
  ]
}
```

Only two fields per row. A null source is stored as `organic` at rollup time. Sources seen in practice: `whatsapp`, `invite`, `referral`, `organic`, `group_gift`.

### `GET /admin/analytics/engagement`

**Query:** same as acquisition — `from` defaults to 30 days ago, `to` to today, `to` inclusive.

**`200` response** — exactly **seven** keys, all numbers:

```json
{
  "success": true,
  "data": {
    "wishlistsCreated": 1840,
    "eventsCreated": 320,
    "giftsCreated": 2211,
    "giftsFulfilled": 1502,
    "groupGiftsCreated": 190,
    "reelsCreated": 88,
    "reelsReleased": 71
  }
}
```

**⚠ Gap — the engagement metric set is much smaller than the product spec.** Sprint 11 of the backend plan lists invites created, items added, items fulfilled, public vs private wishlist usage, wishlist chat activity, group-gift chat activity, gifts reserved/purchased separately, offline gifts completed, and reels submitted/shared. **None of those exist.** Seven counts ship; the rest need backend work. Do not design an engagement dashboard around metrics the API cannot return.

Note these count from the domain collections filtered on `createdAt`, whereas overview filters the event stream on `ts` — the two are not guaranteed to reconcile exactly.

---

## Audit log

### `GET /admin/audit` — permission `audit:view`

**Query**

| Param | Type | Notes |
|---|---|---|
| `targetType` | string | optional, exact match — e.g. `user`, `admin` |
| `targetId` | string | optional, exact match |
| `limit` | int | optional, 1–500, **default 100** |

**`200`** → `data` is a **bare array**, sorted `createdAt` descending:

```json
{
  "success": true,
  "data": [
    {
      "_id": "6671cc...",
      "actorAdminId": "665f1c...",
      "actorEmail": "ops@wishtick.com",
      "action": "user.suspend",
      "targetType": "user",
      "targetId": "665aa1...",
      "diff": [
        { "field": "status", "before": "active", "after": "suspended" },
        { "field": "suspendedReason", "before": null, "after": "Repeated harassment" }
      ],
      "meta": { "reason": "Repeated harassment" },
      "ip": "203.0.113.7",
      "createdAt": "2026-07-21T09:12:00.000Z"
    }
  ]
}
```

`actorEmail` is denormalized so the trail survives the admin being deleted. `diff` contains only genuinely-changed fields; `undefined` is normalized to `null`. The comparison is by JSON string and is **not recursive** — a nested object is stored whole. There is **no `updatedAt`**; the log is append-only and no update or delete path exists.

Actions currently emitted: `admin.create`, `user.suspend`, `user.reactivate`, `user.force_logout`, `moderation.approve|remove|flag|escalate`.

**✅ Fixed (Sprint 5).** Now paginated with `total`, and filterable by `action`, `actorAdminId`, and an inclusive `from`/`to` UTC day range. `GET /admin/audit/actions` returns the distinct action names for populating a filter. Response shape changed from a bare array to `{items,total,page,limit}`.

---

## Related user-facing endpoints

Not part of the admin panel, but they feed it — documented so the queue's contents make sense.

### `POST /reports` — **user** authentication (not admin)

Rate limited **20 / 60s**. Body: `targetType` (enum, required), `targetId` (string ≤64, required), `reason` (string ≤80, required), `detail` (string ≤1000, optional).

**`201`** → `{ "id": "6670aa...", "status": "open" }`

A duplicate `(reporter, target, source)` is **not an error** — the endpoint returns `201` with the *existing* report's id and current status, making it idempotent per reporter.

> Consequence worth knowing when reading the queue: the dedup unique index is **not partial on status**, so a user who reported a target once can *never* file a new report for it, even after the first was resolved or dismissed. Repeat-offender signal is therefore undercounted.

### `POST /events/track` — **user** authentication

Rate limited **120 / 60s**. Body `{ "events": [ { "name": "...", "props": {}, "source": "...", "ts": "..." } ] }`, ≥1 event. **`202`** → `{ "accepted": <submitted count> }`.

`accepted` is the *submitted* count, not the inserted count — the write is unordered and failures are not reflected.

### Health probes

`GET /health` (liveness) and `GET /ready` (Mongo + Redis + queue). **Unprefixed and unversioned** — not `/api/v1`. Both are still wrapped in the success envelope.

---

## Known Gaps

Ranked by how much they constrain the panel. Each needs backend work; none can be solved client-side.

| # | Gap | Consequence for the panel |
|---|---|---|
| 1 | ~~No endpoint returns reported content~~ | **Fixed in Sprint 3** — `GET /admin/moderation/reports/:id/target` |
| 2 | ~~Moderation queue capped at 50, unpaginated~~ | **Fixed in Sprint 3** — `page` + `limit` forwarded, `total` returned |
| 3 | ~~Audit unpaginated, no date or actor filter~~ | **Fixed in Sprint 5** — paginated, plus action/actor/date filters |
| 3b | **No `GET /admin/moderation/reports/:id`** | The panel finds a single report by scanning each status page — works, but is four requests where one would do |
| 4 | ~~Admins cannot be edited or disabled~~ | **Fixed in Sprint 5** — `PATCH` + password reset. Delete remains intentionally absent |
| 5 | **Engagement exposes 7 metrics**; the product spec lists ~15 | Most of the intended engagement dashboard cannot be built |
| 6 | **No refresh token; 2h hard session** | Admins are logged out mid-task and must re-enter TOTP. Panel must protect unsaved work |
| 7 | **No logout-all endpoint** (`tokensInvalidBefore` is DB-write only) | Cannot revoke a compromised admin's other sessions from the UI |
| 8 | **`GET /admin/auth/me` omits `name` and `status`** | Display name is lost on reload unless cached from login |
| 9 | **User `activity` is a 5+5 sample, no pagination** | Not sufficient for support triage of older incidents |
| 10 | **IP allowlist is exact-match, no CIDR** | Unusable for office ranges or VPN pools; per-IP entries only |
| 11 | **Analytics zero is ambiguous** — a missing rollup and a genuine zero are identical | Panel cannot distinguish "no data" from "no activity" without a separate health signal |

Gaps 1 and 2 are the ones to fix before the moderation sprint is worth starting. Gap 3 makes the audit sprint thin. The rest are workable with honest UI copy.

---

## Appendix — error codes the panel will see

Admin-specific: `ADMIN_UNAUTHENTICATED`, `ADMIN_FORBIDDEN`, `ADMIN_NOT_FOUND`, `ADMIN_CREDENTIALS_INVALID`, `ADMIN_TOTP_REQUIRED`, `ADMIN_TOTP_INVALID`, `ADMIN_TOTP_ALREADY_ENABLED`, `ADMIN_IP_NOT_ALLOWED`, `ADMIN_DISABLED`, `REPORT_NOT_FOUND`, `REPORT_ALREADY_HANDLED`, `INVALID_MODERATION_TARGET` (never thrown).

Generic: `VALIDATION_FAILED`, `NOT_FOUND`, `CONFLICT`, `RATE_LIMITED`, `INTERNAL_ERROR`, `SUSPECT_INPUT_REJECTED`, `UNAUTHENTICATED`, `FORBIDDEN`.

Unmapped statuses fall back to the literal string `HTTP_<status>` (e.g. `HTTP_418`), so `error.code` is a string — do not exhaustively switch on it without a default branch.

Error codes are **append-only** by backend convention; renaming one is treated as a breaking API change. Safe to switch on.
