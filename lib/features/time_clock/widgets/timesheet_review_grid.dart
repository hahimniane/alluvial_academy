import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../l10n/app_localizations.dart';
import '../models/timesheet_entry.dart';
import 'timesheet_review_data_source.dart';

class TimesheetReviewGrid extends StatelessWidget {
  const TimesheetReviewGrid({
    super.key,
    required this.dataSource,
    required this.selectAllPendingTriState,
    required this.onSelectAllPendingChanged,
    required this.selectAllPendingEnabled,
    required this.enableHeaderTooltips,
    this.rowHeight = 44,
    this.margin = const EdgeInsets.all(16),
    this.onCardExport,
    this.onCardSelectAllPending,
    this.onDataCellTap,
  });

  final TimesheetReviewDataSource dataSource;
  final bool? selectAllPendingTriState;
  final ValueChanged<bool?> onSelectAllPendingChanged;
  final bool selectAllPendingEnabled;
  final bool enableHeaderTooltips;
  final double rowHeight;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onCardExport;
  final VoidCallback? onCardSelectAllPending;
  /// Opens row detail (e.g. end drawer). Not fired for checkbox/actions columns.
  final void Function(TimesheetEntry entry)? onDataCellTap;

  bool get _showOverflowMenu =>
      onCardExport != null || onCardSelectAllPending != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showOverflowMenu)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: l10n.timesheetReviewGridOverflowMenuTooltip,
                    onSelected: (value) {
                      switch (value) {
                        case 'export':
                          onCardExport?.call();
                          break;
                        case 'pending':
                          onCardSelectAllPending?.call();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem<String>(
                        value: 'export',
                        enabled: onCardExport != null,
                        child: Text(l10n.timesheetReviewGridOverflowExport),
                      ),
                      PopupMenuItem<String>(
                        value: 'pending',
                        enabled: onCardSelectAllPending != null &&
                            selectAllPendingEnabled,
                        child: Text(
                          l10n.timesheetReviewGridOverflowSelectAllPending,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'columns',
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.timesheetReviewGridOverflowColumns,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.timesheetReviewGridOverflowColumnsSoon,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz, color: Color(0xff6B7280)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SfDataGrid(
              source: dataSource,
              allowSorting: true,
              allowFiltering: false,
              rowHeight: rowHeight,
              gridLinesVisibility: GridLinesVisibility.horizontal,
              headerGridLinesVisibility: GridLinesVisibility.horizontal,
              columnWidthMode: ColumnWidthMode.fill,
              onCellTap: onDataCellTap == null
                  ? null
                  : (DataGridCellTapDetails details) {
                      final col = details.column.columnName;
                      if (col == 'select' || col == 'actions') return;
                      const headerRowIndex = 0;
                      final ri = details.rowColumnIndex.rowIndex;
                      if (ri <= headerRowIndex) return;
                      final i = ri - 1;
                      if (i < 0 || i >= dataSource.timesheets.length) return;
                      onDataCellTap!(dataSource.timesheets[i]);
                    },
              columns: [
                GridColumn(
                  columnName: 'select',
                  width: 52,
                  minimumWidth: 48,
                  label: Container(
                    padding: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    child: Checkbox(
                      tristate: true,
                      value: selectAllPendingTriState,
                      onChanged: selectAllPendingEnabled
                          ? onSelectAllPendingChanged
                          : null,
                      activeColor: const Color(0xff0386FF),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                GridColumn(
                  columnName: 'teacher',
                  label: _hdr(l10n.roleTeacher, context),
                ),
                GridColumn(
                  columnName: 'date',
                  width: 110,
                  label: _hdr(l10n.timesheetDate, context),
                ),
                GridColumn(
                  columnName: 'student',
                  minimumWidth: 100,
                  label: _hdr(l10n.roleStudent, context),
                ),
                GridColumn(
                  columnName: 'hours',
                  width: 72,
                  label: _hdrMaybeTip(
                    l10n.hours,
                    enableHeaderTooltips
                        ? l10n.timesheetReviewColumnTooltipHours
                        : null,
                    context,
                  ),
                ),
                GridColumn(
                  columnName: 'payment',
                  width: 88,
                  minimumWidth: 72,
                  label: _hdrMaybeTip(
                    l10n.payment,
                    enableHeaderTooltips
                        ? l10n.timesheetReviewColumnTooltipPayment
                        : null,
                    context,
                  ),
                ),
                GridColumn(
                  columnName: 'source',
                  width: 108,
                  label: _hdr(l10n.source, context),
                ),
                GridColumn(
                  columnName: 'status',
                  width: 100,
                  label: _hdr(l10n.userStatus, context),
                ),
                GridColumn(
                  columnName: 'actions',
                  width: 128,
                  label: _hdr(l10n.timesheetActions, context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _hdr(String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  static Widget _hdrMaybeTip(String text, String? tip, BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
    if (tip == null || tip.isEmpty) return child;
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 500),
      child: child,
    );
  }
}
