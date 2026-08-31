class FormReviewStatus {
  FormReviewStatus._();

  static const String notReviewed = '';
  static const String seen = 'seen';
  static const String inReview = 'in review';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';

  static const List<String> options = [
    notReviewed,
    seen,
    inReview,
    accepted,
    rejected,
  ];

  static String normalize(Object? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'not reviewed' ||
        normalized == 'unreviewed' ||
        normalized == 'neutral') {
      return notReviewed;
    }
    return options.contains(normalized) ? normalized : notReviewed;
  }
}
