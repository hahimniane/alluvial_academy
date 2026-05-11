import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';
import '../utils/teaching_form_classification.dart';
import 'readiness_form_kpi.dart';

/// Teaching-form acceptance for a single audit month — same buckets as
/// [TeacherAuditService._processForms] (shift link / unlinked class-day gate,
/// timesheet proof, per-shift dedupe).
class TeachingFormAcceptanceForMonthResult {
  final List<QueryDocumentSnapshot> nonTeachingForms;
  final List<QueryDocumentSnapshot> teachingForms;
  final List<QueryDocumentSnapshot> validForms;
  final List<QueryDocumentSnapshot> acceptedForms;
  final List<QueryDocumentSnapshot> duplicateForms;
  final List<QueryDocumentSnapshot> rejectNoTimesheet;
  final Set<String> proofFormIds;
  final Set<String> missedShiftExemptFormIds;
  final Set<String> makeupAdminApprovedFormIds;

  const TeachingFormAcceptanceForMonthResult({
    required this.nonTeachingForms,
    required this.teachingForms,
    required this.validForms,
    required this.acceptedForms,
    required this.duplicateForms,
    required this.rejectNoTimesheet,
    required this.proofFormIds,
    required this.missedShiftExemptFormIds,
    required this.makeupAdminApprovedFormIds,
  });
}

class TeachingFormAcceptanceForMonth {
  TeachingFormAcceptanceForMonth._();

  static TeachingFormAcceptanceForMonthResult compute({
    required List<QueryDocumentSnapshot> forms,
    required List<QueryDocumentSnapshot> shifts,
    required List<QueryDocumentSnapshot> timesheets,
    required DateTime startDate,
    required DateTime endDate,
    required String yearMonth,
    Set<String> adminFormAcceptanceOverrideIds = const {},
  }) {
    final validShiftIds = <String>{};
    for (final shift in shifts) {
      final dataRaw = shift.data();
      if (dataRaw is! Map<String, dynamic>) continue;
      final dataMap = dataRaw;
      if (dataMap['isBanned'] == true) continue;
      final startTimestamp = dataMap['shift_start'] as Timestamp?;
      if (startTimestamp == null) continue;
      final start = startTimestamp.toDate();
      if (ReadinessFormKpi.isDateInRange(start, startDate, endDate)) {
        validShiftIds.add(shift.id);
      }
    }
    final validShiftIdSuffixes = <String>{};
    for (final sid in validShiftIds) {
      if (sid.length >= 8) {
        validShiftIdSuffixes.add(sid.substring(sid.length - 8));
      }
    }

    final teachingForms = <QueryDocumentSnapshot>[];
    final nonTeachingForms = <QueryDocumentSnapshot>[];

    for (final form in forms) {
      final dataRaw = form.data();
      if (dataRaw is! Map<String, dynamic>) continue;
      final dataMap = dataRaw;
      if (TeachingFormClassification.isTeachingFormData(dataMap)) {
        teachingForms.add(form);
      } else {
        nonTeachingForms.add(form);
      }
    }

    final validForms = <QueryDocumentSnapshot>[];
    var linkedFormsCount = 0;
    var unlinkedFormsCount = 0;

    for (final form in teachingForms) {
      final dataRaw = form.data();
      if (dataRaw is! Map<String, dynamic>) continue;
      final dataMap = dataRaw;
      final shiftId = dataMap['shiftId'] as String?;

      final linkedByExact = shiftId != null && validShiftIds.contains(shiftId);
      final linkedBySuffix = shiftId != null &&
          shiftId.length >= 8 &&
          validShiftIdSuffixes.contains(shiftId.length > 8
              ? shiftId.substring(shiftId.length - 8)
              : shiftId);
      if (linkedByExact || linkedBySuffix) {
        validForms.add(form);
        linkedFormsCount++;
      } else {
        if (_validateUnlinkedForm(form, startDate, endDate) ||
            adminFormAcceptanceOverrideIds.contains(form.id)) {
          validForms.add(form);
          unlinkedFormsCount++;
        }
      }
    }

    final proofFormIds = _proofFormIdsFromTimesheetDocs(timesheets);

    final afterTimesheetGate = <QueryDocumentSnapshot>[];
    final rejectNoTimesheet = <QueryDocumentSnapshot>[];
    final missedShiftExemptFormIds = <String>{};
    final makeupAdminApprovedFormIds = <String>{};

    for (final form in validForms) {
      final dataRaw = form.data();
      if (dataRaw is! Map<String, dynamic>) continue;
      final dataMap = dataRaw;
      final makeupSt = _normMakeupApproval(dataMap);
      if (TeachingFormClassification
          .requiresTimesheetProofForTeachingAcceptance(dataMap)) {
        if (proofFormIds.contains(form.id)) {
          afterTimesheetGate.add(form);
        } else if (makeupSt == 'approved') {
          afterTimesheetGate.add(form);
          makeupAdminApprovedFormIds.add(form.id);
        } else {
          final shiftDoc = ReadinessFormKpi.resolveShiftDocForFormShiftId(
            dataMap['shiftId'] as String?,
            shifts,
            startDate,
            endDate,
          );
          if (shiftDoc != null && _shiftDocIsMissed(shiftDoc)) {
            if (makeupSt == 'rejected') {
              rejectNoTimesheet.add(form);
            } else {
              afterTimesheetGate.add(form);
              missedShiftExemptFormIds.add(form.id);
            }
          } else if (adminFormAcceptanceOverrideIds.contains(form.id)) {
            afterTimesheetGate.add(form);
          } else {
            rejectNoTimesheet.add(form);
          }
        }
      } else {
        afterTimesheetGate.add(form);
      }
    }

    if (kDebugMode) {
      AppLogger.debug(
        'Form counting for $yearMonth: total forms=${forms.length}, teaching=${teachingForms.length}, nonTeaching=${nonTeachingForms.length}, linked=$linkedFormsCount, unlinked=$unlinkedFormsCount, valid=${validForms.length}, afterTimesheetGate=${afterTimesheetGate.length}, rejectNoTimesheet=${rejectNoTimesheet.length}',
      );
    }

    final acceptedForms = <QueryDocumentSnapshot>[];
    final duplicateForms = <QueryDocumentSnapshot>[];
    final seenShiftKeys = <String>{};
    for (final form in afterTimesheetGate) {
      final dataRaw = form.data();
      if (dataRaw is! Map<String, dynamic>) continue;
      final dataMap = dataRaw;
      final shiftId = dataMap['shiftId'] as String?;
      if (shiftId == null || shiftId.isEmpty) {
        acceptedForms.add(form);
        continue;
      }
      final dedupeKey =
          shiftId.length >= 8 ? shiftId.substring(shiftId.length - 8) : shiftId;
      if (seenShiftKeys.contains(dedupeKey)) {
        duplicateForms.add(form);
      } else {
        seenShiftKeys.add(dedupeKey);
        acceptedForms.add(form);
      }
    }

    return TeachingFormAcceptanceForMonthResult(
      nonTeachingForms: nonTeachingForms,
      teachingForms: teachingForms,
      validForms: validForms,
      acceptedForms: acceptedForms,
      duplicateForms: duplicateForms,
      rejectNoTimesheet: rejectNoTimesheet,
      proofFormIds: proofFormIds,
      missedShiftExemptFormIds: missedShiftExemptFormIds,
      makeupAdminApprovedFormIds: makeupAdminApprovedFormIds,
    );
  }
}

Set<String> _proofFormIdsFromTimesheetDocs(
  List<QueryDocumentSnapshot> timesheets,
) {
  final maps = <Map<String, dynamic>>[];
  for (final ts in timesheets) {
    final raw = ts.data();
    if (raw is Map<String, dynamic>) {
      maps.add(raw);
    }
  }
  return formResponseIdsWithTimesheetProof(maps);
}

String _normMakeupApproval(Map<String, dynamic> dataMap) {
  final raw = dataMap['makeupApprovalStatus'];
  if (raw == null) return '';
  return raw.toString().trim().toLowerCase();
}

bool _shiftDocIsMissed(QueryDocumentSnapshot shift) {
  final raw = shift.data();
  if (raw is! Map<String, dynamic>) return false;
  final st = raw['status'] ?? 'scheduled';
  return st.toString() == 'missed';
}

bool _validateUnlinkedForm(
  QueryDocumentSnapshot form,
  DateTime startDate,
  DateTime endDate,
) {
  try {
    final dataRaw = form.data();
    if (dataRaw is! Map<String, dynamic>) return false;
    final data = dataRaw;
    final submittedAt = data['submittedAt'] as Timestamp?;
    final responses = data['responses'] as Map<String, dynamic>? ?? {};

    if (submittedAt != null) {
      final submitted = submittedAt.toDate();
      final toleranceStart = startDate.subtract(const Duration(days: 5));
      final toleranceEnd = endDate.add(const Duration(days: 5));

      if (submitted.isAfter(toleranceStart) &&
          submitted.isBefore(toleranceEnd)) {
        return _verifyFormByClassDay(responses, startDate, endDate);
      }
    }

    return _verifyFormByClassDay(responses, startDate, endDate);
  } catch (e) {
    AppLogger.error('Error validating unlinked form: $e');
    return false;
  }
}

bool _verifyFormByClassDay(
  Map<String, dynamic> responses,
  DateTime startDate,
  DateTime endDate,
) {
  try {
    String? classDayValue;

    final classDayField = responses['1754406288023'];
    if (classDayField != null) {
      if (classDayField is List) {
        classDayValue =
            classDayField.isNotEmpty ? classDayField.first.toString() : null;
      } else {
        classDayValue = classDayField.toString();
      }
    }

    if (classDayValue == null) {
      for (final entry in responses.entries) {
        final value = entry.value;
        if (value is String || (value is List && value.isNotEmpty)) {
          final valueStr =
              value is List ? value.first.toString() : value.toString();
          if (_isDayOfWeekString(valueStr)) {
            classDayValue = valueStr;
            break;
          }
        }
      }
    }

    if (classDayValue == null) {
      return false;
    }

    final formWeekday = _parseDayOfWeek(classDayValue);
    if (formWeekday == null) {
      return false;
    }

    final currentMonthFirstFiveDays = List.generate(5, (i) {
      final day = startDate.add(Duration(days: i));
      return day.weekday;
    });

    final prevMonth = DateTime(startDate.year, startDate.month - 1);
    final prevMonthLastDay = DateTime(prevMonth.year, prevMonth.month + 1, 0);
    final prevMonthLastFiveDays = List.generate(5, (i) {
      final day = prevMonthLastDay.subtract(Duration(days: 4 - i));
      return day.weekday;
    });

    if (currentMonthFirstFiveDays.contains(formWeekday)) {
      return true;
    }

    if (prevMonthLastFiveDays.contains(formWeekday)) {
      return true;
    }

    final currentMonthAllDays = List.generate(endDate.day, (i) {
      final day = startDate.add(Duration(days: i));
      return day.weekday;
    });

    return currentMonthAllDays.contains(formWeekday);
  } catch (e) {
    AppLogger.error('Error in _verifyFormByClassDay: $e');
    return false;
  }
}

bool _isDayOfWeekString(String value) {
  final lower = value.toLowerCase();
  return lower.contains('mon') ||
      lower.contains('lundi') ||
      lower.contains('tues') ||
      lower.contains('mardi') ||
      lower.contains('wed') ||
      lower.contains('mercredi') ||
      lower.contains('thur') ||
      lower.contains('jeudi') ||
      lower.contains('fri') ||
      lower.contains('vendredi') ||
      lower.contains('sat') ||
      lower.contains('samedi') ||
      lower.contains('sun') ||
      lower.contains('dimanche');
}

int? _parseDayOfWeek(String dayStr) {
  final lower = dayStr.toLowerCase();

  if (lower.contains('mon') || lower.contains('lundi')) return 1;
  if (lower.contains('tues') || lower.contains('mardi')) return 2;
  if (lower.contains('wed') || lower.contains('mercredi')) return 3;
  if (lower.contains('thur') || lower.contains('jeudi')) return 4;
  if (lower.contains('fri') || lower.contains('vendredi')) return 5;
  if (lower.contains('sat') || lower.contains('samedi')) return 6;
  if (lower.contains('sun') || lower.contains('dimanche')) return 7;

  return null;
}
