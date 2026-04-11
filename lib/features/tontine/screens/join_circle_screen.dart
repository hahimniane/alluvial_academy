import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/features/tontine/config/tontine_ui.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_invite.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_member.dart';
import 'package:alluwalacademyadmin/features/tontine/screens/circle_dashboard_screen.dart';
import 'package:alluwalacademyadmin/features/tontine/services/tontine_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class JoinCircleScreen extends StatefulWidget {
  final CircleInvite invite;

  const JoinCircleScreen({
    super.key,
    required this.invite,
  });

  @override
  State<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends State<JoinCircleScreen> {
  bool _isJoining = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l10n.tontineJoinCircle,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: FutureBuilder<Circle?>(
        future: TontineService.getCircleById(widget.invite.circleId),
        builder: (context, circleSnapshot) {
          if (circleSnapshot.connectionState == ConnectionState.waiting) {
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
              final members = membersSnapshot.data ?? const <CircleMember>[];
              final head =
                  members.where((member) => member.isTontineHead).firstOrNull;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
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
                        Text(
                          circle.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.tontineInvitePreview,
                          style: const TextStyle(
                            color: Color(0xFFF0FDF4),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _JoinRow(
                    label: l10n.tontineContributionAmount,
                    value: TontineUi.formatCurrency(
                      circle.currency,
                      circle.contributionAmount,
                    ),
                  ),
                  _JoinRow(
                    label: l10n.tontineFrequency,
                    value: _frequencyLabel(context, circle.frequency),
                  ),
                  _JoinRow(
                    label: l10n.tontineMemberCount,
                    value: '${circle.totalMembers}',
                  ),
                  _JoinRow(
                    label: l10n.tontineCircleHead,
                    value: head?.displayName ?? l10n.commonUnknown,
                  ),
                  _JoinRow(
                    label: l10n.tontineStartDate,
                    value: circle.startDate == null
                        ? l10n.commonNotSet
                        : MaterialLocalizations.of(context)
                            .formatMediumDate(circle.startDate!),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isJoining ? null : _joinCircle,
                    icon: _isJoining
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      _isJoining ? l10n.commonLoading : l10n.tontineJoinCircle,
                    ),
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

  Future<void> _joinCircle() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isJoining = true;
    });

    try {
      await TontineService.acceptInvite(widget.invite.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              CircleDashboardScreen(circleId: widget.invite.circleId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tontineJoinFailed(error.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }
}

class _JoinRow extends StatelessWidget {
  final String label;
  final String value;

  const _JoinRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
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
