import 'package:flutter_test/flutter_test.dart';

import 'package:alluwalacademyadmin/features/parent/models/admin_finance_overview.dart';
import 'package:alluwalacademyadmin/features/parent/services/admin_finance_overview_service.dart';

FinancePayrollEntry payroll({
  required String id,
  required String name,
  required double amount,
  required DateTime date,
  String status = 'approved',
}) =>
    FinancePayrollEntry(
      status: status,
      recipientId: id,
      recipientName: name,
      recipientEmail: '$id@test.io',
      paymentAmount: amount,
      activityDate: date,
    );

FinanceAuditPaymentEntry audit({
  required String id,
  required String name,
  required double amount,
  required DateTime date,
}) =>
    FinanceAuditPaymentEntry(
      recipientId: id,
      recipientName: name,
      recipientEmail: '$id@test.io',
      yearMonth:
          '${date.year}-${date.month.toString().padLeft(2, '0')}',
      grossPayment: amount,
      netPayment: amount,
      activityDate: date,
    );

void main() {
  final month = DateTime(2026, 7);

  group('staff pay trend (timesheet source of truth)', () {
    test('aggregates approved payroll per recipient per month', () {
      final snapshot = AdminFinanceOverviewService.buildSnapshot(
        month: month,
        invoices: const [],
        payments: const [],
        payrollEntries: [
          payroll(id: 't1', name: 'Mama Diallo', amount: 300, date: DateTime(2026, 6, 10)),
          payroll(id: 't1', name: 'Mama Diallo', amount: 200, date: DateTime(2026, 6, 20)),
          payroll(id: 't1', name: 'Mama Diallo', amount: 400, date: DateTime(2026, 7, 5)),
          payroll(id: 't2', name: 'Ahmed Bah', amount: 150, date: DateTime(2026, 7, 8)),
        ],
        now: DateTime(2026, 7, 15),
      );

      final t1 = snapshot.staffPayTrends
          .firstWhere((t) => t.recipientName == 'Mama Diallo');
      expect(t1.total, 900); // 300+200+400
      final june = t1.monthlyPay
          .firstWhere((p) => p.period.year == 2026 && p.period.month == 6);
      final july = t1.monthlyPay
          .firstWhere((p) => p.period.year == 2026 && p.period.month == 7);
      expect(june.amount, 500); // 300+200 same month
      expect(july.amount, 400);
      // Sorted by total desc: Mama (900) before Ahmed (150).
      expect(snapshot.staffPayTrends.first.recipientName, 'Mama Diallo');
    });

    test('does NOT double-count when a teacher has both timesheet and audit',
        () {
      final snapshot = AdminFinanceOverviewService.buildSnapshot(
        month: month,
        invoices: const [],
        payments: const [],
        payrollEntries: [
          payroll(id: 't1', name: 'Mama Diallo', amount: 500, date: DateTime(2026, 7, 5)),
        ],
        auditPayments: [
          audit(id: 't1', name: 'Mama Diallo', amount: 500, date: DateTime(2026, 7, 5)),
        ],
        now: DateTime(2026, 7, 15),
      );

      // Pay trend reflects timesheet only, not timesheet + audit.
      final t1 = snapshot.staffPayTrends
          .firstWhere((t) => t.recipientName == 'Mama Diallo');
      expect(t1.total, 500);

      // Recipient payouts total for this person is timesheet only.
      final payoutTotal = snapshot.recipientPayouts
          .where((p) => p.recipientName == 'Mama Diallo')
          .fold<double>(0, (s, p) => s + p.amount);
      expect(payoutTotal, 500);

      // Audit is still surfaced as a headline number, just not summed in.
      expect(snapshot.auditPayroll, 500);
      // P&L expense uses timesheet only.
      expect(snapshot.staffPayroll, 500);
    });

    test('ignores unapproved (pending) payroll in the trend', () {
      final snapshot = AdminFinanceOverviewService.buildSnapshot(
        month: month,
        invoices: const [],
        payments: const [],
        payrollEntries: [
          payroll(id: 't1', name: 'Mama Diallo', amount: 500, date: DateTime(2026, 7, 5), status: 'pending'),
        ],
        now: DateTime(2026, 7, 15),
      );
      expect(snapshot.staffPayTrends, isEmpty);
    });
  });

  group('weekly trend', () {
    test('produces 8 weeks with revenue and expenses bucketed by week', () {
      final snapshot = AdminFinanceOverviewService.buildSnapshot(
        month: month,
        invoices: const [],
        payments: const [],
        payrollEntries: [
          payroll(id: 't1', name: 'Mama Diallo', amount: 200, date: DateTime(2026, 7, 14)),
        ],
        now: DateTime(2026, 7, 15),
      );
      expect(snapshot.weeklyTrend.length, 8);
      final weekWithPay = snapshot.weeklyTrend.where((w) => w.expenses > 0);
      expect(weekWithPay.length, 1);
      expect(weekWithPay.first.expenses, 200);
    });
  });

  group('financial health', () {
    // Directly exercises the health getter across all four buckets.
    FinanceOverviewSnapshot snap({
      required double revenue,
      required double estimatedNet,
      required double profitMargin,
    }) =>
        FinanceOverviewSnapshot(
          month: month,
          revenue: revenue,
          previousRevenue: 0,
          invoiced: 0,
          outstanding: 0,
          overdueBalance: 0,
          overdueInvoiceCount: 0,
          dueSoonInvoiceCount: 0,
          failedInvoiceSendCount: 0,
          staffPayroll: 0,
          previousStaffPayroll: 0,
          manualExpenses: 0,
          previousManualExpenses: 0,
          pendingPayroll: 0,
          pendingPaymentCount: 0,
          failedPaymentCount: 0,
          knownExpenses: 0,
          previousKnownExpenses: 0,
          estimatedNet: estimatedNet,
          profitMargin: profitMargin,
          revenueGoal: 0,
          projectedRevenue: 0,
          goalProgress: 0,
          projectedGoalProgress: 0,
          revenueByMethod: const {},
          expensesByCategory: const {},
          monthlyTrend: const [],
          spendingCategoryTrends: const [],
          recipientPayouts: const [],
          auditPayroll: 0,
          overdueInvoices: const [],
          recentActivity: const [],
          warnings: const [],
        );

    test('no data when no revenue', () {
      expect(snap(revenue: 0, estimatedNet: 0, profitMargin: 0).health,
          FinanceHealth.noData);
    });
    test('needs attention when net is negative', () {
      expect(snap(revenue: 1000, estimatedNet: -50, profitMargin: -0.05).health,
          FinanceHealth.needsAttention);
    });
    test('healthy when margin >= 15%', () {
      expect(snap(revenue: 1000, estimatedNet: 200, profitMargin: 0.20).health,
          FinanceHealth.healthy);
    });
    test('watch when margin between 0 and 15%', () {
      expect(snap(revenue: 1000, estimatedNet: 80, profitMargin: 0.08).health,
          FinanceHealth.watch);
    });
  });
}
