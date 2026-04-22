import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utility_functions/export_helpers.dart';
import '../export/timesheet_export_builder.dart';
import '../export/timesheet_export_column_preset.dart';
import '../export/timesheet_export_columns.dart';
import '../models/timesheet_entry.dart';

/// Export dialog: only rows currently visible in the table, fixed 7 columns (grid match).
Future<void> showTimesheetReviewExportDialog({
  required BuildContext context,
  required List<TimesheetEntry> visibleEntries,
  required TimesheetExportDateParser parseEntryDate,
  required String baseFileName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  if (visibleEntries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.noDataToExport)),
    );
    return;
  }

  assert(
    TimesheetExportColumns.forPreset(TimesheetExportColumnPreset.screen)
            .length ==
        7,
  );

  final exportContext = context;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.timesheetReviewExportTitle,
          style: GoogleFonts.openSans(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.timesheetReviewExportOnScreenSummary(visibleEntries.length),
                style: GoogleFonts.openSans(
                  fontSize: 13,
                  height: 1.35,
                  color: const Color(0xff374151),
                ),
              ),
              const SizedBox(height: 16),
              _FormatTile(
                icon: Icons.table_chart,
                color: const Color(0xff10B981),
                title: l10n.timesheetReviewExportExcel,
                subtitle: l10n.timesheetReviewExportExcelOneSheet,
                onTap: () {
                  final sheets = TimesheetExportBuilder.build(
                    entries: visibleEntries,
                    parseEntryDate: parseEntryDate,
                    l10n: l10n,
                    detailPreset: TimesheetExportColumnPreset.screen,
                    includeSummarySheets: false,
                  );
                  Navigator.of(ctx).pop();
                  ExportHelpers.exportExcelMultiSheet(
                    sheets.headersBySheet,
                    sheets.rowsBySheet,
                    baseFileName,
                  );
                },
              ),
              const SizedBox(height: 10),
              _FormatTile(
                icon: Icons.description,
                color: const Color(0xff6366F1),
                title: l10n.timesheetReviewExportDetailedCsv,
                subtitle: l10n.timesheetReviewExportCsvSameLayout,
                onTap: () async {
                  final sheets = TimesheetExportBuilder.build(
                    entries: visibleEntries,
                    parseEntryDate: parseEntryDate,
                    l10n: l10n,
                    detailPreset: TimesheetExportColumnPreset.screen,
                    includeSummarySheets: false,
                  );
                  Navigator.of(ctx).pop();
                  await Future<void>.delayed(Duration.zero);
                  if (!exportContext.mounted) return;
                  await ExportHelpers.exportCsvDynamic(
                    exportContext,
                    headers: sheets.detailedHeaders,
                    rows: sheets.detailedRows,
                    baseFileName: '${baseFileName}_table',
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
        ],
      );
    },
  );
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.openSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.openSans(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xff9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}
