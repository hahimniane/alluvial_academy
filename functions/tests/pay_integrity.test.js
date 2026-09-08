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
