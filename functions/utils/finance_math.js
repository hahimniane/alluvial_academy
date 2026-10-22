/**
 * The maths behind a finance month: pure functions, no Firestore.
 *
 * `buildMonthSummary` takes the documents a month is made of and returns the
 * numbers every finance page shows (docs/finance/SPEC.md, "getFinanceMonthSummary"
 * and money rules 1-6). Keeping it free of I/O is what lets the rules be tested
 * one by one: a losing month pays no percentage, a paused administrator is
 * paid nothing, old pay categories never double-count, cancelled invoices
 * never count.
 */

const {normalizeLegacyCategory} = require('./finance_categories');
const {invoiceMonthOf} = require('./finance_invoice_month');

const NEW_YORK = 'America/New_York';
const MONTH_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;
const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const FINAL_AUDIT_STATUSES = ['ceoApproved', 'completed'];
/** Invoice statuses that can still carry a balance. Anything else is settled or void. */
const UNSETTLED_STATUSES = ['pending', 'overdue', 'partial', 'partially_paid', 'unpaid', 'sent', 'issued', 'open'];

const r2 = (n) => Math.round((Number(n) + Number.EPSILON) * 100) / 100;
const num = (v) => {
  const n = typeof v === 'string' ? Number(v) : v;
  return typeof n === 'number' && Number.isFinite(n) ? n : 0;
};
const text = (v) => (typeof v === 'string' ? v.trim() : '');

/** Date from a Firestore Timestamp, Date, ISO string or epoch millis; else null. */
const toDate = (v) => {
  if (!v) return null;
  if (v instanceof Date) return Number.isNaN(v.getTime()) ? null : v;
  if (typeof v.toDate === 'function') return toDate(v.toDate());
  if (typeof v === 'number' || typeof v === 'string') {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof v.seconds === 'number') return new Date(v.seconds * 1000);
  if (typeof v._seconds === 'number') return new Date(v._seconds * 1000);
  return null;
};

// ---------------------------------------------------------------- months ----

const isMonth = (m) => typeof m === 'string' && MONTH_PATTERN.test(m);

const newYorkParts = (date) => {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: NEW_YORK,
    hourCycle: 'h23',
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  }).formatToParts(date);
  const get = (type) => Number(parts.find((p) => p.type === type).value);
  return {year: get('year'), month: get('month'), day: get('day'), hour: get('hour'), minute: get('minute'), second: get('second')};
};

/** yyyy-MM of an instant, in New York time. */
const monthOf = (date) => {
  const p = newYorkParts(date);
  return `${p.year}-${String(p.month).padStart(2, '0')}`;
};

const addMonths = (month, delta) => {
  const [y, m] = month.split('-').map(Number);
  const index = y * 12 + (m - 1) + delta;
  return `${Math.floor(index / 12)}-${String((index % 12) + 1).padStart(2, '0')}`;
};

/** The instant it is 00:00 on the first of `month` in New York. */
const monthStart = (month) => {
  const [y, m] = month.split('-').map(Number);
  const wanted = Date.UTC(y, m - 1, 1);
  let instant = wanted;
  // Each pass moves by how far New York's wall clock is from midnight, which
  // settles the UTC offset even when a clock change is close by.
  for (let i = 0; i < 3; i++) {
    const p = newYorkParts(new Date(instant));
    instant += wanted - Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  }
  return new Date(instant);
};

/** [start, end) of a month in New York time. */
const monthBounds = (month) => ({start: monthStart(month), end: monthStart(addMonths(month, 1))});

/** A month has ended once New York has moved into a later month. */
const monthEnded = (month, now) => monthOf(now) > month;

const monthLabel = (month) => {
  const [y, m] = month.split('-').map(Number);
  return `${MONTH_NAMES[m - 1]} ${y}`;
};

const monthName = (month) => MONTH_NAMES[Number(month.split('-')[1]) - 1];

/** Day of the month it is right now in New York. */
const newYorkDay = (now) => newYorkParts(now).day;

// -------------------------------------------------------------- invoices ----

/** The month an invoice is for: `billing_month`, else `period`, else the month of `period_start`. */
const invoiceMonth = (invoice) => invoiceMonthOf(invoice || {});

const isCancelled = (invoice) => text(invoice.status) === 'cancelled';
const invoiceBalance = (invoice) => Math.max(0, r2(num(invoice.total_amount) - num(invoice.paid_amount)));

/** Overdue is computed: a balance is owed and the due date has passed. */
const isOverdue = (invoice, now) => {
  if (isCancelled(invoice) || invoiceBalance(invoice) <= 0.004) return false;
  const due = toDate(invoice.due_date);
  return Boolean(due) && now.getTime() > due.getTime();
};

/** Positive amount of the discount lines on an invoice. */
const invoiceDiscount = (invoice) => {
  const items = Array.isArray(invoice.items) ? invoice.items : [];
  let total = 0;
  for (const item of items) {
    if (item && item.is_discount === true && num(item.total) < 0) total += -num(item.total);
  }
  return total;
};

/** Billed, collected and owed for the non-cancelled invoices that belong to `month`. */
const invoiceTotals = (invoices, month) => {
  let billed = 0;
  let collected = 0;
  let owed = 0;
  let discounts = 0;
  let count = 0;
  const families = new Set();
  for (const invoice of invoices) {
    if (isCancelled(invoice) || invoiceMonth(invoice) !== month) continue;
    count += 1;
    billed += num(invoice.total_amount);
    collected += num(invoice.paid_amount);
    discounts += invoiceDiscount(invoice);
    const balance = invoiceBalance(invoice);
    owed += balance;
    if (balance > 0.004) families.add(text(invoice.parent_id) || text(invoice.id));
  }
  return {
    billed: r2(billed),
    collected: r2(collected),
    owed: r2(owed),
    discounts: r2(discounts),
    invoice_count: count,
    families_owing: families.size,
  };
};

// -------------------------------------------------------- teacher pay ----

const isFinalAudit = (audit) => FINAL_AUDIT_STATUSES.includes(text(audit.status));

/** Hours the pay was worked out from; falls back to the audit's taught hours. */
const paidHours = (audit) => {
  const summary = audit.paymentSummary || {};
  const bySubject = summary.paymentsBySubject && typeof summary.paymentsBySubject === 'object'
    ? Object.values(summary.paymentsBySubject)
    : [];
  const fromPay = bySubject.reduce((sum, row) => sum + num(row && row.hoursTaught), 0);
  return r2(fromPay > 0 ? fromPay : num(audit.totalHoursTaught));
};

/**
 * Penalties taken from a teacher: the penalty lines coaches add to the audit
 * (`coachAdjustmentLines`, type "penalty"), plus the audit's own
 * `totalPenalties` when it carries one. `totalNetPayment` already has them
 * taken off, so they are shown, never subtracted again.
 */
const auditPenalties = (summary) => {
  const lines = Array.isArray(summary.coachAdjustmentLines) ? summary.coachAdjustmentLines : [];
  const fromLines = lines
    .filter((line) => line && line.type === 'penalty')
    .reduce((sum, line) => sum + Math.abs(num(line.amount)), 0);
  return r2(fromLines + Math.abs(num(summary.totalPenalties)));
};

/**
 * One row per teacher audit that has a pay figure. An audit with no hours and
 * no pay is nobody's pay; it is left out.
 */
const teacherRows = (audits) => {
  const rows = [];
  for (const audit of audits) {
    const summary = audit.paymentSummary;
    if (!summary || typeof summary !== 'object') continue;
    const net = r2(num(summary.totalNetPayment));
    const gross = r2(num(summary.totalGrossPayment));
    const penalties = auditPenalties(summary);
    const hours = paidHours(audit);
    if (net === 0 && gross === 0 && penalties === 0 && hours === 0) continue;
    const uid = text(audit.userId) || text(audit.oderId) || text(audit.id).split('_')[0];
    rows.push({
      uid,
      name: text(audit.teacherName) || text(audit.teacherEmail) || uid,
      hours,
      gross,
      penalties,
      net,
      final: isFinalAudit(audit),
    });
  }
  return rows.sort((a, b) => a.name.localeCompare(b.name));
};

/**
 * Audits that still hold up closing the month: not approved, and either
 * carrying pay or hours. A pending audit for a teacher who taught nothing has
 * nothing to approve.
 */
const auditsBlockingClose = (audits) =>
  audits.filter((audit) => {
    if (isFinalAudit(audit)) return false;
    const summary = audit.paymentSummary || {};
    return num(summary.totalNetPayment) !== 0 || num(summary.totalGrossPayment) !== 0 || paidHours(audit) > 0;
  });

// ------------------------------------------------------------- expenses ----

const expenseMonth = (expense) => {
  if (isMonth(text(expense.month))) return text(expense.month);
  const date = toDate(expense.expense_date);
  return date ? monthOf(date) : null;
};

const EMPTY_CATEGORIES = () => ({software: 0, marketing: 0, transfer_fees: 0, other: 0});

/**
 * Entered costs for the month by category, plus the recurring costs: confirmed
 * ones at the confirmed amount, unconfirmed ones at their usual amount.
 *
 * An expense row that points at a recurring cost counts through that cost's
 * confirmation; it only counts on its own when no confirmation exists.
 */
const costTotals = ({month, expenses, recurringCosts, confirmations, now}) => {
  const totals = EMPTY_CATEGORIES();
  const add = (category, amount) => {
    const key = normalizeLegacyCategory(category);
    if (key && key in totals) totals[key] += num(amount);
  };

  const confirmedByCost = new Map();
  for (const confirmation of confirmations) {
    if (text(confirmation.month) && text(confirmation.month) !== month) continue;
    confirmedByCost.set(text(confirmation.cost_id), confirmation);
  }

  const rowsByCost = new Map();
  for (const expense of expenses) {
    if (expense.deleted === true || expenseMonth(expense) !== month) continue;
    const costId = text(expense.recurring_cost_id);
    if (costId && confirmedByCost.has(costId)) continue;
    if (costId) rowsByCost.set(costId, expense);
    add(expense.category, expense.amount);
  }

  const nowMonth = monthOf(now);
  const ended = monthEnded(month, now);
  const today = newYorkDay(now);
  let pending = 0;
  let due = 0;
  const seen = new Set();

  for (const cost of recurringCosts) {
    const id = text(cost.id);
    const started = !text(cost.start_month) || text(cost.start_month) <= month;
    const stopped = text(cost.end_month) && text(cost.end_month) < month;
    const confirmation = confirmedByCost.get(id);
    if (!started) continue;
    if (stopped && !confirmation) continue;
    seen.add(id);
    const category = normalizeLegacyCategory(cost.category);
    if (confirmation) {
      add(cost.category, confirmation.amount);
    } else if (rowsByCost.has(id)) {
      // Already counted from its own expense row.
    } else if (category) {
      add(cost.category, cost.amount);
      pending += 1;
      if (ended || (month === nowMonth && num(cost.day_of_month) <= today)) due += 1;
    }
  }
  // A confirmation whose cost record was not loaded still counts.
  for (const [id, confirmation] of confirmedByCost) {
    if (!seen.has(id)) add('other', confirmation.amount);
  }

  return {
    software: r2(totals.software),
    marketing: r2(totals.marketing),
    transfer_fees: r2(totals.transfer_fees),
    other: r2(totals.other),
    recurring_pending: pending,
    recurring_due: due,
  };
};

/** Sum of `transfer_fee` on payouts that were not voided, in any month the caller loaded. */
const payoutTransferFees = (payouts) =>
  r2(payouts.filter((p) => p.voided !== true).reduce((sum, p) => sum + num(p.transfer_fee), 0));

// ------------------------------------------------------- administrators ----

/** The terms in force for `month`: the latest entry that starts on or before it. */
const termsInForce = (terms, month) => {
  const list = (Array.isArray(terms) ? terms : [])
    .filter((t) => t && isMonth(text(t.from_month)) && text(t.from_month) <= month)
    .sort((a, b) => (a.from_month < b.from_month ? -1 : a.from_month > b.from_month ? 1 : 0));
  return list.length ? list[list.length - 1] : null;
};

/**
 * The pause that covers `month`, if any. `until_month` is the month pay
 * RESUMES in (exclusive), the same rule as finance_staff_math.pauseForMonth:
 * paused when from_month <= month and (no until_month or month < until_month).
 */
const pauseFor = (pauses, month) => {
  const match = (Array.isArray(pauses) ? pauses : []).filter((p) => {
    if (!p || !isMonth(text(p.from_month)) || text(p.from_month) > month) return false;
    return !text(p.until_month) || month < text(p.until_month);
  });
  if (!match.length) return null;
  const latest = match.sort((a, b) => (a.from_month < b.from_month ? -1 : 1))[match.length - 1];
  return {reason: text(latest.reason), auto: latest.auto === true};
};

/**
 * What one administrator earns for the month: the fixed amount plus an
 * optional percentage of `base`. `base` is the money left after every other
 * cost and is never negative, so a losing month pays the fixed part only. A
 * paused administrator earns nothing.
 */
const adminPay = ({fixed, pct, base, paused}) => {
  if (paused) return {fixed: 0, pct: num(pct), share: 0, total: 0};
  const fixedAmount = r2(Math.max(0, num(fixed)));
  const percent = Math.max(0, num(pct));
  const share = percent > 0 ? r2((Math.max(0, base) * percent) / 100) : 0;
  return {fixed: fixedAmount, pct: percent, share, total: r2(fixedAmount + share)};
};

const adminRows = (adminDocs, month, base) => {
  const rows = [];
  for (const doc of adminDocs) {
    const terms = termsInForce(doc.terms, month);
    if (!terms) continue;
    const paused = pauseFor(doc.pauses, month);
    const pay = adminPay({fixed: terms.fixed, pct: terms.pct, base, paused: Boolean(paused)});
    rows.push({
      uid: text(doc.uid) || text(doc.id),
      name: text(doc.name) || text(doc.uid) || text(doc.id),
      role_title: text(doc.role_title),
      fixed: pay.fixed,
      pct: pay.pct,
      share: pay.share,
      total: pay.total,
      paused,
    });
  }
  return rows.sort((a, b) => a.name.localeCompare(b.name));
};

// -------------------------------------------------------------- summary ----

/** Whether a payout record covers this person. A payout without a role covers whoever its user id names. */
const hasPayout = (payouts, uid, role) =>
  payouts.some((p) => p.voided !== true && text(p.user_id) === uid && (!text(p.role) || text(p.role) === role));

/** Money paid to this person for the month, from the payouts that were not voided. */
const paidTo = (payouts, uid, role) =>
  r2(payouts
    .filter((p) => p.voided !== true && text(p.user_id) === uid && (!text(p.role) || text(p.role) === role))
    .reduce((sum, p) => sum + num(p.amount_paid), 0));

/** An administrator payout that differs from what is due by more than a cent is a mismatch. */
const PAYOUT_TOLERANCE = 0.01;

/**
 * Administrators with a live payout that is not the amount due now. Only
 * meaningful once pay is final (before that the due amount is an estimate).
 * A paid-but-paused administrator counts: they are due nothing.
 */
const adminPayoutMismatches = (admins, payouts) =>
  admins.filter((a) => {
    if (!hasPayout(payouts, a.uid, 'admin')) return false;
    const due = a.paused ? 0 : a.total;
    return Math.abs(paidTo(payouts, a.uid, 'admin') - due) > PAYOUT_TOLERANCE + 1e-9;
  }).length;

/**
 * The month's numbers, without the figures that are not tied to a month
 * (open credit, overdue invoices, first invoices this week).
 *
 * @param {object} input
 * @param {string} input.month yyyy-MM
 * @param {Date} input.now
 * @param {Array} input.invoices invoices that may belong to the month (others are ignored)
 * @param {Array} input.audits teacher_audits for the month
 * @param {Array} input.expenses finance_expenses rows
 * @param {Array} input.recurringCosts finance_recurring_costs started by the month
 * @param {Array} input.confirmations finance_recurring_confirmations for the month
 * @param {Array} input.payouts staff_payouts for the month
 * @param {Array} input.adminTerms admin_pay_terms documents
 */
const buildMonthSummary = ({
  month, now, invoices = [], audits = [], expenses = [], recurringCosts = [],
  confirmations = [], payouts = [], adminTerms = [],
}) => {
  const inv = invoiceTotals(invoices, month);
  const teachers = teacherRows(audits);
  const teacherPay = r2(teachers.reduce((sum, t) => sum + t.net, 0));
  const penalties = r2(teachers.reduce((sum, t) => sum + t.penalties, 0));
  const teacherPayFinal = teachers.every((t) => t.final);

  const costs = costTotals({month, expenses, recurringCosts, confirmations, now});
  const transferFees = r2(costs.transfer_fees + payoutTransferFees(payouts));

  const otherCosts = r2(teacherPay + costs.software + costs.marketing + transferFees + costs.other);
  // The fee for sending an administrator their own pay is still Alluwal's
  // expense, but it does not lower the profit share: otherwise paying (or
  // voiding) one administrator would move the others' amounts by cents.
  const adminPayoutFees = r2(payouts
    .filter((p) => p.voided !== true && text(p.role) === 'admin')
    .reduce((sum, p) => sum + num(p.transfer_fee), 0));
  const adminBase = r2(Math.max(0, inv.billed - (otherCosts - adminPayoutFees)));
  const admins = adminRows(adminTerms, month, adminBase);
  const adminTotal = r2(admins.reduce((sum, a) => sum + a.total, 0));

  const expensesTotal = r2(otherCosts + adminTotal);
  const ended = monthEnded(month, now);
  const final = ended && costs.recurring_pending === 0 && teacherPayFinal;

  const unpaidTeachers = teachers.filter((t) => t.final && t.net > 0 && !hasPayout(payouts, t.uid, 'teacher')).length;
  const unpaidAdmins = final
    ? admins.filter((a) => !a.paused && a.total > 0 && !hasPayout(payouts, a.uid, 'admin')).length
    : 0;

  return {
    month,
    status: 'open',
    final,
    billed: inv.billed,
    collected: inv.collected,
    owed: inv.owed,
    discounts: inv.discounts,
    penalties,
    teacher_pay: teacherPay,
    teacher_pay_final: teacherPayFinal,
    admin_pay: adminTotal,
    admin_base: adminBase,
    software: costs.software,
    marketing: costs.marketing,
    transfer_fees: transferFees,
    other: costs.other,
    expenses: expensesTotal,
    profit: r2(inv.billed - expensesTotal),
    invoice_count: inv.invoice_count,
    families_owing: inv.families_owing,
    recurring_pending: costs.recurring_pending,
    recurring_due: costs.recurring_due,
    unpaid_teachers: unpaidTeachers,
    unpaid_admins: unpaidAdmins,
    admin_payout_mismatches: final ? adminPayoutMismatches(admins, payouts) : 0,
    teachers,
    admins,
  };
};

/**
 * What stands in the way of closing `month`, in plain words. Empty when it can
 * be closed.
 */
const closeBlockers = ({month, now, summary, unapprovedAudits}) => {
  const out = [];
  if (!monthEnded(month, now)) out.push(`${monthLabel(month)} has not ended yet`);
  if (unapprovedAudits > 0) {
    out.push(`${unapprovedAudits} teacher ${unapprovedAudits === 1 ? 'audit is' : 'audits are'} not approved`);
  }
  if (summary.recurring_pending > 0) {
    out.push(`${summary.recurring_pending} recurring ${summary.recurring_pending === 1 ? 'cost is' : 'costs are'} not confirmed`);
  }
  const unpaid = summary.unpaid_teachers + summary.unpaid_admins;
  if (unpaid > 0) out.push(`${unpaid} ${unpaid === 1 ? 'person is' : 'people are'} not paid`);
  const mismatched = num(summary.admin_payout_mismatches);
  if (mismatched > 0) out.push(`Adjust ${mismatched} administrator ${mismatched === 1 ? 'payment' : 'payments'}`);
  return out;
};

module.exports = {
  FINAL_AUDIT_STATUSES,
  UNSETTLED_STATUSES,
  r2,
  num,
  text,
  toDate,
  isMonth,
  monthOf,
  addMonths,
  monthBounds,
  monthEnded,
  monthLabel,
  monthName,
  newYorkDay,
  invoiceMonth,
  invoiceBalance,
  invoiceDiscount,
  invoiceTotals,
  isCancelled,
  isOverdue,
  isFinalAudit,
  paidHours,
  teacherRows,
  auditPenalties,
  auditsBlockingClose,
  expenseMonth,
  costTotals,
  payoutTransferFees,
  termsInForce,
  pauseFor,
  adminPay,
  adminRows,
  adminPayoutMismatches,
  buildMonthSummary,
  closeBlockers,
};
