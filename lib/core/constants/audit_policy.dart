/// Canonical policy constants for teacher audits and shift timesheets.
class AuditPolicyConstants {
  AuditPolicyConstants._();

  /// Starting from this date, audits strictly require valid clock-in
  /// and clock-out timesheets. Form-only submissions do not award hours or pay.
  static const String strictClockPolicyEffectiveDate = '2026-11-01';

  /// The cutoff instant: midnight on the effective date in New York, where
  /// the school runs its calendar. 2026-11-01 is still on EDT (UTC-4) until
  /// 2 AM. Mirrors functions/utils/auditPolicyConstants.js.
  static final DateTime strictClockPolicyCutoffUtc =
      DateTime.parse('2026-11-01T00:00:00-04:00');

  /// Returns true if the given shift start time falls on or after the strict clock policy cutoff.
  static bool isShiftAfterStrictPolicy(DateTime? shiftStart) {
    if (shiftStart == null) return false;
    final startUtc = shiftStart.isUtc ? shiftStart : shiftStart.toUtc();
    return !startUtc.isBefore(strictClockPolicyCutoffUtc);
  }

  /// Returns true if the given yearMonth (e.g., '2026-11') falls on or after the policy cutoff.
  static bool isYearMonthAfterStrictPolicy(String? yearMonth) {
    if (yearMonth == null || yearMonth.trim().isEmpty) return false;
    final ym = yearMonth.trim();
    // Compare 'yyyy-MM' strings directly; '2026-11' >= '2026-11' is true, '2026-10' >= '2026-11' is false.
    final cutoffYm = strictClockPolicyEffectiveDate.substring(0, 7);
    return ym.compareTo(cutoffYm) >= 0;
  }
}
