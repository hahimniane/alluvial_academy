import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../forms/widgets/form_details_modal.dart' show FormSubmissionDetailsView;
import '../audit_shared_widgets.dart';
import '../../../core/audit/audit_assignment_metrics.dart';
import 'audit_form_title_resolver.dart';

class AuditAssignmentsTab extends StatefulWidget {
  final TeacherAuditFull audit;
  const AuditAssignmentsTab({super.key, required this.audit});

  @override
  State<AuditAssignmentsTab> createState() => _AuditAssignmentsTabState();
}

class _AuditAssignmentsTabState extends State<AuditAssignmentsTab> {
  Map<String, dynamic>? _selected;
  Map<String, String> _formTitles = const {};

  @override
  void initState() {
    super.initState();
    _loadFormTitles();
  }

  @override
  void didUpdateWidget(covariant AuditAssignmentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audit.id != widget.audit.id) {
      _selected = null;
      _formTitles = const {};
      _loadFormTitles();
    }
  }

  Future<void> _loadFormTitles() async {
    final titles = await AuditFormTitleResolver.prefetchTitles(
      widget.audit.detailedFormsNonTeaching,
    );
    if (!mounted) return;
    setState(() => _formTitles = titles);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final raw = widget.audit.detailedFormsNonTeaching;
    final forms = raw
        .where((f) => !AuditAssignmentMetrics.isRoutineTeachingPipelineRow(f))
        .toList();

    if (raw.isEmpty) {
      return AuditEmptyState(
        icon: Icons.assignment_outlined,
        message: l10n.auditNoFormsSubmitted,
      );
    }
    if (forms.isEmpty) {
      return AuditEmptyState(
        icon: Icons.assignment_outlined,
        message: l10n.auditNoAssignmentFormsInSnapshot,
      );
    }

    final metrics = AuditAssignmentMetrics.fromDetailedForms(forms);

    return Column(
      children: [
        _stats(metrics),
        const Divider(height: 1, color: Color(0xffE2E8F0)),
        Expanded(
          child: Row(
            children: [
              SizedBox(width: 240, child: _left(forms)),
              const VerticalDivider(width: 1, color: Color(0xffE2E8F0)),
              Expanded(child: _right()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stats(AuditAssignmentMetrics metrics) {
    Widget box(String k, String v, Color c) => Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xffE2E8F0), width: 0.5), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff64748B))),
            Text(v, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: c)),
          ]),
        );
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          box('Assignments', '${metrics.assignments}', const Color(0xFF3B82F6)),
          box('Quizzes', '${metrics.quizzes}', const Color(0xFF0EA5E9)),
          box('Student assessments', '${metrics.studentAssessments}', const Color(0xFF8B5CF6)),
          box('Midterm', metrics.hasMidtermEvidence ? 'Yes' : 'No', metrics.hasMidtermEvidence ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
          box('Final exam', metrics.hasFinalExamEvidence ? 'Yes' : 'No', metrics.hasFinalExamEvidence ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _left(List<Map<String, dynamic>> forms) {
    return ListView(
      children: [
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            'Assessments & assignments (${forms.length} shown)',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xff64748B)),
          ),
        ),
        ...forms.map((form) {
          final selected = identical(_selected, form);
          final submittedAt = (form['submittedAt'] as Timestamp?)?.toDate();
          final date = submittedAt != null ? DateFormat('MMM d, HH:mm').format(submittedAt) : '—';
          final name = AuditFormTitleResolver.resolveTitle(
            form,
            cachedTitles: _formTitles,
          );
          return InkWell(
            onTap: () => setState(() => _selected = form),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                border: Border(left: BorderSide(color: selected ? const Color(0xff1a6ef5) : Colors.transparent, width: 3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(date, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff64748B))),
              ]),
            ),
          );
        }),
      ],
    );
  }

  Widget _right() {
    if (_selected == null) {
      return Center(
        child: Text(AppLocalizations.of(context)!.auditSelectFormToView, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff94A3B8))),
      );
    }
    final selected = _selected!;
    final responses = (selected['responses'] as Map<String, dynamic>?) ?? {};
    final formId = (selected['id'] as String? ?? '').trim();
    final shiftId = (selected['shiftId'] as String? ?? '').trim();
    if (formId.isEmpty) {
      return Center(
        child: Text('Missing form id', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff94A3B8))),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: FormSubmissionDetailsView(
          formId: formId,
          shiftId: shiftId,
          responses: responses,
        ),
      ),
    );
  }
}
