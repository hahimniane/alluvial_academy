'use strict';

/**
 * Pure invoice helpers for the finance area: billing month, overdue, totals,
 * edit validation and the credit created when an edit lowers an invoice below
 * what was already paid. No Firestore here, so every rule is unit-tested
 * without a database (functions/tests/finance_invoices.test.js).
 *
 * The web mirror of the date and overdue rules lives in
 * apps/web/src/lib/finance/invoices.ts; keep the two in step.
 */

const BOOKS_TIME_ZONE = 'America/New_York';
const DAY_MS = 24 * 60 * 60 * 1000;
const MONTH_RE = /^(\d{4})-(\d{2})/;

const r2 = (n) => Math.round((Number(n) + Number.EPSILON) * 100) / 100;

const toNumber = (...values) => {
  for (const value of values) {
    if (value == null || value === '') continue;
    const n = Number(value);
    if (Number.isFinite(n)) return n;
  }
  return 0;
};

/** Timestamp | Date | ISO string | {seconds} -> Date (or null). */
const toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === 'function') return toDate(value.toDate());
  if (typeof value === 'object' && value.seconds != null) {
    return new Date(Number(value.seconds) * 1000);
  }
  if (typeof value === 'object' && value._seconds != null) {
    return new Date(Number(value._seconds) * 1000);
  }
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
};

const partsIn = (date, timeZone) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const pick = (type) => parts.find((p) => p.type === type).value;
  return {y: pick('year'), m: pick('month'), d: pick('day')};
};

/** yyyy-MM of an instant, in New York time. */
const monthOfDate = (date, timeZone = BOOKS_TIME_ZONE) => {
  const {y, m} = partsIn(date, timeZone);
  return `${y}-${m}`;
};

/** yyyy-MM-dd of "today" (or any instant), in New York time. */
const dayKeyNY = (date) => {
  const {y, m, d} = partsIn(date, BOOKS_TIME_ZONE);
  return `${y}-${m}-${d}`;
};

/**
 * The calendar day an invoice is due. Stored due dates are a mix: the
 * generators write midnight UTC for "the 25th", the old web form wrote local
 * noon. A value at exactly 00:00:00 UTC means that UTC date; anything else is
 * read in New York time, so neither kind slips a day.
 */
const dueDayKey = (value) => {
  const date = toDate(value);
  if (!date) return null;
  if (
    date.getUTCHours() === 0 &&
    date.getUTCMinutes() === 0 &&
    date.getUTCSeconds() === 0
  ) {
    return date.toISOString().slice(0, 10);
  }
  return dayKeyNY(date);
};

const dayNumber = (key) => {
  const [y, m, d] = key.split('-').map(Number);
  return Math.round(Date.UTC(y, m - 1, d) / DAY_MS);
};

/** Whole days from `fromKey` to `toKey` (yyyy-MM-dd); positive when later. */
const daysBetween = (fromKey, toKey) => dayNumber(toKey) - dayNumber(fromKey);

/** The stored due date for a calendar day: noon UTC, which is that day in New York. */
const dueTimestampDate = (dayKey) => new Date(`${dayKey}T12:00:00.000Z`);

const isDayKey = (value) => {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const d = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value;
};

/**
 * The month an invoice bills for: `billing_month`, else the `period`
 * (yyyy-MM, or the first month of a range), else the month it was issued.
 */
const invoiceBillingMonth = (invoice = {}) => {
  const direct = String(invoice.billing_month || '').trim();
  if (MONTH_RE.test(direct)) return direct.slice(0, 7);
  const period = String(invoice.period || invoice.period_start || '').trim();
  const match = period.match(MONTH_RE);
  if (match) return `${match[1]}-${match[2]}`;
  const issued = toDate(invoice.issued_date || invoice.created_at);
  return issued ? monthOfDate(issued) : null;
};

const isCancelled = (invoice = {}) =>
  String(invoice.status || '').trim().toLowerCase() === 'cancelled';

const invoiceTotal = (invoice = {}) =>
  r2(toNumber(invoice.total_amount, invoice.totalAmount));
const invoicePaid = (invoice = {}) =>
  r2(toNumber(invoice.paid_amount, invoice.paidAmount));

/** What is still owed; never negative, zero for a cancelled invoice. */
const balanceOf = (invoice = {}) =>
  isCancelled(invoice) ? 0 : Math.max(0, r2(invoiceTotal(invoice) - invoicePaid(invoice)));

/** Overdue is computed: money still owed and today is after the due day. */
const isOverdue = (invoice = {}, now = new Date()) => {
  if (balanceOf(invoice) <= 0.004) return false;
  const due = dueDayKey(invoice.due_date || invoice.dueDate);
  if (!due) return false;
  return dayKeyNY(now) > due;
};

const daysOverdue = (invoice = {}, now = new Date()) => {
  if (!isOverdue(invoice, now)) return 0;
  return daysBetween(dueDayKey(invoice.due_date || invoice.dueDate), dayKeyNY(now));
};

/** Stored status after an edit: only paid or pending; overdue is computed. */
const statusAfterEdit = ({total, paid}) =>
  r2(total) - r2(paid) <= 0.004 ? 'paid' : 'pending';

/** Split stored items into billable lines and discount lines. */
const splitItems = (items) => {
  const list = Array.isArray(items) ? items : [];
  const lines = [];
  const discountLines = [];
  for (const item of list) {
    if (!item || typeof item !== 'object') continue;
    const total = toNumber(item.total, toNumber(item.quantity, 1) * toNumber(item.unit_price, item.unitPrice));
    if (item.is_discount === true || total < 0) {
      discountLines.push({...item, total});
    } else {
      lines.push({...item, total});
    }
  }
  const discountTotal = r2(
    discountLines.reduce((sum, item) => sum + Math.abs(item.total), 0)
  );
  return {lines, discountLines, discountTotal};
};

const linesSubtotal = (lines) =>
  r2((lines || []).reduce((sum, l) => sum + toNumber(l.amount, l.total), 0));

/** total = sum(lines) - discount, floored at zero is NOT applied: invalid instead. */
const totalFor = (lines, discount) => r2(linesSubtotal(lines) - toNumber(discount));

/** Money that becomes a family credit when a total is lowered below what was paid. */
const creditOnLower = ({total, paid}) => {
  const over = r2(r2(paid) - r2(total));
  return over > 0.004 ? over : 0;
};

/**
 * Validates an `editInvoice` request. Returns {ok:true, value} with normalised
 * lines, or {ok:false, error} with a plain sentence for the admin.
 */
const validateEdit = (input = {}) => {
  const reason = String(input.reason == null ? '' : input.reason).trim();
  if (!reason) return {ok: false, error: 'Add a reason for the change.'};

  const rawLines = Array.isArray(input.lines) ? input.lines : [];
  if (rawLines.length === 0) {
    return {ok: false, error: 'An invoice needs at least one line.'};
  }
  const lines = [];
  for (const raw of rawLines) {
    const description = String((raw && raw.description) == null ? '' : raw.description).trim();
    if (!description) {
      return {ok: false, error: 'Every line needs a description.'};
    }
    const amountRaw = raw.amount;
    const amount =
      typeof amountRaw === 'number' ? amountRaw : Number(String(amountRaw == null ? '' : amountRaw).trim());
    if (amountRaw === '' || amountRaw == null || !Number.isFinite(amount)) {
      return {ok: false, error: 'Every line needs an amount.'};
    }
    if (amount < 0) {
      return {
        ok: false,
        error: 'A line cannot be negative. Use the discount box to take money off.',
      };
    }
    const studentId = String((raw && (raw.student_id || raw.studentId)) || '').trim();
    lines.push({
      description,
      amount: r2(amount),
      ...(studentId ? {student_id: studentId} : {}),
    });
  }

  const discountRaw = input.discount == null || input.discount === '' ? 0 : Number(input.discount);
  if (!Number.isFinite(discountRaw) || discountRaw < 0) {
    return {ok: false, error: 'The discount must be zero or more.'};
  }
  const discount = r2(discountRaw);

  const total = totalFor(lines, discount);
  if (total < 0) {
    return {ok: false, error: 'The discount is more than the lines add up to.'};
  }

  const dueDate = String(input.due_date == null ? '' : input.due_date).trim();
  if (!isDayKey(dueDate)) {
    return {ok: false, error: 'Pick a due date.'};
  }

  return {ok: true, value: {reason, lines, discount, total, dueDate}};
};

/**
 * Stored items for an edit: billable lines in the existing schema, plus the
 * discount as `is_discount` negative lines. If the discount did not change the
 * invoice's own discount lines are kept as they were; otherwise a single line
 * carries the new amount under the first old discount's wording.
 */
const buildItems = ({lines, discount, previousItems}) => {
  const previous = splitItems(previousItems);
  const billable = lines.map((l) => ({
    description: l.description,
    quantity: 1,
    unit_price: l.amount,
    total: l.amount,
    ...(l.student_id ? {student_id: l.student_id} : {}),
    shift_ids: [],
  }));
  if (discount <= 0.004) return billable;
  if (Math.abs(previous.discountTotal - discount) < 0.005 && previous.discountLines.length) {
    return [...billable, ...previous.discountLines];
  }
  const first = previous.discountLines[0] || {};
  return [
    ...billable,
    {
      description: first.description || 'Discount',
      quantity: 1,
      unit_price: -discount,
      total: -discount,
      ...(first.student_id && previous.discountLines.length === 1
        ? {student_id: first.student_id}
        : {}),
      shift_ids: [],
      is_discount: true,
      discount_reason: first.discount_reason || '',
    },
  ];
};

/**
 * When the due date moves later, the access cutoff keeps its gap after the due
 * date (never moves earlier), so a family given more time is not suspended by
 * the old cutoff. Returns the new cutoff Date, or null to leave it alone.
 */
const shiftedCutoff = ({oldDue, newDueKey, cutoff}) => {
  const oldKey = dueDayKey(oldDue);
  const cut = toDate(cutoff);
  if (!oldKey || !cut || !isDayKey(newDueKey)) return null;
  const delta = daysBetween(oldKey, newDueKey);
  if (delta <= 0) return null;
  return new Date(cut.getTime() + delta * DAY_MS);
};

/**
 * Monthly tuition is one invoice per family per month. Returns the existing
 * non-cancelled invoice that already bills this month, or null. Counts kinds
 * 'monthly' and 'first_month', and the scheduled generator's invoices (ids
 * `recurring_...`, which predate `kind`).
 */
const findMonthlyInvoiceClash = ({invoices = [], month}) => {
  if (!month) return null;
  for (const inv of invoices) {
    if (!inv || isCancelled(inv)) continue;
    const kind = String(inv.kind || '').trim();
    const generated =
      !kind && (String(inv.id || '').startsWith('recurring_') || Boolean(inv.recurring_plan_id));
    if (kind !== 'monthly' && kind !== 'first_month' && !generated) continue;
    if (invoiceBillingMonth(inv) === month) return inv;
  }
  return null;
};

module.exports = {
  BOOKS_TIME_ZONE,
  r2,
  toNumber,
  toDate,
  monthOfDate,
  dayKeyNY,
  dueDayKey,
  daysBetween,
  dueTimestampDate,
  isDayKey,
  invoiceBillingMonth,
  isCancelled,
  invoiceTotal,
  invoicePaid,
  balanceOf,
  isOverdue,
  daysOverdue,
  statusAfterEdit,
  splitItems,
  linesSubtotal,
  totalFor,
  creditOnLower,
  validateEdit,
  buildItems,
  shiftedCutoff,
  findMonthlyInvoiceClash,
};
