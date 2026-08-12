import 'package:alluwalacademyadmin/features/forms/utils/form_review_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormReviewStatus', () {
    test('uses the neutral status when review status is missing', () {
      expect(FormReviewStatus.normalize(null), FormReviewStatus.notReviewed);
      expect(FormReviewStatus.normalize(''), FormReviewStatus.notReviewed);
    });

    test('normalizes supported leader review statuses', () {
      expect(FormReviewStatus.normalize(' Seen '), FormReviewStatus.seen);
      expect(
        FormReviewStatus.normalize('IN REVIEW'),
        FormReviewStatus.inReview,
      );
      expect(
        FormReviewStatus.normalize('accepted'),
        FormReviewStatus.accepted,
      );
      expect(
        FormReviewStatus.normalize('rejected'),
        FormReviewStatus.rejected,
      );
    });

    test('maps legacy neutral labels to the neutral status', () {
      expect(
        FormReviewStatus.normalize('not reviewed'),
        FormReviewStatus.notReviewed,
      );
      expect(
        FormReviewStatus.normalize('unreviewed'),
        FormReviewStatus.notReviewed,
      );
      expect(
        FormReviewStatus.normalize('neutral'),
        FormReviewStatus.notReviewed,
      );
    });
  });
}
