#!/usr/bin/env node
'use strict';

/**
 * Enquête: pourquoi "Form Hours" n'apparaît pas pour certains shifts dans l'export Excel.
 * Compare: shifts du mois, form_responses du mois, et (optionnel) audit détaillé.
 *
 * Usage: node investigate_form_hours_export.js [yearMonth] [teacherSearch]
 *   yearMonth: default 2026-02
 *   teacherSearch: part of teacher name or email (default: Thierno)
 *
 * Ex: node investigate_form_hours_export.js 2026-02 Thierno
 */

const admin = require('firebase-admin');
const { DateTime } = require('luxon');
const path = require('path');
const fs = require('fs');

// Credentials: use GOOGLE_APPLICATION_CREDENTIALS, or serviceAccountKey.json at repo root
function initFirebase() {
  if (admin.apps.length) return;
  const projectId = process.env.GCLOUD_PROJECT || 'alluwal-academy';
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({ projectId });
    return;
  }
  const keyPaths = [
    path.join(__dirname, '..', '..', 'serviceAccountKey.json'),
    path.join(__dirname, '..', 'serviceAccountKey.json'),
    path.join(process.cwd(), 'serviceAccountKey.json'),
  ];
  for (const keyPath of keyPaths) {
    if (fs.existsSync(keyPath)) {
      const key = require(keyPath);
      admin.initializeApp({ credential: admin.credential.cert(key), projectId });
      return;
    }
  }
  console.error('Credentials not found. Do one of:');
  console.error('  1. Set GOOGLE_APPLICATION_CREDENTIALS to the path of your service account JSON');
  console.error('  2. Or place serviceAccountKey.json in the project root (alluvial_academy/serviceAccountKey.json)');
  console.error('  3. Or run: gcloud auth application-default login');
  process.exit(1);
}

initFirebase();
const db = admin.firestore();

const YEAR_MONTH = process.argv[2] || '2026-02';
const TEACHER_SEARCH = (process.argv[3] || 'Thierno').toLowerCase();

function parseYearMonth(ym) {
  const [y, m] = ym.split('-').map(Number);
  const start = new Date(y, m - 1, 1, 0, 0, 0);
  const end = new Date(y, m, 0, 23, 59, 59);
  return { start, end };
}

function formatDate(d) {
  if (!d) return '—';
  const date = d.toDate ? d.toDate() : d;
  if (!(date instanceof Date)) return '—';
  return DateTime.fromJSDate(date).toFormat('yyyy-MM-dd HH:mm');
}

async function getTeacherIdByNameOrEmail(search) {
  // Teachers are in users with user_type == 'teacher', fields: first_name, last_name, email or e-mail
  const usersSnap = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();
  const searchLower = search.toLowerCase().trim();
  for (const doc of usersSnap.docs) {
    const d = doc.data();
    const firstName = (d.first_name || '').toLowerCase();
    const lastName = (d.last_name || '').toLowerCase();
    const fullName = `${d.first_name || ''} ${d.last_name || ''}`.trim();
    const email = (d.email || d['e-mail'] || '').toLowerCase();
    const match = fullName.toLowerCase().includes(searchLower) ||
      firstName.includes(searchLower) ||
      lastName.includes(searchLower) ||
      email.includes(searchLower);
    if (match) {
      return {
        uid: doc.id,
        name: fullName || doc.id,
        email: d.email || d['e-mail'] || '',
      };
    }
  }
  return null;
}

async function run() {
  console.log('='.repeat(80));
  console.log('ENQUÊTE: Form Hours dans l\'export Excel');
  console.log('='.repeat(80));
  console.log(`Mois: ${YEAR_MONTH}  |  Recherche enseignant: "${TEACHER_SEARCH}"\n`);

  const { start: startDate, end: endDate } = parseYearMonth(YEAR_MONTH);
  const startTs = admin.firestore.Timestamp.fromDate(startDate);
  const endTs = admin.firestore.Timestamp.fromDate(endDate);

  // 1) Trouver l'enseignant
  const teacher = await getTeacherIdByNameOrEmail(TEACHER_SEARCH);
  if (!teacher) {
    console.log('Aucun enseignant trouvé pour:', TEACHER_SEARCH);
    process.exit(1);
  }
  console.log(`Enseignant: ${teacher.name} (${teacher.email})`);
  console.log(`UID: ${teacher.uid}\n`);

  // 2) Shifts du mois pour cet enseignant
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('teacher_id', '==', teacher.uid)
    .where('shift_start', '>=', startTs)
    .where('shift_start', '<=', endTs)
    .get();

  const shifts = [];
  shiftsSnap.docs.forEach(doc => {
    const d = doc.data();
    const shiftStart = d.shift_start && d.shift_start.toDate ? d.shift_start.toDate() : null;
    shifts.push({
      id: doc.id,
      start: shiftStart,
      status: d.status || 'scheduled',
      subject: d.subject_display_name || d.subject || '—',
      isBanned: d.isBanned === true,
    });
  });
  shifts.sort((a, b) => (a.start && b.start ? a.start.getTime() - b.start.getTime() : 0));

  console.log('--- SHIFTS DU MOIS ---');
  console.log(`Total: ${shifts.length} (sans les banned: ${shifts.filter(s => !s.isBanned).length})\n`);

  // 3) Form responses du mois (tous, puis on filtre par userId/submitted_by)
  const formsSnap = await db.collection('form_responses')
    .where('yearMonth', '==', YEAR_MONTH)
    .get();

  const formsByTeacher = [];
  formsSnap.docs.forEach(doc => {
    const d = doc.data();
    const uid = d.userId || d.submitted_by || '';
    if (uid !== teacher.uid) return;
    const submittedAt = d.submittedAt && d.submittedAt.toDate ? d.submittedAt.toDate() : null;
    const responses = d.responses || {};
    let durationHours = 0;
    if (typeof responses.duration === 'number') durationHours = responses.duration / 60;
    else if (typeof responses.duration_hours === 'number') durationHours = responses.duration_hours;
    else if (responses.how_long) {
      const m = String(responses.how_long).match(/(\d+)/);
      if (m) durationHours = parseInt(m[1], 10) / 60;
    }
    // Some forms use "1754407297953" or similar keys for duration (minutes)
    for (const k of Object.keys(responses)) {
      if (/^\d+$/.test(k) && typeof responses[k] === 'number' && responses[k] < 600) {
        durationHours = Math.max(durationHours, responses[k] / 60);
      }
    }
    formsByTeacher.push({
      id: doc.id,
      shiftId: d.shiftId || '',
      submittedAt,
      durationHours,
      yearMonth: d.yearMonth,
    });
  });
  formsByTeacher.sort((a, b) => (a.submittedAt && b.submittedAt ? a.submittedAt.getTime() - b.submittedAt.getTime() : 0));

  console.log('--- FORMULAIRES DU MOIS (pour cet enseignant) ---');
  console.log(`Total: ${formsByTeacher.length}\n`);

  // 4) Tableau: pour chaque shift, form lié ou pas
  const validShiftIds = new Set(shifts.filter(s => !s.isBanned).map(s => s.id));
  const shiftToForm = new Map();
  formsByTeacher.forEach(f => {
    if (f.shiftId && validShiftIds.has(f.shiftId)) {
      shiftToForm.set(f.shiftId, f);
    }
  });

  console.log('--- TABLEAU SHIFT vs FORM HOURS ---');
  console.log('Date       | ShiftId (8) | Status   | Form? | Soumis le    | Duration');
  console.log('-'.repeat(80));

  for (const s of shifts) {
    if (s.isBanned) continue;
    const form = shiftToForm.get(s.id);
    const dateStr = s.start ? DateTime.fromJSDate(s.start).toFormat('yyyy-MM-dd') : '—';
    const idShort = s.id.length >= 8 ? s.id.slice(-8) : s.id;
    const formYes = form ? 'Yes' : 'No';
    const submittedStr = form && form.submittedAt ? DateTime.fromJSDate(form.submittedAt).toFormat('MM-dd HH:mm') : '—';
    const durStr = form && form.durationHours ? form.durationHours.toFixed(2) + 'h' : '—';
    console.log(`${dateStr} | ${idShort} | ${(s.status || '').padEnd(8)} | ${formYes.padEnd(4)} | ${submittedStr} | ${durStr}`);
  }

  // 5) Formulaires SANS shiftId ou avec shiftId invalide
  const formsWithoutLink = formsByTeacher.filter(f => !f.shiftId || !validShiftIds.has(f.shiftId));
  if (formsWithoutLink.length > 0) {
    console.log('\n--- FORMULAIRES SANS LIAISON SHIFT (ou shift hors mois / banned) ---');
    formsWithoutLink.forEach(f => {
      console.log(`  Form ${f.id}  shiftId="${f.shiftId || '(vide)'}"  submitted=${formatDate(f.submittedAt)}  duration=${f.durationHours}h`);
    });
  }

  // 6) Shifts "Done" sans form
  const doneShifts = shifts.filter(s => !s.isBanned && ['fullyCompleted', 'completed', 'partiallyCompleted'].includes(s.status));
  const doneWithoutForm = doneShifts.filter(s => !shiftToForm.has(s.id));
  if (doneWithoutForm.length > 0) {
    console.log('\n--- SHIFTS COMPLÉTÉS SANS FORMULAIRE LIÉ (donc Form Hours = "-" dans l\'export) ---');
    doneWithoutForm.forEach(s => {
      const dateStr = s.start ? DateTime.fromJSDate(s.start).toFormat('yyyy-MM-dd HH:mm') : '—';
      console.log(`  ${dateStr}  ${s.id}  ${s.status}  ${s.subject}`);
    });
  }

  // 7) Résumé
  console.log('\n--- RÉSUMÉ ---');
  console.log(`Shifts (valides): ${shifts.filter(s => !s.isBanned).length}`);
  console.log(`Shifts "Done": ${doneShifts.length}`);
  console.log(`Formulaires (cet enseignant, ce mois): ${formsByTeacher.length}`);
  console.log(`Formulaires liés à un shift valide: ${shiftToForm.size}`);
  console.log(`Shifts Done sans form: ${doneWithoutForm.length}`);
  console.log(`Formulaires sans shiftId ou shift invalide: ${formsWithoutLink.length}`);

  if (doneWithoutForm.length > 0 || formsWithoutLink.length > 0) {
    console.log('\n→ Si tu as rempli des forms "un peu tard": vérifier qu\'ils ont bien un shiftId.');
    console.log('  Les forms sans shiftId n\'apparaissent pas dans la colonne Form Hours du shift.');
    console.log('  Tu peux lier un form à un shift depuis l\'écran Audit (détail) si besoin.');
  }

  // Suggestion: pour chaque shift Done sans form, forms soumis le même jour (candidats à lier)
  if (doneWithoutForm.length > 0 && formsWithoutLink.length > 0) {
    console.log('\n--- CANDIDATS POSSIBLES (forms soumis le jour du shift, à lier manuellement) ---');
    for (const shift of doneWithoutForm) {
      const shiftDay = shift.start ? DateTime.fromJSDate(shift.start).toFormat('yyyy-MM-dd') : null;
      if (!shiftDay) continue;
      const sameDay = formsWithoutLink.filter(f => {
        if (!f.submittedAt) return false;
        const d = DateTime.fromJSDate(f.submittedAt).toFormat('yyyy-MM-dd');
        return d === shiftDay || DateTime.fromJSDate(f.submittedAt).toFormat('yyyy-MM-dd') === shiftDay;
      });
      if (sameDay.length > 0) {
        console.log(`  Shift ${shiftDay} ${shift.id}: ${sameDay.length} form(s) soumis ce jour-là (IDs: ${sameDay.map(f => f.id).join(', ')})`);
      }
    }
  }

  process.exit(0);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
