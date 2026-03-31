import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:alluwalacademyadmin/features/forms/services/form_labels_cache_service.dart';
import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';
import '../../../core/utils/save_export_file.dart';

import 'dart:html' if (dart.library.io) 'package:alluwalacademyadmin/core/utils/html_stub.dart' as html;

/// Export service for Admin → All submissions (review mode).
/// Generates a single file (PDF or Excel) containing the selected submissions,
/// grouped per teacher. Progress is emitted per teacher.
class AdminSubmissionsExportService {
  AdminSubmissionsExportService._();

  /// Prevents duplicate downloads if export is triggered twice in quick succession.
  static bool _exportInProgress = false;

  static String _pdfTeacherAnchor(int teacherIndex) => 'teacher_section_$teacherIndex';

  /// [submissionsByTeacher] contains ONLY the selected documents per teacher.
  static Future<void> exportSelectedSubmissions({
    required Map<String, List<QueryDocumentSnapshot>> submissionsByTeacher,
    required Map<String, String> teacherNames,
    required Map<String, String> formTitles,
    required Map<String, TeachingShift> shiftMap,
    required String format, // 'pdf' | 'excel'
    required String locale,
    required void Function(String teacherId, int index, int total) onTeacherProgress,
  }) async {
    if (submissionsByTeacher.isEmpty) return;
    if (_exportInProgress) return;
    _exportInProgress = true;

    final teacherIds = submissionsByTeacher.keys.toList()
      ..sort((a, b) {
        final na = teacherNames[a] ?? '';
        final nb = teacherNames[b] ?? '';
        return na.compareTo(nb);
      });

    final exportBaseName =
        'admin_submissions_export_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}';

    try {
      if (format == 'pdf') {
        await _exportToPdf(
          submissionsByTeacher: submissionsByTeacher,
          teacherIds: teacherIds,
          teacherNames: teacherNames,
          formTitles: formTitles,
          shiftMap: shiftMap,
          locale: locale,
          exportBaseName: exportBaseName,
          onTeacherProgress: onTeacherProgress,
        );
      } else {
        await _exportToExcel(
          submissionsByTeacher: submissionsByTeacher,
          teacherIds: teacherIds,
          teacherNames: teacherNames,
          formTitles: formTitles,
          shiftMap: shiftMap,
          locale: locale,
          exportBaseName: exportBaseName,
          onTeacherProgress: onTeacherProgress,
        );
      }
    } finally {
      _exportInProgress = false;
    }
  }

  static Future<void> _exportToExcel({
    required Map<String, List<QueryDocumentSnapshot>> submissionsByTeacher,
    required List<String> teacherIds,
    required Map<String, String> teacherNames,
    required Map<String, String> formTitles,
    required Map<String, TeachingShift> shiftMap,
    required String locale,
    required String exportBaseName,
    required void Function(String teacherId, int index, int total) onTeacherProgress,
  }) async {
    final excel = xl.Excel.createExcel();
    final existingSheetNames = <String>{};
    final lc = locale.toLowerCase();
    final isFr = lc.startsWith('fr');
    final isAr = lc.startsWith('ar');
    final questionHeader = isFr ? 'Question' : isAr ? 'السؤال' : 'Question';
    final answerHeader = isFr ? 'Réponse' : isAr ? 'الإجابة' : 'Answer';
    final formMetaLabel = isFr ? 'Formulaire' : isAr ? 'النموذج' : 'Form';
    final submittedMetaLabel = isFr ? 'Soumis le' : isAr ? 'تاريخ الإرسال' : 'Submitted';
    final shiftMetaLabel = isFr ? 'Shift' : isAr ? 'الوردية' : 'Shift';

    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.blueGrey50,
      horizontalAlign: xl.HorizontalAlign.Left,
      verticalAlign: xl.VerticalAlign.Center,
      textWrapping: xl.TextWrapping.WrapText,
    );
    final metaBlockStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.grey100,
      horizontalAlign: xl.HorizontalAlign.Left,
      verticalAlign: xl.VerticalAlign.Top,
      textWrapping: xl.TextWrapping.WrapText,
    );
    final qaCellStyle = xl.CellStyle(
      textWrapping: xl.TextWrapping.WrapText,
      verticalAlign: xl.VerticalAlign.Top,
      horizontalAlign: xl.HorizontalAlign.Left,
    );

    var isFirstTeacherSheet = true;

    for (var i = 0; i < teacherIds.length; i++) {
      final teacherId = teacherIds[i];
      final teacherName = teacherNames[teacherId] ?? teacherId;
      final sheetName = _sanitizeExcelSheetName(
        teacherName,
        existing: existingSheetNames.toList(),
      );
      existingSheetNames.add(sheetName);
      final sheet = excel[sheetName];

      if (isFirstTeacherSheet) {
        isFirstTeacherSheet = false;
        if (excel.tables.containsKey('Sheet1') && excel.tables.length > 1) {
          excel.delete('Sheet1');
        }
      }

      final docs = submissionsByTeacher[teacherId] ?? const [];
      final includeShiftColumn = _sheetHasAnyShiftId(docs);

      final h0 = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      h0.value = xl.TextCellValue(questionHeader);
      h0.cellStyle = headerStyle;
      final h1 = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
      h1.value = xl.TextCellValue(answerHeader);
      h1.cellStyle = headerStyle;

      sheet.setColumnWidth(0, 56);
      sheet.setColumnWidth(1, 56);

      var dataRow0 = 1;

      for (final doc in docs) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final formTitle = _normalizeText(_resolveFormTitle(data, formTitles));
        final submittedAt = _resolveSubmittedAt(data);
        final shiftText = _shiftDisplayText(data, shiftMap);

        final metaLines = <String>[
          '$formMetaLabel: $formTitle',
          '$submittedMetaLabel: $submittedAt',
          if (includeShiftColumn) '$shiftMetaLabel: ${shiftText.isEmpty ? '-' : shiftText}',
        ];
        final metaText = metaLines.join('\n');

        final metaStart = xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: dataRow0);
        final metaEnd = xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: dataRow0);
        sheet.merge(metaStart, metaEnd, customValue: xl.TextCellValue(metaText));
        sheet.cell(metaStart).cellStyle = metaBlockStyle;
        dataRow0++;

        final responses =
            Map<String, dynamic>.from(data['responses'] ?? data['answers'] ?? {});

        final labelMap = await FormLabelsCacheService().getLabelsForFormResponse(doc.id);

        final fieldEntries = responses.entries
            .where((e) => !e.key.toString().startsWith('_'))
            .toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

        if (fieldEntries.isEmpty) {
          _writeExcelQaRow(sheet, dataRow0, '-', '-', qaCellStyle);
          dataRow0++;
        } else {
          for (final e in fieldEntries) {
            final rawLabel = labelMap[e.key.toString()] ?? e.key.toString();
            final question = _labelForLocale(rawLabel, isFr, isAr);
            final answer = _normalizeText(_formatValue(e.value));
            _writeExcelQaRow(sheet, dataRow0, question, answer, qaCellStyle);
            dataRow0++;
          }
        }

        dataRow0++;
      }

      onTeacherProgress(teacherId, i, teacherIds.length);
    }

    // Use encode(), not save(): on web, save() also triggers a browser download
    // as "FlutterExcel.xlsx" via the package helper — we name the file ourselves below.
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) return;

    if (kIsWeb) {
      _downloadWebBytes(bytes, '$exportBaseName.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } else {
      await saveExportBytes(bytes, '$exportBaseName.xlsx');
    }
  }

  static void _writeExcelQaRow(
    xl.Sheet sheet,
    int rowIndex0Based,
    String question,
    String answer,
    xl.CellStyle cellStyle,
  ) {
    final q = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex0Based));
    q.value = xl.TextCellValue(question);
    q.cellStyle = cellStyle;
    final a = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex0Based));
    a.value = xl.TextCellValue(answer);
    a.cellStyle = cellStyle;
  }

  /// True if any submission on this sheet references a shift (omit shift line entirely when false).
  static bool _sheetHasAnyShiftId(List<QueryDocumentSnapshot> docs) {
    for (final doc in docs) {
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final shiftId = (data['shiftId'] ?? data['shift_id'] ?? '').toString().trim();
      if (shiftId.isNotEmpty) return true;
    }
    return false;
  }

  static String _shiftDisplayText(
    Map<String, dynamic> data,
    Map<String, TeachingShift> shiftMap,
  ) {
    final shiftId = (data['shiftId'] ?? data['shift_id'] ?? '').toString().trim();
    if (shiftId.isEmpty) return '';
    final shiftSummary = shiftMap[shiftId];
    if (shiftSummary == null) return shiftId;
    return _normalizeText(_formatShiftSummary(shiftSummary));
  }

  static Future<void> _exportToPdf({
    required Map<String, List<QueryDocumentSnapshot>> submissionsByTeacher,
    required List<String> teacherIds,
    required Map<String, String> teacherNames,
    required Map<String, String> formTitles,
    required Map<String, TeachingShift> shiftMap,
    required String locale,
    required String exportBaseName,
    required void Function(String teacherId, int index, int total) onTeacherProgress,
  }) async {
    final pdf = pw.Document();
    final lcPdf = locale.toLowerCase();
    final isFr = lcPdf.startsWith('fr');
    final isAr = lcPdf.startsWith('ar');
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
    );

    final titleText = isFr
        ? 'Export des soumissions selectionnees'
        : 'Selected submissions export';
    final summaryText = isFr
        ? 'Sommaire (cliquez pour aller à la section)'
        : 'Summary (click to jump to section)';
    final generatedAtLabel = isFr ? 'Genere le' : 'Generated at';
    final submissionsLabel = isFr ? 'soumission(s)' : 'submission(s)';
    final submittedLabel = isFr ? 'Soumis' : 'Submitted';
    final shiftLabel = isFr ? 'Shift' : 'Shift';
    final teacherLabel = isFr ? 'Enseignant' : 'Teacher';
    final questionLabel = isFr ? 'Question' : 'Question';
    final answerLabel = isFr ? 'Reponse' : 'Answer';

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#EAF2FF'),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  titleText,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1D4ED8'),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '$generatedAtLabel: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            summaryText,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...teacherIds.asMap().entries.map((entry) {
            final index = entry.key;
            final idx = index + 1;
            final teacherId = entry.value;
            final name = _normalizeText(teacherNames[teacherId] ?? teacherId);
            final count = submissionsByTeacher[teacherId]?.length ?? 0;
            final anchor = _pdfTeacherAnchor(index);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Link(
                destination: anchor,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '$idx. ',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        '$name — $count $submissionsLabel',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColor.fromHex('#1D4ED8'),
                          decoration: pw.TextDecoration.underline,
                          decorationColor: PdfColor.fromHex('#1D4ED8'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );

    for (var i = 0; i < teacherIds.length; i++) {
      final teacherId = teacherIds[i];
      final teacherName = _normalizeText(teacherNames[teacherId] ?? teacherId);
      final docs = submissionsByTeacher[teacherId] ?? const [];
      final teacherPosition = '${i + 1}/${teacherIds.length}';
      final widgets = <pw.Widget>[
        pw.Outline(
          name: _pdfTeacherAnchor(i),
          title: teacherName,
          level: 0,
          color: PdfColor.fromHex('#1D4ED8'),
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '$teacherLabel: $teacherName',
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Text(teacherPosition, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 12),
      ];

      for (final doc in docs) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final formTitle = _normalizeText(_resolveFormTitle(data, formTitles));
        final submittedAt = _resolveSubmittedAt(data);
        final shiftId = (data['shiftId'] ?? data['shift_id'] ?? '').toString();
        final shiftSummary = shiftMap[shiftId];
        final shiftText = shiftSummary == null
            ? shiftId
            : _normalizeText(_formatShiftSummary(shiftSummary));

        final responses =
            Map<String, dynamic>.from(data['responses'] ?? data['answers'] ?? {});

        final labelMap = await FormLabelsCacheService().getLabelsForFormResponse(doc.id);

        final qaRows = <pw.Widget>[];
        responses.forEach((fieldId, value) {
          if (fieldId.toString().startsWith('_')) return;
          final rawLabel = labelMap[fieldId.toString()] ?? fieldId.toString();
          final label = _labelForLocale(rawLabel, isFr, isAr);
          final answer = _normalizeText(_formatValue(value));
          qaRows.add(
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 6),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFFFFF'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '$questionLabel: $label',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1F2937'),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    '$answerLabel: $answer',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        });

        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F9FAFB'),
              border: pw.Border.all(color: PdfColor.fromHex('#D1D5DB'), width: 0.8),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  formTitle,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '$submittedLabel: $submittedAt',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  '$shiftLabel: $shiftText',
                  style: pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 8),
                ...qaRows,
              ],
            ),
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '$teacherName - ${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (context) => widgets,
        ),
      );
      onTeacherProgress(teacherId, i, teacherIds.length);
    }

    final bytes = await pdf.save();
    if (bytes.isEmpty) return;

    if (kIsWeb) {
      _downloadWebBytes(bytes, '$exportBaseName.pdf', 'application/pdf');
    } else {
      await saveExportBytes(bytes, '$exportBaseName.pdf');
    }
  }

  static String _resolveFormTitle(
    Map<String, dynamic> submissionData,
    Map<String, String> formTitles,
  ) {
    final formId = submissionData['formId'] as String?;
    if (formId != null && formTitles.containsKey(formId)) {
      return formTitles[formId]!;
    }
    final inline = submissionData['formName'] ?? submissionData['formTitle'] ?? submissionData['title'];
    if (inline != null && inline.toString().isNotEmpty) return inline.toString();
    final formType = (submissionData['formType'] ?? '').toString().toLowerCase();
    if (formType == 'daily') return 'Daily Class Report';
    if (formType == 'weekly') return 'Weekly Report';
    if (formType == 'monthly') return 'Monthly Report';
    return 'Form';
  }

  static String _resolveSubmittedAt(Map<String, dynamic> submissionData) {
    final ts = submissionData['submittedAt'] ?? submissionData['createdAt'];
    if (ts is Timestamp) {
      final d = ts.toDate();
      return DateFormat('yyyy-MM-dd HH:mm').format(d);
    }
    if (ts is DateTime) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts);
    }
    return '';
  }

  static String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is Timestamp) return DateFormat('yyyy-MM-dd').format(value.toDate());
    if (value is DateTime) return DateFormat('yyyy-MM-dd').format(value);
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) return value.map((e) => e.toString()).join(', ');
    return value.toString();
  }

  static String _formatShiftSummary(TeachingShift shift) {
    final day = DateFormat('EEE dd MMM').format(shift.shiftStart);
    final start = DateFormat('HH:mm').format(shift.shiftStart);
    final end = DateFormat('HH:mm').format(shift.shiftEnd);
    return '$day $start-$end';
  }

  static String _normalizeText(String raw) {
    return raw
        .replaceAll('\uFFFD', "'")
        .replaceAll('’', "'")
        .replaceAll('`', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Picks one side of "English / Français" style labels for readability in exports.
  static String _labelForLocale(String label, bool preferFrench, bool preferArabic) {
    final parts = label.split(RegExp(r'\s*/\s*'));
    if (parts.length >= 2) {
      final first = parts.first.trim();
      final last = parts.last.trim();
      if (preferFrench) return _normalizeText(last);
      if (preferArabic) return _normalizeText(first);
      return _normalizeText(first);
    }
    return _normalizeText(label);
  }

  static String _sanitizeExcelSheetName(
    String rawName, {
    required List<String> existing,
  }) {
    var name = rawName.trim();
    if (name.isEmpty) name = 'Sheet';
    // Excel forbidden chars: : \ / ? * [ ]
    name = name.replaceAll(RegExp(r'[:\\\\/?*\\[\\]]'), '_');
    if (name.length > 31) name = name.substring(0, 31);

    var candidate = name;
    var counter = 1;
    while (existing.contains(candidate)) {
      final suffix = '_$counter';
      candidate = name.length + suffix.length > 31 ? name.substring(0, (31 - suffix.length)) + suffix : name + suffix;
      counter++;
    }
    return candidate;
  }

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
    // Revoke after a moment to avoid memory leaks.
    Future.delayed(const Duration(seconds: 1), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}

