import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/enrollment_request.dart';
import 'enrollment_applicant_details.dart';
import '../../dashboard/services/job_board_service.dart';
import 'prepare_broadcast_dialog.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:alluwalacademyadmin/core/utils/firebase_error_message.dart';

class EnrollmentCard extends StatelessWidget {
  final EnrollmentRequest enrollment;
  final String nextActionLabel;
  final bool isLive;

  const EnrollmentCard({
    super.key,
    required this.enrollment,
    required this.nextActionLabel,
    required this.isLive,
  });

  bool get _isAdult =>
      enrollment.isAdult ||
      (int.tryParse(enrollment.studentAge ?? '0') ?? 0) >= 18;
  bool get _isArchived => enrollment.status.toLowerCase() == 'archived';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border:
            isLive ? Border.all(color: const Color(0xff10B981), width: 1.5) : null,
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enrollment.programTitle ??
                                enrollment.subject ??
                                AppLocalizations.of(context)!.commonUnknownSubject,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${enrollment.studentName ?? AppLocalizations.of(context)!.commonUnknown} • ${enrollment.gradeLevel}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xff64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    EnrollmentApplicantActionButtons(enrollment: enrollment),
                  ],
                ),
                const SizedBox(height: 12),
                EnrollmentSchedulingChips(enrollment: enrollment),
                if (isLive) ...[
                  const SizedBox(height: 10),
                  _buildLiveBroadcastPanel(context),
                ],
                const SizedBox(height: 12),
                buildActionHistory(context),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildActionBar(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            isLive
                ? const Color(0xffECFDF5)
                : _isArchived
                    ? const Color(0xffF1F5F9)
                    : const Color(0xffF8FAFC),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          if (isLive) ...[
            const Icon(Icons.sensors,
                size: 14, color: Color(0xff059669)),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.liveOnJobBoard,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xff059669),
                letterSpacing: 0.5,
              ),
            ),
          ] else if (_isArchived) ...[
            const Icon(Icons.archive_outlined,
                size: 14, color: Color(0xff64748B)),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.archived,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xff64748B),
                letterSpacing: 0.3,
              ),
            ),
          ] else ...[
            Icon(Icons.access_time_filled,
                size: 14, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM d, h:mm a')
                  .format(enrollment.submittedAt),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ],
          const Spacer(),
          if (_isAdult)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4)),
              child: Text(AppLocalizations.of(context)!.adultStudent,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveBroadcastPanel(BuildContext context) {
    if (enrollment.id == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('enrollments')
          .doc(enrollment.id)
          .snapshots(),
      builder: (context, enrollmentSnap) {
        if (!enrollmentSnap.hasData ||
            enrollmentSnap.data == null ||
            !enrollmentSnap.data!.exists) {
          return const SizedBox.shrink();
        }
        final metadata =
            enrollmentSnap.data!.data()?['metadata'] as Map<String, dynamic>? ??
                {};
        final snapshot =
            metadata['lastBroadcastSnapshot'] as Map<String, dynamic>? ?? {};
        final jobId = (metadata['jobId'] ?? '').toString();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Broadcast Snapshot',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff1E293B),
                ),
              ),
              const SizedBox(height: 6),
              if (snapshot.isNotEmpty) ...[
                enrollmentDetailRow(
                    'Days', (snapshot['days'] as List?)?.join(', ') ?? '-'),
                enrollmentDetailRow('Times',
                    (snapshot['timeSlots'] as List?)?.join(', ') ?? '-'),
                enrollmentDetailRow('Timezone', snapshot['timezoneRef']),
                enrollmentDetailRow(
                    'Time of day', snapshot['timeOfDayPreference'] ?? '-'),
                enrollmentDetailRow('Admin note', snapshot['adminNotesForTeachers']),
              ] else ...[
                Text(
                  'No snapshot stored (legacy broadcast).',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xff64748B),
                  ),
                ),
              ],
              if (jobId.isNotEmpty) ...[
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('job_board')
                      .doc(jobId)
                      .snapshots(),
                  builder: (context, jobDocSnap) {
                    final jobData = jobDocSnap.data?.data();
                    final jobStatus = (jobData?['status'] ?? '').toString();
                    final closedReason =
                        (jobData?['closedReason'] ?? '').toString();
                    final hiddenByFullAvailability = jobStatus == 'closed' &&
                        closedReason ==
                            JobBoardService.kClosedReasonTeacherFullyAvailable;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hiddenByFullAvailability)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xffFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xffF59E0B)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!
                                        .jobBoardHiddenFullAvailabilityBanner,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xff92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final l10n =
                                          AppLocalizations.of(context)!;
                                      try {
                                        await JobBoardService()
                                            .adminReopenJobBoardForTeachers(
                                                jobId);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(l10n
                                                .jobBoardReopenedForTeachers),
                                            backgroundColor:
                                                const Color(0xff047857),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                messageFromFirebaseError(e)),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: Text(AppLocalizations.of(context)!
                                        .jobBoardReopenForTeachersButton),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (jobStatus == 'open')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined,
                                    size: 16, color: Colors.green[700]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .jobBoardVisibleToTeachersHint,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xff166534),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (jobStatus == 'accepted')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              AppLocalizations.of(context)!
                                  .jobBoardAcceptedByTeacherHint,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xff1D4ED8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (jobStatus == 'closed')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              AppLocalizations.of(context)!
                                  .jobBoardClosedOtherReasonHint,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xff64748B),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Text(
                          'Teacher Responses',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xff1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream:
                              JobBoardService().streamJobResponses(jobId),
                          builder: (context, responseSnap) {
                    if (!responseSnap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final responses = responseSnap.data!;
                    if (responses.isEmpty) {
                      return Text(
                        'No teacher responses yet.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xff64748B),
                        ),
                      );
                    }
                    return Column(
                      children: responses.map((r) {
                        final status =
                            (r['availabilityStatus'] ?? '').toString();
                        final teacherName =
                            (r['teacherName'] ?? r['teacherId'] ?? 'Teacher')
                                .toString();
                        final comment = (r['comment'] ?? '').toString().trim();
                        final statusLabel = switch (status) {
                          'available' => 'Available',
                          'partial' => 'Partial',
                          'unavailable' => 'Unavailable',
                          _ => status,
                        };
                        final statusColor = switch (status) {
                          'available' => const Color(0xff166534),
                          'partial' => const Color(0xff92400E),
                          'unavailable' => const Color(0xff991B1B),
                          _ => const Color(0xff334155),
                        };
                        final teacherId = (r['teacherId'] ?? '').toString();
                        final adminRejected = r['adminRejected'] == true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      teacherName,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xff0F172A),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (comment.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  comment,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xff334155),
                                  ),
                                ),
                              ],
                              if (adminRejected) ...[
                                const SizedBox(height: 6),
                                Text(
                                  AppLocalizations.of(context)!
                                      .jobBoardTeacherResponseDeclined,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xff991B1B),
                                  ),
                                ),
                              ] else if (teacherId.isNotEmpty &&
                                  status != 'unavailable') ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final l10n = AppLocalizations.of(
                                              context)!;
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Text(l10n
                                                  .jobBoardDeclineTeacherConfirmTitle),
                                              content: Text(l10n
                                                  .jobBoardDeclineTeacherConfirmBody),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: Text(l10n
                                                      .jobBoardDeclineTeacher),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok != true) return;
                                          try {
                                            await JobBoardService()
                                                .adminRejectTeacherResponse(
                                              jobId,
                                              teacherId,
                                            );
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(l10n
                                                    .jobBoardTeacherResponseDeclined),
                                                backgroundColor:
                                                    Colors.orange[800],
                                              ),
                                            );
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    messageFromFirebaseError(
                                                        e)),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.cancel_outlined,
                                            size: 14),
                                        label: Text(
                                            AppLocalizations.of(context)!
                                                .jobBoardDeclineTeacher),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xff991B1B),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                          textStyle: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            await JobBoardService()
                                                .confirmTeacherMatch(jobId,
                                                    teacherId: teacherId);
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Teacher confirmed and moved to Matched.'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    messageFromFirebaseError(
                                                        e)),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.check_circle,
                                            size: 14),
                                        label: const Text('Confirm Match'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xff0F766E),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                          textStyle: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Builds the action history timeline. Made public so matched cards can reuse it.
  Widget buildActionHistory(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: enrollment.id != null
          ? FirebaseFirestore.instance
              .collection('enrollments')
              .doc(enrollment.id)
              .get()
          : Future.value(null),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final actions = parseActionHistory(metadata);

        if (actions.isEmpty) return const SizedBox.shrink();

        return _buildActionHistoryWidget(actions);
      },
    );
  }

  /// Parse action history from enrollment metadata into displayable entries.
  static List<Map<String, dynamic>> parseActionHistory(Map<String, dynamic> metadata) {
    final List<Map<String, dynamic>> actions = [];

    if (metadata['contactedAt'] != null) {
      actions.add({
        'action': 'Marked as Contacted',
        'by': metadata['contactedByName'] ?? metadata['contactedBy'] ?? 'Admin',
        'at': metadata['contactedAt'],
        'icon': Icons.phone,
        'color': const Color(0xff3B82F6),
      });
    }

    if (metadata['broadcastedAt'] != null) {
      actions.add({
        'action': 'Broadcasted to Teachers',
        'by': metadata['broadcastedByName'] ?? metadata['broadcastedBy'] ?? 'Admin',
        'at': metadata['broadcastedAt'],
        'icon': Icons.sensors,
        'color': const Color(0xff10B981),
      });
    }

    if (metadata['matchedAt'] != null) {
      actions.add({
        'action': 'Matched with Teacher',
        'by': metadata['matchedTeacherName'] ?? metadata['matchedTeacherId'] ?? 'Teacher',
        'at': metadata['matchedAt'],
        'icon': Icons.handshake,
        'color': const Color(0xff8B5CF6),
      });
    }

    final actionHistory = metadata['actionHistory'] as List<dynamic>?;
    if (actionHistory != null && actionHistory.isNotEmpty) {
      for (final entry in actionHistory) {
        if (entry is Map<String, dynamic>) {
          final actionType = entry['action'] as String? ?? '';
          if (actionType == 'marked_contacted' &&
              !actions.any((a) => a['action'] == 'Marked as Contacted')) {
            actions.add({
              'action': 'Marked as Contacted',
              'by': entry['adminName'] ?? entry['adminId'] ?? 'Admin',
              'at': entry['timestamp'],
              'icon': Icons.phone,
              'color': const Color(0xff3B82F6),
            });
          } else if (actionType == 'broadcasted' &&
                     !actions.any((a) => a['action'] == 'Broadcasted to Teachers')) {
            actions.add({
              'action': 'Broadcasted to Teachers',
              'by': entry['adminName'] ?? entry['adminId'] ?? 'Admin',
              'at': entry['timestamp'],
              'icon': Icons.sensors,
              'color': const Color(0xff10B981),
            });
          } else if (actionType == 'teacher_accepted') {
            actions.add({
              'action': 'Matched with Teacher',
              'by': entry['teacherName'] ?? entry['teacherId'] ?? 'Teacher',
              'at': entry['timestamp'],
              'icon': Icons.handshake,
              'color': const Color(0xff8B5CF6),
            });
          } else if (actionType == 'admin_revoked') {
            actions.add({
              'action': 'Admin Revoked (Re-broadcast)',
              'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
              'at': entry['timestamp'],
              'icon': Icons.undo,
              'color': Colors.red,
            });
          } else if (actionType == 'teacher_withdrawn') {
            actions.add({
              'action': 'Teacher Withdrew',
              'by': entry['teacherName'] ?? entry['teacherId'] ?? 'Teacher',
              'at': entry['timestamp'],
              'icon': Icons.exit_to_app,
              'color': Colors.orange,
            });
          } else if (actionType == 'archived') {
            actions.add({
              'action': 'Archived Application',
              'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
              'at': entry['timestamp'],
              'icon': Icons.archive_outlined,
              'color': const Color(0xff475569),
            });
          } else if (actionType == 'unarchived') {
            actions.add({
              'action': 'Unarchived Application',
              'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
              'at': entry['timestamp'],
              'icon': Icons.unarchive_outlined,
              'color': const Color(0xff2563EB),
            });
          } else if (actionType == 'admin_closed') {
            actions.add({
              'action': 'Closed by admin (no re-broadcast)',
              'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
              'at': entry['timestamp'],
              'icon': Icons.archive_outlined,
              'color': const Color(0xff4B5563),
            });
          } else if (actionType == 'job_board_reopened_after_full_availability') {
            actions.add({
              'action': 'Job board reopened after fully available',
              'by': entry['adminName'] ?? entry['adminEmail'] ?? 'Admin',
              'at': entry['timestamp'],
              'icon': Icons.sensor_door_outlined,
              'color': const Color(0xff047857),
            });
          }
        }
      }
    }

    return actions;
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
              Text(
                'Activity History',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff475569),
                ),
              ),
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
                    child: Icon(
                      action['icon'] as IconData,
                      size: 14,
                      color: action['color'] as Color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action['action'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff1E293B),
                          ),
                        ),
                        Text(
                          'by ${action['by']}${timestamp != null ? ' • ${DateFormat('MMM d, h:mm a').format(timestamp.toDate())}' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xff64748B),
                          ),
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

  Widget _buildActionBar(BuildContext context) {
    return Row(
      children: [
        if (_isArchived) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _confirmUnarchive(context),
              icon: const Icon(Icons.unarchive_outlined, size: 16),
              label: const Text('Unarchive'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff2563EB),
                side: const BorderSide(color: Color(0xff93C5FD)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ] else if (isLive) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () =>
                  _handleStatusChange(context, 'contacted'),
              icon: const Icon(Icons.visibility_off_outlined,
                  size: 16),
              label: Text(AppLocalizations.of(context)!.unBroadcast),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xffEF4444),
                side: const BorderSide(color: Color(0xffEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ] else ...[
          IconButton(
            onPressed: () => _confirmArchive(context),
            icon: const Icon(Icons.archive_outlined,
                color: Colors.grey, size: 20),
            tooltip: AppLocalizations.of(context)!.archive,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _advanceWorkflow(context),
              icon: Icon(
                  enrollment.status.toLowerCase() == 'pending'
                      ? Icons.check
                      : Icons.sensors,
                  size: 16),
              label: Text(nextActionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmArchive(BuildContext context) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Archive applicant?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will archive the application and remove it from active lists. '
          'It will not be permanently deleted.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff475569)),
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldArchive != true || !context.mounted) return;
    await _handleStatusChange(
      context,
      'archived',
      forcedAction: 'archived',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Application archived. It was not deleted.'),
      ),
    );
  }

  Future<void> _confirmUnarchive(BuildContext context) async {
    final shouldUnarchive = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Unarchive applicant?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will move the application back to the active pipeline.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unarchive'),
          ),
        ],
      ),
    );

    if (shouldUnarchive != true || !context.mounted || enrollment.id == null) return;

    String restoreStatus = 'pending';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(enrollment.id)
          .get();
      final metadata = snapshot.data()?['metadata'] as Map<String, dynamic>? ?? {};
      final previousStatus =
          (metadata['archivedPreviousStatus'] as String?)?.toLowerCase().trim();
      if (previousStatus == 'contacted') {
        restoreStatus = 'contacted';
      }
    } catch (_) {}

    if (!context.mounted) return;
    await _handleStatusChange(
      context,
      restoreStatus,
      forcedAction: 'unarchived',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restoreStatus == 'contacted'
              ? 'Application moved to Ready.'
              : 'Application moved to Inbox.',
        ),
      ),
    );
  }

  Future<void> _advanceWorkflow(BuildContext context) async {
    final status = enrollment.status.toLowerCase();
    if (status == 'pending') {
      await _handleStatusChange(context, 'contacted');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.markedAsContactedMovedToReady)));
      }
    } else if (status == 'contacted') {
      _showBroadcastDialog(context);
    }
  }

  void _showBroadcastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => PrepareAndBroadcastDialog(enrollment: enrollment),
    );
  }

  Future<void> _handleStatusChange(
      BuildContext context, String newStatus, {String? forcedAction}) async {
    if (enrollment.id == null) return;

    final targetStatus = newStatus == 'rejected' ? 'archived' : newStatus;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (targetStatus == 'contacted') {
      try {
        await JobBoardService().unbroadcastEnrollment(enrollment.id!);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Un-broadcast failed to update job board: $e')),
          );
        }
        return;
      }
    }

    String? adminName;
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (adminDoc.exists) {
        final data = adminDoc.data() as Map<String, dynamic>;
        adminName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
        if (adminName.isEmpty) adminName = data['e-mail'] as String?;
      }
    } catch (e) {
      adminName = currentUser.email;
    }

    final actionEntry = {
      'action': forcedAction ??
          (targetStatus == 'contacted'
              ? 'marked_contacted'
              : targetStatus == 'broadcasted'
                  ? 'broadcasted'
                  : targetStatus == 'archived'
                      ? 'archived'
                      : 'status_changed'),
      'status': targetStatus,
      'adminId': currentUser.uid,
      'adminName': adminName ?? 'Unknown',
      'adminEmail': currentUser.email ?? '',
      'timestamp': Timestamp.fromDate(DateTime.now()),
    };

    await FirebaseFirestore.instance
        .collection('enrollments')
        .doc(enrollment.id)
        .update({
      'metadata.status': targetStatus,
      'metadata.lastUpdated': FieldValue.serverTimestamp(),
      'metadata.updatedBy': currentUser.uid,
      'metadata.updatedByName': adminName,
      if (targetStatus == 'contacted') 'metadata.contactedAt': FieldValue.serverTimestamp(),
      if (targetStatus == 'contacted') 'metadata.contactedBy': currentUser.uid,
      if (targetStatus == 'contacted') 'metadata.contactedByName': adminName,
      if (targetStatus == 'broadcasted') 'metadata.broadcastedBy': currentUser.uid,
      if (targetStatus == 'broadcasted') 'metadata.broadcastedByName': adminName,
      if (targetStatus == 'archived') 'metadata.archivedAt': FieldValue.serverTimestamp(),
      if (targetStatus == 'archived') 'metadata.archivedBy': currentUser.uid,
      if (targetStatus == 'archived') 'metadata.archivedByName': adminName,
      if (targetStatus == 'archived' &&
          enrollment.status.toLowerCase() != 'archived')
        'metadata.archivedPreviousStatus': enrollment.status.toLowerCase(),
      if (forcedAction == 'unarchived')
        'metadata.unarchivedAt': FieldValue.serverTimestamp(),
      if (forcedAction == 'unarchived')
        'metadata.unarchivedBy': currentUser.uid,
      if (forcedAction == 'unarchived')
        'metadata.unarchivedByName': adminName,
      'metadata.actionHistory': FieldValue.arrayUnion([actionEntry]),
    });
  }
}

/// Schedule / timezone / parent row shown on every pipeline card and on matched cards.
class EnrollmentSchedulingChips extends StatelessWidget {
  final EnrollmentRequest enrollment;

  const EnrollmentSchedulingChips({super.key, required this.enrollment});

  bool get _isAdult =>
      enrollment.isAdult ||
      (int.tryParse(enrollment.studentAge ?? '0') ?? 0) >= 18;

  @override
  Widget build(BuildContext context) {
    final days = enrollment.resolvedPreferredDays.join(', ');
    final slots = enrollment.resolvedPreferredTimeSlots.join(', ');
    final tz = enrollment.resolvedTimeZoneDisplay;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _chip(Icons.calendar_today, days),
        _chip(Icons.schedule, slots),
        _chip(Icons.public, tz),
        if (!_isAdult && enrollment.parentName != null)
          _chip(Icons.family_restroom, 'Parent: ${enrollment.parentName}'),
      ],
    );
  }

  Widget _chip(IconData icon, String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xff94A3B8)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label.length > 25 ? '${label.substring(0, 25)}...' : label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xff475569),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
