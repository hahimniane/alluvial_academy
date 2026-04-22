import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Small reusable card shell for admin home "actionable" panels.
class AdminActionCardShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget content;
  final VoidCallback? onViewAll;
  final String? viewAllLabel;

  const AdminActionCardShell({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.content,
    this.onViewAll,
    this.viewAllLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: accentColor.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
            if (onViewAll != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onViewAll,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    viewAllLabel ?? AppLocalizations.of(context)!.adminActionCardsViewAll,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _loadingTile() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFFE5E7EB),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _emptyState(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF6B7280),
      ),
    ),
  );
}

/// Pending timesheets card (AdminTimesheetReview screen).
class PendingTimesheetsCard extends StatelessWidget {
  final void Function(int screenIndex)? onNavigate;
  final int limit;
  final int screenIndex;

  const PendingTimesheetsCard({
    super.key,
    this.onNavigate,
    this.limit = 5,
    this.screenIndex = 7,
  });

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('timesheet_entries')
        .where('status', isEqualTo: 'pending')
        .limit(limit)
        .snapshots();

    final l = AppLocalizations.of(context)!;
    return AdminActionCardShell(
      title: l.adminActionCardsPendingTimesheets,
      icon: Icons.receipt_long,
      accentColor: const Color(0xFF8B5CF6),
      viewAllLabel: l.adminActionCardsTimesheetReview,
      onViewAll: () => onNavigate?.call(screenIndex),
      content: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: List.generate(limit, (_) => _loadingTile()),
            );
          }
          if (snapshot.hasError) {
            return _emptyState(AppLocalizations.of(context)!.adminActionCardsErrorPendingTimesheets);
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _emptyState(AppLocalizations.of(context)!.adminActionCardsNoPendingTimesheets);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final student = (data['student_name'] ?? data['subject'] ?? '').toString();
              final date = (data['date'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${student.isNotEmpty ? student : 'Pending'}${date.isNotEmpty ? ' • $date' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// Overdue tasks card (Tasks screen).
class OverdueTasksCard extends StatelessWidget {
  final void Function(int screenIndex)? onNavigate;
  final int limit;
  final int screenIndex;

  const OverdueTasksCard({
    super.key,
    this.onNavigate,
    this.limit = 5,
    this.screenIndex = 11,
  });

  @override
  Widget build(BuildContext context) {
    final now = Timestamp.now();

    final stream = FirebaseFirestore.instance
        .collection('tasks')
        .where('dueDate', isLessThan: now)
        .limit(20)
        .snapshots();

    final l = AppLocalizations.of(context)!;
    return AdminActionCardShell(
      title: l.adminActionCardsOverdueTasks,
      icon: Icons.task_alt,
      accentColor: const Color(0xFF14B8A6),
      viewAllLabel: l.adminActionCardsOpenTasks,
      onViewAll: () => onNavigate?.call(screenIndex),
      content: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: List.generate(limit, (_) => _loadingTile()),
            );
          }
          if (snapshot.hasError) {
            return _emptyState(AppLocalizations.of(context)!.adminActionCardsErrorTasks);
          }

          final docs = snapshot.data?.docs ?? [];
          final filtered = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final status = (data['status'] ?? '').toString().toLowerCase();
            return !status.contains('done');
          }).take(limit).toList();

          if (filtered.isEmpty) return _emptyState(AppLocalizations.of(context)!.adminActionCardsNoOverdueTasks);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: filtered.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final title = (data['title'] ?? 'Task').toString();
              final due = data['dueDate'];
              final dueLabel = due is Timestamp ? due.toDate().toString().split(' ').first : '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dueLabel.isNotEmpty ? '$title • Due $dueLabel' : '$title',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// Recent submissions card (AdminAllSubmissionsScreen).
class RecentSubmissionsCard extends StatelessWidget {
  final void Function(int screenIndex)? onNavigate;
  final int limit;
  final int screenIndex;

  const RecentSubmissionsCard({
    super.key,
    this.onNavigate,
    this.limit = 5,
    this.screenIndex = 24,
  });

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('form_responses')
        .orderBy('submittedAt', descending: true)
        .limit(limit)
        .snapshots();

    final l = AppLocalizations.of(context)!;
    return AdminActionCardShell(
      title: l.adminActionCardsRecentSubmissions,
      icon: Icons.list_alt,
      accentColor: const Color(0xFF0EA5E9),
      viewAllLabel: l.adminActionCardsAllSubmissions,
      onViewAll: () => onNavigate?.call(screenIndex),
      content: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: List.generate(limit, (_) => _loadingTile()),
            );
          }
          if (snapshot.hasError) {
            return _emptyState(AppLocalizations.of(context)!.adminActionCardsErrorSubmissions);
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _emptyState(AppLocalizations.of(context)!.adminActionCardsNoSubmissions);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final title = (data['formTitle'] ?? data['form_title'] ?? data['title'] ?? 'Form').toString();
              final submittedAt = data['submittedAt'];
              final dateLabel = submittedAt is Timestamp ? submittedAt.toDate().toString().split(' ').first : '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${title.isNotEmpty ? title : 'Form'}${dateLabel.isNotEmpty ? ' • $dateLabel' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// Upcoming shifts card (Shifts screen).
class UpcomingShiftsCard extends StatelessWidget {
  final void Function(int screenIndex)? onNavigate;
  final int limit;
  final int screenIndex;

  const UpcomingShiftsCard({
    super.key,
    this.onNavigate,
    this.limit = 5,
    this.screenIndex = 3,
  });

  @override
  Widget build(BuildContext context) {
    final now = Timestamp.fromDate(DateTime.now());
    final stream = FirebaseFirestore.instance
        .collection('teaching_shifts')
        .where('shift_start', isGreaterThanOrEqualTo: now)
        .orderBy('shift_start', descending: false)
        .limit(limit)
        .snapshots();

    final l = AppLocalizations.of(context)!;
    return AdminActionCardShell(
      title: l.adminActionCardsUpcomingShifts,
      icon: Icons.schedule,
      accentColor: const Color(0xFFF59E0B),
      viewAllLabel: l.adminActionCardsOpenShifts,
      onViewAll: () => onNavigate?.call(screenIndex),
      content: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: List.generate(limit, (_) => _loadingTile()),
            );
          }
          if (snapshot.hasError) {
            return _emptyState(AppLocalizations.of(context)!.adminActionCardsErrorShifts);
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _emptyState(AppLocalizations.of(context)!.adminActionCardsNoUpcomingShifts);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final subject = (data['subject_display_name'] ?? data['subject'] ?? '').toString();
              final teacher = (data['teacher_name'] ?? '').toString();
              final students = (data['student_names'] as List?)?.cast<String>() ?? const [];
              final firstStudent = students.isNotEmpty ? students.first : '';
              final startTs = data['shift_start'];
              final startLabel = startTs is Timestamp ? startTs.toDate().toString().split(' ').first : '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${firstStudent.isNotEmpty ? firstStudent : 'Shift'}${subject.isNotEmpty ? ' • $subject' : ''}${startLabel.isNotEmpty ? ' • $startLabel' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// Applicants to review card (Student applicants + Teacher applicants).
class ApplicantsToReviewCard extends StatelessWidget {
  final void Function(int screenIndex)? onNavigate;
  final int limit;

  const ApplicantsToReviewCard({
    super.key,
    this.onNavigate,
    this.limit = 5,
  });

  @override
  Widget build(BuildContext context) {
    final pendingEnrollmentsStream = FirebaseFirestore.instance
        .collection('enrollments')
        .where('metadata.status', isEqualTo: 'pending')
        .limit(20)
        .snapshots();

    final pendingTeacherAppsStream = FirebaseFirestore.instance
        .collection('teacher_applications')
        .where('status', isEqualTo: 'pending')
        .orderBy('submitted_at', descending: true)
        .limit(20)
        .snapshots();

    final l = AppLocalizations.of(context)!;
    return AdminActionCardShell(
      title: l.adminActionCardsApplicantsToReview,
      icon: Icons.school,
      accentColor: const Color(0xFFDC2626),
      viewAllLabel: l.adminActionCardsReviewApplications,
      onViewAll: () {
        // If we don't know which list should be prioritized, go to student applicants.
        onNavigate?.call(16);
      },
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: pendingEnrollmentsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final docs = snapshot.data!.docs;
              // Sort by submittedAt client-side (consistent with existing list screen).
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aSubmitted = aData['metadata']?['submittedAt'] as Timestamp?;
                final bSubmitted = bData['metadata']?['submittedAt'] as Timestamp?;
                if (aSubmitted == null && bSubmitted == null) return 0;
                if (aSubmitted == null) return 1;
                if (bSubmitted == null) return -1;
                return bSubmitted.compareTo(aSubmitted);
              });

              final take = docs.take(limit).toList();
              if (take.isEmpty) {
                return _emptyState(AppLocalizations.of(context)!.adminActionCardsNoStudentApplicants);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionMiniHeader(
                    icon: Icons.person_outline,
                    title: AppLocalizations.of(context)!.adminActionCardsStudents,
                  ),
                  ...take.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final subject = (data['programTitle'] ?? data['subject'] ?? '').toString();
                    final student = (data['student']?['name'] ?? data['studentName'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${student.isNotEmpty ? student : 'Student'}${subject.isNotEmpty ? ' • $subject' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => onNavigate?.call(16),
                      child: Text(
                        AppLocalizations.of(context)!.adminActionCardsViewStudents,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: pendingTeacherAppsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final docs = snapshot.data!.docs;
              final take = docs.take(limit).toList();
              if (take.isEmpty) {
                return _emptyState(AppLocalizations.of(context)!.adminActionCardsNoTeacherApplicants);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionMiniHeader(
                    icon: Icons.person,
                    title: AppLocalizations.of(context)!.adminActionCardsTeachers,
                  ),
                  ...take.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final first = (data['first_name'] ?? data['firstName'] ?? '').toString();
                    final last = (data['last_name'] ?? data['lastName'] ?? '').toString();
                    final email = (data['email'] ?? '').toString();
                    final name = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Applicant')}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => onNavigate?.call(17),
                      child: Text(
                        AppLocalizations.of(context)!.adminActionCardsViewTeachers,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionMiniHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionMiniHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFDC2626).withOpacity(0.85)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFDC2626),
          ),
        ),
      ],
    );
  }
}

