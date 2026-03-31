import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/teacher_audit_full.dart';
import '../../../../core/services/audit_class_log_row_builder.dart';
import '../../../../core/services/teacher_audit_service.dart';
import '../../../../l10n/app_localizations.dart';
import 'audit_assignment_metrics.dart';

class AuditEvaluationTab extends StatefulWidget {
  final TeacherAuditFull audit;
  final ValueChanged<TeacherAuditFull>? onAuditChanged;

  const AuditEvaluationTab({super.key, required this.audit, this.onAuditChanged});

  @override
  State<AuditEvaluationTab> createState() => _AuditEvaluationTabState();
}

class _AuditEvaluationTabState extends State<AuditEvaluationTab> {
  static const _uuid = Uuid();
  late List<AuditFactor> _factors;
  late Map<String, TextEditingController> _outcomeControllers;
  late List<PaymentAdjustmentLine> _coachLines;
  late List<AdvancePayment> _advanceDraft;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _syncFromAudit(widget.audit);
  }

  void _syncFromAudit(TeacherAuditFull audit) {
    _factors = audit.auditFactors.map((f) => f.copyWith()).toList();
    _outcomeControllers = {
      for (final f in _factors) f.id: TextEditingController(text: f.outcome),
    };
    _coachLines = List<PaymentAdjustmentLine>.from(
      audit.paymentSummary?.coachAdjustmentLines ?? const [],
    );
    _advanceDraft = List<AdvancePayment>.from(
      audit.paymentSummary?.advancePayments ?? const [],
    );
  }

  @override
  void dispose() {
    for (final c in _outcomeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AuditEvaluationTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audit.id != widget.audit.id) {
      for (final c in _outcomeControllers.values) {
        c.dispose();
      }
      _syncFromAudit(widget.audit);
    }
  }

  static const _border = Color(0xffE2E8F0);
  static const _slate = Color(0xff64748B);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = AuditClassLogRowBuilder.buildRows(widget.audit);
    final completed = rows.where((r) {
      final s = r.statusRaw.toLowerCase();
      return s.contains('completed') || s.contains('fully') || s.contains('partially');
    }).length;
    final missed = rows.where((r) => r.statusRaw.toLowerCase().contains('missed')).length;
    final worked = rows.fold<double>(0, (t, r) => t + r.workedHours);
    final applicable = _factors.where((f) => !f.isNotApplicable).toList();
    final totalScore = applicable.fold<int>(0, (t, f) => t + f.rating);
    final maxScore = applicable.isEmpty ? 1 : applicable.length * 5;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(width: 240, child: _leftPanel(completed, missed, worked)),
              const VerticalDivider(width: 1, color: _border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildPaymentAdjustmentsCard(l10n),
                    _buildAdvanceCard(l10n),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        l10n.performanceEvaluation,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _slate,
                        ),
                      ),
                    ),
                    ...List.generate(_factors.length, (i) => _factorCard(_factors[i], i)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              Text(
                'Overall: $totalScore / $maxScore',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.performanceEvaluation),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentAdjustmentsCard(AppLocalizations l10n) {
    final ps = widget.audit.paymentSummary;
    var previewNet = 0.0;
    if (ps != null) {
      final gross = AuditClassLogRowBuilder.computeTotals(widget.audit).grossBySource;
      final coachDelta = _coachLines.fold<double>(
        0.0, (acc, e) => acc + (e.type == 'bonus' ? e.amount : -e.amount));
      final advanceDeduction = _advanceDraft.fold<double>(
        0.0, (acc, a) => acc + a.amount.abs());
      previewNet = gross - ps.totalPenalties + ps.totalBonuses + ps.adminAdjustment + coachDelta - advanceDeduction;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xff38BDF8), width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.auditCoachPaymentAdjustmentsTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          if (ps != null)
            Text(
              '${l10n.auditNetAfterAdjustmentsHint}: \$${previewNet.toStringAsFixed(2)}',
              style: GoogleFonts.inter(fontSize: 11, color: _slate),
            )
          else
            Text(
              l10n.auditNetAfterAdjustmentsHint,
              style: GoogleFonts.inter(fontSize: 11, color: _slate),
            ),
          const SizedBox(height: 8),
          ..._coachLines.map(
            (l) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${l.type} \$${l.amount.toStringAsFixed(2)} — ${l.reason}',
                style: GoogleFonts.inter(fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: _isSubmitting ? null : () => setState(() => _coachLines.remove(l)),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _isSubmitting ? null : _onAddCoachLine,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.auditAddPaymentLine),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvanceCard(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.auditAdvanceSectionTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.auditAdvanceSectionSubtitle,
            style: GoogleFonts.inter(fontSize: 10, color: _slate),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isSubmitting
                ? null
                : () async {
                    final list = await TeacherAuditService.fetchAdvancePaymentSubmissions(
                      userId: widget.audit.oderId,
                      yearMonth: widget.audit.yearMonth,
                    );
                    if (mounted) setState(() => _advanceDraft = list);
                  },
            icon: const Icon(Icons.cloud_download_outlined, size: 18),
            label: Text(l10n.auditAdvanceLoadFromForms),
          ),
          ..._advanceDraft.map(
            (a) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '\$${a.amount.toStringAsFixed(2)} · ${a.formResponseId}',
                style: GoogleFonts.inter(fontSize: 11),
              ),
              subtitle: Text(
                DateFormat.yMMMd().format(a.submittedAt),
                style: GoogleFonts.inter(fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddCoachLine() async {
    final l10n = AppLocalizations.of(context)!;
    var type = 'penalty';
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: Text(l10n.auditAddPaymentLine),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(labelText: l10n.auditPaymentLineTypeLabel),
                items: [
                  DropdownMenuItem(value: 'penalty', child: Text(l10n.auditPaymentLinePenalty)),
                  DropdownMenuItem(value: 'bonus', child: Text(l10n.auditPaymentLineBonus)),
                ],
                onChanged: (v) => setD(() => type = v ?? 'penalty'),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.auditAmountLabel),
              ),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(labelText: l10n.auditReasonLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final amt = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amt <= 0) return;
    setState(() {
      _coachLines.add(
        PaymentAdjustmentLine(
          id: _uuid.v4(),
          type: type,
          amount: amt,
          reason: reasonCtrl.text.trim().isEmpty ? '—' : reasonCtrl.text.trim(),
          factorId: null,
          createdAt: DateTime.now(),
          createdById: u.uid,
          createdByName: u.displayName ?? u.email ?? u.uid,
        ),
      );
    });
  }

  Widget _leftPanel(int completed, int missed, double worked) {
    final hasTaskData = widget.audit.totalTasksAssigned > 0 ||
        widget.audit.overdueTasks > 0 ||
        widget.audit.acknowledgedTasks > 0;
    final assignMetrics =
        AuditAssignmentMetrics.fromDetailedForms(widget.audit.detailedFormsNonTeaching);
    final metrics = <(String, String)>[
      ('Completion', '$completed/${widget.audit.totalClassesScheduled}'),
      ('Hours', '${worked.toStringAsFixed(2)} h'),
      ('Missed', '$missed'),
      ('Late clock-ins', '${widget.audit.lateClockIns}'),
      ('Daily reports', '${widget.audit.readinessFormsSubmitted}/${widget.audit.readinessFormsRequired}'),
      ('Assignments', '${assignMetrics.assignments}'),
      ('Quizzes', '${assignMetrics.quizzes}'),
      ('Student assessments', '${assignMetrics.studentAssessments}'),
      ('Midterm', assignMetrics.hasMidtermEvidence ? 'Yes' : 'No'),
      ('Final exam', assignMetrics.hasFinalExamEvidence ? 'Yes' : 'No'),
      if (hasTaskData) ('Overdue tasks', '${widget.audit.overdueTasks}'),
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Text(
            'Live audit data',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _slate,
            ),
          ),
          const SizedBox(height: 8),
          ...metrics.map(
            (m) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      m.$1,
                      style: GoogleFonts.inter(fontSize: 11, color: _slate),
                    ),
                  ),
                  Text(
                    m.$2,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _factorCard(AuditFactor factor, int index) {
    const labels = [
      'Critical',
      'Below',
      'Meets',
      'Good',
      'Excellent',
      'Outstanding',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _border),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff1E293B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factor.title,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    if (factor.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        factor.description,
                        style: GoogleFonts.inter(fontSize: 10, color: _slate, height: 1.25),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: Text(AppLocalizations.of(context)!.auditFactorNaShort),
              selected: factor.isNotApplicable,
              onSelected: (v) => setState(
                () => _factors[index] = factor.copyWith(isNotApplicable: v),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(6, (score) {
              final selected = factor.rating == score;
              return InkWell(
                onTap: factor.isNotApplicable
                    ? null
                    : () => setState(
                          () => _factors[index] = factor.copyWith(rating: score),
                        ),
                child: Container(
                  width: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: factor.isNotApplicable
                        ? const Color(0xFFF8FAFC).withOpacity(0.5)
                        : (selected ? const Color(0xff1a6ef5) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? const Color(0xff1a6ef5) : _border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$score',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : const Color(0xff1E293B),
                        ),
                      ),
                      Text(
                        labels[score],
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: selected ? Colors.white : _slate,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _outcomeControllers[factor.id],
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Observations...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final updatedFactors = _factors
        .map((f) => f.copyWith(outcome: _outcomeControllers[f.id]?.text.trim() ?? f.outcome))
        .toList();
    final ok = await TeacherAuditService.updateAuditFactors(
      auditId: widget.audit.id,
      factors: updatedFactors,
      coachPaymentAdjustmentLines: _coachLines,
    );
    var advanceOk = true;
    if (ok) {
      advanceOk = await TeacherAuditService.syncAuditAdvancePayments(
        auditId: widget.audit.id,
        advances: _advanceDraft,
      );
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      final refreshed = await TeacherAuditService.getAudit(
        oderId: widget.audit.oderId,
        yearMonth: widget.audit.yearMonth,
      );
      if (refreshed != null) widget.onAuditChanged?.call(refreshed);
      if (!mounted) return;
      if (!advanceOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Evaluation saved, but advance payments did not sync. Try again or add a coach payment line first.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluation submitted successfully'), backgroundColor: Colors.green),
        );
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to submit evaluation'), backgroundColor: Colors.red),
    );
  }
}
