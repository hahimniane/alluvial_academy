/**
 * getFinanceMonthSummary (handlers/finance_summary.js).
 *
 * Expected behavior:
 * - Admin-only; needs a yyyy-MM month.
 * - Returns exactly the shape in docs/finance/SPEC.md.
 * - Reads only the month's documents (never a whole collection), so noise in
 *   other months is never read.
 * - Overdue invoices come from every month; open credit and this week's first
 *   invoices are not tied to the month asked for.
 * - A closed month keeps the figures it was closed with, while money still
 *   arriving (collected, owed) stays live.
 */

jest.mock('firebase-functions', () => {
  class MockHttpsError extends Error {
    constructor(code, message, details) {
      super(message);
      this.code = code;
      this.details = details;
    }
  }
  return {https: {HttpsError: MockHttpsError}};
});

const {getFinanceMonthSummary} = require('../handlers/finance_summary');
const {makeDb, FakeTimestamp} = require('./helpers/finance_overview_db');

const NOW = new Date('2026-10-22T16:00:00Z');
const at = (iso) => new Date(`${iso}T16:00:00Z`);

const SPEC_KEYS = [
  'month', 'status', 'final', 'billed', 'collected', 'owed', 'discounts', 'credit_open', 'penalties',
  'teacher_pay', 'teacher_pay_final', 'admin_pay', 'admin_base', 'software', 'marketing', 'transfer_fees',
  'other', 'expenses', 'profit', 'invoice_count', 'families_owing', 'recurring_pending', 'recurring_due',
  'unpaid_teachers', 'unpaid_admins', 'admin_payout_mismatches', 'overdue_invoices', 'first_invoices_this_week', 'teachers', 'admins',
].sort();

const seed = () => ({
  invoices: {
    a: {parent_id: 'p1', status: 'paid', total_amount: 100, paid_amount: 100, period: '2026-09', due_date: at('2026-10-01'),
      items: [{total: 110}, {total: -10, is_discount: true}]},
    b: {parent_id: 'p2', status: 'pending', total_amount: 200, paid_amount: 50, billing_month: '2026-09', period: '2026-09',
      due_date: at('2026-10-01')},
    c: {parent_id: 'p3', status: 'cancelled', total_amount: 999, paid_amount: 0, period: '2026-09', due_date: at('2026-10-01')},
    // Another month: overdue and counted by the all-months overdue figure only.
    old: {parent_id: 'p4', status: 'pending', total_amount: 60, paid_amount: 0, period: '2026-07', due_date: at('2026-08-01')},
    // Due later: not overdue.
    soon: {parent_id: 'p5', status: 'pending', total_amount: 60, paid_amount: 0, period: '2026-10', due_date: at('2026-11-01'),
      issued_date: at('2026-10-20'), kind: 'first_month'},
    paidOld: {parent_id: 'p6', status: 'paid', total_amount: 60, paid_amount: 60, period: '2026-06', due_date: at('2026-07-01')},
    firstOld: {parent_id: 'p7', status: 'paid', total_amount: 60, paid_amount: 60, period: '2026-06', due_date: at('2026-07-01'),
      issued_date: at('2026-06-01'), kind: 'first_month'},
  },
  teacher_audits: {
    't1_2026-09': {userId: 't1', teacherName: 'Teacher One', yearMonth: '2026-09', status: 'ceoApproved', totalHoursTaught: 10,
      paymentSummary: {totalNetPayment: 80, totalGrossPayment: 90, totalPenalties: 10}},
    't2_2026-09': {userId: 't2', teacherName: 'Teacher Two', yearMonth: '2026-09', status: 'pending', totalHoursTaught: 4,
      paymentSummary: {totalNetPayment: 20, totalGrossPayment: 20, totalPenalties: 0}},
    't1_2026-08': {userId: 't1', teacherName: 'Teacher One', yearMonth: '2026-08', status: 'completed', totalHoursTaught: 99,
      paymentSummary: {totalNetPayment: 9999, totalGrossPayment: 9999, totalPenalties: 0}},
  },
  finance_expenses: {
    e1: {month: '2026-09', category: 'software', amount: 30},
    e2: {expense_date: at('2026-09-15'), category: 'marketing_cost', amount: 10},
    // Has a month, and a date in another month: counted once, in its month.
    e3: {month: '2026-09', expense_date: at('2026-10-02'), category: 'other', amount: 5},
    e4: {month: '2026-09', category: 'teacher_payment', amount: 500},
    e5: {month: '2026-09', category: 'other', amount: 40, deleted: true},
    e6: {month: '2026-08', category: 'software', amount: 70},
    e7: {expense_date: at('2026-08-20'), category: 'software', amount: 70},
  },
  finance_recurring_costs: {
    c1: {category: 'software', amount: 50, day_of_month: 3, start_month: '2026-01', end_month: null},
    c2: {category: 'marketing', amount: 20, day_of_month: 5, start_month: '2026-01'},
    future: {category: 'software', amount: 5000, start_month: '2027-01'},
  },
  finance_recurring_confirmations: {
    '2026-09_c2': {cost_id: 'c2', month: '2026-09', amount: 25},
    '2026-08_c1': {cost_id: 'c1', month: '2026-08', amount: 77},
  },
  staff_payouts: {
    '2026-09_t1': {user_id: 't1', role: 'teacher', month: '2026-09', transfer_fee: 2},
    '2026-08_t1': {user_id: 't1', role: 'teacher', month: '2026-08', transfer_fee: 8},
  },
  admin_pay_terms: {
    a1: {name: 'Admin One', role_title: 'Director', pauses: [],
      terms: [{from_month: '2026-01', fixed: 50, pct: 0}, {from_month: '2026-09', fixed: 100, pct: 10}]},
  },
  family_credits: {
    k1: {status: 'open', amount: 25},
    k2: {status: 'open', amount: 10.5},
    k3: {status: 'used', amount: 99},
  },
});

const deps = (db, over = {}) => ({
  db,
  Timestamp: FakeTimestamp,
  verifyAdmin: async () => ({callerUid: 'admin_1', effectiveAdminEmail: 'a@example.com'}),
  now: () => NOW,
  globalsCache: null,
  ...over,
});

const call = (db, data, over) => getFinanceMonthSummary({auth: {uid: 'admin_1'}, data}, deps(db, over));

describe('getFinanceMonthSummary', () => {
  test('refuses a caller the admin gate refuses', async () => {
    const db = makeDb(seed());
    const refuse = async () => {
      const error = new Error('Only administrators can perform this action');
      error.code = 'permission-denied';
      throw error;
    };
    await expect(call(db, {month: '2026-09'}, {verifyAdmin: refuse})).rejects.toMatchObject({code: 'permission-denied'});
    expect(db.reads).toHaveLength(0);
  });

  test('needs a month', async () => {
    const db = makeDb(seed());
    await expect(call(db, {})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(db, {month: '2026-9'})).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('returns exactly the SPEC shape with the month worked out', async () => {
    const db = makeDb(seed());
    const s = await call(db, {month: '2026-09'});
    expect(Object.keys(s).sort()).toEqual(SPEC_KEYS);
    expect(s).toMatchObject({
      month: '2026-09',
      status: 'open',
      final: false,
      billed: 300,
      collected: 150,
      owed: 150,
      discounts: 10,
      invoice_count: 2,
      families_owing: 1,
      penalties: 10,
      teacher_pay: 100,
      teacher_pay_final: false,
      software: 80,
      marketing: 35,
      transfer_fees: 2,
      other: 5,
      admin_base: 78,
      admin_pay: 107.8,
      expenses: 329.8,
      profit: -29.8,
      recurring_pending: 1,
      recurring_due: 1,
      credit_open: 35.5,
      overdue_invoices: 2,
      first_invoices_this_week: 1,
    });
    expect(s.teachers.map((t) => t.uid)).toEqual(['t1', 't2']);
    expect(s.admins[0]).toMatchObject({uid: 'a1', fixed: 100, pct: 10, share: 7.8, total: 107.8, paused: null});
  });

  test('is plain data a callable can send', async () => {
    const db = makeDb(seed());
    const s = await call(db, {month: '2026-09'});
    expect(JSON.parse(JSON.stringify(s))).toEqual(s);
  });

  test('reads only the documents of the month it was asked about', async () => {
    const db = makeDb(seed());
    await call(db, {month: '2026-09'});
    for (const id of ['t1_2026-08', 'e6', 'e7', 'future', '2026-08_c1', '2026-08_t1']) {
      expect(db.reads.filter((r) => r.endsWith(`/${id}`))).toEqual([]);
    }
    // Another month's invoice is read only by the all-months overdue figure.
    expect(db.reads.filter((r) => r === 'invoices/old')).toHaveLength(1);
  });

  test('a month with nothing in it is all zeros', async () => {
    const db = makeDb({});
    const s = await call(db, {month: '2025-01'});
    expect(Object.keys(s).sort()).toEqual(SPEC_KEYS);
    expect(s).toMatchObject({billed: 0, expenses: 0, profit: 0, teachers: [], admins: [], final: true, credit_open: 0});
  });

  test('the month-free figures are shared between calls for a moment', async () => {
    const db = makeDb(seed());
    const cache = {at: 0, value: null, pending: null};
    await call(db, {month: '2026-09'}, {globalsCache: cache});
    const before = db.reads.filter((r) => r.startsWith('family_credits/')).length;
    await call(db, {month: '2026-08'}, {globalsCache: cache});
    expect(db.reads.filter((r) => r.startsWith('family_credits/')).length).toBe(before);
  });

  test('a closed month keeps its closing figures; money arriving stays live', async () => {
    const data = seed();
    data.finance_months = {
      '2026-09': {
        status: 'closed',
        snapshot: {billed: 280, profit: 11, expenses: 269, teacher_pay: 100, teachers: [{uid: 't1', name: 'T', hours: 1, gross: 1, penalties: 0, net: 1, final: true}], admins: []},
      },
    };
    const db = makeDb(data);
    const s = await call(db, {month: '2026-09'});
    expect(Object.keys(s).sort()).toEqual(SPEC_KEYS);
    expect(s).toMatchObject({status: 'closed', final: true, billed: 280, profit: 11, expenses: 269, collected: 150, owed: 150});
    expect(s.teachers).toHaveLength(1);
    // Nothing but invoices and the shared figures were read.
    expect(db.reads.some((r) => r.startsWith('teacher_audits/'))).toBe(false);
    expect(db.reads.some((r) => r.startsWith('finance_expenses/'))).toBe(false);
  });

  test('a reopened month is worked out live again', async () => {
    const data = seed();
    data.finance_months = {'2026-09': {status: 'open'}};
    const db = makeDb(data);
    const s = await call(db, {month: '2026-09'});
    expect(s).toMatchObject({status: 'open', billed: 300});
  });
});
