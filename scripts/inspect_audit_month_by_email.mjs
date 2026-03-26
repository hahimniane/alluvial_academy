#!/usr/bin/env node
/**
 * Inspect full teacher audit content for one month by teacher email.
 *
 * Usage:
 *   node scripts/inspect_audit_month_by_email.mjs --email=aliou9716@gmail.com --month=2026-02
 *
 * Optional:
 *   --out=./tmp/audit_dump.json   Output path (default: ./tmp/audit_<email>_<month>.json)
 *   --print                       Also print full JSON to stdout
 */

import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const out = {
    email: '',
    month: '2026-02',
    out: '',
    print: false,
    credentials: null,
    projectId: null,
  };
  for (const a of argv) {
    if (a.startsWith('--email=')) out.email = a.slice('--email='.length).trim();
    else if (a.startsWith('--month=')) out.month = a.slice('--month='.length).trim();
    else if (a.startsWith('--out=')) out.out = a.slice('--out='.length).trim();
    else if (a === '--print') out.print = true;
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

function serializeValue(value) {
  if (value === null || value === undefined) return value;
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }
  if (Array.isArray(value)) return value.map((v) => serializeValue(v));
  if (value && typeof value.toDate === 'function') {
    try {
      return value.toDate().toISOString();
    } catch {
      return '[Timestamp]';
    }
  }
  if (typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = serializeValue(v);
    return out;
  }
  return String(value);
}

async function findUserByEmail(db, email) {
  let snap = await db.collection('users').where('e-mail', '==', email).limit(1).get();
  if (!snap.empty) return snap.docs[0];
  snap = await db.collection('users').where('email', '==', email).limit(1).get();
  if (!snap.empty) return snap.docs[0];
  return null;
}

function safeFilePart(input) {
  return input.replace(/[^a-zA-Z0-9._-]+/g, '_');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.email) {
    throw new Error('Missing required --email=...');
  }
  if (!/^\d{4}-\d{2}$/.test(args.month)) {
    throw new Error(`Invalid --month format: "${args.month}" (expected YYYY-MM)`);
  }

  initFirebase(args);
  const db = admin.firestore();

  const userDoc = await findUserByEmail(db, args.email);
  if (!userDoc) {
    throw new Error(`No user found with email: ${args.email}`);
  }
  const userId = userDoc.id;
  const userData = userDoc.data() || {};
  const teacherName =
    `${userData.first_name || ''} ${userData.last_name || ''}`.trim() || args.email;

  const auditId = `${userId}_${args.month}`;
  const auditDoc = await db.collection('teacher_audits').doc(auditId).get();
  if (!auditDoc.exists) {
    const near = await db
      .collection('teacher_audits')
      .where('userId', '==', userId)
      .orderBy('yearMonth', 'desc')
      .limit(6)
      .get();
    const months = near.docs.map((d) => d.get('yearMonth')).filter(Boolean);
    throw new Error(
      `No teacher_audits/${auditId}. Available recent months: ${months.join(', ') || '(none)'}`,
    );
  }

  const audit = auditDoc.data() || {};
  const serializedAudit = serializeValue(audit);

  const output = {
    generatedAt: new Date().toISOString(),
    projectId: admin.app().options.projectId || 'unknown',
    input: {
      email: args.email,
      month: args.month,
    },
    teacher: {
      id: userId,
      name: teacherName,
      email: userData['e-mail'] || userData.email || args.email,
    },
    auditDocPath: `teacher_audits/${auditId}`,
    quickSummary: {
      status: serializedAudit.status,
      overallScore: serializedAudit.overallScore,
      automaticScore: serializedAudit.automaticScore,
      coachScore: serializedAudit.coachScore,
      totalWorkedHours: serializedAudit.totalWorkedHours,
      totalFormHours: serializedAudit.totalFormHours,
      gross: serializedAudit.paymentSummary?.totalGrossPayment,
      net: serializedAudit.paymentSummary?.totalNetPayment,
      detailedShiftsCount: Array.isArray(serializedAudit.detailedShifts)
        ? serializedAudit.detailedShifts.length
        : 0,
      detailedTimesheetsCount: Array.isArray(serializedAudit.detailedTimesheets)
        ? serializedAudit.detailedTimesheets.length
        : 0,
      detailedFormsCount: Array.isArray(serializedAudit.detailedForms)
        ? serializedAudit.detailedForms.length
        : 0,
      changeLogCount: Array.isArray(serializedAudit.changeLog) ? serializedAudit.changeLog.length : 0,
    },
    audit: serializedAudit,
  };

  const defaultOut = path.join(
    process.cwd(),
    'tmp',
    `audit_${safeFilePart(args.email)}_${args.month}.json`,
  );
  const outPath = path.resolve(args.out || defaultOut);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(output, null, 2), 'utf8');

  console.log('Audit export complete.');
  console.log(`- Teacher: ${teacherName} (${args.email})`);
  console.log(`- Audit doc: teacher_audits/${auditId}`);
  console.log(`- Status: ${output.quickSummary.status}`);
  console.log(`- Scores: overall=${output.quickSummary.overallScore}, auto=${output.quickSummary.automaticScore}, coach=${output.quickSummary.coachScore}`);
  console.log(`- Hours: TS=${output.quickSummary.totalWorkedHours}, Forms=${output.quickSummary.totalFormHours}`);
  console.log(`- Pay: gross=${output.quickSummary.gross}, net=${output.quickSummary.net}`);
  console.log(`- Counts: shifts=${output.quickSummary.detailedShiftsCount}, timesheets=${output.quickSummary.detailedTimesheetsCount}, forms=${output.quickSummary.detailedFormsCount}, changelog=${output.quickSummary.changeLogCount}`);
  console.log(`- Output: ${outPath}`);

  if (args.print) {
    console.log('\n=== FULL JSON ===');
    console.log(JSON.stringify(output, null, 2));
  }
}

main().catch((err) => {
  console.error('Script failed:', err.message || err);
  process.exit(1);
});

