/**
 * Finance month maths (utils/finance_math.js, utils/finance_categories.js).
 *
 * Expected behavior:
 * - Billed and collected come from non-cancelled invoices of the month; a
 *   cancelled invoice counts for nothing. Discounts are the negative
 *   is_discount lines, reported as a positive amount.
 * - Teacher pay comes from audits; it is final only once the audit is
 *   ceoApproved or completed.
 * - Old pay categories (teacher_payment, leadership_cost) never reach the
 *   totals, so pay is not counted twice.
 * - An administrator's percentage is of what is left after every other cost,
 *   never below zero, and a paused administrator earns nothing.
 */

const m = require('../utils/finance_math');
const {normalizeLegacyCategory} = require('../utils/finance_categories');

const NOW = new Date('2026-10-22T16:00:00Z');
const day = (iso) => new Date(`${iso}T16:00:00Z`);

describe('months in New York time', () => {
  test('a month runs from midnight on the 1st, New York time', () => {
    expect(m.monthBounds('2026-09')).toEqual({
      start: new Date('2026-09-01T04:00:00Z'),
      end: new Date('2026-10-01T04:00:00Z'),
    });
    // November starts in daylight time and ends in standard time.
    expect(m.monthBounds('2026-11')).toEqual({
      start: new Date('2026-11-01T04:00:00Z'),
      end: new Date('2026-12-01T05:00:00Z'),
    });
  });

  test('a month ends when New York moves into the next one', () => {
    // 01:30 UTC on Oct 1 is still the evening of Sep 30 in New York.
    expect(m.monthEnded('2026-09', new Date('2026-10-01T01:30:00Z'))).toBe(false);
    expect(m.monthEnded('2026-09', new Date('2026-10-01T04:00:00Z'))).toBe(true);
    expect(m.monthEnded('2026-10', NOW)).toBe(false);
  });

  test('addMonths crosses a year', () => {
    expect(m.addMonths('2026-11', 3)).toBe('2027-02');
    expect(m.addMonths('2026-01', -1)).toBe('2025-12');
  });
});

describe('legacy categories', () => {
  test('match the web model', () => {
    expect(normalizeLegacyCategory('software')).toBe('software');
    expect(normalizeLegacyCategory('marketing_cost')).toBe('marketing');
    expect(normalizeLegacyCategory('r_and_d')).toBe('other');
    expect(normalizeLegacyCategory('tiktok')).toBe('other');
    expect(normalizeLegacyCategory(undefined)).toBe('other');
    expect(normalizeLegacyCategory('teacher_payment')).toBeNull();
    expect(normalizeLegacyCategory('leadership_cost')).toBeNull();
    expect(normalizeLegacyCategory('admin_pay')).toBeNull();
  });
});

describe('invoiceTotals', () => {
  const invoices = [
    {id: 'a', parent_id: 'p1', status: 'paid', total_amount: 100, paid_amount: 100, period: '2026-09',
      items: [{total: 110}, {total: -10, is_discount: true}]},
    {id: 'b', parent_id: 'p2', status: 'pending', total_amount: 200, paid_amount: 50, billing_month: '2026-09', period: '2026-08'},
    {id: 'c', parent_id: 'p3', status: 'cancelled', total_amount: 999, paid_amount: 0, period: '2026-09'},
    {id: 'd', parent_id: 'p4', status: 'pending', total_amount: 70, paid_amount: 0, period: '2026-10'},
    {id: 'e', parent_id: 'p2', status: 'pending', total_amount: 40, paid_amount: 0, period_start: '2026-09'},
  ];

  test('cancelled invoices and other months are left out', () => {
    expect(m.invoiceTotals(invoices, '2026-09')).toEqual({
      billed: 340, collected: 150, owed: 190, discounts: 10, invoice_count: 3, families_owing: 1,
    });
  });

  test('billing_month wins over period', () => {
    expect(m.invoiceMonth(invoices[1])).toBe('2026-09');
    expect(m.invoiceMonth({period_start: day('2026-07-15')})).toBe('2026-07');
    expect(m.invoiceMonth({})).toBeNull();
  });

  test('a discount line must be flagged and negative to count', () => {
    const t = m.invoiceTotals([{id: 'x', period: '2026-09', total_amount: 90, paid_amount: 0,
      items: [{total: -5}, {total: 5, is_discount: true}, {total: -7, is_discount: true}]}], '2026-09');
    expect(t.discounts).toBe(7);
  });

  test('overdue is computed from the balance and the due date', () => {
    const due = {due_date: day('2026-10-21'), total_amount: 50, paid_amount: 10, status: 'pending'};
    expect(m.isOverdue(due, NOW)).toBe(true);
    expect(m.isOverdue({...due, paid_amount: 50}, NOW)).toBe(false);
    expect(m.isOverdue({...due, due_date: day('2026-10-23')}, NOW)).toBe(false);
    expect(m.isOverdue({...due, status: 'cancelled'}, NOW)).toBe(false);
    // A stored status of "overdue" alone proves nothing.
    expect(m.isOverdue({status: 'overdue', total_amount: 50, paid_amount: 50, due_date: day('2026-01-01')}, NOW)).toBe(false);
  });
});

describe('teacherRows', () => {
  const audit = (over) => ({
    id: 'u1_2026-09', userId: 'u1', teacherName: 'Zainab', status: 'ceoApproved',
    totalHoursTaught: 12,
    paymentSummary: {
      totalNetPayment: 80, totalGrossPayment: 90, totalPenalties: 10,
      paymentsBySubject: {quran: {hoursTaught: 8.5}, arabic: {hoursTaught: 1.25}},
    },
    ...over,
  });

  test('reads pay from the audit and flags final ones', () => {
    const rows = m.teacherRows([audit(), audit({id: 'u2_2026-09', userId: 'u2', teacherName: 'Abdul', status: 'coachSubmitted'})]);
    expect(rows.map((r) => r.name)).toEqual(['Abdul', 'Zainab']);
    expect(rows[1]).toEqual({uid: 'u1', name: 'Zainab', hours: 9.75, gross: 90, penalties: 10, net: 80, final: true});
    expect(rows[0].final).toBe(false);
  });

  test('penalties come from the penalty lines on the audit and are not taken off the pay again', () => {
    const rows = m.teacherRows([audit({paymentSummary: {
      totalNetPayment: 16.01, totalGrossPayment: 343.25, totalPenalties: 0,
      coachAdjustmentLines: [
        {type: 'penalty', amount: 300},
        {type: 'penalty', amount: -27.24},
        {type: 'bonus', amount: 50},
      ],
    }})]);
    expect(rows[0]).toMatchObject({gross: 343.25, penalties: 327.24, net: 16.01});
    // A total on the audit is added to the lines.
    expect(m.auditPenalties({totalPenalties: 5, coachAdjustmentLines: [{type: 'penalty', amount: 10}]})).toBe(15);
    expect(m.auditPenalties({})).toBe(0);
  });

  test('completed counts as final; pending and disputed do not', () => {
    expect(m.isFinalAudit({status: 'completed'})).toBe(true);
    expect(m.isFinalAudit({status: 'pending'})).toBe(false);
    expect(m.isFinalAudit({status: 'disputed'})).toBe(false);
  });

  test('an audit with no hours and no pay is not listed and does not block closing', () => {
    const empty = audit({id: 'u3_2026-09', userId: 'u3', status: 'pending', totalHoursTaught: 0,
      paymentSummary: {totalNetPayment: 0, totalGrossPayment: 0, totalPenalties: 0}});
    expect(m.teacherRows([empty])).toEqual([]);
    expect(m.auditsBlockingClose([empty])).toEqual([]);
    expect(m.auditsBlockingClose([empty, audit({status: 'pending'}), audit()])).toHaveLength(1);
  });

  test('hours fall back to the audit total', () => {
    const rows = m.teacherRows([audit({paymentSummary: {totalNetPayment: 5, totalGrossPayment: 5}})]);
    expect(rows[0].hours).toBe(12);
  });
});

describe('costTotals', () => {
  const base = {month: '2026-09', now: NOW, recurringCosts: [], confirmations: []};

  test('sorts entered costs by category and ignores pay categories and deleted rows', () => {
    const t = m.costTotals({
      ...base,
      expenses: [
        {id: '1', month: '2026-09', category: 'software', amount: 30},
        {id: '2', expense_date: day('2026-09-15'), category: 'marketing_cost', amount: 10},
        {id: '3', month: '2026-09', category: 'teacher_payment', amount: 500},
        {id: '4', month: '2026-09', category: 'leadership_cost', amount: 300},
        {id: '5', month: '2026-09', category: 'other', amount: 40, deleted: true},
        {id: '6', expense_date: day('2026-09-02'), category: 'r_and_d', amount: 5},
        {id: '7', month: '2026-08', category: 'software', amount: 99},
        {id: '8', month: '2026-09', category: 'transfer_fees', amount: 3},
      ],
    });
    expect(t).toMatchObject({software: 30, marketing: 10, other: 5, transfer_fees: 3, recurring_pending: 0});
  });

  test('unconfirmed recurring costs count at their usual amount and are pending', () => {
    const t = m.costTotals({
      ...base,
      expenses: [],
      recurringCosts: [
        {id: 'c1', category: 'software', amount: 50, day_of_month: 3, start_month: '2026-01', end_month: null},
        {id: 'c2', category: 'marketing', amount: 20, day_of_month: 5, start_month: '2026-01'},
        {id: 'c3', category: 'software', amount: 15, start_month: '2026-10'},
        {id: 'c4', category: 'software', amount: 15, start_month: '2026-01', end_month: '2026-08'},
      ],
      confirmations: [{cost_id: 'c2', month: '2026-09', amount: 25}],
    });
    expect(t).toMatchObject({software: 50, marketing: 25, recurring_pending: 1, recurring_due: 1});
  });

  test('a confirmation counts even for a cost that was stopped afterwards', () => {
    const t = m.costTotals({
      ...base,
      expenses: [],
      recurringCosts: [{id: 'c4', category: 'software', amount: 15, start_month: '2026-01', end_month: '2026-08'}],
      confirmations: [{cost_id: 'c4', month: '2026-09', amount: 12}],
    });
    expect(t.software).toBe(12);
  });

  test('an expense row for a confirmed recurring cost is not counted twice', () => {
    const t = m.costTotals({
      ...base,
      expenses: [{id: 'e1', month: '2026-09', category: 'software', amount: 50, recurring_cost_id: 'c1', kind: 'recurring'}],
      recurringCosts: [{id: 'c1', category: 'software', amount: 50, start_month: '2026-01'}],
      confirmations: [{cost_id: 'c1', month: '2026-09', amount: 50}],
    });
    expect(t).toMatchObject({software: 50, recurring_pending: 0});
  });

  test('an expense row for a recurring cost with no confirmation counts once and is not pending', () => {
    const t = m.costTotals({
      ...base,
      expenses: [{id: 'e1', month: '2026-09', category: 'software', amount: 50, recurring_cost_id: 'c1'}],
      recurringCosts: [{id: 'c1', category: 'software', amount: 50, start_month: '2026-01'}],
      confirmations: [],
    });
    expect(t).toMatchObject({software: 50, recurring_pending: 0});
  });

  test('"due" means the day has come in the current month and always in a past month', () => {
    const costs = [
      {id: 'a', category: 'software', amount: 10, day_of_month: 5, start_month: '2026-01'},
      {id: 'b', category: 'software', amount: 10, day_of_month: 28, start_month: '2026-01'},
    ];
    const current = m.costTotals({month: '2026-10', now: NOW, expenses: [], recurringCosts: costs, confirmations: []});
    expect(current).toMatchObject({recurring_pending: 2, recurring_due: 1});
    const past = m.costTotals({month: '2026-09', now: NOW, expenses: [], recurringCosts: costs, confirmations: []});
    expect(past).toMatchObject({recurring_pending: 2, recurring_due: 2});
    const future = m.costTotals({month: '2026-11', now: NOW, expenses: [], recurringCosts: costs, confirmations: []});
    expect(future).toMatchObject({recurring_pending: 2, recurring_due: 0});
  });
});

describe('administrator pay', () => {
  test('a percentage is taken from what is left', () => {
    expect(m.adminPay({fixed: 100, pct: 10, base: 78, paused: false})).toEqual({fixed: 100, pct: 10, share: 7.8, total: 107.8});
  });

  test('a losing month pays the fixed part only', () => {
    expect(m.adminPay({fixed: 100, pct: 10, base: -250, paused: false})).toMatchObject({share: 0, total: 100});
    expect(m.adminPay({fixed: 100, pct: 10, base: 0, paused: false})).toMatchObject({share: 0, total: 100});
  });

  test('a paused administrator earns nothing', () => {
    expect(m.adminPay({fixed: 100, pct: 10, base: 5000, paused: true})).toMatchObject({fixed: 0, share: 0, total: 0});
  });

  test('without a percentage there is no share', () => {
    expect(m.adminPay({fixed: 100, pct: 0, base: 5000, paused: false})).toMatchObject({share: 0, total: 100});
    expect(m.adminPay({fixed: 100, base: 5000, paused: false}).total).toBe(100);
  });

  test('terms in force are the latest that started on or before the month', () => {
    const terms = [
      {from_month: '2026-09', fixed: 100, pct: 10},
      {from_month: '2026-01', fixed: 50, pct: 0},
      {from_month: '2026-11', fixed: 200, pct: 0},
    ];
    expect(m.termsInForce(terms, '2026-08').fixed).toBe(50);
    expect(m.termsInForce(terms, '2026-09').fixed).toBe(100);
    expect(m.termsInForce(terms, '2026-10').fixed).toBe(100);
    expect(m.termsInForce(terms, '2026-12').fixed).toBe(200);
    expect(m.termsInForce(terms, '2025-12')).toBeNull();
  });

  test('a pause covers its months, to the last one named', () => {
    const pauses = [{from_month: '2026-09', until_month: '2026-10', reason: 'Leave', auto: false}];
    expect(m.pauseFor(pauses, '2026-08')).toBeNull();
    expect(m.pauseFor(pauses, '2026-09')).toEqual({reason: 'Leave', auto: false});
    expect(m.pauseFor(pauses, '2026-10')).toEqual({reason: 'Leave', auto: false});
    expect(m.pauseFor(pauses, '2026-11')).toBeNull();
    expect(m.pauseFor([{from_month: '2026-09', until_month: null, reason: 'Deactivated', auto: true}], '2027-03'))
      .toEqual({reason: 'Deactivated', auto: true});
  });
});

describe('buildMonthSummary', () => {
  const input = () => ({
    month: '2026-09',
    now: NOW,
    invoices: [
      {id: 'a', parent_id: 'p1', status: 'paid', total_amount: 100, paid_amount: 100, period: '2026-09',
        items: [{total: 110}, {total: -10, is_discount: true}]},
      {id: 'b', parent_id: 'p2', status: 'pending', total_amount: 200, paid_amount: 50, period: '2026-09'},
      {id: 'c', parent_id: 'p3', status: 'cancelled', total_amount: 999, paid_amount: 0, period: '2026-09'},
    ],
    audits: [
      {id: 't1_2026-09', userId: 't1', teacherName: 'Teacher One', status: 'ceoApproved', totalHoursTaught: 10,
        paymentSummary: {totalNetPayment: 80, totalGrossPayment: 90, totalPenalties: 10}},
      {id: 't2_2026-09', userId: 't2', teacherName: 'Teacher Two', status: 'pending', totalHoursTaught: 4,
        paymentSummary: {totalNetPayment: 20, totalGrossPayment: 20, totalPenalties: 0}},
    ],
    expenses: [
      {id: '1', month: '2026-09', category: 'software', amount: 30},
      {id: '2', expense_date: day('2026-09-15'), category: 'marketing_cost', amount: 10},
      {id: '3', month: '2026-09', category: 'teacher_payment', amount: 500},
      {id: '4', month: '2026-09', category: 'other', amount: 40, deleted: true},
      {id: '5', month: '2026-09', category: 'r_and_d', amount: 5},
    ],
    recurringCosts: [
      {id: 'c1', category: 'software', amount: 50, day_of_month: 3, start_month: '2026-01'},
      {id: 'c2', category: 'marketing', amount: 20, day_of_month: 5, start_month: '2026-01'},
    ],
    confirmations: [{cost_id: 'c2', month: '2026-09', amount: 25}],
    payouts: [
      {id: '2026-09_t1', user_id: 't1', role: 'teacher', month: '2026-09', transfer_fee: 2},
      {id: '2026-09_x', user_id: 'x', role: 'teacher', month: '2026-09', transfer_fee: 9, voided: true},
    ],
    adminTerms: [
      {id: 'a1', uid: 'a1', name: 'Admin One', role_title: 'Director',
        terms: [{from_month: '2026-01', fixed: 50, pct: 0}, {from_month: '2026-09', fixed: 100, pct: 10}], pauses: []},
    ],
  });

  test('puts the month together', () => {
    const s = m.buildMonthSummary(input());
    expect(s).toMatchObject({
      month: '2026-09',
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
      unpaid_teachers: 0,
      unpaid_admins: 0,
    });
    expect(s.teachers.map((t) => [t.uid, t.net, t.final])).toEqual([['t1', 80, true], ['t2', 20, false]]);
    expect(s.admins).toEqual([{
      uid: 'a1', name: 'Admin One', role_title: 'Director', fixed: 100, pct: 10, share: 7.8, total: 107.8, paused: null,
    }]);
  });

  test('a losing month pays administrators their fixed part only', () => {
    const data = input();
    data.invoices = [{id: 'a', status: 'pending', total_amount: 50, paid_amount: 0, period: '2026-09'}];
    const s = m.buildMonthSummary(data);
    expect(s.admin_base).toBe(0);
    expect(s.admins[0]).toMatchObject({fixed: 100, share: 0, total: 100});
    expect(s.profit).toBe(50 - (100 + 80 + 35 + 2 + 5 + 100));
  });

  test('a paused administrator adds nothing', () => {
    const data = input();
    data.adminTerms[0].pauses = [{from_month: '2026-09', until_month: null, reason: 'Left', auto: true}];
    const s = m.buildMonthSummary(data);
    expect(s.admin_pay).toBe(0);
    expect(s.admins[0]).toMatchObject({fixed: 0, share: 0, total: 0, paused: {reason: 'Left', auto: true}});
  });

  test('a cancelled invoice never counts', () => {
    const s = m.buildMonthSummary(input());
    expect(s.billed).toBe(300);
    const all = m.buildMonthSummary({...input(), invoices: [{id: 'c', status: 'cancelled', total_amount: 5, paid_amount: 5, period: '2026-09'}]});
    expect(all).toMatchObject({billed: 0, collected: 0, invoice_count: 0});
  });

  test('pay stored as an expense under an old category is never counted', () => {
    const data = input();
    data.expenses = [
      {id: '3', month: '2026-09', category: 'teacher_payment', amount: 500},
      {id: '4', month: '2026-09', category: 'leadership_cost', amount: 700},
    ];
    const s = m.buildMonthSummary(data);
    expect(s.other).toBe(0);
    expect(s.teacher_pay).toBe(100);
  });

  test('a finished month with everything approved, confirmed and paid is final with nothing unpaid', () => {
    const data = input();
    data.audits[1].status = 'completed';
    data.recurringCosts = [];
    data.confirmations = [];
    data.payouts = [
      {user_id: 't1', role: 'teacher', month: '2026-09'},
      {user_id: 't2', role: 'teacher', month: '2026-09'},
      {user_id: 'a1', role: 'admin', month: '2026-09'},
    ];
    const s = m.buildMonthSummary(data);
    expect(s).toMatchObject({final: true, teacher_pay_final: true, unpaid_teachers: 0, unpaid_admins: 0, recurring_pending: 0});
  });

  test('final people without a live payout are unpaid; voided payouts do not count', () => {
    const data = input();
    data.audits[1].status = 'completed';
    data.recurringCosts = [];
    data.confirmations = [];
    data.payouts = [{user_id: 't1', role: 'teacher', month: '2026-09', voided: true}];
    const s = m.buildMonthSummary(data);
    expect(s).toMatchObject({final: true, unpaid_teachers: 2, unpaid_admins: 1});
  });

  test('one person paid as a teacher is still unpaid as an administrator', () => {
    const data = input();
    data.audits = [data.audits[0]];
    data.recurringCosts = [];
    data.confirmations = [];
    data.adminTerms[0].uid = 't1';
    data.payouts = [{id: '2026-09_t1_teacher', user_id: 't1', role: 'teacher', month: '2026-09'}];
    let s = m.buildMonthSummary(data);
    expect(s).toMatchObject({final: true, unpaid_teachers: 0, unpaid_admins: 1});
    data.payouts.push({id: '2026-09_t1_admin', user_id: 't1', role: 'admin', month: '2026-09'});
    s = m.buildMonthSummary(data);
    expect(s).toMatchObject({unpaid_teachers: 0, unpaid_admins: 0});
  });

  test('a paused administrator is never unpaid, and estimates are not payable', () => {
    const data = input();
    data.adminTerms[0].pauses = [{from_month: '2026-09', until_month: null, reason: 'Left', auto: false}];
    data.recurringCosts = [];
    data.confirmations = [];
    data.payouts = [];
    const s = m.buildMonthSummary(data);
    // t2 is still an estimate; t1 is final and unpaid; the paused admin is nobody's to pay.
    expect(s).toMatchObject({unpaid_teachers: 1, unpaid_admins: 0, final: false});
  });

  test('a month still running is never final', () => {
    const s = m.buildMonthSummary({...input(), month: '2026-10', invoices: []});
    expect(s.final).toBe(false);
  });
});

describe('closeBlockers', () => {
  const summary = (over) => ({recurring_pending: 0, unpaid_teachers: 0, unpaid_admins: 0, ...over});

  test('lists everything that is left in plain words', () => {
    const out = m.closeBlockers({
      month: '2026-10', now: NOW, unapprovedAudits: 2,
      summary: summary({recurring_pending: 1, unpaid_teachers: 2, unpaid_admins: 1}),
    });
    expect(out).toEqual([
      'October 2026 has not ended yet',
      '2 teacher audits are not approved',
      '1 recurring cost is not confirmed',
      '3 people are not paid',
    ]);
  });

  test('is empty when the month can be closed', () => {
    expect(m.closeBlockers({month: '2026-09', now: NOW, unapprovedAudits: 0, summary: summary({})})).toEqual([]);
  });
});
