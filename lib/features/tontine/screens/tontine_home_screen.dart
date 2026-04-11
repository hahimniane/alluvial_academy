import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/core/services/user_role_service.dart';
import 'package:alluwalacademyadmin/features/tontine/config/tontine_ui.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_cycle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_invite.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/admin_circles_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/circle_dashboard_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/create_admin_circle_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/create_circle_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/join_circle_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/services/eligibility_service.dart';
import 'package:alluwalacademyadmin/features/tontine/services/tontine_service.dart';
import 'package:alluwalacademyadmin/features/tontine/widgets/circle_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class TontineHomeScreen extends StatefulWidget {
  const TontineHomeScreen({super.key});

  @override
  State<TontineHomeScreen> createState() => _TontineHomeScreenState();
}

class _TontineHomeScreenState extends State<TontineHomeScreen> {
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await UserRoleService.getPrimaryRole();
    if (mounted) setState(() => _userRole = role);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Center(
        child: Text(
          l10n.tontineSignInRequired,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      );
    }

    final isTeacher = _userRole == 'teacher';
    final isAdmin = _userRole == 'admin' || _userRole == 'super_admin';

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: StreamBuilder<List<CircleInvite>>(
          stream: TontineService.getPendingInvitesForUser(currentUser.uid),
          builder: (context, invitesSnapshot) {
            return StreamBuilder<List<Circle>>(
              stream: TontineService.getUserCircles(currentUser.uid),
              builder: (context, circlesSnapshot) {
                final invites = invitesSnapshot.data ?? const <CircleInvite>[];
                final circles = circlesSnapshot.data ?? const <Circle>[];

                if (circlesSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !circlesSnapshot.hasData &&
                    invitesSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !invitesSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _Header(
                      title: l10n.tontineSavings,
                      subtitle: l10n.tontineHomeSubtitle,
                      onCreatePressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CreateCircleScreen(),
                          ),
                        );
                      },
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 16),
                      _AdminQuickActions(),
                    ],
                    if (invites.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _PendingInviteBanner(invites: invites),
                    ],
                    if (isTeacher) ...[
                      const SizedBox(height: 20),
                      _AvailableCirclesSection(userId: currentUser.uid),
                    ],
                    const SizedBox(height: 20),
                    if (circles.isEmpty)
                      _EmptyState(
                        title: l10n.tontineNoCirclesTitle,
                        subtitle: l10n.tontineNoCirclesSubtitle,
                        ctaLabel: l10n.tontineCreateCircle,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CreateCircleScreen(),
                            ),
                          );
                        },
                      )
                    else ...[
                      ..._buildCircleSection(
                        context,
                        title: l10n.tontineCirclesCreated,
                        circles: circles
                            .where((c) => c.createdBy == currentUser.uid)
                            .toList(),
                        isCreator: true,
                      ),
                      ..._buildCircleSection(
                        context,
                        title: l10n.tontineCirclesJoined,
                        circles: circles
                            .where((c) => c.createdBy != currentUser.uid)
                            .toList(),
                        isCreator: false,
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCircleSection(
    BuildContext context, {
    required String title,
    required List<Circle> circles,
    required bool isCreator,
  }) {
    if (circles.isEmpty) return [];
    return [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF475569),
        ),
      ),
      const SizedBox(height: 12),
      ...circles.map(
        (circle) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: StreamBuilder<CircleCycle?>(
            stream: TontineService.getCurrentCycle(circle.id),
            builder: (context, cycleSnapshot) {
              return CircleCard(
                circle: circle,
                currentCycle: cycleSnapshot.data,
                isCreator: isCreator,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CircleDashboardScreen(circleId: circle.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 8),
    ];
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onCreatePressed;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: AppLocalizations.of(context)!.tontineTooltipDescription,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                showDuration: const Duration(seconds: 4),
                triggerMode: TooltipTriggerMode.tap,
                textStyle: const TextStyle(color: Colors.white, fontSize: 14),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white70,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFF0FDF4),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreatePressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: Text(
              AppLocalizations.of(context)!.tontineCreateCircle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminQuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded,
                  size: 18, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              const Text(
                'Admin Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminCirclesScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt_rounded, size: 16),
                label: const Text('View All',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AdminActionButton(
                  icon: Icons.school_rounded,
                  label: 'Teacher Circle',
                  color: const Color(0xFF0F766E),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateAdminCircleScreen(
                            circleType: CircleType.teacher),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdminActionButton(
                  icon: Icons.family_restroom_rounded,
                  label: 'Parent Circle',
                  color: const Color(0xFF0E7490),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateAdminCircleScreen(
                            circleType: CircleType.parent),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingInviteBanner extends StatelessWidget {
  final List<CircleInvite> invites;

  const _PendingInviteBanner({required this.invites});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread_rounded,
                  color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.tontinePendingInvites(invites.length),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...invites.take(3).map(
                (invite) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      invite.circleName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(invite.contactInfo),
                    trailing: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => JoinCircleScreen(invite: invite),
                          ),
                        );
                      },
                      child: Text(l10n.tontineReviewInvite),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onPressed;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Color(0xFF15803D),
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}

class _AvailableCirclesSection extends StatelessWidget {
  final String userId;

  const _AvailableCirclesSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<List<Circle>>(
      stream: TontineService.getOpenCirclesForTeachers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final circles = snapshot.data ?? [];
        if (circles.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.explore_rounded,
                    size: 20, color: Color(0xFF0F766E)),
                const SizedBox(width: 8),
                Text(
                  l10n.tontineAvailableCircles,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...circles.map(
              (circle) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _OpenCircleCard(circle: circle, userId: userId),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OpenCircleCard extends StatefulWidget {
  final Circle circle;
  final String userId;

  const _OpenCircleCard({required this.circle, required this.userId});

  @override
  State<_OpenCircleCard> createState() => _OpenCircleCardState();
}

class _OpenCircleCardState extends State<_OpenCircleCard> {
  EligibilityResult? _eligibility;
  bool _loading = true;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    final rules = widget.circle.eligibilityRules;
    if (rules == null) {
      setState(() {
        _eligibility = const EligibilityResult(isEligible: true);
        _loading = false;
      });
      return;
    }

    final result = await EligibilityService.checkEligibility(
      userId: widget.userId,
      rules: rules,
      contributionAmount: widget.circle.contributionAmount,
    );
    if (mounted) {
      setState(() {
        _eligibility = result;
        _loading = false;
      });
    }
  }

  Future<void> _joinCircle() async {
    setState(() => _joining = true);
    try {
      await TontineService.joinOpenCircle(widget.circle.id);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tontineJoinSuccess)),
        );
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CircleDashboardScreen(circleId: widget.circle.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final circle = widget.circle;
    final eligible = _eligibility?.isEligible ?? false;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: eligible
              ? const Color(0xFF0F766E).withOpacity(0.25)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
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
                child: Text(
                  circle.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: eligible
                        ? const Color(0xFF10B981).withOpacity(0.12)
                        : const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    eligible
                        ? l10n.tontineEligible
                        : l10n.tontineNotEligible,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: eligible
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniInfo(
                label: l10n.tontineMonthlyContribution,
                value: TontineUi.formatCurrency(
                    circle.currency, circle.contributionAmount),
              ),
              const SizedBox(width: 24),
              if (circle.maxMembers != null)
                _MiniInfo(
                  label: l10n.tontineOpenSpots,
                  value: circle.maxMembers! - circle.totalMembers > 0
                      ? l10n.tontineSpotsLeft(
                          circle.maxMembers! - circle.totalMembers)
                      : l10n.tontineCircleFull,
                )
              else
                _MiniInfo(
                  label: l10n.tontineOpenSpots,
                  value: l10n.tontineUnlimited,
                ),
            ],
          ),
          if (circle.eligibilityRules != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (circle.eligibilityRules!.incomeMultiplier > 0)
                  _RuleChip(
                    label: l10n.tontineIncomeRequirement(
                      circle.eligibilityRules!.incomeMultiplier
                          .toStringAsFixed(1),
                    ),
                  ),
                if (circle.eligibilityRules!.minTenureMonths > 0)
                  _RuleChip(
                    label: l10n.tontineTenureRequirement(
                        circle.eligibilityRules!.minTenureMonths),
                  ),
                if (circle.eligibilityRules!.minShiftsLast30Days > 0)
                  _RuleChip(
                    label: l10n.tontineShiftsRequirement(
                        circle.eligibilityRules!.minShiftsLast30Days),
                  ),
              ],
            ),
          ],
          if (!_loading && !eligible && _eligibility != null) ...[
            const SizedBox(height: 10),
            ...(_eligibility!.failedReasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.close_rounded,
                        size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  !_loading && eligible && !_joining ? _joinCircle : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.group_add_rounded),
              label: Text(
                l10n.tontineJoinCircle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;

  const _RuleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}
