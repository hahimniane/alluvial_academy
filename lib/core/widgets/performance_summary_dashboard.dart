import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/performance_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PerformanceSummaryDashboard extends StatelessWidget {
  final String title;

  const PerformanceSummaryDashboard({
    super.key,
    this.title = 'Performance Summary',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<int>(
          valueListenable: PerformanceLogger.logRevision,
          builder: (context, _, __) {
            final ops = _buildOperations(PerformanceLogger.entries);
            final ended = ops.where((o) => o.end != null).toList()
              ..sort((a, b) => b.end!.timestamp.compareTo(a.end!.timestamp));

            final slowest = ended.isEmpty
                ? null
                : (ended.toList()
                      ..sort(
                          (a, b) => b.end!.duration.compareTo(a.end!.duration)))
                    .first;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, ended.length),
                const SizedBox(height: 12),
                _buildKeyCards(context, ended),
                const SizedBox(height: 12),
                _buildSlowest(context, slowest),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int endedOps) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                endedOps == 0
                    ? 'No results yet. Use Shift Management, Timesheets, or Forms, then come back here.'
                    : 'Only highlights the latest results for key features.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context)!.clearPerformanceLogs,
          onPressed: PerformanceLogger.clearLogs,
          icon: const Icon(Icons.delete_outline),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context)!.copySummary,
          onPressed:
              endedOps == 0 ? null : () => _copySummaryToClipboard(context),
          icon: const Icon(Icons.copy),
        ),
      ],
    );
  }

  Widget _buildKeyCards(BuildContext context, List<_PerfOperationView> ended) {
    final shiftLoad =
        _latestByBase(ended, 'ShiftManagementScreen._loadShiftData');
    final payments = _latestByBase(
        ended, 'ShiftTimesheetService.getActualPaymentsForShifts');
    final timesheetsInitial =
        _latestByBase(ended, 'AdminTimesheetReview._initialLoad');
    final forms =
        _latestByBase(ended, 'FormResponsesScreen._loadFormResponses');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 680;
        final children = <Widget>[
          _InsightCard(
            title: AppLocalizations.of(context)!.navShifts,
            subtitle: AppLocalizations.of(context)!.timeUntilShiftsDisplay,
            icon: Icons.calendar_month,
            content: _shiftInsight(shiftLoad),
          ),
          _InsightCard(
            title: AppLocalizations.of(context)!.payments,
            subtitle: AppLocalizations.of(context)!.actualPaymentsBackgroundLoad,
            icon: Icons.payments_outlined,
            content: _paymentsInsight(payments),
          ),
          _InsightCard(
            title: AppLocalizations.of(context)!.timesheets,
            subtitle: AppLocalizations.of(context)!.timeUntilTimesheetsDisplay,
            icon: Icons.receipt_long,
            content: _timesheetsInsight(timesheetsInitial),
          ),
          _InsightCard(
            title: AppLocalizations.of(context)!.navForms,
            subtitle: AppLocalizations.of(context)!.formListResponseCounts,
            icon: Icons.assignment_outlined,
            content: _formsInsight(forms),
          ),
        ];

        if (isNarrow) {
          return Column(
            children:
                children.expand((w) => [w, const SizedBox(height: 10)]).toList()
                  ..removeLast(),
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((w) =>
                  SizedBox(width: (constraints.maxWidth - 10) / 2, child: w))
              .toList(),
        );
      },
    );
  }

  Widget _shiftInsight(_PerfOperationView? op) {
    if (op?.end == null) return _noData();

    final shiftCount = _int(op!.end!.metadata['shift_count']);
    final shiftsReceived = op.checkpoints
        .firstWhere(
          (c) => c.checkpointName == 'shifts_received',
          orElse: () => op.end!,
        )
        .duration;

    return _kvLines(
      {
        'First shifts ready': _formatDuration(shiftsReceived),
        'Total load': _formatDuration(op.end!.duration),
        if (shiftCount != null) 'Shift count': shiftCount.toString(),
      },
    );
  }

  Widget _paymentsInsight(_PerfOperationView? op) {
    if (op?.end == null) return _noData();

    final meta = op!.end!.metadata;
    final totalQueryMs = _int(meta['total_query_time_ms']);
    final totalCalcMs = _int(meta['total_calc_time_ms']);
    final batches = _int(meta['batches']);
    final shiftCount = _int(meta['shift_count']);
    final nonZero = _int(meta['non_zero_payments']);

    return _kvLines(
      {
        'Total': _formatDuration(op.end!.duration),
        if (totalQueryMs != null) 'DB query time': _formatMs(totalQueryMs),
        if (totalCalcMs != null) 'Processing time': _formatMs(totalCalcMs),
        if (batches != null) 'Batches': batches.toString(),
        if (shiftCount != null) 'Shift IDs': shiftCount.toString(),
        if (nonZero != null) 'Shifts w/ actual payments': nonZero.toString(),
      },
    );
  }

  Widget _timesheetsInsight(_PerfOperationView? op) {
    if (op?.end == null) return _noData();

    final docCount = _int(op!.end!.metadata['doc_count']);
    final built = _int(op.end!.metadata['entries_built']);
    final userFetchMs = _int(op.end!.metadata['user_fetch_time_ms']);
    final shiftFetchMs = _int(op.end!.metadata['shift_fetch_time_ms']);

    return _kvLines(
      {
        'First load': _formatDuration(op.end!.duration),
        if (docCount != null) 'Docs': docCount.toString(),
        if (built != null) 'Entries': built.toString(),
        if (userFetchMs != null) 'User lookups': _formatMs(userFetchMs),
        if (shiftFetchMs != null) 'Shift lookups': _formatMs(shiftFetchMs),
      },
    );
  }

  Widget _formsInsight(_PerfOperationView? op) {
    if (op?.end == null) return _noData();

    final endMeta = op!.end!.metadata;
    final templateCount = _int(endMeta['template_count']);
    final responseCount = _int(endMeta['response_count']);

    final templateCheckpoint = _checkpoint(op, 'templates_loaded');
    final responsesCheckpoint = _checkpoint(op, 'responses_loaded');
    final userNamesCheckpoint = _checkpoint(op, 'user_names_loaded');

    final templateQueryMs = _int(templateCheckpoint?.metadata['query_time_ms']);
    final responsesQueryMs =
        _int(responsesCheckpoint?.metadata['query_time_ms']);
    final userQueryMs = _int(userNamesCheckpoint?.metadata['query_time_ms']);

    return _kvLines(
      {
        'Total': _formatDuration(op.end!.duration),
        if (templateQueryMs != null)
          'Templates query': _formatMs(templateQueryMs),
        if (responsesQueryMs != null)
          'Responses query': _formatMs(responsesQueryMs),
        if (userQueryMs != null) 'User lookups': _formatMs(userQueryMs),
        if (templateCount != null) 'Templates': templateCount.toString(),
        if (responseCount != null) 'Responses': responseCount.toString(),
      },
    );
  }

  Widget _buildSlowest(BuildContext context, _PerfOperationView? slowest) {
    if (slowest?.end == null) return const SizedBox.shrink();

    final end = slowest!.end!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _speedColor(end.speed).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.speed,
              size: 18,
              color: _speedColor(end.speed),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.slowestInCurrentLogBuffer,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${slowest.base} • ${_formatDuration(end.duration)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _speedColor(end.speed).withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              end.speed,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _speedColor(end.speed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copySummaryToClipboard(BuildContext context) async {
    final ops = _buildOperations(PerformanceLogger.entries);
    final ended = ops.where((o) => o.end != null).toList()
      ..sort((a, b) => b.end!.timestamp.compareTo(a.end!.timestamp));

    final lines = <String>[];

    void addBlock(String title, _PerfOperationView? op) {
      if (op?.end == null) return;
      lines.add(title);
      lines.add('  duration=${_formatDuration(op!.end!.duration)}');
      for (final entry in op.end!.metadata.entries) {
        lines.add('  ${entry.key}=${entry.value}');
      }
      lines.add('');
    }

    addBlock(
        'Shifts', _latestByBase(ended, 'ShiftManagementScreen._loadShiftData'));
    addBlock(
        'Payments',
        _latestByBase(
            ended, 'ShiftTimesheetService.getActualPaymentsForShifts'));
    addBlock('Timesheets',
        _latestByBase(ended, 'AdminTimesheetReview._initialLoad'));
    addBlock('Forms',
        _latestByBase(ended, 'FormResponsesScreen._loadFormResponses'));

    await Clipboard.setData(ClipboardData(text: lines.join('\n').trim()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.performanceSummaryCopied,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xff0386FF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static _PerfOperationView? _latestByBase(
      List<_PerfOperationView> ended, String base) {
    for (final op in ended) {
      if (op.base == base) return op;
    }
    return null;
  }

  static PerfLogEntry? _checkpoint(_PerfOperationView op, String name) {
    for (final c in op.checkpoints) {
      if (c.checkpointName == name) return c;
    }
    return null;
  }

  static Widget _kvLines(Map<String, String> kv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: kv.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ),
                  Text(
                    e.value,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static Widget _noData() {
    return Text(
      AppLocalizations.of(context)!.noDataYet,
      style: GoogleFonts.inter(
        fontSize: 12,
        color: const Color(0xff9CA3AF),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final ms = d.inMilliseconds;
    if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(2)}s';
    return '${ms}ms';
  }

  static String _formatMs(int ms) {
    if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(2)}s';
    return '${ms}ms';
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static Color _speedColor(String speed) {
    switch (speed) {
      case 'SLOW':
        return const Color(0xffDC2626);
      case 'MODERATE':
        return const Color(0xffD97706);
      default:
        return const Color(0xff059669);
    }
  }

  static List<_PerfOperationView> _buildOperations(List<PerfLogEntry> entries) {
    final byId = <String, _PerfOperationView>{};
    for (final entry in entries) {
      final op = byId.putIfAbsent(
        entry.operationId,
        () => _PerfOperationView(
          id: entry.operationId,
          base: _operationBase(entry.operationId),
        ),
      );
      switch (entry.label) {
        case PerfLogLabel.start:
          op.start = entry;
          break;
        case PerfLogLabel.checkpoint:
          op.checkpoints.add(entry);
          break;
        case PerfLogLabel.end:
          op.end = entry;
          break;
      }
    }
    return byId.values.toList();
  }

  static String _operationBase(String operationId) {
    final idx = operationId.lastIndexOf('_');
    if (idx <= 0 || idx == operationId.length - 1) return operationId;
    final suffix = operationId.substring(idx + 1);
    final isNumeric = int.tryParse(suffix) != null;
    return isNumeric ? operationId.substring(0, idx) : operationId;
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget content;

  const _InsightCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffE2E8F0)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xff0386FF).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xff0386FF), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }
}

class _PerfOperationView {
  final String id;
  final String base;
  PerfLogEntry? start;
  PerfLogEntry? end;
  final List<PerfLogEntry> checkpoints = [];

  _PerfOperationView({
    required this.id,
    required this.base,
  });
}
