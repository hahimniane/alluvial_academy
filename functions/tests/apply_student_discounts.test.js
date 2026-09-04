const {applyStudentDiscounts} = require('../utils/student_discounts');

// A stand-in for Firestore holding one document per user id. The point of
// these tests is the wiring — that applyStudentDiscounts actually reaches the
// parent and emits the household line — which testing the line builders on
// their own does not prove.
const fakeDb = (usersById) => {
  const db = {
    collection: () => ({doc: (id) => ({id})}),
    getAll: async (...refs) =>
      refs.map((ref) => ({
        exists: Object.prototype.hasOwnProperty.call(usersById, ref.id),
        data: () => usersById[ref.id],
      })),
  };
  return db;
};

const PERIOD = new Date(Date.UTC(2026, 8, 1));
const START = new Date(Date.UTC(2026, 0, 1));
const tenOff = (over = {}) => ({
  discount: {mode: 'fixed', value: 10, duration: 'ongoing', startDate: START, reason: 'Sibling discount', ...over},
});
const items = [
  {description: 'Tuition - Amina', quantity: 1, unit_price: 100, total: 100, student_id: 'kid_1'},
  {description: 'Tuition - Yusuf', quantity: 1, unit_price: 100, total: 100, student_id: 'kid_2'},
];
const totalOf = (lines) => lines.reduce((sum, line) => sum + line.total, 0);

describe('applyStudentDiscounts', () => {
  test('$10 off each child takes $20 off the invoice', async () => {
    const db = fakeDb({kid_1: tenOff(), kid_2: tenOff()});
    const result = await applyStudentDiscounts(db, items, PERIOD, db, 'parent_1');
    expect(totalOf(result)).toBe(180);
    expect(result.filter((line) => line.is_discount)).toHaveLength(2);
  });

  test('a household discount on the parent takes $10 off once', async () => {
    const db = fakeDb({parent_1: tenOff({scope: 'family'})});
    const result = await applyStudentDiscounts(db, items, PERIOD, db, 'parent_1');
    expect(totalOf(result)).toBe(190);
    const discountLines = result.filter((line) => line.is_discount);
    expect(discountLines).toHaveLength(1);
    expect(discountLines[0].is_family_discount).toBe(true);
    expect(discountLines[0].student_id).toBe('');
  });

  test('the parent is never reached when no parent is passed', async () => {
    const db = fakeDb({parent_1: tenOff({scope: 'family'})});
    const result = await applyStudentDiscounts(db, items, PERIOD, db);
    expect(totalOf(result)).toBe(200);
  });

  test('both kinds together stack, household last', async () => {
    const db = fakeDb({kid_1: tenOff(), parent_1: tenOff({scope: 'family', mode: 'percent', value: 50})});
    const result = await applyStudentDiscounts(db, items, PERIOD, db, 'parent_1');
    // 200 billed, 10 off kid_1, then half of the remaining 190.
    expect(totalOf(result)).toBe(95);
    expect(result[result.length - 1].is_family_discount).toBe(true);
  });

  test('a family-scoped discount saved on a child is not applied per child', async () => {
    const db = fakeDb({kid_1: tenOff({scope: 'family'}), kid_2: tenOff({scope: 'family'})});
    const result = await applyStudentDiscounts(db, items, PERIOD, db, 'parent_1');
    expect(totalOf(result)).toBe(200);
  });

  test('a discount saved before scope existed still comes off that child', async () => {
    const db = fakeDb({kid_1: tenOff()});
    const result = await applyStudentDiscounts(db, items, PERIOD, db, 'parent_1');
    expect(totalOf(result)).toBe(190);
    expect(result.filter((line) => line.is_discount)[0].student_id).toBe('kid_1');
  });

  test('no discounts anywhere leaves the items untouched', async () => {
    const db = fakeDb({});
    const result = await applyStudentDiscounts(db, items, PERIOD, db, 'parent_1');
    expect(result).toEqual(items);
  });
});
