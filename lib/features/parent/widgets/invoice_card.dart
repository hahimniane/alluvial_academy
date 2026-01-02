import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/models/invoice.dart';

class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final String? studentName;
  final VoidCallback? onTap;
  final VoidCallback? onPayNow;

  const InvoiceCard({
    super.key,
    required this.invoice,
    this.studentName,
    this.onTap,
    this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = invoice.isOverdue ? 'OVERDUE' : invoice.status.name.toUpperCase();
    final statusColor = _statusColor(invoice);
    final currencyFormatter = NumberFormat.simpleCurrency(name: invoice.currency);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'Invoice',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (studentName != null && studentName!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  studentName!.trim(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _infoChip(
                      icon: Icons.calendar_month_rounded,
                      label: 'Due ${DateFormat.yMMMd().format(invoice.dueDate)}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoChip(
                      icon: Icons.attach_money_rounded,
                      label: currencyFormatter.format(invoice.totalAmount),
                      strong: true,
                    ),
                  ),
                ],
              ),
              if (onPayNow != null && !invoice.isFullyPaid && invoice.status != InvoiceStatus.cancelled) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onPayNow,
                    icon: const Icon(Icons.credit_card_rounded, size: 18),
                    label: Text(
                      'Pay Now',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String label, bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF111827),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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

