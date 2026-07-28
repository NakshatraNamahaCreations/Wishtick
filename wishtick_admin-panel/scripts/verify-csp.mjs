/**
 * Static verification of the built document: CSP, and the pinned theme.
 *
 *   npm run build && npm run verify:csp
 *
 * Two things can silently break the policy: the policy itself loosening (a
 * stray 'unsafe-inline' in script-src makes the whole thing decorative), or the
 * bundle gaining something the policy forbids (an inline script or a CDN URL,
 * which would leave a blank page in production and pass every unit test).
 *
 * NOT a substitute for browser enforcement. This proves the policy says what we
 * intend and that the build is compatible with it; only a real browser proves
 * the browser honours it. See README for what remains unverified.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const HTML = resolve('dist/index.html');

/** Directives that must never permit inline or eval'd code. */
const MUST_NOT_ALLOW = {
  'script-src': ["'unsafe-inline'", "'unsafe-eval'", '*', 'http:'],
  'default-src': ["'unsafe-inline'", "'unsafe-eval'", '*'],
  'object-src': ["'self'", '*'],
};

const MUST_INCLUDE = {
  'script-src': ["'self'"],
  'object-src': ["'none'"],
  'base-uri': ["'self'"],
  'form-action': ["'self'"],
};

let failures = 0;
const fail = (message) => {
  console.error(`  FAIL  ${message}`);
  failures++;
};
const pass = (message) => console.log(`  PASS  ${message}`);

let html;
try {
  html = readFileSync(HTML, 'utf8');
} catch {
  console.error(`Could not read ${HTML}. Run \`npm run build\` first.`);
  process.exit(1);
}

// Comments are stripped first: the policy comment itself mentions <script>,
// and matching inside it produced a false positive the first time this ran.
const stripped = html.replace(/<!--[\s\S]*?-->/g, '');

// ── 1. The policy is present and parses ──────────────────────────────────────
const metaMatch = stripped.match(
  /<meta\s+http-equiv="Content-Security-Policy"\s+content="([^"]+)"/i,
);
if (!metaMatch) {
  fail('no Content-Security-Policy meta tag in dist/index.html');
  process.exit(1);
}

const policy = Object.fromEntries(
  metaMatch[1]
    .split(';')
    .map((part) => part.trim().replace(/\s+/g, ' '))
    .filter(Boolean)
    .map((part) => {
      const [name, ...values] = part.split(' ');
      return [name, values];
    }),
);
pass(`policy present with ${Object.keys(policy).length} directives`);

// ── 2. Nothing dangerous is permitted ────────────────────────────────────────
for (const [directive, forbidden] of Object.entries(MUST_NOT_ALLOW)) {
  const values = policy[directive];
  if (!values) continue;
  const offenders = forbidden.filter((value) => values.includes(value));
  if (offenders.length > 0) {
    fail(`${directive} permits ${offenders.join(', ')}`);
  } else {
    pass(`${directive} permits nothing dangerous`);
  }
}

for (const [directive, required] of Object.entries(MUST_INCLUDE)) {
  const values = policy[directive];
  const missing = required.filter((value) => !values?.includes(value));
  if (missing.length > 0) fail(`${directive} is missing ${missing.join(', ')}`);
  else pass(`${directive} is ${required.join(' ')}`);
}

// ── 3. The build is compatible with the policy ───────────────────────────────
const inlineScripts = stripped.match(/<script(?![^>]*\bsrc=)[^>]*>[\s\S]*?<\/script>/g) ?? [];
if (inlineScripts.length > 0) {
  fail(`${inlineScripts.length} inline <script> in the build — script-src 'self' would block it`);
} else {
  pass('no inline scripts in the build');
}

const inlineHandlers = stripped.match(/\son[a-z]+\s*=\s*["']/gi) ?? [];
if (inlineHandlers.length > 0) fail(`${inlineHandlers.length} inline event handler attribute(s)`);
else pass('no inline event handlers');

const thirdParty = (stripped.match(/https?:\/\/[^"')\s]+/g) ?? []).filter(
  (url) => !url.startsWith('http://localhost'),
);
if (thirdParty.length > 0) fail(`third-party origin(s) referenced: ${thirdParty.join(', ')}`);
else pass('no third-party origins in the document');

// ── 4. The theme is pinned ───────────────────────────────────────────────────
// The panel ships in light mode. Without the attribute the CSS falls back to
// prefers-color-scheme, so an operator on a dark OS silently gets a different
// palette from the one the design was signed off in.
const htmlTag = stripped.match(/<html[^>]*>/i)?.[0] ?? '';
if (/data-theme=["']light["']/i.test(htmlTag)) {
  pass('theme pinned to light on <html>');
} else {
  fail('<html> is missing data-theme="light" — the panel would follow the OS theme');
}

console.log(
  failures === 0
    ? '\nBuilt document verified. Browser CSP enforcement is NOT covered — see README.'
    : `\n${failures} problem(s) in the built document.`,
);
process.exit(failures === 0 ? 0 : 1);
