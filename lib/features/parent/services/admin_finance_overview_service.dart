import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/features/parent/models/admin_finance_overview.dart';
import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/models/payment.dart';

class AdminFinanceOverviewService {
  final FirebaseFirestore firestore;

  AdminFinanceOverviewService({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  Future<FinanceOverviewSnapshot> loadSnapshot(DateTime month) async {
    final warnings = <FinanceWarningSource>[];

    final invoices = <Invoice>[];
    try {
      final snap = await firestore
          .collection('invoices')
          .orderBy('created_at', descending: true)
          .limit(500)
          .get();
      for (final doc in snap.docs) {
        invoices.add(Invoice.fromFirestore(doc));
      }
    } catch (_) {
      warnings.add(FinanceWarningSource.invoices);
    }

    final payments = <Payment>[];
    try {
      final snap = await firestore
          .collection('payments')
          .orderBy('created_at', descending: true)
          .limit(500)
          .get();
      for (final doc in snap.docs) {
        payments.add(Payment.fromFirestore(doc));
      }
    } catch (_) {
      warnings.add(FinanceWarningSource.payments);
    }

    final payrollEntries = <FinancePayrollEntry>[];
    try {
      final snap =
          await firestore.collection('timesheet_entries').limit(900).get();
      for (final doc in snap.docs) {
        payrollEntries.add(FinancePayrollEntry.fromMap(doc.data()));
      }
    } catch (_) {
      warnings.add(FinanceWarningSource.payroll);
    }

    final expenses = <FinanceExpenseEntry>[];
    try {
      final snap = await firestore
          .collection('finance_expenses')
          .orderBy('expense_date', descending: true)
          .limit(500)
          .get();
      for (final doc in snap.docs) {
        expenses.add(FinanceExpenseEntry.fromMap(doc.data()));
      }
    } catch (_) {
      warnings.add(FinanceWarningSource.expenses);
    }

    final auditPayments = <FinanceAuditPaymentEntry>[];
    try {
      final snap =
          await firestore.collection('teacher_audits').limit(800).get();
      for (final doc in snap.docs) {
        final entry = FinanceAuditPaymentEntry.fromMap(doc.data());
        if ((entry.netPayment > 0 || entry.grossPayment > 0) &&
            entry.activityDate != null) {
          auditPayments.add(entry);
        }
      }
    } catch (_) {
      warnings.add(FinanceWarningSource.auditPayments);
    }

    var revenueGoal = 0.0;
    try {
      final goalDoc = await firestore
          .collection('finance_goals')
          .doc(_goalIdForMonth(month))
          .get();
      final goalData = goalDoc.data();
      revenueGoal =
          _toNumber(goalData?['revenue_goal'] ?? goalData?['revenueGoal']);
    } catch (_) {
      revenueGoal = 0.0;
    }

    return buildSnapshot(
      month: month,
      invoices: invoices,
      payments: payments,
      payrollEntries: payrollEntries,
      expenses: expenses,
      auditPayments: auditPayments,
      revenueGoal: revenueGoal,
      warnings: warnings,
    );
  }

  static FinanceOverviewSnapshot buildSnapshot({
    required DateTime month,
    required List<Invoice> invoices,
    required List<Payment> payments,
    required List<FinancePayrollEntry> payrollEntries,
    List<FinanceExpenseEntry> expenses = const [],
    List<FinanceAuditPaymentEntry> auditPayments = const [],
    double revenueGoal = 0,
    List<FinanceWarningSource> warnings = const [],
    DateTime? now,
  }) {
    final monthStart = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);
    final previousMonth = DateTime(month.year, month.month - 1);
    final today = now ?? DateTime.now();

    final monthInvoices = invoices.where((invoice) {
      return _isInMonth(_invoiceActivityDate(invoice), monthStart, nextMonth);
    }).toList();

    final completedPayments = payments
        .where((payment) => payment.status == PaymentStatus.completed)
        .toList();
    final monthPayments = completedPayments.where((payment) {
      return _isInMonth(_paymentActivityDate(payment), monthStart, nextMonth);
    }).toList();
    final previousPayments = completedPayments.where((payment) {
      return _isInMonth(
        _paymentActivityDate(payment),
        previousMonth,
        monthStart,
      );
    }).toList();

    final approvedPayroll =
        payrollEntries.where((entry) => entry.status == 'approved').toList();
    final monthPayroll = approvedPayroll.where((entry) {
      return _isInMonth(entry.activityDate, monthStart, nextMonth);
    }).toList();
    final previousPayroll = approvedPayroll.where((entry) {
      return _isInMonth(entry.activityDate, previousMonth, monthStart);
    }).toList();

    final monthExpenses = expenses.where((entry) {
      return _isInMonth(_expenseActivityDate(entry), monthStart, nextMonth);
    }).toList();
    final previousExpenses = expenses.where((entry) {
      return _isInMonth(
        _expenseActivityDate(entry),
        previousMonth,
        monthStart,
      );
    }).toList();
    final monthAuditPayments = auditPayments.where((entry) {
      return _isInMonth(entry.activityDate, monthStart, nextMonth);
    }).toList();

    final pendingPayroll = payrollEntries
        .where((entry) => entry.status == 'pending')
        .fold<double>(0, (total, entry) => total + entry.paymentAmount);

    final revenue = monthPayments.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );
    final previousRevenue = previousPayments.fold<double>(
      0,
      (total, payment) => total + payment.amount,
    );
    final invoiced = monthInvoices.fold<double>(
      0,
      (total, invoice) => total + invoice.totalAmount,
    );
    final staffPayroll = monthPayroll.fold<double>(
      0,
      (total, entry) => total + entry.paymentAmount,
    );
    final previousStaffPayroll = previousPayroll.fold<double>(
      0,
      (total, entry) => total + entry.paymentAmount,
    );
    final manualExpenses = monthExpenses.fold<double>(
      0,
      (total, entry) => total + entry.amount,
    );
    final previousManualExpenses = previousExpenses.fold<double>(
      0,
      (total, entry) => total + entry.amount,
    );
    final auditPayroll = monthAuditPayments.fold<double>(
      0,
      (total, entry) =>
          total +
          (entry.netPayment > 0 ? entry.netPayment : entry.grossPayment),
    );

    final activeInvoices = invoices
        .where((invoice) => invoice.status != InvoiceStatus.cancelled)
        .toList();
    final outstanding = activeInvoices.fold<double>(
      0,
      (total, invoice) => total + invoice.remainingBalance,
    );
    final overdueInvoices = activeInvoices
        .where((invoice) => invoice.isOverdue)
        .toList()
      ..sort((a, b) => b.remainingBalance.compareTo(a.remainingBalance));
    final overdueBalance = overdueInvoices.fold<double>(
      0,
      (total, invoice) => total + invoice.remainingBalance,
    );
    final dueSoonEnd = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 7));
    final dueSoonInvoices = activeInvoices.where((invoice) {
      return !invoice.isFullyPaid &&
          !invoice.isOverdue &&
          invoice.dueDate.isBefore(dueSoonEnd);
    }).length;
    final failedInvoiceSends = activeInvoices
        .where((invoice) =>
            (invoice.notificationStatus ?? '').toLowerCase() == 'failed')
        .length;

    final pendingPayments = payments
        .where((payment) =>
            payment.status == PaymentStatus.pending ||
            payment.status == PaymentStatus.processing)
        .length;
    final failedPayments = payments
        .where((payment) => payment.status == PaymentStatus.failed)
        .length;

    final revenueByMethod = <String, double>{};
    for (final payment in monthPayments) {
      final method = payment.paymentMethod.trim().isEmpty
          ? 'unknown'
          : payment.paymentMethod.trim();
      revenueByMethod[method] = (revenueByMethod[method] ?? 0) + payment.amount;
    }

    final expensesByCategory = <String, double>{};
    for (final expense in monthExpenses) {
      final label = expense.categoryLabel.isEmpty
          ? expense.category
          : expense.categoryLabel;
      expensesByCategory[label] =
          (expensesByCategory[label] ?? 0) + expense.amount;
    }

    final trendMonths = List<DateTime>.generate(
      6,
      (index) => DateTime(month.year, month.month - 5 + index),
    );
    final categoryTrends = _buildSpendingCategoryTrends(
      trendMonths: trendMonths,
      currentMonth: monthStart,
      expenses: expenses,
      approvedPayroll: approvedPayroll,
      auditPayments: auditPayments,
    );
    final recipientPayouts = _buildRecipientPayouts(
      expenses: expenses,
      approvedPayroll: approvedPayroll,
      auditPayments: auditPayments,
    );

    final monthlyTrend = List<FinanceMonthlyPoint>.generate(6, (index) {
      final trendMonth = trendMonths[index];
      final trendNextMonth = DateTime(trendMonth.year, trendMonth.month + 1);
      final trendRevenue = completedPayments
          .where((payment) => _isInMonth(
              _paymentActivityDate(payment), trendMonth, trendNextMonth))
          .fold<double>(0, (total, payment) => total + payment.amount);
      final trendExpenses = approvedPayroll
          .where((entry) =>
              _isInMonth(entry.activityDate, trendMonth, trendNextMonth))
          .fold<double>(0, (total, entry) => total + entry.paymentAmount);
      final trendManualExpenses = expenses
          .where((entry) => _isInMonth(
              _expenseActivityDate(entry), trendMonth, trendNextMonth))
          .fold<double>(0, (total, entry) => total + entry.amount);
      return FinanceMonthlyPoint(
        month: trendMonth,
        revenue: trendRevenue,
        expenses: trendExpenses + trendManualExpenses,
        net: trendRevenue - trendExpenses - trendManualExpenses,
      );
    });

    final recentActivity = <FinanceActivity>[
      ...invoices.take(8).map(
            (invoice) => FinanceActivity(
              date: _invoiceActivityDate(invoice),
              title: invoice.invoiceNumber.isNotEmpty
                  ? invoice.invoiceNumber
                  : invoice.id,
              detail: invoice.status.name,
              amount: invoice.totalAmount,
              type: FinanceActivityType.invoice,
            ),
          ),
      ...payments.take(8).map(
            (payment) => FinanceActivity(
              date: _paymentActivityDate(payment),
              title:
                  payment.invoiceId.isNotEmpty ? payment.invoiceId : payment.id,
              detail: payment.status.name,
              amount: payment.amount,
              type: payment.status == PaymentStatus.completed
                  ? FinanceActivityType.completedPayment
                  : FinanceActivityType.pendingPayment,
            ),
          ),
      ...expenses.take(8).map(
            (expense) => FinanceActivity(
              date: _expenseActivityDate(expense),
              title: expense.categoryLabel.isNotEmpty
                  ? expense.categoryLabel
                  : expense.category,
              detail: _expenseActivityDetail(expense),
              amount: expense.amount,
              type: FinanceActivityType.expense,
            ),
          ),
    ]..sort((a, b) {
        final ad = a.date;
        final bd = b.date;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

    // Phase 1: weekly revenue vs expenses for the 8 weeks ending in this month.
    // Expenses use the same approved-timesheet + manual sources as the P&L.
    final weekIsCurrentMonth =
        today.year == monthStart.year && today.month == monthStart.month;
    final weekAnchor = _startOfWeek(
      weekIsCurrentMonth
          ? today
          : DateTime(monthStart.year, monthStart.month + 1, 0),
    );
    final weeklyTrend = List<FinanceWeeklyPoint>.generate(8, (index) {
      final weekStart = weekAnchor.subtract(Duration(days: 7 * (7 - index)));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final weekRevenue = completedPayments
          .where((p) => _isInRange(_paymentActivityDate(p), weekStart, weekEnd))
          .fold<double>(0, (total, p) => total + p.amount);
      final weekPayroll = approvedPayroll
          .where((e) => _isInRange(e.activityDate, weekStart, weekEnd))
          .fold<double>(0, (total, e) => total + e.paymentAmount);
      final weekManual = expenses
          .where((e) => _isInRange(_expenseActivityDate(e), weekStart, weekEnd))
          .fold<double>(0, (total, e) => total + e.amount);
      return FinanceWeeklyPoint(
        weekStart: weekStart,
        revenue: weekRevenue,
        expenses: weekPayroll + weekManual,
      );
    });

    // Phase 1: per-staff-member pay trend over 12 months, from approved
    // timesheet payroll (P&L source of truth), so totals reconcile with net.
    final payTrendMonths = List<DateTime>.generate(
      12,
      (index) => DateTime(month.year, month.month - 11 + index),
    );
    final staffPayTrends = _buildStaffPayTrends(
      approvedPayroll: approvedPayroll,
      months: payTrendMonths,
    );

    final knownExpenses = staffPayroll + manualExpenses;
    final previousKnownExpenses = previousStaffPayroll + previousManualExpenses;
    final estimatedNet = revenue - knownExpenses;
    final profitMargin = revenue <= 0 ? 0.0 : estimatedNet / revenue;
    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final isCurrentMonth =
        today.year == monthStart.year && today.month == monthStart.month;
    final isPastMonth = monthStart.isBefore(DateTime(today.year, today.month));
    final elapsedDays = isCurrentMonth
        ? today.day.clamp(1, daysInMonth)
        : isPastMonth
            ? daysInMonth
            : 0;
    final projectedRevenue = elapsedDays <= 0
        ? 0.0
        : isPastMonth
            ? revenue
            : revenue / elapsedDays * daysInMonth;
    final goalProgress = revenueGoal <= 0 ? 0.0 : revenue / revenueGoal;
    final projectedGoalProgress =
        revenueGoal <= 0 ? 0.0 : projectedRevenue / revenueGoal;

    return FinanceOverviewSnapshot(
      month: monthStart,
      revenue: revenue,
      previousRevenue: previousRevenue,
      invoiced: invoiced,
      outstanding: outstanding,
      overdueBalance: overdueBalance,
      overdueInvoiceCount: overdueInvoices.length,
      dueSoonInvoiceCount: dueSoonInvoices,
      failedInvoiceSendCount: failedInvoiceSends,
      staffPayroll: staffPayroll,
      previousStaffPayroll: previousStaffPayroll,
      manualExpenses: manualExpenses,
      previousManualExpenses: previousManualExpenses,
      pendingPayroll: pendingPayroll,
      pendingPaymentCount: pendingPayments,
      failedPaymentCount: failedPayments,
      knownExpenses: knownExpenses,
      previousKnownExpenses: previousKnownExpenses,
      estimatedNet: estimatedNet,
      profitMargin: profitMargin,
      revenueGoal: revenueGoal,
      projectedRevenue: projectedRevenue,
      goalProgress: goalProgress,
      projectedGoalProgress: projectedGoalProgress,
      revenueByMethod: revenueByMethod,
      expensesByCategory: expensesByCategory,
      monthlyTrend: monthlyTrend,
      spendingCategoryTrends: categoryTrends,
      recipientPayouts: recipientPayouts,
      auditPayroll: auditPayroll,
      overdueInvoices: overdueInvoices.take(5).toList(),
      recentActivity: recentActivity.take(8).toList(),
      warnings: warnings,
      weeklyTrend: weeklyTrend,
      staffPayTrends: staffPayTrends,
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1)); // Monday
  }

  static bool _isInRange(DateTime? date, DateTime start, DateTime end) {
    if (date == null) return false;
    return !date.isBefore(start) && date.isBefore(end);
  }

  static List<FinanceStaffPayTrend> _buildStaffPayTrends({
    required List<FinancePayrollEntry> approvedPayroll,
    required List<DateTime> months,
  }) {
    // key -> (name, month-index -> total)
    final byRecipient = <String, _StaffPayAccumulator>{};
    for (final entry in approvedPayroll) {
      if (entry.paymentAmount <= 0 || entry.activityDate == null) continue;
      final key = _recipientKey(
        id: entry.recipientId,
        email: entry.recipientEmail,
        name: entry.recipientName,
      );
      if (key.isEmpty) continue;
      final acc = byRecipient.putIfAbsent(
        key,
        () => _StaffPayAccumulator(
          name: _recipientName(entry.recipientName, entry.recipientEmail),
          monthTotals: List<double>.filled(months.length, 0),
        ),
      );
      for (var i = 0; i < months.length; i++) {
        final start = months[i];
        final end = DateTime(start.year, start.month + 1);
        if (_isInMonth(entry.activityDate, start, end)) {
          acc.monthTotals[i] += entry.paymentAmount;
          break;
        }
      }
    }

    final trends = byRecipient.entries
        .map(
          (e) => FinanceStaffPayTrend(
            recipientKey: e.key,
            recipientName: e.value.name,
            monthlyPay: [
              for (var i = 0; i < months.length; i++)
                FinanceAmountPoint(
                  period: months[i],
                  amount: e.value.monthTotals[i],
                ),
            ],
          ),
        )
        .where((t) => t.total > 0)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return trends;
  }

  static DateTime? _invoiceActivityDate(Invoice invoice) {
    return invoice.createdAt ?? invoice.issuedDate;
  }

  static DateTime? _paymentActivityDate(Payment payment) {
    return payment.completedAt ?? payment.createdAt;
  }

  static DateTime? _expenseActivityDate(FinanceExpenseEntry expense) {
    return expense.expenseDate ?? expense.createdAt;
  }

  static String _expenseActivityDetail(FinanceExpenseEntry expense) {
    final parts = [
      expense.vendor,
      expense.subcategoryLabel.isNotEmpty
          ? expense.subcategoryLabel
          : expense.subcategory,
      expense.paymentMethod,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.join(' · ');
  }

  static List<FinanceSpendingCategoryTrend> _buildSpendingCategoryTrends({
    required List<DateTime> trendMonths,
    required DateTime currentMonth,
    required List<FinanceExpenseEntry> expenses,
    required List<FinancePayrollEntry> approvedPayroll,
    required List<FinanceAuditPaymentEntry> auditPayments,
  }) {
    final buckets = <String, _CategoryTrendAccumulator>{};

    void addSpend({
      required String categoryKey,
      required String label,
      required DateTime? date,
      required double amount,
    }) {
      if (date == null || amount <= 0) return;
      final period = _monthStart(date);
      if (!trendMonths.contains(period)) return;
      final key = categoryKey.trim().isEmpty ? label : categoryKey.trim();
      final bucket = buckets.putIfAbsent(
        key,
        () => _CategoryTrendAccumulator(
          categoryKey: key,
          label: label.trim().isEmpty ? key : label.trim(),
        ),
      );
      bucket.add(period, amount);
    }

    for (final expense in expenses) {
      addSpend(
        categoryKey: expense.category,
        label: expense.categoryLabel.isEmpty
            ? expense.category
            : expense.categoryLabel,
        date: _expenseActivityDate(expense),
        amount: expense.amount,
      );
    }

    for (final trendMonth in trendMonths) {
      final nextMonth = DateTime(trendMonth.year, trendMonth.month + 1);
      // Source of truth for staff pay is approved timesheet payroll (same as
      // the P&L). Audits are evaluations, not disbursements, so they are not
      // summed into money totals — this keeps every pay figure reconciled
      // with net profit.
      final payrollTotal = approvedPayroll
          .where(
              (entry) => _isInMonth(entry.activityDate, trendMonth, nextMonth))
          .fold<double>(0, (total, entry) => total + entry.paymentAmount);
      addSpend(
        categoryKey: 'teacher_payment',
        label: 'Teacher Payment',
        date: trendMonth,
        amount: payrollTotal,
      );
    }

    final trends = buckets.values
        .map((bucket) => bucket.build(
              trendMonths: trendMonths,
              currentMonth: currentMonth,
            ))
        .where((trend) => trend.total > 0)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return trends;
  }

  static List<FinanceRecipientPayout> _buildRecipientPayouts({
    required List<FinanceExpenseEntry> expenses,
    required List<FinancePayrollEntry> approvedPayroll,
    required List<FinanceAuditPaymentEntry> auditPayments,
  }) {
    final payouts = <FinanceRecipientPayout>[];

    // Recipient payouts reflect actual disbursements: approved timesheet
    // payroll + manually-recorded recipient expenses. Audit evaluations are
    // intentionally NOT included — summing them alongside timesheets
    // double-counted the same person's pay and overstated per-recipient
    // totals. Source of truth = timesheet, consistent with the P&L.
    for (final payroll in approvedPayroll) {
      if (payroll.paymentAmount <= 0) continue;
      payouts.add(
        FinanceRecipientPayout(
          recipientKey: _recipientKey(
            id: payroll.recipientId,
            email: payroll.recipientEmail,
            name: payroll.recipientName,
          ),
          recipientName:
              _recipientName(payroll.recipientName, payroll.recipientEmail),
          recipientEmail: payroll.recipientEmail,
          source: 'timesheet',
          amount: payroll.paymentAmount,
          date: payroll.activityDate,
        ),
      );
    }

    for (final expense in expenses) {
      final isRecipientExpense = expense.category == 'teacher_payment' ||
          expense.category == 'leadership_cost';
      if (!isRecipientExpense || expense.amount <= 0) continue;
      final recipientName = expense.vendor.trim();
      if (recipientName.isEmpty) continue;
      payouts.add(
        FinanceRecipientPayout(
          recipientKey: _recipientKey(name: recipientName),
          recipientName: recipientName,
          recipientEmail: '',
          source: 'expense',
          amount: expense.amount,
          date: _expenseActivityDate(expense),
        ),
      );
    }

    payouts.sort((a, b) {
      final ad = a.date;
      final bd = b.date;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return payouts;
  }

  static String _recipientKey({
    String id = '',
    String email = '',
    String name = '',
  }) {
    final normalizedId = id.trim();
    if (normalizedId.isNotEmpty) return 'id:${normalizedId.toLowerCase()}';
    final normalizedEmail = email.trim();
    if (normalizedEmail.isNotEmpty) {
      return 'email:${normalizedEmail.toLowerCase()}';
    }
    final normalizedName = name.trim();
    if (normalizedName.isNotEmpty) {
      return 'name:${normalizedName.toLowerCase()}';
    }
    return 'unknown';
  }

  static String _recipientName(String name, String email) {
    final normalizedName = name.trim();
    if (normalizedName.isNotEmpty) return normalizedName;
    final normalizedEmail = email.trim();
    if (normalizedEmail.isNotEmpty) return normalizedEmail;
    return 'Unknown recipient';
  }

  static DateTime _monthStart(DateTime value) {
    return DateTime(value.year, value.month);
  }

  static bool _isInMonth(DateTime? value, DateTime start, DateTime end) {
    if (value == null) return false;
    return !value.isBefore(start) && value.isBefore(end);
  }

  static String _goalIdForMonth(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  static double _toNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class _CategoryTrendAccumulator {
  final String categoryKey;
  final String label;
  final Map<DateTime, double> _amounts = {};

  _CategoryTrendAccumulator({
    required this.categoryKey,
    required this.label,
  });

  void add(DateTime period, double amount) {
    _amounts[period] = (_amounts[period] ?? 0) + amount;
  }

  FinanceSpendingCategoryTrend build({
    required List<DateTime> trendMonths,
    required DateTime currentMonth,
  }) {
    final points = trendMonths
        .map(
          (month) => FinanceAmountPoint(
            period: month,
            amount: _amounts[month] ?? 0,
          ),
        )
        .toList();
    final total = points.fold<double>(
        0, (runningTotal, point) => runningTotal + point.amount);
    return FinanceSpendingCategoryTrend(
      categoryKey: categoryKey,
      label: label,
      total: total,
      currentMonthTotal: _amounts[currentMonth] ?? 0,
      points: points,
    );
  }
}

class _StaffPayAccumulator {
  _StaffPayAccumulator({required this.name, required this.monthTotals});
  final String name;
  final List<double> monthTotals;
}
