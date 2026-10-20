import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import '../services/form_review_service.dart';
import '../utils/form_review_status.dart';
import 'form_review_status_badge.dart';

/// The admin's decision on one submitted form, shown under its answers.
///
/// Choosing Accepted or Rejected tells the teacher straight away. The note
/// records what was done ("Issue resolved") so a second leader opening the
/// same form sees it was already handled. Both are read live from the
/// response, so two admins with the form open see each other's changes.
class FormReviewPanel extends StatefulWidget {
  final String responseId;

  const FormReviewPanel({super.key, required this.responseId});

  @override
  State<FormReviewPanel> createState() => _FormReviewPanelState();
}

class _FormReviewPanelState extends State<FormReviewPanel> {
  final _note = TextEditingController();
  final Map<String, String> _names = {};
  String _savedNote = '';
  bool _noteLoaded = false;
  bool _savingStatus = false;
  bool _savingNote = false;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('form_responses')
          .doc(widget.responseId)
          .snapshots();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _resolveName(String uid) async {
    if (uid.isEmpty || _names.containsKey(uid)) return;
    _names[uid] = '';
    final user =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = user.data() ?? const {};
    final name = [data['first_name'], data['last_name']]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    if (mounted) setState(() => _names[uid] = name);
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red : const Color(0xFF059669),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _choose(String status, Map<String, dynamic> submission) async {
    final l10n = AppLocalizations.of(context)!;
    final label = FormReviewStatusBadge.labelFor(context, status);
    setState(() => _savingStatus = true);
    try {
      await FormReviewService.setStatus(widget.responseId, status);
    } catch (_) {
      _snack(l10n.failedToSaveStatusE, error: true);
      if (mounted) setState(() => _savingStatus = false);
      return;
    }
    if (status == FormReviewStatus.accepted ||
        status == FormReviewStatus.rejected) {
      final formTitle = (submission['formTitle'] ??
              submission['formName'] ??
              submission['form_title'] ??
              '')
          .toString();
      final delivery = await FormReviewService.notifySubmitter(
        responseId: widget.responseId,
        submission: submission,
        status: status,
        title: l10n.formDecisionNotificationTitle(label),
        body: l10n.formDecisionNotificationBody(formTitle, label),
      );
      switch (delivery) {
        case FormDecisionDelivery.pushed:
          _snack(l10n.formDecisionNotificationSent);
        case FormDecisionDelivery.visibleOnly:
          _snack(l10n.formDecisionVisibleNoPush);
        case FormDecisionDelivery.failed:
          _snack(l10n.formDecisionNotificationFailed, error: true);
        case FormDecisionDelivery.noTeacher:
          _snack(l10n.formDecisionTeacherMissing, error: true);
      }
    } else {
      _snack(l10n.statusUpdatedToStatus(label));
    }
    if (mounted) setState(() => _savingStatus = false);
  }

  Future<void> _saveNote() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _savingNote = true);
    try {
      await FormReviewService.saveNote(widget.responseId, _note.text);
      _savedNote = _note.text.trim();
      _snack(l10n.noteSavedSuccessfully);
    } catch (_) {
      _snack(l10n.failedToSaveNoteE, error: true);
    }
    if (mounted) setState(() => _savingNote = false);
  }

  String _when(Object? value) {
    final date = value is Timestamp ? value.toDate() : null;
    return date == null ? '' : DateFormat('MMM d, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data == null) return const SizedBox.shrink();

        final status = FormReviewStatus.normalize(data['reviewStatus']);
        final reviewer = (data['reviewedBy'] ?? '').toString();
        final noteAuthor = (data['adminNoteBy'] ?? '').toString();
        final note = (data['adminNote'] ?? '').toString();
        // Take another admin's note as it arrives, unless this admin is
        // halfway through typing their own.
        if (!_noteLoaded || (_note.text.trim() == _savedNote && note != _savedNote)) {
          _note.text = note;
          _savedNote = note;
          _noteLoaded = true;
        }
        _resolveName(reviewer);
        _resolveName(noteAuthor);
        final noteChanged = _note.text.trim() != _savedNote;

        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.formReviewSectionTitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  if (_savingStatus)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final option in FormReviewStatus.options)
                    ChoiceChip(
                      label: Text(FormReviewStatusBadge.labelFor(context, option)),
                      selected: status == option,
                      selectedColor: FormReviewStatusBadge.colorFor(option)
                          .withValues(alpha: 0.15),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: status == option
                            ? FormReviewStatusBadge.colorFor(option)
                            : const Color(0xFF475569),
                      ),
                      onSelected: _savingStatus || status == option
                          ? null
                          : (_) => _choose(option, data),
                    ),
                ],
              ),
              if (status.isNotEmpty && reviewer.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.formReviewedByOn(
                    FormReviewStatusBadge.labelFor(context, status),
                    _names[reviewer]?.isNotEmpty == true
                        ? _names[reviewer]!
                        : l10n.commonUnknown,
                    _when(data['reviewedAt']),
                  ),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                l10n.formAdminNoteLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: l10n.formAdminNoteHint,
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.isNotEmpty && noteAuthor.isNotEmpty
                          ? l10n.formAdminNoteBy(
                              _names[noteAuthor]?.isNotEmpty == true
                                  ? _names[noteAuthor]!
                                  : l10n.commonUnknown,
                              _when(data['adminNoteAt']),
                            )
                          : '',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ),
                  FilledButton(
                    onPressed: noteChanged && !_savingNote ? _saveNote : null,
                    child: Text(l10n.formAdminNoteSave),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
