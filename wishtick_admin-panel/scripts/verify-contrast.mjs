/**
 * WCAG contrast verification for the design tokens.
 *
 *   npm run verify:contrast
 *
 * jsdom has no layout engine, so axe cannot evaluate colour-contrast — which
 * left this the one accessibility criterion the test suite could not cover.
 * This closes that gap by computing the ratios straight from the token values
 * in src/styles/index.css, for both themes.
 *
 * Thresholds:
 *   4.5:1  AA — normal text
 *   3.0:1  AA — large text and UI component boundaries
 *   7.0:1  AAA — held for NAVIGATION only.
 *
 * Nav gets the stricter bar deliberately. AA is a legal floor, not a comfort
 * target, and the sidebar is re-read on every page load — the first palette
 * cleared AA at 4.57–6.69:1 and was still reported as hard to read. Anything
 * scanned that often should not be sitting at the bottom of legal.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const CSS = resolve('src/styles/index.css');

// ── Colour maths ─────────────────────────────────────────────────────────────

function parseHex(hex) {
  const value = hex.trim().replace('#', '');
  const full =
    value.length === 3
      ? value
          .split('')
          .map((c) => c + c)
          .join('')
      : value;
  return [
    parseInt(full.slice(0, 2), 16),
    parseInt(full.slice(2, 4), 16),
    parseInt(full.slice(4, 6), 16),
  ];
}

function relativeLuminance(hex) {
  const [r, g, b] = parseHex(hex).map((channel) => {
    const c = channel / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrast(a, b) {
  const la = relativeLuminance(a);
  const lb = relativeLuminance(b);
  const [lighter, darker] = la > lb ? [la, lb] : [lb, la];
  return (lighter + 0.05) / (darker + 0.05);
}

// ── Token extraction ─────────────────────────────────────────────────────────

const css = readFileSync(CSS, 'utf8');

/**
 * Reads one selector's block, matching braces properly.
 *
 * The first version stopped at the first `}`, which silently truncated the
 * nested @media block and hid the bug this file now guards against.
 */
function blockBody(marker) {
  const index = css.indexOf(marker);
  if (index === -1) throw new Error(`selector not found: ${marker}`);
  const open = css.indexOf('{', index);
  let depth = 0;
  let i = open;
  for (; i < css.length; i++) {
    if (css[i] === '{') depth++;
    else if (css[i] === '}' && --depth === 0) break;
  }
  return css.slice(open, i);
}

function tokensFrom(marker) {
  const tokens = {};
  for (const match of blockBody(marker).matchAll(/(--[a-z0-9-]+):\s*(#[0-9a-fA-F]{3,8})\s*;/g)) {
    tokens[match[1]] = match[2];
  }
  return tokens;
}

const rootDefaults = tokensFrom(':root {');
const mediaDark = tokensFrom('@media (prefers-color-scheme: dark)');
const light = tokensFrom(":root[data-theme='light']");
const dark = tokensFrom(":root[data-theme='dark']");

// ── What has to pass ─────────────────────────────────────────────────────────

/** [foreground, background, minimum ratio, description] */
const PAIRS = (t) => [
  // Body and headings.
  [t['--ink'], t['--surface'], 4.5, 'ink on surface'],
  [t['--ink'], t['--surface-2'], 4.5, 'ink on surface-2'],
  [t['--ink'], t['--ground'], 4.5, 'ink on ground'],

  // Secondary text — labels, captions, table cells. Normal size, so 4.5.
  [t['--muted'], t['--surface'], 4.5, 'muted on surface'],
  [t['--muted'], t['--surface-2'], 4.5, 'muted on surface-2'],
  [t['--muted'], t['--ground'], 4.5, 'muted on ground'],

  // Tertiary text — table headers, ids, hints. Still real text.
  [t['--muted-soft'], t['--surface'], 4.5, 'muted-soft on surface'],
  [t['--muted-soft'], t['--surface-2'], 4.5, 'muted-soft on surface-2'],

  // Navigation — AAA, see the header note.
  [t['--nav-idle'], t['--surface'], 7.0, 'AAA idle nav label on sidebar'],
  [t['--accent-text'], t['--accent-wash'], 7.0, 'AAA active nav label on its pill'],

  // Accent used as text elsewhere: links, inline emphasis.
  [t['--accent-text'], t['--surface'], 4.5, 'accent-text on surface'],
  [t['--accent-text'], t['--ground'], 4.5, 'accent-text on ground'],

  // Primary button label.
  ['#FFFFFF', t['--accent'], 4.5, 'white on accent (primary button)'],

  // Semantic text on its own wash — status pills and notices.
  [t['--good'], t['--good-wash'], 4.5, 'good on good-wash'],
  [t['--info'], t['--info-wash'], 4.5, 'info on info-wash'],
  [t['--warn'], t['--warn-wash'], 4.5, 'warn on warn-wash'],
  [t['--crit'], t['--crit-wash'], 4.5, 'crit on crit-wash'],

  // Semantic text directly on a card (deltas, inline errors).
  [t['--good'], t['--surface'], 4.5, 'good on surface'],
  [t['--crit'], t['--surface'], 4.5, 'crit on surface'],
  [t['--warn'], t['--surface'], 4.5, 'warn on surface'],
  [t['--info'], t['--surface'], 4.5, 'info on surface'],

  // Non-text (WCAG 1.4.11) applies to UI components and meaningful graphics —
  // NOT to decorative dividers. --hairline is deliberately excluded: forcing a
  // card separator to 3:1 would make the whole design heavy and boxy for no
  // accessibility gain. Controls and focus indicators are held to 3:1.
  [t['--field-border'], t['--surface'], 3.0, 'field border on surface (control boundary)'],
  [t['--field-border'], t['--surface-2'], 3.0, 'field border on surface-2'],
  [t['--accent'], t['--ground'], 3.0, 'focus ring on ground'],
  [t['--accent'], t['--surface'], 3.0, 'focus ring on surface'],
];

let failures = 0;

/**
 * Every theme block must define every token.
 *
 * A token missing from a theme block does not error — it silently inherits the
 * :root default, which for a dark block means a LIGHT value on a dark ground.
 * That is exactly how three tokens went missing from the @media block and made
 * the sidebar unreadable for anyone whose OS is set to dark and who never
 * touched the in-app toggle. The contrast checks all passed, because they only
 * read the two data-theme blocks.
 */
function checkParity() {
  console.log('\n  Token parity across theme blocks');
  const expected = Object.keys(rootDefaults);
  for (const [label, tokens] of [
    ['@media prefers-color-scheme: dark', mediaDark],
    ["[data-theme='dark']", dark],
    ["[data-theme='light']", light],
  ]) {
    const missing = expected.filter((name) => !(name in tokens));
    if (missing.length > 0) {
      console.error(
        `  FAIL  ${label} is missing ${missing.join(', ')} — these would inherit the :root (light) value`,
      );
      failures++;
    } else {
      console.log(`  PASS  ${label} defines all ${expected.length} tokens`);
    }
  }

  // The two dark blocks must agree, or the OS preference and the in-app toggle
  // render differently.
  const mismatched = Object.keys(dark).filter(
    (name) => mediaDark[name] && mediaDark[name].toLowerCase() !== dark[name].toLowerCase(),
  );
  if (mismatched.length > 0) {
    console.error(`  FAIL  media-dark and [data-theme='dark'] disagree on ${mismatched.join(', ')}`);
    failures++;
  } else {
    console.log('  PASS  both dark blocks hold identical values');
  }
}

function checkTheme(name, tokens) {
  console.log(`\n  ${name}`);
  for (const [fg, bg, min, label] of PAIRS(tokens)) {
    if (!fg || !bg) {
      console.error(`  FAIL  ${label}: missing token`);
      failures++;
      continue;
    }
    const ratio = contrast(fg, bg);
    const rounded = ratio.toFixed(2);
    if (ratio < min) {
      console.error(`  FAIL  ${label}: ${rounded}:1 (needs ${min}:1)  ${fg} on ${bg}`);
      failures++;
    } else {
      console.log(`  PASS  ${label}: ${rounded}:1`);
    }
  }
}

checkParity();
checkTheme('Light theme', light);
checkTheme('Dark theme', dark);
// Also check the OS-preference block on its own — it is a real rendering path,
// not a copy that only has to look right.
checkTheme('Dark theme (@media prefers-color-scheme)', mediaDark);

console.log(
  failures === 0
    ? '\nAll token pairs meet WCAG AA.'
    : `\n${failures} contrast failure(s) — text below AA is unreadable for low-vision users.`,
);
process.exit(failures === 0 ? 0 : 1);
