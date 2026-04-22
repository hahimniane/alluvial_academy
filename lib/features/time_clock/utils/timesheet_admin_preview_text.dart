import 'package:intl/intl.dart';

import '../../../core/enums/timesheet_enums.dart';
import '../../../l10n/app_localizations.dart';
import '../models/timesheet_entry.dart';
import 'timesheet_entry_review_flags.dart';

/// Multi-line tooltip text for admin timesheet grid hover.
class TimesheetAdminPreviewText {
  const TimesheetAdminPreviewText._();

  static String build(TimesheetEntry e, AppLocalizations l10n) {
    final buf = StringBuffer();

    buf.writeln('${e.teacherName} · ${e.subject}');
    buf.writeln(e.date);
    if (e.shiftTitle != null && e.shiftTitle!.trim().isNotEmpty) {
      buf.writeln('${l10n.shiftDetails}: ${e.shiftTitle}');
    }
    if (e.shiftId != null && e.shiftId!.trim().isNotEmpty) {
      buf.writeln('ID: ${e.shiftId}');
    }
    buf.writeln('${l10n.timesheetClockInTime}: ${e.start}');
    buf.writeln('${l10n.timesheetClockOutTime}: ${e.end}');
    buf.writeln(l10n.timesheetTotalHours(e.totalHours));

    if (e.scheduledStart != null || e.scheduledEnd != null) {
      final a = e.scheduledStart != null
          ? DateFormat('h:mm a').format(e.scheduledStart!)
          : '—';
      final b = e.scheduledEnd != null
          ? DateFormat('h:mm a').format(e.scheduledEnd!)
          : '—';
      buf.writeln('${l10n.shiftScheduled}: $a — $b');
    }
    if (e.scheduledDurationMinutes != null &&
        e.scheduledDurationMinutes! > 0) {
      final h = e.scheduledDurationMinutes! / 60.0;
      buf.writeln('${l10n.shiftDuration}: ${h.toStringAsFixed(2)} ${l10n.shiftHours}');
    }

    buf.writeln('${l10n.timesheetStatus}: ${_statusLabel(e.status, l10n)}');
    buf.writeln(
        '${l10n.source}: ${e.source ?? 'manual'} · ${l10n.formCompleted}: ${e.formCompleted ? l10n.commonYes : l10n.commonNo}');
    if (e.reportedHours != null) {
      buf.writeln('${l10n.timesheetPaymentCalculation}: ${e.reportedHours} h');
    }
    if (e.isEdited) {
      buf.writeln(
          '${l10n.timesheetWasEdited} (${e.editApproved ? l10n.timesheetApproved : l10n.timesheetPending})');
    }
    if (e.employeeNotes != null && e.employeeNotes!.trim().isNotEmpty) {
      buf.writeln('${l10n.employeeNotes}: ${e.employeeNotes}');
    }
    if (e.managerNotes != null && e.managerNotes!.trim().isNotEmpty) {
      buf.writeln('${l10n.managerNotes}: ${e.managerNotes}');
    }
    if (TimesheetEntryReviewFlags.needsAttention(e)) {
      buf.writeln('• ${l10n.timesheetReviewNeedsAttention}');
    }
    if (!TimesheetEntryReviewFlags.isTimesheetComplete(e)) {
      buf.writeln('• ${l10n.timesheetReviewIncompleteEntry}');
    }

    return buf.toString().trimRight();
  }

  static String _statusLabel(TimesheetStatus s, AppLocalizations l10n) {
    switch (s) {
      case TimesheetStatus.approved:
        return l10n.timesheetApproved;
      case TimesheetStatus.rejected:
        return l10n.timesheetRejected;
      case TimesheetStatus.pending:
        return l10n.timesheetPending;
      case TimesheetStatus.draft:
        return l10n.timesheetDraft;
    }
  }
}
