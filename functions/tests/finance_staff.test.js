/**
 * Staff pay callables and the deactivation trigger.
 *
 * Expected behavior:
 * - Admin-only; every mutation asks the month lock first and writes nothing
 *   when the month is closed.
 * - Only FINAL teacher pay (audit ceoApproved | completed) can be paid.
 * - A paused administrator cannot be paid for a paused month.
 * - Partial pay is recorded as given; a second payout adds to the first.
 * - A void keeps the document (voided:true + reason).
 * - Terms need a reason on change; pause/resume maintain pauses[].
 * - Deactivating an administrator auto-pauses from the current month, once;
 *   reactivating never resumes.
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

const {
  recordStaffPayouts,
  voidStaffPayout,
  setAdminPayTerms,
  pauseAdminPay,
  resumeAdminPay,
  autoPauseOnDeactivation,
} = require('../handlers/finance_staff');

const NOW = {seconds: 1760900000, nanoseconds: 0};
const Timestamp = {now: () => NOW};

function makeDb(seed) {
  const store = JSON.parse(JSON.stringify(seed));
  const writes = [];
  const ref = (collection, id) => ({id, collection, path: `${collection}/${id}`});
  const snap = (r) => ({
    id: r.id,
    exists: Boolean(store[r.collection] && store[r.collection][r.id]),
    data: () => JSON.parse(JSON.stringify(store[r.collection][r.id])),
  });
  return {
    store,
    writes,
    collection: (name) => ({
      doc: (id) => {
        const r = ref(name, id);
        r.get = async () => snap(r);
        return r;
      },
    }),
    runTransaction: async (fn) => {
      const pending = [];
      let wrote = false;
      const tx = {
        get: async (r) => {
          if (wrote) throw new Error('reads must come before writes');
          return snap(r);
        },
        set: (r, data) => {
          wrote = true;
          pending.push([r, data]);
        },
      };
      const result = await fn(tx);
      for (const [r, data] of pending) {
        writes.push(r.path);
        store[r.collection] = store[r.collection] || {};
        store[r.collection][r.id] = JSON.parse(JSON.stringify(data));
      }
      return result;
    },
  };
}

const audit = (status, net, name = 'Aisha Bah') => ({
  status,
  teacherName: name,
  paymentSummary: {totalNetPayment: net, totalPenalties: 0},
});

const seed = () => ({
  users: {
    admin_1: {first_name: 'Hawa', last_name: 'Admin', user_type: 'admin'},
    adm_2: {first_name: 'Sajor', last_name: 'Bah', user_type: 'admin', title: 'Coordinator'},
  },
  teacher_audits: {
    't1_2026-09': audit('ceoApproved', 206.4),
    't2_2026-09': audit('coachSubmitted', 80, 'Omar Diallo'),
    't3_2026-09': audit('completed', 120, 'Fanta Camara'),
  },
  admin_pay_terms: {
    adm_2: {
      name: 'Sajor Bah',
      role_title: 'Coordinator',
      terms: [{from_month: '2026-01', fixed: 300, pct: 5, note: 'Start'}],
      pauses: [],
    },
    adm_3: {
      name: 'Paused Person',
      terms: [{from_month: '2026-01', fixed: 200, pct: 0, note: 'Start'}],
      pauses: [{from_month: '2026-08', until_month: null, reason: 'On leave', auto: false}],
    },
  },
});

const makeDeps = (db, closed = false) => {
  const assertMonthOpen = jest.fn(async () => {
    if (closed) {
      const e = new Error('This month is closed.');
      e.code = 'failed-precondition';
      throw e;
    }
  });
  return {
    db,
    Timestamp,
    verifyAdmin: async () => ({callerUid: 'admin_1', effectiveAdminEmail: 'hawa@example.com'}),
    assertMonthOpen,
  };
};

const entry = (over = {}) => ({
  uid: 't1',
  role: 'teacher',
  amount_paid: 206.4,
  method: 'Mobile money',
  date_paid: '2026-10-03',
  ...over,
});

describe('recordStaffPayouts', () => {
  test('refuses a caller the admin gate refuses', async () => {
    const db = makeDb(seed());
    const deps = {
      ...makeDeps(db),
      verifyAdmin: async () => {
        const e = new Error('no');
        e.code = 'permission-denied';
        throw e;
      },
    };
    await expect(recordStaffPayouts({data: {month: '2026-09', entries: [entry()]}}, deps)).rejects.toMatchObject({code: 'permission-denied'});
    expect(db.writes).toEqual([]);
  });

  test('pays a final teacher and stores due, paid, fee and reference', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    const out = await recordStaffPayouts(
      {data: {month: '2026-09', entries: [entry({transfer_fee: 3, reference: 'TX-9', note: 'Sept'})]}},
      deps
    );
    expect(out).toEqual({ok: true, count: 1});
    expect(deps.assertMonthOpen).toHaveBeenCalledWith(db, '2026-09');
    expect(db.store.staff_payouts['2026-09_t1_teacher']).toMatchObject({
      user_id: 't1',
      name: 'Aisha Bah',
      role: 'teacher',
      month: '2026-09',
      amount_due: 206.4,
      amount_paid: 206.4,
      transfer_fee: 3,
      reference: 'TX-9',
      note: 'Sept',
      method: 'Mobile money',
      date_paid: '2026-10-03',
      voided: false,
      recorded_by: 'admin_1',
    });
  });

  test('refuses an estimate (audit not approved) and writes nothing for anyone', async () => {
    const db = makeDb(seed());
    await expect(
      recordStaffPayouts({data: {month: '2026-09', entries: [entry(), entry({uid: 't2', amount_paid: 80})]}}, makeDeps(db))
    ).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.writes).toEqual([]);
  });

  test('refuses a teacher with no audit that month', async () => {
    const db = makeDb(seed());
    await expect(recordStaffPayouts({data: {month: '2026-09', entries: [entry({uid: 'ghost'})]}}, makeDeps(db))).rejects.toMatchObject({
      code: 'failed-precondition',
    });
  });

  test('records partial pay as given, and a second payout adds to it', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    await recordStaffPayouts({data: {month: '2026-09', entries: [entry({amount_paid: 150, transfer_fee: 2})]}}, deps);
    let doc = db.store.staff_payouts['2026-09_t1_teacher'];
    expect(doc.amount_due).toBe(206.4);
    expect(doc.amount_paid).toBe(150);
    await recordStaffPayouts({data: {month: '2026-09', entries: [entry({amount_paid: 56.4, date_paid: '2026-10-09', transfer_fee: 1})]}}, deps);
    doc = db.store.staff_payouts['2026-09_t1_teacher'];
    expect(doc.amount_paid).toBe(206.4);
    expect(doc.transfer_fee).toBe(3);
    expect(doc.history.filter((h) => h.action === 'payment')).toHaveLength(2);
  });

  test('a closed month writes nothing', async () => {
    const db = makeDb(seed());
    await expect(recordStaffPayouts({data: {month: '2026-09', entries: [entry()]}}, makeDeps(db, true))).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    expect(db.writes).toEqual([]);
  });

  test('never pays a paused administrator for a paused month', async () => {
    const db = makeDb(seed());
    await expect(
      recordStaffPayouts({data: {month: '2026-09', entries: [entry({uid: 'adm_3', role: 'admin', amount_paid: 200})]}}, makeDeps(db))
    ).rejects.toMatchObject({code: 'failed-precondition', message: expect.stringContaining('paused')});
    expect(db.writes).toEqual([]);
  });

  test('pays an administrator before the pause started', async () => {
    const db = makeDb(seed());
    await recordStaffPayouts({data: {month: '2026-07', entries: [entry({uid: 'adm_3', role: 'admin', amount_paid: 200})]}}, makeDeps(db));
    expect(db.store.staff_payouts['2026-07_adm_3_admin']).toMatchObject({role: 'admin', amount_due: 200, amount_paid: 200, name: 'Paused Person'});
  });

  test('an administrator is due the total the page shows when it sends one, else the fixed pay', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    await recordStaffPayouts({data: {month: '2026-09', entries: [entry({uid: 'adm_2', role: 'admin', amount_paid: 300})]}}, deps);
    expect(db.store.staff_payouts['2026-09_adm_2_admin'].amount_due).toBe(300);
    await recordStaffPayouts({data: {month: '2026-08', entries: [{...entry({uid: 'adm_2', role: 'admin', amount_paid: 412.5}), amount_due: 412.5}]}}, deps);
    expect(db.store.staff_payouts['2026-08_adm_2_admin'].amount_due).toBe(412.5);
  });

  test('validates the entry', async () => {
    const db = makeDb(seed());
    const call = (e, month = '2026-09') => recordStaffPayouts({data: {month, entries: e}}, makeDeps(db));
    await expect(call([])).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call([entry({amount_paid: 0})])).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call([entry({amount_paid: '5'})])).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call([entry({transfer_fee: -1})])).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call([entry({method: ' '})])).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call([entry({date_paid: 'Oct 3'})])).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call([entry({role: 'boss'})])).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call([entry(), entry()])).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call([entry()], '2026-9')).rejects.toMatchObject({code: 'invalid-argument'});
    expect(db.writes).toEqual([]);
  });

  test('pays several people at once', async () => {
    const db = makeDb(seed());
    const out = await recordStaffPayouts(
      {data: {month: '2026-09', entries: [entry(), entry({uid: 't3', amount_paid: 120, method: 'Bank transfer'})]}},
      makeDeps(db)
    );
    expect(out.count).toBe(2);
    expect(Object.keys(db.store.staff_payouts).sort()).toEqual(['2026-09_t1_teacher', '2026-09_t3_teacher']);
  });
});

describe('a person who is both a teacher and an administrator', () => {
  const dualSeed = () => {
    const data = seed();
    data.teacher_audits['adm_2_2026-09'] = audit('ceoApproved', 90, 'Sajor Bah');
    return data;
  };

  test('is paid for each role separately, even in one batch', async () => {
    const db = makeDb(dualSeed());
    await recordStaffPayouts(
      {data: {month: '2026-09', entries: [entry({uid: 'adm_2', role: 'teacher', amount_paid: 90}), entry({uid: 'adm_2', role: 'admin', amount_paid: 300})]}},
      makeDeps(db)
    );
    expect(Object.keys(db.store.staff_payouts).sort()).toEqual(['2026-09_adm_2_admin', '2026-09_adm_2_teacher']);
    expect(db.store.staff_payouts['2026-09_adm_2_teacher']).toMatchObject({role: 'teacher', amount_paid: 90});
    expect(db.store.staff_payouts['2026-09_adm_2_admin']).toMatchObject({role: 'admin', amount_paid: 300});
    await expect(
      recordStaffPayouts({data: {month: '2026-09', entries: [entry({uid: 't1'}), entry({uid: 't1'})]}}, makeDeps(db))
    ).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('a void needs the role when both payouts are live, and only touches that one', async () => {
    const db = makeDb(dualSeed());
    const deps = makeDeps(db);
    await recordStaffPayouts(
      {data: {month: '2026-09', entries: [entry({uid: 'adm_2', role: 'teacher', amount_paid: 90}), entry({uid: 'adm_2', role: 'admin', amount_paid: 300})]}},
      deps
    );
    await expect(voidStaffPayout({data: {month: '2026-09', uid: 'adm_2', reason: 'x'}}, deps)).rejects.toMatchObject({code: 'invalid-argument'});
    await voidStaffPayout({data: {month: '2026-09', uid: 'adm_2', role: 'admin', reason: 'x'}}, deps);
    expect(db.store.staff_payouts['2026-09_adm_2_admin'].voided).toBe(true);
    expect(db.store.staff_payouts['2026-09_adm_2_teacher'].voided).toBe(false);
    // With one live payout left, the role can be left out.
    await voidStaffPayout({data: {month: '2026-09', uid: 'adm_2', reason: 'y'}}, deps);
    expect(db.store.staff_payouts['2026-09_adm_2_teacher'].voided).toBe(true);
  });
});

describe('recordStaffPayouts: no over-payment, no repeats', () => {
  const pay = (db, entries, deps = makeDeps(db)) => recordStaffPayouts({data: {month: '2026-09', entries}}, deps);

  test('one payment above what is due is refused and writes nothing', async () => {
    const db = makeDb(seed());
    await expect(pay(db, [entry({amount_paid: 300})])).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('more than is owed'),
    });
    expect(db.writes).toEqual([]);
  });

  test('a second payment that takes the total past what is due is refused', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    await pay(db, [entry({amount_paid: 150, transfer_fee: 2})], deps);
    const before = JSON.stringify(db.store.staff_payouts);
    await expect(pay(db, [entry({amount_paid: 60, date_paid: '2026-10-09', transfer_fee: 2})], deps)).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('$150.00'),
    });
    expect(JSON.stringify(db.store.staff_payouts)).toBe(before);
  });

  test('paying exactly what is left (and a half cent of rounding) is accepted', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    await pay(db, [entry({amount_paid: 150})], deps);
    await pay(db, [entry({amount_paid: 56.4, date_paid: '2026-10-09'})], deps);
    expect(db.store.staff_payouts['2026-09_t1_teacher'].amount_paid).toBe(206.4);
  });

  test('an exact duplicate (same amount, date, method, reference) is refused', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    const e = entry({amount_paid: 50, reference: 'TX-1', transfer_fee: 1.5});
    await pay(db, [e], deps);
    await expect(pay(db, [e], deps)).rejects.toMatchObject({
      code: 'failed-precondition',
      message: expect.stringContaining('already has this exact payment'),
    });
    const doc = db.store.staff_payouts['2026-09_t1_teacher'];
    expect(doc.history.filter((h) => h.action === 'payment')).toHaveLength(1);
    expect(doc.amount_paid).toBe(50);
    expect(doc.transfer_fee).toBe(1.5); // the fee was not added again
  });

  test('the same amount on another date or with another reference is a different payment', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    await pay(db, [entry({amount_paid: 50, reference: 'TX-1', transfer_fee: 1})], deps);
    await pay(db, [entry({amount_paid: 50, reference: 'TX-2', transfer_fee: 1})], deps);
    await pay(db, [entry({amount_paid: 50, reference: 'TX-2', date_paid: '2026-10-04', transfer_fee: 1})], deps);
    const doc = db.store.staff_payouts['2026-09_t1_teacher'];
    expect(doc.amount_paid).toBe(150);
    expect(doc.transfer_fee).toBe(3); // once per accepted payment
  });

  test('a refused person stops the whole request: nobody else is paid either', async () => {
    const db = makeDb(seed());
    await expect(pay(db, [entry({amount_paid: 100}), entry({uid: 't3', amount_paid: 999, method: 'Bank'})])).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    expect(db.writes).toEqual([]);
  });

  test('after a void the payout starts again: the voided money no longer counts, nor blocks a repeat', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    await pay(db, [entry({amount_paid: 200, reference: 'R1'})], deps);
    await voidStaffPayout({data: {month: '2026-09', uid: 't1', role: 'teacher', reason: 'wrong account'}}, deps);
    await pay(db, [entry({amount_paid: 200, reference: 'R1'})], deps); // same entry, fine after the void
    expect(db.store.staff_payouts['2026-09_t1_teacher']).toMatchObject({amount_paid: 200, voided: false});
  });

  test('a close that lands after the early check is refused inside the transaction', async () => {
    const s = seed();
    s.finance_months = {'2026-09': {status: 'closed'}};
    const db = makeDb(s);
    await expect(pay(db, [entry()])).rejects.toMatchObject({code: 'failed-precondition', message: expect.stringContaining('closed')});
    expect(db.writes).toEqual([]);
  });

  test('a void after a close is refused too', async () => {
    const s = seed();
    const db = makeDb(s);
    const deps = makeDeps(db);
    await pay(db, [entry()], deps);
    db.store.finance_months = {'2026-09': {status: 'closed'}};
    await expect(
      voidStaffPayout({data: {month: '2026-09', uid: 't1', role: 'teacher', reason: 'x'}}, deps)
    ).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.store.staff_payouts['2026-09_t1_teacher'].voided).toBe(false);
  });
});

describe('voidStaffPayout', () => {
  const paidSeed = async () => {
    const db = makeDb(seed());
    await recordStaffPayouts({data: {month: '2026-09', entries: [entry()]}}, makeDeps(db));
    return db;
  };

  test('keeps the document, marks it voided with the reason', async () => {
    const db = await paidSeed();
    const out = await voidStaffPayout({data: {month: '2026-09', uid: 't1', reason: 'Wrong number'}}, makeDeps(db));
    expect(out).toEqual({ok: true});
    expect(db.store.staff_payouts['2026-09_t1_teacher']).toMatchObject({voided: true, void_reason: 'Wrong number', amount_paid: 0});
  });

  test('needs a reason, an existing payout, and an open month', async () => {
    const db = await paidSeed();
    await expect(voidStaffPayout({data: {month: '2026-09', uid: 't1', reason: ' '}}, makeDeps(db))).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(voidStaffPayout({data: {month: '2026-09', uid: 'nobody', reason: 'x'}}, makeDeps(db))).rejects.toMatchObject({code: 'not-found'});
    await expect(voidStaffPayout({data: {month: '2026-09', uid: 't1', reason: 'x'}}, makeDeps(db, true))).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.store.staff_payouts['2026-09_t1_teacher'].voided).toBe(false);
  });

  test('cannot void twice, and the person can be paid again afterwards', async () => {
    const db = await paidSeed();
    await voidStaffPayout({data: {month: '2026-09', uid: 't1', reason: 'x'}}, makeDeps(db));
    await expect(voidStaffPayout({data: {month: '2026-09', uid: 't1', reason: 'y'}}, makeDeps(db))).rejects.toMatchObject({code: 'failed-precondition'});
    await recordStaffPayouts({data: {month: '2026-09', entries: [entry({amount_paid: 100})]}}, makeDeps(db));
    expect(db.store.staff_payouts['2026-09_t1_teacher']).toMatchObject({voided: false, amount_paid: 100});
  });
});

describe('setAdminPayTerms', () => {
  test('a change needs a reason and keeps the earlier terms', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    await expect(setAdminPayTerms({data: {uid: 'adm_2', from_month: '2026-11', fixed: 350, pct: 5}}, deps)).rejects.toMatchObject({code: 'invalid-argument'});
    await setAdminPayTerms({data: {uid: 'adm_2', from_month: '2026-11', fixed: 350, pct: 7.5, note: 'Raise'}}, deps);
    const doc = db.store.admin_pay_terms.adm_2;
    expect(doc.terms.map((t) => [t.from_month, t.fixed, t.pct])).toEqual([
      ['2026-01', 300, 5],
      ['2026-11', 350, 7.5],
    ]);
    expect(doc.terms[1].note).toBe('Raise');
    expect(deps.assertMonthOpen).toHaveBeenCalledWith(db, '2026-11');
  });

  test('adds an existing user as an administrator', async () => {
    const db = makeDb(seed());
    await setAdminPayTerms({data: {uid: 'admin_1', from_month: '2026-10', fixed: 100, pct: 0}}, makeDeps(db));
    expect(db.store.admin_pay_terms.admin_1).toMatchObject({name: 'Hawa Admin', pauses: []});
    expect(db.store.admin_pay_terms.admin_1.terms[0]).toMatchObject({fixed: 100, pct: 0, note: 'Added'});
    await expect(setAdminPayTerms({data: {uid: 'nobody', from_month: '2026-10', fixed: 1, pct: 0}}, makeDeps(db))).rejects.toMatchObject({code: 'not-found'});
  });

  test('validates fixed, pct and the month lock', async () => {
    const db = makeDb(seed());
    const call = (d, closed) => setAdminPayTerms({data: {uid: 'adm_2', from_month: '2026-11', note: 'x', ...d}}, makeDeps(db, closed));
    await expect(call({fixed: -1, pct: 0})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call({fixed: 10, pct: 101})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call({fixed: 10, pct: -1})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call({fixed: 10, pct: 0}, true)).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.writes).toEqual([]);
  });
});

describe('pauseAdminPay / resumeAdminPay', () => {
  test('pause needs a reason, opens a manual pause, and cannot repeat', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    await expect(pauseAdminPay({data: {uid: 'adm_2', from_month: '2026-10', reason: ''}}, deps)).rejects.toMatchObject({code: 'invalid-argument'});
    await pauseAdminPay({data: {uid: 'adm_2', from_month: '2026-10', reason: 'On leave'}}, deps);
    expect(db.store.admin_pay_terms.adm_2.pauses).toEqual([
      expect.objectContaining({from_month: '2026-10', until_month: null, reason: 'On leave', auto: false}),
    ]);
    await expect(pauseAdminPay({data: {uid: 'adm_2', from_month: '2026-11', reason: 'again'}}, deps)).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('cannot pause a month they are already paid for', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    await recordStaffPayouts({data: {month: '2026-10', entries: [entry({uid: 'adm_2', role: 'admin', amount_paid: 300})]}}, deps);
    await expect(pauseAdminPay({data: {uid: 'adm_2', from_month: '2026-10', reason: 'x'}}, deps)).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('resume closes the open pause with until_month', async () => {
    const db = makeDb(seed());
    const deps = makeDeps(db);
    await resumeAdminPay({data: {uid: 'adm_3', from_month: '2026-11', reason: 'Back from leave'}}, deps);
    expect(db.store.admin_pay_terms.adm_3.pauses[0]).toMatchObject({from_month: '2026-08', until_month: '2026-11', resumed_reason: 'Back from leave'});
    await expect(resumeAdminPay({data: {uid: 'adm_3', from_month: '2026-11', reason: 'x'}}, deps)).rejects.toMatchObject({code: 'failed-precondition'});
  });

  test('resume cannot start before the pause, and needs a reason', async () => {
    const db = makeDb(seed());
    await expect(resumeAdminPay({data: {uid: 'adm_3', from_month: '2026-07', reason: 'x'}}, makeDeps(db))).rejects.toMatchObject({code: 'failed-precondition'});
    await expect(resumeAdminPay({data: {uid: 'adm_3', from_month: '2026-11', reason: ''}}, makeDeps(db))).rejects.toMatchObject({code: 'invalid-argument'});
  });

  test('closed months are locked', async () => {
    const db = makeDb(seed());
    await expect(pauseAdminPay({data: {uid: 'adm_2', from_month: '2026-10', reason: 'x'}}, makeDeps(db, true))).rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.writes).toEqual([]);
  });
});

describe('autoPauseOnDeactivation', () => {
  const NOW_D = new Date('2026-10-22T15:00:00Z');
  const run = (db, before, after) =>
    autoPauseOnDeactivation({db, Timestamp, uid: 'adm_2', before, after, now: NOW_D});

  test('pauses an administrator whose account was deactivated, from this month', async () => {
    const db = makeDb(seed());
    const out = await run(db, {is_active: true}, {is_active: false});
    expect(out).toMatchObject({paused: true, from_month: '2026-10', reason: 'Account deactivated Oct 22'});
    expect(db.store.admin_pay_terms.adm_2.pauses[0]).toMatchObject({from_month: '2026-10', until_month: null, auto: true, reason: 'Account deactivated Oct 22'});
  });

  test('uses deactivated_at for the date when present', async () => {
    const db = makeDb(seed());
    const out = await run(db, {is_active: true}, {is_active: false, deactivated_at: new Date('2026-10-18T12:00:00Z')});
    expect(out.reason).toBe('Account deactivated Oct 18');
  });

  test('is idempotent', async () => {
    const db = makeDb(seed());
    await run(db, {is_active: true}, {is_active: false});
    const again = await run(db, {is_active: true}, {is_active: false});
    expect(again).toMatchObject({paused: false, reason: 'already-paused'});
    expect(db.store.admin_pay_terms.adm_2.pauses).toHaveLength(1);
  });

  test('ignores users without admin pay, other updates, and reactivation', async () => {
    const db = makeDb(seed());
    expect(await autoPauseOnDeactivation({db, Timestamp, uid: 'teacher_9', before: {is_active: true}, after: {is_active: false}, now: NOW_D})).toMatchObject({paused: false});
    expect(await run(db, {is_active: true}, {is_active: true})).toMatchObject({paused: false});
    expect(await run(db, {is_active: false}, {is_active: false})).toMatchObject({paused: false});
    const paused = makeDb(seed());
    await run(paused, {is_active: true}, {is_active: false});
    await run(paused, {is_active: false}, {is_active: true}); // reactivation: pay stays paused
    expect(paused.store.admin_pay_terms.adm_2.pauses[0].until_month).toBeNull();
  });

  test('starts next month when the current month is closed', async () => {
    const data = seed();
    data.finance_months = {'2026-10': {status: 'closed'}};
    const db = makeDb(data);
    const out = await run(db, {is_active: true}, {is_active: false});
    expect(out.from_month).toBe('2026-11');
  });
});
