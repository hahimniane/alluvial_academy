import 'package:cloud_firestore/cloud_firestore.dart';

/// Approved leave windows derived from leave_request / excuse form_responses.
class TeacherLeavePeriods {
  const TeacherLeavePeriods._();

  static const excuseTemplateIds = <String>{
    '6YBwJQoLQ5tNU3RjDp7f',
    'lo88vXRPGQb5P0qhXUIU',
  };

  static DateTime? parseDateField(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

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

      if (leaveStart == null || leaveEnd == null) continue;
      out.add((start: leaveStart, end: leaveEnd));
    }
    return out;
  }
}
