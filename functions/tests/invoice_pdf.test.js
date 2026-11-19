/**
 * Invoice / receipt PDF layout.
 *
 * Expected behavior:
 * - A fully paid invoice prints as a "Receipt" with a PAID badge, the amount
 *   paid and the payment date; anything else prints as an "Invoice" whose badge
 *   says Due, Partially paid, Overdue or Cancelled.
 * - Money columns are right-aligned, long descriptions wrap inside their column,
 *   and long item lists continue on further pages with the table header repeated
 *   and "Page n of m" in every footer. Nothing is drawn below the footer line.
 * - Accented Latin names are kept (WinAnsi); characters the font cannot draw are
 *   dropped instead of corrupting the file.
 * - There is no "Received by" / signature block any more.
 */
const {generateInvoicePdfBuffer, buildInvoicePdfPages, describeInvoice, textWidth, wrapToWidth} = require('../utils/invoice_pdf');

const now = new Date('2026-11-19T12:00:00Z');
const base = {
  invoice_number: 'INV-1', currency: 'USD', status: 'pending',
  issued_date: new Date('2026-11-01T15:00:00Z'), due_date: new Date('2026-11-26T15:00:00Z'),
  total_amount: 200, paid_amount: 0, parentName: 'Mariama Barry', studentName: 'Aminata',
  items: [{description: 'Tuition', quantity: 1, unit_price: 200, total: 200}],
};
const content = (inv) => buildInvoicePdfPages(inv, {now}).join('\n');

test('paid in full prints a receipt with the payment date', () => {
  const inv = {...base, status: 'paid', paid_amount: 200, last_payment_at: new Date('2026-11-19T03:33:25Z')};
  expect(describeInvoice(inv, now).status).toBe('paid');
  const text = content(inv);
  expect(text).toMatch(/\(Receipt\) Tj/);
  expect(text).toMatch(/\(PAID\) Tj/);
  expect(text).toMatch(/\(Paid on November 18, 2026\) Tj/); // New York date
  expect(text).not.toMatch(/Received by|Signature/);
  expect(text).not.toMatch(/\(Access until\)/);
});

test('status badge follows the balance and the due date', () => {
  expect(describeInvoice(base, now).status).toBe('due');
  expect(describeInvoice({...base, paid_amount: 50}, now).status).toBe('partial');
  expect(describeInvoice({...base, paid_amount: 50, due_date: new Date('2026-11-10')}, now).status).toBe('overdue');
  expect(describeInvoice({...base, status: 'cancelled'}, now).status).toBe('cancelled');
  expect(describeInvoice({...base, status: 'pending', paid_amount: 200}, now).status).toBe('paid');
  const text = content({...base, paid_amount: 50});
  expect(text).toMatch(/\(Invoice\) Tj/);
  expect(text).toMatch(/\(PARTIALLY PAID\) Tj/);
  expect(text).toMatch(/\(BALANCE DUE\) Tj/);
  expect(text).toMatch(/\(\$150\.00\) Tj/);
});

test('amounts are right-aligned on the same edge', () => {
  const text = content({...base, items: [{description: 'A', quantity: 1, unit_price: 5, total: 5}, {description: 'B', quantity: 1, unit_price: 1234.5, total: 1234.5}]});
  const right = (s, size) => {
    const re = new RegExp(`/F1 ${size} Tf ([\\d.]+) [\\d.]+ Td \\(\\${s}\\) Tj`);
    const m = text.match(re);
    return Number(m[1]) + textWidth(s, size);
  };
  expect(right('$5.00', 10)).toBeCloseTo(right('$1,234.50', 10), 1);
});

test('long lists flow onto more pages, header repeated, nothing under the footer', () => {
  const items = Array.from({length: 60}, (_, i) => ({description: `Class ${i + 1}`, quantity: 1, unit_price: 10, total: 10}));
  const pages = buildInvoicePdfPages({...base, items, total_amount: 600}, {now});
  expect(pages.length).toBeGreaterThan(1);
  pages.forEach((page, i) => {
    expect(page).toMatch(new RegExp(`\\(Page ${i + 1} of ${pages.length}\\) Tj`));
    expect(page).toMatch(/\(DESCRIPTION\) Tj/);
    expect(page).toMatch(/\(Class \d+\) Tj/);
    const ys = [...page.matchAll(/Tf [\d.]+ ([\d.]+) Td \((?!Page |Alluwal Education Hub )/g)].map((m) => Number(m[1]));
    ys.forEach((y) => expect(y).toBeGreaterThanOrEqual(48 + 44 - 1));
  });
  expect(pages[pages.length - 1]).toMatch(/\(Class 60\) Tj[\s\S]*\(Balance due\) Tj/);
  for (let n = 1; n <= 60; n += 1) expect(pages.join('\n')).toMatch(new RegExp(`\\(Class ${n}\\) Tj`));
});

test('long descriptions wrap within the column', () => {
  const lines = wrapToWidth('Monthly tuition for two students, including Tajweed, Hifz review and weekend club', 200, 10);
  expect(lines.length).toBeGreaterThan(1);
  lines.forEach((l) => expect(textWidth(l, 10)).toBeLessThanOrEqual(200));
  expect(wrapToWidth('x'.repeat(300), 100, 10).every((l) => textWidth(l, 10) <= 100)).toBe(true);
});

test('accented names survive, unknown characters are dropped, file is well formed', () => {
  const buf = generateInvoicePdfBuffer({...base, parentName: 'Aïcha Diakité 🙂', items: [{description: 'Cours — été', quantity: 1, unit_price: 1, total: 1}]}, {now});
  const text = buf.toString('latin1');
  expect(text.startsWith('%PDF-1.4\n')).toBe(true);
  expect(text.trimEnd().endsWith('%%EOF')).toBe(true);
  expect(text).toMatch(/\(A\xEFcha Diakit\xE9\) Tj/);
  expect(text).toMatch(/\(Cours - \xE9t\xE9\) Tj/);
  const xref = Number(text.match(/startxref\n(\d+)/)[1]);
  expect(text.slice(xref, xref + 4)).toBe('xref');
  const offsets = [...text.matchAll(/(\d{10}) 00000 n/g)].map((m) => Number(m[1]));
  offsets.forEach((o, i) => expect(text.slice(o).startsWith(`${i + 1} 0 obj`)).toBe(true));
});

test('billing period: range, one month, then the issue month', () => {
  expect(describeInvoice({...base, period_start: '2026-09', period_end: '2026-11'}, now).billingPeriod).toBe('September 2026 - November 2026');
  expect(describeInvoice({...base, period: '2026-10'}, now).billingPeriod).toBe('October 2026');
  expect(describeInvoice({...base, period: '2026-09..2026-10'}, now).billingPeriod).toBe('September 2026 - October 2026');
  expect(describeInvoice({...base, billing_month: '2026-08'}, now).billingPeriod).toBe('August 2026');
  expect(describeInvoice(base, now).billingPeriod).toBe('November 2026');
});

test('empty and odd invoices still render', () => {
  expect(() => generateInvoicePdfBuffer({}, {now})).not.toThrow();
  expect(() => generateInvoicePdfBuffer({...base, items: null, total_amount: '12.5', paid_amount: 'x'}, {now})).not.toThrow();
  expect(content({...base, items: []})).toMatch(/\(No items on this invoice\) Tj/);
});
