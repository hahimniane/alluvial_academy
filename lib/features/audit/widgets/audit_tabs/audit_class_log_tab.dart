import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';
import '../../services/audit_class_log_row_builder.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../audit_shared_widgets.dart';

class AuditClassLogTab extends StatefulWidget {
  final TeacherAuditFull audit;
  const AuditClassLogTab({super.key, required this.audit});

  @override
  State<AuditClassLogTab> createState() => _AuditClassLogTabState();
}

class _AuditClassLogTabState extends State<AuditClassLogTab> {
  String? _expandedShiftId;
  final ScrollController _horizontalController = ScrollController();
  bool _showScrollHint = true;
  bool _showRightFade = true;
  _ColumnGroup? _activeGroup;

  static const Set<String> _defaultColumns = {
    'date',
    'students',
    'subject',
    'scheduled',
    'worked',
    'pay',
  };

  /// Horizontal padding on header/body rows (12+12) must be included in scroll width.
  static const double _tableHorizontalPadding = 24;

  static const List<_ColumnSpec> _allColumns = [
    _ColumnSpec(key: 'date', label: 'Date', width: 100, group: _ColumnGroup.operations),
    _ColumnSpec(key: 'students', label: 'Students', width: 160, group: _ColumnGroup.operations),
    _ColumnSpec(key: 'subject', label: 'Subject', width: 130, group: _ColumnGroup.operations),
    _ColumnSpec(key: 'scheduled', label: 'Sched.', width: 70, group: _ColumnGroup.timeAndPay),
    _ColumnSpec(key: 'clockIn', label: 'Clock-in', width: 80, group: _ColumnGroup.timeAndPay),
    _ColumnSpec(key: 'clockOut', label: 'Clock-out', width: 80, group: _ColumnGroup.timeAndPay),
    _ColumnSpec(key: 'worked', label: 'Worked', width: 80, group: _ColumnGroup.timeAndPay),
    _ColumnSpec(key: 'billed', label: 'Billed', width: 80, group: _ColumnGroup.timeAndPay),
    _ColumnSpec(key: 'rate', label: 'Rate', width: 70, group: _ColumnGroup.timeAndPay),
    _ColumnSpec(key: 'pay', label: 'Pay', width: 80, group: _ColumnGroup.timeAndPay),
    _ColumnSpec(key: 'form', label: 'Form', width: 80, group: _ColumnGroup.operations),
    _ColumnSpec(key: 'status', label: 'Status', width: 95, group: _ColumnGroup.operations),
  ];

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(_onHorizontalScroll);
  }

  @override
  void dispose() {
    _horizontalController
      ..removeListener(_onHorizontalScroll)
      ..dispose();
    super.dispose();
  }

  void _onHorizontalScroll() {
    if (!_horizontalController.hasClients) return;
    final atStart = _horizontalController.offset <= 2;
    final atEnd = _horizontalController.offset >= _horizontalController.position.maxScrollExtent - 2;
    if (_showScrollHint == atStart && _showRightFade != !atEnd) {
      return;
    }
    setState(() {
      _showScrollHint = atStart;
      _showRightFade = !atEnd;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = AuditClassLogRowBuilder.buildRows(widget.audit);
    final totals = AuditClassLogRowBuilder.computeTotalsFromRows(rows);
    assert(() {
      final warnings = AuditClassLogRowBuilder.consistencyWarnings(widget.audit);
      for (final w in warnings) {
        AppLogger.warning('Audit consistency warning (${widget.audit.id}): $w');
      }
      return true;
    }());
    if (rows.isEmpty) {
      return AuditEmptyState(
        icon: Icons.table_rows_outlined,
        message: AppLocalizations.of(context)!.noClassesFound,
      );
    }

    final completed = rows.where((r) {
      final s = r.statusRaw.toLowerCase();
      return s.contains('completed') || s.contains('fully') || s.contains('partially');
    }).length;
    final missed = rows.where((r) => r.statusRaw.toLowerCase().contains('missed')).length;
    final worked = totals.totalWorkedFromTs;
    final totalPay = totals.grossBySource;

    final visibleColumns = _visibleColumns();
    final tableWidth = _tableHorizontalPadding +
        30.0 +
        visibleColumns.fold<double>(0, (total, c) => total + c.width);

    return Column(
      children: [
        _buildStats(completed, missed, worked, totalPay, rows.length),
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              if (_showScrollHint)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 0.5),
                  ),
                  child: Text(
                    'Scroll right for more columns',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              _groupChip('All', null),
              const SizedBox(width: 6),
              _groupChip('Operations', _ColumnGroup.operations),
              const SizedBox(width: 6),
              _groupChip('Time & Pay', _ColumnGroup.timeAndPay),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xffE2E8F0)),
        Expanded(
          child: Stack(
            children: [
              Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        Container(
                          color: const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(width: 30),
                              ...visibleColumns.map((c) => _HeaderCell(c.label, c.width)),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xffE2E8F0)),
                        Expanded(
                          child: ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, index) => _buildRow(rows[index], visibleColumns),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showRightFade)
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 24,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0x00FFFFFF), Color(0xCCFFFFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<_ColumnSpec> _visibleColumns() {
    if (_activeGroup == null) {
      return _allColumns.where((c) => _defaultColumns.contains(c.key)).toList();
    }
    return _allColumns.where((c) => c.group == _activeGroup).toList();
  }

  Widget _groupChip(String label, _ColumnGroup? group) {
    final selected = _activeGroup == group;
    return InkWell(
      onTap: () {
        if (_activeGroup == group) return;
        setState(() {
          _activeGroup = group;
          _showRightFade = true;
          _showScrollHint = true;
        });
        if (_horizontalController.hasClients) {
          _horizontalController.jumpTo(0);
        }
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(color: selected ? const Color(0xFFBFDBFE) : const Color(0xffE2E8F0), width: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF1D4ED8) : const Color(0xff475569),
          ),
        ),
      ),
    );
  }

  Widget _buildStats(int completed, int missed, double worked, double totalPay, int total) {
    Widget stat(String label, String value, Color color) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xffE2E8F0), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff64748B))),
            Text(
              value,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            stat('Scheduled', '$total', const Color(0xff1E293B)),
            stat('Completed', '$completed', const Color(0xFF10B981)),
            stat('Missed', '$missed', const Color(0xFFEF4444)),
            stat('Hours (TS)', worked.toStringAsFixed(2), const Color(0xff0F766E)),
            stat('Gross pay', '\$${totalPay.toStringAsFixed(2)}', const Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(AuditClassLogRow row, List<_ColumnSpec> columns) {
    final isExpanded = _expandedShiftId == row.shiftId;
    final s = row.statusRaw.toLowerCase();
    final isMissed = s.contains('missed');
    final bg = isMissed ? const Color(0xFFFFF1F2) : Colors.white;
    final statusColor = isMissed ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final dateStr = row.shiftStart != null ? DateFormat('MMM d, yyyy').format(row.shiftStart!) : '—';

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expandedShiftId = isExpanded ? null : row.shiftId),
          child: Container(
            color: bg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xffCBD5E1)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(isExpanded ? '-' : '+', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                ...columns.map((c) => _columnCell(c, row, dateStr, statusColor, isMissed)),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(56, 8, 16, 12),
            color: const Color(0xFFF8FAFC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Billed hours rule', 'Min(worked, scheduled)'),
                if (row.hourlyRate > 0)
                  _kv(
                    'Theoretical (billed × rate)',
                    '${row.billedHours.toStringAsFixed(2)} h × \$${row.hourlyRate.toStringAsFixed(2)} = \$${row.theoreticalPay.toStringAsFixed(2)}',
                  )
                else
                  _kv('Theoretical (billed × rate)', '— (no hourly rate on shift)'),
                _kv(
                  'Recorded base pay (${row.paymentSource})',
                  '\$${row.baseAmount.toStringAsFixed(2)}',
                ),
                if (row.manualAdjustment != 0)
                  _kv(
                    'Manual adjustment',
                    '${row.manualAdjustment >= 0 ? '+' : ''}\$${row.manualAdjustment.toStringAsFixed(2)}',
                  ),
                _kv('Final pay', '\$${row.finalPayment.toStringAsFixed(2)}'),
                _kv('Form linked', row.hasForm ? 'Yes' : 'No'),
              ],
            ),
          ),
        const Divider(height: 1, color: Color(0xffE2E8F0)),
      ],
    );
  }

  Widget _cell(String text, double width, {Color? color}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 11, color: color ?? const Color(0xff1E293B), fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _columnCell(
    _ColumnSpec column,
    AuditClassLogRow row,
    String dateStr,
    Color statusColor,
    bool isMissed,
  ) {
    switch (column.key) {
      case 'date':
        return _cell(dateStr, column.width);
      case 'students':
        return _cell(_studentsForShift(widget.audit, row.shiftId), column.width);
      case 'subject':
        return _cell(row.subject, column.width);
      case 'scheduled':
        return _cell('${row.scheduledHours.toStringAsFixed(2)}h', column.width);
      case 'clockIn':
        return _cell(_clockFromTimesheet(widget.audit, row.shiftId, true), column.width);
      case 'clockOut':
        return _cell(_clockFromTimesheet(widget.audit, row.shiftId, false), column.width);
      case 'worked':
        return _cell(_hoursToHms(row.workedHours), column.width);
      case 'billed':
        return _cell('${row.billedHours.toStringAsFixed(2)}h', column.width);
      case 'rate':
        return _cell(
          row.hourlyRate > 0 ? '\$${row.hourlyRate.toStringAsFixed(2)}' : '-',
          column.width,
        );
      case 'pay':
        return _cell(
          '\$${row.finalPayment.toStringAsFixed(2)}',
          column.width,
          color: row.finalPayment > 0
              ? const Color(0xFF059669)
              : const Color(0xff94A3B8),
        );
      case 'form':
        return _cell(
          row.hasForm ? '✓ Filed' : '—',
          column.width,
          color: row.hasForm ? const Color(0xFF10B981) : const Color(0xff94A3B8),
        );
      case 'status':
        return SizedBox(
          width: column.width,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isMissed ? '✗ Missed' : '✓ Done',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      default:
        return _cell('—', column.width);
    }
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(key, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff64748B))),
          Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _hoursToHms(double hours) {
    if (hours <= 0) return '—';
    final totalSeconds = (hours * 3600).round();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _studentsForShift(TeacherAuditFull audit, String shiftId) {
    final shift = audit.detailedShifts.cast<Map<String, dynamic>?>().firstWhere(
          (s) => (s?['id'] as String?) == shiftId,
          orElse: () => null,
        );
    if (shift == null) return '—';
    final title = (shift['title'] as String?) ?? '';
    final parts = title.split(' - ');
    if (parts.length >= 3) return parts[2].trim();
    return title.isNotEmpty ? title : '—';
  }

  String _clockFromTimesheet(TeacherAuditFull audit, String shiftId, bool inTime) {
    final ts = audit.detailedTimesheets.cast<Map<String, dynamic>?>().firstWhere(
          (t) => ((t?['shift_id'] as String?) == shiftId || (t?['shiftId'] as String?) == shiftId),
          orElse: () => null,
        );
    if (ts == null) return '—';
    final raw = inTime ? (ts['clock_in_timestamp'] ?? ts['clockIn'] ?? ts['clock_in_time']) : (ts['clock_out_timestamp'] ?? ts['clockOut'] ?? ts['clock_out_time']);
    if (raw is Timestamp) return DateFormat('HH:mm:ss').format(raw.toDate());
    if (raw is DateTime) return DateFormat('HH:mm:ss').format(raw);
    if (raw is String) return raw;
    return '—';
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  const _HeaderCell(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff475569), fontWeight: FontWeight.w700),
      ),
    );
  }
}

enum _ColumnGroup { operations, timeAndPay }

class _ColumnSpec {
  final String key;
  final String label;
  final double width;
  final _ColumnGroup group;

  const _ColumnSpec({
    required this.key,
    required this.label,
    required this.width,
    required this.group,
  });
}
