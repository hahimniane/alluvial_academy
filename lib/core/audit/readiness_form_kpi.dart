import 'dart:math' show min;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Readiness "submitted" count for the audit month, given the same
/// [acceptedTeachingForms] list produced by the teaching-form acceptance
/// pipeline (post timesheet gate and per-shift dedupe).
class ReadinessFormKpi {
  ReadinessFormKpi._();

  static bool isDateInRange(DateTime date, DateTime start, DateTime end) {
    return date.isAfter(start.subtract(const Duration(hours: 1))) &&
        date.isBefore(end.add(const Duration(hours: 1)));
  }

  static QueryDocumentSnapshot? resolveShiftDocForFormShiftId(
    String? formShiftId,
    List<QueryDocumentSnapshot> shifts,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (formShiftId == null) return null;
    final fid = formShiftId.trim();
    if (fid.isEmpty) return null;

    for (final s in shifts) {
      final dataRaw = s.data();
      if (dataRaw is! Map<String, dynamic>) continue;
      final dataMap = dataRaw;
      if (dataMap['isBanned'] == true) continue;
      final startTimestamp = dataMap['shift_start'] as Timestamp?;
      if (startTimestamp == null) continue;
      final start = startTimestamp.toDate();
      if (!isDateInRange(start, startDate, endDate)) continue;
      if (s.id == fid) return s;
    }
    for (final s in shifts) {
      final dataRaw = s.data();
      if (dataRaw is! Map<String, dynamic>) continue;
      final dataMap = dataRaw;
      if (dataMap['isBanned'] == true) continue;
      final startTimestamp = dataMap['shift_start'] as Timestamp?;
      if (startTimestamp == null) continue;
      final start = startTimestamp.toDate();
      if (!isDateInRange(start, startDate, endDate)) continue;
      if (fid.length >= 8 &&
          s.id.length >= 8 &&
          s.id.endsWith(fid.substring(fid.length - 8))) {
        return s;
      }
    }
    return null;
  }

  /// Matches [TeacherAuditService._processForms] readiness KPI (cap vs
  /// completed+missed shifts in window).
  static int submittedCountForAcceptedTeachingForms({
    required List<QueryDocumentSnapshot> shifts,
    required List<QueryDocumentSnapshot> acceptedTeachingForms,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    var completedPlusMissedForReadiness = 0;
    for (final shift in shifts) {
      final dataRaw = shift.data();
      if (dataRaw is! Map<String, dynamic>) continue;
      final dataMap = dataRaw;
      if (dataMap['isBanned'] == true) continue;
      final startTimestamp = dataMap['shift_start'] as Timestamp?;
      if (startTimestamp == null) continue;
      final start = startTimestamp.toDate();
      if (!isDateInRange(start, startDate, endDate)) continue;
      final status = (dataMap['status'] ?? 'scheduled').toString();
      if (status == 'completed' || status == 'missed') {
        completedPlusMissedForReadiness++;
      }
    }

    final coveredReadinessShiftKeys = <String>{};
    var unlinkedAcceptedReadiness = 0;
    for (final form in acceptedTeachingForms) {
      final dataRaw = form.data();
      if (dataRaw is! Map<String, dynamic>) continue;
      final dataMap = dataRaw;
      final shiftId = dataMap['shiftId'] as String?;
      if (shiftId == null || shiftId.isEmpty) {
        unlinkedAcceptedReadiness++;
        continue;
      }
      final shiftDoc = resolveShiftDocForFormShiftId(
        shiftId,
        shifts,
        startDate,
        endDate,
      );
      if (shiftDoc == null) continue;
      final shiftData = shiftDoc.data();
      if (shiftData is! Map<String, dynamic>) continue;
      final st = (shiftData['status'] ?? 'scheduled').toString();
      if (st != 'completed' && st != 'missed') continue;
      final sid = shiftDoc.id;
      final key = sid.length >= 8 ? sid.substring(sid.length - 8) : sid;
      coveredReadinessShiftKeys.add(key);
    }

    return min(
      completedPlusMissedForReadiness,
      coveredReadinessShiftKeys.length + unlinkedAcceptedReadiness,
    );
  }
}
