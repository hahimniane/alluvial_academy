import '../models/timesheet_entry.dart';
import '../../../core/enums/timesheet_enums.dart';

/// Pure helpers for admin review filters and tooltips.
class TimesheetEntryReviewFlags {
  const TimesheetEntryReviewFlags._();

  /// Same rules as admin review approval completeness (clock in/out + hours).
  static bool isTimesheetComplete(TimesheetEntry timesheet) {
    final hasStart =
        timesheet.start.isNotEmpty && timesheet.start != '--';
    final hasEnd = timesheet.end.isNotEmpty && timesheet.end != '--';
    final hasValidHours = timesheet.totalHours.isNotEmpty &&
        timesheet.totalHours != '00:00' &&
        timesheet.totalHours != '--';
    return hasStart && hasEnd && hasValidHours;
  }

  /// Pending rows that likely need admin eyes: incomplete, missing post-class
  /// form for clock-in shifts, or unapproved teacher edits.
  static bool needsAttention(TimesheetEntry e) {
    if (e.status != TimesheetStatus.pending) return false;
    if (!isTimesheetComplete(e)) return true;
    final isClockIn = e.source == 'clock_in';
    if (isClockIn && !e.formCompleted) return true;
    if (e.isEdited && !e.editApproved) return true;
    return false;
  }
}
