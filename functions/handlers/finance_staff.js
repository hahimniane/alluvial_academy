/**
 * Finance: staff pay.
 *
 * Callables (admin-only, closed months locked) behind the Staff pay page:
 *   recordStaffPayouts   mark teachers / administrators as paid
 *   voidStaffPayout      take a payout back (the document stays, marked voided)
 *   setAdminPayTerms     fixed monthly pay + optional % for an administrator
 *   pauseAdminPay        stop an administrator's pay from a month
 *   resumeAdminPay       start it again
 * and a Firestore trigger, onAdminUserDeactivated, that pauses an
 * administrator's pay when their account is deactivated.
 *
 * Contract: docs/finance/SPEC.md. Collections:
 *   staff_payouts/{yyyy-MM}_{uid}   one document per person per month
 *   admin_pay_terms/{uid}           terms[] (history) and pauses[]
 *
 * Rules enforced here, not in the page:
 *   - only FINAL teacher pay can be paid (audit ceoApproved | completed);
 *   - a paused administrator is never paid for a paused month;
 *   - amount_paid may differ from amount_due (partial pay); a second payout for
 *     the same person and month adds to the first, history[] keeps every one;
 *   - a void keeps the document with voided:true and the reason.
 *
 * `getFinanceMonthSummary` and `utils/finance_lock` belong to the overview
 * branch; the lock is required lazily so this file loads without it.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onCall} = require('firebase-functions/v2/https');
const {onDocumentUpdated} = require('firebase-functions/v2/firestore');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const math = require('../utils/finance_staff_math');
const {assertMonthOpenInTransaction} = require('../utils/finance_lock');

const FINAL_AUDIT_STATUSES = ['ceoApproved', 'completed'];
const MAX_ENTRIES = 200;
const MAX_TEXT = 300;

const HttpsError = (code, message) => new functions.https.HttpsError(code, message);

const record = (value) =>
  value && typeof value === 'object' && !Array.isArray(value) ? value : {};
const text = (value, max = MAX_TEXT) =>
  (typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : '').slice(0, max);
const money = (n) => `$${(Number(n) || 0).toFixed(2)}`;
const finite = (value) => (typeof value === 'number' && Number.isFinite(value) ? value : null);

// One payout per person, month and role, so someone who is both a teacher and
// an administrator is paid (and voided) separately for each.
const docId = (month, uid, role) => `${month}_${uid}_${role}`;

const defaultAssertMonthOpen = (db, month) =>
  // eslint-disable-next-line global-require
  require('../utils/finance_lock').assertMonthOpen(db, month);

const defaultDeps = () => ({
  db: admin.firestore(),
  Timestamp: admin.firestore.Timestamp,
  verifyAdmin: verifyCallableCallerIsAdmin,
  assertMonthOpen: defaultAssertMonthOpen,
});

const fullName = (profile) => {
  const p = record(profile);
  return (
    `${text(p.first_name)} ${text(p.last_name)}`.trim() ||
    text(p.name) ||
    text(p['e-mail']) ||
    text(p.email)
  );
};

const actorFor = async (db, callerUid, email) => {
  let name = '';
  try {
    const snap = await db.collection('users').doc(callerUid).get();
    if (snap.exists) name = fullName(snap.data());
  } catch (_) {
    // The name is for the history line only; it must not block the action.
  }
  return {uid: callerUid, name: name || email || 'Admin'};
};

const requireMonth = (value, label = 'month') => {
  if (!math.isMonth(value)) {
    throw HttpsError('invalid-argument', `${label} must look like 2026-10.`);
  }
  return value;
};

const requireUid = (value) => {
  const uid = typeof value === 'string' ? value.trim() : '';
  if (!uid || uid.includes('/')) throw HttpsError('invalid-argument', 'uid is required.');
  return uid;
};

const requireReason = (value, message) => {
  const reason = text(value);
  if (!reason) throw HttpsError('invalid-argument', message);
  return reason;
};

// ---------------------------------------------------------------------------
// recordStaffPayouts
// ---------------------------------------------------------------------------

const parseEntry = (raw) => {
  const entry = record(raw);
  const uid = requireUid(entry.uid);
  const role = entry.role;
  if (role !== 'teacher' && role !== 'admin') {
    throw HttpsError('invalid-argument', 'role must be teacher or admin.');
  }
  const amount = finite(entry.amount_paid);
  if (amount === null || amount <= 0) {
    throw HttpsError('invalid-argument', 'Enter the amount paid (more than $0).');
  }
  const method = text(entry.method, 60);
  if (!method) throw HttpsError('invalid-argument', 'Say how it was sent.');
  if (!math.isDateString(entry.date_paid)) {
    throw HttpsError('invalid-argument', 'date_paid must look like 2026-10-03.');
  }
  let fee = 0;
  if (entry.transfer_fee !== undefined && entry.transfer_fee !== null && entry.transfer_fee !== '') {
    fee = finite(entry.transfer_fee);
    if (fee === null || fee < 0) {
      throw HttpsError('invalid-argument', 'The transfer fee cannot be negative.');
    }
  }
  let due = null;
  if (entry.amount_due !== undefined && entry.amount_due !== null) {
    due = finite(entry.amount_due);
    if (due === null || due < 0) throw HttpsError('invalid-argument', 'amount_due is not valid.');
  }
  return {
    uid,
    role,
    amount_paid: math.r2(amount),
    method,
    date_paid: entry.date_paid,
    transfer_fee: math.r2(fee),
    reference: text(entry.reference, 120),
    note: text(entry.note),
    amount_due_hint: due,
  };
};

/** What is owed, from the source of truth for this kind of staff. */
const resolveDue = async (tx, db, month, entry) => {
  if (entry.role === 'teacher') {
    // Audit ids are {uid}_{yyyy-MM}; payout ids are {yyyy-MM}_{uid}.
    const ref = db.collection('teacher_audits').doc(`${entry.uid}_${month}`);
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw HttpsError('failed-precondition', 'There is no audit for this teacher in that month.');
    }
    const audit = snap.data() || {};
    if (!FINAL_AUDIT_STATUSES.includes(audit.status)) {
      throw HttpsError(
        'failed-precondition',
        `${text(audit.teacherName) || 'This teacher'}'s pay is still an estimate. It can be paid once the audit is approved.`
      );
    }
    const net = finite(record(audit.paymentSummary).totalNetPayment);
    return {
      name: text(audit.teacherName) || '',
      amount_due: math.r2(net === null ? 0 : net),
    };
  }

  const ref = db.collection('admin_pay_terms').doc(entry.uid);
  const snap = await tx.get(ref);
  if (!snap.exists) {
    throw HttpsError('failed-precondition', 'This administrator has no pay set up yet.');
  }
  const terms = snap.data() || {};
  const name = text(terms.name);
  if (math.pauseForMonth(terms.pauses, month)) {
    throw HttpsError('failed-precondition', `${name || 'This administrator'}'s pay is paused for that month.`);
  }
  const term = math.termInForce(terms.terms, month);
  if (!term) {
    throw HttpsError('failed-precondition', `${name || 'This administrator'} has no pay terms for that month.`);
  }
  // The share needs the month's profit, which the overview computes; the page
  // sends the total it shows as amount_due, otherwise only the fixed part is due.
  const due = entry.amount_due_hint !== null ? entry.amount_due_hint : math.fixedPayFor(terms, month);
  return {name, amount_due: math.r2(due)};
};

const recordStaffPayouts = async (request, deps = defaultDeps()) => {
  const {db, Timestamp, verifyAdmin, assertMonthOpen} = deps;
  const {callerUid, effectiveAdminEmail} = await verifyAdmin(request);

  const payload = record(request && request.data);
  const month = requireMonth(payload.month);
  const rawEntries = Array.isArray(payload.entries) ? payload.entries : [];
  if (rawEntries.length === 0) throw HttpsError('invalid-argument', 'Choose who to mark as paid.');
  if (rawEntries.length > MAX_ENTRIES) throw HttpsError('invalid-argument', 'Too many people in one go.');
  const entries = rawEntries.map(parseEntry);
  const seen = new Set();
  for (const entry of entries) {
    const key = `${entry.uid}:${entry.role}`;
    if (seen.has(key)) throw HttpsError('invalid-argument', 'Each person can appear once per role.');
    seen.add(key);
  }

  await assertMonthOpen(db, month);
  const actor = await actorFor(db, callerUid, effectiveAdminEmail);
  const at = Timestamp.now();

  await db.runTransaction(async (tx) => {
    // Reads first (a Firestore transaction cannot read after it writes).
    // The month is read here too: a close that lands after the early check
    // conflicts with this transaction instead of being paid into.
    await assertMonthOpenInTransaction(tx, db, month);
    const prepared = [];
    for (const entry of entries) {
      const due = await resolveDue(tx, db, month, entry);
      const ref = db.collection('staff_payouts').doc(docId(month, entry.uid, entry.role));
      const existingSnap = await tx.get(ref);
      const existing = existingSnap.exists ? existingSnap.data() : null;
      prepared.push({entry, due, ref, existing});
    }
    // Nothing is written unless every person in the request is accepted.
    for (const {entry, due, existing} of prepared) {
      const refusal = math.paymentRefusal(existing, entry, due.amount_due);
      if (refusal) {
        const who = due.name || 'This person';
        throw HttpsError(
          'failed-precondition',
          refusal.kind === 'duplicate'
            ? `${who} already has this exact payment recorded (same amount, date, method and reference).`
            : `${who} has ${money(refusal.alreadyPaid)} recorded and ${money(due.amount_due)} due. ` +
                `Adding ${money(entry.amount_paid)} would pay more than is owed.`
        );
      }
    }
    for (const {entry, due, ref, existing} of prepared) {
      const next = math.applyPayment(existing, entry, {
        uid: entry.uid,
        role: entry.role,
        month,
        name: due.name,
        amount_due: due.amount_due,
        at,
        by: actor.uid,
        by_name: actor.name,
      });
      tx.set(ref, next);
    }
  });

  return {ok: true, count: entries.length};
};

// ---------------------------------------------------------------------------
// voidStaffPayout
// ---------------------------------------------------------------------------

const voidStaffPayout = async (request, deps = defaultDeps()) => {
  const {db, Timestamp, verifyAdmin, assertMonthOpen} = deps;
  const {callerUid, effectiveAdminEmail} = await verifyAdmin(request);

  const payload = record(request && request.data);
  const month = requireMonth(payload.month);
  const uid = requireUid(payload.uid);
  const reason = requireReason(payload.reason, 'Say why this payment is being voided.');
  const role = payload.role === undefined || payload.role === null ? null : payload.role;
  if (role !== null && role !== 'teacher' && role !== 'admin') {
    throw HttpsError('invalid-argument', 'role must be teacher or admin.');
  }

  await assertMonthOpen(db, month);
  const actor = await actorFor(db, callerUid, effectiveAdminEmail);
  const at = Timestamp.now();

  await db.runTransaction(async (tx) => {
    await assertMonthOpenInTransaction(tx, db, month);
    // The page names the role; without it the one live payout for this person is used.
    const roles = role ? [role] : ['teacher', 'admin'];
    const found = [];
    for (const r of roles) {
      const ref = db.collection('staff_payouts').doc(docId(month, uid, r));
      const snap = await tx.get(ref);
      if (snap.exists) found.push({ref, existing: snap.data() || {} });
    }
    const live = found.filter((f) => !f.existing.voided);
    if (found.length === 0) throw HttpsError('not-found', 'There is no payment to void.');
    if (live.length === 0) throw HttpsError('failed-precondition', 'This payment is already voided.');
    if (live.length > 1) {
      throw HttpsError('invalid-argument', 'Say whether it is the teacher or the administrator payment.');
    }
    const {ref, existing} = live[0];
    tx.set(ref, math.applyVoid(existing, reason, {at, by: actor.uid, by_name: actor.name}));
  });

  return {ok: true};
};

// ---------------------------------------------------------------------------
// Administrator pay terms and pauses
// ---------------------------------------------------------------------------

const setAdminPayTerms = async (request, deps = defaultDeps()) => {
  const {db, Timestamp, verifyAdmin, assertMonthOpen} = deps;
  const {callerUid, effectiveAdminEmail} = await verifyAdmin(request);

  const payload = record(request && request.data);
  const uid = requireUid(payload.uid);
  const fromMonth = requireMonth(payload.from_month, 'from_month');
  const fixed = finite(payload.fixed);
  if (fixed === null || fixed < 0) throw HttpsError('invalid-argument', 'Fixed pay must be $0 or more.');
  const pctRaw = payload.pct === undefined || payload.pct === null || payload.pct === '' ? 0 : finite(payload.pct);
  if (pctRaw === null || pctRaw < 0 || pctRaw > 100) {
    throw HttpsError('invalid-argument', 'The share must be between 0 and 100%.');
  }
  const note = text(payload.note);

  await assertMonthOpen(db, fromMonth);
  const actor = await actorFor(db, callerUid, effectiveAdminEmail);
  const at = Timestamp.now();

  await db.runTransaction(async (tx) => {
    const ref = db.collection('admin_pay_terms').doc(uid);
    const snap = await tx.get(ref);
    const userSnap = await tx.get(db.collection('users').doc(uid));
    const existing = snap.exists ? snap.data() || {} : null;

    if (!existing && !userSnap.exists) {
      throw HttpsError('not-found', 'That person has no account.');
    }
    const hasTerms = existing && Array.isArray(existing.terms) && existing.terms.length > 0;
    if (hasTerms && !note) throw HttpsError('invalid-argument', 'Say why the pay is changing.');

    const profile = userSnap.exists ? userSnap.data() || {} : {};
    const name = text(payload.name) || text(existing && existing.name) || fullName(profile);
    const roleTitle = text(payload.role_title) || text(existing && existing.role_title) || text(profile.title) || 'Administrator';

    const term = {
      from_month: fromMonth,
      fixed: math.r2(fixed),
      pct: Math.round(pctRaw * 100) / 100,
      note: note || 'Added',
      set_at: at,
      set_by: actor.uid,
      set_by_name: actor.name,
    };
    tx.set(ref, {
      ...(existing || {}),
      name,
      role_title: roleTitle,
      terms: math.upsertTerm(existing && existing.terms, term),
      pauses: Array.isArray(existing && existing.pauses) ? existing.pauses : [],
      updated_at: at,
    });
  });

  return {ok: true};
};

const pauseAdminPay = async (request, deps = defaultDeps()) => {
  const {db, Timestamp, verifyAdmin, assertMonthOpen} = deps;
  const {callerUid, effectiveAdminEmail} = await verifyAdmin(request);

  const payload = record(request && request.data);
  const uid = requireUid(payload.uid);
  const fromMonth = requireMonth(payload.from_month, 'from_month');
  const reason = requireReason(payload.reason, 'Say why the pay is paused.');

  await assertMonthOpen(db, fromMonth);
  const actor = await actorFor(db, callerUid, effectiveAdminEmail);
  const at = Timestamp.now();

  await db.runTransaction(async (tx) => {
    const ref = db.collection('admin_pay_terms').doc(uid);
    const snap = await tx.get(ref);
    if (!snap.exists) throw HttpsError('not-found', 'This administrator has no pay set up.');
    const existing = snap.data() || {};
    if (math.openPause(existing.pauses)) {
      throw HttpsError('failed-precondition', 'Their pay is already paused.');
    }
    const paid = await tx.get(db.collection('staff_payouts').doc(docId(fromMonth, uid, 'admin')));
    if (paid.exists && !(paid.data() || {}).voided) {
      throw HttpsError('failed-precondition', 'They are already paid for that month. Void the payment first.');
    }
    tx.set(ref, {
      ...existing,
      pauses: math.addPause(existing.pauses, {
        from_month: fromMonth,
        until_month: null,
        reason,
        auto: false,
        at,
        by: actor.uid,
        by_name: actor.name,
      }),
      updated_at: at,
    });
  });

  return {ok: true};
};

const resumeAdminPay = async (request, deps = defaultDeps()) => {
  const {db, Timestamp, verifyAdmin, assertMonthOpen} = deps;
  const {callerUid, effectiveAdminEmail} = await verifyAdmin(request);

  const payload = record(request && request.data);
  const uid = requireUid(payload.uid);
  const fromMonth = requireMonth(payload.from_month, 'from_month');
  const reason = requireReason(payload.reason, 'Say why the pay restarts.');

  await assertMonthOpen(db, fromMonth);
  const actor = await actorFor(db, callerUid, effectiveAdminEmail);
  const at = Timestamp.now();

  await db.runTransaction(async (tx) => {
    const ref = db.collection('admin_pay_terms').doc(uid);
    const snap = await tx.get(ref);
    if (!snap.exists) throw HttpsError('not-found', 'This administrator has no pay set up.');
    const existing = snap.data() || {};
    const open = math.openPause(existing.pauses);
    if (!open) throw HttpsError('failed-precondition', 'Their pay is not paused.');
    if (fromMonth < open.from_month) {
      throw HttpsError('failed-precondition', 'Pay cannot restart before it was paused.');
    }
    tx.set(ref, {
      ...existing,
      pauses: math.closeOpenPause(existing.pauses, fromMonth, {
        resumed_reason: reason,
        resumed_at: at,
        resumed_by: actor.uid,
        resumed_by_name: actor.name,
      }),
      updated_at: at,
    });
  });

  return {ok: true};
};

// ---------------------------------------------------------------------------
// Auto-pause when an administrator's account is deactivated
// ---------------------------------------------------------------------------

/**
 * `users/{uid}.is_active` flips to false -> pause that administrator's pay from
 * the current New York month. Reactivation never resumes pay: staff do that by
 * hand. Safe to run twice (it does nothing when a pause is already open).
 *
 * If the current month is already closed the pause starts next month, so a
 * closed month is never rewritten.
 */
const autoPauseOnDeactivation = async ({db, Timestamp, uid, before, after, now = new Date()}) => {
  const wasActive = record(before).is_active !== false;
  const isInactive = record(after).is_active === false;
  if (!(wasActive && isInactive)) return {paused: false, reason: 'not-a-deactivation'};

  const termsRef = db.collection('admin_pay_terms').doc(uid);
  const stamp = Timestamp.now();
  const deactivatedAt = math.toDate(record(after).deactivated_at) || now;
  const reason = `Account deactivated ${math.nyShortDate(deactivatedAt)}`;

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(termsRef);
    if (!snap.exists) return {paused: false, reason: 'no-admin-pay'};
    const existing = snap.data() || {};
    if (math.openPause(existing.pauses)) return {paused: false, reason: 'already-paused'};

    let fromMonth = math.nyMonthOf(now);
    const monthSnap = await tx.get(db.collection('finance_months').doc(fromMonth));
    if (monthSnap.exists && (monthSnap.data() || {}).status === 'closed') {
      fromMonth = math.addMonths(fromMonth, 1);
    }
    tx.set(termsRef, {
      ...existing,
      pauses: math.addPause(existing.pauses, {
        from_month: fromMonth,
        until_month: null,
        reason,
        auto: true,
        at: stamp,
        by: null,
        by_name: 'Automatic',
      }),
      updated_at: stamp,
    });
    return {paused: true, from_month: fromMonth, reason};
  });
};

const onAdminUserDeactivated = onDocumentUpdated(
  {document: 'users/{uid}', region: 'us-central1', memory: '256MiB'},
  async (event) => {
    const before = event.data && event.data.before ? event.data.before.data() : {};
    const after = event.data && event.data.after ? event.data.after.data() : {};
    // Most user updates are heartbeats; leave before touching Firestore.
    if (record(before).is_active === false || record(after).is_active !== false) return null;
    return autoPauseOnDeactivation({
      db: admin.firestore(),
      Timestamp: admin.firestore.Timestamp,
      uid: event.params.uid,
      before,
      after,
    });
  }
);

const callable = (fn) =>
  onCall({cors: true, invoker: 'public'}, (request) => fn(request));

module.exports = {
  // Pure / injectable (tests)
  recordStaffPayouts,
  voidStaffPayout,
  setAdminPayTerms,
  pauseAdminPay,
  resumeAdminPay,
  autoPauseOnDeactivation,
  // Deployed
  recordStaffPayoutsCallable: callable(recordStaffPayouts),
  voidStaffPayoutCallable: callable(voidStaffPayout),
  setAdminPayTermsCallable: callable(setAdminPayTerms),
  pauseAdminPayCallable: callable(pauseAdminPay),
  resumeAdminPayCallable: callable(resumeAdminPay),
  onAdminUserDeactivated,
};
