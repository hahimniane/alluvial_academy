import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../models/timesheet_entry.dart';
import 'timesheet_export_column_preset.dart';
import 'timesheet_export_columns.dart';

typedef TimesheetExportDateParser = DateTime? Function(String rawDate);

/// Multi-sheet export payload for admin timesheet review.
class TimesheetExportSheets {
  const TimesheetExportSheets({
    required this.headersBySheet,
    required this.rowsBySheet,
    required this.detailedHeaders,
    required this.detailedRows,
  });

  final Map<String, List<String>> headersBySheet;
  final Map<String, List<List<dynamic>>> rowsBySheet;
  final List<String> detailedHeaders;
  final List<List<dynamic>> detailedRows;
}

class TimesheetExportBuilder {
  const TimesheetExportBuilder._();

  static TimesheetExportSheets build({
    required List<TimesheetEntry> entries,
    required TimesheetExportDateParser parseEntryDate,
    required AppLocalizations l10n,
    required TimesheetExportColumnPreset detailPreset,
    required bool includeSummarySheets,
  }) {
    final cols = TimesheetExportColumns.forPreset(detailPreset);
    final detailedHeaders = TimesheetExportColumns.headersFor(cols, l10n);
    final detailedRows = <List<dynamic>>[];

    final dailyStats = <String, Map<String, double>>{};
    final weeklyStats = <String, Map<String, double>>{};
    final monthlyStats = <String, Map<String, double>>{};

    void updateStats(
      Map<String, Map<String, double>> map,
      String key,
      double scheduled,
      double worked,
      double pay,
    ) {
      map.putIfAbsent(key, () => {'scheduled': 0, 'worked': 0, 'pay': 0});
      map[key]!['scheduled'] = (map[key]!['scheduled'] ?? 0) + scheduled;
      map[key]!['worked'] = (map[key]!['worked'] ?? 0) + worked;
      map[key]!['pay'] = (map[key]!['pay'] ?? 0) + pay;
    }

    final sortedEntries = List<TimesheetEntry>.from(entries)
      ..sort((a, b) {
        final nameCompare = a.teacherName.compareTo(b.teacherName);
        if (nameCompare != 0) return nameCompare;
        return (parseEntryDate(a.date) ?? DateTime.now())
            .compareTo(parseEntryDate(b.date) ?? DateTime.now());
      });

    for (final entry in sortedEntries) {
      final parsedDate = parseEntryDate(entry.date) ?? DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);

      final weekStart =
          parsedDate.subtract(Duration(days: parsedDate.weekday - 1));
      final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);
      final monthStart = DateTime(parsedDate.year, parsedDate.month, 1);
      final monthKey = DateFormat('yyyy-MM').format(monthStart);

      final m = TimesheetExportColumns.metrics(entry, parsedDate);

      detailedRows.add(
        cols
            .map(
              (c) => TimesheetExportColumns.cellValue(
                c: c,
                entry: entry,
                parsedDate: parsedDate,
                workedHours: m.workedHours,
                scheduledHours: m.scheduledHours,
                pay: m.pay,
                scheduledIn: m.scheduledIn,
                scheduledOut: m.scheduledOut,
                difference: m.difference,
                l10n: l10n,
              ),
            )
            .toList(),
      );

      final teacher = entry.teacherName;
      updateStats(
        dailyStats,
        '$teacher|$dateKey',
        m.scheduledHours,
        m.workedHours,
        m.pay,
      );
      updateStats(
        weeklyStats,
        '$teacher|$weekKey',
        m.scheduledHours,
        m.workedHours,
        m.pay,
      );
      updateStats(
        monthlyStats,
        '$teacher|$monthKey',
        m.scheduledHours,
        m.workedHours,
        m.pay,
      );
    }

    final detailSheetName = l10n.timesheetExportSheetDetail;
    final headersBySheet = <String, List<String>>{
      detailSheetName: detailedHeaders,
    };
    final rowsBySheet = <String, List<List<dynamic>>>{
      detailSheetName: detailedRows,
    };

    if (includeSummarySheets) {
      final dailyHeaders = [
        l10n.timesheetExportSummaryHdrTeacher,
        l10n.timesheetExportSummaryHdrDate,
        l10n.timesheetExportSummaryHdrDay,
        l10n.timesheetExportSummaryHdrTotalScheduled,
        l10n.timesheetExportSummaryHdrTotalWorked,
        l10n.timesheetExportSummaryHdrDifference,
        l10n.timesheetExportSummaryHdrDailyPay,
      ];
      final dailyRows = <List<dynamic>>[];
      dailyStats.forEach((key, stats) {
        final parts = key.split('|');
        final teacher = parts[0];
        final dateStr = parts[1];
        final d = DateTime.parse(dateStr);
        dailyRows.add([
          teacher,
          dateStr,
          DateFormat('EEEE').format(d),
          stats['scheduled']!.toStringAsFixed(2),
          stats['worked']!.toStringAsFixed(2),
          (stats['worked']! - stats['scheduled']!).toStringAsFixed(2),
          stats['pay']!.toStringAsFixed(2),
        ]);
      });
      dailyRows.sort((a, b) {
        final c = (a[0] as String).compareTo(b[0] as String);
        if (c != 0) return c;
        return (a[1] as String).compareTo(b[1] as String);
      });

      final weeklyHeaders = [
        l10n.timesheetExportSummaryHdrTeacher,
        l10n.timesheetExportSummaryHdrWeekStarting,
        l10n.timesheetExportSummaryHdrTotalScheduled,
        l10n.timesheetExportSummaryHdrTotalWorked,
        l10n.timesheetExportSummaryHdrDifference,
        l10n.timesheetExportSummaryHdrWeeklyPay,
      ];
      final weeklyRows = <List<dynamic>>[];
      weeklyStats.forEach((key, stats) {
        final parts = key.split('|');
        weeklyRows.add([
          parts[0],
          parts[1],
          stats['scheduled']!.toStringAsFixed(2),
          stats['worked']!.toStringAsFixed(2),
          (stats['worked']! - stats['scheduled']!).toStringAsFixed(2),
          stats['pay']!.toStringAsFixed(2),
        ]);
      });
      weeklyRows.sort((a, b) => (a[0] as String).compareTo(b[0] as String) == 0
          ? (a[1] as String).compareTo(b[1] as String)
          : (a[0] as String).compareTo(b[0] as String));

      final monthlyHeaders = [
        l10n.timesheetExportSummaryHdrTeacher,
        l10n.timesheetExportSummaryHdrMonth,
        l10n.timesheetExportSummaryHdrTotalScheduled,
        l10n.timesheetExportSummaryHdrTotalWorked,
        l10n.timesheetExportSummaryHdrDifference,
        l10n.timesheetExportSummaryHdrMonthlyPay,
      ];
      final monthlyRows = <List<dynamic>>[];
      monthlyStats.forEach((key, stats) {
        final parts = key.split('|');
        final monthStr = parts[1];
        final d = DateTime.parse('$monthStr-01');
        monthlyRows.add([
          parts[0],
          DateFormat('MMMM yyyy').format(d),
          stats['scheduled']!.toStringAsFixed(2),
          stats['worked']!.toStringAsFixed(2),
          (stats['worked']! - stats['scheduled']!).toStringAsFixed(2),
          stats['pay']!.toStringAsFixed(2),
        ]);
      });
      monthlyRows.sort((a, b) => (a[0] as String).compareTo(b[0] as String) == 0
          ? (a[1] as String).compareTo(b[1] as String)
          : (a[0] as String).compareTo(b[0] as String));

      headersBySheet[l10n.timesheetExportSheetDaily] = dailyHeaders;
      headersBySheet[l10n.timesheetExportSheetWeekly] = weeklyHeaders;
      headersBySheet[l10n.timesheetExportSheetMonthly] = monthlyHeaders;
      rowsBySheet[l10n.timesheetExportSheetDaily] = dailyRows;
      rowsBySheet[l10n.timesheetExportSheetWeekly] = weeklyRows;
      rowsBySheet[l10n.timesheetExportSheetMonthly] = monthlyRows;
    }

    return TimesheetExportSheets(
      headersBySheet: headersBySheet,
      rowsBySheet: rowsBySheet,
      detailedHeaders: detailedHeaders,
      detailedRows: detailedRows,
    );
  }
}
