#!/usr/bin/env node
/**
 * List timesheet_entries as a simple table:
 * teacher | student | clockIn | clockOut
 *
 * Usage:
 *   node scripts/list_timesheet_table.mjs --email=aliou9716@gmail.com --month=2026-02
 *   node scripts/list_timesheet_table.mjs --email=aliou9716@gmail.com --month=2026-02 --csv=./tmp/timesheets.csv
 */

import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const out = {
    email: '',
    month: '', // optional YYYY-MM
    csv: '',
    credentials: null,
    projectId: null,
  };
  for (const a of argv) {
    if (a.startsWith('--email=')) out.email = a.slice('--email='.length).trim();
    else if (a.startsWith('--month=')) out.month = a.slice('--month='.length).trim();
    else if (a.startsWith('--csv=')) out.csv = a.slice('--csv='.length).trim();
    else if (a.startsWith('--credentials=')) out.credentials = a.slice('--credentials='.length).trim();
    else if (a.startsWith('--project=')) out.projectId = a.slice('--project='.length).trim();
  }
  return out;
}

function initFirebase(args) {
  if (admin.apps.length) return;

  const defaultProject =
    args.projectId ||
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    'alluwal-academy';

  const initWithJson = (jsonPath) => {
    const resolved = path.resolve(jsonPath);
    const serviceAccount = JSON.parse(fs.readFileSync(resolved, 'utf8'));
    process.env.GOOGLE_APPLICATION_CREDENTIALS = resolved;
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: args.projectId || serviceAccount.project_id || defaultProject,
    });
  };

  if (args.credentials && fs.existsSync(args.credentials)) {
    initWithJson(args.credentials);
    return;
  }

  const rootKey = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (fs.existsSync(rootKey)) {
    initWithJson(rootKey);
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: defaultProject,
  });
}

async function findUserByEmail(db, email) {
  let snap = await db.collection('users').where('e-mail', '==', email).limit(1).get();
  if (!snap.empty) return snap.docs[0];
  snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (!snap.empty) return snap.docs[0];
  return null;
}

function monthRange(month) {
  if (!/^\d{4}-\d{2}$/.test(month)) {
    throw new Error(`Invalid --month "${month}" (expected YYYY-MM)`);
  }
  const [y, m] = month.split('-').map(Number);
  const start = new Date(Date.UTC(y, m - 1, 1, 0, 0, 0));
  const end = new Date(Date.UTC(y, m, 1, 0, 0, 0)); // exclusive
  return { start, end };
}

function tsToIso(v) {
  if (!v) return '';
  if (typeof v.toDate === 'function') {
    try {
      return v.toDate().toISOString();
    } catch {
      return '';
    }
  }
  return '';
}

function pad(str, len) {
  const s = String(str ?? '');
  return s.length >= len ? s.slice(0, len) : s + ' '.repeat(len - s.length);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.email) throw new Error('Missing --email=...');
  initFirebase(args);
  const db = admin.firestore();

  const teacherDoc = await findUserByEmail(db, args.email);
  if (!teacherDoc) throw new Error(`No user found for email ${args.email}`);
  const teacherId = teacherDoc.id;
  const teacherData = teacherDoc.data() || {};
  const teacherName =
    `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim() || args.email;

  let q = db.collection('timesheet_entries').where('teacher_id', '==', teacherId);

  if (args.month) {
    const { start, end } = monthRange(args.month);
    q = q
      .where('created_at', '>=', admin.firestore.Timestamp.fromDate(start))
      .where('created_at', '<', admin.firestore.Timestamp.fromDate(end));
  }

  const snap = await q.get();

  // Resolve student names in batch
  const studentIds = new Set();
  for (const d of snap.docs) {
    const m = d.data() || {};
    const sid = m.student_id || m.studentId;
    if (sid) studentIds.add(String(sid));
  }
  const studentNameById = new Map();
  const ids = [...studentIds];
  for (let i = 0; i < ids.length; i += 30) {
    const chunk = ids.slice(i, i + 30);
    const us = await db
      .collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
      .get();
    for (const u of us.docs) {
      const d = u.data() || {};
      const name = `${d.first_name || ''} ${d.last_name || ''}`.trim() || d.email || d['e-mail'] || u.id;
      studentNameById.set(u.id, name);
    }
  }

  const rows = snap.docs.map((doc) => {
    const m = doc.data() || {};
    const studentId = String(m.student_id || m.studentId || '');
    return {
      teacher: teacherName,
      student: studentNameById.get(studentId) || studentId || 'N/A',
      clockIn: tsToIso(m.clock_in_time || m.clock_in_timestamp || m.clockIn),
      clockOut: tsToIso(m.effective_end_timestamp || m.clock_out_time || m.clock_out_timestamp || m.clockOut),
      docId: doc.id,
    };
  });

  rows.sort((a, b) => (a.clockIn < b.clockIn ? -1 : a.clockIn > b.clockIn ? 1 : 0));

  console.log(`Teacher: ${teacherName} (${args.email})`);
  console.log(`Teacher ID: ${teacherId}`);
  console.log(`Rows: ${rows.length}`);
  if (args.month) console.log(`Month filter: ${args.month}`);
  console.log('');

  const header =
    `${pad('Teacher', 24)} | ${pad('Student', 24)} | ${pad('ClockIn', 24)} | ${pad('ClockOut', 24)}`;
  console.log(header);
  console.log('-'.repeat(header.length));
  for (const r of rows) {
    console.log(
      `${pad(r.teacher, 24)} | ${pad(r.student, 24)} | ${pad(r.clockIn, 24)} | ${pad(r.clockOut, 24)}`,
    );
  }

  if (args.csv) {
    const out = path.resolve(args.csv);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    const csvLines = ['teacher,student,clockIn,clockOut,docId'];
    for (const r of rows) {
      const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
      csvLines.push([esc(r.teacher), esc(r.student), esc(r.clockIn), esc(r.clockOut), esc(r.docId)].join(','));
    }
    fs.writeFileSync(out, csvLines.join('\n'), 'utf8');
    console.log(`\nCSV written: ${out}`);
  }
}

main().catch((e) => {
  console.error('Script failed:', e.message || e);
  process.exit(1);
});

