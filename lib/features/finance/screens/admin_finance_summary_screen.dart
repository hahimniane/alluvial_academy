import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/timezone_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../models/finance_month_summary.dart';
import '../services/finance_summary_service.dart';

/// Read-only finance totals for the native admin app. Changes are made in
/// Finance on the web.
class AdminFinanceSummaryScreen extends StatefulWidget {
  const AdminFinanceSummaryScreen({
    super.key,
    this.service,
    this.now,
  });

  final FinanceSummaryService? service;

  /// The current time in the school's timezone. Defaults to New York.
  final DateTime Function()? now;

  @override
  State<AdminFinanceSummaryScreen> createState() =>
      _AdminFinanceSummaryScreenState();
}

class _AdminFinanceSummaryScreenState extends State<AdminFinanceSummaryScreen> {
  late final FinanceSummaryService _service;
  late final List<String> _months;
  late String _month;

  FinanceMonthSummary? _summary;
  bool _loading = true;
  bool _failed = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FinanceSummaryService();
    final now = widget.now?.call() ??
        TimezoneUtils.convertToTimezone(
            DateTime.now().toUtc(), 'America/New_York');
    _months = recentFinanceMonths(now);
    _month = _months.first;
    _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final summary = await _service.getMonthSummary(_month);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _selectMonth(String? month) {
    if (month == null || month == _month) return;
    _month = month;
    _load();
  }

  String _monthLabel(String month) {
    final parts = month.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.yMMMM(Localizations.localeOf(context).toString())
        .format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _buildMonthPicker(l10n),
        ),
        Expanded(child: _buildBody(l10n)),
      ],
    );
  }

  Widget _buildMonthPicker(AppLocalizations l10n) {
    return Row(
      children: [
        Text(
          l10n.financeSummaryMonth,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          key: const Key('finance_month_picker'),
          value: _month,
          onChanged: _selectMonth,
          items: [
            for (final month in _months)
              DropdownMenuItem(value: month, child: Text(_monthLabel(month))),
          ],
        ),
        const Spacer(),
        if (_summary?.isClosed == true && !_loading)
          Chip(
            label: Text(l10n.financeSummaryMonthClosed),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = _summary;
    if (_failed || summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.financeSummaryLoadError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('finance_summary_retry'),
                onPressed: _load,
                child: Text(l10n.tryAgain),
              ),
            ],
          ),
        ),
      );
    }

    final money = NumberFormat.simpleCurrency(
      locale: Localizations.localeOf(context).toString(),
      name: 'USD',
      decimalDigits: 0,
    );
    final cards = <_SummaryCard>[
      _SummaryCard(
        label: l10n.financeSummaryBilled,
        value: money.format(summary.billed),
        icon: Icons.receipt_long_rounded,
        color: const Color(0xff0386FF),
      ),
      _SummaryCard(
        label: l10n.financeSummaryCollected,
        value: money.format(summary.collected),
        icon: Icons.payments_rounded,
        color: const Color(0xff10B981),
      ),
      _SummaryCard(
        label: l10n.financeSummaryStillOwed,
        value: money.format(summary.owed),
        icon: Icons.hourglass_bottom_rounded,
        color: const Color(0xffF59E0B),
      ),
      _SummaryCard(
        label: l10n.financeSummaryExpenses,
        value: money.format(summary.expenses),
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xff8B5CF6),
      ),
      _SummaryCard(
        label: summary.isFinal
            ? l10n.financeSummaryProfit
            : l10n.financeSummaryProfitEstimate,
        value: money.format(summary.profit),
        icon: Icons.trending_up_rounded,
        color: summary.profit < 0
            ? const Color(0xffEF4444)
            : const Color(0xff059669),
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 12, runSpacing: 12, children: cards),
          const SizedBox(height: 20),
          _CountRow(
            label: l10n.financeSummaryUnpaidStaff,
            count: summary.unpaidStaff,
          ),
          _CountRow(
            label: l10n.financeSummaryOverdueInvoices,
            count: summary.overdueInvoices,
          ),
          _CountRow(
            label: l10n.financeSummaryRecurringToConfirm,
            count: summary.recurringToConfirm,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.financeSummaryOpenOnWeb,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(
            '$count',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
