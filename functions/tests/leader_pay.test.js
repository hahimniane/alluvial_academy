/**
 * Leader pay decided in the leader audit:
 * - final pay = pay for the month + bonus − pay cut, never below zero;
 * - approving needs a pay for the month and locks the amount; reopening is
 *   refused once Finance marked it paid;
 * - the Finance month counts leader pay as an expense (estimate until
 *   approved) and will not close with leader pay unapproved;
 * - leaders of a month come from leadership classes, hours and pay from
 *   their leadership timesheets (rejected ones left out).
 */
jest.mock('firebase-functions', () => {
  class MockHttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  return {https: {HttpsError: MockHttpsError}};
});

const admin = require('firebase-admin');
const {createFakeFirestore, installOnAdmin, FakeTimestamp, FieldValue} = require('./helpers/fake_firestore');
const leaderPay = require('../handlers/leader_pay');
const math = require('../utils/finance_math');

const ts = (iso) => FakeTimestamp.fromDate(new Date(iso));

const makeDeps = (seed, {paidLock = false} = {}) => {
  const db = createFakeFirestore(seed, {now: () => new Date('2026-11-02T12:00:00Z')});
  installOnAdmin(admin, db);
  return {
    db,
    FieldValue,
    Timestamp: FakeTimestamp,
    verifyAdmin: async () => ({callerUid: 'ceo'}),
    assertMonthOpen: jest.fn(async () => {
      if (paidLock) throw Object.assign(new Error('closed'), {code: 'failed-precondition'});
    }),
    now: () => new Date('2026-11-02T12:00:00Z'),
  };
};

const seed = () => ({
  users: {ceo: {first_name: 'Hassimiou', last_name: 'Niane', user_type: 'admin'}},
  admin_audits: {
    'lead_1_2026-10': {adminId: 'lead_1', adminName: 'Saikou Jalloh', yearMonth: '2026-10', leaderBasePayUsd: 400, ceoBonusMonthlyUsd: 50, ceoPaycutMonthlyUsd: 75},
    'lead_2_2026-10': {adminId: 'lead_2', adminName: 'Fatimah Ibrahim', yearMonth: '2026-10'},
  },
});

const approve = (deps, auditId, approveIt = true) => leaderPay.approveLeaderPay({auth: {uid: 'ceo'}, data: {audit_id: auditId, approve: approveIt}}, deps);

describe('final pay', () => {
  test('pay + bonus − pay cut, never below zero', () => {
    expect(leaderPay.leaderNetPay({base: 400, bonus: 50, paycut: 75})).toBe(375);
    expect(leaderPay.leaderNetPay({base: 100, bonus: 0, paycut: 250})).toBe(0);
  });
});

describe('approveLeaderPay', () => {
  test('approving stores the final pay and who approved it', async () => {
    const deps = makeDeps(seed());
    expect(await approve(deps, 'lead_1_2026-10')).toEqual({approved: true, net: 375});
    expect(deps.db.store.admin_audits['lead_1_2026-10']).toMatchObject({leaderPayStatus: 'approved', leaderNetPayUsd: 375, leaderPayApprovedByName: 'Hassimiou Niane'});
    expect(deps.assertMonthOpen).toHaveBeenCalledWith(deps.db, '2026-10');
  });

  test('cannot approve without a pay for the month', async () => {
    const deps = makeDeps(seed());
    await expect(approve(deps, 'lead_2_2026-10')).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('reopening clears the approval, but not once it was paid', async () => {
    const s = seed();
    s.admin_audits['lead_1_2026-10'] = {...s.admin_audits['lead_1_2026-10'], leaderPayStatus: 'approved', leaderNetPayUsd: 375};
    const deps = makeDeps(s);
    await approve(deps, 'lead_1_2026-10', false);
    expect(deps.db.store.admin_audits['lead_1_2026-10'].leaderPayStatus).toBeNull();
    expect(deps.db.store.admin_audits['lead_1_2026-10'].leaderNetPayUsd).toBeUndefined();

    const paid = seed();
    paid.admin_audits['lead_1_2026-10'] = {...paid.admin_audits['lead_1_2026-10'], leaderPayStatus: 'approved', leaderNetPayUsd: 375};
    paid.staff_payouts = {'2026-10_lead_1_leader': {user_id: 'lead_1', role: 'leader', amount_paid: 375}};
    await expect(approve(makeDeps(paid), 'lead_1_2026-10', false)).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('a closed month cannot change', async () => {
    await expect(approve(makeDeps(seed(), {paidLock: true}), 'lead_1_2026-10')).rejects.toMatchObject({code: 'failed-precondition'});
  });
});

describe('Finance month', () => {
  const leaderAudits = [
    {id: 'lead_1_2026-10', adminId: 'lead_1', adminName: 'Saikou Jalloh', leaderBasePayUsd: 400, ceoBonusMonthlyUsd: 50, ceoPaycutMonthlyUsd: 75, leaderPayStatus: 'approved', leaderNetPayUsd: 375},
    {id: 'lead_2_2026-10', adminId: 'lead_2', adminName: 'Fatimah Ibrahim', leaderBasePayUsd: 100, ceoPaycutMonthlyUsd: 10},
    {id: 'lead_3_2026-10', adminId: 'lead_3', adminName: 'No Pay Yet'},
  ];

  test('leader pay is an expense: approved amount, else an estimate', () => {
    const s = math.buildMonthSummary({month: '2026-10', now: new Date('2026-11-02T12:00:00Z'), leaderAudits});
    expect(s.leaders.map((l) => [l.name, l.net, l.final])).toEqual([
      ['Fatimah Ibrahim', 90, false],
      ['Saikou Jalloh', 375, true],
    ]);
    expect(s.leader_pay).toBe(465);
    expect(s.leader_pay_final).toBe(false);
    expect(s.expenses).toBe(465);
    expect(s.final).toBe(false);
    expect(math.closeBlockers({month: '2026-10', now: new Date('2026-11-02T12:00:00Z'), summary: s, unapprovedAudits: 0}))
      .toContain('1 leader pay is not approved');
  });

  test('an approved leader not yet paid counts as unpaid', () => {
    const s = math.buildMonthSummary({month: '2026-10', now: new Date('2026-11-02T12:00:00Z'), leaderAudits: [leaderAudits[0]]});
    expect(s.unpaid_leaders).toBe(1);
    const paid = math.buildMonthSummary({month: '2026-10', now: new Date('2026-11-02T12:00:00Z'), leaderAudits: [leaderAudits[0]], payouts: [{user_id: 'lead_1', role: 'leader', amount_paid: 375}]});
    expect(paid.unpaid_leaders).toBe(0);
  });
});

describe('leaders of a month', () => {
  test('from leadership classes, with hours and pay from their timesheets', async () => {
    const s = seed();
    s.teaching_shifts = {
      a: {teacher_id: 'lead_1', teacher_name: 'Saikou Jalloh', shift_category: 'leadership', shift_start: ts('2026-10-10T12:00:00Z')},
      b: {teacher_id: 'lead_3', teacher_name: 'Sulaiman Barry', shift_category: 'leadership', shift_start: ts('2026-10-11T12:00:00Z')},
      c: {teacher_id: 't9', teacher_name: 'A Teacher', shift_category: 'teaching', shift_start: ts('2026-10-11T12:00:00Z')},
    };
    s.timesheet_entries = {
      e1: {teacher_id: 'lead_1', teacher_name: 'Saikou Jalloh', shift_category: 'leadership', status: 'approved', payment_amount: 28, created_at: ts('2026-10-10T12:01:00Z'), clock_in_timestamp: ts('2026-10-10T12:00:00Z'), clock_out_timestamp: ts('2026-10-10T19:00:00Z')},
      e2: {teacher_id: 'lead_1', teacher_name: 'Saikou Jalloh', shift_category: 'leadership', status: 'rejected', payment_amount: 99, created_at: ts('2026-10-12T12:01:00Z'), clock_in_timestamp: ts('2026-10-12T12:00:00Z'), clock_out_timestamp: ts('2026-10-12T19:00:00Z')},
      e3: {teacher_id: 'lead_1', shift_category: 'leadership', status: 'approved', payment_amount: 5, created_at: ts('2026-11-01T05:00:00Z'), clock_in_timestamp: ts('2026-11-01T05:00:00Z')},
    };
    const {leaders} = await leaderPay.getLeaderPayMonth({auth: {uid: 'ceo'}, data: {month: '2026-10'}}, makeDeps(s));
    expect(leaders).toEqual([
      {uid: 'lead_1', name: 'Saikou Jalloh', hours: 7, hours_pay: 28, timesheets: 1, classes: 1},
      {uid: 'lead_3', name: 'Sulaiman Barry', hours: 0, hours_pay: 0, timesheets: 0, classes: 1},
    ]);
  });
});
