/// The part of `getFinanceMonthSummary` the native admin summary shows.
class FinanceMonthSummary {
  final String month;
  final bool isClosed;
  final bool isFinal;
  final double billed;
  final double collected;
  final double owed;
  final double expenses;
  final double profit;
  final int unpaidStaff;
  final int overdueInvoices;
  final int recurringToConfirm;

  const FinanceMonthSummary({
    required this.month,
    required this.isClosed,
    required this.isFinal,
    required this.billed,
    required this.collected,
    required this.owed,
    required this.expenses,
    required this.profit,
    required this.unpaidStaff,
    required this.overdueInvoices,
    required this.recurringToConfirm,
  });

  factory FinanceMonthSummary.fromMap(Map<dynamic, dynamic> data) {
    return FinanceMonthSummary(
      month: data['month']?.toString() ?? '',
      isClosed: data['status'] == 'closed',
      isFinal: data['final'] == true,
      billed: _money(data['billed']),
      collected: _money(data['collected']),
      owed: _money(data['owed']),
      expenses: _money(data['expenses']),
      profit: _money(data['profit']),
      unpaidStaff: _count(data['unpaid_teachers']) + _count(data['unpaid_admins']),
      overdueInvoices: _count(data['overdue_invoices']),
      recurringToConfirm: _count(data['recurring_pending']),
    );
  }

  static double _money(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static int _count(Object? value) =>
      value is num ? value.round() : int.tryParse('$value') ?? 0;
}

/// The month keys (`yyyy-MM`) the summary offers: the month of [now] and the
/// five before it, newest first.
List<String> recentFinanceMonths(DateTime now, {int count = 6}) {
  return [
    for (var i = 0; i < count; i++)
      _monthKey(DateTime(now.year, now.month - i)),
  ];
}

String _monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
