import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/services/invoice_data_service.dart';
import 'package:alluwalacademyadmin/features/settings/services/mock_company_service.dart' show CompanyInfo, AdminInfo;

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
    final billingMonthLabel =
        invoice.displayBillingPeriod ?? monthFormat.format(invoice.issuedDate);

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
              pw.SizedBox(height: 28),

              // Invoice Title
              _buildInvoiceTitle(invoice.invoiceNumber.isNotEmpty
                  ? invoice.invoiceNumber
                  : invoice.id),
              pw.SizedBox(height: 22),

              // Invoice Info
              _buildInvoiceInfo(invoice, dateFormat),
              pw.SizedBox(height: 22),

              // Payer/Student Section
              if (resolvedParentName != null || resolvedStudentName != null)
                _buildPayerStudentSection(
                  resolvedParentName ?? 'Parent',
                  resolvedStudentName ?? invoice.studentId,
                  billingMonthLabel,
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
        pw.Container(
          width: 5,
          height: 88,
          decoration: const pw.BoxDecoration(
            color: PdfColors.blue700,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Container(
          width: 64,
          height: 64,
          decoration: pw.BoxDecoration(
            color: PdfColors.blue100,
            border: pw.Border.all(color: PdfColors.blue500, width: 1.5),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Center(
            child: pw.Text(
              'AEH',
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
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                companyInfo.fullAddress,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Contact: ${companyInfo.phone}',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Email: ${companyInfo.email}',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInvoiceTitle(String invoiceNumber) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.blue100,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.blue200, width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 5,
            height: 52,
            color: PdfColors.blue700,
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Tuition & fees',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                  if (invoiceNumber.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      invoiceNumber,
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
          if (invoice.displayBillingPeriod != null) ...[
            pw.SizedBox(height: 12),
            _buildInfoRow('Billing period', invoice.displayBillingPeriod!),
          ],
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
            'From: $parentName  |  Student: $studentName',
            style: pw.TextStyle(
              fontSize: 13,
              color: PdfColors.grey900,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Billing period: $month',
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
            'No items on this invoice',
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
                'Signature',
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

