/**
 * Finance expense callables.
 *
 * Expected behavior:
 * - Every callable is admin-only (the gate is the injected verifyAdmin).
 * - Adding a one-time expense writes finance_expenses with its month and date;
 *   adding a recurring one writes the cost AND a 'created' confirmation for that
 *   month, and a second running cost with the same name is refused.
 * - Delete is a soft delete and needs a reason; restore undoes it; a closed
 *   month refuses both (and every other mutation) with the lock's error.
 * - Confirming records the real amount for a month the cost runs in.
 * - Stopping sets end_month and leaves earlier months alone; it refuses when a
 *   later month is already confirmed.
 * - Resolving a credit moves an open credit to refunded or cancelled, once.
 * - Discount totals add discount lines per billing month and skip cancelled invoices.
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

const handlers = require('../handlers/finance_expenses');

const SERVER_TS = {__ts: 'server'};
const FieldValue = {serverTimestamp: () => SERVER_TS};
const Timestamp = {fromDate: (d) => ({__date: d.toISOString()})};
const NOW = new Date('2026-10-21T15:00:00Z');

// Copies plain data but keeps Timestamp-like values (anything with toDate) intact.
const clone = (value) => {
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === 'object' && typeof value.toDate !== 'function') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, clone(v)]));
  }
  return value;
};

function makeDb(seed = {}) {
  const store = clone(seed);
  let autoId = 0;
  const ref = (collection, id) => ({collection, id, path: `${collection}/${id}`});
  const get = (r) => {
    const data = store[r.collection] && store[r.collection][r.id];
    return {id: r.id, exists: Boolean(data), data: () => clone(data)};
  };
  const put = (r, data, merge) => {
    store[r.collection] = store[r.collection] || {};
    store[r.collection][r.id] = merge ? {...store[r.collection][r.id], ...data} : {...data};
  };
  const docRef = (collection, id) => {
    const r = ref(collection, id || `auto_${++autoId}`);
    r.get = async () => get(r);
    r.set = async (data) => put(r, data, false);
    return r;
  };
  const query = (collection, filters = []) => ({
    where: (field, op, value) => query(collection, [...filters, {field, op, value}]),
    get: async () => {
      const rows = Object.entries(store[collection] || {})
        .filter(([, data]) =>
          filters.every((f) => {
            if (f.op === '==') return data[f.field] === f.value;
            if (f.op === '>=') return String(data[f.field]?.__date || data[f.field]) >= String(f.value.__date || f.value);
            throw new Error(`op ${f.op}`);
          })
        )
        .map(([id]) => get(ref(collection, id)));
      return {docs: rows, empty: rows.length === 0, size: rows.length};
    },
  });
  const db = {
    store,
    collection: (name) => ({doc: (id) => docRef(name, id), ...query(name)}),
    batch: () => {
      const ops = [];
      return {
        set: (r, data) => ops.push(() => put(r, data, false)),
        commit: async () => ops.forEach((op) => op()),
      };
    },
    runTransaction: async (fn) => {
      const pending = [];
      let wrote = false;
      const tx = {
        get: async (r) => {
          if (wrote) throw new Error('reads must come before writes');
          return get(r);
        },
        set: (r, data) => {
          wrote = true;
          pending.push(() => put(r, data, false));
        },
        update: (r, data) => {
          wrote = true;
          if (!store[r.collection] || !store[r.collection][r.id]) throw new Error(`no doc ${r.path}`);
          pending.push(() => put(r, data, true));
        },
      };
      const result = await fn(tx);
      pending.forEach((op) => op());
      return result;
    },
  };
  return db;
}

const closedError = (month) => {
  const e = new Error(`${month} is closed. Reopen it to change it.`);
  e.code = 'failed-precondition';
  return e;
};

function setup(seed = {}, {closed = []} = {}) {
  const db = makeDb({users: {admin1: {first_name: 'Hashim', last_name: 'Niane'}}, ...seed});
  const checked = [];
  const deps = {
    db,
    FieldValue,
    Timestamp,
    now: () => NOW,
    verifyAdmin: jest.fn(async () => ({callerUid: 'admin1', effectiveAdminEmail: 'a@b.c'})),
    assertMonthOpen: jest.fn(async (_db, month) => {
      checked.push(month);
      if (closed.includes(month)) throw closedError(month);
    }),
  };
  return {db, deps, checked, store: db.store};
}

const req = (data) => ({data, auth: {uid: 'admin1'}});

describe('admin gate', () => {
  test('a non-admin is refused before anything is read', async () => {
    const {deps, store} = setup();
    deps.verifyAdmin.mockRejectedValue(Object.assign(new Error('Only administrators'), {code: 'permission-denied'}));
    await expect(
      handlers.addFinanceExpense(req({month: '2026-10', kind: 'one_time', category: 'other', name: 'x', amount: 5}), deps)
    ).rejects.toMatchObject({code: 'permission-denied'});
    expect(store.finance_expenses).toBeUndefined();
  });
});

describe('addFinanceExpense', () => {
  test('one-time writes a month, date and who added it', async () => {
    const {deps, store, checked} = setup();
    const {id} = await handlers.addFinanceExpense(
      req({month: '2026-10', kind: 'one_time', category: 'marketing', name: 'Flyers', amount: '25.5', date: '2026-10-12'}),
      deps
    );
    expect(store.finance_expenses[id]).toMatchObject({
      month: '2026-10',
      kind: 'one_time',
      category: 'marketing',
      name: 'Flyers',
      amount: 25.5,
      expense_date: {__date: '2026-10-12T12:00:00.000Z'},
      deleted: false,
      created_by: 'admin1',
      created_by_name: 'Hashim Niane',
    });
    expect(checked).toEqual(['2026-10']);
  });

  test('recurring writes the cost and a created confirmation for that month', async () => {
    const {deps, store} = setup();
    const {id} = await handlers.addFinanceExpense(
      req({month: '2026-10', kind: 'recurring', category: 'software', name: 'Zoom', amount: 150, day_of_month: 14}),
      deps
    );
    expect(store.finance_recurring_costs[id]).toMatchObject({
      name: 'Zoom',
      category: 'software',
      amount: 150,
      day_of_month: 14,
      start_month: '2026-10',
      end_month: null,
    });
    expect(store.finance_recurring_confirmations[`2026-10_${id}`]).toMatchObject({
      cost_id: id,
      month: '2026-10',
      amount: 150,
      source: 'created',
    });
  });

  test('a second running cost with the same name is refused', async () => {
    const {deps} = setup({
      finance_recurring_costs: {z: {name: 'zoom', start_month: '2026-01', end_month: null}},
    });
    await expect(
      handlers.addFinanceExpense(req({month: '2026-10', kind: 'recurring', category: 'software', name: 'Zoom', amount: 150}), deps)
    ).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('a stopped cost with the same name can be added again', async () => {
    const {deps} = setup({
      finance_recurring_costs: {z: {name: 'Zoom', start_month: '2026-01', end_month: '2026-06'}},
    });
    await expect(
      handlers.addFinanceExpense(req({month: '2026-10', kind: 'recurring', category: 'software', name: 'Zoom', amount: 150}), deps)
    ).resolves.toHaveProperty('id');
  });

  test('refuses pay categories and bad input without writing', async () => {
    const {deps, store} = setup();
    await expect(
      handlers.addFinanceExpense(req({month: '2026-10', kind: 'one_time', category: 'teacher_pay', name: 'x', amount: 5}), deps)
    ).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(
      handlers.addFinanceExpense(req({month: '2026-10', kind: 'one_time', category: 'other', name: '', amount: 5}), deps)
    ).rejects.toMatchObject({code: 'invalid-argument'});
    expect(store.finance_expenses).toBeUndefined();
  });

  test('a closed month refuses and writes nothing', async () => {
    const {deps, store} = setup({}, {closed: ['2026-09']});
    await expect(
      handlers.addFinanceExpense(req({month: '2026-09', kind: 'one_time', category: 'other', name: 'x', amount: 5}), deps)
    ).rejects.toThrow('2026-09 is closed');
    expect(store.finance_expenses).toBeUndefined();
    await expect(
      handlers.addFinanceExpense(req({month: '2026-09', kind: 'recurring', category: 'other', name: 'x', amount: 5}), deps)
    ).rejects.toThrow('closed');
    expect(store.finance_recurring_costs).toBeUndefined();
  });
});

describe('deleteFinanceExpense / restoreFinanceExpense', () => {
  const seed = () => ({
    finance_expenses: {
      e1: {month: '2026-10', category: 'marketing', name: 'Flyers', amount: 25, deleted: false},
      legacy: {category: 'r_and_d', vendor: 'Zoom', amount: 50, expense_date: {toDate: () => new Date('2026-09-01T04:00:00Z')}},
    },
  });

  test('soft delete needs a reason and keeps the row', async () => {
    const {deps, store} = setup(seed());
    await expect(handlers.deleteFinanceExpense(req({id: 'e1', reason: '  '}), deps)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
    await handlers.deleteFinanceExpense(req({id: 'e1', reason: 'Entered twice'}), deps);
    expect(store.finance_expenses.e1).toMatchObject({
      deleted: true,
      deleted_at: SERVER_TS,
      deleted_by: 'admin1',
      deleted_by_name: 'Hashim Niane',
      delete_reason: 'Entered twice',
      name: 'Flyers',
      amount: 25,
    });
  });

  test('deleting twice is refused', async () => {
    const {deps} = setup(seed());
    await handlers.deleteFinanceExpense(req({id: 'e1', reason: 'dup'}), deps);
    await expect(handlers.deleteFinanceExpense(req({id: 'e1', reason: 'dup'}), deps)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  test('a missing expense is not-found', async () => {
    const {deps} = setup(seed());
    await expect(handlers.deleteFinanceExpense(req({id: 'nope', reason: 'x'}), deps)).rejects.toMatchObject({code: 'not-found'});
  });

  test('a legacy row without month is checked against the month of its date', async () => {
    const {deps, checked, store} = setup(seed());
    await handlers.deleteFinanceExpense(req({id: 'legacy', reason: 'Not ours'}), deps);
    expect(checked).toEqual(['2026-09']);
    expect(store.finance_expenses.legacy.deleted).toBe(true);
  });

  test('a closed month refuses delete and restore', async () => {
    const {deps, store} = setup(seed(), {closed: ['2026-10']});
    await expect(handlers.deleteFinanceExpense(req({id: 'e1', reason: 'x'}), deps)).rejects.toThrow('closed');
    expect(store.finance_expenses.e1.deleted).toBe(false);

    const open = setup(seed());
    await handlers.deleteFinanceExpense(req({id: 'e1', reason: 'x'}), open.deps);
    open.deps.assertMonthOpen.mockImplementation(async () => {
      throw closedError('2026-10');
    });
    await expect(handlers.restoreFinanceExpense(req({id: 'e1'}), open.deps)).rejects.toThrow('closed');
    expect(open.store.finance_expenses.e1.deleted).toBe(true);
  });

  test('restore brings it back and records who', async () => {
    const {deps, store} = setup(seed());
    await handlers.deleteFinanceExpense(req({id: 'e1', reason: 'x'}), deps);
    await handlers.restoreFinanceExpense(req({id: 'e1'}), deps);
    expect(store.finance_expenses.e1).toMatchObject({deleted: false, restored_by: 'admin1', restored_at: SERVER_TS});
    await expect(handlers.restoreFinanceExpense(req({id: 'e1'}), deps)).rejects.toMatchObject({code: 'failed-precondition'});
  });
});

describe('confirmRecurringCost', () => {
  const seed = () => ({
    finance_recurring_costs: {zoom: {name: 'Zoom', category: 'software', amount: 150, day_of_month: 14, start_month: '2026-08', end_month: null}},
  });

  test('records the real amount for the month', async () => {
    const {deps, store, checked} = setup(seed());
    await handlers.confirmRecurringCost(req({month: '2026-10', cost_id: 'zoom', amount: '149.9', source: 'manual'}), deps);
    expect(store.finance_recurring_confirmations['2026-10_zoom']).toMatchObject({
      cost_id: 'zoom',
      month: '2026-10',
      amount: 149.9,
      source: 'manual',
      confirmed_by: 'admin1',
    });
    expect(checked).toEqual(['2026-10']);
  });

  test('confirming again replaces the amount and keeps the old one in history', async () => {
    const {deps, store} = setup(seed());
    await handlers.confirmRecurringCost(req({month: '2026-10', cost_id: 'zoom', amount: 150}), deps);
    await handlers.confirmRecurringCost(req({month: '2026-10', cost_id: 'zoom', amount: 160, source: 'bank', bank_transaction_id: 'tx1'}), deps);
    const c = store.finance_recurring_confirmations['2026-10_zoom'];
    expect(c).toMatchObject({amount: 160, source: 'bank', bank_transaction_id: 'tx1'});
    expect(c.history).toHaveLength(1);
    expect(c.history[0]).toMatchObject({amount: 150, source: 'manual'});
  });

  test('refuses a month the cost does not run in, a bad source and a missing cost', async () => {
    const {deps} = setup(seed());
    await expect(handlers.confirmRecurringCost(req({month: '2026-07', cost_id: 'zoom', amount: 1}), deps)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    await expect(
      handlers.confirmRecurringCost(req({month: '2026-10', cost_id: 'zoom', amount: 1, source: 'card'}), deps)
    ).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(handlers.confirmRecurringCost(req({month: '2026-10', cost_id: 'nope', amount: 1}), deps)).rejects.toMatchObject({
      code: 'not-found',
    });
    await expect(handlers.confirmRecurringCost(req({month: '2026-10', cost_id: 'zoom', amount: -1}), deps)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
  });

  test('a closed month refuses', async () => {
    const {deps, store} = setup(seed(), {closed: ['2026-09']});
    await expect(handlers.confirmRecurringCost(req({month: '2026-09', cost_id: 'zoom', amount: 150}), deps)).rejects.toThrow('closed');
    expect(store.finance_recurring_confirmations).toBeUndefined();
  });
});

describe('stopRecurringCost', () => {
  const seed = () => ({
    finance_recurring_costs: {zoom: {name: 'Zoom', amount: 150, start_month: '2026-08', end_month: null}},
    finance_recurring_confirmations: {
      '2026-09_zoom': {cost_id: 'zoom', month: '2026-09', amount: 140},
      '2026-10_zoom': {cost_id: 'zoom', month: '2026-10', amount: 150},
    },
  });

  test('sets end_month and leaves earlier confirmations alone', async () => {
    const {deps, store, checked} = setup(seed());
    await handlers.stopRecurringCost(req({cost_id: 'zoom', last_month: '2026-10'}), deps);
    expect(store.finance_recurring_costs.zoom).toMatchObject({end_month: '2026-10', stopped_by: 'admin1'});
    expect(Object.keys(store.finance_recurring_confirmations)).toHaveLength(2);
    expect(checked).toEqual(['2026-10']);
  });

  test('refuses when a later month is already confirmed', async () => {
    const {deps, store} = setup(seed());
    await expect(handlers.stopRecurringCost(req({cost_id: 'zoom', last_month: '2026-09'}), deps)).rejects.toThrow(
      'October is already confirmed'
    );
    expect(store.finance_recurring_costs.zoom.end_month).toBeNull();
  });

  test('refuses before the start month and when it already stops sooner', async () => {
    const {deps} = setup(seed());
    await expect(handlers.stopRecurringCost(req({cost_id: 'zoom', last_month: '2026-07'}), deps)).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    await handlers.stopRecurringCost(req({cost_id: 'zoom', last_month: '2026-10'}), deps);
    await expect(handlers.stopRecurringCost(req({cost_id: 'zoom', last_month: '2026-11'}), deps)).rejects.toThrow('already stops');
  });

  test('a closed last month refuses', async () => {
    const {deps, store} = setup(seed(), {closed: ['2026-10']});
    await expect(handlers.stopRecurringCost(req({cost_id: 'zoom', last_month: '2026-10'}), deps)).rejects.toThrow('closed');
    expect(store.finance_recurring_costs.zoom.end_month).toBeNull();
  });
});

describe('resolveFamilyCredit', () => {
  const seed = () => ({
    family_credits: {
      c1: {parent_id: 'p1', amount: 40, status: 'open'},
      c2: {parent_id: 'p2', amount: 10, status: 'used'},
    },
  });

  test('refund closes the credit and records the amount refunded', async () => {
    const {deps, store, checked} = setup(seed());
    await handlers.resolveFamilyCredit(req({credit_id: 'c1', action: 'refund', reason: 'Family left'}), deps);
    expect(store.family_credits.c1).toMatchObject({
      status: 'refunded',
      closed_by: 'admin1',
      closed_at: SERVER_TS,
      resolution_reason: 'Family left',
      refunded_amount: 40,
    });
    expect(checked).toEqual(['2026-10']);
    expect(store.finance_expenses).toBeUndefined();
  });

  test('cancel closes it without a refunded amount', async () => {
    const {deps, store} = setup(seed());
    await handlers.resolveFamilyCredit(req({credit_id: 'c1', action: 'cancel', reason: 'Entered by mistake'}), deps);
    expect(store.family_credits.c1.status).toBe('cancelled');
    expect(store.family_credits.c1.refunded_amount).toBeUndefined();
  });

  test('needs a reason and a valid action; only open credits resolve', async () => {
    const {deps} = setup(seed());
    await expect(handlers.resolveFamilyCredit(req({credit_id: 'c1', action: 'refund', reason: ''}), deps)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
    await expect(handlers.resolveFamilyCredit(req({credit_id: 'c1', action: 'void', reason: 'x'}), deps)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
    await expect(handlers.resolveFamilyCredit(req({credit_id: 'c2', action: 'cancel', reason: 'x'}), deps)).rejects.toThrow('already used');
    await handlers.resolveFamilyCredit(req({credit_id: 'c1', action: 'cancel', reason: 'x'}), deps);
    await expect(handlers.resolveFamilyCredit(req({credit_id: 'c1', action: 'refund', reason: 'x'}), deps)).rejects.toThrow(
      'already cancelled'
    );
  });

  test('a closed current month refuses', async () => {
    const {deps, store} = setup(seed(), {closed: ['2026-10']});
    await expect(handlers.resolveFamilyCredit(req({credit_id: 'c1', action: 'refund', reason: 'x'}), deps)).rejects.toThrow('closed');
    expect(store.family_credits.c1.status).toBe('open');
  });
});

describe('getFinanceDiscountTotals', () => {
  const t = (iso) => ({__date: iso, toDate: () => new Date(iso)});
  const seed = () => ({
    invoices: {
      a: {period: '2026-10', issued_date: t('2026-10-01T00:00:00.000Z'), items: [{total: 100}, {total: -10, is_discount: true}]},
      b: {period: '2026-10', issued_date: t('2026-10-02T00:00:00.000Z'), items: [{total: -5, is_discount: true}]},
      c: {period: '2026-09', issued_date: t('2026-09-02T00:00:00.000Z'), items: [{total: -7.5, is_discount: true}]},
      d: {period: '2026-09', issued_date: t('2026-09-03T00:00:00.000Z'), status: 'cancelled', items: [{total: -99, is_discount: true}]},
      e: {period: '2025-12', issued_date: t('2025-12-10T00:00:00.000Z'), items: [{total: -50, is_discount: true}]},
    },
  });

  test('adds discount lines per billing month, skipping cancelled invoices and other years', async () => {
    const {deps} = setup(seed());
    const result = await handlers.getFinanceDiscountTotals(req({through_month: '2026-10'}), deps);
    expect(result.year).toBe(2026);
    expect(result.by_month['2026-10']).toBe(15);
    expect(result.by_month['2026-09']).toBe(7.5);
    expect(result.by_month['2026-01']).toBe(0);
    expect(Object.keys(result.by_month)).toHaveLength(12);
  });
});
