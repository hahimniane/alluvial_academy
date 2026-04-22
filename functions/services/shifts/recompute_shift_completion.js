/**
 * Read-only aggregation of worked time from timesheets (excluding rejected),
 * aligned with handleShiftEndTask overlap + shift-window capping.
 * Exported for unit tests and the timesheet_entries Firestore trigger.
 */

const toDate = (timestamp) => {
  if (timestamp == null) return null;
  return timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
};

const parseClockIn = (data, defaultDate) => {
  if (data.clock_in_timestamp) {
    return data.clock_in_timestamp.toDate();
  }
  const timeString = data.start_time;
  if (typeof timeString === 'string') {
    const match = timeString.trim().match(/(\d{1,2}):(\d{2})\s*(AM|PM)/i);
    if (match) {
      let hour = parseInt(match[1], 10);
      const minute = parseInt(match[2], 10);
      const meridiem = match[3].toUpperCase();
      if (meridiem === 'PM' && hour < 12) hour += 12;
      if (meridiem === 'AM' && hour === 12) hour = 0;
      const parsed = new Date(defaultDate);
      parsed.setHours(hour, minute, 0, 0);
      return parsed;
    }
  }
  return new Date(defaultDate);
};

const clockInSortKey = (data) => {
  if (data.clock_in_timestamp) return data.clock_in_timestamp.toDate().getTime();
  if (data.clock_in_time) return toDate(data.clock_in_time).getTime();
  return 0;
};

const isRejected = (data) => String(data.status || '').toLowerCase() === 'rejected';

/**
 * @param {object} opts
 * @param {Date} opts.shiftStart
 * @param {Date} opts.shiftEnd
 * @param {Array<{data: () => object}>} opts.timesheetDocs Firestore-like docs
 * @param {object} opts.shiftData raw shift document
 * @returns {{ workedMs: number, workedMinutes: number, scheduledMinutes: number, neverClockedIn: boolean }}
 */
function aggregateWorkedAndClockPresence({shiftStart, shiftEnd, timesheetDocs, shiftData}) {
  const startDate = shiftStart;
  const endDate = shiftEnd;
  const hasClockInOnShift = shiftData.clock_in_time != null;

  const nonRejected = timesheetDocs.filter((doc) => !isRejected(doc.data()));

  let workedMs = 0;

  if (nonRejected.length === 0 && hasClockInOnShift) {
    const clockInTime = toDate(shiftData.clock_in_time);
    const clockOutTime = shiftData.clock_out_time
      ? toDate(shiftData.clock_out_time)
      : endDate;
    if (clockInTime) {
      workedMs = Math.max(0, clockOutTime.getTime() - clockInTime.getTime());
    }
  }

  const sorted = [...nonRejected].sort(
    (a, b) => clockInSortKey(a.data()) - clockInSortKey(b.data()),
  );

  let lastEndTime = 0;
  for (const doc of sorted) {
    const data = doc.data();
    const clockIn = parseClockIn(data, startDate);
    let clockOut = data.clock_out_timestamp
      ? data.clock_out_timestamp.toDate()
      : data.clock_out_time
        ? toDate(data.clock_out_time)
        : null;
    if (!clockOut) {
      clockOut = endDate;
    }

    const startTimeMs = clockIn.getTime();
    const endTimeMs = clockOut.getTime();
    const effectiveStartTimeMs = Math.max(startTimeMs, startDate.getTime());
    const effectiveEndTimeMs = Math.min(endTimeMs, endDate.getTime());
    const effectiveStartTime = Math.max(effectiveStartTimeMs, lastEndTime);

    if (effectiveEndTimeMs > effectiveStartTime) {
      const durationMs = Math.max(0, effectiveEndTimeMs - effectiveStartTime);
      workedMs += durationMs;
      lastEndTime = effectiveEndTimeMs;
    }
  }

  const workedMinutes = Math.ceil(workedMs / 60000);
  const scheduledMinutes = Math.max(
    1,
    Math.round((endDate.getTime() - startDate.getTime()) / 60000),
  );

  const hasNonRejectedClockIn = nonRejected.some((doc) => {
    const d = doc.data();
    return !!(d.clock_in_timestamp || d.clock_in_time);
  });
  const neverClockedIn = !hasNonRejectedClockIn && !hasClockInOnShift;

  return {workedMs, workedMinutes, scheduledMinutes, neverClockedIn};
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
  const {workedMinutes, scheduledMinutes, neverClockedIn} = aggregateWorkedAndClockPresence({
    shiftStart,
    shiftEnd,
    timesheetDocs,
    shiftData,
  });

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
  parseClockIn,
  aggregateWorkedAndClockPresence,
  deriveCompletionStatusFromAggregate,
  mergeTimesheetsForShift,
  recomputeShiftCompletionForShiftId,
};
