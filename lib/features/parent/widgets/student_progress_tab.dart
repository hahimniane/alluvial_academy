import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/services/parent_service.dart';
import 'package:alluwalacademyadmin/core/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/core/services/shift_service.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/subject_stat_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class StudentProgressTab extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentProgressTab({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentProgressTab> createState() => _StudentProgressTabState();
}

class _StudentProgressTabState extends State<StudentProgressTab> {
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
            // Attendance Summary
            _sectionHeader('Attendance Summary'),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>>(
              future: ParentService.getStudentAttendanceStats(widget.studentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ));
                }

                if (snapshot.hasError) {
                  return _errorCard('Failed to load attendance: ${snapshot.error}');
                }

                final stats = snapshot.data ?? {
                  'totalClasses': 0,
                  'completedClasses': 0,
                  'missedClasses': 0,
                  'cancelledClasses': 0,
                  'attendanceRate': 0.0,
                };

                return _buildAttendanceSummaryCard(stats);
              },
            ),
            const SizedBox(height: 20),

            // Learning Stats
            _sectionHeader('Learning Statistics'),
            const SizedBox(height: 10),
            StreamBuilder<List<TeachingShift>>(
              stream: ShiftService.getStudentShifts(widget.studentId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ));
                }

                final shifts = snapshot.data!;
                final now = DateTime.now();
                final pastShifts = shifts.where((s) => s.shiftStart.isBefore(now)).toList();
                
                double totalHours = 0;
                for (final shift in pastShifts) {
                  final duration = shift.shiftEnd.difference(shift.shiftStart);
                  totalHours += duration.inMinutes / 60.0;
                }

                final classesThisWeek = shifts.where((s) {
                  final weekAgo = now.subtract(const Duration(days: 7));
                  return s.shiftStart.isAfter(weekAgo) && s.shiftStart.isBefore(now);
                }).length;

                final classesThisMonth = shifts.where((s) {
                  final monthAgo = now.subtract(const Duration(days: 30));
                  return s.shiftStart.isAfter(monthAgo) && s.shiftStart.isBefore(now);
                }).length;

                final uniqueSubjects = shifts.map((s) =>
                  s.subjectDisplayName ?? s.subject.toString()).toSet().length;

                return _buildLearningStatsCard(
                  totalHours: totalHours,
                  classesThisWeek: classesThisWeek,
                  classesThisMonth: classesThisMonth,
                  uniqueSubjects: uniqueSubjects,
                );
              },
            ),
            const SizedBox(height: 20),

            // Subject Performance
            _sectionHeader('Subject Performance'),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, Map<String, dynamic>>>(
              future: ParentService.getStudentSubjectStats(widget.studentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ));
                }

                if (snapshot.hasError) {
                  return _errorCard('Failed to load subject stats: ${snapshot.error}');
                }

                final subjectStats = snapshot.data ?? {};
                if (subjectStats.isEmpty) {
                  return _emptyCard(
                    icon: Icons.subject_rounded,
                    title: AppLocalizations.of(context)!.noSubjectData,
                    subtitle: AppLocalizations.of(context)!.subjectPerformanceWillAppearHereAs,
                  );
                }

                final sortedSubjects = subjectStats.entries.toList()
                  ..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));

                return Column(
                  children: sortedSubjects.map((entry) {
                    final stats = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SubjectStatCard(
                        subjectName: entry.key,
                        classCount: stats['count'] as int,
                        completedCount: stats['completedCount'] as int,
                        totalHours: (stats['totalHours'] as num).toDouble(),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSummaryCard(Map<String, dynamic> stats) {
    final totalClasses = stats['totalClasses'] as int;
    final completedClasses = stats['completedClasses'] as int;
    final missedClasses = stats['missedClasses'] as int;
    final cancelledClasses = stats['cancelledClasses'] as int;
    final attendanceRate = (stats['attendanceRate'] as num).toDouble();
    final attendancePercent = (attendanceRate * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.overallAttendance,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.attendancepercent,
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0386FF),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: attendanceRate,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    attendanceRate >= 0.8
                        ? const Color(0xFF16A34A)
                        : attendanceRate >= 0.6
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Completed',
                  completedClasses.toString(),
                  const Color(0xFF16A34A),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Missed',
                  missedClasses.toString(),
                  const Color(0xFFDC2626),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Cancelled',
                  cancelledClasses.toString(),
                  const Color(0xFF6B7280),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total',
                  totalClasses.toString(),
                  const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildLearningStatsCard({
    required double totalHours,
    required int classesThisWeek,
    required int classesThisMonth,
    required int uniqueSubjects,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildLearningStatItem(
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFF0386FF),
                  label: AppLocalizations.of(context)!.studentProgressTabTotalhours,
                  value: '${totalHours.toStringAsFixed(1)}h',
                ),
              ),
              Expanded(
                child: _buildLearningStatItem(
                  icon: Icons.calendar_view_week_rounded,
                  iconColor: const Color(0xFF16A34A),
                  label: AppLocalizations.of(context)!.timesheetThisWeek,
                  value: classesThisWeek.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildLearningStatItem(
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: AppLocalizations.of(context)!.timesheetThisMonth,
                  value: classesThisMonth.toString(),
                ),
              ),
              Expanded(
                child: _buildLearningStatItem(
                  icon: Icons.subject_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  label: AppLocalizations.of(context)!.studentProgressTabSubjects,
                  value: uniqueSubjects.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLearningStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
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

