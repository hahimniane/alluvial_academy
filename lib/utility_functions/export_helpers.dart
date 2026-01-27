import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional import - uses dart:html on web, stub on other platforms
import 'dart:html' if (dart.library.io) 'html_stub.dart' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ExportHelpers {
  static bool _isExporting = false;
  // Enhanced export function with format selection
  // Enhanced export function with format selection
  static void showExportDialog(
    BuildContext context,
    dynamic headersOrSheets, // List<String> or Map<String, List<String>>
    dynamic
        dataOrSheets, // List<List<dynamic>> or Map<String, List<List<dynamic>>>
    String baseFileName,
  ) {
    AppLogger.debug(
        'ExportHelpers.showExportDialog called with baseFileName: $baseFileName');

    // Check if there's any data to export (basic check)
    bool hasData = false;
    if (dataOrSheets is List) {
      hasData = dataOrSheets.isNotEmpty;
    } else if (dataOrSheets is Map) {
      hasData = dataOrSheets.isNotEmpty;
    }

    if (!hasData) {
      AppLogger.debug('No data found');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.noDataFoundToExport,
            style: GoogleFonts.openSans(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
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
                AppLocalizations.of(context)!.exportData,
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
                AppLocalizations.of(context)!.chooseYourPreferredExportFormat,
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
                () =>
                    _exportToExcel(headersOrSheets, dataOrSheets, baseFileName),
              ),
              // CSV option disabled for multi-sheet exports as CSV doesn't support it
              if (dataOrSheets is List) ...[
                const SizedBox(height: 12),
                _buildFormatOption(
                  context,
                  'CSV (.csv)',
                  'Universal format compatible with all applications',
                  Icons.description,
                  const Color(0xff6366F1),
                  () => _exportToCsv(headersOrSheets as List<String>,
                      dataOrSheets as List<List<String>>, baseFileName),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context)!.commonCancel,
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
          AppLogger.debug(
              'Export already in progress, ignoring duplicate request');
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

  // Export to Excel format (Multi-Sheet Support)
  static void _exportToExcel(
    dynamic
        headersOrSheets, // Can be List<String> (single) or Map<String, List<String>> (multi-headers)
    dynamic
        dataOrSheets, // Can be List<List<dynamic>> (single) or Map<String, List<List<dynamic>>> (multi-data)
    String baseFileName,
  ) {
    AppLogger.debug('═══════════════════════════════════════');
    AppLogger.debug('_exportToExcel called');
    AppLogger.debug('Base filename: $baseFileName');

    if (_isExporting) {
      AppLogger.debug('⚠️ Export already in progress, skipping Excel export');
      return;
    }

    _isExporting = true;
    try {
      // Create a new Excel document
      var excel = xl.Excel.createExcel();

      // Check if it's a multi-sheet export
      if (dataOrSheets is Map<String, List<List<dynamic>>>) {
        final sheetsData = dataOrSheets;
        final sheetsHeaders = headersOrSheets as Map<String, List<String>>;

        for (var sheetName in sheetsData.keys) {
          AppLogger.debug('Processing sheet: $sheetName');
          final headers = sheetsHeaders[sheetName] ?? [];
          final rows = sheetsData[sheetName] ?? [];

          _populateSheet(excel, sheetName, headers, rows);
        }

        // Remove default sheet after adding our own
        if (sheetsData.keys.isNotEmpty) {
          excel.delete('Sheet1');
        }
      } else {
        // Single sheet mode (backward compatibility)
        final headers = headersOrSheets as List<String>;
        final rows = dataOrSheets as List<List<dynamic>>;
        _populateSheet(excel, 'Sheet1', headers, rows);
      }

      AppLogger.debug('Data added to Excel sheets. Generating file...');

      // Generate Excel file bytes
      List<int>? fileBytes = excel.save();

      AppLogger.debug(
          'Excel file bytes generated: ${fileBytes?.length ?? 0} bytes');

      if (fileBytes != null && fileBytes.isNotEmpty) {
        if (kIsWeb) {
          _downloadWebFile(fileBytes, baseFileName, 'xlsx',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        } else {
          AppLogger.error('❌ Excel export is only supported on web platform');
        }
      } else {
        AppLogger.error('❌ Error: Excel file bytes are null or empty');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error exporting to Excel: $e');
      AppLogger.error('Stack trace: $stackTrace');
    } finally {
      // Reset the exporting flag after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _isExporting = false;
      });
    }
  }

  static void _populateSheet(
    xl.Excel excel,
    String sheetName,
    List<String> headers,
    List<List<dynamic>> rows,
  ) {
    xl.Sheet sheet = excel[sheetName];

    // Add headers
    for (int i = 0; i < headers.length; i++) {
      final colRef = _columnIndexToExcelRef(i);
      var cell = sheet.cell(xl.CellIndex.indexByString('${colRef}1'));
      cell.value = xl.TextCellValue(headers[i]);
      cell.cellStyle = xl.CellStyle(
        bold: true,
        horizontalAlign: xl.HorizontalAlign.Center,
      );
    }

    // Add data rows
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      List<dynamic> row = rows[rowIndex];
      for (int colIndex = 0;
          colIndex < row.length && colIndex < headers.length;
          colIndex++) {
        final colRef = _columnIndexToExcelRef(colIndex);
        String cellAddress = '$colRef${rowIndex + 2}';
        var cell = sheet.cell(xl.CellIndex.indexByString(cellAddress));
        var value = row[colIndex];

        if (value is double) {
          cell.value = xl.DoubleCellValue(value);
          // Basic number format, currency formatting depends on library version capabilities
          // For now, we ensure it's treated as a number
        } else if (value is int) {
          cell.value = xl.IntCellValue(value);
        } else if (value is DateTime) {
          // Using ISO string as fallback if DateCellValue constructor is problematic
          // or try to use the library's way to handle DateTime
          try {
            cell.value = xl.DateCellValue(
                year: value.year, month: value.month, day: value.day);
            cell.cellStyle =
                xl.CellStyle(numberFormat: xl.NumFormat.standard_14);
          } catch (e) {
            cell.value = xl.TextCellValue(value.toIso8601String());
          }
        } else {
          cell.value = xl.TextCellValue(value.toString());
        }
      }
    }

    // Auto-size columns based on content
    _autoSizeColumns(sheet, headers.length);
  }

  /// Convert column index (0-based) to Excel column reference (A, B, ..., Z, AA, AB, ...)
  static String _columnIndexToExcelRef(int colIndex) {
    String result = '';
    int index = colIndex;
    while (index >= 0) {
      result = String.fromCharCode(65 + (index % 26)) + result;
      index = (index ~/ 26) - 1;
    }
    return result;
  }

  /// Auto-size columns based on header and content width
  static void _autoSizeColumns(xl.Sheet sheet, int columnCount) {
    // Define optimal column widths based on common column patterns
    final Map<int, double> optimalWidths = {};
    
    // Predefined widths for common column types (in Excel units, where 1 unit ≈ 7 pixels)
    final Map<String, double> columnTypeWidths = {
      'First name': 15.0,
      'Last name': 15.0,
      'Scheduled shift title': 25.0,
      'Type': 12.0,
      'Sub-job': 20.0,
      'Start Date': 18.0,
      'In': 12.0,
      'Start - device': 15.0,
      'End Date': 18.0,
      'Out': 12.0,
      'End - device': 15.0,
      'Employee notes': 30.0,
      'Manager notes': 30.0,
      'Shift hours': 12.0,
      'Daily totals': 15.0,
      'Weekly totals': 15.0,
    };
    
    // Calculate max width for each column
    for (int colIndex = 0; colIndex < columnCount; colIndex++) {
      double maxWidth = 12.0; // Default minimum width
      
      // Check header width and use predefined width if available
      try {
        final colRef = _columnIndexToExcelRef(colIndex);
        final headerCell = sheet.cell(xl.CellIndex.indexByString('${colRef}1'));
        if (headerCell.value != null) {
          final headerText = headerCell.value.toString().trim();
          
          // Check if we have a predefined width for this column
          if (columnTypeWidths.containsKey(headerText)) {
            maxWidth = columnTypeWidths[headerText]!;
          } else {
            // Calculate based on header length
            maxWidth = (headerText.length * 1.3).clamp(12.0, 40.0);
          }
        }
      } catch (e) {
        // If header check fails, use default
      }
      
      // Check data width (sample first 30 rows for performance)
      final rowsToCheck = sheet.maxRows > 30 ? 30 : sheet.maxRows;
      for (int rowIndex = 2; rowIndex <= rowsToCheck + 1 && rowIndex <= sheet.maxRows; rowIndex++) {
        try {
          final colRef = _columnIndexToExcelRef(colIndex);
          final cell = sheet.cell(xl.CellIndex.indexByString('$colRef$rowIndex'));
          if (cell.value != null) {
            final cellText = cell.value.toString();
            // For dates (DateTime objects), use fixed width
            if (cellText.contains('T') && cellText.contains('-') && cellText.length > 10) {
              maxWidth = 18.0; // Date columns
            } else if (cellText.length > maxWidth * 0.7) {
              // Adjust width based on content, but be reasonable
              final textWidth = (cellText.length * 1.2).clamp(12.0, 50.0);
              if (textWidth > maxWidth) {
                maxWidth = textWidth;
              }
            }
          }
        } catch (e) {
          // Skip invalid cells
        }
      }
      
      // Set reasonable min/max bounds
      maxWidth = maxWidth.clamp(12.0, 50.0);
      optimalWidths[colIndex] = maxWidth;
    }
    
    // Apply column widths using reflection/dynamic calls since API might vary
    for (int colIndex = 0; colIndex < columnCount; colIndex++) {
      try {
        final width = optimalWidths[colIndex] ?? 15.0;
        
        // Try to set column width - the Excel package API may vary
        // We'll use dynamic invocation to handle different API versions
        try {
          // Attempt to call setColumnWidth if it exists
          final sheetDynamic = sheet as dynamic;
          if (sheetDynamic.setColumnWidth != null) {
            sheetDynamic.setColumnWidth(colIndex, width);
          }
        } catch (e) {
          // If dynamic call fails, try accessing columns directly
          try {
            final sheetDynamic = sheet as dynamic;
            if (sheetDynamic.columns != null) {
              final columns = sheetDynamic.columns as List;
              if (columns.length > colIndex && columns[colIndex] != null) {
                final column = columns[colIndex] as dynamic;
                if (column.width != null) {
                  column.width = width;
                }
              }
            }
          } catch (e2) {
            // If all methods fail, that's okay - Excel will use default widths
            AppLogger.debug('Column width auto-sizing not available for column $colIndex');
          }
        }
      } catch (e) {
        // Silently continue - column widths are a nice-to-have feature
      }
    }
  }

  static void _downloadWebFile(
      List<int> bytes, String fileName, String extension, String mimeType) {
    AppLogger.debug('Creating blob for web download...');
    final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..style.display = 'none'
      ..download = "$fileName.$extension";

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);

    Future.delayed(const Duration(milliseconds: 1000), () {
      html.Url.revokeObjectUrl(url);
    });

    AppLogger.info('✓ File exported successfully: $fileName.$extension');
  }

  // Export to CSV format (existing functionality)
  static void _exportToCsv(
    List<String> headers,
    List<List<String>> data,
    String baseFileName,
  ) {
    if (_isExporting) {
      AppLogger.debug('Export already in progress, skipping CSV export');
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

        AppLogger.error('CSV file exported successfully: $baseFileName.csv');
      } else {
        AppLogger.error('CSV export is only supported on web platform');
      }
    } catch (e) {
      AppLogger.error('Error exporting to CSV: $e');
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
      AppLogger.error('exportFormResponsesToExcel failed: $e');
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
