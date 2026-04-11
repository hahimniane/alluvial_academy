import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/features/tontine/models/circle_contribution.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_member.dart';
import 'package:alluwalacademyadmin/features/tontine/widgets/member_tile.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class PaymentStatusBoard extends StatelessWidget {
  final List<CircleMember> members;
  final List<CircleContribution> contributions;
  final String? recipientUserId;
  final String currency;
  final int crossAxisCount;
  final double childAspectRatio;
  final bool showHeader;
  final void Function(CircleMember member, CircleContribution? contribution)?
      onMemberTap;

  const PaymentStatusBoard({
    super.key,
    required this.members,
    required this.contributions,
    required this.recipientUserId,
    required this.currency,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.78,
    this.showHeader = true,
    this.onMemberTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contributionByUserId = <String, CircleContribution>{
      for (final contribution in contributions)
        contribution.userId: contribution,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Text(
            l10n.tontinePaymentStatusBoard,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final contribution = contributionByUserId[member.userId];
            return MemberTile(
              member: member,
              contribution: contribution,
              isRecipient: member.userId == recipientUserId,
              currency: currency,
              isDesktop: crossAxisCount >= 3,
              onTap: onMemberTap == null
                  ? null
                  : () => onMemberTap!(member, contribution),
            );
          },
        ),
      ],
    );
  }
}
