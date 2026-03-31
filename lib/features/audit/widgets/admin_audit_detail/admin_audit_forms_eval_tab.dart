import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/admin_audit_evaluation_taxonomy.dart';
import '../../../../core/models/admin_audit.dart';
import '../../../../core/services/admin_audit_ceo_submissions_service.dart';
import '../../../../core/services/admin_audit_form_title_resolver.dart' show AdminAuditFormTitleResolver;
import '../../../forms/widgets/form_details_modal.dart' show FormSubmissionDetailsView;
import '../../../../l10n/app_localizations.dart';

class AdminAuditFormsEvalTab extends StatefulWidget {
  final AdminAudit audit;
  final String themeId;
  final Map<String, int?> scores;
  final void Function(String criterionId, int? value) onScoreChanged;
  final TextEditingController sectionCommentController;
  final String sectionScopeTitle;
  final VoidCallback onSectionCommentEdited;

  const AdminAuditFormsEvalTab({
    super.key,
    required this.audit,
    required this.themeId,
    required this.scores,
    required this.onScoreChanged,
    required this.sectionCommentController,
    required this.sectionScopeTitle,
    required this.onSectionCommentEdited,
  });

  @override
  State<AdminAuditFormsEvalTab> createState() => _AdminAuditFormsEvalTabState();
}

class _AdminAuditFormsEvalTabState extends State<AdminAuditFormsEvalTab> {
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  bool _loading = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? _selected;
  Map<String, String> _titles = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminAuditFormsEvalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audit.id != widget.audit.id ||
        oldWidget.themeId != widget.themeId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _selected = null;
    });
    final ids = AdminAuditEvaluationTaxonomy.templateIdsForThemeId(widget.themeId);
    final list = await AdminAuditCeoSubmissionsService.loadSubmissions(
      adminUserId: widget.audit.adminId,
      yearMonth: widget.audit.yearMonth,
      templateIds: ids,
    );
    final keys = list
        .map((d) {
          final data = d.data();
          return (data['templateId'] as String?)?.trim() ??
              (data['formId'] as String?)?.trim() ??
              '';
        })
        .where((k) => k.isNotEmpty)
        .toSet();
    final titles = await AdminAuditFormTitleResolver.resolveTitles(keys);
    if (!mounted) return;
    setState(() {
      _docs = list;
      _titles = titles;
      _loading = false;
      if (list.isNotEmpty) _selected = list.first;
    });
  }

  String _docTitle(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final tid = (data['templateId'] as String?)?.trim() ??
        (data['formId'] as String?)?.trim() ??
        '';
    final resolved = _titles[tid];
    final name = (resolved != null && resolved.isNotEmpty) ? resolved : tid;
    final ts = data['submittedAt'];
    String when = '';
    if (ts is Timestamp) {
      when = DateFormat('MMM d, HH:mm').format(ts.toDate());
    }
    return when.isEmpty ? name : '$name · $when';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final criteria =
        AdminAuditEvaluationTaxonomy.formCriteriaForThemeId(widget.themeId);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 6,
          child: _selected == null
              ? Center(
                  child: Text(
                    l10n.adminAuditSelectSubmissionHint,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff94A3B8),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Compact selection instead of the full left column.
                    if (_docs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selected!.id,
                            // DropdownButton asserts that itemHeight must be null or >= kMinInteractiveDimension.
                            itemHeight: 48,
                            borderRadius: BorderRadius.circular(8),
                            hint: Text(l10n.adminAuditSelectSubmissionHint),
                            selectedItemBuilder: (context) {
                              return _docs.map((d) {
                                return Text(
                                  _docTitle(d),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }).toList();
                            },
                            items: _docs.map((d) {
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text(
                                  _docTitle(d),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                              );
                            }).toList(),
                            onChanged: (id) {
                              if (id == null) return;
                              final next = _docs.firstWhere((d) => d.id == id);
                              setState(() => _selected = next);
                            },
                          ),
                        ),
                      ),
                    Expanded(
                      child: _docs.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  l10n.adminAuditNoSubmissionsMonth,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xff64748B),
                                  ),
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.all(10),
                              children: [
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 520),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xffE2E8F0)),
                                  ),
                                  child: FormSubmissionDetailsView(
                                    formId: _selected!.id,
                                    shiftId: (_selected!.data()['shiftId'] ??
                                                _selected!.data()['shift_id'] ??
                                                '')
                                            .toString(),
                                    responses: Map<String, dynamic>.from(
                                      _selected!.data()['responses'] ??
                                          _selected!.data()['answers'] ??
                                          {},
                                    ),
                                  ),
                                ),
                              ],
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
                const SizedBox(height: 2),
                Text(
                  widget.sectionScopeTitle,
                  style: GoogleFonts.inter(fontSize: 9, color: const Color(0xff94A3B8)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                ...criteria.map((c) => _criterionTile(c.id, c.labelEn, c.hintEn)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _criterionTile(String id, String label, String? hint) {
    final v = widget.scores[id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          if (hint != null && hint.isNotEmpty)
            Text(
              hint,
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xff94A3B8)),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var n = 0; n <= 5; n++)
                _scoreChip('$n', v == n, () => widget.onScoreChanged(id, n)),
              _scoreChip(
                AppLocalizations.of(context)!.adminAuditScoreNa,
                v == null,
                () => widget.onScoreChanged(id, null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(String text, bool selected, VoidCallback onTap) {
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
