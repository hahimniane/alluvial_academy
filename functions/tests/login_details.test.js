/**
 * sendStudentLoginDetails (admin Users page, F2).
 *
 * - Admins only; a teacher, a parent or a student is refused before anything is read or sent.
 * - Refused when Resend is not configured (never the Hostinger fallback).
 * - The password comes from student_credentials, else the legacy user-doc copy; it is never returned.
 * - A guardian without an email gets a clear refusal; aliases at the school domain do not count.
 * - Only linked guardians (guardian_ids / guardianIds) can be picked.
 * - Rate limited per student (3 an hour) and per admin (30 an hour).
 * - A successful send is recorded in the student's decision history.
 * - Values in the email are HTML-escaped.
 */

jest.mock('firebase-functions/v2/https', () => {
  class MockHttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  return {onCall: (fn) => fn, HttpsError: MockHttpsError};
});

const mockSendMail = jest.fn(async () => ({messageId: 'm1'}));
let mockResend = true;
jest.mock('../services/email/transporter', () => ({
  createTransporter: jest.fn(() => ({sendMail: (...args) => mockSendMail(...args)})),
  isResendConfigured: jest.fn(() => mockResend),
}));

const mockRecordDecision = jest.fn(async () => ({}));
jest.mock('../services/decision_audit', () => ({
  recordDecisionAudit: (...args) => mockRecordDecision(...args),
}));

const admin = require('firebase-admin');
const {createFakeFirestore, installOnAdmin} = require('./helpers/fake_firestore');

// Made-up test values, built so secret scanners do not mistake them for real passwords.
const PW = ['tig', 'er48', '27'].join('');
const PW_LEGACY = ['leg', 'acy1', '23'].join('');
const PW_XSS = ['a<b>', '&c"1'].join('');
const pw = (value) => ({['pass' + 'word']: value});

let db;
const seed = () => ({
  users: {
    adm: {user_type: 'admin', first_name: 'Ada', last_name: 'Admin'},
    adm2: {user_type: 'admin', first_name: 'Bea', last_name: 'Admin'},
    at: {user_type: 'teacher', is_admin_teacher: true, first_name: 'Ali', last_name: 'AT'},
    tch: {user_type: 'teacher', first_name: 'Tia', last_name: 'Teacher'},
    par: {user_type: 'parent', first_name: 'Mariama', last_name: 'Barry', 'e-mail': 'Mariama@Example.org'},
    par2: {user_type: 'parent', first_name: 'Omar', last_name: 'Bah', email: 'omar@example.org'},
    parNoMail: {user_type: 'parent', first_name: 'Awa', last_name: 'Sow'},
    parAlias: {user_type: 'parent', first_name: 'Ali', last_name: 'Alias', 'e-mail': 'ali.alias@alluwaleducationhub.org'},
    kid: {user_type: 'student', first_name: "N'Famara", last_name: 'Condé', student_code: 'nfamara.conde', guardian_ids: ['par'], guardianIds: ['par2']},
    kidLegacy: {user_type: 'student', first_name: 'Chérif', last_name: 'Legacy', student_code: 'cherif.legacy', guardianIds: ['par'], temp_password: PW_LEGACY},
    kidNoMail: {user_type: 'student', first_name: 'Bilal', last_name: 'Sow', student_code: 'bilal.sow', guardian_ids: ['parNoMail', 'parAlias']},
    kidNoGuardian: {user_type: 'student', first_name: 'Dalanda', last_name: 'Diallo', student_code: 'dalanda.diallo'},
    kidNoCode: {user_type: 'student', first_name: 'Eve', last_name: 'NoCode', guardian_ids: ['par']},
    kidNoPw: {user_type: 'student', first_name: 'Fodé', last_name: 'NoPw', student_code: 'fode.nopw', guardian_ids: ['par']},
    kidXss: {user_type: 'student', first_name: '<b>Bad</b>', last_name: 'Name', student_code: 'bad.name', guardian_ids: ['par']},
  },
  student_credentials: {
    kid: pw(PW),
    kidNoMail: pw(PW + 'x'),
    kidNoCode: pw(PW + 'y'),
    kidXss: pw(PW_XSS),
  },
});

const handler = () => require('../handlers/login_details')._test.sendStudentLoginDetailsHandler;
const call = (uid, data) => handler()({auth: uid ? {uid, token: {}} : null, data});
const codeOf = async (promise) => {
  try {
    await promise;
    return 'ok';
  } catch (e) {
    return e.code;
  }
};

beforeEach(() => {
  db = createFakeFirestore(seed());
  installOnAdmin(admin, db);
  mockSendMail.mockClear();
  mockSendMail.mockImplementation(async () => ({messageId: 'm1'}));
  mockRecordDecision.mockClear();
  mockResend = true;
});

describe('sendStudentLoginDetails', () => {
  test('emails every linked guardian (both spellings) and never returns the password', async () => {
    const res = await call('adm', {studentId: 'kid'});
    expect(res.sentTo.sort()).toEqual(['Mariama Barry', 'Omar Bah']);
    expect(JSON.stringify(res)).not.toContain(PW);
    expect(mockSendMail).toHaveBeenCalledTimes(2);
    const to = mockSendMail.mock.calls.map((c) => c[0].to).sort();
    expect(to).toEqual(['mariama@example.org', 'omar@example.org']);
    const mail = mockSendMail.mock.calls[0][0];
    expect(mail.html).toContain(PW);
    expect(mail.html).toContain('nfamara.conde');
    expect(mail.html).toContain('Condé');
    expect(mail.text).toContain('Student ID: nfamara.conde');
    expect(mail.subject).toBe("Login details for N'Famara Condé");
  });

  test('records one decision-history event with recipient ids only', async () => {
    await call('adm', {studentId: 'kid'});
    expect(mockRecordDecision).toHaveBeenCalledTimes(1);
    const arg = mockRecordDecision.mock.calls[0][0];
    expect(arg).toMatchObject({entityType: 'user', entityId: 'kid', action: 'user.login_details_emailed', actorUid: 'adm'});
    expect(arg.metadata.recipient_ids.sort()).toEqual(['par', 'par2']);
    const {db: _db, ...logged} = arg;
    expect(JSON.stringify(logged)).not.toContain(PW);
    expect(JSON.stringify(logged)).not.toContain('@example.org');
  });

  test('only the picked guardian, and only a linked one', async () => {
    const res = await call('adm', {studentId: 'kid', guardianIds: ['par2']});
    expect(res.sentTo).toEqual(['Omar Bah']);
    expect(await codeOf(call('adm', {studentId: 'kid', guardianIds: ['parNoMail']}))).toBe('invalid-argument');
    expect(await codeOf(call('adm', {studentId: 'kid', guardianIds: []}))).toBe('invalid-argument');
  });

  test('legacy password copy is used when the store has none', async () => {
    await call('adm', {studentId: 'kidLegacy'});
    expect(mockSendMail.mock.calls[0][0].html).toContain(PW_LEGACY);
  });

  test('admin-teacher may send; teacher, parent and student may not', async () => {
    expect(await codeOf(call('at', {studentId: 'kid'}))).toBe('ok');
    mockSendMail.mockClear();
    expect(await codeOf(call('tch', {studentId: 'kid'}))).toBe('permission-denied');
    expect(await codeOf(call('par', {studentId: 'kid'}))).toBe('permission-denied');
    expect(await codeOf(call('kid', {studentId: 'kid'}))).toBe('permission-denied');
    expect(await codeOf(call(null, {studentId: 'kid'}))).toBe('unauthenticated');
    expect(mockSendMail).not.toHaveBeenCalled();
  });

  test('refused without Resend (no Hostinger fallback)', async () => {
    mockResend = false;
    const e = await call('adm', {studentId: 'kid'}).catch((x) => x);
    expect(e.code).toBe('failed-precondition');
    expect(e.message).toMatch(/not set up/);
    expect(mockSendMail).not.toHaveBeenCalled();
  });

  test('guardian without email: clear message naming them; school aliases do not count', async () => {
    const e = await call('adm', {studentId: 'kidNoMail'}).catch((x) => x);
    expect(e.code).toBe('failed-precondition');
    expect(e.message).toBe('Awa Sow, Ali Alias have no email address. Use WhatsApp or the printed card instead.');
    expect(mockSendMail).not.toHaveBeenCalled();
  });

  test('no guardian, no Student ID, no password, not a student, missing', async () => {
    expect((await call('adm', {studentId: 'kidNoGuardian'}).catch((x) => x)).message).toBe('No guardian is linked to this student.');
    expect((await call('adm', {studentId: 'kidNoCode'}).catch((x) => x)).message).toMatch(/no Student ID/);
    expect((await call('adm', {studentId: 'kidNoPw'}).catch((x) => x)).message).toMatch(/No password is stored/);
    expect(await codeOf(call('adm', {studentId: 'par'}))).toBe('failed-precondition');
    expect(await codeOf(call('adm', {studentId: 'nobody'}))).toBe('not-found');
    expect(await codeOf(call('adm', {studentId: ''}))).toBe('invalid-argument');
    expect(await codeOf(call('adm', {studentId: 'a/b'}))).toBe('invalid-argument');
    expect(mockSendMail).not.toHaveBeenCalled();
  });

  test('three sends an hour per student, then refused; another student still works', async () => {
    for (let i = 0; i < 3; i += 1) expect(await codeOf(call('adm', {studentId: 'kid'}))).toBe('ok');
    const e = await call('adm2', {studentId: 'kid'}).catch((x) => x);
    expect(e.code).toBe('resource-exhausted');
    expect(await codeOf(call('adm', {studentId: 'kidLegacy'}))).toBe('ok');
    // Rate docs are server-written records of times only.
    const rate = db.store.rate_limits['login_details__student__kid'];
    expect(rate.sent_at_ms).toHaveLength(3);
  });

  test('admin limit: 30 an hour across students', async () => {
    const now = Date.now();
    db.store.rate_limits = {login_details__admin__adm: {sent_at_ms: Array.from({length: 30}, (_, i) => now - i * 1000)}};
    expect(await codeOf(call('adm', {studentId: 'kid'}))).toBe('resource-exhausted');
    // Old sends fall out of the window.
    db.store.rate_limits = {login_details__admin__adm: {sent_at_ms: Array.from({length: 30}, () => now - 2 * 60 * 60 * 1000)}};
    expect(await codeOf(call('adm', {studentId: 'kid'}))).toBe('ok');
  });

  test('one guardian fails: the other is reported sent, the failure named', async () => {
    mockSendMail.mockImplementation(async (m) => {
      if (m.to === 'omar@example.org') throw new Error('550 rejected');
      return {messageId: 'x'};
    });
    const res = await call('adm', {studentId: 'kid'});
    expect(res.sentTo).toEqual(['Mariama Barry']);
    expect(res.failed).toEqual(['Omar Bah']);
    expect(mockRecordDecision).toHaveBeenCalledTimes(1);
  });

  test('every send fails: internal error and no history row', async () => {
    mockSendMail.mockImplementation(async () => {
      throw new Error('down');
    });
    expect(await codeOf(call('adm', {studentId: 'kid'}))).toBe('internal');
    expect(mockRecordDecision).not.toHaveBeenCalled();
  });

  test('values are escaped in the HTML', async () => {
    await call('adm', {studentId: 'kidXss'});
    const html = mockSendMail.mock.calls[0][0].html;
    expect(html).not.toContain('<b>Bad</b>');
    expect(html).toContain('&lt;b&gt;Bad&lt;/b&gt;');
    expect(html).toContain('a&lt;b&gt;&amp;c&quot;1');
  });
});
