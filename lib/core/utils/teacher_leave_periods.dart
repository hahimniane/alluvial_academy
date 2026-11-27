import 'package:cloud_firestore/cloud_firestore.dart';

/// Approved leave windows derived from leave_request / excuse form_responses.
class TeacherLeavePeriods {
  const TeacherLeavePeriods._();

  static const excuseTemplateIds = <String>{
    '6YBwJQoLQ5tNU3RjDp7f',
    'lo88vXRPGQb5P0qhXUIU',
  };

  static final _dayMonthYear = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$');

  /// A stored form date: a Timestamp, an ISO string, or the forms' own
  /// "day/month/year" text (both the app and the website save dates that way).
  /// A value whose second part is over 12 can only be month/day/year.
  static DateTime? parseDateField(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty) return null;
    final match = _dayMonthYear.firstMatch(text);
    if (match == null) return DateTime.tryParse(text);
    var day = int.parse(match.group(1)!);
    var month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    if (month > 12 && day <= 12) {
      final swap = day;
      day = month;
      month = swap;
    }
    if (month < 1 || month > 12 || day < 1) return null;
    final date = DateTime(year, month, day);
    // Rejects dates such as 31/2/2026 that DateTime would roll forward.
    if (date.month != month || date.day != day) return null;
    return date;
  }

  /// The leave as a [start, end) window. A date with no time of day covers
  /// that whole day, so a one-day excuse (same start and end date) covers the
  /// day, and the end date is included. Dates entered back to front are put in order.
  static ({DateTime start, DateTime end})? window(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    var from = start;
    var to = end;
    if (to.isBefore(from)) {
      final swap = from;
      from = to;
      to = swap;
    }
    if (_isMidnight(to)) to = DateTime(to.year, to.month, to.day + 1);
    if (!to.isAfter(from)) return null;
    return (start: from, end: to);
  }

  static bool _isMidnight(DateTime d) =>
      d.hour == 0 && d.minute == 0 && d.second == 0 && d.millisecond == 0 && d.microsecond == 0;

  static List<({DateTime start, DateTime end})> periodsForTeacherFromFormDocs(
    Iterable<Map<String, dynamic>> formMaps,
    String teacherId,
  ) {
    final out = <({DateTime start, DateTime end})>[];
    for (final dataMap in formMaps) {
      final templateId = dataMap['templateId'] as String? ??
          dataMap['formId'] as String? ??
          '';

      final tid = dataMap['userId'] as String? ??
          dataMap['submittedBy'] as String? ??
          dataMap['submitted_by'] as String?;
      if (tid != teacherId) continue;

      final responses = (dataMap['responses'] as Map<String, dynamic>?) ?? {};
      DateTime? leaveStart;
      DateTime? leaveEnd;

      if (templateId == 'leave_request') {
        if ((dataMap['status'] as String?)?.toLowerCase() != 'approved') {
          continue;
        }
        leaveStart = parseDateField(responses['start_date']);
        leaveEnd = parseDateField(responses['end_date']);
      } else if (excuseTemplateIds.contains(templateId)) {
        if ((dataMap['reviewStatus'] as String?)?.toLowerCase() != 'accepted') {
          continue;
        }
        leaveStart = parseDateField(responses['1754402840684']);
        leaveEnd = parseDateField(responses['1754402885007']);
      } else {
        continue;
      }

      final period = window(leaveStart, leaveEnd);
      if (period != null) out.add(period);
    }
    return out;
  }
}
