import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FinancialSummaryCard extends StatelessWidget {
  final double outstanding;
  final double overdue;
  final double paid;
  final String currency;
  final VoidCallback? onPayNow;

  const FinancialSummaryCard({
    super.key,
    required this.outstanding,
    required this.overdue,
    required this.paid,
    this.currency = 'USD',
    this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.simpleCurrency(name: currency);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.financialSummary,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onPayNow != null && outstanding > 0)
                ElevatedButton.icon(
                  onPressed: onPayNow,
                  icon: const Icon(Icons.credit_card_rounded, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!.payNow,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0386FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metric(
                  label: 'Outstanding',
                  value: formatter.format(outstanding),
                  accent: outstanding > 0 ? const Color(0xFF38BDF8) : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric(
                  label: 'Overdue',
                  value: formatter.format(overdue),
                  accent: overdue > 0 ? const Color(0xFFFCA5A5) : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric(
                  label: 'Paid',
                  value: formatter.format(paid),
                  accent: const Color(0xFF86EFAC),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

