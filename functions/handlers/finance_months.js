/**
 * Closing and reopening a finance month (docs/finance/SPEC.md, money rule 13).
 *
 * A closed month keeps a snapshot of its numbers and is locked: every finance
 * callable that changes money calls `assertMonthOpen` (utils/finance_lock.js).
 * Only an admin can reopen it, with a reason, and the log keeps who did what.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const math = require('../utils/finance_math');
const {computeLiveMonth} = require('./finance_summary');

const MAX_REASON_LENGTH = 300;

/**
 * What staff have been paid for a month, as one string. Read before the close
 * blockers are worked out and again inside the closing transaction: if a
 * payout was recorded or voided in between, the blockers are stale and the
 * close is refused (the admin simply tries again).
 */
const payoutFingerprint = (docs) =>
  docs
    .map((d) => {
      const p = (d.data && d.data()) || {};
      return `${d.id}|${Number(p.amount_paid) || 0}|${p.voided ? 1 : 0}`;
    })
    .sort()
    .join(';');

const readPayoutFingerprint = async (reader, db, month) => {
  const query = db.collection('staff_payouts').where('month', '==', month);
  const snap = await (reader === db ? query.get() : reader.get(query));
  return payoutFingerprint(snap.docs);
};

const defaultDeps = () => ({
  db: admin.firestore(),
  Timestamp: admin.firestore.Timestamp,
  FieldValue: admin.firestore.FieldValue,
  verifyAdmin: verifyCallableCallerIsAdmin,
  now: () => new Date(),
});

const requireMonth = (data) => {
  const month = math.text(data && data.month);
  if (!math.isMonth(month)) {
    throw new functions.https.HttpsError('invalid-argument', 'A month (yyyy-MM) is required.');
  }
  return month;
};

/** Name for the history line; failing to read it never blocks the action. */
const actorName = async (db, uid, email) => {
  try {
    const snap = await db.collection('users').doc(uid).get();
    const data = snap.exists ? snap.data() || {} : {};
    const full = `${math.text(data.first_name)} ${math.text(data.last_name || data.lastName)}`.trim();
    return full || math.text(data['e-mail']) || math.text(data.email) || email || 'Admin';
  } catch (_) {
    return email || 'Admin';
  }
};

/**
 * Admin-only callable.
 *
 * Accepts: { month: 'yyyy-MM' }
 * Returns: { ok: true }
 * Refuses (failed-precondition) while the month has not ended, a teacher audit
 * is not approved, a recurring cost is not confirmed or someone is not paid;
 * the message lists what is left.
 */
const closeFinanceMonth = async (request, deps = defaultDeps()) => {
  const {db, Timestamp, FieldValue} = deps;
  const {callerUid, effectiveAdminEmail} = await deps.verifyAdmin(request);
  const month = requireMonth(request && request.data);
  const label = math.monthLabel(month);

  const ref = db.collection('finance_months').doc(month);
  const existing = await ref.get();
  if (existing.exists && (existing.data() || {}).status === 'closed') {
    throw new functions.https.HttpsError('failed-precondition', `${label} is already closed.`);
  }

  const payoutsBefore = await readPayoutFingerprint(db, db, month);
  const {summary, unapprovedAudits} = await computeLiveMonth(deps, month);
  const blockers = math.closeBlockers({month, now: deps.now(), summary, unapprovedAudits});
  if (blockers.length > 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `${label} cannot be closed yet: ${blockers.join('; ')}.`,
      {remaining: blockers}
    );
  }

  const name = await actorName(db, callerUid, effectiveAdminEmail);
  const at = Timestamp.now();
  const snapshot = {...summary};
  delete snapshot.status;

  await db.runTransaction(async (tx) => {
    const current = await tx.get(ref);
    if (current.exists && (current.data() || {}).status === 'closed') {
      throw new functions.https.HttpsError('failed-precondition', `${label} is already closed.`);
    }
    if ((await readPayoutFingerprint(tx, db, month)) !== payoutsBefore) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Staff payments for ${label} changed while it was being closed. Check them and try again.`
      );
    }
    tx.set(ref, {
      status: 'closed',
      closed_at: at,
      closed_by: callerUid,
      closed_by_name: name,
      snapshot: {...snapshot, snapshot_at: at},
      log: FieldValue.arrayUnion({action: 'closed', at, by: callerUid, by_name: name, reason: ''}),
    }, {merge: true});
  });
  return {ok: true};
};

/**
 * Admin-only callable.
 *
 * Accepts: { month: 'yyyy-MM', reason: string }  (the reason is required)
 * Returns: { ok: true }
 */
const reopenFinanceMonth = async (request, deps = defaultDeps()) => {
  const {db, Timestamp, FieldValue} = deps;
  const {callerUid, effectiveAdminEmail} = await deps.verifyAdmin(request);
  const data = (request && request.data) || {};
  const month = requireMonth(data);
  const label = math.monthLabel(month);
  const reason = math.text(data.reason).replace(/\s+/g, ' ').slice(0, MAX_REASON_LENGTH);
  if (!reason) {
    throw new functions.https.HttpsError('invalid-argument', 'Say why you are reopening the month.');
  }

  const name = await actorName(db, callerUid, effectiveAdminEmail);
  const at = Timestamp.now();
  const ref = db.collection('finance_months').doc(month);

  await db.runTransaction(async (tx) => {
    const current = await tx.get(ref);
    if (!current.exists || (current.data() || {}).status !== 'closed') {
      throw new functions.https.HttpsError('failed-precondition', `${label} is not closed.`);
    }
    tx.update(ref, {
      status: 'open',
      reopened_at: at,
      reopened_by: callerUid,
      reopened_by_name: name,
      snapshot: FieldValue.delete(),
      closed_at: FieldValue.delete(),
      closed_by: FieldValue.delete(),
      closed_by_name: FieldValue.delete(),
      log: FieldValue.arrayUnion({action: 'reopened', at, by: callerUid, by_name: name, reason}),
    });
  });
  return {ok: true};
};

module.exports = {closeFinanceMonth, reopenFinanceMonth, MAX_REASON_LENGTH};
