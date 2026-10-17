/// Which classes a teacher can file a class (readiness) report for.
///
/// Matches the teacher web console: a class that started within the last
/// [windowDays] days, has ended (or was already closed as completed/missed),
/// and was not cancelled. A class still marked scheduled or active after its
/// end time was taught and must be reportable.
class ClassReportEligibility {
  const ClassReportEligibility._();

  static const int windowDays = 60;

  static const Set<String> _closedStatuses = {
    'completed',
    'fullycompleted',
    'partiallycompleted',
    'missed',
  };

  static DateTime windowStart(DateTime now) =>
      now.subtract(const Duration(days: windowDays));

  static bool isCancelledStatus(String status) {
    final normalized = status.toLowerCase();
    return normalized.contains('cancel') ||
        normalized.contains('deleted') ||
        normalized.contains('void');
  }

  static bool isEligible({
    required DateTime? start,
    required DateTime? end,
    required String status,
    required DateTime now,
  }) {
    if (start == null || end == null) return false;
    if (isCancelledStatus(status)) return false;
    if (start.isBefore(windowStart(now))) return false;
    if (!start.isBefore(now)) return false;
    final compact = status.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return end.isBefore(now) || _closedStatuses.contains(compact);
  }
}
