# Wishtick — Mobile App Plan

> **Design source of truth:** Figma file [Wishtick-UI-v2](https://www.figma.com/design/6WXJf85eSt7J3SpPzyoJP2/Wishtick-UI-v2)
> (fileKey: `6WXJf85eSt7J3SpPzyoJP2`). The UI team duplicated the original
> `Wishtick-UI` file (`8OShdlUS8kUWEE6j5DQ8GP`) and continues in the copy.
> **v2 fully re-inventoried 2026-08-01** (201 frames: 64 new · 24 removed ·
> 12 redesigned · 1 renamed) — per-screen node IDs and ⚠️ v2 markers live in
> [sprints.md](sprints.md); the export checklist is
> [`UI_Screen/_v2_export_list.txt`](UI_Screen/_v2_export_list.txt).
>
> **Rule: every screen is built by first opening its Figma frame (node ID listed in
> [sprints.md](sprints.md)), pulling a fresh screenshot + design context via the Figma MCP, and
> implementing the UI *as designed* — spacing, type, radii, colors. No improvisation.**
> To open a frame: `https://www.figma.com/design/6WXJf85eSt7J3SpPzyoJP2/Wishtick-UI-v2?node-id=<ID with ':' replaced by '-'>`

---

## 1. What Wishtick is

A social gifting platform for the Indian market — "Gifting, made together". Four pillars:

1. **Wishlists** — multi-wishlist per user, public/shareable, quick-add, items imported from Amazon / Flipkart / Myntra (affiliate links, price tracking).
2. **Events & Invitations** — occasions (Birthday, Anniversary, Wedding, House Warming, Mom-to-Be, Rakhi, Best Wishes, Custom), invitation templates, invites + RSVP, guest list with export *(v2)*.
3. **Gifting & Group Gifts** — reserve a gift (hold), buy solo, or pool money as a group (chip-in with goal tracking, participant chat, order confirmation → tracking → delivery, thank-you notes). *(v2)* group gifts extend to **multiple gifts + extra charges** with a **summary**, and a full **refund flow** paying back contributors via **UPI payouts**.
4. **Memories** — time-locked capsules: friends add photo / video / text messages that unlock on the occasion date *(audio compose screens were dropped in v2 — pending design confirmation)*, surfaced under Profile → My Memories.

Deep onboarding personalization (interests, colors, sizes, important dates) powers a gift-recommendation feed ("Discover").

**Tabs:** Home · Wishlist · (+) Create · Memories · Profile

---

## 2. Repo layout

| Folder | What | State |
|---|---|---|
| `wishtick_backend/` | NestJS + MongoDB + Redis/BullMQ API | Large, most modules exist (see §6) |
| `wishtick_admin-panel/` | Admin web panel | Exists |
| `wishtick_flutter/` | Flutter app | Fresh scaffold — **this plan** |

---

## 3. Flutter architecture

- **Flutter** (Dart 3, Material 3 base but fully custom-themed to Figma).
- **State management:** Riverpod (v2, code-gen). One `Notifier`/`AsyncNotifier` per feature.
- **Navigation:** `go_router` — `StatefulShellRoute` for the 5-tab shell; deep links for public slugs (`/public/wishlists/:slug`, `/public/invites/:token`, group-gift shares).
- **Networking:** `dio` + interceptors (JWT access/refresh rotation, request-id, error envelope from backend `response.interceptor`).
- **Models:** `freezed` + `json_serializable`.
- **Storage:** `flutter_secure_storage` (tokens), `shared_preferences` (theme mode, onboarding flags), `cached_network_image`.
- **Media:** `image_picker`, audio record/play, video player + compression for Memory messages.
- **Push:** Firebase Cloud Messaging + local notifications.
- **Payments:** Razorpay Flutter SDK (group-gift contributions & solo purchase) — backend work required (§6).

### Folder structure

```
wishtick_flutter/lib/
  core/
    theme/            # THE theming system (see §4) — tokens, light/dark ThemeData
    network/          # dio client, interceptors, error mapping
    router/           # go_router config, guards (auth, onboarding-complete)
    widgets/          # shared UI: buttons, chips, cards, sheets, avatars
    utils/
  features/
    auth/             # welcome, signup, mobile+OTP, avatar
    onboarding/       # interests, colors, size&fit, important dates
    home/
    wishlist/         # my wishlists, discover, product detail, add/import
    gifting/          # reserve, orders, friend wishlists
    group_gift/       # create, contribute, participants, chat, thank-you
    events/           # create event, templates, invites, RSVP
    memories/         # create, messages, previews, unlock
    notifications/
    profile/          # profile, edit, address book, settings, legal
  app.dart            # MaterialApp.router + theme wiring
  main.dart
```

Each feature: `data/` (api + dtos) · `domain/` (models) · `presentation/` (screens, widgets, providers).

---

## 4. Design system & theming (hard requirement)

**Goals:** colors 100% consistent · palette swappable later from one place · light **and** dark mode, both consistent.

### 4.1 Token architecture (3 layers)

1. **Raw palette** — `core/theme/app_palette.dart`. The Figma "Color System" page names, verbatim:
   `plum, plumDeep, plumSoft, pink, pinkSoft, pinkPale, ivory, ivoryDeep, cream, gold, goldSoft, coral, coralSoft, roseSoft, teal, tealSoft, navy, navyDeep, violet, violetSoft, amber, amberSoft, blue, blueSoft, ink, inkSoft, textMuted, textFaint`.
   *This is the ONLY file that contains hex literals.* Rebranding = editing this file (or later, loading it from remote config/JSON).
2. **Semantic tokens** — `WishtickColors extends ThemeExtension<WishtickColors>`: `primary, primaryDeep, accent, background, surface, surfaceAlt, cardGold, textPrimary, textSecondary, textMuted, success, danger, …` Each has a **light value and a dark value**, both drawn from the raw palette.
3. **Component usage** — widgets only ever read `context.colors.*` (extension getter on `BuildContext`). **Never `Color(0xFF…)` in a widget.** Enforced by a custom lint / code review + a grep check in CI.

Same 3-layer approach for **typography** (`app_typography.dart`: display serif for headings/logo, Montserrat for UI — confirm exact families from Figma text styles) and **spacing/radius** (`app_dimens.dart`: 4-pt scale, card radius 16, sheet radius 24, pill buttons).

### 4.2 Palette values — ✅ verified against the Color System page (2026-07-31)

Every swatch on the Figma **Color System** page (node `0:1`) was sampled from a
full render of the page and now lives verbatim in `app_palette.dart`:

| Swatch | Hex | | Swatch | Hex |
|---|---|---|---|---|
| plum | `#5B1A6E` | | teal / teal soft | `#3FBFA6` / `#7FD9C6` |
| plum deep | `#3F0E4C` | | navy / navy deep | `#1E1B3A` / `#0F0D24` |
| plum soft | `#7B3A8F` | | violet / violet soft | `#7C6BE6` / `#B7ADF2` |
| pink / soft / pale | `#E94E85` / `#F27BA3` / `#FCE7EE` | | amber / amber soft | `#F3AB4A` / `#F9D08B` |
| ivory / ivory deep | `#FCFBF5` / `#F5EFE4` | | blue / blue soft | `#4E8BE9` / `#8FB4F0` |
| cream | `#FFF7EA` | | ink / ink soft | `#1E1B3A` / `#4A4463` |
| gold / gold soft | `#E7B85C` / `#F5D48C` | | text muted / faint | `#8A82A1` / `#B7B2C6` |
| coral / coral soft | `#FF7B5C` / `#FFB199` | | rose soft | `#F4B6C2` |

Findings from verification (already applied):
- **The CTA colour `#3F0E4C` is officially *plum deep*** — the swatch named
  *plum* is `#5B1A6E`. Semantic `primary` (light) maps to plum deep, so every
  built screen is unchanged; the dark theme's primary uses the official plum.
- **Screen backgrounds are *ivory deep*** (`#F5EFE4`), not cream.
- **The LOGOUT red (`#D51112`) is not on the page** — official *coral* is an
  orange (`#FF7B5C`). The alarm red is kept as a screen-sampled value
  (`redAlert`), separate from coral.
- A handful of screen-only colours (gradient stops, lavender washes) are kept in
  a clearly-marked *screen-sampled* section of `app_palette.dart`.

### 4.3 Dark mode

- The Figma file is light-only today → we define a **dark mapping per semantic token** (e.g. `background: ivory → #17101B`, `surface: white → #221826`, `primary: plum → plumSoft/violet` for contrast, text inverts to ivory tones). Documented in `app_colors.dart` next to each token so light/dark never drift.
- `ThemeMode` (system / light / dark) exposed in Profile → Settings, persisted in `shared_preferences`, applied at `MaterialApp` level from day one — **every screen is built against both themes from Sprint 0**, not retrofitted.
- Definition of done for any screen: screenshot in light **and** dark, no hardcoded colors.

---

## 5. Figma screen inventory

Full inventory with node IDs lives in [sprints.md](sprints.md). As of the v2
re-inventory (2026-08-01): **201 top-level frames ≈ 115 unique screens** across
Onboarding/Auth (~24), Home (2), Wishlist (12), Gifting/Orders (12), Group
gifts (**~30** — the refund flow and summary/charges screens landed in v2),
Events/Invitations (14 — guest list added), Memories (12), Notifications (11),
Profile (18 — My Memories and Refunds & Payouts added).

---

## 6. Backend: current state vs. app needs

Backend already has (NestJS, versioned API): `auth` (signup/login/refresh/sessions, email+phone OTP verify, password reset) · `onboarding` (options/status/steps/complete) · `wishlists` (CRUD, items, reorder, participants, share, public slugs) · `products` (search, categories, resolve-url, import-to-wishlist, affiliate redirect `r/:itemId`, click tracking) · `gifting` (reserve/unreserve, gift-offline, purchase, fulfill, complete, cancel, given/received/on-hold) · `group-gifts` (create, join, contribute, cancel contribution, purchase, share, public slug) · `chat` (wishlist, group-gift and **direct** chats, messages, reactions, read; a direct chat's view carries its `counterpart` and last-message preview, because its `refId` is a one-way hash that names nobody) · `events` (CRUD, publish, invite templates, invites, resend, public invite links + RSVP) · `notifications` (list, read, preferences, thank-you flows) · `reels` · `media` (upload-url/confirm + local dev storage) · `profile` (`/me`, preferences, export, delete, restore) · `wishmates` (**Sprint 11**: handles, people search, WishLink requests, mutuals, suggestions, presence, and the shared-event "Recent Activity" a profile is allowed to show) · `taxonomy`, `analytics`, `dashboard`, `admin`.

### Gaps to close (backend work, scheduled inside sprints)

| Gap | Needed by | Notes |
|---|---|---|
| **Payment gateway** (Razorpay order + verify webhook) | Group-gift contribute, solo purchase | `contribute` endpoint exists but no PG integration visible |
| **Address book** (`/me/addresses` CRUD, default) | Checkout, Profile → Address Book | No routes exist today |
| **Order tracking** (statuses, courier events, timeline) | Tracking / Delivered screens | Only purchase/fulfill/complete today |
| **Memories module** (capsule, invited contributors, photo/video/audio/text messages, time-lock, unlock notify) | Memories tab | `reels` is adjacent but not the same — decide extend vs. new module |
| **Discover feed** (personalized recommendations: per-friend occasion suggestions, price bands, premium picks) | Wishlist → Discover | Only raw product search today |
| **Group-gift chat** | Group chat screen | Chat is wishlist-scoped; needs group-gift scope |
| **Push (FCM)** (device token registry + send pipeline) | All notifications | Only in-app notification list today; mailer/SMS are console stubs |
| ~~**Friends/relations**~~ ✅ **closed in Sprint 11** | Home, Discover, Events | `wishmates` ships the real user-to-user graph (handles, requests, mutuals, presence, 1:1 chat). Note the two are *different models* and both remain: an **important date** is a free-text contact you saved (`personName`, `relation`) and needs no account; a **WishMate** is a real linked user. Gifting requires the latter — see the Gift Now note below |
| **Location** ("Where to deliver") | Home header | Simple; ties into addresses |
| ~~**Gifting a catalogue product**~~ ✅ **built** | Product detail → "Gift Now" | Option **(a)** as scoped: "Gift Now" asks who it is for (saved important dates + WishMates, or a typed name), saves the product to the buyer's **own** list tagged via `WishlistItem.recipientName`/`relation`, then hands off to the merchant through the affiliate redirect. Creates **no `Gift` record** — Wishtick takes no payment and the recipient usually has no account. The seller rows under "Available at N sellers" are clickable and each converts **its own** merchant URL: `GET /r/p/:provider/:externalId?offer=N` monetizes per offer (`Product.offers[].affiliateUrl`, cached separately from the product-level one) and records a click with a null `itemId` |
| **Refund engine + UPI payouts** *(v2)* | Group-gift refund flow (S6), Profile → Refunds & Payouts / Enter UPI (S9) | Cancel / goal-missed / over-collection → per-contributor refunds via Razorpay refund API; payout destination (UPI) stored on profile; refund status timeline to match the ~16 refund frames |
| **Group-gift charges & multi-gift** *(v2)* | Group gift summary / Add charge / Add gift (S6) | Extends the group-gift model: several gifts per group + miscellaneous charges rolled into the goal |
| **Guest-list export** *(v2)* | Event guest list / Download (S7) | View is a projection over invites+RSVPs; download (CSV/PDF) is a new endpoint |

---

## 7. Cross-cutting quality bars

- **API contract:** typed DTOs mirrored from backend DTOs; single error-envelope mapper; all list screens handle loading / empty / error states (design the empty states from Figma where present).
- **Offline-ish:** cache last Home/Wishlist payloads; optimistic UI for wishlist item add/remove, reserve, read receipts.
- **Deep links:** public wishlist / invite / group-gift slugs open in-app; App Links + Universal Links.
- **Analytics:** `events/track` wired to screen views + key funnels (onboarding, add-to-wishlist, contribute, order).
- **Testing:** unit tests for providers/mappers; golden tests for core widgets in **light + dark**; integration smoke for auth + wishlist flow. CI: analyze, test, build APK/IPA.
- **Localization-ready:** strings via ARB from day one (English now; Hindi later). Currency formatting via `intl` (₹).

---

## 8. Delivery

Milestones map 1:1 to sprints in [sprints.md](sprints.md):

- **M1 (S0–S2):** Foundation + full onboarding/auth — installable, themed, dark/light.
- **M2 (S3–S4):** Wishlists end-to-end + Home.
- **M3 (S5–S6):** Gifting + Group gifts with payments.
- **M4 (S7–S8):** Events/invitations + Memories.
- **M5 (S9–S10):** Notifications, Profile, orders polish, release hardening (stores).
