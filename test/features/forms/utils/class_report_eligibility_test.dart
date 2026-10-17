import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/forms/utils/class_report_eligibility.dart';

void main() {
  final now = DateTime.utc(2026, 10, 16, 15);

  bool eligible(Duration startedAgo, String status,
      {Duration length = const Duration(hours: 1)}) {
    final start = now.subtract(startedAgo);
    return ClassReportEligibility.isEligible(
      start: start,
      end: start.add(length),
      status: status,
      now: now,
    );
  }

  test('an ended class is reportable whatever non-cancelled status it has',
      () {
    for (final status in [
      'scheduled',
      'active',
      'completed',
      'fullyCompleted',
      'partially_completed',
      'missed',
      '',
    ]) {
      expect(eligible(const Duration(hours: 3), status), isTrue,
          reason: status);
    }
  });

  test('cancelled, deleted and voided classes are refused', () {
    for (final status in ['cancelled', 'Canceled', 'deleted', 'void', 'voided']) {
      expect(ClassReportEligibility.isCancelledStatus(status), isTrue,
          reason: status);
      expect(eligible(const Duration(hours: 3), status), isFalse,
          reason: status);
    }
  });

  test('a class that has not ended is refused unless already closed', () {
    expect(eligible(const Duration(minutes: 30), 'active'), isFalse);
    expect(eligible(const Duration(minutes: 30), 'scheduled'), isFalse);
    expect(eligible(const Duration(minutes: 30), 'completed'), isTrue);
    expect(eligible(const Duration(hours: -2), 'completed'), isFalse);
  });

  test('the window is the last 60 days: 59 days in, 61 days out', () {
    expect(eligible(const Duration(days: 59), 'scheduled'), isTrue);
    expect(eligible(const Duration(days: 61), 'completed'), isFalse);
    expect(ClassReportEligibility.windowStart(now),
        DateTime.utc(2026, 8, 17, 15));
  });

  test('a class from last calendar month is still reportable', () {
    expect(
      ClassReportEligibility.isEligible(
        start: DateTime.utc(2026, 9, 29, 10),
        end: DateTime.utc(2026, 9, 29, 11),
        status: 'scheduled',
        now: DateTime.utc(2026, 10, 1, 10),
      ),
      isTrue,
    );
  });

  test('missing times are refused', () {
    expect(
      ClassReportEligibility.isEligible(
          start: null, end: now, status: 'completed', now: now),
      isFalse,
    );
  });
}
