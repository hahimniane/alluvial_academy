/**
 * Pure helpers for finance expenses, recurring costs and family credits.
 *
 * Nothing here reads or writes Firestore, so the rules in docs/finance/SPEC.md
 * (categories, recurring costs, soft delete) can be tested on their own.
 * Months are `yyyy-MM` strings in America/New_York time.
 */

const BOOKS_TIME_ZONE = 'America/New_York';

/** Categories an admin can enter. Teacher and administrator pay are computed. */
const ENTERED_CATEGORIES = ['software', 'marketing', 'transfer_fees', 'other'];
const ALL_CATEGORIES = ['teacher_pay', 'admin_pay', ...ENTERED_CATEGORIES];

const CATEGORY_GROUP = {
  teacher_pay: 'Staff',
  admin_pay: 'Staff',
  software: 'Administration',
  transfer_fees: 'Administration',
  marketing: 'Other',
  other: 'Other',
};

const MAX_NAME_LENGTH = 120;
const MAX_REASON_LENGTH = 300;
const MAX_AMOUNT = 1000000;

const MONTH_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

const isMonth = (value) => typeof value === 'string' && MONTH_PATTERN.test(value);

const isDateString = (value) => {
  if (typeof value !== 'string' || !DATE_PATTERN.test(value)) return false;
  const [y, m, d] = value.split('-').map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
};

const round2 = (n) => Math.round((Number(n) + Number.EPSILON) * 100) / 100;

/** `yyyy-MM-dd` and `yyyy-MM` of an instant, on the books' clock. */
const partsInBooksTime = (date, timeZone = BOOKS_TIME_ZONE) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const pick = (type) => parts.find((p) => p.type === type).value;
  return {year: pick('year'), month: pick('month'), day: pick('day')};
};

const monthOfDate = (date, timeZone = BOOKS_TIME_ZONE) => {
  const p = partsInBooksTime(date, timeZone);
  return `${p.year}-${p.month}`;
};

const dateStringOf = (date, timeZone = BOOKS_TIME_ZONE) => {
  const p = partsInBooksTime(date, timeZone);
  return `${p.year}-${p.month}-${p.day}`;
};

const addMonths = (month, delta) => {
  const [y, m] = month.split('-').map(Number);
  const index = y * 12 + (m - 1) + delta;
  return `${Math.floor(index / 12)}-${String((index % 12) + 1).padStart(2, '0')}`;
};

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const monthName = (month) => MONTH_NAMES[Number(month.split('-')[1]) - 1];

const cleanText = (value, max) =>
  (typeof value === 'string' ? value : '').replace(/\s+/g, ' ').trim().slice(0, max);

/**
 * A money amount in dollars, rounded to cents. `null` when it is not a usable
 * number (NaN, negative, absurdly large, or zero when zero is not allowed).
 */
const parseAmount = (raw, {allowZero = false} = {}) => {
  if (typeof raw === 'string' && raw.trim() === '') return null;
  const n = typeof raw === 'string' ? Number(raw.replace(/[$,\s]/g, '')) : Number(raw);
  if (!Number.isFinite(n) || n < 0 || n > MAX_AMOUNT) return null;
  const cents = round2(n);
  if (cents === 0 && !allowZero) return null;
  return cents;
};

/** The reason a person typed, or '' when missing. */
const parseReason = (raw) => cleanText(raw, MAX_REASON_LENGTH);

/**
 * Checks what an admin submitted when adding an expense.
 * Returns {ok:true, value} or {ok:false, message} with a plain message.
 *
 * `today` is the current day on the books' clock (`yyyy-MM-dd`); it is the
 * default date of a one-time expense when the month is the current one.
 */
const parseExpenseInput = (data, today) => {
  const input = data && typeof data === 'object' ? data : {};
  const month = input.month;
  if (!isMonth(month)) return {ok: false, message: 'Choose a month.'};

  const kind = input.kind;
  if (kind !== 'one_time' && kind !== 'recurring') {
    return {ok: false, message: 'Choose one time or every month.'};
  }

  const category = input.category;
  if (!ENTERED_CATEGORIES.includes(category)) {
    return {ok: false, message: 'Choose Software, Marketing, Transfer fees or Other.'};
  }

  const name = cleanText(input.name, MAX_NAME_LENGTH);
  if (!name) return {ok: false, message: 'Add what it was for.'};

  const amount = parseAmount(input.amount);
  if (amount === null) return {ok: false, message: 'Enter an amount above zero.'};

  if (kind === 'recurring') {
    const raw = input.day_of_month;
    const day = raw === undefined || raw === null || raw === '' ? 1 : Number(raw);
    if (!Number.isInteger(day) || day < 1 || day > 28) {
      return {ok: false, message: 'The billed-on day is a number from 1 to 28.'};
    }
    return {ok: true, value: {month, kind, category, name, amount, day_of_month: day}};
  }

  let date = input.date;
  if (date === undefined || date === null || date === '') {
    date = today && today.slice(0, 7) === month ? today : `${month}-01`;
  }
  if (!isDateString(date)) return {ok: false, message: 'Enter the date as year-month-day.'};
  if (date.slice(0, 7) !== month) {
    return {ok: false, message: `The date must be in ${monthName(month)}.`};
  }
  return {ok: true, value: {month, kind, category, name, amount, date}};
};

/** Whether a recurring cost applies to a month (start inclusive, end inclusive). */
const recurringInMonth = (cost, month) => {
  if (!cost || !isMonth(month) || !isMonth(cost.start_month)) return false;
  if (month < cost.start_month) return false;
  if (isMonth(cost.end_month) && month > cost.end_month) return false;
  return true;
};

const recurringCostsForMonth = (costs, month) =>
  (costs || []).filter((cost) => recurringInMonth(cost, month));

/**
 * 'confirmed' once the real amount is recorded; otherwise 'due' when the
 * billed-on day has come (or the month is over) and 'upcoming' before that.
 * `today` is `yyyy-MM-dd` on the books' clock.
 */
const recurringStatus = (cost, month, confirmation, today) => {
  if (confirmation) return 'confirmed';
  const currentMonth = today.slice(0, 7);
  if (month < currentMonth) return 'due';
  if (month > currentMonth) return 'upcoming';
  return Number(cost.day_of_month || 1) <= Number(today.slice(8, 10)) ? 'due' : 'upcoming';
};

/**
 * What a recurring cost counts for in a month: the confirmed amount, or the
 * usual amount flagged as an estimate until it is confirmed.
 */
const recurringAmount = (cost, confirmation) =>
  confirmation
    ? {amount: round2(confirmation.amount), estimate: false}
    : {amount: round2(cost.amount), estimate: true};

/**
 * The month a stored expense belongs to. Rows written before `month` existed
 * fall back to their `expense_date` (a Firestore Timestamp, Date or string).
 */
const expenseMonth = (row) => {
  if (!row) return null;
  if (isMonth(row.month)) return row.month;
  const raw = row.expense_date;
  if (!raw) return null;
  if (typeof raw === 'string') return isDateString(raw) ? raw.slice(0, 7) : null;
  const date = typeof raw.toDate === 'function' ? raw.toDate() : raw;
  return date instanceof Date && !Number.isNaN(date.getTime()) ? monthOfDate(date) : null;
};

/**
 * Legacy `finance_expenses.category` values. `null` means the row never counts
 * (pay comes from teacher audits and staff payouts instead).
 */
const normalizeLegacyCategory = (raw) => {
  switch (String(raw == null ? '' : raw).trim()) {
    case 'software':
      return 'software';
    case 'marketing':
    case 'marketing_cost':
      return 'marketing';
    case 'transfer_fees':
      return 'transfer_fees';
    case 'teacher_payment':
    case 'teacher_pay':
    case 'leadership_cost':
    case 'admin_pay':
      return null;
    default:
      return 'other';
  }
};

const emptyTotals = () => ({
  teacher_pay: 0,
  admin_pay: 0,
  software: 0,
  marketing: 0,
  transfer_fees: 0,
  other: 0,
});

/**
 * Totals by category for a month.
 *
 * - `oneOffs`: finance_expenses rows (deleted ones are skipped; rows whose
 *   legacy category is pay are skipped).
 * - `costs` + `confirmations`: recurring costs in the month, each counting its
 *   confirmed amount or its usual amount as an estimate.
 * - `computed`: {teacher_pay, admin_pay, transfer_fees} that come from staff
 *   pay, added as given.
 *
 * Returns {byCategory, total, estimate} where `estimate` is true while any
 * recurring cost is unconfirmed.
 */
const totalsForMonth = ({month, oneOffs = [], costs = [], confirmations = [], computed = {}}) => {
  const byCategory = emptyTotals();
  let estimate = false;

  for (const key of Object.keys(computed)) {
    if (key in byCategory) byCategory[key] += Number(computed[key]) || 0;
  }

  for (const row of oneOffs) {
    if (!row || row.deleted === true) continue;
    if (expenseMonth(row) !== month) continue;
    const category = normalizeLegacyCategory(row.category);
    if (!category) continue;
    byCategory[category] += Number(row.amount) || 0;
  }

  const confirmed = new Map();
  for (const confirmation of confirmations) {
    if (confirmation && confirmation.month === month) confirmed.set(confirmation.cost_id, confirmation);
  }
  for (const cost of recurringCostsForMonth(costs, month)) {
    const {amount, estimate: isEstimate} = recurringAmount(cost, confirmed.get(cost.id));
    const category = ENTERED_CATEGORIES.includes(cost.category) ? cost.category : 'other';
    byCategory[category] += amount;
    if (isEstimate) estimate = true;
  }

  for (const key of Object.keys(byCategory)) byCategory[key] = round2(byCategory[key]);
  const total = round2(Object.values(byCategory).reduce((a, b) => a + b, 0));
  return {byCategory, total, estimate};
};

/** Staff / Administration / Other roll-up of category totals. */
const rollup = (byCategory) => {
  const out = {Staff: 0, Administration: 0, Other: 0};
  for (const [category, amount] of Object.entries(byCategory || {})) {
    const group = CATEGORY_GROUP[category];
    if (group) out[group] += Number(amount) || 0;
  }
  for (const key of Object.keys(out)) out[key] = round2(out[key]);
  return out;
};

const toDate = (value) => {
  if (!value) return null;
  const date = typeof value.toDate === 'function' ? value.toDate() : value;
  return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
};

/**
 * The month an invoice bills for: `billing_month` (new invoices), else a
 * `period` that starts with `yyyy-MM` (older ones: "2026-09", "2026-07..2026-08"
 * count for their first month), else the month it was issued.
 */
const invoiceBillingMonth = (invoice) => {
  if (!invoice) return null;
  if (isMonth(invoice.billing_month)) return invoice.billing_month;
  const period = typeof invoice.period === 'string' ? invoice.period.trim() : '';
  if (isMonth(period.slice(0, 7)) && (period.length === 7 || /^\d{4}-\d{2}(\s|\.|$)/.test(period))) {
    return period.slice(0, 7);
  }
  const issued = toDate(invoice.issued_date) || toDate(invoice.created_at);
  return issued ? monthOfDate(issued) : null;
};

/** Dollars of discount lines on an invoice; cancelled invoices give none. */
const invoiceDiscountTotal = (invoice) => {
  if (!invoice || invoice.status === 'cancelled') return 0;
  const items = Array.isArray(invoice.items) ? invoice.items : [];
  let cents = 0;
  for (const item of items) {
    if (item && item.is_discount === true) cents += Math.round(Math.abs(Number(item.total) || 0) * 100);
  }
  return cents / 100;
};

module.exports = {
  invoiceBillingMonth,
  invoiceDiscountTotal,
  BOOKS_TIME_ZONE,
  ENTERED_CATEGORIES,
  ALL_CATEGORIES,
  CATEGORY_GROUP,
  MAX_NAME_LENGTH,
  MAX_REASON_LENGTH,
  isMonth,
  isDateString,
  round2,
  monthOfDate,
  dateStringOf,
  addMonths,
  monthName,
  parseAmount,
  parseReason,
  parseExpenseInput,
  recurringInMonth,
  recurringCostsForMonth,
  recurringStatus,
  recurringAmount,
  expenseMonth,
  normalizeLegacyCategory,
  totalsForMonth,
  rollup,
};
