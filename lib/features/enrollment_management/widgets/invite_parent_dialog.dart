import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Admin-only dialog to invite or link a parent to an existing enrollment's
/// student account. Calls the `inviteParentForEnrollment` callable.
///
/// [studentUid] is the Auth UID of the already-created student (from the prior
/// Create Account action). The callable will either:
///   - re-use an existing parent by email (status `linked`), or
///   - create a fresh parent auth user + users/* doc and email a password
///     reset link (status `invited`).
class InviteParentDialog extends StatefulWidget {
  final String enrollmentId;
  final String studentUid;
  final String? initialEmail;
  final String? initialFirstName;
  final String? initialLastName;
  final String? initialPhone;
  final String? initialCountryCode;

  const InviteParentDialog({
    super.key,
    required this.enrollmentId,
    required this.studentUid,
    this.initialEmail,
    this.initialFirstName,
    this.initialLastName,
    this.initialPhone,
    this.initialCountryCode,
  });

  @override
  State<InviteParentDialog> createState() => _InviteParentDialogState();
}

class _InviteParentDialogState extends State<InviteParentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _firstNameController =
        TextEditingController(text: widget.initialFirstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.initialLastName ?? '');
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('inviteParentForEnrollment');
      final result = await callable.call<Map<String, dynamic>>({
        'enrollmentId': widget.enrollmentId,
        'studentUid': widget.studentUid,
        'email': _emailController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        if ((widget.initialCountryCode ?? '').isNotEmpty)
          'countryCode': widget.initialCountryCode,
      });

      if (!mounted) return;
      final data = Map<String, dynamic>.from(result.data);
      Navigator.of(context).pop(data);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        l.inviteParentDialogTitle,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.inviteParentDialogSubtitle,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: l.inviteParentEmailLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return l.inviteParentEmailRequired;
                  if (!t.contains('@')) return l.inviteParentEmailInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: l.inviteParentFirstNameLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: l.inviteParentLastNameLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l.inviteParentPhoneLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send, size: 16),
          label: Text(l.inviteParentSendInvite),
        ),
      ],
    );
  }
}
