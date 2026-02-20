const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onCall} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onDocumentDeleted} = require('firebase-functions/v2/firestore');
const {DateTime} = require('luxon');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || process.env.PROJECT_ID || '';
const TEMPLATE_COLLECTION = 'shift_templates';
const SHIFTS_COLLECTION = 'teaching_shifts';
const DEFAULT_MAX_DAYS_AHEAD = 10;

const _truthy = (value) =>
  value === true ||
  value === 1 ||
  value === '1' ||
  (typeof value === 'string' && value.toLowerCase() === 'true');

const _isAdminRole = (data) => {
  if (!data) return false;
  const role = (data.role || data.user_type || data.userType || '').toString().trim().toLowerCase();
  return (
    role === 'admin' ||
    role === 'super_admin' ||
    _truthy(data.is_admin) ||
    _truthy(data.isAdmin) ||
    _truthy(data.is_super_admin) ||
    _truthy(data.isSuperAdmin) ||
    _truthy(data.is_admin_teacher) ||
    _truthy(data.isAdminTeacher)
  );
};

const _isAdminUid = async (uid) => {
  if (!uid) return false;
  const doc = await admin.firestore().collection('users').doc(uid).get();
  if (!doc.exists) return false;
  return _isAdminRole(doc.data());
};

const _isTemplatesEnabledProject = () => {
  const id = (PROJECT_ID || '').toString().trim().toLowerCase();
  if (!id) return false;
  if (id === 'alluwal-dev' || id.includes('alluwal-dev') || id.endsWith('-dev') || id.includes('demo')) {
    return true;
  }
  if (id === 'alluwal-academy' || id.includes('alluwal-academy')) {
    return true;
  }
  return false;
};

const _assertTemplatesEnabledOrThrow = () => {
  if (_isTemplatesEnabledProject()) return;
  throw new functions.https.HttpsError(
    'failed-precondition',
    `Shift templates are not enabled for this project. (projectId=${PROJECT_ID || 'unknown'})`,
  );
};

const _normalizeTimezone = (timezone) => {
  const tz = (timezone || '').toString().trim();
  if (!tz) return 'UTC';
  const test = DateTime.now().setZone(tz);
  if (test.isValid) return tz;
  return 'UTC';
};

const _parseHHmm = (value) => {
  const raw = (value || '').toString().trim();
  const match = raw.match(/^(\d{1,2}):(\d{2})$/);
  if (!match) {
    throw new functions.https.HttpsError('invalid-argument', `Invalid time format (expected HH:mm): "${raw}"`);
  }
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (!Number.isInteger(hour) || !Number.isInteger(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw new functions.https.HttpsError('invalid-argument', `Invalid time value: "${raw}"`);
  }
  return {hour, minute};
};

const _toJsDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
};

const _toTimestamp = (value) => {
  const date = _toJsDate(value);
  if (!date) return null;
  return admin.firestore.Timestamp.fromDate(date);
};

const _toTimestampInTimezone = (value, timezone) => {
  if (!value) return null;

  // Firestore Timestamp (admin/sdk) or Timestamp-like
  if (typeof value.toDate === 'function') {
    const date = value.toDate();
    if (!date || Number.isNaN(date.getTime())) return null;
    return admin.firestore.Timestamp.fromDate(date);
  }

  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return null;
    return admin.firestore.Timestamp.fromDate(value);
  }

  if (typeof value === 'string') {
    const raw = value.trim();
    // Date-only values are treated as calendar days in the admin timezone.
    if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
      const dt = DateTime.fromISO(raw, {zone: timezone}).startOf('day');
      if (!dt.isValid) return null;
      return admin.firestore.Timestamp.fromDate(dt.toJSDate());
    }
  }

  return _toTimestamp(value);
};

const _dateKey = (dt) => dt.toISODate();

const _matchesRecurrence = ({day, recurrence, adminTimezone}) => {
  const type = (recurrence?.type || 'none').toString().trim().toLowerCase();
  if (type === 'none') return false;

  const excludedWeekdays = Array.isArray(recurrence?.excludedWeekdays) ? recurrence.excludedWeekdays : [];
  if (excludedWeekdays.includes(day.weekday)) return false;

  const excludedDates = Array.isArray(recurrence?.excludedDates) ? recurrence.excludedDates : [];
  if (excludedDates.length > 0) {
    const excludedKeys = new Set(
      excludedDates
        .map((d) => _toJsDate(d))
        .filter(Boolean)
        .map((d) => _dateKey(DateTime.fromJSDate(d, {zone: adminTimezone}).startOf('day'))),
    );
    if (excludedKeys.has(_dateKey(day))) return false;
  }

  switch (type) {
    case 'daily':
      return true;
    case 'weekly': {
      const selected = Array.isArray(recurrence?.selectedWeekdays) ? recurrence.selectedWeekdays : [];
      return selected.includes(day.weekday);
    }
    case 'monthly': {
      const selectedDays = Array.isArray(recurrence?.selectedMonthDays) ? recurrence.selectedMonthDays : [];
      return selectedDays.includes(day.day);
    }
    case 'yearly': {
      const selectedMonths = Array.isArray(recurrence?.selectedMonths) ? recurrence.selectedMonths : [];
      return selectedMonths.includes(day.month);
    }
    default:
      return false;
  }
};

const _hasConflictingShift = async ({teacherId, shiftStartUtc, shiftEndUtc}) => {
  const db = admin.firestore();

  const startUtc = DateTime.fromJSDate(shiftStartUtc, {zone: 'utc'});
  const startOfDay = startUtc.startOf('day');
  const rangeStart = startOfDay.minus({days: 1}).toJSDate();
  const rangeEnd = startOfDay.plus({days: 2}).toJSDate(); // end of day +1

  let docs = [];
  try {
    const snap = await db
      .collection(SHIFTS_COLLECTION)
      .where('teacher_id', '==', teacherId)
      .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(rangeStart))
      .where('shift_start', '<', admin.firestore.Timestamp.fromDate(rangeEnd))
      .get();
    docs = snap.docs;
  } catch (err) {
    const missingIndex =
      err?.code === 9 && typeof err?.message === 'string' && err.message.toLowerCase().includes('index');
    if (!missingIndex) throw err;
    const snap = await db.collection(SHIFTS_COLLECTION).where('teacher_id', '==', teacherId).get();
    docs = snap.docs;
  }

  for (const doc of docs) {
    const data = doc.data() || {};
    const existingStart = _toJsDate(data.shift_start);
    const existingEnd = _toJsDate(data.shift_end);
    if (!existingStart || !existingEnd) continue;

    const overlaps = shiftStartUtc < existingEnd && shiftEndUtc > existingStart;
    if (overlaps) return true;
  }
  return false;
};

const _buildGeneratedShiftId = ({templateId, shiftStartUtc}) => {
  const seconds = Math.floor(shiftStartUtc.toSeconds());
  return `tpl_${templateId}_${seconds}`;
};

const _buildGeneratedShiftData = ({templateId, shiftId, template, shiftStartUtc, shiftEndUtc}) => {
  const videoProvider = (template.video_provider || template.videoProvider || 'livekit').toString().trim().toLowerCase();

  return {
    id: shiftId,
    teacher_id: template.teacher_id,
    teacher_name: template.teacher_name,
    student_ids: template.student_ids || [],
    student_names: template.student_names || [],
    shift_start: admin.firestore.Timestamp.fromDate(shiftStartUtc.toJSDate()),
    shift_end: admin.firestore.Timestamp.fromDate(shiftEndUtc.toJSDate()),
    admin_timezone: template.admin_timezone || 'UTC',
    teacher_timezone: template.teacher_timezone || 'UTC',
    subject: template.subject,
    subject_id: template.subject_id || null,
    subject_display_name: template.subject_display_name || null,
    auto_generated_name: template.auto_generated_name || null,
    custom_name: template.custom_name || null,
    hourly_rate: template.hourly_rate ?? null,
    status: 'scheduled',
    created_by_admin_id: template.created_by_admin_id || null,
    created_at: admin.firestore.Timestamp.now(),
    last_modified: admin.firestore.Timestamp.now(),
    recurrence: template.recurrence || 'none',
    enhanced_recurrence: template.enhanced_recurrence || {type: 'none'},
    recurrence_end_date: template.recurrence_end_date || null,
    recurrence_settings: template.recurrence_settings || null,
    recurrence_series_id: template.recurrence_series_id || null,
    series_created_at: template.series_created_at || null,
    notes: template.notes || null,
    shift_category: template.category || template.shift_category || 'teaching',
    leader_role: template.leader_role || null,
    video_provider: videoProvider,
    livekit_room_name: videoProvider === 'livekit' ? `shift_${shiftId}` : null,
    generated_from_template: true,
    template_id: templateId,
  };
};

// Rolling window materialization (dev only):
// Generates upcoming shifts for templates, capped by max_days_ahead.
const _generateShiftsForTemplate = async ({templateId, template}) => {
  const db = admin.firestore();

  const adminTimezone = _normalizeTimezone(template.admin_timezone || 'UTC');
  const {hour: startHour, minute: startMinute} = _parseHHmm(template.start_time);
  const durationMinutes = Number(template.duration_minutes || 0);
  if (!Number.isFinite(durationMinutes) || durationMinutes <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'duration_minutes must be a positive number');
  }

  const nowAdminDay = DateTime.now().setZone(adminTimezone).startOf('day');
  const maxDaysAhead = Number(template.max_days_ahead || DEFAULT_MAX_DAYS_AHEAD);
  const horizonExclusive = nowAdminDay.plus({days: maxDaysAhead});

  const baseShiftStart = _toJsDate(template.base_shift_start);
  const baseStartDay = baseShiftStart
    ? DateTime.fromJSDate(baseShiftStart, {zone: adminTimezone}).startOf('day')
    : null;

  const recurrence = template.enhanced_recurrence || {type: 'none'};
  const endDateValue = recurrence.endDate || template.recurrence_end_date;
  const endDate = _toJsDate(endDateValue);
  const endDay = endDate ? DateTime.fromJSDate(endDate, {zone: adminTimezone}).startOf('day') : null;

  let created = 0;
  let skippedConflicts = 0;
  let skippedTeacherModified = 0;
  let skippedTerminalState = 0;
  let skippedNotStarted = 0;
  let skippedOutsideEndDate = 0;
  let skippedNoMatch = 0;

  let batch = db.batch();
  let pendingWrites = 0;

  for (let cursor = nowAdminDay; cursor < horizonExclusive; cursor = cursor.plus({days: 1})) {
    const day = cursor.startOf('day');

    if (baseStartDay && day < baseStartDay) {
      skippedNotStarted += 1;
      continue;
    }

    if (endDay && day > endDay) {
      skippedOutsideEndDate += 1;
      continue;
    }

    if (!_matchesRecurrence({day, recurrence, adminTimezone})) {
      skippedNoMatch += 1;
      continue;
    }

    // Per-day time slots: use slot for this weekday if present
    let dayStartHour = startHour;
    let dayStartMinute = startMinute;
    let dayDurationMinutes = durationMinutes;
    const weekdaySlots = recurrence.weekdayTimeSlots;
    if (Array.isArray(weekdaySlots) && weekdaySlots.length > 0) {
      const slot = weekdaySlots.find((s) => s && Number(s.weekday) === day.weekday);
      if (slot) {
        dayStartHour = Number(slot.start_hour);
        dayStartMinute = Number(slot.start_minute);
        const endH = Number(slot.end_hour);
        const endM = Number(slot.end_minute);
        dayDurationMinutes = (endH * 60 + endM) - (dayStartHour * 60 + dayStartMinute);
        if (dayDurationMinutes <= 0) dayDurationMinutes += 24 * 60; // cross-midnight
      }
    }

    const shiftStart = day.set({hour: dayStartHour, minute: dayStartMinute, second: 0, millisecond: 0});
    const shiftEnd = shiftStart.plus({minutes: dayDurationMinutes});
    const shiftStartUtc = shiftStart.toUTC();
    const shiftEndUtc = shiftEnd.toUTC();

    const hasConflict = await _hasConflictingShift({
      teacherId: template.teacher_id,
      shiftStartUtc: shiftStartUtc.toJSDate(),
      shiftEndUtc: shiftEndUtc.toJSDate(),
    });

    if (hasConflict) {
      skippedConflicts += 1;
      continue;
    }

    const generatedShiftId = _buildGeneratedShiftId({templateId, shiftStartUtc});
    const shiftRef = db.collection(SHIFTS_COLLECTION).doc(generatedShiftId);

    // Check if shift already exists and was modified by teacher - never overwrite teacher modifications
    const existingShift = await shiftRef.get();
    if (existingShift.exists) {
      const existingData = existingShift.data() || {};
      if (existingData.teacher_modified || existingData.teacher_modified_at) {
        // Skip regeneration for teacher-modified shifts to preserve their changes
        console.log(`[shift_templates] Skipping shift ${generatedShiftId}: teacher-modified`);
        skippedTeacherModified += 1;
        continue;
      }
      // Also skip if shift is already in a terminal or active state
      if (['completed', 'cancelled', 'active', 'missed'].includes(existingData.status)) {
        skippedTerminalState += 1;
        continue;
      }
    }

    const shiftData = _buildGeneratedShiftData({
      templateId,
      shiftId: generatedShiftId,
      template,
      shiftStartUtc,
      shiftEndUtc,
    });

    batch.set(shiftRef, shiftData, {merge: true});
    created += 1;
    pendingWrites += 1;

    if (pendingWrites >= 450) {
      await batch.commit();
      batch = db.batch();
      pendingWrites = 0;
    }
  }

  if (pendingWrites > 0) {
    await batch.commit();
  }

  if (created === 0 && skippedNoMatch === maxDaysAhead) {
    // Help distinguish misconfigured templates from legitimate "no shifts in window" scenarios.
    console.log(`[shift_templates] Template ${templateId}: no matching days in window.`);
  }

  await db
    .collection(TEMPLATE_COLLECTION)
    .doc(templateId)
    .set(
      {
        last_generated_date: nowAdminDay.toISODate(),
        last_modified: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

  return {created, skippedConflicts, skippedTeacherModified, skippedTerminalState, skippedNotStarted, skippedOutsideEndDate, skippedNoMatch};
};

// Remove legacy generated shifts so the dev UI doesn't show duplicates.
// Safe-guard: only deletes docs that were marked `generated_from_template: true`
// and are still in non-terminal states (scheduled/missed).
const _cleanupGeneratedShifts = async ({templateId = null} = {}) => {
  const db = admin.firestore();
  const snap = await db.collection(SHIFTS_COLLECTION).where('generated_from_template', '==', true).get();
  const docs = snap.docs;

  const candidates = docs.filter((doc) => {
    const data = doc.data() || {};
    if (templateId && (data.template_id || '').toString() !== templateId) return false;
    const status = (data.status || '').toString().trim().toLowerCase();
    if (status !== 'scheduled' && status !== 'missed') return false;
    return true;
  });

  if (candidates.length === 0) return {deleted: 0};

  let deleted = 0;
  for (let i = 0; i < candidates.length; i += 450) {
    const chunk = candidates.slice(i, i + 450);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += chunk.length;
  }

  return {deleted};
};

const createShiftTemplate = onCall(async (request) => {
  _assertTemplatesEnabledOrThrow();

  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const uid = request.auth.uid;
  const isAdmin = await _isAdminUid(uid);
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const data = request.data || {};
  const teacherId = (data.teacher_id || '').toString().trim();
  const baseShiftId = (data.base_shift_id || '').toString().trim();
  if (!teacherId || !baseShiftId) {
    throw new functions.https.HttpsError('invalid-argument', 'teacher_id and base_shift_id are required');
  }

  const adminTimezone = _normalizeTimezone(data.admin_timezone || 'UTC');
  const teacherTimezone = _normalizeTimezone(data.teacher_timezone || 'UTC');

  const baseShiftStart = _toTimestamp(data.base_shift_start);
  const baseShiftEnd = _toTimestamp(data.base_shift_end);
  if (!baseShiftStart || !baseShiftEnd) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'base_shift_start and base_shift_end are required (ISO timestamps)',
    );
  }

  const recurrenceInput = data.enhanced_recurrence || {};
  const templateRecurrence = {
    type: (recurrenceInput.type || 'none').toString().trim().toLowerCase(),
    endDate: _toTimestampInTimezone(recurrenceInput.endDate, adminTimezone),
    excludedDates: Array.isArray(recurrenceInput.excludedDates)
      ? recurrenceInput.excludedDates.map((d) => _toTimestampInTimezone(d, adminTimezone)).filter(Boolean)
      : [],
    excludedWeekdays: Array.isArray(recurrenceInput.excludedWeekdays)
      ? recurrenceInput.excludedWeekdays.map((n) => Number(n)).filter((n) => Number.isInteger(n))
      : [],
    selectedWeekdays: Array.isArray(recurrenceInput.selectedWeekdays)
      ? recurrenceInput.selectedWeekdays.map((n) => Number(n)).filter((n) => Number.isInteger(n))
      : [],
    selectedMonthDays: Array.isArray(recurrenceInput.selectedMonthDays)
      ? recurrenceInput.selectedMonthDays.map((n) => Number(n)).filter((n) => Number.isInteger(n))
      : [],
    selectedMonths: Array.isArray(recurrenceInput.selectedMonths)
      ? recurrenceInput.selectedMonths.map((n) => Number(n)).filter((n) => Number.isInteger(n))
      : [],
  };

  if (!['daily', 'weekly', 'monthly', 'yearly'].includes(templateRecurrence.type)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Unsupported recurrence type "${templateRecurrence.type}"`,
    );
  }
  if (templateRecurrence.type === 'weekly' && templateRecurrence.selectedWeekdays.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'weekly recurrence requires selectedWeekdays');
  }
  if (templateRecurrence.type === 'monthly' && templateRecurrence.selectedMonthDays.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'monthly recurrence requires selectedMonthDays');
  }
  if (templateRecurrence.type === 'yearly' && templateRecurrence.selectedMonths.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'yearly recurrence requires selectedMonths');
  }

  const templateId = baseShiftId;
  const templateRef = admin.firestore().collection(TEMPLATE_COLLECTION).doc(templateId);

  const templateDoc = {
    teacher_id: teacherId,
    teacher_name: (data.teacher_name || '').toString().trim(),
    student_ids: Array.isArray(data.student_ids) ? data.student_ids : [],
    student_names: Array.isArray(data.student_names) ? data.student_names : [],
    start_time: (data.start_time || '').toString().trim(),
    end_time: (data.end_time || '').toString().trim(),
    duration_minutes: Number(data.duration_minutes || 0),
    admin_timezone: adminTimezone,
    teacher_timezone: teacherTimezone,
    enhanced_recurrence: templateRecurrence,
    recurrence: (data.recurrence || 'none').toString().trim().toLowerCase(),
    recurrence_series_id: data.recurrence_series_id || null,
    series_created_at: _toTimestamp(data.series_created_at),
    recurrence_end_date:
      _toTimestampInTimezone(data.recurrence_end_date, adminTimezone) || templateRecurrence.endDate || null,
    recurrence_settings: data.recurrence_settings || null,
    subject: (data.subject || '').toString().trim(),
    subject_id: data.subject_id || null,
    subject_display_name: data.subject_display_name || null,
    hourly_rate: data.hourly_rate ?? null,
    auto_generated_name: data.auto_generated_name || null,
    custom_name: data.custom_name || null,
    notes: data.notes || null,
    category: (data.category || 'teaching').toString().trim(),
    leader_role: data.leader_role || null,
    video_provider: (data.video_provider || 'livekit').toString().trim().toLowerCase(),
    created_by_admin_id: data.created_by_admin_id || uid,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    last_modified: admin.firestore.FieldValue.serverTimestamp(),
    is_active: true,
    last_generated_date: null,
    max_days_ahead: Number(data.max_days_ahead || DEFAULT_MAX_DAYS_AHEAD),
    base_shift_id: baseShiftId,
    base_shift_start: baseShiftStart,
    base_shift_end: baseShiftEnd,
  };

  // Validate time fields early (gives clearer errors).
  _parseHHmm(templateDoc.start_time);
  _parseHHmm(templateDoc.end_time);
  if (!Number.isFinite(templateDoc.duration_minutes) || templateDoc.duration_minutes <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'duration_minutes must be a positive number');
  }

  await templateRef.set(templateDoc, {merge: true});

  // Best-effort cleanup of any legacy materialized shifts for this template.
  let deleted = 0;
  try {
    const result = await _cleanupGeneratedShifts({templateId});
    deleted = result.deleted;
  } catch (err) {
    console.warn(`[shift_templates] Failed to cleanup generated shifts for template ${templateId}:`, err);
  }

  let generated = null;
  try {
    generated = await _generateShiftsForTemplate({templateId, template: templateDoc});
  } catch (err) {
    console.warn(`[shift_templates] Failed to generate shifts for template ${templateId}:`, err);
  }

  return {templateId, cleanup_deleted: deleted, generated};
});

const generateShiftsForTemplateCallable = onCall(async (request) => {
  _assertTemplatesEnabledOrThrow();

  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const uid = request.auth.uid;
  const isAdmin = await _isAdminUid(uid);
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const templateId = (request.data?.templateId || request.data?.template_id || '').toString().trim();
  if (!templateId) {
    throw new functions.https.HttpsError('invalid-argument', 'templateId is required');
  }

  const doc = await admin.firestore().collection(TEMPLATE_COLLECTION).doc(templateId).get();
  if (!doc.exists) {
    throw new functions.https.HttpsError('not-found', 'Template not found');
  }

  const template = doc.data() || {};
  if (template.is_active === false) {
    return {templateId, cleanup_deleted: 0, skippedInactive: true};
  }

  const result = await _generateShiftsForTemplate({templateId, template});
  return {templateId, generated: result};
});

const generateDailyShifts = onSchedule({schedule: '0 0 * * *', timeZone: 'Etc/UTC'}, async () => {
  if (!_isTemplatesEnabledProject()) {
    console.log(
      `[shift_templates] Skipping daily generation on disabled project (${PROJECT_ID || 'unknown'}).`,
    );
    return;
  }

  const db = admin.firestore();

  const templatesSnap = await db
    .collection(TEMPLATE_COLLECTION)
    .where('is_active', '==', true)
    .get();

  if (templatesSnap.empty) {
    console.log('[shift_templates] No active templates found for daily generation.');
    return;
  }

  let created = 0;
  let skipped = 0;
  const teacherShiftCounts = new Map(); // teacherId -> { name, shiftsCreated }

  for (const doc of templatesSnap.docs) {
    const templateId = doc.id;
    const template = doc.data() || {};
    try {
      const result = await _generateShiftsForTemplate({templateId, template});
      const shiftsCreated = result.created || 0;
      created += shiftsCreated;
      skipped += (result.skippedConflicts || 0) + (result.skippedNoMatch || 0);

      // Track teacher if shifts were created
      if (shiftsCreated > 0) {
        const teacherId = template.teacher_id;
        const teacherName = template.teacher_name || 'Unknown Teacher';
        if (teacherShiftCounts.has(teacherId)) {
          const existing = teacherShiftCounts.get(teacherId);
          existing.shiftsCreated += shiftsCreated;
        } else {
          teacherShiftCounts.set(teacherId, {
            name: teacherName,
            shiftsCreated: shiftsCreated,
          });
        }
      }
    } catch (err) {
      console.error(`[shift_templates] Failed daily generation for ${templateId}:`, err);
    }
  }

  console.log(`[shift_templates] Daily generation done. created=${created} skipped=${skipped}`);

  // Send email report
  try {
    const {sendDailyShiftGenerationReport} = require('../services/email/senders');
    const runDate = DateTime.now().setZone('America/New_York').toFormat('cccc, LLLL d, yyyy');

    // Convert map to array sorted by shifts created
    const teachersAffected = Array.from(teacherShiftCounts.values())
      .sort((a, b) => b.shiftsCreated - a.shiftsCreated);

    await sendDailyShiftGenerationReport({
      totalTemplates: templatesSnap.size,
      totalShiftsCreated: created,
      totalSkipped: skipped,
      teachersAffected,
      runDate,
    });

    console.log('[shift_templates] Daily generation email report sent successfully.');
  } catch (emailErr) {
    console.error('[shift_templates] Failed to send email report:', emailErr);
  }
});

const updateShiftTemplate = onCall(async (request) => {
  _assertTemplatesEnabledOrThrow();

  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const uid = request.auth.uid;
  const isAdmin = await _isAdminUid(uid);
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const data = request.data || {};
  const templateId = (data.templateId || data.template_id || '').toString().trim();
  if (!templateId) {
    throw new functions.https.HttpsError('invalid-argument', 'templateId is required');
  }

  const templateRef = admin.firestore().collection(TEMPLATE_COLLECTION).doc(templateId);
  const templateSnap = await templateRef.get();
  if (!templateSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Template not found');
  }

  const updates = {};

  if (typeof data.start_time === 'string') {
    _parseHHmm(data.start_time);
    updates.start_time = data.start_time.trim();
  }
  if (typeof data.end_time === 'string') {
    _parseHHmm(data.end_time);
    updates.end_time = data.end_time.trim();
  }
  if (data.duration_minutes != null) {
    const duration = Number(data.duration_minutes);
    if (!Number.isFinite(duration) || duration <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'duration_minutes must be a positive number');
    }
    updates.duration_minutes = duration;
  }

  // Preserve existing timezones: do not overwrite from request so the template keeps
  // its original admin_timezone and teacher_timezone regardless of who modifies it.
  if (data.teacher_id) updates.teacher_id = String(data.teacher_id).trim();
  if (data.teacher_name) updates.teacher_name = String(data.teacher_name).trim();
  if (Array.isArray(data.student_ids)) updates.student_ids = data.student_ids;
  if (Array.isArray(data.student_names)) updates.student_names = data.student_names;
  if (data.subject) updates.subject = String(data.subject).trim();
  if (data.subject_id !== undefined) updates.subject_id = data.subject_id || null;
  if (data.subject_display_name !== undefined) updates.subject_display_name = data.subject_display_name || null;
  if (data.hourly_rate !== undefined) updates.hourly_rate = data.hourly_rate ?? null;
  if (data.auto_generated_name !== undefined) updates.auto_generated_name = data.auto_generated_name || null;
  if (data.custom_name !== undefined) updates.custom_name = data.custom_name || null;
  if (data.notes !== undefined) updates.notes = data.notes || null;
  if (data.category) updates.category = String(data.category).trim();
  if (data.leader_role !== undefined) updates.leader_role = data.leader_role || null;
  if (data.video_provider) updates.video_provider = String(data.video_provider).trim().toLowerCase();
  if (data.is_active !== undefined) {
    const active = Boolean(data.is_active);
    updates.is_active = active;
    if (!active) {
      updates.deactivated_at = admin.firestore.FieldValue.serverTimestamp();
      updates.deactivated_reason = data.deactivated_reason || 'manual';
    }
  }

  if (data.base_shift_start) updates.base_shift_start = _toTimestamp(data.base_shift_start);
  if (data.base_shift_end) updates.base_shift_end = _toTimestamp(data.base_shift_end);

  // Merge enhanced_recurrence so "Modify Days" can update selectedWeekdays and per-day times
  const inputRecurrence = data.enhanced_recurrence || null;
  if (inputRecurrence && typeof inputRecurrence === 'object') {
    const current = templateSnap.data() || {};
    const currentRecurrence = current.enhanced_recurrence || { type: 'weekly' };
    const merged = { ...currentRecurrence };
    if (Array.isArray(inputRecurrence.selectedWeekdays)) {
      merged.selectedWeekdays = inputRecurrence.selectedWeekdays.map((n) => Number(n)).filter((n) => Number.isInteger(n) && n >= 1 && n <= 7);
    }
    if (inputRecurrence.weekdayTimeSlots && Array.isArray(inputRecurrence.weekdayTimeSlots)) {
      merged.weekdayTimeSlots = inputRecurrence.weekdayTimeSlots.map((slot) => {
        if (!slot || typeof slot !== 'object') return null;
        const w = Number(slot.weekday);
        const sh = Number(slot.start_hour);
        const sm = Number(slot.start_minute);
        const eh = Number(slot.end_hour);
        const em = Number(slot.end_minute);
        if (!Number.isInteger(w) || w < 1 || w > 7) return null;
        return { weekday: w, start_hour: sh, start_minute: sm, end_hour: eh, end_minute: em };
      }).filter(Boolean);
    }
    if (typeof inputRecurrence.useDifferentTimesPerDay === 'boolean') {
      merged.useDifferentTimesPerDay = inputRecurrence.useDifferentTimesPerDay;
    }
    if (merged.selectedWeekdays && merged.selectedWeekdays.length > 0) {
      merged.type = 'weekly';
    }
    updates.enhanced_recurrence = merged;
  }

  updates.last_modified = admin.firestore.FieldValue.serverTimestamp();

  await templateRef.set(updates, {merge: true});

  // When recurrence or times change: remove future generated shifts and regenerate from updated template.
  // When template is deactivated: only remove future generated shifts (no regenerate).
  const recurrenceOrTimeChanged =
    updates.enhanced_recurrence != null ||
    updates.start_time != null ||
    updates.end_time != null;
  const deactivated = updates.is_active === false;

  if (recurrenceOrTimeChanged || deactivated) {
    let cleanupResult = { deleted: 0 };
    try {
      cleanupResult = await _cleanupGeneratedShifts({ templateId });
    } catch (err) {
      console.warn(`[shift_templates] Failed to cleanup generated shifts for template ${templateId}:`, err);
    }

    if (recurrenceOrTimeChanged && !deactivated) {
      const updatedSnap = await templateRef.get();
      const mergedTemplate = updatedSnap.exists ? updatedSnap.data() : null;
      if (mergedTemplate) {
        try {
          const genResult = await _generateShiftsForTemplate({ templateId, template: mergedTemplate });
          return {
            templateId,
            updated: true,
            cleanup_deleted: cleanupResult.deleted,
            generated: genResult,
          };
        } catch (err) {
          console.warn(`[shift_templates] Failed to regenerate shifts for template ${templateId}:`, err);
          return {
            templateId,
            updated: true,
            cleanup_deleted: cleanupResult.deleted,
            regenerate_error: String(err && err.message),
          };
        }
      }
    }

    return {
      templateId,
      updated: true,
      cleanup_deleted: cleanupResult.deleted,
    };
  }

  return { templateId, updated: true };
});

const excludeShiftTemplateDate = onCall(async (request) => {
  _assertTemplatesEnabledOrThrow();

  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const uid = request.auth.uid;
  const isAdmin = await _isAdminUid(uid);
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const data = request.data || {};
  const templateId = (data.templateId || data.template_id || '').toString().trim();
  if (!templateId) {
    throw new functions.https.HttpsError('invalid-argument', 'templateId is required');
  }

  const adminTimezone = _normalizeTimezone(data.admin_timezone || 'UTC');
  const excluded = _toTimestampInTimezone(data.date, adminTimezone);
  if (!excluded) {
    throw new functions.https.HttpsError('invalid-argument', 'date is required (YYYY-MM-DD)');
  }

  const templateRef = admin.firestore().collection(TEMPLATE_COLLECTION).doc(templateId);
  await templateRef.set(
    {
      'enhanced_recurrence.excludedDates': admin.firestore.FieldValue.arrayUnion(excluded),
      last_modified: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {templateId, excluded_date: excluded.toDate().toISOString().slice(0, 10)};
});

const onTeacherDeleted = onDocumentDeleted('users/{userId}', async (event) => {
  if (!_isTemplatesEnabledProject()) return;

  const deleted = event.data?.data ? event.data.data() : null;
  const userType = (deleted?.user_type || deleted?.role || '').toString().trim().toLowerCase();
  if (userType !== 'teacher') return;

  const teacherId = event.params.userId;
  const db = admin.firestore();

  let templatesSnap = null;
  try {
    templatesSnap = await db.collection(TEMPLATE_COLLECTION).where('teacher_id', '==', teacherId).get();
  } catch (err) {
    console.error(`[shift_templates] Failed to query templates for deleted teacher ${teacherId}:`, err);
    return;
  }

  if (templatesSnap.empty) return;

  let updated = 0;
  for (let i = 0; i < templatesSnap.docs.length; i += 450) {
    const chunk = templatesSnap.docs.slice(i, i + 450);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.set(
        doc.ref,
        {
          is_active: false,
          deactivated_at: admin.firestore.FieldValue.serverTimestamp(),
          deactivated_reason: 'teacher_deleted',
          last_modified: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    }
    await batch.commit();
    updated += chunk.length;
  }

  console.log(`[shift_templates] Deactivated ${updated} template(s) for deleted teacher ${teacherId}`);
});

module.exports = {
  generateDailyShifts,
  createShiftTemplate,
  generateShiftsForTemplateCallable,
  updateShiftTemplate,
  excludeShiftTemplateDate,
  onTeacherDeleted,
  _generateShiftsForTemplate,
  _cleanupGeneratedShifts,
  __test: {
    _buildGeneratedShiftId,
    _matchesRecurrence,
    _normalizeTimezone,
    _parseHHmm,
  },
};
