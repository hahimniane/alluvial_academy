/**
 * Finance: expenses, recurring costs and family credits.
 *
 * Callables (all admin-only, gen2 onCall; see docs/finance/SPEC.md):
 *   addFinanceExpense        one-time expense, or a recurring cost that counts
 *                            as paid for the month it is added in
 *   deleteFinanceExpense     soft delete, reason required
 *   restoreFinanceExpense    undo a soft delete
 *   confirmRecurringCost     record what a recurring cost really was this month
 *   stopRecurringCost        end a recurring cost after a month; earlier months stay
 *   resolveFamilyCredit      refund or cancel an open family credit
 *   getFinanceDiscountTotals discounts given per month (for the Discounts page)
 *
 * Every mutation checks the closed-month lock with assertMonthOpen from
 * utils/finance_lock.js (owned by the overview branch). Clients never write
 * these collections; firestore.rules denies it.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const math = require('../utils/finance_expense_math');

const EXPENSES = 'finance_expenses';
const RECURRING_COSTS = 'finance_recurring_costs';
const CONFIRMATIONS = 'finance_recurring_confirmations';
const FAMILY_CREDITS = 'family_credits';
const INVOICES = 'invoices';

const record = (value) =>
  value && typeof value === 'object' && !Array.isArray(value) ? value : {};
const text = (value) => (typeof value === 'string' ? value.trim() : '');

const invalid = (message) => new functions.https.HttpsError('invalid-argument', message);
const notFound = (message) => new functions.https.HttpsError('not-found', message);
const blocked = (message) => new functions.https.HttpsError('failed-precondition', message);

const defaultDeps = () => ({
  db: admin.firestore(),
  FieldValue: admin.firestore.FieldValue,
  Timestamp: admin.firestore.Timestamp,
  verifyAdmin: verifyCallableCallerIsAdmin,
  // Loaded when first used so this file does not depend on the lock module
  // being present while the overview branch is still unmerged.
  assertMonthOpen: (db, month) => require('../utils/finance_lock').assertMonthOpen(db, month),
  now: () => new Date(),
});

/** Who is acting: uid plus a display name for "deleted by" lists. */
const loadActor = async (db, callerUid, email) => {
  let profile = null;
  try {
    const snap = await db.collection('users').doc(callerUid).get();
    profile = snap.exists ? snap.data() : null;
  } catch (_) {
    // The name is for display only; it must not block the action.
  }
  const data = record(profile);
  const full = `${text(data.first_name)} ${text(data.last_name)}`.trim();
  const name = full || text(data['e-mail']) || text(data.email) || email || 'Admin';
  return {uid: callerUid, name};
};

const startOfDayNoonUtc = (dateString) => new Date(`${dateString}T12:00:00.000Z`);

/* ------------------------------------------------------------ add -- */

const addFinanceExpense = async (request, deps = defaultDeps()) => {
  const {db, FieldValue, Timestamp} = deps;
  const {callerUid, effectiveAdminEmail} = await deps.verifyAdmin(request);

  const parsed = math.parseExpenseInput(request && request.data, math.dateStringOf(deps.now()));
  if (!parsed.ok) throw invalid(parsed.message);
  const value = parsed.value;

  await deps.assertMonthOpen(db, value.month);
  const actor = await loadActor(db, callerUid, effectiveAdminEmail);

  if (value.kind === 'one_time') {
    const ref = db.collection(EXPENSES).doc();
    await ref.set({
      month: value.month,
      kind: 'one_time',
      category: value.category,
      name: value.name,
      // `vendor` and `currency` keep the older summary readers working.
      vendor: value.name,
      currency: 'USD',
      amount: value.amount,
      expense_date: Timestamp.fromDate(startOfDayNoonUtc(value.date)),
      deleted: false,
      created_at: FieldValue.serverTimestamp(),
      created_by: actor.uid,
      created_by_name: actor.name,
    });
    return {id: ref.id};
  }

  // Recurring: refuse a second cost with the same name that is still running,
  // so a double click or a repeat add cannot bill the same thing twice.
  const wanted = value.name.toLowerCase();
  const existing = await db.collection(RECURRING_COSTS).get();
  const running = existing.docs.find((doc) => {
    const data = record(doc.data());
    if (text(data.name).toLowerCase() !== wanted) return false;
    return !math.isMonth(data.end_month) || data.end_month >= value.month;
  });
  if (running) throw blocked(`${value.name} is already a monthly cost.`);

  const costRef = db.collection(RECURRING_COSTS).doc();
  const confirmationRef = db.collection(CONFIRMATIONS).doc(`${value.month}_${costRef.id}`);
  const batch = db.batch();
  batch.set(costRef, {
    name: value.name,
    category: value.category,
    amount: value.amount,
    day_of_month: value.day_of_month,
    start_month: value.month,
    end_month: null,
    created_at: FieldValue.serverTimestamp(),
    created_by: actor.uid,
    created_by_name: actor.name,
  });
  batch.set(confirmationRef, {
    cost_id: costRef.id,
    month: value.month,
    amount: value.amount,
    source: 'created',
    confirmed_at: FieldValue.serverTimestamp(),
    confirmed_by: actor.uid,
    confirmed_by_name: actor.name,
  });
  await batch.commit();
  return {id: costRef.id};
};

/* ------------------------------------------------- delete / restore -- */

const expenseIdOf = (data) => {
  const id = text(record(data).id);
  if (!id || id.includes('/')) throw invalid('Choose an expense.');
  return id;
};

const deleteFinanceExpense = async (request, deps = defaultDeps()) => {
  const {db, FieldValue} = deps;
  const {callerUid, effectiveAdminEmail} = await deps.verifyAdmin(request);
  const id = expenseIdOf(request && request.data);
  const reason = math.parseReason(record(request.data).reason);
  if (!reason) throw invalid('Say why you are deleting it.');
  const actor = await loadActor(db, callerUid, effectiveAdminEmail);

  await db.runTransaction(async (tx) => {
    const ref = db.collection(EXPENSES).doc(id);
    const snap = await tx.get(ref);
    if (!snap.exists) throw notFound('This expense no longer exists.');
    const data = snap.data() || {};
    if (data.deleted === true) throw blocked('This expense is already deleted.');
    const month = math.expenseMonth(data);
    if (!month) throw blocked('This expense has no date, so its month cannot be checked.');
    await deps.assertMonthOpen(db, month);
    tx.update(ref, {
      deleted: true,
      deleted_at: FieldValue.serverTimestamp(),
      deleted_by: actor.uid,
      deleted_by_name: actor.name,
      delete_reason: reason,
    });
  });
  return {ok: true};
};

const restoreFinanceExpense = async (request, deps = defaultDeps()) => {
  const {db, FieldValue} = deps;
  const {callerUid, effectiveAdminEmail} = await deps.verifyAdmin(request);
  const id = expenseIdOf(request && request.data);
  const actor = await loadActor(db, callerUid, effectiveAdminEmail);

  await db.runTransaction(async (tx) => {
    const ref = db.collection(EXPENSES).doc(id);
    const snap = await tx.get(ref);
    if (!snap.exists) throw notFound('This expense no longer exists.');
    const data = snap.data() || {};
    if (data.deleted !== true) throw blocked('This expense is not deleted.');
    const month = math.expenseMonth(data);
    if (!month) throw blocked('This expense has no date, so its month cannot be checked.');
    await deps.assertMonthOpen(db, month);
    tx.update(ref, {
      deleted: false,
      restored_at: FieldValue.serverTimestamp(),
      restored_by: actor.uid,
      restored_by_name: actor.name,
    });
  });
  return {ok: true};
};

/* ------------------------------------------------ recurring costs -- */

const costIdOf = (data) => {
  const id = text(record(data).cost_id);
  if (!id || id.includes('/')) throw invalid('Choose a recurring cost.');
  return id;
};

const confirmRecurringCost = async (request, deps = defaultDeps()) => {
  const {db, FieldValue} = deps;
  const {callerUid, effectiveAdminEmail} = await deps.verifyAdmin(request);
  const data = record(request && request.data);
  const month = data.month;
  if (!math.isMonth(month)) throw invalid('Choose a month.');
  const costId = costIdOf(data);
  const amount = math.parseAmount(data.amount, {allowZero: true});
  if (amount === null) throw invalid('Enter the amount on the bill.');
  const source = data.source === undefined || data.source === null ? 'manual' : data.source;
  if (source !== 'manual' && source !== 'bank') throw invalid('The source is manual or bank.');
  const bankTransactionId = text(data.bank_transaction_id);
  const actor = await loadActor(db, callerUid, effectiveAdminEmail);

  await db.runTransaction(async (tx) => {
    const costRef = db.collection(RECURRING_COSTS).doc(costId);
    const confirmationRef = db.collection(CONFIRMATIONS).doc(`${month}_${costId}`);
    const costSnap = await tx.get(costRef);
    const confirmationSnap = await tx.get(confirmationRef);
    if (!costSnap.exists) throw notFound('This recurring cost no longer exists.');
    const cost = {id: costId, ...(costSnap.data() || {})};
    if (!math.recurringInMonth(cost, month)) {
      throw blocked(`${cost.name || 'This cost'} does not run in ${math.monthName(month)}.`);
    }
    await deps.assertMonthOpen(db, month);

    const previous = confirmationSnap.exists ? confirmationSnap.data() || {} : null;
    const history = previous
      ? [
          ...(Array.isArray(previous.history) ? previous.history : []),
          {
            amount: previous.amount,
            source: previous.source || null,
            confirmed_at: previous.confirmed_at || null,
            confirmed_by: previous.confirmed_by || null,
          },
        ]
      : [];
    tx.set(confirmationRef, {
      cost_id: costId,
      month,
      amount,
      source,
      ...(source === 'bank' && bankTransactionId ? {bank_transaction_id: bankTransactionId} : {}),
      confirmed_at: FieldValue.serverTimestamp(),
      confirmed_by: actor.uid,
      confirmed_by_name: actor.name,
      ...(history.length > 0 ? {history} : {}),
    });
  });
  return {ok: true};
};

const stopRecurringCost = async (request, deps = defaultDeps()) => {
  const {db, FieldValue} = deps;
  const {callerUid, effectiveAdminEmail} = await deps.verifyAdmin(request);
  const data = record(request && request.data);
  const costId = costIdOf(data);
  const lastMonth = data.last_month;
  if (!math.isMonth(lastMonth)) throw invalid('Choose the last month it is paid.');
  const actor = await loadActor(db, callerUid, effectiveAdminEmail);

  // A later month that is already confirmed would silently stop counting, so
  // the person picks a later last month instead.
  const confirmations = await db.collection(CONFIRMATIONS).where('cost_id', '==', costId).get();
  const later = confirmations.docs
    .map((doc) => record(doc.data()).month)
    .filter((month) => math.isMonth(month) && month > lastMonth)
    .sort();
  if (later.length > 0) {
    throw blocked(
      `${math.monthName(later[0])} is already confirmed. Stop it after ${math.monthName(later[later.length - 1])} or later.`
    );
  }

  await db.runTransaction(async (tx) => {
    const ref = db.collection(RECURRING_COSTS).doc(costId);
    const snap = await tx.get(ref);
    if (!snap.exists) throw notFound('This recurring cost no longer exists.');
    const cost = snap.data() || {};
    if (math.isMonth(cost.start_month) && lastMonth < cost.start_month) {
      throw blocked(`It starts in ${math.monthName(cost.start_month)}, so it cannot stop before that.`);
    }
    if (math.isMonth(cost.end_month) && cost.end_month <= lastMonth) {
      throw blocked(`It already stops after ${math.monthName(cost.end_month)}.`);
    }
    await deps.assertMonthOpen(db, lastMonth);
    tx.update(ref, {
      end_month: lastMonth,
      stopped_at: FieldValue.serverTimestamp(),
      stopped_by: actor.uid,
      stopped_by_name: actor.name,
    });
  });
  return {ok: true};
};

/* ------------------------------------------------------ credits -- */

const resolveFamilyCredit = async (request, deps = defaultDeps()) => {
  const {db, FieldValue} = deps;
  const {callerUid, effectiveAdminEmail} = await deps.verifyAdmin(request);
  const data = record(request && request.data);
  const creditId = text(data.credit_id);
  if (!creditId || creditId.includes('/')) throw invalid('Choose a credit.');
  const action = data.action;
  if (action !== 'refund' && action !== 'cancel') throw invalid('Choose refund or cancel.');
  const reason = math.parseReason(data.reason);
  if (!reason) throw invalid('Say why.');
  const actor = await loadActor(db, callerUid, effectiveAdminEmail);

  await db.runTransaction(async (tx) => {
    const ref = db.collection(FAMILY_CREDITS).doc(creditId);
    const snap = await tx.get(ref);
    if (!snap.exists) throw notFound('This credit no longer exists.');
    const credit = snap.data() || {};
    if (credit.status !== 'open') {
      throw blocked(
        credit.status === 'used'
          ? 'This credit is already used on an invoice.'
          : `This credit is already ${credit.status}.`
      );
    }
    // A refund or cancellation happens now, so it needs the current month open.
    await deps.assertMonthOpen(db, math.monthOfDate(deps.now()));
    tx.update(ref, {
      status: action === 'refund' ? 'refunded' : 'cancelled',
      closed_at: FieldValue.serverTimestamp(),
      closed_by: actor.uid,
      closed_by_name: actor.name,
      resolution_reason: reason,
      ...(action === 'refund' ? {refunded_amount: credit.amount} : {}),
    });
  });
  return {ok: true};
};

/* --------------------------------------------------- discounts -- */

/**
 * Discounts given per billing month for one year, read on the server so the
 * Discounts page does not pull every invoice into the browser.
 *
 * Accepts {through_month?: 'yyyy-MM'} (default: this month).
 * Returns {year, by_month: {'yyyy-MM': dollars}}.
 */
const getFinanceDiscountTotals = async (request, deps = defaultDeps()) => {
  const {db, Timestamp} = deps;
  await deps.verifyAdmin(request);
  const data = record(request && request.data);
  const through = math.isMonth(data.through_month) ? data.through_month : math.monthOfDate(deps.now());
  const year = through.slice(0, 4);

  // Start a month early: an invoice issued in December can bill January.
  const from = new Date(Date.UTC(Number(year) - 1, 11, 1));
  const snapshot = await db
    .collection(INVOICES)
    .where('issued_date', '>=', Timestamp.fromDate(from))
    .get();

  const byMonth = {};
  for (let m = 1; m <= 12; m++) byMonth[`${year}-${String(m).padStart(2, '0')}`] = 0;
  for (const doc of snapshot.docs) {
    const invoice = record(doc.data());
    const month = math.invoiceBillingMonth(invoice);
    if (!month || !(month in byMonth)) continue;
    byMonth[month] += math.invoiceDiscountTotal(invoice);
  }
  for (const key of Object.keys(byMonth)) byMonth[key] = math.round2(byMonth[key]);
  return {year: Number(year), by_month: byMonth};
};

module.exports = {
  addFinanceExpense,
  deleteFinanceExpense,
  restoreFinanceExpense,
  confirmRecurringCost,
  stopRecurringCost,
  resolveFamilyCredit,
  getFinanceDiscountTotals,
};
