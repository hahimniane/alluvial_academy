import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/features/tontine/config/tontine_ui.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_contribution.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_member.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class MemberTile extends StatelessWidget {
  final CircleMember member;
  final CircleContribution? contribution;
  final bool isRecipient;
  final String currency;
  final bool isDesktop;
  final VoidCallback? onTap;

  const MemberTile({
    super.key,
    required this.member,
    required this.contribution,
    required this.isRecipient,
    required this.currency,
    this.isDesktop = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = TontineUi.contributionStatusColor(
      contribution?.status,
      memberStatus: member.status,
    );
    final statusLabel = TontineUi.contributionStatusLabel(
      context,
      contribution?.status,
      memberStatus: member.status,
    );
    final initials = TontineUi.initialsForName(member.displayName);
    final submittedAmount = contribution?.submittedAmount;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 18 : 12),
        decoration: BoxDecoration(
          color:
              isRecipient ? const Color(0xFFF3F8FF) : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isRecipient ? const Color(0xFF60A5FA) : const Color(0xFFE2E8F0),
            width: isRecipient ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.07),
              blurRadius: isRecipient ? 26 : 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: isDesktop ? 24 : 18,
                  backgroundColor: isRecipient
                      ? const Color(0xFFBFDBFE)
                      : const Color(0xFFDBEAFE),
                  backgroundImage:
                      member.photoUrl != null && member.photoUrl!.isNotEmpty
                          ? NetworkImage(member.photoUrl!)
                          : null,
                  child: member.photoUrl == null || member.photoUrl!.isEmpty
                      ? Text(
                          initials,
                          style: TextStyle(
                            color: const Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w800,
                            fontSize: isDesktop ? 14 : 12,
                          ),
                        )
                      : null,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: isDesktop ? 11 : 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 12 : 6),
            Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: isDesktop ? 8 : 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.tontinePosition(member.payoutPosition),
                    style: TextStyle(
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                      fontSize: isDesktop ? 14 : 12,
                    ),
                  ),
                ),
                if (isRecipient)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.tontineCurrentRecipient,
                      style: TextStyle(
                        color: const Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w800,
                        fontSize: isDesktop ? 14 : 12,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: isDesktop ? 12 : 6),
            if (submittedAmount != null)
              Text(
                TontineUi.formatCurrency(currency, submittedAmount),
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              )
            else
              Text(
                TontineUi.formatCurrency(
                    currency, contribution?.expectedAmount ?? 0),
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            const SizedBox(height: 2),
            Text(
              submittedAmount != null
                  ? l10n.tontineSubmittedAmount
                  : l10n.tontineExpectedAmount,
              style: TextStyle(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: isDesktop ? 14 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
