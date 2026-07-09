import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';

class FinanceOverviewSnapshot {
  final DateTime month;
  final double revenue;
  final double previousRevenue;
  final double invoiced;
  final double outstanding;
  final double overdueBalance;
  final int overdueInvoiceCount;
  final int dueSoonInvoiceCount;
  final int failedInvoiceSendCount;
  final double staffPayroll;
  final double previousStaffPayroll;
  final double manualExpenses;
  final double previousManualExpenses;
  final double pendingPayroll;
  final int pendingPaymentCount;
  final int failedPaymentCount;
  final double knownExpenses;
  final double previousKnownExpenses;
  final double estimatedNet;
  final double profitMargin;
  final double revenueGoal;
  final double projectedRevenue;
  final double goalProgress;
  final double projectedGoalProgress;
  final Map<String, double> revenueByMethod;
  final Map<String, double> expensesByCategory;
  final List<FinanceMonthlyPoint> monthlyTrend;
  final List<FinanceSpendingCategoryTrend> spendingCategoryTrends;
  final List<FinanceRecipientPayout> recipientPayouts;
  final double auditPayroll;
  final List<Invoice> overdueInvoices;
  final List<FinanceActivity> recentActivity;
  final List<FinanceWarningSource> warnings;

  const FinanceOverviewSnapshot({
    required this.month,
    required this.revenue,
    required this.previousRevenue,
    required this.invoiced,
    required this.outstanding,
    required this.overdueBalance,
    required this.overdueInvoiceCount,
    required this.dueSoonInvoiceCount,
    required this.failedInvoiceSendCount,
    required this.staffPayroll,
    required this.previousStaffPayroll,
    required this.manualExpenses,
    required this.previousManualExpenses,
    required this.pendingPayroll,
    required this.pendingPaymentCount,
    required this.failedPaymentCount,
    required this.knownExpenses,
    required this.previousKnownExpenses,
    required this.estimatedNet,
    required this.profitMargin,
    required this.revenueGoal,
    required this.projectedRevenue,
    required this.goalProgress,
    required this.projectedGoalProgress,
    required this.revenueByMethod,
    required this.expensesByCategory,
    required this.monthlyTrend,
    required this.spendingCategoryTrends,
    required this.recipientPayouts,
    required this.auditPayroll,
    required this.overdueInvoices,
    required this.recentActivity,
    required this.warnings,
  });
}

class FinanceMonthlyPoint {
  final DateTime month;
  final double revenue;
  final double expenses;
  final double net;

  const FinanceMonthlyPoint({
    required this.month,
    required this.revenue,
    required this.expenses,
    required this.net,
  });
}

class FinanceAmountPoint {
  final DateTime period;
  final double amount;

  const FinanceAmountPoint({
    required this.period,
    required this.amount,
  });
}

class FinanceSpendingCategoryTrend {
  final String categoryKey;
  final String label;
  final double total;
  final double currentMonthTotal;
  final List<FinanceAmountPoint> points;

  const FinanceSpendingCategoryTrend({
    required this.categoryKey,
    required this.label,
    required this.total,
    required this.currentMonthTotal,
    required this.points,
  });
}

class FinanceRecipientPayout {
  final String recipientKey;
  final String recipientName;
  final String recipientEmail;
  final String source;
  final double amount;
  final DateTime? date;

  const FinanceRecipientPayout({
    required this.recipientKey,
    required this.recipientName,
    required this.recipientEmail,
    required this.source,
    required this.amount,
    required this.date,
  });
}

class FinancePayrollEntry {
  final String status;
  final String recipientId;
  final String recipientName;
  final String recipientEmail;
  final double paymentAmount;
  final DateTime? activityDate;

  const FinancePayrollEntry({
    required this.status,
    required this.recipientId,
    required this.recipientName,
    required this.recipientEmail,
    required this.paymentAmount,
    required this.activityDate,
  });

  factory FinancePayrollEntry.fromMap(Map<String, dynamic> data) {
    return FinancePayrollEntry(
      status: (data['status'] ?? '').toString().toLowerCase(),
      recipientId: (data['teacher_id'] ??
              data['teacherId'] ??
              data['employee_id'] ??
              data['employeeId'] ??
              data['user_id'] ??
              data['userId'] ??
              '')
          .toString()
          .trim(),
      recipientName: (data['teacher_name'] ??
              data['teacherName'] ??
              data['employee_name'] ??
              data['employeeName'] ??
              data['user_name'] ??
              data['userName'] ??
              '')
          .toString()
          .trim(),
      recipientEmail:
          (data['teacher_email'] ?? data['teacherEmail'] ?? data['email'] ?? '')
              .toString()
              .trim(),
      paymentAmount: _toDouble(data['payment_amount'] ?? data['total_pay']),
      activityDate: _toDate(data['approved_at']) ??
          _toDate(data['submitted_at']) ??
          _toDate(data['created_at']) ??
          _parseDateString(data['date']),
    );
  }
}

class FinanceAuditPaymentEntry {
  final String recipientId;
  final String recipientName;
  final String recipientEmail;
  final String yearMonth;
  final double grossPayment;
  final double netPayment;
  final DateTime? activityDate;

  const FinanceAuditPaymentEntry({
    required this.recipientId,
    required this.recipientName,
    required this.recipientEmail,
    required this.yearMonth,
    required this.grossPayment,
    required this.netPayment,
    required this.activityDate,
  });

  factory FinanceAuditPaymentEntry.fromMap(Map<String, dynamic> data) {
    final paymentSummary = data['paymentSummary'] is Map
        ? Map<String, dynamic>.from(data['paymentSummary'] as Map)
        : const <String, dynamic>{};
    final yearMonth = (data['yearMonth'] ?? '').toString().trim();
    return FinanceAuditPaymentEntry(
      recipientId: (data['oderId'] ?? data['userId'] ?? data['teacherId'] ?? '')
          .toString()
          .trim(),
      recipientName:
          (data['teacherName'] ?? data['teacher_name'] ?? '').toString().trim(),
      recipientEmail: (data['teacherEmail'] ?? data['teacher_email'] ?? '')
          .toString()
          .trim(),
      yearMonth: yearMonth,
      grossPayment: _toDouble(paymentSummary['totalGrossPayment']),
      netPayment: _toDouble(paymentSummary['totalNetPayment']),
      activityDate: _parseYearMonthStart(yearMonth) ??
          _toDate(data['lastUpdated']) ??
          _toDate(data['updated_at']),
    );
  }
}

class FinanceExpenseEntry {
  final String category;
  final String categoryLabel;
  final String subcategory;
  final String subcategoryLabel;
  final String vendor;
  final String paymentMethod;
  final String notes;
  final double amount;
  final DateTime? expenseDate;
  final DateTime? createdAt;

  const FinanceExpenseEntry({
    required this.category,
    required this.categoryLabel,
    required this.subcategory,
    required this.subcategoryLabel,
    required this.vendor,
    required this.paymentMethod,
    required this.notes,
    required this.amount,
    required this.expenseDate,
    required this.createdAt,
  });

  factory FinanceExpenseEntry.fromMap(Map<String, dynamic> data) {
    final category = (data['category'] ?? 'other').toString().trim();
    return FinanceExpenseEntry(
      category: category.isEmpty ? 'other' : category,
      categoryLabel:
          (data['category_label'] ?? data['categoryLabel'] ?? category)
              .toString()
              .trim(),
      subcategory:
          (data['subcategory'] ?? data['sub_category'] ?? '').toString().trim(),
      subcategoryLabel:
          (data['subcategory_label'] ?? data['subcategoryLabel'] ?? '')
              .toString()
              .trim(),
      vendor: (data['vendor'] ?? data['payee'] ?? '').toString().trim(),
      paymentMethod: (data['payment_method'] ?? data['paymentMethod'] ?? '')
          .toString()
          .trim(),
      notes: (data['notes'] ?? '').toString().trim(),
      amount: _toDouble(data['amount']),
      expenseDate: _toDate(data['expense_date'] ?? data['expenseDate']),
      createdAt: _toDate(data['created_at'] ?? data['createdAt']),
    );
  }
}

class FinanceActivity {
  final DateTime? date;
  final String title;
  final String detail;
  final double amount;
  final FinanceActivityType type;

  const FinanceActivity({
    required this.date,
    required this.title,
    required this.detail,
    required this.amount,
    required this.type,
  });
}

enum FinanceActivityType { invoice, completedPayment, pendingPayment, expense }

enum FinanceWarningSource {
  invoices,
  payments,
  payroll,
  expenses,
  auditPayments,
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime? _parseDateString(dynamic value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed != null) return parsed;
  for (final pattern in ['M/d/yyyy', 'MM/dd/yyyy', 'MMM d, yyyy']) {
    try {
      return DateFormat(pattern).parseStrict(raw);
    } catch (_) {
      continue;
    }
  }
  return null;
}

DateTime? _parseYearMonthStart(String value) {
  final parts = value.split('-');
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month);
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
