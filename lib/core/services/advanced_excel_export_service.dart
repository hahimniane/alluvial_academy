import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teacher_audit_full.dart';

/// Translations for Excel export (no BuildContext in service, so we use locale code).
class _ExcelExportL10n {
  final String sheetDashboard;
  final String sheetActivity;
  final String sheetPaiement;
  final String payrollSummaryTitle;
  final String payrollSummarySubtitle;
  final String colTeacher;
  final String colSubject;
  final String colHrsTs;
  final String colHrsForms;
  final String colPayTs;
  final String colPayForms;
  final String colGrossPay;
  final String colPenalties;
  final String colBonuses;
  final String colNetPay;
  final String colGlobalAdj;
  final String colFinalPay;
  final String totalLabel;
  final String issuesAndFlagsTitle;
  final String colIssueType;
  final String colDescription;
  final String colSeverity;
  final String dashboardTitle;
  final String dashboardSubtitle;
  final String teacherPerformanceOverview;

  const _ExcelExportL10n({
    required this.sheetDashboard,
    required this.sheetActivity,
    required this.sheetPaiement,
    required this.payrollSummaryTitle,
    required this.payrollSummarySubtitle,
    required this.colTeacher,
    required this.colSubject,
    required this.colHrsTs,
    required this.colHrsForms,
    required this.colPayTs,
    required this.colPayForms,
    required this.colGrossPay,
    required this.colPenalties,
    required this.colBonuses,
    required this.colNetPay,
    required this.colGlobalAdj,
    required this.colFinalPay,
    required this.totalLabel,
    required this.issuesAndFlagsTitle,
    required this.colIssueType,
    required this.colDescription,
    required this.colSeverity,
    required this.dashboardTitle,
    required this.dashboardSubtitle,
    required this.teacherPerformanceOverview,
  });

  static _ExcelExportL10n forLocale(String locale) {
    final isFr = locale.startsWith('fr');
    return isFr ? _fr : _en;
  }

  static const _en = _ExcelExportL10n(
    sheetDashboard: '🎯 Dashboard',
    sheetActivity: '📋 Activity',
    sheetPaiement: '💰 Payment',
    payrollSummaryTitle: 'PAYROLL SUMMARY',
    payrollSummarySubtitle: 'Summary by teacher · Final Pay = sum of Final Pay (Activity)',
    colTeacher: 'Teacher',
    colSubject: 'Subject',
    colHrsTs: 'Hrs (TS)',
    colHrsForms: 'Hrs (Forms)',
    colPayTs: 'Pay (TS)',
    colPayForms: 'Pay (Forms)',
    colGrossPay: 'Gross Pay',
    colPenalties: 'Penalties',
    colBonuses: 'Bonuses',
    colNetPay: 'Net Pay',
    colGlobalAdj: 'Global Adj',
    colFinalPay: 'Final Pay',
    totalLabel: 'TOTAL',
    issuesAndFlagsTitle: 'ISSUES & FLAGS',
    colIssueType: 'Issue Type',
    colDescription: 'Description',
    colSeverity: 'Severity',
    dashboardTitle: 'TEACHER AUDIT REPORT',
    dashboardSubtitle: 'teachers · 1 month · Auto-generated report',
    teacherPerformanceOverview: 'TEACHER PERFORMANCE OVERVIEW',
  );

  static const _fr = _ExcelExportL10n(
    sheetDashboard: '🎯 Tableau de bord',
    sheetActivity: '📋 Activité',
    sheetPaiement: '💰 Paiement',
    payrollSummaryTitle: 'RÉSUMÉ DE PAIE',
    payrollSummarySubtitle: 'Résumé par enseignant · Paiement final = somme des Paiements finaux (Activité)',
    colTeacher: 'Enseignant',
    colSubject: 'Matière',
    colHrsTs: 'H (feuilles)',
    colHrsForms: 'H (form.)',
    colPayTs: 'Paie (feuilles)',
    colPayForms: 'Paie (form.)',
    colGrossPay: 'Brut',
    colPenalties: 'Pénalités',
    colBonuses: 'Bonus',
    colNetPay: 'Net',
    colGlobalAdj: 'Ajust. global',
    colFinalPay: 'Paiement final',
    totalLabel: 'TOTAL',
    issuesAndFlagsTitle: 'PROBLÈMES & ALERTES',
    colIssueType: 'Type',
    colDescription: 'Description',
    colSeverity: 'Gravité',
    dashboardTitle: 'RAPPORT D\'AUDIT ENSEIGNANTS',
    dashboardSubtitle: 'enseignants · 1 mois · Rapport généré automatiquement',
    teacherPerformanceOverview: 'APERÇU DE LA PERFORMANCE',
  );
}

/// Advanced Excel Export Service with colors, filters, and all audit data
/// Organized by Teacher with monthly breakdown - PIVOT TABLE STYLE
/// Months are columns, Teachers are rows
class AdvancedExcelExportService {
  /// Export audits to a well-formatted Excel file with multiple sheets.
  /// [locale] e.g. 'en' or 'fr' to translate sheet names and content.
  static Future<void> exportToExcel({
    required List<TeacherAuditFull> audits,
    required String yearMonth,
    bool groupByTeacher = true,
    String? locale,
  }) async {
    final l10n = _ExcelExportL10n.forLocale(locale ?? 'en');
    final stopwatch = Stopwatch()..start();
    
    try {
      final excel = Excel.createExcel();
      
      // Group audits by teacher for better organization
      final auditsByTeacher = <String, List<TeacherAuditFull>>{};
      for (var audit in audits) {
        auditsByTeacher.putIfAbsent(audit.teacherName, () => []).add(audit);
      }
      
      // Sort each teacher's audits by month (oldest first for column order)
      for (var teacherAudits in auditsByTeacher.values) {
        teacherAudits.sort((a, b) => a.yearMonth.compareTo(b.yearMonth));
      }
      
      // ══════════════════════════════════════════════════════════════════════
      // STYLED REPORT (same layout as Python build_report.py): Dashboard,
      // Activity, Payment + Evaluation, Reviews, Leave Requests
      // ══════════════════════════════════════════════════════════════════════
      _createDashboardSheetStyled(excel, audits, yearMonth, l10n);
      _createActiviteSheetStyled(excel, audits, yearMonth, l10n);
      _createPaiementSheetStyled(excel, audits, yearMonth, l10n);
      _createEvaluationSheet(excel, audits);
      _createReviewSheet(excel, audits);
      await _createLeaveRequestsSheet(excel, audits, yearMonth);
      
      // Remove default sheet if present (excel package creates "Sheet1" by default)
      if (excel.sheets.containsKey('Sheet1') && excel.sheets.length >= 2) {
        excel.delete('Sheet1');
      }
      // Force workbook to open on Dashboard (styled report)
      if (excel.sheets.containsKey(l10n.sheetDashboard)) {
        excel.setDefaultSheet(l10n.sheetDashboard);
      }
      
      // Generate file
      final bytes = excel.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }
      
      // Download in browser (unique filename so you don't open an old cached file)
      if (kIsWeb) {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'teacher_audit_report_${yearMonth}_$timestamp.xlsx';
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      }
      
      if (kDebugMode) {
        print('✅ Excel exported in ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error exporting Excel: $e');
      }
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // NEW: MONTHLY PIVOT SHEET - Teachers as rows, Months as columns
  // ════════════════════════════════════════════════════════════════════════════
  
  /// Creates a pivot table with teachers as rows and months as column groups
  /// Each month has: Score, Tier, Hours, Classes, Completed, Payment
  static void _createMonthlyPivotSheet(
    Excel excel,
    Map<String, List<TeacherAuditFull>> auditsByTeacher,
    List<String> allMonths,
  ) {
    final sheet = excel['📊 Monthly View'];
    
    // Styles
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final monthHeaderStyle = CellStyle(
      bold: true,
      fontSize: 12,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final metricHeaderStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#3B82F6'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final teacherStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
    );
    
    // Title row
    final totalCols = 2 + (allMonths.length * 6); // Teacher + Email + 6 metrics per month
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 0));
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('📊 MONTHLY REPORT BY TEACHER - ${allMonths.length} Months');
    titleCell.cellStyle = titleStyle;
    
    // Metrics for each month (6 metrics per month)
    final metricsPerMonth = ['Score', 'Tier', 'Hours', 'Classes', 'Completed', 'Payment'];
    
    // Row 2: Month headers (merged across 6 columns each)
    // Row 3: Metric headers
    int colOffset = 2; // Start after Teacher and Email columns
    
      // Fixed headers for teacher info
      final teacherHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2));
      teacherHeaderCell.value = TextCellValue('Teacher');
      teacherHeaderCell.cellStyle = metricHeaderStyle;
      
      final emailHeaderCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2));
      emailHeaderCell.value = TextCellValue('Email');
      emailHeaderCell.cellStyle = metricHeaderStyle;
    
    for (var monthIdx = 0; monthIdx < allMonths.length; monthIdx++) {
      final month = allMonths[monthIdx];
      final startCol = colOffset + (monthIdx * metricsPerMonth.length);
      final endCol = startCol + metricsPerMonth.length - 1;
      
      // Merge month header
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: 1),
      );
      
      final monthCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: 1));
      monthCell.value = TextCellValue(_formatYearMonth(month));
      monthCell.cellStyle = monthHeaderStyle;
      
      // Metric sub-headers
      for (var metricIdx = 0; metricIdx < metricsPerMonth.length; metricIdx++) {
        final metricCell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: startCol + metricIdx, 
          rowIndex: 2,
        ));
        metricCell.value = TextCellValue(metricsPerMonth[metricIdx]);
        metricCell.cellStyle = metricHeaderStyle;
      }
    }
    
    // Data rows - one per teacher
    int row = 3;
    final sortedTeachers = auditsByTeacher.keys.toList()..sort();
    
    for (var teacherName in sortedTeachers) {
      final teacherAudits = auditsByTeacher[teacherName]!;
      
      // Teacher name and email
      final teacherCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      teacherCell.value = TextCellValue(teacherName);
      teacherCell.cellStyle = teacherStyle;
      
      final emailCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      emailCell.value = TextCellValue(teacherAudits.first.teacherEmail);
      
      // Create a map of month -> audit for quick lookup
      final auditByMonth = <String, TeacherAuditFull>{};
      for (var audit in teacherAudits) {
        auditByMonth[audit.yearMonth] = audit;
      }
      
      // Fill data for each month
      for (var monthIdx = 0; monthIdx < allMonths.length; monthIdx++) {
        final month = allMonths[monthIdx];
        final startCol = colOffset + (monthIdx * metricsPerMonth.length);
        final audit = auditByMonth[month];
        
        if (audit != null) {
          // Score
          final scoreCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: row));
          scoreCell.value = TextCellValue('${audit.overallScore.toStringAsFixed(1)}/10');
          scoreCell.cellStyle = CellStyle(
            backgroundColorHex: _getTierColor(audit.performanceTier),
            fontColorHex: ExcelColor.white,
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
          
          // Tier
          final tierCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + 1, rowIndex: row));
          tierCell.value = TextCellValue(_formatTierShort(audit.performanceTier));
          tierCell.cellStyle = CellStyle(
            backgroundColorHex: _getTierColor(audit.performanceTier),
            fontColorHex: ExcelColor.white,
            horizontalAlign: HorizontalAlign.Center,
          );
          
          // Hours
          final hoursCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + 2, rowIndex: row));
          hoursCell.value = TextCellValue('${audit.totalWorkedHours.toStringAsFixed(1)}h');
          hoursCell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
          
          // Classes scheduled
          final classesCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + 3, rowIndex: row));
          classesCell.value = TextCellValue(audit.totalClassesScheduled.toString());
          classesCell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
          
          // Classes completed
          final completedCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + 4, rowIndex: row));
          completedCell.value = TextCellValue(audit.totalClassesCompleted.toString());
          final completionPct = audit.totalClassesScheduled > 0 
              ? (audit.totalClassesCompleted / audit.totalClassesScheduled * 100) 
              : 0.0;
          completedCell.cellStyle = CellStyle(
            backgroundColorHex: _getRateColor(completionPct),
            horizontalAlign: HorizontalAlign.Center,
          );
          
          // Payment
          final paymentCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + 5, rowIndex: row));
          paymentCell.value = TextCellValue('\$${audit.paymentSummary?.totalNetPayment.toStringAsFixed(0) ?? '0'}');
          paymentCell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#DCFCE7'),
            fontColorHex: ExcelColor.fromHexString('#166534'),
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        } else {
          // No data for this month - fill with "-"
          for (var i = 0; i < metricsPerMonth.length; i++) {
            final emptyCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + i, rowIndex: row));
            emptyCell.value = TextCellValue('-');
            emptyCell.cellStyle = CellStyle(
              fontColorHex: ExcelColor.fromHexString('#9CA3AF'),
              horizontalAlign: HorizontalAlign.Center,
            );
          }
        }
      }
      
      row++;
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25); // Teacher name
    sheet.setColumnWidth(1, 28); // Email
    for (var i = 0; i < allMonths.length * metricsPerMonth.length; i++) {
      sheet.setColumnWidth(i + 2, 12);
    }
  }
  
  /// Creates a score comparison sheet - simplified view of just scores by month
  static void _createScoreComparisonSheet(
    Excel excel,
    Map<String, List<TeacherAuditFull>> auditsByTeacher,
    List<String> allMonths,
  ) {
    final sheet = excel['📈 Scores by Month'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#7C3AED'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // Headers
    final headers = ['Teacher', ...allMonths.map(_formatYearMonth), 'Average', 'Change'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Data rows
    int row = 1;
    final sortedTeachers = auditsByTeacher.keys.toList()..sort();
    
    for (var teacherName in sortedTeachers) {
      final teacherAudits = auditsByTeacher[teacherName]!;
      final auditByMonth = <String, TeacherAuditFull>{};
      for (var audit in teacherAudits) {
        auditByMonth[audit.yearMonth] = audit;
      }
      
      // Teacher name
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(teacherName)
        ..cellStyle = CellStyle(bold: true);
      
      // Scores for each month
      List<double> scores = [];
      for (var monthIdx = 0; monthIdx < allMonths.length; monthIdx++) {
        final month = allMonths[monthIdx];
        final audit = auditByMonth[month];
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: monthIdx + 1, rowIndex: row));
        
        if (audit != null) {
          scores.add(audit.overallScore);
          cell.value = TextCellValue(audit.overallScore.toStringAsFixed(1));
          cell.cellStyle = CellStyle(
            backgroundColorHex: _getTierColor(audit.performanceTier),
            fontColorHex: ExcelColor.white,
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        } else {
          cell.value = TextCellValue('-');
          cell.cellStyle = CellStyle(
            fontColorHex: ExcelColor.fromHexString('#9CA3AF'),
            horizontalAlign: HorizontalAlign.Center,
          );
        }
      }
      
      // Average score
      final avgCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: allMonths.length + 1, rowIndex: row));
      if (scores.isNotEmpty) {
        final avg = scores.reduce((a, b) => a + b) / scores.length;
        avgCell.value = TextCellValue(avg.toStringAsFixed(1));
        avgCell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'),
        );
      } else {
        avgCell.value = TextCellValue('-');
      }
      
      // Evolution (last - first)
      final evoCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: allMonths.length + 2, rowIndex: row));
      if (scores.length >= 2) {
        final evolution = scores.last - scores.first;
        final sign = evolution >= 0 ? '+' : '';
        evoCell.value = TextCellValue('$sign${evolution.toStringAsFixed(1)}');
        evoCell.cellStyle = CellStyle(
          bold: true,
          fontColorHex: evolution >= 0 
              ? ExcelColor.fromHexString('#16A34A')
              : ExcelColor.fromHexString('#DC2626'),
          backgroundColorHex: evolution >= 0
              ? ExcelColor.fromHexString('#DCFCE7')
              : ExcelColor.fromHexString('#FEE2E2'),
          horizontalAlign: HorizontalAlign.Center,
        );
      } else {
        evoCell.value = TextCellValue('-');
      }
      
      row++;
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25);
    for (var i = 1; i < headers.length; i++) {
      sheet.setColumnWidth(i, 14);
    }
  }
  
  /// Creates an hours comparison sheet by month
  static void _createHoursComparisonSheet(
    Excel excel,
    Map<String, List<TeacherAuditFull>> auditsByTeacher,
    List<String> allMonths,
  ) {
    final sheet = excel['⏰ Hours by Month'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#0891B2'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // Headers
    final headers = ['Teacher', ...allMonths.map(_formatYearMonth), 'Total', 'Avg/Month'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Data rows
    int row = 1;
    final sortedTeachers = auditsByTeacher.keys.toList()..sort();
    
    for (var teacherName in sortedTeachers) {
      final teacherAudits = auditsByTeacher[teacherName]!;
      final auditByMonth = <String, TeacherAuditFull>{};
      for (var audit in teacherAudits) {
        auditByMonth[audit.yearMonth] = audit;
      }
      
      // Teacher name
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(teacherName)
        ..cellStyle = CellStyle(bold: true);
      
      // Hours for each month
      double totalHours = 0;
      int monthsWithData = 0;
      
      for (var monthIdx = 0; monthIdx < allMonths.length; monthIdx++) {
        final month = allMonths[monthIdx];
        final audit = auditByMonth[month];
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: monthIdx + 1, rowIndex: row));
        
        if (audit != null) {
          totalHours += audit.totalWorkedHours;
          monthsWithData++;
          cell.value = TextCellValue('${audit.totalWorkedHours.toStringAsFixed(1)}h');
          cell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: audit.totalWorkedHours > 20 
                ? ExcelColor.fromHexString('#DCFCE7')
                : audit.totalWorkedHours > 10 
                    ? ExcelColor.fromHexString('#FEF9C3')
                    : ExcelColor.fromHexString('#FEE2E2'),
          );
        } else {
          cell.value = TextCellValue('-');
          cell.cellStyle = CellStyle(
            fontColorHex: ExcelColor.fromHexString('#9CA3AF'),
            horizontalAlign: HorizontalAlign.Center,
          );
        }
      }
      
      // Total hours
      final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: allMonths.length + 1, rowIndex: row));
      totalCell.value = TextCellValue('${totalHours.toStringAsFixed(1)}h');
      totalCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#E0E7FF'),
      );
      
      // Average per month
      final avgCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: allMonths.length + 2, rowIndex: row));
      if (monthsWithData > 0) {
        avgCell.value = TextCellValue('${(totalHours / monthsWithData).toStringAsFixed(1)}h');
        avgCell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'),
        );
      } else {
        avgCell.value = TextCellValue('-');
      }
      
      row++;
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25);
    for (var i = 1; i < headers.length; i++) {
      sheet.setColumnWidth(i, 14);
    }
  }
  
  /// Creates a payment comparison sheet by month
  static void _createPaymentComparisonSheet(
    Excel excel,
    Map<String, List<TeacherAuditFull>> auditsByTeacher,
    List<String> allMonths,
  ) {
    final sheet = excel['💰 Payments by Month'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#059669'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // Headers
    final headers = ['Teacher', ...allMonths.map(_formatYearMonth), 'Total Paid', 'Avg/Month'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Data rows
    int row = 1;
    final sortedTeachers = auditsByTeacher.keys.toList()..sort();
    
    // Track totals for summary row
    Map<String, double> monthTotals = {for (var m in allMonths) m: 0.0};
    double grandTotal = 0;
    
    for (var teacherName in sortedTeachers) {
      final teacherAudits = auditsByTeacher[teacherName]!;
      final auditByMonth = <String, TeacherAuditFull>{};
      for (var audit in teacherAudits) {
        auditByMonth[audit.yearMonth] = audit;
      }
      
      // Teacher name
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(teacherName)
        ..cellStyle = CellStyle(bold: true);
      
      // Payments for each month
      double totalPayment = 0;
      int monthsWithData = 0;
      
      for (var monthIdx = 0; monthIdx < allMonths.length; monthIdx++) {
        final month = allMonths[monthIdx];
        final audit = auditByMonth[month];
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: monthIdx + 1, rowIndex: row));
        
        if (audit != null && audit.paymentSummary != null) {
          final payment = audit.paymentSummary!.totalNetPayment;
          totalPayment += payment;
          monthTotals[month] = (monthTotals[month] ?? 0) + payment;
          monthsWithData++;
          cell.value = TextCellValue('\$${payment.toStringAsFixed(0)}');
          cell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: ExcelColor.fromHexString('#DCFCE7'),
            fontColorHex: ExcelColor.fromHexString('#166534'),
          );
        } else {
          cell.value = TextCellValue('-');
          cell.cellStyle = CellStyle(
            fontColorHex: ExcelColor.fromHexString('#9CA3AF'),
            horizontalAlign: HorizontalAlign.Center,
          );
        }
      }
      
      grandTotal += totalPayment;
      
      // Total payment
      final totalCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: allMonths.length + 1, rowIndex: row));
      totalCell.value = TextCellValue('\$${totalPayment.toStringAsFixed(0)}');
      totalCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#BBF7D0'),
        fontColorHex: ExcelColor.fromHexString('#166534'),
      );
      
      // Average per month
      final avgCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: allMonths.length + 2, rowIndex: row));
      if (monthsWithData > 0) {
        avgCell.value = TextCellValue('\$${(totalPayment / monthsWithData).toStringAsFixed(0)}');
        avgCell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'),
        );
      } else {
        avgCell.value = TextCellValue('-');
      }
      
      row++;
    }
    
    // Summary row with totals
    row++;
    final summaryStyle = CellStyle(
      bold: true,
      fontSize: 12,
      backgroundColorHex: ExcelColor.fromHexString('#FEF3C7'),
      fontColorHex: ExcelColor.fromHexString('#92400E'),
    );
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue('TOTAL')
      ..cellStyle = summaryStyle;
    
    for (var monthIdx = 0; monthIdx < allMonths.length; monthIdx++) {
      final month = allMonths[monthIdx];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: monthIdx + 1, rowIndex: row))
        ..value = TextCellValue('\$${monthTotals[month]?.toStringAsFixed(0) ?? '0'}')
        ..cellStyle = summaryStyle;
    }
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: allMonths.length + 1, rowIndex: row))
      ..value = TextCellValue('\$${grandTotal.toStringAsFixed(0)}')
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        backgroundColorHex: ExcelColor.fromHexString('#22C55E'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );
    
    // Set column widths
    sheet.setColumnWidth(0, 25);
    for (var i = 1; i < headers.length; i++) {
      sheet.setColumnWidth(i, 14);
    }
  }
  
  // Helper for short tier format
  static String _formatTierShort(String tier) {
    switch (tier.toLowerCase()) {
      case 'excellent': return '⭐';
      case 'good': return '✅';
      case 'needsimprovement': return '⚠️';
      case 'critical': return '🚨';
      default: return '❓';
    }
  }
  
  /// Creates a form compliance comparison sheet by month
  static void _createFormComplianceComparisonSheet(
    Excel excel,
    Map<String, List<TeacherAuditFull>> auditsByTeacher,
    List<String> allMonths,
  ) {
    final sheet = excel['📋 Forms by Month'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#DC2626'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // Headers: Teacher | Month1 (Required, Submitted, Rate, Hours) | Month2... | Totals
    final headers = ['Teacher'];
    for (var month in allMonths) {
      headers.addAll([
        '${_formatYearMonth(month)} - Required',
        '${_formatYearMonth(month)} - Submitted',
        '${_formatYearMonth(month)} - Rate %',
        '${_formatYearMonth(month)} - Hours',
      ]);
    }
    headers.addAll(['Total Required', 'Total Submitted', 'Overall Rate %', 'Total Hours']);
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Data rows
    int row = 1;
    final sortedTeachers = auditsByTeacher.keys.toList()..sort();
    
    for (var teacherName in sortedTeachers) {
      final teacherAudits = auditsByTeacher[teacherName]!;
      final auditByMonth = <String, TeacherAuditFull>{};
      for (var audit in teacherAudits) {
        auditByMonth[audit.yearMonth] = audit;
      }
      
      // Teacher name
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(teacherName)
        ..cellStyle = CellStyle(bold: true);
      
      // Form metrics for each month
      int totalRequired = 0;
      int totalSubmitted = 0;
      double totalFormHours = 0;
      
      int col = 1;
      for (var month in allMonths) {
        final audit = auditByMonth[month];
        
        if (audit != null) {
          // Required
          final reqCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          reqCell.value = TextCellValue(audit.readinessFormsRequired.toString());
          reqCell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
          totalRequired += audit.readinessFormsRequired;
          col++;
          
          // Submitted
          final subCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          subCell.value = TextCellValue(audit.readinessFormsSubmitted.toString());
          final complianceColor = audit.readinessFormsSubmitted >= audit.readinessFormsRequired
              ? ExcelColor.fromHexString('#DCFCE7')
              : audit.readinessFormsSubmitted >= audit.readinessFormsRequired * 0.8
                  ? ExcelColor.fromHexString('#FEF9C3')
                  : ExcelColor.fromHexString('#FEE2E2');
          subCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: complianceColor,
          );
          totalSubmitted += audit.readinessFormsSubmitted;
          col++;
          
          // Rate
          final rateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          rateCell.value = TextCellValue('${audit.formComplianceRate.toStringAsFixed(1)}%');
          rateCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: _getRateColor(audit.formComplianceRate),
            fontColorHex: audit.formComplianceRate < 50 
                ? ExcelColor.white 
                : ExcelColor.black,
            bold: audit.formComplianceRate < 80,
          );
          col++;
          
          // Form Hours
          final hoursCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          hoursCell.value = TextCellValue('${audit.totalFormHours.toStringAsFixed(1)}h');
          hoursCell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
          totalFormHours += audit.totalFormHours;
          col++;
        } else {
          // No data - fill with "-"
          for (var i = 0; i < 4; i++) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: col + i, rowIndex: row))
              ..value = TextCellValue('-')
              ..cellStyle = CellStyle(
                fontColorHex: ExcelColor.fromHexString('#9CA3AF'),
                horizontalAlign: HorizontalAlign.Center,
              );
          }
          col += 4;
        }
      }
      
      // Totals
      final totalReqCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalReqCell.value = TextCellValue(totalRequired.toString());
      totalReqCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'),
      );
      col++;
      
      final totalSubCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalSubCell.value = TextCellValue(totalSubmitted.toString());
      totalSubCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'),
      );
      col++;
      
      final globalRate = totalRequired > 0 ? (totalSubmitted / totalRequired * 100) : 0.0;
      final globalRateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      globalRateCell.value = TextCellValue('${globalRate.toStringAsFixed(1)}%');
      globalRateCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: _getRateColor(globalRate),
        fontColorHex: globalRate < 50 ? ExcelColor.white : ExcelColor.black,
      );
      col++;
      
      final totalHoursCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalHoursCell.value = TextCellValue('${totalFormHours.toStringAsFixed(1)}h');
      totalHoursCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#E0E7FF'),
      );
      
      row++;
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25);
    for (var i = 1; i < headers.length; i++) {
      sheet.setColumnWidth(i, 14);
    }
  }
  
  /// Creates a punctuality comparison sheet by month
  static void _createPunctualityComparisonSheet(
    Excel excel,
    Map<String, List<TeacherAuditFull>> auditsByTeacher,
    List<String> allMonths,
  ) {
    final sheet = excel['⏰ Punctuality by Month'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#EA580C'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // Headers: Teacher | Month1 (On-Time, Late, Rate, Avg Latency) | Month2... | Totals
    final headers = ['Teacher'];
    for (var month in allMonths) {
      headers.addAll([
        '${_formatYearMonth(month)} - On-Time',
        '${_formatYearMonth(month)} - Late',
        '${_formatYearMonth(month)} - Rate %',
        '${_formatYearMonth(month)} - Avg Latency (min)',
      ]);
    }
    headers.addAll(['Total On-Time', 'Total Late', 'Overall Rate %', 'Avg Latency']);
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Data rows
    int row = 1;
    final sortedTeachers = auditsByTeacher.keys.toList()..sort();
    
    for (var teacherName in sortedTeachers) {
      final teacherAudits = auditsByTeacher[teacherName]!;
      final auditByMonth = <String, TeacherAuditFull>{};
      for (var audit in teacherAudits) {
        auditByMonth[audit.yearMonth] = audit;
      }
      
      // Teacher name
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(teacherName)
        ..cellStyle = CellStyle(bold: true);
      
      // Punctuality metrics for each month
      int totalOnTime = 0;
      int totalLate = 0;
      double totalLatency = 0;
      int monthsWithData = 0;
      
      int col = 1;
      for (var month in allMonths) {
        final audit = auditByMonth[month];
        
        if (audit != null && audit.totalClockIns > 0) {
          // On-Time
          final onTimeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          onTimeCell.value = TextCellValue(audit.onTimeClockIns.toString());
          onTimeCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: ExcelColor.fromHexString('#DCFCE7'),
          );
          totalOnTime += audit.onTimeClockIns;
          col++;
          
          // Late
          final lateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          lateCell.value = TextCellValue(audit.lateClockIns.toString());
          lateCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: audit.lateClockIns > 0
                ? ExcelColor.fromHexString('#FEE2E2')
                : ExcelColor.fromHexString('#DCFCE7'),
            fontColorHex: audit.lateClockIns > 0
                ? ExcelColor.fromHexString('#DC2626')
                : ExcelColor.black,
            bold: audit.lateClockIns > 0,
          );
          totalLate += audit.lateClockIns;
          col++;
          
          // Rate
          final rateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          rateCell.value = TextCellValue('${audit.punctualityRate.toStringAsFixed(1)}%');
          rateCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: _getRateColor(audit.punctualityRate),
            fontColorHex: audit.punctualityRate < 50 ? ExcelColor.white : ExcelColor.black,
          );
          col++;
          
          // Avg Latency
          final latencyCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          latencyCell.value = TextCellValue('${audit.avgLatencyMinutes.toStringAsFixed(1)}');
          latencyCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: audit.avgLatencyMinutes > 10
                ? ExcelColor.fromHexString('#FEE2E2')
                : audit.avgLatencyMinutes > 5
                    ? ExcelColor.fromHexString('#FEF9C3')
                    : ExcelColor.fromHexString('#DCFCE7'),
          );
          totalLatency += audit.avgLatencyMinutes;
          monthsWithData++;
          col++;
        } else {
          // No data
          for (var i = 0; i < 4; i++) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: col + i, rowIndex: row))
              ..value = TextCellValue('-')
              ..cellStyle = CellStyle(
                fontColorHex: ExcelColor.fromHexString('#9CA3AF'),
                horizontalAlign: HorizontalAlign.Center,
              );
          }
          col += 4;
        }
      }
      
      // Totals
      final totalOnTimeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalOnTimeCell.value = TextCellValue(totalOnTime.toString());
      totalOnTimeCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'),
      );
      col++;
      
      final totalLateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalLateCell.value = TextCellValue(totalLate.toString());
      totalLateCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: totalLate > 0
            ? ExcelColor.fromHexString('#FEE2E2')
            : ExcelColor.fromHexString('#DCFCE7'),
      );
      col++;
      
      final totalClockIns = totalOnTime + totalLate;
      final globalRate = totalClockIns > 0 ? (totalOnTime / totalClockIns * 100) : 0.0;
      final globalRateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      globalRateCell.value = TextCellValue('${globalRate.toStringAsFixed(1)}%');
      globalRateCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: _getRateColor(globalRate),
        fontColorHex: globalRate < 50 ? ExcelColor.white : ExcelColor.black,
      );
      col++;
      
      final avgLatencyCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      if (monthsWithData > 0) {
        avgLatencyCell.value = TextCellValue('${(totalLatency / monthsWithData).toStringAsFixed(1)}');
        avgLatencyCell.cellStyle = CellStyle(
          horizontalAlign: HorizontalAlign.Center,
          backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'),
        );
      } else {
        avgLatencyCell.value = TextCellValue('-');
      }
      
      row++;
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25);
    for (var i = 1; i < headers.length; i++) {
      sheet.setColumnWidth(i, 16);
    }
  }
  
  /// Creates a classes completion comparison sheet by month
  static void _createClassesCompletionComparisonSheet(
    Excel excel,
    Map<String, List<TeacherAuditFull>> auditsByTeacher,
    List<String> allMonths,
  ) {
    final sheet = excel['📚 Classes by Month'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#7C2D12'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // Headers: Teacher | Month1 (Scheduled, Completed, Missed, Rate) | Month2... | Totals
    final headers = ['Teacher'];
    for (var month in allMonths) {
      headers.addAll([
        '${_formatYearMonth(month)} - Scheduled',
        '${_formatYearMonth(month)} - Completed',
        '${_formatYearMonth(month)} - Missed',
        '${_formatYearMonth(month)} - Rate %',
      ]);
    }
    headers.addAll(['Total Scheduled', 'Total Completed', 'Total Missed', 'Overall Rate %']);
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Data rows
    int row = 1;
    final sortedTeachers = auditsByTeacher.keys.toList()..sort();
    
    for (var teacherName in sortedTeachers) {
      final teacherAudits = auditsByTeacher[teacherName]!;
      final auditByMonth = <String, TeacherAuditFull>{};
      for (var audit in teacherAudits) {
        auditByMonth[audit.yearMonth] = audit;
      }
      
      // Teacher name
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(teacherName)
        ..cellStyle = CellStyle(bold: true);
      
      // Class metrics for each month
      int totalScheduled = 0;
      int totalCompleted = 0;
      int totalMissed = 0;
      
      int col = 1;
      for (var month in allMonths) {
        final audit = auditByMonth[month];
        
        if (audit != null) {
          // Scheduled
          final schedCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          schedCell.value = TextCellValue(audit.totalClassesScheduled.toString());
          schedCell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
          totalScheduled += audit.totalClassesScheduled;
          col++;
          
          // Completed
          final compCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          compCell.value = TextCellValue(audit.totalClassesCompleted.toString());
          compCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: ExcelColor.fromHexString('#DCFCE7'),
          );
          totalCompleted += audit.totalClassesCompleted;
          col++;
          
          // Missed
          final missedCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          missedCell.value = TextCellValue(audit.totalClassesMissed.toString());
          missedCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: audit.totalClassesMissed > 0
                ? ExcelColor.fromHexString('#FEE2E2')
                : ExcelColor.fromHexString('#DCFCE7'),
            fontColorHex: audit.totalClassesMissed > 0
                ? ExcelColor.fromHexString('#DC2626')
                : ExcelColor.black,
            bold: audit.totalClassesMissed > 0,
          );
          totalMissed += audit.totalClassesMissed;
          col++;
          
          // Rate
          final rateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          rateCell.value = TextCellValue('${audit.completionRate.toStringAsFixed(1)}%');
          rateCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: _getRateColor(audit.completionRate),
            fontColorHex: audit.completionRate < 50 ? ExcelColor.white : ExcelColor.black,
          );
          col++;
        } else {
          // No data
          for (var i = 0; i < 4; i++) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: col + i, rowIndex: row))
              ..value = TextCellValue('-')
              ..cellStyle = CellStyle(
                fontColorHex: ExcelColor.fromHexString('#9CA3AF'),
                horizontalAlign: HorizontalAlign.Center,
              );
          }
          col += 4;
        }
      }
      
      // Totals
      final totalSchedCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalSchedCell.value = TextCellValue(totalScheduled.toString());
      totalSchedCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'),
      );
      col++;
      
      final totalCompCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalCompCell.value = TextCellValue(totalCompleted.toString());
      totalCompCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#DCFCE7'),
      );
      col++;
      
      final totalMissedCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalMissedCell.value = TextCellValue(totalMissed.toString());
      totalMissedCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: totalMissed > 0
            ? ExcelColor.fromHexString('#FEE2E2')
            : ExcelColor.fromHexString('#DCFCE7'),
        fontColorHex: totalMissed > 0 ? ExcelColor.fromHexString('#DC2626') : ExcelColor.black,
      );
      col++;
      
      final globalRate = totalScheduled > 0 ? (totalCompleted / totalScheduled * 100) : 0.0;
      final globalRateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      globalRateCell.value = TextCellValue('${globalRate.toStringAsFixed(1)}%');
      globalRateCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: _getRateColor(globalRate),
        fontColorHex: globalRate < 50 ? ExcelColor.white : ExcelColor.black,
      );
      
      row++;
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25);
    for (var i = 1; i < headers.length; i++) {
      sheet.setColumnWidth(i, 14);
    }
  }
  
  /// Creates an academic metrics comparison sheet by month
  static void _createAcademicMetricsComparisonSheet(
    Excel excel,
    Map<String, List<TeacherAuditFull>> auditsByTeacher,
    List<String> allMonths,
  ) {
    final sheet = excel['📖 Academic by Month'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#1E40AF'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // Headers: Teacher | Month1 (Quizzes, Assignments, Meetings Missed, Overdue Tasks) | Month2... | Totals
    final headers = ['Teacher'];
    for (var month in allMonths) {
      headers.addAll([
        '${_formatYearMonth(month)} - Quizzes',
        '${_formatYearMonth(month)} - Assignments',
        '${_formatYearMonth(month)} - Meetings Missed',
        '${_formatYearMonth(month)} - Overdue Tasks',
      ]);
    }
    headers.addAll(['Total Quizzes', 'Total Assignments', 'Total Meetings Missed', 'Total Overdue Tasks']);
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Data rows
    int row = 1;
    final sortedTeachers = auditsByTeacher.keys.toList()..sort();
    
    for (var teacherName in sortedTeachers) {
      final teacherAudits = auditsByTeacher[teacherName]!;
      final auditByMonth = <String, TeacherAuditFull>{};
      for (var audit in teacherAudits) {
        auditByMonth[audit.yearMonth] = audit;
      }
      
      // Teacher name
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(teacherName)
        ..cellStyle = CellStyle(bold: true);
      
      // Academic metrics for each month
      int totalQuizzes = 0;
      int totalAssignments = 0;
      int totalMeetingsMissed = 0;
      int totalOverdueTasks = 0;
      
      int col = 1;
      for (var month in allMonths) {
        final audit = auditByMonth[month];
        
        if (audit != null) {
          // Quizzes
          final quizCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          quizCell.value = TextCellValue(audit.quizzesGiven.toString());
          quizCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: audit.quizzesGiven > 0
                ? ExcelColor.fromHexString('#DCFCE7')
                : ExcelColor.fromHexString('#FEE2E2'),
          );
          totalQuizzes += audit.quizzesGiven;
          col++;
          
          // Assignments
          final assignCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          assignCell.value = TextCellValue(audit.assignmentsGiven.toString());
          assignCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: audit.assignmentsGiven > 0
                ? ExcelColor.fromHexString('#DCFCE7')
                : ExcelColor.fromHexString('#FEE2E2'),
          );
          totalAssignments += audit.assignmentsGiven;
          col++;
          
          // Meetings Missed
          final meetingsCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          meetingsCell.value = TextCellValue(audit.staffMeetingsMissed.toString());
          meetingsCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: audit.staffMeetingsMissed > 0
                ? ExcelColor.fromHexString('#FEE2E2')
                : ExcelColor.fromHexString('#DCFCE7'),
            fontColorHex: audit.staffMeetingsMissed > 0
                ? ExcelColor.fromHexString('#DC2626')
                : ExcelColor.black,
            bold: audit.staffMeetingsMissed > 0,
          );
          totalMeetingsMissed += audit.staffMeetingsMissed;
          col++;
          
          // Overdue Tasks
          final tasksCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
          tasksCell.value = TextCellValue(audit.overdueTasks.toString());
          tasksCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: audit.overdueTasks > 0
                ? ExcelColor.fromHexString('#FEE2E2')
                : ExcelColor.fromHexString('#DCFCE7'),
            fontColorHex: audit.overdueTasks > 0
                ? ExcelColor.fromHexString('#DC2626')
                : ExcelColor.black,
            bold: audit.overdueTasks > 0,
          );
          totalOverdueTasks += audit.overdueTasks;
          col++;
        } else {
          // No data
          for (var i = 0; i < 4; i++) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: col + i, rowIndex: row))
              ..value = TextCellValue('-')
              ..cellStyle = CellStyle(
                fontColorHex: ExcelColor.fromHexString('#9CA3AF'),
                horizontalAlign: HorizontalAlign.Center,
              );
          }
          col += 4;
        }
      }
      
      // Totals
      final totalQuizCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalQuizCell.value = TextCellValue(totalQuizzes.toString());
      totalQuizCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'),
      );
      col++;
      
      final totalAssignCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalAssignCell.value = TextCellValue(totalAssignments.toString());
      totalAssignCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'),
      );
      col++;
      
      final totalMeetingsCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalMeetingsCell.value = TextCellValue(totalMeetingsMissed.toString());
      totalMeetingsCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: totalMeetingsMissed > 0
            ? ExcelColor.fromHexString('#FEE2E2')
            : ExcelColor.fromHexString('#DCFCE7'),
        fontColorHex: totalMeetingsMissed > 0 ? ExcelColor.fromHexString('#DC2626') : ExcelColor.black,
      );
      col++;
      
      final totalTasksCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      totalTasksCell.value = TextCellValue(totalOverdueTasks.toString());
      totalTasksCell.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: totalOverdueTasks > 0
            ? ExcelColor.fromHexString('#FEE2E2')
            : ExcelColor.fromHexString('#DCFCE7'),
        fontColorHex: totalOverdueTasks > 0 ? ExcelColor.fromHexString('#DC2626') : ExcelColor.black,
      );
      
      row++;
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25);
    for (var i = 1; i < headers.length; i++) {
      sheet.setColumnWidth(i, 18);
    }
  }
  
  /// Creates an extended pivot sheet with ALL key metrics in one comprehensive view
  static void _createExtendedPivotSheet(
    Excel excel,
    Map<String, List<TeacherAuditFull>> auditsByTeacher,
    List<String> allMonths,
  ) {
    final sheet = excel['📊 Complete Monthly View'];
    
    // Styles
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final monthHeaderStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    final metricHeaderStyle = CellStyle(
      bold: true,
      fontSize: 9,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#3B82F6'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // Title
    final totalCols = 2 + (allMonths.length * 12); // Teacher + Email + 12 metrics per month
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 0));
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('📊 COMPREHENSIVE VIEW - ALL METRICS BY MONTH');
    titleCell.cellStyle = titleStyle;
    
    // 12 metrics per month: Score, Tier, Hours, Classes, Completed, Missed, Forms Req, Forms Sub, Form Rate, Late, Punctuality, Payment
    final metricsPerMonth = [
      'Score', 'Tier', 'Hours', 'Classes', 'Completed', 'Missed',
      'Forms Req', 'Forms Sub', 'Form %', 'Late', 'Punct %', 'Payment'
    ];
    
    // Row 2: Month headers (merged across 12 columns each)
    // Row 3: Metric headers
    int colOffset = 2; // Start after Teacher and Email columns
    
      // Fixed headers
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
        ..value = TextCellValue('Teacher')
        ..cellStyle = metricHeaderStyle;
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2))
      ..value = TextCellValue('Email')
      ..cellStyle = metricHeaderStyle;
    
    for (var monthIdx = 0; monthIdx < allMonths.length; monthIdx++) {
      final month = allMonths[monthIdx];
      final startCol = colOffset + (monthIdx * metricsPerMonth.length);
      final endCol = startCol + metricsPerMonth.length - 1;
      
      // Merge month header
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: 1),
      );
      
      final monthCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol, rowIndex: 1));
      monthCell.value = TextCellValue(_formatYearMonth(month));
      monthCell.cellStyle = monthHeaderStyle;
      
      // Metric sub-headers
      for (var metricIdx = 0; metricIdx < metricsPerMonth.length; metricIdx++) {
        final metricCell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: startCol + metricIdx, 
          rowIndex: 2,
        ));
        metricCell.value = TextCellValue(metricsPerMonth[metricIdx]);
        metricCell.cellStyle = metricHeaderStyle;
      }
    }
    
    // Data rows
    int row = 3;
    final sortedTeachers = auditsByTeacher.keys.toList()..sort();
    
    for (var teacherName in sortedTeachers) {
      final teacherAudits = auditsByTeacher[teacherName]!;
      final auditByMonth = <String, TeacherAuditFull>{};
      for (var audit in teacherAudits) {
        auditByMonth[audit.yearMonth] = audit;
      }
      
      // Teacher name and email
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(teacherName)
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'));
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        ..value = TextCellValue(teacherAudits.first.teacherEmail);
      
      // Fill data for each month
      for (var monthIdx = 0; monthIdx < allMonths.length; monthIdx++) {
        final month = allMonths[monthIdx];
        final startCol = colOffset + (monthIdx * metricsPerMonth.length);
        final audit = auditByMonth[month];
        
        if (audit != null) {
          int metricIdx = 0;
          
          // Score
          final scoreCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          scoreCell.value = TextCellValue('${audit.overallScore.toStringAsFixed(1)}');
          scoreCell.cellStyle = CellStyle(
            backgroundColorHex: _getTierColor(audit.performanceTier),
            fontColorHex: ExcelColor.white,
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
          metricIdx++;
          
          // Tier
          final tierCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          tierCell.value = TextCellValue(_formatTierShort(audit.performanceTier));
          tierCell.cellStyle = CellStyle(
            backgroundColorHex: _getTierColor(audit.performanceTier),
            fontColorHex: ExcelColor.white,
            horizontalAlign: HorizontalAlign.Center,
          );
          metricIdx++;
          
          // Hours
          final hoursCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          hoursCell.value = TextCellValue('${audit.totalWorkedHours.toStringAsFixed(1)}');
          hoursCell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
          metricIdx++;
          
          // Classes scheduled
          final classesCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          classesCell.value = TextCellValue(audit.totalClassesScheduled.toString());
          classesCell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
          metricIdx++;
          
          // Classes completed
          final completedCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          completedCell.value = TextCellValue(audit.totalClassesCompleted.toString());
          completedCell.cellStyle = CellStyle(
            backgroundColorHex: _getRateColor(audit.completionRate),
            horizontalAlign: HorizontalAlign.Center,
          );
          metricIdx++;
          
          // Classes missed
          final missedCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          missedCell.value = TextCellValue(audit.totalClassesMissed.toString());
          missedCell.cellStyle = CellStyle(
            backgroundColorHex: audit.totalClassesMissed > 0
                ? ExcelColor.fromHexString('#FEE2E2')
                : ExcelColor.fromHexString('#DCFCE7'),
            fontColorHex: audit.totalClassesMissed > 0
                ? ExcelColor.fromHexString('#DC2626')
                : ExcelColor.black,
            horizontalAlign: HorizontalAlign.Center,
            bold: audit.totalClassesMissed > 0,
          );
          metricIdx++;
          
          // Forms Required
          final formsReqCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          formsReqCell.value = TextCellValue(audit.readinessFormsRequired.toString());
          formsReqCell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
          metricIdx++;
          
          // Forms Submitted
          final formsSubCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          formsSubCell.value = TextCellValue(audit.readinessFormsSubmitted.toString());
          formsSubCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: audit.readinessFormsSubmitted >= audit.readinessFormsRequired
                ? ExcelColor.fromHexString('#DCFCE7')
                : ExcelColor.fromHexString('#FEE2E2'),
          );
          metricIdx++;
          
          // Form Compliance Rate
          final formRateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          formRateCell.value = TextCellValue('${audit.formComplianceRate.toStringAsFixed(0)}%');
          formRateCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: _getRateColor(audit.formComplianceRate),
            fontColorHex: audit.formComplianceRate < 50 ? ExcelColor.white : ExcelColor.black,
            bold: audit.formComplianceRate < 80,
          );
          metricIdx++;
          
          // Late Clock-ins
          final lateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          lateCell.value = TextCellValue(audit.lateClockIns.toString());
          lateCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: audit.lateClockIns > 0
                ? ExcelColor.fromHexString('#FEE2E2')
                : ExcelColor.fromHexString('#DCFCE7'),
            fontColorHex: audit.lateClockIns > 0
                ? ExcelColor.fromHexString('#DC2626')
                : ExcelColor.black,
            bold: audit.lateClockIns > 0,
          );
          metricIdx++;
          
          // Punctuality Rate
          final punctCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          punctCell.value = TextCellValue('${audit.punctualityRate.toStringAsFixed(0)}%');
          punctCell.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
            backgroundColorHex: _getRateColor(audit.punctualityRate),
            fontColorHex: audit.punctualityRate < 50 ? ExcelColor.white : ExcelColor.black,
          );
          metricIdx++;
          
          // Payment
          final paymentCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + metricIdx, rowIndex: row));
          paymentCell.value = TextCellValue('\$${audit.paymentSummary?.totalNetPayment.toStringAsFixed(0) ?? '0'}');
          paymentCell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#DCFCE7'),
            fontColorHex: ExcelColor.fromHexString('#166534'),
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        } else {
          // No data - fill with "-"
          for (var i = 0; i < metricsPerMonth.length; i++) {
            final emptyCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: startCol + i, rowIndex: row));
            emptyCell.value = TextCellValue('-');
            emptyCell.cellStyle = CellStyle(
              fontColorHex: ExcelColor.fromHexString('#9CA3AF'),
              horizontalAlign: HorizontalAlign.Center,
            );
          }
        }
      }
      
      row++;
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25); // Teacher name
    sheet.setColumnWidth(1, 28); // Email
    for (var i = 0; i < allMonths.length * metricsPerMonth.length; i++) {
      sheet.setColumnWidth(i + 2, 10);
    }
  }
  
  /// Create individual sheets per teacher with monthly breakdown
  static void _createTeacherDetailSheets(Excel excel, Map<String, List<TeacherAuditFull>> auditsByTeacher) {
    // Limit to first 10 teachers to avoid too many sheets
    var count = 0;
    for (var entry in auditsByTeacher.entries) {
      if (count >= 10) break;
      count++;
      
      final teacherName = entry.key;
      final audits = entry.value;
      
      // Sanitize sheet name (max 31 chars, no special chars)
      final sheetName = '👤 ${teacherName.length > 25 ? teacherName.substring(0, 25) : teacherName}'
          .replaceAll(RegExp(r'[\\/*?\[\]:]'), '');
      
      final sheet = excel[sheetName];
      
      // Header
      final headerStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('#673AB7'),
      );
      
      // Title
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('H1'));
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('$teacherName - Performance History');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('#673AB7'),
      );
      
      // Headers for monthly data
      final headers = ['Month', 'Score', 'Tier', 'Classes', 'Completed', 'Hours', 'Net Pay', 'Forms'];
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }
      
      // Data rows
      for (var rowIdx = 0; rowIdx < audits.length; rowIdx++) {
        final audit = audits[rowIdx];
        final row = rowIdx + 3;
        
        final data = [
          _formatYearMonth(audit.yearMonth),
          '${audit.overallScore.toStringAsFixed(1)}/10',
          _formatTier(audit.performanceTier),
          audit.totalClassesScheduled.toString(),
          audit.totalClassesCompleted.toString(),
          '${audit.totalWorkedHours.toStringAsFixed(1)}h',
          '\$${audit.paymentSummary?.totalNetPayment.toStringAsFixed(2) ?? '0.00'}',
          '${audit.detailedForms.length}',
        ];
        
        final tierColor = _getTierColor(audit.performanceTier);
        
        for (var colIdx = 0; colIdx < data.length; colIdx++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
          cell.value = TextCellValue(data[colIdx]);
          
          if (colIdx == 1 || colIdx == 2) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: tierColor,
              fontColorHex: ExcelColor.white,
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          }
        }
      }
      
      // Set column widths
      sheet.setColumnWidth(0, 15); // Month
      sheet.setColumnWidth(1, 10); // Score
      sheet.setColumnWidth(2, 12); // Tier
      sheet.setColumnWidth(3, 10); // Classes
      sheet.setColumnWidth(4, 12); // Completed
      sheet.setColumnWidth(5, 10); // Hours
      sheet.setColumnWidth(6, 12); // Net Pay
      sheet.setColumnWidth(7, 8); // Forms
    }
  }
  
  /// Sheet 1: Summary - Overview of all teachers
  /// Now with teacher grouping information
  static void _createSummarySheet(
    Excel excel, 
    List<TeacherAuditFull> audits, 
    String yearMonth,
    [Map<String, List<TeacherAuditFull>>? auditsByTeacher]
  ) {
    final sheet = excel['📊 Summary'];
    
    // Determine unique months for multi-month exports
    final uniqueMonths = audits.map((a) => a.yearMonth).toSet().toList()..sort();
    final monthRange = uniqueMonths.length > 1 
        ? '${_formatYearMonth(uniqueMonths.last)} to ${_formatYearMonth(uniqueMonths.first)}'
        : _formatYearMonth(yearMonth);
    
    // Title row
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#0078D4'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('M1'));
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('Teacher Audit Report - $monthRange');
    titleCell.cellStyle = titleStyle;
    
    // Subtitle with stats
    if (auditsByTeacher != null) {
      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('M2'));
      final subtitleCell = sheet.cell(CellIndex.indexByString('A2'));
      subtitleCell.value = TextCellValue(
        '${auditsByTeacher.length} Teachers | ${uniqueMonths.length} Month(s) | ${audits.length} Total Records'
      );
      subtitleCell.cellStyle = CellStyle(
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#666666'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }
    
    // Header row (row 3 if subtitle exists, row 2 otherwise)
    final headerRow = auditsByTeacher != null ? 3 : 2;
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#2D5A8A'),
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // Add Month column for multi-month exports
    final isMultiMonthExport = uniqueMonths.length > 1;
    final headers = isMultiMonthExport
        ? ['Month', 'Teacher Name', 'Email', 'Department', 'Score', 'Tier', 'Status',
           'Classes', 'Completed', 'Missed', 'Hours Worked', 'Net Payment', 'Issues']
        : ['Teacher Name', 'Email', 'Department', 'Score', 'Tier', 'Status',
           'Classes', 'Completed', 'Missed', 'Hours Worked', 'Net Payment', 'Issues'];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Sort audits by teacher name, then by month (descending)
    final sortedAudits = List<TeacherAuditFull>.from(audits)
      ..sort((a, b) {
        final nameCompare = a.teacherName.compareTo(b.teacherName);
        if (nameCompare != 0) return nameCompare;
        return b.yearMonth.compareTo(a.yearMonth);
      });
    
    // Data rows with conditional formatting
    for (var rowIdx = 0; rowIdx < sortedAudits.length; rowIdx++) {
      final audit = sortedAudits[rowIdx];
      final row = rowIdx + headerRow + 1;
      
      // Get tier color
      final tierColor = _getTierColor(audit.performanceTier);
      final rowStyle = CellStyle(
        backgroundColorHex: rowIdx % 2 == 0 
            ? ExcelColor.fromHexString('#F5F5F5') 
            : ExcelColor.white,
      );
      
      // Department
      final department = audit.hoursTaughtBySubject.keys.isNotEmpty
          ? audit.hoursTaughtBySubject.keys.first
          : 'N/A';
      
      // Build data row based on whether we have multi-month export
      final data = isMultiMonthExport
          ? [
              _formatYearMonth(audit.yearMonth),
              audit.teacherName,
              audit.teacherEmail,
              department,
              '${audit.overallScore.toStringAsFixed(1)}/10',
              _formatTier(audit.performanceTier),
              _formatStatus(audit.status),
              audit.totalClassesScheduled.toString(),
              audit.totalClassesCompleted.toString(),
              audit.totalClassesMissed.toString(),
              '${audit.totalWorkedHours.toStringAsFixed(1)}h',
              '\$${audit.paymentSummary?.totalNetPayment.toStringAsFixed(2) ?? '0.00'}',
              audit.issues.length.toString(),
            ]
          : [
              audit.teacherName,
              audit.teacherEmail,
              department,
              '${audit.overallScore.toStringAsFixed(1)}/10',
              _formatTier(audit.performanceTier),
              _formatStatus(audit.status),
              audit.totalClassesScheduled.toString(),
              audit.totalClassesCompleted.toString(),
              audit.totalClassesMissed.toString(),
              '${audit.totalWorkedHours.toStringAsFixed(1)}h',
              '\$${audit.paymentSummary?.totalNetPayment.toStringAsFixed(2) ?? '0.00'}',
              audit.issues.length.toString(),
            ];
      
      // Adjust column indices for multi-month export
      final scoreCol = isMultiMonthExport ? 4 : 3;
      final tierCol = isMultiMonthExport ? 5 : 4;
      final missedCol = isMultiMonthExport ? 9 : 8;
      final issuesCol = isMultiMonthExport ? 12 : 11;
      
      for (var colIdx = 0; colIdx < data.length; colIdx++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
        cell.value = TextCellValue(data[colIdx]);
        
        // Apply conditional coloring for score and tier
        if (colIdx == scoreCol) { // Score column
          cell.cellStyle = CellStyle(
            backgroundColorHex: tierColor,
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        } else if (colIdx == tierCol) { // Tier column
          cell.cellStyle = CellStyle(
            backgroundColorHex: tierColor,
            fontColorHex: ExcelColor.white,
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        } else if (colIdx == missedCol && audit.totalClassesMissed > 0) { // Missed classes
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#FFE0E0'),
            fontColorHex: ExcelColor.fromHexString('#D32F2F'),
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        } else if (colIdx == issuesCol && audit.issues.isNotEmpty) { // Issues
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
            fontColorHex: ExcelColor.fromHexString('#E65100'),
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        } else {
          cell.cellStyle = rowStyle;
        }
      }
    }
    
    // Set column widths (adjust for multi-month)
    if (isMultiMonthExport) {
      sheet.setColumnWidth(0, 15); // Month
      sheet.setColumnWidth(1, 25); // Teacher Name
      sheet.setColumnWidth(2, 30); // Email
      sheet.setColumnWidth(3, 15); // Department
      sheet.setColumnWidth(4, 12); // Score
      sheet.setColumnWidth(5, 15); // Tier
      sheet.setColumnWidth(6, 15); // Status
      sheet.setColumnWidth(7, 10); // Classes
      sheet.setColumnWidth(8, 12); // Completed
      sheet.setColumnWidth(9, 10); // Missed
      sheet.setColumnWidth(10, 14); // Hours
      sheet.setColumnWidth(11, 14); // Payment
      sheet.setColumnWidth(12, 10); // Issues
    } else {
      sheet.setColumnWidth(0, 25); // Teacher Name
      sheet.setColumnWidth(1, 30); // Email
      sheet.setColumnWidth(2, 15); // Department
      sheet.setColumnWidth(3, 12); // Score
      sheet.setColumnWidth(4, 15); // Tier
      sheet.setColumnWidth(5, 15); // Status
      sheet.setColumnWidth(6, 10); // Classes
      sheet.setColumnWidth(7, 12); // Completed
      sheet.setColumnWidth(8, 10); // Missed
      sheet.setColumnWidth(9, 14); // Hours
      sheet.setColumnWidth(10, 14); // Payment
      sheet.setColumnWidth(11, 10); // Issues
    }
  }
  
  /// Sheet 2: Detailed Metrics
  static void _createDetailedMetricsSheet(Excel excel, List<TeacherAuditFull> audits) {
    final sheet = excel['📈 Metrics'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
    );
    
    final headers = [
      'Teacher', 'Scheduled Hours', 'Worked Hours', 'Form Hours',
      'Completion Rate', 'Punctuality Rate', 'Form Compliance',
      'On-Time Clock-ins', 'Late Clock-ins', 'Avg Latency (min)',
      'Forms Required', 'Forms Submitted'
    ];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    for (var rowIdx = 0; rowIdx < audits.length; rowIdx++) {
      final audit = audits[rowIdx];
      final row = rowIdx + 1;
      
      final data = [
        audit.teacherName,
        audit.totalScheduledHours.toStringAsFixed(1),
        audit.totalWorkedHours.toStringAsFixed(1),
        audit.totalFormHours.toStringAsFixed(1),
        '${audit.completionRate.toStringAsFixed(1)}%',
        '${audit.punctualityRate.toStringAsFixed(1)}%',
        '${audit.formComplianceRate.toStringAsFixed(1)}%',
        audit.onTimeClockIns.toString(),
        audit.lateClockIns.toString(),
        audit.avgLatencyMinutes.toStringAsFixed(1),
        audit.readinessFormsRequired.toString(),
        audit.readinessFormsSubmitted.toString(),
      ];
      
      for (var colIdx = 0; colIdx < data.length; colIdx++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
        cell.value = TextCellValue(data[colIdx]);
        
        // Color code rates
        if (colIdx >= 4 && colIdx <= 6) {
          final value = double.tryParse(data[colIdx].replaceAll('%', '')) ?? 0;
          cell.cellStyle = CellStyle(
            backgroundColorHex: _getRateColor(value),
            horizontalAlign: HorizontalAlign.Center,
          );
        }
      }
    }
    
    // Set column widths
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 0 ? 25 : 15);
    }
  }
  
  /// Sheet 3: Payment Details
  static void _createPaymentSheet(Excel excel, List<TeacherAuditFull> audits) {
    final sheet = excel['💰 Payments'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#FF9800'),
    );
    
    final headers = [
      'Teacher', 'Subject', 'Hours', 'Hourly Rate', 'Gross Pay',
      'Penalties', 'Bonuses', 'Net Pay', 'Global Adjustment', 'Individual Shift Adjustments', 'Adjustment Reason', 'Final Pay'
    ];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    var row = 1;
    for (var audit in audits) {
      if (audit.paymentSummary == null) continue;
      
      final payment = audit.paymentSummary!;
      
      // If has subject-level payments
      if (payment.paymentsBySubject.isNotEmpty) {
        for (var entry in payment.paymentsBySubject.entries) {
          final subjectPay = entry.value;
          
          // Calculate total individual shift adjustments for this teacher
          final shiftAdjustmentsTotal = payment.shiftPaymentAdjustments.values.fold(0.0, (sum, adj) => sum + adj);
          
          final data = [
            audit.teacherName,
            entry.key,
            subjectPay.hoursTaught.toStringAsFixed(1),
            '\$${subjectPay.hourlyRate.toStringAsFixed(2)}',
            '\$${subjectPay.grossAmount.toStringAsFixed(2)}',
            '\$${subjectPay.penalties.toStringAsFixed(2)}',
            '\$${subjectPay.bonuses.toStringAsFixed(2)}',
            '\$${subjectPay.netAmount.toStringAsFixed(2)}',
            '\$${payment.adminAdjustment.toStringAsFixed(2)}',
            shiftAdjustmentsTotal != 0 
                ? '\$${shiftAdjustmentsTotal.toStringAsFixed(2)} (${payment.shiftPaymentAdjustments.length} shifts)'
                : 'None',
            payment.adjustmentReason,
            '\$${payment.totalNetPayment.toStringAsFixed(2)}',
          ];
          
          for (var colIdx = 0; colIdx < data.length; colIdx++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
            cell.value = TextCellValue(data[colIdx]);
            
            // Color penalties red
            if (colIdx == 5 && subjectPay.penalties > 0) {
              cell.cellStyle = CellStyle(
                fontColorHex: ExcelColor.fromHexString('#D32F2F'),
                bold: true,
              );
            }
            // Color bonuses green
            if (colIdx == 6 && subjectPay.bonuses > 0) {
              cell.cellStyle = CellStyle(
                fontColorHex: ExcelColor.fromHexString('#4CAF50'),
                bold: true,
              );
            }
            // Color global adjustment
            if (colIdx == 8 && payment.adminAdjustment != 0) {
              cell.cellStyle = CellStyle(
                fontColorHex: payment.adminAdjustment > 0 
                    ? ExcelColor.fromHexString('#4CAF50')
                    : ExcelColor.fromHexString('#D32F2F'),
                bold: true,
              );
            }
            // Color individual shift adjustments
            if (colIdx == 9 && shiftAdjustmentsTotal != 0) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
                fontColorHex: ExcelColor.fromHexString('#1976D2'),
                bold: true,
              );
            }
            // Color final pay green
            if (colIdx == 11) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
                fontColorHex: ExcelColor.fromHexString('#2E7D32'),
                bold: true,
              );
            }
          }
          row++;
        }
      } else {
        // Summary row only
        final shiftAdjustmentsTotal = payment.shiftPaymentAdjustments.values.fold(0.0, (sum, adj) => sum + adj);
        
        final data = [
          audit.teacherName,
          'All Subjects',
          audit.totalWorkedHours.toStringAsFixed(1),
          '-',
          '\$${payment.totalGrossPayment.toStringAsFixed(2)}',
          '\$${payment.totalPenalties.toStringAsFixed(2)}',
          '\$${payment.totalBonuses.toStringAsFixed(2)}',
          '\$${(payment.totalGrossPayment - payment.totalPenalties + payment.totalBonuses).toStringAsFixed(2)}',
          '\$${payment.adminAdjustment.toStringAsFixed(2)}',
          shiftAdjustmentsTotal != 0 
              ? '\$${shiftAdjustmentsTotal.toStringAsFixed(2)} (${payment.shiftPaymentAdjustments.length} shifts)'
              : 'None',
          payment.adjustmentReason,
          '\$${payment.totalNetPayment.toStringAsFixed(2)}',
        ];
        
        for (var colIdx = 0; colIdx < data.length; colIdx++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
          cell.value = TextCellValue(data[colIdx]);
          
          // Color individual shift adjustments
          if (colIdx == 9 && shiftAdjustmentsTotal != 0) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
              fontColorHex: ExcelColor.fromHexString('#1976D2'),
              bold: true,
            );
          }
        }
        
      }
    }
    
    // Total row
    final totalGross = audits.fold(0.0, (sum, a) => sum + (a.paymentSummary?.totalGrossPayment ?? 0));
    final totalPenalties = audits.fold(0.0, (sum, a) => sum + (a.paymentSummary?.totalPenalties ?? 0));
    final totalNet = audits.fold(0.0, (sum, a) => sum + (a.paymentSummary?.totalNetPayment ?? 0));
    
    row++;
    final totalStyle = CellStyle(
      bold: true,
      fontSize: 12,
      backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
    );
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue('TOTAL')
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
      ..value = TextCellValue('\$${totalGross.toStringAsFixed(2)}')
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
      ..value = TextCellValue('\$${totalPenalties.toStringAsFixed(2)}')
      ..cellStyle = totalStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row))
      ..value = TextCellValue('\$${totalNet.toStringAsFixed(2)}')
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
        fontColorHex: ExcelColor.white,
      );
    
    // Set column widths
    sheet.setColumnWidth(0, 25); // Teacher
    sheet.setColumnWidth(1, 15); // Subject
    sheet.setColumnWidth(2, 10); // Hours
    sheet.setColumnWidth(3, 12); // Hourly Rate
    sheet.setColumnWidth(4, 12); // Gross Pay
    sheet.setColumnWidth(5, 12); // Penalties
    sheet.setColumnWidth(6, 12); // Bonuses
    sheet.setColumnWidth(7, 12); // Net Pay
    sheet.setColumnWidth(8, 18); // Global Adjustment
    sheet.setColumnWidth(9, 30); // Individual Shift Adjustments
    sheet.setColumnWidth(10, 25); // Adjustment Reason
    sheet.setColumnWidth(11, 14); // Final Pay
  }
  
  /// Sheet 4: Individual Shift Payment Details
  static void _createShiftPaymentDetailsSheet(Excel excel, List<TeacherAuditFull> audits) {
    final sheet = excel['💵 Shift Payments'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#FF6B35'),
    );
    
    final headers = [
      'Teacher', 'Shift ID', 'Date', 'Subject', 'Status',
      'Scheduled Hours', 'Worked Hours (TS)', 'Form Hours',
      'Has Form', 'Payment Source', 'Base Amount',
      'Manual Adjustment', 'Final Payment', 'Hourly Rate'
    ];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    var row = 1;
    for (var audit in audits) {
      if (audit.detailedShifts.isEmpty) continue;
      
      // Get adjustments map
      final adjustments = audit.paymentSummary?.shiftPaymentAdjustments ?? {};
      
      // Build a map of shiftId -> form info (and by last-8-chars suffix for ID mismatch fallback)
      final shiftForms = <String, Map<String, dynamic>>{};
      final shiftFormsBySuffix = <String, Map<String, dynamic>>{};
      for (var form in audit.detailedForms) {
        final sid = form['shiftId'] as String?;
        if (sid == null || sid.isEmpty) continue;
        shiftForms[sid] = form;
        if (sid.length >= 8) shiftFormsBySuffix[sid.substring(sid.length - 8)] = form;
      }
      // Map shiftId -> timesheet (and by suffix) for worked hours / payment
      final timesheetByShiftId = <String, Map<String, dynamic>>{};
      final timesheetBySuffix = <String, Map<String, dynamic>>{};
      for (var ts in audit.detailedTimesheets) {
        final tsMap = ts as Map<String, dynamic>;
        final sid = tsMap['shift_id'] as String? ?? tsMap['shiftId'] as String?;
        if (sid != null && sid.isNotEmpty) {
          timesheetByShiftId[sid] = tsMap;
          if (sid.length >= 8) timesheetBySuffix[sid.substring(sid.length - 8)] = tsMap;
        }
      }
      
      // Get shift payments from detailedShifts (if available) or calculate
      for (var shiftData in audit.detailedShifts) {
        final shiftId = shiftData['id'] as String? ?? '';
        if (shiftId.isEmpty) continue;
        
        final shiftStart = (shiftData['start'] as Timestamp?)?.toDate();
        final status = shiftData['status'] as String? ?? 'unknown';
        final subject = shiftData['subject_display_name'] as String? ?? 
                       shiftData['subject'] as String? ?? 'N/A';
        
        // Scheduled hours from duration (minutes or hours)
        final scheduledMinutes = (shiftData['duration_minutes'] as num?)?.toDouble() ?? 0;
        final durationHours = (shiftData['duration'] as num?)?.toDouble() ?? 0;
        final scheduledHours = scheduledMinutes > 0 ? scheduledMinutes / 60.0 : durationHours;
        
        final timesheetEntry = timesheetByShiftId[shiftId] ?? (shiftId.length >= 8 ? timesheetBySuffix[shiftId.substring(shiftId.length - 8)] : null) ?? <String, dynamic>{};
        // Worked hours = same as "Total Worked" in Shift Details: clock_in to effective_end/clock_out, capped at shift end
        double workedHours = 0;
        if (timesheetEntry.isNotEmpty) {
          final clockInRaw = timesheetEntry['clock_in_time'] ?? timesheetEntry['clock_in_timestamp'] ?? timesheetEntry['clockIn'];
          final clockOutRaw = timesheetEntry['effective_end_timestamp'] ?? timesheetEntry['clock_out_time'] ?? timesheetEntry['clock_out_timestamp'] ?? timesheetEntry['clockOut'];
          final shiftEndDt = (shiftData['end'] as Timestamp?)?.toDate();
          final shiftStartDt = (shiftData['start'] as Timestamp?)?.toDate();
          if (clockInRaw != null && clockOutRaw != null && clockInRaw is Timestamp && clockOutRaw is Timestamp) {
            DateTime start = (clockInRaw as Timestamp).toDate();
            DateTime end = (clockOutRaw as Timestamp).toDate();
            if (shiftEndDt != null && end.isAfter(shiftEndDt)) end = shiftEndDt;
            if (shiftStartDt != null && start.isBefore(shiftStartDt)) start = shiftStartDt;
            final dur = end.difference(start);
            if (!dur.isNegative) workedHours = dur.inSeconds / 3600.0;
          }
          if (workedHours <= 0) {
            final mins = (timesheetEntry['worked_minutes'] as num?)?.toDouble() ?? (timesheetEntry['workedMinutes'] as num?)?.toDouble();
            if (mins != null && mins > 0) workedHours = mins / 60.0;
          }
        }
        if (workedHours <= 0 && (status.toString().toLowerCase().contains('completed') || status.toString().toLowerCase().contains('fully') || status.toString().toLowerCase().contains('partially'))) {
          workedHours = scheduledHours;
        }
        
        // Get form info (try exact shiftId then suffix match)
        final formData = shiftForms[shiftId] ?? (shiftId.length >= 8 ? shiftFormsBySuffix[shiftId.substring(shiftId.length - 8)] : null);
        final hasForm = formData != null;
        final formHours = formData != null
            ? ((formData['durationHours'] as num?)?.toDouble() ?? 0)
            : 0.0;
        
        // Determine payment source
        String paymentSource = 'None';
        double baseAmount = 0.0;
        
        if (timesheetEntry.isNotEmpty) {
          final paymentAmount = (timesheetEntry['payment_amount'] as num?)?.toDouble() ?? 0;
          final totalPay = (timesheetEntry['total_pay'] as num?)?.toDouble() ?? 0;
          if (paymentAmount > 0 || totalPay > 0) {
            paymentSource = 'Timesheet';
            baseAmount = paymentAmount > 0 ? paymentAmount : totalPay;
          }
        }
        
        // If no timesheet payment, check form
        if (baseAmount == 0 && hasForm && formHours > 0) {
          final hourlyRate = (shiftData['hourly_rate'] as num?)?.toDouble() ?? 0;
          if (hourlyRate > 0) {
            paymentSource = 'Form Duration';
            baseAmount = formHours * hourlyRate;
          }
        }
        
        // If still no payment and shift has no form, it's orphan
        if (!hasForm) {
          paymentSource = 'Orphan (No Form)';
          baseAmount = 0.0;
        }
        
        // Get manual adjustment
        final adjustment = adjustments[shiftId] ?? 0.0;
        final finalPayment = baseAmount + adjustment;
        
        // Get hourly rate
        final hourlyRate = (shiftData['hourly_rate'] as num?)?.toDouble() ?? 0;
        
        final data = [
          audit.teacherName,
          shiftId.length > 12 ? shiftId.substring(0, 12) : shiftId,
          shiftStart != null ? DateFormat('MMM d, yyyy HH:mm').format(shiftStart) : 'N/A',
          subject,
          status,
          scheduledHours.toStringAsFixed(2),
          workedHours > 0 ? workedHours.toStringAsFixed(2) : '-',
          formHours > 0 ? formHours.toStringAsFixed(2) : '-',
          hasForm ? 'Yes' : 'No',
          paymentSource,
          '\$${baseAmount.toStringAsFixed(2)}',
          adjustment != 0 ? '\$${adjustment.toStringAsFixed(2)}' : '-',
          '\$${finalPayment.toStringAsFixed(2)}',
          hourlyRate > 0 ? '\$${hourlyRate.toStringAsFixed(2)}' : '-',
        ];
        
        for (var colIdx = 0; colIdx < data.length; colIdx++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
          cell.value = TextCellValue(data[colIdx]);
          
          // Color code "Has Form"
          if (colIdx == 8) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: hasForm 
                  ? ExcelColor.fromHexString('#C8E6C9')
                  : ExcelColor.fromHexString('#FFCDD2'),
              fontColorHex: hasForm 
                  ? ExcelColor.fromHexString('#2E7D32')
                  : ExcelColor.fromHexString('#C62828'),
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          }
          
          // Color code "Payment Source"
          if (colIdx == 9) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: paymentSource.contains('Timesheet')
                  ? ExcelColor.fromHexString('#E1F5FE')
                  : paymentSource.contains('Form')
                      ? ExcelColor.fromHexString('#F3E5F5')
                      : paymentSource.contains('Orphan')
                          ? ExcelColor.fromHexString('#FFEBEE')
                          : ExcelColor.fromHexString('#F5F5F5'),
              fontColorHex: paymentSource.contains('Orphan')
                  ? ExcelColor.fromHexString('#C62828')
                  : ExcelColor.black,
              horizontalAlign: HorizontalAlign.Center,
            );
          }
          
          // Color adjustments
          if (colIdx == 11 && adjustment != 0) {
            cell.cellStyle = CellStyle(
              fontColorHex: adjustment > 0 
                  ? ExcelColor.fromHexString('#2E7D32')
                  : ExcelColor.fromHexString('#C62828'),
              bold: true,
            );
          }
          
          // Highlight final payment
          if (colIdx == 12) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
              fontColorHex: ExcelColor.fromHexString('#2E7D32'),
              bold: true,
            );
          }
        }
        row++;
      }
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25); // Teacher
    sheet.setColumnWidth(1, 15); // Shift ID
    sheet.setColumnWidth(2, 18); // Date
    sheet.setColumnWidth(3, 15); // Subject
    sheet.setColumnWidth(4, 12); // Status
    sheet.setColumnWidth(5, 14); // Scheduled Hours
    sheet.setColumnWidth(6, 14); // Worked Hours
    sheet.setColumnWidth(7, 12); // Form Hours
    sheet.setColumnWidth(8, 10); // Has Form
    sheet.setColumnWidth(9, 18); // Payment Source
    sheet.setColumnWidth(10, 12); // Base Amount
    sheet.setColumnWidth(11, 15); // Manual Adjustment
    sheet.setColumnWidth(12, 14); // Final Payment
    sheet.setColumnWidth(13, 12); // Hourly Rate
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // STYLED SHEETS (same layout as Python build_report.py)
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const String _bgHeader = '#1E3A5F';
  static const String _bgSub = '#152A47';
  static const String _bgAccent = '#EFF6FF';
  static const String _bgRowAlt = '#F8FAFC';
  static const String _bgWhite = '#FFFFFF';
  static const String _textWhite = '#FFFFFF';
  static const String _textDark = '#1A1A2E';
  static const String _textMuted = '#6B7280';
  static const String _excellent = '#16A34A';
  static const String _good = '#65A30D';
  static const String _needsImp = '#D97706';
  static const String _critical = '#DC2626';
  static const String _greenBg = '#DCFCE7';
  static const String _greenFg = '#166534';
  static const String _yellowBg = '#FEF9C3';
  static const String _yellowFg = '#854D0E';
  static const String _redBg = '#FEE2E2';
  static const String _redFg = '#991B1B';
  static const String _blueBg = '#DBEAFE';
  static const String _blueFg = '#1E40AF';
  
  static String _monthLabelUpper(String yearMonth) {
    try {
      final date = DateTime.parse('$yearMonth-01');
      return DateFormat('MMMM yyyy').format(date).toUpperCase();
    } catch (_) {
      return yearMonth;
    }
  }
  
  static ExcelColor _tierColorHex(String tier) {
    final t = tier.toLowerCase();
    if (t.contains('excellent')) return ExcelColor.fromHexString(_excellent);
    if (t.contains('good')) return ExcelColor.fromHexString(_good);
    if (t.contains('needs')) return ExcelColor.fromHexString(_needsImp);
    if (t.contains('critical')) return ExcelColor.fromHexString(_critical);
    return ExcelColor.fromHexString('#9E9E9E');
  }
  
  static ExcelColor _rateBgFg(double rate) {
    if (rate >= 90) return ExcelColor.fromHexString(_greenBg);
    if (rate >= 70) return ExcelColor.fromHexString(_yellowBg);
    return ExcelColor.fromHexString(_redBg);
  }
  
  static ExcelColor _rateFg(double rate) {
    if (rate >= 90) return ExcelColor.fromHexString(_greenFg);
    if (rate >= 70) return ExcelColor.fromHexString(_yellowFg);
    return ExcelColor.fromHexString(_redFg);
  }

  /// Totals from Activity sheet logic (same as Activité): hrs from timesheets, hrs from forms, pay by source, sum Final Pay.
  static Map<String, double> _computeActivityTotalsForAudit(TeacherAuditFull audit) {
    double totalWorkedFromTs = 0, totalFormHrs = 0, payFromTs = 0, payFromForm = 0, sumFinalPay = 0;
    final shiftForms = <String, Map<String, dynamic>>{};
    final shiftFormsBySuffix = <String, Map<String, dynamic>>{};
    for (var form in audit.detailedForms) {
      final sid = form['shiftId'] as String?;
      if (sid == null || sid.isEmpty) continue;
      shiftForms[sid] = form;
      if (sid.length >= 8) shiftFormsBySuffix[sid.substring(sid.length - 8)] = form;
    }
    final adjustments = audit.paymentSummary?.shiftPaymentAdjustments ?? {};
    final timesheetByShiftId = <String, Map<String, dynamic>>{};
    final timesheetBySuffix = <String, Map<String, dynamic>>{};
    for (var ts in audit.detailedTimesheets) {
      final tsMap = ts as Map<String, dynamic>;
      final sid = tsMap['shift_id'] as String? ?? tsMap['shiftId'] as String?;
      if (sid != null && sid.isNotEmpty) {
        timesheetByShiftId[sid] = tsMap;
        if (sid.length >= 8) timesheetBySuffix[sid.substring(sid.length - 8)] = tsMap;
      }
    }
    for (var shiftData in audit.detailedShifts) {
      final shiftId = shiftData['id'] as String? ?? '';
      if (shiftId.isEmpty) continue;
      final status = shiftData['status'] as String? ?? 'unknown';
      final duration = (shiftData['duration'] as num?)?.toDouble() ?? 0.0;
      final formData = shiftForms[shiftId] ?? (shiftId.length >= 8 ? shiftFormsBySuffix[shiftId.substring(shiftId.length - 8)] : null);
      final hasForm = formData != null;
      final formHours = hasForm ? ((formData!['durationHours'] as num?)?.toDouble() ?? 0) : 0.0;
      totalFormHrs += formHours;
      String paymentSource = 'None';
      double baseAmount = 0.0;
      final timesheetEntry = timesheetByShiftId[shiftId] ?? (shiftId.length >= 8 ? timesheetBySuffix[shiftId.substring(shiftId.length - 8)] : null) ?? <String, dynamic>{};
      if (timesheetEntry.isNotEmpty) {
        final pay = (timesheetEntry['payment_amount'] as num?)?.toDouble() ?? (timesheetEntry['total_pay'] as num?)?.toDouble() ?? 0;
        if (pay > 0) {
          paymentSource = 'Timesheet';
          baseAmount = pay;
        }
      }
      if (baseAmount == 0 && hasForm && formHours > 0) {
        final rate = (shiftData['hourlyRate'] as num?)?.toDouble() ?? 0;
        if (rate > 0) {
          paymentSource = 'Form Duration';
          baseAmount = formHours * rate;
        }
      }
      final adj = adjustments[shiftId] ?? 0.0;
      final finalPay = baseAmount + adj;
      sumFinalPay += finalPay;
      if (paymentSource == 'Timesheet') payFromTs += baseAmount;
      if (paymentSource == 'Form Duration') payFromForm += baseAmount;
      double workedHours = 0;
      if (timesheetEntry.isNotEmpty) {
        final clockInRaw = timesheetEntry['clock_in_time'] ?? timesheetEntry['clock_in_timestamp'] ?? timesheetEntry['clockIn'];
        final clockOutRaw = timesheetEntry['effective_end_timestamp'] ?? timesheetEntry['clock_out_time'] ?? timesheetEntry['clock_out_timestamp'] ?? timesheetEntry['clockOut'];
        final shiftEndDt = (shiftData['end'] as Timestamp?)?.toDate();
        final shiftStartDt = (shiftData['start'] as Timestamp?)?.toDate();
        if (clockInRaw != null && clockOutRaw != null && clockInRaw is Timestamp && clockOutRaw is Timestamp) {
          DateTime start = (clockInRaw as Timestamp).toDate();
          DateTime end = (clockOutRaw as Timestamp).toDate();
          if (shiftEndDt != null && end.isAfter(shiftEndDt)) end = shiftEndDt;
          if (shiftStartDt != null && start.isBefore(shiftStartDt)) start = shiftStartDt;
          final dur = end.difference(start);
          if (!dur.isNegative) workedHours = dur.inSeconds / 3600.0;
        }
        if (workedHours <= 0) {
          final mins = (timesheetEntry['worked_minutes'] as num?)?.toDouble() ?? (timesheetEntry['workedMinutes'] as num?)?.toDouble();
          if (mins != null && mins > 0) workedHours = mins / 60.0;
        }
      }
      if (workedHours <= 0 && (status.toString().toLowerCase().contains('completed') || status.toString().toLowerCase().contains('fully') || status.toString().toLowerCase().contains('partially'))) {
        workedHours = duration;
      }
      totalWorkedFromTs += workedHours;
    }
    return {
      'totalWorkedFromTs': totalWorkedFromTs,
      'totalFormHrs': totalFormHrs,
      'payFromTs': payFromTs,
      'payFromForm': payFromForm,
      'sumFinalPay': sumFinalPay,
    };
  }

  /// Sheet: Dashboard — title, KPIs, teacher performance table, awards
  static void _createDashboardSheetStyled(Excel excel, List<TeacherAuditFull> audits, String yearMonth, _ExcelExportL10n l10n) {
    final sheet = excel[l10n.sheetDashboard];
    final monthLabel = _monthLabelUpper(yearMonth);
    final nTeachers = audits.length;
    
    // Title row (row 0)
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('R1'));
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('  📋  ${l10n.dashboardTitle} — $monthLabel');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 18,
      fontColorHex: ExcelColor.fromHexString(_textWhite),
      backgroundColorHex: ExcelColor.fromHexString(_bgHeader),
    );
    
    // Subtitle (row 1)
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('R2'));
    final subCell = sheet.cell(CellIndex.indexByString('A2'));
    subCell.value = TextCellValue('  $nTeachers ${l10n.dashboardSubtitle}');
    subCell.cellStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#A0B4CC'),
      backgroundColorHex: ExcelColor.fromHexString(_bgSub),
    );
    
    // Pre-compute Activity totals per audit (same logic as Activité sheet)
    final activityTotalsByAudit = <String, Map<String, double>>{};
    for (var a in audits) {
      activityTotalsByAudit[a.oderId] = _computeActivityTotalsForAudit(a);
    }
    // KPIs (row 3): Avg Score, Total Hours (= sum of Activity Worked Hours), Total Payroll (= sum of Final Pay), Active Issues
    double avgScore = 0;
    double totalHours = 0;
    double totalPay = 0;
    int totalIssues = 0;
    for (var a in audits) {
      avgScore += a.overallScore;
      final tot = activityTotalsByAudit[a.oderId] ?? {};
      totalHours += tot['totalWorkedFromTs'] ?? 0;
      totalPay += tot['sumFinalPay'] ?? 0;
      totalIssues += a.issues.length;
    }
    if (audits.isNotEmpty) avgScore /= audits.length;
    
    final kpis = [
      ('Avg Score', '${avgScore.toStringAsFixed(1)} / 10', '#2563EB', _blueBg),
      ('Total Hours', '${totalHours.toStringAsFixed(0)} h', '#059669', _greenBg),
      ('Total Payroll', '\$${totalPay.toStringAsFixed(2)}', '#7C3AED', '#EDE9FE'),
      ('Active Issues', '$totalIssues', _critical, _redBg),
    ];
    final kpiColStarts = [1, 5, 9, 13]; // B, F, J, N
    for (var i = 0; i < kpis.length; i++) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: kpiColStarts[i], rowIndex: 3),
        CellIndex.indexByColumnRow(columnIndex: kpiColStarts[i] + 3, rowIndex: 3),
      );
      final c = sheet.cell(CellIndex.indexByColumnRow(columnIndex: kpiColStarts[i], rowIndex: 3));
      c.value = TextCellValue('${kpis[i].$1}\n${kpis[i].$2}');
      c.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: ExcelColor.fromHexString(kpis[i].$3),
        backgroundColorHex: ExcelColor.fromHexString(kpis[i].$4),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }
    
    // Section label (row 4)
    sheet.merge(CellIndex.indexByString('A4'), CellIndex.indexByString('R4'));
    final sectionCell = sheet.cell(CellIndex.indexByString('A4'));
    sectionCell.value = TextCellValue('  ${l10n.teacherPerformanceOverview}');
    sectionCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#4B5563'),
      backgroundColorHex: ExcelColor.fromHexString(_bgAccent),
    );
    
    // Headers (row 5)
    final dashboardCols = [
      l10n.colTeacher, 'Score', 'Tier',
      'Classes\nDone / Total', 'Completion\nRate', 'On-Time\nClockIns', 'Punctuality',
      'Forms\nSub / Req', 'Form\nCompliance', l10n.colHrsTs.replaceAll(' ', '\n'), l10n.colHrsForms.replaceAll(' ', '\n'),
      l10n.colGrossPay, l10n.colNetPay, 'Late\nClockIns', 'Missed\nClasses', 'Issues', 'Status'
    ];
    for (var i = 0; i < dashboardCols.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i + 1, rowIndex: 5));
      cell.value = TextCellValue(dashboardCols[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_textWhite),
        backgroundColorHex: ExcelColor.fromHexString(_bgHeader),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }
    
    // Sort by overall score for rank
    final sorted = List<TeacherAuditFull>.from(audits)
      ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
    
    var dataRow = 6;
    for (var idx = 0; idx < sorted.length; idx++) {
      final audit = sorted[idx];
      final rank = idx + 1;
      final rowBg = idx.isEven ? _bgWhite : _bgRowAlt;
      final tierHex = _tierColorHex(audit.performanceTier);
      final completionRate = audit.completionRate.clamp(0.0, 100.0);
      final punctRate = audit.punctualityRate.clamp(0.0, 100.0);
      final formRate = audit.formComplianceRate.clamp(0.0, 100.0);
      final tot = activityTotalsByAudit[audit.oderId] ?? {};
      final hrsTs = tot['totalWorkedFromTs'] ?? 0;
      final hrsForms = tot['totalFormHrs'] ?? 0;
      final sumFinalPay = tot['sumFinalPay'] ?? 0;
      final statusStr = _formatStatus(audit.status);
      final issuesCount = audit.issues.length;
      final issuesText = issuesCount > 0 ? audit.issues.map((e) => e.type).join(' / ') : '✓ None';
      
      final rowData = [
        '#$rank  ${audit.teacherName}',
        audit.overallScore.toStringAsFixed(1),
        _formatTier(audit.performanceTier),
        '${audit.totalClassesCompleted}/${audit.totalClassesScheduled}',
        '${completionRate.toStringAsFixed(0)}%',
        audit.lateClockIns == 0 ? '✓' : '${audit.lateClockIns} late',
        '${punctRate.toStringAsFixed(0)}%',
        '${audit.readinessFormsSubmitted}/${audit.readinessFormsRequired}',
        '${formRate.toStringAsFixed(0)}%',
        '${hrsTs.toStringAsFixed(1)}h',
        '${hrsForms.toStringAsFixed(1)}h',
        '\$${((tot['payFromTs'] ?? 0) + (tot['payFromForm'] ?? 0)).toStringAsFixed(2)}',
        '\$${sumFinalPay.toStringAsFixed(2)}',
        '${audit.lateClockIns}',
        '${audit.totalClassesMissed}',
        issuesText,
        statusStr,
      ];
      for (var col = 0; col < rowData.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col + 1, rowIndex: dataRow));
        cell.value = TextCellValue(rowData[col]);
        final isNetCol = col == 12;
        cell.cellStyle = CellStyle(
          bold: col == 0 || col == 1 || col == 2 || (isNetCol && sumFinalPay > 0),
          fontSize: col == 16 ? 8 : 10,
          fontColorHex: col == 2 ? ExcelColor.fromHexString(_textWhite)
              : (col == 5 || col == 7 || col == 8 ? _rateFg(col == 5 ? completionRate : col == 7 ? punctRate : formRate) : ExcelColor.fromHexString(_textDark)),
          backgroundColorHex: col == 2 ? tierHex
              : (col == 5 ? _rateBgFg(completionRate) : (col == 7 ? _rateBgFg(punctRate) : (col == 8 ? _rateBgFg(formRate) : (isNetCol ? ExcelColor.fromHexString(_greenBg) : (col == 13 ? (audit.lateClockIns > 0 ? ExcelColor.fromHexString(_redBg) : ExcelColor.fromHexString(_greenBg)) : (col == 14 ? (audit.totalClassesMissed > 0 ? ExcelColor.fromHexString(_redBg) : ExcelColor.fromHexString(_greenBg)) : (col == 15 ? (issuesCount > 0 ? ExcelColor.fromHexString(_redBg) : ExcelColor.fromHexString(_greenBg)) : ExcelColor.fromHexString(rowBg)))))))),
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }
      dataRow++;
    }
    
    // Awards row
    final awardsParts = <String>[];
    for (var idx = 0; idx < sorted.length; idx++) {
      final a = sorted[idx];
      final nameFirst = a.teacherName.split(' ').first;
      String awards = '';
      if (idx == 0 && a.overallScore >= 75) awards = '🏆 Teacher of Month';
      if (a.formComplianceRate >= 95) awards += (awards.isEmpty ? '' : ', ') + '📋 Most Diligent';
      if (awards.isNotEmpty) awardsParts.add('$nameFirst: $awards');
    }
    if (awardsParts.isNotEmpty) {
      sheet.merge(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: dataRow), CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: dataRow));
      final aw = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: dataRow));
      aw.value = TextCellValue('  🏅  ' + awardsParts.join('   ·   '));
      aw.cellStyle = CellStyle(bold: true, fontSize: 9, fontColorHex: ExcelColor.fromHexString('#4338CA'), backgroundColorHex: ExcelColor.fromHexString('#EEF2FF'));
    }
    
    // Column widths
    sheet.setColumnWidth(0, 2);
    sheet.setColumnWidth(1, 26);
    sheet.setColumnWidth(2, 8);
    sheet.setColumnWidth(3, 14);
    for (var i = 4; i <= 17; i++) sheet.setColumnWidth(i, i == 16 ? 22 : 12);
    sheet.setColumnWidth(18, 2);
  }
  
  /// Sheet: Activity — shifts + forms merged (Lesson/Content, Session Quality)
  static void _createActiviteSheetStyled(Excel excel, List<TeacherAuditFull> audits, String yearMonth, _ExcelExportL10n l10n) {
    final sheet = excel[l10n.sheetActivity];
    final monthLabel = _monthLabelUpper(yearMonth);
    
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('O1'));
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('  📋  ACTIVITY LOG — SHIFTS & FORMS — $monthLabel');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString(_textWhite),
      backgroundColorHex: ExcelColor.fromHexString('#065F46'),
    );
    
    const actCols = [
      'Teacher', 'Date', 'Subject', 'Shift ID', 'Status',
      'Sched\nHours', 'Worked\nHours', 'Form\nHours', 'Form\nFiled?',
      'Lesson / Content', 'Session\nQuality',
      'Payment\nSource', 'Base\nAmount', 'Adj', 'Final\nPay'
    ];
    for (var i = 0; i < actCols.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = TextCellValue(actCols[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(_textWhite),
        backgroundColorHex: ExcelColor.fromHexString('#065F46'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }
    
    var actRow = 3;
    for (var audit in audits) {
      final shiftForms = <String, Map<String, dynamic>>{};
      final shiftFormsBySuffix = <String, Map<String, dynamic>>{};
      for (var form in audit.detailedForms) {
        final sid = form['shiftId'] as String?;
        if (sid == null || sid.isEmpty) continue;
        shiftForms[sid] = form;
        if (sid.length >= 8) shiftFormsBySuffix[sid.substring(sid.length - 8)] = form;
      }
      final adjustments = audit.paymentSummary?.shiftPaymentAdjustments ?? {};
      // Map shiftId -> timesheet entry (and by last-8-chars for ID mismatch)
      final timesheetByShiftId = <String, Map<String, dynamic>>{};
      final timesheetBySuffix = <String, Map<String, dynamic>>{};
      for (var ts in audit.detailedTimesheets) {
        final tsMap = ts as Map<String, dynamic>;
        final sid = tsMap['shift_id'] as String? ?? tsMap['shiftId'] as String?;
        if (sid != null && sid.isNotEmpty) {
          timesheetByShiftId[sid] = tsMap;
          if (sid.length >= 8) timesheetBySuffix[sid.substring(sid.length - 8)] = tsMap;
        }
      }
      
      for (var shiftData in audit.detailedShifts) {
        final shiftId = shiftData['id'] as String? ?? '';
        if (shiftId.isEmpty) continue;
        final shiftStart = (shiftData['start'] as Timestamp?)?.toDate();
        final status = shiftData['status'] as String? ?? 'unknown';
        final subject = shiftData['subject'] as String? ?? shiftData['subject_display_name'] as String? ?? 'N/A';
        final duration = (shiftData['duration'] as num?)?.toDouble() ?? 0.0;
        final formData = shiftForms[shiftId] ?? (shiftId.length >= 8 ? shiftFormsBySuffix[shiftId.substring(shiftId.length - 8)] : null);
        final hasForm = formData != null;
        final formHours = hasForm ? ((formData!['durationHours'] as num?)?.toDouble() ?? 0) : 0.0;
        String paymentSource = 'None';
        double baseAmount = 0.0;
        final timesheetEntry = timesheetByShiftId[shiftId] ?? (shiftId.length >= 8 ? timesheetBySuffix[shiftId.substring(shiftId.length - 8)] : null) ?? <String, dynamic>{};
        if (timesheetEntry.isNotEmpty) {
          final pay = (timesheetEntry['payment_amount'] as num?)?.toDouble() ?? (timesheetEntry['total_pay'] as num?)?.toDouble() ?? 0;
          if (pay > 0) {
            paymentSource = 'Timesheet';
            baseAmount = pay;
          }
        }
        if (baseAmount == 0 && hasForm && formHours > 0) {
          final rate = (shiftData['hourlyRate'] as num?)?.toDouble() ?? 0;
          if (rate > 0) {
            paymentSource = 'Form Duration';
            baseAmount = formHours * rate;
          }
        }
        if (!hasForm && baseAmount == 0) paymentSource = 'Orphan (No Form)';
        final adj = adjustments[shiftId] ?? 0.0;
        final finalPay = baseAmount + adj;
        
        String statusLabel = status;
        ExcelColor stBg = ExcelColor.fromHexString(_blueBg);
        ExcelColor stFg = ExcelColor.fromHexString(_blueFg);
        if (status.toString().toLowerCase().contains('completed') || status.toString().toLowerCase().contains('fully')) {
          statusLabel = '✓ Done';
          stBg = ExcelColor.fromHexString(_greenBg);
          stFg = ExcelColor.fromHexString(_greenFg);
        } else if (status.toString().toLowerCase().contains('missed')) {
          statusLabel = '✗ Missed';
          stBg = ExcelColor.fromHexString(_redBg);
          stFg = ExcelColor.fromHexString(_redFg);
        } else if (status.toString().toLowerCase().contains('late')) {
          statusLabel = '⚠ Late';
          stBg = ExcelColor.fromHexString(_yellowBg);
          stFg = ExcelColor.fromHexString(_yellowFg);
        }
        
        final lesson = hasForm ? (formData!['lessonCovered'] as String? ?? '').toString().replaceAll('nan', '').trim() : '';
        final quality = hasForm ? (formData!['sessionQuality'] as String? ?? '').toString().replaceAll('nan', '').trim() : '';
        
        // Worked hours = same as "Total Worked" in Shift Details: clock_in to effective_end/clock_out, capped at shift end
        double workedHours = 0;
        if (timesheetEntry.isNotEmpty) {
          final clockInRaw = timesheetEntry['clock_in_time'] ?? timesheetEntry['clock_in_timestamp'] ?? timesheetEntry['clockIn'];
          final clockOutRaw = timesheetEntry['effective_end_timestamp'] ?? timesheetEntry['clock_out_time'] ?? timesheetEntry['clock_out_timestamp'] ?? timesheetEntry['clockOut'];
          final shiftEndDt = (shiftData['end'] as Timestamp?)?.toDate();
          final shiftStartDt = (shiftData['start'] as Timestamp?)?.toDate();
          if (clockInRaw != null && clockOutRaw != null && clockInRaw is Timestamp && clockOutRaw is Timestamp) {
            DateTime start = (clockInRaw as Timestamp).toDate();
            DateTime end = (clockOutRaw as Timestamp).toDate();
            if (shiftEndDt != null && end.isAfter(shiftEndDt)) end = shiftEndDt;
            if (shiftStartDt != null && start.isBefore(shiftStartDt)) start = shiftStartDt;
            final dur = end.difference(start);
            if (!dur.isNegative) workedHours = dur.inSeconds / 3600.0;
          }
          if (workedHours <= 0) {
            final mins = (timesheetEntry['worked_minutes'] as num?)?.toDouble() ?? (timesheetEntry['workedMinutes'] as num?)?.toDouble();
            if (mins != null && mins > 0) workedHours = mins / 60.0;
          }
        }
        if (workedHours <= 0 && (status.toString().toLowerCase().contains('completed') || status.toString().toLowerCase().contains('fully') || status.toString().toLowerCase().contains('partially'))) {
          workedHours = duration;
        }
        final rowValues = [
          audit.teacherName,
          shiftStart != null ? DateFormat('MMM d, yyyy').format(shiftStart) : '',
          subject,
          shiftId.length > 8 ? shiftId.substring(shiftId.length - 8) : shiftId,
          statusLabel,
          duration.toStringAsFixed(2),
          workedHours > 0 ? workedHours.toStringAsFixed(2) : '-',
          formHours > 0 ? formHours.toStringAsFixed(2) : '-',
          hasForm ? 'Yes' : 'No',
          lesson.isEmpty ? '—' : (lesson.length > 40 ? lesson.substring(0, 40) : lesson),
          quality.isEmpty ? '—' : (quality.length > 15 ? quality.substring(0, 15) : quality),
          paymentSource.length > 14 ? paymentSource.substring(0, 14) : paymentSource,
          '\$${baseAmount.toStringAsFixed(2)}',
          adj != 0 ? '\$${adj.toStringAsFixed(2)}' : '-',
          '\$${finalPay.toStringAsFixed(2)}',
        ];
        for (var c = 0; c < rowValues.length; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: actRow));
          cell.value = TextCellValue(rowValues[c].toString());
          if (c == 4) {
            cell.cellStyle = CellStyle(bold: true, fontColorHex: stFg, backgroundColorHex: stBg, horizontalAlign: HorizontalAlign.Center);
          } else if (c == 8) {
            cell.cellStyle = CellStyle(
              bold: true,
              fontColorHex: hasForm ? ExcelColor.fromHexString(_greenFg) : ExcelColor.fromHexString(_redFg),
              backgroundColorHex: hasForm ? ExcelColor.fromHexString(_greenBg) : ExcelColor.fromHexString(_redBg),
              horizontalAlign: HorizontalAlign.Center,
            );
          } else if (c == 14) {
            cell.cellStyle = CellStyle(bold: true, fontColorHex: ExcelColor.fromHexString(_greenFg), backgroundColorHex: ExcelColor.fromHexString(_greenBg), horizontalAlign: HorizontalAlign.Center);
          } else {
            cell.cellStyle = CellStyle(backgroundColorHex: actRow % 2 == 0 ? ExcelColor.fromHexString(_bgWhite) : ExcelColor.fromHexString(_bgRowAlt), horizontalAlign: c >= 1 && c <= 4 || (c >= 5 && c <= 9) || c >= 11 ? HorizontalAlign.Center : HorizontalAlign.Left);
          }
        }
        actRow++;
      }
    }
    
    final actWidths = [22.0, 13.0, 14.0, 11.0, 10.0, 7.0, 8.0, 7.0, 8.0, 28.0, 12.0, 13.0, 11.0, 8.0, 10.0];
    for (var i = 0; i < actWidths.length; i++) sheet.setColumnWidth(i, actWidths[i]);
  }
  
  /// Sheet: Payment — payroll summary aligned with Activity (Pay from TS, Pay from Forms, Final Pay = sum of Activity Final Pay)
  static void _createPaiementSheetStyled(Excel excel, List<TeacherAuditFull> audits, String yearMonth, _ExcelExportL10n l10n) {
    final sheet = excel[l10n.sheetPaiement];
    final monthLabel = _monthLabelUpper(yearMonth);
    
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('L1'));
    final t = sheet.cell(CellIndex.indexByString('A1'));
    t.value = TextCellValue('  💰  ${l10n.payrollSummaryTitle} — $monthLabel');
    t.cellStyle = CellStyle(bold: true, fontSize: 14, fontColorHex: ExcelColor.fromHexString(_textWhite), backgroundColorHex: ExcelColor.fromHexString('#92400E'));
    
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('L2'));
    final lbl = sheet.cell(CellIndex.indexByString('A2'));
    lbl.value = TextCellValue('  ${l10n.payrollSummarySubtitle}');
    lbl.cellStyle = CellStyle(bold: true, fontSize: 9, fontColorHex: ExcelColor.fromHexString('#78350F'), backgroundColorHex: ExcelColor.fromHexString('#FEF3C7'));
    
    final sumCols = [l10n.colTeacher, l10n.colSubject, l10n.colHrsTs, l10n.colHrsForms, l10n.colPayTs, l10n.colPayForms, l10n.colGrossPay, l10n.colPenalties, l10n.colBonuses, l10n.colNetPay, l10n.colGlobalAdj, l10n.colFinalPay];
    for (var i = 0; i < sumCols.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(sumCols[i]);
      cell.cellStyle = CellStyle(bold: true, fontSize: 9, fontColorHex: ExcelColor.fromHexString(_textWhite), backgroundColorHex: ExcelColor.fromHexString('#92400E'), horizontalAlign: HorizontalAlign.Center);
    }
    
    double grandTotalFinalPay = 0;
    var payRow = 4;
    for (var audit in audits) {
      final tot = _computeActivityTotalsForAudit(audit);
      final hrsTs = tot['totalWorkedFromTs'] ?? 0;
      final hrsForms = tot['totalFormHrs'] ?? 0;
      final payFromTs = tot['payFromTs'] ?? 0;
      final payFromForm = tot['payFromForm'] ?? 0;
      final sumFinalPay = tot['sumFinalPay'] ?? 0;
      grandTotalFinalPay += sumFinalPay;
      final ps = audit.paymentSummary;
      final subjectLabel = ps != null && ps.paymentsBySubject.isNotEmpty
          ? (ps.paymentsBySubject.length == 1 ? ps.paymentsBySubject.values.first.subjectName : 'All')
          : '-';
      final gross = (ps != null ? ps.totalGrossPayment : 0.0);
      final penalties = ps?.totalPenalties ?? 0;
      final bonuses = ps?.totalBonuses ?? 0;
      final net = ps?.totalNetPayment ?? 0;
      final adj = ps?.adminAdjustment ?? 0;
      final rowData = [
        audit.teacherName,
        subjectLabel,
        hrsTs > 0 ? '${hrsTs.toStringAsFixed(2)}' : '-',
        hrsForms > 0 ? '${hrsForms.toStringAsFixed(2)}' : '-',
        '\$${payFromTs.toStringAsFixed(2)}',
        '\$${payFromForm.toStringAsFixed(2)}',
        '\$${gross.toStringAsFixed(2)}',
        '\$${penalties.toStringAsFixed(2)}',
        '\$${bonuses.toStringAsFixed(2)}',
        '\$${net.toStringAsFixed(2)}',
        adj != 0 ? '\$${adj.toStringAsFixed(2)}' : '-',
        '\$${sumFinalPay.toStringAsFixed(2)}',
      ];
      for (var c = 0; c < rowData.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: payRow));
        cell.value = TextCellValue(rowData[c]);
        final isFinal = c == 11;
        final isPenalty = c == 7;
        final isBonus = c == 8;
        var bg = payRow % 2 == 0 ? _bgWhite : _bgRowAlt;
        var fg = _textDark;
        if (isFinal) { bg = _greenBg; fg = _greenFg; }
        else if (isPenalty && penalties != 0) { bg = _redBg; fg = _redFg; }
        else if (isBonus && bonuses != 0) { bg = _greenBg; fg = _greenFg; }
        cell.cellStyle = CellStyle(bold: c == 0 || isFinal, fontSize: c == 0 ? 10 : 9, fontColorHex: ExcelColor.fromHexString(fg), backgroundColorHex: ExcelColor.fromHexString(bg), horizontalAlign: c == 0 ? HorizontalAlign.Left : HorizontalAlign.Center);
      }
      payRow++;
    }
    // Total row: sum of Final Pay (= sum of Activity Final Pay)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: payRow)).value = TextCellValue(l10n.totalLabel);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: payRow)).cellStyle = CellStyle(bold: true, fontSize: 10, fontColorHex: ExcelColor.fromHexString(_textWhite), backgroundColorHex: ExcelColor.fromHexString('#92400E'));
    for (var c = 1; c < 11; c++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: payRow)).value = TextCellValue('');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: payRow)).value = TextCellValue('\$${grandTotalFinalPay.toStringAsFixed(2)}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: payRow)).cellStyle = CellStyle(bold: true, fontSize: 10, fontColorHex: ExcelColor.fromHexString(_greenFg), backgroundColorHex: ExcelColor.fromHexString(_greenBg), horizontalAlign: HorizontalAlign.Center);
    payRow++;
    
    payRow++;
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: payRow), CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: payRow));
    final lbl2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: payRow));
    lbl2.value = TextCellValue('  ⚠️  ${l10n.issuesAndFlagsTitle}');
    lbl2.cellStyle = CellStyle(bold: true, fontSize: 9, fontColorHex: ExcelColor.fromHexString('#991B1B'), backgroundColorHex: ExcelColor.fromHexString(_redBg));
    payRow++;
    for (var i = 0; i < 4; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: payRow));
      cell.value = TextCellValue([l10n.colTeacher, l10n.colIssueType, l10n.colDescription, l10n.colSeverity][i]);
      cell.cellStyle = CellStyle(bold: true, fontSize: 9, fontColorHex: ExcelColor.fromHexString(_textWhite), backgroundColorHex: ExcelColor.fromHexString('#DC2626'), horizontalAlign: HorizontalAlign.Center);
    }
    payRow++;
    for (var audit in audits) {
      for (var issue in audit.issues) {
        final sev = issue.severity.toLowerCase();
        final sevBg = sev == 'high' ? _redBg : (sev == 'medium' ? _yellowBg : _greenBg);
        final sevFg = sev == 'high' ? _redFg : (sev == 'medium' ? _yellowFg : _greenFg);
        setCell(sheet, payRow, 0, audit.teacherName, bold: true);
        setCell(sheet, payRow, 1, issue.type, color: _redFg, bold: true);
        setCell(sheet, payRow, 2, issue.description);
        final sc = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: payRow));
        sc.value = TextCellValue(sev.toUpperCase());
        sc.cellStyle = CellStyle(bold: true, fontColorHex: ExcelColor.fromHexString(sevFg), backgroundColorHex: ExcelColor.fromHexString(sevBg), horizontalAlign: HorizontalAlign.Center);
        payRow++;
      }
    }
    
    final payWidths = [22.0, 12.0, 8.0, 9.0, 10.0, 10.0, 10.0, 9.0, 9.0, 10.0, 10.0, 11.0];
    for (var i = 0; i < payWidths.length; i++) sheet.setColumnWidth(i, payWidths[i]);
  }
  
  static void setCell(Sheet sheet, int row, int col, String value, {bool bold = false, String? color, String? bg}) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);
    cell.cellStyle = CellStyle(
      bold: bold,
      fontSize: 9,
      fontColorHex: color != null ? ExcelColor.fromHexString(color) : ExcelColor.fromHexString(_textDark),
      backgroundColorHex: bg != null ? ExcelColor.fromHexString(bg) : ExcelColor.fromHexString(_bgWhite),
    );
  }
  
  /// Sheet 5: Coach Evaluation (16 factors)
  static void _createEvaluationSheet(Excel excel, List<TeacherAuditFull> audits) {
    final sheet = excel['📝 Evaluation'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#9C27B0'),
    );
    
    // Get factor titles from first audit with factors
    final sampleAudit = audits.firstWhere(
      (a) => a.auditFactors.isNotEmpty,
      orElse: () => audits.first,
    );
    
    final factorTitles = sampleAudit.auditFactors.isNotEmpty
        ? sampleAudit.auditFactors.map((f) => f.title).toList()
        : TeacherAuditFull.getDefaultAuditFactors().map((f) => f.title).toList();
    
    // Headers: Teacher + each factor + Total
    final headers = ['Teacher', ...factorTitles, 'Total Score', 'Avg Rating'];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    for (var rowIdx = 0; rowIdx < audits.length; rowIdx++) {
      final audit = audits[rowIdx];
      final row = rowIdx + 1;
      
      // Teacher name
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(audit.teacherName);
      
      // Factor ratings
      var totalRating = 0;
      for (var factorIdx = 0; factorIdx < factorTitles.length; factorIdx++) {
        final factor = audit.auditFactors.length > factorIdx
            ? audit.auditFactors[factorIdx]
            : null;
        final rating = factor?.rating ?? 9;
        totalRating += rating;
        
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: factorIdx + 1, rowIndex: row));
        cell.value = TextCellValue(rating.toString());
        cell.cellStyle = CellStyle(
          backgroundColorHex: _getRatingColor(rating),
          horizontalAlign: HorizontalAlign.Center,
          fontColorHex: rating < 5 ? ExcelColor.white : ExcelColor.black,
        );
      }
      
      // Total and average
      final maxScore = factorTitles.length * 9;
      final avgRating = totalRating / factorTitles.length;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: factorTitles.length + 1, rowIndex: row))
        ..value = TextCellValue('$totalRating / $maxScore')
        ..cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: factorTitles.length + 2, rowIndex: row))
        ..value = TextCellValue(avgRating.toStringAsFixed(1))
        ..cellStyle = CellStyle(
          backgroundColorHex: _getRatingColor(avgRating.round()),
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25);
    for (var i = 1; i < headers.length; i++) {
      sheet.setColumnWidth(i, 12);
    }
  }
  
  /// Sheet 6: Review Chain
  static void _createReviewSheet(Excel excel, List<TeacherAuditFull> audits) {
    final sheet = excel['✅ Reviews'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#00BCD4'),
    );
    
    final headers = [
      'Teacher', 'Coach Reviewer', 'Coach Status', 'Coach Notes',
      'CEO Reviewer', 'CEO Status', 'CEO Notes',
      'Founder Reviewer', 'Founder Status', 'Founder Notes',
      'Final Status'
    ];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    for (var rowIdx = 0; rowIdx < audits.length; rowIdx++) {
      final audit = audits[rowIdx];
      final row = rowIdx + 1;
      final review = audit.reviewChain;
      
      final data = [
        audit.teacherName,
        review?.coachReview?.reviewerName ?? '-',
        review?.coachReview?.status ?? '-',
        review?.coachReview?.notes ?? '-',
        review?.ceoReview?.reviewerName ?? '-',
        review?.ceoReview?.status ?? '-',
        review?.ceoReview?.notes ?? '-',
        review?.founderReview?.reviewerName ?? '-',
        review?.founderReview?.status ?? '-',
        review?.founderReview?.notes ?? '-',
        _formatStatus(audit.status),
      ];
      
      for (var colIdx = 0; colIdx < data.length; colIdx++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
        cell.value = TextCellValue(data[colIdx]);
        
        // Color status columns
        if (colIdx == 2 || colIdx == 5 || colIdx == 8 || colIdx == 10) {
          final status = data[colIdx].toLowerCase();
          cell.cellStyle = CellStyle(
            backgroundColorHex: status.contains('approved') 
                ? ExcelColor.fromHexString('#C8E6C9')
                : status.contains('rejected')
                    ? ExcelColor.fromHexString('#FFCDD2')
                    : ExcelColor.fromHexString('#FFF9C4'),
            horizontalAlign: HorizontalAlign.Center,
          );
        }
      }
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(3, 30);
    sheet.setColumnWidth(4, 20);
    sheet.setColumnWidth(6, 30);
    sheet.setColumnWidth(7, 20);
    sheet.setColumnWidth(9, 30);
    sheet.setColumnWidth(10, 15);
  }
  
  /// Sheet 7: Issues
  static void _createIssuesSheet(Excel excel, List<TeacherAuditFull> audits) {
    final sheet = excel['⚠️ Issues'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#F44336'),
    );
    
    final headers = ['Teacher', 'Issue Type', 'Description', 'Severity'];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    var row = 1;
    for (var audit in audits) {
      if (audit.issues.isEmpty) continue;
      
      for (var issue in audit.issues) {
        final data = [
          audit.teacherName,
          issue.type,
          issue.description,
          issue.severity,
        ];
        
        for (var colIdx = 0; colIdx < data.length; colIdx++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
          cell.value = TextCellValue(data[colIdx]);
          
          // Color severity
          if (colIdx == 3) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: issue.severity == 'high'
                  ? ExcelColor.fromHexString('#FFCDD2')
                  : issue.severity == 'medium'
                      ? ExcelColor.fromHexString('#FFE0B2')
                      : ExcelColor.fromHexString('#FFF9C4'),
              fontColorHex: issue.severity == 'high'
                  ? ExcelColor.fromHexString('#C62828')
                  : ExcelColor.black,
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          }
        }
        row++;
      }
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 40);
    sheet.setColumnWidth(3, 12);
  }
  
  /// Helper to safely convert dynamic data (List or String) to String
  static String _safeToString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) {
      // Si c'est une liste (ex: liste d'élèves), on joint les éléments par une virgule
      return value.map((e) => e.toString()).join(', '); 
    }
    return value.toString();
  }

  /// Sheet 7: Form Details (Daily, Weekly, Monthly) - Enhanced for new templates
  static void _createFormDetailsSheet(Excel excel, List<TeacherAuditFull> audits) {
    final sheet = excel['📋 Form Details'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#2196F3'),
    );
    
    // Extended headers to support all form types
    final headers = [
      'Teacher', 'Form Type', 'Shift ID', 'Date', 'Duration (h)', 
      'Subject', 'Students Attended', 'Lesson Covered', 
      'Used Curriculum', 'Session Quality', 'Teacher Notes',
      // Weekly fields
      'Weekly Rating', 'Classes Taught', 'Absences', 'Video Done', 'Achievements', 'Challenges', 'Coach Helpfulness',
      // Monthly fields
      'Month Rating', 'Goals Met', 'Bayana Completed', 'Student Attendance', 'Monthly Achievements', 'Admin Comments',
    ];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    var row = 1;
    for (var audit in audits) {
      for (var form in audit.detailedForms) {
        final formType = form['formType'] as String? ?? 'legacy';
        final shiftId = form['shiftId'] as String? ?? '';
        final submittedAt = (form['submittedAt'] as Timestamp?)?.toDate();
        final duration = (form['durationHours'] as num?)?.toDouble() ?? 0;
        final responses = form['responses'] as Map<String, dynamic>? ?? {};
        
        // Daily/Per-Session fields (using _safeToString for safety)
        final lessonCovered = _safeToString(
          form['lessonCovered'] ?? 
          responses['lesson_covered'] ?? 
          responses['1754407184691']
        );
                             
        final usedCurriculum = _safeToString(
          form['usedCurriculum'] ?? 
          responses['used_curriculum'] ?? 
          responses['1754407297953']
        );
                              
        final sessionQuality = _safeToString(
          form['sessionQuality'] ?? 
          responses['session_quality']
        );
                             
        final teacherNotes = _safeToString(
          form['teacherNotes'] ?? 
          responses['teacher_notes'] ?? 
          responses['1754407509366']
        );
                            
        final studentsAttended = _safeToString(
          form['studentsAttended'] ?? 
          responses['students_attended'] ?? 
          responses['students_present'] ?? 
          responses['1754406457284']
        );
        
        // Get subject from shift if available
        String subject = '';
        if (shiftId.isNotEmpty) {
          subject = _safeToString(form['shiftTitle']);
        }
        
        // Weekly Summary fields
        final weeklyRating = _safeToString(responses['weekly_rating']);
        final classesTaught = _safeToString(responses['classes_taught']);
        final absences = _safeToString(responses['absences_this_week']);
        final videoDone = _safeToString(responses['video_recording_done']);
        final achievements = _safeToString(responses['achievements']);
        final challenges = _safeToString(responses['challenges']);
        final coachHelpfulness = _safeToString(responses['coach_helpfulness']);
        
        // Monthly Review fields
        final monthRating = _safeToString(responses['month_rating']);
        final goalsMet = _safeToString(responses['goals_met']);
        final bayanaCompleted = _safeToString(responses['bayana_completed']);
        final studentAttendance = _safeToString(responses['student_attendance_summary']);
        final monthlyAchievements = _safeToString(responses['monthly_achievements']);
        final adminComments = _safeToString(responses['comments_for_admin']);
        
        final data = [
          audit.teacherName,
          _formatFormType(formType),
          shiftId.isNotEmpty ? shiftId.substring(0, shiftId.length.clamp(0, 12)) : 'N/A',
          submittedAt != null ? DateFormat('MMM d, yyyy').format(submittedAt) : 'N/A',
          duration.toStringAsFixed(2),
          subject,
          studentsAttended,
          lessonCovered,
          usedCurriculum,
          sessionQuality,
          teacherNotes,
          // Weekly fields
          weeklyRating,
          classesTaught,
          absences,
          videoDone,
          achievements,
          challenges,
          coachHelpfulness,
          // Monthly fields
          monthRating,
          goalsMet,
          bayanaCompleted,
          studentAttendance,
          monthlyAchievements,
          adminComments,
        ];
        
        for (var colIdx = 0; colIdx < data.length; colIdx++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
          cell.value = TextCellValue(data[colIdx]);
          
          // Color code form type
          if (colIdx == 1) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: _getFormTypeColor(formType),
              fontColorHex: ExcelColor.white,
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          }
          
          // Color code session quality (Daily) and ratings (Weekly/Monthly)
          if (colIdx == 9 || colIdx == 11 || colIdx == 18) {
            final ratingValue = data[colIdx].toLowerCase();
            if (ratingValue.isNotEmpty) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ratingValue.contains('excellent') 
                    ? ExcelColor.fromHexString('#4CAF50')
                    : ratingValue.contains('good')
                        ? ExcelColor.fromHexString('#8BC34A')
                        : ratingValue.contains('average')
                            ? ExcelColor.fromHexString('#FFC107')
                            : ratingValue.contains('challenging')
                                ? ExcelColor.fromHexString('#FF9800')
                                : ExcelColor.white,
                fontColorHex: ratingValue.contains('excellent') || ratingValue.contains('good')
                    ? ExcelColor.white
                    : ExcelColor.black,
                horizontalAlign: HorizontalAlign.Center,
              );
            }
          }
          
          // Color code Yes/No fields
          if (colIdx == 14 || colIdx == 20) { // Video Done, Bayana Completed
            final yesNoValue = data[colIdx].toLowerCase();
            if (yesNoValue.isNotEmpty) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: yesNoValue.contains('yes')
                    ? ExcelColor.fromHexString('#C8E6C9')
                    : yesNoValue.contains('no')
                        ? ExcelColor.fromHexString('#FFCDD2')
                        : ExcelColor.white,
                horizontalAlign: HorizontalAlign.Center,
              );
            }
          }
        }
        row++;
      }
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25); // Teacher
    sheet.setColumnWidth(1, 12); // Form Type
    sheet.setColumnWidth(2, 15); // Shift ID
    sheet.setColumnWidth(3, 14); // Date
    sheet.setColumnWidth(4, 12); // Duration
    sheet.setColumnWidth(5, 15); // Subject
    sheet.setColumnWidth(6, 25); // Students
    sheet.setColumnWidth(7, 30); // Lesson
    sheet.setColumnWidth(8, 20); // Curriculum
    sheet.setColumnWidth(9, 15); // Quality
    sheet.setColumnWidth(10, 40); // Notes
    // Weekly columns
    sheet.setColumnWidth(11, 15); // Weekly Rating
    sheet.setColumnWidth(12, 14); // Classes Taught
    sheet.setColumnWidth(13, 12); // Absences
    sheet.setColumnWidth(14, 12); // Video Done
    sheet.setColumnWidth(15, 35); // Achievements
    sheet.setColumnWidth(16, 30); // Challenges
    sheet.setColumnWidth(17, 18); // Coach Helpfulness
    // Monthly columns
    sheet.setColumnWidth(18, 15); // Month Rating
    sheet.setColumnWidth(19, 15); // Goals Met
    sheet.setColumnWidth(20, 15); // Bayana
    sheet.setColumnWidth(21, 30); // Student Attendance
    sheet.setColumnWidth(22, 35); // Monthly Achievements
    sheet.setColumnWidth(23, 35); // Admin Comments
  }
  
  // Helper methods
  static String _formatYearMonth(String yearMonth) {
    try {
      final date = DateTime.parse('$yearMonth-01');
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return yearMonth;
    }
  }
  
  static String _formatTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'excellent': return '🌟 Excellent';
      case 'good': return '✅ Good';
      case 'needsimprovement': return '⚠️ Needs Improvement';
      case 'critical': return '🚨 Critical';
      default: return tier;
    }
  }
  
  static String _formatStatus(AuditStatus status) {
    switch (status) {
      case AuditStatus.pending: return 'Pending';
      case AuditStatus.coachReview: return 'Coach Review';
      case AuditStatus.coachSubmitted: return 'Coach Submitted';
      case AuditStatus.ceoReview: return 'CEO Review';
      case AuditStatus.ceoApproved: return 'CEO Approved';
      case AuditStatus.founderReview: return 'Founder Review';
      case AuditStatus.completed: return 'Completed';
      case AuditStatus.disputed: return 'Disputed';
    }
  }
  
  static ExcelColor _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'excellent': return ExcelColor.fromHexString('#4CAF50');
      case 'good': return ExcelColor.fromHexString('#8BC34A');
      case 'needsimprovement': return ExcelColor.fromHexString('#FF9800');
      case 'critical': return ExcelColor.fromHexString('#F44336');
      default: return ExcelColor.fromHexString('#9E9E9E');
    }
  }
  
  static ExcelColor _getRateColor(double rate) {
    if (rate >= 90) return ExcelColor.fromHexString('#C8E6C9');
    if (rate >= 70) return ExcelColor.fromHexString('#DCEDC8');
    if (rate >= 50) return ExcelColor.fromHexString('#FFF9C4');
    return ExcelColor.fromHexString('#FFCDD2');
  }
  
  static ExcelColor _getRatingColor(int rating) {
    if (rating >= 8) return ExcelColor.fromHexString('#4CAF50');
    if (rating >= 6) return ExcelColor.fromHexString('#8BC34A');
    if (rating >= 4) return ExcelColor.fromHexString('#FFC107');
    if (rating >= 2) return ExcelColor.fromHexString('#FF9800');
    return ExcelColor.fromHexString('#F44336');
  }
  
  static String _formatFormType(String formType) {
    switch (formType.toLowerCase()) {
      case 'daily':
      case 'persession':
        return '📅 Daily';
      case 'weekly':
        return '📆 Weekly';
      case 'monthly':
        return '📊 Monthly';
      case 'ondemand':
      case 'on_demand':
        return '⚡ On-Demand';
      case 'feedback':
      case 'teacher_feedback':
      case 'leadership_feedback':
        return '💬 Feedback';
      case 'assessment':
      case 'student_assessment':
      case 'parent_feedback':
        return '📚 Assessment';
      case 'administrative':
      case 'leave_request':
      case 'incident_report':
        return '📋 Administrative';
      default:
        return '📝 Legacy';
    }
  }
  
  static ExcelColor _getFormTypeColor(String formType) {
    switch (formType.toLowerCase()) {
      case 'daily':
      case 'persession':
        return ExcelColor.fromHexString('#2196F3');
      case 'weekly':
        return ExcelColor.fromHexString('#4CAF50');
      case 'monthly':
        return ExcelColor.fromHexString('#FF9800');
      case 'ondemand':
      case 'on_demand':
        return ExcelColor.fromHexString('#EC4899'); // Pink for on-demand
      case 'feedback':
      case 'teacher_feedback':
      case 'leadership_feedback':
        return ExcelColor.fromHexString('#8B5CF6');
      case 'assessment':
      case 'student_assessment':
      case 'parent_feedback':
        return ExcelColor.fromHexString('#3B82F6');
      case 'administrative':
      case 'leave_request':
      case 'incident_report':
        return ExcelColor.fromHexString('#F59E0B');
      default:
        return ExcelColor.fromHexString('#9E9E9E');
    }
  }

  /// Sheet 8: Additional Forms (Feedback, Assessment, Administrative)
  static Future<void> _createAdditionalFormsSheet(
    Excel excel,
    List<TeacherAuditFull> audits,
    String yearMonth,
  ) async {
    final sheet = excel['💬 Additional Forms'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#8B5CF6'),
    );
    
    final headers = [
      'Teacher', 'Form Type', 'Category', 'Date Submitted', 'Status',
      'Feedback Type', 'Subject/Topic', 'Description', 'Urgency',
      'Overall Rating', 'Communication Quality', 'Support Quality',
      'Student Name', 'Assessment Type', 'Reading Level', 'Writing Level',
      'Overall Level', 'Surahs Known', 'Hadiths Known',
      'Incident Type', 'People Involved', 'Action Taken', 'Follow-up Needed',
      'Leave Type', 'Start Date', 'End Date', 'Shifts Affected', 'Advance Notice', 'Coverage Arranged',
    ];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Query form_responses for additional forms
    final firestore = FirebaseFirestore.instance;
    final teacherIds = audits.map((a) => a.oderId).toSet();
    
    var row = 1;
    for (var teacherId in teacherIds) {
      // Get all additional form responses for this teacher in this month
      final responsesSnapshot = await firestore
          .collection('form_responses')
          .where('userId', isEqualTo: teacherId)
          .where('yearMonth', isEqualTo: yearMonth)
          .get();
      
      for (var doc in responsesSnapshot.docs) {
        final data = doc.data();
        final formId = data['formId'] as String? ?? '';
        final formType = _getFormCategoryFromId(formId);
        final responses = data['responses'] as Map<String, dynamic>? ?? {};
        final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
        final status = data['status'] as String? ?? 'submitted';
        
        final teacherName = audits.firstWhere(
          (a) => a.oderId == teacherId,
          orElse: () => audits.first,
        ).teacherName;
        
        // Extract fields based on form type
        final rowData = [
          teacherName,
          _formatAdditionalFormType(formId),
          formType,
          submittedAt != null ? DateFormat('MMM d, yyyy').format(submittedAt) : 'N/A',
          status,
          // Feedback fields
          _safeToString(responses['feedback_type']),
          _safeToString(responses['subject']),
          _safeToString(responses['description']),
          _safeToString(responses['urgency']),
          _safeToString(responses['leader_rating'] ?? responses['overall_rating']),
          _safeToString(responses['communication']),
          _safeToString(responses['support_quality']),
          // Assessment fields
          _safeToString(responses['student_name']),
          _safeToString(responses['assessment_type']),
          _safeToString(responses['reading_level']),
          _safeToString(responses['writing_level']),
          _safeToString(responses['overall_level']),
          _safeToString(responses['surahs_known']),
          _safeToString(responses['hadiths_known']),
          // Incident fields
          _safeToString(responses['incident_type']),
          _safeToString(responses['people_involved']),
          _safeToString(responses['action_taken']),
          _safeToString(responses['followup_needed']),
          // Leave request fields
          _safeToString(responses['leave_type']),
          _safeToString(responses['start_date']),
          _safeToString(responses['end_date']),
          _safeToString(responses['affected_shifts']),
          _safeToString(responses['advance_notice']),
          _safeToString(responses['coverage_arranged']),
        ];
        
        for (var colIdx = 0; colIdx < rowData.length; colIdx++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
          cell.value = TextCellValue(rowData[colIdx]);
          
          // Color code form type
          if (colIdx == 1) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: _getFormTypeColor(formId),
              fontColorHex: ExcelColor.white,
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          }
          
          // Color code urgency
          if (colIdx == 8) {
            final urgency = rowData[colIdx].toLowerCase();
            if (urgency.contains('critical')) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#F44336'),
                fontColorHex: ExcelColor.white,
              );
            } else if (urgency.contains('high')) {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#FF9800'),
                fontColorHex: ExcelColor.white,
              );
            }
          }
          
          // Color code leave request status
          if (colIdx == 4 && formId.contains('leave')) {
            final leaveStatus = rowData[colIdx].toLowerCase();
            if (leaveStatus == 'approved') {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#C8E6C9'),
                fontColorHex: ExcelColor.fromHexString('#2E7D32'),
              );
            } else if (leaveStatus == 'rejected') {
              cell.cellStyle = CellStyle(
                backgroundColorHex: ExcelColor.fromHexString('#FFCDD2'),
                fontColorHex: ExcelColor.fromHexString('#C62828'),
              );
            }
          }
        }
        row++;
      }
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 25); // Teacher
    sheet.setColumnWidth(1, 18); // Form Type
    sheet.setColumnWidth(2, 15); // Category
    sheet.setColumnWidth(3, 14); // Date
    sheet.setColumnWidth(4, 12); // Status
    for (var i = 5; i < headers.length; i++) {
      sheet.setColumnWidth(i, 18);
    }
  }

  /// Sheet 9: Leave Requests Summary
  static Future<void> _createLeaveRequestsSheet(
    Excel excel,
    List<TeacherAuditFull> audits,
    String yearMonth,
  ) async {
    final sheet = excel['🏖️ Leave Requests'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#F59E0B'),
    );
    
    final headers = [
      'Teacher', 'Leave Type', 'Start Date', 'End Date', 'Duration (days)',
      'Shifts Affected', 'Advance Notice', 'Coverage Arranged', 'Status',
      'Approved By', 'Approval Date', 'Reason', 'Impact on Attendance',
    ];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    final firestore = FirebaseFirestore.instance;
    final teacherIds = audits.map((a) => a.oderId).toSet();
    
    var row = 1;
    final leaveStats = <String, Map<String, int>>{}; // teacherId -> stats
    
    for (var teacherId in teacherIds) {
      final audit = audits.firstWhere((a) => a.oderId == teacherId);
      
      // Get leave requests
      final leaveSnapshot = await firestore
          .collection('form_responses')
          .where('userId', isEqualTo: teacherId)
          .where('formId', isEqualTo: 'leave_request')
          .where('yearMonth', isEqualTo: yearMonth)
          .get();
      
      leaveStats[teacherId] = {
        'total': leaveSnapshot.docs.length,
        'approved': 0,
        'pending': 0,
        'rejected': 0,
      };
      
      for (var doc in leaveSnapshot.docs) {
        final data = doc.data();
        final responses = data['responses'] as Map<String, dynamic>? ?? {};
        final status = data['status'] as String? ?? 'pending';
        final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
        final approvedBy = data['approvedBy'] as String? ?? '';
        final approvalDate = (data['approvalDate'] as Timestamp?)?.toDate();
        
        final startDateStr = _safeToString(responses['start_date']);
        final endDateStr = _safeToString(responses['end_date']);
        
        DateTime? startDate;
        DateTime? endDate;
        int durationDays = 0;
        
        try {
          if (startDateStr.isNotEmpty) {
            startDate = DateTime.parse(startDateStr);
          }
          if (endDateStr.isNotEmpty) {
            endDate = DateTime.parse(endDateStr);
          }
          if (startDate != null && endDate != null) {
            durationDays = endDate.difference(startDate).inDays + 1;
          }
        } catch (_) {
          // Ignore parse errors
        }
        
        final shiftsAffected = int.tryParse(_safeToString(responses['affected_shifts'])) ?? 0;
        final impactOnAttendance = status == 'approved' 
            ? 'Approved - Not counted as missed'
            : status == 'rejected'
                ? 'Rejected - Counted as missed'
                : 'Pending - Not yet counted';
        
        // Update stats
        if (status == 'approved') leaveStats[teacherId]!['approved'] = (leaveStats[teacherId]!['approved'] ?? 0) + 1;
        else if (status == 'rejected') leaveStats[teacherId]!['rejected'] = (leaveStats[teacherId]!['rejected'] ?? 0) + 1;
        else leaveStats[teacherId]!['pending'] = (leaveStats[teacherId]!['pending'] ?? 0) + 1;
        
        final rowData = [
          audit.teacherName,
          _safeToString(responses['leave_type']),
          startDate != null ? DateFormat('MMM d, yyyy').format(startDate) : startDateStr,
          endDate != null ? DateFormat('MMM d, yyyy').format(endDate) : endDateStr,
          durationDays.toString(),
          shiftsAffected.toString(),
          _safeToString(responses['advance_notice']),
          _safeToString(responses['coverage_arranged']),
          status.toUpperCase(),
          approvedBy.isNotEmpty ? approvedBy : 'N/A',
          approvalDate != null ? DateFormat('MMM d, yyyy').format(approvalDate) : 'N/A',
          _safeToString(responses['reason']),
          impactOnAttendance,
        ];
        
        for (var colIdx = 0; colIdx < rowData.length; colIdx++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
          cell.value = TextCellValue(rowData[colIdx]);
          
          // Color code status
          if (colIdx == 8) {
            final statusLower = rowData[colIdx].toLowerCase();
            cell.cellStyle = CellStyle(
              backgroundColorHex: statusLower == 'approved'
                  ? ExcelColor.fromHexString('#C8E6C9')
                  : statusLower == 'rejected'
                      ? ExcelColor.fromHexString('#FFCDD2')
                      : ExcelColor.fromHexString('#FFF9C4'),
              fontColorHex: statusLower == 'approved'
                  ? ExcelColor.fromHexString('#2E7D32')
                  : statusLower == 'rejected'
                      ? ExcelColor.fromHexString('#C62828')
                      : ExcelColor.fromHexString('#F57F17'),
              bold: true,
              horizontalAlign: HorizontalAlign.Center,
            );
          }
        }
        row++;
      }
    }
    
    // Add summary row
    row++;
    final summaryStyle = CellStyle(
      bold: true,
      fontSize: 12,
      backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
    );
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue('SUMMARY')
      ..cellStyle = summaryStyle;
    
    final totalLeaves = leaveStats.values.fold(0, (sum, stats) => sum + (stats['total'] ?? 0));
    final totalApproved = leaveStats.values.fold(0, (sum, stats) => sum + (stats['approved'] ?? 0));
    final totalPending = leaveStats.values.fold(0, (sum, stats) => sum + (stats['pending'] ?? 0));
    final totalRejected = leaveStats.values.fold(0, (sum, stats) => sum + (stats['rejected'] ?? 0));
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
      ..value = TextCellValue('Total Requests: $totalLeaves')
      ..cellStyle = summaryStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
      ..value = TextCellValue('Approved: $totalApproved | Pending: $totalPending | Rejected: $totalRejected')
      ..cellStyle = summaryStyle;
    
    // Set column widths
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 0 ? 25 : i == 11 ? 40 : 18);
    }
  }

  /// Sheet 10: Leaderboard & Rankings
  static Future<void> _createLeaderboardSheet(
    Excel excel,
    List<TeacherAuditFull> audits,
    String yearMonth,
  ) async {
    final sheet = excel['🏆 Leaderboard'];
    
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#673AB7'),
    );
    
    final headers = [
      'Rank', 'Teacher', 'Overall Score', 'Performance Tier',
      'Attendance Rank', 'Attendance Score', 'Form Compliance Rank', 'Form Compliance Score',
      'Quality Rank', 'Quality Score', 'Previous Month Score', 'Score Change', 'Rank Change',
      'Awards', 'Total Shifts', 'Completed', 'Missed', 'Late Arrivals',
      'Forms Submitted', 'Forms Required', 'Form Compliance %',
    ];
    
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Sort audits by overall score for ranking
    final sortedAudits = List<TeacherAuditFull>.from(audits)
      ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
    
    // Calculate rankings
    final attendanceSorted = List<TeacherAuditFull>.from(audits)
      ..sort((a, b) {
        final aScore = (a.completionRate * 0.6) + (a.punctualityRate * 0.4);
        final bScore = (b.completionRate * 0.6) + (b.punctualityRate * 0.4);
        return bScore.compareTo(aScore);
      });
    
    final formComplianceSorted = List<TeacherAuditFull>.from(audits)
      ..sort((a, b) => b.formComplianceRate.compareTo(a.formComplianceRate));
    
    final qualitySorted = List<TeacherAuditFull>.from(audits)
      ..sort((a, b) => b.coachScore.compareTo(a.coachScore));
    
    // Create rank maps
    final overallRanks = <String, int>{};
    final attendanceRanks = <String, int>{};
    final formRanks = <String, int>{};
    final qualityRanks = <String, int>{};
    
    for (var i = 0; i < sortedAudits.length; i++) {
      overallRanks[sortedAudits[i].oderId] = i + 1;
      attendanceRanks[attendanceSorted[i].oderId] = i + 1;
      formRanks[formComplianceSorted[i].oderId] = i + 1;
      qualityRanks[qualitySorted[i].oderId] = i + 1;
    }
    
    var row = 1;
    for (var i = 0; i < sortedAudits.length; i++) {
      final audit = sortedAudits[i];
      final attendanceScore = (audit.completionRate * 0.6) + (audit.punctualityRate * 0.4);
      
      // Determine awards (simplified - would need leaderboard service for full logic)
      final awards = <String>[];
      if (i == 0 && audit.overallScore >= 75) awards.add('🏆 Teacher of Month');
      if (attendanceRanks[audit.oderId] == 1 && attendanceScore >= 90) awards.add('⏰ Most Reliable');
      if (formRanks[audit.oderId] == 1 && audit.formComplianceRate >= 95) awards.add('📋 Most Diligent');
      if (qualityRanks[audit.oderId] == 1 && audit.coachScore >= 80) awards.add('⭐ Top Rated');
      
      final rowData = [
        (i + 1).toString(),
        audit.teacherName,
        audit.overallScore.toStringAsFixed(1),
        _formatTier(audit.performanceTier),
        attendanceRanks[audit.oderId]?.toString() ?? '-',
        attendanceScore.toStringAsFixed(1),
        formRanks[audit.oderId]?.toString() ?? '-',
        audit.formComplianceRate.toStringAsFixed(1),
        qualityRanks[audit.oderId]?.toString() ?? '-',
        audit.coachScore.toStringAsFixed(1),
        '0', // Previous month score (would need leaderboard service)
        '0', // Score change
        '0', // Rank change
        awards.join(', '),
        audit.totalClassesScheduled.toString(),
        audit.totalClassesCompleted.toString(),
        audit.totalClassesMissed.toString(),
        audit.lateClockIns.toString(),
        audit.readinessFormsSubmitted.toString(),
        audit.readinessFormsRequired.toString(),
        audit.formComplianceRate.toStringAsFixed(1) + '%',
      ];
      
      for (var colIdx = 0; colIdx < rowData.length; colIdx++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
        cell.value = TextCellValue(rowData[colIdx]);
        
        // Color code rank (top 3)
        if (colIdx == 0) {
          if (i == 0) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#FFD700'),
              fontColorHex: ExcelColor.fromHexString('#000000'),
              bold: true,
              fontSize: 12,
            );
          } else if (i == 1) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#C0C0C0'),
              fontColorHex: ExcelColor.fromHexString('#000000'),
              bold: true,
            );
          } else if (i == 2) {
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString('#CD7F32'),
              fontColorHex: ExcelColor.white,
              bold: true,
            );
          }
        }
        
        // Color code performance tier
        if (colIdx == 3) {
          cell.cellStyle = CellStyle(
            backgroundColorHex: _getTierColor(audit.performanceTier),
            fontColorHex: ExcelColor.white,
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
        }
        
        // Color code scores
        if (colIdx == 2 || colIdx == 5 || colIdx == 7 || colIdx == 9) {
          final score = double.tryParse(rowData[colIdx]) ?? 0;
          cell.cellStyle = CellStyle(
            backgroundColorHex: _getRateColor(score),
            horizontalAlign: HorizontalAlign.Center,
          );
        }
      }
      row++;
    }
    
    // Set column widths
    sheet.setColumnWidth(0, 8); // Rank
    sheet.setColumnWidth(1, 25); // Teacher
    sheet.setColumnWidth(2, 15); // Overall Score
    sheet.setColumnWidth(3, 18); // Tier
    for (var i = 4; i < headers.length; i++) {
      sheet.setColumnWidth(i, 16);
    }
  }

  // Helper methods for additional forms
  static String _getFormCategoryFromId(String formId) {
    if (formId.contains('feedback') || formId.contains('complaint')) return 'Feedback';
    if (formId.contains('assessment') || formId.contains('student') || formId.contains('parent')) return 'Assessment';
    if (formId.contains('leave') || formId.contains('incident') || formId.contains('admin')) return 'Administrative';
    return 'Other';
  }

  static String _formatAdditionalFormType(String formId) {
    if (formId.contains('teacher_feedback')) return '💬 Teacher Feedback';
    if (formId.contains('leadership_feedback')) return '👔 Leadership Feedback';
    if (formId.contains('admin_self')) return '📊 Admin Self-Assessment';
    if (formId.contains('coach_performance')) return '👑 Coach Review';
    if (formId.contains('student_assessment')) return '📚 Student Assessment';
    if (formId.contains('parent_feedback')) return '👨‍👩‍👧 Parent Feedback';
    if (formId.contains('leave_request')) return '🏖️ Leave Request';
    if (formId.contains('incident_report')) return '⚠️ Incident Report';
    return '📝 Other';
  }
}

