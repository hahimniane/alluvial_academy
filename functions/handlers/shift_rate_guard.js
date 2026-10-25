'use strict';

/**
 * Keeps every upcoming class paying its subject's rate.
 *
 * Classes are created and edited from the Flutter app, the admin website,
 * the template generator and the makeup flow, and several of those copy
 * whatever rate they were handed - including none. Clock-out, timesheets and
 * audits all pay from the class's `hourly_rate`, so a class with no rate pays
 * $0 for every hour taught. This trigger is the one place that holds the rule
 * for all of them:
 *   - a teaching class with no rate (or $0) gets its subject's rate;
 *   - a class whose subject changes gets the new subject's rate, unless the
 *     same edit also set a rate.
 * Only classes that have not ended yet are touched, so pay already earned on
 * past classes never moves.
 */

const admin = require('firebase-admin');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const subjectRate = require('../utils/subject_rate');

const num = (v) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
};

const endMs = (data) => {
  const end = data && data.shift_end;
  if (end && typeof end.toMillis === 'function') return end.toMillis();
  if (end instanceof Date) return end.getTime();
  return null;
};

/**
 * What the class's rate should be re-derived for, or null to leave it alone.
 * @returns {null | 'no_rate' | 'subject_changed'}
 */
const rateDecision = (before, after, nowMs) => {
  if (!after) return null;
  if (!subjectRate.isTeaching(after)) return null;
  if (String(after.status || '').toLowerCase() === 'deleted') return null;
  const end = endMs(after);
  if (end === null || end <= nowMs) return null;
  if (!(num(after.hourly_rate) > 0)) return 'no_rate';
  if (!before) return null;
  const subjectChanged = subjectRate.subjectKey(before) !== subjectRate.subjectKey(after);
  const rateChanged = num(before.hourly_rate) !== num(after.hourly_rate);
  if (subjectChanged && !rateChanged) return 'subject_changed';
  return null;
};

const applySubjectRate = async ({db, ref, before, after, now = Date.now()}) => {
  const reason = rateDecision(before, after, now);
  if (!reason) return null;
  const {rate, source} = await subjectRate.resolveSubjectRate(db, after);
  if (num(after.hourly_rate) === rate) return null;
  await ref.set({
    hourly_rate: rate,
    hourly_rate_source: source,
    hourly_rate_set_reason: reason,
    hourly_rate_set_at: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {reason, rate, source};
};

const enforceShiftSubjectRate = onDocumentWritten('teaching_shifts/{shiftId}', async (event) => {
  const before = event.data && event.data.before && event.data.before.exists ? event.data.before.data() : null;
  const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;
  const result = await applySubjectRate({db: admin.firestore(), ref: event.data.after.ref, before, after});
  if (result) {
    console.log(`[shift_rate_guard] ${event.params.shiftId}: ${result.reason} -> $${result.rate} (${result.source})`);
  }
});

module.exports = {enforceShiftSubjectRate, rateDecision, applySubjectRate};
