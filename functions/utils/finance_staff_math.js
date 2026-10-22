/**
 * Pure helpers for finance staff pay: which pay terms apply in a month, whether
 * an administrator is paused, and how payouts add up. No Firestore here, so
 * everything is unit-tested directly (tests/finance_staff_math.test.js).
 *
 * Months are `yyyy-MM` strings in America/New_York (docs/finance/SPEC.md).
 */

const NY_TIME_ZONE = 'America/New_York';
const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;
const DATE_RE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;
const SHORT_MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const isMonth = (value) => typeof value === 'string' && MONTH_RE.test(value);

const isDateString = (value) => {
  if (typeof value !== 'string' || !DATE_RE.test(value)) return false;
  const [y, m, d] = value.split('-').map(Number);
  const probe = new Date(Date.UTC(y, m - 1, d));
  return probe.getUTCFullYear() === y && probe.getUTCMonth() === m - 1 && probe.getUTCDate() === d;
};

const r2 = (n) => Math.round((Number(n) + Number.EPSILON) * 100) / 100;

const toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

/** The New York `yyyy-MM` for an instant. */
const nyMonthOf = (date = new Date()) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: NY_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(date);
  const y = parts.find((p) => p.type === 'year').value;
  const m = parts.find((p) => p.type === 'month').value;
  return `${y}-${m}`;
};

/** "Oct 22" for an instant, in New York time. */
const nyShortDate = (date = new Date()) => {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: NY_TIME_ZONE,
    month: 'numeric',
    day: 'numeric',
  }).formatToParts(date);
  const m = Number(parts.find((p) => p.type === 'month').value);
  const d = Number(parts.find((p) => p.type === 'day').value);
  return `${SHORT_MONTHS[m - 1]} ${d}`;
};

const addMonths = (month, delta) => {
  const [y, m] = month.split('-').map(Number);
  const idx = y * 12 + (m - 1) + delta;
  return `${Math.floor(idx / 12)}-${String((idx % 12) + 1).padStart(2, '0')}`;
};

/** The term that applies in `month`: the latest one starting on or before it. */
const termInForce = (terms, month) => {
  let best = null;
  for (const term of Array.isArray(terms) ? terms : []) {
    if (!term || !isMonth(term.from_month) || term.from_month > month) continue;
    if (!best || term.from_month >= best.from_month) best = term;
  }
  return best;
};

/** The pause covering `month` (from_month <= month < until_month), if any. */
const pauseForMonth = (pauses, month) => {
  for (const pause of Array.isArray(pauses) ? pauses : []) {
    if (!pause || !isMonth(pause.from_month) || pause.from_month > month) continue;
    if (pause.until_month && pause.until_month <= month) continue;
    return pause;
  }
  return null;
};

/** The pause that has not been resumed yet. */
const openPause = (pauses) => {
  const open = (Array.isArray(pauses) ? pauses : []).filter((p) => p && !p.until_month);
  return open.length ? open[open.length - 1] : null;
};

/** Fixed pay for a month: 0 when paused or before any terms. */
const fixedPayFor = (doc, month) => {
  if (pauseForMonth(doc && doc.pauses, month)) return 0;
  const term = termInForce(doc && doc.terms, month);
  return term ? r2(Math.max(0, Number(term.fixed) || 0)) : 0;
};

/** A profit share: pct of the base, which is floored at 0 (a losing month pays nothing). */
const shareOf = (base, pct) => r2((Math.max(0, Number(base) || 0) * Math.min(100, Math.max(0, Number(pct) || 0))) / 100);

/**
 * Add or replace the term starting `from_month`; history stays sorted by start
 * month. Returns a new array.
 */
const upsertTerm = (terms, term) => {
  const kept = (Array.isArray(terms) ? terms : []).filter((t) => t && t.from_month !== term.from_month);
  return [...kept, term].sort((a, b) => (a.from_month < b.from_month ? -1 : a.from_month > b.from_month ? 1 : 0));
};

/** Open a pause. Returns a new array. */
const addPause = (pauses, pause) => [...(Array.isArray(pauses) ? pauses : []), pause];

/** Close the open pause at `untilMonth`. Returns a new array. */
const closeOpenPause = (pauses, untilMonth, extra = {}) =>
  (Array.isArray(pauses) ? pauses : []).map((p) =>
    p && !p.until_month ? {...p, until_month: untilMonth, ...extra} : p
  );

/** What has really been paid: payments in the history that were not voided. */
const payoutTotals = (history) => {
  let paid = 0;
  let fee = 0;
  let count = 0;
  for (const entry of Array.isArray(history) ? history : []) {
    if (!entry || entry.action !== 'payment' || entry.voided) continue;
    paid += Number(entry.amount_paid) || 0;
    fee += Number(entry.transfer_fee) || 0;
    count += 1;
  }
  return {paid: r2(paid), fee: r2(fee), count};
};

/** Money still owed on a payout (never negative). */
const amountLeft = (due, paid) => r2(Math.max(0, (Number(due) || 0) - (Number(paid) || 0)));

/** The history entry that is the same payment (amount, date, method, reference). */
const sameEntry = (entry, payment) =>
  r2(entry.amount_paid) === r2(payment.amount_paid) &&
  entry.date_paid === payment.date_paid &&
  String(entry.method || '').toLowerCase() === String(payment.method || '').toLowerCase() &&
  String(entry.reference || '').toLowerCase() === String(payment.reference || '').toLowerCase();

/**
 * Why a payment must not be added to this payout, or null when it is fine:
 *  - {kind:'duplicate'} the same payment is already in the history (a double
 *    click, a retried request);
 *  - {kind:'overpay', alreadyPaid} what is already paid (voided payments do not
 *    count) plus this payment is more than what is due.
 */
const paymentRefusal = (existing, payment, amountDue) => {
  const history = existing && Array.isArray(existing.history) ? existing.history : [];
  const live = history.filter((e) => e && e.action === 'payment' && !e.voided);
  if (existing && !existing.voided && live.some((e) => sameEntry(e, payment))) {
    return {kind: 'duplicate'};
  }
  const alreadyPaid =
    existing && !existing.voided
      ? Math.max(r2(Number(existing.amount_paid) || 0), payoutTotals(history).paid)
      : 0;
  if (r2(alreadyPaid + payment.amount_paid) > r2(amountDue) + 0.005) {
    return {kind: 'overpay', alreadyPaid};
  }
  return null;
};

/**
 * The staff_payouts document after one more payment.
 *
 * A second payment for the same person and month adds to the first; a payout
 * that was voided starts again from zero (its history is kept, marked voided).
 */
const applyPayment = (existing, payment, ctx) => {
  const live = existing && !existing.voided ? existing : null;
  const history = [
    ...(existing && Array.isArray(existing.history) ? existing.history : []),
    {
      action: 'payment',
      amount_paid: r2(payment.amount_paid),
      method: payment.method,
      date_paid: payment.date_paid,
      transfer_fee: r2(payment.transfer_fee || 0),
      reference: payment.reference || '',
      note: payment.note || '',
      at: ctx.at,
      by: ctx.by,
      by_name: ctx.by_name || '',
    },
  ];
  const totals = payoutTotals(history);
  return {
    user_id: ctx.uid,
    name: ctx.name || (existing && existing.name) || '',
    role: ctx.role,
    month: ctx.month,
    amount_due: r2(ctx.amount_due),
    amount_paid: totals.paid,
    date_paid: payment.date_paid,
    method: payment.method,
    transfer_fee: totals.fee,
    reference: payment.reference || (live && live.reference) || '',
    receipt_path: (live && live.receipt_path) || null,
    note: payment.note || (live && live.note) || '',
    recorded_at: ctx.at,
    recorded_by: ctx.by,
    voided: false,
    void_reason: '',
    history,
  };
};

/** The document after a void: nothing counts, nothing is deleted. */
const applyVoid = (existing, reason, ctx) => ({
  ...existing,
  amount_paid: 0,
  transfer_fee: 0,
  voided: true,
  void_reason: reason,
  voided_at: ctx.at,
  voided_by: ctx.by,
  history: [
    ...(Array.isArray(existing.history) ? existing.history : []).map((e) =>
      e && e.action === 'payment' ? {...e, voided: true} : e
    ),
    {action: 'void', reason, at: ctx.at, by: ctx.by, by_name: ctx.by_name || ''},
  ],
});

module.exports = {
  NY_TIME_ZONE,
  isMonth,
  isDateString,
  r2,
  toDate,
  nyMonthOf,
  nyShortDate,
  addMonths,
  termInForce,
  pauseForMonth,
  openPause,
  fixedPayFor,
  shareOf,
  upsertTerm,
  addPause,
  closeOpenPause,
  payoutTotals,
  amountLeft,
  paymentRefusal,
  applyPayment,
  applyVoid,
};
