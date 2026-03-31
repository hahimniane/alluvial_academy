import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:alluwalacademyadmin/features/audit/config/admin_audit_evaluation_taxonomy.dart';
import 'package:alluwalacademyadmin/features/audit/models/admin_audit.dart';
import '../../../core/utils/save_export_file.dart';
import 'dart:html' if (dart.library.io) 'package:alluwalacademyadmin/core/utils/html_stub.dart' as html;

/// Labels for PDF/Excel admin evaluation exports (from [AppLocalizations]).
class AdminEvalExportLabels {
  final String documentTitle;
  final String evaluatedLabel;
  final String evaluatorLabel;
  final String periodLabel;
  final String documentDateLabel;
  final String subtitle;
  final String ceoNotesHeading;
  final String paymentHeading;
  final String bonusLabel;
  final String paycutLabel;
  final String rationaleLabel;
  final String tasksSectionTitle;
  final String otherSectionTitle;
  final String autoKpiLine;
  final String unknownEvaluator;
  final String evaluatorSectionCommentLabel;

  const AdminEvalExportLabels({
    required this.documentTitle,
    required this.evaluatedLabel,
    required this.evaluatorLabel,
    required this.periodLabel,
    required this.documentDateLabel,
    required this.subtitle,
    required this.ceoNotesHeading,
    required this.paymentHeading,
    required this.bonusLabel,
    required this.paycutLabel,
    required this.rationaleLabel,
    required this.tasksSectionTitle,
    required this.otherSectionTitle,
    required this.autoKpiLine,
    required this.unknownEvaluator,
    required this.evaluatorSectionCommentLabel,
  });

  factory AdminEvalExportLabels.fromL10n(AppLocalizations l10n, AdminAudit audit) {
    return AdminEvalExportLabels(
      documentTitle: l10n.adminAuditEvalExportDocTitle,
      evaluatedLabel: l10n.adminAuditEvalExportEvaluated,
      evaluatorLabel: l10n.adminAuditEvalExportEvaluator,
      periodLabel: l10n.adminAuditEvalExportPeriod,
      documentDateLabel: l10n.adminAuditEvalExportDocumentDate,
      subtitle: l10n.adminAuditEvalExportSubtitle,
      ceoNotesHeading: l10n.adminAuditEvalExportCeoNotesHeading,
      paymentHeading: l10n.adminAuditEvalExportPaymentHeading,
      bonusLabel: l10n.adminAuditEvalExportBonus,
      paycutLabel: l10n.adminAuditEvalExportPaycut,
      rationaleLabel: l10n.adminAuditEvalExportRationale,
      tasksSectionTitle: l10n.adminAuditEvalExportTasksSection,
      otherSectionTitle: l10n.adminAuditEvalExportOtherSection,
      autoKpiLine: l10n.adminAuditEvalExportAutoKpi(
        audit.overallScore,
        audit.formComplianceScore,
        audit.taskEfficiencyScore,
      ),
      unknownEvaluator: l10n.adminAuditEvalExportUnknownEvaluator,
      evaluatorSectionCommentLabel: l10n.adminAuditEvalSectionCommentLabel,
    );
  }
}

/// Exports manual admin evaluation scores (PDF / Excel).
class AdminAuditEvaluationExportService {
  AdminAuditEvaluationExportService._();

  static void _downloadWebBytes(List<int> bytes, String fileName, String mimeType) {
    final b = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(b);
    final anchor = html.AnchorElement()
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    Future.delayed(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  static Set<String> _knownCriterionIds() {
    final s = <String>{};
    for (final th in AdminAuditEvaluationTaxonomy.formThemes) {
      for (final c in th.criteria) {
        s.add(c.id);
      }
    }
    for (final c in AdminAuditEvaluationTaxonomy.taskCriteria) {
      s.add(c.id);
    }
    return s;
  }

  static void _addPdfEvaluatorComment(
    List<pw.Widget> blocks,
    AdminEvalExportLabels labels,
    String? raw,
  ) {
    final t = raw?.trim();
    if (t == null || t.isEmpty) return;
    blocks.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Text(
          '${labels.evaluatorSectionCommentLabel}: $t',
          style: pw.TextStyle(
            fontSize: 8,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey700,
          ),
        ),
      ),
    );
  }

  static pw.Widget _metaTable(
    AdminEvalExportLabels labels,
    AdminAudit audit,
    String evaluatorName,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    String ev = evaluatorName.trim();
    if (ev.isEmpty) ev = labels.unknownEvaluator;

    pw.TableRow row(String a, String b) => pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(a, style: labelStyle),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(b, style: valueStyle),
            ),
          ],
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(120),
        1: const pw.FlexColumnWidth(),
      },
      children: [
        row(labels.evaluatedLabel, audit.adminName),
        row(labels.evaluatorLabel, ev),
        row(labels.periodLabel, audit.yearMonth),
        row(
          labels.documentDateLabel,
          DateFormat.yMMMd().format(DateTime.now()),
        ),
      ],
    );
  }

  static Future<void> exportPdf({
    required AdminAudit audit,
    required Map<String, int?> scores,
    required Map<String, String> criterionLabels,
    required AdminEvalExportLabels labels,
    String evaluatorName = '',
  }) async {
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
    final labelStyle = pw.TextStyle(font: boldFont, fontSize: 9);
    const valueStyle = pw.TextStyle(fontSize: 9);
    final sectionTitleStyle = pw.TextStyle(font: boldFont, fontSize: 11);
    const bodyStyle = pw.TextStyle(fontSize: 9);

    final blocks = <pw.Widget>[
      pw.Center(
        child: pw.Text(
          labels.documentTitle,
          style: pw.TextStyle(font: boldFont, fontSize: 16),
          textAlign: pw.TextAlign.center,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Center(
        child: pw.Text(
          labels.subtitle,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          textAlign: pw.TextAlign.center,
        ),
      ),
      pw.SizedBox(height: 14),
      _metaTable(labels, audit, evaluatorName, labelStyle, valueStyle),
      pw.SizedBox(height: 10),
      pw.Text(labels.autoKpiLine, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
      pw.SizedBox(height: 14),
    ];

    final secComments = audit.adminEvalSectionComments;
    final allNote = secComments[AdminAuditEvaluationTaxonomy.themeAllId];
    if (allNote != null && allNote.trim().isNotEmpty) {
      blocks.add(
        pw.Text(AdminAuditEvaluationTaxonomy.themeAll.titleEn, style: sectionTitleStyle),
      );
      blocks.add(pw.SizedBox(height: 4));
      _addPdfEvaluatorComment(blocks, labels, allNote);
      blocks.add(pw.SizedBox(height: 10));
    }

    for (final th in AdminAuditEvaluationTaxonomy.formThemes) {
      final rows = <pw.Widget>[];
      for (final c in th.criteria) {
        final v = scores[c.id];
        if (v == null) continue;
        final label = criterionLabels[c.id] ?? c.labelEn;
        rows.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Text('• $label', style: bodyStyle)),
                pw.Text('$v / 5', style: pw.TextStyle(font: boldFont, fontSize: 9)),
              ],
            ),
          ),
        );
      }
      if (rows.isEmpty) continue;
      blocks.add(pw.Text(th.titleEn, style: sectionTitleStyle));
      blocks.add(pw.SizedBox(height: 4));
      _addPdfEvaluatorComment(blocks, labels, secComments[th.id]);
      blocks.addAll(rows);
      blocks.add(pw.SizedBox(height: 10));
    }

    final taskRows = <pw.Widget>[];
    for (final c in AdminAuditEvaluationTaxonomy.taskCriteria) {
      final v = scores[c.id];
      if (v == null) continue;
      final label = criterionLabels[c.id] ?? c.labelEn;
      taskRows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.Text('• $label', style: bodyStyle)),
              pw.Text('$v / 5', style: pw.TextStyle(font: boldFont, fontSize: 9)),
            ],
          ),
        ),
      );
    }
    if (taskRows.isNotEmpty) {
      blocks.add(pw.Text(labels.tasksSectionTitle, style: sectionTitleStyle));
      blocks.add(pw.SizedBox(height: 4));
      blocks.addAll(taskRows);
      blocks.add(pw.SizedBox(height: 10));
    }

    final known = _knownCriterionIds();
    final other = <MapEntry<String, int>>[];
    for (final e in scores.entries) {
      if (e.value == null || known.contains(e.key)) continue;
      other.add(MapEntry(e.key, e.value!));
    }
    if (other.isNotEmpty) {
      blocks.add(pw.Text(labels.otherSectionTitle, style: sectionTitleStyle));
      blocks.add(pw.SizedBox(height: 4));
      for (final e in other) {
        final label = criterionLabels[e.key] ?? e.key;
        blocks.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Text('• $label', style: bodyStyle)),
                pw.Text('${e.value} / 5', style: pw.TextStyle(font: boldFont, fontSize: 9)),
              ],
            ),
          ),
        );
      }
      blocks.add(pw.SizedBox(height: 10));
    }

    final showPayment = audit.ceoBonusMonthlyUsd > 0 ||
        audit.ceoPaycutMonthlyUsd > 0 ||
        audit.ceoAdjustmentRationale.trim().isNotEmpty;
    if (showPayment) {
      blocks.add(pw.Text(labels.paymentHeading, style: sectionTitleStyle));
      blocks.add(pw.SizedBox(height: 4));
      if (audit.ceoBonusMonthlyUsd > 0) {
        blocks.add(pw.Text(
          '${labels.bonusLabel}: \$${audit.ceoBonusMonthlyUsd.toStringAsFixed(2)}',
          style: bodyStyle,
        ));
        blocks.add(pw.SizedBox(height: 2));
      }
      if (audit.ceoPaycutMonthlyUsd > 0) {
        blocks.add(pw.Text(
          '${labels.paycutLabel}: \$${audit.ceoPaycutMonthlyUsd.toStringAsFixed(2)}',
          style: bodyStyle,
        ));
        blocks.add(pw.SizedBox(height: 2));
      }
      if (audit.ceoAdjustmentRationale.trim().isNotEmpty) {
        blocks.add(pw.Text('${labels.rationaleLabel}:', style: labelStyle));
        blocks.add(pw.SizedBox(height: 2));
        blocks.add(pw.Text(audit.ceoAdjustmentRationale.trim(), style: bodyStyle));
      }
      blocks.add(pw.SizedBox(height: 12));
    }

    if (audit.ceoNotes.trim().isNotEmpty) {
      blocks.add(pw.Text(labels.ceoNotesHeading, style: sectionTitleStyle));
      blocks.add(pw.SizedBox(height: 4));
      blocks.add(pw.Text(audit.ceoNotes.trim(), style: bodyStyle));
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => blocks,
      ),
    );
    final bytes = await doc.save();
    if (bytes.isEmpty) return;
    final name =
        'admin_eval_${audit.adminId}_${audit.yearMonth}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    if (kIsWeb) {
      _downloadWebBytes(bytes, name, 'application/pdf');
    } else {
      await saveExportBytes(bytes, name);
    }
  }

  static Future<void> exportExcel({
    required AdminAudit audit,
    required Map<String, int?> scores,
    required Map<String, String> criterionLabels,
    required AdminEvalExportLabels labels,
    String evaluatorName = '',
  }) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Evaluation'];
    if (excel.tables.containsKey('Sheet1') && excel.tables.length > 1) {
      excel.delete('Sheet1');
    }

    // Match AdminSubmissionsExportService: wrap + top align so long notes read like the submissions export.
    final wrapStyle = xl.CellStyle(
      textWrapping: xl.TextWrapping.WrapText,
      verticalAlign: xl.VerticalAlign.Top,
      horizontalAlign: xl.HorizontalAlign.Left,
    );
    final titleStyle = xl.CellStyle(
      bold: true,
      verticalAlign: xl.VerticalAlign.Center,
      horizontalAlign: xl.HorizontalAlign.Left,
      textWrapping: xl.TextWrapping.WrapText,
    );
    final sectionBandStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.blueGrey50,
      verticalAlign: xl.VerticalAlign.Top,
      horizontalAlign: xl.HorizontalAlign.Left,
      textWrapping: xl.TextWrapping.WrapText,
    );
    final scoreNumStyle = xl.CellStyle(
      verticalAlign: xl.VerticalAlign.Top,
      horizontalAlign: xl.HorizontalAlign.Center,
    );

    void writeCell(int col, int row, String v, {xl.CellStyle? style}) {
      final c = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      c.value = xl.TextCellValue(v);
      c.cellStyle = style ?? wrapStyle;
    }

    void mergeAcrossAB(int row, String text, xl.CellStyle style) {
      final a = xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row);
      final b = xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row);
      sheet.merge(a, b, customValue: xl.TextCellValue(text));
      sheet.cell(a).cellStyle = style;
    }

    var r = 0;
    mergeAcrossAB(r, labels.documentTitle, titleStyle);
    r += 2;
    writeCell(0, r, labels.evaluatedLabel);
    writeCell(1, r, audit.adminName);
    r++;
    final ev = evaluatorName.trim().isEmpty ? labels.unknownEvaluator : evaluatorName.trim();
    writeCell(0, r, labels.evaluatorLabel);
    writeCell(1, r, ev);
    r++;
    writeCell(0, r, labels.periodLabel);
    writeCell(1, r, audit.yearMonth);
    r++;
    writeCell(0, r, labels.documentDateLabel);
    writeCell(1, r, DateFormat.yMMMd().format(DateTime.now()));
    r++;
    mergeAcrossAB(r, labels.autoKpiLine, wrapStyle);
    r += 2;

    mergeAcrossAB(r, labels.subtitle, wrapStyle);
    r += 2;

    final secComments = audit.adminEvalSectionComments;

    void excelSectionComment(String? raw) {
      final t = raw?.trim();
      if (t == null || t.isEmpty) return;
      writeCell(0, r, labels.evaluatorSectionCommentLabel);
      writeCell(1, r, t, style: wrapStyle);
      r++;
    }

    final allNoteX = secComments[AdminAuditEvaluationTaxonomy.themeAllId];
    if (allNoteX != null && allNoteX.trim().isNotEmpty) {
      mergeAcrossAB(r, AdminAuditEvaluationTaxonomy.themeAll.titleEn, sectionBandStyle);
      r++;
      excelSectionComment(allNoteX);
      r++;
    }

    void scoredRow(String criterion, int v) {
      writeCell(0, r, criterion, style: wrapStyle);
      writeCell(1, r, '$v', style: scoreNumStyle);
      r++;
    }

    for (final th in AdminAuditEvaluationTaxonomy.formThemes) {
      var any = false;
      for (final c in th.criteria) {
        final v = scores[c.id];
        if (v != null) any = true;
      }
      if (!any) continue;
      mergeAcrossAB(r, th.titleEn, sectionBandStyle);
      r++;
      excelSectionComment(secComments[th.id]);
      for (final c in th.criteria) {
        final v = scores[c.id];
        if (v == null) continue;
        final label = criterionLabels[c.id] ?? c.labelEn;
        scoredRow(label, v);
      }
      r++;
    }

    var anyTask = false;
    for (final c in AdminAuditEvaluationTaxonomy.taskCriteria) {
      if (scores[c.id] != null) anyTask = true;
    }
    if (anyTask) {
      mergeAcrossAB(r, labels.tasksSectionTitle, sectionBandStyle);
      r++;
      excelSectionComment(secComments[AdminAuditEvaluationTaxonomy.tasksEvalSectionId]);
      for (final c in AdminAuditEvaluationTaxonomy.taskCriteria) {
        final v = scores[c.id];
        if (v == null) continue;
        final label = criterionLabels[c.id] ?? c.labelEn;
        scoredRow(label, v);
      }
      r++;
    }

    final known = _knownCriterionIds();
    final other = <MapEntry<String, int>>[];
    for (final e in scores.entries) {
      if (e.value == null || known.contains(e.key)) continue;
      other.add(MapEntry(e.key, e.value!));
    }
    if (other.isNotEmpty) {
      mergeAcrossAB(r, labels.otherSectionTitle, sectionBandStyle);
      r++;
      for (final e in other) {
        scoredRow(criterionLabels[e.key] ?? e.key, e.value);
      }
      r++;
    }

    final showPayment = audit.ceoBonusMonthlyUsd > 0 ||
        audit.ceoPaycutMonthlyUsd > 0 ||
        audit.ceoAdjustmentRationale.trim().isNotEmpty;
    if (showPayment) {
      mergeAcrossAB(r, labels.paymentHeading, sectionBandStyle);
      r++;
      if (audit.ceoBonusMonthlyUsd > 0) {
        writeCell(0, r, labels.bonusLabel);
        writeCell(1, r, audit.ceoBonusMonthlyUsd.toStringAsFixed(2), style: scoreNumStyle);
        r++;
      }
      if (audit.ceoPaycutMonthlyUsd > 0) {
        writeCell(0, r, labels.paycutLabel);
        writeCell(1, r, audit.ceoPaycutMonthlyUsd.toStringAsFixed(2), style: scoreNumStyle);
        r++;
      }
      if (audit.ceoAdjustmentRationale.trim().isNotEmpty) {
        writeCell(0, r, labels.rationaleLabel);
        writeCell(1, r, audit.ceoAdjustmentRationale.trim(), style: wrapStyle);
        r++;
      }
      r++;
    }

    if (audit.ceoNotes.trim().isNotEmpty) {
      mergeAcrossAB(r, labels.ceoNotesHeading, sectionBandStyle);
      r++;
      mergeAcrossAB(r, audit.ceoNotes.trim(), wrapStyle);
      r++;
    }

    sheet.setColumnWidth(0, 56);
    sheet.setColumnWidth(1, 56);

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) return;
    final name =
        'admin_eval_${audit.adminId}_${audit.yearMonth}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
    if (kIsWeb) {
      _downloadWebBytes(bytes, name, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } else {
      await saveExportBytes(bytes, name);
    }
  }

  /// Build label map for all known criterion ids.
  static Map<String, String> criterionLabelMap() {
    final m = <String, String>{};
    for (final th in AdminAuditEvaluationTaxonomy.formThemes) {
      for (final c in th.criteria) {
        m[c.id] = c.labelEn;
      }
    }
    for (final c in AdminAuditEvaluationTaxonomy.taskCriteria) {
      m[c.id] = c.labelEn;
    }
    return m;
  }
}
