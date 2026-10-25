#!/usr/bin/env node
/**
 * One-off (2026-10-25): give every UPCOMING teaching class a subject rate.
 *
 *   node scripts/fix_upcoming_class_rates.js            # dry run
 *   node scripts/fix_upcoming_class_rates.js --apply
 *
 * - The two subject-less templates that still have students get the subject
 *   their students' other classes with the same teacher use.
 * - Active teaching templates with no rate get their subject's rate.
 * - Classes that have not ended and have no rate get their subject's rate
 *   (and the template's subject, for the two templates above).
 * Past classes are not touched: pay already earned stays as it was.
 */
const admin = require('firebase-admin');
admin.initializeApp({projectId: 'alluwal-academy'});
const {resolveSubjectRate, isTeaching} = require('../utils/subject_rate');

const APPLY = process.argv.includes('--apply');
const SUBJECTS = {
  // Kadidjatu Bah with Chernor Ahmadu Jalloh: her other classes with him are Quran Studies.
  Uoc28nGWh5yVOdXzTSaH: {subject: 'quranStudies', subject_display_name: 'Quran Studies', subject_id: null},
  // Rugiatu Jalloh with Rahmatullaah Balde: her other classes with her are Islamic Studies.
  ngidtglKNDxOi7yplAuT: {subject: 'islamic', subject_display_name: 'Islamic Studies', subject_id: '5w7SXs0X7ydFRz8R2Wjf'},
};

(async () => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const writes = [];
  const tpls = await db.collection('shift_templates').get();
  for (const doc of tpls.docs) {
    const t = doc.data();
    if (t.is_active === false || !isTeaching(t)) continue;
    const patch = {...(SUBJECTS[doc.id] || {})};
    const merged = {...t, ...patch};
    if (!(Number(t.hourly_rate) > 0) || Object.keys(patch).length) {
      const {rate, source} = await resolveSubjectRate(db, merged);
      if (!(Number(t.hourly_rate) > 0)) Object.assign(patch, {hourly_rate: rate, hourly_rate_source: source});
    }
    if (Object.keys(patch).length) writes.push({ref: doc.ref, label: `template ${doc.id} ${t.teacher_name}`, before: `${t.subject || '-'} $${t.hourly_rate}`, patch});
  }
  const shifts = await db.collection('teaching_shifts').where('shift_end', '>', now).get();
  for (const doc of shifts.docs) {
    const s = doc.data();
    if (!isTeaching(s) || String(s.status).toLowerCase() === 'deleted') continue;
    const patch = {...(SUBJECTS[s.template_id] && !String(s.subject || '').trim() ? SUBJECTS[s.template_id] : {})};
    if (!(Number(s.hourly_rate) > 0)) {
      const {rate, source} = await resolveSubjectRate(db, {...s, ...patch});
      Object.assign(patch, {hourly_rate: rate, hourly_rate_source: source, hourly_rate_set_reason: 'no_rate'});
    }
    if (Object.keys(patch).length) writes.push({ref: doc.ref, label: `class ${doc.id} ${s.teacher_name} ${s.shift_start.toDate().toISOString().slice(0, 10)}`, before: `${s.subject || '-'} $${s.hourly_rate}`, patch});
  }
  for (const w of writes) console.log(`${w.label}: ${w.before} -> ${JSON.stringify(w.patch)}`);
  console.log(`${writes.length} documents ${APPLY ? 'updated' : 'would be updated (dry run)'}`);
  if (APPLY) {
    for (let i = 0; i < writes.length; i += 400) {
      const batch = db.batch();
      for (const w of writes.slice(i, i + 400)) batch.set(w.ref, {...w.patch, last_modified: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
      await batch.commit();
    }
  }
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
