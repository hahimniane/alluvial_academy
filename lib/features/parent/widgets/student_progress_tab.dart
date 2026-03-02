import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/core/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/core/services/shift_service.dart';
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
      child: StreamBuilder<List<TeachingShift>>(
        stream: ShiftService.getStudentShifts(widget.studentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _loadingCard(),
            );
          }

          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _errorCard('Failed to load progress: ${snapshot.error}'),
            );
          }

          final metrics =
              _buildMetrics(snapshot.data ?? const <TeachingShift>[]);

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(metrics),
                const SizedBox(height: 16),
                _buildAttendanceBreakdownCard(metrics),
                const SizedBox(height: 16),
                _sectionHeader('Subject Performance'),
                const SizedBox(height: 10),
                if (metrics.subjectStats.isEmpty)
                  _emptyCard(
                    icon: Icons.subject_rounded,
                    title: AppLocalizations.of(context)!.noSubjectData,
                    subtitle: AppLocalizations.of(context)!
                        .subjectPerformanceWillAppearHereAs,
                  )
                else
                  Column(
                    children: metrics.subjectStats
                        .take(6)
                        .map(
                          (subject) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildSubjectProgressCard(subject),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  _StudentProgressMetrics _buildMetrics(List<TeachingShift> shifts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));
    final monthStart = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));

    int completedClasses = 0;
    int missedClasses = 0;
    int cancelledClasses = 0;
    int classesLast7Days = 0;
    int classesPrevious7Days = 0;
    int classesLast30Days = 0;
    double totalHoursLast30Days = 0;
    final weeklyCounts = List<int>.filled(7, 0);
    final uniqueSubjectsLast30Days = <String>{};

    final subjectStatsByName = <String, _SubjectAccumulator>{};

    for (final shift in shifts) {
      if (!shift.shiftStart.isBefore(now)) {
        continue;
      }

      final subjectName = _subjectDisplayName(shift);
      final isCompleted = _isCompletedStatus(shift.status);
      final isMissed = shift.status == ShiftStatus.missed;
      final isCancelled = shift.status == ShiftStatus.cancelled;

      final subjectAccumulator =
          subjectStatsByName.putIfAbsent(subjectName, _SubjectAccumulator.new);
      subjectAccumulator.totalClasses += 1;
      if (isCompleted) {
        final hours =
            shift.shiftEnd.difference(shift.shiftStart).inMinutes / 60.0;
        subjectAccumulator.completedClasses += 1;
        subjectAccumulator.totalHours += hours > 0 ? hours : 0;
      } else if (isMissed) {
        subjectAccumulator.missedClasses += 1;
      } else if (isCancelled) {
        subjectAccumulator.cancelledClasses += 1;
      }

      final isInLast30Days = shift.shiftStart.isAfter(monthStart);
      if (!isInLast30Days) {
        continue;
      }

      classesLast30Days += 1;
      uniqueSubjectsLast30Days.add(subjectName);

      final shiftDay = DateTime(
          shift.shiftStart.year, shift.shiftStart.month, shift.shiftStart.day);
      final dayIndex = shiftDay.difference(weekStart).inDays;
      if (dayIndex >= 0 && dayIndex < 7 && !shiftDay.isAfter(today)) {
        weeklyCounts[dayIndex] += 1;
      }

      if (shift.shiftStart.isAfter(sevenDaysAgo)) {
        classesLast7Days += 1;
      } else if (shift.shiftStart.isAfter(fourteenDaysAgo)) {
        classesPrevious7Days += 1;
      }

      if (isCompleted) {
        final hours =
            shift.shiftEnd.difference(shift.shiftStart).inMinutes / 60.0;
        completedClasses += 1;
        totalHoursLast30Days += hours > 0 ? hours : 0;
      } else if (isMissed) {
        missedClasses += 1;
      } else if (isCancelled) {
        cancelledClasses += 1;
      }
    }

    final trackedClasses = completedClasses + missedClasses + cancelledClasses;
    final attendanceRate =
        trackedClasses > 0 ? completedClasses / trackedClasses : 0.0;

    final subjectStats = subjectStatsByName.entries
        .map(
          (entry) => _SubjectProgressData(
            name: entry.key,
            totalClasses: entry.value.totalClasses,
            completedClasses: entry.value.completedClasses,
            missedClasses: entry.value.missedClasses,
            cancelledClasses: entry.value.cancelledClasses,
            totalHours: entry.value.totalHours,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalClasses.compareTo(a.totalClasses));

    final weekDays =
        List<DateTime>.generate(7, (i) => weekStart.add(Duration(days: i)));

    return _StudentProgressMetrics(
      attendanceRate: attendanceRate,
      completedClasses: completedClasses,
      missedClasses: missedClasses,
      cancelledClasses: cancelledClasses,
      totalTrackedClasses: trackedClasses,
      classesLast7Days: classesLast7Days,
      classesPrevious7Days: classesPrevious7Days,
      classesLast30Days: classesLast30Days,
      uniqueSubjectsLast30Days: uniqueSubjectsLast30Days.length,
      totalHoursLast30Days: totalHoursLast30Days,
      weeklyCounts: weeklyCounts,
      weekDays: weekDays,
      subjectStats: subjectStats,
      attentionLevel:
          _attentionLevelForAttendance(attendanceRate, trackedClasses),
    );
  }

  bool _isCompletedStatus(ShiftStatus status) {
    return status == ShiftStatus.completed ||
        status == ShiftStatus.fullyCompleted ||
        status == ShiftStatus.partiallyCompleted;
  }

  String _subjectDisplayName(TeachingShift shift) {
    final fromDisplayName = (shift.subjectDisplayName ?? '').trim();
    if (fromDisplayName.isNotEmpty) return fromDisplayName;
    return shift.subject.name;
  }

  _AttentionLevel _attentionLevelForAttendance(
    double attendanceRate,
    int trackedClasses,
  ) {
    if (trackedClasses == 0) return _AttentionLevel.watch;
    if (attendanceRate >= 0.8) return _AttentionLevel.onTrack;
    if (attendanceRate >= 0.6) return _AttentionLevel.watch;
    return _AttentionLevel.needsSupport;
  }

  Widget _buildOverviewCard(_StudentProgressMetrics metrics) {
    final attendancePercent = (metrics.attendanceRate * 100).round();
    final trendDelta = metrics.classesLast7Days - metrics.classesPrevious7Days;
    final trendColor = trendDelta > 0
        ? const Color(0xFF16A34A)
        : trendDelta < 0
            ? const Color(0xFFDC2626)
            : const Color(0xFF64748B);
    final trendIcon = trendDelta > 0
        ? Icons.trending_up_rounded
        : trendDelta < 0
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2B57), Color(0xFF1659B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2B57).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
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
                      '${widget.studentName} Progress',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A focused view of attendance, study volume, and class consistency.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: metrics.attendanceRate.clamp(0.0, 1.0),
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.24),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$attendancePercent%',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Attendance',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 620;
              final cards = [
                _buildHeroMetricCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'Classes (7d)',
                  value: '${metrics.classesLast7Days}',
                ),
                _buildHeroMetricCard(
                  icon: Icons.schedule_rounded,
                  label: 'Hours (30d)',
                  value: metrics.totalHoursLast30Days.toStringAsFixed(1),
                ),
                _buildHeroMetricCard(
                  icon: Icons.menu_book_rounded,
                  label: 'Subjects',
                  value: '${metrics.uniqueSubjectsLast30Days}',
                ),
                _buildHeroMetricCard(
                  icon: Icons.flag_rounded,
                  label: 'Status',
                  value: _attentionLabel(metrics.attentionLevel),
                  accent: _attentionColor(metrics.attentionLevel),
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: cards
                      .map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: card,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: List<Widget>.generate(cards.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: index == cards.length - 1 ? 0 : 10),
                      child: cards[index],
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildWeeklyActivityChart(metrics),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(trendIcon, size: 16, color: trendColor),
              const SizedBox(width: 6),
              Text(
                trendDelta == 0
                    ? 'Stable class activity vs previous week'
                    : trendDelta > 0
                        ? '+$trendDelta class activity vs previous week'
                        : '$trendDelta class activity vs previous week',
                style: GoogleFonts.inter(
                  color: trendColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricCard({
    required IconData icon,
    required String label,
    required String value,
    Color accent = const Color(0xFFBFDBFE),
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityChart(_StudentProgressMetrics metrics) {
    final maxCount = metrics.weeklyCounts.fold<int>(
      0,
      (current, value) => value > current ? value : current,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Weekly Activity',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${metrics.classesLast7Days} classes',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(metrics.weeklyCounts.length, (index) {
                final value = metrics.weeklyCounts[index];
                final normalized = maxCount == 0 ? 0.0 : value / maxCount;
                final barHeight = maxCount == 0 ? 8.0 : 10 + (normalized * 60);
                final dayLabel = _weekLabel(metrics.weekDays[index]);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 12,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$value',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration:
                                Duration(milliseconds: 320 + (index * 35)),
                            height: barHeight,
                            width: 16,
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(alpha: value == 0 ? 0.3 : 0.88),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 12,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              dayLabel,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _weekLabel(DateTime day) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[day.weekday - 1];
  }

  Widget _buildAttendanceBreakdownCard(_StudentProgressMetrics metrics) {
    final attendancePercent = (metrics.attendanceRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Text(
                'Attendance Breakdown (30 days)',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Text(
                metrics.totalTrackedClasses == 0 ? '--' : '$attendancePercent%',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSegmentedAttendanceBar(metrics),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAttendanceMetric(
                  label: 'Completed',
                  value: '${metrics.completedClasses}',
                  valueColor: const Color(0xFF16A34A),
                ),
              ),
              Expanded(
                child: _buildAttendanceMetric(
                  label: 'Missed',
                  value: '${metrics.missedClasses}',
                  valueColor: const Color(0xFFDC2626),
                ),
              ),
              Expanded(
                child: _buildAttendanceMetric(
                  label: 'Cancelled',
                  value: '${metrics.cancelledClasses}',
                  valueColor: const Color(0xFF6B7280),
                ),
              ),
              Expanded(
                child: _buildAttendanceMetric(
                  label: 'Tracked',
                  value: '${metrics.totalTrackedClasses}',
                  valueColor: const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedAttendanceBar(_StudentProgressMetrics metrics) {
    final total = metrics.totalTrackedClasses;
    if (total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (metrics.completedClasses > 0)
              Expanded(
                flex: metrics.completedClasses,
                child: Container(color: const Color(0xFF16A34A)),
              ),
            if (metrics.missedClasses > 0)
              Expanded(
                flex: metrics.missedClasses,
                child: Container(color: const Color(0xFFDC2626)),
              ),
            if (metrics.cancelledClasses > 0)
              Expanded(
                flex: metrics.cancelledClasses,
                child: Container(color: const Color(0xFF9CA3AF)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceMetric({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectProgressCard(_SubjectProgressData data) {
    final completionRate =
        data.totalClasses > 0 ? data.completedClasses / data.totalClasses : 0.0;
    final completionPercent = (completionRate * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                child: Text(
                  data.name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      _completionColor(completionRate).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$completionPercent% completed',
                  style: GoogleFonts.inter(
                    color: _completionColor(completionRate),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completionRate,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(
                  _completionColor(completionRate)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _subjectMetric(
                  label: 'Classes',
                  value: '${data.totalClasses}',
                  color: const Color(0xFF111827),
                ),
              ),
              Expanded(
                child: _subjectMetric(
                  label: 'Completed',
                  value: '${data.completedClasses}',
                  color: const Color(0xFF16A34A),
                ),
              ),
              Expanded(
                child: _subjectMetric(
                  label: 'Hours',
                  value: '${data.totalHours.toStringAsFixed(1)}h',
                  color: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _completionColor(double completionRate) {
    if (completionRate >= 0.8) return const Color(0xFF16A34A);
    if (completionRate >= 0.6) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  Widget _subjectMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Color _attentionColor(_AttentionLevel level) {
    switch (level) {
      case _AttentionLevel.needsSupport:
        return const Color(0xFFDC2626);
      case _AttentionLevel.watch:
        return const Color(0xFFD97706);
      case _AttentionLevel.onTrack:
        return const Color(0xFF15803D);
    }
  }

  String _attentionLabel(_AttentionLevel level) {
    switch (level) {
      case _AttentionLevel.needsSupport:
        return 'Needs Support';
      case _AttentionLevel.watch:
        return 'Watch';
      case _AttentionLevel.onTrack:
        return 'On Track';
    }
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

  Widget _loadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2B57),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading student progress insights...',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(
      {required IconData icon,
      required String title,
      required String subtitle}) {
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

enum _AttentionLevel {
  needsSupport,
  watch,
  onTrack,
}

class _StudentProgressMetrics {
  const _StudentProgressMetrics({
    required this.attendanceRate,
    required this.completedClasses,
    required this.missedClasses,
    required this.cancelledClasses,
    required this.totalTrackedClasses,
    required this.classesLast7Days,
    required this.classesPrevious7Days,
    required this.classesLast30Days,
    required this.uniqueSubjectsLast30Days,
    required this.totalHoursLast30Days,
    required this.weeklyCounts,
    required this.weekDays,
    required this.subjectStats,
    required this.attentionLevel,
  });

  final double attendanceRate;
  final int completedClasses;
  final int missedClasses;
  final int cancelledClasses;
  final int totalTrackedClasses;
  final int classesLast7Days;
  final int classesPrevious7Days;
  final int classesLast30Days;
  final int uniqueSubjectsLast30Days;
  final double totalHoursLast30Days;
  final List<int> weeklyCounts;
  final List<DateTime> weekDays;
  final List<_SubjectProgressData> subjectStats;
  final _AttentionLevel attentionLevel;
}

class _SubjectProgressData {
  const _SubjectProgressData({
    required this.name,
    required this.totalClasses,
    required this.completedClasses,
    required this.missedClasses,
    required this.cancelledClasses,
    required this.totalHours,
  });

  final String name;
  final int totalClasses;
  final int completedClasses;
  final int missedClasses;
  final int cancelledClasses;
  final double totalHours;
}

class _SubjectAccumulator {
  int totalClasses = 0;
  int completedClasses = 0;
  int missedClasses = 0;
  int cancelledClasses = 0;
  double totalHours = 0;
}
