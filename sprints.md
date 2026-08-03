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

**Working agreement (applies to every sprint):**
1. Before building a screen: pull its Figma frame (screenshot + design context) by node ID and match it exactly.
2. No hardcoded colors/fonts/spacing — semantic tokens only (`plan.md` §4).
3. Every screen verified in **light and dark** mode before "done".
4. Screens marked *(variant)* are alternate states of the same screen — build one widget, cover all states.

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

## Sprint 3 — Wishlist core (2 wk)

**Goal:** create wishlists, add products by URL or search, manage items.

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

## Sprint 4 — Home, sharing & discovery (2 wk)

**Goal:** Home tab live; share wishlists; discover feed with recommendations.

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

## Sprint 5 — Gifting & orders (2 wk)

**Goal:** reserve gifts on friends' wishlists, buy via affiliate redirect, order states.

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

**API:** `POST items/:itemId/reserve`, `DELETE …/reserve`, `items/:itemId/gift-offline`, `gifts/:id/purchase|fulfill|complete`, `GET r/:itemId` redirect.
**Backend (new):** address book CRUD; order-tracking model (status timeline); Razorpay integration groundwork.

---

## Sprint 6 — Group gifts + payments (2 wk → resize to ~3 wk)

**Goal:** full chip-in flow with real payments, group chat, **refunds and payouts**.

> ⚠️ **v2 grew this sprint substantially**: a full refund flow (~16 frames), a
> group-gift *summary* with extra charges and multiple gifts, and UPI payout
> collection. Re-estimate before starting.

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
| **Group refund flow** | ⚠️ v2 — **new**: `4092:174` (states: `4092:203`, `4093:444`, `4095:574`, `4095:611`, `4095:637`, `4095:883`, `4095:967`, `4095:1036`, `4095:1169`, `4095:1181`, `4099:936`, `4099:976`, `4099:1026`, `4099:1075`, `4099:1199`) |
| Group thank-you | `2219:603` (variant `2288:5`) |

**API:** `POST items/:itemId/group-gift`, `group-gifts/:id/join|contribute|purchase|share`, `GET group-gifts/:id`, `public/group-gifts/:slug`, chat endpoints.
**Backend (new):** Razorpay order/verify/webhook for contributions; **refund engine** (cancel / goal-missed / over-collection → per-contributor refunds via Razorpay refund API, with status tracking to match the ~16 refund frames); **UPI payout collection** (see Sprint 9's Refunds & Payouts screens); **charges + multi-gift group-gift model**; extend chat to group-gift scope.

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
| Address book | `324:1295` |
| Add new address | `324:1340` |
| Privacy policy | `2262:1019` |
| Help centre | `2252:628` |
| About us | `2252:703` (about page `2293:23`) |
| Logout popup | `2252:611` |

**API:** `notifications` list/read/preferences, `thank-you` flows, `/me` + preferences + export/delete/restore, gifting given/received/on-hold.
**Backend (new):** FCM device-token registry + push pipeline; real mail adapter.

---

## Sprint 10 — Hardening & release (1.5 wk)

- Dark-mode audit across all ~90 screens (goldens), accessibility pass (contrast, tap targets, TalkBack/VoiceOver).
- Performance: image caching, list virtualization, startup time.
- Deep-link matrix test (wishlist/invite/group-gift slugs), analytics funnel wiring, crash reporting (Sentry/Crashlytics).
- Store assets, privacy disclosures, staged rollout (internal → closed → production).

---

## Backlog / not scheduled

- Workspace screens (`2175:1021`, `2209:221`) — purpose unclear, clarify with design.
- Reels public pages (`public/reels`) — web-share surface, likely not in-app.
- Hindi localization, remote-config palette (design supports it via token layer).
