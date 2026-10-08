jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (...args) => args[args.length - 1],
}));

const admin = require('firebase-admin');

// A tiny Firestore double that records which collections were read and the
// filters each query carried, and returns nothing — the point here is what
// the repair jobs ask Firestore for, not what they do with the rows.
const buildDb = () => {
  const reads = [];
  const makeQuery = (name, filters = []) => ({
    where: (field, op, value) => makeQuery(name, [...filters, {field, op, value}]),
    get: async () => {
      reads.push({collection: name, filters});
      return {docs: [], empty: true, size: 0};
    },
  });
  return {
    reads,
    collection: (name) => ({
      ...makeQuery(name),
      doc: (id) => ({get: async () => ({exists: false, id, data: () => ({})})}),
    }),
    batch: () => ({update: jest.fn(), set: jest.fn(), commit: jest.fn(async () => {})}),
  };
};

describe('timesheet / shift repair schedules', () => {
  let db;
  beforeEach(() => {
    db = buildDb();
    admin.firestore = jest.fn(() => db);
    admin.firestore.Timestamp = {
      fromDate: (d) => ({toDate: () => d, toMillis: () => d.getTime(), __ts: true}),
      now: () => ({toDate: () => new Date(), toMillis: () => Date.now(), __ts: true}),
    };
    admin.firestore.FieldValue = {serverTimestamp: () => ({__type: 'serverTimestamp'})};
    jest.spyOn(console, 'log').mockImplementation(() => {});
  });
  afterEach(() => jest.restoreAllMocks());

  test('the 30-minute job only asks for open shifts whose end has passed, and never touches timesheets', async () => {
    const {fixTimesheetsPayAndStatus} = require('../handlers/shifts');
    const before = Date.now();
    await fixTimesheetsPayAndStatus();
    expect(db.reads.map((r) => r.collection)).toEqual(['teaching_shifts']);
    const [{filters}] = db.reads;
    expect(filters).toEqual(expect.arrayContaining([
      {field: 'status', op: 'in', value: ['active', 'scheduled']},
      expect.objectContaining({field: 'shift_end', op: '<'}),
    ]));
    const bound = filters.find((f) => f.field === 'shift_end').value;
    expect(bound.__ts).toBe(true);
    expect(bound.toMillis()).toBeGreaterThanOrEqual(before);
    expect(bound.toMillis()).toBeLessThanOrEqual(Date.now());
  });

  test('the payment repair runs on its own schedule and is the only reader of timesheet_entries', async () => {
    const {fixTimesheetsPayment} = require('../handlers/shifts');
    await fixTimesheetsPayment();
    expect(db.reads.map((r) => r.collection)).toEqual(['timesheet_entries']);
  });
});
