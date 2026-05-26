/**
 * Read-only aggregation of worked time from timesheets (excluding rejected),
 * aligned with handleShiftEndTask overlap + shift-window capping.
 * Exported for unit tests and the timesheet_entries Firestore trigger.
 */

const {
  computeSession,
  getScheduledHours,
  isRejected,
  toDate,
  toDouble,
  workedMinutesCeil,
} = require('../../utils/shiftSessionAggregator');

/**
 * Pay buckets from computeSession are dollars; convert to whole minutes at shift hourly_rate.
 * When rate is unknown, split [payable] worked minutes across buckets by dollar share (floors + remainder).
 * payable_minutes matches worked_minutes (ceil of worked hours) — single billing clock for the shift.
 */
function derivePayBucketMinutes(result, shift, workedMinutes) {
  const rate = toDouble(shift.hourly_rate, 0) || toDouble(shift.hourlyRate, 0);
  let payPaidMinutes = 0;
  let payApprovedMinutes = 0;
  let payPendingMinutes = 0;

  if (rate > 0) {
    payPaidMinutes = Math.ceil((toDouble(result.payPaid, 0) / rate) * 60);
    payApprovedMinutes = Math.ceil((toDouble(result.payApproved, 0) / rate) * 60);
    payPendingMinutes = Math.ceil((toDouble(result.payPending, 0) / rate) * 60);
    return {payPaidMinutes, payApprovedMinutes, payPendingMinutes};
  }

  const sumPay =
    toDouble(result.payPaid, 0) +
    toDouble(result.payApproved, 0) +
    toDouble(result.payPending, 0);
  if (sumPay <= 0 || workedMinutes <= 0) {
    return {payPaidMinutes: 0, payApprovedMinutes: 0, payPendingMinutes: 0};
  }

  payPaidMinutes = Math.floor(
    (workedMinutes * toDouble(result.payPaid, 0)) / sumPay,
  );
  payApprovedMinutes = Math.floor(
    (workedMinutes * toDouble(result.payApproved, 0)) / sumPay,
  );
  payPendingMinutes =
    workedMinutes - payPaidMinutes - payApprovedMinutes;

  return {payPaidMinutes, payApprovedMinutes, payPendingMinutes};
}

/**
 * @param {object} opts
 * @param {Date} opts.shiftStart
 * @param {Date} opts.shiftEnd
 * @param {Array<{data: () => object}>} opts.timesheetDocs Firestore-like docs
 * @param {object} opts.shiftData raw shift document
 * @returns {{ workedMs: number, workedMinutes: number, scheduledMinutes: number, neverClockedIn: boolean }}
 */
function timesheetHasValidClockPair(ts) {
  if (isRejected(ts)) return false;
  const ci = toDate(ts.clock_in_time ?? ts.clock_in_timestamp);
  const co = toDate(ts.clock_out_time ?? ts.clock_out_timestamp);
  return Boolean(ci && co && co > ci);
}

function aggregateWorkedAndClockPresence({shiftStart, shiftEnd, timesheetDocs, shiftData, formDocs = []}) {
  const shift = {...shiftData};
  if (shiftStart != null) shift.shift_start = shiftStart;
  if (shiftEnd != null) shift.shift_end = shiftEnd;

  let timesheets = timesheetDocs.map((d) => d.data());
  const hasDocPunch = timesheets.some(timesheetHasValidClockPair);
  if (
    !hasDocPunch &&
    shiftData.clock_in_time != null &&
    shiftData.clock_out_time != null
  ) {
    timesheets = [
      ...timesheets,
      {
        clock_in_timestamp: shiftData.clock_in_time,
        clock_out_timestamp: shiftData.clock_out_time,
        status: shiftData.status || 'approved',
      },
    ];
  }

  const forms = formDocs.map((d) => d.data());

  const result = computeSession(shift, timesheets, forms);
  const scheduledHours = getScheduledHours(shift);

  const workedMinutes = workedMinutesCeil(result);
  const scheduledMinutes = Math.max(1, Math.round(scheduledHours * 60));

  const hasClockInOnShift = shiftData.clock_in_time != null;
  const neverClockedIn =
    !hasDocPunch && !hasClockInOnShift && !result.hasForm;

  const {payPaidMinutes, payApprovedMinutes, payPendingMinutes} =
    derivePayBucketMinutes(result, shift, workedMinutes);

  return {
    workedMs: result.workedHours * 3600000,
    workedMinutes,
    scheduledMinutes,
    neverClockedIn,
    payPaidMinutes,
    payApprovedMinutes,
    payPendingMinutes,
    payableMinutes: workedMinutes,
  };
}

/**
 * @param {object} opts
 * @param {number} opts.workedMinutes
 * @param {number} opts.scheduledMinutes
 * @param {boolean} opts.neverClockedIn
 * @param {number} [opts.toleranceMinutes=1]
 */
function deriveCompletionStatusFromAggregate({
  workedMinutes,
  scheduledMinutes,
  neverClockedIn,
  toleranceMinutes = 1,
}) {
  let newStatus = 'partiallyCompleted';
  let completionState = 'partial';
  let missedReason = null;

  if (neverClockedIn || workedMinutes === 0) {
    newStatus = 'missed';
    completionState = 'none';
    missedReason = 'Teacher did not clock in before shift ended';
  } else if (workedMinutes + toleranceMinutes >= scheduledMinutes) {
    newStatus = 'fullyCompleted';
    completionState = 'full';
  }

  return {newStatus, completionState, missedReason};
}

async function mergeTimesheetsForShift(db, shiftId) {
  const [snap1, snap2] = await Promise.all([
    db.collection('timesheet_entries').where('shift_id', '==', shiftId).get(),
    db.collection('timesheet_entries').where('shiftId', '==', shiftId).get(),
  ]);
  const byId = new Map();
  snap1.docs.forEach((d) => byId.set(d.id, d));
  snap2.docs.forEach((d) => byId.set(d.id, d));
  return [...byId.values()];
}

/**
 * Updates teaching_shifts completion fields when the shift has ended (or is already in a terminal completion state).
 * Does not write timesheet rows. Does not send missed-shift notifications (shift-end task owns first miss).
 */
async function recomputeShiftCompletionForShiftId(db, shiftId) {
  const admin = require('firebase-admin');
  if (!shiftId) return {skipped: true, reason: 'no_shift_id'};

  const shiftRef = db.collection('teaching_shifts').doc(shiftId);
  const snapshot = await shiftRef.get();
  if (!snapshot.exists) {
    return {skipped: true, reason: 'shift_not_found'};
  }

  const shiftData = snapshot.data();
  const statusNorm = String(shiftData.status || '').toLowerCase();
  if (statusNorm === 'cancelled') {
    return {skipped: true, reason: 'cancelled'};
  }

  const shiftStart = toDate(shiftData.shift_start);
  const shiftEnd = toDate(shiftData.shift_end);
  if (!shiftStart || !shiftEnd || Number.isNaN(shiftStart.getTime()) || Number.isNaN(shiftEnd.getTime())) {
    return {skipped: true, reason: 'invalid_shift_times'};
  }

  const now = new Date();
  const shiftEnded = shiftEnd.getTime() <= now.getTime();
  const terminalCompletion = ['missed', 'partiallycompleted', 'fullycompleted'].includes(statusNorm);

  if (!shiftEnded && !terminalCompletion) {
    return {skipped: true, reason: 'shift_not_ended'};
  }

  const timesheetDocs = await mergeTimesheetsForShift(db, shiftId);
  const formDocsSnap = await db.collection('form_responses').where('shiftId', '==', shiftId).get();
  const formDocs = formDocsSnap.docs;

  const agg = aggregateWorkedAndClockPresence({
    shiftStart,
    shiftEnd,
    timesheetDocs,
    shiftData,
    formDocs,
  });
  const {
    workedMinutes,
    scheduledMinutes,
    neverClockedIn,
    payPaidMinutes,
    payApprovedMinutes,
    payPendingMinutes,
    payableMinutes,
  } = agg;

  const {newStatus, completionState, missedReason} = deriveCompletionStatusFromAggregate({
    workedMinutes,
    scheduledMinutes,
    neverClockedIn,
    toleranceMinutes: 1,
  });

  const updatePayload = {
    worked_minutes: workedMinutes,
    completion_state: completionState,
    last_modified: admin.firestore.FieldValue.serverTimestamp(),
  };

  const writePayBuckets = process.env.WRITE_SHIFT_PAY_BUCKET_MINUTES !== '0';
  if (writePayBuckets) {
    updatePayload.pay_paid_minutes = payPaidMinutes;
    updatePayload.pay_approved_minutes = payApprovedMinutes;
    updatePayload.pay_pending_minutes = payPendingMinutes;
    updatePayload.payable_minutes = payableMinutes;
  }

  if (missedReason) {
    updatePayload.missed_reason = missedReason;
    updatePayload.missed_at = admin.firestore.FieldValue.serverTimestamp();
  } else {
    updatePayload.missed_reason = admin.firestore.FieldValue.delete();
    updatePayload.missed_at = admin.firestore.FieldValue.delete();
  }

  if (statusNorm !== 'cancelled') {
    updatePayload.status = newStatus;
  }

  await shiftRef.update(updatePayload);

  return {
    skipped: false,
    shiftId,
    workedMinutes,
    scheduledMinutes,
    status: newStatus,
    completionState,
  };
}

module.exports = {
  aggregateWorkedAndClockPresence,
  deriveCompletionStatusFromAggregate,
  mergeTimesheetsForShift,
  recomputeShiftCompletionForShiftId,
};
