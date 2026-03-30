import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/admin_audit_compliance_config.dart';
import '../../../core/models/admin_audit.dart';
import '../../../core/services/admin_audit_form_title_resolver.dart';
import '../../../l10n/app_localizations.dart';

/// Left rail: all [AdminAudit] KPIs (mirrors teacher evaluation stats column pattern).
class AdminAuditMetricsSidebar extends StatefulWidget {
  final AdminAudit audit;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  const AdminAuditMetricsSidebar({
    super.key,
    required this.audit,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  @override
  State<AdminAuditMetricsSidebar> createState() => _AdminAuditMetricsSidebarState();
}

class _AdminAuditMetricsSidebarState extends State<AdminAuditMetricsSidebar> {
  Future<Map<String, String>>? _titlesFuture;

  @override
  void initState() {
    super.initState();
    _titlesFuture = AdminAuditFormTitleResolver.resolveTitles(widget.audit.formsBreakdown.keys);
  }

  @override
  void didUpdateWidget(covariant AdminAuditMetricsSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audit.id != widget.audit.id) {
      _titlesFuture = AdminAuditFormTitleResolver.resolveTitles(widget.audit.formsBreakdown.keys);
    }
  }

  static const _border = Color(0xffE2E8F0);
  static const _slate = Color(0xff64748B);
  static const _ink = Color(0xff0F172A);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final formPct = '${(AdminAuditComplianceConfig.overallWeightForm * 100).round()}';
    final taskPct = '${(AdminAuditComplianceConfig.overallWeightTask * 100).round()}';

    if (widget.collapsed) {
      return Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                onPressed: widget.onToggleCollapsed,
                tooltip: 'Expand metrics',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ),
            const Spacer(),
            Text(
              'Score',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: _slate,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.audit.overallScore}%',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: const Color(0xff1D4ED8),
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
          ],
        ),
      );
    }

    Widget row(String k, String v, {Color? vColor}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  k,
                  style: GoogleFonts.inter(fontSize: 11, color: _slate, height: 1.25),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                v,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: vColor ?? _ink,
                ),
                textAlign: TextAlign.end,
              ),
            ],
          ),
        );

    return Container(
      color: const Color(0xFFF8FAFC),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.adminAuditMetricsSidebarTitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _slate,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                onPressed: widget.onToggleCollapsed,
                tooltip: 'Collapse metrics',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 10),
          row(l10n.adminAuditOverallScore, '${widget.audit.overallScore}%',
              vColor: const Color(0xff1D4ED8)),
          row(l10n.adminAuditFormComplianceShort, '${widget.audit.formComplianceScore}%'),
          row(l10n.adminAuditTaskEfficiencyShort, '${widget.audit.taskEfficiencyScore}%'),
          const Divider(height: 20, color: _border),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              expandedAlignment: Alignment.topLeft,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              initiallyExpanded: false,
              title: Text(
                l10n.adminAuditScoreHelpTitle,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _slate),
              ),
              children: [
                Text(
                  l10n.adminAuditScoreHelpBody(formPct, taskPct),
                  style: GoogleFonts.inter(fontSize: 10, height: 1.35, color: _slate),
                ),
              ],
            ),
          ),
          const Divider(height: 20, color: _border),
          row(l10n.adminAuditFormsSubmitted, '${widget.audit.formsSubmitted}'),
          row(l10n.adminAuditTasksCompleted,
              '${widget.audit.tasksCompleted} / ${widget.audit.totalTasksAssigned}'),
          row(l10n.adminAuditOverdue, '${widget.audit.tasksOverdue}',
              vColor: widget.audit.tasksOverdue > 0 ? const Color(0xffDC2626) : _ink),
          row(l10n.adminAuditAcknowledged,
              '${widget.audit.tasksAcknowledged} / ${widget.audit.totalTasksAssigned}'),
          row(l10n.adminAuditTasksCreated, '${widget.audit.tasksCreatedByAdmin}'),
          row(l10n.adminAuditSubTasksRatio, '${widget.audit.subTasksRatio}%'),
          row(
            l10n.adminAuditAvgCompletionDays,
            widget.audit.avgTaskCompletionDays > 0
                ? widget.audit.avgTaskCompletionDays.toStringAsFixed(1)
                : '—',
          ),
          if (widget.audit.formsBreakdown.isNotEmpty) ...[
            const Divider(height: 20, color: _border),
            Text(
              l10n.adminAuditFormBreakdown,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _slate),
            ),
            const SizedBox(height: 6),
            FutureBuilder<Map<String, String>>(
              future: _titlesFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _slate.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  );
                }
                final titles = snap.data ?? {};
                final list = widget.audit.formsBreakdown.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: list.take(12).map((e) {
                    final id = e.key;
                    final resolved = titles[id];
                    final display = id == '_unknown'
                        ? l10n.adminAuditUnknownForm
                        : ((resolved != null && resolved.isNotEmpty) ? resolved : id);
                    final showIdFoot =
                        id != '_unknown' && resolved != null && resolved.isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Tooltip(
                        message: id == '_unknown' ? display : id,
                        waitDuration: const Duration(milliseconds: 400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            row(display, '${e.value}'),
                            if (showIdFoot)
                              Text(
                                id.length > 32 ? '${id.substring(0, 32)}…' : id,
                                style: GoogleFonts.inter(fontSize: 8, color: _slate.withValues(alpha: 0.75)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
          if (widget.audit.tasksByLabel.isNotEmpty) ...[
            const Divider(height: 20, color: _border),
            Text(
              l10n.adminAuditTaskLabels,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _slate),
            ),
            const SizedBox(height: 6),
            ...widget.audit.tasksByLabel.entries.map((e) => row(e.key, '${e.value}')),
          ],
        ],
      ),
    );
  }
}
