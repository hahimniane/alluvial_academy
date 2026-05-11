import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared teaching vs non-teaching classification for audits and live metrics.
class TeachingFormClassification {
  const TeachingFormClassification._();

  static const String studentGradeAssessmentTemplateId = 'Sn0TEj7lFN1hJnLlfMBx';
  static const String dailyClassReportFormId = 'daily_class_report';
  static const String studentGradeAssessmentTypeFieldId = '1754432189399';

  static bool gradeAssessmentTypeFieldLooksFilled(dynamic raw) {
    if (raw == null) return false;
    if (raw is String) return raw.trim().isNotEmpty;
    if (raw is List) return raw.isNotEmpty;
    return true;
  }

  static bool responsesLookLikeDailyClassReport(
      Map<String, dynamic> responses) {
    return responses.containsKey('actual_duration') ||
        responses.containsKey('lesson_covered') ||
        responses.containsKey('used_curriculum') ||
        responses.containsKey('session_quality') ||
        responses.containsKey('teacher_notes') ||
        responses.containsKey('students_present') ||
        responses.containsKey('students_attended') ||
        responses.containsKey('1754407297953') ||
        responses.containsKey('1754407184691') ||
        responses.containsKey('1754407509366') ||
        responses.containsKey('1754406457284');
  }

  static bool isStudentGradeAssessmentFormData(
    Map<String, dynamic> dataMap,
    Map<String, dynamic> responses,
  ) {
    final tid = (dataMap['templateId'] as String? ?? '').trim();
    final fid = (dataMap['formId'] as String? ?? '').trim();
    if (tid == studentGradeAssessmentTemplateId ||
        fid == studentGradeAssessmentTemplateId) {
      return true;
    }
    if (tid == dailyClassReportFormId || fid == dailyClassReportFormId) {
      return false;
    }

    final eff = effectiveFormTypeForClassification(dataMap);
    if (eff == 'daily' || eff == 'weekly' || eff == 'monthly') {
      return false;
    }

    if (responsesLookLikeDailyClassReport(responses)) return false;
    return gradeAssessmentTypeFieldLooksFilled(
      responses[studentGradeAssessmentTypeFieldId],
    );
  }

  static String effectiveFormTypeForClassification(
      Map<String, dynamic> dataMap) {
    var raw = (dataMap['formType'] as String? ?? '').trim().toLowerCase();
    if (raw.isNotEmpty) return raw;

    final freq = (dataMap['frequency'] as String? ?? '').trim().toLowerCase();
    switch (freq) {
      case 'persession':
      case 'per_session':
        return 'daily';
      case 'weekly':
        return 'weekly';
      case 'monthly':
        return 'monthly';
      case 'ondemand':
        return 'ondemand';
      default:
        break;
    }

    return (dataMap['templateId'] != null) ? 'daily' : 'legacy';
  }

  static String _compactResponseHaystackForClassification(
    Map<String, dynamic> responses, {
    int maxChars = 2500,
  }) {
    final buf = StringBuffer();
    for (final e in responses.entries) {
      buf.write('${e.key} ${e.value} ');
      if (buf.length >= maxChars) break;
    }
    return buf.toString().toLowerCase();
  }

  static bool _haystackLooksNonTeaching(String haystack) {
    const phrases = <String>[
      'student assessment',
      'students assessment',
      'grade form',
      'formulaire d\'évaluation',
      '/grade form',
      'monthly quiz',
      'homework',
      'devoir maison',
      'formulaire de devoir',
      'formulaire de quiz',
      'assignment form',
      'quiz form',
      'if this is an assignment',
      'this is an assignment',
      'type n/a if',
      'midterm',
      'final exam',
      'quiz score',
      ' qcm ',
      'rubric',
      'penalty',
      'leave request',
      'excuse',
    ];
    if (phrases.any(haystack.contains)) return true;
    if (haystack.contains('assignment') && haystack.contains('grade')) {
      return true;
    }
    return false;
  }

  static bool isTeachingFormData(Map<String, dynamic> dataMap) {
    final shiftId = (dataMap['shiftId'] as String? ?? '').trim();

    final effectiveType = effectiveFormTypeForClassification(dataMap);
    final formTitle = ((dataMap['formName'] as String?) ??
            (dataMap['formTitle'] as String?) ??
            (dataMap['title'] as String?) ??
            '')
        .toLowerCase();

    final responses = (dataMap['responses'] is Map)
        ? (dataMap['responses'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    if (isStudentGradeAssessmentFormData(dataMap, responses)) return false;

    if (effectiveType == 'daily' ||
        effectiveType == 'weekly' ||
        effectiveType == 'monthly') {
      return true;
    }

    final responseHaystack =
        _compactResponseHaystackForClassification(responses, maxChars: 2000);

    final haystack = '$effectiveType $formTitle $responseHaystack';

    if (_haystackLooksNonTeaching(haystack)) return false;

    if (shiftId.isNotEmpty) return true;

    if (effectiveType == 'legacy') {
      return true;
    }

    if (effectiveType == 'ondemand') {
      const teachingLike = <String>[
        'readiness',
        'préparation',
        'preparation',
        'class report',
        'cours journalier',
        'daily class',
        'rapport quotidien',
        'formulaire de préparation',
        'readiness form',
      ];
      if (teachingLike.any(formTitle.contains)) return true;
      return false;
    }

    const teachingTokens = <String>[
      'readiness',
      'class report',
      'classroom',
      'cours journalier',
      'preparation',
      'préparation',
      'formulaire de préparation',
      'readiness form',
    ];
    if (teachingTokens.any(haystack.contains)) return true;

    return false;
  }

  static bool requiresTimesheetProofForTeachingAcceptance(
      Map<String, dynamic> dataMap) {
    final t = effectiveFormTypeForClassification(dataMap);
    return t == 'daily';
  }
}

bool timesheetDocHasClockPair(Map<String, dynamic> dataMap) {
  final cin = dataMap['clock_in_timestamp'] as Timestamp? ??
      dataMap['clock_in'] as Timestamp?;
  final cout = dataMap['clock_out_timestamp'] as Timestamp? ??
      dataMap['clock_out'] as Timestamp?;
  return cin != null && cout != null;
}

Set<String> formResponseIdsWithTimesheetProof(
    Iterable<Map<String, dynamic>> timesheets) {
  final ids = <String>{};
  for (final d in timesheets) {
    if (!timesheetDocHasClockPair(d)) continue;
    final frid = (d['form_response_id']?.toString() ?? '').trim();
    if (frid.isEmpty) continue;
    ids.add(frid);
  }
  return ids;
}
