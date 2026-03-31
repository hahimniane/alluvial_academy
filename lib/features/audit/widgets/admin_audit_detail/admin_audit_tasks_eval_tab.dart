import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/audit/config/admin_audit_evaluation_taxonomy.dart';
import 'package:alluwalacademyadmin/features/tasks/enums/task_enums.dart';
import 'package:alluwalacademyadmin/features/audit/models/admin_audit.dart';
import '../../services/admin_audit_tasks_query_service.dart';
import '../../../tasks/models/task.dart';
import '../../../../l10n/app_localizations.dart';

class AdminAuditTasksEvalTab extends StatefulWidget {
  final AdminAudit audit;
  final Map<String, int?> scores;
  final void Function(String criterionId, int? value) onScoreChanged;
  final TextEditingController sectionCommentController;
  final VoidCallback onSectionCommentEdited;

  const AdminAuditTasksEvalTab({
    super.key,
    required this.audit,
    required this.scores,
    required this.onScoreChanged,
    required this.sectionCommentController,
    required this.onSectionCommentEdited,
  });

  @override
  State<AdminAuditTasksEvalTab> createState() => _AdminAuditTasksEvalTabState();
}

class _AdminAuditTasksEvalTabState extends State<AdminAuditTasksEvalTab> {
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminAuditTasksEvalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audit.id != widget.audit.id) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await AdminAuditTasksQueryService.loadTasksForAdminMonth(
      adminId: widget.audit.adminId,
      yearMonth: widget.audit.yearMonth,
    );
    if (!mounted) return;
    setState(() {
      _tasks = list;
      _loading = false;
    });
  }

  bool _isDone(Task t) => t.status == TaskStatus.done;

  bool _isOverdueFlag(Task t) {
    if (_isDone(t)) {
      return (t.overdueDaysAtCompletion ?? 0) > 0;
    }
    return t.dueDate.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final assigned = _tasks.where((t) => t.assignedTo.contains(widget.audit.adminId)).length;
    final done = _tasks.where((t) => t.assignedTo.contains(widget.audit.adminId) && _isDone(t)).length;
    final overdue = _tasks.where((t) => t.assignedTo.contains(widget.audit.adminId) && _isOverdueFlag(t)).length;

    final criteria = AdminAuditEvaluationTaxonomy.taskCriteria;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                decoration: const BoxDecoration(
                  color: Color(0xffF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adminAuditTasksForMonth,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.adminAuditTaskStatsHeader(assigned, done, overdue),
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff64748B)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _tasks.isEmpty
                    ? Center(
                        child: Text(
                          l10n.adminAuditNoSubmissionsMonth,
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff94A3B8)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _tasks.length,
                        itemBuilder: (context, i) {
                          final t = _tasks[i];
                          final role = t.assignedTo.contains(widget.audit.adminId)
                              ? 'Assignee'
                              : (t.createdBy == widget.audit.adminId ? 'Creator' : '');
                          return ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            title: Text(
                              t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${DateFormat('yyyy-MM-dd').format(t.dueDate)} · ${t.status.name} · $role',
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff64748B)),
                            ),
                            children: [
                              if (t.description.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    t.description,
                                    style: GoogleFonts.inter(fontSize: 11, height: 1.35),
                                  ),
                                ),
                              if (t.labels.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: t.labels
                                      .map((lb) => Chip(
                                            label: Text(lb, style: GoogleFonts.inter(fontSize: 9)),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                          ))
                                      .toList(),
                                ),
                              ],
                              if (t.subTaskIds.isNotEmpty)
                                Text(
                                  'Sub-tasks: ${t.subTaskIds.length}',
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff64748B)),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 260,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xffE2E8F0))),
            ),
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                Text(
                  l10n.adminAuditEvalCriteriaTitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.adminAuditEvalSectionCommentLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff64748B),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: widget.sectionCommentController,
                  maxLines: 3,
                  onChanged: (_) => widget.onSectionCommentEdited(),
                  style: GoogleFonts.inter(fontSize: 11),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.adminAuditEvalSectionCommentHint,
                    hintStyle: GoogleFonts.inter(fontSize: 10, color: const Color(0xff94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  ),
                ),
                const SizedBox(height: 12),
                ...criteria.map((c) {
                  final v = widget.scores[c.id];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.labelEn,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        if (c.hintEn != null)
                          Text(
                            c.hintEn!,
                            style: GoogleFonts.inter(fontSize: 9, color: const Color(0xff94A3B8)),
                          ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (var n = 0; n <= 5; n++)
                              _chip('$n', v == n, () => widget.onScoreChanged(c.id, n)),
                            _chip(
                              l10n.adminAuditScoreNa,
                              v == null,
                              () => widget.onScoreChanged(c.id, null),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? const Color(0xff1D4ED8).withValues(alpha: 0.12) : const Color(0xffF1F5F9),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: selected ? const Color(0xff1D4ED8) : const Color(0xff64748B),
            ),
          ),
        ),
      ),
    );
  }
}
