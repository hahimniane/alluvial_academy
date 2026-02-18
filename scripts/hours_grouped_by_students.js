/**
 * Hours Grouped by Students
 *
 * Reads form_responses for a teacher + yearMonth and outputs a summary table:
 *   Student Group | Forms (count + list of form numbers) | Hours per Session | Total Hours
 *
 * - Readiness: field 1754406457284 (students), 1754406414139 (duration).
 * - Daily class reports: student group from linked shift (autofill logic):
 *   shift.student_names / shift.studentNames; if missing, resolve from shift.student_ids
 *   via users (first_name + last_name). Display = known group name or joined names.
 * - Other forms (e.g. weekly/monthly): form_templates.frequency → "Weekly forms" or "Monthly forms".
 *
 * Usage:
 *   node scripts/hours_grouped_by_students.js [yearMonth]              → all teachers
 *   node scripts/hours_grouped_by_students.js <teacher-email> [yearMonth]  → one teacher
 *
 * Examples:
 *   node scripts/hours_grouped_by_students.js 2026-01
 *   node scripts/hours_grouped_by_students.js dmamadousaidou682@gmail.com 2026-01
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

if (!admin.apps.length) {
  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || 'alluwal-academy'
    });
  } else {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'alluwal-academy'
    });
  }
}

const db = admin.firestore();

const READINESS_FORM_ID = 'Ur1oW7SmFsMyNniTf6jS';
const DAILY_REPORT_FORM_ID = 'daily_class_report';

const ARGV = process.argv.slice(2);
const YEAR_MONTH_RE = /^\d{4}-\d{2}$/;

function parseArgs() {
  const a0 = ARGV[0];
  const a1 = ARGV[1];
  let email = null;
  let yearMonth = '2026-01';
  if (a0 && YEAR_MONTH_RE.test(a0)) {
    yearMonth = a0;
    if (a1 && !YEAR_MONTH_RE.test(a1)) email = a1.trim();
  } else if (a0) {
    email = a0.trim();
    yearMonth = (a1 && YEAR_MONTH_RE.test(a1)) ? a1 : '2026-01';
  }
  if (!a0) {
    console.error('Usage: node scripts/hours_grouped_by_students.js [yearMonth]');
    console.error('       node scripts/hours_grouped_by_students.js <teacher-email> [yearMonth]');
    console.error('  With only yearMonth (e.g. 2026-01): run for all teachers.');
    console.error('  With email: run for that teacher only.');
    process.exit(1);
  }
  return { email, yearMonth };
}

const { email: EMAIL, yearMonth: YEAR_MONTH } = parseArgs();

/** Normalize raw student text to display name (full names) */
function normalizeStudentGroup(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const s = raw.trim().toLowerCase();
  if (s.includes('adama')) return 'Adama Jalloh';
  if ((s.includes('mohamed') && s.includes('khadijah')) || (s.includes('khadija') && s.includes('mohamed'))) return 'Mohamed and Khadijah';
  if (s.includes('mamadou') && (s.includes('fatoumata') || s.includes('fatoumeta') || s.includes('aïssata') || s.includes('aissata') || s.includes('assata'))) return 'Mamadou, Fatoumata, and Aïssata';
  return raw.trim();
}

/** From shift student_names array -> display group name (known group or joined names) */
function studentGroupFromShift(studentNames) {
  if (!Array.isArray(studentNames) || studentNames.length === 0) return null;
  const names = studentNames.map(n => (n && typeof n === 'string' ? n.trim() : String(n)).trim()).filter(Boolean);
  if (names.length === 0) return null;
  const s = names.join(' ').toLowerCase();
  if (s.includes('adama')) return 'Adama Jalloh';
  if (s.includes('mohamed') && (s.includes('khadijah') || s.includes('khadija'))) return 'Mohamed and Khadijah';
  if (s.includes('mamadou') && (s.includes('fatoumata') || s.includes('fatoumeta') || s.includes('aïssata') || s.includes('aissata') || s.includes('assata'))) return 'Mamadou, Fatoumata, and Aïssata';
  return names.join(', ');
}

function pickValue(val) {
  if (Array.isArray(val) && val.length > 0) return val[0];
  if (val != null && typeof val === 'string') return val;
  return null;
}

function parseHours(val) {
  if (val == null) return null;
  const n = Number(typeof val === 'string' ? val.replace(',', '.') : val);
  return Number.isFinite(n) ? n : null;
}

/** Get day of month (1-31) for a form: submittedAt, or shift date, or note "05th January" */
function getDayOfMonth(data, shiftCache, shiftId) {
  const submittedAt = data.submittedAt && data.submittedAt.toDate ? data.submittedAt.toDate() : null;
  if (submittedAt) return submittedAt.getDate();
  if (data.formId === DAILY_REPORT_FORM_ID && shiftId) {
    const shift = shiftCache.get(shiftId);
    const start = shift && shift.shift_start && shift.shift_start.toDate ? shift.shift_start.toDate() : null;
    if (start) return start.getDate();
  }
  const note = pickValue((data.responses || {})['1754407509366']) || '';
  const m = note.match(/(\d{1,2})(?:st|nd|rd|th)?\s*January/i);
  if (m) return Math.min(31, Math.max(1, parseInt(m[1], 10)));
  return submittedAt ? submittedAt.getDate() : null;
}

const GROUP_ORDER = [
  'Adama Jalloh',
  'Mohamed and Khadijah',
  'Mamadou, Fatoumata, and Aïssata',
  'Weekly forms',
  'Monthly forms',
  'Per-session forms',
  'On-demand forms',
  'Unspecified (daily_class_report forms)',
  'Unspecified (readiness)',
  'Other'
];

function printTable(ordered, teacherLabel, totalForms) {
  console.log('');
  console.log('Hours Grouped by Students (' + YEAR_MONTH + ')');
  console.log('');
  console.log('Teacher: ' + teacherLabel);
  console.log('Total forms: ' + totalForms);
  console.log('');
  for (const { name, formNumbers, days, hours } of ordered) {
    const count = formNumbers.length;
    const totalHours = hours.reduce((a, b) => a + b, 0);
    const dayList = (days || []).slice();
    const formList = dayList
      .map(d => (d >= 1 && d <= 31 ? d : null))
      .sort((a, b) => (a || 32) - (b || 32))
      .map(d => d != null ? String(d) : '?')
      .join(', ') || formNumbers.slice().sort((a, b) => a - b).join(', ');
    let hoursPerSession;
    const uniq = [...new Set(hours.map(h => Number(h.toFixed(2))))];
    if (uniq.length === 1) {
      const h = uniq[0];
      hoursPerSession = h === 1 ? '1.0 hour each' : h + ' hours each';
    } else {
      const freq = {};
      hours.forEach(h => { const k = Number(h.toFixed(2)); freq[k] = (freq[k] || 0) + 1; });
      hoursPerSession = Object.entries(freq).map(([h, n]) => n + ' x ' + h + ' hour' + (n > 1 ? 's' : '')).join(', ');
    }
    const totalStr = totalHours % 1 === 0 ? totalHours.toFixed(1) : totalHours.toFixed(2);
    console.log('Student Group: ' + name);
    console.log('  Forms: ' + count + ' forms (days: ' + formList + ')');
    console.log('  Hours per Session: ' + hoursPerSession);
    console.log('  Total Hours: ' + totalStr + ' hours');
    console.log('');
  }
}

async function processOneTeacher(docs, teacherEmail, shiftCache, templateCache) {
  docs.sort((a, b) => {
    const ta = a.data().submittedAt && a.data().submittedAt.toDate ? a.data().submittedAt.toDate().getTime() : 0;
    const tb = b.data().submittedAt && b.data().submittedAt.toDate ? b.data().submittedAt.toDate().getTime() : 0;
    if (ta !== tb) return ta - tb;
    return (a.id || '').localeCompare(b.id || '');
  });

  async function getStudentNamesFromShift(shift) {
    if (!shift) return [];
    let names = shift.student_names || shift.studentNames;
    if (Array.isArray(names) && names.length > 0) return names.map(n => (n && typeof n === 'string' ? n.trim() : String(n)).trim()).filter(Boolean);
    const ids = shift.student_ids || shift.studentIds;
    if (!Array.isArray(ids) || ids.length === 0) return [];
    const out = [];
    for (const uid of ids) {
      try {
        const userSnap = await db.collection('users').doc(String(uid)).get();
        if (!userSnap.exists) continue;
        const d = userSnap.data();
        const first = (d.first_name || d.firstName || '').toString().trim();
        const last = (d.last_name || d.lastName || '').toString().trim();
        const name = (first + ' ' + last).trim();
        if (name) out.push(name);
      } catch (_) {}
    }
    return out;
  }

  const rows = [];
  for (let i = 0; i < docs.length; i++) {
    const doc = docs[i];
    const data = doc.data();
    const formId = data.formId || '';
    const formNumber = i + 1;
    let studentGroup = null;
    let hours = null;

    if (formId === READINESS_FORM_ID) {
      const responses = data.responses || {};
      const rawStudents = pickValue(responses['1754406457284']);
      studentGroup = normalizeStudentGroup(rawStudents) || 'Unspecified (readiness)';
      const dur = pickValue(responses['1754406414139']) ?? data.reportedHours;
      hours = parseHours(dur);
    } else if (formId === DAILY_REPORT_FORM_ID) {
      const shiftId = data.shiftId || data.shift_id || null;
      if (shiftId) {
        if (!shiftCache.has(shiftId)) {
          const shiftSnap = await db.collection('teaching_shifts').doc(shiftId).get();
          const shiftData = shiftSnap.exists ? shiftSnap.data() : null;
          shiftCache.set(shiftId, shiftData);
          const resolved = shiftData ? await getStudentNamesFromShift(shiftData) : [];
          shiftCache.set(shiftId + '_names', resolved);
        }
        const names = shiftCache.get(shiftId + '_names') || [];
        studentGroup = studentGroupFromShift(names) || 'Unspecified (daily_class_report forms)';
      } else {
        studentGroup = 'Unspecified (daily_class_report forms)';
      }
      const resp = data.responses || {};
      hours = parseHours(resp.actual_duration);
    } else {
      let typeLabel = 'Other';
      if (!templateCache.has(formId)) {
        try {
          const tplSnap = await db.collection('form_templates').doc(formId).get();
          templateCache.set(formId, tplSnap.exists ? tplSnap.data() : null);
        } catch (_) {
          templateCache.set(formId, null);
        }
      }
      const tpl = templateCache.get(formId);
      const freq = tpl && (tpl.frequency || tpl.Frequency);
      if (freq === 'weekly') typeLabel = 'Weekly forms';
      else if (freq === 'monthly') typeLabel = 'Monthly forms';
      else if (freq === 'perSession') typeLabel = 'Per-session forms';
      else if (freq === 'onDemand') typeLabel = 'On-demand forms';
      studentGroup = typeLabel;
      hours = parseHours(data.reportedHours);
    }

    const dayOfMonth = getDayOfMonth(data, shiftCache, formId === DAILY_REPORT_FORM_ID ? (data.shiftId || data.shift_id) : null);
    const day = dayOfMonth != null && dayOfMonth >= 1 && dayOfMonth <= 31 ? dayOfMonth : (data.submittedAt && data.submittedAt.toDate ? data.submittedAt.toDate().getDate() : null);

    if (!studentGroup) studentGroup = 'Unspecified (daily_class_report forms)';
    rows.push({ formNumber, dayOfMonth: day, studentGroup, hours: hours != null ? hours : 0 });
  }

  const byGroup = new Map();
  for (const r of rows) {
    if (!byGroup.has(r.studentGroup)) byGroup.set(r.studentGroup, { formNumbers: [], days: [], hours: [] });
    byGroup.get(r.studentGroup).formNumbers.push(r.formNumber);
    byGroup.get(r.studentGroup).days.push(r.dayOfMonth != null ? r.dayOfMonth : 0);
    byGroup.get(r.studentGroup).hours.push(r.hours);
  }

  const ordered = [];
  for (const name of GROUP_ORDER) {
    if (byGroup.has(name)) ordered.push({ name, ...byGroup.get(name) });
  }
  for (const [name, data] of byGroup) {
    if (!GROUP_ORDER.includes(name)) ordered.push({ name, ...data });
  }

  printTable(ordered, teacherEmail, rows.length);
}

async function main() {
  const formSnap = await db.collection('form_responses').where('yearMonth', '==', YEAR_MONTH).get();
  const allDocs = formSnap.docs;

  const shiftCache = new Map();
  const templateCache = new Map();

  if (EMAIL) {
    const emailLower = EMAIL.trim().toLowerCase();
    const docs = allDocs.filter(d => {
      const e = (d.data().userEmail || d.data().user_email || '').toString().trim().toLowerCase();
      return e === emailLower;
    });
    if (docs.length === 0) {
      console.log('No forms found for ' + EMAIL + ' in ' + YEAR_MONTH);
      return;
    }
    await processOneTeacher(docs, EMAIL, shiftCache, templateCache);
  } else {
    const byTeacher = new Map();
    for (const d of allDocs) {
      const e = (d.data().userEmail || d.data().user_email || '').toString().trim();
      if (!e) continue;
      const key = e.toLowerCase();
      if (!byTeacher.has(key)) byTeacher.set(key, []);
      byTeacher.get(key).push(d);
    }
    const emails = [...byTeacher.keys()].sort();
    for (const emailKey of emails) {
      const docs = byTeacher.get(emailKey);
      const displayEmail = docs[0].data().userEmail || docs[0].data().user_email || emailKey;
      await processOneTeacher(docs, displayEmail, shiftCache, templateCache);
    }
  }
  console.log('Done.');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
