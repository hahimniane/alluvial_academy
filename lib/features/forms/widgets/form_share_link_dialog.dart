import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Field on a form_templates document: anyone with the form's link can fill
/// it in without an account (served by the getPublicForm /
/// submitPublicFormResponse callables).
const String kFormPublicLinkField = 'public_link_enabled';

const Set<String> _fileFieldTypes = {
  'image_upload',
  'imageUpload',
  'signature',
  'file',
  'file_upload',
  'fileUpload',
};

/// The one link a form is shared by (the website's /form/ page).
String formShareLink(String templateId) =>
    'https://alluwaleducationhub.org/form/?id=${Uri.encodeQueryComponent(templateId)}';

/// Whether any question of the form takes a file (stored as a list or a map).
bool formHasFileQuestions(Object? fields) {
  final values = fields is Map
      ? fields.values
      : fields is List
          ? fields
          : const [];
  return values.any((field) =>
      field is Map && _fileFieldTypes.contains(field['type']?.toString()));
}

/// "Share link": the form's link, a Copy button, and the switch that lets
/// anyone with the link fill it in without an account.
class FormShareLinkDialog extends StatefulWidget {
  final String templateId;
  final String formName;

  const FormShareLinkDialog({
    super.key,
    required this.templateId,
    required this.formName,
  });

  @override
  State<FormShareLinkDialog> createState() => _FormShareLinkDialogState();
}

class _FormShareLinkDialogState extends State<FormShareLinkDialog> {
  bool _saving = false;
  String? _error;

  DocumentReference<Map<String, dynamic>> get _doc => FirebaseFirestore.instance
      .collection('form_templates')
      .doc(widget.templateId);

  Future<void> _setPublic(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _doc.update({
        kFormPublicLinkField: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) setState(() => _error = l10n.formShareLinkSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy(String link) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.formShareLinkCopied),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final link = formShareLink(widget.templateId);
    return AlertDialog(
      title: Text(
        l10n.formShareLinkTitle,
        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 460,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _doc.snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final isPublic = data[kFormPublicLinkField] == true;
            final isActive = data['isActive'] != false;
            final hasFiles = formHasFileQuestions(data['fields']);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.formName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.formShareLinkHint,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    link,
                    style: GoogleFonts.robotoMono(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () => _copy(link),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.formShareLinkCopy),
                  ),
                ),
                const Divider(height: 32),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isPublic,
                  onChanged: _saving || !snapshot.hasData ? null : _setPublic,
                  title: Text(
                    l10n.formShareLinkPublicSwitch,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    isPublic
                        ? l10n.formShareLinkPublicOn
                        : l10n.formShareLinkPublicOff,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                if (isPublic && hasFiles) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.formShareLinkFileNote,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.orange.shade800),
                  ),
                ],
                if (!isActive) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.formShareLinkInactiveNote,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.orange.shade800),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.red.shade700),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
