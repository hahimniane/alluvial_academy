/**
 * Weekly proof that what teachers clocked is what their audits pay.
 *
 * For each of the last months, every teacher's approved timesheet hours are
 * compared with the worked hours stored on their audit. A gap larger than
 * six minutes, or an audit missing for a teacher who clocked time, is a pay
 * problem — whatever caused it — and admins are emailed the list the same
 * morning. This is the tripwire for the class of bug where a month's early
 * classes dropped out of the audit after the 60-day archival.
 */
const admin = require('firebase-admin');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {DateTime} = require('luxon');
const {createTransporter} = require('../services/email/transporter');
const {brandedEmailHtml} = require('../services/email/branding');

const ZONE = 'America/New_York';
const TOLERANCE_HOURS = 0.1;

/** "01:29:52" → 1.4978; numbers pass through; anything else is 0. */
const hoursOf = (value) => {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  const text = String(value ?? '').trim();
  const m = text.match(/^(\d+):(\d{1,2}):(\d{1,2})$/);
  if (m) return Number(m[1]) + Number(m[2]) / 60 + Number(m[3]) / 3600;
  const n = parseFloat(text);
  return Number.isFinite(n) ? n : 0;
};

const round2 = (n) => Math.round(n * 100) / 100;

/**
 * Pure comparison. `timesheetHours` and `auditHours` map uid → hours.
 * Returns the teachers whose pay basis disagrees, largest gap first.
 */
const compareMonth = ({timesheetHours, auditHours, tolerance = TOLERANCE_HOURS}) => {
  const uids = new Set([...Object.keys(timesheetHours), ...Object.keys(auditHours)]);
  const rows = [];
  for (const uid of uids) {
    const clocked = round2(timesheetHours[uid] || 0);
    const audited = auditHours[uid] == null ? null : round2(auditHours[uid]);
    if (audited == null) {
      if (clocked > tolerance) rows.push({uid, clocked, audited: null, gap: clocked, reason: 'no audit for a teacher with clocked hours'});
      continue;
    }
    const gap = round2(clocked - audited);
    if (Math.abs(gap) > tolerance) rows.push({uid, clocked, audited, gap, reason: gap > 0 ? 'audit pays fewer hours than were clocked' : 'audit pays more hours than were clocked (approved forms or attestations?)'});
  }
  return rows.sort((a, b) => Math.abs(b.gap) - Math.abs(a.gap));
};

const monthWindow = (yearMonth) => {
  const start = DateTime.fromFormat(yearMonth, 'yyyy-MM', {zone: ZONE}).startOf('month');
  return {start: start.toJSDate(), end: start.plus({months: 1}).toJSDate()};
};

/** The months worth checking: the three completed months before the current one. */
const recentMonths = (now = new Date()) => {
  const cur = DateTime.fromJSDate(now, {zone: ZONE}).startOf('month');
  return [3, 2, 1].map((back) => cur.minus({months: back}).toFormat('yyyy-MM'));
};

const loadMonth = async (db, yearMonth) => {
  const {start, end} = monthWindow(yearMonth);
  const ts = admin.firestore.Timestamp;
  const entries = await db.collection('timesheet_entries')
    .where('scheduled_start', '>=', ts.fromDate(start))
    .where('scheduled_start', '<', ts.fromDate(end))
    .get();
  const timesheetHours = {};
  for (const d of entries.docs) {
    const e = d.data() || {};
    if (String(e.status || '').toLowerCase() !== 'approved') continue;
    const uid = String(e.teacher_id || '');
    if (!uid) continue;
    timesheetHours[uid] = (timesheetHours[uid] || 0) + hoursOf(e.total_hours);
  }
  const audits = await db.collection('teacher_audits').where('yearMonth', '==', yearMonth).get();
  const auditHours = {};
  for (const d of audits.docs) {
    const uid = d.id.endsWith(`_${yearMonth}`) ? d.id.slice(0, -(yearMonth.length + 1)) : String((d.data() || {}).oderId || '');
    if (uid) auditHours[uid] = Number((d.data() || {}).totalWorkedHours) || 0;
  }
  return {yearMonth, timesheetHours, auditHours, entries: entries.size, audits: audits.size};
};

const nameOf = async (db, uid) => {
  try {
    const u = (await db.collection('users').doc(uid).get()).data();
    if (!u) return `${uid} (deleted account)`;
    return `${u.first_name || ''} ${u.last_name || ''}`.trim() || uid;
  } catch (e) {
    return uid;
  }
};

const runPayIntegrityCheck = async (db, {months = recentMonths()} = {}) => {
  const report = {ranAt: new Date().toISOString(), months: []};
  for (const yearMonth of months) {
    const m = await loadMonth(db, yearMonth);
    const rows = compareMonth(m);
    for (const r of rows) r.name = await nameOf(db, r.uid);
    // Deleted accounts still owning timesheet hours are noted but not paged on.
    report.months.push({yearMonth, entries: m.entries, audits: m.audits, mismatches: rows});
  }
  const live = (r) => !r.name.endsWith('(deleted account)');
  report.underpaid = report.months.reduce((n, m) => n + m.mismatches.filter((r) => live(r) && r.gap > 0).length, 0);
  report.overpaid = report.months.reduce((n, m) => n + m.mismatches.filter((r) => live(r) && r.gap < 0).length, 0);
  report.total = report.underpaid + report.overpaid;
  return report;
};

const adminEmails = async (db) => {
  const [byRole, byType] = await Promise.all([
    db.collection('users').where('role', '==', 'admin').get(),
    db.collection('users').where('user_type', '==', 'admin').get(),
  ]);
  const emails = new Set();
  for (const d of [...byRole.docs, ...byType.docs]) {
    const u = d.data() || {};
    if (u.is_active === false) continue;
    const email = String(u['e-mail'] || u.email || '').trim().toLowerCase();
    if (email.includes('@') && !email.startsWith('e2e-admin-')) emails.add(email);
  }
  return [...emails];
};

const escapeHtml = (v) => String(v ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const reportHtml = (report) => {
  const rows = report.months.flatMap((m) => m.mismatches.map((r) =>
    `<tr><td>${m.yearMonth}</td><td>${escapeHtml(r.name)}</td><td style="text-align:right">${r.clocked.toFixed(2)}</td><td style="text-align:right">${r.audited == null ? '—' : r.audited.toFixed(2)}</td><td style="text-align:right">${r.gap > 0 ? '+' : ''}${r.gap.toFixed(2)}</td><td>${escapeHtml(r.reason)}</td></tr>`));
  return brandedEmailHtml({
    heading: `Pay check: ${report.total} teacher-month${report.total === 1 ? '' : 's'} do not match`,
    bodyHtml: `
      <p>Approved timesheet hours were compared with the worked hours on each teacher's audit for ${report.months.map((m) => m.yearMonth).join(', ')}. ${report.underpaid} teacher-month${report.underpaid === 1 ? '' : 's'} would be <strong>paid less than clocked</strong> (fix first) and ${report.overpaid} more than clocked (check the approved forms behind them):</p>
      <table style="border-collapse:collapse;width:100%;font-size:13px">
        <tr><th align="left">Month</th><th align="left">Teacher</th><th align="right">Clocked h</th><th align="right">Audit h</th><th align="right">Gap</th><th align="left">Why it matters</th></tr>
        ${rows.join('')}
      </table>
      <p>Open the Audit screen, recompute the month for these teachers, and check the timesheet review if the gap remains. A teacher paid on the audit figure is paid on the smaller number until this is resolved.</p>`,
    footerNote: 'Sent every Monday by the pay integrity check. No email is sent when everything matches.',
  });
};

const emailAdmins = async (db, report) => {
  const to = await adminEmails(db);
  if (!to.length) return 0;
  const transporter = await createTransporter();
  await transporter.sendMail({
    from: '"Alluwal Education Hub" <no-reply@alluwaleducationhub.org>',
    to: to.join(', '),
    subject: `Pay check: ${report.total} teacher-month${report.total === 1 ? '' : 's'} do not match their timesheets`,
    html: reportHtml(report),
  });
  return to.length;
};

const checkPayIntegrity = onSchedule(
  {schedule: '0 8 * * 1', timeZone: ZONE, memory: '512MiB', timeoutSeconds: 540},
  async () => {
    const db = admin.firestore();
    const report = await runPayIntegrityCheck(db);
    await db.collection('pay_integrity_reports').doc(report.ranAt.slice(0, 10)).set(report);
    if (report.total > 0) {
      const sent = await emailAdmins(db, report);
      console.log(`checkPayIntegrity: ${report.total} mismatches, emailed ${sent} admins`);
    } else {
      console.log('checkPayIntegrity: all teacher-months match');
    }
  },
);

module.exports = {
  checkPayIntegrity,
  _compareMonth: compareMonth,
  _hoursOf: hoursOf,
  _recentMonths: recentMonths,
  _runPayIntegrityCheck: runPayIntegrityCheck,
  _reportHtml: reportHtml,
};
