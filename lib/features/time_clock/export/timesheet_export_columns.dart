import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../enums/timesheet_enums.dart';
import '../../../l10n/app_localizations.dart';
import '../models/timesheet_entry.dart';
import '../services/timesheet_payment_service.dart';
import 'timesheet_export_column_preset.dart';

/// Single export column (machine key → label + cell value).
enum TimesheetExportColumn {
  entryId,
  teacherName,
  dateIso,
  /// Same string as the grid “Date” column (`entry.date`).
  dateAsShownInTable,
  dayName,
  weekStartingIso,
  monthLabel,
  subject,
  scheduledStart,
  scheduledEnd,
  clockIn,
  clockOut,
  scheduledHours,
  workedHours,
  /// Same value as the grid “Hours” column (`total_hours` / display string).
  hoursAsShownInTable,
  hoursDifference,
  hourlyRate,
  totalPay,
  status,
  formCompleted,
  employeeNotes,
  managerNotes,
  shiftId,
  shiftTitle,
  shiftType,
  source,
  clockInPlatform,
  clockOutPlatform,
  reportedHours,
  formNotes,
  formResponseId,
  isEdited,
  editApproved,
  editedAt,
  rejectionReason,
  clockInAddress,
  clockOutAddress,
}

class TimesheetExportColumns {
  const TimesheetExportColumns._();

  /// Matches the on-screen admin grid (exactly seven columns).
  static const List<TimesheetExportColumn> screen = [
    TimesheetExportColumn.teacherName,
    TimesheetExportColumn.dateIso,
    TimesheetExportColumn.subject,
    TimesheetExportColumn.hoursAsShownInTable,
    TimesheetExportColumn.totalPay,
    TimesheetExportColumn.source,
    TimesheetExportColumn.status,
  ];

  static const List<TimesheetExportColumn> payroll = [
    TimesheetExportColumn.entryId,
    TimesheetExportColumn.teacherName,
    TimesheetExportColumn.dateIso,
    TimesheetExportColumn.clockIn,
    TimesheetExportColumn.clockOut,
    TimesheetExportColumn.workedHours,
    TimesheetExportColumn.hourlyRate,
    TimesheetExportColumn.totalPay,
    TimesheetExportColumn.status,
  ];

  static const List<TimesheetExportColumn> operations = [
    TimesheetExportColumn.teacherName,
    TimesheetExportColumn.dateIso,
    TimesheetExportColumn.shiftId,
    TimesheetExportColumn.shiftTitle,
    TimesheetExportColumn.shiftType,
    TimesheetExportColumn.subject,
    TimesheetExportColumn.scheduledStart,
    TimesheetExportColumn.scheduledEnd,
    TimesheetExportColumn.scheduledHours,
    TimesheetExportColumn.workedHours,
    TimesheetExportColumn.hoursDifference,
    TimesheetExportColumn.clockIn,
    TimesheetExportColumn.clockOut,
    TimesheetExportColumn.source,
  ];

  static const List<TimesheetExportColumn> audit = [
    TimesheetExportColumn.entryId,
    TimesheetExportColumn.teacherName,
    TimesheetExportColumn.dateIso,
    TimesheetExportColumn.shiftId,
    TimesheetExportColumn.shiftTitle,
    TimesheetExportColumn.subject,
    TimesheetExportColumn.clockIn,
    TimesheetExportColumn.clockOut,
    TimesheetExportColumn.workedHours,
    TimesheetExportColumn.hourlyRate,
    TimesheetExportColumn.totalPay,
    TimesheetExportColumn.status,
    TimesheetExportColumn.formCompleted,
    TimesheetExportColumn.reportedHours,
    TimesheetExportColumn.formNotes,
    TimesheetExportColumn.formResponseId,
    TimesheetExportColumn.isEdited,
    TimesheetExportColumn.editApproved,
    TimesheetExportColumn.editedAt,
    TimesheetExportColumn.rejectionReason,
    TimesheetExportColumn.clockInPlatform,
    TimesheetExportColumn.clockOutPlatform,
    TimesheetExportColumn.employeeNotes,
    TimesheetExportColumn.managerNotes,
  ];

  static const List<TimesheetExportColumn> full = TimesheetExportColumn.values;

  static List<TimesheetExportColumn> forPreset(TimesheetExportColumnPreset p) {
    switch (p) {
      case TimesheetExportColumnPreset.screen:
        return screen;
      case TimesheetExportColumnPreset.payroll:
        return payroll;
      case TimesheetExportColumnPreset.operations:
        return operations;
      case TimesheetExportColumnPreset.audit:
        return audit;
      case TimesheetExportColumnPreset.full:
        return full;
    }
  }

  static String header(TimesheetExportColumn c, AppLocalizations l10n) {
    switch (c) {
      case TimesheetExportColumn.entryId:
        return l10n.timesheetExportColEntryId;
      case TimesheetExportColumn.teacherName:
        return l10n.timesheetExportColTeacherName;
      case TimesheetExportColumn.dateIso:
        return l10n.timesheetExportColDate;
      case TimesheetExportColumn.dateAsShownInTable:
        return l10n.timesheetDate;
      case TimesheetExportColumn.dayName:
        return l10n.timesheetExportColDay;
      case TimesheetExportColumn.weekStartingIso:
        return l10n.timesheetExportColWeekStarting;
      case TimesheetExportColumn.monthLabel:
        return l10n.timesheetExportColMonth;
      case TimesheetExportColumn.subject:
        return l10n.timesheetExportColStudentSubject;
      case TimesheetExportColumn.scheduledStart:
        return l10n.timesheetExportColScheduledStart;
      case TimesheetExportColumn.scheduledEnd:
        return l10n.timesheetExportColScheduledEnd;
      case TimesheetExportColumn.clockIn:
        return l10n.timesheetExportColClockIn;
      case TimesheetExportColumn.clockOut:
        return l10n.timesheetExportColClockOut;
      case TimesheetExportColumn.scheduledHours:
        return l10n.timesheetExportColScheduledHours;
      case TimesheetExportColumn.workedHours:
        return l10n.timesheetExportColWorkedHours;
      case TimesheetExportColumn.hoursAsShownInTable:
        return l10n.hours;
      case TimesheetExportColumn.hoursDifference:
        return l10n.timesheetExportColHoursDifference;
      case TimesheetExportColumn.hourlyRate:
        return l10n.timesheetExportColHourlyRate;
      case TimesheetExportColumn.totalPay:
        return l10n.timesheetExportColTotalPay;
      case TimesheetExportColumn.status:
        return l10n.timesheetExportColStatus;
      case TimesheetExportColumn.formCompleted:
        return l10n.timesheetExportColFormCompleted;
      case TimesheetExportColumn.employeeNotes:
        return l10n.timesheetExportColEmployeeNotes;
      case TimesheetExportColumn.managerNotes:
        return l10n.timesheetExportColManagerNotes;
      case TimesheetExportColumn.shiftId:
        return l10n.timesheetExportColShiftId;
      case TimesheetExportColumn.shiftTitle:
        return l10n.timesheetExportColShiftTitle;
      case TimesheetExportColumn.shiftType:
        return l10n.timesheetExportColShiftType;
      case TimesheetExportColumn.source:
        return l10n.timesheetExportColSource;
      case TimesheetExportColumn.clockInPlatform:
        return l10n.timesheetExportColClockInDevice;
      case TimesheetExportColumn.clockOutPlatform:
        return l10n.timesheetExportColClockOutDevice;
      case TimesheetExportColumn.reportedHours:
        return l10n.timesheetExportColReportedHours;
      case TimesheetExportColumn.formNotes:
        return l10n.timesheetExportColFormNotes;
      case TimesheetExportColumn.formResponseId:
        return l10n.timesheetExportColFormResponseId;
      case TimesheetExportColumn.isEdited:
        return l10n.timesheetExportColIsEdited;
      case TimesheetExportColumn.editApproved:
        return l10n.timesheetExportColEditApproved;
      case TimesheetExportColumn.editedAt:
        return l10n.timesheetExportColEditedAt;
      case TimesheetExportColumn.rejectionReason:
        return l10n.timesheetExportColRejectionReason;
      case TimesheetExportColumn.clockInAddress:
        return l10n.timesheetExportColClockInAddress;
      case TimesheetExportColumn.clockOutAddress:
        return l10n.timesheetExportColClockOutAddress;
    }
  }

  static List<String> headersFor(
    List<TimesheetExportColumn> cols,
    AppLocalizations l10n,
  ) =>
      cols.map((c) => header(c, l10n)).toList();

  static dynamic cellValue({
    required TimesheetExportColumn c,
    required TimesheetEntry entry,
    required DateTime parsedDate,
    required double workedHours,
    required double scheduledHours,
    required double pay,
    required String scheduledIn,
    required String scheduledOut,
    required double difference,
    required AppLocalizations l10n,
  }) {
    final dateKey = DateFormat('yyyy-MM-dd').format(parsedDate);
    final weekStart =
        parsedDate.subtract(Duration(days: parsedDate.weekday - 1));
    final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);
    final monthStart = DateTime(parsedDate.year, parsedDate.month, 1);

    switch (c) {
      case TimesheetExportColumn.entryId:
        return entry.documentId ?? '';
      case TimesheetExportColumn.teacherName:
        return entry.teacherName;
      case TimesheetExportColumn.dateIso:
        return dateKey;
      case TimesheetExportColumn.dateAsShownInTable:
        return entry.date;
      case TimesheetExportColumn.dayName:
        return DateFormat('EEEE').format(parsedDate);
      case TimesheetExportColumn.weekStartingIso:
        return weekKey;
      case TimesheetExportColumn.monthLabel:
        return DateFormat('MMMM yyyy').format(monthStart);
      case TimesheetExportColumn.subject:
        return entry.subject;
      case TimesheetExportColumn.scheduledStart:
        return scheduledIn;
      case TimesheetExportColumn.scheduledEnd:
        return scheduledOut;
      case TimesheetExportColumn.clockIn:
        return entry.start;
      case TimesheetExportColumn.clockOut:
        return entry.end;
      case TimesheetExportColumn.scheduledHours:
        return scheduledHours > 0 ? scheduledHours.toStringAsFixed(2) : '--';
      case TimesheetExportColumn.workedHours:
        return workedHours.toStringAsFixed(2);
      case TimesheetExportColumn.hoursAsShownInTable:
        return entry.totalHours;
      case TimesheetExportColumn.hoursDifference:
        return scheduledHours > 0 ? difference.toStringAsFixed(2) : '--';
      case TimesheetExportColumn.hourlyRate:
        return entry.hourlyRate.toStringAsFixed(2);
      case TimesheetExportColumn.totalPay:
        return pay.toStringAsFixed(2);
      case TimesheetExportColumn.status:
        return _statusLabel(entry.status, l10n);
      case TimesheetExportColumn.formCompleted:
        return entry.formCompleted ? l10n.commonYes : l10n.commonNo;
      case TimesheetExportColumn.employeeNotes:
        return entry.employeeNotes ?? '';
      case TimesheetExportColumn.managerNotes:
        return entry.managerNotes ?? '';
      case TimesheetExportColumn.shiftId:
        return entry.shiftId ?? '';
      case TimesheetExportColumn.shiftTitle:
        return entry.shiftTitle ?? '';
      case TimesheetExportColumn.shiftType:
        return entry.shiftType ?? '';
      case TimesheetExportColumn.source:
        return entry.source ?? 'manual';
      case TimesheetExportColumn.clockInPlatform:
        return entry.clockInPlatform ?? '';
      case TimesheetExportColumn.clockOutPlatform:
        return entry.clockOutPlatform ?? '';
      case TimesheetExportColumn.reportedHours:
        return entry.reportedHours?.toString() ?? '';
      case TimesheetExportColumn.formNotes:
        return entry.formNotes ?? '';
      case TimesheetExportColumn.formResponseId:
        return entry.formResponseId ?? '';
      case TimesheetExportColumn.isEdited:
        return entry.isEdited ? l10n.commonYes : l10n.commonNo;
      case TimesheetExportColumn.editApproved:
        return entry.editApproved ? l10n.commonYes : l10n.commonNo;
      case TimesheetExportColumn.editedAt:
        return _ts(entry.editedAt);
      case TimesheetExportColumn.rejectionReason:
        return entry.rejectionReason ?? '';
      case TimesheetExportColumn.clockInAddress:
        return entry.clockInAddress ?? '';
      case TimesheetExportColumn.clockOutAddress:
        return entry.clockOutAddress ?? '';
    }
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

  static String _ts(Timestamp? t) {
    if (t == null) return '';
    final d = t.toDate();
    return DateFormat('yyyy-MM-dd HH:mm').format(d);
  }

  /// Per-entry computed schedule / pay reused by detail rows and aggregates.
  static TimesheetEntryExportMetrics metrics(
    TimesheetEntry entry,
    DateTime parsedDate,
  ) {
    final workedHours =
        TimesheetPaymentService.parseHoursToDecimal(entry.totalHours);
    final pay = TimesheetPaymentService.calculatePayment(entry);

    double scheduledHours = 0;
    var scheduledIn = '--';
    var scheduledOut = '--';

    if (entry.scheduledDurationMinutes != null &&
        entry.scheduledDurationMinutes! > 0) {
      scheduledHours = entry.scheduledDurationMinutes! / 60.0;
    } else if (entry.scheduledStart != null && entry.scheduledEnd != null) {
      final duration =
          entry.scheduledEnd!.difference(entry.scheduledStart!);
      scheduledHours = duration.inMinutes / 60.0;
    }

    if (entry.scheduledStart != null) {
      scheduledIn = DateFormat('h:mm a').format(entry.scheduledStart!);
    }
    if (entry.scheduledEnd != null) {
      scheduledOut = DateFormat('h:mm a').format(entry.scheduledEnd!);
    }

    final difference = workedHours - scheduledHours;

    return TimesheetEntryExportMetrics(
      workedHours: workedHours,
      pay: pay,
      scheduledHours: scheduledHours,
      scheduledIn: scheduledIn,
      scheduledOut: scheduledOut,
      difference: difference,
      parsedDate: parsedDate,
    );
  }
}

class TimesheetEntryExportMetrics {
  const TimesheetEntryExportMetrics({
    required this.workedHours,
    required this.pay,
    required this.scheduledHours,
    required this.scheduledIn,
    required this.scheduledOut,
    required this.difference,
    required this.parsedDate,
  });

  final double workedHours;
  final double pay;
  final double scheduledHours;
  final String scheduledIn;
  final String scheduledOut;
  final double difference;
  final DateTime parsedDate;
}
