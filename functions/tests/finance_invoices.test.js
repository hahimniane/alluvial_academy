/**
 * Finance invoices: pure math, editInvoice, cancelInvoice, sendInvoiceReminder.
 *
 * Expected behavior:
 * - Overdue is computed (balance > 0 and today after the due day), never read
 *   from status.
 * - editInvoice is admin-only, needs a reason, refuses a closed month, never
 *   writes paid_amount, keeps edit_history, and turns "lowered below what was
 *   paid" into an open family credit.
 * - cancelInvoice works only when nothing is paid and also kills the pay link.
 * - Parents are told only when finance_settings/main.parent_messages_enabled.
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

const math = require('../utils/finance_invoice_math');
const {editInvoice, cancelInvoice, sendInvoiceReminder} = require('../handlers/finance_invoices');

const NOW = new Date('2026-10-22T15:00:00Z'); // Oct 22, 11am in New York

/* ------------------------------------------------------------------ math -- */

describe('finance_invoice_math', () => {
  test('billing month: billing_month, then period, then issued month', () => {
    expect(math.invoiceBillingMonth({billing_month: '2026-11', period: '2026-10'})).toBe('2026-11');
    expect(math.invoiceBillingMonth({period: '2026-10'})).toBe('2026-10');
    expect(math.invoiceBillingMonth({period: '2026-06 to 2026-08'})).toBe('2026-06');
    expect(math.invoiceBillingMonth({issued_date: new Date('2026-09-30T23:30:00Z')})).toBe('2026-09');
    // 03:00Z on Oct 1 is still Sept 30 in New York
    expect(math.invoiceBillingMonth({issued_date: new Date('2026-10-01T03:00:00Z')})).toBe('2026-09');
    expect(math.invoiceBillingMonth({})).toBeNull();
  });

  test('due day: midnight UTC means that date, other times are read in New York', () => {
    expect(math.dueDayKey(new Date('2026-10-25T00:00:00Z'))).toBe('2026-10-25');
    expect(math.dueDayKey(new Date('2026-10-25T16:00:00Z'))).toBe('2026-10-25'); // local noon
    expect(math.dueDayKey(math.dueTimestampDate('2026-10-25'))).toBe('2026-10-25');
  });

  test('overdue is computed from the due day and the balance', () => {
    const base = {total_amount: 100, paid_amount: 0, status: 'pending'};
    expect(math.isOverdue({...base, due_date: new Date('2026-10-21T00:00:00Z')}, NOW)).toBe(true);
    expect(math.daysOverdue({...base, due_date: new Date('2026-10-21T00:00:00Z')}, NOW)).toBe(1);
    expect(math.daysOverdue({...base, due_date: new Date('2026-09-22T00:00:00Z')}, NOW)).toBe(30);
    // due today is not overdue yet
    expect(math.isOverdue({...base, due_date: new Date('2026-10-22T00:00:00Z')}, NOW)).toBe(false);
    // status 'overdue' alone proves nothing: paid in full is never overdue
    expect(math.isOverdue({total_amount: 100, paid_amount: 100, status: 'overdue', due_date: new Date('2026-09-01T00:00:00Z')}, NOW)).toBe(false);
    // partly paid and late is overdue
    expect(math.isOverdue({total_amount: 100, paid_amount: 40, due_date: new Date('2026-09-01T00:00:00Z')}, NOW)).toBe(true);
    // cancelled is never overdue
    expect(math.isOverdue({...base, status: 'cancelled', due_date: new Date('2026-09-01T00:00:00Z')}, NOW)).toBe(false);
  });

  test('totals, credit on lower and status after an edit', () => {
    expect(math.totalFor([{amount: 80}, {amount: 40.5}], 20.25)).toBe(100.25);
    expect(math.creditOnLower({total: 60, paid: 100})).toBe(40);
    expect(math.creditOnLower({total: 100, paid: 100})).toBe(0);
    expect(math.creditOnLower({total: 120, paid: 100})).toBe(0);
    expect(math.statusAfterEdit({total: 60, paid: 100})).toBe('paid');
    expect(math.statusAfterEdit({total: 120, paid: 100})).toBe('pending');
    expect(math.statusAfterEdit({total: 0, paid: 0})).toBe('paid');
  });

  describe('validateEdit', () => {
    const good = {
      reason: 'Schedule changed',
      lines: [{description: 'Tuition - Amina', amount: 80}],
      discount: 0,
      due_date: '2026-10-30',
    };
    test('accepts a good edit and normalises it', () => {
      const out = math.validateEdit({...good, lines: [{description: ' Tuition ', amount: '80.005', student_id: 's1'}], discount: '10'});
      expect(out.ok).toBe(true);
      expect(out.value.total).toBe(70.01);
      expect(out.value.lines[0]).toEqual({description: 'Tuition', amount: 80.01, student_id: 's1'});
    });
    test.each([
      ['a missing reason', {reason: '  '}],
      ['no lines', {lines: []}],
      ['a blank description', {lines: [{description: ' ', amount: 5}]}],
      ['a missing amount', {lines: [{description: 'x', amount: ''}]}],
      ['a non-numeric amount', {lines: [{description: 'x', amount: 'abc'}]}],
      ['an infinite amount', {lines: [{description: 'x', amount: Infinity}]}],
      ['a negative line', {lines: [{description: 'x', amount: -5}]}],
      ['a negative discount', {discount: -1}],
      ['a discount above the lines', {discount: 81}],
      ['a bad due date', {due_date: '2026-02-30'}],
      ['no due date', {due_date: ''}],
    ])('rejects %s', (_, patch) => {
      const out = math.validateEdit({...good, ...patch});
      expect(out.ok).toBe(false);
      expect(typeof out.error).toBe('string');
    });
  });

  test('buildItems keeps old discount lines when the discount is unchanged', () => {
    const previous = [
      {description: 'Tuition - A', total: 100, student_id: 'a'},
      {description: 'Discount — 10% off', total: -10, is_discount: true, student_id: 'a'},
    ];
    const kept = math.buildItems({lines: [{description: 'Tuition - A', amount: 100, student_id: 'a'}], discount: 10, previousItems: previous});
    expect(kept).toHaveLength(2);
    expect(kept[1].description).toBe('Discount — 10% off');

    const changed = math.buildItems({lines: [{description: 'Tuition - A', amount: 100}], discount: 25, previousItems: previous});
    expect(changed[1]).toMatchObject({is_discount: true, total: -25, description: 'Discount — 10% off'});

    const none = math.buildItems({lines: [{description: 'Tuition - A', amount: 100}], discount: 0, previousItems: previous});
    expect(none).toHaveLength(1);
  });

  test('cutoff follows a later due date and never moves earlier', () => {
    const oldDue = new Date('2026-10-25T00:00:00Z');
    const cutoff = new Date('2026-10-26T00:00:00Z');
    expect(math.shiftedCutoff({oldDue, newDueKey: '2026-10-30', cutoff}).toISOString()).toBe('2026-10-31T00:00:00.000Z');
    expect(math.shiftedCutoff({oldDue, newDueKey: '2026-10-20', cutoff})).toBeNull();
    expect(math.shiftedCutoff({oldDue, newDueKey: '2026-10-30', cutoff: null})).toBeNull();
  });

  describe('findMonthlyInvoiceClash', () => {
    const inv = (over) => ({id: 'a', parent_id: 'p', status: 'pending', period: '2026-11', ...over});
    test('finds monthly and first_month invoices for the month', () => {
      expect(math.findMonthlyInvoiceClash({invoices: [inv({kind: 'monthly', invoice_number: 'INV-1'})], month: '2026-11'}).invoice_number).toBe('INV-1');
      expect(math.findMonthlyInvoiceClash({invoices: [inv({kind: 'first_month'})], month: '2026-11'})).not.toBeNull();
    });
    test('ignores cancelled, other months and one-off charges', () => {
      expect(math.findMonthlyInvoiceClash({invoices: [inv({kind: 'monthly', status: 'cancelled'})], month: '2026-11'})).toBeNull();
      expect(math.findMonthlyInvoiceClash({invoices: [inv({kind: 'monthly'})], month: '2026-12'})).toBeNull();
      expect(math.findMonthlyInvoiceClash({invoices: [inv({kind: 'one_off'})], month: '2026-11'})).toBeNull();
      expect(math.findMonthlyInvoiceClash({invoices: [inv({})], month: '2026-11'})).toBeNull();
    });
    test('counts invoices from the scheduled generator, which predate kind', () => {
      expect(math.findMonthlyInvoiceClash({invoices: [inv({id: 'recurring_plan_2026-11'})], month: '2026-11'})).not.toBeNull();
    });
  });
});

/* -------------------------------------------------------------- handlers -- */

const SERVER_TS = {__serverTimestamp: true};
const DELETE = {__delete: true};
const FieldValue = {serverTimestamp: () => SERVER_TS, delete: () => DELETE};
const Timestamp = {fromDate: (d) => ({iso: d.toISOString(), toDate: () => d})};
const ts = (iso) => Timestamp.fromDate(new Date(iso));

function makeDb(seed) {
  const store = JSON.parse(JSON.stringify({}));
  Object.entries(seed).forEach(([name, docs]) => {
    store[name] = {};
    Object.entries(docs).forEach(([id, doc]) => {
      store[name][id] = {...doc};
    });
  });
  const writes = [];
  let auto = 0;
  const ref = (collection, id) => ({
    id,
    collection,
    path: `${collection}/${id}`,
    get: async () => snap(collection, id),
    update: async (data) => apply('update', collection, id, data),
  });
  const snap = (collection, id) => ({
    id,
    exists: Boolean(store[collection] && store[collection][id]),
    data: () => ({...(store[collection] || {})[id]}),
  });
  const apply = (op, collection, id, data) => {
    store[collection] = store[collection] || {};
    if (op === 'update') {
      if (!store[collection][id]) throw new Error(`update of missing ${collection}/${id}`);
      const next = {...store[collection][id]};
      Object.entries(data).forEach(([k, v]) => {
        if (v === DELETE) delete next[k];
        else next[k] = v;
      });
      store[collection][id] = next;
    } else {
      store[collection][id] = {...data};
    }
    writes.push({op, path: `${collection}/${id}`, data});
  };
  const query = (collection, filters) => ({
    __isQuery: true,
    where: (field, op, value) => query(collection, [...filters, {field, op, value}]),
    run: () => {
      const docs = Object.keys(store[collection] || {})
        .filter((id) => filters.every((f) => (store[collection][id] || {})[f.field] === f.value))
        .map((id) => snap(collection, id));
      return {docs, empty: docs.length === 0, size: docs.length};
    },
  });
  return {
    store,
    writes,
    collection: (name) => ({
      doc: (id) => ref(name, id || `auto_${++auto}`),
      add: async (data) => apply('set', name, `added_${++auto}`, data),
      where: (field, op, value) => query(name, [{field, op, value}]),
    }),
    runTransaction: async (fn) => {
      let wrote = false;
      const staged = [];
      const tx = {
        get: async (r) => {
          if (wrote) throw new Error('reads must come before writes');
          if (r.__isQuery) return r.run();
          return snap(r.collection, r.id);
        },
        update: (r, data) => {
          wrote = true;
          staged.push(() => apply('update', r.collection, r.id, data));
        },
        set: (r, data) => {
          wrote = true;
          staged.push(() => apply('set', r.collection, r.id, data));
        },
      };
      const result = await fn(tx);
      staged.forEach((run) => run());
      return result;
    },
  };
}

const invoiceDoc = (over = {}) => ({
  invoice_number: 'INV-2026-100',
  parent_id: 'parent_1',
  student_id: 'stu_1',
  student_ids: ['stu_1'],
  status: 'pending',
  total_amount: 100,
  paid_amount: 0,
  currency: 'USD',
  period: '2026-10',
  due_date: ts('2026-10-25T00:00:00Z'),
  access_cutoff_date: ts('2026-10-26T00:00:00Z'),
  items: [{description: 'Tuition - Amina', quantity: 1, unit_price: 100, total: 100, student_id: 'stu_1', shift_ids: []}],
  pay_link_token: 'tok',
  pay_link_status: 'active',
  ...over,
});

const seed = (over = {}) => ({
  users: {admin_1: {first_name: 'Hawa', last_name: 'Admin', user_type: 'admin'}, parent_1: {first_name: 'Mariama'}},
  invoices: {inv_1: invoiceDoc(over.invoice)},
  finance_settings: {main: {parent_messages_enabled: over.messages === true}},
  family_credits: {},
});

const depsFor = (db, over = {}) => ({
  db,
  FieldValue,
  Timestamp,
  verifyAdmin: async () => ({callerUid: 'admin_1', effectiveAdminEmail: 'hawa@example.com'}),
  assertMonthOpen: jest.fn(async () => {}),
  resolveActor: async () => ({uid: 'admin_1', name: 'Hawa Admin'}),
  audit: jest.fn(),
  notifyParent: jest.fn(async () => ({sent: true})),
  resendInvoiceNotice: jest.fn(async () => ({emailSent: true, pushSent: false})),
  now: () => NOW,
  ...over,
});

const goodEdit = (over = {}) => ({
  invoice_id: 'inv_1',
  lines: [{description: 'Tuition - Amina', amount: 80, student_id: 'stu_1'}],
  discount: 0,
  due_date: '2026-10-30',
  reason: 'Schedule changed to 3 classes a week',
  ...over,
});

const call = (fn, deps, data) => fn({auth: {uid: 'admin_1'}, data}, deps);

describe('editInvoice', () => {
  test('a non-admin writes nothing', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db, {
      verifyAdmin: async () => {
        const e = new Error('Only administrators can perform this action');
        e.code = 'permission-denied';
        throw e;
      },
    });
    await expect(call(editInvoice, deps, goodEdit())).rejects.toMatchObject({code: 'permission-denied'});
    expect(db.writes).toHaveLength(0);
  });

  test('requires a reason, lines with descriptions and amounts', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db);
    await expect(call(editInvoice, deps, goodEdit({reason: ' '}))).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(editInvoice, deps, goodEdit({lines: []}))).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(editInvoice, deps, goodEdit({lines: [{description: '', amount: 5}]}))).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(editInvoice, deps, goodEdit({lines: [{description: 'x', amount: NaN}]}))).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(editInvoice, deps, goodEdit({discount: -5}))).rejects.toMatchObject({code: 'invalid-argument'});
    expect(db.writes).toHaveLength(0);
  });

  test('a closed month refuses the edit and writes nothing', async () => {
    const db = makeDb(seed());
    const closed = Object.assign(new Error('October 2026 is closed. Reopen it to make changes.'), {code: 'failed-precondition'});
    const deps = depsFor(db, {assertMonthOpen: jest.fn(async () => { throw closed; })});
    await expect(call(editInvoice, deps, goodEdit())).rejects.toMatchObject({code: 'failed-precondition'});
    expect(deps.assertMonthOpen).toHaveBeenCalledWith(db, '2026-10');
    expect(db.writes).toHaveLength(0);
  });

  test('uses billing_month over period for the lock', async () => {
    const db = makeDb(seed({invoice: {billing_month: '2026-11'}}));
    const deps = depsFor(db);
    await call(editInvoice, deps, goodEdit());
    expect(deps.assertMonthOpen).toHaveBeenCalledWith(db, '2026-11');
  });

  test('lowering an unpaid invoice updates total, due date and history, never paid_amount', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db);
    const out = await call(editInvoice, deps, goodEdit());

    const stored = db.store.invoices.inv_1;
    expect(stored.total_amount).toBe(80);
    expect(stored.paid_amount).toBe(0);
    expect(stored.status).toBe('pending');
    expect(stored.items).toHaveLength(1);
    expect(stored.items[0]).toMatchObject({description: 'Tuition - Amina', total: 80, student_id: 'stu_1'});
    expect(math.dueDayKey(stored.due_date)).toBe('2026-10-30');
    // the cutoff keeps its one-day gap after the later due date
    expect(stored.access_cutoff_date.toDate().toISOString()).toBe('2026-10-31T00:00:00.000Z');

    expect(stored.edit_history).toHaveLength(1);
    expect(stored.edit_history[0]).toMatchObject({
      by: 'admin_1',
      by_name: 'Hawa Admin',
      reason: 'Schedule changed to 3 classes a week',
      before: expect.objectContaining({total_amount: 100}),
      after: expect.objectContaining({total_amount: 80}),
    });
    expect(Object.keys(db.writes.find((w) => w.path === 'invoices/inv_1').data)).not.toContain('paid_amount');
    expect(out.invoice).toMatchObject({id: 'inv_1', total_amount: 80, status: 'pending'});
    expect(out.credit_id).toBeUndefined();
    expect(db.store.family_credits).toEqual({});
    expect(deps.audit).toHaveBeenCalledTimes(1);
  });

  test('history appends across edits', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db);
    await call(editInvoice, deps, goodEdit());
    await call(editInvoice, deps, goodEdit({lines: [{description: 'Tuition - Amina', amount: 90}], reason: 'Back to 90'}));
    expect(db.store.invoices.inv_1.edit_history.map((h) => h.reason)).toEqual(['Schedule changed to 3 classes a week', 'Back to 90']);
  });

  test('lowering below what was paid sets paid to the new total, marks it paid and opens a family credit', async () => {
    const db = makeDb(seed({invoice: {paid_amount: 100, status: 'paid'}}));
    const deps = depsFor(db);
    const out = await call(editInvoice, deps, goodEdit({lines: [{description: 'Tuition - Amina', amount: 60, student_id: 'stu_1'}]}));

    const stored = db.store.invoices.inv_1;
    expect(stored.total_amount).toBe(60);
    expect(stored.paid_amount).toBe(60);
    expect(stored.status).toBe('paid');
    expect(out.credit_id).toBeTruthy();
    expect(db.store.family_credits[out.credit_id]).toMatchObject({
      parent_id: 'parent_1',
      student_id: 'stu_1',
      amount: 40,
      source: 'invoice_edit',
      status: 'open',
      used_on_invoice_id: null,
      invoice_id: 'inv_1',
    });
    expect(stored.edit_history[0].credit_id).toBe(out.credit_id);
    // The history keeps paid before and after.
    expect(stored.edit_history[0].before).toMatchObject({total_amount: 100, paid_amount: 100});
    expect(stored.edit_history[0].after).toMatchObject({total_amount: 60, paid_amount: 60});
    expect(out.invoice).toMatchObject({total_amount: 60, paid_amount: 60});
  });

  test('Collected in the month summary follows the lowered paid amount', async () => {
    const monthMath = require('../utils/finance_math');
    const db = makeDb(seed({invoice: {paid_amount: 100, status: 'paid'}}));
    const month = '2026-10';
    expect(monthMath.invoiceTotals([{id: 'inv_1', ...db.store.invoices.inv_1}], month)).toMatchObject({billed: 100, collected: 100});
    await call(editInvoice, depsFor(db), goodEdit({lines: [{description: 'Tuition - Amina', amount: 60, student_id: 'stu_1'}]}));
    expect(monthMath.invoiceTotals([{id: 'inv_1', ...db.store.invoices.inv_1}], month)).toMatchObject({billed: 60, collected: 60, owed: 0});
    expect(monthMath.buildMonthSummary({month, now: new Date('2026-11-05T16:00:00Z'), invoices: [{id: 'inv_1', ...db.store.invoices.inv_1}]}))
      .toMatchObject({billed: 60, collected: 60, owed: 0});
  });

  test('raising a paid invoice leaves it pending with the balance owed', async () => {
    const db = makeDb(seed({invoice: {paid_amount: 100, status: 'paid'}}));
    const deps = depsFor(db);
    await call(editInvoice, deps, goodEdit({lines: [{description: 'Tuition - Amina', amount: 130, student_id: 'stu_1'}]}));
    expect(db.store.invoices.inv_1.status).toBe('pending');
    expect(db.store.invoices.inv_1.paid_amount).toBe(100);
  });

  test('a discount is stored as a negative is_discount line and counted in the total', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db);
    await call(editInvoice, deps, goodEdit({lines: [{description: 'Tuition - Amina', amount: 100, student_id: 'stu_1'}], discount: 15}));
    const stored = db.store.invoices.inv_1;
    expect(stored.total_amount).toBe(85);
    expect(stored.items.find((i) => i.is_discount)).toMatchObject({total: -15, unit_price: -15});
  });

  test('refuses a cancelled invoice and an edit that changes nothing', async () => {
    const cancelled = makeDb(seed({invoice: {status: 'cancelled'}}));
    await expect(call(editInvoice, depsFor(cancelled), goodEdit())).rejects.toMatchObject({code: 'failed-precondition'});
    expect(cancelled.writes).toHaveLength(0);

    const same = makeDb(seed());
    await expect(
      call(editInvoice, depsFor(same), goodEdit({lines: [{description: 'Tuition - Amina', amount: 100}], due_date: '2026-10-25'}))
    ).rejects.toMatchObject({code: 'failed-precondition'});
    expect(same.writes).toHaveLength(0);
  });

  test('unknown invoice is not-found', async () => {
    const db = makeDb(seed());
    await expect(call(editInvoice, depsFor(db), goodEdit({invoice_id: 'nope'}))).rejects.toMatchObject({code: 'not-found'});
  });

  test('parent is told only when parent messages are on', async () => {
    const off = makeDb(seed({messages: false}));
    const offDeps = depsFor(off);
    await call(editInvoice, offDeps, goodEdit());
    expect(offDeps.notifyParent).not.toHaveBeenCalled();

    const on = makeDb(seed({messages: true}));
    const onDeps = depsFor(on);
    await call(editInvoice, onDeps, goodEdit());
    expect(onDeps.notifyParent).toHaveBeenCalledTimes(1);
    expect(onDeps.notifyParent.mock.calls[0][1]).toMatchObject({
      parentId: 'parent_1',
      body: 'Your invoice INV-2026-100 was updated. New total $80.00.',
    });
  });

  test('a failing notification never undoes the edit', async () => {
    const db = makeDb(seed({messages: true}));
    const deps = depsFor(db, {notifyParent: jest.fn(async () => { throw new Error('fcm down'); })});
    await expect(call(editInvoice, deps, goodEdit())).resolves.toMatchObject({invoice: {total_amount: 80}});
  });
});

describe('cancelInvoice', () => {
  test('requires a reason', async () => {
    const db = makeDb(seed());
    await expect(call(cancelInvoice, depsFor(db), {invoice_id: 'inv_1', reason: ''})).rejects.toMatchObject({code: 'invalid-argument'});
    expect(db.writes).toHaveLength(0);
  });

  test('cancels an unpaid invoice and its pay link', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db);
    await expect(call(cancelInvoice, deps, {invoice_id: 'inv_1', reason: 'Enrolled twice'})).resolves.toEqual({ok: true});
    const stored = db.store.invoices.inv_1;
    expect(stored).toMatchObject({
      status: 'cancelled',
      cancelled_by: 'admin_1',
      cancel_reason: 'Enrolled twice',
      pay_link_status: 'cancelled',
      pay_link_cancelled_by: 'admin_1',
    });
    expect(stored.cancelled_at).toBe(SERVER_TS);
    expect(stored.pay_link_pending).toBeUndefined();
    expect(stored.edit_history[0]).toMatchObject({action: 'cancelled', reason: 'Enrolled twice'});
    expect(stored.paid_amount).toBe(0);
  });

  test('leaves an already-cancelled pay link alone', async () => {
    const db = makeDb(seed({invoice: {pay_link_status: 'cancelled'}}));
    await call(cancelInvoice, depsFor(db), {invoice_id: 'inv_1', reason: 'x'});
    expect(db.writes.find((w) => w.path === 'invoices/inv_1').data.pay_link_cancelled_at).toBeUndefined();
  });

  test.each([
    ['paid_amount above zero', {paid_amount: 10}],
    ['status paid', {status: 'paid', paid_amount: 0}],
  ])('refuses when there is %s', async (_, invoice) => {
    const db = makeDb(seed({invoice}));
    await expect(call(cancelInvoice, depsFor(db), {invoice_id: 'inv_1', reason: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.writes).toHaveLength(0);
  });

  test('a closed month refuses the cancel', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db, {
      assertMonthOpen: jest.fn(async () => { throw Object.assign(new Error('closed'), {code: 'failed-precondition'}); }),
    });
    await expect(call(cancelInvoice, deps, {invoice_id: 'inv_1', reason: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.writes).toHaveLength(0);
  });

  test('cancelling a cancelled invoice is refused', async () => {
    const db = makeDb(seed({invoice: {status: 'cancelled'}}));
    await expect(call(cancelInvoice, depsFor(db), {invoice_id: 'inv_1', reason: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
  });
});

describe('sendInvoiceReminder', () => {
  test('is refused while parent messages are off', async () => {
    const db = makeDb(seed({messages: false}));
    const deps = depsFor(db);
    await expect(call(sendInvoiceReminder, deps, {invoice_id: 'inv_1'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(deps.resendInvoiceNotice).not.toHaveBeenCalled();
  });

  test('sends and records the reminder when messages are on', async () => {
    const db = makeDb(seed({messages: true}));
    const deps = depsFor(db);
    await expect(call(sendInvoiceReminder, deps, {invoice_id: 'inv_1'})).resolves.toEqual({ok: true, sent: true});
    expect(deps.resendInvoiceNotice).toHaveBeenCalledTimes(1);
    expect(db.store.invoices.inv_1.reminders).toHaveLength(1);
    expect(db.store.invoices.inv_1.reminders[0]).toMatchObject({kind: 'manual', by: 'admin_1'});
  });

  test('nothing to remind about on a paid invoice', async () => {
    const db = makeDb(seed({messages: true, invoice: {paid_amount: 100}}));
    await expect(call(sendInvoiceReminder, depsFor(db), {invoice_id: 'inv_1'})).rejects.toMatchObject({code: 'failed-precondition'});
  });
});

/* ----------------------------------------------- review fixes (finance) -- */

describe('editInvoice: credit follows the NEW shortfall only', () => {
  const lines = (amount) => [{description: 'Tuition - Amina', amount, student_id: 'stu_1'}];
  const credits = (db) => Object.entries(db.store.family_credits);

  test('lowering twice below what was paid credits only the extra each time', async () => {
    const db = makeDb(seed({invoice: {paid_amount: 100, status: 'paid'}}));
    const deps = depsFor(db);
    await call(editInvoice, deps, goodEdit({lines: lines(60)}));
    await call(editInvoice, deps, goodEdit({lines: lines(50), reason: 'Lower again'}));
    const amounts = credits(db).map(([, c]) => c.amount).sort((a, b) => a - b);
    // 40 for the first edit, 10 for the second: 50 in all, never 40 + 50
    expect(amounts).toEqual([10, 40]);
    expect(amounts.reduce((a, b) => a + b, 0)).toBe(50);
  });

  test('an invoice already below what was paid gets credit only for the further drop', async () => {
    const db = makeDb(seed({invoice: {paid_amount: 100, total_amount: 80, status: 'paid', items: [{description: 'Tuition - Amina', quantity: 1, unit_price: 80, total: 80, student_id: 'stu_1', shift_ids: []}]}}));
    await call(editInvoice, depsFor(db), goodEdit({lines: lines(70)}));
    expect(credits(db).map(([, c]) => c.amount)).toEqual([10]);
  });

  test('raising the total again takes back the open credit by the difference', async () => {
    const db = makeDb(seed({invoice: {paid_amount: 100, status: 'paid'}}));
    const deps = depsFor(db);
    const first = await call(editInvoice, deps, goodEdit({lines: lines(60)}));
    expect(db.store.family_credits[first.credit_id].amount).toBe(40);

    const second = await call(editInvoice, deps, goodEdit({lines: lines(80), reason: 'Back up'}));
    expect(second.credit_id).toBeUndefined();
    expect(db.store.family_credits[first.credit_id]).toMatchObject({status: 'open', amount: 20, original_amount: 40});
    expect(credits(db)).toHaveLength(1); // never a negative or extra credit
    // The 20 given back to the invoice is paid again: 60 + 20.
    expect(db.store.invoices.inv_1).toMatchObject({total_amount: 80, paid_amount: 80, status: 'paid'});
    expect(db.store.invoices.inv_1.edit_history[1].before.paid_amount).toBe(60);
    expect(db.store.invoices.inv_1.edit_history[1].after.paid_amount).toBe(80);
  });

  test('paid plus open credit always add up to the money received', async () => {
    const db = makeDb(seed({invoice: {paid_amount: 100, status: 'paid'}}));
    const deps = depsFor(db);
    const openCredit = () => credits(db).filter(([, c]) => c.status === 'open').reduce((sum, [, c]) => sum + c.amount, 0);
    for (const amount of [60, 80, 70, 100, 90]) {
      await call(editInvoice, deps, goodEdit({lines: lines(amount), reason: `Set ${amount}`}));
      expect(db.store.invoices.inv_1.paid_amount + openCredit()).toBe(100);
      expect(db.store.invoices.inv_1.paid_amount).toBe(amount);
    }
  });

  test('raising beyond the original total keeps what was paid and owes the rest', async () => {
    const db = makeDb(seed({invoice: {paid_amount: 100, status: 'paid'}}));
    const deps = depsFor(db);
    await call(editInvoice, deps, goodEdit({lines: lines(60)}));
    await call(editInvoice, deps, goodEdit({lines: lines(150), reason: 'Added a student'}));
    expect(db.store.invoices.inv_1).toMatchObject({total_amount: 150, paid_amount: 100, status: 'pending'});
    expect(credits(db).filter(([, c]) => c.status === 'open')).toHaveLength(0);
  });

  test('an older invoice left with paid above its total is brought back to the total', async () => {
    const db = makeDb(seed({invoice: {paid_amount: 100, total_amount: 60, status: 'paid', items: [{description: 'Tuition - Amina', quantity: 1, unit_price: 60, total: 60, student_id: 'stu_1', shift_ids: []}]}}));
    db.store.family_credits.old = {source: 'invoice_edit', status: 'open', amount: 40, invoice_id: 'inv_1'};
    await call(editInvoice, depsFor(db), goodEdit({lines: lines(80)}));
    expect(db.store.invoices.inv_1).toMatchObject({total_amount: 80, paid_amount: 80, status: 'paid'});
    expect(db.store.family_credits.old).toMatchObject({status: 'open', amount: 20});
  });

  test('raising to or past the paid amount cancels the open credit', async () => {
    const db = makeDb(seed({invoice: {paid_amount: 100, status: 'paid'}}));
    const deps = depsFor(db);
    const first = await call(editInvoice, deps, goodEdit({lines: lines(60)}));
    await call(editInvoice, deps, goodEdit({lines: lines(130), reason: 'Back up past paid'}));
    expect(db.store.family_credits[first.credit_id]).toMatchObject({status: 'cancelled'});
    expect(db.store.invoices.inv_1.status).toBe('pending');
    expect(credits(db)).toHaveLength(1);
  });

  test('a credit that was already used is left alone when the total goes back up', async () => {
    const s = seed({invoice: {paid_amount: 100, total_amount: 60, status: 'paid', items: [{description: 'Tuition - Amina', quantity: 1, unit_price: 60, total: 60, student_id: 'stu_1', shift_ids: []}]}});
    s.family_credits.used_1 = {source: 'invoice_edit', status: 'used', amount: 40, invoice_id: 'inv_1', used_on_invoice_id: 'inv_9'};
    const db = makeDb(s);
    await call(editInvoice, depsFor(db), goodEdit({lines: lines(100)}));
    expect(db.store.family_credits.used_1).toMatchObject({status: 'used', amount: 40});
    expect(credits(db)).toHaveLength(1);
    // Those 40 were used elsewhere, so only 60 is paid here and 40 is owed.
    expect(db.store.invoices.inv_1).toMatchObject({total_amount: 100, paid_amount: 60, status: 'pending'});
  });

  test('only credits of this invoice and source invoice_edit are touched', async () => {
    const s = seed({invoice: {paid_amount: 100, status: 'paid'}});
    s.family_credits.other = {source: 'invoice_edit', status: 'open', amount: 25, invoice_id: 'inv_other'};
    s.family_credits.manual = {source: 'manual', status: 'open', amount: 25, invoice_id: 'inv_1'};
    const db = makeDb(s);
    const deps = depsFor(db);
    await call(editInvoice, deps, goodEdit({lines: lines(60)}));
    await call(editInvoice, deps, goodEdit({lines: lines(100), reason: 'Back'}));
    expect(db.store.family_credits.other.amount).toBe(25);
    expect(db.store.family_credits.manual.amount).toBe(25);
  });
});

describe('cancelInvoice: family credits used on the invoice come back', () => {
  test('a credit used in full is reopened', async () => {
    const s = seed({invoice: {credit_applied: 30, credit_lines: [{credit_id: 'c1', amount: 30}]}});
    s.family_credits.c1 = {parent_id: 'parent_1', amount: 30, status: 'used', used_on_invoice_id: 'inv_1', closed_at: SERVER_TS, closed_by: 'system'};
    s.family_credits.unrelated = {parent_id: 'parent_1', amount: 5, status: 'used', used_on_invoice_id: 'inv_2'};
    const db = makeDb(s);
    await call(cancelInvoice, depsFor(db), {invoice_id: 'inv_1', reason: 'Enrolled twice'});
    expect(db.store.family_credits.c1).toMatchObject({status: 'open', used_on_invoice_id: null, amount: 30});
    expect(db.store.family_credits.c1.closed_at).toBeUndefined();
    expect(db.store.family_credits.unrelated).toMatchObject({status: 'used', used_on_invoice_id: 'inv_2'});
    expect(db.store.invoices.inv_1.status).toBe('cancelled');
  });

  test('a credit used in part: the used piece reopens next to the remainder (original amount restored in total)', async () => {
    const s = seed();
    s.family_credits.c2 = {parent_id: 'parent_1', amount: 30, original_amount: 50, status: 'used', used_on_invoice_id: 'inv_1'};
    s.family_credits['c2__rest_inv_1'] = {parent_id: 'parent_1', amount: 20, status: 'open', split_from: 'c2', used_on_invoice_id: null};
    const db = makeDb(s);
    await call(cancelInvoice, depsFor(db), {invoice_id: 'inv_1', reason: 'x'});
    const open = Object.values(db.store.family_credits).filter((c) => c.status === 'open');
    expect(open.reduce((sum, c) => sum + c.amount, 0)).toBe(50);
    expect(db.store.family_credits.c2).toMatchObject({status: 'open', used_on_invoice_id: null, amount: 30});
  });

  test('credits are not touched when the cancel is refused', async () => {
    const s = seed({invoice: {paid_amount: 10}});
    s.family_credits.c1 = {amount: 30, status: 'used', used_on_invoice_id: 'inv_1'};
    const db = makeDb(s);
    await expect(call(cancelInvoice, depsFor(db), {invoice_id: 'inv_1', reason: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.store.family_credits.c1.status).toBe('used');
  });
});

describe('edit and cancel: month lock', () => {
  const closedSeed = (over) => {
    const s = seed(over);
    s.finance_months = {'2026-10': {status: 'closed'}};
    return s;
  };

  test('a month closed after the early check is still refused inside the transaction (edit)', async () => {
    const db = makeDb(closedSeed());
    // the early check passes (as if it ran just before the close)
    await expect(call(editInvoice, depsFor(db), goodEdit())).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.writes).toHaveLength(0);
  });

  test('a month closed after the early check is still refused inside the transaction (cancel)', async () => {
    const s = closedSeed();
    const db = makeDb(s);
    await expect(call(cancelInvoice, depsFor(db), {invoice_id: 'inv_1', reason: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.writes).toHaveLength(0);
    expect(db.store.invoices.inv_1.status).toBe('pending');
  });

  test('an open month record does not block', async () => {
    const s = seed();
    s.finance_months = {'2026-10': {status: 'open'}};
    const db = makeDb(s);
    await expect(call(cancelInvoice, depsFor(db), {invoice_id: 'inv_1', reason: 'x'})).resolves.toEqual({ok: true});
  });

  test('an invoice with no month at all fails closed (edit and cancel)', async () => {
    const noMonth = {period: undefined, period_start: undefined, billing_month: undefined, issued_date: undefined, created_at: undefined};
    const db = makeDb(seed({invoice: noMonth}));
    const deps = depsFor(db);
    await expect(call(editInvoice, deps, goodEdit())).rejects.toMatchObject({code: 'failed-precondition'});
    await expect(call(cancelInvoice, deps, {invoice_id: 'inv_1', reason: 'x'})).rejects.toMatchObject({code: 'failed-precondition'});
    expect(deps.assertMonthOpen).not.toHaveBeenCalled();
    expect(db.writes).toHaveLength(0);
  });
});
