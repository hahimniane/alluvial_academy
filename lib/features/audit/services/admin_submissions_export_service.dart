import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

import 'package:alluwalacademyadmin/features/forms/screens/admin_submissions_review_screen.dart'
    show kAdminSubmissionsExportNoFormIdBucket;
import 'package:alluwalacademyadmin/features/forms/services/form_labels_cache_service.dart';
import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';
import '../../../core/utils/save_export_file.dart';

import 'dart:html'
    if (dart.library.io) 'package:alluwalacademyadmin/core/utils/html_stub.dart'
    as html;

enum AdminSubmissionsExportStatus {
  loadingFieldLabels,
  loadingDocumentFonts,
  buildingFile,
  startingDownload,
}

/// Export service for Admin → All submissions (review mode).
/// Export loads form/template definitions once per sheet so column headers match
/// the legacy Responses UI (human-readable labels).
class AdminSubmissionsExportService {
  AdminSubmissionsExportService._();

  /// Prevents duplicate downloads if export is triggered twice in quick succession.
  static bool _exportInProgress = false;

  static String _pdfTeacherAnchor(int teacherIndex) =>
      'form_section_$teacherIndex';

  /// [submissionsByForm] maps formId → selected submission docs for that form.
  static Future<void> exportSelectedSubmissions({
    required Map<String, List<QueryDocumentSnapshot>> submissionsByForm,
    required Map<String, String> teacherNames,
    required Map<String, String> formTitles,
    required Map<String, TeachingShift> shiftMap,
    required String format, // 'pdf' | 'excel'
    required String locale,
    required void Function(String formId, int index, int total) onFormProgress,
    void Function(AdminSubmissionsExportStatus status)? onStatus,
  }) async {
    if (submissionsByForm.isEmpty) return;
    if (_exportInProgress) return;
    _exportInProgress = true;

    final formIds = submissionsByForm.keys.toList()
      ..sort((a, b) {
        final ta = (formTitles[a] ?? a).toLowerCase();
        final tb = (formTitles[b] ?? b).toLowerCase();
        return ta.compareTo(tb);
      });

    final exportBaseName =
        'admin_submissions_export_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}';

    onStatus?.call(AdminSubmissionsExportStatus.loadingFieldLabels);
    await Future<void>.delayed(Duration.zero);
    final fieldLabelsByFormId =
        await _resolveFieldLabelsByFormId(submissionsByForm);

    try {
      if (format == 'pdf') {
        await _exportToPdf(
          submissionsByForm: submissionsByForm,
          formIds: formIds,
          teacherNames: teacherNames,
          formTitles: formTitles,
          shiftMap: shiftMap,
          locale: locale,
          exportBaseName: exportBaseName,
          fieldLabelsByFormId: fieldLabelsByFormId,
          onFormProgress: onFormProgress,
          onStatus: onStatus,
        );
      } else {
        await _exportToExcel(
          submissionsByForm: submissionsByForm,
          formIds: formIds,
          teacherNames: teacherNames,
          formTitles: formTitles,
          shiftMap: shiftMap,
          exportBaseName: exportBaseName,
          fieldLabelsByFormId: fieldLabelsByFormId,
          onFormProgress: onFormProgress,
          onStatus: onStatus,
        );
      }
    } finally {
      _exportInProgress = false;
    }
  }

  static Future<void> _exportToExcel({
    required Map<String, List<QueryDocumentSnapshot>> submissionsByForm,
    required List<String> formIds,
    required Map<String, String> teacherNames,
    required Map<String, String> formTitles,
    required Map<String, TeachingShift> shiftMap,
    required String exportBaseName,
    required Map<String, Map<String, String>> fieldLabelsByFormId,
    required void Function(String formId, int index, int total) onFormProgress,
    void Function(AdminSubmissionsExportStatus status)? onStatus,
  }) async {
    final excel = xl.Excel.createExcel();
    final existingSheetNames = <String>{};

    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.blueGrey50,
      horizontalAlign: xl.HorizontalAlign.Left,
      verticalAlign: xl.VerticalAlign.Center,
      textWrapping: xl.TextWrapping.WrapText,
    );
    final dataCellStyle = xl.CellStyle(
      textWrapping: xl.TextWrapping.WrapText,
      verticalAlign: xl.VerticalAlign.Top,
      horizontalAlign: xl.HorizontalAlign.Left,
    );

    var isFirstSheet = true;
    var wroteAnySheet = false;

    for (var i = 0; i < formIds.length; i++) {
      final formId = formIds[i];
      final docs = submissionsByForm[formId] ?? const [];
      if (docs.isEmpty) continue;

      wroteAnySheet = true;
      onFormProgress(formId, i, formIds.length);
      await Future<void>.delayed(Duration.zero);
      final formTitle = formTitles[formId] ?? formId;
      final sheetName = _sanitizeExcelSheetName(
        formTitle,
        existing: existingSheetNames.toList(),
      );
      existingSheetNames.add(sheetName);
      final sheet = excel[sheetName];

      if (isFirstSheet) {
        isFirstSheet = false;
        if (excel.tables.containsKey('Sheet1') && excel.tables.length > 1) {
          excel.delete('Sheet1');
        }
      }

      final allFieldKeys = <String>{};
      for (final doc in docs) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final responses = Map<String, dynamic>.from(
            data['responses'] ?? data['answers'] ?? {});

        for (final key in responses.keys) {
          if (!key.toString().startsWith('_')) {
            allFieldKeys.add(key.toString());
          }
        }
      }

      final sortedFieldKeys = allFieldKeys.toList()..sort();

      final labels = fieldLabelsByFormId[formId] ?? const {};

      final headers = <String>[
        'Teacher Name',
        'Email',
        'Submitted At',
        'Shift',
        ...sortedFieldKeys.map((k) => _excelSafeCellText(labels[k] ?? k)),
        'Status',
        'Admin Notes',
        '#',
        'Document ID',
      ];

      for (var col = 0; col < headers.length; col++) {
        final cell = sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.value = xl.TextCellValue(_excelSafeCellText(headers[col]));
        cell.cellStyle = headerStyle;
        if (col == 0) {
          sheet.setColumnWidth(col, 22);
        } else if (col == 1) {
          sheet.setColumnWidth(col, 30);
        } else if (col == 2) {
          sheet.setColumnWidth(col, 18);
        } else if (col == 3) {
          sheet.setColumnWidth(col, 32);
        } else if (col < headers.length - 4) {
          sheet.setColumnWidth(col, 28);
        } else if (col == headers.length - 4) {
          sheet.setColumnWidth(col, 14);
        } else if (col == headers.length - 3) {
          sheet.setColumnWidth(col, 36);
        } else if (col == headers.length - 2) {
          sheet.setColumnWidth(col, 10);
        } else {
          sheet.setColumnWidth(col, 28);
        }
      }

      // 3. Write Data Rows
      var dataRow = 1;
      for (var docIndex = 0; docIndex < docs.length; docIndex++) {
        final doc = docs[docIndex];
        final data = (doc.data() as Map<String, dynamic>?) ?? {};

        final teacherId = (data['userId'] ?? '').toString();
        final teacherName = teacherNames[teacherId] ?? teacherId;
        final teacherEmail = (data['userEmail'] ?? '').toString();
        final submittedAt = _resolveSubmittedAt(data);
        final shiftText = _shiftDisplayText(data, shiftMap);
        final status =
            (data['reviewStatus'] ?? data['status'] ?? 'seen').toString();
        final adminNote = (data['adminNote'] ?? '').toString();

        final responses = Map<String, dynamic>.from(
            data['responses'] ?? data['answers'] ?? {});

        final rowData = <String>[
          _excelSafeCellText(teacherName),
          _excelSafeCellText(teacherEmail),
          _excelSafeCellText(submittedAt),
          _excelSafeCellText(shiftText.isEmpty ? '-' : shiftText),
          ...sortedFieldKeys.map((key) {
            if (!responses.containsKey(key)) return _excelSafeCellText('-');
            return _excelSafeCellText(_formatValue(responses[key]));
          }),
          _excelSafeCellText(status.toUpperCase()),
          _excelSafeCellText(adminNote),
          _excelSafeCellText('${docIndex + 1}'),
          _excelSafeCellText(doc.id),
        ];

        for (var col = 0; col < rowData.length; col++) {
          final cell = sheet.cell(xl.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: dataRow));
          cell.value = xl.TextCellValue(rowData[col]);
          cell.cellStyle = dataCellStyle;
        }

        dataRow++;
      }
    }

    if (!wroteAnySheet) return;

    // Use encode(), not save(): on web, save() also triggers a browser download
    // as "FlutterExcel.xlsx" via the package helper — we name the file ourselves below.
    onStatus?.call(AdminSubmissionsExportStatus.buildingFile);
    await Future<void>.delayed(Duration.zero);
    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) return;

    onStatus?.call(AdminSubmissionsExportStatus.startingDownload);
    await Future<void>.delayed(Duration.zero);
    if (kIsWeb) {
      _downloadWebBytes(bytes, '$exportBaseName.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } else {
      await saveExportBytes(bytes, '$exportBaseName.xlsx');
    }
  }

  static Future<Map<String, Map<String, String>>> _resolveFieldLabelsByFormId(
    Map<String, List<QueryDocumentSnapshot>> submissionsByForm,
  ) async {
    final svc = FormLabelsCacheService();
    final entries = submissionsByForm.entries
        .where((e) =>
            e.key.isNotEmpty && e.key != kAdminSubmissionsExportNoFormIdBucket)
        .toList();

    Future<MapEntry<String, Map<String, String>>?> resolveOne(
      String formKey,
      List<QueryDocumentSnapshot> docs,
    ) async {
      final templateIds = <String>{};
      for (final doc in docs) {
        final d = doc.data() as Map<String, dynamic>?;
        final tid = d?['templateId']?.toString().trim();
        if (tid != null && tid.isNotEmpty) templateIds.add(tid);
      }
      var merged = <String, String>{};
      final templateMaps = await Future.wait(
        templateIds.map((tid) => svc.getLabelsForTemplate(tid)),
      );
      for (final m in templateMaps) {
        if (m.isNotEmpty) merged = {...merged, ...m};
      }
      final tMain = await svc.getLabelsForTemplate(formKey);
      final fMain = await svc.getLabelsForForm(formKey);
      merged = {...merged, ...tMain, ...fMain};
      if (merged.isEmpty) return null;
      return MapEntry(formKey, merged);
    }

    final pairs = await Future.wait(
      entries.map((e) => resolveOne(e.key, e.value)),
    );
    final out = <String, Map<String, String>>{};
    for (final p in pairs) {
      if (p != null) out[p.key] = p.value;
    }
    return out;
  }

  static String _shiftDisplayText(
    Map<String, dynamic> data,
    Map<String, TeachingShift> shiftMap,
  ) {
    final shiftId = _resolveShiftIdForExport(data);
    if (shiftId.isEmpty) return '';
    final shiftSummary = shiftMap[shiftId];
    if (shiftSummary == null) return shiftId;
    return _normalizeText(_formatShiftSummary(shiftSummary));
  }

  /// Same shift-key resolution as [AdminSubmissionsReviewScreen._resolveShiftId].
  static String _resolveShiftIdForExport(Map<String, dynamic> data) {
    final raw = data['shiftId'] ??
        data['shift_id'] ??
        data['linkedShiftId'] ??
        data['linked_shift_id'];
    final sid = raw?.toString().trim() ?? '';
    if (sid.isEmpty) return '';
    if (sid.toLowerCase() == 'n/a') return '';
    if (sid == 'N/A') return '';
    return sid;
  }

  static Future<void> _exportToPdf({
    required Map<String, List<QueryDocumentSnapshot>> submissionsByForm,
    required List<String> formIds,
    required Map<String, String> teacherNames,
    required Map<String, String> formTitles,
    required Map<String, TeachingShift> shiftMap,
    required String locale,
    required String exportBaseName,
    required Map<String, Map<String, String>> fieldLabelsByFormId,
    required void Function(String formId, int index, int total) onFormProgress,
    void Function(AdminSubmissionsExportStatus status)? onStatus,
  }) async {
    final pdf = pw.Document();
    final lcPdf = locale.toLowerCase();
    final isFr = lcPdf.startsWith('fr');
    final isAr = lcPdf.startsWith('ar');
    onStatus?.call(AdminSubmissionsExportStatus.loadingDocumentFonts);
    await Future<void>.delayed(Duration.zero);
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
    final questionLabel = isFr ? 'Question' : 'Question';
    final answerLabel = isFr ? 'Reponse' : 'Answer';
    final formMetaLabel = isFr
        ? 'Formulaire'
        : isAr
            ? 'النموذج'
            : 'Form';

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
          ...formIds.asMap().entries.map((entry) {
            final index = entry.key;
            final idx = index + 1;
            final formId = entry.value;
            final title = _normalizeText(formTitles[formId] ?? formId);
            final count = submissionsByForm[formId]?.length ?? 0;
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
                        '$title — $count $submissionsLabel',
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

    for (var i = 0; i < formIds.length; i++) {
      final formId = formIds[i];
      final formTitle = _normalizeText(formTitles[formId] ?? formId);
      final docs = submissionsByForm[formId] ?? const [];
      if (docs.isEmpty) continue;

      onFormProgress(formId, i, formIds.length);
      await Future<void>.delayed(Duration.zero);

      final labels = fieldLabelsByFormId[formId] ?? const {};

      final formPosition = '${i + 1}/${formIds.length}';
      final widgets = <pw.Widget>[
        pw.Outline(
          name: _pdfTeacherAnchor(i),
          title: formTitle,
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
                    '$formMetaLabel: $formTitle',
                    style: pw.TextStyle(
                        fontSize: 15, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Text(formPosition, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 12),
      ];

      for (final doc in docs) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final teacherId = (data['userId'] ?? '').toString();
        final teacherName =
            _normalizeText(teacherNames[teacherId] ?? teacherId);
        final submittedAt = _resolveSubmittedAt(data);
        final shiftId = _resolveShiftIdForExport(data);
        final shiftSummary = shiftMap[shiftId];
        final shiftText = shiftSummary == null
            ? shiftId
            : _normalizeText(_formatShiftSummary(shiftSummary));

        final responses = Map<String, dynamic>.from(
            data['responses'] ?? data['answers'] ?? {});

        final qaRows = <pw.Widget>[];
        responses.forEach((fieldId, value) {
          if (fieldId.toString().startsWith('_')) return;
          final humanLabel = _normalizeText(
            labels[fieldId.toString()] ?? fieldId.toString(),
          );
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
                    '$questionLabel: $humanLabel',
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
              border:
                  pw.Border.all(color: PdfColor.fromHex('#D1D5DB'), width: 0.8),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  teacherName,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold),
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
              '$formTitle - ${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (context) => widgets,
        ),
      );
    }

    onStatus?.call(AdminSubmissionsExportStatus.buildingFile);
    await Future<void>.delayed(Duration.zero);
    final bytes = await pdf.save();
    if (bytes.isEmpty) return;

    onStatus?.call(AdminSubmissionsExportStatus.startingDownload);
    await Future<void>.delayed(Duration.zero);
    if (kIsWeb) {
      _downloadWebBytes(bytes, '$exportBaseName.pdf', 'application/pdf');
    } else {
      await saveExportBytes(bytes, '$exportBaseName.pdf');
    }
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
    if (value is Timestamp)
      return DateFormat('yyyy-MM-dd').format(value.toDate());
    if (value is DateTime) return DateFormat('yyyy-MM-dd').format(value);
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is Map) {
      final parts = <String>[];
      for (final e in value.entries) {
        parts.add('${e.key}: ${_formatValue(e.value)}');
      }
      return parts.join(' | ');
    }
    if (value is List) return value.map(_formatValue).join(', ');
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

  /// Strips characters that break OOXML / Excel's XML parser so the file opens without repair.
  static String _excelSafeCellText(String raw) {
    final base = _normalizeText(raw);
    if (base.isEmpty) return '';
    final buf = StringBuffer();
    for (final r in base.runes) {
      if (r == 0x9 || r == 0xA || r == 0xD) {
        buf.writeCharCode(r);
      } else if (r >= 0x20 && r <= 0xD7FF) {
        buf.writeCharCode(r);
      } else if (r >= 0xE000 && r <= 0xFFFD) {
        buf.writeCharCode(r);
      } else if (r >= 0x10000 && r <= 0x10FFFF) {
        buf.write(String.fromCharCode(r));
      } else {
        buf.write(' ');
      }
    }
    var out = buf.toString();
    const maxLen = 32000;
    if (out.length > maxLen) {
      out = '${out.substring(0, maxLen)}…';
    }
    return out;
  }

  static String _sanitizeExcelSheetName(
    String rawName, {
    required List<String> existing,
  }) {
    var name = rawName.trim();
    if (name.isEmpty) name = 'Sheet';
    // Excel forbidden chars: : \ / ? * [ ]
    name = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), '_');
    if (name.length > 31) name = name.substring(0, 31);

    final existingLower = existing.map((e) => e.toLowerCase()).toSet();
    var candidate = name;
    var counter = 1;
    while (existingLower.contains(candidate.toLowerCase())) {
      final suffix = '_$counter';
      candidate = name.length + suffix.length > 31
          ? name.substring(0, (31 - suffix.length).clamp(0, 31)) + suffix
          : name + suffix;
      counter++;
    }
    return candidate;
  }

  static void _downloadWebBytes(
      List<int> bytes, String fileName, String mimeType) {
    final typed = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final b = html.Blob([typed], mimeType);
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

  @visibleForTesting
  static String debugSanitizeExcelSheetName(
          String rawName, List<String> existing) =>
      _sanitizeExcelSheetName(rawName, existing: existing);

  @visibleForTesting
  static String debugFormatSubmissionValue(dynamic value) =>
      _formatValue(value);

  @visibleForTesting
  static String debugResolveShiftIdForExport(Map<String, dynamic> data) =>
      _resolveShiftIdForExport(data);
}
