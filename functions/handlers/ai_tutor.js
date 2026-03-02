/**
 * AI Tutor Cloud Function Handlers
 *
 * Provides callable functions for connecting students to the LiveKit AI tutor agent.
 */

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { RoomServiceClient, AgentDispatchClient } = require('livekit-server-sdk');
const { DateTime } = require('luxon');
const { getLiveKitConfig, isLiveKitConfigured } = require('../services/livekit/config');
const { generateAccessToken } = require('../services/livekit/token');

// AI Tutor agent name (as registered in LiveKit Cloud)
const AI_TUTOR_AGENT_NAME = 'Alluwal';
const DEFAULT_AI_VOICE_PREFERENCE = 'blake';
const ALLOWED_AI_VOICE_PREFERENCES = new Set(['blake', 'jacqueline', 'robyn']);
const ALLOWED_AI_TTS_LANGUAGES = new Set(['en', 'ar']);
const DEFAULT_AI_TTS_LANGUAGE = ALLOWED_AI_TTS_LANGUAGES.has(
  (process.env.AI_TUTOR_TTS_LANGUAGE || '').trim().toLowerCase(),
)
  ? (process.env.AI_TUTOR_TTS_LANGUAGE || '').trim().toLowerCase()
  : 'en';
const DEFAULT_AI_TTS_PRONUNCIATION_DICT_ID =
  (process.env.AI_TUTOR_TTS_PRONUNCIATION_DICT_ID || '').trim();
const AI_VOICE_PREFERENCE_ALIASES = new Map([
  // Backward compatibility with previously stored values.
  ['alluwal', 'blake'],
  ['katie', 'jacqueline'],
  ['kiefer', 'blake'],
]);
const ALLOWED_AI_BACKGROUND_PREFERENCES = new Set([
  'none',
  'forest',
  'city',
  'office',
  'hold_music',
]);

const normalizeTimezone = (timezone) => {
  const tz = typeof timezone === 'string' ? timezone.trim() : '';
  if (!tz) return 'UTC';
  try {
    const test = DateTime.now().setZone(tz);
    return test.isValid ? tz : 'UTC';
  } catch (_) {
    return 'UTC';
  }
};

const parseRequestedTimezone = (timezone) => {
  const raw = typeof timezone === 'string' ? timezone.trim() : '';
  if (!raw) return null;
  try {
    const test = DateTime.now().setZone(raw);
    return test.isValid ? raw : null;
  } catch (_) {
    return null;
  }
};

const parseClientNowEpochMs = (value) => {
  if (value === null || value === undefined) return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return null;
  if (parsed <= 0) return null;
  return Math.round(parsed);
};

const normalizePronunciationDictId = (value) => {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (!raw) return '';
  // Cartesia dict IDs are short ASCII tokens; keep this strict to avoid passing junk.
  if (!/^[A-Za-z0-9_-]{4,128}$/.test(raw)) return '';
  return raw;
};

/**
 * Helper: Get user display name from Firestore
 */
const getUserDisplayName = async (uid) => {
  if (!uid) return 'Student';
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return 'Student';
    const data = userDoc.data();
    const firstName = data.first_name || data.firstName || '';
    const lastName = data.last_name || data.lastName || '';
    const fullName = [firstName, lastName].filter(Boolean).join(' ');
    return fullName || data['e-mail'] || data.email || 'Student';
  } catch (_) {
    return 'Student';
  }
};

/**
 * Helper: Get normalized user role
 */
const getUserRole = async (uid) => {
  if (!uid) return '';
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return '';
    const data = userDoc.data();
    const role = data.role || data.user_type || data.userType || '';
    return role.toString().trim().toLowerCase();
  } catch (_) {
    return '';
  }
};

/**
 * Helper: Get user's timezone
 */
const getUserTimezone = async (uid) => {
  if (!uid) return 'UTC';
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return 'UTC';
    const data = userDoc.data() || {};
    return normalizeTimezone(
      data.timezone || data.preferred_timezone || data.time_zone,
    );
  } catch (_) {
    return 'UTC';
  }
};

/**
 * Helper: Check if AI Tutor is enabled for user
 */
const checkAITutorEnabled = async (uid) => {
  if (!uid) return false;
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    const data = userDoc.data() || {};
    return data.ai_tutor_enabled === true;
  } catch (_) {
    return false;
  }
};

/**
 * Helper: Get student's live, recent, and upcoming classes.
 * Past classes are intentionally limited to today and yesterday only.
 */
const getStudentClasses = async (uid, studentTimezone = 'UTC', nowUtcOverride = null) => {
  if (!uid) return '';

  try {
    const db = admin.firestore();
    const resolvedStudentTimezone = normalizeTimezone(studentTimezone);
    const nowUtc = nowUtcOverride && nowUtcOverride.isValid
      ? nowUtcOverride.setZone('utc')
      : DateTime.utc();
    const now = nowUtc.toJSDate();
    const nowEpochMs = now.getTime();
    const nowLocal = nowUtc.setZone(resolvedStudentTimezone);
    const todayLocal = nowLocal.startOf('day');
    const yesterdayLocal = todayLocal.minus({ days: 1 });
    const windowStartTs = admin.firestore.Timestamp.fromDate(
      yesterdayLocal.toUTC().toJSDate(),
    );

    const teacherCache = {};
    const timeline = {
      live: [],
      completedToday: [],
      completedYesterday: [],
      upcoming: [],
    };
    const isMissingIndexError = (err) => {
      if (!err) return false;
      const code = err.code;
      const msg = (err.message || err.toString() || '').toLowerCase();
      return (
        code === 9 ||
        msg.includes('failed_precondition') ||
        msg.includes('requires an index')
      );
    };

    const toDate = (value) => {
      if (!value) return null;
      if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
      if (typeof value.toDate === 'function') {
        const dt = value.toDate();
        return dt instanceof Date && !Number.isNaN(dt.getTime()) ? dt : null;
      }
      if (typeof value === 'string' || typeof value === 'number') {
        const dt = new Date(value);
        return Number.isNaN(dt.getTime()) ? null : dt;
      }
      return null;
    };

    const normalizeSubject = (raw) => {
      const subject = (raw || 'Class').toString().trim();
      if (!subject) return 'Class';
      return subject
        .replace(/([a-z])([A-Z])/g, '$1 $2')
        .replace(/_/g, ' ')
        .replace(/\b\w/g, (c) => c.toUpperCase());
    };

    const formatHHmm = (value, sourceTimezone = resolvedStudentTimezone) => {
      const raw = (value || '').toString().trim();
      const match = raw.match(/^(\d{1,2}):(\d{2})$/);
      if (!match) return raw;
      const hours = Number(match[1]);
      const minutes = Number(match[2]);
      if (!Number.isInteger(hours) || !Number.isInteger(minutes)) return raw;
      const sourceTz = normalizeTimezone(sourceTimezone);
      const sourceDt = nowUtc.setZone(sourceTz).set({
        hour: hours,
        minute: minutes,
        second: 0,
        millisecond: 0,
      });
      if (!sourceDt.isValid) return raw;
      return sourceDt.setZone(resolvedStudentTimezone).toFormat('h:mm a');
    };

    const getTeacherName = async (teacherId, fallbackName = 'Teacher') => {
      if (!teacherId) return fallbackName;
      if (teacherCache[teacherId]) return teacherCache[teacherId];
      try {
        const teacherDoc = await db.collection('users').doc(teacherId).get();
        if (teacherDoc.exists) {
          const teacherData = teacherDoc.data() || {};
          const fullName = [teacherData.first_name, teacherData.last_name]
            .filter(Boolean)
            .join(' ')
            .trim();
          const teacherName = fullName || fallbackName;
          teacherCache[teacherId] = teacherName;
          return teacherName;
        }
      } catch (_) {}
      teacherCache[teacherId] = fallbackName;
      return fallbackName;
    };

    const buildShiftEntry = async (shift) => {
      const startTime = toDate(shift.shift_start || shift.start_time);
      const endTime = toDate(shift.shift_end || shift.end_time);
      if (!startTime) return null;

      const startDt = DateTime.fromJSDate(startTime, { zone: 'utc' })
        .setZone(resolvedStudentTimezone);
      if (!startDt.isValid) return null;
      const endDt = endTime
        ? DateTime.fromJSDate(endTime, { zone: 'utc' }).setZone(resolvedStudentTimezone)
        : null;

      const startEpochMs = startTime.getTime();
      const endEpochMs = endTime ? endTime.getTime() : null;
      const isLive = endEpochMs !== null &&
        startEpochMs <= nowEpochMs &&
        nowEpochMs < endEpochMs;
      const isPast = !isLive && startEpochMs <= nowEpochMs;
      const referenceDt = (endDt && endDt.isValid) ? endDt : startDt;
      const isToday = referenceDt.hasSame(nowLocal, 'day');
      const isYesterday = referenceDt.hasSame(yesterdayLocal, 'day');

      // Past classes older than yesterday are intentionally hidden.
      if (isPast && !isToday && !isYesterday) return null;

      const teacherName = await getTeacherName(
        shift.teacher_id,
        shift.teacher_name || 'Teacher',
      );
      const subject = normalizeSubject(
        shift.subject_display_name ||
          shift.subject_name ||
          shift.custom_name ||
          shift.auto_generated_name ||
          shift.subject,
      );
      const startLabel = startDt.toFormat('h:mm a');
      const endLabel = endDt ? endDt.toFormat('h:mm a') : 'end time not set';
      let line = `${subject} with ${teacherName} on ${startDt.toFormat('cccc LLL d')} from ${startLabel} to ${endLabel}`;

      let bucket = 'upcoming';
      if (isLive) {
        bucket = 'live';
        if (endDt && endDt.isValid) {
          const remainingMinutes = Math.max(
            0,
            Math.round(endDt.diff(nowLocal, 'minutes').minutes),
          );
          line = `${line} (live now, about ${remainingMinutes} minute${remainingMinutes === 1 ? '' : 's'} remaining)`;
        } else {
          line = `${line} (live now)`;
        }
      } else if (isPast && isToday) {
        bucket = 'completedToday';
      } else if (isPast && isYesterday) {
        bucket = 'completedYesterday';
      }

      return { bucket, line, startEpochMs };
    };

    let shiftDocs = [];

    // Primary lookup: include yesterday onward so AI can distinguish live/recent/upcoming.
    try {
      const shiftsSnapshot = await db.collection('teaching_shifts')
        .where('student_ids', 'array-contains', uid)
        .where('shift_start', '>=', windowStartTs)
        .orderBy('shift_start', 'asc')
        .limit(30)
        .get();
      shiftDocs = shiftsSnapshot.docs;
    } catch (err) {
      if (isMissingIndexError(err)) {
        console.warn('[AI Tutor] Missing index for shift_start query; continuing with fallbacks.');
      } else {
        throw err;
      }
    }

    // Legacy fallback for older docs that used start_time/end_time as timestamps.
    if (shiftDocs.length === 0) {
      try {
        const legacySnapshot = await db.collection('teaching_shifts')
          .where('student_ids', 'array-contains', uid)
          .where('start_time', '>=', windowStartTs)
          .orderBy('start_time', 'asc')
          .limit(30)
          .get();
        shiftDocs = legacySnapshot.docs;
      } catch (err) {
        if (isMissingIndexError(err)) {
          console.warn('[AI Tutor] Missing index for legacy start_time query; skipping legacy query.');
        } else {
          throw err;
        }
      }
    }

    // Final fallback if indexed queries cannot run: in-memory filter over student shifts.
    if (shiftDocs.length === 0) {
      try {
        const broadSnapshot = await db.collection('teaching_shifts')
          .where('student_ids', 'array-contains', uid)
          .limit(300)
          .get();
        const windowStartDate = yesterdayLocal.toUTC().toJSDate();
        shiftDocs = broadSnapshot.docs
          .filter((doc) => {
            const data = doc.data() || {};
            const start = toDate(data.shift_start || data.start_time);
            return !!start && start >= windowStartDate;
          })
          .sort((a, b) => {
            const aStart = toDate((a.data() || {}).shift_start || (a.data() || {}).start_time);
            const bStart = toDate((b.data() || {}).shift_start || (b.data() || {}).start_time);
            return (aStart?.getTime() || 0) - (bStart?.getTime() || 0);
          })
          .slice(0, 30);
      } catch (err) {
        if (!isMissingIndexError(err)) {
          throw err;
        }
      }
    }

    for (const doc of shiftDocs) {
      const shift = doc.data() || {};
      const entry = await buildShiftEntry(shift);
      if (!entry) continue;
      timeline[entry.bucket].push(entry);
    }

    const sortByStart = (entries) =>
      entries.sort((a, b) => a.startEpochMs - b.startEpochMs);
    sortByStart(timeline.live);
    sortByStart(timeline.completedToday);
    sortByStart(timeline.completedYesterday);
    sortByStart(timeline.upcoming);

    const sections = [];
    const sectionLine = (title, entries) => {
      if (!entries.length) return null;
      return `${title}: ${entries.map((entry) => entry.line).join('. ')}.`;
    };
    const liveSection = sectionLine('Live now', timeline.live);
    if (liveSection) sections.push(liveSection);
    const completedTodaySection = sectionLine('Completed today', timeline.completedToday);
    if (completedTodaySection) sections.push(completedTodaySection);
    const completedYesterdaySection = sectionLine('Completed yesterday', timeline.completedYesterday);
    if (completedYesterdaySection) sections.push(completedYesterdaySection);
    const upcomingSection = sectionLine('Upcoming', timeline.upcoming);
    if (upcomingSection) sections.push(upcomingSection);

    if (sections.length > 0) {
      return (
        `Class timeline (all times in your timezone: ${resolvedStudentTimezone}). `
        + `${sections.join(' ')} `
        + 'Past classes shown are limited to today and yesterday.'
      );
    }

    // Fallback: if shift instances are not generated yet, use active templates (upcoming pattern only).
    const templatesSnapshot = await db.collection('shift_templates')
      .where('student_ids', 'array-contains', uid)
      .limit(10)
      .get();

    const weekdayNames = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };

    const templateClasses = [];
    for (const doc of templatesSnapshot.docs) {
      const template = doc.data() || {};
      if (template.is_active === false) continue;

      const teacherName = await getTeacherName(
        template.teacher_id,
        template.teacher_name || 'Teacher',
      );
      const subject = normalizeSubject(
        template.subject_display_name ||
          template.subject_name ||
          template.custom_name ||
          template.auto_generated_name ||
          template.subject,
      );

      const recurrence = template.enhanced_recurrence || {};
      const templateTimezone = normalizeTimezone(
        template.teacher_timezone || template.admin_timezone || resolvedStudentTimezone,
      );
      const recurrenceType = (recurrence.type || '').toString().toLowerCase();
      const selectedWeekdays = Array.isArray(recurrence.selectedWeekdays)
        ? recurrence.selectedWeekdays
        : [];
      const weekdayText = [...new Set(selectedWeekdays
        .map((day) => {
          const sourceDay = Number(day);
          if (!Number.isInteger(sourceDay) || sourceDay < 1 || sourceDay > 7) {
            return null;
          }
          const weekStart = nowUtc.setZone(templateTimezone).startOf('week');
          let sourceDate = weekStart;
          for (let i = 0; i < 7; i++) {
            if (sourceDate.weekday === sourceDay) break;
            sourceDate = sourceDate.plus({ days: 1 });
          }
          const shifted = sourceDate
            .set({ hour: 12, minute: 0, second: 0, millisecond: 0 })
            .setZone(resolvedStudentTimezone);
          return weekdayNames[shifted.weekday] || null;
        })
        .filter(Boolean))]
        .join(', ');

      const startTime = formatHHmm(template.start_time, templateTimezone);
      const endTime = formatHHmm(template.end_time, templateTimezone);
      const timeRange = startTime && endTime
        ? `${startTime} to ${endTime}`
        : (startTime || endTime || 'time not set');

      let pattern = 'schedule pattern not set';
      if (recurrenceType === 'weekly' && weekdayText) {
        pattern = `every ${weekdayText}`;
      } else if (recurrenceType === 'daily') {
        pattern = 'every day';
      } else if (recurrenceType) {
        pattern = `${recurrenceType} schedule`;
      }

      templateClasses.push(`${subject} with ${teacherName} ${pattern} at ${timeRange}`);
    }

    return templateClasses.length > 0
      ? `Upcoming class template schedule (all times in your timezone: ${resolvedStudentTimezone}): ${templateClasses.join('. ')}.`
      : `No live, recent, or upcoming classes scheduled in your timezone (${resolvedStudentTimezone}). Past classes are limited to today and yesterday.`;
  } catch (err) {
    console.warn('[AI Tutor] Failed to fetch student classes:', err.message);
    return 'Unable to load class schedule.';
  }
};

/**
 * Helper: Get teacher live, recent, and upcoming classes.
 * Past classes are intentionally limited to today and yesterday only.
 */
const getTeacherClasses = async (uid, teacherTimezone = 'UTC', nowUtcOverride = null) => {
  if (!uid) return '';

  try {
    const db = admin.firestore();
    const resolvedTimezone = normalizeTimezone(teacherTimezone);
    const nowUtc = nowUtcOverride && nowUtcOverride.isValid
      ? nowUtcOverride.setZone('utc')
      : DateTime.utc();
    const now = nowUtc.toJSDate();
    const nowEpochMs = now.getTime();
    const nowLocal = nowUtc.setZone(resolvedTimezone);
    const todayLocal = nowLocal.startOf('day');
    const yesterdayLocal = todayLocal.minus({ days: 1 });
    const windowStartTs = admin.firestore.Timestamp.fromDate(
      yesterdayLocal.toUTC().toJSDate(),
    );

    const timeline = {
      live: [],
      completedToday: [],
      completedYesterday: [],
      upcoming: [],
    };
    const isMissingIndexError = (err) => {
      if (!err) return false;
      const code = err.code;
      const msg = (err.message || err.toString() || '').toLowerCase();
      return (
        code === 9 ||
        msg.includes('failed_precondition') ||
        msg.includes('requires an index')
      );
    };

    const toDate = (value) => {
      if (!value) return null;
      if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
      if (typeof value.toDate === 'function') {
        const dt = value.toDate();
        return dt instanceof Date && !Number.isNaN(dt.getTime()) ? dt : null;
      }
      if (typeof value === 'string' || typeof value === 'number') {
        const dt = new Date(value);
        return Number.isNaN(dt.getTime()) ? null : dt;
      }
      return null;
    };

    const normalizeSubject = (raw) => {
      const subject = (raw || 'Class').toString().trim();
      if (!subject) return 'Class';
      return subject
        .replace(/([a-z])([A-Z])/g, '$1 $2')
        .replace(/_/g, ' ')
        .replace(/\b\w/g, (c) => c.toUpperCase());
    };

    const buildShiftEntry = (shift) => {
      const startTime = toDate(shift.shift_start || shift.start_time);
      const endTime = toDate(shift.shift_end || shift.end_time);
      if (!startTime) return null;

      const startDt = DateTime.fromJSDate(startTime, { zone: 'utc' })
        .setZone(resolvedTimezone);
      if (!startDt.isValid) return null;
      const endDt = endTime
        ? DateTime.fromJSDate(endTime, { zone: 'utc' }).setZone(resolvedTimezone)
        : null;

      const startEpochMs = startTime.getTime();
      const endEpochMs = endTime ? endTime.getTime() : null;
      const isLive = endEpochMs !== null &&
        startEpochMs <= nowEpochMs &&
        nowEpochMs < endEpochMs;
      const isPast = !isLive && startEpochMs <= nowEpochMs;
      const referenceDt = (endDt && endDt.isValid) ? endDt : startDt;
      const isToday = referenceDt.hasSame(nowLocal, 'day');
      const isYesterday = referenceDt.hasSame(yesterdayLocal, 'day');

      // Past classes older than yesterday are intentionally hidden.
      if (isPast && !isToday && !isYesterday) return null;

      const subject = normalizeSubject(
        shift.subject_display_name ||
          shift.subject_name ||
          shift.custom_name ||
          shift.auto_generated_name ||
          shift.subject,
      );

      const studentNames = Array.isArray(shift.student_names)
        ? shift.student_names.filter(Boolean)
        : [];
      const studentLabel = studentNames.length === 0
        ? 'students not listed'
        : (studentNames.length <= 2
            ? studentNames.join(' and ')
            : `${studentNames.slice(0, 2).join(', ')} and ${studentNames.length - 2} more`);

      const startLabel = startDt.toFormat('h:mm a');
      const endLabel = endDt ? endDt.toFormat('h:mm a') : 'end time not set';
      let line = `${subject} with ${studentLabel} on ${startDt.toFormat('cccc LLL d')} from ${startLabel} to ${endLabel}`;

      let bucket = 'upcoming';
      if (isLive) {
        bucket = 'live';
        if (endDt && endDt.isValid) {
          const remainingMinutes = Math.max(
            0,
            Math.round(endDt.diff(nowLocal, 'minutes').minutes),
          );
          line = `${line} (live now, about ${remainingMinutes} minute${remainingMinutes === 1 ? '' : 's'} remaining)`;
        } else {
          line = `${line} (live now)`;
        }
      } else if (isPast && isToday) {
        bucket = 'completedToday';
      } else if (isPast && isYesterday) {
        bucket = 'completedYesterday';
      }

      return { bucket, line, startEpochMs };
    };

    let shiftDocs = [];
    try {
      const shiftsSnapshot = await db.collection('teaching_shifts')
        .where('teacher_id', '==', uid)
        .where('shift_start', '>=', windowStartTs)
        .orderBy('shift_start', 'asc')
        .limit(30)
        .get();
      shiftDocs = shiftsSnapshot.docs;
    } catch (err) {
      if (isMissingIndexError(err)) {
        console.warn('[AI Tutor] Missing index for teacher shift_start query; continuing with fallback.');
      } else {
        throw err;
      }
    }

    // In-memory fallback (avoids index requirement)
    if (shiftDocs.length === 0) {
      const broadSnapshot = await db.collection('teaching_shifts')
        .where('teacher_id', '==', uid)
        .limit(300)
        .get();
      const windowStartDate = yesterdayLocal.toUTC().toJSDate();
      shiftDocs = broadSnapshot.docs
        .filter((doc) => {
          const data = doc.data() || {};
          const start = toDate(data.shift_start || data.start_time);
          return !!start && start >= windowStartDate;
        })
        .sort((a, b) => {
          const aStart = toDate((a.data() || {}).shift_start || (a.data() || {}).start_time);
          const bStart = toDate((b.data() || {}).shift_start || (b.data() || {}).start_time);
          return (aStart?.getTime() || 0) - (bStart?.getTime() || 0);
        })
        .slice(0, 30);
    }

    for (const doc of shiftDocs) {
      const entry = buildShiftEntry(doc.data() || {});
      if (!entry) continue;
      timeline[entry.bucket].push(entry);
    }

    const sortByStart = (entries) =>
      entries.sort((a, b) => a.startEpochMs - b.startEpochMs);
    sortByStart(timeline.live);
    sortByStart(timeline.completedToday);
    sortByStart(timeline.completedYesterday);
    sortByStart(timeline.upcoming);

    const sections = [];
    const sectionLine = (title, entries) => {
      if (!entries.length) return null;
      return `${title}: ${entries.map((entry) => entry.line).join('. ')}.`;
    };
    const liveSection = sectionLine('Live now', timeline.live);
    if (liveSection) sections.push(liveSection);
    const completedTodaySection = sectionLine('Completed today', timeline.completedToday);
    if (completedTodaySection) sections.push(completedTodaySection);
    const completedYesterdaySection = sectionLine('Completed yesterday', timeline.completedYesterday);
    if (completedYesterdaySection) sections.push(completedYesterdaySection);
    const upcomingSection = sectionLine('Upcoming', timeline.upcoming);
    if (upcomingSection) sections.push(upcomingSection);

    if (sections.length > 0) {
      return (
        `Your teaching schedule timeline (all times in your timezone: ${resolvedTimezone}). `
        + `${sections.join(' ')} `
        + 'Past classes shown are limited to today and yesterday.'
      );
    }

    // Template fallback for teachers (upcoming pattern only)
    const templatesSnapshot = await db.collection('shift_templates')
      .where('teacher_id', '==', uid)
      .where('is_active', '==', true)
      .limit(10)
      .get();

    const weekdayNames = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };

    const templateClasses = [];
    for (const doc of templatesSnapshot.docs) {
      const template = doc.data() || {};
      const subject = normalizeSubject(
        template.subject_display_name ||
          template.subject_name ||
          template.custom_name ||
          template.auto_generated_name ||
          template.subject,
      );

      const recurrence = template.enhanced_recurrence || {};
      const recurrenceType = (recurrence.type || '').toString().toLowerCase();
      const selectedWeekdays = Array.isArray(recurrence.selectedWeekdays)
        ? recurrence.selectedWeekdays
        : [];
      const weekdayText = selectedWeekdays
        .map((day) => weekdayNames[Number(day)])
        .filter(Boolean)
        .join(', ');

      const startTime = (template.start_time || '').toString().trim();
      const endTime = (template.end_time || '').toString().trim();
      const timeRange = startTime && endTime
        ? `${startTime} to ${endTime}`
        : (startTime || endTime || 'time not set');

      let pattern = 'schedule pattern not set';
      if (recurrenceType === 'weekly' && weekdayText) {
        pattern = `every ${weekdayText}`;
      } else if (recurrenceType === 'daily') {
        pattern = 'every day';
      } else if (recurrenceType) {
        pattern = `${recurrenceType} schedule`;
      }

      templateClasses.push(`${subject} ${pattern} at ${timeRange}`);
    }

    return templateClasses.length > 0
      ? `Upcoming teaching template schedule (all times in your timezone: ${resolvedTimezone}): ${templateClasses.join('. ')}.`
      : `No live, recent, or upcoming classes scheduled in your timezone (${resolvedTimezone}). Past classes are limited to today and yesterday.`;
  } catch (err) {
    console.warn('[AI Tutor] Failed to fetch teacher classes:', err.message);
    return 'Unable to load class schedule.';
  }
};

/**
 * Callable function: Get LiveKit token for AI Tutor session
 *
 * This creates a unique room for the student to interact with the AI tutor agent.
 * The room name follows a pattern that the LiveKit agent dispatcher recognizes.
 *
 * @param {Object} request - Firebase callable request
 * @returns {Object} LiveKit connection details for AI tutor session
 */
const getAITutorToken = onCall({
  secrets: ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'],
}, async (request) => {
  const uid = request.auth?.uid;
  const requestedMode = request.data?.interactionMode;
  const interactionModeRaw = typeof requestedMode === 'string'
    ? requestedMode.trim().toLowerCase()
    : '';
  const interactionMode = interactionModeRaw === 'text' ? 'text' : 'voice';
  const requestedVoice = request.data?.aiVoice;
  const aiVoiceRaw = typeof requestedVoice === 'string'
    ? requestedVoice.trim().toLowerCase()
    : '';
  const aiVoiceNormalized = AI_VOICE_PREFERENCE_ALIASES.get(aiVoiceRaw) || aiVoiceRaw;
  const voicePreference = ALLOWED_AI_VOICE_PREFERENCES.has(aiVoiceNormalized)
    ? aiVoiceNormalized
    : DEFAULT_AI_VOICE_PREFERENCE;
  const requestedBackground = request.data?.aiBackground;
  const aiBackgroundRaw = typeof requestedBackground === 'string'
    ? requestedBackground.trim().toLowerCase()
    : '';
  const backgroundPreference = ALLOWED_AI_BACKGROUND_PREFERENCES.has(aiBackgroundRaw)
    ? aiBackgroundRaw
    : 'forest';
  const requestedTtsLanguage = request.data?.aiTtsLanguage;
  const ttsLanguageRaw = typeof requestedTtsLanguage === 'string'
    ? requestedTtsLanguage.trim().toLowerCase()
    : '';
  const ttsLanguageCandidate = ttsLanguageRaw || DEFAULT_AI_TTS_LANGUAGE;
  const ttsLanguage = ALLOWED_AI_TTS_LANGUAGES.has(ttsLanguageCandidate)
    ? ttsLanguageCandidate
    : 'en';
  const requestedPronunciationDictId =
    request.data?.aiTtsPronunciationDictId || request.data?.aiPronunciationDictId;
  const ttsPronunciationDictId =
    normalizePronunciationDictId(requestedPronunciationDictId) ||
    normalizePronunciationDictId(DEFAULT_AI_TTS_PRONUNCIATION_DICT_ID);
  const requestedClientTimezone = request.data?.clientTimezone;
  const requestedClientLocalIso = request.data?.clientLocalIso;
  const requestedClientNowEpochMs = request.data?.clientNowEpochMs;

  // Require authentication
  if (!uid) {
    console.log('[AI Tutor] Unauthenticated request');
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  // Check LiveKit configuration
  if (!isLiveKitConfigured()) {
    console.error('[AI Tutor] LiveKit not configured');
    throw new HttpsError('unavailable', 'AI Tutor is not available at this time');
  }

  // Verify role: AI tutor currently supports students and teachers.
  const userRoleRaw = await getUserRole(uid);
  const isTeacher = userRoleRaw.includes('teacher');
  const isStudent = userRoleRaw === 'student';
  const sessionRole = isTeacher ? 'teacher' : (isStudent ? 'student' : '');
  const teacherActionsEnabled = sessionRole === 'teacher';
  if (!sessionRole) {
    console.log('[AI Tutor] Unsupported role access attempt. uid:', uid, 'role:', userRoleRaw);
    throw new HttpsError('permission-denied', 'AI Tutor is only available for students and teachers');
  }

  // Check if AI Tutor is enabled for this user
  const aiTutorEnabled = await checkAITutorEnabled(uid);
  if (!aiTutorEnabled) {
    console.log('[AI Tutor] Access denied - AI Tutor not enabled. uid:', uid);
    throw new HttpsError('permission-denied', 'AI Tutor access has not been enabled for your account');
  }

  // Get user details and role-specific class schedule
  const displayName = await getUserDisplayName(uid);
  const profileTimezone = await getUserTimezone(uid);
  const clientTimezone = parseRequestedTimezone(requestedClientTimezone);
  const userTimezone = normalizeTimezone(clientTimezone || profileTimezone);
  const clientNowEpochMs = parseClientNowEpochMs(requestedClientNowEpochMs);
  const nowUtc = clientNowEpochMs !== null
    ? DateTime.fromMillis(clientNowEpochMs, { zone: 'utc' })
    : DateTime.utc();
  const nowLocal = nowUtc.setZone(userTimezone);
  const clientLocalIsoRaw = typeof requestedClientLocalIso === 'string'
    ? requestedClientLocalIso.trim()
    : '';
  const currentLocalMetadata = {
    current_utc_iso: nowUtc.toISO(),
    current_local_iso: nowLocal.toISO(),
    current_local_date: nowLocal.toFormat('yyyy-LL-dd'),
    current_local_time: nowLocal.toFormat('h:mm a'),
    current_local_weekday: nowLocal.toFormat('cccc'),
    current_local_readable: nowLocal.toFormat('cccc, LLLL d, yyyy h:mm a'),
    current_local_timestamp_ms: nowUtc.toMillis(),
    client_timezone: clientTimezone || '',
    client_local_iso: clientLocalIsoRaw,
    server_generated_at_utc: DateTime.utc().toISO(),
  };
  const classSchedule = isTeacher
    ? await getTeacherClasses(uid, userTimezone, nowUtc)
    : await getStudentClasses(uid, userTimezone, nowUtc);
  const classScheduleStatus =
    typeof classSchedule === 'string' &&
    classSchedule.startsWith('Unable to load class schedule.')
      ? 'unavailable'
      : 'available';

  console.log(
    '[AI Tutor] Fetched class schedule for user:',
    uid,
    'role:',
    sessionRole,
    'timezone:',
    userTimezone,
    'clientTimezone:',
    clientTimezone || '(none)',
    'currentLocal:',
    currentLocalMetadata.current_local_readable,
    'ttsLanguage:',
    ttsLanguage,
    'pronDict:',
    ttsPronunciationDictId || '(none)',
    'status:',
    classScheduleStatus,
    'summary:',
    classSchedule.slice(0, 220),
  );

  // Create a unique room name for this AI tutor session
  // The room name pattern should be recognized by the LiveKit agent dispatcher
  // Format: ai_tutor_{userId}_{timestamp}
  const timestamp = Date.now();
  const roomName = `ai_tutor_${uid}_${timestamp}`;

  // Token TTL: 1 hour for AI tutor sessions
  const ttlSeconds = 3600;

  // Generate LiveKit token with metadata for the AI agent
  // The agent uses {{metadata.user_name}} in its greeting template
  const livekitConfig = getLiveKitConfig();

  // Normalize the LiveKit URL for server API (ws -> http)
  const normalizeUrl = (url) => {
    if (!url) return url;
    if (url.startsWith('wss://')) return `https://${url.slice('wss://'.length)}`;
    if (url.startsWith('ws://')) return `http://${url.slice('ws://'.length)}`;
    return url;
  };

  const serverUrl = normalizeUrl(livekitConfig.url);

  // Create room with metadata for the agent
  const roomMetadata = JSON.stringify({
    user_name: displayName,
    session_type: 'ai_tutor',
    user_role: sessionRole,
    teacher_actions_enabled: teacherActionsEnabled,
    interaction_mode: interactionMode,
    voice_preference: voicePreference,
    background_preference: backgroundPreference,
    tts_language: ttsLanguage,
    ...(ttsPronunciationDictId
      ? { tts_pronunciation_dict_id: ttsPronunciationDictId }
      : {}),
    user_timezone: userTimezone,
    class_schedule_status: classScheduleStatus,
    class_schedule: classSchedule,
    ...currentLocalMetadata,
  });

  try {
    // Create room service client
    const roomService = new RoomServiceClient(serverUrl, livekitConfig.apiKey, livekitConfig.apiSecret);

    // Create the room first
    console.log('[AI Tutor] Creating room:', roomName);
    await roomService.createRoom({
      name: roomName,
      metadata: roomMetadata,
      emptyTimeout: 300, // 5 minutes empty timeout
      maxParticipants: 2, // Just student and agent
    });
    console.log('[AI Tutor] Room created successfully');

    // Dispatch the AI agent to the room
    console.log('[AI Tutor] Dispatching agent:', AI_TUTOR_AGENT_NAME);
    const agentDispatch = new AgentDispatchClient(serverUrl, livekitConfig.apiKey, livekitConfig.apiSecret);
    await agentDispatch.createDispatch(roomName, AI_TUTOR_AGENT_NAME, {
      metadata: roomMetadata,
    });
    console.log('[AI Tutor] Agent dispatched successfully');
  } catch (roomErr) {
    console.error('[AI Tutor] Room/Agent setup error:', roomErr.message);
    // Continue even if room creation fails - it might already exist
    // The token will still work
  }

  const token = await generateAccessToken(roomName, {
    identity: uid,
    name: displayName,
    metadata: {
      user_name: displayName,
      role: sessionRole,
      user_role: sessionRole,
      teacher_actions_enabled: teacherActionsEnabled,
      interaction_mode: interactionMode,
      voice_preference: voicePreference,
      background_preference: backgroundPreference,
      tts_language: ttsLanguage,
      ...(ttsPronunciationDictId
        ? { tts_pronunciation_dict_id: ttsPronunciationDictId }
        : {}),
      session_type: 'ai_tutor',
      user_timezone: userTimezone,
      class_schedule_status: classScheduleStatus,
      class_schedule: classSchedule,
      ...currentLocalMetadata,
    },
    ttlSeconds,
    videoGrant: {
      canPublish: true,
      canPublishData: true,
      canSubscribe: true,
    },
  });

  console.log('[AI Tutor] Token generated. uid:', uid, 'room:', roomName, 'displayName:', displayName);

  // Log session start for analytics
  try {
    await admin.firestore().collection('ai_tutor_sessions').add({
      userId: uid,
      userName: displayName,
      userRole: sessionRole,
      roomName: roomName,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'started',
    });
  } catch (logErr) {
    console.warn('[AI Tutor] Failed to log session:', logErr.message);
    // Non-blocking - continue even if logging fails
  }

  return {
    success: true,
    livekitUrl: livekitConfig.url,
    token: token,
    roomName: roomName,
    displayName: displayName,
    expiresInSeconds: ttlSeconds,
    agentName: AI_TUTOR_AGENT_NAME,
    userRole: sessionRole,
    teacherActionsEnabled,
    interactionMode: interactionMode,
    voicePreference: voicePreference,
    backgroundPreference: backgroundPreference,
    ttsLanguage: ttsLanguage,
    ttsPronunciationDictId: ttsPronunciationDictId || null,
    userTimezone: userTimezone,
    currentLocalIso: currentLocalMetadata.current_local_iso,
    currentLocalDate: currentLocalMetadata.current_local_date,
    currentLocalWeekday: currentLocalMetadata.current_local_weekday,
  };
});

/**
 * Callable function: End AI Tutor session
 *
 * Updates the session log with end time and duration.
 *
 * @param {Object} request - Firebase callable request
 * @param {string} request.data.roomName - The room name of the session to end
 * @returns {Object} Success status
 */
const endAITutorSession = onCall({}, async (request) => {
  const uid = request.auth?.uid;
  const roomName = request.data?.roomName;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  if (!roomName || typeof roomName !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing or invalid roomName');
  }

  // Find and update the session
  try {
    const sessionsSnapshot = await admin.firestore()
      .collection('ai_tutor_sessions')
      .where('userId', '==', uid)
      .where('roomName', '==', roomName)
      .where('status', '==', 'started')
      .limit(1)
      .get();

    if (!sessionsSnapshot.empty) {
      const sessionDoc = sessionsSnapshot.docs[0];
      await sessionDoc.ref.update({
        endedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'ended',
      });
      console.log('[AI Tutor] Session ended. uid:', uid, 'room:', roomName);
    }

    return { success: true };
  } catch (err) {
    console.error('[AI Tutor] Failed to end session:', err.message);
    // Don't throw - session ending is not critical
    return { success: true };
  }
});

module.exports = {
  getAITutorToken,
  endAITutorSession,
};
