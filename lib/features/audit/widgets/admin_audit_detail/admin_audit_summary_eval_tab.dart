import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/models/admin_audit.dart';
import '../../../../core/services/admin_audit_evaluation_export_service.dart';
import '../../../../l10n/app_localizations.dart';

class AdminAuditSummaryEvalTab extends StatelessWidget {
  final AdminAudit audit;
  final Map<String, int?> scores;

  const AdminAuditSummaryEvalTab({
    super.key,
    required this.audit,
    required this.scores,
  });

  static double? _averagePercent(Map<String, int?> scores) {
    final vals = scores.values.whereType<int>().toList();
    if (vals.isEmpty) return null;
    final sum = vals.fold<int>(0, (a, b) => a + b);
    return (sum / (vals.length * 5)) * 100;
  }

  static String _evaluatorName() {
    final user = FirebaseAuth.instance.currentUser;
    final dn = user?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final em = user?.email?.trim();
    if (em != null && em.isNotEmpty) return em;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final avg = _averagePercent(scores);
    final pctStr = avg == null ? '—' : avg.toStringAsFixed(1);
    final criterionLabels = AdminAuditEvaluationExportService.criterionLabelMap();
    final exportLabels = AdminEvalExportLabels.fromL10n(l10n, audit);
    final evaluatorName = _evaluatorName();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.adminAuditEvalSummaryTitle,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.adminAuditEvalAverage(pctStr),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: avg == null ? 0 : (avg / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: const Color(0xffE2E8F0),
                  color: const Color(0xff1D4ED8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () async {
                await AdminAuditEvaluationExportService.exportPdf(
                  audit: audit,
                  scores: scores,
                  criterionLabels: criterionLabels,
                  labels: exportLabels,
                  evaluatorName: evaluatorName,
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(l10n.adminAuditExportEvalPdf),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await AdminAuditEvaluationExportService.exportExcel(
                  audit: audit,
                  scores: scores,
                  criterionLabels: criterionLabels,
                  labels: exportLabels,
                  evaluatorName: evaluatorName,
                );
              },
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: Text(l10n.adminAuditExportEvalExcel),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.adminAuditEnteredScores,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xff64748B)),
        ),
        const SizedBox(height: 8),
        ...scores.entries.map((e) {
          final lab = criterionLabels[e.key] ?? e.key;
          final v = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(lab, style: GoogleFonts.inter(fontSize: 11)),
                ),
                Text(
                  v == null ? l10n.adminAuditScoreNa : '$v / 5',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
