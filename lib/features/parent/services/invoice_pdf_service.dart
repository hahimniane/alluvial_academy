import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/services/invoice_data_service.dart';

/// Status shown on the invoice / receipt PDF.
enum InvoicePdfStatus { paid, partial, overdue, due, cancelled }

/// What the PDF says about an invoice. Same rules as the emailed copy
/// (functions/utils/invoice_pdf.js) and the parent web download
/// (apps/web/src/lib/invoicePdf.ts) — keep the three in step.
class InvoicePdfSummary {
  final InvoicePdfStatus status;
  final double remaining;

  const InvoicePdfSummary(this.status, this.remaining);

  bool get isReceipt => status == InvoicePdfStatus.paid;

  factory InvoicePdfSummary.of(Invoice invoice, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final remaining = double.parse(
        (invoice.totalAmount - invoice.paidAmount).clamp(0, double.infinity).toStringAsFixed(2));
    InvoicePdfStatus status;
    if (invoice.status == InvoiceStatus.cancelled) {
      status = InvoicePdfStatus.cancelled;
    } else if (invoice.status == InvoiceStatus.paid ||
        (invoice.totalAmount > 0 && remaining <= 0)) {
      status = InvoicePdfStatus.paid;
    } else if (invoice.dueDate.isBefore(clock)) {
      status = InvoicePdfStatus.overdue;
    } else if (invoice.paidAmount > 0) {
      status = InvoicePdfStatus.partial;
    } else {
      status = InvoicePdfStatus.due;
    }
    return InvoicePdfSummary(status, remaining);
  }
}

/// Service for generating invoice / receipt PDFs.
class InvoicePdfService {
  static const _companyName = 'Alluwal Education Hub';
  static const _street = '3184 Webster Ave';
  static const _city = 'Bronx, NY 10467, United States';
  static const _phone = '+1 646-338-1286';
  static const _email = 'billing@alluwaleducationhub.org';
  static const _website = 'alluwaleducationhub.org';

  static const _brand = PdfColor.fromInt(0xFF0369D9);
  static const _ink = PdfColor.fromInt(0xFF0F172A);
  static const _body = PdfColor.fromInt(0xFF334155);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _line = PdfColor.fromInt(0xFFE2E8F0);
  static const _soft = PdfColor.fromInt(0xFFF8FAFC);

  static const Map<InvoicePdfStatus, List<Object>> _badge = {
    InvoicePdfStatus.paid: ['PAID', PdfColor.fromInt(0xFF047857), PdfColor.fromInt(0xFFD1FAE5)],
    InvoicePdfStatus.partial: ['PARTIALLY PAID', PdfColor.fromInt(0xFFB45309), PdfColor.fromInt(0xFFFEF3C7)],
    InvoicePdfStatus.overdue: ['OVERDUE', PdfColor.fromInt(0xFFB91C1C), PdfColor.fromInt(0xFFFEE2E2)],
    InvoicePdfStatus.due: ['DUE', PdfColor.fromInt(0xFF0369D9), PdfColor.fromInt(0xFFDBEAFE)],
    InvoicePdfStatus.cancelled: ['CANCELLED', PdfColor.fromInt(0xFF475569), PdfColor.fromInt(0xFFE2E8F0)],
  };

  /// Generate PDF bytes for an invoice (a receipt once it is paid in full).
  static Future<Uint8List> generateInvoicePDF(
    Invoice invoice, {
    String? parentName,
    String? studentName,
    DateTime? now,
  }) async {
    final resolvedParentName =
        parentName ?? await InvoiceDataService.getParentName(invoice.parentId);
    final resolvedStudentName =
        studentName ?? await InvoiceDataService.getStudentName(invoice.studentId);
    final doc = buildDocument(
      invoice,
      parentName: resolvedParentName,
      studentName: resolvedStudentName,
      now: now,
    );
    return doc.save();
  }

  /// The document itself (no lookups), so tests can build it directly.
  static pw.Document buildDocument(
    Invoice invoice, {
    String? parentName,
    String? studentName,
    DateTime? now,
  }) {
    final summary = InvoicePdfSummary.of(invoice, now: now);
    final money = NumberFormat.simpleCurrency(name: invoice.currency.toUpperCase());
    final longDate = DateFormat.yMMMMd('en_US');
    final shortDate = DateFormat.yMMMd('en_US');
    final number = invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : invoice.id;
    final period = invoice.displayBillingPeriod ??
        DateFormat.yMMMM('en_US').format(invoice.issuedDate);

    final doc = pw.Document(title: '${summary.isReceipt ? 'Receipt' : 'Invoice'} $number');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 40),
        footer: (context) => _footer(context),
        build: (context) => [
          _header(summary, number),
          pw.SizedBox(height: 22),
          _hero(invoice, summary, money, longDate),
          pw.SizedBox(height: 26),
          _meta(invoice, summary, number, period, shortDate,
              parentName: parentName, studentName: studentName),
          pw.SizedBox(height: 26),
          _items(invoice, money),
          _totals(invoice, summary, money),
          pw.SizedBox(height: 22),
          _note(summary),
        ],
      ),
    );
    return doc;
  }

  static pw.TextStyle _t(double size,
          {PdfColor color = _ink, bool bold = false}) =>
      pw.TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );

  static pw.Widget _header(InvoicePdfSummary summary, String number) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 18),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.75)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 40,
            height: 40,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _brand,
              borderRadius: pw.BorderRadius.circular(9),
            ),
            child: pw.Text('AEH', style: _t(12, color: PdfColors.white, bold: true)),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 4),
                pw.Text(_companyName, style: _t(14, bold: true)),
                pw.SizedBox(height: 3),
                pw.Text(_website, style: _t(9, color: _muted)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(summary.isReceipt ? 'Receipt' : 'Invoice', style: _t(24, bold: true)),
              pw.SizedBox(height: 2),
              pw.Text(number, style: _t(10, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _hero(Invoice invoice, InvoicePdfSummary summary,
      NumberFormat money, DateFormat longDate) {
    late final String label;
    late final double amount;
    late final String sub;
    switch (summary.status) {
      case InvoicePdfStatus.paid:
        label = 'AMOUNT PAID';
        amount = invoice.paidAmount > 0 ? invoice.paidAmount : invoice.totalAmount;
        sub = invoice.lastPaymentAt != null
            ? 'Paid on ${longDate.format(invoice.lastPaymentAt!.toLocal())}'
            : 'Paid in full';
        break;
      case InvoicePdfStatus.cancelled:
        label = 'INVOICE TOTAL';
        amount = invoice.totalAmount;
        sub = 'This invoice was cancelled. Nothing is owed.';
        break;
      default:
        label = invoice.paidAmount > 0 ? 'BALANCE DUE' : 'AMOUNT DUE';
        amount = summary.remaining;
        sub = '${summary.status == InvoicePdfStatus.overdue ? 'Was due' : 'Due'} '
            '${longDate.format(invoice.dueDate.toLocal())}';
    }
    final badge = _badge[summary.status]!;
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(12)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: _t(8.5, color: _muted, bold: true)),
                pw.SizedBox(height: 6),
                pw.Text(money.format(amount), style: _t(24, bold: true)),
                pw.SizedBox(height: 4),
                pw.Text(sub, style: _t(9.5, color: _body)),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: pw.BoxDecoration(
              color: badge[2] as PdfColor,
              borderRadius: pw.BorderRadius.circular(11),
            ),
            child: pw.Text(badge[0] as String,
                style: _t(8.5, color: badge[1] as PdfColor, bold: true)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _heading(String text) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(text, style: _t(8, color: _muted, bold: true)),
      );

  static pw.Widget _meta(Invoice invoice, InvoicePdfSummary summary,
      String number, String period, DateFormat shortDate,
      {String? parentName, String? studentName}) {
    final hasParent = (parentName ?? '').trim().isNotEmpty;
    final hasStudent = (studentName ?? '').trim().isNotEmpty;
    final details = <List<String>>[
      [summary.isReceipt ? 'Receipt for' : 'Invoice', number],
      ['Issued', shortDate.format(invoice.issuedDate.toLocal())],
      if (summary.status != InvoicePdfStatus.paid &&
          summary.status != InvoicePdfStatus.cancelled)
        ['Due', shortDate.format(invoice.dueDate.toLocal())],
      if (summary.isReceipt && invoice.lastPaymentAt != null)
        ['Paid', shortDate.format(invoice.lastPaymentAt!.toLocal())],
      if (period.isNotEmpty) ['Period', period],
      if (invoice.accessCutoffDate != null &&
          summary.status != InvoicePdfStatus.paid &&
          summary.status != InvoicePdfStatus.cancelled)
        ['Access until', shortDate.format(invoice.accessCutoffDate!.toLocal())],
    ];
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _heading('BILLED TO'),
                pw.Text(hasParent ? parentName!.trim() : 'Parent', style: _t(10, bold: true)),
                if (hasStudent) ...[
                  pw.SizedBox(height: 3),
                  pw.Text('Student: ${studentName!.trim()}', style: _t(10, color: _body)),
                ],
              ],
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _heading('DETAILS'),
              for (final row in details)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(children: [
                    pw.SizedBox(width: 68, child: pw.Text(row[0], style: _t(9.5, color: _muted))),
                    pw.Expanded(child: pw.Text(row[1], style: _t(9.5))),
                  ]),
                ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _heading('FROM'),
              pw.Text(_companyName, style: _t(9.5, bold: true)),
              for (final line in const [_street, _city, _phone, _email])
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(line, style: _t(9.5, color: _body)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _items(Invoice invoice, NumberFormat money) {
    pw.Widget cell(String text,
            {bool right = false, bool head = false, PdfColor color = _ink}) =>
        pw.Padding(
          padding: pw.EdgeInsets.fromLTRB(right ? 8 : 0, head ? 0 : 8, 0, head ? 8 : 8),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: head ? _t(8, color: _muted, bold: true) : _t(10, color: color),
          ),
        );
    String qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
    return pw.Table(
      columnWidths: const {
        0: pw.FractionColumnWidth(0.56),
        1: pw.FractionColumnWidth(0.08),
        2: pw.FractionColumnWidth(0.18),
        3: pw.FractionColumnWidth(0.18),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.9)),
          ),
          children: [
            cell('DESCRIPTION', head: true),
            cell('QTY', head: true, right: true),
            cell('UNIT PRICE', head: true, right: true),
            cell('AMOUNT', head: true, right: true),
          ],
        ),
        if (invoice.items.isEmpty)
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.75)),
            ),
            children: [
              cell('No items on this invoice', color: _muted),
              cell(''),
              cell(''),
              cell(''),
            ],
          ),
        for (final item in invoice.items)
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.75)),
            ),
            children: [
              cell(item.description.isEmpty ? 'Item' : item.description),
              cell(qty(item.quantity.toDouble()), right: true, color: _body),
              cell(money.format(item.unitPrice), right: true, color: _body),
              cell(money.format(item.total), right: true),
            ],
          ),
      ],
    );
  }

  static pw.Widget _totals(
      Invoice invoice, InvoicePdfSummary summary, NumberFormat money) {
    final rows = <List<Object>>[
      ['Total', money.format(invoice.totalAmount), false],
      if (summary.status != InvoicePdfStatus.cancelled) ...[
        [
          'Amount paid',
          invoice.paidAmount > 0 ? '-${money.format(invoice.paidAmount)}' : money.format(0),
          false
        ],
        [summary.isReceipt ? 'Balance' : 'Balance due', money.format(summary.remaining), true],
      ],
    ];
    return pw.Row(
      children: [
        pw.Spacer(),
        pw.SizedBox(
          width: 258,
          child: pw.Column(
            children: [
              pw.SizedBox(height: 6),
              for (final row in rows)
                pw.Container(
                  padding: pw.EdgeInsets.only(top: row[2] == true ? 10 : 5, bottom: 5),
                  decoration: row[2] == true
                      ? const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: _line, width: 0.75)))
                      : null,
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(row[0] as String,
                            style: row[2] == true ? _t(11, bold: true) : _t(10, color: _body)),
                      ),
                      pw.Text(row[1] as String,
                          style: row[2] == true ? _t(13, color: _brand, bold: true) : _t(10)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String noteText(InvoicePdfStatus status) {
    switch (status) {
      case InvoicePdfStatus.paid:
        return 'Thank you for your payment. Keep this receipt for your records.';
      case InvoicePdfStatus.cancelled:
        return 'Questions about this invoice? Write to $_email.';
      default:
        return 'Pay online from your parent account at alluwaleducationhub.org, '
            'or with the Pay link in your invoice email.';
    }
  }

  static pw.Widget _note(InvoicePdfSummary summary) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Text(noteText(summary.status), style: _t(9.5, color: _body)),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line, width: 0.75)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text('$_companyName  ·  $_email  ·  $_phone',
                style: _t(8, color: _muted)),
          ),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: _t(8, color: _muted)),
        ],
      ),
    );
  }
}
