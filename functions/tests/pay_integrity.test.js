jest.mock('firebase-functions/v2/scheduler', () => ({onSchedule: (_o, fn) => fn}));
jest.mock('../services/email/transporter', () => ({createTransporter: async () => ({sendMail: async () => {}})}));

const {_compareMonth, _hoursOf, _recentMonths, _reportHtml} = require('../handlers/pay_integrity');

test('hours parse the timesheet formats the app writes', () => {
  expect(_hoursOf('01:00:00')).toBe(1);
  expect(_hoursOf('01:29:52')).toBeCloseTo(1.4978, 3);
  expect(_hoursOf(1.5)).toBe(1.5);
  expect(_hoursOf('')).toBe(0);
  expect(_hoursOf(null)).toBe(0);
});

test('a month where the audit pays fewer hours than were clocked is flagged, largest gap first', () => {
  const rows = _compareMonth({
    timesheetHours: {jalloh: 55.25, fine: 10.0, deleted: 3},
    auditHours: {jalloh: 40.4, fine: 10.04, overpaid: 5},
  });
  expect(rows.map((r) => r.uid)).toEqual(['jalloh', 'overpaid', 'deleted']);
  expect(rows[0]).toMatchObject({clocked: 55.25, audited: 40.4, gap: 14.85});
  expect(rows[1].reason).toMatch(/more hours/);
  expect(rows[2]).toMatchObject({audited: null, reason: expect.stringContaining('no audit')});
});

test('the three completed months before the current one are checked', () => {
  expect(_recentMonths(new Date('2026-09-07T12:00:00Z'))).toEqual(['2026-06', '2026-07', '2026-08']);
  expect(_recentMonths(new Date('2026-01-15T12:00:00Z'))).toEqual(['2025-10', '2025-11', '2025-12']);
});

test('the email names the teacher, the month and the gap', () => {
  const html = _reportHtml({months: [{yearMonth: '2026-07', mismatches: [{name: 'Sheikh <Ahmad>', clocked: 55.25, audited: 40.4, gap: 14.85, reason: 'audit pays fewer hours than were clocked'}]}], total: 1, underpaid: 1, overpaid: 0});
  expect(html).toContain('2026-07');
  expect(html).toContain('Sheikh &lt;Ahmad&gt;');
  expect(html).toContain('+14.85');
});

describe('who the pay check is allowed to worry about', () => {
  test('somebody who does not teach is not a missing audit', () => {
    // An administrator clocks hours and has no teaching audit, which is not a
    // pay fault. Reported as one, it invented a 60-hour debt for an admin.
    const rows = _compareMonth({
      timesheetHours: {admin_1: 41.8, teacher_1: 10},
      auditHours: {teacher_1: 4},
      isTeacher: (uid) => uid === 'teacher_1',
    });
    expect(rows.map((r) => r.uid)).toEqual(['teacher_1']);
  });

  test('an audit that paid the schedule is not an overpayment', () => {
    const rows = _compareMonth({
      timesheetHours: {teacher_1: 0},
      auditHours: {teacher_1: 32},
      paidOnSchedule: (uid) => uid === 'teacher_1',
    });
    expect(rows).toEqual([]);
  });

  test('an audit paying more for any other reason is still reported', () => {
    const rows = _compareMonth({
      timesheetHours: {teacher_1: 29.45},
      auditHours: {teacher_1: 42.45},
      paidOnSchedule: () => false,
    });
    expect(rows).toHaveLength(1);
    expect(rows[0].reason).toMatch(/more hours/);
  });

  test('being paid LESS than clocked is reported even on a schedule audit', () => {
    // The whole reason this check exists: hours worked that nobody pays for.
    const rows = _compareMonth({
      timesheetHours: {teacher_1: 73.27},
      auditHours: {teacher_1: 72.5},
      paidOnSchedule: () => true,
    });
    expect(rows).toHaveLength(1);
    expect(rows[0].gap).toBeCloseTo(0.77, 2);
  });

  test('by default nothing is filtered, so a caller must opt in', () => {
    const rows = _compareMonth({timesheetHours: {a: 5}, auditHours: {}});
    expect(rows.map((r) => r.uid)).toEqual(['a']);
  });
});

describe('what the email puts first', () => {
  const month = (mismatches) => ({months: [{yearMonth: '2026-07', mismatches}], total: mismatches.length,
    underpaid: mismatches.filter((r) => r.gap > 0).length,
    overpaid: mismatches.filter((r) => r.gap < 0).length});

  test('hours nobody is paying for lead, and say somebody may be owed them', () => {
    const html = _reportHtml(month([
      {name: 'Short Teacher', clocked: 73.27, audited: 72.5, gap: 0.77, reason: 'audit pays fewer hours than were clocked'},
      {name: 'Extra Teacher', clocked: 2, audited: 32, gap: -30, reason: 'audit pays more hours than were clocked'},
    ]));
    expect(html).toContain('may be owed');
    expect(html.indexOf('Short Teacher')).toBeLessThan(html.indexOf('Extra Teacher'));
  });

  test('the headline counts only what somebody has to act on', () => {
    const html = _reportHtml(month([
      {name: 'Extra One', clocked: 2, audited: 32, gap: -30, reason: 'more'},
      {name: 'Extra Two', clocked: 5, audited: 15, gap: -10, reason: 'more'},
    ]));
    expect(html).toContain('nothing to act on');
    expect(html).toContain('For information only');
    expect(html).not.toMatch(/Pay check: 2 teacher-months paid less/);
  });

  test('an audit paying more is named as usually expected, not as a fault', () => {
    const html = _reportHtml(month([{name: 'Extra Teacher', clocked: 2, audited: 32, gap: -30, reason: 'more'}]));
    expect(html).toMatch(/Approved forms and attestations add hours/);
  });
});
