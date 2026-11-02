/**
 * Leader pay, decided in the leader audit (admin_audits) the way teacher pay
 * is decided in the teacher audit:
 *
 *   final pay = pay for the month + CEO bonus − CEO pay cut
 *
 * "Pay for the month" is entered by the CEO (leaderBasePayUsd); the leader's
 * leadership hours from their timesheets are shown next to it as a guide.
 * Approving locks the amount (leaderNetPayUsd) and Finance counts it as an
 * expense; approved pay can be marked paid on the Staff pay page.
 *
 * Callables (admin-only):
 *   getLeaderPayMonth  {month} → every leader of the month with hours and pay
 *                      from their leadership timesheets
 *   approveLeaderPay   {audit_id, approve} → approve or reopen one leader's pay
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {DateTime} = require('luxon');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const {shiftsInRange} = require('../utils/shifts_in_range');

const ZONE = 'America/New_York';
const HttpsError = (code, message) => new functions.https.HttpsError(code, message);
const str = (v) => (v == null ? '' : String(v)).trim();
const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);
const r2 = (n) => Math.round((Number(n) || 0) * 100) / 100;
const toDate = (v) => (v && typeof v.toDate === 'function' ? v.toDate() : v instanceof Date ? v : null);
const isLeadership = (category) => {
  const c = str(category).toLowerCase();
  return c !== '' && c !== 'teaching';
};

const monthBounds = (month) => {
  if (!/^\d{4}-\d{2}$/.test(str(month))) throw HttpsError('invalid-argument', 'A month (yyyy-MM) is required.');
  const start = DateTime.fromISO(`${month}-01`, {zone: ZONE}).startOf('month');
  return {start: start.toJSDate(), end: start.plus({months: 1}).toJSDate()};
};

/** Final pay from the three amounts the CEO enters. Never below zero. */
const leaderNetPay = ({base, bonus, paycut}) => r2(Math.max(0, num(base) + num(bonus) - num(paycut)));

/**
 * Leaders of a month: everyone with a leadership (non-teaching) class that
 * month, with the hours and pay of their leadership timesheets. Rejected
 * timesheets do not count.
 */
const leadersForMonth = async (db, month) => {
  const {start, end} = monthBounds(month);
  const leaders = new Map();
  const touch = (uid, name) => {
    if (!uid) return null;
    if (!leaders.has(uid)) leaders.set(uid, {uid, name: name || '', hours: 0, hours_pay: 0, timesheets: 0, classes: 0});
    const row = leaders.get(uid);
    if (!row.name && name) row.name = name;
    return row;
  };

  const shifts = await shiftsInRange(db, {start, end});
  for (const doc of shifts) {
    const s = doc.data() || {};
    if (!isLeadership(s.shift_category)) continue;
    const row = touch(str(s.teacher_id), str(s.teacher_name));
    if (row) row.classes += 1;
  }

  // Timesheets are written when a person clocks in; a day either side of the
  // month catches clock-ins near midnight, then the clock-in time decides.
  const snap = await db.collection('timesheet_entries')
    .where('created_at', '>=', new Date(start.getTime() - 86400000))
    .where('created_at', '<', new Date(end.getTime() + 86400000))
    .select('shift_category', 'status', 'payment_amount', 'total_pay', 'teacher_id', 'teacher_name',
      'clock_in_timestamp', 'clock_out_timestamp', 'effective_end_timestamp')
    .get();
  for (const doc of snap.docs) {
    const t = doc.data() || {};
    if (!isLeadership(t.shift_category) || str(t.status).toLowerCase() === 'rejected') continue;
    const clockIn = toDate(t.clock_in_timestamp);
    if (!clockIn || clockIn < start || clockIn >= end) continue;
    const row = touch(str(t.teacher_id), str(t.teacher_name));
    if (!row) continue;
    const out = toDate(t.effective_end_timestamp) || toDate(t.clock_out_timestamp);
    if (out && out > clockIn) row.hours += (out - clockIn) / 3600000;
    row.hours_pay += num(t.payment_amount ?? t.total_pay);
    row.timesheets += 1;
  }

  return [...leaders.values()]
    .map((l) => ({...l, hours: r2(l.hours), hours_pay: r2(l.hours_pay)}))
    .sort((a, b) => a.name.localeCompare(b.name));
};

const defaultDeps = () => ({
  db: admin.firestore(),
  FieldValue: admin.firestore.FieldValue,
  Timestamp: admin.firestore.Timestamp,
  verifyAdmin: verifyCallableCallerIsAdmin,
  assertMonthOpen: (db, month) => require('../utils/finance_lock').assertMonthOpen(db, month),
  now: () => new Date(),
});

const getLeaderPayMonth = async (request, deps = defaultDeps()) => {
  await deps.verifyAdmin(request);
  const month = str(request && request.data && request.data.month);
  return {month, leaders: await leadersForMonth(deps.db, month)};
};

const approveLeaderPay = async (request, deps = defaultDeps()) => {
  const {callerUid} = await deps.verifyAdmin(request);
  const data = (request && request.data) || {};
  const auditId = str(data.audit_id);
  const approve = data.approve !== false;
  if (!auditId) throw HttpsError('invalid-argument', 'audit_id is required.');
  const {db, FieldValue, Timestamp} = deps;
  const ref = db.collection('admin_audits').doc(auditId);
  const first = await ref.get();
  if (!first.exists) throw HttpsError('not-found', 'That leader audit does not exist.');
  const month = str((first.data() || {}).yearMonth);
  await deps.assertMonthOpen(db, month);
  const actorSnap = await db.collection('users').doc(callerUid).get();
  const actor = actorSnap.exists ? actorSnap.data() || {} : {};
  const actorName = [actor.first_name, actor.last_name].filter(Boolean).join(' ').trim() || str(actor.email) || callerUid;

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const a = snap.data() || {};
    const leaderId = str(a.adminId);
    const payoutRef = db.collection('staff_payouts').doc(`${month}_${leaderId}_leader`);
    const payout = await tx.get(payoutRef);
    const paid = payout.exists && (payout.data() || {}).voided !== true;

    if (!approve) {
      if (paid) throw HttpsError('failed-precondition', 'This pay was already marked paid in Finance. Void that payment first.');
      tx.update(ref, {
        leaderPayStatus: null,
        leaderNetPayUsd: FieldValue.delete(),
        leaderPayApprovedBy: FieldValue.delete(),
        leaderPayApprovedByName: FieldValue.delete(),
        leaderPayApprovedAt: FieldValue.delete(),
        lastUpdated: Timestamp.fromDate(deps.now()),
      });
      return {approved: false};
    }

    const base = num(a.leaderBasePayUsd);
    if (!(base > 0)) throw HttpsError('failed-precondition', 'Enter the pay for the month before approving.');
    const net = leaderNetPay({base, bonus: a.ceoBonusMonthlyUsd, paycut: a.ceoPaycutMonthlyUsd});
    tx.update(ref, {
      leaderPayStatus: 'approved',
      leaderNetPayUsd: net,
      leaderPayApprovedBy: callerUid,
      leaderPayApprovedByName: actorName,
      leaderPayApprovedAt: Timestamp.fromDate(deps.now()),
      lastUpdated: Timestamp.fromDate(deps.now()),
    });
    return {approved: true, net};
  });
};

module.exports = {getLeaderPayMonth, approveLeaderPay, leadersForMonth, leaderNetPay, __test: {isLeadership, monthBounds}};
