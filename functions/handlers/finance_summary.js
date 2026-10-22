/**
 * getFinanceMonthSummary: the single source of month numbers for every
 * finance page (docs/finance/SPEC.md).
 *
 * Reads are bounded: each collection is queried by month (or by an open
 * status), never read whole, so a month costs a few hundred document reads
 * however long the school has been billing. A closed month serves its stored
 * snapshot for the figures that closing locks and reads only invoices and
 * credit live, so the history chart is cheap.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const math = require('../utils/finance_math');

/** Figures a closed month keeps exactly as they were when it was closed. */
const LOCKED_KEYS = [
  'final', 'billed', 'discounts', 'penalties', 'teacher_pay', 'teacher_pay_final',
  'admin_pay', 'admin_base', 'software', 'marketing', 'transfer_fees', 'other',
  'expenses', 'profit', 'invoice_count', 'recurring_pending', 'recurring_due',
  'unpaid_teachers', 'unpaid_admins', 'teachers', 'admins',
];

// Short: the overview asks for many months at once, but an edit (a credit,
// a payment) should show on the next load.
const GLOBALS_TTL_MS = 5 * 1000;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

const docsOf = (snap) => snap.docs.map((d) => ({id: d.id, ...d.data()}));

const unionById = (...lists) => {
  const byId = new Map();
  for (const list of lists) for (const item of list) if (!byId.has(item.id)) byId.set(item.id, item);
  return [...byId.values()];
};

/** The overview asks for many months at once; the month-free figures are shared between those calls. */
const sharedGlobals = {at: 0, value: null, pending: null};

const defaultDeps = () => ({
  db: admin.firestore(),
  Timestamp: admin.firestore.Timestamp,
  verifyAdmin: verifyCallableCallerIsAdmin,
  now: () => new Date(),
  globalsCache: sharedGlobals,
});

/**
 * The audit fields finance reads. An audit document also carries every shift,
 * form and timesheet detail (~70 KB each); asking for these fields alone keeps
 * a month to a few KB instead of ~2 MB.
 */
const AUDIT_FIELDS = ['status', 'paymentSummary', 'totalHoursTaught', 'userId', 'oderId', 'teacherName', 'teacherEmail', 'yearMonth'];
const PENALTY_AUDIT_FIELDS = ['paymentSummary', 'userId', 'oderId', 'teacherName', 'yearMonth'];
const MAX_PENALTY_MONTHS = 24;

const requireMonth = (data) => {
  const month = math.text(data && data.month);
  if (!math.isMonth(month)) {
    throw new functions.https.HttpsError('invalid-argument', 'A month (yyyy-MM) is required.');
  }
  return month;
};

/** Invoices for a month: new ones carry `billing_month`, every one carries `period`. */
const loadInvoices = async (db, month) => {
  const col = db.collection('invoices');
  const [byBilling, byPeriod] = await Promise.all([
    col.where('billing_month', '==', month).get(),
    col.where('period', '==', month).get(),
  ]);
  return unionById(docsOf(byBilling), docsOf(byPeriod));
};

const loadMonthDocs = async (db, month, Timestamp) => {
  const {start, end} = math.monthBounds(month);
  const [invoices, audits, byMonth, byDate, recurringCosts, confirmations, payouts, terms] = await Promise.all([
    loadInvoices(db, month),
    db.collection('teacher_audits').where('yearMonth', '==', month).select(...AUDIT_FIELDS).get(),
    db.collection('finance_expenses').where('month', '==', month).get(),
    db.collection('finance_expenses')
      .where('expense_date', '>=', Timestamp.fromDate(start))
      .where('expense_date', '<', Timestamp.fromDate(end))
      .get(),
    db.collection('finance_recurring_costs').where('start_month', '<=', month).get(),
    db.collection('finance_recurring_confirmations').where('month', '==', month).get(),
    db.collection('staff_payouts').where('month', '==', month).get(),
    // One document per administrator: a handful, not a growing collection.
    db.collection('admin_pay_terms').limit(500).get(),
  ]);
  // Rows saved before `month` existed are placed by their date.
  const legacyExpenses = docsOf(byDate).filter((e) => !math.isMonth(math.text(e.month)));
  return {
    invoices,
    audits: docsOf(audits),
    expenses: unionById(docsOf(byMonth), legacyExpenses),
    recurringCosts: docsOf(recurringCosts),
    confirmations: docsOf(confirmations),
    payouts: docsOf(payouts),
    adminTerms: docsOf(terms).map((d) => ({...d, uid: d.uid || d.id})),
  };
};

/** Figures that are not tied to one month: open credit, overdue invoices, this week's first invoices. */
const loadGlobals = async (deps) => {
  const {db, Timestamp} = deps;
  const now = deps.now();
  const [credits, unsettled, recent] = await Promise.all([
    db.collection('family_credits').where('status', '==', 'open').get(),
    db.collection('invoices').where('status', 'in', math.UNSETTLED_STATUSES).get(),
    db.collection('invoices').where('issued_date', '>=', Timestamp.fromDate(new Date(now.getTime() - WEEK_MS))).get(),
  ]);
  const creditOpen = math.r2(docsOf(credits).reduce((sum, c) => sum + math.num(c.amount), 0));
  const overdue = docsOf(unsettled).filter((invoice) => math.isOverdue(invoice, now)).length;
  const firstInvoices = docsOf(recent).filter(
    (invoice) => math.text(invoice.kind) === 'first_month' && !math.isCancelled(invoice)
  ).length;
  return {credit_open: creditOpen, overdue_invoices: overdue, first_invoices_this_week: firstInvoices};
};

const cachedGlobals = async (deps) => {
  const cache = deps.globalsCache;
  if (!cache) return loadGlobals(deps);
  const now = deps.now().getTime();
  if (cache.value && now - cache.at < GLOBALS_TTL_MS) return cache.value;
  if (!cache.pending) {
    cache.pending = loadGlobals(deps)
      .then((value) => {
        cache.value = value;
        cache.at = deps.now().getTime();
        return value;
      })
      .finally(() => {
        cache.pending = null;
      });
  }
  return cache.pending;
};

const monthRecord = async (db, month) => {
  const snap = await db.collection('finance_months').doc(month).get();
  return snap.exists ? snap.data() || {} : {};
};

/** The month worked out from live data. `unapprovedAudits` feeds the close checklist. */
const computeLiveMonth = async (deps, month) => {
  const docs = await loadMonthDocs(deps.db, month, deps.Timestamp);
  const summary = math.buildMonthSummary({month, now: deps.now(), ...docs});
  return {summary, unapprovedAudits: math.auditsBlockingClose(docs.audits).length};
};

/**
 * The summary for one month, exactly the SPEC shape. A closed month returns
 * the figures stored when it was closed; money still arriving (collected, owed)
 * and the month-free figures stay live.
 */
const summaryForMonth = async (deps, month) => {
  const {db} = deps;
  const record = await monthRecord(db, month);
  const closed = record.status === 'closed';
  const snapshot = closed && record.snapshot && typeof record.snapshot === 'object' ? record.snapshot : null;

  let summary;
  if (snapshot) {
    const invoices = await loadInvoices(db, month);
    const totals = math.invoiceTotals(invoices, month);
    summary = {
      ...math.buildMonthSummary({month, now: deps.now(), invoices: []}),
      collected: totals.collected,
      owed: totals.owed,
      families_owing: totals.families_owing,
    };
    for (const key of LOCKED_KEYS) if (snapshot[key] !== undefined) summary[key] = snapshot[key];
  } else {
    summary = (await computeLiveMonth(deps, month)).summary;
  }
  summary.status = closed ? 'closed' : 'open';
  if (closed) summary.final = true;

  const globals = await cachedGlobals(deps);
  return {...summary, ...globals};
};

/**
 * Admin-only callable.
 *
 * Accepts: { month: 'yyyy-MM' }
 * Returns: the shape in docs/finance/SPEC.md.
 */
const getFinanceMonthSummary = async (request, deps = defaultDeps()) => {
  await deps.verifyAdmin(request);
  const month = requireMonth(request && request.data);
  return summaryForMonth(deps, month);
};

/** Timestamps (and anything else with toDate) become ISO strings so they survive the callable. */
const plain = (value) => {
  if (value && typeof value.toDate === 'function') return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(plain);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, plain(v)]));
  }
  return value;
};

/**
 * Admin-only callable for the Penalties page: the pay summary of every
 * teacher audit in `months`, without the rest of each audit.
 *
 * Accepts: { months: ['yyyy-MM', ...] } (at most 24)
 * Returns: { audits: [{ id, data }] }
 */
const getFinancePenaltyAudits = async (request, deps = defaultDeps()) => {
  await deps.verifyAdmin(request);
  const raw = request && request.data && request.data.months;
  const months = Array.isArray(raw) ? [...new Set(raw.map(math.text))] : [];
  if (!months.length || months.length > MAX_PENALTY_MONTHS || !months.every(math.isMonth)) {
    throw new functions.https.HttpsError('invalid-argument', `Between 1 and ${MAX_PENALTY_MONTHS} months (yyyy-MM) are required.`);
  }
  const chunks = [];
  for (let i = 0; i < months.length; i += 10) chunks.push(months.slice(i, i + 10));
  const snaps = await Promise.all(chunks.map((part) =>
    deps.db.collection('teacher_audits').where('yearMonth', 'in', part).select(...PENALTY_AUDIT_FIELDS).get()
  ));
  return {audits: snaps.flatMap((snap) => snap.docs.map((doc) => ({id: doc.id, data: plain(doc.data() || {})})))};
};

module.exports = {
  getFinanceMonthSummary,
  getFinancePenaltyAudits,
  AUDIT_FIELDS,
  summaryForMonth,
  computeLiveMonth,
  defaultDeps,
  LOCKED_KEYS,
  _requireMonth: requireMonth,
};
