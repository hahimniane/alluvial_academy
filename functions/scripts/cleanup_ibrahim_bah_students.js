#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'alluwal-academy';
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp';
const APPLY = process.argv.includes('--apply');

const IBRAHIM_BAH_ID = '04lt4dzmKPWkNXq5Wb5LRpD6JNh1';

const writeCsv = (filePath, headers, rows) => {
  const escapeCell = (value) => {
    if (value === null || value === undefined) return '';
    const raw = String(value);
    if (raw.includes('"')) return `"${raw.replace(/"/g, '""')}"`;
    if (/[,\n]/.test(raw)) return `"${raw}"`;
    return raw;
  };

  const lines = [headers.join(',')];
  rows.forEach((row) => {
    lines.push(headers.map((header) => escapeCell(row[header])).join(','));
  });
  fs.writeFileSync(filePath, `${lines.join('\n')}\n`, 'utf8');
};

const toIso = (value) => {
  if (!value) return '';
  if (typeof value.toDate === 'function') {
    const dt = value.toDate();
    return dt ? dt.toISOString() : '';
  }
  if (value instanceof Date) return value.toISOString();
  return '';
};

const main = async () => {
  if (!admin.apps.length) {
    admin.initializeApp({projectId: PROJECT_ID});
  }
  const db = admin.firestore();

  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Mode: ${APPLY ? 'APPLY' : 'AUDIT ONLY'}`);

  const ibrahimTemplatesSnap = await db.collection('shift_templates').where('teacher_id', '==', IBRAHIM_BAH_ID).get();
  const ibrahimStudentIds = new Set();
  const ibrahimStudentNames = new Map();
  ibrahimTemplatesSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const studentIds = Array.isArray(data.student_ids) ? data.student_ids.map(String) : [];
    const studentNames = Array.isArray(data.student_names) ? data.student_names.map(String) : [];
    studentIds.forEach((studentId, index) => {
      if (!studentId) return;
      ibrahimStudentIds.add(studentId);
      const name = studentNames[index] || '';
      if (name && !ibrahimStudentNames.has(studentId)) {
        ibrahimStudentNames.set(studentId, name);
      }
    });
  });

  if (ibrahimStudentIds.size === 0) {
    console.log('No Ibrahim Bah students found in templates.');
    return;
  }

  const templatesSnap = await db.collection('shift_templates').get();
  const templatesToDelete = [];
  const templateIdsToDelete = new Set();
  templatesSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const teacherId = data.teacher_id || '';
    if (teacherId === IBRAHIM_BAH_ID) return;
    const studentIds = Array.isArray(data.student_ids) ? data.student_ids.map(String) : [];
    if (!studentIds.some((id) => ibrahimStudentIds.has(id))) return;
    templatesToDelete.push({
      template_id: doc.id,
      teacher_name: data.teacher_name || '',
      teacher_id: teacherId,
      student_names: Array.isArray(data.student_names) ? data.student_names.join('|') : '',
      weekdays: Array.isArray(data.enhanced_recurrence?.selectedWeekdays)
        ? data.enhanced_recurrence.selectedWeekdays.join('|')
        : '',
      start_time: data.start_time || '',
      end_time: data.end_time || '',
      active: data.active === false ? 'false' : 'true',
      last_modified: toIso(data.last_modified || data.created_at),
    });
    templateIdsToDelete.add(doc.id);
  });

  const shiftsToDelete = [];
  const shiftsSnap = await db.collection('teaching_shifts').get();
  shiftsSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const teacherId = data.teacher_id || '';
    if (teacherId === IBRAHIM_BAH_ID) return;
    const studentIds = Array.isArray(data.student_ids) ? data.student_ids.map(String) : [];
    if (!studentIds.some((id) => ibrahimStudentIds.has(id))) return;
    shiftsToDelete.push({
      shift_id: doc.id,
      status: data.status || '',
      shift_start: toIso(data.shift_start),
      shift_end: toIso(data.shift_end),
      teacher_name: data.teacher_name || '',
      student_names: Array.isArray(data.student_names) ? data.student_names.join('|') : '',
      template_id: data.template_id || '',
    });
  });

  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const templateSnapshot = path.join(OUTPUT_DIR, `prod_ibrahim_bah_other_templates_delete_${timestamp}.csv`);
  const shiftSnapshot = path.join(OUTPUT_DIR, `prod_ibrahim_bah_other_shifts_delete_${timestamp}.csv`);

  writeCsv(
    templateSnapshot,
    ['template_id', 'teacher_name', 'teacher_id', 'student_names', 'weekdays', 'start_time', 'end_time', 'active', 'last_modified'],
    templatesToDelete,
  );
  writeCsv(
    shiftSnapshot,
    ['shift_id', 'status', 'shift_start', 'shift_end', 'teacher_name', 'student_names', 'template_id'],
    shiftsToDelete,
  );

  console.log(`Templates to delete: ${templatesToDelete.length}`);
  console.log(`Shifts to delete: ${shiftsToDelete.length}`);
  console.log(`Template snapshot: ${templateSnapshot}`);
  console.log(`Shift snapshot: ${shiftSnapshot}`);

  if (!APPLY) return;

  let batch = db.batch();
  let opCount = 0;
  const flush = async () => {
    if (opCount === 0) return;
    await batch.commit();
    batch = db.batch();
    opCount = 0;
  };

  for (const row of shiftsToDelete) {
    batch.delete(db.collection('teaching_shifts').doc(row.shift_id));
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  }
  await flush();

  batch = db.batch();
  opCount = 0;
  for (const row of templatesToDelete) {
    batch.delete(db.collection('shift_templates').doc(row.template_id));
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  }
  await flush();

  console.log('Cleanup complete.');
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
