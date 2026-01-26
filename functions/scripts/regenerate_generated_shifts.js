#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'alluwal-academy';
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp';
const APPLY = process.argv.includes('--apply');
const INCLUDE_ACTIVE = process.argv.includes('--include-active');
const INCLUDE_IN_PROGRESS = process.argv.includes('--include-in-progress');

const DEFAULT_STATUSES = ['scheduled', 'pending'];

const STATUS_ALIASES = new Map([
  ['inprogress', 'in_progress'],
  ['in-progress', 'in_progress'],
]);

const normalizeStatus = (value) => {
  const raw = (value || '').toString().trim().toLowerCase();
  return STATUS_ALIASES.get(raw) || raw;
};

const isTruthy = (value) =>
  value === true ||
  value === 1 ||
  value === '1' ||
  (typeof value === 'string' && value.toLowerCase() === 'true');

const isExplicitFalse = (value) =>
  value === false ||
  value === 0 ||
  value === '0' ||
  (typeof value === 'string' && value.toLowerCase() === 'false');

const writeCsv = (filePath, headers, rows) => {
  const escapeCell = (value) => {
    if (value === null || value === undefined) return '';
    const raw = String(value);
    if (raw.includes('"')) {
      return `"${raw.replace(/"/g, '""')}"`;
    }
    if (/[,\n]/.test(raw)) {
      return `"${raw}"`;
    }
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

  const statuses = [...DEFAULT_STATUSES];
  if (INCLUDE_ACTIVE) statuses.push('active');
  if (INCLUDE_IN_PROGRESS) statuses.push('in_progress');

  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Mode: ${APPLY ? 'APPLY' : 'AUDIT ONLY'}`);
  console.log(`Statuses to delete: ${statuses.join(', ')}`);

  const snapshotRows = [];
  const shiftsToDelete = [];

  if (statuses.length === 0) {
    console.log('No statuses selected. Exiting.');
    return;
  }

  const statusSnap = await db.collection('teaching_shifts').where('status', 'in', statuses).get();
  statusSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    if (!isTruthy(data.generated_from_template)) return;
    const status = normalizeStatus(data.status);
    if (!statuses.includes(status)) return;

    shiftsToDelete.push(doc.ref);
    snapshotRows.push({
      shift_id: doc.id,
      status,
      shift_start: toIso(data.shift_start),
      shift_end: toIso(data.shift_end),
      teacher_id: data.teacher_id || '',
      teacher_name: data.teacher_name || '',
      student_ids: Array.isArray(data.student_ids) ? data.student_ids.join('|') : '',
      student_names: Array.isArray(data.student_names) ? data.student_names.join('|') : '',
      template_id: data.template_id || '',
      generated_from_template: data.generated_from_template === true ? 'true' : 'false',
    });
  });

  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const snapshotPath = path.join(OUTPUT_DIR, `prod_generated_shift_snapshot_${timestamp}.csv`);
  writeCsv(
    snapshotPath,
    [
      'shift_id',
      'status',
      'shift_start',
      'shift_end',
      'teacher_id',
      'teacher_name',
      'student_ids',
      'student_names',
      'template_id',
      'generated_from_template',
    ],
    snapshotRows,
  );

  console.log(`Generated shift snapshot: ${snapshotPath}`);
  console.log(`Generated shifts to delete: ${shiftsToDelete.length}`);

  if (!APPLY) return;

  let batch = db.batch();
  let opCount = 0;
  const flush = async () => {
    if (opCount === 0) return;
    await batch.commit();
    batch = db.batch();
    opCount = 0;
  };

  for (const ref of shiftsToDelete) {
    batch.delete(ref);
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  }
  await flush();
  console.log(`Deleted ${shiftsToDelete.length} generated shifts.`);

  const shiftTemplateHandlers = require('../handlers/shift_templates');
  const templatesSnap = await db.collection('shift_templates').get();

  let totalCreated = 0;
  let totalSkippedConflicts = 0;
  let totalSkippedNotStarted = 0;
  let totalSkippedOutsideEndDate = 0;
  let totalSkippedNoMatch = 0;
  let processed = 0;
  const failures = [];

  for (const doc of templatesSnap.docs) {
    const data = doc.data() || {};
    const activeValue = data.is_active ?? data.isActive;
    if (activeValue !== undefined && isExplicitFalse(activeValue)) {
      continue;
    }

    try {
      const result = await shiftTemplateHandlers._generateShiftsForTemplate({
        templateId: doc.id,
        template: data,
      });
      totalCreated += result.created || 0;
      totalSkippedConflicts += result.skippedConflicts || 0;
      totalSkippedNotStarted += result.skippedNotStarted || 0;
      totalSkippedOutsideEndDate += result.skippedOutsideEndDate || 0;
      totalSkippedNoMatch += result.skippedNoMatch || 0;
      processed += 1;
    } catch (err) {
      failures.push({templateId: doc.id, error: err?.message || String(err)});
    }
  }

  console.log(`Templates processed: ${processed}`);
  console.log(`Shifts created: ${totalCreated}`);
  console.log(`Skipped (conflicts): ${totalSkippedConflicts}`);
  console.log(`Skipped (before start): ${totalSkippedNotStarted}`);
  console.log(`Skipped (after end date): ${totalSkippedOutsideEndDate}`);
  console.log(`Skipped (no match): ${totalSkippedNoMatch}`);
  if (failures.length) {
    console.log(`Failures: ${failures.length}`);
    failures.slice(0, 10).forEach((failure) => {
      console.log(`- ${failure.templateId}: ${failure.error}`);
    });
  }
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
