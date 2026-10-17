/**
 * Canonical policy constants for teacher audits and shift timesheets.
 * Mirrors lib/core/constants/audit_policy.dart.
 */

const STRICT_CLOCK_POLICY_EFFECTIVE_DATE = '2026-11-01';

/**
 * Returns true if the shift start timestamp is on or after the strict clock policy cutoff (2026-11-01T00:00:00Z).
 * @param {Date|Object|string|number} shiftStart
 * @returns {boolean}
 */
function isShiftAfterStrictPolicy(shiftStart) {
  if (!shiftStart) return false;
  let date;
  if (shiftStart.toDate && typeof shiftStart.toDate === 'function') {
    date = shiftStart.toDate();
  } else if (shiftStart instanceof Date) {
    date = shiftStart;
  } else {
    date = new Date(shiftStart);
  }
  if (Number.isNaN(date.getTime())) return false;
  const cutoff = new Date('2026-11-01T00:00:00Z');
  return date.getTime() >= cutoff.getTime();
}

/**
 * Returns true if the given yearMonth (e.g., '2026-11') falls on or after the policy cutoff.
 * @param {string} yearMonth
 * @returns {boolean}
 */
function isYearMonthAfterStrictPolicy(yearMonth) {
  if (!yearMonth) return false;
  const ym = String(yearMonth).trim();
  const cutoffYm = STRICT_CLOCK_POLICY_EFFECTIVE_DATE.slice(0, 7);
  return ym >= cutoffYm;
}

module.exports = {
  STRICT_CLOCK_POLICY_EFFECTIVE_DATE,
  isShiftAfterStrictPolicy,
  isYearMonthAfterStrictPolicy,
};
