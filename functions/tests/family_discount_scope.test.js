const {
  readDiscount,
  buildDiscountLines,
  buildFamilyDiscountLine,
} = require('../utils/student_discounts');

const PERIOD = new Date(Date.UTC(2026, 8, 1));
const START = new Date(Date.UTC(2026, 8, 1));

const tuition = (studentId, total) => ({
  description: 'Tuition',
  quantity: 1,
  unit_price: total,
  total,
  student_id: studentId,
});

const discount = (over) => ({
  mode: 'fixed',
  value: 10,
  duration: 'ongoing',
  startDate: START,
  reason: 'Sibling discount',
  ...over,
});

describe('per-student vs family discounts', () => {
  test('a discount saved before scope existed is read as per-student', () => {
    const read = readDiscount({mode: 'fixed', value: 10, duration: 'ongoing', startDate: START});
    expect(read.scope).toBe('student');
  });

  test('$10 off each student takes $20 off two siblings', () => {
    const items = [tuition('kid_1', 100), tuition('kid_2', 100)];
    const byStudent = new Map([
      ['kid_1', discount()],
      ['kid_2', discount()],
    ]);
    const lines = buildDiscountLines(items, byStudent, PERIOD);
    expect(lines).toHaveLength(2);
    expect(lines.reduce((sum, line) => sum + line.total, 0)).toBe(-20);
  });

  test('$10 off for the family takes $10 off the same two siblings, once', () => {
    const items = [tuition('kid_1', 100), tuition('kid_2', 100)];
    const line = buildFamilyDiscountLine(items, discount({scope: 'family'}), PERIOD);
    expect(line.total).toBe(-10);
    expect(line.student_id).toBe('');
    expect(line.is_family_discount).toBe(true);
  });

  test('a family percentage is taken after the per-student lines', () => {
    const items = [tuition('kid_1', 100), tuition('kid_2', 100)];
    const studentLines = buildDiscountLines(items, new Map([['kid_1', discount()]]), PERIOD);
    const line = buildFamilyDiscountLine(
      [...items, ...studentLines],
      discount({scope: 'family', mode: 'percent', value: 50}),
      PERIOD,
    );
    // 200 billed, 10 off for kid_1, so 50% of the remaining 190.
    expect(line.total).toBe(-95);
  });

  test('the two together never take an invoice below zero', () => {
    const items = [tuition('kid_1', 20)];
    const studentLines = buildDiscountLines(items, new Map([['kid_1', discount({value: 15})]]), PERIOD);
    const line = buildFamilyDiscountLine(
      [...items, ...studentLines],
      discount({scope: 'family', value: 50}),
      PERIOD,
    );
    const total = [...items, ...studentLines, line].reduce((sum, i) => sum + i.total, 0);
    expect(total).toBe(0);
  });

  test('a per-student discount is never applied as a family line', () => {
    const items = [tuition('kid_1', 100)];
    expect(buildFamilyDiscountLine(items, discount({scope: 'student'}), PERIOD)).toBeNull();
  });

  test('a family discount outside its window adds no line', () => {
    const items = [tuition('kid_1', 100)];
    const expired = discount({scope: 'family', duration: 'months', months: 1, startDate: new Date(Date.UTC(2026, 5, 1))});
    expect(buildFamilyDiscountLine(items, expired, PERIOD)).toBeNull();
  });

  test('nothing billable means no family line', () => {
    expect(buildFamilyDiscountLine([], discount({scope: 'family'}), PERIOD)).toBeNull();
  });
});
