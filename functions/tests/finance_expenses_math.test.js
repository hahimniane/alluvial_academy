/**
 * Pure rules for finance expenses (docs/finance/SPEC.md rules 4, 5, 14).
 *
 * Expected behavior:
 * - Entered categories are software, marketing, transfer_fees, other; pay is never entered.
 * - A one-time date must sit inside the month; a recurring day is 1 to 28.
 * - A recurring cost runs from its start month to its end month, both included.
 * - An unconfirmed recurring cost counts at its usual amount, flagged estimate.
 * - Totals skip soft-deleted rows and legacy pay rows; roll-ups add up.
 */

const {
  parseAmount,
  parseExpenseInput,
  recurringInMonth,
  recurringStatus,
  recurringAmount,
  expenseMonth,
  normalizeLegacyCategory,
  totalsForMonth,
  rollup,
  monthOfDate,
  invoiceBillingMonth,
  invoiceDiscountTotal,
} = require('../utils/finance_expense_math');

const stamp = (iso) => ({toDate: () => new Date(iso)});

describe('parseAmount', () => {
  test('rounds to cents and accepts money-looking strings', () => {
    expect(parseAmount('12.345')).toBe(12.35);
    expect(parseAmount('$1,200.50')).toBe(1200.5);
    expect(parseAmount(40)).toBe(40);
  });
  test('rejects blank, negative, zero, NaN and huge amounts', () => {
    for (const bad of ['', '  ', -1, 0, 'abc', NaN, null, undefined, 5e9]) {
      expect(parseAmount(bad)).toBeNull();
    }
  });
  test('zero is allowed when asked (a waived bill)', () => {
    expect(parseAmount(0, {allowZero: true})).toBe(0);
  });
});

describe('parseExpenseInput', () => {
  const base = {month: '2026-10', kind: 'one_time', category: 'marketing', name: ' Flyers ', amount: '25'};

  test('one-time: trims the name, defaults the date to today inside the month', () => {
    const r = parseExpenseInput(base, '2026-10-21');
    expect(r).toEqual({
      ok: true,
      value: {month: '2026-10', kind: 'one_time', category: 'marketing', name: 'Flyers', amount: 25, date: '2026-10-21'},
    });
  });
  test('one-time: another month defaults to its first day', () => {
    const r = parseExpenseInput({...base, month: '2026-09'}, '2026-10-21');
    expect(r.value.date).toBe('2026-09-01');
  });
  test('one-time: a date outside the month is refused', () => {
    const r = parseExpenseInput({...base, date: '2026-11-02'}, '2026-10-21');
    expect(r.ok).toBe(false);
    expect(r.message).toBe('The date must be in October.');
  });
  test('one-time: an impossible date is refused', () => {
    expect(parseExpenseInput({...base, date: '2026-10-32'}, '2026-10-21').ok).toBe(false);
    expect(parseExpenseInput({...base, date: '2026-02-30', month: '2026-02'}, '2026-10-21').ok).toBe(false);
  });
  test('refuses pay categories, unknown categories, blank names and bad amounts', () => {
    for (const patch of [
      {category: 'teacher_pay'},
      {category: 'admin_pay'},
      {category: 'r_and_d'},
      {name: '   '},
      {amount: 0},
      {amount: -3},
      {month: '2026-13'},
      {kind: 'weekly'},
    ]) {
      expect(parseExpenseInput({...base, ...patch}, '2026-10-21').ok).toBe(false);
    }
  });
  test('recurring: day 1 to 28, default 1', () => {
    const rec = {...base, kind: 'recurring', day_of_month: 15};
    expect(parseExpenseInput(rec, '2026-10-21').value.day_of_month).toBe(15);
    expect(parseExpenseInput({...rec, day_of_month: undefined}, '2026-10-21').value.day_of_month).toBe(1);
    for (const bad of [0, 29, 31, 1.5, 'x']) {
      expect(parseExpenseInput({...rec, day_of_month: bad}, '2026-10-21').ok).toBe(false);
    }
  });
});

describe('recurring costs in a month', () => {
  const cost = {id: 'c1', name: 'Zoom', category: 'software', amount: 150, day_of_month: 14, start_month: '2026-08', end_month: '2026-10'};

  test('start and end months are both included', () => {
    expect(recurringInMonth(cost, '2026-07')).toBe(false);
    expect(recurringInMonth(cost, '2026-08')).toBe(true);
    expect(recurringInMonth(cost, '2026-10')).toBe(true);
    expect(recurringInMonth(cost, '2026-11')).toBe(false);
  });
  test('no end month runs forever', () => {
    expect(recurringInMonth({...cost, end_month: null}, '2030-01')).toBe(true);
  });
  test('status: confirmed, due once the day has come, upcoming before', () => {
    const today = '2026-10-21';
    expect(recurringStatus(cost, '2026-10', {amount: 149.9}, today)).toBe('confirmed');
    expect(recurringStatus(cost, '2026-10', null, today)).toBe('due');
    expect(recurringStatus({...cost, day_of_month: 25}, '2026-10', null, today)).toBe('upcoming');
    expect(recurringStatus(cost, '2026-09', null, today)).toBe('due');
    expect(recurringStatus(cost, '2026-11', null, today)).toBe('upcoming');
  });
  test('amount: confirmed is final, unconfirmed is the usual amount as an estimate', () => {
    expect(recurringAmount(cost, {amount: 149.9})).toEqual({amount: 149.9, estimate: false});
    expect(recurringAmount(cost, null)).toEqual({amount: 150, estimate: true});
  });
});

describe('expenseMonth', () => {
  test('uses month when present, else the expense date on New York time', () => {
    expect(expenseMonth({month: '2026-09', expense_date: stamp('2026-10-05T12:00:00Z')})).toBe('2026-09');
    expect(expenseMonth({expense_date: stamp('2026-09-01T12:00:00Z')})).toBe('2026-09');
    // 02:00 UTC on Oct 1 is still Sept 30 in New York.
    expect(expenseMonth({expense_date: stamp('2026-10-01T02:00:00Z')})).toBe('2026-09');
    expect(expenseMonth({expense_date: '2026-07-10'})).toBe('2026-07');
    expect(expenseMonth({})).toBeNull();
  });
  test('monthOfDate follows Eastern time', () => {
    expect(monthOfDate(new Date('2026-11-01T03:30:00Z'))).toBe('2026-10');
  });
});

describe('legacy categories', () => {
  test('map as the spec says', () => {
    expect(normalizeLegacyCategory('marketing_cost')).toBe('marketing');
    expect(normalizeLegacyCategory('r_and_d')).toBe('other');
    expect(normalizeLegacyCategory('other')).toBe('other');
    expect(normalizeLegacyCategory('teacher_payment')).toBeNull();
    expect(normalizeLegacyCategory('leadership_cost')).toBeNull();
    expect(normalizeLegacyCategory('software')).toBe('software');
  });
});

describe('totalsForMonth and rollup', () => {
  const costs = [
    {id: 'zoom', category: 'software', amount: 150, day_of_month: 14, start_month: '2026-01', end_month: null},
    {id: 'host', category: 'software', amount: 12, day_of_month: 3, start_month: '2026-01', end_month: '2026-09'},
    {id: 'ads', category: 'marketing', amount: 80, day_of_month: 5, start_month: '2026-10', end_month: null},
  ];
  const confirmations = [
    {cost_id: 'zoom', month: '2026-10', amount: 149.9},
    {cost_id: 'zoom', month: '2026-09', amount: 140},
  ];
  const oneOffs = [
    {category: 'other', amount: 20, month: '2026-10'},
    {category: 'r_and_d', amount: 50, expense_date: stamp('2026-10-02T12:00:00Z')},
    {category: 'marketing', amount: 99, month: '2026-10', deleted: true},
    {category: 'teacher_payment', amount: 500, month: '2026-10'},
    {category: 'other', amount: 1000, month: '2026-09'},
  ];

  test('counts confirmed amounts, estimates the rest, skips deleted, pay and other months', () => {
    const r = totalsForMonth({
      month: '2026-10',
      oneOffs,
      costs,
      confirmations,
      computed: {teacher_pay: 1000, admin_pay: 400, transfer_fees: 6},
    });
    expect(r.byCategory).toEqual({
      teacher_pay: 1000,
      admin_pay: 400,
      software: 149.9,
      marketing: 80,
      transfer_fees: 6,
      other: 70,
    });
    expect(r.total).toBe(1705.9);
    expect(r.estimate).toBe(true);
  });
  test('not an estimate once every recurring cost is confirmed', () => {
    const r = totalsForMonth({
      month: '2026-09',
      oneOffs: [],
      costs: costs.slice(0, 2),
      confirmations: [...confirmations, {cost_id: 'host', month: '2026-09', amount: 12}],
    });
    expect(r.estimate).toBe(false);
    expect(r.byCategory.software).toBe(152);
  });
  test('roll-ups: Staff, Administration, Other', () => {
    expect(rollup({teacher_pay: 1000, admin_pay: 400, software: 149.9, transfer_fees: 6, marketing: 80, other: 70})).toEqual({
      Staff: 1400,
      Administration: 155.9,
      Other: 150,
    });
  });
});

describe('invoice discounts', () => {
  test('billing month: billing_month, then period start, then the issue month', () => {
    expect(invoiceBillingMonth({billing_month: '2026-10', period: '2026-09'})).toBe('2026-10');
    expect(invoiceBillingMonth({period: '2026-09'})).toBe('2026-09');
    expect(invoiceBillingMonth({period: '2026-07..2026-08'})).toBe('2026-07');
    expect(invoiceBillingMonth({period: '2026-06 to 2026-07'})).toBe('2026-06');
    expect(invoiceBillingMonth({period: 'Adult payment verification', issued_date: stamp('2026-05-20T15:00:00Z')})).toBe('2026-05');
    expect(invoiceBillingMonth({})).toBeNull();
  });
  test('discount total adds discount lines in cents and ignores cancelled invoices', () => {
    const items = [
      {total: 100},
      {total: -10.1, is_discount: true},
      {total: -4.2, is_discount: true},
    ];
    expect(invoiceDiscountTotal({items})).toBe(14.3);
    expect(invoiceDiscountTotal({items, status: 'cancelled'})).toBe(0);
    expect(invoiceDiscountTotal({})).toBe(0);
  });
});
