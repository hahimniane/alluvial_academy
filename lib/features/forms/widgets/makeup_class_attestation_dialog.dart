import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:alluwalacademyadmin/core/utils/makeup_class_attestation.dart';

/// Collects structured makeup fields for form-only (missed / no timesheet) submissions.
Future<Map<String, dynamic>?> showMakeupClassAttestationDialog(
  BuildContext context,
) async {
  final loc = AppLocalizations.of(context)!;
  final occurredAtCtrl = TextEditingController();
  final startCtrl = TextEditingController();
  final endCtrl = TextEditingController();
  final hostCtrl = TextEditingController();
  final otherCtrl = TextEditingController();
  final studentsCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  String deliveryMode = 'zoom';

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: const OutlineInputBorder(),
      );

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final maxW = math.min(
            400.0,
            MediaQuery.sizeOf(ctx).width - 24,
          );
          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            title: Text(
              loc.makeupAttestationTitle,
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            content: SizedBox(
              width: maxW,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      loc.makeupAttestationSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: occurredAtCtrl,
                      decoration: _dec(loc.makeupFieldOccurredAt),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startCtrl,
                            decoration: _dec(loc.makeupFieldStartTime),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: endCtrl,
                            decoration: _dec(loc.makeupFieldEndTime),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.makeupFieldDeliveryMode,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(loc.makeupDeliveryZoom),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          selected: deliveryMode == 'zoom',
                          onSelected: (_) =>
                              setLocal(() => deliveryMode = 'zoom'),
                        ),
                        ChoiceChip(
                          label: Text(loc.makeupDeliveryLivekit),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          selected: deliveryMode == 'livekit',
                          onSelected: (_) =>
                              setLocal(() => deliveryMode = 'livekit'),
                        ),
                        ChoiceChip(
                          label: Text(loc.makeupDeliveryOther),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          selected: deliveryMode == 'other',
                          onSelected: (_) =>
                              setLocal(() => deliveryMode = 'other'),
                        ),
                      ],
                    ),
                    if (deliveryMode == 'zoom' ||
                        deliveryMode == 'livekit') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: hostCtrl,
                        decoration: _dec(loc.makeupFieldZoomHost),
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                    if (deliveryMode == 'other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherCtrl,
                        decoration: _dec(loc.makeupFieldOtherDetail),
                        textInputAction: TextInputAction.next,
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: studentsCtrl,
                      decoration: _dec(loc.makeupFieldStudentsPresent),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      decoration: _dec(loc.makeupFieldNotesOptional),
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.commonCancel),
              ),
              TextButton(
                onPressed: () {
                  final host = hostCtrl.text.trim();
                  final other = otherCtrl.text.trim();
                  final out = <String, dynamic>{
                    MakeupClassAttestation.keyOccurredAt:
                        occurredAtCtrl.text.trim(),
                    MakeupClassAttestation.keyStartTime: startCtrl.text.trim(),
                    MakeupClassAttestation.keyEndTime: endCtrl.text.trim(),
                    MakeupClassAttestation.keyDeliveryMode: deliveryMode,
                    MakeupClassAttestation.keyZoomHost: host,
                    MakeupClassAttestation.keyOtherDetail: other,
                    MakeupClassAttestation.keyStudentsPresent:
                        studentsCtrl.text.trim(),
                    MakeupClassAttestation.keyNotes: notesCtrl.text.trim(),
                  };
                  if (!MakeupClassAttestation.responsesHaveRequiredKeys(out)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(loc.commonRequired)),
                    );
                    return;
                  }
                  Navigator.pop(ctx, out);
                },
                child: Text(loc.makeupSubmitContinue),
              ),
            ],
          );
        },
      );
    },
  );
}
