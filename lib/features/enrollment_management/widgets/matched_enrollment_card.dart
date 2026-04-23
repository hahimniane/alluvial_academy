import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/models/enrollment_request.dart';
import '../../../core/models/employee_model.dart';
import '../../dashboard/services/job_board_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../shift_management/widgets/create_shift_dialog.dart';
import 'enrollment_card.dart';
import 'invite_parent_dialog.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Card for enrollments in `matched` status (teacher accepted).
/// Replaces the old FilledOpportunitiesScreen cards inline in the pipeline.
class MatchedEnrollmentCard extends StatefulWidget {
  final EnrollmentRequest enrollment;

  const MatchedEnrollmentCard({super.key, required this.enrollment});

  @override
  State<MatchedEnrollmentCard> createState() => _MatchedEnrollmentCardState();
}

class _MatchedEnrollmentCardState extends State<MatchedEnrollmentCard> {
  bool _isLoadingTeacher = false;
  bool _isCreatingStudent = false;
  bool _isRevoking = false;
  bool _isClosing = false;
  bool _studentCreatedSuccessfully = false;
  String? _teacherName;
  String? _teacherEmail;
  String? _teacherTimezone;
  String? _jobId;
  Map<String, String>? _teacherSelectedTimes;
  bool _tzInitialized = false;

  /// Auth UID of the student account (after Create Account) or loaded from
  /// metadata.studentUserId if a previous session already created it. Needed
  /// for the Invite Parent action.
  String? _studentUid;

  /// One of: 'linked' (parent account linked), 'invited' (invite sent, awaiting
  /// password setup), or null (no parent yet).
  String? _parentInviteStatus;

  @override
  void initState() {
    super.initState();
    _loadMatchedData();
  }

  Future<void> _loadMatchedData() async {
    if (!_tzInitialized) {
      tz.initializeTimeZones();
      _tzInitialized = true;
    }
    final e = widget.enrollment;
    if (e.id == null) return;

    // Read fresh enrollment doc to get metadata.matchedTeacherId and metadata.jobId
    try {
      final doc = await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(e.id)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data() ?? const <String, dynamic>{};
      final metadata = (data['metadata'] as Map<String, dynamic>?) ?? {};
      final contact = (data['contact'] as Map<String, dynamic>?) ?? {};
      final teacherId = metadata['matchedTeacherId'] as String?;
      _jobId = metadata['jobId'] as String?;

      // Pick up a previously-created student UID (if any) so the Invite Parent
      // action is available on card re-renders.
      _studentUid = metadata['studentUserId'] as String?;
      if (_studentUid != null && _studentUid!.isNotEmpty) {
        _studentCreatedSuccessfully = true;
      }
      // Parent link / invite status.
      final rawStatus = metadata['parentInviteStatus'] as String?;
      if (rawStatus == 'linked' || rawStatus == 'invited') {
        _parentInviteStatus = rawStatus;
      } else if ((contact['guardianId'] as String?)?.isNotEmpty == true) {
        _parentInviteStatus = 'linked';
      }

      // Load teacher selected times from job_board doc
      if (_jobId != null) {
        final jobDoc = await FirebaseFirestore.instance
            .collection('job_board')
            .doc(_jobId)
            .get();
        if (jobDoc.exists && mounted) {
          final jobData = jobDoc.data() ?? {};
          final raw = jobData['teacherSelectedTimes'];
          if (raw is Map) {
            _teacherSelectedTimes = Map<String, String>.from(raw);
          }
        }
      }

      if (teacherId != null) {
        setState(() => _isLoadingTeacher = true);
        final teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .get();
        if (teacherDoc.exists && mounted) {
          final data = teacherDoc.data() as Map<String, dynamic>;
          _teacherName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
          _teacherEmail = data['e-mail'] as String?;
          _teacherTimezone = data['timezone'] as String? ?? 'UTC';
        }
      }
    } catch (e) {
      AppLogger.error('Error loading matched data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTeacher = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.enrollment;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff10B981), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xffECFDF5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xff10B981)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: Color(0xff059669)),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)?.matched ?? 'MATCHED',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff065F46),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, h:mm a').format(e.submittedAt),
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xff64748B)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xffEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Color(0xff3B82F6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.studentName ?? 'Student',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              e.programTitle ?? e.subject,
                              if (e.gradeLevel.isNotEmpty) e.gradeLevel,
                              if (e.sessionDuration != null) e.sessionDuration,
                              if (e.classType != null) e.classType,
                            ].whereType<String>().join(' • '),
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                EnrollmentSchedulingChips(enrollment: e),

                // Teacher's selected times
                if (_teacherSelectedTimes != null && _teacherSelectedTimes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xffD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xff10B981)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: Color(0xff059669)),
                            const SizedBox(width: 6),
                            Text(
                              "Teacher's Selected Schedule:",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff065F46),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ..._teacherSelectedTimes!.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(left: 20, top: 2),
                          child: Text(
                            '${entry.key}: ${entry.value}',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff047857)),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Teacher info
                _isLoadingTeacher
                    ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffFDBA74)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.school, color: Color(0xffEA580C), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _teacherName ?? AppLocalizations.of(context)!.commonUnknownTeacher,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xff1E293B),
                                    ),
                                  ),
                                  if (_teacherTimezone != null)
                                    Text(
                                      _teacherTimezone!,
                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff64748B)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                const SizedBox(height: 12),

                // Activity history (reuses EnrollmentCard's static parser)
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                  future: e.id != null
                      ? FirebaseFirestore.instance.collection('enrollments').doc(e.id).get()
                      : Future.value(null),
                  builder: (context, snap) {
                    if (!snap.hasData || snap.data == null || !snap.data!.exists) {
                      return const SizedBox.shrink();
                    }
                    final metadata = (snap.data!.data()?['metadata'] as Map<String, dynamic>?) ?? {};
                    final actions = EnrollmentCard.parseActionHistory(metadata);
                    if (actions.isEmpty) return const SizedBox.shrink();
                    return _buildActionHistoryWidget(actions);
                  },
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Actions row 1: Revoke + Close
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isRevoking || _isClosing) ? null : _revokeAcceptance,
                        icon: _isRevoking
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                            : const Icon(Icons.undo, size: 16, color: Colors.red),
                        label: Text(
                          _isRevoking ? 'Revoking...' : 'Revoke & Re-broadcast',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.red, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isRevoking || _isClosing) ? null : _closeJob,
                        icon: _isClosing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.archive_outlined, size: 16, color: Color(0xff4B5563)),
                        label: Text(
                          _isClosing ? 'Closing...' : 'Archive (close)',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xff4B5563), fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xff4B5563)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Actions row 2: Create Account + Finalize Schedule
                Row(
                  children: [
                    Expanded(
                      child: _studentCreatedSuccessfully
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xffD1FAE5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xff10B981)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xff059669), size: 16),
                                  const SizedBox(width: 6),
                                  Text('Account Created', style: GoogleFonts.inter(color: const Color(0xff059669), fontWeight: FontWeight.w600, fontSize: 12)),
                                ],
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: _isCreatingStudent ? null : _createStudentAccount,
                              icon: _isCreatingStudent
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.person_add_outlined, size: 16),
                              label: Text('Create Account', style: GoogleFonts.inter(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _createShift,
                        icon: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 16),
                        label: Text(
                          AppLocalizations.of(context)!.finalizeSchedule,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),

                // Actions row 3: Invite Parent + status chip
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildParentStatusChip(context),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_studentUid == null || _studentUid!.isEmpty)
                            ? null
                            : _openInviteParentDialog,
                        icon: const Icon(Icons.family_restroom, size: 16),
                        label: Text(
                          AppLocalizations.of(context)!.inviteParentActionLabel,
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentStatusChip(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final Color bg;
    final Color fg;
    final IconData icon;
    final String label;
    switch (_parentInviteStatus) {
      case 'linked':
        bg = const Color(0xffD1FAE5);
        fg = const Color(0xff065F46);
        icon = Icons.verified_user;
        label = l.inviteParentChipLinked;
        break;
      case 'invited':
        bg = const Color(0xffFEF3C7);
        fg = const Color(0xff92400E);
        icon = Icons.mark_email_read_outlined;
        label = l.inviteParentChipInvited;
        break;
      default:
        bg = const Color(0xffF1F5F9);
        fg = const Color(0xff475569);
        icon = Icons.person_off_outlined;
        label = l.inviteParentChipMissing;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInviteParentDialog() async {
    final e = widget.enrollment;
    if (_studentUid == null || _studentUid!.isEmpty || e.id == null) return;

    final initialFirst = (e.parentName ?? '').trim().split(RegExp(r'\s+'));
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => InviteParentDialog(
        enrollmentId: e.id!,
        studentUid: _studentUid!,
        initialEmail: e.email,
        initialFirstName:
            initialFirst.isNotEmpty ? initialFirst.first : null,
        initialLastName: initialFirst.length > 1
            ? initialFirst.sublist(1).join(' ')
            : null,
        initialPhone: e.phoneNumber,
        initialCountryCode: e.countryCode,
      ),
    );

    if (!mounted || result == null) return;
    final status = result['status']?.toString();
    setState(() {
      if (status == 'linked' || status == 'invited') {
        _parentInviteStatus = status;
      }
    });

    final l = AppLocalizations.of(context)!;
    final String msg;
    if (status == 'linked') {
      msg = l.inviteParentSuccessLinked;
    } else if (result['inviteSent'] == true) {
      msg = l.inviteParentSuccessInvited;
    } else {
      msg = l.inviteParentSuccessInvitedNoEmail;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  Widget _buildActionHistoryWidget(List<Map<String, dynamic>> actions) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 16, color: Color(0xff64748B)),
              const SizedBox(width: 6),
              Text('Activity History', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xff475569))),
            ],
          ),
          const SizedBox(height: 8),
          ...actions.map((action) {
            final timestamp = action['at'] as Timestamp?;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: (action['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(action['icon'] as IconData, size: 14, color: action['color'] as Color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action['action'] as String, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xff1E293B))),
                        Text(
                          'by ${action['by']}${timestamp != null ? ' • ${DateFormat('MMM d, h:mm a').format(timestamp.toDate())}' : ''}',
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xff64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _revokeAcceptance() async {
    if (_jobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No job ID found for this enrollment.'), backgroundColor: Colors.red),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke acceptance?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'This will remove the match with ${_teacherName ?? "the teacher"} and make this opportunity available again.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRevoking = true);
    try {
      await JobBoardService().adminRevokeAcceptance(_jobId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acceptance revoked. Job re-broadcast for other teachers.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }

  Future<void> _closeJob() async {
    if (_jobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No job ID found for this enrollment.'), backgroundColor: Colors.red),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close without re-broadcasting?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'This opportunity will be closed and will not be offered to teachers again.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isClosing = true);
    try {
      await JobBoardService().adminCloseJob(_jobId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opportunity closed.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  Future<void> _createStudentAccount() async {
    if (_studentCreatedSuccessfully) return;
    final e = widget.enrollment;

    setState(() => _isCreatingStudent = true);
    try {
      final enrollmentDoc = await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(e.id)
          .get();
      if (!enrollmentDoc.exists) throw Exception('Enrollment not found');

      final enrollmentData = enrollmentDoc.data()!;
      final contact = enrollmentData['contact'] as Map<String, dynamic>? ?? {};
      final studentDoc =
          enrollmentData['student'] as Map<String, dynamic>? ?? {};
      final metadata = enrollmentData['metadata'] as Map<String, dynamic>? ?? {};

      // Prefer the firstName/lastName stored on the student subdoc at
      // submission time; fall back to splitting studentName, then to defaults.
      String firstName = (studentDoc['firstName'] as String?)?.trim() ?? '';
      String lastName = (studentDoc['lastName'] as String?)?.trim() ?? '';

      if (firstName.isEmpty || lastName.isEmpty) {
        final fullName = (e.studentName ?? studentDoc['name'] ?? '').toString().trim();
        if (fullName.isNotEmpty) {
          final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
          if (firstName.isEmpty && parts.isNotEmpty) firstName = parts.first;
          if (lastName.isEmpty && parts.length > 1) lastName = parts.sublist(1).join(' ');
        }
      }
      if (firstName.isEmpty) firstName = 'Student';
      if (lastName.isEmpty) lastName = 'Unknown';

      // Only pass an email for adult students. For minors, the contact email
      // belongs to the parent and must NOT be used as the student's auth email.
      // Leaving `email` null causes createStudentAccount to generate an alias
      // email (e.g. yyyy@alluwaleducationhub.org) from the student_code.
      final isAdult = e.isAdult || (metadata['isAdult'] == true);
      final String? studentEmail = isAdult
          ? (contact['email'] as String?)?.trim()
          : null;

      final studentData = {
        'firstName': firstName,
        'lastName': lastName,
        'isAdultStudent': isAdult,
        if (studentEmail != null && studentEmail.isNotEmpty)
          'email': studentEmail,
        'phoneNumber': contact['phone'],
        'guardianIds':
            contact['guardianId'] != null ? [contact['guardianId']] : [],
      };

      final callable = FirebaseFunctions.instance.httpsCallable('createStudentAccount');
      final result = await callable.call(studentData);

      // Capture the newly-created student auth UID so the Invite Parent action
      // has a target. Also persist it on the enrollment doc for future sessions.
      final newStudentUid = result.data['studentId']?.toString();
      if (newStudentUid != null && newStudentUid.isNotEmpty) {
        _studentUid = newStudentUid;
        try {
          await FirebaseFirestore.instance
              .collection('enrollments')
              .doc(e.id)
              .set({
            'metadata': {
              'studentUserId': newStudentUid,
              'studentAccountCreatedAt':
                  FieldValue.serverTimestamp(),
            },
          }, SetOptions(merge: true));
        } catch (persistErr) {
          AppLogger.error(
              'Failed to persist studentUserId on enrollment: $persistErr');
        }
      }

      if (mounted) {
        final studentCode = result.data['studentCode']?.toString() ?? '';
        setState(() => _studentCreatedSuccessfully = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.studentAccountCreatedIdStudentcode(studentCode)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message ?? e.code}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingStudent = false);
    }
  }

  Future<void> _createShift() async {
    final e = widget.enrollment;
    if (e.id == null) return;

    try {
      final enrollmentDoc = await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(e.id)
          .get();
      if (!enrollmentDoc.exists) return;

      final enrollmentData = enrollmentDoc.data() as Map<String, dynamic>;
      final contact = enrollmentData['contact'] as Map<String, dynamic>? ?? {};
      final preferences = enrollmentData['preferences'] as Map<String, dynamic>? ?? {};
      final program = enrollmentData['program'] as Map<String, dynamic>? ?? {};
      final metadata = enrollmentData['metadata'] as Map<String, dynamic>? ?? {};
      final matchedTeacherId = metadata['matchedTeacherId'] as String?;

      if (matchedTeacherId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.teacherInformationNotAvailable), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Find student by email
      final studentEmail = contact['email'] as String?;
      Employee? preloadedStudent;
      if (studentEmail != null && studentEmail.isNotEmpty) {
        try {
          final q = await FirebaseFirestore.instance
              .collection('users')
              .where('e-mail', isEqualTo: studentEmail)
              .where('user_type', isEqualTo: 'student')
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            final doc = q.docs.first;
            final data = doc.data();
            String fmtTs(dynamic ts) => ts is Timestamp ? ts.toDate().toString() : ts?.toString() ?? 'Never';
            preloadedStudent = Employee(
              firstName: data['first_name'] ?? '',
              lastName: data['last_name'] ?? '',
              email: data['e-mail'] ?? '',
              countryCode: data['country_code'] ?? '',
              mobilePhone: data['phone_number'] ?? '',
              userType: data['user_type'] ?? 'student',
              title: data['title'] ?? '',
              employmentStartDate: fmtTs(data['employment_start_date']),
              kioskCode: data['kiosk_code'] ?? doc.id,
              studentCode: data['student_code'] ?? data['studentCode'] ?? '',
              dateAdded: fmtTs(data['date_added']),
              lastLogin: fmtTs(data['last_login']),
              documentId: doc.id,
              isAdminTeacher: data['is_admin_teacher'] as bool? ?? false,
              isActive: data['is_active'] as bool? ?? true,
            );
          }
        } catch (_) {}
      }

      // Load teacher
      Employee? preloadedTeacher;
      try {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(matchedTeacherId)
            .get();
        if (teacherDoc.exists) {
          final data = teacherDoc.data() as Map<String, dynamic>;
          String fmtTs(dynamic ts) => ts is Timestamp ? ts.toDate().toString() : ts?.toString() ?? 'Never';
          preloadedTeacher = Employee(
            firstName: data['first_name'] ?? '',
            lastName: data['last_name'] ?? '',
            email: data['e-mail'] ?? '',
            countryCode: data['country_code'] ?? '',
            mobilePhone: data['phone_number'] ?? '',
            userType: data['user_type'] ?? 'teacher',
            title: data['title'] ?? '',
            employmentStartDate: fmtTs(data['employment_start_date']),
            kioskCode: data['kiosk_code'] ?? '',
            dateAdded: fmtTs(data['date_added']),
            lastLogin: fmtTs(data['last_login']),
            documentId: teacherDoc.id,
            isAdminTeacher: data['is_admin_teacher'] as bool? ?? false,
            isActive: data['is_active'] as bool? ?? true,
          );
        }
      } catch (_) {}

      // Timezone conversion
      final studentTzName = preferences['timeZone'] ?? e.timeZone;
      final teacherTzName = _teacherTimezone ?? 'UTC';
      final teacherSelectedTimes = _teacherSelectedTimes ?? metadata['teacherSelectedTimes'] as Map<String, dynamic>?;

      List<dynamic>? rawDays;
      TimeOfDay? initialStartTime;

      if (teacherSelectedTimes != null && teacherSelectedTimes.isNotEmpty) {
        rawDays = teacherSelectedTimes.keys.toList();
        final firstSlot = teacherSelectedTimes.values.first.toString().split('-').first.trim();
        try {
          final dt = DateFormat('h:mm a').parse(firstSlot);
          initialStartTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        } catch (_) {}
      } else {
        final rawTimeSlots = preferences['timeSlots'] as List<dynamic>? ?? e.preferredTimeSlots;
        rawDays = preferences['days'] as List<dynamic>? ?? e.preferredDays;
        if (rawTimeSlots.isNotEmpty) {
          final firstSlot = rawTimeSlots.first.toString().split('-').first.trim();
          try {
            final dt = DateFormat('h:mm a').parse(firstSlot);
            final studentLoc = tz.getLocation(studentTzName.isEmpty ? 'UTC' : studentTzName);
            final now = tz.TZDateTime.now(studentLoc);
            final studentDt = tz.TZDateTime(studentLoc, now.year, now.month, now.day, dt.hour, dt.minute);
            final teacherLoc = tz.getLocation(teacherTzName);
            final teacherDt = tz.TZDateTime.from(studentDt, teacherLoc);
            initialStartTime = TimeOfDay(hour: teacherDt.hour, minute: teacherDt.minute);
          } catch (_) {}
        }
      }

      final sessionDuration = program['sessionDuration'] ?? e.sessionDuration ?? '60 minutes';

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => CreateShiftDialog(
          initialTeacherId: _teacherEmail ?? matchedTeacherId,
          initialStudentEmail: studentEmail,
          initialSubjectName: enrollmentData['subject'] as String? ?? e.subject,
          initialDays: rawDays?.map((d) => d.toString()).toList(),
          initialTimezone: teacherTzName,
          initialTime: initialStartTime,
          preloadedTeacher: preloadedTeacher,
          preloadedStudent: preloadedStudent,
          sessionDuration: sessionDuration,
          onShiftCreated: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.shiftCreatedSyncedToTeacherTimezone),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorE), backgroundColor: Colors.red),
      );
    }
  }
}
