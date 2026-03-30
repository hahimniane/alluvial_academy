import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/admin_audit_evaluation_taxonomy.dart';
import '../../../core/models/admin_audit.dart';
import '../../../core/services/admin_audit_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../l10n/app_localizations.dart';
import 'admin_audit_context_forms_tab.dart';
import 'admin_audit_forms_eval_tab.dart';
import 'admin_audit_metrics_sidebar.dart';
import 'admin_audit_summary_eval_tab.dart';
import 'admin_audit_tasks_eval_tab.dart';

/// Admin audit detail body: metrics sidebar + tabbed evaluation workspace.
class AdminAuditEvaluationWorkspace extends StatefulWidget {
  final AdminAudit audit;
  final Widget breakdownTab;
  final Widget ceoNotesTab;

  /// Called after evaluation draft (scores + section comments) is written to Firestore (debounced).
  final void Function(Map<String, int> scores, Map<String, String> sectionComments)?
      onAdminEvalDraftPersisted;

  const AdminAuditEvaluationWorkspace({
    super.key,
    required this.audit,
    required this.breakdownTab,
    required this.ceoNotesTab,
    this.onAdminEvalDraftPersisted,
  });

  @override
  State<AdminAuditEvaluationWorkspace> createState() =>
      _AdminAuditEvaluationWorkspaceState();
}

class _AdminAuditEvaluationWorkspaceState extends State<AdminAuditEvaluationWorkspace>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, int?> _scores = {};
  /// Lazy; dispose in [_disposeSectionCommentControllers].
  final Map<String, TextEditingController> _sectionCommentControllers = {};
  String _formThemeId = AdminAuditEvaluationTaxonomy.themeAllId;
  bool _metricsCollapsed = true;
  Timer? _persistDraftDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initScores();
  }

  void _initScores() {
    _scores.clear();
    final saved = widget.audit.adminEvalScores;
    for (final th in AdminAuditEvaluationTaxonomy.formThemes) {
      for (final c in th.criteria) {
        _scores[c.id] = saved[c.id];
      }
    }
    for (final c in AdminAuditEvaluationTaxonomy.taskCriteria) {
      _scores[c.id] = saved[c.id];
    }
  }

  void _disposeSectionCommentControllers() {
    for (final c in _sectionCommentControllers.values) {
      c.dispose();
    }
    _sectionCommentControllers.clear();
  }

  TextEditingController _commentCtrl(String sectionId) {
    return _sectionCommentControllers.putIfAbsent(
      sectionId,
      () => TextEditingController(
        text: widget.audit.adminEvalSectionComments[sectionId] ?? '',
      ),
    );
  }

  @override
  void dispose() {
    _persistDraftDebounce?.cancel();
    _disposeSectionCommentControllers();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdminAuditEvaluationWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audit.id != widget.audit.id) {
      _persistDraftDebounce?.cancel();
      _disposeSectionCommentControllers();
      _initScores();
      return;
    }
    // Do not dispose section comment controllers when maps change — recreating controllers
    // resets the caret (cursor jumps to start). Only drop scores state when server scores differ.
    if (!mapEquals(oldWidget.audit.adminEvalScores, widget.audit.adminEvalScores)) {
      _persistDraftDebounce?.cancel();
      _initScores();
      _patchStaleEmptySectionCommentsFromAudit();
    } else if (!mapEquals(
        oldWidget.audit.adminEvalSectionComments,
        widget.audit.adminEvalSectionComments,
      )) {
      _patchStaleEmptySectionCommentsFromAudit();
    }
  }

  /// Fills comment fields from Firestore only when the local controller is still empty
  /// (e.g. after KPI refresh). Never overwrites text the evaluator is typing.
  void _patchStaleEmptySectionCommentsFromAudit() {
    for (final sid in AdminAuditEvaluationTaxonomy.evalSectionCommentKeys) {
      final server = widget.audit.adminEvalSectionComments[sid];
      if (server == null || server.isEmpty) continue;
      final c = _sectionCommentControllers[sid];
      if (c == null) continue;
      if (c.text.isEmpty) {
        c.value = TextEditingValue(
          text: server,
          selection: TextSelection.collapsed(offset: server.length),
        );
      }
    }
  }

  Map<String, int> _nonNullScoresMap() {
    final out = <String, int>{};
    for (final e in _scores.entries) {
      if (e.value != null) out[e.key] = e.value!;
    }
    return out;
  }

  Map<String, String> _sectionCommentsForSave() {
    final out = <String, String>{};
    for (final sid in AdminAuditEvaluationTaxonomy.evalSectionCommentKeys) {
      final t = _sectionCommentControllers[sid]?.text.trim() ?? '';
      if (t.isNotEmpty) out[sid] = t;
    }
    return out;
  }

  Future<void> _persistDraftToFirestore() async {
    final scores = _nonNullScoresMap();
    final sectionComments = _sectionCommentsForSave();
    try {
      await AdminAuditService.updateAdminEvalDraft(
        widget.audit.id,
        scores: scores,
        sectionComments: sectionComments,
      );
      widget.onAdminEvalDraftPersisted?.call(scores, sectionComments);
    } catch (e, st) {
      AppLogger.error('Admin eval draft save failed: $e\n$st');
    }
  }

  void _scheduleEvalDraftPersist() {
    _persistDraftDebounce?.cancel();
    _persistDraftDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _persistDraftToFirestore();
    });
  }

  void _onScore(String id, int? v) {
    setState(() => _scores[id] = v);
    _scheduleEvalDraftPersist();
  }

  void _onSectionCommentEdited() {
    _scheduleEvalDraftPersist();
  }

  String _formThemeTitle(String id) {
    final opts = AdminAuditEvaluationTaxonomy.formThemeOptions;
    for (final th in opts) {
      if (th.id == id) return th.titleEn;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: _metricsCollapsed ? 86 : 268,
          child: AdminAuditMetricsSidebar(
            audit: widget.audit,
            collapsed: _metricsCollapsed,
            onToggleCollapsed: () {
              if (!mounted) return;
              setState(() => _metricsCollapsed = !_metricsCollapsed);
            },
          ),
        ),
        if (!_metricsCollapsed) const VerticalDivider(width: 1, color: Color(0xffE2E8F0)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: const Color(0xff1D4ED8),
                  unselectedLabelColor: const Color(0xff64748B),
                  indicatorColor: const Color(0xff1D4ED8),
                  labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(text: l10n.adminAuditTabFormsEval),
                    Tab(text: l10n.adminAuditTabTasksEval),
                    Tab(text: l10n.adminAuditTabContextForms),
                    Tab(text: l10n.adminAuditTabEvalSummary),
                    Tab(text: l10n.adminAuditFormBreakdown),
                    Tab(text: l10n.adminAuditCeoNotes),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Row(
                            children: [
                              Text(
                                l10n.adminAuditEvalThemeFilter,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff64748B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _formThemeId,
                                    isExpanded: true,
                                    items: AdminAuditEvaluationTaxonomy.formThemeOptions
                                        .map(
                                          (th) => DropdownMenuItem(
                                            value: th.id,
                                            child: Text(
                                              th.titleEn,
                                              style: GoogleFonts.inter(fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() => _formThemeId = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: AdminAuditFormsEvalTab(
                            key: ValueKey('${widget.audit.id}_$_formThemeId'),
                            audit: widget.audit,
                            themeId: _formThemeId,
                            scores: _scores,
                            onScoreChanged: _onScore,
                            sectionCommentController: _commentCtrl(_formThemeId),
                            sectionScopeTitle: _formThemeTitle(_formThemeId),
                            onSectionCommentEdited: _onSectionCommentEdited,
                          ),
                        ),
                      ],
                    ),
                    AdminAuditTasksEvalTab(
                      audit: widget.audit,
                      scores: _scores,
                      onScoreChanged: _onScore,
                      sectionCommentController:
                          _commentCtrl(AdminAuditEvaluationTaxonomy.tasksEvalSectionId),
                      onSectionCommentEdited: _onSectionCommentEdited,
                    ),
                    AdminAuditContextFormsTab(audit: widget.audit),
                    AdminAuditSummaryEvalTab(
                      audit: widget.audit,
                      scores: Map<String, int?>.from(_scores),
                    ),
                    widget.breakdownTab,
                    widget.ceoNotesTab,
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
