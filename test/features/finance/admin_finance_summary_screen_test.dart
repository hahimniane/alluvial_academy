import 'package:alluwalacademyadmin/features/finance/models/finance_month_summary.dart';
import 'package:alluwalacademyadmin/features/finance/screens/admin_finance_summary_screen.dart';
import 'package:alluwalacademyadmin/features/finance/services/finance_summary_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService extends FinanceSummaryService {
  _FakeService(this._handler);

  final Future<FinanceMonthSummary> Function(String month) _handler;
  final List<String> requested = [];

  @override
  Future<FinanceMonthSummary> getMonthSummary(String month) {
    requested.add(month);
    return _handler(month);
  }
}

FinanceMonthSummary _summary(
  String month, {
  bool isFinal = true,
  bool isClosed = false,
  double profit = 1250,
}) {
  return FinanceMonthSummary(
    month: month,
    isClosed: isClosed,
    isFinal: isFinal,
    billed: 9000,
    collected: 7500,
    owed: 1500,
    expenses: 4000,
    profit: profit,
    unpaidStaff: 3,
    overdueInvoices: 5,
    recurringToConfirm: 2,
  );
}

Widget _app(FinanceSummaryService service) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: AdminFinanceSummaryScreen(
        service: service,
        now: () => DateTime(2026, 10, 22),
      ),
    ),
  );
}

void main() {
  group('recentFinanceMonths', () {
    test('lists the current month and the five before it, newest first', () {
      expect(
        recentFinanceMonths(DateTime(2026, 2, 10)),
        ['2026-02', '2026-01', '2025-12', '2025-11', '2025-10', '2025-09'],
      );
    });
  });

  group('FinanceMonthSummary.fromMap', () {
    test('adds unpaid teachers and admins and tolerates missing fields', () {
      final summary = FinanceMonthSummary.fromMap({
        'month': '2026-09',
        'status': 'closed',
        'final': true,
        'billed': 100,
        'unpaid_teachers': 2,
        'unpaid_admins': 1,
        'recurring_pending': 4,
      });
      expect(summary.isClosed, isTrue);
      expect(summary.unpaidStaff, 3);
      expect(summary.recurringToConfirm, 4);
      expect(summary.overdueInvoices, 0);
      expect(summary.collected, 0);
    });
  });

  group('AdminFinanceSummaryScreen', () {
    testWidgets('shows the totals, counts and the web note', (tester) async {
      final service = _FakeService((m) async => _summary(m));
      await tester.pumpWidget(_app(service));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(service.requested, ['2026-10']);
      expect(find.text('Billed'), findsOneWidget);
      expect(find.text(r'$9,000'), findsOneWidget);
      expect(find.text('Collected'), findsOneWidget);
      expect(find.text(r'$7,500'), findsOneWidget);
      expect(find.text('Still owed'), findsOneWidget);
      expect(find.text(r'$1,500'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text(r'$4,000'), findsOneWidget);
      expect(find.text('Profit'), findsOneWidget);
      expect(find.text(r'$1,250'), findsOneWidget);
      expect(find.text('Staff still to pay'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Overdue invoices'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Recurring costs to confirm'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Open Finance on the web to make changes.'),
          findsOneWidget);
      expect(find.text('Profit (estimate)'), findsNothing);
      expect(find.text('Closed'), findsNothing);
    });

    testWidgets('labels profit as an estimate until the month is final',
        (tester) async {
      final service = _FakeService((m) async => _summary(m, isFinal: false));
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      expect(find.text('Profit (estimate)'), findsOneWidget);
      expect(find.text('Profit'), findsNothing);
    });

    testWidgets('marks a closed month', (tester) async {
      final service = _FakeService((m) async => _summary(m, isClosed: true));
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      expect(find.text('Closed'), findsOneWidget);
    });

    testWidgets('offers the current month and the five before it',
        (tester) async {
      final service = _FakeService((m) async => _summary(m));
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance_month_picker')));
      await tester.pumpAndSettle();

      for (final label in [
        'October 2026',
        'September 2026',
        'August 2026',
        'July 2026',
        'June 2026',
        'May 2026',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('April 2026'), findsNothing);
    });

    testWidgets('loads the month that is picked', (tester) async {
      final service = _FakeService((m) async => _summary(m));
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finance_month_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('August 2026').last);
      await tester.pumpAndSettle();

      expect(service.requested, ['2026-10', '2026-08']);
    });

    testWidgets('shows an error and retries', (tester) async {
      var calls = 0;
      final service = _FakeService((m) async {
        calls++;
        if (calls == 1) throw Exception('boom');
        return _summary(m);
      });
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      expect(find.text("Finance couldn't be loaded."), findsOneWidget);
      expect(find.text(r'$9,000'), findsNothing);

      await tester.tap(find.byKey(const Key('finance_summary_retry')));
      await tester.pumpAndSettle();

      expect(find.text("Finance couldn't be loaded."), findsNothing);
      expect(find.text(r'$9,000'), findsOneWidget);
    });
  });
}
