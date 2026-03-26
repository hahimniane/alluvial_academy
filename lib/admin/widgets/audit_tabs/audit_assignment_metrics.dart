// Shared counts from TeacherAuditFull.detailedFormsNonTeaching — Assignments and
// Evaluation tabs use the same logic (no manual overrides for these numbers).

/// Students Assessment/Grade Form — "Type of assessment …" (multi_select).
const String auditGradeFormAssessmentTypeFieldId = '1754432189399';

enum AuditAssignmentKind { assignment, quiz, assessment }

class AuditAssignmentMetrics {
  final int assignments;
  final int quizzes;
  final int studentAssessments;
  final bool hasMidtermEvidence;
  final bool hasFinalExamEvidence;

  const AuditAssignmentMetrics({
    required this.assignments,
    required this.quizzes,
    required this.studentAssessments,
    required this.hasMidtermEvidence,
    required this.hasFinalExamEvidence,
  });

  /// Rows that belong to the class-report pipeline, not Assignments & assessments.
  static bool isRoutineTeachingPipelineRow(Map<String, dynamic> f) =>
      _shouldExcludeAsRoutineTeachingForm(f);

  static AuditAssignmentMetrics fromDetailedForms(
    List<Map<String, dynamic>> forms,
  ) {
    var assignments = 0;
    var quizzes = 0;
    var assessments = 0;
    var hasMidterm = false;
    var hasFinal = false;

    for (final f in forms) {
      // Stale audits may still list routine class reports here; never count them as
      // assignments/assessments (must match [TeacherAuditService] teaching split).
      if (_shouldExcludeAsRoutineTeachingForm(f)) continue;

      switch (classifyForm(f)) {
        case AuditAssignmentKind.assignment:
          assignments++;
          break;
        case AuditAssignmentKind.quiz:
          quizzes++;
          break;
        case AuditAssignmentKind.assessment:
          assessments++;
          break;
      }
      final flags = _midtermFinalFlagsForForm(f);
      hasMidterm = hasMidterm || flags.$1;
      hasFinal = hasFinal || flags.$2;
    }

    return AuditAssignmentMetrics(
      assignments: assignments,
      quizzes: quizzes,
      studentAssessments: assessments,
      hasMidtermEvidence: hasMidterm,
      hasFinalExamEvidence: hasFinal,
    );
  }

  /// Same shape checks as [TeacherAuditService._responsesLookLikeDailyClassReport].
  static bool _responsesLookLikeDailyClassReport(Map<String, dynamic> responses) {
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

  static bool _shouldExcludeAsRoutineTeachingForm(Map<String, dynamic> f) {
    final fid = (f['formId']?.toString() ?? '').trim();
    final tid = (f['templateId']?.toString() ?? '').trim();
    if (fid == 'daily_class_report' || tid == 'daily_class_report') return true;

    final ft = (f['formType'] as String? ?? '').trim().toLowerCase();
    if (ft == 'daily' || ft == 'weekly' || ft == 'monthly') return true;

    final responses = (f['responses'] as Map<String, dynamic>?) ?? const {};
    return _responsesLookLikeDailyClassReport(responses);
  }

  static String _normalizeAssessmentTypeValue(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.toLowerCase();
    if (v is List) {
      return v.map((e) => e.toString().toLowerCase()).join(' ');
    }
    if (v is Map) {
      return v.values.map((e) => e.toString().toLowerCase()).join(' ');
    }
    return v.toString().toLowerCase();
  }

  static AuditAssignmentKind classifyForm(Map<String, dynamic> f) {
    final responses = (f['responses'] as Map<String, dynamic>?) ?? const {};
    final fromField = _classifyFromGradeFormTypeField(responses);
    if (fromField != null) return fromField;

    final name = ((f['formName'] as String?) ?? '').toLowerCase();
    final type = ((f['formType'] as String?) ?? '').toLowerCase();
    final title = ((f['title'] as String?) ?? '').toLowerCase();

    final responseText = responses.entries
        .map((e) => '${e.key} ${e.value}')
        .join(' ')
        .toLowerCase();

    final haystack = '$name $type $title $responseText';
    if (_containsAny(haystack, const ['quiz', 'qcm', 'test score', 'monthly quiz', 'interrogation'])) {
      return AuditAssignmentKind.quiz;
    }
    if (_containsAny(haystack, const [
      'assessment',
      'grade',
      'student assessment',
      'évaluation',
      'evaluation',
      'score',
      'rubric',
      'note',
    ])) {
      return AuditAssignmentKind.assessment;
    }
    if (_containsAny(haystack, const ['assignment', 'homework', 'devoir', 'task sheet', 'devoir maison'])) {
      return AuditAssignmentKind.assignment;
    }
    return AuditAssignmentKind.assessment;
  }

  /// Values like "Quiz - Quiz", "Assignment - Devoir", "Midterm - …".
  static AuditAssignmentKind? _classifyFromGradeFormTypeField(
    Map<String, dynamic> responses,
  ) {
    if (!responses.containsKey(auditGradeFormAssessmentTypeFieldId)) return null;
    final s = _normalizeAssessmentTypeValue(responses[auditGradeFormAssessmentTypeFieldId]).trim();
    if (s.isEmpty) return null;

    if (s.contains('quiz')) return AuditAssignmentKind.quiz;
    if (s.contains('assignment') || s.contains('devoir')) {
      return AuditAssignmentKind.assignment;
    }
    if (s.contains('midterm') ||
        s.contains('final exam') ||
        s.contains('examen final') ||
        s.contains('project') ||
        s.contains('projet') ||
        s.contains('class work') ||
        s.contains('travail en classe')) {
      return AuditAssignmentKind.assessment;
    }
    return AuditAssignmentKind.assessment;
  }

  static bool _containsAny(String haystack, List<String> tokens) {
    for (final t in tokens) {
      if (haystack.contains(t)) return true;
    }
    return false;
  }

  /// (midterm, finalExam)
  static (bool, bool) _midtermFinalFlagsForForm(Map<String, dynamic> f) {
    final responses = (f['responses'] as Map<String, dynamic>?) ?? const {};
    final fromField =
        _normalizeAssessmentTypeValue(responses[auditGradeFormAssessmentTypeFieldId]);

    var mid = fromField.contains('midterm') ||
        fromField.contains('mi-semestre') ||
        fromField.contains('mi semestre');
    var fin = fromField.contains('final exam') || fromField.contains('examen final');

    final name = ((f['formName'] as String?) ?? '').toLowerCase();
    final type = ((f['formType'] as String?) ?? '').toLowerCase();
    final title = ((f['title'] as String?) ?? '').toLowerCase();
    final responseText = responses.entries
        .map((e) => '${e.key} ${e.value}')
        .join(' ')
        .toLowerCase();
    final haystack = '$name $type $title $responseText';

    if (!mid) {
      mid = _containsAny(haystack, const ['midterm', 'mi-semestre', 'examen de mi-semestre']);
    }
    if (!fin) {
      fin = _containsAny(haystack, const ['final exam', 'examen final']);
    }

    return (mid, fin);
  }
}
