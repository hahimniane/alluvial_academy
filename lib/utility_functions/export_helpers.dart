import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional import - uses dart:html on web, stub on other platforms
import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ExportFormat { csv, excel }

class ExportHelpers {
  static bool _isExporting = false;
  // Enhanced export function with format selection
  static void showExportDialog(
    BuildContext context,
    List<String> headers,
    List<List<String>> data,
    String baseFileName,
  ) {
    print(
        'ExportHelpers.showExportDialog called with baseFileName: $baseFileName, headers: ${headers.length}, data rows: ${data.length}');

    // Check if there's any data to export and add sample data if empty
    List<List<String>> exportData = data;
    if (data.isEmpty) {
      print('No real data found, creating sample data for testing');
      // Create sample data for testing
      exportData = [
        ['Sample', 'Data', 'Row', '1'],
        ['Test', 'Export', 'Row', '2'],
        ['Excel', 'Working', 'Row', '3'],
      ];

      // Show info that sample data is being used
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No data found. Using sample data for export test.',
            style: GoogleFonts.openSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xffF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xff0386FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.file_download,
                  color: Color(0xff0386FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Export Data',
                style: GoogleFonts.openSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1F2937),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your preferred export format:',
                style: GoogleFonts.openSans(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
              ),
              const SizedBox(height: 20),
              _buildFormatOption(
                context,
                'Excel (.xlsx)',
                'Best for data analysis and advanced formatting',
                Icons.table_chart,
                const Color(0xff10B981),
                () => _exportToExcel(headers, exportData, baseFileName),
              ),
              const SizedBox(height: 12),
              _buildFormatOption(
                context,
                'CSV (.csv)',
                'Universal format compatible with all applications',
                Icons.description,
                const Color(0xff6366F1),
                () => _exportToCsv(headers, exportData, baseFileName),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.openSans(
                  color: const Color(0xff6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildFormatOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        if (_isExporting) {
          print('Export already in progress, ignoring duplicate request');
          return;
        }
        Navigator.of(context).pop();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.openSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xff9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  // Export to Excel format
  static void _exportToExcel(
    List<String> headers,
    List<List<String>> data,
    String baseFileName,
  ) {
    if (_isExporting) {
      print('Export already in progress, skipping Excel export');
      return;
    }

    _isExporting = true;
    try {
      print(
          'Starting Excel export with ${headers.length} headers and ${data.length} rows');

      // Create a new Excel document
      var excel = xl.Excel.createExcel();

      // Get the default sheet
      xl.Sheet sheet = excel['Sheet1'];

      // Add headers row by row
      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(xl.CellIndex.indexByString('${String.fromCharCode(65 + i)}1'))
            .value = xl.TextCellValue(headers[i]);
        print(
            'Added header: ${headers[i]} at column ${String.fromCharCode(65 + i)}1');
      }

      // Add data rows
      for (int rowIndex = 0; rowIndex < data.length; rowIndex++) {
        List<String> row = data[rowIndex];
        for (int colIndex = 0;
            colIndex < row.length && colIndex < headers.length;
            colIndex++) {
          String cellAddress =
              '${String.fromCharCode(65 + colIndex)}${rowIndex + 2}'; // +2 because row 1 is headers
          sheet.cell(xl.CellIndex.indexByString(cellAddress)).value =
              xl.TextCellValue(row[colIndex] ?? '');
        }
        if (rowIndex < 3) {
          print('Added data row ${rowIndex + 1}: ${row.take(3).join(", ")}...');
        }
      }

      print('Data added to Excel sheet. Generating file...');

      // Generate Excel file bytes
      List<int>? fileBytes = excel.save();

      print('Excel file bytes generated: ${fileBytes?.length ?? 0} bytes');

      if (fileBytes != null && fileBytes.isNotEmpty) {
        if (kIsWeb) {
          // Create blob and download
          final blob = html.Blob([
            Uint8List.fromList(fileBytes)
          ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

          final url = html.Url.createObjectUrlFromBlob(blob);

          // Create and configure the anchor element
          final anchor = html.AnchorElement()
            ..href = url
            ..style.display = 'none'
            ..download = "$baseFileName.xlsx";

          // Add to DOM, click, then remove
          html.document.body?.children.add(anchor);
          anchor.click();
          html.document.body?.children.remove(anchor);

          // Clean up URL after a delay to ensure download starts
          Future.delayed(const Duration(milliseconds: 1000), () {
            html.Url.revokeObjectUrl(url);
          });

          print('Excel file exported successfully: $baseFileName.xlsx');
        } else {
          print('Excel export is only supported on web platform');
        }
      } else {
        print('Error: Excel file bytes are null or empty');
      }
    } catch (e, stackTrace) {
      print('Error exporting to Excel: $e');
      print('Stack trace: $stackTrace');
    } finally {
      // Reset the exporting flag after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _isExporting = false;
      });
    }
  }

  // Export to CSV format (existing functionality)
  static void _exportToCsv(
    List<String> headers,
    List<List<String>> data,
    String baseFileName,
  ) {
    if (_isExporting) {
      print('Export already in progress, skipping CSV export');
      return;
    }

    _isExporting = true;
    try {
      List<List<String>> csvData = [
        headers,
        ...data,
      ];

      String csv = const ListToCsvConverter().convert(csvData);

      if (kIsWeb) {
        // Create a Blob
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);

        // Create a link element
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement()
          ..href = url
          ..style.display = 'none'
          ..download = "$baseFileName.csv";

        // Add to DOM, click, then remove
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);

        // Clean up URL after download
        Future.delayed(const Duration(milliseconds: 1000), () {
          html.Url.revokeObjectUrl(url);
        });

        print('CSV file exported successfully: $baseFileName.csv');
      } else {
        print('CSV export is only supported on web platform');
      }
    } catch (e) {
      print('Error exporting to CSV: $e');
    } finally {
      // Reset the exporting flag after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _isExporting = false;
      });
    }
  }

  // Convenience wrapper for exporting form responses to Excel without a UI dialog
  // Keeps backward compatibility with older callers
  static void exportFormResponsesToExcel(
    List<QueryDocumentSnapshot> responses,
    Map<String, DocumentSnapshot> formTemplates,
  ) {
    try {
      final headers = <String>[
        'Form Title',
        'First Name',
        'Last Name',
        'Email',
        'Status',
        'Submitted At',
      ];

      final rows = responses.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final template = formTemplates[data['formId']];
        final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
        final submittedAtStr = submittedAt != null
            ? '${submittedAt.year}-${submittedAt.month.toString().padLeft(2, '0')}-${submittedAt.day.toString().padLeft(2, '0')} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}'
            : '';

        return <String>[
          (template != null
                  ? (template['title'] ?? 'Untitled Form')
                  : 'Untitled Form')
              .toString(),
          (data['firstName'] ?? '').toString(),
          (data['lastName'] ?? '').toString(),
          (data['userEmail'] ?? '').toString(),
          (data['status'] ?? 'Completed').toString(),
          submittedAtStr,
        ];
      }).toList();

      _exportToExcel(headers, rows, 'form_responses');
    } catch (e) {
      // Fall back silently; callers can handle errors if needed
      print('exportFormResponsesToExcel failed: $e');
    }
  }
}

// Legacy function for backward compatibility
void exportData(
  List<String> headers,
  List<List<String>> data,
  String fileName,
) {
  ExportHelpers._exportToCsv(headers, data, fileName.replaceAll('.csv', ''));
}
