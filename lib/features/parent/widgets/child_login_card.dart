import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/services/student_credentials_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// What the card shows for the password.
enum ChildPasswordState { hidden, loading, shown, error }

/// The child's login on the parent's child page: Student ID, and the
/// password behind Show / Hide. The password is read from
/// `student_credentials` only when Show is pressed (rules: the student's own
/// guardians and admins), dropped again on Hide, and never logged.
/// Mirrors the web parent area's ChildLoginCard.
class ChildLoginCard extends StatefulWidget {
  final String studentId;

  /// Test seams: load the child's user document and the password.
  final Future<Map<String, dynamic>?> Function(String studentId)? loadStudent;
  final Future<String> Function(String studentId, Map<String, dynamic> data)?
      loadPassword;

  const ChildLoginCard({
    super.key,
    required this.studentId,
    this.loadStudent,
    this.loadPassword,
  });

  @override
  State<ChildLoginCard> createState() => _ChildLoginCardState();
}

class _ChildLoginCardState extends State<ChildLoginCard> {
  Map<String, dynamic>? _student;
  bool _studentLoaded = false;
  ChildPasswordState _state = ChildPasswordState.hidden;
  String _password = '';

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    Map<String, dynamic>? data;
    try {
      data = widget.loadStudent != null
          ? await widget.loadStudent!(widget.studentId)
          : (await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.studentId)
                  .get())
              .data();
    } catch (_) {
      data = null;
    }
    if (!mounted) return;
    setState(() {
      _student = data;
      _studentLoaded = true;
    });
  }

  String get _studentCode {
    final data = _student ?? const {};
    final raw = data['student_code'] ?? data['studentCode'] ?? data['student_id'];
    return raw == null ? '' : raw.toString().trim();
  }

  Future<void> _show() async {
    setState(() => _state = ChildPasswordState.loading);
    try {
      final value = widget.loadPassword != null
          ? await widget.loadPassword!(widget.studentId, _student ?? {})
          : await _readPassword();
      if (!mounted) return;
      setState(() {
        _password = value;
        _state = ChildPasswordState.shown;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _password = '';
        _state = ChildPasswordState.error;
      });
    }
  }

  /// The store first (a permission error is reported, not hidden), then the
  /// legacy copy on the user document.
  Future<String> _readPassword() async {
    final snap = await FirebaseFirestore.instance
        .collection(StudentCredentialsService.collection)
        .doc(widget.studentId)
        .get();
    return StudentCredentialsService.pickPassword(snap.data(), _student ?? {});
  }

  void _hide() => setState(() {
        _password = '';
        _state = ChildPasswordState.hidden;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final code = _studentCode;
    final shown = _state == ChildPasswordState.shown;
    final passwordText = switch (_state) {
      ChildPasswordState.shown => _password.isEmpty ? '—' : _password,
      ChildPasswordState.loading => '…',
      _ => '••••••••',
    };

    return Container(
      key: const Key('child_login_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0386FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.key_rounded,
                    size: 20, color: Color(0xFF0386FF)),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.parentChildLoginTitle,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_studentLoaded)
            const LinearProgressIndicator(minHeight: 2)
          else if (code.isEmpty)
            _note(l10n.parentChildLoginNoStudentId, const Color(0xFF6B7280))
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _field(l10n.parentChildLoginStudentId, code)),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    l10n.parentChildLoginPassword,
                    passwordText,
                    valueKey: const Key('child_password'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const Key('child_password_toggle'),
                  onPressed: _state == ChildPasswordState.loading
                      ? null
                      : (shown ? _hide : _show),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    shown ? l10n.parentChildLoginHide : l10n.parentChildLoginShow,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (shown && _password.isEmpty)
              _note(l10n.parentChildLoginNoPassword, const Color(0xFFB45309)),
            if (_state == ChildPasswordState.error)
              _note(l10n.parentChildLoginCannotRead, const Color(0xFFDC2626)),
            const SizedBox(height: 8),
            Text(
              l10n.parentChildLoginWhere,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(String label, String value, {Key? valueKey}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          key: valueKey,
          style: GoogleFonts.robotoMono(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _note(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );
}
