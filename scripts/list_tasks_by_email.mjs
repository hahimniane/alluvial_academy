#!/usr/bin/env node
/**
 * List Firestore `tasks` for a user identified by email (assigned + optionally created).
 *
 * Usage:
 *   node scripts/list_tasks_by_email.mjs --email=aliou9716@gmail.com
 *
 * Optional:
 *   --include-created     Also list tasks where createdBy == user (even if not assigned)
 *   --out=./tmp/tasks.json   Write full task docs as JSON (default: stdout only)
 *   --credentials=path.json  Service account JSON (else ../serviceAccountKey.json or ADC)
 *   --project=project-id
 *
 * Each task prints the Firestore `description` field (what is being asked / consigne).
 */

import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const out = {
    email: '',
    includeCreated: false,
    out: '',
    credentials: null,
    projectId: null,
  };
  for (const a of argv) {
    if (a.startsWith('--email=')) out.email = a.slice('--email='.length).trim();
    else if (a === '--include-created') out.includeCreated = true;
    else if (a.startsWith('--out=')) out.out = a.slice('--out='.length).trim();
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

function isAssignedToUser(data, uid) {
  const a = data.assignedTo;
  if (a == null) return false;
  if (Array.isArray(a)) return a.includes(uid);
  if (typeof a === 'string') return a === uid;
  return false;
}

/** Firestore stores enum as e.g. `TaskStatus.todo` — shorten for console output */
function shortEnum(s) {
  if (typeof s !== 'string') return s;
  return s.replace(/^Task(Status|Priority)\./, '');
}

function dueMs(data) {
  const d = data.dueDate;
  if (d && typeof d.toDate === 'function') {
    try {
      return d.toDate().getTime();
    } catch {
      return 0;
    }
  }
  return 0;
}

/** Print multi-line text with a fixed indent (preserves newlines). */
function printIndentedBlock(label, text) {
  const raw = typeof text === 'string' ? text : '';
  const trimmed = raw.trim();
  console.log(`${label}`);
  if (!trimmed) {
    console.log('  (aucune description enregistrée dans Firestore)');
    return;
  }
  for (const line of raw.split('\n')) {
    console.log(`  ${line}`);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.email) {
    throw new Error('Missing required --email=...');
  }

  initFirebase(args);
  const db = admin.firestore();

  const userDoc = await findUserByEmail(db, args.email);
  if (!userDoc) {
    throw new Error(`No user found with email: ${args.email}`);
  }
  const uid = userDoc.id;
  const userData = userDoc.data() || {};
  const displayName =
    `${userData.first_name || ''} ${userData.last_name || ''}`.trim() || args.email;

  const byId = new Map();

  const q1 = await db.collection('tasks').where('assignedTo', 'array-contains', uid).get();
  q1.docs.forEach((d) => byId.set(d.id, d));

  let q2;
  try {
    q2 = await db.collection('tasks').where('assignedTo', '==', uid).get();
  } catch (e) {
    q2 = { docs: [], empty: true };
  }
  if (q2.docs) {
    q2.docs.forEach((d) => byId.set(d.id, d));
  }

  if (args.includeCreated) {
    const q3 = await db.collection('tasks').where('createdBy', '==', uid).get();
    q3.docs.forEach((d) => byId.set(d.id, d));
  }

  const docs = [...byId.values()].sort((a, b) => dueMs(b.data()) - dueMs(a.data()));

  const rows = docs.map((doc) => {
    const data = doc.data() || {};
    const assigned = isAssignedToUser(data, uid);
    const created = data.createdBy === uid;
    let role = '—';
    if (assigned && created) role = 'assigned + created';
    else if (assigned) role = 'assigned';
    else if (created) role = 'created only';

    return {
      id: doc.id,
      title: data.title || '',
      description: typeof data.description === 'string' ? data.description : '',
      status: shortEnum(data.status || ''),
      priority: shortEnum(data.priority || ''),
      dueDate: serializeValue(data.dueDate),
      isDraft: data.isDraft === true,
      isArchived: data.isArchived === true,
      labels: Array.isArray(data.labels) ? data.labels : [],
      location: data.location && String(data.location).trim() ? String(data.location).trim() : '',
      role,
      assignedTo: serializeValue(data.assignedTo),
      createdBy: data.createdBy || '',
    };
  });

  console.log(`Tasks for ${displayName} <${args.email}>`);
  console.log(`User ID: ${uid}`);
  console.log(`Project: ${admin.app().options.projectId || 'unknown'}`);
  console.log(`Total task documents: ${rows.length}`);
  console.log('Pour chaque tâche : consigne = champ `description` dans Firestore.\n');

  for (const r of rows) {
    console.log('—'.repeat(72));
    console.log(`ID:       ${r.id}`);
    console.log(`Titre:    ${r.title}`);
    printIndentedBlock('Consigne (description) :', r.description);
    if (r.location) console.log(`Lieu:     ${r.location}`);
    console.log(`Statut:   ${r.status}   Priorité: ${r.priority}`);
    console.log(`Échéance: ${r.dueDate || 'n/a'}`);
    console.log(`Rôle:     ${r.role}`);
    if (r.isDraft) console.log(`Brouillon: oui`);
    if (r.isArchived) console.log(`Archivée: oui`);
    if (r.labels.length) console.log(`Labels:   ${r.labels.join(', ')}`);
  }
  console.log('—'.repeat(72));

  if (args.out) {
    const payload = {
      generatedAt: new Date().toISOString(),
      user: {
        id: uid,
        email: args.email,
        name: displayName,
      },
      tasks: docs.map((doc) => ({
        id: doc.id,
        path: `tasks/${doc.id}`,
        data: serializeValue(doc.data()),
      })),
    };
    const outPath = path.resolve(args.out);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, JSON.stringify(payload, null, 2), 'utf8');
    console.log(`\nWrote JSON: ${outPath}`);
  }
}

main().catch((err) => {
  console.error('Script failed:', err.message || err);
  process.exit(1);
});
