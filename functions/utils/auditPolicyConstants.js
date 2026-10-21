/**
 * Canonical policy constants for teacher audits and shift timesheets.
 * Mirrors lib/core/constants/audit_policy.dart.
 */

const STRICT_CLOCK_POLICY_EFFECTIVE_DATE = '2026-11-01';

/**
 * The cutoff instant: midnight on the effective date in New York, where the
 * school runs its calendar. 2026-11-01 is still on EDT (UTC-4) until 2 AM.
 */
const STRICT_CLOCK_POLICY_CUTOFF_ISO = '2026-11-01T00:00:00-04:00';
const STRICT_CLOCK_POLICY_CUTOFF_MS = Date.parse(STRICT_CLOCK_POLICY_CUTOFF_ISO);

/**
 * Returns true if the shift start is on or after the strict clock policy
 * cutoff (2026-11-01 00:00 America/New_York).
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
  return date.getTime() >= STRICT_CLOCK_POLICY_CUTOFF_MS;
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
  STRICT_CLOCK_POLICY_CUTOFF_ISO,
  isShiftAfterStrictPolicy,
  isYearMonthAfterStrictPolicy,
};
