'use strict';

/**
 * sendStudentLoginDetails: an admin emails a student's guardians the
 * student's login (Student ID + password) from the admin Users page.
 *
 * - Admins, super admins and admin-teachers only (verifyCallableCallerIsAdmin).
 * - Mail goes through Resend only. When RESEND_API_KEY is not set the call is
 *   refused instead of falling back to the old Hostinger SMTP path, which no
 *   longer delivers.
 * - The password is read here, from student_credentials (legacy user-doc copy
 *   as the fallback), and never returned to the caller.
 * - Rate limited per student and per admin (rate_limits/*, server-only).
 * - Every send is recorded in the student's decision history.
 */

const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const {verifyCallableCallerIsAdmin} = require('../utils/callable_admin');
const {readStudentPassword} = require('../services/student_credentials');
const {createTransporter, isResendConfigured} = require('../services/email/transporter');
const {brandedEmailHtml} = require('../services/email/branding');
const {recordDecisionAudit} = require('../services/decision_audit');

const STUDENT_LOGIN_DOMAIN = 'alluwaleducationhub.org';
const SIGN_IN_URL = 'https://alluwaleducationhub.org/student/login/';
const DECISION_ACTION = 'user.login_details_emailed';

/** At most this many sends in the window, per student and per admin. */
const LIMITS = {
  student: {max: 3, windowMs: 60 * 60 * 1000},
  admin: {max: 30, windowMs: 60 * 60 * 1000},
};

const RATE_COLLECTION = 'rate_limits';

const _text = (value) => (value == null ? '' : String(value)).trim();

const _idList = (...lists) => [
  ...new Set(
    lists
      .flatMap((list) => (Array.isArray(list) ? list : []))
      .map(_text)
      .filter(Boolean)
  ),
];

const _escape = (value) =>
  _text(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const _nameOf = (data) => `${_text(data && data.first_name)} ${_text(data && data.last_name)}`.trim();

/** A guardian's real address: `e-mail`, else `email`; the school's own student aliases reach nobody. */
const guardianEmailOf = (data) => {
  for (const key of ['e-mail', 'email']) {
    const value = _text(data && data[key]).toLowerCase();
    if (value && value.includes('@') && !value.endsWith(`@${STUDENT_LOGIN_DOMAIN}`)) return value;
  }
  return '';
};

/** Sends inside the window, oldest dropped; `now` in ms. */
const recentSends = (stored, now, windowMs) =>
  (Array.isArray(stored) ? stored : [])
    .map((v) => (typeof v === 'number' ? v : Number(v && typeof v.toMillis === 'function' ? v.toMillis() : v)))
    .filter((ms) => Number.isFinite(ms) && now - ms < windowMs);

/**
 * Reserves one send for the student and the admin, or throws
 * resource-exhausted. Counted before sending so a failing address cannot be
 * retried without limit.
 */
const reserveSend = async (db, {studentId, adminUid, now}) => {
  const studentRef = db.collection(RATE_COLLECTION).doc(`login_details__student__${studentId}`);
  const adminRef = db.collection(RATE_COLLECTION).doc(`login_details__admin__${adminUid}`);
  await db.runTransaction(async (tx) => {
    const [studentSnap, adminSnap] = [await tx.get(studentRef), await tx.get(adminRef)];
    const studentSends = recentSends(studentSnap.exists ? (studentSnap.data() || {}).sent_at_ms : [], now, LIMITS.student.windowMs);
    const adminSends = recentSends(adminSnap.exists ? (adminSnap.data() || {}).sent_at_ms : [], now, LIMITS.admin.windowMs);
    if (studentSends.length >= LIMITS.student.max) {
      throw new HttpsError(
        'resource-exhausted',
        `Login details for this student were already emailed ${LIMITS.student.max} times in the last hour. Try again later.`
      );
    }
    if (adminSends.length >= LIMITS.admin.max) {
      throw new HttpsError(
        'resource-exhausted',
        `You have emailed login details ${LIMITS.admin.max} times in the last hour. Try again later.`
      );
    }
    tx.set(studentRef, {kind: 'login_details_student', sent_at_ms: [...studentSends, now]});
    tx.set(adminRef, {kind: 'login_details_admin', sent_at_ms: [...adminSends, now]});
  });
};

/** The email body. Every value is escaped. */
const loginDetailsEmail = ({guardianName, studentName, studentCode, password}) => {
  const first = _escape(studentName) || 'your child';
  const loginEmail = `${studentCode.toLowerCase()}@${STUDENT_LOGIN_DOMAIN}`;
  const bodyHtml = `
    <p>Dear ${_escape(guardianName) || 'parent'},</p>
    <p>Here are the login details for ${first} at Alluwal Education Hub.</p>
    <table role="presentation" style="border-collapse: collapse; margin: 0 0 16px; font-size: 15px;">
      <tr><td style="padding: 6px 16px 6px 0; color: #475569;">Student ID</td><td style="padding: 6px 0; font-family: monospace; font-weight: bold;">${_escape(studentCode)}</td></tr>
      <tr><td style="padding: 6px 16px 6px 0; color: #475569;">Password</td><td style="padding: 6px 0; font-family: monospace; font-weight: bold;">${_escape(password)}</td></tr>
      <tr><td style="padding: 6px 16px 6px 0; color: #475569;">Login email</td><td style="padding: 6px 0; font-family: monospace;">${_escape(loginEmail)}</td></tr>
    </table>
    <p>To sign in, open <a href="${SIGN_IN_URL}">${SIGN_IN_URL.replace(/^https:\/\//, '').replace(/\/$/, '')}</a> or the Alluwal app, choose Student ID, and enter the Student ID and password above.</p>
    <p>Please keep these details private.</p>
  `;
  return {
    subject: `Login details for ${_text(studentName) || 'your child'}`,
    html: brandedEmailHtml({heading: 'Student login details', bodyHtml}),
    text:
      `Dear ${_text(guardianName) || 'parent'},\n\n` +
      `Here are the login details for ${_text(studentName) || 'your child'} at Alluwal Education Hub.\n\n` +
      `Student ID: ${studentCode}\nPassword: ${password}\nLogin email: ${loginEmail}\n\n` +
      `To sign in, open ${SIGN_IN_URL} or the Alluwal app, choose Student ID, and enter the Student ID and password above.\n\n` +
      'Please keep these details private.\n',
  };
};

const sendStudentLoginDetailsHandler = async (request) => {
  if (!request || !request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to send login details.');
  }
  const {callerUid} = await verifyCallableCallerIsAdmin(request);

  const data = request.data || {};
  const studentId = _text(data.studentId);
  if (!studentId || studentId.includes('/')) {
    throw new HttpsError('invalid-argument', 'studentId is required.');
  }
  const requested = data.guardianIds === undefined ? null : _idList(data.guardianIds);
  if (requested !== null && requested.length === 0) {
    throw new HttpsError('invalid-argument', 'Pick at least one guardian.');
  }

  if (!isResendConfigured()) {
    throw new HttpsError('failed-precondition', 'Email is not set up on this server, so nothing was sent.');
  }

  const db = admin.firestore();
  const studentSnap = await db.collection('users').doc(studentId).get();
  if (!studentSnap.exists) throw new HttpsError('not-found', 'This student no longer exists.');
  const student = studentSnap.data() || {};
  if (_text(student.user_type).toLowerCase() !== 'student') {
    throw new HttpsError('failed-precondition', 'Login details can only be sent for students.');
  }

  const linked = _idList(student.guardian_ids, student.guardianIds);
  if (linked.length === 0) {
    throw new HttpsError('failed-precondition', 'No guardian is linked to this student.');
  }
  if (requested && requested.some((id) => !linked.includes(id))) {
    throw new HttpsError('invalid-argument', 'That person is not linked to this student as a guardian.');
  }
  const targets = requested || linked;

  const studentCode = _text(student.student_code);
  if (!studentCode) {
    throw new HttpsError('failed-precondition', 'This student has no Student ID yet. Reset the password to make one.');
  }
  const password = await readStudentPassword(db, studentId, student);
  if (!password) {
    throw new HttpsError('failed-precondition', 'No password is stored for this student. Reset the password first.');
  }

  const guardians = [];
  const noEmail = [];
  for (const id of targets) {
    const snap = await db.collection('users').doc(id).get();
    if (!snap.exists) continue;
    const g = snap.data() || {};
    const name = _nameOf(g) || 'Guardian';
    const email = guardianEmailOf(g);
    if (email) guardians.push({id, name, email});
    else noEmail.push(name);
  }
  if (guardians.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      noEmail.length > 0
        ? `${noEmail.join(', ')} ${noEmail.length > 1 ? 'have' : 'has'} no email address. Use WhatsApp or the printed card instead.`
        : 'No linked guardian account was found.'
    );
  }

  await reserveSend(db, {studentId, adminUid: callerUid, now: Date.now()});

  const studentName = _nameOf(student);
  const transporter = createTransporter('support');
  const sentTo = [];
  const failed = [];
  for (const g of guardians) {
    const message = loginDetailsEmail({guardianName: g.name, studentName, studentCode, password});
    try {
      const info = await transporter.sendMail({
        from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
        to: g.email,
        subject: message.subject,
        html: message.html,
        text: message.text,
      });
      if (info && info.skipped) failed.push(g.name);
      else sentTo.push({id: g.id, name: g.name});
    } catch (error) {
      console.error(`sendStudentLoginDetails: mail to guardian ${g.id} failed:`, error && error.message);
      failed.push(g.name);
    }
  }

  if (sentTo.length > 0) {
    try {
      await recordDecisionAudit({
        db,
        entityType: 'user',
        entityId: studentId,
        entityLabel: studentName,
        action: DECISION_ACTION,
        actorUid: callerUid,
        source: 'callable:sendStudentLoginDetails',
        metadata: {channel: 'email', recipient_ids: sentTo.map((g) => g.id), recipient_count: sentTo.length},
        eventId: `${DECISION_ACTION}_${Date.now()}`,
      });
    } catch (error) {
      // The email went out; a history write failure is logged, not reported as a failed send.
      console.error('sendStudentLoginDetails: decision history write failed:', error && error.message);
    }
  }

  if (sentTo.length === 0) {
    throw new HttpsError('internal', 'The email could not be sent. Try again, or use WhatsApp or the printed card.');
  }

  return {
    success: true,
    sentTo: sentTo.map((g) => g.name),
    failed,
    noEmail,
  };
};

exports.sendStudentLoginDetails = onCall(sendStudentLoginDetailsHandler);

exports._test = {
  LIMITS,
  DECISION_ACTION,
  guardianEmailOf,
  loginDetailsEmail,
  recentSends,
  reserveSend,
  sendStudentLoginDetailsHandler,
};
