import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/parent_service.dart';
import '../../../core/services/user_role_service.dart';

class StudentProgressScreen extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const StudentProgressScreen({
    super.key,
    this.studentId,
    this.studentName,
  });

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

enum _AttendancePeriod { weekly, monthly }

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  bool _isProfileLoading = true;
  String _studentId = '';
  String _studentName = 'Student';
  _AttendancePeriod _period = _AttendancePeriod.monthly;
  Future<_StudentAttendanceAnalytics>? _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final directId = (widget.studentId ?? '').trim();
    final resolvedId = directId.isNotEmpty
        ? directId
        : (UserRoleService.getCurrentUserId() ??
            FirebaseAuth.instance.currentUser?.uid ??
            '');

    String resolvedName = (widget.studentName ?? '').trim();
    if (resolvedName.isEmpty) {
      final userData = await UserRoleService.getCurrentUserData();
      final firstName = (userData?['first_name'] ?? '').toString().trim();
      final lastName = (userData?['last_name'] ?? '').toString().trim();
      final fullName = '$firstName $lastName'.trim();
      resolvedName = fullName.isNotEmpty ? fullName : 'Student';
    }

    if (!mounted) return;

    setState(() {
      _studentId = resolvedId;
      _studentName = resolvedName;
      _isProfileLoading = false;
      _analyticsFuture = resolvedId.isEmpty ? null : _loadAnalytics();
    });
  }

  String _periodTypeValue() {
    return _period == _AttendancePeriod.weekly ? 'weekly' : 'monthly';
  }

  Future<void> _refreshAnalytics() async {
    if (_studentId.isEmpty) return;
    setState(() {
      _analyticsFuture = _loadAnalytics(forceRefresh: true);
    });
    await _analyticsFuture;
  }

  Future<_StudentAttendanceAnalytics> _loadAnalytics({
    bool forceRefresh = false,
  }) async {
    if (_studentId.isEmpty) {
      return _StudentAttendanceAnalytics.empty();
    }

    final report = await ParentService.getStudentAttendanceReport(
      _studentId,
      periodType: _periodTypeValue(),
      forceRefresh: forceRefresh,
    );

    if (report == null) {
      return _StudentAttendanceAnalytics.empty();
    }

    final metrics = _asMap(report['metrics']);
    final rates = _asMap(report['rates']);
    final averages = _asMap(report['averages']);

    final scheduledClasses = _asInt(metrics['scheduled_classes']);
    final attendedClasses = _asInt(metrics['attended_classes']);
    final absentClasses = _asInt(metrics['absent_classes']);
    final lateClasses = _asInt(metrics['late_classes']);
    final onTimeClasses = _asInt(metrics['on_time_classes']);
    final arrivedBeforeStartClasses =
        _asInt(metrics['arrived_before_start_classes']);
    final teacherAbsentIncidents =
        _asInt(metrics['student_present_teacher_absent_classes']);
    final joinsBeforeStartEvents =
        _asInt(metrics['total_joins_before_start_events']);
    final totalPresenceMinutes =
        _asDouble(metrics['total_student_presence_minutes']) ?? 0.0;
    final totalOverlapMinutes =
        _asDouble(metrics['total_teacher_overlap_minutes']) ?? 0.0;

    final attendanceRate = _asDouble(rates['attendance_rate']) ??
        (scheduledClasses > 0 ? attendedClasses / scheduledClasses : 0.0);
    final punctualityRate = _asDouble(rates['punctuality_rate']) ??
        (attendedClasses > 0 ? onTimeClasses / attendedClasses : 0.0);
    final lateRate = _asDouble(rates['late_rate']) ??
        (attendedClasses > 0 ? lateClasses / attendedClasses : 0.0);
    final presenceCoverageRate =
        _asDouble(rates['presence_coverage_rate']) ?? 0.0;
    final teacherOverlapRate = _asDouble(rates['teacher_overlap_rate']) ?? 0.0;
    final averageJoinOffsetMinutes =
        _asDouble(averages['average_join_offset_minutes']) ?? 0.0;

    return _StudentAttendanceAnalytics(
      hasReport: true,
      scheduledClasses: scheduledClasses,
      attendedClasses: attendedClasses,
      absentClasses: absentClasses,
      lateClasses: lateClasses,
      onTimeClasses: onTimeClasses,
      arrivedBeforeStartClasses: arrivedBeforeStartClasses,
      teacherAbsentIncidents: teacherAbsentIncidents,
      joinsBeforeStartEvents: joinsBeforeStartEvents,
      totalPresenceMinutes: totalPresenceMinutes,
      totalOverlapMinutes: totalOverlapMinutes,
      attendanceRate: attendanceRate.clamp(0.0, 1.0),
      punctualityRate: punctualityRate.clamp(0.0, 1.0),
      lateRate: lateRate.clamp(0.0, 1.0),
      presenceCoverageRate: presenceCoverageRate.clamp(0.0, 1.0),
      teacherOverlapRate: teacherOverlapRate.clamp(0.0, 1.0),
      averageJoinOffsetMinutes: averageJoinOffsetMinutes,
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  void _setPeriod(_AttendancePeriod nextPeriod) {
    if (_period == nextPeriod || _studentId.isEmpty) return;
    setState(() {
      _period = nextPeriod;
      _analyticsFuture = _loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isProfileLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_studentId.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load student profile.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAnalytics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildPeriodToggle(),
                const SizedBox(height: 12),
                FutureBuilder<_StudentAttendanceAnalytics>(
                  future: _analyticsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _loadingCard();
                    }

                    if (snapshot.hasError) {
                      return _errorCard(
                        'Failed to load attendance analytics: ${snapshot.error}',
                      );
                    }

                    final analytics =
                        snapshot.data ?? _StudentAttendanceAnalytics.empty();

                    if (!analytics.hasReport) {
                      return _emptyCard(
                        icon: Icons.insights_outlined,
                        title: 'No attendance analytics yet',
                        subtitle:
                            'Attendance insights will appear once your class attendance is tracked.',
                      );
                    }

                    return Column(
                      children: [
                        _buildTopMetrics(analytics),
                        const SizedBox(height: 12),
                        _buildStatusBreakdown(analytics),
                        const SizedBox(height: 12),
                        _buildAdvancedMetrics(analytics),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2B57), Color(0xFF1659B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Attendance and punctuality insights for $_studentName.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodButton(
              label: 'Weekly',
              selected: _period == _AttendancePeriod.weekly,
              onTap: () => _setPeriod(_AttendancePeriod.weekly),
            ),
          ),
          Expanded(
            child: _buildPeriodButton(
              label: 'Monthly',
              selected: _period == _AttendancePeriod.monthly,
              onTap: () => _setPeriod(_AttendancePeriod.monthly),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color:
                  selected ? const Color(0xFF111827) : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopMetrics(_StudentAttendanceAnalytics analytics) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            label: 'Attendance',
            value: '${(analytics.attendanceRate * 100).round()}%',
            helper:
                '${analytics.attendedClasses}/${analytics.scheduledClasses} classes',
            color: const Color(0xFF0E72ED),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            label: 'On Time',
            value: '${(analytics.punctualityRate * 100).round()}%',
            helper:
                '${analytics.onTimeClasses}/${analytics.attendedClasses} attended',
            color: const Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBreakdown(_StudentAttendanceAnalytics analytics) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Class Status Breakdown',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _smallMetric(
                  'On time',
                  analytics.onTimeClasses.toString(),
                  const Color(0xFF16A34A),
                ),
              ),
              Expanded(
                child: _smallMetric(
                  'Late',
                  analytics.lateClasses.toString(),
                  const Color(0xFFF59E0B),
                ),
              ),
              Expanded(
                child: _smallMetric(
                  'Absent',
                  analytics.absentClasses.toString(),
                  const Color(0xFFDC2626),
                ),
              ),
              Expanded(
                child: _smallMetric(
                  'Attended',
                  analytics.attendedClasses.toString(),
                  const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedMetrics(_StudentAttendanceAnalytics analytics) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Information',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          _detailRow(
            'Arrived before start (classes)',
            analytics.arrivedBeforeStartClasses.toString(),
          ),
          _detailRow(
            'Joined before start (events)',
            analytics.joinsBeforeStartEvents.toString(),
          ),
          _detailRow(
            'Student present / teacher absent',
            analytics.teacherAbsentIncidents.toString(),
          ),
          _detailRow(
            'Average join offset',
            '${analytics.averageJoinOffsetMinutes.toStringAsFixed(1)} min',
          ),
          _detailRow(
            'Presence coverage',
            '${(analytics.presenceCoverageRate * 100).round()}%',
          ),
          _detailRow(
            'Teacher overlap',
            '${(analytics.teacherOverlapRate * 100).round()}%',
          ),
          _detailRow(
            'Total presence minutes',
            analytics.totalPresenceMinutes.toStringAsFixed(1),
          ),
          _detailRow(
            'Teacher overlap minutes',
            analytics.totalOverlapMinutes.toStringAsFixed(1),
          ),
          _detailRow(
            'Late rate',
            '${(analytics.lateRate * 100).round()}%',
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required String helper,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFB91C1C),
        ),
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: const Color(0xFF6B7280)),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentAttendanceAnalytics {
  final bool hasReport;
  final int scheduledClasses;
  final int attendedClasses;
  final int absentClasses;
  final int lateClasses;
  final int onTimeClasses;
  final int arrivedBeforeStartClasses;
  final int teacherAbsentIncidents;
  final int joinsBeforeStartEvents;
  final double totalPresenceMinutes;
  final double totalOverlapMinutes;
  final double attendanceRate;
  final double punctualityRate;
  final double lateRate;
  final double presenceCoverageRate;
  final double teacherOverlapRate;
  final double averageJoinOffsetMinutes;

  const _StudentAttendanceAnalytics({
    required this.hasReport,
    required this.scheduledClasses,
    required this.attendedClasses,
    required this.absentClasses,
    required this.lateClasses,
    required this.onTimeClasses,
    required this.arrivedBeforeStartClasses,
    required this.teacherAbsentIncidents,
    required this.joinsBeforeStartEvents,
    required this.totalPresenceMinutes,
    required this.totalOverlapMinutes,
    required this.attendanceRate,
    required this.punctualityRate,
    required this.lateRate,
    required this.presenceCoverageRate,
    required this.teacherOverlapRate,
    required this.averageJoinOffsetMinutes,
  });

  factory _StudentAttendanceAnalytics.empty() {
    return const _StudentAttendanceAnalytics(
      hasReport: false,
      scheduledClasses: 0,
      attendedClasses: 0,
      absentClasses: 0,
      lateClasses: 0,
      onTimeClasses: 0,
      arrivedBeforeStartClasses: 0,
      teacherAbsentIncidents: 0,
      joinsBeforeStartEvents: 0,
      totalPresenceMinutes: 0,
      totalOverlapMinutes: 0,
      attendanceRate: 0,
      punctualityRate: 0,
      lateRate: 0,
      presenceCoverageRate: 0,
      teacherOverlapRate: 0,
      averageJoinOffsetMinutes: 0,
    );
  }
}
