import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/parent/models/admin_finance_overview.dart';
import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/services/admin_finance_overview_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class AdminFinanceOverviewScreen extends StatefulWidget {
  final VoidCallback onOpenCreateInvoice;
  final VoidCallback onOpenAllInvoices;

  const AdminFinanceOverviewScreen({
    super.key,
    required this.onOpenCreateInvoice,
    required this.onOpenAllInvoices,
  });

  @override
  State<AdminFinanceOverviewScreen> createState() =>
      _AdminFinanceOverviewScreenState();
}

class _AdminFinanceOverviewScreenState
    extends State<AdminFinanceOverviewScreen> {
  final AdminFinanceOverviewService _financeService =
      AdminFinanceOverviewService();
  late DateTime _month;
  late Future<FinanceOverviewSnapshot> _snapshotFuture;
  String? _selectedRecipientKey;
  _RecipientTrendPeriod _recipientTrendPeriod = _RecipientTrendPeriod.monthly;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _snapshotFuture = _financeService.loadSnapshot(_month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _snapshotFuture = _financeService.loadSnapshot(_month);
    });
  }

  Future<void> _refresh() async {
    setState(() => _snapshotFuture = _financeService.loadSnapshot(_month));
    await _snapshotFuture;
  }

  Future<void> _recordExpense() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _RecordExpenseDialog(),
    );
    if (saved == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _setRevenueGoal(FinanceOverviewSnapshot data) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RevenueGoalDialog(
        month: data.month,
        currentGoal: data.revenueGoal,
      ),
    );
    if (saved == true && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<FinanceOverviewSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: '${l10n.financeDataLoadError}: ${snapshot.error}',
              onRetry: _refresh,
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return _ErrorState(
              message: l10n.financeDataLoadError,
              onRetry: _refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                    child: _Header(
                  month: data.month,
                  onPrevious: () => _changeMonth(-1),
                  onNext: () => _changeMonth(1),
                  onCreateInvoice: widget.onOpenCreateInvoice,
                  onOpenInvoices: widget.onOpenAllInvoices,
                  onRecordExpense: _recordExpense,
                  onSetGoal: () => _setRevenueGoal(data),
                )),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  sliver: SliverToBoxAdapter(child: _MetricGrid(data: data)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(child: _FinanceCharts(data: data)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: _FinanceDeepDivePanel(
                      data: data,
                      selectedRecipientKey: _selectedRecipientKey,
                      period: _recipientTrendPeriod,
                      onRecipientChanged: (value) {
                        setState(() => _selectedRecipientKey = value);
                      },
                      onPeriodChanged: (value) {
                        setState(() => _recipientTrendPeriod = value);
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 980;
                        final left = Column(
                          children: [
                            _CashFlowPanel(data: data),
                            const SizedBox(height: 12),
                            _ExpenseCoveragePanel(data: data),
                          ],
                        );
                        final right = Column(
                          children: [
                            _AttentionPanel(data: data),
                            const SizedBox(height: 12),
                            _RecentActivityPanel(data: data),
                          ],
                        );
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 11, child: left),
                              const SizedBox(width: 12),
                              Expanded(flex: 9, child: right),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            left,
                            const SizedBox(height: 12),
                            right,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCreateInvoice;
  final VoidCallback onOpenInvoices;
  final VoidCallback onRecordExpense;
  final VoidCallback onSetGoal;

  const _Header({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onCreateInvoice,
    required this.onOpenInvoices,
    required this.onRecordExpense,
    required this.onSetGoal,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthLabel = DateFormat.yMMMM(locale).format(month);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border.all(color: const Color(0xFF1E293B)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF38BDF8),
                        Color(0xFF22C55E),
                        Color(0xFFF59E0B),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final titleBlock = ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.financeOverviewTitle,
                            style: GoogleFonts.inter(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.financeMonthLive(monthLabel),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    );

                    final controls = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.end,
                      children: [
                        _IconButton(
                          tooltip: l10n.financePreviousMonth,
                          icon: Icons.chevron_left_rounded,
                          onPressed: onPrevious,
                          dark: true,
                        ),
                        Container(
                          height: 36,
                          width: 142,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Text(
                            monthLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        _IconButton(
                          tooltip: l10n.financeNextMonth,
                          icon: Icons.chevron_right_rounded,
                          onPressed: onNext,
                          dark: true,
                        ),
                        _ActionButton(
                          icon: Icons.add_rounded,
                          label: l10n.financeOpenCreateInvoice,
                          onPressed: onCreateInvoice,
                          color: const Color(0xFF0284C7),
                        ),
                        _ActionButton(
                          icon: Icons.trending_up_rounded,
                          label: l10n.financeSetIncomeGoal,
                          onPressed: onSetGoal,
                          color: const Color(0xFF4F46E5),
                        ),
                        _ActionButton(
                          icon: Icons.add_card_rounded,
                          label: l10n.financeRecordExpense,
                          onPressed: onRecordExpense,
                          color: const Color(0xFFB45309),
                        ),
                        _ActionButton(
                          icon: Icons.receipt_long_rounded,
                          label: l10n.financeOpenAllInvoices,
                          onPressed: onOpenInvoices,
                          color: const Color(0xFF059669),
                        ),
                      ],
                    );

                    if (constraints.maxWidth < 820) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleBlock,
                          const SizedBox(height: 12),
                          controls,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 16),
                        controls,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final FinanceOverviewSnapshot data;

  const _MetricGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final metrics = [
      _Metric(
        label: l10n.financeRevenueCollected,
        value: _money(data.revenue),
        helper: data.revenueGoal > 0
            ? l10n.financeGoalProgress(
                NumberFormat.percentPattern()
                    .format(data.goalProgress.clamp(0, 9).toDouble()),
              )
            : _deltaLabel(context, data.revenue, data.previousRevenue),
        icon: Icons.payments_rounded,
        color: const Color(0xFF047857),
      ),
      _Metric(
        label: l10n.financeProjectedRevenue,
        value: _money(data.projectedRevenue),
        helper: l10n.financeMonthEndProjection,
        icon: Icons.insights_rounded,
        color: const Color(0xFF0F766E),
      ),
      _Metric(
        label: l10n.financeIncomeGoal,
        value: data.revenueGoal > 0
            ? _money(data.revenueGoal)
            : l10n.financeNoIncomeGoal,
        helper: data.revenueGoal > 0
            ? l10n.financeProjectedGoalProgress(
                NumberFormat.percentPattern()
                    .format(data.projectedGoalProgress.clamp(0, 9).toDouble()),
              )
            : l10n.financeSetIncomeGoal,
        icon: Icons.flag_rounded,
        color: const Color(0xFF4F46E5),
      ),
      _Metric(
        label: l10n.financeInvoiced,
        value: _money(data.invoiced),
        helper: l10n.financeCurrentMonth,
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF0369A1),
      ),
      _Metric(
        label: l10n.financeOutstanding,
        value: _money(data.outstanding),
        helper: '${data.overdueInvoiceCount} ${l10n.financeOverdueInvoices}',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFB45309),
      ),
      _Metric(
        label: l10n.financeKnownExpenses,
        value: _money(data.knownExpenses),
        helper: data.manualExpenses > 0
            ? l10n.financeIncludesRecordedExpenses
            : l10n.financeStaffPayrollOnly,
        icon: Icons.badge_rounded,
        color: const Color(0xFF7C3AED),
      ),
      _Metric(
        label: l10n.financeEstimatedNet,
        value: _money(data.estimatedNet),
        helper: l10n.financePartialLedger,
        icon: Icons.trending_up_rounded,
        color: data.estimatedNet >= 0
            ? const Color(0xFF0F766E)
            : const Color(0xFFDC2626),
      ),
      _Metric(
        label: l10n.financeProfitMargin,
        value: NumberFormat.percentPattern().format(data.profitMargin),
        helper: l10n.financeRevenueMinusKnownExpenses,
        icon: Icons.percent_rounded,
        color: const Color(0xFF4338CA),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 1120
            ? 4
            : width >= 880
                ? 3
                : width >= 560
                    ? 2
                    : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 92,
          ),
          itemBuilder: (context, index) => _MetricTile(metric: metrics[index]),
        );
      },
    );
  }

  String _deltaLabel(BuildContext context, double current, double previous) {
    final l10n = AppLocalizations.of(context)!;
    if (previous <= 0 && current <= 0) return l10n.financeNoPriorRevenue;
    if (previous <= 0) return l10n.financeNewRevenueThisMonth;
    final delta = (current - previous) / previous;
    final formatted = NumberFormat.percentPattern().format(delta.abs());
    return delta >= 0
        ? l10n.financeUpFromLastMonth(formatted)
        : l10n.financeDownFromLastMonth(formatted);
  }
}

class _CashFlowPanel extends StatelessWidget {
  final FinanceOverviewSnapshot data;

  const _CashFlowPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Panel(
      title: l10n.financeCashFlowTable,
      icon: Icons.table_chart_rounded,
      child: Column(
        children: [
          _DataRow(
            label: l10n.financeRevenue,
            current: _money(data.revenue),
            previous: _money(data.previousRevenue),
            change: _change(data.revenue, data.previousRevenue),
            tone: _RowTone.positive,
          ),
          _DataRow(
            label: l10n.financeExpenses,
            current: _money(data.knownExpenses),
            previous: _money(data.previousKnownExpenses),
            change: _change(data.knownExpenses, data.previousKnownExpenses),
            tone: _RowTone.warning,
          ),
          _DataRow(
            label: l10n.financeNet,
            current: _money(data.estimatedNet),
            previous: _money(data.previousRevenue - data.previousKnownExpenses),
            change: _change(
              data.estimatedNet,
              data.previousRevenue - data.previousKnownExpenses,
            ),
            tone: data.estimatedNet >= 0 ? _RowTone.positive : _RowTone.danger,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _FinanceCharts extends StatelessWidget {
  final FinanceOverviewSnapshot data;

  const _FinanceCharts({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 940;
        final trend = _TrendChartPanel(data: data);
        final methods = _RevenueMethodBarsPanel(data: data);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 13, child: trend),
              const SizedBox(width: 12),
              Expanded(flex: 7, child: methods),
            ],
          );
        }
        return Column(
          children: [
            trend,
            const SizedBox(height: 12),
            methods,
          ],
        );
      },
    );
  }
}

class _TrendChartPanel extends StatelessWidget {
  final FinanceOverviewSnapshot data;

  const _TrendChartPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hasData = data.monthlyTrend.any(
      (point) => point.revenue > 0 || point.expenses > 0,
    );

    return _Panel(
      title: l10n.financeSixMonthTrend,
      icon: Icons.show_chart_rounded,
      child: Column(
        children: [
          SizedBox(
            height: 124,
            child: hasData
                ? CustomPaint(
                    painter: _TrendChartPainter(
                      points: data.monthlyTrend,
                      revenueGoal: data.revenueGoal,
                      projectedRevenue: data.projectedRevenue,
                    ),
                    child: const SizedBox.expand(),
                  )
                : _EmptyInline(text: l10n.financeNoChartData),
          ),
          const SizedBox(height: 8),
          Row(
            children: data.monthlyTrend
                .map(
                  (point) => Expanded(
                    child: Text(
                      DateFormat.MMM(locale).format(point.month),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ChartLegend(
                color: const Color(0xFF047857),
                label: l10n.financeRevenue,
              ),
              const SizedBox(width: 14),
              _ChartLegend(
                color: const Color(0xFFB45309),
                label: l10n.financeExpenses,
              ),
              if (data.revenueGoal > 0) ...[
                const SizedBox(width: 14),
                _ChartLegend(
                  color: const Color(0xFF4F46E5),
                  label: l10n.financeIncomeGoal,
                ),
              ],
              const Spacer(),
              Text(
                '${l10n.financeNet}: ${_money(data.estimatedNet)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: data.estimatedNet >= 0
                      ? const Color(0xFF047857)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueMethodBarsPanel extends StatelessWidget {
  final FinanceOverviewSnapshot data;

  const _RevenueMethodBarsPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = data.revenueByMethod.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = rows.fold<double>(
      0,
      (maxValue, row) => math.max(maxValue, row.value),
    );

    return _Panel(
      title: l10n.financeRevenueByMethod,
      icon: Icons.bar_chart_rounded,
      child: rows.isEmpty
          ? SizedBox(
              height: 156,
              child: _EmptyInline(text: l10n.financeNoRevenueMethods),
            )
          : Column(
              children: rows
                  .take(5)
                  .map(
                    (entry) => _MethodBar(
                      label: entry.key == 'unknown'
                          ? l10n.financeUnknownMethod
                          : entry.key.toUpperCase(),
                      value: entry.value,
                      maxValue: maxValue,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _FinanceDeepDivePanel extends StatelessWidget {
  final FinanceOverviewSnapshot data;
  final String? selectedRecipientKey;
  final _RecipientTrendPeriod period;
  final ValueChanged<String?> onRecipientChanged;
  final ValueChanged<_RecipientTrendPeriod> onPeriodChanged;

  const _FinanceDeepDivePanel({
    required this.data,
    required this.selectedRecipientKey,
    required this.period,
    required this.onRecipientChanged,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Panel(
      title: l10n.financeSpendingInsightsTitle,
      icon: Icons.query_stats_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final categories = data.spendingCategoryTrends.take(6).toList();
          final recipients = _recipientAggregates(data.recipientPayouts);
          final resolvedRecipient = recipients.where(
            (item) => item.key == selectedRecipientKey,
          );
          final selectedRecipient = resolvedRecipient.isNotEmpty
              ? resolvedRecipient.first
              : recipients.isNotEmpty
                  ? recipients.first
                  : null;
          final left = _SpendingCategoriesDetail(categories: categories);
          final right = _RecipientPayoutDetail(
            payouts: data.recipientPayouts,
            recipients: recipients,
            selectedRecipient: selectedRecipient,
            period: period,
            onRecipientChanged: onRecipientChanged,
            onPeriodChanged: onPeriodChanged,
          );

          if (constraints.maxWidth >= 960) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: left),
                const SizedBox(width: 14),
                Expanded(flex: 9, child: right),
              ],
            );
          }
          return Column(
            children: [
              left,
              const SizedBox(height: 14),
              right,
            ],
          );
        },
      ),
    );
  }
}

class _SpendingCategoriesDetail extends StatelessWidget {
  final List<FinanceSpendingCategoryTrend> categories;

  const _SpendingCategoriesDetail({required this.categories});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (categories.isEmpty) {
      return _EmptyInline(text: l10n.financeNoSpendingTrend);
    }
    final maxValue = categories.fold<double>(
      0,
      (maxValue, trend) => math.max(maxValue, trend.total),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.financeWhereMoneyGoes,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        ...categories.map(
          (trend) => _SpendingTrendRow(
            trend: trend,
            maxValue: maxValue,
          ),
        ),
      ],
    );
  }
}

class _SpendingTrendRow extends StatelessWidget {
  final FinanceSpendingCategoryTrend trend;
  final double maxValue;

  const _SpendingTrendRow({
    required this.trend,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = _financeCategoryDisplayLabel(
      l10n,
      trend.categoryKey,
      trend.label,
    );
    final percent =
        maxValue <= 0 ? 0.0 : (trend.total / maxValue).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _money(trend.total),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percent.toDouble(),
                    minHeight: 9,
                    color: const Color(0xFFB45309),
                    backgroundColor: const Color(0xFFFFF7ED),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 128,
                height: 24,
                child: _MiniTrendBars(points: trend.points),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${l10n.financeCurrentMonthSpend}: ${_money(trend.currentMonthTotal)}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              Text(
                l10n.financeSixMonthSpend,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTrendBars extends StatelessWidget {
  final List<FinanceAmountPoint> points;

  const _MiniTrendBars({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(
      0,
      (maxValue, point) => math.max(maxValue, point.amount),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points
          .map(
            (point) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: FractionallySizedBox(
                  heightFactor: maxValue <= 0
                      ? 0.08
                      : (point.amount / maxValue).clamp(0.08, 1).toDouble(),
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RecipientPayoutDetail extends StatelessWidget {
  final List<FinanceRecipientPayout> payouts;
  final List<_RecipientAggregate> recipients;
  final _RecipientAggregate? selectedRecipient;
  final _RecipientTrendPeriod period;
  final ValueChanged<String?> onRecipientChanged;
  final ValueChanged<_RecipientTrendPeriod> onPeriodChanged;

  const _RecipientPayoutDetail({
    required this.payouts,
    required this.recipients,
    required this.selectedRecipient,
    required this.period,
    required this.onRecipientChanged,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (recipients.isEmpty || selectedRecipient == null) {
      return _EmptyInline(text: l10n.financeNoRecipientPayouts);
    }
    final selectedPayouts = payouts
        .where((payout) => payout.recipientKey == selectedRecipient!.key)
        .toList();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final periodTotals =
        _recipientPeriodTotals(selectedPayouts, period, locale);
    final sourceTotals = _recipientSourceTotals(selectedPayouts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.financeRecipientPayouts,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedRecipient!.key,
          decoration:
              _dialogInputDecoration(label: l10n.financeSelectRecipient),
          items: recipients
              .take(120)
              .map(
                (recipient) => DropdownMenuItem(
                  value: recipient.key,
                  child: Text(
                    recipient.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onRecipientChanged,
        ),
        const SizedBox(height: 10),
        SegmentedButton<_RecipientTrendPeriod>(
          segments: [
            ButtonSegment(
              value: _RecipientTrendPeriod.monthly,
              label: Text(l10n.financeMonthly),
              icon: const Icon(Icons.calendar_month_rounded, size: 16),
            ),
            ButtonSegment(
              value: _RecipientTrendPeriod.quarterly,
              label: Text(l10n.financeQuarterly),
              icon: const Icon(Icons.view_week_rounded, size: 16),
            ),
          ],
          selected: {period},
          onSelectionChanged: (values) => onPeriodChanged(values.first),
        ),
        const SizedBox(height: 10),
        if (periodTotals.isEmpty)
          _EmptyInline(text: l10n.financeNoRecipientPayouts)
        else
          ...periodTotals.take(8).map(
                (total) => _RecipientPeriodRow(
                  total: total,
                  maxValue: periodTotals.fold<double>(
                    0,
                    (maxValue, item) => math.max(maxValue, item.amount),
                  ),
                ),
              ),
        if (sourceTotals.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),
          ...sourceTotals.entries.map(
            (entry) => _LedgerLine(
              label: _recipientSourceLabel(l10n, entry.key),
              value: _money(entry.value),
              status: selectedRecipient!.displayName,
              color: const Color(0xFF4F46E5),
              compact: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _RecipientPeriodRow extends StatelessWidget {
  final _RecipientPeriodTotal total;
  final double maxValue;

  const _RecipientPeriodRow({
    required this.total,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final percent =
        maxValue <= 0 ? 0.0 : (total.amount / maxValue).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              total.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: percent.toDouble(),
                minHeight: 8,
                color: const Color(0xFF4F46E5),
                backgroundColor: const Color(0xFFEDE9FE),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: Text(
              _money(total.amount),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}

class _MethodBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;

  const _MethodBar({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final percent =
        maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _money(value),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              color: const Color(0xFF0284C7),
              backgroundColor: const Color(0xFFE0F2FE),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<FinanceMonthlyPoint> points;
  final double revenueGoal;
  final double projectedRevenue;

  const _TrendChartPainter({
    required this.points,
    required this.revenueGoal,
    required this.projectedRevenue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final maxValue = points.fold<double>(
        math.max(revenueGoal, projectedRevenue), (maxValue, point) {
      return math.max(maxValue, math.max(point.revenue, point.expenses));
    });
    if (maxValue <= 0) return;

    final plot = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    Path pathFor(double Function(FinanceMonthlyPoint point) valueOf) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = plot.left + plot.width * i / (points.length - 1);
        final y = plot.bottom - (valueOf(points[i]) / maxValue) * plot.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    void drawSeries({
      required Path path,
      required Color color,
      required bool fill,
    }) {
      if (fill) {
        final area = Path.from(path)
          ..lineTo(plot.right, plot.bottom)
          ..lineTo(plot.left, plot.bottom)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0.02),
              ],
            ).createShader(plot),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final revenuePath = pathFor((point) => point.revenue);
    final expensePath = pathFor((point) => point.expenses);
    if (revenueGoal > 0) {
      final goalY = plot.bottom - (revenueGoal / maxValue) * plot.height;
      canvas.drawLine(
        Offset(plot.left, goalY),
        Offset(plot.right, goalY),
        Paint()
          ..color = const Color(0xFF4F46E5).withValues(alpha: 0.7)
          ..strokeWidth = 1.5,
      );
    }
    drawSeries(path: revenuePath, color: const Color(0xFF047857), fill: true);
    drawSeries(path: expensePath, color: const Color(0xFFB45309), fill: false);

    for (var i = 0; i < points.length; i++) {
      final x = plot.left + plot.width * i / (points.length - 1);
      final revenueY =
          plot.bottom - (points[i].revenue / maxValue) * plot.height;
      final expenseY =
          plot.bottom - (points[i].expenses / maxValue) * plot.height;
      canvas.drawCircle(
        Offset(x, revenueY),
        3.2,
        Paint()..color = const Color(0xFF047857),
      );
      canvas.drawCircle(
        Offset(x, expenseY),
        3.2,
        Paint()..color = const Color(0xFFB45309),
      );
    }

    if (projectedRevenue > points.last.revenue) {
      final x = plot.right;
      final projectedY =
          plot.bottom - (projectedRevenue / maxValue) * plot.height;
      final actualY =
          plot.bottom - (points.last.revenue / maxValue) * plot.height;
      canvas.drawLine(
        Offset(x, actualY),
        Offset(x, projectedY),
        Paint()
          ..color = const Color(0xFF047857).withValues(alpha: 0.42)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(x, projectedY),
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, projectedY),
        4,
        Paint()..color = const Color(0xFF047857),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.revenueGoal != revenueGoal ||
        oldDelegate.projectedRevenue != projectedRevenue;
  }
}

class _ExpenseCoveragePanel extends StatelessWidget {
  final FinanceOverviewSnapshot data;

  const _ExpenseCoveragePanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final methodRows = data.revenueByMethod.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final expenseRows = data.expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Panel(
      title: l10n.financeExpenseCoverage,
      icon: Icons.account_tree_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LedgerLine(
            label: l10n.financeStaffPayroll,
            value: _money(data.staffPayroll),
            status: l10n.financeConnected,
            color: const Color(0xFF047857),
          ),
          _LedgerLine(
            label: l10n.financeSubscriptions,
            value: l10n.financeNotConnected,
            status: l10n.financeSubscriptionLedgerMissing,
            color: const Color(0xFFB45309),
          ),
          _LedgerLine(
            label: l10n.financeManualExpenses,
            value: _money(data.manualExpenses),
            status: data.manualExpenses > 0
                ? l10n.financeRecordedThisMonth
                : l10n.financeNoRecordedExpenses,
            color: data.manualExpenses > 0
                ? const Color(0xFF0F766E)
                : const Color(0xFFB45309),
            last: true,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.financeExpensesByCategory,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          if (expenseRows.isEmpty)
            _EmptyInline(text: l10n.financeNoRecordedExpenses)
          else
            ...expenseRows.take(4).map(
                  (entry) => _LedgerLine(
                    label: entry.key,
                    value: _money(entry.value),
                    status: l10n.financeCurrentMonth,
                    color: const Color(0xFFB45309),
                    compact: true,
                  ),
                ),
          const SizedBox(height: 12),
          Text(
            l10n.financeRevenueByMethod,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          if (methodRows.isEmpty)
            _EmptyInline(text: l10n.financeNoRevenueMethods)
          else
            ...methodRows.take(4).map(
                  (entry) => _LedgerLine(
                    label: entry.key == 'unknown'
                        ? l10n.financeUnknownMethod
                        : entry.key.toUpperCase(),
                    value: _money(entry.value),
                    status: l10n.financeCurrentMonth,
                    color: const Color(0xFF0369A1),
                    compact: true,
                  ),
                ),
        ],
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  final FinanceOverviewSnapshot data;

  const _AttentionPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <_AttentionItem>[
      if (data.overdueInvoiceCount > 0)
        _AttentionItem(
          title: l10n.financeOverdueInvoices,
          value: '${data.overdueInvoiceCount}',
          detail: _money(data.overdueBalance),
          color: const Color(0xFFDC2626),
        ),
      if (data.dueSoonInvoiceCount > 0)
        _AttentionItem(
          title: l10n.financeDueSoonInvoices,
          value: '${data.dueSoonInvoiceCount}',
          detail: l10n.financeDueSoon,
          color: const Color(0xFFB45309),
        ),
      if (data.pendingPaymentCount > 0)
        _AttentionItem(
          title: l10n.financePendingPayments,
          value: '${data.pendingPaymentCount}',
          detail: l10n.financeNeedsReview,
          color: const Color(0xFF0369A1),
        ),
      if (data.failedPaymentCount > 0)
        _AttentionItem(
          title: l10n.financeFailedPayments,
          value: '${data.failedPaymentCount}',
          detail: l10n.financeNeedsReview,
          color: const Color(0xFFDC2626),
        ),
      if (data.failedInvoiceSendCount > 0)
        _AttentionItem(
          title: l10n.financeFailedInvoiceSends,
          value: '${data.failedInvoiceSendCount}',
          detail: l10n.financeNeedsReview,
          color: const Color(0xFFDC2626),
        ),
      if (data.pendingPayroll > 0)
        _AttentionItem(
          title: l10n.financePendingPayroll,
          value: _money(data.pendingPayroll),
          detail: l10n.financeNeedsApproval,
          color: const Color(0xFF7C3AED),
        ),
      if (data.warnings.isNotEmpty)
        _AttentionItem(
          title: l10n.financeDataGaps,
          value: '${data.warnings.length}',
          detail: l10n.financeSomeSourcesUnavailable,
          color: const Color(0xFFB45309),
        ),
    ];

    return _Panel(
      title: l10n.financeAttentionQueue,
      icon: Icons.priority_high_rounded,
      child: items.isEmpty
          ? _EmptyInline(text: l10n.financeNoAttentionItems)
          : Column(
              children: [
                ...items.map((item) => _AttentionRow(item: item)),
                if (data.overdueInvoices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  ...data.overdueInvoices.map((invoice) => _OverdueInvoiceRow(
                        invoice: invoice,
                      )),
                ],
              ],
            ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  final FinanceOverviewSnapshot data;

  const _RecentActivityPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Panel(
      title: l10n.financeRecentActivity,
      icon: Icons.history_rounded,
      child: data.recentActivity.isEmpty
          ? _EmptyInline(text: l10n.financeNoRecentActivity)
          : Column(
              children: data.recentActivity
                  .map((activity) => _ActivityRow(activity: activity))
                  .toList(),
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(icon, size: 17, color: const Color(0xFF475569)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _Metric metric;

  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(metric.icon, size: 18, color: metric.color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    metric.helper,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String current;
  final String previous;
  final String change;
  final _RowTone tone;
  final bool last;

  const _DataRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.change,
    required this.tone,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = switch (tone) {
      _RowTone.positive => const Color(0xFF047857),
      _RowTone.warning => const Color(0xFFB45309),
      _RowTone.danger => const Color(0xFFDC2626),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          Expanded(child: _ColumnValue(l10n.financeCurrentMonth, current)),
          Expanded(child: _ColumnValue(l10n.financePreviousMonth, previous)),
          Expanded(
            child: Text(
              change,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnValue extends StatelessWidget {
  final String label;
  final String value;

  const _ColumnValue(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _LedgerLine extends StatelessWidget {
  final String label;
  final String value;
  final String status;
  final Color color;
  final bool compact;
  final bool last;

  const _LedgerLine({
    required this.label,
    required this.value,
    required this.status,
    required this.color,
    this.compact = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final _AttentionItem item;

  const _AttentionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: item.color,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  item.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueInvoiceRow extends StatelessWidget {
  final Invoice invoice;

  const _OverdueInvoiceRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              invoice.invoiceNumber.isNotEmpty
                  ? invoice.invoiceNumber
                  : invoice.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money(invoice.remainingBalance),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final FinanceActivity activity;

  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = activity.date == null
        ? ''
        : DateFormat.MMMd(locale).format(activity.date!);
    final icon = switch (activity.type) {
      FinanceActivityType.invoice => Icons.receipt_long_rounded,
      FinanceActivityType.completedPayment => Icons.check_circle_rounded,
      FinanceActivityType.pendingPayment => Icons.pending_rounded,
      FinanceActivityType.expense => Icons.add_card_rounded,
    };
    final label = switch (activity.type) {
      FinanceActivityType.invoice => l10n.financeInvoiceCreated,
      FinanceActivityType.completedPayment => l10n.financePaymentCompleted,
      FinanceActivityType.pendingPayment => l10n.financePaymentPending,
      FinanceActivityType.expense => l10n.financeExpenseRecorded,
    };
    final color = switch (activity.type) {
      FinanceActivityType.invoice => const Color(0xFF0369A1),
      FinanceActivityType.completedPayment => const Color(0xFF047857),
      FinanceActivityType.pendingPayment => const Color(0xFFB45309),
      FinanceActivityType.expense => const Color(0xFFB45309),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
                Text(
                  '${activity.title} ${activity.detail.isNotEmpty ? '- ${activity.detail}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(activity.amount),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                date,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool dark;

  const _IconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 36,
        height: 36,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: BorderSide(
              color: dark
                  ? Colors.white.withValues(alpha: 0.16)
                  : const Color(0xFFE2E8F0),
            ),
            backgroundColor: dark ? Colors.white.withValues(alpha: 0.06) : null,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Icon(
            icon,
            color: dark ? Colors.white : const Color(0xFF334155),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _RecordExpenseDialog extends StatefulWidget {
  const _RecordExpenseDialog();

  @override
  State<_RecordExpenseDialog> createState() => _RecordExpenseDialogState();
}

class _RecordExpenseDialogState extends State<_RecordExpenseDialog> {
  static const _customRecipient = '__custom_recipient__';

  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _otherCategoryController = TextEditingController();
  final _notesController = TextEditingController();
  late final Future<List<String>> _recipientOptionsFuture;
  DateTime _expenseDate = DateTime.now();
  String _category = 'teacher_payment';
  String? _selectedRecipient;
  String? _subcategory;
  String _paymentMethod = 'card';
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recipientOptionsFuture = _loadExpenseRecipients();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _vendorController.dispose();
    _otherCategoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = l10n.financeExpenseInvalidAmount);
      return;
    }
    final customCategory = _otherCategoryController.text.trim();
    if (_category == 'other' && customCategory.isEmpty) {
      setState(() => _error = l10n.financeExpenseOtherRequired);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final categoryLabel = _category == 'other'
          ? customCategory
          : _expenseCategoryLabel(l10n, _category);
      final subcategoryLabel = _subcategory == null
          ? ''
          : _expenseSubcategoryLabel(l10n, _subcategory!);
      await FirebaseFirestore.instance.collection('finance_expenses').add({
        'amount': amount,
        'currency': 'USD',
        'category': _category,
        'category_label': categoryLabel,
        if (_subcategory != null) 'subcategory': _subcategory,
        if (subcategoryLabel.isNotEmpty) 'subcategory_label': subcategoryLabel,
        'vendor': _vendorController.text.trim(),
        'payment_method': _paymentMethod,
        'notes': _notesController.text.trim(),
        'expense_date': Timestamp.fromDate(_expenseDate),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        if (uid != null) 'created_by': uid,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<List<String>> _loadExpenseRecipients() async {
    final snap =
        await FirebaseFirestore.instance.collection('users').limit(400).get();
    final recipients = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final roleText = [
        data['role'],
        data['user_type'],
        data['userType'],
        data['position'],
        data['title'],
      ].whereType<Object>().join(' ').toLowerCase();
      final looksLikeRecipient = [
        'teacher',
        'instructor',
        'staff',
        'employee',
        'admin',
        'leader',
        'leadership',
        'manager',
      ].any(roleText.contains);
      if (!looksLikeRecipient) continue;

      final name = (data['display_name'] ??
              data['displayName'] ??
              data['full_name'] ??
              data['fullName'] ??
              data['name'] ??
              '')
          .toString()
          .trim();
      final email = (data['email'] ?? '').toString().trim();
      final label = name.isNotEmpty && email.isNotEmpty
          ? '$name - $email'
          : name.isNotEmpty
              ? name
              : email;
      if (label.isNotEmpty) recipients.add(label);
    }
    final sorted = recipients.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Widget _recipientField(AppLocalizations l10n) {
    final label = _expenseRecipientLabel(l10n, _category);
    if (!_usesRecipientList(_category)) {
      return TextField(
        controller: _vendorController,
        decoration: _dialogInputDecoration(label: label),
      );
    }

    return FutureBuilder<List<String>>(
      future: _recipientOptionsFuture,
      builder: (context, snapshot) {
        final options = snapshot.data ?? const <String>[];
        if (options.isEmpty) {
          return TextField(
            controller: _vendorController,
            decoration: _dialogInputDecoration(label: label),
          );
        }

        final currentText = _vendorController.text.trim();
        final selectedValue = options.contains(_selectedRecipient)
            ? _selectedRecipient
            : currentText.isEmpty || options.contains(currentText)
                ? null
                : _customRecipient;
        final showManualField =
            selectedValue == _customRecipient || currentText.isEmpty;

        return Column(
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('recipient-$_category-${selectedValue ?? ''}'),
              initialValue: selectedValue,
              decoration: _dialogInputDecoration(label: label),
              items: [
                ...options.take(100).map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                DropdownMenuItem(
                  value: _customRecipient,
                  child: Text(l10n.adminInvoicePaymentMethodOther),
                ),
              ],
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() {
                        _selectedRecipient = value;
                        if (value != null && value != _customRecipient) {
                          _vendorController.text = value;
                        } else {
                          _vendorController.clear();
                        }
                      }),
            ),
            if (showManualField) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _vendorController,
                decoration: _dialogInputDecoration(
                  label: l10n.financeExpenseRecipientManual,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = _expenseCategories(l10n);
    final subcategories = _expenseSubcategories(l10n, _category);
    final methods = <DropdownMenuItem<String>>[
      DropdownMenuItem(
          value: 'card', child: Text(l10n.financeExpenseMethodCard)),
      DropdownMenuItem(
          value: 'bank_transfer',
          child: Text(l10n.adminInvoicePaymentMethodBankTransfer)),
      DropdownMenuItem(
          value: 'zelle', child: Text(l10n.adminInvoicePaymentMethodZelle)),
      DropdownMenuItem(
          value: 'cash', child: Text(l10n.adminInvoicePaymentMethodCash)),
      DropdownMenuItem(
          value: 'check', child: Text(l10n.adminInvoicePaymentMethodCheck)),
      DropdownMenuItem(
          value: 'other', child: Text(l10n.adminInvoicePaymentMethodOther)),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_card_rounded,
                        color: Color(0xFFB45309), size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.financeRecordExpense,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _dialogInputDecoration(
                  label: l10n.financeExpenseAmount,
                  prefixText: 'USD ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration:
                    _dialogInputDecoration(label: l10n.financeExpenseCategory),
                items: categories,
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() {
                          _category = value ?? _category;
                          _subcategory = null;
                          _selectedRecipient = null;
                        }),
              ),
              if (subcategories.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _subcategory,
                  decoration: _dialogInputDecoration(
                    label: l10n.financeExpenseSubcategory,
                  ),
                  items: subcategories,
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _subcategory = value),
                ),
              ],
              if (_category == 'other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otherCategoryController,
                  decoration: _dialogInputDecoration(
                    label: l10n.financeExpenseOtherCategory,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _recipientField(l10n),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration:
                    _dialogInputDecoration(label: l10n.financeExpenseMethod),
                items: methods,
                onChanged: _isSaving
                    ? null
                    : (value) => setState(
                        () => _paymentMethod = value ?? _paymentMethod),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _isSaving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _expenseDate,
                          firstDate: DateTime(2024),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _expenseDate = picked);
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration:
                      _dialogInputDecoration(label: l10n.financeExpenseDate),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded,
                          size: 17, color: Color(0xFFB45309)),
                      const SizedBox(width: 8),
                      Text(DateFormat.yMMMd().format(_expenseDate)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 3,
                decoration:
                    _dialogInputDecoration(label: l10n.financeExpenseNotes),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: Text(l10n.financeSaveExpense),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueGoalDialog extends StatefulWidget {
  final DateTime month;
  final double currentGoal;

  const _RevenueGoalDialog({
    required this.month,
    required this.currentGoal,
  });

  @override
  State<_RevenueGoalDialog> createState() => _RevenueGoalDialogState();
}

class _RevenueGoalDialogState extends State<_RevenueGoalDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentGoal > 0 ? widget.currentGoal.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount < 0) {
      setState(() => _error = l10n.financeGoalInvalidAmount);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final goalId =
          '${widget.month.year}-${widget.month.month.toString().padLeft(2, '0')}';
      await FirebaseFirestore.instance
          .collection('finance_goals')
          .doc(goalId)
          .set(
        {
          'revenue_goal': amount,
          'month': goalId,
          'updated_at': FieldValue.serverTimestamp(),
          if (uid != null) 'updated_by': uid,
        },
        SetOptions(merge: true),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.financeSetIncomeGoal,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat.yMMMM(locale).format(widget.month),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _dialogInputDecoration(
                  label: l10n.financeIncomeGoal,
                  prefixText: 'USD ',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.flag_rounded, size: 17),
                      label: Text(l10n.financeSaveGoal),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _dialogInputDecoration({
  required String label,
  String? prefixText,
}) {
  return InputDecoration(
    labelText: label,
    prefixText: prefixText,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
    ),
  );
}

List<DropdownMenuItem<String>> _expenseCategories(AppLocalizations l10n) {
  const values = [
    'teacher_payment',
    'leadership_cost',
    'marketing_cost',
    'r_and_d',
    'other',
  ];
  return values
      .map(
        (value) => DropdownMenuItem(
          value: value,
          child: Text(_expenseCategoryLabel(l10n, value)),
        ),
      )
      .toList();
}

String _expenseCategoryLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'teacher_payment' => l10n.financeExpenseCategoryTeacherPayment,
    'leadership_cost' => l10n.financeExpenseCategoryLeadershipCost,
    'marketing_cost' => l10n.financeExpenseCategoryMarketingCost,
    'r_and_d' => l10n.financeExpenseCategoryResearchDevelopment,
    _ => l10n.adminInvoicePaymentMethodOther,
  };
}

List<DropdownMenuItem<String>> _expenseSubcategories(
  AppLocalizations l10n,
  String category,
) {
  final values = switch (category) {
    'marketing_cost' => [
        'social_marketing',
        'newsletter_subscription',
        'paid_ads',
        'creative_tools',
      ],
    'r_and_d' => [
        'website_fees',
        'recurring_subscriptions',
        'software_tools',
        'research_tools',
      ],
    _ => const <String>[],
  };
  return values
      .map(
        (value) => DropdownMenuItem(
          value: value,
          child: Text(_expenseSubcategoryLabel(l10n, value)),
        ),
      )
      .toList();
}

String _expenseSubcategoryLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'social_marketing' => l10n.financeExpenseSubcategorySocialMarketing,
    'newsletter_subscription' =>
      l10n.financeExpenseSubcategoryNewsletterSubscription,
    'paid_ads' => l10n.financeExpenseSubcategoryPaidAds,
    'creative_tools' => l10n.financeExpenseSubcategoryCreativeTools,
    'website_fees' => l10n.financeExpenseSubcategoryWebsiteFees,
    'recurring_subscriptions' =>
      l10n.financeExpenseSubcategoryRecurringSubscriptions,
    'software_tools' => l10n.financeExpenseSubcategorySoftwareTools,
    'research_tools' => l10n.financeExpenseSubcategoryResearchTools,
    _ => '',
  };
}

String _expenseRecipientLabel(AppLocalizations l10n, String category) {
  return switch (category) {
    'teacher_payment' => l10n.financeExpenseTeacherRecipient,
    'leadership_cost' => l10n.financeExpenseLeadershipRecipient,
    _ => l10n.financeExpenseVendor,
  };
}

bool _usesRecipientList(String category) {
  return category == 'teacher_payment' || category == 'leadership_cost';
}

String _financeCategoryDisplayLabel(
  AppLocalizations l10n,
  String categoryKey,
  String fallback,
) {
  final key = categoryKey.trim();
  if (key == 'teacher_payment' ||
      key == 'leadership_cost' ||
      key == 'marketing_cost' ||
      key == 'r_and_d') {
    return _expenseCategoryLabel(l10n, key);
  }
  return fallback.trim().isEmpty ? key : fallback;
}

String _recipientSourceLabel(AppLocalizations l10n, String source) {
  return switch (source) {
    'audit' => l10n.financeAuditPayrollSource,
    'timesheet' => l10n.financeTimesheetPayrollSource,
    'expense' => l10n.financeRecordedExpenseSource,
    _ => source,
  };
}

List<_RecipientAggregate> _recipientAggregates(
  List<FinanceRecipientPayout> payouts,
) {
  final map = <String, _RecipientAggregate>{};
  for (final payout in payouts) {
    if (payout.amount <= 0 || payout.recipientKey == 'unknown') continue;
    final existing = map[payout.recipientKey];
    if (existing == null) {
      map[payout.recipientKey] = _RecipientAggregate(
        key: payout.recipientKey,
        displayName: payout.recipientName,
        total: payout.amount,
      );
    } else {
      existing.total += payout.amount;
    }
  }
  final recipients = map.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return recipients;
}

List<_RecipientPeriodTotal> _recipientPeriodTotals(
  List<FinanceRecipientPayout> payouts,
  _RecipientTrendPeriod period,
  String locale,
) {
  final totals = <String, _RecipientPeriodTotal>{};
  for (final payout in payouts) {
    final date = payout.date;
    if (date == null || payout.amount <= 0) continue;
    final periodStart = period == _RecipientTrendPeriod.monthly
        ? DateTime(date.year, date.month)
        : DateTime(date.year, ((date.month - 1) ~/ 3) * 3 + 1);
    final key = '${periodStart.year}-${periodStart.month}';
    final label = period == _RecipientTrendPeriod.monthly
        ? DateFormat.yMMM(locale).format(periodStart)
        : 'Q${((periodStart.month - 1) ~/ 3) + 1} ${periodStart.year}';
    final existing = totals[key];
    if (existing == null) {
      totals[key] = _RecipientPeriodTotal(
        period: periodStart,
        label: label,
        amount: payout.amount,
      );
    } else {
      existing.amount += payout.amount;
    }
  }
  final rows = totals.values.toList()
    ..sort((a, b) => b.period.compareTo(a.period));
  return rows;
}

Map<String, double> _recipientSourceTotals(
    List<FinanceRecipientPayout> payouts) {
  final totals = <String, double>{};
  for (final payout in payouts) {
    if (payout.amount <= 0) continue;
    totals[payout.source] = (totals[payout.source] ?? 0) + payout.amount;
  }
  return totals;
}

class _RecipientAggregate {
  final String key;
  final String displayName;
  double total;

  _RecipientAggregate({
    required this.key,
    required this.displayName,
    required this.total,
  });
}

class _RecipientPeriodTotal {
  final DateTime period;
  final String label;
  double amount;

  _RecipientPeriodTotal({
    required this.period,
    required this.label,
    required this.amount,
  });
}

class _EmptyInline extends StatelessWidget {
  final String text;

  const _EmptyInline({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFDC2626), size: 36),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.financeRefresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
  });
}

class _AttentionItem {
  final String title;
  final String value;
  final String detail;
  final Color color;

  const _AttentionItem({
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
  });
}

enum _RowTone { positive, warning, danger }

enum _RecipientTrendPeriod { monthly, quarterly }

String _money(double amount) {
  return NumberFormat.simpleCurrency(name: 'USD').format(amount);
}

String _change(double current, double previous) {
  if (previous == 0 && current == 0) return '0%';
  if (previous == 0) return '+100%';
  final delta = (current - previous) / previous;
  final sign = delta >= 0 ? '+' : '-';
  return '$sign${NumberFormat.percentPattern().format(delta.abs())}';
}
