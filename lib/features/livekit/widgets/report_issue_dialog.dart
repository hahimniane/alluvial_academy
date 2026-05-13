import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/features/livekit/services/call_diagnostics_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ReportIssueResult {
  final List<String> categories;
  final String? note;
  const ReportIssueResult({required this.categories, this.note});
}

/// Dialog that lets a participant report one or more issues during a call.
///
/// [prefilledCategories] is set when the user is responding to a peer's
/// broadcast and we want the broadcaster's categories preselected. The user
/// is free to add or remove categories before submitting.
Future<ReportIssueResult?> showReportIssueDialog({
  required BuildContext context,
  Set<String>? prefilledCategories,
  String? promptMessage,
}) {
  return showDialog<ReportIssueResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ReportIssueDialog(
      prefilledCategories: prefilledCategories,
      promptMessage: promptMessage,
    ),
  );
}

class _ReportIssueDialog extends StatefulWidget {
  final Set<String>? prefilledCategories;
  final String? promptMessage;

  const _ReportIssueDialog({this.prefilledCategories, this.promptMessage});

  @override
  State<_ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<_ReportIssueDialog> {
  final Set<String> _selected = <String>{};
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCategories != null) {
      _selected.addAll(widget.prefilledCategories!);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.reportIssueDialogTitle),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.promptMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.promptMessage!,
                          style: TextStyle(color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                l10n.reportIssueCategoryPrompt,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.reportIssueCategoryHint,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CallIssueCategory.all.map((key) {
                  final selected = _selected.contains(key);
                  return FilterChip(
                    label: Text(_categoryLabel(l10n, key)),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selected.add(key);
                        } else {
                          _selected.remove(key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.reportIssueNoteLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: l10n.reportIssueNoteHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () {
                  Navigator.of(context).pop(
                    ReportIssueResult(
                      categories: _orderedSelection(),
                      note: _noteController.text.trim().isEmpty
                          ? null
                          : _noteController.text.trim(),
                    ),
                  );
                },
          child: Text(l10n.reportIssueSubmit),
        ),
      ],
    );
  }

  /// Return the user's selection in the canonical category order so peers
  /// receive the same ordering and the Firestore docs are easy to scan.
  List<String> _orderedSelection() {
    return CallIssueCategory.all.where(_selected.contains).toList();
  }
}

String _categoryLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case CallIssueCategory.audioCantHearOthers:
      return l10n.reportIssueCategoryAudioCantHearOthers;
    case CallIssueCategory.audioOthersCantHearMe:
      return l10n.reportIssueCategoryAudioOthersCantHearMe;
    case CallIssueCategory.audioChoppyOrEcho:
      return l10n.reportIssueCategoryAudioChoppyOrEcho;
    case CallIssueCategory.videoCantSeeOthers:
      return l10n.reportIssueCategoryVideoCantSeeOthers;
    case CallIssueCategory.videoOthersCantSeeMe:
      return l10n.reportIssueCategoryVideoOthersCantSeeMe;
    case CallIssueCategory.videoFrozenOrLaggy:
      return l10n.reportIssueCategoryVideoFrozenOrLaggy;
    case CallIssueCategory.gotDisconnected:
      return l10n.reportIssueCategoryGotDisconnected;
    case CallIssueCategory.screenShareIssue:
      return l10n.reportIssueCategoryScreenShareIssue;
    case CallIssueCategory.whiteboardOrChatIssue:
      return l10n.reportIssueCategoryWhiteboardOrChatIssue;
    case CallIssueCategory.other:
    default:
      return l10n.reportIssueCategoryOther;
  }
}

/// Public helper so peer-prompt UI can show the same label.
String reportIssueCategoryLabel(BuildContext context, String key) {
  return _categoryLabel(AppLocalizations.of(context)!, key);
}

/// Joins multiple category keys into a single localized, comma-separated
/// string suitable for embedding in a peer-broadcast banner.
String reportIssueCategoriesJoined(
    BuildContext context, List<String> keys) {
  if (keys.isEmpty) return '';
  final l10n = AppLocalizations.of(context)!;
  return keys.map((k) => _categoryLabel(l10n, k)).join(', ');
}
