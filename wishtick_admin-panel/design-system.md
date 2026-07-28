# Wishtick Admin Panel — Design System

The visual language for the operator console, extracted from the approved reference direction (a light, airy dashboard with a violet accent and soft rounded cards) and adapted to Wishtick's actual screens.

Live prototype of these tokens applied to the real dashboard: **[Wishtick Admin — UI Direction](https://claude.ai/code/artifact/5b048d3a-c58f-4618-a141-78d554f46aed)**

This document is the source of truth for tokens. Screens are specified in [sprints.md](sprints.md); the data behind them is in [backend_api.md](backend_api.md).

---

## Design tokens

Ship these as CSS custom properties (or the Tailwind theme extension below) and reference them by name. **No raw hex in component code.**

### Color — light

| Token | Value | Use |
|---|---|---|
| `--ground` | `#EFEFF2` | Page background behind the shell |
| `--surface` | `#FFFFFF` | Shell, cards, panels |
| `--surface-2` | `#FBFBFC` | Inset areas — segmented controls, progress tracks, hover |
| `--ink` | `#14141A` | Primary text |
| `--muted` | `#666673` | Labels, secondary text |
| `--muted-soft` | `#70707E` | Table headers, tertiary text, ids |
| `--hairline` | `#EEEEF1` | **Decorative** dividers and card borders only |
| `--field-border` | `#8A8A96` | Borders that delineate a **control** (inputs, selects) |
| `--nav-idle` | `#3A3A45` | Idle nav labels — **AAA**, see below |
| `--accent` | `#6C4DEF` | Fill: buttons, focus ring, data emphasis |
| `--accent-text` | `#4C2DBF` | Accent used **as text**: links, active nav label |
| `--accent-hover` | `#5B3CE0` | Primary button hover |
| `--accent-wash` | `#F0EBFF` | Active nav pill, icon tiles, soft fills |
| `--accent-wash-2` | `#F7F4FF` | Lightest tint |

Both neutrals carry a slight violet bias so they sit with the accent rather than reading as generic grey. Do not substitute a pure `#888`.

> **These values are contrast-constrained, not taste-constrained.** The first palette put `--muted` at `#8E8E9A` and `--muted-soft` at `#A9A9B4`, which measured **2.3–3.2:1** against the backgrounds they sat on — comfortably readable on a good monitor, and below WCAG AA for anyone else. Nineteen pairs failed across the two themes. `npm run verify:contrast` computes every ratio from these tokens and fails the build below AA, so the palette cannot drift back.
>
> Two splits came out of that fix and must be preserved:
> - **`--accent` (fill) vs `--accent-text`.** One value cannot satisfy both "white text on it" and "it as text on a dark surface" — those pull in opposite directions. In dark mode they are genuinely different colours.
> - **`--hairline` vs `--field-border`.** WCAG 1.4.11 requires 3:1 for *UI components*, not decorative dividers. Forcing card separators to 3:1 would make the design heavy and boxy for no accessibility gain; input borders genuinely need it.
>
> **Navigation is held to AAA (7:1), not AA.** A second round of feedback found the sidebar hard to read *after* it already cleared AA — idle labels at 6.69:1 and the active label at 4.57:1. Two things were wrong. First, nav labels were using `--muted`, the token for captions and secondary text; a nav label is **primary interactive text** and should never have been muted. Hence `--nav-idle`. Second, AA is a legal floor, not a comfort target, and a sidebar is re-read on every page load — so it gets the stricter bar. `verify:contrast` enforces 7:1 on both nav states.

> **Light is the shipped theme.** `data-theme="light"` is set on `<html>`, which wins over `prefers-color-scheme` on both specificity (`(0,2,0)` vs `(0,1,0)`) and source order. The dark palette below is maintained and verified but not currently rendered.

### Color — dark

The panel must work in both themes. Dark is not an inversion — the accent brightens to hold contrast on a dark ground.

> **The dark palette is defined in two places and they must stay identical:** `@media (prefers-color-scheme: dark)` (the OS preference) and `:root[data-theme='dark']` (the in-app toggle). A token present in one and absent from the other does not error — it silently inherits the `:root` **light** value, which on a dark ground means dark text on dark background.
>
> That is not hypothetical. Three tokens were added to the `data-theme` block and missed in the `@media` block, and the sidebar became unreadable for anyone whose OS is dark and who never touched the toggle. Every contrast check still passed, because they only read the two `data-theme` blocks. `verify:contrast` now asserts token parity across all three blocks and runs the ratios against the `@media` block too.

| Token | Value |
|---|---|
| `--ground` | `#101015` |
| `--surface` | `#1A1A21` |
| `--surface-2` | `#1F1F27` |
| `--ink` | `#F3F3F6` |
| `--muted` | `#A0A0AC` |
| `--muted-soft` | `#8A8A96` |
| `--hairline` | `#2A2A33` |
| `--field-border` | `#6B6B79` |
| `--nav-idle` | `#C7C7D1` |
| `--accent` (fill) | `#6D4DE6` |
| `--accent-text` | `#C4B5FF` |
| `--accent-hover` | `#7C5EF0` |
| `--accent-wash` | `#2E2850` |

### Semantic color

**Kept deliberately separate from the accent.** Violet means "primary action or emphasis"; it never means "good". A status pill must never be accent-colored, or state and affordance become indistinguishable.

| Meaning | Light fg / bg | Dark fg / bg | Used for |
|---|---|---|---|
| Good | `#166534` / `#E7F6EC` | `#4ADE80` / `#14301F` | Positive deltas, `resolved`, `active` |
| Info | `#1D4ED8` / `#E8F1FE` | `#60A5FA` / `#16263F` | `open`, neutral state |
| Warning | `#92400E` / `#FEF3E2` | `#FBBF24` / `#33260C` | `reviewing`, truncation notices, medium severity |
| Critical | `#B91C1C` / `#FDECEC` | `#F87171` / `#3A1A1A` | `suspended`, negative deltas, high severity |

Never encode state with color alone — every pill carries a text label, and severity pairs a color bar with its number. Roughly 1 in 12 men has some form of color vision deficiency, and this is an operations tool where misreading state has consequences.

### Chart categories

For acquisition sources and other categorical series, in order:

`#6C4DEF` violet · `#3B82F6` blue · `#0EA5A5` teal · `#F59E0B` amber · `#A855F7` orchid

Distinguishable in both themes and for the common CVD types. Bars use a subtle vertical gradient to the lighter tint of the same hue.

### Radius

| Token | Value | Use |
|---|---|---|
| `--r-shell` | `28px` | The outer app container |
| `--r-card` | `18px` | Cards and panels |
| `--r-nav` | `12px` | Active nav pill |
| `--r-pill` | `999px` | Buttons, chips, badges, progress bars |

The reference's signature is the **contrast** between fully-rounded pills and softly-rounded cards. Do not flatten everything to one radius.

### Elevation

| Token | Value |
|---|---|
| `--shadow-shell` | `0 8px 40px rgba(20,20,40,0.06)` |
| `--shadow-card` | `0 1px 2px rgba(20,20,40,0.03)` |
| `--shadow-pop` | `0 6px 24px rgba(20,20,40,0.10)` |

Cards are separated by **hairline borders, not shadows**. Shadow is reserved for the shell and for genuinely floating elements (dropdowns, tooltips, modals). Stacked drop shadows are the fastest way to lose this design's calm.

### Spacing

4px base. Card padding `21–22px`, grid gaps `16px`, section gaps `22px`. Generous whitespace is doing real work here — resist tightening it to fit more in.

### Typography

The reference uses a geometric sans (Poppins family). **Self-host it** — do not use a font CDN.

```
--font-display: "Poppins", "Segoe UI Variable Display", system-ui, sans-serif;
--font-body:    "Inter", "Segoe UI", system-ui, sans-serif;
```

| Role | Size / weight | Notes |
|---|---|---|
| Page title | 27px / 700 | `letter-spacing: -0.02em` |
| Greeting | 30px / 700 | `-0.025em`, `text-wrap: balance` |
| Panel title | 17.5px / 700 | `-0.015em` |
| KPI value | 24px / 700 | **`tabular-nums`** |
| Body / table | 14–15px / 400–600 | |
| Label, caption | 12.5–13.5px / 400–500 | `--muted` |
| Table header | 12px / 600 | uppercase, `letter-spacing: 0.05em`, `--muted-soft` |

**`font-variant-numeric: tabular-nums` on every column of digits** — KPI values, table numbers, counts, severity. Without it, figures jitter between rows and the eye can't scan a column.

> The prototype falls back to a system stack because the artifact sandbox blocks font CDNs. In the real app, self-host Poppins — the geometric character is a substantial part of this look, and Segoe/system is a visibly different voice.

---

## Components

### App shell

Rounded `--surface` container floating on `--ground`, `244px` sidebar + fluid main, `overflow: hidden` so children clip to the radius.

### Sidebar

Logo mark (violet rounded square, white letterform) + wordmark, divider, then nav. Icons are **1.8px-stroke outlined**, 19px, never filled.

- Default: **`--nav-idle`** text, transparent background — *not* `--muted`; see the contrast note above
- Hover: `--surface-2` background, `--ink` text
- **Active: `--accent-wash` background, `--accent-text`, weight 600, `--r-nav` radius**

Both nav states are held to AAA (7:1). The active pill's background is deliberately lifted in dark mode (`#2E2850`, not `#26213F`) so "selected" reads as a state rather than a faint tint.

Settings and Help Center pin to the bottom via `margin-top: auto`.

### KPI card

The reference's most distinctive component. Two zones split by a hairline:

1. **Body** — 40px circular outlined icon tile, then label, then value with its delta on the baseline.
2. **Footer** — comparison text (`+24 from yesterday`) with a right-aligned arrow.

Delta is `good` up / `critical` down, with a matching arrow glyph so direction survives without color.

### Panel

`--surface`, hairline border, `--r-card`, `21–22px` padding. Header row: title (plus optional sub-caption) left, control right — a `chip` (date range) or `seg` (segmented control).

### Pills and badges

Fully rounded, `5px 12px`, 12.5px/600, semantic wash background with matching foreground. Status vocabulary maps 1:1 to the API enums: `open` info · `reviewing` warning · `resolved` good · `dismissed` neutral.

### Severity indicator

Severity is an **unbounded number**, not an enum (base 1–4, `+5` per escalation). Render the raw number beside a 4px color bar, bucketed:

| Bucket | Range | Color |
|---|---|---|
| Low | 1 | `--muted-soft` |
| Medium | 2 | info |
| High | 3–4 | warning |
| Critical | 5+ | critical |

### Table

Uppercase hairline-underlined headers, `15px` row padding, hairline row dividers, no zebra striping, last row borderless. Target cells pair a rounded icon tile with a name and a truncated monospace-ish id. Wrap in `overflow-x: auto` — the page body must never scroll sideways.

### Truncation notice

The component that keeps this panel honest. Amber wash, info glyph, one sentence naming the exact limit:

> Showing the **50 most recent** — the queue endpoint has no pagination, so any backlog beyond this is not reachable.

**Required wherever the API caps a result set** (moderation queue at 50, audit at 500). A capped list rendered without one reads as complete, and an operator acting on that belief is the failure mode this panel most needs to avoid.

### Gap card

Dashed hairline border, `--surface-2`, centered. Marks a designed slot whose endpoint does not exist yet. Deliberately **not** a skeleton loader — it must not look like data that is about to arrive.

---

## Responsive — a requirement, not a nice-to-have

**Every screen must work on a phone.** Operators triage incidents from wherever they are; a moderation queue that needs a desktop is a queue that waits.

### Frame

Full-bleed, never a centered fixed-width card. Height is **`h-dvh`, not `h-screen`** — on mobile browsers `100vh` sits behind the collapsing address bar and clips the bottom of the page.

| Breakpoint | Frame |
|---|---|
| `< 768px` | Single column. Sidebar is an off-canvas drawer behind a hamburger, with a backdrop |
| `≥ 768px` | `260px` sidebar + fluid main. Main scrolls; the frame does not |

The drawer must: close on navigation, close on Escape and backdrop click, move focus to its first item on open, return focus to the toggle on close, and lock body scroll while open.

### Rules for every screen

- **Tables become cards below `md`.** A horizontally-scrolling table on a phone hides the columns that carry the decision. Render the same data as a stacked card per row, leading with what the operator scans for.
- **Touch targets ≥ 44px** on mobile, even where the desktop control is smaller.
- **Filters collapse** into a single control that opens a sheet, rather than wrapping across three rows.
- **Secondary identity chrome drops first** — the avatar survives, the name and role label do not.
- **No horizontal body scroll, ever.** Wide content scrolls inside its own container.
- **Test at 375px** (iPhone SE) as the floor, not 390 or 414.

## Interaction

- **Focus:** `2px solid var(--accent)` with `2px` offset on every interactive element. Never remove the outline.
- **Transitions:** 140ms ease on color and background only. No layout or transform animation — this is a tool, not a showcase.
- **Reduced motion:** `@media (prefers-reduced-motion: reduce)` disables all transitions.
- **Hit targets:** 40px minimum.
- **Destructive actions** (suspend, remove) always confirm, and the dialog states the real consequence — *"this ends their sessions and disconnects them immediately"*, not *"are you sure?"*

---

## Tailwind theme

```js
// tailwind.config.js
theme: {
  extend: {
    colors: {
      ground: 'var(--ground)',
      surface: { DEFAULT: 'var(--surface)', 2: 'var(--surface-2)' },
      ink: 'var(--ink)',
      muted: { DEFAULT: 'var(--muted)', soft: 'var(--muted-soft)' },
      hairline: 'var(--hairline)',
      accent: {
        DEFAULT: 'var(--accent)',
        hover: 'var(--accent-hover)',
        wash: 'var(--accent-wash)',
      },
      good: 'var(--good)', info: 'var(--info)',
      warn: 'var(--warn)', crit: 'var(--crit)',
    },
    borderRadius: {
      shell: '28px', card: '18px', nav: '12px', pill: '999px',
    },
    boxShadow: {
      shell: '0 8px 40px rgba(20,20,40,0.06)',
      card: '0 1px 2px rgba(20,20,40,0.03)',
      pop: '0 6px 24px rgba(20,20,40,0.10)',
    },
  },
}
```

Define the raw values once in `:root`, redefine under `@media (prefers-color-scheme: dark)` and `:root[data-theme="dark"]`, and style only through the tokens. Components then theme for free.

---

## Where the reference and Wishtick differ

The reference is an e-commerce dashboard. Three things do not transfer, and forcing them would mean inventing data:

| Reference element | Wishtick treatment | Why |
|---|---|---|
| Large area/line chart of sales over 12 months | **Acquisition bar chart** by source | No endpoint returns a time series. Acquisition and engagement are both grouped totals. A line chart would be fabricated |
| "Traffic" panel — 3 fixed channels | **Engagement** — the 7 real metrics | The other 8 metrics in the product spec do not exist |
| Product table with images and stock status | **Moderation queue** — severity, target, reason, age, status | Wishtick's operators triage reports, not inventory |

Everything else — shell, sidebar, KPI cards, pills, panel headers, typography, spacing, radii — transfers directly.

Two additions the reference has no equivalent for, both required by [the API's real behavior](backend_api.md#known-gaps): the **truncation notice** and the **"as of" cache timestamp** on analytics (figures can lag by up to 5 minutes, and a missing rollup is indistinguishable from a genuine zero).
