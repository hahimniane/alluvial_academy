import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/parent/models/student_discount.dart';

StudentDiscount? read(Map<String, dynamic> over) => StudentDiscount.read({
      'mode': 'fixed',
      'value': 10,
      'duration': 'ongoing',
      'startDate': DateTime.utc(2026, 1, 1),
      'reason': 'Sibling discount',
      ...over,
    });

void main() {
  final september = DateTime.utc(2026, 9, 1);

  group('reading a stored discount', () {
    test('a record saved before scope existed is per-student', () {
      expect(read({})!.scope, DiscountScope.student);
    });

    test('only "family" counts as a household discount', () {
      expect(read({'scope': 'everyone'})!.scope, DiscountScope.student);
      expect(read({'scope': 'family'})!.scope, DiscountScope.family);
    });

    test('a record with no usable amount is not a discount', () {
      expect(read({'value': 0}), isNull);
      expect(read({'value': -5}), isNull);
      expect(read({'mode': 'percent', 'value': 120}), isNull);
      expect(StudentDiscount.read(null), isNull);
    });

    test('a fixed-length discount needs a month count', () {
      expect(read({'duration': 'months'}), isNull);
      expect(read({'duration': 'months', 'months': 3})!.months, 3);
    });
  });

  group('the window is month-granular', () {
    test('a discount starting mid-month still covers that month', () {
      final d = read({'duration': 'months', 'months': 3, 'startDate': DateTime.utc(2026, 9, 15)})!;
      expect(d.coversPeriod(september), isTrue);
    });

    test('it stops after its months, and never applies before it starts', () {
      final d = read({'duration': 'months', 'months': 3, 'startDate': DateTime.utc(2026, 9, 15)})!;
      expect(d.coversPeriod(DateTime.utc(2026, 11, 1)), isTrue);
      expect(d.coversPeriod(DateTime.utc(2026, 12, 1)), isFalse);
      expect(d.coversPeriod(DateTime.utc(2026, 8, 1)), isFalse);
    });
  });

  group('what comes off', () {
    test('a fixed discount never exceeds the total', () {
      expect(read({'value': 10})!.amountFor(100), 10);
      expect(read({'value': 150})!.amountFor(100), 100);
    });

    test('a percentage is computed in whole cents', () {
      expect(read({'mode': 'percent', 'value': 12.5})!.amountFor(99.99), 12.5);
    });

    test('nothing billable takes nothing off', () {
      expect(read({})!.amountFor(0), 0);
    });
  });

  group('the invoice preview', () {
    ({String name, double amount, StudentDiscount? discount}) charge(
            String name, double amount, StudentDiscount? discount) =>
        (name: name, amount: amount, discount: discount);

    test('\$10 off each child takes \$20 off two siblings', () {
      final preview = previewInvoice(
        charges: [charge('Amina', 100, read({})), charge('Yusuf', 100, read({}))],
        familyDiscount: null,
        periodStart: september,
      );
      expect(preview.subtotal, 200);
      expect(preview.lines.length, 2);
      expect(preview.total, 180);
    });

    test('\$10 off for the family takes \$10 off the same two siblings, once', () {
      final preview = previewInvoice(
        charges: [charge('Amina', 100, null), charge('Yusuf', 100, null)],
        familyDiscount: read({'scope': 'family'}),
        periodStart: september,
      );
      expect(preview.lines.single.label, contains('Whole family'));
      expect(preview.total, 190);
    });

    test('a family percentage is taken after the per-student lines', () {
      final preview = previewInvoice(
        charges: [charge('Amina', 100, read({})), charge('Yusuf', 100, null)],
        familyDiscount: read({'scope': 'family', 'mode': 'percent', 'value': 50}),
        periodStart: september,
      );
      expect(preview.total, 95);
      expect(preview.lines.last.label, contains('Whole family'));
    });

    test('the two together never take an invoice below zero', () {
      final preview = previewInvoice(
        charges: [charge('Amina', 20, read({'value': 15}))],
        familyDiscount: read({'scope': 'family', 'value': 50}),
        periodStart: september,
      );
      expect(preview.total, 0);
    });

    test('a family-scoped discount on a child is not applied per child', () {
      final preview = previewInvoice(
        charges: [charge('Amina', 100, read({'scope': 'family'}))],
        familyDiscount: null,
        periodStart: september,
      );
      expect(preview.lines, isEmpty);
      expect(preview.total, 100);
    });

    test('a discount outside its window adds no line', () {
      final preview = previewInvoice(
        charges: [charge('Amina', 100, read({'duration': 'months', 'months': 1, 'startDate': DateTime.utc(2026, 6, 1)}))],
        familyDiscount: null,
        periodStart: september,
      );
      expect(preview.total, 100);
    });
  });
}
