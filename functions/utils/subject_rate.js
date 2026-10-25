'use strict';

/**
 * The hourly rate a class pays, taken from its subject.
 *
 * A class's own `hourly_rate` is what clock-out, timesheets and audits pay
 * from, so a class saved with no rate pays $0 for every hour taught. This
 * resolves the rate its subject carries instead:
 *   1. `subjects/{subject_id}.defaultWage`
 *   2. a subject whose name or display name matches the class's subject
 *      (`subjects`, then the audit rates in `subject_hourly_rates`)
 *   3. the global teacher rate (`app_settings/global.teacher_hourly_rate`)
 *   4. DEFAULT_RATE
 * so a teaching class always ends up with a rate above zero.
 */

const DEFAULT_RATE = 4;
const CACHE_MS = 60 * 1000;

const num = (v) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
};

/** "Quran Studies", "quranStudies", "quran_studies" and "quran" all compare equal. */
const normalizeSubjectName = (value) =>
  String(value ?? '')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .toLowerCase()
    .replace(/[_-]+/g, ' ')
    .replace(/\bstudies\b/g, '')
    .replace(/\s+/g, ' ')
    .trim();

const isTeaching = (data) =>
  String((data && (data.shift_category || data.category)) || 'teaching').trim().toLowerCase() === 'teaching';

const hasSubject = (data) => Boolean(String((data && (data.subject || data.subject_id)) ?? '').trim());

let cache = null;

const loadCatalog = async (db) => {
  if (cache && Date.now() - cache.at < CACHE_MS) return cache.value;
  const [subjects, auditRates, global] = await Promise.all([
    db.collection('subjects').get(),
    db.collection('subject_hourly_rates').get(),
    db.collection('app_settings').doc('global').get(),
  ]);
  const byId = new Map();
  const byName = new Map();
  for (const doc of subjects.docs) {
    const s = doc.data() || {};
    const wage = num(s.defaultWage);
    if (wage <= 0) continue;
    byId.set(doc.id, wage);
    for (const name of [s.name, s.displayName, s.display_name]) {
      const key = normalizeSubjectName(name);
      if (key && !byName.has(key)) byName.set(key, wage);
    }
  }
  for (const doc of auditRates.docs) {
    const r = doc.data() || {};
    if (r.isActive === false) continue;
    const rate = num(r.hourlyRate);
    if (rate <= 0) continue;
    if (r.subjectId && !byId.has(r.subjectId)) byId.set(r.subjectId, rate);
    const key = normalizeSubjectName(r.subjectName);
    if (key && !byName.has(key)) byName.set(key, rate);
  }
  const globalRate = num(global.exists ? (global.data() || {}).teacher_hourly_rate : 0);
  const value = {byId, byName, fallback: globalRate > 0 ? globalRate : DEFAULT_RATE};
  cache = {at: Date.now(), value};
  return value;
};

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {{subject_id?: string, subject?: string, subject_display_name?: string}} data a class or class template
 * @returns {Promise<{rate: number, source: string}>}
 */
const resolveSubjectRate = async (db, data) => {
  const catalog = await loadCatalog(db);
  const id = String((data && data.subject_id) || '').trim();
  if (id && catalog.byId.has(id)) return {rate: catalog.byId.get(id), source: 'subject'};
  for (const name of [data && data.subject_display_name, data && data.subject]) {
    const key = normalizeSubjectName(name);
    if (key && key !== 'other' && catalog.byName.has(key)) return {rate: catalog.byName.get(key), source: 'subject_name'};
  }
  return {rate: catalog.fallback, source: 'global_rate'};
};

const subjectKey = (data) =>
  [data && data.subject_id, data && data.subject, data && data.subject_display_name].map((v) => String(v ?? '').trim()).join('|');

module.exports = {
  DEFAULT_RATE,
  resolveSubjectRate,
  normalizeSubjectName,
  isTeaching,
  hasSubject,
  subjectKey,
  _resetCache: () => {
    cache = null;
  },
};
