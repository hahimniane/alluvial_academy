import '../models/admin_audit.dart';

/// Builds a CSV snapshot of [AdminAudit] rows for spreadsheet review.
class AdminAuditCsvExport {
  AdminAuditCsvExport._();

  static String _cell(String raw) {
    final s = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// One row per admin; [formsBreakdown] serialized as `id:count|id:count`.
  static String build(List<AdminAudit> audits) {
    final headers = [
      'admin_name',
      'admin_email',
      'year_month',
      'overall_score_pct',
      'form_compliance_pct',
      'task_efficiency_pct',
      'forms_submitted',
      'tasks_completed',
      'tasks_assigned_total',
      'tasks_overdue',
      'tasks_acknowledged',
      'tasks_created_by_admin',
      'avg_completion_days',
      'sub_tasks_ratio_pct',
      'forms_breakdown',
      'ceo_notes',
    ];
    final buf = StringBuffer()..writeln(headers.map(_cell).join(','));

    for (final a in audits) {
      final bd = a.formsBreakdown.entries.map((e) => '${e.key}:${e.value}').join('|');
      final notes = a.ceoNotes.replaceAll('\n', ' ').trim();
      final row = [
        a.adminName,
        a.adminEmail,
        a.yearMonth,
        '${a.overallScore}',
        '${a.formComplianceScore}',
        '${a.taskEfficiencyScore}',
        '${a.formsSubmitted}',
        '${a.tasksCompleted}',
        '${a.totalTasksAssigned}',
        '${a.tasksOverdue}',
        '${a.tasksAcknowledged}',
        '${a.tasksCreatedByAdmin}',
        a.avgTaskCompletionDays > 0 ? a.avgTaskCompletionDays.toStringAsFixed(2) : '',
        '${a.subTasksRatio}',
        bd,
        notes,
      ];
      buf.writeln(row.map(_cell).join(','));
    }
    return buf.toString();
  }
}
