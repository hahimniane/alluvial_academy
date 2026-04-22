/// Checkout-style line for the sticky enrollment summary.
class EnrollmentSummaryLine {
  const EnrollmentSummaryLine({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;
}

/// A grouped section for the review card (e.g. "Enrollment Details", "Schedule").
class EnrollmentReviewSection {
  const EnrollmentReviewSection({
    required this.sectionTitle,
    required this.icon,
    required this.editStepIndex,
    required this.rows,
  });

  final String sectionTitle;
  final String icon;
  final int editStepIndex;
  final List<(String label, String value)> rows;
}

/// Step indices for [ProgramSelectionPage] / [EnrollmentCoordinator]:
/// 0 role+accountLink, 1 students, 2 programs(pillTabs), 3 schedule(progressive), 4 review+contact.
const int kEnrollmentFlowStepCount = 5;

/// Step index where the primary action submits the form.
const int kEnrollmentFlowSubmitStepIndex = 4;
