/**
 * closeFinanceMonth / reopenFinanceMonth (handlers/finance_months.js) and
 * assertMonthOpen (utils/finance_lock.js).
 *
 * Expected behavior:
 * - Close is admin-only and refuses (failed-precondition, listing what is
 *   left) until the month has ended, every audit with pay is approved, no
 *   recurring cost is waiting and nobody is unpaid.
 * - Closing stores the snapshot and a log entry with who and when.
 * - Reopening needs a reason, clears the snapshot and logs the reason.
 * - assertMonthOpen throws only for a closed month.
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

const {closeFinanceMonth, reopenFinanceMonth} = require('../handlers/finance_months');
const {assertMonthOpen} = require('../utils/finance_lock');
const {makeDb, FakeTimestamp, FieldValue} = require('./helpers/finance_overview_db');

const NOW = new Date('2026-10-22T16:00:00Z');

/** September fully done: approved, confirmed, paid. */
const readySeed = () => ({
  users: {admin_1: {first_name: 'Hawa', last_name: 'Bah', user_type: 'admin'}},
  invoices: {
    a: {parent_id: 'p1', status: 'paid', total_amount: 300, paid_amount: 300, period: '2026-09'},
  },
  teacher_audits: {
    't1_2026-09': {userId: 't1', teacherName: 'Teacher One', yearMonth: '2026-09', status: 'ceoApproved', totalHoursTaught: 10,
      paymentSummary: {totalNetPayment: 80, totalGrossPayment: 80, totalPenalties: 0}},
    // Taught nothing: nothing to approve.
    't2_2026-09': {userId: 't2', teacherName: 'Teacher Two', yearMonth: '2026-09', status: 'pending', totalHoursTaught: 0,
      paymentSummary: {totalNetPayment: 0, totalGrossPayment: 0, totalPenalties: 0}},
  },
  finance_expenses: {e1: {month: '2026-09', category: 'software', amount: 30}},
  finance_recurring_costs: {c1: {category: 'software', amount: 50, day_of_month: 3, start_month: '2026-01'}},
  finance_recurring_confirmations: {'2026-09_c1': {cost_id: 'c1', month: '2026-09', amount: 50}},
  staff_payouts: {'2026-09_t1': {user_id: 't1', role: 'teacher', month: '2026-09'}},
  admin_pay_terms: {},
});

const deps = (db, over = {}) => ({
  db,
  Timestamp: FakeTimestamp,
  FieldValue,
  verifyAdmin: async () => ({callerUid: 'admin_1', effectiveAdminEmail: 'hawa@example.com'}),
  now: () => NOW,
  globalsCache: null,
  ...over,
});

const close = (db, data, over) => closeFinanceMonth({auth: {uid: 'admin_1'}, data}, deps(db, over));
const reopen = (db, data, over) => reopenFinanceMonth({auth: {uid: 'admin_1'}, data}, deps(db, over));

describe('closeFinanceMonth', () => {
  test('refuses a caller the admin gate refuses, writing nothing', async () => {
    const db = makeDb(readySeed());
    const refuse = async () => {
      const error = new Error('no');
      error.code = 'permission-denied';
      throw error;
    };
    await expect(close(db, {month: '2026-09'}, {verifyAdmin: refuse})).rejects.toMatchObject({code: 'permission-denied'});
    expect(db.store.finance_months).toBeUndefined();
  });

  test('needs a month', async () => {
    await expect(close(makeDb(readySeed()), {})).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('closes a finished month, keeping the snapshot and who closed it', async () => {
    const db = makeDb(readySeed());
    await expect(close(db, {month: '2026-09'})).resolves.toEqual({ok: true});
    const doc = db.store.finance_months['2026-09'];
    expect(doc).toMatchObject({status: 'closed', closed_by: 'admin_1', closed_by_name: 'Hawa Bah'});
    expect(doc.closed_at).toBeInstanceOf(FakeTimestamp);
    expect(doc.snapshot).toMatchObject({billed: 300, collected: 300, expenses: 160, profit: 140, teacher_pay: 80, final: true});
    expect(doc.snapshot.status).toBeUndefined();
    expect(doc.log).toHaveLength(1);
    expect(doc.log[0]).toMatchObject({action: 'closed', by: 'admin_1', by_name: 'Hawa Bah'});
  });

  test('refuses a month that has not ended', async () => {
    const db = makeDb(readySeed());
    await expect(close(db, {month: '2026-10'})).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('October 2026 has not ended yet'),
    });
    expect(db.store.finance_months).toBeUndefined();
  });

  test('lists everything that is left', async () => {
    const data = readySeed();
    data.teacher_audits['t1_2026-09'].status = 'coachSubmitted';
    data.finance_recurring_confirmations = {};
    data.staff_payouts = {};
    const db = makeDb(data);
    let error;
    try {
      await close(db, {month: '2026-09'});
    } catch (e) {
      error = e;
    }
    expect(error.code).toBe('failed-precondition');
    expect(error.message).toContain('1 teacher audit is not approved');
    expect(error.message).toContain('1 recurring cost is not confirmed');
    expect(error.details.remaining).toHaveLength(2);
    expect(db.store.finance_months).toBeUndefined();
  });

  test('people still to pay hold it up', async () => {
    const data = readySeed();
    data.staff_payouts = {};
    const db = makeDb(data);
    await expect(close(db, {month: '2026-09'})).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('1 person is not paid'),
    });
  });

  test('a voided payout leaves the person unpaid', async () => {
    const data = readySeed();
    data.staff_payouts['2026-09_t1'].voided = true;
    await expect(close(makeDb(data), {month: '2026-09'})).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('a payout voided while the close is in flight stops the close', async () => {
    const db = makeDb(readySeed());
    const realTransaction = db.runTransaction;
    // blockers were worked out with everyone paid; then someone voids a payout
    db.runTransaction = async (fn) => {
      db.store.staff_payouts['2026-09_t1'].voided = true;
      return realTransaction(fn);
    };
    await expect(close(db, {month: '2026-09'})).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('changed while it was being closed'),
    });
    expect(db.store.finance_months).toBeUndefined();
  });

  test('a payout recorded while the close is in flight also stops the close (try again)', async () => {
    const db = makeDb(readySeed());
    const realTransaction = db.runTransaction;
    db.runTransaction = async (fn) => {
      db.store.staff_payouts['2026-09_late'] = {user_id: 'late', role: 'teacher', month: '2026-09', amount_paid: 10};
      return realTransaction(fn);
    };
    await expect(close(db, {month: '2026-09'})).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('refuses a month that is already closed', async () => {
    const db = makeDb(readySeed());
    await close(db, {month: '2026-09'});
    await expect(close(db, {month: '2026-09'})).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('already closed'),
    });
    expect(db.store.finance_months['2026-09'].log).toHaveLength(1);
  });
});

describe('reopenFinanceMonth', () => {
  test('needs a reason', async () => {
    const db = makeDb(readySeed());
    await close(db, {month: '2026-09'});
    await expect(reopen(db, {month: '2026-09'})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(reopen(db, {month: '2026-09', reason: '   '})).rejects.toMatchObject({code: 'invalid-argument'});
    expect(db.store.finance_months['2026-09'].status).toBe('closed');
  });

  test('reopens with the reason logged and the snapshot cleared', async () => {
    const db = makeDb(readySeed());
    await close(db, {month: '2026-09'});
    await expect(reopen(db, {month: '2026-09', reason: "A teacher's penalty was entered by mistake"})).resolves.toEqual({ok: true});
    const doc = db.store.finance_months['2026-09'];
    expect(doc.status).toBe('open');
    expect(doc.snapshot).toBeUndefined();
    expect(doc.closed_by).toBeUndefined();
    expect(doc.log.map((l) => l.action)).toEqual(['closed', 'reopened']);
    expect(doc.log[1]).toMatchObject({by: 'admin_1', by_name: 'Hawa Bah', reason: "A teacher's penalty was entered by mistake"});
  });

  test('refuses a month that is not closed', async () => {
    const db = makeDb(readySeed());
    await expect(reopen(db, {month: '2026-09', reason: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('a reopened month can be closed again, and the history keeps every entry', async () => {
    const db = makeDb(readySeed());
    await close(db, {month: '2026-09'});
    await reopen(db, {month: '2026-09', reason: 'Fix'});
    await close(db, {month: '2026-09'});
    expect(db.store.finance_months['2026-09'].log.map((l) => l.action)).toEqual(['closed', 'reopened', 'closed']);
  });
});

describe('assertMonthOpen', () => {
  test('passes for a month with no record or an open one', async () => {
    const db = makeDb({finance_months: {'2026-08': {status: 'open'}}});
    await expect(assertMonthOpen(db, '2026-09')).resolves.toBeUndefined();
    await expect(assertMonthOpen(db, '2026-08')).resolves.toBeUndefined();
  });

  test('throws failed-precondition for a closed month', async () => {
    const db = makeDb({finance_months: {'2026-09': {status: 'closed'}}});
    await expect(assertMonthOpen(db, '2026-09')).rejects.toMatchObject({
      code: 'failed-precondition',
      message: 'September 2026 is closed. Reopen it to change it.',
    });
  });

  test('is closed after closing and open again after reopening', async () => {
    const db = makeDb(readySeed());
    await close(db, {month: '2026-09'});
    await expect(assertMonthOpen(db, '2026-09')).rejects.toMatchObject({code: 'failed-precondition'});
    await reopen(db, {month: '2026-09', reason: 'Fix'});
    await expect(assertMonthOpen(db, '2026-09')).resolves.toBeUndefined();
  });

  test('refuses a missing month instead of letting a write through', async () => {
    await expect(assertMonthOpen(makeDb({}), undefined)).rejects.toMatchObject({code: 'invalid-argument'});
  });
});
