#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'alluwal-academy';
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp';

const args = process.argv.slice(2);
const includePending = args.includes('--include-pending');
const includeActive = args.includes('--include-active');
const includeInProgress = args.includes('--include-in-progress');
const generatedOnly = args.includes('--generated-only');

const STATUS_ALIASES = new Map([
  ['inprogress', 'in_progress'],
  ['in-progress', 'in_progress'],
]);

const normalizeStatus = (value) => {
  const raw = (value || '').toString().trim().toLowerCase();
  return STATUS_ALIASES.get(raw) || raw;
};

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

  const statuses = new Set(['scheduled']);
  if (includePending) statuses.add('pending');
  if (includeActive) statuses.add('active');
  if (includeInProgress) statuses.add('in_progress');

  const statusList = Array.from(statuses);
  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Statuses: ${statusList.join(', ')}`);
  console.log(`Generated only: ${generatedOnly ? 'true' : 'false'}`);

  let query = db.collection('teaching_shifts');
  if (statusList.length === 1) {
    query = query.where('status', '==', statusList[0]);
  } else {
    query = query.where('status', 'in', statusList);
  }

  const snap = await query.get();
  const rows = [];

  snap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const status = normalizeStatus(data.status);
    if (!statuses.has(status)) return;
    if (generatedOnly && data.generated_from_template !== true) return;

    rows.push({
      shift_id: doc.id,
      status,
      shift_start: toIso(data.shift_start),
      shift_end: toIso(data.shift_end),
      admin_timezone: data.admin_timezone || '',
      teacher_timezone: data.teacher_timezone || '',
      teacher_id: data.teacher_id || '',
      teacher_name: data.teacher_name || '',
      student_ids: Array.isArray(data.student_ids) ? data.student_ids.join('|') : '',
      student_names: Array.isArray(data.student_names) ? data.student_names.join('|') : '',
      template_id: data.template_id || '',
      generated_from_template: data.generated_from_template === true ? 'true' : 'false',
      subject: data.subject_display_name || data.subject || '',
      shift_category: data.shift_category || data.category || '',
      video_provider: data.video_provider || '',
      created_at: toIso(data.created_at),
      last_modified: toIso(data.last_modified),
    });
  });

  rows.sort((a, b) => {
    if (a.shift_start === b.shift_start) {
      if (a.teacher_name === b.teacher_name) return a.student_names.localeCompare(b.student_names);
      return a.teacher_name.localeCompare(b.teacher_name);
    }
    return a.shift_start.localeCompare(b.shift_start);
  });

  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const outputPath = path.join(OUTPUT_DIR, `prod_scheduled_shifts_snapshot_${timestamp}.csv`);
  writeCsv(
    outputPath,
    [
      'shift_id',
      'status',
      'shift_start',
      'shift_end',
      'admin_timezone',
      'teacher_timezone',
      'teacher_id',
      'teacher_name',
      'student_ids',
      'student_names',
      'template_id',
      'generated_from_template',
      'subject',
      'shift_category',
      'video_provider',
      'created_at',
      'last_modified',
    ],
    rows,
  );

  console.log(`Scheduled shifts: ${rows.length}`);
  console.log(`Snapshot: ${outputPath}`);
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
