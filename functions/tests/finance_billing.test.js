/**
 * Finance billing engine against an in-memory Firestore.
 *
 * Covers the owner's rules: first invoice pro-rated and due 3 days after the
 * first class, the monthly amount set once and changed only with a reason, one
 * monthly invoice per family per month (fixed doc id), discounts then credits,
 * the generator OFF by default, reminders OFF until parent messages are on,
 * and the automatic first invoice when a student's first class completes.
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

jest.mock('../utils/finance_lock', () => ({assertMonthOpen: jest.fn(async () => undefined)}), {virtual: true});

const admin = require('firebase-admin');
const {createFakeFirestore, installOnAdmin, FakeTimestamp, FieldValue} = require('./helpers/fake_firestore');
const finance = require('../handlers/finance_billing');

const ts = (iso) => FakeTimestamp.fromDate(new Date(iso));

const ADMIN = {user_type: 'admin', first_name: 'Hawa', last_name: 'Admin'};
const parent = (over = {}) => ({user_type: 'parent', first_name: 'Fatou', last_name: 'Diallo', 'e-mail': 'fatou@example.com', ...over});
const student = (name) => ({user_type: 'student', first_name: name, last_name: 'Diallo'});

const baseSeed = () => ({
  users: {
    admin_1: ADMIN,
    parent_1: parent(),
    parent_2: parent({first_name: 'Ousmane', last_name: 'Bah', 'e-mail': 'ousmane@example.com'}),
    stu_1: student('Amina'),
    stu_2: student('Omar'),
    stu_3: student('Kadi'),
  },
});

let lock;
const makeDeps = (seed, nowIso = '2026-10-22T15:00:00Z') => {
  const db = createFakeFirestore(seed, {now: () => new Date(nowIso)});
  installOnAdmin(admin, db);
  const {applyStudentDiscounts} = require('../utils/student_discounts');
  return {
    db,
    FieldValue,
    Timestamp: FakeTimestamp,
    verifyAdmin: async () => ({callerUid: 'admin_1', effectiveAdminEmail: 'hawa@example.com'}),
    assertMonthOpen: lock,
    now: () => new Date(nowIso),
    applyDiscounts: applyStudentDiscounts,
    sendReminder: jest.fn(async () => ({email: true, push: false})),
  };
};

beforeEach(() => {
  lock = jest.fn(async () => undefined);
});

const firstInput = (over = {}) => ({
  parent_id: 'parent_1',
  student_id: 'stu_1',
  monthly_amount: 80,
  classes_in_month: 8,
  classes_left: 3,
  first_class_date: '2026-10-20',
  ...over,
});

const callFirst = (deps, data) => finance.createFirstInvoice({auth: {uid: 'admin_1'}, data}, deps);

describe('createFirstInvoice', () => {
  test('Oct 20 start with 3 of 8 classes left at $80 is a $30 invoice due Oct 23', async () => {
    const deps = makeDeps(baseSeed());
    const out = await callFirst(deps, firstInput());

    expect(out.invoice_id).toBe('first_stu_1');
    const invoice = deps.db.store.invoices.first_stu_1;
    expect(invoice).toMatchObject({
      kind: 'first_month',
      billing_month: '2026-10',
      parent_id: 'parent_1',
      student_id: 'stu_1',
      student_ids: ['stu_1'],
      total_amount: 30,
      paid_amount: 0,
      status: 'pending',
      monthly_amount: 80,
      classes_left: 3,
      classes_in_month: 8,
      first_class_date: '2026-10-20',
    });
    expect(invoice.invoice_number).toMatch(/^INV-2026-001$/);
    expect(invoice.due_date.toDate().toISOString()).toBe('2026-10-23T04:00:00.000Z');
    expect(invoice.items).toHaveLength(1);
    expect(invoice.items[0]).toMatchObject({student_id: 'stu_1', total: 30});
    expect(invoice.pay_link_token).toBeTruthy();
  });

  test('writes family_billing with the monthly amount and an empty history', async () => {
    const deps = makeDeps(baseSeed());
    await callFirst(deps, firstInput());
    expect(deps.db.store.family_billing.parent_1).toMatchObject({
      monthly_amount: 80,
      student_ids: ['stu_1'],
      set_on_invoice_id: 'first_stu_1',
      history: [],
      active: true,
    });
    expect(deps.db.store.family_billing.parent_1.set_at).toBeTruthy();
  });

  test('checks the month lock for the month of the first class', async () => {
    const deps = makeDeps(baseSeed());
    await callFirst(deps, firstInput({first_class_date: '2026-10-30'}));
    expect(lock).toHaveBeenCalledWith(deps.db, '2026-10');
  });

  test('a closed month refuses and writes nothing', async () => {
    const deps = makeDeps(baseSeed());
    lock.mockRejectedValueOnce(Object.assign(new Error('October is closed.'), {code: 'failed-precondition'}));
    await expect(callFirst(deps, firstInput())).rejects.toMatchObject({code: 'failed-precondition'});
    expect(deps.db.writes).toHaveLength(0);
  });

  test('a second first invoice for the same student is refused', async () => {
    const deps = makeDeps(baseSeed());
    await callFirst(deps, firstInput());
    const writesAfterFirst = deps.db.writes.length;
    await expect(callFirst(deps, firstInput())).rejects.toMatchObject({code: 'already-exists'});
    expect(deps.db.writes).toHaveLength(writesAfterFirst);
  });

  test('numbers come from the shared yearly counter', async () => {
    const seed = baseSeed();
    seed.invoice_counters = {2026: {next: 31}};
    const deps = makeDeps(seed);
    await callFirst(deps, firstInput());
    expect(deps.db.store.invoices.first_stu_1.invoice_number).toBe('INV-2026-031');
    expect(deps.db.store.invoice_counters['2026'].next).toBe(32);
  });

  test('applies a student discount and open family credit, discount first', async () => {
    const seed = baseSeed();
    seed.users.stu_1.discount = {mode: 'percent', value: 50, startDate: new Date('2026-09-01T00:00:00Z'), duration: 'ongoing'};
    seed.family_credits = {c1: {parent_id: 'parent_1', amount: 10, status: 'open', reason: 'Paused', created_at: ts('2026-09-01T00:00:00Z')}};
    const deps = makeDeps(seed);
    await callFirst(deps, firstInput());

    // $30 prorated, 50% off = $15, minus $10 credit = $5.
    const invoice = deps.db.store.invoices.first_stu_1;
    expect(invoice.subtotal).toBe(30);
    expect(invoice.discount_total).toBe(15);
    expect(invoice.credit_applied).toBe(10);
    expect(invoice.total_amount).toBe(5);
    expect(deps.db.store.family_credits.c1).toMatchObject({status: 'used', used_on_invoice_id: 'first_stu_1'});
  });

  test('a second child of an existing family adds to the family amount from next month', async () => {
    const seed = baseSeed();
    seed.family_billing = {
      parent_1: {monthly_amount: 80, student_ids: ['stu_1'], history: [], active: true, set_on_invoice_id: 'x'},
    };
    const deps = makeDeps(seed);
    await callFirst(deps, firstInput({student_id: 'stu_2', monthly_amount: 60, classes_left: 4}));

    expect(deps.db.store.invoices.first_stu_2.total_amount).toBe(30);
    const fb = deps.db.store.family_billing.parent_1;
    expect(fb.monthly_amount).toBe(140);
    expect(fb.student_ids).toEqual(['stu_1', 'stu_2']);
    expect(fb.set_on_invoice_id).toBe('x');
    expect(fb.history).toHaveLength(1);
    expect(fb.history[0]).toMatchObject({from_month: '2026-11', old: 80, new: 140, by: 'admin_1'});
  });

  test.each([
    [{monthly_amount: 0}],
    [{classes_in_month: 0}],
    [{classes_left: 9}],
    [{classes_left: 0}],
    [{first_class_date: '10/20/2026'}],
    [{parent_id: ''}],
  ])('rejects bad input %j', async (over) => {
    const deps = makeDeps(baseSeed());
    await expect(callFirst(deps, firstInput(over))).rejects.toMatchObject({code: 'invalid-argument'});
    expect(deps.db.writes).toHaveLength(0);
  });

  test('refuses a caller the admin gate refuses', async () => {
    const deps = makeDeps(baseSeed());
    deps.verifyAdmin = async () => {
      throw Object.assign(new Error('Only administrators can perform this action'), {code: 'permission-denied'});
    };
    await expect(callFirst(deps, firstInput())).rejects.toMatchObject({code: 'permission-denied'});
    expect(deps.db.writes).toHaveLength(0);
  });
});

describe('setFamilyMonthlyAmount', () => {
  const seed = () => {
    const s = baseSeed();
    s.family_billing = {
      parent_1: {monthly_amount: 80, student_ids: ['stu_1'], history: [], active: true, student_amounts: {stu_1: 80}},
    };
    return s;
  };
  const call = (deps, data) => finance.setFamilyMonthlyAmount({auth: {uid: 'admin_1'}, data}, deps);

  test('records old, new, reason and who, starting with the next invoice', async () => {
    const deps = makeDeps(seed(), '2026-10-22T15:00:00Z');
    const out = await call(deps, {parent_id: 'parent_1', monthly_amount: 90, reason: 'Added a weekly class'});

    expect(out).toMatchObject({ok: true, from_month: '2026-11'});
    const fb = deps.db.store.family_billing.parent_1;
    expect(fb.monthly_amount).toBe(90);
    expect(fb.history).toHaveLength(1);
    expect(fb.history[0]).toMatchObject({
      from_month: '2026-11',
      old: 80,
      new: 90,
      reason: 'Added a weekly class',
      by: 'admin_1',
    });
    expect(fb.history[0].at).toBeTruthy();
    expect(fb.student_amounts).toBeUndefined();
    expect(lock).toHaveBeenCalledWith(deps.db, '2026-11');
  });

  test('if next month is already invoiced the change starts the month after', async () => {
    const s = seed();
    s.invoices = {'monthly_parent_1_2026-11': {parent_id: 'parent_1', status: 'pending'}};
    const deps = makeDeps(s, '2026-10-27T15:00:00Z');
    const out = await call(deps, {parent_id: 'parent_1', monthly_amount: 90, reason: 'Raise'});
    expect(out.from_month).toBe('2026-12');
    expect(lock).toHaveBeenCalledWith(deps.db, '2026-12');
  });

  test('a reason is required', async () => {
    const deps = makeDeps(seed());
    await expect(call(deps, {parent_id: 'parent_1', monthly_amount: 90, reason: '  '})).rejects.toMatchObject({code: 'invalid-argument'});
    expect(deps.db.writes).toHaveLength(0);
  });

  test('the amount must be above zero', async () => {
    const deps = makeDeps(seed());
    await expect(call(deps, {parent_id: 'parent_1', monthly_amount: 0, reason: 'x'})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(deps, {parent_id: 'parent_1', monthly_amount: -5, reason: 'x'})).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('a family without family_billing is refused', async () => {
    const deps = makeDeps(baseSeed());
    await expect(call(deps, {parent_id: 'parent_1', monthly_amount: 90, reason: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('a closed month refuses and changes nothing', async () => {
    const deps = makeDeps(seed());
    lock.mockRejectedValueOnce(Object.assign(new Error('closed'), {code: 'failed-precondition'}));
    await expect(call(deps, {parent_id: 'parent_1', monthly_amount: 90, reason: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(deps.db.writes).toHaveLength(0);
  });

  test('an unchanged amount is refused', async () => {
    const deps = makeDeps(seed());
    await expect(call(deps, {parent_id: 'parent_1', monthly_amount: 80, reason: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
  });
});

describe('monthly generation', () => {
  const families = () => {
    const s = baseSeed();
    s.finance_settings = {main: {auto_billing_enabled: true}};
    s.family_billing = {
      parent_1: {monthly_amount: 80, student_ids: ['stu_1'], history: [], active: true},
      parent_2: {monthly_amount: 150, student_ids: ['stu_2', 'stu_3'], history: [], active: true},
    };
    return s;
  };
  const run = (deps) => finance.runMonthlyGeneration(deps);

  test('does nothing while auto billing is off (the default)', async () => {
    const s = families();
    delete s.finance_settings;
    const deps = makeDeps(s, '2026-10-26T10:00:00Z');
    expect(await run(deps)).toEqual({skipped: 'auto_billing_off'});
    expect(deps.db.writes).toHaveLength(0);
  });

  test('does nothing before the issue day', async () => {
    const deps = makeDeps(families(), '2026-10-24T10:00:00Z');
    expect(await run(deps)).toEqual({skipped: 'before_issue_day'});
    expect(deps.db.writes).toHaveLength(0);
  });

  test('on the 25th creates next month for every family, with the fixed doc id', async () => {
    const deps = makeDeps(families(), '2026-10-25T10:00:00Z');
    const result = await run(deps);

    expect(result).toMatchObject({month: '2026-11', created: 2, failed: 0});
    const one = deps.db.store.invoices['monthly_parent_1_2026-11'];
    expect(one).toMatchObject({
      kind: 'monthly',
      billing_month: '2026-11',
      period_start: '2026-11',
      parent_id: 'parent_1',
      student_ids: ['stu_1'],
      total_amount: 80,
      status: 'pending',
    });
    expect(one.due_date.toDate().toISOString()).toBe('2026-11-01T04:00:00.000Z');
    expect(one.invoice_number).toBe('INV-2026-001');
    // Two children share the family amount as two lines.
    const two = deps.db.store.invoices['monthly_parent_2_2026-11'];
    expect(two.total_amount).toBe(150);
    expect(two.items.map((i) => i.student_id)).toEqual(['stu_2', 'stu_3']);
    expect(two.items.map((i) => i.total)).toEqual([75, 75]);
    expect(lock).toHaveBeenCalledWith(deps.db, '2026-11');
  });

  test('is idempotent: a second run on the same day creates nothing', async () => {
    const deps = makeDeps(families(), '2026-10-25T10:00:00Z');
    await run(deps);
    const invoicesBefore = Object.keys(deps.db.store.invoices).length;
    const second = await run(deps);
    expect(second).toMatchObject({created: 0, existing: 2});
    expect(Object.keys(deps.db.store.invoices)).toHaveLength(invoicesBefore);
    expect(deps.db.store.invoice_counters['2026'].next).toBe(3);
  });

  test('createMonthlyInvoice itself is a no-op when the document already exists', async () => {
    const deps = makeDeps(families(), '2026-10-25T10:00:00Z');
    const settings = {due_day: 1, issue_day: 25};
    const first = await finance.createMonthlyInvoice({deps, parentId: 'parent_1', month: '2026-11', settings});
    const again = await finance.createMonthlyInvoice({deps, parentId: 'parent_1', month: '2026-11', settings});
    expect(first.created).toBe(true);
    expect(again).toMatchObject({created: false, reason: 'invoice_exists'});
  });

  test('uses the amount in force for that month, not an amount set later', async () => {
    const s = families();
    s.family_billing.parent_1 = {
      monthly_amount: 100,
      student_ids: ['stu_1'],
      active: true,
      history: [{from_month: '2026-12', old: 80, new: 100, reason: 'x', by: 'a'}],
    };
    const deps = makeDeps(s, '2026-10-25T10:00:00Z');
    await run(deps);
    expect(deps.db.store.invoices['monthly_parent_1_2026-11'].total_amount).toBe(80);
  });

  test('applies discounts then credit, marks credit used and keeps the rest of a big credit open', async () => {
    const s = families();
    s.users.stu_1.discount = {mode: 'fixed', value: 20, startDate: new Date('2026-01-01T00:00:00Z'), duration: 'ongoing'};
    s.family_credits = {
      c1: {parent_id: 'parent_1', amount: 100, status: 'open', reason: 'Left early', source: 'leave', created_at: ts('2026-09-01T00:00:00Z')},
      other: {parent_id: 'parent_2', amount: 5, status: 'cancelled', created_at: ts('2026-09-01T00:00:00Z')},
    };
    const deps = makeDeps(s, '2026-10-25T10:00:00Z');
    await run(deps);

    // $80 - $20 discount = $60; the $100 credit covers all $60.
    const invoice = deps.db.store.invoices['monthly_parent_1_2026-11'];
    expect(invoice).toMatchObject({subtotal: 80, discount_total: 20, credit_applied: 60, total_amount: 0, status: 'paid', settled_by_credit: true});
    expect(invoice.credit_lines).toEqual([{credit_id: 'c1', amount: 60, reason: 'Left early'}]);
    expect(deps.db.store.family_credits.c1).toMatchObject({status: 'used', amount: 60, original_amount: 100, used_on_invoice_id: 'monthly_parent_1_2026-11'});
    const rest = deps.db.store.family_credits['c1__rest_monthly_parent_1_2026-11'];
    expect(rest).toMatchObject({parent_id: 'parent_1', amount: 40, status: 'open', split_from: 'c1', reason: 'Left early'});
    // A cancelled credit of another family is never used.
    expect(deps.db.store.family_credits.other.status).toBe('cancelled');
    expect(deps.db.store.invoices['monthly_parent_2_2026-11'].credit_applied).toBe(0);
  });

  test('a credit that fits is simply marked used, and next month does not reuse it', async () => {
    const s = families();
    s.family_credits = {c1: {parent_id: 'parent_1', amount: 30, status: 'open', created_at: ts('2026-09-01T00:00:00Z')}};
    const deps = makeDeps(s, '2026-10-25T10:00:00Z');
    await run(deps);
    expect(deps.db.store.invoices['monthly_parent_1_2026-11'].total_amount).toBe(50);
    expect(deps.db.store.family_credits.c1.status).toBe('used');

    const later = makeDeps(deps.db.store, '2026-11-26T10:00:00Z');
    await run(later);
    expect(later.db.store.invoices['monthly_parent_1_2026-12'].credit_applied).toBe(0);
  });

  test('skips a family that already has an invoice for the month from the old system', async () => {
    const s = families();
    s.invoices = {
      recurring_plan_9_2026_11: {
        parent_id: 'parent_1',
        period_start: '2026-11',
        period_end: '2026-11',
        status: 'pending',
        recurring_plan_id: 'plan_9',
      },
    };
    const deps = makeDeps(s, '2026-10-25T10:00:00Z');
    const result = await run(deps);
    expect(result).toMatchObject({created: 1, existing: 1});
    expect(deps.db.store.invoices['monthly_parent_1_2026-11']).toBeUndefined();
    expect(deps.db.store.invoices['monthly_parent_2_2026-11']).toBeDefined();
  });

  test('an old multi-month invoice that covers the month also counts', async () => {
    const s = families();
    s.invoices = {
      old_quarter: {parent_id: 'parent_1', period_start: '2026-10', period_end: '2026-12', status: 'pending'},
    };
    const deps = makeDeps(s, '2026-10-25T10:00:00Z');
    const result = await run(deps);
    expect(result.existing).toBe(1);
    expect(deps.db.store.invoices['monthly_parent_1_2026-11']).toBeUndefined();
  });

  test('a cancelled old invoice does not block, but a cancelled monthly one is never recreated', async () => {
    const s = families();
    s.invoices = {
      old_cancelled: {parent_id: 'parent_1', period_start: '2026-11', period_end: '2026-11', status: 'cancelled'},
      'monthly_parent_2_2026-11': {parent_id: 'parent_2', period_start: '2026-11', status: 'cancelled', kind: 'monthly'},
    };
    const deps = makeDeps(s, '2026-10-25T10:00:00Z');
    const result = await run(deps);
    expect(result.created).toBe(1);
    expect(deps.db.store.invoices['monthly_parent_1_2026-11']).toBeDefined();
    expect(deps.db.store.invoices['monthly_parent_2_2026-11'].status).toBe('cancelled');
  });

  test('a closed month is skipped without writing', async () => {
    const deps = makeDeps(families(), '2026-10-25T10:00:00Z');
    lock.mockRejectedValueOnce(Object.assign(new Error('closed'), {code: 'failed-precondition'}));
    expect(await run(deps)).toEqual({skipped: 'month_closed', month: '2026-11'});
    expect(deps.db.writes).toHaveLength(0);
  });

  test('inactive families and zero amounts are not billed', async () => {
    const s = families();
    s.family_billing.parent_1.active = false;
    const deps = makeDeps(s, '2026-10-25T10:00:00Z');
    const result = await run(deps);
    expect(result.created).toBe(1);
    expect(deps.db.store.invoices['monthly_parent_1_2026-11']).toBeUndefined();
  });

  test('one family failing does not stop the others', async () => {
    const deps = makeDeps(families(), '2026-10-25T10:00:00Z');
    const real = deps.applyDiscounts;
    deps.applyDiscounts = jest.fn(async (db, items, period, reader, parentId) => {
      if (parentId === 'parent_1' && reader !== db) throw new Error('boom');
      return real(db, items, period, reader, parentId);
    });
    const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    const result = await run(deps);
    errorSpy.mockRestore();
    expect(result).toMatchObject({created: 1, failed: 1});
    expect(deps.db.store.invoices['monthly_parent_2_2026-11']).toBeDefined();
    expect(deps.db.store.invoices['monthly_parent_1_2026-11']).toBeUndefined();
  });
});

describe('previewMonthlyBilling', () => {
  const seed = () => {
    const s = baseSeed();
    s.family_billing = {
      parent_1: {monthly_amount: 80, student_ids: ['stu_1'], history: [], active: true},
      parent_2: {monthly_amount: 150, student_ids: ['stu_2', 'stu_3'], history: [], active: true},
    };
    s.users.stu_1.discount = {mode: 'fixed', value: 10, startDate: new Date('2026-01-01T00:00:00Z'), duration: 'ongoing'};
    s.family_credits = {c1: {parent_id: 'parent_2', amount: 25, status: 'open', created_at: ts('2026-09-01T00:00:00Z')}};
    return s;
  };
  const call = (deps, data) => finance.previewMonthlyBilling({auth: {uid: 'admin_1'}, data}, deps);

  test('lists each family with amount, discount, credit and total, plus totals', async () => {
    const deps = makeDeps(seed());
    const out = await call(deps, {month: '2026-11'});

    expect(out.month).toBe('2026-11');
    const byId = Object.fromEntries(out.rows.map((r) => [r.parent_id, r]));
    expect(byId.parent_1).toMatchObject({
      parent_name: 'Fatou Diallo',
      students: ['Amina Diallo'],
      monthly_amount: 80,
      discount: 10,
      credit: 0,
      total: 70,
    });
    expect(byId.parent_2).toMatchObject({monthly_amount: 150, discount: 0, credit: 25, total: 125});
    expect(byId.parent_1.existing_invoice_id).toBeUndefined();
    expect(out.totals).toMatchObject({families: 2, to_create: 2, monthly_amount: 230, discount: 10, credit: 25, total: 195});
    // Read-only.
    expect(deps.db.writes).toHaveLength(0);
  });

  test('shows an existing invoice from either system and leaves it out of the totals', async () => {
    const s = seed();
    s.invoices = {
      recurring_plan_1_2026_11: {parent_id: 'parent_1', period_start: '2026-11', period_end: '2026-11', status: 'pending', total_amount: 80},
      'monthly_parent_2_2026-11': {parent_id: 'parent_2', period_start: '2026-11', status: 'pending', kind: 'monthly', total_amount: 125},
    };
    const deps = makeDeps(s);
    const out = await call(deps, {month: '2026-11'});
    const byId = Object.fromEntries(out.rows.map((r) => [r.parent_id, r]));
    expect(byId.parent_1.existing_invoice_id).toBe('recurring_plan_1_2026_11');
    expect(byId.parent_2.existing_invoice_id).toBe('monthly_parent_2_2026-11');
    expect(out.totals).toMatchObject({to_create: 0, total: 0, already_invoiced: 2});
  });

  test('a first-month or one-off invoice does not count as the month being invoiced', async () => {
    const s = seed();
    s.invoices = {
      first_stu_1: {parent_id: 'parent_1', period_start: '2026-11', status: 'pending', kind: 'first_month'},
      x: {parent_id: 'parent_2', period_start: '2026-11', status: 'pending', kind: 'one_off'},
    };
    const deps = makeDeps(s);
    const out = await call(deps, {month: '2026-11'});
    expect(out.rows.every((r) => !r.existing_invoice_id)).toBe(true);
  });

  test('inactive families are left out', async () => {
    const s = seed();
    s.family_billing.parent_2.active = false;
    const deps = makeDeps(s);
    const out = await call(deps, {month: '2026-11'});
    expect(out.rows.map((r) => r.parent_id)).toEqual(['parent_1']);
  });

  test('proposals fill in families with no family_billing yet, and real documents win', async () => {
    const deps = makeDeps(seed());
    const out = await finance.computeMonthlyPlan({
      db: deps.db,
      month: '2026-11',
      proposals: {
        parent_1: {monthly_amount: 999, student_ids: ['stu_1']},
        parent_3: {monthly_amount: 40, student_ids: ['stu_3']},
      },
    });
    const byId = Object.fromEntries(out.rows.map((r) => [r.parent_id, r]));
    expect(byId.parent_1.monthly_amount).toBe(80);
    expect(byId.parent_1.proposed).toBe(false);
    expect(byId.parent_3).toMatchObject({monthly_amount: 40, proposed: true});
  });

  test('rejects a bad month', async () => {
    const deps = makeDeps(seed());
    await expect(call(deps, {month: 'November'})).rejects.toMatchObject({code: 'invalid-argument'});
  });
});

describe('automatic first invoice when the first class completes', () => {
  const seed = (over = {}) => {
    const s = baseSeed();
    s.family_billing = {
      parent_1: {
        student_ids: ['stu_1'],
        pending_first_invoice: {monthly_amount: 80, classes_in_month: 8},
        active: true,
      },
      ...over.family_billing,
    };
    // Classes in the rest of October for stu_1: the one that just completed (Oct 20)
    // plus Oct 22, 27 and 29 — and one cancelled and one for someone else.
    s.teaching_shifts = {
      s_first: {student_ids: ['stu_1'], status: 'fullyCompleted', shift_start: ts('2026-10-20T21:00:00Z'), teacher_id: 't1'},
      s_b: {student_ids: ['stu_1'], status: 'scheduled', shift_start: ts('2026-10-22T21:00:00Z'), teacher_id: 't1'},
      s_c: {student_ids: ['stu_1'], status: 'scheduled', shift_start: ts('2026-10-27T21:00:00Z'), teacher_id: 't1'},
      s_d: {student_ids: ['stu_1'], status: 'scheduled', shift_start: ts('2026-10-29T21:00:00Z'), teacher_id: 't1'},
      s_cancelled: {student_ids: ['stu_1'], status: 'cancelled', shift_start: ts('2026-10-28T21:00:00Z'), teacher_id: 't1'},
      s_other: {student_ids: ['stu_2'], status: 'scheduled', shift_start: ts('2026-10-26T21:00:00Z'), teacher_id: 't1'},
      s_earlier: {student_ids: ['stu_1'], status: 'completed', shift_start: ts('2026-10-05T21:00:00Z'), teacher_id: 't1'},
      s_november: {student_ids: ['stu_1'], status: 'scheduled', shift_start: ts('2026-11-03T21:00:00Z'), teacher_id: 't1'},
    };
    s.teaching_shifts_archive = {};
    return s;
  };

  const completed = (over = {}) => ({
    student_ids: ['stu_1'],
    status: 'fullyCompleted',
    shift_start: ts('2026-10-20T21:00:00Z'),
    teacher_id: 't1',
    ...over,
  });
  const scheduled = (over = {}) => completed({status: 'scheduled', ...over});

  test('creates the pro-rated first invoice and tells the admins', async () => {
    const deps = makeDeps(seed(), '2026-10-20T23:00:00Z');
    const out = await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed()});

    expect(out.outcomes).toHaveLength(1);
    expect(out.outcomes[0]).toMatchObject({created: true, invoiceId: 'first_stu_1'});
    const invoice = deps.db.store.invoices.first_stu_1;
    // The schedule holds four classes from Oct 20 on (the 20th, 22nd, 27th, 29th; the cancelled
    // and other-student ones do not count): 80 x 4 / 8.
    expect(invoice).toMatchObject({kind: 'first_month', billing_month: '2026-10', classes_left: 4, total_amount: 40, created_by: 'system'});
    expect(invoice.due_date.toDate().toISOString()).toBe('2026-10-23T04:00:00.000Z');

    const fb = deps.db.store.family_billing.parent_1;
    expect(fb).toMatchObject({monthly_amount: 80, set_on_invoice_id: 'first_stu_1'});
    expect(fb.pending_first_invoice).toBeUndefined();

    const notes = Object.values(deps.db.store.admin_notifications);
    expect(notes).toHaveLength(1);
    expect(notes[0]).toMatchObject({type: 'first_invoice_created', invoice_id: 'first_stu_1', read: false, student_id: 'stu_1'});
    expect(notes[0].message).toContain('Amina Diallo');
    expect(lock).toHaveBeenCalledWith(deps.db, '2026-10');
  });

  test('never writes to the shift', async () => {
    const deps = makeDeps(seed(), '2026-10-20T23:00:00Z');
    await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed()});
    expect(deps.db.writes.filter((w) => w.path.startsWith('teaching_shifts'))).toEqual([]);
  });

  test('is idempotent: the same completion twice makes one invoice and one notification', async () => {
    const deps = makeDeps(seed(), '2026-10-20T23:00:00Z');
    await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed()});
    const again = await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed()});
    expect(again.outcomes || []).toEqual([]);
    expect(Object.keys(deps.db.store.invoices)).toEqual(['first_stu_1']);
    expect(Object.keys(deps.db.store.admin_notifications)).toHaveLength(1);
    expect(deps.db.store.invoice_counters['2026'].next).toBe(2);
  });

  test('completed -> fullyCompleted is not a new first class', async () => {
    const deps = makeDeps(seed());
    const out = await finance.handleShiftChange({
      deps,
      shiftId: 's_first',
      before: completed({status: 'completed'}),
      after: completed({status: 'fullyCompleted'}),
    });
    expect(out).toEqual({skipped: 'not_a_new_completion'});
    expect(deps.db.writes).toHaveLength(0);
  });

  test('a missed or cancelled class does not count as attending', async () => {
    const deps = makeDeps(seed());
    for (const status of ['missed', 'cancelled', 'scheduled']) {
      const out = await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed({status})});
      expect(out).toEqual({skipped: 'not_a_new_completion'});
    }
    expect(deps.db.writes).toHaveLength(0);
  });

  test('partiallyCompleted and completed both count', async () => {
    for (const status of ['partiallyCompleted', 'completed']) {
      const deps = makeDeps(seed(), '2026-10-20T23:00:00Z');
      const out = await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed({status})});
      expect(out.outcomes[0]).toMatchObject({created: true});
    }
  });

  test('a family with no pending first invoice is left alone', async () => {
    const s = seed({family_billing: {parent_1: {student_ids: ['stu_1'], monthly_amount: 80, active: true}}});
    const deps = makeDeps(s);
    const out = await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed()});
    expect(out.outcomes).toEqual([]);
    expect(deps.db.writes).toHaveLength(0);
  });

  test('a student with a prior invoice is not billed twice; the wait ends', async () => {
    const s = seed();
    s.invoices = {old_1: {parent_id: 'parent_1', student_id: 'stu_1', status: 'pending', total_amount: 80}};
    const deps = makeDeps(s, '2026-10-20T23:00:00Z');
    const out = await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed()});
    expect(out.outcomes[0]).toMatchObject({created: false, reason: 'prior_invoice'});
    expect(deps.db.store.invoices.first_stu_1).toBeUndefined();
    const fb = deps.db.store.family_billing.parent_1;
    expect(fb.pending_first_invoice).toBeUndefined();
    expect(fb.first_invoice_skipped).toMatchObject({reason: 'prior_invoice', student_id: 'stu_1'});
    expect(deps.db.store.admin_notifications).toBeUndefined();
  });

  test('only the student the pending invoice names triggers it', async () => {
    const s = seed();
    s.family_billing.parent_1.student_ids = ['stu_1', 'stu_2'];
    s.family_billing.parent_1.pending_first_invoice.student_id = 'stu_2';
    const deps = makeDeps(s, '2026-10-20T23:00:00Z');
    const none = await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed()});
    expect(none.outcomes).toEqual([]);
    const yes = await finance.handleShiftChange({
      deps,
      shiftId: 's_x',
      before: scheduled({student_ids: ['stu_2']}),
      after: completed({student_ids: ['stu_2']}),
    });
    expect(yes.outcomes[0]).toMatchObject({created: true, invoiceId: 'first_stu_2'});
  });

  test('a closed month leaves the wait in place and warns the admins', async () => {
    const deps = makeDeps(seed(), '2026-10-20T23:00:00Z');
    lock.mockRejectedValueOnce(Object.assign(new Error('October is closed.'), {code: 'failed-precondition'}));
    const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    const out = await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed()});
    errorSpy.mockRestore();
    expect(out.outcomes[0].error).toContain('closed');
    expect(deps.db.store.invoices).toBeUndefined();
    expect(deps.db.store.family_billing.parent_1.pending_first_invoice).toBeTruthy();
    expect(Object.values(deps.db.store.admin_notifications)[0]).toMatchObject({type: 'first_invoice_blocked', action_required: true});
  });

  test('classes left never exceeds the classes in a full month', async () => {
    const s = seed();
    s.family_billing.parent_1.pending_first_invoice.classes_in_month = 2;
    const deps = makeDeps(s, '2026-10-20T23:00:00Z');
    const out = await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed()});
    expect(out.outcomes[0]).toMatchObject({created: true});
    expect(deps.db.store.invoices.first_stu_1).toMatchObject({classes_left: 2, total_amount: 80});
  });

  test('classes archived out of the live collection still count', async () => {
    const s = seed();
    delete s.teaching_shifts.s_b;
    s.teaching_shifts_archive = {
      s_b: {student_ids: ['stu_1'], status: 'scheduled', shift_start: ts('2026-10-22T21:00:00Z'), teacher_id: 't1'},
    };
    const deps = makeDeps(s, '2026-10-20T23:00:00Z');
    await finance.handleShiftChange({deps, shiftId: 's_first', before: scheduled(), after: completed()});
    expect(deps.db.store.invoices.first_stu_1.classes_left).toBe(4);
  });
});

describe('invoice reminders', () => {
  const seed = () => {
    const s = baseSeed();
    s.finance_settings = {main: {parent_messages_enabled: true, reminder_days_before: 3}};
    s.invoices = {
      in3: {parent_id: 'parent_1', status: 'pending', total_amount: 80, paid_amount: 0, due_date: FakeTimestamp.fromDate(new Date('2026-11-01T04:00:00Z'))},
      today: {parent_id: 'parent_1', status: 'pending', total_amount: 80, paid_amount: 0, due_date: FakeTimestamp.fromDate(new Date('2026-10-29T04:00:00Z'))},
      in2: {parent_id: 'parent_1', status: 'pending', total_amount: 80, paid_amount: 0, due_date: FakeTimestamp.fromDate(new Date('2026-10-31T04:00:00Z'))},
      paid: {parent_id: 'parent_1', status: 'paid', total_amount: 80, paid_amount: 80, due_date: FakeTimestamp.fromDate(new Date('2026-11-01T04:00:00Z'))},
      cancelled: {parent_id: 'parent_1', status: 'cancelled', total_amount: 80, paid_amount: 0, due_date: FakeTimestamp.fromDate(new Date('2026-11-01T04:00:00Z'))},
      partly: {parent_id: 'parent_2', status: 'pending', total_amount: 80, paid_amount: 80, due_date: FakeTimestamp.fromDate(new Date('2026-11-01T04:00:00Z'))},
    };
    return s;
  };

  test('does nothing while parent messages are off (the default)', async () => {
    const s = seed();
    delete s.finance_settings;
    const deps = makeDeps(s, '2026-10-29T13:00:00Z');
    expect(await finance.runInvoiceReminders(deps)).toEqual({skipped: 'parent_messages_off'});
    expect(deps.sendReminder).not.toHaveBeenCalled();
    expect(deps.db.writes).toHaveLength(0);
  });

  test('sends one reminder 3 days before and one on the due date', async () => {
    const deps = makeDeps(seed(), '2026-10-29T13:00:00Z');
    const out = await finance.runInvoiceReminders(deps);

    expect(out).toMatchObject({sent: 2});
    const calls = deps.sendReminder.mock.calls.map(([a]) => [a.invoiceId, a.kind, a.daysUntil]).sort();
    expect(calls).toEqual([['in3', 'before', 3], ['today', 'due', 0]]);
    expect(deps.db.store.invoices.in3.reminders_sent.before).toMatchObject({email: true, push: false});
    expect(deps.db.store.invoices.today.reminders_sent.due).toBeTruthy();
    // Paid, cancelled, fully-covered and the wrong day are untouched.
    for (const id of ['paid', 'cancelled', 'partly', 'in2']) {
      expect(deps.db.store.invoices[id].reminders_sent).toBeUndefined();
    }
  });

  test('a rerun the same day sends nothing more', async () => {
    const deps = makeDeps(seed(), '2026-10-29T13:00:00Z');
    await finance.runInvoiceReminders(deps);
    deps.sendReminder.mockClear();
    const again = await finance.runInvoiceReminders(deps);
    expect(again.sent).toBe(0);
    expect(deps.sendReminder).not.toHaveBeenCalled();
  });

  test('the due-date reminder still goes out after the earlier one', async () => {
    const s = seed();
    const deps = makeDeps(s, '2026-10-29T13:00:00Z');
    await finance.runInvoiceReminders(deps);
    const dueDay = {...deps, now: () => new Date('2026-11-01T13:00:00Z')};
    dueDay.sendReminder = jest.fn(async () => ({email: true, push: true}));
    const out = await finance.runInvoiceReminders(dueDay);
    expect(out.sent).toBe(1);
    expect(dueDay.sendReminder.mock.calls[0][0]).toMatchObject({invoiceId: 'in3', kind: 'due'});
    expect(deps.db.store.invoices.in3.reminders_sent).toMatchObject({before: expect.anything(), due: expect.anything()});
  });
});
