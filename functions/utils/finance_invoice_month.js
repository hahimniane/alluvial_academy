'use strict';

/**
 * The ONE answer to "which finance month does this invoice belong to".
 *
 * Order: billing_month, then period (yyyy-MM, or the first part of
 * 'yyyy-MM..yyyy-MM' / 'yyyy-MM to yyyy-MM'), then the month of period_start,
 * then the month it was issued (New York time), then created_at as a last
 * resort. Returns null when none of them gives a month; callers that guard
 * money (edit, cancel, confirm) must fail closed on null.
 *
 * Used by the invoice callables, the bank confirmation path, the month
 * summary and the discount totals, so the month lock, the summary and the
 * bank page can never disagree about an invoice.
 */

const NEW_YORK = 'America/New_York';
const MONTH_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;
const LEADING_MONTH = /^(\d{4}-(?:0[1-9]|1[0-2]))(?:$|[\s.])/;

const toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === 'function') return toDate(value.toDate());
  if (typeof value === 'object') {
    const seconds = value.seconds != null ? value.seconds : value._seconds;
    if (seconds != null && Number.isFinite(Number(seconds))) return new Date(Number(seconds) * 1000);
    return null;
  }
  if (typeof value === 'number' || typeof value === 'string') {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
};

const nyMonthOf = (date) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: NEW_YORK,
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(date);
  const pick = (type) => parts.find((p) => p.type === type).value;
  return `${pick('year')}-${pick('month')}`;
};

const leadingMonth = (value) => {
  const s = typeof value === 'string' ? value.trim() : '';
  const m = s.match(LEADING_MONTH);
  return m ? m[1] : null;
};

/** @returns {string|null} yyyy-MM */
const invoiceMonthOf = (invoice) => {
  if (!invoice || typeof invoice !== 'object') return null;
  const billing = typeof invoice.billing_month === 'string' ? invoice.billing_month.trim() : '';
  if (MONTH_PATTERN.test(billing)) return billing;

  const fromPeriod = leadingMonth(invoice.period);
  if (fromPeriod) return fromPeriod;

  const start = invoice.period_start;
  const fromStartText = leadingMonth(start);
  if (fromStartText) return fromStartText;
  if (start && typeof start !== 'string') {
    const d = toDate(start);
    if (d) return nyMonthOf(d);
  }

  const issued = toDate(invoice.issued_date) || toDate(invoice.created_at);
  return issued ? nyMonthOf(issued) : null;
};

module.exports = {invoiceMonthOf, MONTH_PATTERN};
