import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/features/tontine/config/tontine_ui.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_contribution.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_cycle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_member.dart';
import 'package:alluwalacademyadmin/features/tontine/services/tontine_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ReviewSubmissionsScreen extends StatelessWidget {
  final Circle circle;
  final CircleCycle cycle;

  const ReviewSubmissionsScreen({
    super.key,
    required this.circle,
    required this.cycle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l10n.tontineReviewSubmissions,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: StreamBuilder<List<CircleMember>>(
        stream: TontineService.getCircleMembers(circle.id),
        builder: (context, membersSnapshot) {
          if (membersSnapshot.connectionState == ConnectionState.waiting &&
              !membersSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = membersSnapshot.data ?? const <CircleMember>[];
          final activeMembers = members
              .where((member) => member.status == CircleMemberStatus.active)
              .toList();

          return StreamBuilder<List<CircleContribution>>(
            stream: TontineService.getContributionsForCycle(cycle.id),
            builder: (context, contributionsSnapshot) {
              final contributions =
                  contributionsSnapshot.data ?? const <CircleContribution>[];
              final contributionByUserId = <String, CircleContribution>{
                for (final contribution in contributions)
                  contribution.userId: contribution,
              };
              final confirmedCount = activeMembers
                  .where((member) =>
                      contributionByUserId[member.userId]?.status ==
                      CircleContributionStatus.confirmed)
                  .length;
              final allConfirmed = activeMembers.isNotEmpty &&
                  confirmedCount == activeMembers.length;
              final progress = activeMembers.isEmpty
                  ? 0.0
                  : confirmedCount / activeMembers.length;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tontineReviewProgress,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.tontineConfirmedOf(
                              confirmedCount, activeMembers.length),
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...activeMembers.map((member) {
                    final contribution = contributionByUserId[member.userId];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _SubmissionCard(
                        member: member,
                        contribution: contribution,
                        currency: circle.currency,
                        onConfirm: contribution?.status ==
                                CircleContributionStatus.submitted
                            ? () async {
                                await TontineService.confirmContribution(
                                  contribution!.id,
                                );
                              }
                            : null,
                        onReject: contribution?.status ==
                                CircleContributionStatus.submitted
                            ? () => _showRejectDialog(
                                  context,
                                  contribution!,
                                )
                            : null,
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: allConfirmed &&
                            cycle.status != CircleCycleStatus.completed
                        ? () async {
                            await TontineService.markPayoutSent(cycle.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.tontinePayoutMarkedSent),
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          }
                        : null,
                    icon: const Icon(Icons.verified_rounded),
                    label: Text(l10n.tontineMarkPayoutSent),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    CircleContribution contribution,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.tontineRejectContribution),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.tontineRejectionReason,
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(l10n.tontineRejectContribution),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;
    await TontineService.rejectContribution(contribution.id, reason);
  }
}

class _SubmissionCard extends StatelessWidget {
  final CircleMember member;
  final CircleContribution? contribution;
  final String currency;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  const _SubmissionCard({
    required this.member,
    required this.contribution,
    required this.currency,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = TontineUi.contributionStatusColor(
      contribution?.status,
      memberStatus: member.status,
    );
    final receiptUrl = contribution?.receiptImageUrl;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFDBEAFE),
                backgroundImage:
                    member.photoUrl != null && member.photoUrl!.isNotEmpty
                        ? NetworkImage(member.photoUrl!)
                        : null,
                child: member.photoUrl == null || member.photoUrl!.isEmpty
                    ? Text(
                        TontineUi.initialsForName(member.displayName),
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      TontineUi.contributionStatusLabel(
                        context,
                        contribution?.status,
                        memberStatus: member.status,
                      ),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: l10n.tontineExpectedAmount,
            value: contribution == null
                ? '-'
                : TontineUi.formatCurrency(
                    currency, contribution!.expectedAmount),
          ),
          _InfoRow(
            label: l10n.tontineSubmittedAmount,
            value: contribution?.submittedAmount == null
                ? '-'
                : TontineUi.formatCurrency(
                    currency, contribution!.submittedAmount!),
          ),
          if (contribution?.rejectionReason?.isNotEmpty == true)
            _InfoRow(
              label: l10n.tontineRejectionReason,
              value: contribution!.rejectionReason!,
            ),
          if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.network(receiptUrl, fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  child: Text(l10n.tontineRejectContribution),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  child: Text(l10n.tontineConfirmContribution),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
