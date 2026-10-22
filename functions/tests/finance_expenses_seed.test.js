/**
 * The recurring-cost seed plan (scripts/finance_seed_recurring.js).
 *
 * Expected behavior:
 * - A known service with a matching expense is added at its latest amount,
 *   starting the month after that expense; without one it is "needs amount".
 * - A vendor paid in two months, or marked as a recurring subscription, is added.
 * - Test-looking short names, deleted rows, one-off vendors and costs that
 *   already run are not added.
 */
const {planSeed} = require('../scripts/finance_seed_recurring');

const row = (over) => ({
  amount: 10,
  expense_date: {toDate: () => new Date('2026-09-01T12:00:00Z')},
  ...over,
});

describe('planSeed', () => {
  const expenses = [
    row({vendor: 'Zoom', amount: 50, subcategory: 'recurring_subscriptions'}),
    row({vendor: 'Zoom.us 3 licences', amount: 150, expense_date: {toDate: () => new Date('2026-09-14T12:00:00Z')}}),
    row({vendor: 'Claude Monthly Subcription', amount: 100, subcategory: 'recurring_subscriptions'}),
    row({vendor: 'lol', amount: 50, subcategory: 'recurring_subscriptions'}),
    row({vendor: 'tiktok', amount: 20, category: 'other', expense_date: {toDate: () => new Date('2026-07-10T12:00:00Z')}}),
    row({vendor: 'Canva', amount: 13, category: 'marketing', expense_date: {toDate: () => new Date('2026-07-05T12:00:00Z')}}),
    row({vendor: 'Canva', amount: 13, category: 'marketing', expense_date: {toDate: () => new Date('2026-08-05T12:00:00Z')}}),
    row({vendor: 'Old tool', amount: 9, deleted: true, subcategory: 'recurring_subscriptions'}),
  ];

  test('adds known services, repeated vendors and flagged subscriptions', () => {
    const plan = planSeed(expenses, [], '2026-10');
    const byName = Object.fromEntries(plan.add.map((c) => [c.name, c]));

    expect(byName.Zoom).toMatchObject({category: 'software', amount: 150, day_of_month: 14, start_month: '2026-10', end_month: null});
    expect(byName['Claude Monthly Subcription']).toMatchObject({category: 'software', amount: 100, start_month: '2026-10'});
    expect(byName.Canva).toMatchObject({category: 'marketing', amount: 13, start_month: '2026-09', day_of_month: 5});
    expect(byName.tiktok).toBeUndefined();
    expect(byName['Old tool']).toBeUndefined();
  });

  test('known services with no expense need an amount', () => {
    const plan = planSeed(expenses, [], '2026-10');
    expect(plan.needsAmount).toEqual(['Hostinger', 'Firebase / Google Cloud', 'Google Workspace']);
  });

  test('short test-looking names are skipped with a reason', () => {
    const plan = planSeed(expenses, [], '2026-10');
    expect(plan.skipped).toEqual([{name: 'lol', why: 'name is too short to be a real vendor; check it'}]);
  });

  test('running costs and --skip names are left alone; stopped ones can come back', () => {
    const plan = planSeed(
      expenses,
      [
        {name: 'zoom', end_month: null},
        {name: 'Canva', end_month: '2026-08'},
      ],
      '2026-10',
      ['Claude Monthly Subcription']
    );
    const names = plan.add.map((c) => c.name);
    expect(names).toEqual(['Canva']);
    expect(plan.skipped.map((s) => s.name)).toEqual(expect.arrayContaining(['Zoom', 'Claude Monthly Subcription']));
  });
});
