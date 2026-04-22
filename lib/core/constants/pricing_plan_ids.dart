/// Stable IDs for pricing tiers (landing CTA, enrollment metadata, analytics).
abstract final class PricingPlanIds {
  /// V2 track IDs (subscription-style pricing).
  static const islamic = 'islamic';
  static const tutoring = 'tutoring';
  static const group = 'group';

  @Deprecated('Legacy pricing plan id. Use track IDs instead.')
  static const islamic14 = 'islamic_1_4';
  @Deprecated('Legacy pricing plan id. Use track IDs instead.')
  static const islamicWeekend = 'islamic_weekend';
  @Deprecated('Legacy pricing plan id. Use track IDs instead.')
  static const tutoring5Plus = 'tutoring_5_plus';
  @Deprecated('Legacy pricing plan id. Use track IDs instead.')
  static const tutoring13 = 'tutoring_1_3';
  @Deprecated('Legacy pricing plan id. Use track IDs instead.')
  static const tutoring4Plus = 'tutoring_4_plus';
}

/// Maps legacy pricing plan IDs to v2 track IDs.
String? legacyToTrack(String? legacyPlanId) {
  switch (legacyPlanId) {
    case PricingPlanIds.islamic14:
      return PricingPlanIds.islamic;
    case PricingPlanIds.islamicWeekend:
      return PricingPlanIds.group;
    case PricingPlanIds.tutoring13:
    case PricingPlanIds.tutoring4Plus:
    case PricingPlanIds.tutoring5Plus:
      return PricingPlanIds.tutoring;
    default:
      return null;
  }
}

/// Subject string must match [ProgramSelectionPage] internal options.
const String kAfterSchoolTutoringSubject =
    'After School Tutoring (Math, Science, Physics, etc...)';

/// Group / weekend pricing track — must match [ProgramSelectionPage] (not the same as one-on-one Islamic subject).
const String kGroupClassesSubject =
    'Group Classes (weekend / small group)';
