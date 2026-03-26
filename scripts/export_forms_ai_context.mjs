#!/usr/bin/env node
/**
 * Export ALL form definitions (questions, labels, types, options) + optional response samples
 * for AI context (improving Flutter admin/teacher screens, labels, validation).
 *
 * Outputs:
 *   - forms_ai_context.json  — full structured data
 *   - forms_ai_context.md    — readable digest for pasting into chats
 *
 * Prerequisites: npm install at repo root, serviceAccountKey.json at project root (same as other scripts).
 *
 * Usage:
 *   node scripts/export_forms_ai_context.mjs
 *   node scripts/export_forms_ai_context.mjs --out=./exports/forms_ai
 *   node scripts/export_forms_ai_context.mjs --no-responses
 *   node scripts/export_forms_ai_context.mjs --max-response-docs=2000 --samples-per-template=3
 *
 * Every form entry includes:
 *   - questions[] — normalized list (fieldId, label, type, options, validation, rawField)
 *   - metadata — all top-level fields except `fields` (settings, titles, etc.)
 *   - completeDocument — FULL Firestore document as JSON (includes raw `fields` tree)
 *
 *   --split-forms        Also write one JSON per form under outDir/by_form/
 *   --no-complete-doc    Omit completeDocument (smaller forms_ai_context.json)
 */

import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ── Firebase init (aligned with discover_form_fields.mjs) ──────────────────

function validateServiceAccountJson(obj, jsonPath) {
  const required = ['type', 'project_id', 'private_key', 'client_email'];
  const missing = required.filter((k) => obj[k] == null || obj[k] === '');
  if (missing.length) {
    console.error(`Invalid service account file (missing: ${missing.join(', ')}): ${jsonPath}`);
    process.exit(1);
  }
  if (obj.type !== 'service_account') {
    console.error(`Expected type "service_account" in ${jsonPath}`);
    process.exit(1);
  }
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
    const prevAdc = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (prevAdc && path.resolve(prevAdc) !== resolved) {
      console.error('[warn] Overriding GOOGLE_APPLICATION_CREDENTIALS for this process');
    }
    process.env.GOOGLE_APPLICATION_CREDENTIALS = resolved;
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
    console.error(`✅ Firebase Admin (${label}) projectId=${projectId}\n`);
  };

  if (args.credentials) {
    if (!fs.existsSync(args.credentials)) {
      console.error(`Not found: ${args.credentials}`);
      process.exit(1);
    }
    initWithJson(args.credentials, 'credentials');
    return;
  }
  const rootKey = path.join(__dirname, '..', 'serviceAccountKey.json');
  const cwdKey = path.join(process.cwd(), 'serviceAccountKey.json');
  if (fs.existsSync(rootKey)) {
    initWithJson(rootKey, 'serviceAccountKey.json');
    return;
  }
  if (fs.existsSync(cwdKey) && path.resolve(cwdKey) !== path.resolve(rootKey)) {
    initWithJson(cwdKey, 'cwd serviceAccountKey.json');
    return;
  }
  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: defaultProject,
    });
    console.error('✅ Firebase Admin (application default)\n');
  } catch (e) {
    console.error('Missing credentials. Place serviceAccountKey.json in project root.');
    console.error(e.message);
    process.exit(1);
  }
}

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
    console.error('✅ OAuth access token OK\n');
  } catch (e) {
    console.error('⚠ Token check failed:', e.message);
  }
}

// ── Firestore pagination ─────────────────────────────────────────────────────

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

// ── Serialize / normalize fields ───────────────────────────────────────────

function serializeValue(v, depth = 4) {
  if (v === null || v === undefined) return v;
  if (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean') return v;
  if (depth <= 0) return '[max-depth]';
  if (typeof v.toDate === 'function') {
    try {
      return { _firestoreTimestamp: v.toDate().toISOString() };
    } catch {
      return '[timestamp]';
    }
  }
  if (Array.isArray(v)) return v.slice(0, 100).map((x) => serializeValue(x, depth - 1));
  if (typeof v === 'object') {
    const o = {};
    let i = 0;
    for (const [k, val] of Object.entries(v)) {
      if (i++ >= 60) {
        o._truncatedKeys = true;
        break;
      }
      o[k] = serializeValue(val, depth - 1);
    }
    return o;
  }
  return String(v);
}

/**
 * Deep serialization for full form documents (all questions / nested config).
 * Limits are high so exports stay faithful; raise maxDepth if you hit [max-depth].
 */
function serializeCompleteDocument(v, opts) {
  const maxDepth = opts?.maxDepth ?? 16;
  const maxKeys = opts?.maxKeysPerObject ?? 300;
  const maxArr = opts?.maxArrayLength ?? 2000;

  function walk(x, depth) {
    if (x === null || x === undefined) return x;
    if (typeof x === 'string' || typeof x === 'number' || typeof x === 'boolean') return x;
    if (depth <= 0) return '[max-depth]';
    if (typeof x.toDate === 'function') {
      try {
        return { _firestoreTimestamp: x.toDate().toISOString() };
      } catch {
        return '[timestamp]';
      }
    }
    if (Array.isArray(x)) {
      return x.slice(0, maxArr).map((item) => walk(item, depth - 1));
    }
    if (typeof x === 'object') {
      const o = {};
      let i = 0;
      for (const [k, val] of Object.entries(x)) {
        if (i++ >= maxKeys) {
          o._truncated = `more than ${maxKeys} keys omitted`;
          break;
        }
        o[k] = walk(val, depth - 1);
      }
      return o;
    }
    return String(x);
  }

  return walk(v, maxDepth);
}

function labelFromField(f) {
  return String(
    f.label ??
      f.question ??
      f.title ??
      f.name ??
      f.text ??
      f.labelText ??
      '',
  ).trim();
}

function pickOptions(f) {
  const o = f.options ?? f.choices ?? f.values ?? f.items ?? f.selectOptions;
  if (!o) return null;
  if (Array.isArray(o)) {
    return o
      .slice(0, 250)
      .map((x) =>
        typeof x === 'string'
          ? x
          : x?.label ?? x?.value ?? x?.text ?? x?.title ?? JSON.stringify(x),
      );
  }
  if (typeof o === 'object') {
    return Object.entries(o).map(([k, v]) => `${k}: ${typeof v === 'object' ? JSON.stringify(v).slice(0, 80) : v}`);
  }
  return null;
}

function pickValidation(f) {
  const keys = [
    'min',
    'max',
    'minLength',
    'maxLength',
    'pattern',
    'regex',
    'step',
    'multiple',
  ];
  const v = {};
  for (const k of keys) {
    if (f[k] !== undefined && f[k] !== null) v[k] = f[k];
  }
  return Object.keys(v).length ? v : null;
}

function normalizeQuestion(fieldId, f) {
  return {
    fieldId: String(fieldId),
    label: labelFromField(f) || String(fieldId),
    type: f.type ?? f.fieldType ?? f.inputType ?? f.widget ?? null,
    required: Boolean(f.required ?? f.isRequired ?? f.mandatory),
    placeholder: f.placeholder ?? f.hint ?? null,
    description: f.description ?? f.help ?? f.helperText ?? f.subtitle ?? null,
    options: pickOptions(f),
    defaultValue: f.defaultValue ?? f.default ?? undefined,
    validation: pickValidation(f),
    /** Full field object (depth-limited) for AI to infer custom props */
    rawField: serializeValue(f, 5),
  };
}

function extractQuestions(fields) {
  const out = [];
  if (fields == null) return out;
  if (Array.isArray(fields)) {
    let i = 0;
    for (const f of fields) {
      if (!f || typeof f !== 'object') continue;
      const id = f.id ?? f.fieldId ?? f.key ?? f.field_id;
      const fid = id != null && String(id) !== '' ? String(id) : `__index_${i}`;
      out.push(normalizeQuestion(fid, f));
      i++;
    }
    return out;
  }
  if (typeof fields === 'object') {
    for (const [key, f] of Object.entries(fields)) {
      if (!f || typeof f !== 'object') continue;
      out.push(normalizeQuestion(key, f));
    }
  }
  return out;
}

function displayTitleForDoc(docId, data) {
  const d = data || {};
  return String(
    d.title ??
      d.name ??
      d.formTitle ??
      d.templateTitle ??
      d.displayName ??
      d.label ??
      docId,
  );
}

function formMetadata(data) {
  const skip = new Set(['fields']);
  const meta = {};
  for (const [k, v] of Object.entries(data || {})) {
    if (skip.has(k)) continue;
    meta[k] = serializeValue(v, 3);
  }
  return meta;
}

function buildFormExport(source, collection, doc, exportOpts) {
  const data = doc.data() || {};
  const questions = extractQuestions(data.fields);
  const base = {
    source,
    firestoreCollection: collection,
    firestoreDocumentId: doc.id,
    displayTitle: displayTitleForDoc(doc.id, data),
    questionCount: questions.length,
    metadata: formMetadata(data),
    /** Normalized rows — one per input; use for tables and response key mapping */
    questions,
  };
  if (exportOpts?.includeCompleteDocument !== false) {
    /** Entire Firestore document including raw `fields` (all builder props, order, sections) */
    base.completeDocument = serializeCompleteDocument(data, exportOpts?.completeDocOpts);
  }
  return base;
}

// ── Field index across all forms ────────────────────────────────────────────

function mergeFieldIndex(index, formExport) {
  for (const q of formExport.questions) {
    const id = q.fieldId;
    if (!index[id]) {
      index[id] = {
        fieldId: id,
        labels: new Set(),
        types: new Set(),
        usedIn: [],
      };
    }
    const e = index[id];
    if (q.label) e.labels.add(q.label);
    if (q.type) e.types.add(String(q.type));
    e.usedIn.push({
      displayTitle: formExport.displayTitle,
      firestoreDocumentId: formExport.firestoreDocumentId,
      collection: formExport.firestoreCollection,
    });
  }
}

function finalizeFieldIndex(index) {
  const out = {};
  for (const [id, v] of Object.entries(index)) {
    out[id] = {
      fieldId: id,
      labelsSeen: [...v.labels].sort(),
      typesSeen: [...v.types].sort(),
      usedInForms: v.usedIn,
    };
  }
  return out;
}

// ── Response samples (by templateId / formId) ──────────────────────────────

function truncateStr(s, max = 400) {
  if (typeof s !== 'string') return s;
  return s.length <= max ? s : `${s.slice(0, max)}…`;
}

function sanitizeResponsesForSample(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const o = {};
  let n = 0;
  for (const [k, v] of Object.entries(raw)) {
    if (n++ >= 120) {
      o._note = 'truncated keys at 120';
      break;
    }
    if (v === null || v === undefined) o[k] = v;
    else if (typeof v === 'string') o[k] = truncateStr(v, 500);
    else if (typeof v === 'number' || typeof v === 'boolean') o[k] = v;
    else if (Array.isArray(v)) o[k] = serializeValue(v, 3);
    else if (typeof v === 'object' && v !== null) {
      const s = JSON.stringify(v);
      o[k] = s.length > 400 ? `${s.slice(0, 400)}…` : v;
    } else o[k] = String(v);
  }
  return o;
}

async function collectResponseSamples(db, opts) {
  const { batchSize, maxResponseDocs, samplesPerTemplate, samplesPerForm } = opts;
  /** @type {Map<string, { templateKey: string, samples: any[], count: number }>} */
  const groups = new Map();
  let scanned = 0;

  await paginateCollection(db, 'form_responses', batchSize, maxResponseDocs, (doc) => {
    scanned++;
    const data = doc.data() || {};
    const templateId = (data.templateId && String(data.templateId)) || '';
    const formId = (data.formId && String(data.formId)) || '';
    const key = templateId
      ? `template:${templateId}`
      : formId
        ? `form:${formId}`
        : `doc:${doc.id}`;

    let g = groups.get(key);
    if (!g) {
      g = {
        templateKey: key,
        templateId: templateId || null,
        legacyFormId: formId || null,
        formTitle: (data.formTitle ?? data.title ?? '').toString() || null,
        samples: [],
        count: 0,
      };
      groups.set(key, g);
    }
    g.count += 1;
    const limit = templateId ? samplesPerTemplate : samplesPerForm;
    if (g.samples.length >= limit) return;

    const responses = data.responses ?? data.answers ?? {};
    g.samples.push({
      responseDocumentId: doc.id,
      userId: data.userId ?? null,
      shiftId: data.shiftId ?? data.shift_id ?? null,
      status: data.status ?? null,
      submittedAt: data.submittedAt ? serializeValue(data.submittedAt) : null,
      responses: sanitizeResponsesForSample(
        typeof responses === 'object' && !Array.isArray(responses) ? responses : {},
      ),
    });
  });

  return {
    responseDocumentsScanned: scanned,
    groups: [...groups.values()].sort((a, b) => b.count - a.count),
  };
}

// ── Markdown ────────────────────────────────────────────────────────────────

function mdEscape(s) {
  return String(s).replace(/\|/g, '\\|').replace(/\n/g, ' ');
}

function buildMarkdown(ctx) {
  const lines = [];
  lines.push('# Alluvial Academy — forms context for AI');
  lines.push('');
  lines.push(`Generated: ${ctx.generatedAt}`);
  lines.push(`Project: ${ctx.projectId}`);
  lines.push('');
  lines.push('## How to use this');
  lines.push(
    '- **formTemplates** / **legacyForms**: each entry is one Firestore document; **questions** are UI fields.',
  );
  lines.push(
    '- **fieldId** is the key stored under `responses` / `answers` in `form_responses` (numeric ids or snake_case strings).',
  );
  lines.push('- **responseSamples**: example answer shapes per template or legacy form.');
  lines.push('');
  lines.push('## Summary');
  lines.push('');
  lines.push(`| Metric | Value |`);
  lines.push(`|--------|-------|`);
  lines.push(`| form_templates documents | ${ctx.summary.formTemplatesCount} |`);
  lines.push(`| form (legacy) documents | ${ctx.summary.legacyFormsCount} |`);
  lines.push(`| Total questions (rows) | ${ctx.summary.totalQuestions} |`);
  lines.push(`| Distinct fieldIds in schemas | ${ctx.summary.distinctFieldIdsInSchemas} |`);
  lines.push(
    `| form_responses docs scanned (samples) | ${ctx.summary.responseDocumentsScanned} |`,
  );
  lines.push('');

  function sectionForms(title, forms) {
    lines.push(`## ${title}`);
    lines.push('');
    for (const f of forms) {
      lines.push(`### ${mdEscape(f.displayTitle)}`);
      lines.push('');
      lines.push(`- **Firestore**: \`${f.firestoreCollection}/${f.firestoreDocumentId}\``);
      lines.push(`- **Questions**: ${f.questionCount}`);
      if (f.completeDocument) {
        lines.push(
          '- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).',
        );
      }
      lines.push('');
      lines.push(`| # | fieldId | label | type | required |`);
      lines.push(`|---|---------|-------|------|----------|`);
      f.questions.forEach((q, i) => {
        lines.push(
          `| ${i + 1} | \`${mdEscape(q.fieldId)}\` | ${mdEscape(q.label)} | ${mdEscape(q.type ?? '')} | ${q.required ? 'yes' : ''} |`,
        );
      });
      lines.push('');
      const withOpts = f.questions.filter((q) => q.options && q.options.length);
      if (withOpts.length) {
        lines.push('**Options (choice fields)**');
        lines.push('');
        for (const q of withOpts) {
          lines.push(`- **${mdEscape(q.fieldId)}** (${mdEscape(q.label)}): ${q.options.slice(0, 20).join('; ')}${q.options.length > 20 ? '…' : ''}`);
        }
        lines.push('');
      }
      const withDesc = f.questions.filter((q) => q.description || q.placeholder);
      if (withDesc.length) {
        lines.push('**Descriptions / placeholders**');
        lines.push('');
        for (const q of withDesc) {
          const bits = [];
          if (q.description) bits.push(`desc: ${mdEscape(q.description)}`);
          if (q.placeholder) bits.push(`placeholder: ${mdEscape(q.placeholder)}`);
          lines.push(`- **${mdEscape(q.fieldId)}**: ${bits.join(' · ')}`);
        }
        lines.push('');
      }
    }
  }

  sectionForms('Form templates (`form_templates`)', ctx.formTemplates);
  sectionForms('Legacy forms (`form`)', ctx.legacyForms);

  if (ctx.responseSamples?.groups?.length) {
    lines.push('## Response samples (by template / form)');
    lines.push('');
    for (const g of ctx.responseSamples.groups.slice(0, 80)) {
      lines.push(`### ${mdEscape(g.templateKey)} (${g.count} docs)`);
      if (g.formTitle) lines.push(`formTitle: ${mdEscape(g.formTitle)}`);
      lines.push('');
      for (const s of g.samples) {
        lines.push(`- sample \`${s.responseDocumentId}\`: ${Object.keys(s.responses || {}).length} keys`);
      }
      lines.push('');
    }
    if (ctx.responseSamples.groups.length > 80) {
      lines.push(`_… ${ctx.responseSamples.groups.length - 80} more groups in JSON_`);
      lines.push('');
    }
  }

  lines.push('## Global fieldId index (merge labels across forms)');
  lines.push('');
  const idxEntries = Object.values(ctx.fieldIdIndex || {}).sort((a, b) =>
    a.fieldId.localeCompare(b.fieldId, undefined, { numeric: true }),
  );
  lines.push(`| fieldId | labels (distinct) | types | #forms |`);
  lines.push(`|---------|-------------------|-------|--------|`);
  for (const row of idxEntries.slice(0, 400)) {
    lines.push(
      `| \`${mdEscape(row.fieldId)}\` | ${mdEscape(row.labelsSeen.join(' / '))} | ${mdEscape(row.typesSeen.join(','))} | ${row.usedInForms.length} |`,
    );
  }
  if (idxEntries.length > 400) {
    lines.push(`| … | ${idxEntries.length - 400} more in JSON | | |`);
  }
  lines.push('');

  return lines.join('\n');
}

// ── CLI ─────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const out = {
    credentials: null,
    projectId: null,
    batch: 400,
    outDir: path.join(process.cwd(), 'forms_ai_export'),
    includeResponses: true,
    maxResponseDocs: 4000,
    samplesPerTemplate: 2,
    samplesPerForm: 2,
    includeCompleteDocument: true,
    splitForms: false,
    completeDocMaxDepth: 16,
    completeDocMaxKeys: 300,
    completeDocMaxArray: 2000,
  };
  for (const a of argv) {
    if (a.startsWith('--credentials=')) out.credentials = a.slice(14);
    else if (a.startsWith('--project=')) out.projectId = a.slice(10);
    else if (a.startsWith('--batch=')) out.batch = Math.max(50, parseInt(a.slice(8), 10) || 400);
    else if (a.startsWith('--out=')) out.outDir = path.resolve(a.slice(6));
    else if (a === '--no-responses') out.includeResponses = false;
    else if (a === '--no-complete-doc') out.includeCompleteDocument = false;
    else if (a === '--split-forms') out.splitForms = true;
    else if (a.startsWith('--complete-doc-depth='))
      out.completeDocMaxDepth = Math.max(4, parseInt(a.slice(21), 10) || 16);
    else if (a.startsWith('--max-response-docs='))
      out.maxResponseDocs = Math.max(0, parseInt(a.slice(20), 10) || 0);
    else if (a.startsWith('--samples-per-template='))
      out.samplesPerTemplate = Math.max(0, parseInt(a.slice(23), 10) || 2);
    else if (a.startsWith('--samples-per-form='))
      out.samplesPerForm = Math.max(0, parseInt(a.slice(19), 10) || 2);
  }
  return out;
}

function safeFormFilename(collection, docId) {
  const safe = docId.replace(/[^a-zA-Z0-9._-]+/g, '_');
  return `${collection}__${safe}.json`;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  initFirebase(args);
  await verifyServiceAccountOAuthExchange();

  const db = admin.firestore();
  const projectId = admin.app().options.projectId || 'unknown';

  const formTemplates = [];
  const legacyForms = [];
  const fieldIndex = {};

  const exportOpts = {
    includeCompleteDocument: args.includeCompleteDocument,
    completeDocOpts: {
      maxDepth: args.completeDocMaxDepth,
      maxKeysPerObject: args.completeDocMaxKeys,
      maxArrayLength: args.completeDocMaxArray,
    },
  };

  console.error('Loading form_templates…');
  await paginateCollection(db, 'form_templates', args.batch, 0, (doc) => {
    formTemplates.push(buildFormExport('form_template', 'form_templates', doc, exportOpts));
  });
  console.error(`  ${formTemplates.length} documents`);

  console.error('Loading form (legacy)…');
  await paginateCollection(db, 'form', args.batch, 0, (doc) => {
    legacyForms.push(buildFormExport('legacy_form', 'form', doc, exportOpts));
  });
  console.error(`  ${legacyForms.length} documents`);

  for (const f of formTemplates) mergeFieldIndex(fieldIndex, f);
  for (const f of legacyForms) mergeFieldIndex(fieldIndex, f);

  const totalQuestions = formTemplates.reduce((n, f) => n + f.questionCount, 0) +
    legacyForms.reduce((n, f) => n + f.questionCount, 0);

  let responseSamples = null;
  let responseDocumentsScanned = 0;
  if (args.includeResponses && args.maxResponseDocs > 0) {
    console.error(
      `Sampling form_responses (max ${args.maxResponseDocs} docs, ${args.samplesPerTemplate} per template)…`,
    );
    responseSamples = await collectResponseSamples(db, {
      batchSize: args.batch,
      maxResponseDocs: args.maxResponseDocs,
      samplesPerTemplate: args.samplesPerTemplate,
      samplesPerForm: args.samplesPerForm,
    });
    responseDocumentsScanned = responseSamples.responseDocumentsScanned;
    console.error(`  scanned ${responseDocumentsScanned} documents`);
  }

  const context = {
    generatedAt: new Date().toISOString(),
    projectId,
    purpose:
      'Full form/question definitions from Firestore for AI-assisted improvements to Flutter admin/teacher UI, labels, validation, and analytics.',
    conventions: {
      responseStorage:
        'Submitted answers live in collection `form_responses`, maps `responses` and/or `answers`, keyed by fieldId.',
      numericFieldIds:
        'Many templates use numeric string fieldIds (timestamp-style ids from the form builder).',
      templatesVsLegacy:
        'New system: `form_templates` + templateId on responses. Old: `form` + formId.',
      perFormShape:
        'Each form has: metadata (doc without fields), questions[] (normalized), completeDocument (entire Firestore doc including raw fields).',
    },
    summary: {
      formTemplatesCount: formTemplates.length,
      legacyFormsCount: legacyForms.length,
      totalQuestions,
      distinctFieldIdsInSchemas: Object.keys(fieldIndex).length,
      responseDocumentsScanned,
    },
    formTemplates,
    legacyForms,
    fieldIdIndex: finalizeFieldIndex(fieldIndex),
    responseSamples,
  };

  if (!fs.existsSync(args.outDir)) {
    fs.mkdirSync(args.outDir, { recursive: true });
  }
  const jsonPath = path.join(args.outDir, 'forms_ai_context.json');
  const mdPath = path.join(args.outDir, 'forms_ai_context.md');

  fs.writeFileSync(jsonPath, JSON.stringify(context, null, 2), 'utf8');
  fs.writeFileSync(mdPath, buildMarkdown(context), 'utf8');

  console.error(`\nWrote:\n  ${jsonPath}\n  ${mdPath}`);

  if (args.splitForms) {
    const byFormDir = path.join(args.outDir, 'by_form');
    fs.mkdirSync(byFormDir, { recursive: true });
    let n = 0;
    for (const f of formTemplates) {
      const name = safeFormFilename('form_templates', f.firestoreDocumentId);
      fs.writeFileSync(path.join(byFormDir, name), JSON.stringify(f, null, 2), 'utf8');
      n++;
    }
    for (const f of legacyForms) {
      const name = safeFormFilename('form', f.firestoreDocumentId);
      fs.writeFileSync(path.join(byFormDir, name), JSON.stringify(f, null, 2), 'utf8');
      n++;
    }
    console.error(`  ${byFormDir}/ (${n} per-form JSON files)`);
  }

  console.error(
    `\nEach form includes questions[] + completeDocument (full Firestore). Use --split-forms for one file per form.`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
