/**
 * Bundle budget for the built output.
 *
 *   npm run build && npm run verify:bundle
 *
 * Budgets are on the GZIPPED size of what a cold load actually fetches — the
 * entry chunk plus CSS. Route chunks are excluded because they load on demand;
 * a large Analytics page should not fail the build for someone opening Users.
 *
 * These are ceilings with headroom, not targets. Raise them deliberately with a
 * note, never quietly to make a red build green.
 */
import { gzipSync } from 'node:zlib';
import { readdirSync, readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';

const ASSETS = resolve('dist/assets');

const BUDGETS = {
  /** Entry chunk: React + router + query + the app shell. */
  entryJsGzipKb: 130,
  /** Tailwind output for the whole app. */
  cssGzipKb: 12,
  /** Any single lazily-loaded route chunk. */
  routeChunkGzipKb: 20,
};

let failures = 0;
const fail = (m) => {
  console.error(`  FAIL  ${m}`);
  failures++;
};
const pass = (m) => console.log(`  PASS  ${m}`);

let files;
try {
  files = readdirSync(ASSETS);
} catch {
  console.error('Could not read dist/assets. Run `npm run build` first.');
  process.exit(1);
}

const gzipKb = (name) =>
  Number((gzipSync(readFileSync(join(ASSETS, name))).length / 1024).toFixed(1));

const entry = files.find((f) => /^index-.*\.js$/.test(f));
const css = files.filter((f) => f.endsWith('.css'));
const routeChunks = files.filter((f) => f.endsWith('.js') && f !== entry);

if (!entry) {
  fail('no entry chunk found');
} else {
  const size = gzipKb(entry);
  if (size > BUDGETS.entryJsGzipKb) {
    fail(`entry chunk ${size}kb gzipped exceeds ${BUDGETS.entryJsGzipKb}kb`);
  } else {
    pass(`entry chunk ${size}kb gzipped (budget ${BUDGETS.entryJsGzipKb}kb)`);
  }
}

const cssTotal = css.reduce((sum, f) => sum + gzipKb(f), 0);
if (cssTotal > BUDGETS.cssGzipKb) {
  fail(`css ${cssTotal.toFixed(1)}kb gzipped exceeds ${BUDGETS.cssGzipKb}kb`);
} else {
  pass(`css ${cssTotal.toFixed(1)}kb gzipped (budget ${BUDGETS.cssGzipKb}kb)`);
}

const oversized = routeChunks
  .map((f) => [f, gzipKb(f)])
  .filter(([, size]) => size > BUDGETS.routeChunkGzipKb);

if (oversized.length > 0) {
  for (const [name, size] of oversized) {
    fail(`route chunk ${name} is ${size}kb gzipped, over ${BUDGETS.routeChunkGzipKb}kb`);
  }
} else {
  pass(`${routeChunks.length} route chunks, all under ${BUDGETS.routeChunkGzipKb}kb gzipped`);
}

// Splitting only helps if it actually happened.
if (routeChunks.length < 5) {
  fail(`only ${routeChunks.length} split chunks — route splitting may have regressed`);
} else {
  pass(`code splitting active (${routeChunks.length} chunks)`);
}

console.log(failures === 0 ? '\nBundle within budget.' : `\n${failures} budget problem(s).`);
process.exit(failures === 0 ? 0 : 1);
