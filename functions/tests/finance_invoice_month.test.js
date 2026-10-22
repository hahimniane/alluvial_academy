/**
 * One shared answer to "which month is this invoice in" (utils/finance_invoice_month.js),
 * and proof that every finance module uses it.
 *
 * Order: billing_month, period (first part of a range), period_start,
 * issued_date (New York), created_at. null when nothing gives a month.
 */
const {invoiceMonthOf} = require('../utils/finance_invoice_month');
const invoiceMath = require('../utils/finance_invoice_math');
const expenseMath = require('../utils/finance_expense_math');
const financeMath = require('../utils/finance_math');

const ts = (iso) => ({toDate: () => new Date(iso)});

describe('invoiceMonthOf', () => {
  test.each([
    ['billing_month wins', {billing_month: '2026-11', period: '2026-10', period_start: '2026-09'}, '2026-11'],
    ['period next', {period: '2026-10', period_start: '2026-09'}, '2026-10'],
    ['a dotted range counts for its first month', {period: '2026-07..2026-08'}, '2026-07'],
    ['a spaced range counts for its first month', {period: '2026-06 to 2026-08'}, '2026-06'],
    ['period_start as text', {period_start: '2026-04'}, '2026-04'],
    ['period_start as a timestamp (New York month)', {period_start: ts('2026-08-01T02:00:00Z')}, '2026-07'],
    ['free-text period falls through to the issue date', {period: 'Adult payment verification', issued_date: ts('2026-05-20T15:00:00Z')}, '2026-05'],
    ['issued_date in New York time', {issued_date: new Date('2026-10-01T03:00:00Z')}, '2026-09'],
    ['created_at as a last resort', {created_at: ts('2026-03-10T15:00:00Z')}, '2026-03'],
    ['a malformed billing_month is ignored', {billing_month: '2026-13', period: '2026-02'}, '2026-02'],
  ])('%s', (_, invoice, expected) => {
    expect(invoiceMonthOf(invoice)).toBe(expected);
  });

  test('null when nothing gives a month', () => {
    expect(invoiceMonthOf({})).toBeNull();
    expect(invoiceMonthOf(null)).toBeNull();
    expect(invoiceMonthOf({period: 'abc', due_date: ts('2026-10-01T00:00:00Z')})).toBeNull();
  });

  test('the due date never decides the month (the bank page used to read it first)', () => {
    expect(invoiceMonthOf({period: '2026-09', due_date: ts('2026-10-01T04:00:00Z')})).toBe('2026-09');
    expect(invoiceMonthOf({issued_date: ts('2026-09-25T16:00:00Z'), due_date: ts('2026-10-01T04:00:00Z')})).toBe('2026-09');
  });

  test('the invoice, expense and summary modules all give the same answer', () => {
    const samples = [
      {billing_month: '2026-11', period: '2026-10'},
      {period: '2026-07..2026-08'},
      {period_start: '2026-04'},
      {period_start: ts('2026-08-15T12:00:00Z')},
      {issued_date: ts('2026-09-25T16:00:00Z')},
      {},
    ];
    for (const sample of samples) {
      const expected = invoiceMonthOf(sample);
      expect(invoiceMath.invoiceBillingMonth(sample)).toBe(expected);
      expect(expenseMath.invoiceBillingMonth(sample)).toBe(expected);
      expect(financeMath.invoiceMonth(sample)).toBe(expected);
    }
  });
});
