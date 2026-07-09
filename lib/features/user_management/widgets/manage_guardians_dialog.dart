import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import '../services/guardian_service.dart';

bool _isMinorBlock(Object error) {
  if (error is! FirebaseFunctionsException) return false;
  final details = error.details;
  if (details is Map && details['reason'] == 'last_guardian_minor') {
    return true;
  }
  return (error.message ?? '').toLowerCase().contains('minor');
}

Future<bool> _confirmAdultOverride(
  BuildContext context, {
  required String studentName,
  required String guardianName,
}) async {
  final l = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            l.unlinkGuardianAdultOverrideTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: Text(
            l.unlinkGuardianAdultOverrideBody(studentName, guardianName),
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.unlinkGuardianAdultOverrideAction),
            ),
          ],
        ),
      ) ??
      false;
}

/// Admin dialog that lists the guardians linked to a student and lets the admin
/// unlink any of them. The inverse of the "Invite Parent" flow.
class ManageGuardiansDialog extends StatefulWidget {
  final String studentUid;
  final String studentName;

  const ManageGuardiansDialog({
    super.key,
    required this.studentUid,
    required this.studentName,
  });

  @override
  State<ManageGuardiansDialog> createState() => _ManageGuardiansDialogState();
}

class _ManageGuardiansDialogState extends State<ManageGuardiansDialog> {
  bool _loading = true;
  bool _error = false;
  bool _changed = false;
  String? _unlinkingId;
  List<GuardianLink> _guardians = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final guardians =
          await GuardianService.getStudentGuardians(widget.studentUid);
      if (!mounted) return;
      setState(() {
        _guardians = guardians;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _confirmUnlink(GuardianLink guardian) async {
    final l = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l.unlinkGuardianConfirmTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.unlinkGuardianConfirmBody(guardian.name, widget.studentName),
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l.unlinkGuardianReasonLabel,
                hintText: l.unlinkGuardianReasonHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.unlinkGuardianConfirmAction),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _performUnlink(guardian, reasonController.text);
  }

  Future<void> _performUnlink(
    GuardianLink guardian,
    String reason, {
    bool convertStudentToAdult = false,
  }) async {
    final l = AppLocalizations.of(context)!;
    setState(() => _unlinkingId = guardian.id);
    try {
      await GuardianService.unlinkGuardian(
        studentUid: widget.studentUid,
        parentUid: guardian.id,
        reason: reason,
        convertStudentToAdult: convertStudentToAdult,
      );
      if (!mounted) return;
      _changed = true;
      setState(() {
        _guardians = _guardians.where((g) => g.id != guardian.id).toList();
        _unlinkingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.unlinkGuardianSuccess),
          backgroundColor: const Color(0xff16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _unlinkingId = null);
      if (_isMinorBlock(e)) {
        final shouldConvert = await _confirmAdultOverride(
          context,
          studentName: widget.studentName,
          guardianName: guardian.name,
        );
        if (!mounted) return;
        if (shouldConvert && mounted) {
          await _performUnlink(
            guardian,
            reason,
            convertStudentToAdult: true,
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isMinorBlock(e)
                ? l.unlinkGuardianMinorBlocked
                : l.unlinkGuardianError,
          ),
          backgroundColor: const Color(0xffDC2626),
          duration: _isMinorBlock(e)
              ? const Duration(seconds: 6)
              : const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        l.manageGuardiansTitle,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.manageGuardiansSubtitle(widget.studentName),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            _buildBody(l),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          child: Text(l.commonCancel),
        ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xffDC2626), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.manageGuardiansLoadError,
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _load,
              child: Text(l.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_guardians.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            l.manageGuardiansEmpty,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
      );
    }
    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _guardians.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _buildGuardianTile(l, _guardians[i]),
      ),
    );
  }

  Widget _buildGuardianTile(AppLocalizations l, GuardianLink guardian) {
    final unlinking = _unlinkingId == guardian.id;
    final subtitle = [guardian.email, guardian.phone]
        .where((v) => v != null && v.trim().isNotEmpty)
        .join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xff3B82F6).withValues(alpha: 0.1),
        child: Text(
          guardian.name.isNotEmpty ? guardian.name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            color: const Color(0xff3B82F6),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        guardian.name,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, style: GoogleFonts.inter(fontSize: 12)),
      trailing: unlinking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton.icon(
              onPressed:
                  _unlinkingId == null ? () => _confirmUnlink(guardian) : null,
              icon: const Icon(Icons.link_off, size: 16),
              label: Text(l.unlink),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xffDC2626),
              ),
            ),
    );
  }
}

/// Admin dialog that lists students linked to a parent and lets the admin sever
/// a wrong parent/student association with the same server-side guardrails.
class ManageParentStudentsDialog extends StatefulWidget {
  final String parentUid;
  final String parentName;

  const ManageParentStudentsDialog({
    super.key,
    required this.parentUid,
    required this.parentName,
  });

  @override
  State<ManageParentStudentsDialog> createState() =>
      _ManageParentStudentsDialogState();
}

class _ManageParentStudentsDialogState
    extends State<ManageParentStudentsDialog> {
  bool _loading = true;
  bool _error = false;
  bool _changed = false;
  String? _unlinkingId;
  List<ParentStudentLink> _students = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final students =
          await GuardianService.getParentStudents(widget.parentUid);
      if (!mounted) return;
      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _confirmUnlink(ParentStudentLink student) async {
    final l = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l.unlinkGuardianConfirmTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.unlinkGuardianConfirmBody(widget.parentName, student.name),
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l.unlinkGuardianReasonLabel,
                hintText: l.unlinkGuardianReasonHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.unlinkGuardianConfirmAction),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _performUnlink(student, reasonController.text);
  }

  Future<void> _performUnlink(
    ParentStudentLink student,
    String reason, {
    bool convertStudentToAdult = false,
  }) async {
    final l = AppLocalizations.of(context)!;
    setState(() => _unlinkingId = student.id);
    try {
      await GuardianService.unlinkGuardian(
        studentUid: student.id,
        parentUid: widget.parentUid,
        reason: reason,
        convertStudentToAdult: convertStudentToAdult,
      );
      if (!mounted) return;
      _changed = true;
      setState(() {
        _students = _students.where((s) => s.id != student.id).toList();
        _unlinkingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.unlinkGuardianSuccess),
          backgroundColor: const Color(0xff16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _unlinkingId = null);
      if (_isMinorBlock(e)) {
        final shouldConvert = await _confirmAdultOverride(
          context,
          studentName: student.name,
          guardianName: widget.parentName,
        );
        if (!mounted) return;
        if (shouldConvert && mounted) {
          await _performUnlink(
            student,
            reason,
            convertStudentToAdult: true,
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isMinorBlock(e)
                ? l.unlinkGuardianMinorBlocked
                : l.unlinkGuardianError,
          ),
          backgroundColor: const Color(0xffDC2626),
          duration: _isMinorBlock(e)
              ? const Duration(seconds: 6)
              : const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        l.manageParentStudentsTitle,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.manageParentStudentsSubtitle(widget.parentName),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            _buildBody(l),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          child: Text(l.commonClose),
        ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xffDC2626), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.manageParentStudentsLoadError,
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _load,
              child: Text(l.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_students.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            l.manageParentStudentsEmpty,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
      );
    }
    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _students.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _buildStudentTile(l, _students[i]),
      ),
    );
  }

  Widget _buildStudentTile(AppLocalizations l, ParentStudentLink student) {
    final unlinking = _unlinkingId == student.id;
    final subtitleParts = <String>[
      if ((student.email ?? '').trim().isNotEmpty) student.email!.trim(),
      if ((student.studentCode ?? '').trim().isNotEmpty)
        l.studentIdStudentcode(student.studentCode!.trim()),
      if (student.isAdultStudent) l.adultStudent,
    ];
    final subtitle = subtitleParts.join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xff3B82F6).withValues(alpha: 0.1),
        child: Text(
          student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
          style: GoogleFonts.inter(
            color: const Color(0xff3B82F6),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        student.name,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, style: GoogleFonts.inter(fontSize: 12)),
      trailing: unlinking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton.icon(
              onPressed:
                  _unlinkingId == null ? () => _confirmUnlink(student) : null,
              icon: const Icon(Icons.link_off, size: 16),
              label: Text(l.unlink),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xffDC2626),
              ),
            ),
    );
  }
}
