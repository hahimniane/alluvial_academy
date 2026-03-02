const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');

const LATE_GRACE_MINUTES = 5;
const REPORT_COLLECTION = 'student_attendance_reports';
const MAX_SHIFT_BREAKDOWN_ITEMS = 250;
const BATCH_WRITE_LIMIT = 400;

const toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return new Date(value.getTime());
  if (typeof value?.toDate === 'function') return value.toDate();
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
};

const startOfUtcDay = (date) =>
  new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));

const addUtcDays = (date, days) =>
  new Date(date.getTime() + days * 24 * 60 * 60 * 1000);

const getWeeklyPeriodForDate = (referenceDate) => {
  const ref = startOfUtcDay(referenceDate);
  const weekday = ref.getUTCDay(); // Sun=0
  const distanceToMonday = (weekday + 6) % 7;
  const periodStart = addUtcDays(ref, -distanceToMonday);
  const periodEnd = addUtcDays(periodStart, 7);
  return { periodStart, periodEnd };
};

const getMonthlyPeriodForDate = (referenceDate) => {
  const periodStart = new Date(Date.UTC(referenceDate.getUTCFullYear(), referenceDate.getUTCMonth(), 1));
  const periodEnd = new Date(Date.UTC(referenceDate.getUTCFullYear(), referenceDate.getUTCMonth() + 1, 1));
  return { periodStart, periodEnd };
};

const getPreviousWeeklyPeriod = (referenceDate = new Date()) => {
  const thisWeek = getWeeklyPeriodForDate(referenceDate);
  const periodEnd = thisWeek.periodStart;
  const periodStart = addUtcDays(periodEnd, -7);
  return { periodStart, periodEnd };
};

const getPreviousMonthlyPeriod = (referenceDate = new Date()) => {
  const currentMonthStart = new Date(Date.UTC(referenceDate.getUTCFullYear(), referenceDate.getUTCMonth(), 1));
  const periodEnd = currentMonthStart;
  const periodStart = new Date(Date.UTC(currentMonthStart.getUTCFullYear(), currentMonthStart.getUTCMonth() - 1, 1));
  return { periodStart, periodEnd };
};

const formatDateKey = (date) => date.toISOString().slice(0, 10);

const buildPeriodKey = (periodType, periodStart) => {
  if (periodType === 'weekly') {
    return `week_${formatDateKey(periodStart)}`;
  }
  return `month_${periodStart.toISOString().slice(0, 7)}`;
};

const buildReportDocId = ({ studentId, periodType, periodStart }) =>
  `${studentId}_${periodType}_${buildPeriodKey(periodType, periodStart)}`;

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

const chunkArray = (values, size) => {
  const chunks = [];
  for (let i = 0; i < values.length; i += size) {
    chunks.push(values.slice(i, i + size));
  }
  return chunks;
};

const normalizeShiftRecord = (doc) => {
  const data = doc.data() || {};
  const shiftStart = toDate(data.shift_start || data.shiftStart);
  const shiftEnd = toDate(data.shift_end || data.shiftEnd);
  if (!shiftStart || !shiftEnd || !shiftEnd.getTime || shiftEnd <= shiftStart) {
    return null;
  }

  const categoryRaw = data.shift_category || data.shiftCategory || 'teaching';
  const category = String(categoryRaw).trim().toLowerCase();
  if (category !== 'teaching') return null;

  const studentIdsRaw = data.student_ids || data.studentIds || [];
  const studentIds = Array.isArray(studentIdsRaw)
    ? studentIdsRaw.map((item) => `${item || ''}`.trim()).filter(Boolean)
    : [];

  const teacherId = `${data.teacher_id || data.teacherId || ''}`.trim();
  const status = `${data.status || 'scheduled'}`.trim();
  const subjectName = `${data.subject_display_name || data.subjectDisplayName || data.subject || 'Class'}`.trim();

  return {
    id: doc.id,
    teacherId,
    studentIds,
    shiftStart,
    shiftEnd,
    status,
    subjectName,
  };
};

const parseLegacyWindow = (sessionData) => {
  const joinedAt = toDate(sessionData.joined_at);
  if (!joinedAt) return [];
  const leftAt = toDate(sessionData.left_at);
  return [
    {
      joinAt: joinedAt,
      leaveAt: leftAt && leftAt > joinedAt ? leftAt : null,
    },
  ];
};

const normalizeRawWindows = (sessionData) => {
  const rawWindows = Array.isArray(sessionData.presence_windows)
    ? sessionData.presence_windows
    : null;

  if (!rawWindows || rawWindows.length === 0) {
    return parseLegacyWindow(sessionData);
  }

  return rawWindows
    .map((windowData) => {
      if (!windowData || typeof windowData !== 'object') return null;
      const joinAt = toDate(windowData.join_at);
      if (!joinAt) return null;
      const leaveAt = toDate(windowData.leave_at);
      return {
        joinAt,
        leaveAt: leaveAt && leaveAt > joinAt ? leaveAt : null,
      };
    })
    .filter(Boolean);
};

const clipWindowToShift = ({ joinAt, leaveAt, shiftStart, shiftEnd, now }) => {
  const windowEnd = leaveAt || now;
  if (!windowEnd || windowEnd <= joinAt) return null;

  let effectiveStart = joinAt;
  let effectiveEnd = windowEnd;

  if (shiftStart && effectiveStart < shiftStart) effectiveStart = shiftStart;
  if (shiftEnd && effectiveEnd > shiftEnd) effectiveEnd = shiftEnd;

  if (effectiveEnd <= effectiveStart) return null;
  return {
    start: effectiveStart,
    end: effectiveEnd,
  };
};

const computeParticipantPresenceMetrics = ({
  sessionData,
  shiftStart,
  shiftEnd,
  now = new Date(),
  lateGraceMinutes = LATE_GRACE_MINUTES,
}) => {
  if (!sessionData || typeof sessionData !== 'object') {
    return {
      joinCount: 0,
      joinsBeforeStartCount: 0,
      joinsLateCount: 0,
      firstJoinAt: null,
      firstJoinOffsetMinutes: null,
      totalPresenceSeconds: 0,
      windows: [],
      hadAnyPresence: false,
    };
  }

  const rawWindows = normalizeRawWindows(sessionData)
    .sort((a, b) => a.joinAt - b.joinAt);

  const windows = rawWindows
    .map((windowData) =>
      clipWindowToShift({
        joinAt: windowData.joinAt,
        leaveAt: windowData.leaveAt,
        shiftStart,
        shiftEnd,
        now,
      }))
    .filter(Boolean)
    .sort((a, b) => a.start - b.start);

  const derivedJoinCount = rawWindows.length;
  const joinCountRaw = Number(sessionData.join_count);
  const joinCount = Number.isFinite(joinCountRaw) && joinCountRaw >= 0
    ? joinCountRaw
    : derivedJoinCount;

  const derivedJoinsBeforeStart = shiftStart
    ? rawWindows.filter((windowData) => windowData.joinAt < shiftStart).length
    : 0;
  const joinsBeforeStartRaw = Number(sessionData.joins_before_start_count);
  const joinsBeforeStartCount =
    Number.isFinite(joinsBeforeStartRaw) && joinsBeforeStartRaw >= 0
      ? joinsBeforeStartRaw
      : derivedJoinsBeforeStart;

  const lateBoundary = shiftStart
    ? new Date(shiftStart.getTime() + lateGraceMinutes * 60 * 1000)
    : null;
  const derivedLateJoins = lateBoundary
    ? rawWindows.filter((windowData) => windowData.joinAt > lateBoundary).length
    : 0;
  const joinsLateRaw = Number(sessionData.joins_late_count);
  const joinsLateCount =
    Number.isFinite(joinsLateRaw) && joinsLateRaw >= 0
      ? joinsLateRaw
      : derivedLateJoins;

  const firstJoinAt = toDate(sessionData.first_joined_at) ||
    (rawWindows.length > 0 ? rawWindows[0].joinAt : null);
  const firstJoinOffsetMinutes = firstJoinAt && shiftStart
    ? Math.round((firstJoinAt.getTime() - shiftStart.getTime()) / 60000)
    : null;

  let totalPresenceSeconds = 0;
  for (const windowData of windows) {
    totalPresenceSeconds += Math.max(
      0,
      Math.floor((windowData.end.getTime() - windowData.start.getTime()) / 1000),
    );
  }

  const hadAnyPresence =
    joinCount > 0 || totalPresenceSeconds > 0 || firstJoinAt != null;

  return {
    joinCount,
    joinsBeforeStartCount,
    joinsLateCount,
    firstJoinAt,
    firstJoinOffsetMinutes,
    totalPresenceSeconds,
    windows,
    hadAnyPresence,
  };
};

const calculateOverlapSeconds = (firstWindows, secondWindows) => {
  if (!Array.isArray(firstWindows) || !Array.isArray(secondWindows)) return 0;
  if (firstWindows.length === 0 || secondWindows.length === 0) return 0;

  const a = [...firstWindows].sort((x, y) => x.start - y.start);
  const b = [...secondWindows].sort((x, y) => x.start - y.start);

  let i = 0;
  let j = 0;
  let overlapSeconds = 0;

  while (i < a.length && j < b.length) {
    const startMs = Math.max(a[i].start.getTime(), b[j].start.getTime());
    const endMs = Math.min(a[i].end.getTime(), b[j].end.getTime());
    if (endMs > startMs) {
      overlapSeconds += Math.floor((endMs - startMs) / 1000);
    }

    if (a[i].end.getTime() <= b[j].end.getTime()) {
      i += 1;
    } else {
      j += 1;
    }
  }

  return overlapSeconds;
};

const buildParticipantMetricsIndex = ({
  shifts,
  sessionsByShift,
  now,
  lateGraceMinutes,
}) => {
  const index = new Map();

  for (const shift of shifts) {
    const shiftSessions = sessionsByShift.get(shift.id) || new Map();
    const participantMetrics = new Map();
    for (const [userId, sessionData] of shiftSessions.entries()) {
      participantMetrics.set(
        userId,
        computeParticipantPresenceMetrics({
          sessionData,
          shiftStart: shift.shiftStart,
          shiftEnd: shift.shiftEnd,
          now,
          lateGraceMinutes,
        }),
      );
    }
    index.set(shift.id, participantMetrics);
  }

  return index;
};

const buildEmptyStudentReport = ({
  studentId,
  periodType,
  periodStart,
  periodEnd,
}) => ({
  report_type: 'student_attendance',
  report_version: 1,
  student_id: studentId,
  period_type: periodType,
  period_key: buildPeriodKey(periodType, periodStart),
  period_start: periodStart,
  period_end: periodEnd,
  computed_from_shift_count: 0,
  metrics: {
    total_shifts_in_period: 0,
    cancelled_classes: 0,
    scheduled_classes: 0,
    attended_classes: 0,
    absent_classes: 0,
    late_classes: 0,
    on_time_classes: 0,
    arrived_before_start_classes: 0,
    student_present_teacher_absent_classes: 0,
    total_join_events: 0,
    total_joins_before_start_events: 0,
    total_student_presence_minutes: 0,
    total_teacher_overlap_minutes: 0,
  },
  rates: {
    attendance_rate: 0,
    punctuality_rate: 0,
    late_rate: 0,
    arrived_before_start_rate: 0,
    student_present_teacher_absent_rate: 0,
    teacher_overlap_rate: 0,
    presence_coverage_rate: 0,
    teacher_overlap_coverage_rate: 0,
  },
  averages: {
    average_join_offset_minutes: 0,
    average_presence_minutes_per_attended_class: 0,
    average_teacher_overlap_minutes_per_attended_class: 0,
  },
  configuration: {
    late_grace_minutes: LATE_GRACE_MINUTES,
  },
  shift_breakdown: [],
});

const computeStudentAttendanceReport = ({
  studentId,
  periodType,
  periodStart,
  periodEnd,
  shifts,
  participantMetricsByShift,
  lateGraceMinutes = LATE_GRACE_MINUTES,
}) => {
  const studentShifts = shifts
    .filter((shift) => shift.studentIds.includes(studentId))
    .sort((a, b) => a.shiftStart - b.shiftStart);

  if (studentShifts.length === 0) {
    return buildEmptyStudentReport({
      studentId,
      periodType,
      periodStart,
      periodEnd,
    });
  }

  const counters = {
    totalShiftsInPeriod: studentShifts.length,
    cancelledClasses: 0,
    scheduledClasses: 0,
    attendedClasses: 0,
    absentClasses: 0,
    lateClasses: 0,
    onTimeClasses: 0,
    arrivedBeforeStartClasses: 0,
    studentPresentTeacherAbsentClasses: 0,
    totalJoinEvents: 0,
    totalJoinsBeforeStartEvents: 0,
    totalStudentPresenceSeconds: 0,
    totalTeacherOverlapSeconds: 0,
    totalScheduledSeconds: 0,
    sumJoinOffsetMinutes: 0,
    joinOffsetSamples: 0,
  };

  const shiftBreakdown = [];

  for (const shift of studentShifts) {
    const isCancelled = shift.status === 'cancelled';
    if (isCancelled) {
      counters.cancelledClasses += 1;
      if (shiftBreakdown.length < MAX_SHIFT_BREAKDOWN_ITEMS) {
        shiftBreakdown.push({
          shift_id: shift.id,
          shift_start_iso: shift.shiftStart.toISOString(),
          shift_end_iso: shift.shiftEnd.toISOString(),
          subject: shift.subjectName,
          status: shift.status,
          cancelled: true,
        });
      }
      continue;
    }

    counters.scheduledClasses += 1;

    const scheduledSeconds = Math.max(
      0,
      Math.floor((shift.shiftEnd.getTime() - shift.shiftStart.getTime()) / 1000),
    );
    counters.totalScheduledSeconds += scheduledSeconds;

    const metricsForShift = participantMetricsByShift.get(shift.id) || new Map();
    const studentMetrics = metricsForShift.get(studentId) ||
      computeParticipantPresenceMetrics({
        sessionData: null,
        shiftStart: shift.shiftStart,
        shiftEnd: shift.shiftEnd,
        lateGraceMinutes,
      });

    const teacherMetrics = metricsForShift.get(shift.teacherId) ||
      computeParticipantPresenceMetrics({
        sessionData: null,
        shiftStart: shift.shiftStart,
        shiftEnd: shift.shiftEnd,
        lateGraceMinutes,
      });

    const attended = studentMetrics.hadAnyPresence;
    const teacherPresent = teacherMetrics.hadAnyPresence;
    const lateBoundary = new Date(
      shift.shiftStart.getTime() + lateGraceMinutes * 60 * 1000,
    );
    const isLate = attended &&
      studentMetrics.firstJoinAt != null &&
      studentMetrics.firstJoinAt > lateBoundary;
    const arrivedBeforeStart = attended &&
      studentMetrics.firstJoinAt != null &&
      studentMetrics.firstJoinAt < shift.shiftStart;
    const overlapSeconds = calculateOverlapSeconds(
      studentMetrics.windows,
      teacherMetrics.windows,
    );
    const studentPresentTeacherAbsent = attended && !teacherPresent;

    if (attended) {
      counters.attendedClasses += 1;
      if (isLate) counters.lateClasses += 1;
      if (!isLate) counters.onTimeClasses += 1;
      if (arrivedBeforeStart) counters.arrivedBeforeStartClasses += 1;
      if (studentPresentTeacherAbsent) {
        counters.studentPresentTeacherAbsentClasses += 1;
      }

      if (studentMetrics.firstJoinOffsetMinutes != null) {
        counters.sumJoinOffsetMinutes += studentMetrics.firstJoinOffsetMinutes;
        counters.joinOffsetSamples += 1;
      }
    } else {
      counters.absentClasses += 1;
    }

    counters.totalJoinEvents += studentMetrics.joinCount;
    counters.totalJoinsBeforeStartEvents += studentMetrics.joinsBeforeStartCount;
    counters.totalStudentPresenceSeconds += studentMetrics.totalPresenceSeconds;
    counters.totalTeacherOverlapSeconds += overlapSeconds;

    if (shiftBreakdown.length < MAX_SHIFT_BREAKDOWN_ITEMS) {
      shiftBreakdown.push({
        shift_id: shift.id,
        shift_start_iso: shift.shiftStart.toISOString(),
        shift_end_iso: shift.shiftEnd.toISOString(),
        subject: shift.subjectName,
        status: shift.status,
        attended,
        teacher_present: teacherPresent,
        late: isLate,
        arrived_before_start: arrivedBeforeStart,
        student_present_teacher_absent: studentPresentTeacherAbsent,
        join_events: studentMetrics.joinCount,
        joins_before_start_events: studentMetrics.joinsBeforeStartCount,
        first_join_offset_minutes: studentMetrics.firstJoinOffsetMinutes,
        student_presence_minutes:
          Number((studentMetrics.totalPresenceSeconds / 60).toFixed(2)),
        teacher_overlap_minutes:
          Number((overlapSeconds / 60).toFixed(2)),
      });
    }
  }

  const scheduledClasses = counters.scheduledClasses;
  const attendedClasses = counters.attendedClasses;
  const attendanceRate = scheduledClasses > 0
    ? attendedClasses / scheduledClasses
    : 0;
  const punctualityRate = attendedClasses > 0
    ? counters.onTimeClasses / attendedClasses
    : 0;
  const lateRate = attendedClasses > 0
    ? counters.lateClasses / attendedClasses
    : 0;
  const arrivedBeforeStartRate = attendedClasses > 0
    ? counters.arrivedBeforeStartClasses / attendedClasses
    : 0;
  const studentPresentTeacherAbsentRate = attendedClasses > 0
    ? counters.studentPresentTeacherAbsentClasses / attendedClasses
    : 0;
  const teacherOverlapRate = counters.totalStudentPresenceSeconds > 0
    ? counters.totalTeacherOverlapSeconds / counters.totalStudentPresenceSeconds
    : 0;
  const presenceCoverageRate = counters.totalScheduledSeconds > 0
    ? counters.totalStudentPresenceSeconds / counters.totalScheduledSeconds
    : 0;
  const teacherOverlapCoverageRate = counters.totalScheduledSeconds > 0
    ? counters.totalTeacherOverlapSeconds / counters.totalScheduledSeconds
    : 0;

  const averageJoinOffsetMinutes = counters.joinOffsetSamples > 0
    ? counters.sumJoinOffsetMinutes / counters.joinOffsetSamples
    : 0;
  const averagePresenceMinutes = attendedClasses > 0
    ? (counters.totalStudentPresenceSeconds / 60) / attendedClasses
    : 0;
  const averageTeacherOverlapMinutes = attendedClasses > 0
    ? (counters.totalTeacherOverlapSeconds / 60) / attendedClasses
    : 0;

  return {
    report_type: 'student_attendance',
    report_version: 1,
    student_id: studentId,
    period_type: periodType,
    period_key: buildPeriodKey(periodType, periodStart),
    period_start: periodStart,
    period_end: periodEnd,
    computed_from_shift_count: studentShifts.length,
    metrics: {
      total_shifts_in_period: counters.totalShiftsInPeriod,
      cancelled_classes: counters.cancelledClasses,
      scheduled_classes: counters.scheduledClasses,
      attended_classes: counters.attendedClasses,
      absent_classes: counters.absentClasses,
      late_classes: counters.lateClasses,
      on_time_classes: counters.onTimeClasses,
      arrived_before_start_classes: counters.arrivedBeforeStartClasses,
      student_present_teacher_absent_classes:
        counters.studentPresentTeacherAbsentClasses,
      total_join_events: counters.totalJoinEvents,
      total_joins_before_start_events: counters.totalJoinsBeforeStartEvents,
      total_student_presence_minutes:
        Number((counters.totalStudentPresenceSeconds / 60).toFixed(2)),
      total_teacher_overlap_minutes:
        Number((counters.totalTeacherOverlapSeconds / 60).toFixed(2)),
    },
    rates: {
      attendance_rate: Number(clamp(attendanceRate, 0, 1).toFixed(4)),
      punctuality_rate: Number(clamp(punctualityRate, 0, 1).toFixed(4)),
      late_rate: Number(clamp(lateRate, 0, 1).toFixed(4)),
      arrived_before_start_rate:
        Number(clamp(arrivedBeforeStartRate, 0, 1).toFixed(4)),
      student_present_teacher_absent_rate:
        Number(clamp(studentPresentTeacherAbsentRate, 0, 1).toFixed(4)),
      teacher_overlap_rate:
        Number(clamp(teacherOverlapRate, 0, 1).toFixed(4)),
      presence_coverage_rate:
        Number(clamp(presenceCoverageRate, 0, 1).toFixed(4)),
      teacher_overlap_coverage_rate:
        Number(clamp(teacherOverlapCoverageRate, 0, 1).toFixed(4)),
    },
    averages: {
      average_join_offset_minutes:
        Number(averageJoinOffsetMinutes.toFixed(2)),
      average_presence_minutes_per_attended_class:
        Number(averagePresenceMinutes.toFixed(2)),
      average_teacher_overlap_minutes_per_attended_class:
        Number(averageTeacherOverlapMinutes.toFixed(2)),
    },
    configuration: {
      late_grace_minutes: lateGraceMinutes,
    },
    shift_breakdown: shiftBreakdown,
  };
};

const isAdminUser = (data = {}) => {
  const role = String(data.role || data.user_type || data.userType || '')
    .trim()
    .toLowerCase();
  return role === 'admin' ||
    role === 'super_admin' ||
    data.is_admin === true ||
    data.isAdmin === true ||
    data.is_super_admin === true ||
    data.isSuperAdmin === true;
};

const hasAdminClaims = (token = {}) => {
  if (!token || typeof token !== 'object') return false;
  const role = String(token.role || token.user_type || token.userType || '')
    .trim()
    .toLowerCase();
  return token.admin === true ||
    token.is_admin === true ||
    role === 'admin' ||
    role === 'super_admin';
};

const canAccessStudentReport = async ({ uid, studentId, authToken }) => {
  if (!uid || !studentId) return false;
  if (uid === studentId) return true;
  if (hasAdminClaims(authToken)) return true;

  const db = admin.firestore();
  const requesterDoc = await db.collection('users').doc(uid).get();
  const requesterData = requesterDoc.exists ? requesterDoc.data() || {} : {};
  if (isAdminUser(requesterData)) return true;

  const studentDoc = await db.collection('users').doc(studentId).get();
  if (!studentDoc.exists) return false;
  const studentData = studentDoc.data() || {};
  const guardianIds = studentData.guardian_ids || studentData.guardianIds || [];
  return Array.isArray(guardianIds) && guardianIds.includes(uid);
};

const loadShiftsForPeriod = async ({ periodStart, periodEnd }) => {
  const db = admin.firestore();
  const shiftsSnapshot = await db
    .collection('teaching_shifts')
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(periodStart))
    .where('shift_start', '<', admin.firestore.Timestamp.fromDate(periodEnd))
    .get();

  const shifts = [];
  for (const doc of shiftsSnapshot.docs) {
    const normalized = normalizeShiftRecord(doc);
    if (normalized) shifts.push(normalized);
  }
  return shifts;
};

const loadSessionsByShift = async ({ shiftIds }) => {
  const db = admin.firestore();
  const sessionsByShift = new Map();
  if (!Array.isArray(shiftIds) || shiftIds.length === 0) return sessionsByShift;

  const chunks = chunkArray(shiftIds, 30);
  for (const chunk of chunks) {
    const sessionsSnapshot = await db
      .collection('livekit_sessions')
      .where('shift_id', 'in', chunk)
      .get();

    for (const doc of sessionsSnapshot.docs) {
      const data = doc.data() || {};
      const shiftId = `${data.shift_id || ''}`.trim();
      const userId = `${data.user_id || ''}`.trim();
      if (!shiftId || !userId) continue;

      if (!sessionsByShift.has(shiftId)) {
        sessionsByShift.set(shiftId, new Map());
      }
      sessionsByShift.get(shiftId).set(userId, data);
    }
  }

  return sessionsByShift;
};

const writeReports = async ({ reports }) => {
  const db = admin.firestore();
  let batch = db.batch();
  let count = 0;
  let writes = 0;

  for (const report of reports) {
    const docId = buildReportDocId({
      studentId: report.student_id,
      periodType: report.period_type,
      periodStart: report.period_start,
    });

    const ref = db.collection(REPORT_COLLECTION).doc(docId);
    batch.set(
      ref,
      {
        ...report,
        generated_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    count += 1;
    writes += 1;

    if (count >= BATCH_WRITE_LIMIT) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }

  if (count > 0) {
    await batch.commit();
  }

  return writes;
};

const generateStudentAttendanceReportsForPeriod = async ({
  periodType,
  periodStart,
  periodEnd,
  targetStudentIds,
  lateGraceMinutes = LATE_GRACE_MINUTES,
}) => {
  const shifts = await loadShiftsForPeriod({ periodStart, periodEnd });
  const shiftIds = shifts.map((shift) => shift.id);
  const sessionsByShift = await loadSessionsByShift({ shiftIds });
  const participantMetricsByShift = buildParticipantMetricsIndex({
    shifts,
    sessionsByShift,
    now: new Date(),
    lateGraceMinutes,
  });

  const allStudentIds = new Set();
  for (const shift of shifts) {
    for (const studentId of shift.studentIds) {
      if (studentId) allStudentIds.add(studentId);
    }
  }

  if (Array.isArray(targetStudentIds)) {
    for (const studentId of targetStudentIds) {
      if (studentId) allStudentIds.add(studentId);
    }
  }

  const reports = [];
  for (const studentId of allStudentIds) {
    reports.push(
      computeStudentAttendanceReport({
        studentId,
        periodType,
        periodStart,
        periodEnd,
        shifts,
        participantMetricsByShift,
        lateGraceMinutes,
      }),
    );
  }

  const writeCount = await writeReports({ reports });
  return {
    generatedReports: writeCount,
    analyzedShifts: shifts.length,
    analyzedSessionDocs: [...sessionsByShift.values()].reduce(
      (sum, map) => sum + map.size,
      0,
    ),
    studentCount: reports.length,
    periodType,
    periodKey: buildPeriodKey(periodType, periodStart),
  };
};

const generateWeeklyStudentAttendanceReports = onSchedule(
  { schedule: '0 2 * * 1', timeZone: 'Etc/UTC' },
  async () => {
    const { periodStart, periodEnd } = getPreviousWeeklyPeriod(new Date());
    const result = await generateStudentAttendanceReportsForPeriod({
      periodType: 'weekly',
      periodStart,
      periodEnd,
    });
    console.log('[attendance] Weekly report generation complete:', result);
  },
);

const generateMonthlyStudentAttendanceReports = onSchedule(
  { schedule: '0 3 1 * *', timeZone: 'Etc/UTC' },
  async () => {
    const { periodStart, periodEnd } = getPreviousMonthlyPeriod(new Date());
    const result = await generateStudentAttendanceReportsForPeriod({
      periodType: 'monthly',
      periodStart,
      periodEnd,
    });
    console.log('[attendance] Monthly report generation complete:', result);
  },
);

const parseRequestedPeriod = ({ periodTypeRaw, referenceDateRaw }) => {
  const periodType = String(periodTypeRaw || 'monthly')
    .trim()
    .toLowerCase();
  if (periodType !== 'weekly' && periodType !== 'monthly') {
    throw new HttpsError(
      'invalid-argument',
      'periodType must be "weekly" or "monthly"',
    );
  }

  const referenceDate = referenceDateRaw
    ? new Date(referenceDateRaw)
    : new Date();
  if (Number.isNaN(referenceDate.getTime())) {
    throw new HttpsError('invalid-argument', 'referenceDate is invalid');
  }

  const { periodStart, periodEnd } = periodType === 'weekly'
    ? getWeeklyPeriodForDate(referenceDate)
    : getMonthlyPeriodForDate(referenceDate);

  return { periodType, periodStart, periodEnd };
};

const getStudentAttendanceReport = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication required');
  }

  const studentId = `${request.data?.studentId || ''}`.trim();
  if (!studentId) {
    throw new HttpsError('invalid-argument', 'studentId is required');
  }

  const allowed = await canAccessStudentReport({
    uid,
    studentId,
    authToken: request.auth?.token,
  });
  if (!allowed) {
    throw new HttpsError(
      'permission-denied',
      'You are not allowed to view this student report',
    );
  }

  const forceRefresh = request.data?.forceRefresh === true;
  const { periodType, periodStart, periodEnd } = parseRequestedPeriod({
    periodTypeRaw: request.data?.periodType,
    referenceDateRaw: request.data?.referenceDate,
  });

  const db = admin.firestore();
  const docId = buildReportDocId({ studentId, periodType, periodStart });
  const reportRef = db.collection(REPORT_COLLECTION).doc(docId);

  if (!forceRefresh) {
    const existing = await reportRef.get();
    if (existing.exists) {
      return {
        success: true,
        cached: true,
        reportId: existing.id,
        report: existing.data(),
      };
    }
  }

  const generationResult = await generateStudentAttendanceReportsForPeriod({
    periodType,
    periodStart,
    periodEnd,
    targetStudentIds: [studentId],
  });

  const generated = await reportRef.get();
  return {
    success: true,
    cached: false,
    reportId: generated.id,
    report: generated.exists ? generated.data() : null,
    generation: generationResult,
  };
});

module.exports = {
  generateWeeklyStudentAttendanceReports,
  generateMonthlyStudentAttendanceReports,
  getStudentAttendanceReport,
  __test__: {
    toDate,
    getWeeklyPeriodForDate,
    getMonthlyPeriodForDate,
    getPreviousWeeklyPeriod,
    getPreviousMonthlyPeriod,
    buildPeriodKey,
    buildReportDocId,
    normalizeShiftRecord,
    normalizeRawWindows,
    computeParticipantPresenceMetrics,
    calculateOverlapSeconds,
    computeStudentAttendanceReport,
  },
};
