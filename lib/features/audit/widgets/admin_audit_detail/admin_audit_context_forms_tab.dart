import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/audit/models/admin_audit.dart';
import '../../services/admin_audit_ceo_submissions_service.dart';
import '../../services/admin_audit_form_title_resolver.dart';
import '../../../forms/widgets/form_details_modal.dart' show FormSubmissionDetailsView;
import '../../../../l10n/app_localizations.dart';

/// Facts-finding & advance / payment request submissions for this admin.
class AdminAuditContextFormsTab extends StatefulWidget {
  final AdminAudit audit;

  const AdminAuditContextFormsTab({super.key, required this.audit});

  @override
  State<AdminAuditContextFormsTab> createState() => _AdminAuditContextFormsTabState();
}

class _AdminAuditContextFormsTabState extends State<AdminAuditContextFormsTab> {
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
  void didUpdateWidget(covariant AdminAuditContextFormsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audit.id != widget.audit.id) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _selected = null;
    });
    final list = await AdminAuditCeoSubmissionsService.loadContextSubmissions(
      adminUserId: widget.audit.adminId,
      yearMonth: widget.audit.yearMonth,
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

  String _title(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final tid = (data['templateId'] as String?)?.trim() ??
        (data['formId'] as String?)?.trim() ??
        '';
    final resolved = _titles[tid];
    final name = (resolved != null && resolved.isNotEmpty) ? resolved : tid;
    final ts = data['submittedAt'];
    if (ts is Timestamp) {
      return '$name · ${DateFormat('MMM d, HH:mm').format(ts.toDate())}';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xffE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    l10n.adminAuditContextFormsHint,
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff64748B)),
                  ),
                ),
                Expanded(
                  child: _docs.isEmpty
                      ? Center(
                          child: Text(
                            l10n.adminAuditNoSubmissionsMonth,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff94A3B8)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _docs.length,
                          itemBuilder: (context, i) {
                            final d = _docs[i];
                            final sel = _selected?.id == d.id;
                            return InkWell(
                              onTap: () => setState(() => _selected = d),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel ? const Color(0xffEFF6FF) : Colors.transparent,
                                  border: const Border(
                                    bottom: BorderSide(color: Color(0xffF1F5F9)),
                                  ),
                                ),
                                child: Text(
                                  _title(d),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _selected == null
              ? Center(
                  child: Text(
                    l10n.adminAuditSelectSubmissionHint,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff94A3B8)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxHeight: 560),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffE2E8F0)),
                      ),
                      child: FormSubmissionDetailsView(
                        formId: _selected!.id,
                        shiftId: (_selected!.data()['shiftId'] ?? _selected!.data()['shift_id'] ?? '')
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
    );
  }
}
