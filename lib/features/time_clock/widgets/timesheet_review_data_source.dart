import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../core/enums/timesheet_enums.dart';
import '../../../l10n/app_localizations.dart';
import '../models/timesheet_entry.dart';
import '../services/timesheet_payment_service.dart';
import '../utils/timesheet_admin_preview_text.dart';

class TimesheetReviewDataSource extends DataGridSource {
  TimesheetReviewDataSource({
    required this.timesheets,
    required this.onApprove,
    required this.onReject,
    required this.onViewDetails,
    required this.onSelectionChanged,
    required this.selectedIds,
    required this.context,
    this.enableRichTooltips = false,
    this.compact = true,
  });

  List<TimesheetEntry> timesheets;
  final void Function(TimesheetEntry) onApprove;
  final void Function(TimesheetEntry) onReject;
  final void Function(TimesheetEntry) onViewDetails;
  final void Function(String, bool) onSelectionChanged;
  final Set<String> selectedIds;
  final BuildContext context;
  final bool enableRichTooltips;
  final bool compact;

  /// Web-only: row whose action icons are visible (hover affordance).
  String? _actionsHoverDocId;

  EdgeInsets get _pad => compact
      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
      : const EdgeInsets.all(8);

  @override
  List<DataGridRow> get rows => timesheets.map<DataGridRow>((timesheet) {
        return DataGridRow(cells: [
          DataGridCell<TimesheetEntry>(columnName: 'select', value: timesheet),
          DataGridCell<String>(
              columnName: 'teacher', value: timesheet.teacherName),
          DataGridCell<String>(columnName: 'date', value: timesheet.date),
          DataGridCell<String>(columnName: 'student', value: timesheet.subject),
          DataGridCell<String>(
              columnName: 'hours', value: timesheet.totalHours),
          DataGridCell<double>(
              columnName: 'payment', value: _calculatePayment(timesheet)),
          DataGridCell<String>(
              columnName: 'source', value: timesheet.source ?? 'manual'),
          DataGridCell<TimesheetStatus>(
              columnName: 'status', value: timesheet.status),
          DataGridCell<TimesheetEntry>(columnName: 'actions', value: timesheet),
        ]);
      }).toList();

  double _calculatePayment(TimesheetEntry timesheet) {
    return TimesheetPaymentService.calculatePayment(timesheet);
  }

  Widget _tip(Widget child, TimesheetEntry entry) {
    if (!enableRichTooltips) return child;
    final l10n = AppLocalizations.of(context)!;
    final msg = TimesheetAdminPreviewText.build(entry, l10n);
    return Tooltip(
      message: msg,
      waitDuration: const Duration(milliseconds: 450),
      child: child,
    );
  }

  bool get _tips => enableRichTooltips;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final timesheet = row
        .getCells()
        .firstWhere(
          (cell) => cell.columnName == 'select',
          orElse: () => row.getCells().first,
        )
        .value as TimesheetEntry?;

    Color rowColor = Colors.white;
    if (timesheet != null) {
      switch (timesheet.status) {
        case TimesheetStatus.approved:
          rowColor = const Color(0xFFF0FDF4);
          break;
        case TimesheetStatus.rejected:
          rowColor = const Color(0xFFFEF2F2);
          break;
        case TimesheetStatus.pending:
          rowColor = const Color(0xFFFFF7ED);
          break;
        case TimesheetStatus.draft:
          rowColor = const Color(0xFFF9FAFB);
          break;
      }
    }

    return DataGridRowAdapter(
      color: rowColor,
      cells: row.getCells().map<Widget>((dataGridCell) {
        if (dataGridCell.columnName == 'select') {
          final ts = dataGridCell.value as TimesheetEntry;
          final isSelected = selectedIds.contains(ts.documentId);

          return Container(
            alignment: Alignment.center,
            padding: _pad,
            child: Checkbox(
              value: isSelected,
              onChanged: (value) {
                onSelectionChanged(ts.documentId!, value ?? false);
              },
              activeColor: const Color(0xff0386FF),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          );
        }
        if (dataGridCell.columnName == 'teacher') {
          final ts = row
              .getCells()
              .firstWhere((c) => c.columnName == 'select')
              .value as TimesheetEntry;
          final w = Container(
            alignment: Alignment.centerLeft,
            padding: _pad,
            child: Text(
              dataGridCell.value.toString(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: compact ? 13 : 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
          return _tips ? _tip(w, ts) : w;
        }
        if (dataGridCell.columnName == 'payment') {
          final ts = row
              .getCells()
              .firstWhere((c) => c.columnName == 'select')
              .value as TimesheetEntry;
          final w = Container(
            alignment: Alignment.center,
            padding: _pad,
            child: Text(
              '\$${dataGridCell.value.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
                fontSize: compact ? 13 : 14,
              ),
            ),
          );
          return _tips ? _tip(w, ts) : w;
        }
        if (dataGridCell.columnName == 'source') {
          final source = dataGridCell.value as String;
          final isClockIn = source == 'clock_in';
          final ts = row
              .getCells()
              .firstWhere((c) => c.columnName == 'select')
              .value as TimesheetEntry;

          final w = Container(
            alignment: Alignment.center,
            padding: _pad,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isClockIn
                    ? const Color(0xff10B981).withOpacity(0.1)
                    : const Color(0xff0386FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isClockIn ? Icons.access_time : Icons.edit,
                    size: 11,
                    color: isClockIn
                        ? const Color(0xff10B981)
                        : const Color(0xff0386FF),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      isClockIn ? 'Clock In' : 'Unclocked',
                      style: GoogleFonts.inter(
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        color: isClockIn
                            ? const Color(0xff10B981)
                            : const Color(0xff0386FF),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
          return _tips ? _tip(w, ts) : w;
        }
        if (dataGridCell.columnName == 'status') {
          final status = dataGridCell.value as TimesheetStatus;
          final ts = row
              .getCells()
              .firstWhere((c) => c.columnName == 'select')
              .value as TimesheetEntry;
          Color color;
          String text;

          switch (status) {
            case TimesheetStatus.approved:
              color = Colors.green;
              text = 'Approved';
              break;
            case TimesheetStatus.rejected:
              color = Colors.red;
              text = 'Rejected';
              break;
            case TimesheetStatus.pending:
              color = Colors.orange;
              text = 'Pending';
              break;
            case TimesheetStatus.draft:
              color = Colors.grey;
              text = 'Draft';
              break;
          }

          final w = Container(
            alignment: Alignment.center,
            padding: _pad,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          );
          return _tips ? _tip(w, ts) : w;
        }
        if (dataGridCell.columnName == 'actions') {
          final ts = dataGridCell.value as TimesheetEntry;
          final docId = ts.documentId ?? '';
          final showActions = !kIsWeb || _actionsHoverDocId == docId;

          Widget actionRow() {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showActions) ...[
                  IconButton(
                    onPressed: () => onViewDetails(ts),
                    icon: Icon(Icons.visibility, size: compact ? 17 : 18),
                    tooltip: AppLocalizations.of(context)!.shiftViewDetails,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                  ),
                  if (ts.status == TimesheetStatus.pending) ...[
                    IconButton(
                      onPressed: () => onApprove(ts),
                      icon: Icon(Icons.check_circle,
                          color: Colors.green, size: compact ? 17 : 18),
                      tooltip: AppLocalizations.of(context)!.approve,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                    IconButton(
                      onPressed: () => onReject(ts),
                      icon: Icon(Icons.cancel,
                          color: Colors.red, size: compact ? 17 : 18),
                      tooltip: AppLocalizations.of(context)!.reject,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                  ],
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.more_horiz,
                        size: 20, color: Colors.grey.shade500),
                  ),
              ],
            );
          }

          final padded = Container(
            alignment: Alignment.center,
            padding:
                EdgeInsets.symmetric(horizontal: compact ? 2 : 4, vertical: 4),
            child: actionRow(),
          );

          if (kIsWeb) {
            return MouseRegion(
              opaque: true,
              onEnter: (_) {
                if (_actionsHoverDocId != docId) {
                  _actionsHoverDocId = docId;
                  notifyListeners();
                }
              },
              onExit: (_) {
                if (_actionsHoverDocId == docId) {
                  _actionsHoverDocId = null;
                  notifyListeners();
                }
              },
              child: padded,
            );
          }
          return padded;
        }
        if (dataGridCell.columnName == 'hours') {
          final ts = row
              .getCells()
              .firstWhere((c) => c.columnName == 'select')
              .value as TimesheetEntry;
          final w = Container(
            alignment: Alignment.center,
            padding: _pad,
            child: Text(
              dataGridCell.value.toString(),
              style: GoogleFonts.inter(fontSize: compact ? 13 : 14),
            ),
          );
          return _tips ? _tip(w, ts) : w;
        }
        final ts = row
            .getCells()
            .firstWhere((c) => c.columnName == 'select')
            .value as TimesheetEntry;
        final w = Container(
          alignment: Alignment.centerLeft,
          padding: _pad,
          child: Text(
            dataGridCell.value.toString(),
            style: GoogleFonts.inter(fontSize: compact ? 13 : 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
        return _tips ? _tip(w, ts) : w;
      }).toList(),
    );
  }
}

bool timesheetReviewEnableHoverTooltips() {
  if (kIsWeb) return true;
  return defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS;
}
