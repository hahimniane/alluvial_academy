import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/core/services/parent_service.dart';
import 'package:alluwalacademyadmin/features/tasks/models/task.dart';
import 'package:alluwalacademyadmin/features/tasks/services/task_service.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/student_quick_stats_card.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/class_card.dart';
import 'package:alluwalacademyadmin/core/enums/task_enums.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class StudentOverviewTab extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentOverviewTab({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentOverviewTab> createState() => _StudentOverviewTabState();
}

class _StudentOverviewTabState extends State<StudentOverviewTab> {
  final TaskService _taskService = TaskService();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats
            FutureBuilder<Map<String, dynamic>>(
              future: _loadQuickStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ));
                }

                if (snapshot.hasError) {
                  return _errorCard('Failed to load statistics: ${snapshot.error}');
                }

                final stats = snapshot.data ?? {
                  'totalClasses': 0,
                  'attendanceRate': 0.0,
                  'completedTasks': 0,
                  'totalTasks': 0,
                };

                return StudentQuickStatsCard(
                  totalClasses: stats['totalClasses'] as int,
                  attendanceRate: stats['attendanceRate'] as double,
                  completedTasks: stats['completedTasks'] as int,
                  totalTasks: stats['totalTasks'] as int,
                );
              },
            ),
            const SizedBox(height: 20),

            // Today's Classes
            _sectionHeader('Today\'s Classes'),
            const SizedBox(height: 10),
            FutureBuilder<List<TeachingShift>>(
              future: ParentService.getStudentTodayShifts(widget.studentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ));
                }

                if (snapshot.hasError) {
                  return _errorCard('Failed to load today\'s classes: ${snapshot.error}');
                }

                final classes = snapshot.data ?? [];
                if (classes.isEmpty) {
                  return _emptyCard(
                    icon: Icons.calendar_today_rounded,
                    title: AppLocalizations.of(context)!.noClassesToday,
                    subtitle: AppLocalizations.of(context)!.yourChildHasNoScheduledClasses,
                  );
                }

                return Column(
                  children: classes.map((shift) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClassCard(shift: shift),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 20),

            // Upcoming Classes Preview
            _sectionHeader('Upcoming Classes'),
            const SizedBox(height: 10),
            FutureBuilder<List<TeachingShift>>(
              future: ParentService.getStudentUpcomingShifts(widget.studentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ));
                }

                if (snapshot.hasError) {
                  return _errorCard('Failed to load upcoming classes: ${snapshot.error}');
                }

                final classes = snapshot.data ?? [];
                final previewClasses = classes.take(5).toList();

                if (previewClasses.isEmpty) {
                  return _emptyCard(
                    icon: Icons.calendar_month_rounded,
                    title: AppLocalizations.of(context)!.noUpcomingClasses,
                    subtitle: AppLocalizations.of(context)!.yourChildHasNoUpcomingClasses,
                  );
                }

                return Column(
                  children: previewClasses.map((shift) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClassCard(shift: shift),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 20),

            // Recent Activity
            _sectionHeader('Recent Activity'),
            const SizedBox(height: 10),
            StreamBuilder<List<Task>>(
              stream: _taskService.getStudentTasks(widget.studentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ));
                }

                if (snapshot.hasError) {
                  return _errorCard('Failed to load recent activity: ${snapshot.error}');
                }

                final tasks = snapshot.data ?? [];
                final completedTasks = tasks.where((t) => t.status == TaskStatus.done).toList();
                completedTasks.sort((a, b) {
                  final aDate = a.completedAt?.toDate();
                  final bDate = b.completedAt?.toDate();
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return bDate.compareTo(aDate);
                });
                final lastCompletedTask = completedTasks.isNotEmpty ? completedTasks.first : null;

                return FutureBuilder<List<TeachingShift>>(
                  future: ParentService.getStudentShiftsHistory(widget.studentId, startDate: null, endDate: DateTime.now()),
                  builder: (context, shiftSnapshot) {
                    final shifts = shiftSnapshot.data ?? [];
                    final completedShifts = shifts.where((s) => 
                      s.status.toString().contains('completed')).toList();
                    completedShifts.sort((a, b) => b.shiftStart.compareTo(a.shiftStart));
                    final lastClass = completedShifts.isNotEmpty ? completedShifts.first : null;

                    if (lastCompletedTask == null && lastClass == null) {
                      return _emptyCard(
                        icon: Icons.history_rounded,
                        title: AppLocalizations.of(context)!.noRecentActivity,
                        subtitle: AppLocalizations.of(context)!.activityWillAppearHereAsYour,
                      );
                    }

                    return Column(
                      children: [
                        if (lastClass != null)
                          _recentActivityItem(
                            icon: Icons.school_rounded,
                            iconColor: const Color(0xFF16A34A),
                            title: AppLocalizations.of(context)!.lastClassCompleted,
                            subtitle: DateFormat('MMM dd, yyyy • h:mm a').format(lastClass.shiftStart),
                            detail: lastClass.subjectDisplayName ?? lastClass.subject.toString(),
                          ),
                        if (lastCompletedTask != null) ...[
                          if (lastClass != null) const SizedBox(height: 12),
                          _recentActivityItem(
                            icon: Icons.assignment_turned_in_rounded,
                            iconColor: const Color(0xFF0386FF),
                            title: AppLocalizations.of(context)!.lastTaskCompleted,
                            subtitle: lastCompletedTask.completedAt != null
                                ? DateFormat('MMM dd, yyyy').format(lastCompletedTask.completedAt!.toDate())
                                : 'Recently',
                            detail: lastCompletedTask.title,
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadQuickStats() async {
    final attendanceStats = await ParentService.getStudentAttendanceStats(widget.studentId);
    final shifts = await ParentService.getStudentShiftsHistory(widget.studentId, startDate: null, endDate: DateTime.now());
    final tasksSnapshot = await _taskService.getStudentTasks(widget.studentId).first;

    return {
      'totalClasses': shifts.length,
      'attendanceRate': attendanceStats['attendanceRate'] as double,
      'completedTasks': tasksSnapshot.where((t) => t.status == TaskStatus.done).length,
      'totalTasks': tasksSnapshot.length,
    };
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF111827),
      ),
    );
  }

  Widget _recentActivityItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Icon(icon, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF7F1D1D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

