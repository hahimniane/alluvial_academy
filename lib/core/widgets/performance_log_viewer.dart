import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/performance_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PerformanceLogViewer extends StatefulWidget {
  final String title;
  final double listHeight;

  const PerformanceLogViewer({
    super.key,
    this.title = 'Performance Logs',
    this.listHeight = 520,
  });

  @override
  State<PerformanceLogViewer> createState() => _PerformanceLogViewerState();
}

class _PerformanceLogViewerState extends State<PerformanceLogViewer> {
  final TextEditingController _searchController = TextEditingController();

  bool _showOnlyEnds = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            final entries = PerformanceLogger.entries;
            final ops = _buildOperations(entries);
            final aggregates = _buildAggregates(ops);

            final visibleOps = ops.where((op) {
              if (_query.isEmpty) return true;
              final base = op.base.toLowerCase();
              final id = op.id.toLowerCase();
              final meta = _kv(op.end?.metadata).toLowerCase();
              return base.contains(_query) ||
                  id.contains(_query) ||
                  meta.contains(_query);
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, entries.length),
                const SizedBox(height: 10),
                _buildControls(context),
                const SizedBox(height: 12),
                _buildSummary(aggregates),
                const SizedBox(height: 12),
                _buildTopSlow(aggregates),
                const SizedBox(height: 12),
                _buildOperationList(context, visibleOps),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int entryCount) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context)!.showsPerformanceloggerStartCheckpointEndEvents,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xffF3F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            AppLocalizations.of(context)!.entrycountEvents,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xff374151),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchByOperationIdMetadata,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xff0386FF), width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: AppLocalizations.of(context)!.clearLogs,
              onPressed: () => setState(PerformanceLogger.clearLogs),
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.copySummary,
              onPressed: () => _copySummaryToClipboard(context),
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildToggleChip(
              label: 'Only END events',
              value: _showOnlyEnds,
              onChanged: (v) => setState(() => _showOnlyEnds = v),
            ),
            _buildToggleChip(
              label: 'Perf enabled',
              value: PerformanceLogger.enabled,
              onChanged: (v) => setState(() => PerformanceLogger.enabled = v),
            ),
            _buildToggleChip(
              label: 'Capture enabled',
              value: PerformanceLogger.captureEnabled,
              onChanged: (v) =>
                  setState(() => PerformanceLogger.captureEnabled = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      selected: value,
      onSelected: onChanged,
      selectedColor: const Color(0xff0386FF).withOpacity(0.12),
      checkmarkColor: const Color(0xff0386FF),
      side: BorderSide(
        color: value ? const Color(0xff0386FF) : const Color(0xffE2E8F0),
      ),
    );
  }

  Widget _buildSummary(_PerfAggregates aggregates) {
    final avgText = aggregates.endCount == 0
        ? '—'
        : '${(aggregates.totalEndMs / aggregates.endCount).toStringAsFixed(0)}ms avg';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _summaryPill(
          label: 'END ops',
          value: aggregates.endCount.toString(),
          color: const Color(0xff111827),
        ),
        _summaryPill(
          label: 'SLOW',
          value: aggregates.slowCount.toString(),
          color: const Color(0xffDC2626),
        ),
        _summaryPill(
          label: 'MODERATE',
          value: aggregates.moderateCount.toString(),
          color: const Color(0xffD97706),
        ),
        _summaryPill(
          label: 'FAST',
          value: aggregates.fastCount.toString(),
          color: const Color(0xff059669),
        ),
        _summaryPill(
          label: 'Avg',
          value: avgText,
          color: const Color(0xff2563EB),
        ),
      ],
    );
  }

  Widget _summaryPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        AppLocalizations.of(context)!.labelValue,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTopSlow(_PerfAggregates aggregates) {
    if (aggregates.slowestEnds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.slowestEnd,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 8),
        ...aggregates.slowestEnds.take(5).map((op) {
          final end = op.end;
          if (end == null) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffFEE2E2)),
              color: const Color(0xffFEF2F2),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xffDC2626), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    op.base,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDuration(end.duration),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xffDC2626),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOperationList(
      BuildContext context, List<_PerfOperationView> ops) {
    final visible =
        _showOnlyEnds ? ops.where((o) => o.end != null).toList() : ops;
    if (visible.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffE2E8F0)),
          color: const Color(0xffF8FAFC),
        ),
        child: Text(
          AppLocalizations.of(context)!.noMatchingLogsYet,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xff6B7280),
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.listHeight,
      child: ListView.builder(
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final op = visible[index];
          final end = op.end;
          final speed = end?.speed ?? '—';
          final color = _speedColor(speed);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xffE2E8F0)),
              color: Colors.white,
            ),
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                childrenPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                title: Text(
                  op.base,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff111827),
                  ),
                ),
                subtitle: Text(
                  op.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xff6B7280),
                  ),
                ),
                trailing: end == null
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatDuration(end.duration),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            speed,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                children: [
                  if (op.start != null)
                    _metaBlock('START metadata', op.start!.metadata),
                  if (op.end != null)
                    _metaBlock('END metadata', op.end!.metadata),
                  if (op.checkpoints.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      AppLocalizations.of(context)!.checkpoints,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...op.checkpoints.map((c) => _checkpointRow(c)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _checkpointRow(PerfLogEntry entry) {
    final elapsed = entry.metadata['elapsed_ms'];
    final delta = entry.metadata['delta_ms'];
    final label = entry.checkpointName ?? 'checkpoint';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xffF8FAFC),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, size: 16, color: Color(0xff64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111827),
              ),
            ),
          ),
          if (delta != null)
            Text(
              '+${delta}ms',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xff0E72ED),
              ),
            ),
          if (elapsed != null) ...[
            const SizedBox(width: 10),
            Text(
              '${elapsed}ms',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xff6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaBlock(String title, Map<String, dynamic> metadata) {
    if (metadata.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xffF8FAFC),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Text(
            _kv(metadata),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xff374151),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  List<_PerfOperationView> _buildOperations(List<PerfLogEntry> entries) {
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

    final ops = byId.values.toList();
    ops.sort((a, b) {
      final at = a.end?.timestamp ??
          a.start?.timestamp ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.end?.timestamp ??
          b.start?.timestamp ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return ops;
  }

  _PerfAggregates _buildAggregates(List<_PerfOperationView> ops) {
    int fast = 0;
    int moderate = 0;
    int slow = 0;
    int endCount = 0;
    int totalMs = 0;

    final ended = <_PerfOperationView>[];

    for (final op in ops) {
      final end = op.end;
      if (end == null) continue;
      ended.add(op);
      endCount++;
      totalMs += end.duration.inMilliseconds;

      switch (end.speed) {
        case 'SLOW':
          slow++;
          break;
        case 'MODERATE':
          moderate++;
          break;
        default:
          fast++;
          break;
      }
    }

    ended.sort((a, b) {
      final ad = a.end?.duration ?? Duration.zero;
      final bd = b.end?.duration ?? Duration.zero;
      return bd.compareTo(ad);
    });

    return _PerfAggregates(
      fastCount: fast,
      moderateCount: moderate,
      slowCount: slow,
      endCount: endCount,
      totalEndMs: totalMs,
      slowestEnds: ended,
    );
  }

  String _operationBase(String operationId) {
    final idx = operationId.lastIndexOf('_');
    if (idx <= 0 || idx == operationId.length - 1) return operationId;
    final suffix = operationId.substring(idx + 1);
    final isNumeric = int.tryParse(suffix) != null;
    return isNumeric ? operationId.substring(0, idx) : operationId;
  }

  Color _speedColor(String speed) {
    switch (speed) {
      case 'SLOW':
        return const Color(0xffDC2626);
      case 'MODERATE':
        return const Color(0xffD97706);
      default:
        return const Color(0xff059669);
    }
  }

  String _formatDuration(Duration d) {
    final ms = d.inMilliseconds;
    if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(2)}s';
    return '${ms}ms';
  }

  String _kv(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return '';
    final keys = metadata.keys.toList()..sort();
    return keys.map((k) => '$k=${metadata[k]}').join('\n');
  }

  Future<void> _copySummaryToClipboard(BuildContext context) async {
    final entries = PerformanceLogger.entries;
    final ops = _buildOperations(entries);
    final aggregates = _buildAggregates(ops);

    final slowest = aggregates.slowestEnds
        .take(10)
        .map((op) {
          final end = op.end;
          return end == null
              ? ''
              : '${op.base} ${_formatDuration(end.duration)} (${end.speed})';
        })
        .where((s) => s.isNotEmpty)
        .join('\n');

    final text = [
      'Performance summary',
      'events=${entries.length}',
      'ended_ops=${aggregates.endCount}',
      'slow=${aggregates.slowCount}, moderate=${aggregates.moderateCount}, fast=${aggregates.fastCount}',
      if (aggregates.endCount > 0)
        'avg_ms=${(aggregates.totalEndMs / aggregates.endCount).toStringAsFixed(0)}',
      '',
      'Slowest (top 10)',
      slowest,
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.performanceSummaryCopiedToClipboard,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xff0386FF),
        behavior: SnackBarBehavior.floating,
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

class _PerfAggregates {
  final int fastCount;
  final int moderateCount;
  final int slowCount;
  final int endCount;
  final int totalEndMs;
  final List<_PerfOperationView> slowestEnds;

  const _PerfAggregates({
    required this.fastCount,
    required this.moderateCount,
    required this.slowCount,
    required this.endCount,
    required this.totalEndMs,
    required this.slowestEnds,
  });
}
