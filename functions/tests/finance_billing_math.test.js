const math = require('../utils/finance_billing_math');

describe('prorate', () => {
  test('Oct 20 start, 3 of 8 classes left at $80 is $30', () => {
    expect(math.prorate({monthly: 80, classesInMonth: 8, classesLeft: 3})).toBe(30);
  });

  test('rounds to the cent', () => {
    // 100 x 1 / 3 = 33.333...
    expect(math.prorate({monthly: 100, classesInMonth: 3, classesLeft: 1})).toBe(33.33);
    // 100 x 2 / 3 = 66.666...
    expect(math.prorate({monthly: 100, classesInMonth: 3, classesLeft: 2})).toBe(66.67);
  });

  test('all classes left is the full month', () => {
    expect(math.prorate({monthly: 123.45, classesInMonth: 12, classesLeft: 12})).toBe(123.45);
  });

  test('refuses nonsense', () => {
    expect(() => math.prorate({monthly: 0, classesInMonth: 8, classesLeft: 3})).toThrow(RangeError);
    expect(() => math.prorate({monthly: 80, classesInMonth: 0, classesLeft: 3})).toThrow(RangeError);
    expect(() => math.prorate({monthly: 80, classesInMonth: 8, classesLeft: 0})).toThrow(RangeError);
    expect(() => math.prorate({monthly: 80, classesInMonth: 8, classesLeft: 9})).toThrow(RangeError);
    expect(() => math.prorate({monthly: 80, classesInMonth: 8, classesLeft: 2.5})).toThrow(RangeError);
  });
});

describe('dates in New York time', () => {
  test('first invoice: first class Oct 20 + 3 days is due Oct 23', () => {
    expect(math.firstInvoiceDueDateString('2026-10-20', 3)).toBe('2026-10-23');
    const due = math.startOfNyDay('2026-10-23');
    expect(math.nyDateString(due)).toBe('2026-10-23');
  });

  test('due date crosses a month end', () => {
    expect(math.firstInvoiceDueDateString('2026-10-30', 3)).toBe('2026-11-02');
  });

  test('the monthly invoice for November is issued Oct 25 and due Nov 1', () => {
    expect(math.monthlyIssueDateString('2026-11', 25)).toBe('2026-10-25');
    expect(math.monthlyDueDateString('2026-11', 1)).toBe('2026-11-01');
  });

  test('January invoices are issued in the previous December', () => {
    expect(math.monthlyIssueDateString('2027-01', 25)).toBe('2026-12-25');
  });

  test('an issue day past the end of a short month is clamped', () => {
    // March invoices are issued in February.
    expect(math.monthlyIssueDateString('2027-03', 31)).toBe('2027-02-28');
  });

  test('start of day is New York midnight, not UTC midnight', () => {
    // Nov 1 2026 00:00 EDT = 04:00 UTC (DST ends Nov 1 at 02:00 local).
    expect(math.startOfNyDay('2026-11-01').toISOString()).toBe('2026-11-01T04:00:00.000Z');
    // Nov 2 2026 00:00 EST = 05:00 UTC.
    expect(math.startOfNyDay('2026-11-02').toISOString()).toBe('2026-11-02T05:00:00.000Z');
  });

  test('next billing month follows the New York date, not UTC', () => {
    // 2026-10-31 23:30 EDT is already Nov 1 in UTC.
    expect(math.nextBillingMonth(new Date('2026-11-01T03:30:00Z'))).toBe('2026-11');
    expect(math.nextBillingMonth(new Date('2026-11-01T04:30:00Z'))).toBe('2026-12');
    expect(math.nextBillingMonth(new Date('2026-12-15T12:00:00Z'))).toBe('2027-01');
  });

  test('monthToGenerate is null before the issue day and next month from it', () => {
    expect(math.monthToGenerate(new Date('2026-10-24T14:00:00Z'), 25)).toBeNull();
    expect(math.monthToGenerate(new Date('2026-10-25T14:00:00Z'), 25)).toBe('2026-11');
    expect(math.monthToGenerate(new Date('2026-10-31T14:00:00Z'), 25)).toBe('2026-11');
    expect(math.monthToGenerate(new Date('2026-12-26T14:00:00Z'), 25)).toBe('2027-01');
  });

  test('daysUntilDue counts New York calendar days', () => {
    const due = math.startOfNyDay('2026-11-01');
    expect(math.daysUntilDue(due, new Date('2026-10-29T15:00:00Z'))).toBe(3);
    expect(math.daysUntilDue(due, new Date('2026-11-01T15:00:00Z'))).toBe(0);
    expect(math.daysUntilDue(due, new Date('2026-11-02T15:00:00Z'))).toBe(-1);
  });

  test('month and date validation', () => {
    expect(math.isMonth('2026-11')).toBe(true);
    expect(math.isMonth('2026-13')).toBe(false);
    expect(math.isMonth('2026-1')).toBe(false);
    expect(math.isDateString('2026-10-20')).toBe(true);
    expect(math.isDateString('2026-02-30')).toBe(false);
    expect(math.isDateString('20-10-2026')).toBe(false);
  });
});

describe('document ids', () => {
  test('monthly invoice id is monthly_{parentId}_{yyyy-MM}', () => {
    expect(math.monthlyInvoiceId('abc123', '2026-11')).toBe('monthly_abc123_2026-11');
  });

  test('a parent id with odd characters cannot break the path', () => {
    expect(math.monthlyInvoiceId('a/b c', '2026-11')).toBe('monthly_a_b_c_2026-11');
  });

  test('first invoice id is one per student', () => {
    expect(math.firstInvoiceId('stu_9')).toBe('first_stu_9');
  });
});

describe('amountForMonth', () => {
  const fb = {
    monthly_amount: 120,
    history: [
      {from_month: '2026-12', old: 100, new: 110},
      {from_month: '2027-02', old: 110, new: 120},
    ],
  };

  test('uses the latest amount for months after every change', () => {
    expect(math.amountForMonth(fb, '2027-02')).toBe(120);
    expect(math.amountForMonth(fb, '2027-06')).toBe(120);
  });

  test('uses the amount in force before a change starts', () => {
    expect(math.amountForMonth(fb, '2026-11')).toBe(100);
    expect(math.amountForMonth(fb, '2026-12')).toBe(110);
    expect(math.amountForMonth(fb, '2027-01')).toBe(110);
  });

  test('no history is just the amount', () => {
    expect(math.amountForMonth({monthly_amount: 80}, '2026-11')).toBe(80);
  });

  test('a change starts on the next invoice nobody has issued yet', () => {
    const now = new Date('2026-10-22T15:00:00Z');
    expect(math.changeStartMonth(now, new Set())).toBe('2026-11');
    expect(math.changeStartMonth(now, new Set(['2026-11']))).toBe('2026-12');
    expect(math.changeStartMonth(now, new Set(['2026-11', '2026-12']))).toBe('2027-01');
  });
});

describe('old generator skip', () => {
  test('skips a family that has family_billing when auto billing is on', () => {
    expect(math.shouldOldGeneratorSkip({autoBillingEnabled: true, familyBilling: {monthly_amount: 80}})).toBe(true);
  });

  test('never skips while auto billing is off', () => {
    expect(math.shouldOldGeneratorSkip({autoBillingEnabled: false, familyBilling: {monthly_amount: 80}})).toBe(false);
    expect(math.shouldOldGeneratorSkip({autoBillingEnabled: undefined, familyBilling: {monthly_amount: 80}})).toBe(false);
  });

  test('with a month, skips only when the family amount for that month is above zero', () => {
    expect(math.shouldOldGeneratorSkip({autoBillingEnabled: true, familyBilling: {monthly_amount: 80}, month: '2026-11'})).toBe(true);
    expect(math.shouldOldGeneratorSkip({autoBillingEnabled: true, familyBilling: {monthly_amount: 0}, month: '2026-11'})).toBe(false);
    expect(math.shouldOldGeneratorSkip({autoBillingEnabled: true, familyBilling: {active: true}, month: '2026-11'})).toBe(false);
  });

  test('does not skip a family without family_billing, or one switched off', () => {
    expect(math.shouldOldGeneratorSkip({autoBillingEnabled: true, familyBilling: null})).toBe(false);
    expect(math.shouldOldGeneratorSkip({autoBillingEnabled: true, familyBilling: {active: false}})).toBe(false);
  });
});

describe('splitAmount', () => {
  test('one child gets all of it', () => {
    expect(math.splitAmount({amount: 80, studentIds: ['a']})).toEqual([{studentId: 'a', cents: 8000}]);
  });

  test('splits evenly and gives the odd cents to the first children', () => {
    const parts = math.splitAmount({amount: 100, studentIds: ['a', 'b', 'c']});
    expect(parts.map((p) => p.cents)).toEqual([3334, 3333, 3333]);
    expect(parts.reduce((s, p) => s + p.cents, 0)).toBe(10000);
  });

  test('uses per-child amounts when they add up exactly', () => {
    const parts = math.splitAmount({amount: 150, studentIds: ['a', 'b'], studentAmounts: {a: 100, b: 50}});
    expect(parts.map((p) => p.cents)).toEqual([10000, 5000]);
  });

  test('ignores per-child amounts that no longer add up', () => {
    const parts = math.splitAmount({amount: 160, studentIds: ['a', 'b'], studentAmounts: {a: 100, b: 50}});
    expect(parts.map((p) => p.cents)).toEqual([8000, 8000]);
  });

  test('no children is one unattributed line', () => {
    expect(math.splitAmount({amount: 80, studentIds: []})).toEqual([{studentId: '', cents: 8000}]);
  });
});

const discountLine = (amount, studentId = 'a') => ({
  description: 'Discount',
  quantity: 1,
  unit_price: -amount,
  total: -amount,
  student_id: studentId,
  shift_ids: [],
  is_discount: true,
});

describe('buildMonthlyInvoice', () => {
  test('plain month: one line, no credit', () => {
    const r = math.buildMonthlyInvoice({month: '2026-11', amount: 80, studentIds: ['a']});
    expect(r.total).toBe(80);
    expect(r.subtotal).toBe(80);
    expect(r.discount).toBe(0);
    expect(r.credit_applied).toBe(0);
    expect(r.items).toHaveLength(1);
    expect(r.items[0]).toMatchObject({student_id: 'a', total: 80, description: 'Monthly tuition — November 2026'});
  });

  test('a credit larger than the invoice is used in part', () => {
    const r = math.buildMonthlyInvoice({
      month: '2026-11',
      amount: 80,
      studentIds: ['a'],
      credits: [{id: 'c1', amount: 100, reason: 'Paused', created_ms: 1}],
    });
    expect(r.total).toBe(0);
    expect(r.credit_applied).toBe(80);
    expect(r.credit_uses).toEqual([
      expect.objectContaining({credit_id: 'c1', applied: 80, remaining: 20, partial: true}),
    ]);
    expect(r.credit_lines).toEqual([{credit_id: 'c1', amount: 80, reason: 'Paused'}]);
    // The credit shows on the invoice as its own negative line.
    expect(r.items[r.items.length - 1]).toMatchObject({is_credit: true, total: -80, credit_id: 'c1'});
  });

  test('a credit smaller than the invoice is used whole', () => {
    const r = math.buildMonthlyInvoice({
      month: '2026-11',
      amount: 80,
      studentIds: ['a'],
      credits: [{id: 'c1', amount: 25, created_ms: 1}],
    });
    expect(r.total).toBe(55);
    expect(r.credit_uses[0]).toMatchObject({applied: 25, remaining: 0, partial: false});
  });

  test('discount comes off first, then credit', () => {
    // $100 - $20 discount = $80, then a $50 credit leaves $30.
    const r = math.buildMonthlyInvoice({
      month: '2026-11',
      amount: 100,
      studentIds: ['a'],
      discountLines: [discountLine(20)],
      credits: [{id: 'c1', amount: 50, created_ms: 1}],
    });
    expect(r.subtotal).toBe(100);
    expect(r.discount).toBe(20);
    expect(r.credit_applied).toBe(50);
    expect(r.total).toBe(30);
  });

  test('credit is capped by what is left after the discount, not the full price', () => {
    // $100 - $40 = $60; a $100 credit can only use $60 of itself.
    const r = math.buildMonthlyInvoice({
      month: '2026-11',
      amount: 100,
      studentIds: ['a'],
      discountLines: [discountLine(40)],
      credits: [{id: 'c1', amount: 100, created_ms: 1}],
    });
    expect(r.credit_applied).toBe(60);
    expect(r.credit_uses[0]).toMatchObject({applied: 60, remaining: 40, partial: true});
    expect(r.total).toBe(0);
  });

  test('several credits are used oldest first until the invoice is covered', () => {
    const r = math.buildMonthlyInvoice({
      month: '2026-11',
      amount: 80,
      studentIds: ['a'],
      credits: [
        {id: 'new', amount: 30, created_ms: 200},
        {id: 'old', amount: 30, created_ms: 100},
        {id: 'mid', amount: 30, created_ms: 150},
      ],
    });
    expect(r.credit_uses.map((u) => u.credit_id)).toEqual(['old', 'mid', 'new']);
    expect(r.credit_uses.map((u) => u.applied)).toEqual([30, 30, 20]);
    expect(r.total).toBe(0);
    expect(r.credit_uses[2]).toMatchObject({partial: true, remaining: 10});
  });

  test('credits are untouched when nothing is left to pay', () => {
    const r = math.buildMonthlyInvoice({
      month: '2026-11',
      amount: 80,
      studentIds: ['a'],
      discountLines: [discountLine(80)],
      credits: [{id: 'c1', amount: 25, created_ms: 1}],
    });
    expect(r.total).toBe(0);
    expect(r.credit_uses).toEqual([]);
  });

  test('money stays in whole cents', () => {
    const r = math.buildMonthlyInvoice({
      month: '2026-11',
      amount: 99.99,
      studentIds: ['a', 'b'],
      credits: [{id: 'c1', amount: 0.01, created_ms: 1}],
    });
    expect(r.items.filter((i) => !i.is_credit).reduce((s, i) => s + Math.round(i.total * 100), 0)).toBe(9999);
    expect(r.total).toBe(99.98);
  });
});
