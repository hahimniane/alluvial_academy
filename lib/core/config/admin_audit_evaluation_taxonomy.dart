// ignore_for_file: public_member_api_docs

import 'admin_audit_compliance_config.dart';

/// Whether evaluation evidence is tied to form responses, tasks, or contextual documents.
enum AdminEvalEvidenceKind { form, task, document }

/// One scoring row in the admin evaluation UI (0–5 + N/A).
class AdminEvalCriterion {
  final String id;
  final String labelEn;
  final String? hintEn;
  final AdminEvalEvidenceKind evidence;
  final Set<String> templateIds;

  const AdminEvalCriterion({
    required this.id,
    required this.labelEn,
    this.hintEn,
    required this.evidence,
    this.templateIds = const {},
  });
}

/// Groups criteria and defines which templates filter the submission list.
class AdminEvalTheme {
  final String id;
  final String titleEn;
  final Set<String> templateIds;
  final List<AdminEvalCriterion> criteria;

  const AdminEvalTheme({
    required this.id,
    required this.titleEn,
    required this.templateIds,
    required this.criteria,
  });
}

/// Taxonomy for admin CEO evaluation: separate form vs task criteria; themes map to templates.
class AdminAuditEvaluationTaxonomy {
  AdminAuditEvaluationTaxonomy._();

  static const String themeAllId = 'all';

  static final AdminEvalTheme themeAll = AdminEvalTheme(
    id: themeAllId,
    titleEn: 'All CEO forms',
    templateIds: AdminAuditComplianceConfig.allCeoEvaluationTemplateIds,
    criteria: const [],
  );

  static final List<AdminEvalTheme> formThemes = [
    AdminEvalTheme(
      id: 'hosting',
      titleEn: 'Zoom hosting',
      templateIds: {AdminAuditComplianceConfig.zoomHostingCeoTemplateId},
      criteria: [
        AdminEvalCriterion(
          id: 'h1',
          labelEn: 'Hosting start time reported',
          hintEn: 'Declared start vs expected',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: {AdminAuditComplianceConfig.zoomHostingCeoTemplateId},
        ),
        AdminEvalCriterion(
          id: 'h2',
          labelEn: 'Hosting end time reported',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: {AdminAuditComplianceConfig.zoomHostingCeoTemplateId},
        ),
        AdminEvalCriterion(
          id: 'h3',
          labelEn: 'Absent/late teachers documented with follow-up',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: {AdminAuditComplianceConfig.zoomHostingCeoTemplateId},
        ),
      ],
    ),
    AdminEvalTheme(
      id: 'end_of_shift',
      titleEn: 'Daily end of shift (CEO)',
      templateIds: AdminAuditComplianceConfig.dailyEndOfShiftTemplateIds,
      criteria: [
        AdminEvalCriterion(
          id: 'eos1',
          labelEn: 'Shift goals and achievements documented',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: AdminAuditComplianceConfig.dailyEndOfShiftTemplateIds,
        ),
        AdminEvalCriterion(
          id: 'eos2',
          labelEn: 'Hours and shift boundaries declared consistently',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: AdminAuditComplianceConfig.dailyEndOfShiftTemplateIds,
        ),
        AdminEvalCriterion(
          id: 'eos3',
          labelEn: 'Overdue tasks count reported honestly',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: AdminAuditComplianceConfig.dailyEndOfShiftTemplateIds,
        ),
      ],
    ),
    AdminEvalTheme(
      id: 'weekly_reports',
      titleEn: 'Weekly / marketing / finance reports',
      templateIds: AdminAuditComplianceConfig.weeklyReportTemplateIds,
      criteria: [
        AdminEvalCriterion(
          id: 'wr1',
          labelEn: 'Weekly CEO-style reports submitted on time',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: AdminAuditComplianceConfig.weeklyReportTemplateIds,
        ),
        AdminEvalCriterion(
          id: 'wr2',
          labelEn: 'Marketing weekly summary complete',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: {
            '3MB3jxkjcCdD11us9q4N',
          },
        ),
      ],
    ),
    AdminEvalTheme(
      id: 'excuse',
      titleEn: 'Excuse workflow',
      templateIds: {AdminAuditComplianceConfig.excuseCeoTemplateId},
      criteria: [
        AdminEvalCriterion(
          id: 'ex1',
          labelEn: 'Excuse form used when required (timely notice)',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: {AdminAuditComplianceConfig.excuseCeoTemplateId},
        ),
      ],
    ),
    AdminEvalTheme(
      id: 'student_ops',
      titleEn: 'Students & attendance (CEO)',
      templateIds: {
        AdminAuditComplianceConfig.studentsStatusCeoTemplateId,
        AdminAuditComplianceConfig.groupBayanaAttendanceTemplateId,
      },
      criteria: [
        AdminEvalCriterion(
          id: 'so1',
          labelEn: 'Student status / BAYANA forms used consistently',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: {
            AdminAuditComplianceConfig.studentsStatusCeoTemplateId,
            AdminAuditComplianceConfig.groupBayanaAttendanceTemplateId,
          },
        ),
      ],
    ),
    AdminEvalTheme(
      id: 'overdues_sheet',
      titleEn: 'Weekly overdues data',
      templateIds: {AdminAuditComplianceConfig.weeklyOverduesCeoTemplateId},
      criteria: [
        AdminEvalCriterion(
          id: 'ov1',
          labelEn: 'Overdues report submitted with clear numbers',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: {AdminAuditComplianceConfig.weeklyOverduesCeoTemplateId},
        ),
      ],
    ),
    AdminEvalTheme(
      id: 'coachees',
      titleEn: 'Bi-weekly coachees performance',
      templateIds: {AdminAuditComplianceConfig.biweeklyCoacheesPerformanceId},
      criteria: [
        AdminEvalCriterion(
          id: 'bc1',
          labelEn: 'Bi-weekly coachee performance form complete',
          evidence: AdminEvalEvidenceKind.form,
          templateIds: {AdminAuditComplianceConfig.biweeklyCoacheesPerformanceId},
        ),
      ],
    ),
  ];

  static final List<AdminEvalCriterion> taskCriteria = [
    const AdminEvalCriterion(
      id: 't1',
      labelEn: 'Overdue assigned tasks under control',
      hintEn: 'Prefer tasks collection as source of truth',
      evidence: AdminEvalEvidenceKind.task,
    ),
    const AdminEvalCriterion(
      id: 't2',
      labelEn: 'Completion rate vs assigned workload',
      evidence: AdminEvalEvidenceKind.task,
    ),
    const AdminEvalCriterion(
      id: 't3',
      labelEn: 'Tasks acknowledged / opened promptly',
      evidence: AdminEvalEvidenceKind.task,
    ),
    const AdminEvalCriterion(
      id: 't4',
      labelEn: 'Use of labels and sub-tasks for clarity',
      evidence: AdminEvalEvidenceKind.task,
    ),
  ];

  static Set<String> templateIdsForThemeId(String themeId) {
    if (themeId == themeAllId) return themeAll.templateIds;
    for (final th in formThemes) {
      if (th.id == themeId) return th.templateIds;
    }
    return AdminAuditComplianceConfig.allCeoEvaluationTemplateIds;
  }

  static List<AdminEvalTheme> get formThemeOptions => [themeAll, ...formThemes];

  static List<AdminEvalCriterion> formCriteriaForThemeId(String themeId) {
    if (themeId == themeAllId) {
      return formThemes.expand((th) => th.criteria).toList();
    }
    final th = formThemes.where((x) => x.id == themeId).toList();
    if (th.isEmpty) return [];
    return th.first.criteria;
  }

  /// Firestore / UI key for the Tasks tab section comment.
  static const String tasksEvalSectionId = 'tasks';

  /// Keys for [AdminAudit.adminEvalSectionComments]: each forms theme id (incl. [themeAllId]) + tasks.
  static List<String> get evalSectionCommentKeys => [
        ...formThemeOptions.map((t) => t.id),
        tasksEvalSectionId,
      ];
}
