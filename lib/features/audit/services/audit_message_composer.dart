import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';
import 'package:alluwalacademyadmin/features/audit/services/audit_class_log_row_builder.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

enum AuditMessageChannel {
  chatShort,
  fcmShort,
  chatDraft,
  shareLink,
}

class AuditMessageComposer {
  const AuditMessageComposer._();

  static String compose({
    required TeacherAuditFull audit,
    required AppLocalizations l10n,
    required AuditMessageChannel channel,
  }) {
    switch (channel) {
      case AuditMessageChannel.chatShort:
      case AuditMessageChannel.fcmShort:
        return notificationBody(
              l10n: l10n,
              yearMonth: audit.yearMonth,
              status: audit.status,
            ) ??
            '';
      case AuditMessageChannel.chatDraft:
      case AuditMessageChannel.shareLink:
        return _detailedAuditBody(audit, l10n);
    }
  }

  static String? notificationBody({
    required AppLocalizations l10n,
    required String yearMonth,
    required AuditStatus status,
  }) {
    final body = switch (status) {
      AuditStatus.coachSubmitted => l10n.auditMessageReadyInMyReport,
      AuditStatus.ceoApproved => l10n.auditMessagePassedCeoReview,
      AuditStatus.completed => l10n.auditMessageFinalized,
      _ => null,
    };
    if (body == null) return null;
    return '${l10n.auditMessageTitle} - $yearMonth\n$body';
  }

  static String _detailedAuditBody(
    TeacherAuditFull audit,
    AppLocalizations l10n,
  ) {
    final paymentSummary = audit.paymentSummary;
    final rows = AuditClassLogRowBuilder.buildRows(audit);
    final totals = AuditClassLogRowBuilder.computeTotalsFromRows(rows);
    final timesheetHours = totals.totalWorkedFromTs;
    final formHours = totals.totalFormHours;
    final totalHours = timesheetHours + formHours;
    final payFromTimesheet = totals.payFromTs;
    final payFromForms = totals.payFromForm;
    final grossBySource = totals.grossBySource;
    final rateBreakdown = _rateBreakdown(
      totals.rateHoursByRate,
      totalHours,
      l10n,
    );

    final lines = <String>[
      '${l10n.auditDiscussionAdminButton} - ${audit.yearMonth}',
      '',
      '${l10n.auditMessageTeacher}: ${audit.teacherName}',
      '',
      '${l10n.auditMessagePaymentSummary}:',
      '1) ${l10n.auditMessageHoursSection}:',
      '- ${l10n.auditMessageWorkedHours}: ${timesheetHours.toStringAsFixed(2)}h',
      '- ${l10n.auditMessageFormHours}: ${formHours.toStringAsFixed(2)}h',
      '- ${l10n.auditMessageTotalHours}: ${totalHours.toStringAsFixed(2)}h',
      '2) ${l10n.auditMessageHourlyRateBreakdown}:',
      '- $rateBreakdown',
    ];

    if (paymentSummary == null) {
      lines.addAll([
        '3) ${l10n.auditMessageGrossAmount}: ${l10n.auditMessageNotAvailable}',
        '4) ${l10n.auditMessageAdjustments}: ${l10n.auditMessageNotAvailable}',
        '5) ${l10n.auditMessageAdvanceDeduction}: ${l10n.auditMessageNotAvailable}',
        '6) ${l10n.auditMessageFinalAmount}: ${l10n.auditMessageNotAvailable}',
        '',
        l10n.auditMessageReviewReply,
      ]);
      return lines.join('\n');
    }

    final coachDelta = paymentSummary.coachAdjustmentLines.fold<double>(
      0.0,
      (total, line) =>
          total + (line.type == 'bonus' ? line.amount : -line.amount),
    );
    final adjustmentImpact = paymentSummary.totalBonuses -
        paymentSummary.totalPenalties +
        paymentSummary.adminAdjustment +
        coachDelta;
    final finalAmount = grossBySource -
        paymentSummary.totalPenalties +
        paymentSummary.totalBonuses +
        paymentSummary.adminAdjustment +
        coachDelta -
        paymentSummary.totalAdvanceDeduction;

    lines.addAll([
      '3) ${l10n.auditMessageGrossAmount}: \$${grossBySource.toStringAsFixed(2)}',
      '- ${l10n.auditMessagePayFromTimesheets}: \$${payFromTimesheet.toStringAsFixed(2)}',
      '- ${l10n.auditMessagePayFromForms}: \$${payFromForms.toStringAsFixed(2)}',
      '4) ${l10n.auditMessageAdjustments}:',
      '- ${l10n.auditMessageAutoPenalties}: -\$${paymentSummary.totalPenalties.toStringAsFixed(2)}',
      '- ${l10n.auditMessageAutoBonuses}: +\$${paymentSummary.totalBonuses.toStringAsFixed(2)}',
      '- ${l10n.auditMessageAdminAdjustment}: ${_signedMoney(paymentSummary.adminAdjustment)}',
    ]);

    if (paymentSummary.coachAdjustmentLines.isNotEmpty) {
      lines.add('- ${l10n.auditMessageCoachLines}:');
      for (final line in paymentSummary.coachAdjustmentLines) {
        final amount = line.type == 'bonus' ? line.amount : -line.amount;
        lines.add('  - ${_signedMoney(amount)} (${line.reason})');
      }
    }

    lines.addAll([
      '- ${l10n.auditMessageTotalAdjustmentsImpact}: ${_signedMoney(adjustmentImpact)}',
      '5) ${l10n.auditMessageAdvanceDeduction}: -\$${paymentSummary.totalAdvanceDeduction.toStringAsFixed(2)}',
      '6) ${l10n.auditMessageFinalAmount}: \$${finalAmount.toStringAsFixed(2)}',
      '',
      l10n.auditMessageReviewReply,
    ]);
    return lines.join('\n');
  }

  static String _rateBreakdown(
    Map<double, double> rateBuckets,
    double totalHours,
    AppLocalizations l10n,
  ) {
    if (rateBuckets.isEmpty) return l10n.auditMessageNotAvailable;
    if (rateBuckets.length == 1) {
      final rate = rateBuckets.keys.first;
      return '${totalHours.toStringAsFixed(2)}h x \$${rate.toStringAsFixed(2)}/hr';
    }
    return rateBuckets.entries
        .map(
          (entry) =>
              '${entry.value.toStringAsFixed(2)}h x \$${entry.key.toStringAsFixed(2)}/hr',
        )
        .join(' + ');
  }

  static String _signedMoney(double value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign\$${value.abs().toStringAsFixed(2)}';
  }
}
