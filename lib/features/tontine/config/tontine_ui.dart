import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/tontine/models/circle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_contribution.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_cycle.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_invite.dart';
import 'package:alluwalacademyadmin/features/tontine/models/circle_member.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class TontineUi {
  static String formatCurrency(String currency, double amount) {
    final hasDecimals = amount != amount.roundToDouble();
    if (currency.toUpperCase() == 'USD') {
      return NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: hasDecimals ? 2 : 0,
      ).format(amount);
    }

    return NumberFormat.currency(
      symbol: '$currency ',
      decimalDigits: hasDecimals ? 2 : 0,
    ).format(amount);
  }

  static Color circleStatusColor(CircleStatus status) {
    switch (status) {
      case CircleStatus.forming:
        return const Color(0xFFF59E0B);
      case CircleStatus.active:
        return const Color(0xFF10B981);
      case CircleStatus.completed:
        return const Color(0xFF2563EB);
      case CircleStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  static Color contributionStatusColor(
    CircleContributionStatus? status, {
    required CircleMemberStatus memberStatus,
  }) {
    if (memberStatus == CircleMemberStatus.invited) {
      return const Color(0xFF94A3B8);
    }

    switch (status) {
      case CircleContributionStatus.confirmed:
        return const Color(0xFF10B981);
      case CircleContributionStatus.submitted:
        return const Color(0xFFF59E0B);
      case CircleContributionStatus.rejected:
      case CircleContributionStatus.missed:
        return const Color(0xFFEF4444);
      case CircleContributionStatus.pending:
      case null:
        return const Color(0xFFDC2626);
    }
  }

  static Color cycleStatusColor(CircleCycleStatus status) {
    switch (status) {
      case CircleCycleStatus.pending:
        return const Color(0xFFF59E0B);
      case CircleCycleStatus.inProgress:
        return const Color(0xFF0E72ED);
      case CircleCycleStatus.completed:
        return const Color(0xFF10B981);
    }
  }

  static String circleStatusLabel(BuildContext context, CircleStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case CircleStatus.forming:
        return l10n.tontineStatusForming;
      case CircleStatus.active:
        return l10n.tontineStatusActive;
      case CircleStatus.completed:
        return l10n.tontineStatusCompleted;
      case CircleStatus.cancelled:
        return l10n.tontineStatusCancelled;
    }
  }

  static String cycleStatusLabel(
      BuildContext context, CircleCycleStatus status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case CircleCycleStatus.pending:
        return l10n.tontineCyclePending;
      case CircleCycleStatus.inProgress:
        return l10n.tontineCycleInProgress;
      case CircleCycleStatus.completed:
        return l10n.tontineCycleCompleted;
    }
  }

  static String contributionStatusLabel(
    BuildContext context,
    CircleContributionStatus? status, {
    required CircleMemberStatus memberStatus,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (memberStatus == CircleMemberStatus.invited) {
      return l10n.tontineMemberInvited;
    }

    switch (status) {
      case CircleContributionStatus.confirmed:
        return l10n.tontineContributionConfirmed;
      case CircleContributionStatus.submitted:
        return l10n.tontineContributionSubmitted;
      case CircleContributionStatus.rejected:
        return l10n.tontineContributionRejected;
      case CircleContributionStatus.missed:
        return l10n.tontineContributionMissed;
      case CircleContributionStatus.pending:
      case null:
        return l10n.tontineContributionPending;
    }
  }

  static String missedPaymentActionLabel(
    BuildContext context,
    CircleMissedPaymentAction action,
  ) {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case CircleMissedPaymentAction.moveToBack:
        return l10n.tontineMissedMoveToBack;
      case CircleMissedPaymentAction.suspend:
        return l10n.tontineMissedSuspend;
    }
  }

  static String inviteMethodLabel(
      BuildContext context, CircleInviteMethod method) {
    final l10n = AppLocalizations.of(context)!;
    switch (method) {
      case CircleInviteMethod.phone:
        return l10n.tontineInviteByPhone;
      case CircleInviteMethod.email:
        return l10n.tontineInviteByEmail;
    }
  }

  static String initialsForName(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
