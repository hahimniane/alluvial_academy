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
 *
 * Two things this deliberately does NOT report, because reporting them made
 * every week's email 51 rows long and taught everyone to ignore it:
 *
 * `isTeacher` — only people who teach can have a teaching audit. An
 * administrator who clocks hours has no audit to compare against, and calling
 * that "paid less than clocked" invented a 60-hour debt to somebody who was
 * never owed it. Seven of twelve such rows were not teachers at all.
 *
 * `paidOnSchedule` — when a teacher never clocked in, the audit pays their
 * scheduled hours instead. The audit then legitimately exceeds the clock, and
 * saying so every week is describing the design rather than finding a fault.
 * An audit paying MORE for some other reason is still reported, and an audit
 * paying LESS than was clocked is always reported, whatever the reason.
 */
const compareMonth = ({
  timesheetHours,
  auditHours,
  tolerance = TOLERANCE_HOURS,
  isTeacher = () => true,
  paidOnSchedule = () => false,
}) => {
  const uids = new Set([...Object.keys(timesheetHours), ...Object.keys(auditHours)]);
  const rows = [];
  for (const uid of uids) {
    if (!isTeacher(uid)) continue;
    const clocked = round2(timesheetHours[uid] || 0);
    const audited = auditHours[uid] == null ? null : round2(auditHours[uid]);
    if (audited == null) {
      if (clocked > tolerance) rows.push({uid, clocked, audited: null, gap: clocked, reason: 'no audit for a teacher with clocked hours'});
      continue;
    }
    const gap = round2(clocked - audited);
    if (Math.abs(gap) <= tolerance) continue;
    if (gap < 0 && paidOnSchedule(uid)) continue;
    rows.push({uid, clocked, audited, gap, reason: gap > 0 ? 'audit pays fewer hours than were clocked' : 'audit pays more hours than were clocked (approved forms or attestations?)'});
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
  const scheduleOnly = new Set();
  for (const d of audits.docs) {
    const a = d.data() || {};
    const uid = d.id.endsWith(`_${yearMonth}`) ? d.id.slice(0, -(yearMonth.length + 1)) : String(a.oderId || '');
    if (!uid) continue;
    auditHours[uid] = Number(a.totalWorkedHours) || 0;
    // Nobody clocked in, so the audit fell back to the schedule. The clock and
    // the audit are then measuring different things by design.
    const worked = Number(a.totalWorkedHours) || 0;
    const scheduled = Number(a.totalScheduledHours) || 0;
    const clockIns = Number(a.totalClockIns) || 0;
    if (clockIns === 0 && scheduled > 0 && Math.abs(worked - scheduled) <= TOLERANCE_HOURS) {
      scheduleOnly.add(uid);
    }
  }
  return {yearMonth, timesheetHours, auditHours, scheduleOnly, entries: entries.size, audits: audits.size};
};

/**
 * Who among these people actually teaches.
 *
 * Read once per run rather than per row, and a person whose record cannot be
 * read is treated as a teacher: leaving somebody out of a pay check because
 * their profile failed to load is the more expensive mistake.
 */
const teachersAmong = async (db, uids) => {
  const teaching = new Set();
  const ids = [...uids];
  for (let i = 0; i < ids.length; i += 25) {
    const batch = ids.slice(i, i + 25);
    const docs = await Promise.all(batch.map((uid) => db.collection('users').doc(uid).get().catch(() => null)));
    docs.forEach((doc, index) => {
      const uid = batch[index];
      if (!doc || !doc.exists) { teaching.add(uid); return; }
      const u = doc.data() || {};
      const type = String(u.user_type || u.role || '').trim().toLowerCase();
      const secondary = Array.isArray(u.secondary_roles)
        ? u.secondary_roles.map((r) => String(r).trim().toLowerCase())
        : [];
      if (type === 'teacher' || secondary.includes('teacher')) teaching.add(uid);
    });
  }
  return teaching;
};

const nameOf = async (db, uid) => {
  try {
    const u = (await db.collection('users').doc(uid).get()).data();
    if (!u) return `${uid} (deleted account)`;
    // Some records carry no name at all, and a bare id tells a reader nothing.
    return `${u.first_name || ''} ${u.last_name || ''}`.trim()
      || String(u['e-mail'] || u.email || '').trim()
      || uid;
  } catch (e) {
    return uid;
  }
};

const runPayIntegrityCheck = async (db, {months = recentMonths()} = {}) => {
  const report = {ranAt: new Date().toISOString(), months: []};
  for (const yearMonth of months) {
    const m = await loadMonth(db, yearMonth);
    const teaching = await teachersAmong(db, new Set([
      ...Object.keys(m.timesheetHours), ...Object.keys(m.auditHours),
    ]));
    const rows = compareMonth({
      ...m,
      isTeacher: (uid) => teaching.has(uid),
      paidOnSchedule: (uid) => m.scheduleOnly.has(uid),
    });
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
  const table = (rows) => `
    <table style="border-collapse:collapse;width:100%;font-size:13px">
      <tr><th align="left">Month</th><th align="left">Teacher</th><th align="right">Clocked h</th><th align="right">Audit h</th><th align="right">Gap</th></tr>
      ${rows.join('')}
    </table>`;
  const row = (yearMonth, r) =>
    `<tr><td>${yearMonth}</td><td>${escapeHtml(r.name)}</td><td style="text-align:right">${r.clocked.toFixed(2)}</td><td style="text-align:right">${r.audited == null ? '—' : r.audited.toFixed(2)}</td><td style="text-align:right">${r.gap > 0 ? '+' : ''}${r.gap.toFixed(2)}</td></tr>`;

  const short = report.months.flatMap((m) => m.mismatches.filter((r) => r.gap > 0).map((r) => row(m.yearMonth, r)));
  const extra = report.months.flatMap((m) => m.mismatches.filter((r) => r.gap < 0).map((r) => row(m.yearMonth, r)));
  const period = report.months.map((m) => m.yearMonth).join(', ');

  // Hours worked that nobody is paying for lead, because that is the only part
  // somebody has to act on. An audit paying more than the clock usually means
  // approved forms added hours, so it is kept as a second, quieter list rather
  // than being counted in the headline — a weekly alarm that always fires is a
  // weekly alarm nobody opens.
  const bodyHtml = `
    ${short.length ? `
      <p><strong>${short.length} teacher-month${short.length === 1 ? '' : 's'} clocked hours the audit does not pay for</strong> (${period}). Someone may be owed this time:</p>
      ${table(short)}
      <p>Open the Audit screen, recompute the month for these teachers, and check the timesheet review if the gap remains. A teacher paid on the audit figure is paid on the smaller number until this is resolved.</p>`
    : `<p>No teacher clocked hours their audit fails to pay for in ${period}. Nothing to act on.</p>`}
    ${extra.length ? `
      <p style="margin-top:28px;color:#64748B"><strong>For information only —</strong> ${extra.length} teacher-month${extra.length === 1 ? '' : 's'} where the audit pays more than was clocked. Approved forms and attestations add hours that were never clocked, so this is usually expected rather than an error:</p>
      ${table(extra)}` : ''}`;

  return brandedEmailHtml({
    heading: short.length
      ? `Pay check: ${short.length} teacher-month${short.length === 1 ? '' : 's'} paid less than clocked`
      : 'Pay check: nothing to act on',
    bodyHtml,
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
    subject: report.underpaid
      ? `Pay check: ${report.underpaid} teacher-month${report.underpaid === 1 ? '' : 's'} paid less than clocked`
      : `Pay check: ${report.overpaid} to review, none underpaid`,
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
  _teachersAmong: teachersAmong,
  _reportHtml: reportHtml,
};
