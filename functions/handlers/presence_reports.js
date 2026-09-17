'use strict';

/**
 * Drop-out reporting: per class, per week, per month.
 *
 * The bot's reports leave a trail of arrivals and departures. This turns that
 * trail into the three numbers a person reads — how often somebody dropped, how
 * much lesson time went with it, and the longest single absence — and keeps the
 * summaries after the raw detail has aged out with the class.
 *
 * Summarising happens once a class is over rather than on demand, because the
 * raw events live 60 days and the weekly and monthly figures are meant to
 * outlast them. Reading them back later would silently shrink the past.
 */

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { shiftsInRange, shiftsByIds } = require('../utils/shifts_in_range');
const { isAdminRequester } = require('../utils/admin_access');
const { buildClassSummary, toMs } = require('../services/presence/class_report');
const { rollUp } = require('../services/presence/summary');

const EVENTS = 'class_presence_events';
const CLASS_SUMMARIES = 'class_presence_summaries';
const PERIOD_REPORTS = 'presence_period_reports';

/** A class is only summarised once its grace period has run out. */
const CLASS_SETTLE_MINUTES = 20;
/** How far back a sweep looks, so one missed run repairs itself. */
const SWEEP_LOOKBACK_HOURS = 8;
/** Never let a single sweep run away with the day. */
const MAX_CLASSES_PER_SWEEP = 200;

const _startOfUtcDay = (date) => new Date(Date.UTC(
  date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
));

/** Monday, because a teaching week reads Monday to Sunday. */
const startOfWeek = (date) => {
  const day = _startOfUtcDay(date);
  const weekday = (day.getUTCDay() + 6) % 7;
  day.setUTCDate(day.getUTCDate() - weekday);
  return day;
};

const startOfMonth = (date) => new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1));

const periodKey = (periodType, periodStart) =>
  `${periodType}_${periodStart.toISOString().slice(0, 10)}`;

/**
 * Summarise every class that has finished and has not been summarised yet.
 *
 * Idempotent on purpose: it asks which classes already have a summary rather
 * than trusting that the last run finished, so a missed run or a restart
 * repairs itself on the next sweep instead of leaving a hole.
 */
const summariseFinishedClasses = async ({ now = new Date() } = {}) => {
  const db = admin.firestore();
  const settledBefore = new Date(now.getTime() - CLASS_SETTLE_MINUTES * 60 * 1000);
  const from = new Date(now.getTime() - SWEEP_LOOKBACK_HOURS * 60 * 60 * 1000);

  const shiftDocs = await shiftsInRange(db, { start: from, end: now, endInclusive: true });
  const finished = shiftDocs.filter((doc) => {
    const end = toMs((doc.data() || {}).shift_end);
    return Number.isFinite(end) && end <= settledBefore.getTime();
  }).slice(0, MAX_CLASSES_PER_SWEEP);

  let written = 0;
  let skipped = 0;

  for (const shiftDoc of finished) {
    const shiftId = shiftDoc.id;
    const summaryRef = db.collection(CLASS_SUMMARIES).doc(shiftId);
    const existing = await summaryRef.get();
    if (existing.exists) { skipped += 1; continue; }

    const eventsSnap = await db.collection(EVENTS).doc(shiftId).collection('events').get();
    const summary = buildClassSummary({
      shiftId,
      shiftData: shiftDoc.data() || {},
      eventDocs: eventsSnap.docs.map((doc) => doc.data() || {}),
    });
    // No events at all means the bot never watched this class. Writing a clean
    // sheet would claim it went perfectly, which we have no basis to say.
    if (!summary) { skipped += 1; continue; }

    await summaryRef.set({
      ...summary,
      computed_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    written += 1;
  }

  if (written > 0 || skipped > 0) {
    console.log(`[presence] summarised ${written} finished class(es), skipped ${skipped}.`);
  }
  return { written, skipped, considered: finished.length };
};

/** Roll finished classes into one week or one month, per person. */
const buildPeriodReports = async ({ periodType, periodStart, periodEnd }) => {
  const db = admin.firestore();
  const shiftDocs = await shiftsInRange(db, { start: periodStart, end: periodEnd });
  const shiftIds = shiftDocs.map((doc) => doc.id);
  if (shiftIds.length === 0) return { people: 0 };

  const summaries = [];
  for (let i = 0; i < shiftIds.length; i += 10) {
    const chunk = shiftIds.slice(i, i + 10);
    const docs = await Promise.all(
      chunk.map((id) => db.collection(CLASS_SUMMARIES).doc(id).get()),
    );
    for (const doc of docs) if (doc.exists) summaries.push(doc.data() || {});
  }
  if (summaries.length === 0) return { people: 0 };

  const people = rollUp(summaries);
  const key = periodKey(periodType, periodStart);
  let batch = db.batch();
  let pending = 0;

  for (const person of people) {
    const ref = db.collection(PERIOD_REPORTS).doc(`${person.uid}_${key}`);
    batch.set(ref, {
      uid: person.uid,
      role: person.role || null,
      name: person.name || null,
      period_type: periodType,
      period_start: admin.firestore.Timestamp.fromDate(periodStart),
      period_end: admin.firestore.Timestamp.fromDate(periodEnd),
      classes: person.classes,
      classes_with_a_drop: person.classesWithADrop,
      counted: person.counted,
      by_cause: person.byCause,
      // The classes the totals are made of, so a figure can be questioned.
      occasions: person.occasions || [],
      classes_summarised: summaries.length,
      computed_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    pending += 1;
    if (pending >= 400) { await batch.commit(); batch = db.batch(); pending = 0; }
  }
  if (pending > 0) await batch.commit();

  console.log(`[presence] ${periodType} report ${key}: ${people.length} people over ${summaries.length} classes.`);
  return { people: people.length, classes: summaries.length };
};

const _periodFor = (periodType, reference) => {
  if (periodType === 'monthly') {
    const start = startOfMonth(reference);
    const end = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 1));
    return { periodStart: start, periodEnd: end };
  }
  const start = startOfWeek(reference);
  const end = new Date(start.getTime());
  end.setUTCDate(end.getUTCDate() + 7);
  return { periodStart: start, periodEnd: end };
};

// ---------------------------------------------------------------- scheduled

/**
 * Bring the week and the month a reader is currently living in up to date.
 *
 * The reports a person opens are for the period they are in, so a period that
 * is only built once it has ended is a period nobody ever sees: the Monday job
 * writes the week that just finished, while every card on screen that week asks
 * for the week in progress, and the two keys never meet.
 *
 * Rebuilt only when a class was actually summarised, so quiet sweeps — most of
 * them — read nothing at all.
 */
const refreshCurrentPeriods = async ({ now = new Date() } = {}) => {
  for (const periodType of ['weekly', 'monthly']) {
    await buildPeriodReports({ periodType, ..._periodFor(periodType, now) });
  }
};

const summariseClassPresence = onSchedule(
  { schedule: 'every 30 minutes', timeoutSeconds: 540 },
  async () => {
    const now = new Date();
    const { written } = await summariseFinishedClasses({ now });
    if (written > 0) await refreshCurrentPeriods({ now });
  },
);

const generateWeeklyPresenceReports = onSchedule(
  // Monday, after the student attendance reports have had their turn.
  { schedule: '30 2 * * 1', timeZone: 'UTC', timeoutSeconds: 540 },
  async () => {
    const lastWeek = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    await buildPeriodReports({ periodType: 'weekly', ..._periodFor('weekly', lastWeek) });
  },
);

const generateMonthlyPresenceReports = onSchedule(
  { schedule: '30 3 1 * *', timeZone: 'UTC', timeoutSeconds: 540 },
  async () => {
    const lastMonth = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
    await buildPeriodReports({ periodType: 'monthly', ..._periodFor('monthly', lastMonth) });
  },
);

// ----------------------------------------------------------------- callable

/**
 * One person's drop-outs for a period. A teacher may read their own; an
 * administrator may read anybody's.
 */
const getPresenceReport = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');

  const subject = String(request.data?.uid || '').trim() || uid;
  if (subject !== uid) {
    const allowed = await isAdminRequester({ uid, authToken: request.auth?.token });
    if (!allowed) {
      throw new HttpsError('permission-denied', 'You can only view your own connection report.');
    }
  }

  const periodType = request.data?.periodType === 'monthly' ? 'monthly' : 'weekly';
  const reference = request.data?.referenceDate
    ? new Date(request.data.referenceDate)
    : new Date();
  if (!Number.isFinite(reference.getTime())) {
    throw new HttpsError('invalid-argument', 'referenceDate is not a date');
  }
  const { periodStart, periodEnd } = _periodFor(periodType, reference);

  const db = admin.firestore();
  const doc = await db.collection(PERIOD_REPORTS)
    .doc(`${subject}_${periodKey(periodType, periodStart)}`)
    .get();

  return {
    success: true,
    uid: subject,
    periodType,
    periodStart: periodStart.toISOString(),
    periodEnd: periodEnd.toISOString(),
    report: doc.exists ? doc.data() : null,
  };
});

/** Everyone's drop-outs for a period, worst first. Administrators only. */
const getPresenceOverview = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Authentication required');
  const allowed = await isAdminRequester({ uid, authToken: request.auth?.token });
  if (!allowed) {
    throw new HttpsError('permission-denied', 'Only administrators can view the overview.');
  }

  const periodType = request.data?.periodType === 'monthly' ? 'monthly' : 'weekly';
  const reference = request.data?.referenceDate
    ? new Date(request.data.referenceDate)
    : new Date();
  if (!Number.isFinite(reference.getTime())) {
    throw new HttpsError('invalid-argument', 'referenceDate is not a date');
  }
  const { periodStart, periodEnd } = _periodFor(periodType, reference);

  const db = admin.firestore();
  const snap = await db.collection(PERIOD_REPORTS)
    .where('period_type', '==', periodType)
    .where('period_start', '==', admin.firestore.Timestamp.fromDate(periodStart))
    .get();

  const people = snap.docs
    .map((doc) => doc.data() || {})
    .filter((row) => String(row.role || '') === 'teacher')
    .sort((a, b) => (b.counted?.drops || 0) - (a.counted?.drops || 0));

  return {
    success: true,
    periodType,
    periodStart: periodStart.toISOString(),
    periodEnd: periodEnd.toISOString(),
    teachers: people,
  };
});

module.exports = {
  summariseClassPresence,
  generateWeeklyPresenceReports,
  generateMonthlyPresenceReports,
  getPresenceReport,
  getPresenceOverview,
  __test__: {
    summariseFinishedClasses,
    buildPeriodReports,
    startOfWeek,
    startOfMonth,
    periodKey,
    _periodFor,
  },
};
