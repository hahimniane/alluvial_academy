import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';
import 'package:alluwalacademyadmin/features/audit/services/teacher_audit_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

import 'audit_detail_panel.dart';

Future<TeacherAuditFull?> openTeacherDisputeResolutionDialog(
  BuildContext context,
  TeacherAuditFull audit, {
  required bool readOnly,
}) {
  return showDialog<TeacherAuditFull>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => TeacherDisputeResolutionDialog(
      audit: audit,
      readOnly: readOnly,
    ),
  );
}

class TeacherDisputeResolutionDialog extends StatefulWidget {
  final TeacherAuditFull audit;
  final bool readOnly;

  const TeacherDisputeResolutionDialog({
    super.key,
    required this.audit,
    required this.readOnly,
  });

  @override
  State<TeacherDisputeResolutionDialog> createState() =>
      _TeacherDisputeResolutionDialogState();
}

class _TeacherDisputeResolutionDialogState
    extends State<TeacherDisputeResolutionDialog> {
  late final TextEditingController _responseCtrl;
  bool _resolutionAccepted = true;
  bool _clearTeacherAck = false;
  bool _notifyTeacher = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing =
        widget.audit.reviewChain?.teacherDispute?.adminResponse ?? '';
    _responseCtrl = TextEditingController(text: existing);
    _responseCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _responseCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final updated = await TeacherAuditService.resolveTeacherDispute(
        auditId: widget.audit.id,
        resolutionStatus: _resolutionAccepted ? 'accepted' : 'rejected',
        adminResponse: text,
        clearTeacherAcknowledgement: _clearTeacherAck,
        notifyTeacher: _notifyTeacher,
      );
      if (!mounted) return;
      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.adminAuditResolveTeacherDisputeSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, updated);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminAuditResolveTeacherDisputeFailed),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final d = widget.audit.reviewChain?.teacherDispute;
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    if (d == null) {
      return AlertDialog(
        title: Text(l10n.adminAuditResolveTeacherDisputeTitle),
        content: Text(l10n.adminAuditResolveTeacherDisputeFailed),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
        ],
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.readOnly
            ? l10n.adminAuditViewTeacherDispute
            : l10n.adminAuditResolveTeacherDisputeTitle,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.teacherAuditDisputeFieldLabel}: ${AuditDetailFullPanel.disputeFieldDisplayLabel(l10n, d.field)}',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(d.reason,
                  style: GoogleFonts.inter(fontSize: 13, height: 1.35)),
              if (d.suggestedValue != null &&
                  '${d.suggestedValue}'.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.adminAuditTeacherDisputeSuggestedValue,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700),
                ),
                Text('${d.suggestedValue}',
                    style: GoogleFonts.inter(fontSize: 13)),
              ],
              if (d.resolvedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  DateFormat.yMMMd(localeTag).add_jm().format(d.resolvedAt!),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
              if (d.adminResponse.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.adminResponse,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(d.adminResponse, style: GoogleFonts.inter(fontSize: 13)),
              ],
              if (!widget.readOnly && d.status == 'pending') ...[
                const SizedBox(height: 16),
                Text(
                  l10n.adminAuditResolveTeacherDisputeResponseLabel,
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(l10n.adminAuditResolveTeacherDisputeAccept),
                      selected: _resolutionAccepted,
                      onSelected: (_) =>
                          setState(() => _resolutionAccepted = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(l10n.adminAuditResolveTeacherDisputeReject),
                      selected: !_resolutionAccepted,
                      onSelected: (_) =>
                          setState(() => _resolutionAccepted = false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _responseCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText:
                        l10n.adminAuditResolveTeacherDisputeResponseLabel,
                    hintText: l10n.adminAuditResolveTeacherDisputeResponseHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _clearTeacherAck,
                  onChanged: (v) =>
                      setState(() => _clearTeacherAck = v ?? false),
                  title: Text(
                    l10n.adminAuditResolveTeacherDisputeRequireReAck,
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _notifyTeacher,
                  onChanged: (v) => setState(() => _notifyTeacher = v ?? true),
                  title: Text(
                    l10n.adminAuditResolveTeacherDisputeNotifyTeacher,
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child:
              Text(widget.readOnly ? l10n.adminAuditClose : l10n.commonCancel),
        ),
        if (!widget.readOnly && d.status == 'pending')
          ElevatedButton(
            onPressed: _submitting || _responseCtrl.text.trim().isEmpty
                ? null
                : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.adminAuditResolveTeacherDisputeSubmit),
          ),
      ],
    );
  }
}
