/** Client-side CSV export from already-loaded data. No extra request. */

type Cell = string | number | null | undefined;

/**
 * Quotes every field and doubles inner quotes. A source label or metric name
 * containing a comma would otherwise shift every following column.
 */
function escapeCell(value: Cell): string {
  const text = value === null || value === undefined ? '' : String(value);
  return `"${text.replace(/"/g, '""')}"`;
}

export function toCsv(headers: string[], rows: Cell[][]): string {
  return [headers.map(escapeCell).join(','), ...rows.map((row) => row.map(escapeCell).join(','))]
    .join('\r\n');
}

export function downloadCsv(filename: string, headers: string[], rows: Cell[][]): void {
  // BOM so Excel reads it as UTF-8 rather than the local codepage.
  const blob = new Blob(['﻿' + toCsv(headers, rows)], {
    type: 'text/csv;charset=utf-8;',
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}
