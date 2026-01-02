import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/models/invoice.dart';
import 'package:alluwalacademyadmin/core/models/payment.dart';
import 'package:alluwalacademyadmin/core/services/invoice_service.dart';
import 'package:alluwalacademyadmin/core/services/invoice_pdf_service.dart';
import 'package:alluwalacademyadmin/features/parent/screens/payment_screen.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/beautiful_invoice_widget.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Text(
          'Invoice Details',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<Invoice>(
        future: InvoiceService.getInvoice(invoiceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _errorState(context, '${snapshot.error}');
          }
          final invoice = snapshot.data;
          if (invoice == null) {
            return _errorState(context, 'Invoice not found');
          }

          final statusLabel = invoice.isOverdue ? 'OVERDUE' : invoice.status.name.toUpperCase();
          final statusColor = _statusColor(invoice);
          final money = NumberFormat.simpleCurrency(name: invoice.currency);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: invoice.isFullyPaid || invoice.status == InvoiceStatus.cancelled
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PaymentScreen(invoiceId: invoice.id),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.credit_card_rounded, size: 18),
                          label: Text(
                            invoice.isFullyPaid ? 'Paid' : 'Pay Invoice',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0386FF),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            disabledForegroundColor: const Color(0xFF9CA3AF),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _downloadInvoicePDF(context, invoice),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: Text(
                            'Download PDF',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF111827),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Status Badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Beautiful Invoice Widget
                BeautifulInvoiceWidget(invoice: invoice),
                const SizedBox(height: 18),
                Text(
                  'Payments',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('payments')
                      .where('invoice_id', isEqualTo: invoice.id)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                    }
                    if (snap.hasError) {
                      return _inlineError('Failed to load payments: ${snap.error}');
                    }
                    final docs = snap.data?.docs ?? const [];
                    final payments = docs
                        .map((d) => Payment.fromFirestore(d))
                        .toList()
                      ..sort((a, b) {
                        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                        return bTime.compareTo(aTime);
                      });

                    if (payments.isEmpty) {
                      return _inlineEmpty('No payments for this invoice yet.');
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: payments.map((p) {
                          final date = p.createdAt == null ? '' : DateFormat.yMMMd().format(p.createdAt!);
                          return ListTile(
                            leading: _statusDot(p.status),
                            title: Text(
                              money.format(p.amount),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              '${p.status.name.toUpperCase()}${date.isEmpty ? '' : ' • $date'}',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _downloadInvoicePDF(BuildContext context, Invoice invoice) async {
    try {
      // Show loading indicator
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate PDF
      final pdfBytes = await InvoicePdfService.generateInvoicePDF(invoice);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Share/Save PDF using printing package
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate PDF: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _errorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load invoice.\n$message',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _inlineEmpty(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _inlineError(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: GoogleFonts.inter(color: const Color(0xFF7F1D1D), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _statusDot(PaymentStatus status) {
    Color color;
    switch (status) {
      case PaymentStatus.completed:
        color = const Color(0xFF16A34A);
        break;
      case PaymentStatus.failed:
        color = const Color(0xFFDC2626);
        break;
      case PaymentStatus.processing:
        color = const Color(0xFF2563EB);
        break;
      case PaymentStatus.pending:
        color = const Color(0xFFF59E0B);
        break;
    }
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  Color _statusColor(Invoice invoice) {
    if (invoice.isOverdue) return const Color(0xFFDC2626);
    switch (invoice.status) {
      case InvoiceStatus.paid:
        return const Color(0xFF16A34A);
      case InvoiceStatus.cancelled:
        return const Color(0xFF6B7280);
      case InvoiceStatus.pending:
      case InvoiceStatus.overdue:
        return const Color(0xFFF59E0B);
    }
  }
}

