import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/teacher_audit_full.dart';
import '../../services/teacher_audit_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../forms/widgets/form_details_modal.dart' show FormSubmissionDetailsView;
import '../audit_shared_widgets.dart';
import 'audit_form_title_resolver.dart';

class AuditFormsTab extends StatefulWidget {
  final TeacherAuditFull audit;
  final ValueChanged<TeacherAuditFull>? onAuditChanged;

  const AuditFormsTab({
    super.key,
    required this.audit,
    this.onAuditChanged,
  });

  @override
  State<AuditFormsTab> createState() => _AuditFormsTabState();
}

class _AuditFormsTabState extends State<AuditFormsTab> {
  Map<String, dynamic>? _selected;
  Map<String, String> _formTitles = const {};
  final Set<String> _selectedOverrideIds = {};
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    _loadFormTitles();
  }

  @override
  void didUpdateWidget(covariant AuditFormsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audit.id != widget.audit.id) {
      _selected = null;
      _formTitles = const {};
      _selectedOverrideIds.clear();
      _loadFormTitles();
    }
  }

  Future<void> _loadFormTitles() async {
    final all = <Map<String, dynamic>>[
      ...widget.audit.detailedForms,
      ...widget.audit.detailedFormsNoSchedule,
      ...widget.audit.detailedFormsRejected,
    ];
    final titles = await AuditFormTitleResolver.prefetchTitles(all);
    if (!mounted) return;
    setState(() => _formTitles = titles);
  }

  static String _rejectionReason(Map<String, dynamic> form) =>
      (form['rejectionReason'] as String? ?? 'no_shift').trim();

  String _rejectBadgeLabel(AppLocalizations loc, String reason) {
    switch (reason) {
      case 'no_timesheet':
        return loc.auditFormStatusRejectedNoTimesheet;
      case 'duplicate':
        return loc.auditFormStatusRejectedDuplicate;
      default:
        return loc.auditFormStatusRejectedNoShift;
    }
  }

  String _acceptedBadgeLabel(AppLocalizations loc, Map<String, dynamic> form) {
    if (form['acceptanceKind'] == 'missed_shift_linked') {
      return loc.auditFormStatusAcceptedMissedShift;
    }
    return loc.auditFormStatusAccepted;
  }

  Future<void> _runBulkAccept(AppLocalizations loc) async {
    final reasonCtrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.auditBulkAcceptReasonTitle),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(hintText: loc.auditBulkAcceptReasonHint),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.commonOk),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _bulkBusy = true);
    final ok = await TeacherAuditService.appendAdminFormAcceptanceOverrides(
      auditId: widget.audit.id,
      formResponseIds: _selectedOverrideIds.toList(),
      reason: reasonCtrl.text.trim().isEmpty
          ? 'Admin override'
          : reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _bulkBusy = false);
    if (ok) {
      _selectedOverrideIds.clear();
      final refreshed = await TeacherAuditService.getAudit(
        oderId: widget.audit.oderId,
        yearMonth: widget.audit.yearMonth,
      );
      if (refreshed != null) widget.onAuditChanged?.call(refreshed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.auditBulkAcceptSuccess)),
        );
      }
    }
  }

  Widget _bulkAcceptBar(
    AppLocalizations loc,
    List<Map<String, dynamic>> rejectedNoShift,
    List<Map<String, dynamic>> rejectedNoTimesheet,
  ) {
    return Material(
      color: const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_selectedOverrideIds.length}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff1E293B),
                ),
              ),
            ),
            TextButton(
              onPressed: _bulkBusy
                  ? null
                  : () {
                      final ids = <String>{
                        for (final e in rejectedNoShift)
                          (e['id'] as String? ?? '').trim(),
                        for (final e in rejectedNoTimesheet)
                          (e['id'] as String? ?? '').trim(),
                      }..removeWhere((e) => e.isEmpty);
                      setState(() => _selectedOverrideIds.addAll(ids));
                    },
              child: Text(loc.auditBulkAcceptAllInSection),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: _bulkBusy ? null : () => _runBulkAccept(loc),
              child: _bulkBusy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Text(loc.auditBulkAcceptSelected),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final accepted = widget.audit.detailedForms;

    final noSchedule = widget.audit.detailedFormsNoSchedule;
    final rejectedNoShift = noSchedule
        .where((e) => _rejectionReason(e) == 'no_shift')
        .map((e) => {...e, '_rejected': true})
        .toList();
    final rejectedNoTimesheet = noSchedule
        .where((e) => _rejectionReason(e) == 'no_timesheet')
        .map((e) => {...e, '_rejected': true})
        .toList();

    final rejectedDuplicate = widget.audit.detailedFormsRejected
        .map((e) => {...e, '_rejected': true, 'rejectionReason': 'duplicate'})
        .toList();

    final rejected = <Map<String, dynamic>>[
      ...rejectedNoShift,
      ...rejectedNoTimesheet,
      ...rejectedDuplicate,
    ];

    final total = accepted.length + rejected.length;
    if (total == 0) {
      return AuditEmptyState(
        icon: Icons.description_outlined,
        message: loc.auditNoFormsSubmitted,
      );
    }

    return Column(
      children: [
        _stats(
          loc,
          accepted.length,
          rejectedNoShift.length,
          rejectedNoTimesheet.length,
          rejectedDuplicate.length,
        ),
        if (_selectedOverrideIds.isNotEmpty)
          _bulkAcceptBar(loc, rejectedNoShift, rejectedNoTimesheet),
        const Divider(height: 1, color: Color(0xffE2E8F0)),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 240,
                child: _leftList(
                  loc,
                  accepted,
                  rejectedNoShift,
                  rejectedNoTimesheet,
                  rejectedDuplicate,
                ),
              ),
              const VerticalDivider(width: 1, color: Color(0xffE2E8F0)),
              Expanded(child: _rightDetail()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stats(
    AppLocalizations loc,
    int accepted,
    int noShift,
    int noTimesheet,
    int duplicate,
  ) {
    final total = accepted + noShift + noTimesheet + duplicate;

    Widget box(String k, String v, Color c) => Container(
          margin: const EdgeInsets.only(right: 8, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xffE2E8F0), width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                k,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xff64748B),
                ),
              ),
              Text(
                v,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c,
                ),
              ),
            ],
          ),
        );

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          box(loc.auditFormsTabStatTotalTeaching, '$total', const Color(0xff1E293B)),
          box(loc.auditFormsAccepted, '$accepted', const Color(0xFF10B981)),
          box(loc.auditFormsTabStatRejectedNoShift, '$noShift', const Color(0xFFEF4444)),
          box(loc.auditFormsTabStatRejectedNoTimesheet, '$noTimesheet', const Color(0xFFEA580C)),
          box(loc.auditFormsTabStatRejectedDuplicate, '$duplicate', const Color(0xFFDC2626)),
          box(
            loc.auditFormsTabStatReadiness,
            '${widget.audit.readinessFormsSubmitted}',
            const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }

  Widget _leftList(
    AppLocalizations loc,
    List<Map<String, dynamic>> accepted,
    List<Map<String, dynamic>> rejectedNoShift,
    List<Map<String, dynamic>> rejectedNoTimesheet,
    List<Map<String, dynamic>> rejectedDuplicate,
  ) {
    Widget section(
      String title,
      List<Map<String, dynamic>> items,
      Color color, {
      required bool isAccepted,
      String Function(Map<String, dynamic> form)? acceptedLabel,
      String Function(Map<String, dynamic> form)? rejectLabel,
      bool enableBulkSelect = false,
    }) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xff64748B),
              ),
            ),
          ),
          ...items.map((form) {
            final selected = identical(_selected, form);
            final submittedAt = (form['submittedAt'] as Timestamp?)?.toDate();
            final date = submittedAt != null
                ? DateFormat('MMM d, HH:mm').format(submittedAt)
                : '—';
            final type = AuditFormTitleResolver.resolveTitle(
              form,
              cachedTitles: _formTitles,
            );
            final badgeText = isAccepted
                ? (acceptedLabel ?? (_) => loc.auditFormStatusAccepted)(form)
                : rejectLabel!(form);
            final showMissedHint =
                isAccepted && form['acceptanceKind'] == 'missed_shift_linked';
            final fid = (form['id'] as String? ?? '').trim();
            return InkWell(
              onTap: () => setState(() => _selected = form),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                  border: Border(
                    left: BorderSide(
                      color: selected ? const Color(0xff1a6ef5) : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (enableBulkSelect && fid.isNotEmpty)
                      Checkbox(
                        value: _selectedOverrideIds.contains(fid),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedOverrideIds.add(fid);
                            } else {
                              _selectedOverrideIds.remove(fid);
                            }
                          });
                        },
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badgeText,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            date,
                            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff64748B)),
                          ),
                          if (showMissedHint) ...[
                            const SizedBox(height: 4),
                            Text(
                              loc.auditFormHintMissedShiftReport,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                height: 1.25,
                                color: const Color(0xff64748B),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    return ListView(
      children: [
        section(
          loc.auditFormsSectionAccepted(accepted.length),
          accepted,
          const Color(0xFF10B981),
          isAccepted: true,
          acceptedLabel: (f) => _acceptedBadgeLabel(loc, f),
        ),
        section(
          loc.auditFormsSectionRejectedNoShift(rejectedNoShift.length),
          rejectedNoShift,
          const Color(0xFFEF4444),
          isAccepted: false,
          rejectLabel: (f) => _rejectBadgeLabel(loc, _rejectionReason(f)),
          enableBulkSelect: true,
        ),
        section(
          loc.auditFormsSectionRejectedNoTimesheet(rejectedNoTimesheet.length),
          rejectedNoTimesheet,
          const Color(0xFFEA580C),
          isAccepted: false,
          rejectLabel: (f) => _rejectBadgeLabel(loc, _rejectionReason(f)),
          enableBulkSelect: true,
        ),
        section(
          loc.auditFormsSectionRejectedDuplicate(rejectedDuplicate.length),
          rejectedDuplicate,
          const Color(0xFFDC2626),
          isAccepted: false,
          rejectLabel: (_) => loc.auditFormStatusRejectedDuplicate,
        ),
      ],
    );
  }

  Widget _rightDetail() {
    if (_selected == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.auditSelectFormToView,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff94A3B8)),
        ),
      );
    }
    final form = _selected!;
    final shiftId = (form['shiftId']?.toString() ?? '').trim();
    final formId = (form['id'] as String? ?? '').trim();
    final responses = (form['responses'] as Map<String, dynamic>?) ?? {};

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (formId.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              AppLocalizations.of(context)!.auditFormNoMatchingShift,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff991B1B)),
            ),
          )
        else
          Container(
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
      ],
    );
  }
}
