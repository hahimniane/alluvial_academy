import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../models/invoice.dart';
import 'invoice_data_service.dart';
import 'mock_company_service.dart' show CompanyInfo, AdminInfo;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Service for generating PDF invoices
class InvoicePdfService {
  /// Generate PDF bytes for an invoice
  static Future<Uint8List> generateInvoicePDF(
    Invoice invoice, {
    String? parentName,
    String? studentName,
    String? adminName,
  }) async {
    // Fetch names if not provided
    final resolvedParentName = parentName ?? await InvoiceDataService.getParentName(invoice.parentId);
    final resolvedStudentName = studentName ?? await InvoiceDataService.getStudentName(invoice.studentId);
    final companyInfo = InvoiceDataService.getCompanyInfo();
    final adminInfo = adminName != null 
        ? AdminInfo(name: adminName, signature: '') 
        : InvoiceDataService.getAdminInfo();

    final money = NumberFormat.simpleCurrency(name: invoice.currency);
    final dateFormat = DateFormat.yMMMMd();
    final monthFormat = DateFormat.yMMMM();

    // Create PDF document
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildHeader(companyInfo),
              pw.SizedBox(height: 32),

              // Invoice Title
              _buildInvoiceTitle(),
              pw.SizedBox(height: 24),

              // Invoice Info
              _buildInvoiceInfo(invoice, dateFormat),
              pw.SizedBox(height: 24),

              // Payer/Student Section
              if (resolvedParentName != null || resolvedStudentName != null)
                _buildPayerStudentSection(
                  resolvedParentName ?? 'Parent',
                  resolvedStudentName ?? invoice.studentId,
                  monthFormat.format(invoice.issuedDate),
                ),
              if (resolvedParentName != null || resolvedStudentName != null) pw.SizedBox(height: 24),

              // Items Table
              _buildItemsTable(invoice, money),
              pw.SizedBox(height: 24),

              // Summary Section
              _buildSummarySection(invoice, money),
              pw.SizedBox(height: 32),

              // Footer
              _buildFooter(adminInfo),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(CompanyInfo companyInfo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Logo placeholder (can be replaced with actual image later)
        pw.Container(
          width: 64,
          height: 64,
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue500, width: 2),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Center(
            child: pw.Text(
              AppLocalizations.of(context)!.aeh,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700,
              ),
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                companyInfo.name,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                companyInfo.fullAddress,
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Contact: ${companyInfo.phone}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Email: ${companyInfo.email}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInvoiceTitle() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        AppLocalizations.of(context)!.monthlyFeesPayment,
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue700,
        ),
      ),
    );
  }

  static pw.Widget _buildInvoiceInfo(Invoice invoice, DateFormat dateFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Invoice Number', invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : invoice.id),
          pw.SizedBox(height: 12),
          _buildInfoRow('Payment Date', dateFormat.format(invoice.issuedDate)),
          pw.SizedBox(height: 12),
          _buildInfoRow('Due Date', dateFormat.format(invoice.dueDate)),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey900,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPayerStudentSection(String parentName, String studentName, String month) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            AppLocalizations.of(context)!.fromParentnameForStudentSStudentname,
            style: pw.TextStyle(
              fontSize: 13,
              color: PdfColors.grey900,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            AppLocalizations.of(context)!.forTheMonthSOfMonth,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(Invoice invoice, NumberFormat money) {
    if (invoice.items.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text(
            AppLocalizations.of(context)!.noItemsOnThisInvoice,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey600,
            ),
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue700),
          children: [
            _buildTableCell('Description', isHeader: true),
            _buildTableCell('Qty', isHeader: true, align: pw.TextAlign.center),
            _buildTableCell('Price', isHeader: true, align: pw.TextAlign.right),
            _buildTableCell('Total', isHeader: true, align: pw.TextAlign.right),
          ],
        ),
        // Items
        ...invoice.items.map((item) {
          return pw.TableRow(
            children: [
              _buildTableCell(item.description),
              _buildTableCell('${item.quantity}', align: pw.TextAlign.center),
              _buildTableCell(money.format(item.unitPrice), align: pw.TextAlign.right),
              _buildTableCell(money.format(item.total), align: pw.TextAlign.right, isBold: true),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.grey900,
        ),
      ),
    );
  }

  static pw.Widget _buildSummarySection(Invoice invoice, NumberFormat money) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          _buildSummaryRow('Subtotal', money.format(invoice.totalAmount)),
          pw.SizedBox(height: 12),
          _buildSummaryRow('Paid', money.format(invoice.paidAmount), isPaid: true),
          pw.Divider(height: 20, color: PdfColors.grey300),
          _buildSummaryRow('Remaining Balance', money.format(invoice.remainingBalance), isTotal: true),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isTotal = false, bool isPaid = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isTotal ? 14 : 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isTotal ? 16 : 12,
            fontWeight: pw.FontWeight.bold,
            color: isTotal ? PdfColors.blue700 : PdfColors.grey900,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(AdminInfo adminInfo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Received by: ${adminInfo.name}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Text(
                AppLocalizations.of(context)!.signature,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Expanded(
                child: pw.Container(
                  height: 30,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey900, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

