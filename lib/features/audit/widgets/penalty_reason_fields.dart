import 'package:flutter/material.dart';

import '../../../core/constants/penalty_reasons.dart';
import '../../../l10n/app_localizations.dart';

/// Required "Reason" dropdown and a note field for a penalty or deduction.
/// The note is required when the reason is "Other".
class PenaltyReasonFields extends StatelessWidget {
  final String? code;
  final TextEditingController noteController;
  final ValueChanged<String?> onCodeChanged;
  final PenaltyReasonError? error;

  const PenaltyReasonFields({
    super.key,
    required this.code,
    required this.noteController,
    required this.onCodeChanged,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final noteRequired = code == PenaltyReasons.other;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('penalty_reason_dropdown'),
          initialValue: code,
          isExpanded: true,
          hint: Text(l10n.penaltyReasonSelectHint),
          decoration: InputDecoration(
            labelText: l10n.auditReasonLabel,
            errorText: error == PenaltyReasonError.reasonMissing
                ? PenaltyReasons.errorText(l10n, error!)
                : null,
          ),
          items: [
            for (final c in PenaltyReasons.codes)
              DropdownMenuItem(
                value: c,
                child: Text(PenaltyReasons.label(l10n, c)),
              ),
          ],
          onChanged: onCodeChanged,
        ),
        TextField(
          key: const ValueKey('penalty_note_field'),
          controller: noteController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: noteRequired
                ? l10n.penaltyNoteRequiredLabel
                : l10n.penaltyNoteOptionalLabel,
            errorText: error == PenaltyReasonError.noteMissing
                ? PenaltyReasons.errorText(l10n, error!)
                : null,
          ),
        ),
      ],
    );
  }
}
