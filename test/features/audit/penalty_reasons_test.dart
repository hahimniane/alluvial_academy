import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/core/constants/penalty_reasons.dart';
import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';
import 'package:alluwalacademyadmin/features/audit/widgets/payment_line_dialog.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations_en.dart';

Map<String, dynamic> _lineMap({Map<String, dynamic> extra = const {}}) => {
      'id': 'l1',
      'type': 'penalty',
      'amount': 10,
      'reason': 'Deducting 10 dollars for missing homework and 3 absences',
      'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
      'createdById': 'u1',
      'createdByName': 'Coach',
      ...extra,
    };

void main() {
  group('PenaltyReasons.validate', () {
    test('a reason is required', () {
      expect(PenaltyReasons.validate(null, ''),
          PenaltyReasonError.reasonMissing);
      expect(PenaltyReasons.validate('not_a_code', 'x'),
          PenaltyReasonError.reasonMissing);
    });

    test('Other needs a note, every other code does not', () {
      expect(PenaltyReasons.validate(PenaltyReasons.other, '  '),
          PenaltyReasonError.noteMissing);
      expect(PenaltyReasons.validate(PenaltyReasons.other, 'Left early'), isNull);
      for (final c in PenaltyReasons.codes.where((c) => c != 'other')) {
        expect(PenaltyReasons.validate(c, ''), isNull, reason: c);
      }
    });

    test('codes match the finance spec', () {
      expect(PenaltyReasons.codes, [
        'late_clock_in',
        'missed_class',
        'late_class_report',
        'left_class_early',
        'no_camera_or_setup',
        'conduct',
        'other',
      ]);
    });
  });

  group('reading old entries', () {
    test('a line with no code reads as other with its text as the note', () {
      final line = PaymentAdjustmentLine.fromMap(_lineMap());
      expect(line.penaltyReason, isNull);
      expect(line.penaltyValue.code, PenaltyReasons.other);
      expect(line.penaltyValue.note, contains('missing homework'));
    });

    test('a placeholder dash is not a note', () {
      final line = PaymentAdjustmentLine.fromMap(_lineMap(extra: {'reason': '—'}));
      expect(line.penaltyValue.code, PenaltyReasons.other);
      expect(line.penaltyValue.note, '');
    });

    test('an unknown stored code reads as other', () {
      final line = PaymentAdjustmentLine.fromMap(_lineMap(
          extra: {'penalty_reason': 'bogus', 'penalty_note': 'n'}));
      expect(line.penaltyValue.code, PenaltyReasons.other);
    });

    test('a coded line keeps its code and note and round-trips', () {
      final line = PaymentAdjustmentLine.fromMap(_lineMap(extra: {
        'penalty_reason': 'late_clock_in',
        'penalty_note': '17 times',
        'reason': 'Late clock-in — 17 times',
      }));
      expect(line.penaltyValue.code, 'late_clock_in');
      expect(line.penaltyValue.note, '17 times');
      final map = line.toMap();
      expect(map['penalty_reason'], 'late_clock_in');
      expect(map['penalty_note'], '17 times');
    });

    test('an uncoded line is written back without inventing a code', () {
      final map = PaymentAdjustmentLine.fromMap(_lineMap()).toMap();
      expect(map.containsKey('penalty_reason'), isFalse);
    });

    test('plain reason text keeps the English label for older readers', () {
      expect(PenaltyReasons.composeReasonText('conduct', ''), 'Conduct');
      expect(PenaltyReasons.composeReasonText('missed_class', 'twice'),
          'Missed a class without notice — twice');
    });

    test('display uses the viewer language label', () {
      final l10n = AppLocalizationsEn();
      expect(PenaltyReasons.display(l10n, 'late_class_report', 'June'),
          'Late class report: June');
      expect(PenaltyReasons.display(l10n, null, ''), 'Other');
    });
  });

  group('payment summary', () {
    PaymentSummary summary(Map<String, dynamic> extra) =>
        PaymentSummary.fromMap({
          'paymentsBySubject': <String, dynamic>{},
          'totalGrossPayment': 100,
          'totalPenalties': 0,
          'totalBonuses': 0,
          'totalNetPayment': 100,
          'adminAdjustment': 0,
          'adjustmentReason': '',
          'adminId': '',
          ...extra,
        });

    test('form penalty reason survives a rewrite', () {
      final ps = summary({
        'totalPenalties': 6,
        'formPenaltyPerMissing': 2,
        'formPenaltyTotal': 6,
        'formPenaltyReason': 'late_class_report',
        'formPenaltyNote': 'three missing',
      });
      final again = PaymentSummary.fromMap(ps.toMap());
      expect(again.formPenaltyValue?.code, 'late_class_report');
      expect(again.formPenaltyValue?.note, 'three missing');
      expect(again.formPenaltyTotal, 6);
    });

    test('a negative adjustment without a code reads as other', () {
      final ps = summary({'adminAdjustment': -3, 'adjustmentReason': 'rounding'});
      expect(ps.adjustmentDeductionValue?.code, PenaltyReasons.other);
      expect(ps.adjustmentDeductionValue?.note, 'rounding');
    });

    test('a positive adjustment has no deduction reason', () {
      expect(summary({'adminAdjustment': 3}).adjustmentDeductionValue, isNull);
    });

    test('no form penalty means no form penalty reason', () {
      expect(summary({}).formPenaltyValue, isNull);
    });

    test('adding reason fields does not change the net', () {
      final plain = summary({'totalNetPayment': 90});
      final coded = summary({
        'totalNetPayment': 90,
        'coachAdjustmentLines': [
          _lineMap(extra: {'penalty_reason': 'conduct', 'penalty_note': ''})
        ],
      });
      expect(coded.netWithCoachLines(), plain.netWithCoachLines() - 10);
    });
  });

  group('issues', () {
    test('system issue types map to codes', () {
      expect(PenaltyReasons.forIssueType('late_clock_ins'), 'late_clock_in');
      expect(PenaltyReasons.forIssueType('missed_classes'), 'missed_class');
      expect(PenaltyReasons.forIssueType('missing_forms'), 'late_class_report');
      expect(PenaltyReasons.forIssueType('unlinked_forms'), isNull);
    });

    test('an old issue reads its code from its type', () {
      final issue = AuditIssue.fromMap({
        'type': 'late_clock_ins',
        'description': '3 late',
        'severity': 'low',
      });
      expect(issue.penaltyReason, isNull);
      expect(issue.effectivePenaltyReason, 'late_clock_in');
    });
  });

  group('add payment line dialog', () {
    Future<PaymentLineInput?> openDialog(WidgetTester tester) async {
      PaymentLineInput? result;
      var done = false;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPaymentLineDialog(context);
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(done, isFalse);
      return result;
    }

    testWidgets('a penalty cannot be added without a reason', (tester) async {
      await openDialog(tester);
      await tester.enterText(find.byKey(const ValueKey('payment_line_amount')), '5');
      await tester.tap(find.byKey(const ValueKey('payment_line_ok')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a reason.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Other needs a note', (tester) async {
      await openDialog(tester);
      await tester.enterText(find.byKey(const ValueKey('payment_line_amount')), '5');
      await tester.tap(find.byKey(const ValueKey('penalty_reason_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      expect(find.text('Note (required)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('payment_line_ok')));
      await tester.pumpAndSettle();
      expect(find.text('Add a note when the reason is Other.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('a coded penalty is returned with plain reason text',
        (tester) async {
      PaymentLineInput? result;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showPaymentLineDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('payment_line_amount')), '7.5');
      await tester.tap(find.byKey(const ValueKey('penalty_reason_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Late clock-in').last);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('penalty_note_field')), 'five times');
      await tester.tap(find.byKey(const ValueKey('payment_line_ok')));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.type, 'penalty');
      expect(result!.amount, 7.5);
      expect(result!.penaltyReason, 'late_clock_in');
      expect(result!.penaltyNote, 'five times');
      expect(result!.reasonText, 'Late clock-in — five times');
    });

    testWidgets('a bonus keeps a free-text reason and no code', (tester) async {
      PaymentLineInput? result;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showPaymentLineDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Penalty (subtract)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bonus (add)').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('penalty_reason_dropdown')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('payment_line_amount')), '4');
      await tester.tap(find.byKey(const ValueKey('payment_line_ok')));
      await tester.pumpAndSettle();
      expect(result?.type, 'bonus');
      expect(result?.penaltyReason, isNull);
    });
  });
}
