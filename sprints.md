# Wishtick — Sprint Plan

Figma file: **`6WXJf85eSt7J3SpPzyoJP2` (Wishtick-UI-v2)** — open any node via
`https://www.figma.com/design/6WXJf85eSt7J3SpPzyoJP2/Wishtick-UI-v2?node-id=<node id, ':' → '-'>`

> **✅ v2 re-inventory complete (2026-08-01).** Full metadata diff of v2 section
> `7:80` against the v1 inventory: **201 top-level frames** — 64 new, 24 removed,
> 12 redesigned in place (size changed), 1 renamed. All node IDs below are
> updated to v2. The headline additions: a **group-gift refund flow** (~16
> frames) with **Refunds & Payouts + UPI collection** in Profile, **group-gift
> summary with extra charges / multiple gifts**, an **event guest list**
> (view/details/download), **Profile → My Memories**, and a wishlist **quick-add
> popup**. Audio *compose* screens were dropped (previews remain — confirm
> whether audio messages are cut entirely). Screens marked **⚠️ v2** below were
> added or redesigned and need fresh exports —
> [`UI_Screen/_v2_export_list.txt`](UI_Screen/_v2_export_list.txt) is the
> download checklist (PNG named `<node-id with '-'>.png`).
>
> ⚠️ **The refund / payout / UPI frames predate the money-model decision below**
> and describe a product Wishtick is not building. See *Decision: Wishtick never
> handles money*.

**Working agreement (applies to every sprint):**
1. Before building a screen: pull its Figma frame (screenshot + design context) by node ID and match it exactly.
2. No hardcoded colors/fonts/spacing — semantic tokens only (`plan.md` §4).
3. Every screen verified in **light and dark** mode before "done".
4. Screens marked *(variant)* are alternate states of the same screen — build one widget, cover all states.

---

## Decision: Wishtick never handles money (2026-08-05)

**Wishtick is an affiliate business, not a payments business.** Revenue comes
from referral commission when a user is sent to a merchant and buys there. No
payment is ever collected, held, or disbursed by us.

Two vendors make that work:

| Vendor | Job |
|---|---|
| **SerpApi** | The catalogue. Google Shopping search, and the only route to a *merchant* product URL. |
| **Cuelinks** | The monetization. Turns a merchant URL into a tracked `clnk.in` link and reports the sales it produced. |

### What this invalidates

Several v2 frames and earlier backlog lines assume Wishtick is a payment
processor. They describe flows that cannot exist:

- **Razorpay** — not integrated, anywhere. Sprint 5's "Razorpay groundwork" and
  Sprint 6's "order/verify/webhook" are both cancelled.
- **The ~16 refund frames** — there is nothing to refund. Wishtick holds no
  funds, so there is no PSP to call and no processing/settled/failed lifecycle.
  They are being rebuilt as **settle-up** screens (see Sprint 6b).
- **UPI payout collection** (Sprint 9's *Refunds & Payouts*) — Wishtick pays
  nobody out. At most it stores a group-gift buyer's UPI ID so contributors can
  pay **that person** directly.

### What a group gift becomes

A **split-the-bill ledger**, not a pot of money:

1. Contributors **pledge** an amount (the `ContributionStatus.PLEDGED` state
   that has sat unused in the schema since Sprint 6's original design).
2. One person — the initiator — buys at the merchant through the affiliate
   link. Wishtick earns the referral on that single purchase.
3. Everyone else settles with the buyer **outside the app** (UPI, cash), marks
   it paid, and the buyer confirms receipt.

"Confirmed" therefore changes meaning: it is the buyer acknowledging a share
arrived, not a payment captured. `collectedAmountMinor` becomes *pledged*, not
*raised* — worth renaming when 6b touches the model.

---

## Sprint 0 — Foundation & design system ✅ DONE

**Goal:** installable themed shell; all later sprints only add features.

**Delivered:**
- Packages (riverpod 3, go_router, dio, secure storage, shared_preferences), CI workflow (format + analyze `--fatal-infos` + test + debug APK).
- **Theming:** `app_palette.dart` (only file with colour literals) → `WishtickColors` ThemeExtension (light **and** dark value per token) → `context.colors.*` in widgets. Plus `app_typography.dart`, `app_dimens.dart`, `app_theme.dart`.
- **`design_system_guard_test.dart`** — scans `lib/` and fails the build on a stray colour literal or a widget importing the palette. Makes "colours stay consistent" enforced, not aspirational.
- Theme mode (system/light/dark) persisted, applied before first frame, exposed at Profile → Appearance.
- Fonts bundled as variable TTFs (Montserrat + Playfair Display) instead of runtime-fetched.
- Splash screen, 5-tab shell with the custom bottom nav, placeholder screens carrying their sprint + Figma node ID.
- Dio client, auth interceptor with single-flight refresh rotation, `ApiException` mapped from the backend's `{success:false, error:{code,…}}` envelope.

**Status:** 29 tests passing, analyzer clean, debug APK builds.

| Screen | Figma node ID |
|---|---|
| Splash | `143:356` |
| Bottom navigation (part of Home) | `51:11` |
| Color System reference page | `0:1` |

**Carry-over into Sprint 1:**
- ✅ **Palette verified (2026-07-31).** All 28 Color System swatches sampled from
  a full render of node `0:1` and applied to `app_palette.dart` — including the
  naming correction (CTA = *plum deep* `#3F0E4C`; *plum* is `#5B1A6E`) and the
  background correction (*ivory deep* `#F5EFE4`, not cream). See plan.md §4.2.
  All 95 tests (incl. WCAG AA contrast) pass on the verified values.
- ✅ Splash now resolves the stored session and hands over to the router
  (signed in + onboarded → home, incomplete → onboarding, else → welcome).
- ✅ `onSessionExpiredProvider` is overridden in `main()` to sign out and
  redirect (`sessionExpiryOverride`).
- Logo mark on the splash is a placeholder; needs the exported asset (`214:607`).

**Backend:** none (uses existing `/health`).

---

## Sprint 1 — Auth (1.5 wk) — 🟡 IN PROGRESS

**Goal:** new user signs in with phone + OTP, session persists across launches.

### Decision: passwordless is now the real auth model

The design assumes phone + OTP sign-in, but the backend only had password
signup/login — `verify/phone/confirm` marked a number verified and issued no
session, and only worked for an already-registered user. Two endpoints were
added rather than bending the app to passwords:

| Endpoint | Behaviour |
|---|---|
| `POST /auth/otp/request` | Sends a 6-digit code to any number, registered or not. 202. |
| `POST /auth/otp/verify` | Consumes the code, finds-or-creates the user, returns `{user, tokens, isNewUser}`. |

Supporting changes: `OtpPurpose.SIGN_IN` (codes are salted by purpose, so a
verification code can never mint a session); `passwordHash` is now optional, and
`login` rejects passwordless accounts with the same generic error as a wrong
password; `verifyOtpLogin` reports `ACCOUNT_DELETED` rather than a duplicate-key
409 when a soft-deleted account still holds the number.

**Done — backend:** the two endpoints above, 9 e2e tests. Full suite green
(16 suites, 286 tests) and 16/16 unit suites.

**Done — app:**
- `PhoneNumber` (E.164, matches the backend regex, `+91` default) — 13 tests
- `AuthRepository` covering both the passwordless and password flows
- `SessionController` — restore / accept / signOut / expiry, with the router
  redirecting off session status; splash resolves the session then hands over
- `SignInController` — request → countdown → verify, every OTP error code
  mapped to copy, attempts-remaining surfaced
- Welcome carousel (structure from `7:81`)
- 70 Flutter tests green, analyzer clean under `--fatal-infos`

### Screens

Designs were exported to [`UI_Screen/`](UI_Screen/) (1x PNGs) after the Figma MCP
tool-call limit ran out.

| Screen | Figma node ID | State |
|---|---|---|
| Welcome carousel ×4 | `7:81`, `280:33`, `280:56`, `280:102` | ✅ built |
| Mobile number entry | `17:329` (+ `143:141`; ⚠️ v2 adds variant `4032:148` — reconcile once exported) | ✅ built |
| OTP verification | `17:530` | ✅ built |
| Create Your Profile | `31:608` | ✅ built |
| Select Your Avatar | `195:131` | ✅ built (20 avatars in `assets/avatar/`) |

**Flow, as the designs actually show it:** Welcome ×4 → Mobile number → OTP →
*(new user)* Create Your Profile → onboarding steps 2–5. "Create Your Profile" is
labelled **Step 1 of 5** and maps onto `OnboardingStep.PROFILE`, so it belongs to
onboarding rather than to auth — the route sits under `/onboarding`, not
`/welcome`.

### Notes from the exports

- **OTP box count.** `17:530` draws four boxes but its own copy says "6-digit
  code", and the backend issues six (`OTP_LENGTH=6`). Built with six. Worth
  correcting in the design file.
- **"Every Ocassion Made Special!"** (`280:33`) is misspelled in the design —
  should be "Occasion". Implemented verbatim so code and design match; one word
  to change once confirmed.
- **Hero artwork** is cropped from the 1x screen export
  (`assets/images/welcome_hero.png`), so it is soft on a 3x display. A proper
  @2x/@3x export of just the artwork would fix it.
- **Avatar assets.** `195:131` shows 20 illustrated avatars; those images are not
  exported yet.

### Backend additions for Create Your Profile

The screen collects five things; the API supported two. Three were added:

| Field | Status |
|---|---|
| Name | ✅ `displayName` on the profile step |
| Date of Birth | ✅ `dateOfBirth` |
| Photo | ✅ `photoMediaId` via `/media` (`PROFILE_PHOTO`) |
| Gender | ✅ **added** — `Gender` enum (male/female/other), the design's fixed three |
| Email | ✅ **added** — writable on the profile step and `PATCH /me`, stored **unverified** |
| Preset avatar | ✅ **added** — `avatarKey` (`avatar_01`…`avatar_20`) |

Notes on the choices:

- **Email lands unverified.** A self-declared address proves nothing; possession
  is established by `/auth/verify/email/*`. `UsersService.setEmail` rejects an
  address another account already holds (409) and is a no-op when unchanged, so
  re-submitting the step is safe.
- **`avatarKey` and `photoMediaId` are mutually exclusive** — setting either
  clears the other, so "which picture" never has two answers. Only the key is
  stored; the image ships with the app.
- **Avatar keys are validated against a pattern**, so a path like
  `../../etc/passwd` cannot reach the asset lookup.

14 e2e tests cover these (`test/profile-fields.e2e-spec.ts`).

### Onboarding gate

The router now holds a signed-in user in onboarding until the required profile
step is done — a fresh OTP account goes to step 1 rather than the tab shell, and
onboarding is unreachable once complete. `isNewUser` from `/auth/otp/verify`
skips the status round trip for brand-new accounts. If the status call fails the
app defaults to *complete*: letting someone in on a failed request is
recoverable, trapping them in onboarding is not.

**Still to do:** real SMS adapter (MSG91/Twilio) in place of the console stub,
SMS OTP auto-read on Android, and photo upload on the profile screen (needs the
`/media` presign → PUT → confirm round trip; scheduled with profile editing in
Sprint 9 — the camera button currently explains this).

---

## Sprint 2 — Onboarding personalization ✅ DONE (app + backend)

**Goal:** interests → per-category detail → colors → size & fit → important dates → all set.

**Delivered — backend:**
- **Taxonomy reseeded to the v2 designs** (migration `013-taxonomy-v2`; the v1
  flat interests/colours are deactivated, never deleted): 12 interest
  categories + ~75 category-prefixed sub-interests (`fashion_shoes`,
  `tech_gaming`…), **40 grouped colours** with hexes sampled from the design
  render, shoe sizes in **UK/US/EU** (`uk_3`–`uk_13`, `us_4`–`us_13`,
  `eu_36`–`eu_47`), `fit_preference` (slim/regular/relaxed/oversized), and the
  `special_moments` occasion. Labels are verbatim from Figma **including its
  typos** ("Activites", "Liesure", "Deserts") — fix in both places together.
- New preference fields: `interestCategories`, `customInterests` (free text —
  the "Anything Else You Love?" screen, deliberately not taxonomy-validated),
  `fitPreference`. Step gating and `/me` extended accordingly.
- **`/me/important-dates`** (GET/POST/DELETE) — person, free-text relationship,
  occasion key, date; own collection indexed by `(userId, date)` so Home's
  Upcoming rail and reminders can query it. This starts paying down plan §6's
  *friends/relations* gap.
- 11 new e2e tests; suites using retired v1 keys migrated. **Full backend e2e:
  18 suites, 312 tests green.**

**Delivered — app:** all six screens + the flow (screens push in selection
order through category details; every step skippable; step 5's Continue runs
`/onboarding/complete` → All Set → shell). 115 Flutter tests, analyzer clean,
APK builds.

| Screen | Figma node ID | Notes |
|---|---|---|
| Interests (main grid) | `36:839` | built from this export; ⚠️ v2 `4097:556` not exported yet — reconcile when it lands |
| Category detail ×11 | `204:471`, `238:4`, `238:55`, `204:539`, `239:370`, `239:259`, `239:106`, `239:157`, `239:208`, `239:310`, `239:411` | one widget, options per category |
| "Anything Else You Love?" (Other) | `239:454` (selected `239:510`) | custom free-text + suggested tiles |
| Favorite colors | `39:1061` (v2 redesign, built from the `39-106.png` export) | variants `4097:612`, `4038:308` unexported |
| Size & Fit | `51:42` | UK/US/EU toggle resets the pick on switch |
| Important dates | `199:10` (variants `204:321`, `204:371`) | per-entry Save Date hits the API immediately |
| All set | `199:145` | Explore Wishtick → `markOnboardingComplete` → home |

**Open items:**
- **Selection caps are inferred** (`OnboardingCaps`: 2 categories, 2 per
  category, 4 colours) — every mock shows its counter at capacity ("2/2",
  "4/4"), which is ambiguous. One constants block to change once design
  confirms.
- **Tile photography not exported** — tiles fall back to a themed wash +
  initial (layout exact). Export `assets/onboarding/<taxonomy-key>.png` to
  light them up. Same for the dates screen's occasion collage carousel and the
  All-Set confetti heart.
- "Teal Blue" and "Peri winkle" swatches are **grey placeholders in the design
  file** — stand-in hexes seeded; needs design.
- Onboarding is **not yet resumable mid-flow** (a killed app restarts at step
  1's screen; saved steps are already idempotent server-side). Wire
  `completedSteps` → initial route if this matters before launch.

**API:** `GET onboarding/options|status`, `POST onboarding/steps/:step`, `POST onboarding/complete`, `/me/important-dates`.

---

## Sprint 3 — Wishlist core ✅ DONE

**Goal:** create wishlists, add products by URL or search, manage items.

**Delivered:** wishlist CRUD + item management + reorder, product search and
URL resolution (behind `IProductProvider`, fixture-backed at the time), device
photo picker for covers, and `recipientName` / `relation` / `occasionKey` added
to `WishlistItem` so an item can say who it is for.

> **Note:** `POST /wishlists/:id/items/from-product` lives on
> `ProductImportController` in the **products** module, mounted under
> `/wishlists` — not on `WishlistsController`. That keeps wishlists from
> importing the products module. Easy to conclude it does not exist.

| Screen | Figma node ID |
|---|---|
| My Wishlist tab | `280:428` (⚠️ v2 adds variant `4097:481`) |
| Create new wishlist | `280:476` |
| Wishlist detail (own) | `280:212` |
| Wishlist detail — celebration state (variant) | `288:721` |
| Wishlist item view | `280:300` |
| Product detail | `280:403` ⚠️ v2 redesign (2467→2136 px) |
| Add to wishlist popup | `280:584` (variants `285:638`, `2175:498`) |
| Choose wishlist popup | `2172:446` |
| Quick add popup | ⚠️ v2 `2092:388` (variant `4096:5`) — **new**; frame repurposed from a v1 scratch frame |

**API:** `wishlists` CRUD + items + reorder, `POST products/resolve-url`, `POST wishlists/:id/items/from-product`, `GET products/search`, media upload for covers.

---

## Sprint 4 — Home, sharing & discovery ✅ DONE

**Goal:** Home tab live; share wishlists; discover feed with recommendations.

**Delivered:** Home rails (occasion grid, upcoming occasions, events, group
gift), a real address book (`/me/addresses` with a single-default invariant),
the Discover feed, share links, and the public wishlist view.

> **On "recommendations":** there is no recommendation model. Wishtick knows the
> *occasion*, never the recipient's taste, so shelves are curated by occasion in
> `discover.curation.ts` — an editorial table, honestly labelled as one.
> `rakhi` and `best_wishes` were added to the occasion taxonomy for Home's grid.

| Screen | Figma node ID |
|---|---|
| Home | `51:11` (⚠️ v2 variant `4095:1345`; v1 variant `80:438` deleted) |
| Delivery location | `2293:25` |
| Discover tab (gift feed) | `280:131` (variants `2167:18`; ⚠️ v2 adds `4097:287`, `4097:418`) |
| Share wishlist sheet | `288:780` (variant `2204:40`) |
| Public wishlist view (deep link) | `291:1074` |

**API:** wishlist `share` + `public/wishlists/:slug`, `dashboard/summary`, `products/search`.
**Backend (new):** Discover feed endpoints (per-friend occasion suggestions, price bands, premium picks); friends/relations + upcoming-occasions source; location/addresses stub for the Home header.

---

## Sprint 5 — Gifting & orders ✅ DONE

**Goal:** reserve gifts on friends' wishlists, buy via affiliate redirect, order states.

**Delivered:** the full reserve → buy → track → delivered flow, plus the invite
view and RSVP. An `Order` model with a six-stage timeline, a human `WTK-…`
reference, and HMAC-verified courier-webhook groundwork that nothing calls yet.

| Screen | Figma node ID |
|---|---|
| Friend's wishlist | `291:1074` |
| Friend's wishlist product | `291:1170` (variant `316:834` ⚠️ v2 redesign, 1508→1714 px) |
| Friend's event view ("Siya's 24th") | `291:1008` ⚠️ v2 redesign (1321→1455 px) |
| Reserve gift sheet | `299:1371` |
| Order confirmed | `299:1486` (variants `316:444`, `316:298`, `2175:909`, `2209:223`, `2209:243`) |
| Order tracking | `299:1513` (variant `316:405`) |
| Order delivered | `299:1620` (variant `316:460`) |
| Add new address (checkout) | `316:883` |

**API:** `POST items/:itemId/reserve`, `DELETE …/reserve`, `items/:itemId/gift-offline`, `gifts/:id/purchase|fulfill|complete`, `GET r/:itemId` redirect, `GET orders/mine|:id`, `GET gifts/:id/order`.
**Backend (new):** address book CRUD (moved here from Sprint 4); order-tracking model (status timeline). ~~Razorpay groundwork~~ — cancelled, see the money-model decision.

**Deliberate gaps, all because the data does not exist:**
- **No delivery date.** Every carrier field is null until there is a logistics
  feed, so Order Confirmed says *"Confirmed by the store at checkout"* rather
  than printing the mock's `26 Jul 2026`.
- **Timeline has three states, not two** — `Pending` / `Not reported` / a real
  timestamp. The server marks every stage *before* the current one reached, so
  a delivered order showed four filled dots labelled "Pending".
- **No star rating** on the product page: no ratings API exists.
- **"Proceed to Pay" is "Continue to Store"** — Wishtick takes no payment. The
  purchase is the gifter's word, which is what `POST /gifts/:id/purchase` is.

**Also added (not in the original scope):** a *Shared with you* section on the
wishlist tab — without a wishlist you do not own, none of Sprint 5 is reachable.
Owner-only actions (Edit/Share/Delete, per-item delete) are now hidden when
`access.canManage` is false; they were being drawn on friends' lists and would
have 403'd.

**Known theme defect (not Sprint 5's to fix):** dark-mode `colors.primary`
(#5B1A6E) measures **1.61:1** against the dark page background — under the 3:1
floor for large text. Affects every headline drawn in it, on screens from
earlier sprints too. `context.headlineBrandColor` works around it on the screens
shipped here; re-tuning the dark palette is a design decision.

---

## Sprint 6a — Real catalogue & monetization ✅ BACKEND DONE & LIVE-VERIFIED

**Goal:** replace the fixture catalogue with real products, and make an outbound
click actually earn.

Split out of Sprint 6 because it is the revenue path, and because real products
make every group-gift screen in 6b testable with real data.

**Delivered — backend:**
- `SerpApiProductProvider` behind the existing `IProductProvider` port. The port
  promised the swap would be "one new file plus a config flag"; it held.
- `CuelinksClient` (`links/convert`, `campaigns`, `transactions`, `ping`) and
  `MonetizationService`.
- `ConversionSyncService` — cursor-based incremental sale reconciliation, hourly.
- `Conversion` + `AffiliateSyncState` schemas, migration `017`.
- 14 unit + 11 e2e tests, all against a stubbed `fetch`. Full backend: **183
  unit, 356 e2e**, tsc and eslint clean.

### The cost split that shaped the design

SerpApi charges per engine call, and the two engines do different jobs:

| Engine | Gives | Cost |
|---|---|---|
| `google_shopping` | ~40 results: title, price, image, merchant *name*, rating | 1 call per search |
| `google_immersive_product` | `product_results.stores[].link` — the **merchant's own URL** | 1 call **per product** |

`google_shopping`'s `product_link` points at *Google's* page, which no affiliate
network can monetize. Resolving every search result would therefore cost ~40
SerpApi calls **plus** ~40 Cuelinks calls per page, for products nobody asked
for.

So **monetization is lazy**: search stays one call and leaves `affiliateUrl`
null; the merchant URL and tracked link are resolved at the *click*, cached on
the product row, and backfilled overnight for products someone saved. Every
failure returns a working unmonetized link — earning nothing is bad, a dead buy
button is worse. Measured live: first click ~2s (two vendor calls), second
click **12 ms**.

### What the live probe corrected (2026-08-05)

Every one of these was coded from the vendors' public docs and was **wrong**.
The docs are not a substitute for a probe.

| Assumed | Actual |
|---|---|
| `engine=google_product` returns sellers | **HTTP 400 — "The Google Product service is no longer offered by Google."** The engine is retired. |
| Sellers at `sellers_results.online_sellers[].direct_link` | `product_results.stores[].link`, via `engine=google_immersive_product` |
| Detail lookup keyed by `product_id` | Keyed by `immersive_product_page_token`, which **only a search response carries** |
| Cuelinks returns `{tracking_url, affiliated}` | Wrapped: `{data: {…}}` — reading the top level yields `undefined`, which looks exactly like "not affiliated" |
| Sub-IDs are `subid1…subid5` | First dimension is **`subid`**. `subid1` is accepted and **silently dropped** — that is the item id, so all sale attribution was being lost |
| Transactions paginate by `next_cursor` | Page-based: `{data, meta:{page, next_page, total_pages}}` |
| Tracking domain `clnk.in` | `linksredirect.com` |

**`affiliated: false` is not a gate.** Live calls against Amazon India
(campaign 817) and Flipkart (campaign 1) both return `affiliated:false`
*together with* a valid `tracking_url` on a real campaign — it appears to
describe this publisher's approval state, not whether the URL can be tracked.
Gating on it rejected 100% of links. The presence of `tracking_url` decides; the
flag is recorded for reporting.

### Two more the *device* run found (2026-08-06)

Both invisible to the API probe, because both need the app's own query shapes.

1. **Discover was empty.** `priceBandSection()` and `premiumSection()` search
   with *only* a min/max price — no keyword, no category. The fixture catalogue
   answered that by filtering its in-memory list; a keyword engine cannot, so
   `queryFor()` returned null and both shelves were silently dropped.
   `/discover/feed` answered **200 in 24 ms with zero sections** — a success
   response for a broken feed. A price filter is now treated as intent to
   browse and gets a generic `gifts` term.
2. **`PRODUCT_TIMEOUT_MS=4000` was too tight for SerpApi.** It proxies a live
   Google Shopping search, and measured latency straddles 4 s: a cold search
   burned all three attempts (`serpapi unavailable (timeout) and no cached
   results`) while the very next identical call succeeded. The timeout, not the
   vendor, was the outage. Now **15 s with 1 retry** — a timeout here means
   Google is slow, and a second full wait doubles the user's latency without
   improving the odds.

> **Cache caveat that will waste your time:** a failed or empty search is cached
> under the same key as a good one (fresh TTL 15 min, stale 24 h). After
> changing provider behaviour, a fix appears not to work until the key expires.
> `freshness: "cached"` on a zero-item result is the tell.

### Things that will bite if forgotten

- **The immersive token must be persisted at search time.** It is the only route
  to a merchant URL, and it exists nowhere else. A Product row without one can
  never be monetized *or* re-priced — which is why `IProductProvider` grew an
  optional `getDetailsByRef(externalId, ref)`.
- **`upsertMany` must not write `affiliateUrl` unconditionally.** A catalogue
  provider always reports it as null, so an unguarded write erased a resolved
  link every time anyone re-searched the product. Fixed, with a test pinning it.
- **Conversion sync walks from page 1 every run**, because a *revision* to an
  old sale (pending → confirmed, changed commission) can surface on any page.
  It stops at the first page with nothing new, so the steady state is one call,
  and refuses a `next_page` that does not strictly advance.

### Verified live

`PRODUCT_PROVIDER=serpapi` + `AFFILIATE_NETWORK=cuelinks` against the running
API: search returned real Indian listings (Amazon.in ₹1,999 / Myntra ₹1,699 /
Flipkart ₹1,199), import succeeded, and `GET /r/:itemId` answered **302 to
`linksredirect.com`** carrying `subid=<itemId>` and our own `subId` click id,
wrapping the real `amazon.in/dp/…` merchant URL. Second click served from cache.

**Backend suite:** 186 unit, 359 e2e, tsc and eslint clean.

### Verified on device (2026-08-06)

Physical device against the real API (`adb reverse tcp:3000 tcp:3000`, run with
`--dart-define=WISHTICK_API_BASE_URL=http://127.0.0.1:3000`; Dart's HttpClient
bypasses Android's cleartext policy, so no manifest change was needed):

- **Discover** renders "Gifts Under ₹2,000" and "Premium Picks for You" with
  real listings, images off Google's CDN, and real merchant names.
- **Search** for "sony" returned Sony WH-CH520 ₹4,199 (Vijay Sales), SA-D40M2
  ₹5,719 struck through from ₹6,499 (vlebazaar.in), PS4 Slim ₹19,999
  (GameLoot), ULT Field 1 ₹9,599 (TATA CLiQ LUXURY). The struck-through price
  appears only on the one row with a genuine discount — `toListPriceMinor`
  behaving correctly on live data.

> `adb reverse` is cleared when `flutter run` attaches. Re-add it *after* the
> app is installed, or every request fails with "No connection".

### Still open

- **No conversion has ever been observed**, because no real purchase has been
  made through a Wishtick link. `/transactions` returns an empty page today, so
  the reconciler's parsing of a *populated* row is still only covered by tests —
  and given how much else in these vendors' docs was wrong, treat its field
  names as unconfirmed until a real sale lands.
- **Shelf quality is poor for the generic browse.** `gifts` returns marketplace
  long-tail — "Gift Card ₹1,000.00" from *Itihasikala*, Ferrero Rocher as a
  "Premium Pick". Correct, but not compelling. Curated per-band queries (or
  price bands layered onto the category shelves) would fix it; that is a
  product decision, not a bug.

---

## Sprint 6b — Group gifts as a split-the-bill ledger (~2.5 wk)

**Goal:** chip-in coordination, group chat, and settle-up — with no money
passing through Wishtick. See the money-model decision above.

**Already built (Sprint 6's original backend, mostly reusable):** the group-gift
funding state machine, contributions with durable `(groupGiftId, idempotencyKey)`
idempotency, over-fund policy, the nightly reconciler, share links + OG progress
card, and the participant model. **Group-gift chat is done too** — provisioned
eagerly, WebSocket fan-out, system messages, anti-spoiler masking. sprints.md
previously listed "extend chat to group-gift scope" as new work; it is not.

**Model changes needed:**
- `PLEDGED` becomes the default contribution state; `CONFIRMED` re-means *the
  buyer acknowledged this share arrived*.
- **Settle-up tracking**: who has paid the buyer, who has not, who confirmed.
- **Misc charges** (delivery, wrapping) as splittable line items.
- **Multi-gift groups**: one group gift covers several items. This is the schema
  change — `itemId` becomes a list — and it needs a migration. Doing it with
  charges rather than after, since the summary frame (`4006:463`) needs both and
  splitting means migrating twice.
- Optional buyer UPI ID, so contributors can pay a person directly.

| Screen | Figma node ID |
|---|---|
| Create group gift | `299:1658` |
| Group gift details | `316:166` |
| Group gift summary | ⚠️ v2 `4006:463` (variant `4007:801`) — **new** |
| Miscellaneous charges | ⚠️ v2 `4007:568` — **new** (extra costs on a group gift) |
| Add charge | ⚠️ v2 `4007:628` — **new** |
| Add gift (multi-gift group) | ⚠️ v2 `4007:720` — **new** |
| Group created | `299:1735` (variants `308:3` ⚠️ v2 redesign 1456→1768 px, `316:320`; ⚠️ v2 adds `4095:786`, `4095:1056`, `4099:1096`, `4099:1323`) |
| Contribute sheet (pay) | `316:119` (⚠️ v2 adds variant `4095:538`) |
| Group participants | `316:536` (variants `2262:1084`, `2262:1152` ⚠️ v2 redesign 1501→1024 px; ⚠️ v2 adds `4092:66`, `4093:273`, `4093:338`, `4093:405`, `4095:702`) |
| Group chat | `316:640` (⚠️ v2 adds variant `4093:474`) |
| **Settle-up flow** | ⚠️ v2 `4092:174` (states: `4092:203`, `4093:444`, `4095:574`, `4095:611`, `4095:637`, `4095:883`, `4095:967`, `4095:1036`, `4095:1169`, `4095:1181`, `4099:936`, `4099:976`, `4099:1026`, `4099:1075`, `4099:1199`) — **all of it survives.** See the mapping below. |
| Group thank-you | `2219:603` (variant `2288:5`) |

**API:** `POST items/:itemId/group-gift`, `group-gifts/:id/join|contribute|purchase|share`, `GET group-gifts/:id`, `public/group-gifts/:slug`, chat endpoints — all already built. New: settle-up marks, charges, multi-gift.
**Backend (new):** pledge/settle-up ledger; **charges + multi-gift group-gift model** (schema change + migration). ~~Razorpay order/verify/webhook~~, ~~refund engine~~, ~~UPI payout collection~~ — all cancelled; Wishtick holds no funds. ~~extend chat to group-gift scope~~ — already done.

**Flutter:** essentially all of it. Today there is only a read-only `GroupGift`
model and Home's chip-in card — no repository, no screens.

### The settle-up frames, mapped (2026-08-06)

**The earlier prediction in this file was wrong.** These were described as "drawn
for PSP refunds (processing / settled / failed / retry), which cannot happen
here — expect several to collapse". Reading them says the opposite: the designer
built the whole flow **person-to-person from the start**. `4099:976` states it
outright —

> *"You are sending refund of ₹333 to each contributor **outside Wishtick**.
> Once sent, mark each refund as 'Sent'."*

— and `4095:1036` asks the contributor to confirm *"your refund of ₹333 **from
the host**"*. Nothing anywhere expects Wishtick to hold or move money. The
frames need **no redesign**; only the word "refund" is doing double duty, since
it means "the host sends your money back", not a card reversal.

It is a **balance-adjustment flow that runs in both directions**:

| Direction | Frame | What it is |
|---|---|---|
| **Shortfall** (gift costs more than pledged) | `4092:174` | *Contribution Request* — additional amount, per-member split, message to group |
| **Surplus** (over-collected) | `4093:444` | *Refund Distribution* — extra balance, split equally or custom per contributor |
| ↳ host | `4099:1199` | *Request UPI Details* — who has / has not shared one, per-person Request |
| ↳ host | `4099:936` | *UPI Received* — all collected, "you can now send refunds" |
| ↳ host | `4099:976` | *Refund Progress* — per-contributor **Mark as Sent** → **Sent** |
| ↳ contributor | `4099:1075` | *UPI Details Required* — "Rohan will refund this amount to you" |
| ↳ contributor | `4095:611` | *Enter UPI ID* sheet, with "save this UPI ID in my profile" |
| ↳ contributor | `4095:1036` | *Refund Received?* — Yes / Not Yet |
| ↳ contributor | `4095:1169` | *Thank You* — confirmed |

**This also answers the Sprint 9 question.** "UPI collection" is not a payout
Wishtick makes — it is contributors handing the *host* a UPI ID so the host can
pay them back. It belongs here, in 6b, and the Profile screens should be dropped.

**Six frames are not exported yet:** `4092:203`, `4095:574`, `4095:637`,
`4095:883`, `4095:967`, `4099:1026` (plus `4095:1056` from *Group created*).
Likely intermediate/empty states of the above; export before building those.

### What this needs from the backend

- **`Settlement`** — one row per (group gift, contributor): direction
  (`return` | `top_up`), `amountMinor`, status `pending → sent → confirmed`,
  plus `sentAt` / `confirmedAt`. This is the ledger the whole flow reads.
- **UPI ID** on the user profile, with the "save for next time" opt-in, and a
  per-settlement copy so a later profile edit cannot rewrite history.
- **Balance** = pledged − (gift cost + charges), which is what decides whether
  the group is in shortfall or surplus.
- **Contribution request** — a shortfall broadcast with a per-member amount.

### Build status — 6b is implemented, front to back

Backend and Flutter are both done and green (375 e2e, 193 unit, 273 widget/unit
Dart). Beyond the list above, building it forced four additions:

- **`items[]` on the group-gift view** — the summary needs a title, thumbnail
  and price per row, and the view only carried `itemId`. Assembled server-side,
  primary-first, with `removable: false` on the primary so no client has to
  re-derive which one the `×` may not touch.
- **`hostId` on the view** — the participant list badges the host (`316:536`),
  and `share` only tells the *caller* whether they are the host.
- **`PATCH /group-gifts/:id/charges/:chargeId`** — the charges screen has an
  edit pencil. Remove-then-add would leave the charge deleted if the second
  call failed, silently lowering the Grand Total.
- **`GROUP_GIFT_BILL_LOCKED`** — split out of `GROUP_GIFT_NOT_OPEN`, which was
  serving two conditions. The client can now offer the one thing that still
  works (a contribution request) instead of saying the group is closed.

### Group chat and the thank-you note

**Group chat (`316:640`)** is built. The backend module already existed; the
Flutter side is new — domain, REST repository, and a Socket.IO client on the
`/chat` namespace. Shape worth keeping:

- **Messages are posted over REST, never over the socket.** The backend routes
  both transports through one validation and authorization path and the gateway
  only *delivers*; posting over the socket would be a second way in with a
  second set of rules.
- **System cards render from `systemType` + `systemPayload`, not from `body`.**
  That is what the backend's own note asks for, so the copy can change without
  breaking clients. An unrecognised type falls back to the server's text rather
  than drawing a blank card.
- **The socket sits behind `ChatSocketPort`.** The real one reads the handshake
  token from secure storage, which has no platform channel under `flutter test`
  — the interface is what makes the controller testable.
- New dependency: `socket_io_client`.

**Thank-you note (`2219:603`, `2288:5`)** is built, and needed backend that did
not exist: `thankYouNote` / `thankYouAt` on the group gift plus
`POST /group-gifts/:id/thank-you`. Gated on the **item's owner**, not the
initiator — the note comes from the person the gift was for, and the host is
usually not that person — and only once the gift has been bought.

⚠️ **Two gaps here.** Both exported frames are the *read* view: no composer was
designed, so the sheet that writes the note is an addition. And the card's
floral artwork is not exported, so the card is drawn from tokens — the same warm
gradient and script headline, without inventing an asset that will not match
when the real one lands.

### Three more the device found in chat and dark mode

7. **The chat sat on "Reconnecting…" forever.** `chatSocketProvider` is
   `autoDispose` and the controller only ever `ref.read` it — which establishes
   no dependency, so the socket was collected the moment after it connected.
   The server log was the tell: it showed a socket authenticating and then
   vanishing. Now `ref.watch`ed in `build`.
8. **System cards said "Someone Paid" for a named contributor.** The payload
   carries `contributorId`, not a name — I had guessed `actorName`. Names are
   now resolved against the group's participant list, and `anonymous: true` is
   honoured as a deliberate withholding rather than missing data.
9. **Outlined and text buttons were unreadable in dark mode.** The theme took
   `primary` as their foreground in both themes; in dark that is #5B1A6E on
   #17101B — **1.61:1**. App-wide, not just 6b. Both now step to `brandMark`
   in dark (5.89:1), the same substitution `context.headlineBrandColor` already
   makes for headlines, and a theme test asserts AA on both.

Smaller: the thank-you card's "With warmest regards," dangled over nothing,
because the view exposed no recipient name. `recipientName` is now on the view
(the item's owner), and the whole sign-off is hidden when there is none.

### Four defects only the device found

All four passed `flutter analyze` and the whole test suite before they were
caught by walking the flow on a real phone. Each now has a regression test.

1. **The create screen crashed on open** — "Tried to modify a provider while
   the widget tree was building". `_primeGoal` seeded the goal straight out of
   `build()`. Now primed after the item loads and via a `ref.listen`, both of
   which run outside the build phase.
2. **"Add Another Gift" spun forever, then 429'd.** Its `FutureProvider.family`
   was keyed on a record holding a `Set`. Records compare by field but a `Set`
   compares by *identity*, so every rebuild minted a new provider, refetched,
   and rebuilt. **Nothing without value equality may go in a family key.**
3. **A themed button in a `Row` asserted.** The button theme sets
   `minimumSize: Size.fromHeight(h)` — that is `Size(double.infinity, h)`, an
   infinite *minimum* width. It is what makes footer buttons full-bleed, and it
   is why the settle-up ledger's "Mark as Sent" needed a bounded box. Third
   escape of this bug class (splash, onboarding, now this).
4. **The suggested-amount chips stacked one per line.** A `Container` with an
   `alignment` expands to its maximum *bounded* constraint, and a `Wrap` hands
   children the full row width. Replaced with a hugging `Row`.

Also fixed while there: Home's chip-in card was still a Sprint-6 placeholder
(`_notYet('Chipping in')`) and titled itself from `message`; it now opens the
group gift and uses the real `title`.

Not defects, but worth knowing: the app deliberately does **not** follow the
system theme (`ThemeMode.light` default, changed only in Profile → Appearance),
and Profile is still a Sprint-9 placeholder, so there is no in-app way to reach
Appearance yet.

### Three places the design does not answer

1. **The summary has no CTA.** Neither `4007:801` nor `4006:463` carries a
   button, but the flow has to reach "Miscellaneous Charges" somehow, and
   "+ Add Another Gift" is the only other control. Shipped with a **Continue**
   footer — replace it if the intended affordance turns up.
2. ~~**"Add Another Gift" is drawn as a catalogue search**~~ — **settled: it
   creates a wishlist item from the catalogue product.** Built as the design
   draws it. `POST /group-gifts/:id/gifts/from-product` creates the item on the
   recipient's wishlist and then claims it through the same lock, transaction
   and holder gift as any other line.

   Two things this forced:

   - **It is the only path on which a non-owner writes to another person's
     wishlist.** The authority is having initiated the group gift, checked in
     `GroupGiftService`; `ProductImportService.importForWishlist` deliberately
     does no access check of its own, and its doc comment says so.
   - **`WishlistItem.hiddenFromOwner`.** The recipient never asked for this
     item, so showing it on their own list would both confuse the list and give
     the surprise away. Set whenever the group gift is hidden from them;
     filtered out of the owner's list *and* 404'd on direct fetch, so guessing
     the id does not reach it either. Everyone else still sees it — they must,
     or two people buy the same thing.

   If the claim fails after the item is created, the item is deleted: it exists
   only to be claimed, and a stray entry nobody asked for and nobody can see is
   worse than an error.
3. **"Additional Amount Required" (`4092:174`) is shown, never entered.** The
   bill is frozen once anyone contributes, so a shortfall can only come from
   the price moving — which only the host can see. Shipped as an editable
   field, prefilled from the balance when there is a shortfall.

Also still open from the original mapping: **a member who refuses to pay their
share.** Nothing re-splits; the balance simply stays open. No frame covers it.

---

## Sprint 7 — Events & invitations (2 wk)

**Goal:** create events, design invitations from templates, invite + RSVP.

| Screen | Figma node ID |
|---|---|
| Create event ("What are you celebrating?") | `257:733` ⚠️ v2 redesign (854→884 px); variant `257:755` (v1 variant `263:828` deleted) |
| Relation picker popup | `2252:423` (variants `2252:485`, `2252:540`, `2252:566`; ⚠️ v2 adds `4095:1530`) |
| Invitation — choose photo | `2248:5` |
| Invitation — upload | `2248:70` ⚠️ v2 redesign (902→963 px) |
| Invitation templates | `263:900` (variants `263:966`, `263:1014`, `263:1061` ⚠️ v2 redesign 1234→1073 px, `2248:140`, `2248:187`; v1 "colors temp" `2262:1252` deleted) |
| Events overview | `2058:16` (⚠️ v2 adds `4095:1486`, `4096:30`, `4104:1539`) |
| **Event guest list** | ⚠️ v2 `4096:66` (variant `4099:1256`) — **new** |
| **Guest details** | ⚠️ v2 `4096:162` — **new** |
| **Download guest list** | ⚠️ v2 `4096:206` (variant `4097:255`) — **new** |

**API:** `events` CRUD + publish, `invite-templates`, `events/:id/invites` (+ resend/link), `public/invites/:token` + RSVP, `events/mine|invited`.
**Backend (new):** guest-list view is mostly a projection over invites + RSVPs, but **guest-list download/export** (CSV/PDF per the v2 screens) is a new endpoint.

> **Already built in Sprint 5:** the invitee side — `/i/:token` renders
> `public/invites/:token` and RSVP works, gated so an event-only wishlist
> appears only after a yes/maybe. What remains here is the **host** side:
> creating events, designing invitations, sending invites, and the guest list.
> An Event still has **no venue field** (only a free-text slot inside an invite
> template), which is why the invite screen shows a time but no location.

### What shipped

**Backend.** `Event` gained `venue`, `personName` and `relation` (a `relation`
taxonomy key, seeded by migration `019-relations`; the taxonomy cache key went
to `v3` so a warm cache cannot hide the new kind). `GET
events/:id/invites/export` returns a `StreamableFile` in PDF, XLSX or CSV —
CSV and XLSX de-formula any cell starting `= + - @`, because a guest named
`=cmd|calc!A1` would otherwise execute in Excel. `InviteView` gained
`createdAt` ("Added on"). A new `event_invite` media purpose accepts GIF, MP4
and PDF up to 10 MB — the only purpose that does — and `Event.inviteMediaUrl`
carries the host's own artwork through to the invitee. The invite card's venue
slot now falls back to the event's own venue, which closes the "time but no
location" gap called out above.

**Flutter.** Create event (`257:733` → `257:755`), the relation picker
(`2252:423`), the invitation method sheet (`2248:5`), the template picker
(`263:900`), the preview (`263:1014`), upload-your-own (`2248:70`), the guest
list (`4099:1256`), guest details (`4096:162`) and the download sheet
(`4096:206`). Reached from the centre "+" → Event, which was a Sprint-4
placeholder until now.

### Four defects only the device found

1. **`GET /invite-templates` answers with `{templates: [...]}`,** not the bare
   array every other list route returns, and its query parameter is
   `eventType`, not `type`. The picker was empty and the filter was ignored.
2. **`POST events/:id/invite/preview` takes `{inviteTemplate: {...}}`,** not a
   bare choice. Sending the choice unwrapped read as "no choice".
3. **The preview drew the OG raster.** `imageUrl` is the 1200×630 image
   WhatsApp crops to when a link unfurls; the frame is a portrait card. Drawn
   `cover` into 4:5 it sliced the headline in half. The card is now always
   rendered natively from the palette and the resolved copy.
4. **The RSVP pills were unreadable.** `success` on `successSubtle` is #3FBFA6
   on #7FD9C6 — **1.7:1**. `successSubtle`/`warningSubtle` were mid-tone
   accents, not backgrounds. They are now near-white tints with their own ink
   tokens (`onSuccessSubtle`, `onWarningSubtle`, `onDangerSubtle`), all three
   covered by the AA contrast test.

Also: `DateTime.now().timeZoneName` gives `IST`/`GMT+05:30`, which the server's
`IsTimezone` rejects — event creation would have 400'd on every device. Dart
cannot report an IANA zone, so `kDefaultTimezone` is `Asia/Kolkata` until one
lands on the profile.

### Still open

- **Events overview** (`2058:16`, `4095:1486`, `4096:30`) is not built — the
  frames are not exported. Until it is, an existing event's guest list is only
  reachable at the end of the create flow.
- **No frame covers *adding* guests.** `POST events/:id/invites` takes up to
  200 recipients and is fully tested, but nothing in the design opens it, so
  the guest list can only fill up through RSVPs to a shared link.
- **Guest details omits the "Group Gift — 1 Active" row** of `4096:162`.
  Nothing links an event to a group gift; wiring one would add an
  events→group-gifts module dependency for a single count.
- The occasion tiles and the template cards use glyphs and a typographic
  placeholder rather than the designed illustrations, which are not exported.

---

## Sprint 8 — Memories (2 wk)

**Goal:** time-locked capsules: create, contribute messages, unlock experience.

| Screen | Figma node ID |
|---|---|
| Memories tab | `2032:460` |
| Create memory | `2058:16` |
| Add photo message | `2073:55` |
| Add text message | `2078:233` |
| Add audio message | `2074:152` |
| Add video message | `2074:129` |
| Photo preview | `2074:76` |
| Video preview | `2078:255` |
| Audio preview | `2078:202` |
| Text preview | `2240:71` |
| Combined preview | `2219:554` |
| Memory preview (full experience) | `2078:357` (variants `2078:390`, `2078:529`, `2078:592`) |
| Memory unlock moment | `2198:73` |

**Backend (new): Memories module** — capsule (person/relation/occasion/date/cover), contributor invites, media messages (photo/video/audio/text via `media` module), time-lock rule, unlock job (BullMQ scheduled) + notifications. Decide: extend `reels` or new `memories` module.

> **Three node IDs above are wrong.** The Memories tab is exported as
> **`4104:1433`**, not `2032:460`; Create Memory as **`4104:1539`**, not
> `2058:16`; and `2198:73` is *"When should this Memory Unlock?"* — the second
> step of the create flow, not an "unlock moment".

### The module decision: a new `memories` module

`ReelCollection` is also a time-locked collection of contributed messages, and
extending it was the cheaper-looking option. It was rejected: a reel is for a
**registered recipient**, is birthday-only, and compiles its wishes into one
MP4; a memory is for a *named person who usually has no account* — that is the
point of it — carries an occasion and a cover, opens at an instant the host
picks to the minute, and is browsed wish by wish. Sharing the schema would have
made `recipientUserId`, `birthdayMonth/Day`, `releaseAt` and the whole
compilation pipeline mean one thing for reels and another for memories, and put
a shipped, tested feature at risk for it. The two modules share the `media`
module and the scheduler pattern; nothing else.

### What shipped

**Backend.** `MemoryCapsule` + `MemoryWish`, migration `020-memory-indexes`,
`memory-unlock` on the shared scheduler (with a staleness guard, so a host who
moves the date does not get opened at the old instant), a `MEMORY_UNLOCKED`
domain event and its notification. Two new media purposes: `memory_cover`, and
`memory_wish` — the only purpose that admits audio as well as stills and video.

**The time-lock lives in exactly one place**, `memory.views.ts`. Content is
attached only for an `unlocked` capsule; metadata — the count, contributors'
first names — is deliberately visible while sealed, because the frames show
"4 Wishes" on a locked capsule. `GET /memories/:id/wishes` **409s** while
sealed rather than answering an empty list, so no client can present "locked"
as "nobody wrote anything". Eight of the eighteen e2e tests exist to prove it,
including that the *host* cannot read their own sealed capsule.

**Flutter.** Memories tab (`4104:1433`), create memory (`4104:1539`), unlock
date/time (`2198:73`), the add-a-wish flow (`2073:55`, `2078:233`, `2074:129`,
audio), the previews (`2074:76`, `2240:71`, `2078:202`, `2078:255`) and the
story-style experience (`2078:357` + variants). Reached from the centre "+" →
Memory, which was a placeholder until now.

**Voice notes and videos play**, via `just_audio` and `video_player`: the
transport row of `2078:529` is real (replay-5 / play-pause / forward-5, live
position against duration, the waveform filling to the playhead), and a video
holds on its first frame under a play button in the preview (`2078:255`) and
autoplays in the story (`2078:390`). A clip reaching its end advances the story
— a still segment still runs on a six-second timer, but a timer would cut a
voice note off mid-sentence.

### Defects the device found

1. **Page headlines were the wrong typeface — across Sprint 7 too.** Every
   frame draws a big page headline in Playfair; `headline*` is Montserrat and
   `display*` is Playfair. Sprint 7's "Tell us about your event", "Choose a
   Template" and "Preview Your Invite" all used `headline*`, which is why they
   rendered sans against serif frames. Every onboarding and auth screen already
   used `displaySmall`; the convention existed and three screens had broken it.
2. **A text wish was printed twice** in the story — once as the card body and
   again as the caption below it. The caption belongs to media wishes only.
3. **A text wish's preview card was left-aligned** where the frame centres it:
   a centred `Text` inside a `crossAxisAlignment: start` Column only spans its
   own content, so there is nothing to centre it in. Fourth escape of the
   loose-constraints bug class.
4. **Every `XFile.fromData` upload sent the wrong content type — Sprint 7's
   too.** `XFile.fromData` documents its `name` as *ignored* on io, so
   `file.name` came back empty and the guess fell through to `image/jpeg`: a
   `.m4a` uploaded as a JPEG, got a `.jpg` storage key, and would not play.
   `MediaRepository.uploadFile` now takes the filename explicitly, and the
   guess table covers every extension the app can send.
5. **Native players could not reach the dev backend.** Android blocks cleartext
   HTTP from API 28, but Dart's own stack (`dart:io`, so Dio and
   `Image.network`) does not go through that policy — which is why the API and
   images worked over `http://localhost:3000` while ExoPlayer failed on the
   same host. A **debug-only** network-security config now permits cleartext to
   `localhost`, `127.0.0.1` and `10.0.2.2`; release keeps TLS everywhere.

### Still open

- **Two frames are not exported** — "Add audio message" (`2074:152`) and the
  combined preview (`2219:554`). Both paths are built and working, but
  **inferred** from their neighbours (`2078:202` and the photo/text previews)
  rather than matched. The four compose screens are one screen with a kind
  picker at the top, which is what `2074:152` would have shown.
- **The capsule detail screen has no frame at all.** The exports jump from
  creating a capsule to adding a wish to the opened story, but something has to
  hold the countdown, the contribute link and "Add a Wish". Built from patterns
  the matched screens use, and marked inferred in its doc comment.
- The occasion tiles use glyphs rather than the designed illustrations, which
  are not exported. Same substitution as the event-creation grid.

---

## Sprint 9 — Notifications & Profile (2 wk)

**Goal:** notification center + push; complete profile section.

| Screen | Figma node ID |
|---|---|
| Notification center | `324:1392` |
| Notification popups | `2012:109` (variants `2067:120`, `2219:529`) |
| Gift arrival | `2012:72` |
| Gift details | `2012:163` |
| Thank-you — photo message | `2015:271` |
| Thank-you — video message | `2015:382` |
| Thank-you — text message | `2209:104` |
| Thank-you — audio message | `2209:122` |
| Thank-you previews (video/text/audio) | `2209:141`, `2227:146`, `2209:156` |
| Thank-you sent | `2209:203` |
| Profile | `64:158` (variant `2296:51`) |
| Edit profile | `90:21` (variant `2297:158`) |
| My Events | `324:973` (variants `2297:208`, `2252:302`; cards `2227:58`) |
| My Invites | `324:1071` (variants `2252:262`, `2297:228`; cards `2227:90`) |
| Gifts received | `324:1108` |
| Gifts given | `324:1253` (variant `2227:163`) |
| Gifts on hold | `324:1210` |
| Address book | `324:1295` (backend shipped in Sprint 5) |
| Add new address | `324:1340` |
| Privacy policy | `2262:1019` |
| Help centre | `2252:628` |
| About us | `2252:703` (about page `2293:23`) |
| Logout popup | `2252:611` |

**API:** `notifications` list/read/preferences, `thank-you` flows, `/me` + preferences + export/delete/restore, gifting given/received/on-hold.
**Backend (new):** FCM device-token registry + push pipeline; real mail adapter.

> **Refunds & Payouts / UPI collection — resolved, drop from this sprint.**
> Reading the v2 frames (see Sprint 6b's mapping) settles it: UPI collection is
> contributors handing the **host** a UPI ID so the host can pay them back
> outside the app. Wishtick pays nobody out. It is built in 6b. What may still
> belong in Profile is the *saved* UPI ID — `4095:611` offers "save this UPI ID
> in my profile" — which is one field on the profile screen, not a section.

---

## Sprint 10 — Hardening & release (1.5 wk)

> Add to the dark-mode audit: `colors.primary` on a dark background is
> **1.61:1**, below the 3:1 large-text floor. See Sprint 5's note.

- Dark-mode audit across all ~90 screens (goldens), accessibility pass (contrast, tap targets, TalkBack/VoiceOver).
- Performance: image caching, list virtualization, startup time.
- Deep-link matrix test (wishlist/invite/group-gift slugs), analytics funnel wiring, crash reporting (Sentry/Crashlytics).
- Store assets, privacy disclosures, staged rollout (internal → closed → production).

---

## Backlog / not scheduled

- Workspace screens (`2175:1021`, `2209:221`) — purpose unclear, clarify with design.
- Reels public pages (`public/reels`) — web-share surface, likely not in-app.
- Hindi localization, remote-config palette (design supports it via token layer).
