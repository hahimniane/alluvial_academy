import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

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

  static const _accent = Color(0xFF1A56DB);

  Color get _statusColor {
    if (invoice.isOverdue) return const Color(0xFFDC2626);
    switch (invoice.status) {
      case InvoiceStatus.paid:
        return const Color(0xFF059669);
      case InvoiceStatus.cancelled:
        return const Color(0xFF6B7280);
      case InvoiceStatus.pending:
      case InvoiceStatus.overdue:
        return const Color(0xFFD97706);
    }
  }

  String get _statusLabel {
    if (invoice.isOverdue) return 'OVERDUE';
    switch (invoice.status) {
      case InvoiceStatus.paid:
        return 'PAID';
      case InvoiceStatus.overdue:
        return 'OVERDUE';
      case InvoiceStatus.cancelled:
        return 'CANCELLED';
      case InvoiceStatus.pending:
        return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.simpleCurrency(name: invoice.currency);
    final invNo = invoice.invoiceNumber.isNotEmpty
        ? invoice.invoiceNumber
        : 'Invoice';
    final statusColor = _statusColor;
    final isPayable = !invoice.isFullyPaid &&
        invoice.status != InvoiceStatus.cancelled &&
        onPayNow != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left status bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: statusColor,
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: invoice number + status badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  invNo,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusBadge(
                                  label: _statusLabel, color: statusColor),
                            ],
                          ),

                          // Student name
                          if (studentName != null &&
                              studentName!.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded,
                                    size: 13, color: Color(0xFF9CA3AF)),
                                const SizedBox(width: 4),
                                Text(
                                  studentName!.trim(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Billing period
                          if (invoice.displayBillingPeriod != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.calendar_month_outlined,
                                    size: 13, color: _accent),
                                const SizedBox(width: 4),
                                Text(
                                  invoice.displayBillingPeriod!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Row 2: amount (left) + due date (right)
                          Row(
                            children: [
                              // Amount due
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Amount due',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: const Color(0xFF9CA3AF),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      money.format(invoice.remainingBalance),
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: invoice.isFullyPaid
                                            ? const Color(0xFF059669)
                                            : const Color(0xFF111827),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Due date chip
                              _DueDateChip(
                                  date: invoice.dueDate,
                                  isOverdue: invoice.isOverdue),
                            ],
                          ),

                          // Access cutoff indicator (for unpaid, non-cancelled invoices)
                          if (!invoice.isFullyPaid &&
                              invoice.status != InvoiceStatus.cancelled) ...[
                            const SizedBox(height: 8),
                            _AccessCutoffBadge(
                              cutoffDate: invoice.effectiveAccessCutoffDate,
                            ),
                          ],

                          // Pay Now button
                          if (isPayable) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: ElevatedButton.icon(
                                onPressed: onPayNow,
                                icon: const Icon(Icons.credit_card_rounded,
                                    size: 16),
                                label: Text(
                                  AppLocalizations.of(context)!.payNow,
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _DueDateChip extends StatelessWidget {
  const _DueDateChip({required this.date, required this.isOverdue});
  final DateTime date;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    final color =
        isOverdue ? const Color(0xFFDC2626) : const Color(0xFF6B7280);
    final bgColor =
        isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFF9FAFB);
    final borderColor =
        isOverdue ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB);

    final now = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final daysOverdue = isOverdue ? now.difference(date).inDays : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue
                ? Icons.warning_amber_rounded
                : Icons.calendar_today_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            isOverdue
                ? '$daysOverdue day${daysOverdue == 1 ? '' : 's'} overdue'
                : DateFormat('MMM d').format(date),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessCutoffBadge extends StatelessWidget {
  const _AccessCutoffBadge({required this.cutoffDate});
  final DateTime cutoffDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLeft = cutoffDate.difference(now).inDays;
    final isPast = daysLeft < 0;
    final isToday = daysLeft == 0;

    // Don't show anything for fully future cutoffs that are far away
    // (only show when <= 14 days away or already past)
    if (!isPast && daysLeft > 14) return const SizedBox.shrink();

    final Color color;
    final Color bgColor;
    final Color borderColor;
    final IconData icon;
    final String label;

    if (isPast || isToday) {
      color = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      icon = Icons.lock_rounded;
      label = isPast
          ? 'Access suspended ${-daysLeft} day${-daysLeft == 1 ? '' : 's'} ago'
          : 'Access suspended today';
    } else if (daysLeft <= 3) {
      color = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFFED7AA);
      icon = Icons.lock_clock_rounded;
      label = daysLeft == 1
          ? 'Access cut off tomorrow'
          : 'Access cut off in $daysLeft days';
    } else {
      color = const Color(0xFFD97706);
      bgColor = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
      icon = Icons.lock_clock_rounded;
      label = 'Access cut off in $daysLeft days';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
