import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/tontine/config/tontine_ui.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_contribution.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_cycle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_member.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/edit_circle_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/review_submissions_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/submit_payment_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/services/tontine_service.dart';
import 'package:alluwalacademyadmin/features/tontine/widgets/cycle_countdown.dart';
import 'package:alluwalacademyadmin/features/tontine/widgets/payment_status_board.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class CircleDashboardScreen extends StatelessWidget {
  final String circleId;

  const CircleDashboardScreen({
    super.key,
    required this.circleId,
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
          l10n.tontineCircleDetails,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          _EditCircleButton(circleId: circleId),
        ],
      ),
      body: StreamBuilder<Circle?>(
        stream: TontineService.getCircle(circleId),
        builder: (context, circleSnapshot) {
          if (circleSnapshot.connectionState == ConnectionState.waiting &&
              !circleSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final circle = circleSnapshot.data;
          if (circle == null) {
            return Center(
              child: Text(
                l10n.tontineCircleNotFound,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return StreamBuilder<List<CircleMember>>(
            stream: TontineService.getCircleMembers(circle.id),
            builder: (context, membersSnapshot) {
              if (membersSnapshot.connectionState == ConnectionState.waiting &&
                  !membersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = membersSnapshot.data ?? const <CircleMember>[];
              return StreamBuilder<CircleCycle?>(
                stream: TontineService.getCurrentCycle(circle.id),
                builder: (context, cycleSnapshot) {
                  final cycle = cycleSnapshot.data;
                  if (cycle == null) {
                    return _CircleDashboardBody(
                      circle: circle,
                      members: members,
                      cycle: null,
                      contributions: const <CircleContribution>[],
                    );
                  }

                  return StreamBuilder<List<CircleContribution>>(
                    stream: TontineService.getContributionsForCycle(cycle.id),
                    builder: (context, contributionsSnapshot) {
                      final contributions = contributionsSnapshot.data ??
                          const <CircleContribution>[];
                      return _CircleDashboardBody(
                        circle: circle,
                        members: members,
                        cycle: cycle,
                        contributions: contributions,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CircleDashboardBody extends StatelessWidget {
  final Circle circle;
  final List<CircleMember> members;
  final CircleCycle? cycle;
  final List<CircleContribution> contributions;

  const _CircleDashboardBody({
    required this.circle,
    required this.members,
    required this.cycle,
    required this.contributions,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final currentMember =
        members.where((member) => member.userId == currentUserId).firstOrNull;
    final isHead = currentMember?.isTontineHead ?? false;
    final head = members.where((member) => member.isTontineHead).firstOrNull;
    final activeMembers = members
        .where((member) => member.status == CircleMemberStatus.active)
        .toList();
    final currentContribution = contributions
        .where((contribution) => contribution.userId == currentUserId)
        .firstOrNull;
    final recipient = cycle == null
        ? null
        : members
            .where((member) => member.userId == cycle!.payoutRecipientUserId)
            .firstOrNull;
    final canActivate = isHead &&
        circle.status == CircleStatus.forming &&
        activeMembers.length == circle.totalMembers;
    final confirmedCount = contributions
        .where((contribution) =>
            contribution.status == CircleContributionStatus.confirmed)
        .length;
    final submittedCount = contributions
        .where((contribution) =>
            contribution.status == CircleContributionStatus.submitted)
        .length;
    final completedPayoutCount =
        members.where((member) => member.hasReceivedPayout).length;
    final progress =
        activeMembers.isEmpty ? 0.0 : confirmedCount / activeMembers.length;
    final totalPot = circle.contributionAmount * circle.totalMembers;
    final primaryAction = cycle == null
        ? null
        : _resolvePrimaryAction(
            context,
            isHead: isHead,
            cycle: cycle!,
            currentContribution: currentContribution,
          );
    final primaryActionLabel = isHead
        ? l10n.tontineReviewSubmissions
        : currentContribution?.status == CircleContributionStatus.confirmed
            ? l10n.tontinePaymentConfirmed
            : l10n.tontineSubmitPayment;
    final primaryActionIcon =
        isHead ? Icons.fact_check_rounded : Icons.upload_file_rounded;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        if (isDesktop) {
          return _buildDesktopLayout(
            context,
            head: head,
            recipient: recipient,
            activeMembers: activeMembers,
            totalPot: totalPot,
            confirmedCount: confirmedCount,
            submittedCount: submittedCount,
            completedPayoutCount: completedPayoutCount,
            progress: progress,
            canActivate: canActivate,
            primaryAction: primaryAction,
            primaryActionLabel: primaryActionLabel,
            primaryActionIcon: primaryActionIcon,
            maxWidth: constraints.maxWidth,
            isHead: isHead,
          );
        }

        return _buildMobileLayout(
          context,
          recipient: recipient,
          activeMembers: activeMembers,
          totalPot: totalPot,
          confirmedCount: confirmedCount,
          canActivate: canActivate,
          primaryAction: primaryAction,
          primaryActionLabel: primaryActionLabel,
          primaryActionIcon: primaryActionIcon,
          isHead: isHead,
        );
      },
    );
  }

  Widget _buildMobileLayout(
    BuildContext context, {
    required CircleMember? recipient,
    required List<CircleMember> activeMembers,
    required double totalPot,
    required int confirmedCount,
    required bool canActivate,
    required VoidCallback? primaryAction,
    required String primaryActionLabel,
    required IconData primaryActionIcon,
    required bool isHead,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeroCard(
          context,
          recipient: recipient,
          activeMembers: activeMembers,
          totalPot: totalPot,
          confirmedCount: confirmedCount,
          head: members.where((member) => member.isTontineHead).firstOrNull,
          isDesktop: false,
          showSummaryPanel: false,
        ),
        const SizedBox(height: 18),
        if (cycle != null) ...[
          _SurfaceCard(
            title: l10n.tontineCurrentCycle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.tontineDueDate}: ${DateFormat('MMM d, yyyy').format(cycle!.dueDate ?? DateTime.now())}',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusBadge(
                  label: TontineUi.cycleStatusLabel(context, cycle!.status),
                  color: TontineUi.cycleStatusColor(cycle!.status),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        PaymentStatusBoard(
          members: members,
          contributions: contributions,
          recipientUserId: cycle?.payoutRecipientUserId,
          currency: circle.currency,
          onMemberTap: (member, contribution) => _showMemberDetails(
            context,
            member,
            contribution,
            circle.currency,
            isHead,
            circle.id,
          ),
        ),
        const SizedBox(height: 18),
        _buildStatePanel(
          context,
          activeMembers: activeMembers,
          canActivate: canActivate,
          primaryAction: primaryAction,
          primaryActionLabel: primaryActionLabel,
          primaryActionIcon: primaryActionIcon,
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context, {
    required CircleMember? head,
    required CircleMember? recipient,
    required List<CircleMember> activeMembers,
    required double totalPot,
    required int confirmedCount,
    required int submittedCount,
    required int completedPayoutCount,
    required double progress,
    required bool canActivate,
    required VoidCallback? primaryAction,
    required String primaryActionLabel,
    required IconData primaryActionIcon,
    required double maxWidth,
    required bool isHead,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final boardColumns = maxWidth >= 1580 ? 4 : 3;
    final statsColumns = maxWidth >= 1520 ? 4 : 2;
    final recipientName =
        recipient?.displayName ?? l10n.tontineRecipientPending;
    final dueDateLabel = cycle?.dueDate == null
        ? l10n.commonNotSet
        : DateFormat('EEE, MMM d').format(cycle!.dueDate!);
    final joinedValue = '${activeMembers.length}/${circle.totalMembers}';
    final completedValue = '$completedPayoutCount/${circle.totalMembers}';

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFF0FDFA),
                  Color(0xFFEFF6FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        const Positioned(
          top: -120,
          right: -80,
          child: _BackgroundOrb(
            size: 360,
            colors: [Color(0x4014B8A6), Color(0x0014B8A6)],
          ),
        ),
        const Positioned(
          top: 360,
          left: -120,
          child: _BackgroundOrb(
            size: 340,
            colors: [Color(0x262563EB), Color(0x002563EB)],
          ),
        ),
        const Positioned(
          bottom: -220,
          right: 120,
          child: _BackgroundOrb(
            size: 460,
            colors: [Color(0x22F59E0B), Color(0x00F59E0B)],
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 30, 32, 42),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroCard(
                    context,
                    recipient: recipient,
                    activeMembers: activeMembers,
                    totalPot: totalPot,
                    confirmedCount: confirmedCount,
                    head: head,
                    isDesktop: true,
                    showSummaryPanel: true,
                  ),
                  const SizedBox(height: 22),
                  GridView.count(
                    crossAxisCount: statsColumns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: statsColumns == 4 ? 2.05 : 2.35,
                    children: [
                      _OverviewStatCard(
                        label: l10n.tontineContributionAmount,
                        value: TontineUi.formatCurrency(
                          circle.currency,
                          circle.contributionAmount,
                        ),
                        icon: Icons.wallet_rounded,
                        accent: const Color(0xFF0E7490),
                      ),
                      _OverviewStatCard(
                        label: l10n.tontinePotAmount,
                        value:
                            TontineUi.formatCurrency(circle.currency, totalPot),
                        icon: Icons.savings_rounded,
                        accent: const Color(0xFF10B981),
                      ),
                      _OverviewStatCard(
                        label: l10n.tontineMemberCount,
                        value: joinedValue,
                        icon: Icons.groups_2_rounded,
                        accent: const Color(0xFF2563EB),
                      ),
                      _OverviewStatCard(
                        label: l10n.tontineStatusCompleted,
                        value: completedValue,
                        icon: Icons.workspace_premium_rounded,
                        accent: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _SurfaceCard(
                          title: l10n.tontinePaymentStatusBoard,
                          subtitle: l10n.tontineConfirmedOf(
                            confirmedCount,
                            activeMembers.length,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _LegendPill(
                                    label: l10n.tontineContributionConfirmed,
                                    color: const Color(0xFF10B981),
                                  ),
                                  _LegendPill(
                                    label: l10n.tontineContributionSubmitted,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                  _LegendPill(
                                    label: l10n.tontineContributionPending,
                                    color: const Color(0xFFDC2626),
                                  ),
                                  _LegendPill(
                                    label: l10n.tontineCurrentRecipient,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF8FAFC),
                                      Color(0xFFF0FDFA),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFD9F99D),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _SectionMetricTile(
                                        label: l10n.tontineCurrentRecipient,
                                        value: recipientName,
                                        accent: const Color(0xFF2563EB),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _SectionMetricTile(
                                        label: l10n.tontineDueDate,
                                        value: dueDateLabel,
                                        accent: const Color(0xFF0E7490),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _SectionMetricTile(
                                        label:
                                            l10n.tontineContributionSubmitted,
                                        value:
                                            '$submittedCount/${activeMembers.length}',
                                        accent: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              PaymentStatusBoard(
                                members: members,
                                contributions: contributions,
                                recipientUserId: cycle?.payoutRecipientUserId,
                                currency: circle.currency,
                                crossAxisCount: boardColumns,
                                childAspectRatio:
                                    boardColumns == 4 ? 1.14 : 1.0,
                                showHeader: false,
                                onMemberTap: (member, contribution) =>
                                    _showMemberDetails(
                                  context,
                                  member,
                                  contribution,
                                  circle.currency,
                                  isHead,
                                  circle.id,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 360,
                        child: Column(
                          children: [
                            _SurfaceCard(
                              title: l10n.tontineCurrentCycle,
                              subtitle: TontineUi.circleStatusLabel(
                                context,
                                circle.status,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF0F172A),
                                          Color(0xFF134E4A),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                recipientName,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            if (cycle != null)
                                              _StatusBadge(
                                                label:
                                                    TontineUi.cycleStatusLabel(
                                                  context,
                                                  cycle!.status,
                                                ),
                                                color:
                                                    TontineUi.cycleStatusColor(
                                                  cycle!.status,
                                                ),
                                                dark: true,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          l10n.tontineCurrentRecipient,
                                          style: const TextStyle(
                                            color: Color(0xFFCCFBF1),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        CycleCountdown(dueDate: cycle?.dueDate),
                                        const SizedBox(height: 18),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _Metric(
                                                label: l10n.tontineDueDate,
                                                value: dueDateLabel,
                                              ),
                                            ),
                                            Expanded(
                                              child: _Metric(
                                                label:
                                                    l10n.tontineConfirmedCount,
                                                value:
                                                    '$confirmedCount/${activeMembers.length}',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _buildStatePanel(
                                    context,
                                    activeMembers: activeMembers,
                                    canActivate: canActivate,
                                    primaryAction: primaryAction,
                                    primaryActionLabel: primaryActionLabel,
                                    primaryActionIcon: primaryActionIcon,
                                    embedded: true,
                                  ),
                                  if (circle.status == CircleStatus.active &&
                                      cycle != null) ...[
                                    const SizedBox(height: 18),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 10,
                                        backgroundColor:
                                            const Color(0xFFE2E8F0),
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _InlineMetric(
                                            label: l10n
                                                .tontineContributionSubmitted,
                                            value:
                                                '$submittedCount/${activeMembers.length}',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _InlineMetric(
                                            label: l10n.tontineStatusCompleted,
                                            value:
                                                '$completedPayoutCount/${circle.totalMembers}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SurfaceCard(
                              title: l10n.tontinePaymentInstructions,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      circle.paymentInstructions.isEmpty
                                          ? l10n.commonNotSet
                                          : circle.paymentInstructions,
                                      style: const TextStyle(
                                        height: 1.6,
                                        color: Color(0xFF334155),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _SectionMetricTile(
                                          label: l10n.tontineGracePeriodDays,
                                          value:
                                              '${circle.rules.gracePeriodDays}',
                                          accent: const Color(0xFF10B981),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _SectionMetricTile(
                                          label:
                                              l10n.tontineMissedPaymentAction,
                                          value: TontineUi
                                              .missedPaymentActionLabel(
                                            context,
                                            circle.rules.missedPaymentAction,
                                          ),
                                          accent: const Color(0xFF0E7490),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SurfaceCard(
                              title: l10n.tontinePayoutOrder,
                              subtitle: l10n.tontineMonthOf(
                                cycle?.cycleNumber ??
                                    (circle.currentCycleIndex + 1),
                                circle.totalMembers,
                              ),
                              child: Column(
                                children: members
                                    .map(
                                      (member) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _PayoutOrderRow(
                                          member: member,
                                          isRecipient: member.userId ==
                                              cycle?.payoutRecipientUserId,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required CircleMember? recipient,
    required List<CircleMember> activeMembers,
    required double totalPot,
    required int confirmedCount,
    required CircleMember? head,
    required bool isDesktop,
    required bool showSummaryPanel,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final dueDateLabel = cycle?.dueDate == null
        ? l10n.tontineWaitingForCycle
        : DateFormat('MMM d, yyyy').format(cycle!.dueDate!);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusBadge(
          label: TontineUi.circleStatusLabel(context, circle.status),
          color: TontineUi.circleStatusColor(circle.status),
          dark: true,
        ),
        const SizedBox(height: 14),
        Text(
          circle.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: isDesktop ? 36 : 24,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          circle.paymentInstructions.isEmpty
              ? l10n.tontineHomeSubtitle
              : circle.paymentInstructions,
          maxLines: isDesktop ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color:
                isDesktop ? const Color(0xFFD1FAE5) : const Color(0xFFDCFCE7),
            height: 1.6,
            fontWeight: FontWeight.w500,
            fontSize: isDesktop ? 15 : 14,
          ),
        ),
        const SizedBox(height: 18),
        if (isDesktop)
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _HeroFactCard(
                icon: Icons.workspace_premium_rounded,
                label: l10n.tontineCurrentRecipient,
                value: recipient?.displayName ?? l10n.tontineRecipientPending,
              ),
              _HeroFactCard(
                icon: Icons.verified_user_rounded,
                label: l10n.tontineCircleHead,
                value: head?.displayName ?? l10n.commonUnknown,
              ),
              _HeroFactCard(
                icon: Icons.calendar_month_rounded,
                label: l10n.tontineDueDate,
                value: dueDateLabel,
              ),
              _HeroFactCard(
                icon: Icons.repeat_rounded,
                label: l10n.tontineFrequency,
                value: _frequencyLabel(context, circle.frequency),
              ),
            ],
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(
                icon: Icons.calendar_month_rounded,
                label: cycle == null
                    ? l10n.tontineMonthOf(
                        circle.currentCycleIndex + 1,
                        circle.totalMembers,
                      )
                    : l10n.tontineMonthOf(
                        cycle!.cycleNumber,
                        circle.totalMembers,
                      ),
              ),
              _Chip(
                icon: Icons.workspace_premium_rounded,
                label: recipient?.displayName ?? l10n.tontineRecipientPending,
              ),
              _Chip(
                icon: Icons.verified_user_rounded,
                label:
                    '${l10n.tontineCircleHead}: ${head?.displayName ?? l10n.commonUnknown}',
              ),
              _Chip(
                icon: Icons.repeat_rounded,
                label: _frequencyLabel(context, circle.frequency),
              ),
            ],
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isDesktop ? 30 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF115E59), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x334BF0C8), Color(0x004BF0C8)],
                ),
              ),
            ),
          ),
          if (showSummaryPanel)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: content),
                const SizedBox(width: 22),
                Expanded(
                  flex: 3,
                  child: _HeroSummaryCard(
                    potValue:
                        TontineUi.formatCurrency(circle.currency, totalPot),
                    confirmedValue: '$confirmedCount/${activeMembers.length}',
                    countdown: CycleCountdown(dueDate: cycle?.dueDate),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: l10n.tontinePotAmount,
                        value:
                            TontineUi.formatCurrency(circle.currency, totalPot),
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: l10n.tontineConfirmedCount,
                        value: '$confirmedCount/${activeMembers.length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                CycleCountdown(dueDate: cycle?.dueDate),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatePanel(
    BuildContext context, {
    required List<CircleMember> activeMembers,
    required bool canActivate,
    required VoidCallback? primaryAction,
    required String primaryActionLabel,
    required IconData primaryActionIcon,
    bool embedded = false,
  }) {
    final l10n = AppLocalizations.of(context)!;

    if (circle.status == CircleStatus.forming) {
      final allJoined = activeMembers.length >= circle.totalMembers;
      return embedded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allJoined
                      ? l10n.tontineAllMembersJoined
                      : l10n.tontineCircleStillForming,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.tontineMembersJoined(
                    activeMembers.length,
                    circle.totalMembers,
                  ),
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: circle.totalMembers == 0
                        ? 0
                        : activeMembers.length / circle.totalMembers,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: allJoined
                        ? const Color(0xFF10B981)
                        : const Color(0xFF3B82F6),
                  ),
                ),
                if (canActivate) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await TontineService.activateCircle(circle.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.tontineCircleActivated),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: Text(l10n.tontineActivateCircle),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ],
            )
          : _FormingPanel(
              activeMembers: activeMembers.length,
              totalMembers: circle.totalMembers,
              canActivate: canActivate,
              onActivate: canActivate
                  ? () async {
                      await TontineService.activateCircle(circle.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.tontineCircleActivated)),
                        );
                      }
                    }
                  : null,
            );
    }

    if (circle.status == CircleStatus.completed) {
      return embedded
          ? _EmbeddedMessage(
              icon: Icons.celebration_rounded,
              title: l10n.tontineStatusCompleted,
              message: l10n.tontineCircleCompletedMessage,
            )
          : _InfoPanel(message: l10n.tontineCircleCompletedMessage);
    }

    if (cycle == null) {
      return embedded
          ? _EmbeddedMessage(
              icon: Icons.hourglass_top_rounded,
              title: l10n.tontineCurrentCycle,
              message: l10n.tontineWaitingForCycle,
            )
          : _InfoPanel(message: l10n.tontineWaitingForCycle);
    }

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: CycleCountdown(dueDate: cycle?.dueDate)),
              const SizedBox(width: 12),
              _StatusBadge(
                label: TontineUi.cycleStatusLabel(context, cycle!.status),
                color: TontineUi.cycleStatusColor(cycle!.status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InlineMetric(
            label: l10n.tontineCurrentRecipient,
            value: members
                    .where(
                      (member) => member.userId == cycle!.payoutRecipientUserId,
                    )
                    .firstOrNull
                    ?.displayName ??
                l10n.tontineRecipientPending,
          ),
          const SizedBox(height: 12),
          _InlineMetric(
            label: l10n.tontineDueDate,
            value: DateFormat('MMM d, yyyy')
                .format(cycle!.dueDate ?? DateTime.now()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: primaryAction,
            icon: Icon(primaryActionIcon),
            label: Text(primaryActionLabel),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      );
    }

    return FilledButton.icon(
      onPressed: primaryAction,
      icon: Icon(primaryActionIcon),
      label: Text(primaryActionLabel),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _frequencyLabel(BuildContext context, String frequency) {
    final l10n = AppLocalizations.of(context)!;
    switch (frequency) {
      case 'weekly':
        return l10n.tontineFrequencyWeekly;
      case 'biweekly':
        return l10n.tontineFrequencyBiweekly;
      case 'monthly':
        return l10n.tontineFrequencyMonthly;
      case 'quarterly':
        return l10n.tontineFrequencyQuarterly;
      default:
        return frequency;
    }
  }

  VoidCallback? _resolvePrimaryAction(
    BuildContext context, {
    required bool isHead,
    required CircleCycle cycle,
    required CircleContribution? currentContribution,
  }) {
    if (!isHead &&
        currentContribution?.status == CircleContributionStatus.confirmed) {
      return null;
    }

    if (isHead) {
      return () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ReviewSubmissionsScreen(circle: circle, cycle: cycle),
          ),
        );
      };
    }

    return () {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubmitPaymentScreen(
            circle: circle,
            cycle: cycle,
            existingContribution: currentContribution,
          ),
        ),
      );
    };
  }

  void _showMemberDetails(
    BuildContext context,
    CircleMember member,
    CircleContribution? contribution,
    String currency,
    bool isHead,
    String circleId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final content = Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          _StatusBadge(
            label: TontineUi.contributionStatusLabel(
              context,
              contribution?.status,
              memberStatus: member.status,
            ),
            color: TontineUi.contributionStatusColor(
              contribution?.status,
              memberStatus: member.status,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            label: l10n.tontineExpectedAmount,
            value: contribution == null
                ? '-'
                : TontineUi.formatCurrency(
                    currency, contribution.expectedAmount),
          ),
          _DetailRow(
            label: l10n.tontineSubmittedAmount,
            value: contribution?.submittedAmount == null
                ? '-'
                : TontineUi.formatCurrency(
                    currency,
                    contribution!.submittedAmount!,
                  ),
          ),
          _DetailRow(
            label: l10n.tontineReceiptAttached,
            value: contribution?.receiptImageUrl?.isNotEmpty == true
                ? l10n.commonYes
                : l10n.commonNo,
          ),
          if (contribution?.receiptImageUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.network(
                  contribution!.receiptImageUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          if (contribution?.rejectionReason != null &&
              contribution!.rejectionReason!.isNotEmpty)
            _DetailRow(
              label: l10n.tontineRejectionReason,
              value: contribution.rejectionReason!,
            ),
          if (isHead && member.status == CircleMemberStatus.invited) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () async {
                  try {
                    await TontineService.resendCircleInvite(
                      circleId: circleId,
                      userId: member.userId,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite resent successfully!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to resend invite: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Resend Invite'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (MediaQuery.of(context).size.width >= 900) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: content,
              ),
            ),
          );
        },
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => content,
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroFactCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 248),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFA7F3D0),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _BackgroundOrb({
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final String potValue;
  final String confirmedValue;
  final Widget countdown;

  const _HeroSummaryCard({
    required this.potValue,
    required this.confirmedValue,
    required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.tontineCurrentCycle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          countdown,
          const SizedBox(height: 20),
          _Metric(label: l10n.tontinePotAmount, value: potValue),
          const SizedBox(height: 14),
          _Metric(label: l10n.tontineConfirmedCount, value: confirmedValue),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SurfaceCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _OverviewStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.16),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.1),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _SectionMetricTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InlineMetric({
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
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool dark;

  const _StatusBadge({
    required this.label,
    required this.color,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.white : color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PayoutOrderRow extends StatelessWidget {
  final CircleMember member;
  final bool isRecipient;

  const _PayoutOrderRow({
    required this.member,
    required this.isRecipient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isRecipient ? const Color(0xFFF3F8FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isRecipient ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isRecipient
                  ? const Color(0xFFDBEAFE)
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '${member.payoutPosition}',
              style: TextStyle(
                color: isRecipient
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF475569),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.displayName,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isRecipient)
            const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFF2563EB),
              size: 18,
            ),
        ],
      ),
    );
  }
}

class _EmbeddedMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmbeddedMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1D4ED8)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({
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
            color: Color(0xFFCBD5E1),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FormingPanel extends StatelessWidget {
  final int activeMembers;
  final int totalMembers;
  final VoidCallback? onActivate;
  final bool canActivate;

  const _FormingPanel({
    required this.activeMembers,
    required this.totalMembers,
    required this.onActivate,
    required this.canActivate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allJoined = activeMembers >= totalMembers;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            allJoined
                ? l10n.tontineAllMembersJoined
                : l10n.tontineCircleStillForming,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.tontineMembersJoined(activeMembers, totalMembers),
            style: const TextStyle(
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: totalMembers == 0
                  ? 0
                  : activeMembers / totalMembers,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              color: allJoined
                  ? const Color(0xFF10B981)
                  : const Color(0xFF3B82F6),
            ),
          ),
          if (canActivate) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onActivate,
              child: Text(l10n.tontineActivateCircle),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              l10n.tontineWaitingForMembers,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String message;

  const _InfoPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

class _EditCircleButton extends StatelessWidget {
  final String circleId;
  const _EditCircleButton({required this.circleId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Circle?>(
      stream: TontineService.getCircle(circleId),
      builder: (context, snapshot) {
        final circle = snapshot.data;
        if (circle == null) return const SizedBox();
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (circle.createdBy != currentUserId) return const SizedBox();

        return IconButton(
          icon: const Icon(Icons.edit_rounded),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditCircleScreen(circle: circle),
              ),
            );
          },
        );
      },
    );
  }
}
