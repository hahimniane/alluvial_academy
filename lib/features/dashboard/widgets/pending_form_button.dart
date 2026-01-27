import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/shift_form_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Button widget that shows "Fill" if form doesn't exist, or "View" (eye icon) if it does
class PendingFormButton extends StatefulWidget {
  final String shiftId;
  final VoidCallback onFill;
  final Function(String formId, Map<String, dynamic> responses) onView;

  const PendingFormButton({
    super.key,
    required this.shiftId,
    required this.onFill,
    required this.onView,
  });

  @override
  State<PendingFormButton> createState() => _PendingFormButtonState();
}

class _PendingFormButtonState extends State<PendingFormButton> {
  String? _formResponseId;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkFormStatus();
  }

  Future<void> _checkFormStatus() async {
    if (widget.shiftId.isEmpty) {
      setState(() {
        _isChecking = false;
      });
      return;
    }

    try {
      final formId = await ShiftFormService.getFormResponseForShift(widget.shiftId);
      if (mounted) {
        setState(() {
          _formResponseId = formId;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _handleView() async {
    if (_formResponseId == null) return;

    try {
      final formDoc = await FirebaseFirestore.instance
          .collection('form_responses')
          .doc(_formResponseId!)
          .get();

      if (formDoc.exists && mounted) {
        final data = formDoc.data() ?? {};
        final responses = data['responses'] as Map<String, dynamic>? ?? {};
        widget.onView(_formResponseId!, responses);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading form details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_formResponseId != null) {
      // Form exists - show View button with eye icon
      return InkWell(
        onTap: _handleView,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.commonView,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Form doesn't exist - show Fill button
    return InkWell(
      onTap: widget.onFill,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0386FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_document, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context)!.fill,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
