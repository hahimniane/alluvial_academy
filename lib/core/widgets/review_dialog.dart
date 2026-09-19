import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Reviewing something that went wrong in a class.
///
/// Shared between the two ways a teacher can be missing from a lesson — never
/// arrived, or arrived and dropped out — because it is the same job either
/// way: somebody looked, decided what happened, and recorded what they did
/// about it. One dialog rather than two that drift apart.

/// One thing an administrator can say they did.
class ReviewActionOption {
  final String key;
  final String label;
  final IconData icon;

  const ReviewActionOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

/// What the reviewer decided, on its way back to whoever asked.
class ReviewDraft {
  final List<String> actionKeys;
  final List<String> actionLabels;
  final String note;

  const ReviewDraft({
    required this.actionKeys,
    required this.actionLabels,
    required this.note,
  });
}

/// The actions offered when reviewing an absence.
///
/// Keys are stored and labels are stored beside them, so a review written in
/// one language still reads correctly in another: the key is re-resolved to
/// the reader's own label, and the stored label is the fallback when a key is
/// one this build no longer offers.
List<ReviewActionOption> reviewActionOptions(AppLocalizations l10n) => [
      ReviewActionOption(
        key: 'contacted_teacher',
        label: l10n.noShowReviewActionContactedTeacher,
        icon: Icons.call_outlined,
      ),
      ReviewActionOption(
        key: 'contacted_student_parent',
        label: l10n.noShowReviewActionContactedStudentParent,
        icon: Icons.forum_outlined,
      ),
      ReviewActionOption(
        key: 'confirmed_teacher_late',
        label: l10n.noShowReviewActionConfirmedTeacherLate,
        icon: Icons.person_search_outlined,
      ),
      ReviewActionOption(
        key: 'confirmed_student_late',
        label: l10n.noShowReviewActionConfirmedStudentLate,
        icon: Icons.manage_search_outlined,
      ),
      ReviewActionOption(
        key: 'excused_absence',
        label: l10n.noShowReviewActionExcusedAbsence,
        icon: Icons.event_available_outlined,
      ),
      ReviewActionOption(
        key: 'rescheduled_class',
        label: l10n.noShowReviewActionRescheduledClass,
        icon: Icons.update_outlined,
      ),
      ReviewActionOption(
        key: 'technical_issue_followup',
        label: l10n.noShowReviewActionTechnicalFollowup,
        icon: Icons.support_agent_outlined,
      ),
      ReviewActionOption(
        key: 'payroll_billing_followup',
        label: l10n.noShowReviewActionBillingFollowup,
        icon: Icons.receipt_long_outlined,
      ),
      ReviewActionOption(
        key: 'escalated_to_admin',
        label: l10n.noShowReviewActionEscalatedAdmin,
        icon: Icons.report_problem_outlined,
      ),
      ReviewActionOption(
        key: 'false_alarm',
        label: l10n.noShowReviewActionFalseAlarm,
        icon: Icons.check_circle_outline,
      ),
    ];

/// Ask what happened and what was done about it.
///
/// Returns a [ReviewDraft], or null if the reviewer backed out. Submitting is
/// refused while nothing has been said: a review with no action and no note
/// records that somebody clicked a button, which is worse than no review at
/// all because it looks like a decision.
class ReviewDialog extends StatefulWidget {
  const ReviewDialog({
    super.key,
    required this.subject,
    required this.actions,
  });

  /// What is being reviewed, in the reader's terms — a class and its day.
  final String subject;
  final List<ReviewActionOption> actions;

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final _noteController = TextEditingController();
  final Set<String> _selectedKeys = {};

  bool get _canSubmit =>
      _selectedKeys.isNotEmpty || _noteController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController
      ..removeListener(_onNoteChanged)
      ..dispose();
    super.dispose();
  }

  void _onNoteChanged() => setState(() {});

  void _submit() {
    final selected = widget.actions
        .where((action) => _selectedKeys.contains(action.key))
        .toList(growable: false);
    Navigator.pop(
      context,
      ReviewDraft(
        actionKeys: selected.map((action) => action.key).toList(growable: false),
        actionLabels:
            selected.map((action) => action.label).toList(growable: false),
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.of(context).size.height * 0.86;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.noShowReviewTitle,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                widget.subject,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff64748B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.noShowReviewActionsPrompt,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff334155),
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.actions.map((action) {
                      final selected = _selectedKeys.contains(action.key);
                      return FilterChip(
                        selected: selected,
                        avatar: Icon(action.icon, size: 16),
                        label: Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedKeys.add(action.key);
                            } else {
                              _selectedKeys.remove(action.key);
                            }
                          });
                        },
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.noShowReviewOtherLabel,
                  hintText: l10n.noShowReviewOtherHint,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _canSubmit ? _submit : null,
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: Text(l10n.noShowReviewSubmit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
