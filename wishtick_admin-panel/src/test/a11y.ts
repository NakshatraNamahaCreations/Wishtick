import axe, { type AxeResults, type Result } from 'axe-core';
import { expect } from 'vitest';

/**
 * Real axe-core runs against rendered output, so accessibility is an assertion
 * rather than a claim.
 *
 * Scoped to WCAG 2.1 A/AA, and to `critical` + `serious` impact — the exit
 * criterion. `moderate`/`minor` findings are reported for information but do
 * not fail, because in jsdom several of them are artefacts of an unstyled
 * document rather than genuine defects.
 */
export async function expectNoA11yViolations(container: HTMLElement): Promise<void> {
  const results: AxeResults = await axe.run(container, {
    runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'] },
    rules: {
      // jsdom has no layout engine, so every element computes to zero size and
      // colour-contrast cannot be evaluated. Contrast is verified against the
      // design tokens in design-system.md instead, not here.
      'color-contrast': { enabled: false },
    },
  });

  const blocking = results.violations.filter(
    (violation) => violation.impact === 'critical' || violation.impact === 'serious',
  );

  if (blocking.length > 0) {
    throw new Error(formatViolations(blocking));
  }

  expect(blocking).toHaveLength(0);
}

function formatViolations(violations: Result[]): string {
  return violations
    .map((violation) => {
      const nodes = violation.nodes
        .slice(0, 3)
        .map((node) => `      ${node.html.slice(0, 120)}`)
        .join('\n');
      return [
        `  [${violation.impact}] ${violation.id}: ${violation.help}`,
        `    ${violation.helpUrl}`,
        nodes,
      ].join('\n');
    })
    .join('\n\n');
}
