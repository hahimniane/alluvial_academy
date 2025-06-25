enum TimesheetStatus { draft, pending, approved, rejected }

class TimesheetEntry {
  final String? documentId; // Firebase document ID for updates
  final String date;
  final String subject; // student name
  final String start;
  final String end;
  final String breakDuration;
  final String totalHours;
  final String description;
  final TimesheetStatus status;

  const TimesheetEntry({
    this.documentId,
    required this.date,
    required this.subject,
    required this.start,
    required this.end,
    required this.breakDuration,
    required this.totalHours,
    required this.description,
    required this.status,
  });
}
