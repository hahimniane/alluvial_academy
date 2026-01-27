import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/models/payment.dart';
import 'package:alluwalacademyadmin/core/services/payment_service.dart';
import 'package:alluwalacademyadmin/features/parent/screens/invoice_detail_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final String parentId;

  const PaymentHistoryScreen({super.key, required this.parentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.paymentHistory, style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<List<Payment>>(
        stream: PaymentService.getPaymentHistory(parentId, limit: 100),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _message('Failed to load payments: ${snapshot.error}');
          }
          final payments = snapshot.data ?? const <Payment>[];
          if (payments.isEmpty) {
            return _message('No payments yet.');
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemBuilder: (context, index) {
              final p = payments[index];
              final money = NumberFormat.simpleCurrency().format(p.amount);
              final date = p.createdAt == null ? '' : DateFormat.yMMMd().format(p.createdAt!);
              final statusColor = _statusColor(p.status);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.payments_rounded, color: statusColor),
                  ),
                  title: Text(
                    money,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF111827)),
                  ),
                  subtitle: Text(
                    '${p.status.name.toUpperCase()}${date.isEmpty ? '' : ' • $date'}',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                  onTap: () async {
                    final invoiceId = p.invoiceId.trim();
                    if (invoiceId.isEmpty) return;
                    final doc = await FirebaseFirestore.instance.collection('invoices').doc(invoiceId).get();
                    if (!context.mounted) return;
                    if (!doc.exists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.invoiceNotFoundForThisPayment, style: GoogleFonts.inter())),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId)),
                    );
                  },
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: payments.length,
          );
        },
      ),
    );
  }

  Widget _message(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.completed:
        return const Color(0xFF16A34A);
      case PaymentStatus.processing:
        return const Color(0xFF2563EB);
      case PaymentStatus.failed:
        return const Color(0xFFDC2626);
      case PaymentStatus.pending:
        return const Color(0xFFF59E0B);
    }
  }
}

