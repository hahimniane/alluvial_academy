import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/features/shift_management/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/features/shift_management/services/shift_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Shown instead of the delete confirmation when a class has already
/// started. Such a class is a record and can't be deleted; when nobody
/// clocked in it can be cancelled so it stops counting as missed.
/// Returns true when the class was cancelled.
Future<bool> showPastClassDialog(
    BuildContext context, TeachingShift shift) async {
  final cancelled = await showDialog<bool>(
    context: context,
    builder: (context) => _PastClassDialog(shift: shift),
  );
  return cancelled == true;
}

class _PastClassDialog extends StatefulWidget {
  const _PastClassDialog({required this.shift});
  final TeachingShift shift;

  @override
  State<_PastClassDialog> createState() => _PastClassDialogState();
}

class _PastClassDialogState extends State<_PastClassDialog> {
  late final Future<bool> _taught =
      ShiftService.shiftHasClockIn(widget.shift.id).catchError((_) => true);
  bool _busy = false;
  String? _error;

  bool get _alreadyCancelled => widget.shift.status == ShiftStatus.cancelled;

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ShiftService.cancelPastShift(widget.shift);
      if (mounted) Navigator.pop(context, true);
    } on PastShiftCancelRefused {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.pastClassTaught;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.pastClassCancelFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<bool>(
      future: _taught,
      builder: (context, snapshot) {
        final taught = snapshot.data;
        final canCancel = taught == false && !_alreadyCancelled;
        final detail = _alreadyCancelled
            ? l10n.pastClassAlreadyCancelled
            : taught == null
                ? ''
                : taught
                    ? l10n.pastClassTaught
                    : l10n.pastClassNotTaught;
        return AlertDialog(
          title: Text(l10n.pastClassTitle,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pastClassCannotDelete(widget.shift.displayName),
                  style: GoogleFonts.inter()),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(detail,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xff6B7280))),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.red,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: Text(l10n.commonClose,
                  style: GoogleFonts.inter(color: const Color(0xff6B7280))),
            ),
            if (canCancel)
              ElevatedButton(
                onPressed: _busy ? null : _cancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0386FF),
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.cancelThisClass,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
          ],
        );
      },
    );
  }
}
