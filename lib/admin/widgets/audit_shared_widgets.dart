import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuditDetailPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;

  const AuditDetailPill({
    super.key,
    required this.label,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlined ? color : Colors.transparent),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class AuditSectionTitle extends StatelessWidget {
  final String title;
  final bool isSubsection;

  const AuditSectionTitle({
    super.key,
    required this.title,
    this.isSubsection = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      isSubsection ? title : title.toUpperCase(),
      style: isSubsection
          ? GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xff64748B),
            )
          : GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xff9CA3AF),
              letterSpacing: 0.8,
            ),
    );
  }
}

class AuditKpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const AuditKpiCard({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 16, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff94A3B8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AuditRateBar extends StatelessWidget {
  final String label;
  final double rate;
  final double goodThreshold;
  final double warningThreshold;

  const AuditRateBar({
    super.key,
    required this.label,
    required this.rate,
    this.goodThreshold = 80,
    this.warningThreshold = 60,
  });

  Color get _color {
    if (rate >= goodThreshold) return const Color(0xFF10B981);
    if (rate >= warningThreshold) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final clamped = rate.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff475569))),
            Text(
              '${clamped.toStringAsFixed(0)}%',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 6,
            backgroundColor: const Color(0xffF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ],
    );
  }
}

class AuditSubjectRow extends StatelessWidget {
  final String subject;
  final double hours;
  final double maxHours;

  const AuditSubjectRow({
    super.key,
    required this.subject,
    required this.hours,
    required this.maxHours,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxHours > 0 ? (hours / maxHours).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              subject,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff374151)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: const Color(0xffF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff0078D4)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${hours.toStringAsFixed(1)}h',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xff64748B),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class AuditEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const AuditEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: color ?? const Color(0xffCBD5E1)),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AuditMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const AuditMiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? const Color(0xff9CA3AF)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color ?? const Color(0xff1E293B),
              ),
            ),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff9CA3AF))),
          ],
        ),
      ],
    );
  }
}

class AuditPayCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isHighlighted;

  const AuditPayCard({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? color.withValues(alpha: 0.3) : const Color(0xffE2E8F0),
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff64748B))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isHighlighted ? color : const Color(0xff1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

class AuditPayDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  final double fontSize;

  const AuditPayDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              color: const Color(0xff374151),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? const Color(0xff1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

class AuditAdjustmentRow extends StatelessWidget {
  final double amount;
  final String reason;

  const AuditAdjustmentRow({super.key, required this.amount, required this.reason});

  @override
  Widget build(BuildContext context) {
    final isPositive = amount >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isPositive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
            size: 16,
            color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(reason, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff374151)))),
          Text(
            '${isPositive ? '+' : ''}\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class AuditEditableFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const AuditEditableFieldRow({
    super.key,
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff475569)))),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xff1E293B))),
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined, size: 15, color: Color(0xff94A3B8)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
