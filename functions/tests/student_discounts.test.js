const {
  readDiscount,
  coversPeriod,
  discountAmountFor,
  discountLabel,
  buildDiscountLines,
  applyStudentDiscounts
} = require('../utils/student_discounts');

const d = (over = {}) => ({
  mode: 'percent',
  value: 20,
  duration: 'months',
  months: 3,
  startDate: new Date(Date.UTC(2026, 7, 15)),
  reason: 'Sibling discount',
  ...over
});

const period = (y, m) => new Date(Date.UTC(y, m - 1, 1));

describe('readDiscount', () => {
  test('accepts a complete record and a Firestore Timestamp', () => {
    const stamp = {toDate: () => new Date(Date.UTC(2026, 7, 15))};
    const parsed = readDiscount({...d(), startDate: stamp});
    expect(parsed.mode).toBe('percent');
    expect(parsed.startDate.getUTCMonth()).toBe(7);
  });

  test('rejects anything half-written rather than guessing an amount', () => {
    expect(readDiscount(null)).toBeNull();
    expect(readDiscount({})).toBeNull();
    expect(readDiscount({...d(), mode: 'freebie'})).toBeNull();
    expect(readDiscount({...d(), value: 0})).toBeNull();
    expect(readDiscount({...d(), value: -5})).toBeNull();
    expect(readDiscount({...d(), value: 'twenty'})).toBeNull();
    expect(readDiscount({...d(), mode: 'percent', value: 101})).toBeNull();
    expect(readDiscount({...d(), startDate: null})).toBeNull();
    expect(readDiscount({...d(), months: 0})).toBeNull();
    expect(readDiscount({...d(), months: 2.5})).toBeNull();
  });

  test('a fixed discount above 100 is a real amount', () => {
    expect(readDiscount({...d(), mode: 'fixed', value: 150})).not.toBeNull();
  });

  test('ongoing needs no month count', () => {
    const parsed = readDiscount({...d(), duration: 'ongoing', months: undefined});
    expect(parsed).not.toBeNull();
    expect(parsed.months).toBeUndefined();
  });
});

describe('coversPeriod', () => {
  test('the start month is month 1 even when the period begins earlier in it', () => {
    expect(coversPeriod(d(), period(2026, 8))).toBe(true);
  });

  test('runs for exactly the number of months given', () => {
    expect(coversPeriod(d({months: 3}), period(2026, 9))).toBe(true);
    expect(coversPeriod(d({months: 3}), period(2026, 10))).toBe(true);
    expect(coversPeriod(d({months: 3}), period(2026, 11))).toBe(false);
  });

  test('never applies to a period before it starts', () => {
    expect(coversPeriod(d(), period(2026, 7))).toBe(false);
    expect(coversPeriod(d(), period(2025, 12))).toBe(false);
  });

  test('crosses a year boundary by month count, not calendar year', () => {
    const disc = d({startDate: new Date(Date.UTC(2026, 10, 15)), months: 4});
    expect(coversPeriod(disc, period(2027, 1))).toBe(true);
    expect(coversPeriod(disc, period(2027, 2))).toBe(true);
    expect(coversPeriod(disc, period(2027, 3))).toBe(false);
  });

  test('ongoing has no end', () => {
    const disc = d({duration: 'ongoing', months: undefined});
    expect(coversPeriod(disc, period(2031, 5))).toBe(true);
    expect(coversPeriod(disc, period(2026, 7))).toBe(false);
  });

  test('a missing period is not covered', () => {
    expect(coversPeriod(d(), null)).toBe(false);
  });
});

describe('discountAmountFor', () => {
  test('percent and fixed both come off the total', () => {
    expect(discountAmountFor(d({mode: 'percent', value: 20}), 100)).toBe(20);
    expect(discountAmountFor(d({mode: 'fixed', value: 30}), 100)).toBe(30);
  });

  test('never exceeds the total or becomes credit', () => {
    expect(discountAmountFor(d({mode: 'fixed', value: 300}), 120)).toBe(120);
    expect(discountAmountFor(d({mode: 'fixed', value: 30}), 0)).toBe(0);
    expect(discountAmountFor(d({mode: 'fixed', value: 30}), -10)).toBe(0);
  });

  test('lands on whole cents', () => {
    const amount = discountAmountFor(d({mode: 'percent', value: 33}), 19.99);
    expect(amount).toBe(6.6);
    expect(Number.isInteger(Math.round(amount * 100))).toBe(true);
  });
});

describe('buildDiscountLines', () => {
  const items = [
    {description: 'Quran', total: 100, student_id: 's1'},
    {description: 'Arabic', total: 50, student_id: 's1'},
    {description: 'Math', total: 80, student_id: 's2'},
    {description: 'Registration', total: 25}
  ];

  test('discounts each student against their own lines only', () => {
    const map = new Map([['s1', d({mode: 'percent', value: 10})]]);
    const lines = buildDiscountLines(items, map, period(2026, 8));
    expect(lines).toHaveLength(1);
    expect(lines[0].student_id).toBe('s1');
    // 10% of s1's 150, not of the 255 invoice total.
    expect(lines[0].total).toBe(-15);
    expect(lines[0].is_discount).toBe(true);
  });

  test('a line with no student is never discounted', () => {
    const map = new Map([['s1', d({mode: 'fixed', value: 500})]]);
    const lines = buildDiscountLines(items, map, period(2026, 8));
    // Capped at s1's own 150, and the unattributed $25 is untouched.
    expect(lines[0].total).toBe(-150);
  });

  test('produces nothing outside the window', () => {
    const map = new Map([['s1', d()]]);
    expect(buildDiscountLines(items, map, period(2026, 12))).toHaveLength(0);
  });

  test('running twice cannot compound', () => {
    const map = new Map([['s1', d({mode: 'percent', value: 10})]]);
    const once = [...items, ...buildDiscountLines(items, map, period(2026, 8))];
    const twice = buildDiscountLines(once, map, period(2026, 8));
    expect(twice).toHaveLength(1);
    expect(twice[0].total).toBe(-15);
  });

  test('several students each get their own line', () => {
    const map = new Map([
      ['s1', d({mode: 'percent', value: 10})],
      ['s2', d({mode: 'fixed', value: 20})]
    ]);
    const lines = buildDiscountLines(items, map, period(2026, 8));
    expect(lines.map((l) => l.total).sort((a, b) => a - b)).toEqual([-20, -15]);
  });

  test('the description says what came off and why', () => {
    const map = new Map([['s1', d({mode: 'percent', value: 20, months: 3})]]);
    const [line] = buildDiscountLines(items, map, period(2026, 8));
    expect(line.description).toBe('Discount — 20% off · first 3 months (Sibling discount)');
  });
});

describe('applyStudentDiscounts', () => {
  const fakeDb = (discounts) => ({
    collection: () => ({doc: (id) => ({id})}),
    getAll: async (...refs) =>
      refs.map((ref) => ({
        exists: Object.prototype.hasOwnProperty.call(discounts, ref.id),
        data: () => ({discount: discounts[ref.id]})
      }))
  });

  const items = [{description: 'Quran', total: 100, student_id: 's1'}];

  test('appends a discount line when one applies', async () => {
    const db = fakeDb({s1: d({mode: 'percent', value: 25})});
    const out = await applyStudentDiscounts(db, items, period(2026, 8));
    expect(out).toHaveLength(2);
    expect(out[1].total).toBe(-25);
  });

  test('returns the items untouched when nothing applies', async () => {
    const db = fakeDb({});
    await expect(applyStudentDiscounts(db, items, period(2026, 8))).resolves.toEqual(items);
    const stale = fakeDb({s1: d({months: 1, startDate: new Date(Date.UTC(2020, 0, 1))})});
    await expect(applyStudentDiscounts(stale, items, period(2026, 8))).resolves.toEqual(items);
  });

  test('a malformed stored discount bills at full price', async () => {
    const db = fakeDb({s1: {mode: 'percent', value: 'lots'}});
    await expect(applyStudentDiscounts(db, items, period(2026, 8))).resolves.toEqual(items);
  });

  test('no period means no discount rather than an unbounded one', async () => {
    const db = fakeDb({s1: d()});
    await expect(applyStudentDiscounts(db, items, null)).resolves.toEqual(items);
  });

  test('reads through the transaction when given one', async () => {
    const db = fakeDb({});
    const tx = {getAll: jest.fn(fakeDb({s1: d({mode: 'percent', value: 50})}).getAll)};
    const out = await applyStudentDiscounts(db, items, period(2026, 8), tx);
    expect(tx.getAll).toHaveBeenCalled();
    expect(out[1].total).toBe(-50);
  });

  test('existing discount lines are stripped before recomputing', async () => {
    const db = fakeDb({s1: d({mode: 'percent', value: 10})});
    const withOld = [...items, {description: 'old', total: -99, student_id: 's1', is_discount: true}];
    const out = await applyStudentDiscounts(db, withOld, period(2026, 8));
    expect(out.filter((i) => i.is_discount)).toHaveLength(1);
    expect(out.reduce((sum, i) => sum + i.total, 0)).toBe(90);
  });
});
