import 'package:flutter/material.dart';
import 'enrollment/enrollment_coordinator.dart';

/// Thin wrapper so call sites keep importing [ProgramSelectionPage].
class ProgramSelectionPage extends StatelessWidget {
  final String? initialSubject;
  final bool isLanguageSelection;
  final String? initialAfricanLanguage;
  final String? initialPricingPlanId;
  final String? initialTrackId;
  final String? initialPricingPlanSummary;
  final int? initialHoursPerWeek;

  /// Pre-creates extra student slots (Parent/Guardian step shows 1 + this count).
  /// Use 1 to start with two learners without tapping + on step 1.
  final int initialAdditionalStudents;

  const ProgramSelectionPage({
    super.key,
    this.initialSubject,
    this.isLanguageSelection = false,
    this.initialAfricanLanguage,
    this.initialPricingPlanId,
    this.initialTrackId,
    this.initialPricingPlanSummary,
    this.initialHoursPerWeek,
    this.initialAdditionalStudents = 0,
  });

  @override
  Widget build(BuildContext context) {
    return EnrollmentCoordinator(
      initialSubject: initialSubject,
      isLanguageSelection: isLanguageSelection,
      initialAfricanLanguage: initialAfricanLanguage,
      initialPricingPlanId: initialPricingPlanId,
      initialTrackId: initialTrackId,
      initialPricingPlanSummary: initialPricingPlanSummary,
      initialHoursPerWeek: initialHoursPerWeek,
      initialAdditionalStudents: initialAdditionalStudents,
    );
  }
}
