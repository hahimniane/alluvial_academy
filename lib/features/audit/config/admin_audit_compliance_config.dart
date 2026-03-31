// ignore_for_file: public_member_api_docs

/// Template IDs for Tier-1 recurring form compliance (see docs/admin_audit_discovery_mvp_spec.md).
/// Multiple Firestore templates may represent the same logical form (migrations / duplicates).
class AdminAuditComplianceConfig {
  AdminAuditComplianceConfig._();

  /// All known "Daily End of Shift form - CEO" template + legacy form IDs.
  static const Set<String> dailyEndOfShiftTemplateIds = {
    '4G0oKBSTA8l0780cQ2Vx',
    '85R0ZZdF4UWBEVkcSF2P',
    'GvJwLp8p8YaKNo0XexJT',
    'LyQtk2qVL6Uh9Rw70VIy',
    'lKymuqF9jDRRZMngFXyS',
    'r1jmV5rkGyqupyKNhEN7',
    'XxgGuLqV5XaqVDUE7KbY', // legacy `form` collection
  };

  static const String biweeklyCoacheesPerformanceId = '0Nsvp0FofwFKa67mNVBX';

  /// Weekly-style progress / finance / CEO reports (expected ≈ weeks overlapping month).
  static const Set<String> weeklyReportTemplateIds = {
    '0wxe4mCVTe3Y2ME67uEp', // X Progress Summary Report
    '3MB3jxkjcCdD11us9q4N', // Marketing Weekly Progress Summary
    'YVA3i7czCuQDTvWnS2uH', // Finance Weekly Update Form-Salimatu/CEO
    'yuOxAyXQDoTaigyHUqId', // CEO Weekly Progress Form
  };

  /// Expected biweekly coachees submissions per calendar month (MVP heuristic).
  static const int expectedBiweeklyCoacheesPerMonth = 2;

  /// Weight for form compliance in overall score (rest is task efficiency).
  static const double overallWeightForm = 0.55;
  static const double overallWeightTask = 0.45;

  // --- CEO evaluation allowlist (forms_ai_export / Firestore template ids) ---

  static const String zoomHostingCeoTemplateId = 'm7zKkQCcqKtbQZ0OCWpi';
  static const String excuseCeoTemplateId = '6YBwJQoLQ5tNU3RjDp7f';
  static const String factsFindingCeoTemplateId = '5aXUrmtZnRGC5lj0bx7a';
  static const String paymentAdvanceCeoTemplateId = 'ILMi0ShOhMvL6UUvXGLO';
  static const String groupBayanaAttendanceTemplateId = 'UsZpSINroY4iNpGJEDVC';
  static const String weeklyOverduesCeoTemplateId = 'S0UADgFYC5iyvTnRbogT';
  static const String studentsStatusCeoTemplateId = 'b8wEkVRhdI5TxkA7Tep9';

  /// Submissions shown in the admin audit "Context" tab (paycut / advance evidence).
  static const Set<String> contextPenaltyFormTemplateIds = {
    factsFindingCeoTemplateId,
    paymentAdvanceCeoTemplateId,
  };

  /// Union of CEO-facing templates used for evaluation drill-down (month filter).
  static Set<String> get allCeoEvaluationTemplateIds => {
        ...dailyEndOfShiftTemplateIds,
        zoomHostingCeoTemplateId,
        excuseCeoTemplateId,
        factsFindingCeoTemplateId,
        paymentAdvanceCeoTemplateId,
        groupBayanaAttendanceTemplateId,
        weeklyOverduesCeoTemplateId,
        studentsStatusCeoTemplateId,
        biweeklyCoacheesPerformanceId,
        ...weeklyReportTemplateIds,
      };
}
