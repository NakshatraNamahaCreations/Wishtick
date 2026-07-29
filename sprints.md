# Wishtick — Sprint Plan

Figma file: `8OShdlUS8kUWEE6j5DQ8GP` — open any node via
`https://www.figma.com/design/8OShdlUS8kUWEE6j5DQ8GP/Wishtick-UI?node-id=<node id, ':' → '-'>`

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
- ⚠️ **Palette values still need verification against Figma.** The MCP `get_variable_defs` call is blocked by the Figma Starter-plan tool-call limit, so the swatches were sampled from rendered frames. Re-run against node `0:1` and correct `app_palette.dart` (one file).
- Splash routes straight to Home; replace with the real session check (signed in → home, onboarding incomplete → onboarding, else → welcome).
- `onSessionExpiredProvider` currently only clears tokens — override it to reset session state and redirect.
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

### ⛔ Blocked on Figma exports

The Figma MCP tool-call limit (Starter plan) ran out before these frames could
be opened, so they are **not** built — the working agreement is to match the
design, not guess at it. Export these and the screens go in:

| Screen | Figma node ID | State |
|---|---|---|
| Welcome carousel slide 1 | `7:81` | ✅ built |
| Welcome slides 2–5 | `251:580`, `280:33`, `280:56`, `280:102` | ⛔ copy + artwork needed |
| Create account | `31:608` | ⛔ placeholder |
| Avatar picker | `195:131` | ⛔ placeholder |
| Mobile number entry | `17:329` | ⛔ placeholder |
| Mobile number — OTP auto-read (variant) | `143:141` | ⛔ placeholder |
| OTP verification | `17:530` | ⛔ placeholder |

The logic behind all of them is written and tested; what is missing is the
presentation layer.

**Still to do once unblocked:** real SMS adapter (MSG91/Twilio) in place of the
console stub, and SMS OTP auto-read on Android.

---

## Sprint 2 — Onboarding personalization (1.5 wk)

**Goal:** interests → per-category detail → colors → size & fit → important dates → all set; resumable via `onboarding/status`.

| Screen | Figma node ID |
|---|---|
| Interests (main grid) | `33:751` |
| Interests (variants) | `39:986`, `80:545`, `36:839` |
| Category detail — Fashion & Style | `204:471` |
| Category detail — Technology & Gadgets | `238:4` |
| Category detail — Home & Living | `238:55` |
| Category detail — Health & Fitness | `204:539` |
| Category detail — Entertainment | `239:370` |
| Category detail — Sustainable Living | `239:259` |
| Category detail — Travel & Experiences | `239:106` |
| Category detail — Hobbies & Creativity | `239:157` |
| Category detail — Automotive | `239:208` |
| Category detail — Food & Beverages | `239:310` |
| Category detail — Kids & Family | `239:411` |
| Category detail — Other | `239:454` (selected: `239:510`) |
| Favorite colors | `39:1061` (variant `2259:793`) |
| Size & Fit | `51:42` |
| Important dates | `199:10` (variants `204:321`, `204:371`) |
| All set | `199:145` |

**API:** `GET onboarding/options|status`, `POST onboarding/steps/:step`, `POST onboarding/complete`, `GET products/categories` (taxonomy).

---

## Sprint 3 — Wishlist core (2 wk)

**Goal:** create wishlists, add products by URL or search, manage items.

| Screen | Figma node ID |
|---|---|
| My Wishlist tab | `280:428` |
| Create new wishlist | `280:476` |
| Wishlist detail (own) | `280:212` |
| Wishlist detail — celebration state (variant) | `288:721` |
| Wishlist item view | `280:300` |
| Product detail | `280:403` |
| Add to wishlist popup | `280:584` (variants `285:638`, `2175:498`) |
| Choose wishlist popup | `2172:446` |

**API:** `wishlists` CRUD + items + reorder, `POST products/resolve-url`, `POST wishlists/:id/items/from-product`, `GET products/search`, media upload for covers.

---

## Sprint 4 — Home, sharing & discovery (2 wk)

**Goal:** Home tab live; share wishlists; discover feed with recommendations.

| Screen | Figma node ID |
|---|---|
| Home | `51:11` (variant `80:438`) |
| Delivery location | `2293:25` |
| Discover tab (gift feed) | `280:131` (variant `2167:18`) |
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
| Friend's wishlist product | `291:1170` (variant `316:834`) |
| Friend's event view ("Siya's 24th") | `291:1008` |
| Reserve gift sheet | `299:1371` |
| Order confirmed | `299:1486` (variants `316:444`, `316:298`, `2175:909`, `2209:223`, `2209:243`) |
| Order tracking | `299:1513` (variant `316:405`) |
| Order delivered | `299:1620` (variant `316:460`) |
| Add new address (checkout) | `316:883` |

**API:** `POST items/:itemId/reserve`, `DELETE …/reserve`, `items/:itemId/gift-offline`, `gifts/:id/purchase|fulfill|complete`, `GET r/:itemId` redirect.
**Backend (new):** address book CRUD; order-tracking model (status timeline); Razorpay integration groundwork.

---

## Sprint 6 — Group gifts + payments (2 wk)

**Goal:** full chip-in flow with real payments and group chat.

| Screen | Figma node ID |
|---|---|
| Create group gift | `299:1658` |
| Group gift details | `316:166` |
| Group created | `299:1735` (variants `308:3`, `316:320`) |
| Contribute sheet (pay) | `316:119` |
| Group participants | `316:536` (variants `2262:1084`, `2262:1152`) |
| Group chat | `316:640` |
| Group thank-you | `2219:603` (variant `2288:5`) |

**API:** `POST items/:itemId/group-gift`, `group-gifts/:id/join|contribute|purchase|share`, `GET group-gifts/:id`, `public/group-gifts/:slug`, chat endpoints.
**Backend (new):** Razorpay order/verify/webhook for contributions + refunds on cancel; extend chat to group-gift scope.

---

## Sprint 7 — Events & invitations (2 wk)

**Goal:** create events, design invitations from templates, invite + RSVP.

| Screen | Figma node ID |
|---|---|
| Create event ("What are you celebrating?") | `257:733` (variants `263:828`, `257:755`) |
| Relation picker popup | `2252:423` (variants `2252:485`, `2252:540`, `2252:566`) |
| Invitation — choose photo | `2248:5` |
| Invitation — upload | `2248:70` |
| Invitation templates | `263:900` (variants `263:966`, `263:1014`, `263:1061`, `2248:140`, `2248:187`) |
| Template color options | `2262:1252` |
| Events overview | `2058:16` *(shares layout with Create Memory)* |

**API:** `events` CRUD + publish, `invite-templates`, `events/:id/invites` (+ resend/link), `public/invites/:token` + RSVP, `events/mine|invited`.

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
