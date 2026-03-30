#!/usr/bin/env node
/**
 * Create a one-off test advance-payment form response for a teacher.
 *
 * Default target:
 *   email: aliou9716@gmail.com
 *   submittedAt: 2026-02-20T12:00:00Z
 *   yearMonth: 2026-02
 *   formId: ILMi0ShOhMvL6UUvXGLO (advance form template id used by audit service)
 *
 * Usage examples:
 *   node scripts/create_test_advance_submission.mjs
 *   node scripts/create_test_advance_submission.mjs --email=aliou9716@gmail.com --amount=75
 *   node scripts/create_test_advance_submission.mjs --submittedAt=2026-02-20T09:00:00Z --reason="QA test"
 *   node scripts/create_test_advance_submission.mjs --delete=<DOC_ID>
 */

import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_FORM_ID = 'ILMi0ShOhMvL6UUvXGLO';
const FALLBACK_FORM_NAME = 'Payment Request/Advance CEO';

function parseArgs(argv) {
  const out = {
    email: 'aliou9716@gmail.com',
    amount: 50,
    submittedAt: '2026-02-20T12:00:00Z',
    yearMonth: '2026-02',
    formId: DEFAULT_FORM_ID,
    reason: 'Test advance request (safe to delete)',
    credentials: null,
    projectId: null,
    deleteId: null,
  };
  for (const a of argv) {
    if (a.startsWith('--email=')) out.email = a.slice('--email='.length).trim();
    else if (a.startsWith('--amount=')) out.amount = Number(a.slice('--amount='.length));
    else if (a.startsWith('--submittedAt=')) out.submittedAt = a.slice('--submittedAt='.length).trim();
    else if (a.startsWith('--yearMonth=')) out.yearMonth = a.slice('--yearMonth='.length).trim();
    else if (a.startsWith('--formId=')) out.formId = a.slice('--formId='.length).trim();
    else if (a.startsWith('--reason=')) out.reason = a.slice('--reason='.length).trim();
    else if (a.startsWith('--credentials=')) out.credentials = a.slice('--credentials='.length).trim();
    else if (a.startsWith('--project=')) out.projectId = a.slice('--project='.length).trim();
    else if (a.startsWith('--delete=')) out.deleteId = a.slice('--delete='.length).trim();
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

async function findTeacherByEmail(db, email) {
  const users = db.collection('users');

  let snap = await users.where('e-mail', '==', email).limit(1).get();
  if (!snap.empty) return snap.docs[0];

  snap = await users.where('email', '==', email).limit(1).get();
  if (!snap.empty) return snap.docs[0];

  return null;
}

function buildResponses(amount, reason, submittedAtIso, teacherName) {
  // Real field IDs from template ILMi0ShOhMvL6UUvXGLO (Payment Request/Advance CEO).
  return {
    '1754612176642': teacherName, // Your Name
    '1754612226604': teacherName, // Who are you requesting this for?
    '1754612363426': '1st time requesting advance payment',
    '1754612493990': 'Salary PrePayment',
    '1754612573403': reason, // Why this request
    '1754612617191': 'Test entry for audit validation.',
    '1754612720342': 'Current month salary',
    '1754612938747': `${amount} USD`, // Requested amount
    '1754613040481': submittedAtIso.slice(0, 10), // Needed by date
    amount, // keep numeric fallback for parser robustness
  };
}

async function resolveAdvanceTemplate(db, requestedFormId) {
  const byId = await db.collection('form_templates').doc(requestedFormId).get();
  if (byId.exists) {
    const data = byId.data() || {};
    return {
      id: byId.id,
      name: String(data.name || FALLBACK_FORM_NAME),
    };
  }

  const byName = await db
      .collection('form_templates')
      .where('name', '==', FALLBACK_FORM_NAME)
      .limit(1)
      .get();
  if (!byName.empty) {
    const d = byName.docs[0];
    const data = d.data() || {};
    return {
      id: d.id,
      name: String(data.name || FALLBACK_FORM_NAME),
    };
  }

  throw new Error(
      `Advance template not found (id=${requestedFormId}, name=${FALLBACK_FORM_NAME})`);
}

async function createTestSubmission(args) {
  const db = admin.firestore();

  const submittedDate = new Date(args.submittedAt);
  if (Number.isNaN(submittedDate.getTime())) {
    throw new Error(`Invalid --submittedAt value: ${args.submittedAt}`);
  }
  if (!Number.isFinite(args.amount) || args.amount <= 0) {
    throw new Error(`Invalid --amount value: ${args.amount}`);
  }

  const teacherDoc = await findTeacherByEmail(db, args.email);
  if (!teacherDoc) {
    throw new Error(`No user found with email: ${args.email}`);
  }

  const userId = teacherDoc.id;
  const teacher = teacherDoc.data() || {};
  const teacherName =
    `${teacher.first_name || ''} ${teacher.last_name || ''}`.trim() || args.email;

  const template = await resolveAdvanceTemplate(db, args.formId);

  const payload = {
    formId: template.id,
    templateId: template.id,
    formTitle: template.name,
    userId,
    submitted_by: userId,
    yearMonth: args.yearMonth,
    status: 'submitted',
    responses: buildResponses(
      args.amount,
      args.reason,
      submittedDate.toISOString(),
      teacherName,
    ),
    submittedAt: admin.firestore.Timestamp.fromDate(submittedDate),
    createdAt: admin.firestore.Timestamp.fromDate(submittedDate),
    source: 'script_test_seed',
    isTestData: true,
    testTag: 'DELETE_ME_ADVANCE_TEST',
  };

  const ref = await db.collection('form_responses').add(payload);
  console.log('Created test advance form response.');
  console.log(`- docId: ${ref.id}`);
  console.log(`- userId: ${userId}`);
  console.log(`- teacher: ${teacherName}`);
  console.log(`- email: ${args.email}`);
  console.log(`- submittedAt: ${submittedDate.toISOString()}`);
  console.log(`- yearMonth: ${args.yearMonth}`);
  console.log(`- template: ${template.id} (${template.name})`);
  console.log('\nDelete command:');
  console.log(`node scripts/create_test_advance_submission.mjs --delete=${ref.id}`);
}

async function deleteById(docId) {
  const db = admin.firestore();
  await db.collection('form_responses').doc(docId).delete();
  console.log(`Deleted form_responses/${docId}`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  initFirebase(args);

  if (args.deleteId) {
    await deleteById(args.deleteId);
    return;
  }

  await createTestSubmission(args);
}

main().catch((e) => {
  console.error('Script failed:', e.message || e);
  process.exit(1);
});

