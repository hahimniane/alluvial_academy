/**
 * Admin review of a teacher's makeup request for a missed class.
 *
 * A teacher writes `reschedule_requests/{id}` (status `pending`) proposing a
 * new time for one of their missed classes. Approving it schedules exactly one
 * makeup class; declining it records the reason. Both notify the teacher.
 *
 * Everything about the makeup except its time comes from the ORIGINAL shift —
 * teacher, students, subject, hourly rate, video provider, timezones. The
 * request document is written by the teacher, so its copies of those fields
 * are display-only and never trusted here. The length is the original
 * class's length: a makeup can't be longer than the class it replaces.
 *
 * The makeup's document id is `makeup_<originalShiftId>`, so a missed class
 * gets at most one makeup however many requests are approved, and approving
 * the same request twice returns the class the first approval made.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const {shiftsInRange} = require('../utils/shifts_in_range');

const MAX_REASON_LENGTH = 500;
const DAY_MS = 24 * 3600e3;

const record = (value) =>
  value && typeof value === 'object' && !Array.isArray(value) ? value : {};
const text = (value) => (typeof value === 'string' ? value.trim() : '');
const list = (value) =>
  Array.isArray(value) ? value.filter((item) => typeof item === 'string') : [];

const toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === 'function') return value.toDate();
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (typeof value.seconds === 'number') return new Date(value.seconds * 1000);
  if (typeof value._seconds === 'number') return new Date(value._seconds * 1000);
  return null;
};

const httpsError = (code, message) => new functions.https.HttpsError(code, message);

/** Same rule as firestore.rules teachingShiftHasSubject. */
const teachingShiftHasSubject = (data) => {
  const category = data.shift_category;
  if (category != null && category !== 'teaching') return true;
  return typeof data.subject === 'string' && data.subject.trim().length > 0;
};

const makeupShiftIdFor = (originalShiftId) => `makeup_${originalShiftId}`;

/**
 * Builds the makeup class from the original shift. Only the window and the
 * provenance fields are new; the rest is the original class's.
 */
const buildMakeupShift = ({
  shiftId,
  original,
  requestId,
  originalShiftId,
  start,
  end,
  notes,
  actor,
  Timestamp,
  FieldValue,
}) => {
  const category = text(original.shift_category) || 'teaching';
  const videoProvider = text(original.video_provider) || 'zoom';
  const data = {
    id: shiftId,
    teacher_id: original.teacher_id,
    teacher_name: original.teacher_name || '',
    student_ids: list(original.student_ids),
    student_names: list(original.student_names),
    shift_start: Timestamp.fromDate(start),
    shift_end: Timestamp.fromDate(end),
    admin_timezone: original.admin_timezone || 'UTC',
    teacher_timezone: original.teacher_timezone || original.admin_timezone || 'UTC',
    auto_generated_name: original.auto_generated_name || '',
    custom_name: original.custom_name || null,
    hourly_rate: typeof original.hourly_rate === 'number' ? original.hourly_rate : 0,
    status: 'scheduled',
    shift_category: category,
    leader_role: original.leader_role || null,
    video_provider: videoProvider,
    recurrence: 'none',
    notes: notes || null,
    is_published: false,
    created_by_admin_id: actor.uid,
    created_by_name: actor.name,
    created_by_email: actor.email || '',
    created_at: FieldValue.serverTimestamp(),
    last_modified: FieldValue.serverTimestamp(),
    makeup_for_shift_id: originalShiftId,
    reschedule_request_id: requestId,
  };
  if (category === 'teaching') {
    data.subject = original.subject;
    data.subject_id = original.subject_id || null;
    data.subject_display_name = original.subject_display_name || null;
  }
  if (videoProvider === 'livekit') data.livekit_room_name = `shift_${shiftId}`;
  return data;
};

const loadTeacherShiftsNear = async (db, teacherId, start) => {
  const docs = await shiftsInRange(db, {
    start: new Date(start.getTime() - DAY_MS),
    end: new Date(start.getTime() + 2 * DAY_MS),
    teacherId,
  });
  return docs.map((d) => {
    const x = d.data() || {};
    return {
      id: d.id,
      startMs: toDate(x.shift_start)?.getTime() ?? NaN,
      endMs: toDate(x.shift_end)?.getTime() ?? NaN,
      status: x.status || '',
      name: x.custom_name || x.auto_generated_name || '',
    };
  });
};

const defaultDeps = () => {
  const shiftHandlers = require('./shifts');
  const {sendFCMNotificationToTeacher, formatDateInTimezone} = require('../services/notifications/fcm');
  const db = admin.firestore();
  return {
    db,
    FieldValue: admin.firestore.FieldValue,
    Timestamp: admin.firestore.Timestamp,
    verifyAdmin: verifyCallableCallerIsAdmin,
    now: () => new Date(),
    loadTeacherShifts: (teacherId, start) => loadTeacherShiftsNear(db, teacherId, start),
    findConflict: shiftHandlers.__test__.findClaimConflict,
    // Read-only: the same capacity/timing check the admin clients run before
    // creating a Zoom class. Routing itself is left to onTeachingShiftWritten.
    zoomGuardrail: (args) => require('./zoom').__test__._zoomHubCapacityGuardrailDecision(args),
    scheduleLifecycle: (shiftId, callerUid) =>
      shiftHandlers.scheduleShiftLifecycle.run({auth: {uid: callerUid}, data: {shiftId}}),
    notifyTeacher: sendFCMNotificationToTeacher,
    formatDate: formatDateInTimezone,
  };
};

const loadActor = async (db, callerUid, email) => {
  try {
    const snap = await db.collection('users').doc(callerUid).get();
    const data = snap.exists ? record(snap.data()) : {};
    const name = `${text(data.first_name)} ${text(data.last_name)}`.trim();
    return {
      uid: callerUid,
      name: name || text(data['e-mail']) || email || 'Admin',
      email: text(data['e-mail']) || text(data.email) || email || '',
    };
  } catch (_) {
    // The name is provenance only; it must not block the review.
    return {uid: callerUid, name: email || 'Admin', email: email || ''};
  }
};

const notify = async (deps, teacherId, notification, data) => {
  try {
    await deps.notifyTeacher(teacherId, notification, data);
  } catch (err) {
    console.warn('[reviewRescheduleRequest] teacher notification failed', err?.message || err);
  }
};

const approve = async ({deps, requestRef, requestId, request, payload, actor}) => {
  const {db, FieldValue, Timestamp} = deps;
  // A repeat approval returns the first one's class before any check that it
  // would now fail (its own makeup overlaps the requested time).
  if (request.status === 'approved' && request.created_shift_id) {
    return {success: true, status: 'approved', createdShiftId: request.created_shift_id, alreadyReviewed: true};
  }
  if (request.status !== 'pending') {
    throw httpsError('failed-precondition', `This request is already ${request.status || 'closed'}.`);
  }
  const originalShiftId = text(request.original_shift_id);
  if (!originalShiftId) {
    throw httpsError('failed-precondition', 'This request is not linked to a class.');
  }
  const originalSnap = await db.collection('teaching_shifts').doc(originalShiftId).get();
  if (!originalSnap.exists) {
    throw httpsError('not-found', 'The missed class no longer exists.');
  }
  const original = record(originalSnap.data());
  if (!original.teacher_id || original.teacher_id !== request.teacher_id) {
    throw httpsError('failed-precondition', 'This request was not made by the class\'s teacher.');
  }
  if (String(original.status || '').toLowerCase() !== 'missed') {
    throw httpsError('failed-precondition', 'Only a missed class can be made up.');
  }
  if (!teachingShiftHasSubject(original)) {
    throw httpsError('failed-precondition', 'The missed class has no subject. Set its subject first.');
  }

  const originalStart = toDate(original.shift_start);
  const originalEnd = toDate(original.shift_end);
  const durationMs = originalStart && originalEnd ? originalEnd.getTime() - originalStart.getTime() : 0;
  if (!(durationMs > 0)) {
    throw httpsError('failed-precondition', 'The missed class has no valid length.');
  }

  const customStart = payload.startTime != null ? toDate(payload.startTime) : null;
  if (payload.startTime != null && !customStart) {
    throw httpsError('invalid-argument', 'startTime is not a valid time.');
  }
  const start = customStart || toDate(request.proposed_start);
  if (!start) throw httpsError('failed-precondition', 'This request has no proposed time.');
  const end = new Date(start.getTime() + durationMs);
  if (end.getTime() <= deps.now().getTime()) {
    throw httpsError('failed-precondition', 'That time has already passed. Pick a later time.');
  }

  const shiftId = makeupShiftIdFor(originalShiftId);

  const mine = await deps.loadTeacherShifts(original.teacher_id, start);
  const conflict = deps.findConflict(start.getTime(), end.getTime(), mine, shiftId);
  if (conflict) {
    throw httpsError('failed-precondition',
      `${original.teacher_name || 'The teacher'} already has "${conflict.name}" at that time. Pick a different time.`);
  }

  const shiftData = buildMakeupShift({
    shiftId,
    original,
    requestId,
    originalShiftId,
    start,
    end,
    notes: text(request.notes),
    actor,
    Timestamp,
    FieldValue,
  });

  if (shiftData.video_provider === 'zoom') {
    const decision = await deps.zoomGuardrail({shiftId, shiftData});
    if (decision && decision.ok === false) {
      throw httpsError('failed-precondition', decision.message || 'Zoom has no room at that time. Pick a different time.');
    }
  }

  const shiftRef = db.collection('teaching_shifts').doc(shiftId);
  const outcome = await db.runTransaction(async (tx) => {
    const fresh = await tx.get(requestRef);
    const current = record(fresh.exists ? fresh.data() : null);
    if (current.status === 'approved' && current.created_shift_id) {
      return {created: false, createdShiftId: current.created_shift_id};
    }
    if (current.status !== 'pending') {
      throw httpsError('failed-precondition', `This request is already ${current.status || 'closed'}.`);
    }
    const existing = await tx.get(shiftRef);
    if (existing.exists) {
      throw httpsError('already-exists', 'This class already has a makeup scheduled.');
    }
    tx.set(shiftRef, shiftData);
    tx.update(requestRef, {
      status: 'approved',
      admin_id: actor.uid,
      reviewed_by_name: actor.name,
      reviewed_at: FieldValue.serverTimestamp(),
      created_shift_id: shiftId,
      approved_start: Timestamp.fromDate(start),
      approved_end: Timestamp.fromDate(end),
      updated_at: FieldValue.serverTimestamp(),
    });
    return {created: true, createdShiftId: shiftId};
  });

  if (!outcome.created) {
    return {success: true, status: 'approved', createdShiftId: outcome.createdShiftId, alreadyReviewed: true};
  }

  try {
    await deps.scheduleLifecycle(shiftId, actor.uid);
  } catch (err) {
    // The 6-hourly lifecycle scheduler picks the class up if this fails.
    console.warn(`[reviewRescheduleRequest] lifecycle scheduling failed for ${shiftId}`, err?.message || err);
  }

  const subject = original.subject_display_name || original.subject || 'Class';
  const when = deps.formatDate(start, original.teacher_timezone || 'UTC');
  await notify(deps, original.teacher_id, {
    title: 'Makeup class scheduled',
    body: `${subject} is scheduled for ${when}.`,
  }, {
    type: 'makeup_request',
    action: 'approved',
    requestId,
    shiftId,
    originalShiftId,
  });

  return {
    success: true,
    status: 'approved',
    createdShiftId: shiftId,
    shiftStart: start.toISOString(),
    shiftEnd: end.toISOString(),
  };
};

const decline = async ({deps, requestRef, requestId, request, payload, actor}) => {
  const {db, FieldValue} = deps;
  const reason = text(payload.reason).replace(/\s+/g, ' ').slice(0, MAX_REASON_LENGTH);

  const outcome = await db.runTransaction(async (tx) => {
    const fresh = await tx.get(requestRef);
    const current = record(fresh.exists ? fresh.data() : null);
    if (current.status === 'declined') return {changed: false};
    if (current.status !== 'pending') {
      throw httpsError('failed-precondition', `This request is already ${current.status || 'closed'}.`);
    }
    tx.update(requestRef, {
      status: 'declined',
      admin_id: actor.uid,
      reviewed_by_name: actor.name,
      reviewed_at: FieldValue.serverTimestamp(),
      decline_reason: reason,
      updated_at: FieldValue.serverTimestamp(),
    });
    return {changed: true};
  });

  if (!outcome.changed) return {success: true, status: 'declined', alreadyReviewed: true};

  await notify(deps, request.teacher_id, {
    title: 'Makeup request declined',
    body: reason || 'Open the missed class for details.',
  }, {
    type: 'makeup_request',
    action: 'declined',
    requestId,
    originalShiftId: text(request.original_shift_id),
  });

  return {success: true, status: 'declined'};
};

/**
 * Admin-only callable.
 *
 * Accepts: { requestId: string, decision: 'approve' | 'decline',
 *            startTime?: ISO string (approve: replaces the proposed start),
 *            reason?: string (decline) }
 * Returns: { success, status, createdShiftId?, shiftStart?, shiftEnd?, alreadyReviewed? }
 */
const reviewRescheduleRequest = async (request, deps = defaultDeps()) => {
  const {callerUid, effectiveAdminEmail} = await deps.verifyAdmin(request);
  const payload = record(request && request.data);
  const requestId = text(payload.requestId);
  const decisionValue = text(payload.decision).toLowerCase();
  if (!requestId) throw httpsError('invalid-argument', 'requestId is required');
  if (decisionValue !== 'approve' && decisionValue !== 'decline') {
    throw httpsError('invalid-argument', 'decision must be "approve" or "decline"');
  }

  const requestRef = deps.db.collection('reschedule_requests').doc(requestId);
  const requestSnap = await requestRef.get();
  if (!requestSnap.exists) throw httpsError('not-found', 'Request not found');
  const requestData = record(requestSnap.data());

  const actor = await loadActor(deps.db, callerUid, effectiveAdminEmail);
  const args = {deps, requestRef, requestId, request: requestData, payload, actor};
  const result = decisionValue === 'approve' ? await approve(args) : await decline(args);
  console.log(`[reviewRescheduleRequest] ${requestId} -> ${result.status} by ${callerUid}` +
    (result.createdShiftId ? ` (shift ${result.createdShiftId})` : ''));
  return result;
};

module.exports = {
  reviewRescheduleRequest,
  buildMakeupShift,
  makeupShiftIdFor,
  teachingShiftHasSubject,
};
