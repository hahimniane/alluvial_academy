/// Admin export column bundles (Power BI–style “different questions”).
enum TimesheetExportColumnPreset {
  /// Same seven columns as the admin review grid (teacher, date, student, hours, pay, source, status).
  screen,

  /// Minimal columns for payroll / approvals.
  payroll,

  /// Scheduling: shift identity, schedule vs actual, source.
  operations,

  /// Compliance: forms, edits, rejection, devices, notes.
  audit,

  /// All supported columns.
  full,
}
