import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class CycleCountdown extends StatelessWidget {
  final DateTime? dueDate;

  const CycleCountdown({
    super.key,
    required this.dueDate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (dueDate == null) {
      return _CountdownChip(
        label: l10n.tontineNoDeadline,
        icon: Icons.schedule_rounded,
        backgroundColor: const Color(0xFFE2E8F0),
        foregroundColor: const Color(0xFF475569),
      );
    }

    final now = DateTime.now();
    final difference = dueDate!.difference(now);
    if (difference.isNegative) {
      return _CountdownChip(
        label: l10n.tontineOverdueBy('${difference.abs().inDays}d'),
        icon: Icons.warning_amber_rounded,
        backgroundColor: const Color(0xFFFEE2E2),
        foregroundColor: const Color(0xFFB91C1C),
      );
    }

    if (difference.inDays == 0) {
      return _CountdownChip(
        label: l10n.tontineDueToday,
        icon: Icons.today_rounded,
        backgroundColor: const Color(0xFFDCFCE7),
        foregroundColor: const Color(0xFF15803D),
      );
    }

    return _CountdownChip(
      label: l10n.tontineDueInDays(difference.inDays),
      icon: Icons.timelapse_rounded,
      backgroundColor: const Color(0xFFDBEAFE),
      foregroundColor: const Color(0xFF1D4ED8),
    );
  }
}

class _CountdownChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _CountdownChip({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
