import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/core/services/admin_submissions_export_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

import '../widgets/form_details_modal.dart';

const Color _kPrimary = Color(0xff0386FF);
const Color _kText = Color(0xff1E293B);
const Color _kMuted = Color(0xff64748B);
const Color _kBorder = Color(0xffE2E8F0);

class _ExportProgress {
  final String teacherLabel;
  final int index;
  final int total;

  const _ExportProgress(this.teacherLabel, this.index, this.total);
}

/// Split view: pick submissions, preview Q/A, export PDF/Excel (grouped per teacher).
class AdminSubmissionsReviewScreen extends StatefulWidget {
  final List<QueryDocumentSnapshot> submissions;
  final Map<String, Map<String, dynamic>> teachersData;
  final Map<String, String> formTitles;
  final Future<Map<String, TeachingShift>> Function(Set<String> shiftIds)
      getShiftSummaries;

  const AdminSubmissionsReviewScreen({
    super.key,
    required this.submissions,
    required this.teachersData,
    required this.formTitles,
    required this.getShiftSummaries,
  });

  @override
  State<AdminSubmissionsReviewScreen> createState() =>
      _AdminSubmissionsReviewScreenState();
}

class _AdminSubmissionsReviewScreenState
    extends State<AdminSubmissionsReviewScreen> {
  final Set<String> _selectedDocIds = {};
  QueryDocumentSnapshot? _focusedDoc;

  /// Resolve shift id field across inconsistent Firestore schemas.
  /// Returns '' when shift should be treated as missing.
  String _resolveShiftId(Map<String, dynamic>? data) {
    final raw = data?['shiftId'] ??
        data?['shift_id'] ??
        data?['linkedShiftId'] ??
        data?['linked_shift_id'];
    final sid = raw?.toString().trim() ?? '';
    if (sid.isEmpty) return '';
    if (sid.toLowerCase() == 'n/a') return '';
    // Keep exact 'N/A' out as well (FormDetailsModal checks by equality).
    if (sid == 'N/A') return '';
    return sid;
  }

  Map<String, List<QueryDocumentSnapshot>> get _byTeacher {
    final m = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in widget.submissions) {
      final data = doc.data() as Map<String, dynamic>?;
      final uid = data?['userId'] as String?;
      if (uid == null) continue;
      m.putIfAbsent(uid, () => []).add(doc);
    }
    for (final e in m.values) {
      e.sort((a, b) {
        final ta = (a.data() as Map<String, dynamic>?)?['submittedAt'];
        final tb = (b.data() as Map<String, dynamic>?)?['submittedAt'];
        final da = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
        final db = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
        return db.compareTo(da);
      });
    }
    return m;
  }

  List<String> get _sortedTeacherIds {
    final ids = _byTeacher.keys.toList();
    ids.sort((a, b) {
      final na = (widget.teachersData[a]?['name'] ?? a).toString();
      final nb = (widget.teachersData[b]?['name'] ?? b).toString();
      return na.toLowerCase().compareTo(nb.toLowerCase());
    });
    return ids;
  }

  String _teacherName(String uid) =>
      (widget.teachersData[uid]?['name'] ?? uid).toString();

  String _submissionTitle(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    final formId = data?['formId'] as String?;
    final title = (data?['formTitle'] ??
            data?['form_title'] ??
            data?['formName'] ??
            (formId != null ? widget.formTitles[formId] : null) ??
            '')
        .toString();
    final ts = (data?['submittedAt'] as Timestamp?)?.toDate();
    final when = ts != null ? DateFormat('MMM d, h:mm a').format(ts) : '';
    if (title.isNotEmpty && when.isNotEmpty) return '$title · $when';
    if (title.isNotEmpty) return title;
    return doc.id;
  }

  void _selectAllInTeacher(String teacherId, bool select) {
    final docs = _byTeacher[teacherId] ?? [];
    setState(() {
      for (final d in docs) {
        if (select) {
          _selectedDocIds.add(d.id);
        } else {
          _selectedDocIds.remove(d.id);
        }
      }
    });
  }

  bool _teacherFullySelected(String teacherId) {
    final docs = _byTeacher[teacherId] ?? [];
    if (docs.isEmpty) return false;
    return docs.every((d) => _selectedDocIds.contains(d.id));
  }

  bool _teacherPartiallySelected(String teacherId) {
    final docs = _byTeacher[teacherId] ?? [];
    if (docs.isEmpty) return false;
    final n = docs.where((d) => _selectedDocIds.contains(d.id)).length;
    return n > 0 && n < docs.length;
  }

  Map<String, List<QueryDocumentSnapshot>> _selectedByTeacher() {
    final out = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in widget.submissions) {
      if (!_selectedDocIds.contains(doc.id)) continue;
      final data = doc.data() as Map<String, dynamic>?;
      final uid = data?['userId'] as String?;
      if (uid == null) continue;
      out.putIfAbsent(uid, () => []).add(doc);
    }
    return out;
  }

  Future<void> _runExport(String format) async {
    final l10n = AppLocalizations.of(context)!;
    final grouped = _selectedByTeacher();
    if (grouped.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminSubmissionsNoTeacherSelected)),
      );
      return;
    }

    final shiftIds = <String>{};
    for (final doc in widget.submissions) {
      if (!_selectedDocIds.contains(doc.id)) continue;
      final data = doc.data() as Map<String, dynamic>?;
      final sid = _resolveShiftId(data);
      if (sid.isNotEmpty) shiftIds.add(sid);
    }

    final shiftMap = await widget.getShiftSummaries(shiftIds);
    if (!mounted) return;
    final teacherNames = <String, String>{
      for (final id in grouped.keys) id: _teacherName(id),
    };
    final locale = Localizations.localeOf(context).toLanguageTag();

    final progress = ValueNotifier<_ExportProgress>(
      _ExportProgress('', -1, grouped.length),
    );

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return ValueListenableBuilder<_ExportProgress>(
          valueListenable: progress,
          builder: (context, p, _) {
            return AlertDialog(
              title: Text(
                l10n.adminSubmissionsExportFormatLabel,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adminSubmissionsExportProgressSubtitle,
                      style: GoogleFonts.inter(fontSize: 12, color: _kMuted),
                    ),
                    const SizedBox(height: 12),
                    if (p.total > 0)
                      LinearProgressIndicator(
                        value: p.index < 0 || p.total <= 0
                            ? null
                            : (p.index + 1) / p.total,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      p.index < 0
                          ? '…'
                          : '${p.index + 1} / ${p.total} — ${p.teacherLabel}',
                      style: GoogleFonts.inter(fontSize: 11, color: _kMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final nav = Navigator.of(context, rootNavigator: true);
    try {
      await AdminSubmissionsExportService.exportSelectedSubmissions(
        submissionsByTeacher: grouped,
        teacherNames: teacherNames,
        formTitles: Map<String, String>.from(widget.formTitles),
        shiftMap: shiftMap,
        format: format,
        locale: locale,
        onTeacherProgress: (teacherId, index, total) {
          progress.value = _ExportProgress(
            teacherNames[teacherId] ?? teacherId,
            index,
            total,
          );
        },
      );
    } finally {
      progress.dispose();
      if (nav.canPop()) nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.of(context).size.width >= 900;
    final totalSel = _selectedDocIds.length;
    final totalAll = widget.submissions.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.adminSubmissionsReviewMode,
          style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: _kText),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                if (_selectedDocIds.length == widget.submissions.length) {
                  _selectedDocIds.clear();
                } else {
                  _selectedDocIds
                    ..clear()
                    ..addAll(widget.submissions.map((d) => d.id));
                }
              });
            },
            child: Text(
              _selectedDocIds.length == widget.submissions.length
                  ? l10n.adminSubmissionsClearAll
                  : l10n.adminSubmissionsSelectAll,
              style: GoogleFonts.inter(fontSize: 12, color: _kPrimary),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_outlined, color: _kPrimary),
            onSelected: (v) => _runExport(v),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'pdf',
                child: Text(l10n.adminSubmissionsExportPdfLabel),
              ),
              PopupMenuItem(
                value: 'excel',
                child: Text(l10n.adminSubmissionsExportExcelLabel),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xffF8FAFC),
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Text(
              l10n.adminSubmissionsSelectionProgress(totalSel, totalAll),
              style: GoogleFonts.inter(fontSize: 12, color: _kMuted),
            ),
          ),
          Expanded(
            child: isWide ? _wideBody(l10n) : _narrowBody(l10n),
          ),
        ],
      ),
    );
  }

  Widget _wideBody(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 360,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: _kBorder)),
            ),
            child: _teacherSubmissionList(l10n),
          ),
        ),
        Expanded(child: _detailPanel(l10n)),
      ],
    );
  }

  Widget _narrowBody(AppLocalizations l10n) {
    return _teacherSubmissionList(l10n);
  }

  Widget _teacherSubmissionList(AppLocalizations l10n) {
    final ids = _sortedTeacherIds;
    if (ids.isEmpty) {
      return Center(
        child: Text(
          l10n.adminSubmissionsNoSubmissions,
          style: GoogleFonts.inter(color: _kMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: ids.length,
      itemBuilder: (context, i) {
        final tid = ids[i];
        final docs = _byTeacher[tid] ?? [];
        final fully = _teacherFullySelected(tid);
        final partial = _teacherPartiallySelected(tid);
        return ExpansionTile(
          key: PageStorageKey<String>('t_$tid'),
          title: Row(
            children: [
              SizedBox(
                width: 40,
                child: Checkbox(
                  tristate: true,
                  value: fully ? true : (partial ? null : false),
                  onChanged: (v) {
                    if (v == true) {
                      _selectAllInTeacher(tid, true);
                    } else {
                      _selectAllInTeacher(tid, false);
                    }
                    setState(() {});
                  },
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _teacherName(tid),
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${docs.length} ${docs.length == 1 ? 'submission' : 'submissions'}',
                      style: GoogleFonts.inter(fontSize: 11, color: _kMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: docs.map((doc) {
            final sel = _selectedDocIds.contains(doc.id);
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 48, right: 8),
              title: Text(
                _submissionTitle(doc),
                style: GoogleFonts.inter(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              leading: SizedBox(
                width: 28,
                child: Checkbox(
                  value: sel,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedDocIds.add(doc.id);
                        _focusedDoc = doc;
                      } else {
                        _selectedDocIds.remove(doc.id);
                        if (_focusedDoc?.id == doc.id) _focusedDoc = null;
                      }
                    });
                  },
                ),
              ),
              onTap: () {
                setState(() => _focusedDoc = doc);
                if (MediaQuery.of(context).size.width < 900) {
                  _openDetailSheet(l10n, doc);
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _openDetailSheet(AppLocalizations l10n, QueryDocumentSnapshot doc) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        maxChildSize: 0.98,
        minChildSize: 0.4,
        builder: (_, scroll) {
          return _SubmissionDetailScroll(
            title: _submissionTitle(doc),
            doc: doc,
            shiftId: _resolveShiftId(doc.data() as Map<String, dynamic>?),
            scrollController: scroll,
            onOpenFull: () {
              final data = doc.data() as Map<String, dynamic>?;
              FormDetailsModal.show(
                context,
                formId: doc.id,
                shiftId: _resolveShiftId(data),
                responses:
                    (data?['responses'] as Map<String, dynamic>?) ?? {},
              );
            },
          );
        },
      ),
    );
  }

  Widget _detailPanel(AppLocalizations l10n) {
    final doc = _focusedDoc;
    if (doc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.adminSubmissionsSelectToViewDetails,
            style: GoogleFonts.inter(color: _kMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return _SubmissionDetailScroll(
      title: _submissionTitle(doc),
      doc: doc,
      shiftId: _resolveShiftId(doc.data() as Map<String, dynamic>?),
      onOpenFull: () {
        final data = doc.data() as Map<String, dynamic>?;
        FormDetailsModal.show(
          context,
          formId: doc.id,
          shiftId: _resolveShiftId(data),
          responses: (data?['responses'] as Map<String, dynamic>?) ?? {},
        );
      },
    );
  }
}

class _SubmissionDetailScroll extends StatelessWidget {
  final String title;
  final QueryDocumentSnapshot doc;
  final String shiftId;
  final ScrollController? scrollController;
  final VoidCallback onOpenFull;

  const _SubmissionDetailScroll({
    required this.title,
    required this.doc,
    required this.shiftId,
    this.scrollController,
    required this.onOpenFull,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = doc.data() as Map<String, dynamic>?;
    final responses = Map<String, dynamic>.from(
      data?['responses'] ?? data?['answers'] ?? {},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _kText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onOpenFull,
                child: Text(l10n.viewFormDetails),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FormSubmissionDetailsView(
            formId: doc.id,
            shiftId: shiftId,
            responses: responses,
            scrollController: scrollController,
          ),
        ),
      ],
    );
  }
}
