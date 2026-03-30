#!/usr/bin/env node
/**
 * Sample admin form_responses for a given month and produce statistics.
 *
 * Joins each response's templateId/formId to the exported form titles
 * from forms_ai_context.json.
 *
 * Usage:
 *   node scripts/sample_admin_form_responses.mjs --month=2026-03
 *   node scripts/sample_admin_form_responses.mjs --month=2026-02 --out=./tmp/admin_forms_stats.json
 *
 * Output (stdout + optional JSON file):
 *   Per-template: volume, top filled fields, avg text length
 *   Per-admin: total submissions, breakdown by template
 *   Optional keyword tags: incident, parent, schedule, etc.
 *
 * Prerequisites:
 *   - npm install at repo root
 *   - serviceAccountKey.json at project root
 */

import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ── Argument parsing ────────────────────────────────────────────────────────
function parseArgs(argv) {
  const out = {
    month: '',
    out: '',
    credentials: null,
    projectId: null,
    formsContextPath: null,
  };
  for (const a of argv) {
    if (a.startsWith('--month=')) out.month = a.slice('--month='.length).trim();
    else if (a.startsWith('--out=')) out.out = a.slice('--out='.length).trim();
    else if (a.startsWith('--credentials=')) out.credentials = a.slice('--credentials='.length).trim();
    else if (a.startsWith('--project=')) out.projectId = a.slice('--project='.length).trim();
    else if (a.startsWith('--forms-context=')) out.formsContextPath = a.slice('--forms-context='.length).trim();
  }
  if (!out.month) {
    const now = new Date();
    out.month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    console.error(`[info] No --month specified, defaulting to ${out.month}`);
  }
  return out;
}

// ── Firebase init (same pattern as other scripts) ───────────────────────────
function initFirebase(args) {
  if (admin.apps.length) return;
  const defaultProject =
    args.projectId ||
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    'alluwal-academy';

  const candidates = [
    args.credentials,
    path.join(__dirname, '..', 'serviceAccountKey.json'),
    path.join(__dirname, '..', 'service-account-key.json'),
  ].filter(Boolean);

  for (const candidate of candidates) {
    const resolved = path.resolve(candidate);
    if (fs.existsSync(resolved)) {
      const sa = JSON.parse(fs.readFileSync(resolved, 'utf8'));
      const projectId = args.projectId || sa.project_id || defaultProject;
      admin.initializeApp({
        credential: admin.credential.cert(sa),
        projectId,
      });
      console.error(`Firebase Admin init OK — project=${projectId}\n`);
      return;
    }
  }
  console.error('No service account key found. Place serviceAccountKey.json at repo root.');
  process.exit(1);
}

// ── Keyword tagging (lightweight, no LLM) ───────────────────────────────────
const KEYWORD_PATTERNS = [
  { tag: 'incident', re: /incident|accident|injury|emergency/i },
  { tag: 'parent', re: /parent|mother|father|guardian|family/i },
  { tag: 'schedule', re: /schedule|timetable|calendar|reschedule/i },
  { tag: 'finance', re: /payment|receipt|bank|salary|advance|paycheck/i },
  { tag: 'discipline', re: /penalty|repercussion|warning|suspend/i },
  { tag: 'excuse', re: /excuse|absent|absence|sick|leave/i },
  { tag: 'goal', re: /goal|objective|plan|target|daily.?plan/i },
  { tag: 'shift_report', re: /end.?of.?shift|shift.?report|checkout|check.?out/i },
];

function extractTags(text) {
  if (!text || typeof text !== 'string') return [];
  const found = new Set();
  for (const { tag, re } of KEYWORD_PATTERNS) {
    if (re.test(text)) found.add(tag);
  }
  return [...found];
}

// ── Load forms context ──────────────────────────────────────────────────────
function loadFormsContext(contextPath) {
  const resolved = path.resolve(
    contextPath || path.join(__dirname, '..', 'forms_ai_export', 'forms_ai_context.json')
  );
  if (!fs.existsSync(resolved)) {
    console.error(`[warn] forms_ai_context.json not found at ${resolved} — template names unavailable`);
    return {};
  }
  const data = JSON.parse(fs.readFileSync(resolved, 'utf8'));
  const map = {};
  for (const form of (data.forms || [])) {
    const id = form.firestoreId || form.id || '';
    // Extract the document ID from paths like "form_templates/XXXXX"
    const docId = id.includes('/') ? id.split('/').pop() : id;
    map[docId] = {
      title: form.title || '(untitled)',
      allowedRoles: form.metadata?.allowedRoles || form.allowedRoles || [],
      questionCount: (form.questions || []).length,
    };
  }
  return map;
}

// ── Main ────────────────────────────────────────────────────────────────────
async function main() {
  const args = parseArgs(process.argv.slice(2));
  initFirebase(args);

  const db = admin.firestore();
  const formsMap = loadFormsContext(args.formsContextPath);
  console.error(`Loaded ${Object.keys(formsMap).length} form templates from context.\n`);

  // 1. Get admin user IDs
  const usersSnap = await db.collection('users')
    .where('user_type', 'in', ['admin', 'super_admin'])
    .get();

  const adminMap = {};
  for (const doc of usersSnap.docs) {
    const d = doc.data();
    const first = (d.first_name || '').trim();
    const last = (d.last_name || '').trim();
    const name = `${first} ${last}`.trim() || d.email || doc.id;
    adminMap[doc.id] = { name, email: d.email || '' };
  }
  const adminIds = new Set(Object.keys(adminMap));
  console.error(`Found ${adminIds.size} admin/super_admin users.\n`);

  // 2. Query form_responses for the month
  const responsesSnap = await db.collection('form_responses')
    .where('yearMonth', '==', args.month)
    .get();

  console.error(`Total form_responses for ${args.month}: ${responsesSnap.docs.length}`);

  // 3. Filter admin responses and aggregate
  const templateStats = {};  // templateId -> { count, fieldFillCounts, textLengths, tags }
  const adminStats = {};     // adminId -> { total, byTemplate }

  let adminResponseCount = 0;

  for (const doc of responsesSnap.docs) {
    const data = doc.data();
    const submitter = data.userId || data.submitted_by;
    if (!submitter || !adminIds.has(submitter)) continue;

    adminResponseCount++;
    const templateId = data.templateId || data.formId || 'unknown';

    // Admin stats
    if (!adminStats[submitter]) {
      adminStats[submitter] = { total: 0, byTemplate: {} };
    }
    adminStats[submitter].total++;
    adminStats[submitter].byTemplate[templateId] =
      (adminStats[submitter].byTemplate[templateId] || 0) + 1;

    // Template stats
    if (!templateStats[templateId]) {
      templateStats[templateId] = {
        count: 0,
        fieldFillCounts: {},
        textLengths: [],
        allTags: {},
      };
    }
    const tpl = templateStats[templateId];
    tpl.count++;

    // Analyze response fields (answers/responses/fields)
    const answers = data.answers || data.responses || data.fields || {};
    const allText = [];

    const processValue = (key, val) => {
      if (val === null || val === undefined || val === '') return;
      tpl.fieldFillCounts[key] = (tpl.fieldFillCounts[key] || 0) + 1;
      if (typeof val === 'string') {
        allText.push(val);
        tpl.textLengths.push(val.length);
      } else if (Array.isArray(val)) {
        allText.push(val.join(' '));
      }
    };

    if (typeof answers === 'object' && !Array.isArray(answers)) {
      for (const [k, v] of Object.entries(answers)) {
        processValue(k, v);
      }
    }

    // Keyword tagging
    const combinedText = allText.join(' ');
    for (const tag of extractTags(combinedText)) {
      tpl.allTags[tag] = (tpl.allTags[tag] || 0) + 1;
    }
  }

  console.error(`Admin responses: ${adminResponseCount}\n`);

  // 4. Build report
  const report = {
    month: args.month,
    totalFormResponses: responsesSnap.docs.length,
    adminResponseCount,
    adminCount: adminIds.size,
    templateBreakdown: [],
    adminBreakdown: [],
  };

  // Template breakdown (sorted by count desc)
  for (const [templateId, stats] of Object.entries(templateStats)) {
    const formInfo = formsMap[templateId] || {};
    const topFields = Object.entries(stats.fieldFillCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([field, count]) => ({ field, count }));

    const avgTextLen = stats.textLengths.length > 0
      ? Math.round(stats.textLengths.reduce((a, b) => a + b, 0) / stats.textLengths.length)
      : 0;

    report.templateBreakdown.push({
      templateId,
      title: formInfo.title || '(unknown template)',
      allowedRoles: formInfo.allowedRoles,
      responseCount: stats.count,
      topFilledFields: topFields,
      avgTextLength: avgTextLen,
      keywordTags: stats.allTags,
    });
  }
  report.templateBreakdown.sort((a, b) => b.responseCount - a.responseCount);

  // Admin breakdown (anonymized: show name but not email in stdout)
  for (const [adminId, stats] of Object.entries(adminStats)) {
    const info = adminMap[adminId] || {};
    const byTemplate = Object.entries(stats.byTemplate).map(([tid, count]) => ({
      templateId: tid,
      title: (formsMap[tid] || {}).title || '(unknown)',
      count,
    }));
    byTemplate.sort((a, b) => b.count - a.count);

    report.adminBreakdown.push({
      adminName: info.name || adminId,
      totalSubmissions: stats.total,
      byTemplate,
    });
  }
  report.adminBreakdown.sort((a, b) => b.totalSubmissions - a.totalSubmissions);

  // 5. Output
  console.log('\n══════════════════════════════════════════════════════');
  console.log(`  ADMIN FORM RESPONSES — ${args.month}`);
  console.log('══════════════════════════════════════════════════════\n');
  console.log(`Total responses (all users): ${report.totalFormResponses}`);
  console.log(`Admin responses:             ${report.adminResponseCount}`);
  console.log(`Admin users:                 ${report.adminCount}\n`);

  console.log('── By Template ──────────────────────────────────────\n');
  for (const t of report.templateBreakdown) {
    console.log(`  ${t.title}  (${t.responseCount} responses)`);
    console.log(`    templateId: ${t.templateId}`);
    if (t.allowedRoles?.length) console.log(`    roles: ${t.allowedRoles.join(', ')}`);
    if (t.topFilledFields.length) {
      console.log(`    top fields: ${t.topFilledFields.map(f => `${f.field}(${f.count})`).join(', ')}`);
    }
    if (t.avgTextLength) console.log(`    avg text length: ${t.avgTextLength} chars`);
    if (Object.keys(t.keywordTags).length) {
      console.log(`    keyword tags: ${Object.entries(t.keywordTags).map(([k, v]) => `${k}(${v})`).join(', ')}`);
    }
    console.log('');
  }

  console.log('── By Admin ─────────────────────────────────────────\n');
  for (const a of report.adminBreakdown) {
    console.log(`  ${a.adminName}: ${a.totalSubmissions} submissions`);
    for (const t of a.byTemplate) {
      console.log(`    - ${t.title}: ${t.count}`);
    }
    console.log('');
  }

  // Write JSON if requested
  if (args.out) {
    const outDir = path.dirname(path.resolve(args.out));
    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(path.resolve(args.out), JSON.stringify(report, null, 2), 'utf8');
    console.error(`\nJSON written to ${path.resolve(args.out)}`);
  }

  process.exit(0);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
