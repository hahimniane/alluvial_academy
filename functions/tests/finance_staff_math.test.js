/**
 * Pure helpers behind finance staff pay: which terms apply, when pay is
 * paused, and how payouts add up.
 */
const m = require('../utils/finance_staff_math');

describe('months and dates', () => {
  test('isMonth / isDateString', () => {
    expect(m.isMonth('2026-10')).toBe(true);
    expect(m.isMonth('2026-13')).toBe(false);
    expect(m.isMonth('2026-1')).toBe(false);
    expect(m.isDateString('2026-10-03')).toBe(true);
    expect(m.isDateString('2026-02-30')).toBe(false);
    expect(m.isDateString('Oct 3')).toBe(false);
  });

  test('New York month and short date follow Eastern time', () => {
    // 03:30 UTC on Nov 1 is still Oct 31 evening in New York.
    const d = new Date('2026-11-01T03:30:00Z');
    expect(m.nyMonthOf(d)).toBe('2026-10');
    expect(m.nyShortDate(d)).toBe('Oct 31');
  });

  test('addMonths crosses years', () => {
    expect(m.addMonths('2026-12', 1)).toBe('2027-01');
    expect(m.addMonths('2026-01', -1)).toBe('2025-12');
  });
});

describe('terms in force', () => {
  const terms = [
    {from_month: '2026-01', fixed: 300, pct: 0},
    {from_month: '2026-06', fixed: 400, pct: 5},
  ];
  test('uses the latest term starting on or before the month', () => {
    expect(m.termInForce(terms, '2026-05').fixed).toBe(300);
    expect(m.termInForce(terms, '2026-06').fixed).toBe(400);
    expect(m.termInForce(terms, '2026-10').pct).toBe(5);
  });
  test('no terms before the first start', () => {
    expect(m.termInForce(terms, '2025-12')).toBeNull();
    expect(m.termInForce(undefined, '2026-10')).toBeNull();
  });
  test('upsertTerm replaces the same start month and keeps order', () => {
    const next = m.upsertTerm(terms, {from_month: '2026-06', fixed: 450, pct: 6});
    expect(next.map((t) => t.from_month)).toEqual(['2026-01', '2026-06']);
    expect(next[1].fixed).toBe(450);
    const added = m.upsertTerm(terms, {from_month: '2026-03', fixed: 350, pct: 0});
    expect(added.map((t) => t.from_month)).toEqual(['2026-01', '2026-03', '2026-06']);
    expect(terms).toHaveLength(2); // input untouched
  });
});

describe('pauses', () => {
  const pauses = [
    {from_month: '2026-03', until_month: '2026-05', reason: 'Leave'},
    {from_month: '2026-09', until_month: null, reason: 'Account deactivated Sep 12', auto: true},
  ];
  test('paused from the start month, back in the resume month', () => {
    expect(m.pauseForMonth(pauses, '2026-02')).toBeNull();
    expect(m.pauseForMonth(pauses, '2026-03').reason).toBe('Leave');
    expect(m.pauseForMonth(pauses, '2026-04').reason).toBe('Leave');
    expect(m.pauseForMonth(pauses, '2026-05')).toBeNull();
    expect(m.pauseForMonth(pauses, '2026-10').auto).toBe(true);
  });
  test('openPause finds the pause without an end', () => {
    expect(m.openPause(pauses).from_month).toBe('2026-09');
    expect(m.openPause([pauses[0]])).toBeNull();
  });
  test('closeOpenPause only closes the open one', () => {
    const closed = m.closeOpenPause(pauses, '2026-11', {resumed_reason: 'Back'});
    expect(closed[0].until_month).toBe('2026-05');
    expect(closed[1].until_month).toBe('2026-11');
    expect(closed[1].resumed_reason).toBe('Back');
    expect(m.pauseForMonth(closed, '2026-11')).toBeNull();
  });
  test('fixed pay is 0 while paused', () => {
    const doc = {terms: [{from_month: '2026-01', fixed: 300, pct: 0}], pauses};
    expect(m.fixedPayFor(doc, '2026-02')).toBe(300);
    expect(m.fixedPayFor(doc, '2026-04')).toBe(0);
    expect(m.fixedPayFor(doc, '2026-10')).toBe(0);
    expect(m.fixedPayFor(doc, '2025-12')).toBe(0);
  });
});

describe('profit share', () => {
  test('is a percentage of the base, floored at 0', () => {
    expect(m.shareOf(2000, 5)).toBe(100);
    expect(m.shareOf(-500, 5)).toBe(0);
    expect(m.shareOf(1234.56, 10)).toBe(123.46);
    expect(m.shareOf(1000, 150)).toBe(1000);
  });
});

describe('payout documents', () => {
  const at = {seconds: 1};
  const ctx = {uid: 't1', role: 'teacher', month: '2026-09', name: 'Aisha', amount_due: 206, at, by: 'a1', by_name: 'Admin'};

  test('first payment', () => {
    const doc = m.applyPayment(null, {amount_paid: 150, method: 'Mobile money', date_paid: '2026-10-03', transfer_fee: 3, reference: 'TX1'}, ctx);
    expect(doc).toMatchObject({amount_due: 206, amount_paid: 150, transfer_fee: 3, reference: 'TX1', voided: false, role: 'teacher'});
    expect(doc.history).toHaveLength(1);
    expect(m.amountLeft(doc.amount_due, doc.amount_paid)).toBe(56);
  });

  test('a second payment adds to the first and keeps both in the history', () => {
    const first = m.applyPayment(null, {amount_paid: 150, method: 'Mobile money', date_paid: '2026-10-03', transfer_fee: 3}, ctx);
    const second = m.applyPayment(first, {amount_paid: 56, method: 'Bank transfer', date_paid: '2026-10-10', transfer_fee: 1.5}, ctx);
    expect(second.amount_paid).toBe(206);
    expect(second.transfer_fee).toBe(4.5);
    expect(second.method).toBe('Bank transfer');
    expect(second.history).toHaveLength(2);
    expect(m.amountLeft(second.amount_due, second.amount_paid)).toBe(0);
  });

  test('a void keeps the document and the history, and counts for nothing', () => {
    const paid = m.applyPayment(null, {amount_paid: 206, method: 'Mobile money', date_paid: '2026-10-03', transfer_fee: 2}, ctx);
    const voided = m.applyVoid(paid, 'Sent to the wrong number', {at, by: 'a1', by_name: 'Admin'});
    expect(voided).toMatchObject({voided: true, void_reason: 'Sent to the wrong number', amount_paid: 0, transfer_fee: 0});
    expect(voided.history[0].voided).toBe(true);
    expect(voided.history[voided.history.length - 1]).toMatchObject({action: 'void'});
    expect(m.payoutTotals(voided.history)).toEqual({paid: 0, fee: 0, count: 0});
  });

  test('paying again after a void starts from zero', () => {
    const paid = m.applyPayment(null, {amount_paid: 206, method: 'Mobile money', date_paid: '2026-10-03', reference: 'OLD'}, ctx);
    const voided = m.applyVoid(paid, 'Wrong number', {at, by: 'a1'});
    const again = m.applyPayment(voided, {amount_paid: 100, method: 'Bank transfer', date_paid: '2026-10-05'}, ctx);
    expect(again.amount_paid).toBe(100);
    expect(again.voided).toBe(false);
    expect(again.reference).toBe('');
    expect(again.history).toHaveLength(3);
  });
});
