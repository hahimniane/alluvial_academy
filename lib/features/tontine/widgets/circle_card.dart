import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/features/tontine/config/tontine_ui.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_cycle.dart';
import 'package:alluwalacademyadmin/features/tontine/widgets/cycle_countdown.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class CircleCard extends StatelessWidget {
  final Circle circle;
  final CircleCycle? currentCycle;
  final VoidCallback onTap;
  final bool isCreator;

  const CircleCard({
    super.key,
    required this.circle,
    required this.currentCycle,
    required this.onTap,
    this.isCreator = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = TontineUi.circleStatusColor(circle.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isCreator
              ? Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  width: 1.5,
                )
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        circle.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (isCreator) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.shield_rounded,
                                size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              l10n.tontineCreatedByYou,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    TontineUi.circleStatusLabel(context, circle.status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoBlock(
                    label: l10n.tontineMonthlyContribution,
                    value: TontineUi.formatCurrency(
                      circle.currency,
                      circle.contributionAmount,
                    ),
                  ),
                ),
                Expanded(
                  child: _InfoBlock(
                    label: l10n.tontinePotAmount,
                    value: TontineUi.formatCurrency(
                      circle.currency,
                      circle.contributionAmount * circle.totalMembers,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    currentCycle == null
                        ? l10n.tontineNoActiveCycle
                        : l10n.tontineMonthOf(
                            currentCycle!.cycleNumber,
                            circle.totalMembers,
                          ),
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                CycleCountdown(dueDate: currentCycle?.dueDate),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBlock({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
