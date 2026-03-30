#!/usr/bin/env node
/**
 * Scan Firestore for form-related field ids and response keys.
 *
 * Prerequisites:
 *   1. From repo root: npm install   (firebase-admin is listed in package.json)
 *   2. Credentials (same convention as other repo scripts, e.g. cleanup_orphaned_timesheets.js):
 *      - Prefer serviceAccountKey.json in the project root (gitignored).
 *      - Or set GOOGLE_APPLICATION_CREDENTIALS, or pass --credentials=PATH.
 *
 * Usage:
 *   node scripts/discover_form_fields.mjs
 *
 * Options:
 *   --credentials=PATH   Service account JSON (overrides default serviceAccountKey.json)
 *   --project=ID         Firebase project id (optional if key contains project_id)
 *   --batch=500          Page size per query (default 500)
 *   --max-docs=N         Stop after N documents per collection (0 = no limit)
 *   --json=FILE          Write full report as JSON
 *   --skip-responses     Do not scan form_responses
 *   --skip-form          Do not scan form
 *   --skip-templates     Do not scan form_templates
 */

import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function validateServiceAccountJson(obj, jsonPath) {
  const required = ['type', 'project_id', 'private_key', 'client_email'];
  const missing = required.filter((k) => obj[k] == null || obj[k] === '');
  if (missing.length) {
    console.error(`Invalid service account file (missing: ${missing.join(', ')}): ${jsonPath}`);
    process.exit(1);
  }
  if (obj.type !== 'service_account') {
    console.error(
      `Expected type "service_account" in ${jsonPath}, got "${obj.type}". Use a Firebase/GCP service account key, not an OAuth client secret.`,
    );
    process.exit(1);
  }
  const pk = String(obj.private_key);
  if (!pk.includes('BEGIN PRIVATE KEY') && !pk.includes('BEGIN RSA PRIVATE KEY')) {
    console.error(
      `Invalid private_key in ${jsonPath} (no PEM block). Re-download the key from Firebase Console.`,
    );
    process.exit(1);
  }
}

function printFirestoreAuthFailure(err) {
  const reason = err?.reason || err?.details || '';
  const full = String(err?.message || err);
  console.error('\n--- Firestore authentication failed ---');
  console.error(full);
  if (reason) console.error('Detail:', reason);
  if (isLikelyClockSkewMessage(full)) printClockSkewHint();
  console.error(`
Typical causes of UNAUTHENTICATED / ACCESS_TOKEN_EXPIRED with a service account JSON:

  0. firebase login does NOT fix this script — that only logs in the Firebase CLI.
     Node uses serviceAccountKey.json or Application Default Credentials (gcloud), not "firebase login".

  1. Stale GOOGLE_APPLICATION_CREDENTIALS — If it pointed to an old gcloud user JSON, this script
     now overrides it to serviceAccountKey.json for the process. If it still fails, regenerate the key.

  2. Key revoked or expired — Regenerate
     Firebase Console → Project settings → Service accounts → Generate new private key
     Replace serviceAccountKey.json (old files stop working if the key was deleted in GCP).

  3. Wrong system clock — Fix Windows date & time (set automatic / sync now).

  4. Wrong Firebase project — Open serviceAccountKey.json and check "project_id" matches
     the project whose Firestore you want (e.g. alluwal-academy vs alluwal-dev).
     You can override with: node scripts/discover_form_fields.mjs --project=YOUR_PROJECT_ID

  5. IAM — In Google Cloud Console (same project), the "client_email" in the JSON needs
     permission to use Firestore (e.g. Cloud Datastore User, or a role that includes it).

  6. Optional: use gcloud user ADC instead of a key (no JSON file):
     gcloud auth application-default login
     Then temporarily rename serviceAccountKey.json so this script falls through to ADC.
`);
}

function isFirestoreAuthError(err) {
  const code = err?.code;
  const r = String(err?.reason || '');
  return code === 16 || r === 'ACCESS_TOKEN_EXPIRED' || /UNAUTHENTICATED|invalid authentication credential/i.test(String(err?.message || ''));
}

/** Google returns this when local clock is far from real time (JWT iat/exp "unreasonable"). */
function isLikelyClockSkewMessage(msg) {
  const s = String(msg || '');
  return (
    /reasonable timeframe/i.test(s) ||
    /iat and exp/i.test(s) ||
    /invalid_grant.*jwt/i.test(s) ||
    /Token must be a short-lived token/i.test(s)
  );
}

function printClockSkewHint() {
  console.error(`
>>> Fix your PC clock first (this error is usually NOT a bad Firebase key):
    Google rejected the JWT because "iat" / "exp" are outside an allowed window.

    Windows: Settings → Time & language → Date & time
      - Turn ON "Set time automatically" and "Set time zone automatically"
      - Click "Sync now"
    Also check: wrong BIOS time, dual-boot drift, corporate VPN or VM host clock skew.
    After syncing, run this script again. Only if it still fails, regenerate the service account key.
`);
}

function parseArgs(argv) {
  const out = {
    credentials: null,
    projectId: null,
    batch: 500,
    maxDocs: 0,
    jsonOut: null,
    skipResponses: false,
    skipForm: false,
    skipTemplates: false,
  };
  for (const a of argv) {
    if (a.startsWith('--credentials=')) out.credentials = a.slice('--credentials='.length);
    else if (a.startsWith('--project=')) out.projectId = a.slice('--project='.length);
    else if (a.startsWith('--batch=')) out.batch = Math.max(1, parseInt(a.slice('--batch='.length), 10) || 500);
    else if (a.startsWith('--max-docs=')) out.maxDocs = Math.max(0, parseInt(a.slice('--max-docs='.length), 10) || 0);
    else if (a.startsWith('--json=')) out.jsonOut = a.slice('--json='.length);
    else if (a === '--skip-responses') out.skipResponses = true;
    else if (a === '--skip-form') out.skipForm = true;
    else if (a === '--skip-templates') out.skipTemplates = true;
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

  const initWithJson = (jsonPath, label) => {
    const resolved = path.resolve(jsonPath);
    const serviceAccount = JSON.parse(fs.readFileSync(resolved, 'utf8'));
    validateServiceAccountJson(serviceAccount, resolved);
    const projectId = args.projectId || serviceAccount.project_id || defaultProject;
    if (args.projectId && serviceAccount.project_id && args.projectId !== serviceAccount.project_id) {
      console.error(
        `[warn] --project=${args.projectId} overrides JSON project_id=${serviceAccount.project_id}`,
      );
    }

    // gRPC / google-auth sometimes consult GOOGLE_APPLICATION_CREDENTIALS even when
    // credential.cert() is passed. A stale ADC path (e.g. expired gcloud user creds) causes
    // ACCESS_TOKEN_EXPIRED while the service-account JSON is fine — align env to this file.
    const prevAdc = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (prevAdc && path.resolve(prevAdc) !== resolved) {
      console.error('[warn] GOOGLE_APPLICATION_CREDENTIALS pointed at a different file:');
      console.error(`      was: ${prevAdc}`);
      console.error(`      overriding for this Node process to: ${resolved}`);
    }
    process.env.GOOGLE_APPLICATION_CREDENTIALS = resolved;

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
    console.error(`✅ Firebase Admin initialized (${label})`);
    console.error(`   Firestore / Admin projectId: ${projectId}`);
    console.error(`   Service account: ${serviceAccount.client_email}`);
    console.error(`   GOOGLE_APPLICATION_CREDENTIALS (this process): ${resolved}\n`);
  };

  if (args.credentials) {
    if (!fs.existsSync(args.credentials)) {
      console.error(`Credentials file not found: ${args.credentials}`);
      process.exit(1);
    }
    initWithJson(args.credentials, args.credentials);
    return;
  }

  // Same as scripts/cleanup_orphaned_timesheets.js, scripts/create_firestore_indexes.js, etc.
  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  const cwdKeyPath = path.join(process.cwd(), 'serviceAccountKey.json');

  if (fs.existsSync(serviceAccountPath)) {
    initWithJson(serviceAccountPath, 'serviceAccountKey.json at project root');
    return;
  }
  if (
    fs.existsSync(cwdKeyPath) &&
    path.resolve(cwdKeyPath) !== path.resolve(serviceAccountPath)
  ) {
    initWithJson(cwdKeyPath, 'serviceAccountKey.json in cwd');
    return;
  }

  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    try {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: defaultProject,
      });
      console.error('✅ Firebase Admin initialized (GOOGLE_APPLICATION_CREDENTIALS)\n');
      return;
    } catch (e) {
      console.error(
        'GOOGLE_APPLICATION_CREDENTIALS is set but application default failed:',
        e.message,
      );
    }
  }

  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: defaultProject,
    });
    console.error('✅ Firebase Admin initialized (application default credentials)\n');
    return;
  } catch (e) {
    console.error('Credentials not found. Do one of:');
    console.error(
      '  1. Place serviceAccountKey.json in the project root (alluvial_academy/serviceAccountKey.json)',
    );
    console.error('     — same as other scripts under scripts/ (see .gitignore).');
    console.error('  2. Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path.');
    console.error('  3. Pass --credentials=PATH');
    console.error('  4. Or: gcloud auth application-default login');
    console.error('Details:', e.message);
    process.exit(1);
  }
}

function previewValue(value) {
  if (value === null || value === undefined) return String(value);
  if (typeof value === 'boolean' || typeof value === 'number') return String(value);
  if (typeof value === 'string') return value.length > 120 ? `${value.slice(0, 117)}...` : value;
  if (Array.isArray(value)) {
    const s = JSON.stringify(value);
    return s.length > 120 ? `${s.slice(0, 117)}...` : s;
  }
  if (value && typeof value.toDate === 'function') {
    try {
      return `Timestamp(${value.toDate().toISOString()})`;
    } catch {
      return '[Timestamp]';
    }
  }
  if (typeof value === 'object') {
    const s = JSON.stringify(value);
    return s.length > 120 ? `${s.slice(0, 117)}...` : s;
  }
  return String(value);
}

function recordField(statsMap, key, value) {
  let s = statsMap.get(key);
  if (!s) {
    s = { count: 0, types: new Set(), samples: [] };
    statsMap.set(key, s);
  }
  s.count += 1;
  let typeTag = value === null || value === undefined ? 'null' : typeof value;
  if (Array.isArray(value)) typeTag = 'array';
  else if (value && typeof value.toDate === 'function') typeTag = 'firestore_timestamp';
  s.types.add(typeTag);
  const pv = previewValue(value);
  if (s.samples.length < 5 && !s.samples.includes(pv)) s.samples.push(pv);
}

function mergeResponseMaps(data, statsMap) {
  for (const field of ['responses', 'answers']) {
    const m = data[field];
    if (m && typeof m === 'object' && !Array.isArray(m)) {
      for (const [k, v] of Object.entries(m)) {
        recordField(statsMap, k, v);
      }
    }
  }
}

/** Field ids from form template / legacy form `fields` (Map or List). */
function extractSchemaFieldIds(fields) {
  const ids = new Set();
  if (fields == null) return ids;
  if (Array.isArray(fields)) {
    for (const f of fields) {
      if (f && typeof f === 'object') {
        const id = f.id ?? f.fieldId ?? f.key;
        if (id != null && String(id).length > 0) ids.add(String(id));
      }
    }
  } else if (typeof fields === 'object') {
    for (const k of Object.keys(fields)) ids.add(k);
  }
  return ids;
}

async function paginateCollection(db, collectionName, batchSize, maxDocs, onDoc) {
  let lastDoc = null;
  let total = 0;
  const base = db.collection(collectionName).orderBy(admin.firestore.FieldPath.documentId());

  while (true) {
    let q = base.limit(batchSize);
    if (lastDoc) q = q.startAfter(lastDoc);
    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      if (maxDocs > 0 && total >= maxDocs) return total;
      await onDoc(doc);
      total += 1;
    }
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < batchSize) break;
  }
  return total;
}

function statsToPlain(statsMap) {
  const obj = {};
  const keys = [...statsMap.keys()].sort();
  for (const k of keys) {
    const s = statsMap.get(k);
    obj[k] = {
      occurrenceCount: s.count,
      valueTypes: [...s.types].sort(),
      sampleValues: s.samples,
    };
  }
  return obj;
}

function printSection(title, statsMap) {
  console.log(`\n=== ${title} (${statsMap.size} unique keys) ===`);
  const keys = [...statsMap.keys()].sort();
  for (const k of keys) {
    const s = statsMap.get(k);
    console.log(
      `  ${k}\n    count: ${s.count}  types: ${[...s.types].join(', ')}\n    samples: ${s.samples.join(' | ')}`,
    );
  }
}

/** Confirms JWT → access token works (isolates Firestore vs credential issues). */
async function verifyServiceAccountOAuthExchange() {
  const adc = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!adc || !fs.existsSync(adc)) return;
  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(adc, 'utf8'));
  } catch {
    return;
  }
  if (parsed.type !== 'service_account') return;
  try {
    const { GoogleAuth } = await import('google-auth-library');
    const auth = new GoogleAuth({
      credentials: parsed,
      projectId: parsed.project_id,
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    });
    const client = await auth.getClient();
    const res = await client.getAccessToken();
    if (!res.token) throw new Error('empty token');
    console.error('✅ OAuth access token OK (service account → Google token endpoint)\n');
  } catch (e) {
    const msg = e.message || String(e);
    console.error('⚠ OAuth token exchange failed (google-auth-library):', msg);
    if (isLikelyClockSkewMessage(msg)) printClockSkewHint();
    else
      console.error('  → Regenerate serviceAccountKey.json and/or fix Windows date/time.\n');
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  initFirebase(args);
  await verifyServiceAccountOAuthExchange();

  const db = admin.firestore();
  const report = {
    generatedAt: new Date().toISOString(),
    formResponses: { documentsScanned: 0, fieldStats: {} },
    form: { documentsScanned: 0, fieldIdsByDoc: {}, allFieldIds: [] },
    formTemplates: { documentsScanned: 0, fieldIdsByDoc: {}, allFieldIds: [] },
  };

  const responseStats = new Map();

  if (!args.skipResponses) {
    console.error('Scanning form_responses...');
    const n = await paginateCollection(
      db,
      'form_responses',
      args.batch,
      args.maxDocs,
      (doc) => {
        const data = doc.data() || {};
        mergeResponseMaps(data, responseStats);
      },
    );
    report.formResponses.documentsScanned = n;
    report.formResponses.fieldStats = statsToPlain(responseStats);
    console.error(`  done: ${n} documents`);
    printSection('form_responses (responses + answers keys)', responseStats);
  }

  const formSchemaIds = new Set();
  const formPerDoc = {};

  if (!args.skipForm) {
    console.error('\nScanning form...');
    const n = await paginateCollection(db, 'form', args.batch, args.maxDocs, (doc) => {
      const data = doc.data() || {};
      const ids = extractSchemaFieldIds(data.fields);
      formPerDoc[doc.id] = [...ids].sort();
      for (const id of ids) formSchemaIds.add(id);
    });
    report.form.documentsScanned = n;
    report.form.fieldIdsByDoc = formPerDoc;
    report.form.allFieldIds = [...formSchemaIds].sort();
    console.error(`  done: ${n} documents, ${formSchemaIds.size} unique field ids across form definitions`);
    console.log('\n=== form (schema field ids) ===');
    for (const id of [...formSchemaIds].sort()) console.log(`  ${id}`);
  }

  const templateSchemaIds = new Set();
  const templatePerDoc = {};

  if (!args.skipTemplates) {
    console.error('\nScanning form_templates...');
    const n = await paginateCollection(
      db,
      'form_templates',
      args.batch,
      args.maxDocs,
      (doc) => {
        const data = doc.data() || {};
        const ids = extractSchemaFieldIds(data.fields);
        templatePerDoc[doc.id] = [...ids].sort();
        for (const id of ids) templateSchemaIds.add(id);
      },
    );
    report.formTemplates.documentsScanned = n;
    report.formTemplates.fieldIdsByDoc = templatePerDoc;
    report.formTemplates.allFieldIds = [...templateSchemaIds].sort();
    console.error(`  done: ${n} documents, ${templateSchemaIds.size} unique field ids across templates`);
    console.log('\n=== form_templates (schema field ids) ===');
    for (const id of [...templateSchemaIds].sort()) console.log(`  ${id}`);
  }

  // Keys that appear in responses but not in any scanned schema (best-effort)
  if (!args.skipResponses && (formSchemaIds.size > 0 || templateSchemaIds.size > 0)) {
    const schemaUnion = new Set([...formSchemaIds, ...templateSchemaIds]);
    const orphan = [...responseStats.keys()].filter((k) => !schemaUnion.has(k)).sort();
    report.formResponses.keysNotInScannedSchema = orphan;
    console.log('\n=== form_responses keys not found in scanned form + form_templates field ids ===');
    if (orphan.length === 0) console.log('  (none)');
    else orphan.forEach((k) => console.log(`  ${k}`));
  }

  if (args.jsonOut) {
    const outPath = path.isAbsolute(args.jsonOut)
      ? args.jsonOut
      : path.join(process.cwd(), args.jsonOut);
    fs.writeFileSync(outPath, JSON.stringify(report, null, 2), 'utf8');
    console.error(`\nWrote JSON report: ${outPath}`);
  }

  console.error('\nFinished.');
}

main().catch((err) => {
  if (isFirestoreAuthError(err)) printFirestoreAuthFailure(err);
  else console.error(err);
  process.exit(1);
});
