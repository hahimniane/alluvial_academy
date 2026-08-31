import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/parent/services/parent_service.dart';
import '../../../core/services/user_role_service.dart';
import '../../../l10n/app_localizations.dart';

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

    final rawBreakdown = report['shift_breakdown'];
    final classes = <_ClassAttendance>[];
    if (rawBreakdown is List) {
      for (final entry in rawBreakdown) {
        final item = _asMap(entry);
        final cancelled =
            item['cancelled'] == true || item['status'] == 'cancelled';
        final attended = item['attended'] == true;
        final late = item['late'] == true;
        final presenceMinutes = _asDouble(item['student_presence_minutes']) ?? 0.0;
        final joinEvents = _asInt(item['join_events']);
        final joinedAtAll = presenceMinutes > 0 ||
            joinEvents > 0 ||
            _asDouble(item['first_join_offset_minutes']) != null;
        final _ClassStatus status = cancelled
            ? _ClassStatus.cancelled
            : attended
                ? (late ? _ClassStatus.late : _ClassStatus.attended)
                : joinedAtAll
                    ? _ClassStatus.leftEarly
                    : _ClassStatus.missed;
        final sessions = <_ClassSession>[];
        final rawSessions = item['sessions'];
        if (rawSessions is List) {
          for (final s in rawSessions) {
            final sm = _asMap(s);
            sessions.add(_ClassSession(
              join: _parseDate(sm['join_iso']),
              leave: _parseDate(sm['leave_iso']),
              minutes: _asDouble(sm['minutes']) ?? 0.0,
            ));
          }
        }
        classes.add(_ClassAttendance(
          shiftId: (item['shift_id'] ?? '').toString(),
          start: _parseDate(item['shift_start_iso']),
          end: _parseDate(item['shift_end_iso']),
          subject: (item['subject'] ?? '').toString(),
          status: status,
          joinOffsetMinutes: _asDouble(item['first_join_offset_minutes']),
          presenceMinutes: presenceMinutes,
          teacherOverlapMinutes: _asDouble(item['teacher_overlap_minutes']) ?? 0.0,
          teacherPresent: item['teacher_present'] == true,
          joinCount: joinEvents,
          firstJoin: _parseDate(item['first_join_iso']),
          lastLeave: _parseDate(item['last_leave_iso']),
          sessions: sessions,
          teacherAbsent: item['student_present_teacher_absent'] == true,
        ));
      }
      classes.sort((a, b) =>
          (b.start?.millisecondsSinceEpoch ?? 0) -
          (a.start?.millisecondsSinceEpoch ?? 0));
    }

    return _StudentAttendanceAnalytics(
      hasReport: true,
      classes: classes,
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

  DateTime? _parseDate(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
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
      body: ScrollNotificationObserver(
        child: SelectionArea(
          child: SafeArea(
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
                        _buildClassByClass(analytics),
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
    final l10n = AppLocalizations.of(context)!;
    final cards = [
      _metricCard(
        label: l10n.studentAttendanceStudentClassTime,
        value: _formatClassHours(l10n, analytics.totalPresenceMinutes),
        helper: _period == _AttendancePeriod.weekly
            ? l10n.studentAttendanceWeekly
            : l10n.studentAttendanceMonthly,
        color: const Color(0xFF7C3AED),
      ),
      _metricCard(
        label: l10n.studentAttendanceRate,
        value: '${(analytics.attendanceRate * 100).round()}%',
        helper:
            '${analytics.attendedClasses}/${analytics.scheduledClasses} classes',
        color: const Color(0xFF0E72ED),
      ),
      _metricCard(
        label: 'On Time',
        value: '${(analytics.punctualityRate * 100).round()}%',
        helper:
            '${analytics.onTimeClasses}/${analytics.attendedClasses} attended',
        color: const Color(0xFF16A34A),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Three compact tiles side by side — phones included. Only collapse to
        // a column on truly tiny widths where three-across can't breathe.
        if (constraints.maxWidth < 300) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                SizedBox(width: double.infinity, child: cards[index]),
                if (index < cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                Expanded(child: cards[index]),
                if (index < cards.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatClassHours(AppLocalizations l10n, double minutes) {
    return l10n.studentAttendanceHoursValue((minutes / 60).toStringAsFixed(1));
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

  Widget _buildClassByClass(_StudentAttendanceAnalytics analytics) {
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
            'Class by class',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          if (analytics.classes.isEmpty)
            Text(
              'No class history in this period yet.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            )
          else
            ...analytics.classes.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _classRow(c),
              ),
            ),
        ],
      ),
    );
  }

  Widget _classRow(_ClassAttendance c) {
    final s = _statusStyle(c.status);
    final when = c.start != null
        ? '${DateFormat('EEE, MMM d').format(c.start!)} · ${DateFormat.jm().format(c.start!)}'
        : '';
    final detail = _classDetailLine(c);
    final subtitle = [when, if (detail.isNotEmpty) detail].join(' · ');
    return InkWell(
      onTap: () => _showClassDetail(c),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: s.dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.subject.isEmpty ? 'Class' : c.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: s.bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                s.label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: s.fg,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  _StatusStyle _statusStyle(_ClassStatus status) {
    switch (status) {
      case _ClassStatus.attended:
        return const _StatusStyle('Attended', Color(0xFFDCFCE7),
            Color(0xFF166534), Color(0xFF16A34A));
      case _ClassStatus.late:
        return const _StatusStyle('Late', Color(0xFFFEF3C7),
            Color(0xFF92400E), Color(0xFFF59E0B));
      case _ClassStatus.leftEarly:
        return const _StatusStyle('Left early', Color(0xFFFEF3C7),
            Color(0xFF92400E), Color(0xFFF97316));
      case _ClassStatus.missed:
        return const _StatusStyle('Missed', Color(0xFFFEE2E2),
            Color(0xFFB91C1C), Color(0xFFEF4444));
      case _ClassStatus.cancelled:
        return const _StatusStyle('Cancelled', Color(0xFFF1F5F9),
            Color(0xFF64748B), Color(0xFF94A3B8));
    }
  }

  String _classDetailLine(_ClassAttendance c) {
    switch (c.status) {
      case _ClassStatus.attended:
      case _ClassStatus.late:
        final off = c.joinOffsetMinutes;
        if (off == null) return 'Joined';
        final m = off.round();
        if (m > 0) return 'Joined $m min late';
        if (m < 0) return 'Joined ${m.abs()} min early';
        return 'Joined on time';
      case _ClassStatus.leftEarly:
        final m = c.presenceMinutes.round();
        return 'Joined ${m < 1 ? 1 : m} min, left early';
      case _ClassStatus.missed:
        return 'Did not join';
      case _ClassStatus.cancelled:
        return '';
    }
  }

  String _fmtMins(double minutes) {
    final total = minutes.round() < 0 ? 0 : minutes.round();
    if (total < 60) return '$total min';
    final h = total ~/ 60;
    final min = total % 60;
    return min == 0 ? '$h h' : '$h h $min min';
  }

  void _showClassDetail(_ClassAttendance c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _classDetailSheet(c),
    );
  }

  Widget _classDetailSheet(_ClassAttendance c) {
    String tm(DateTime? d) => d != null ? DateFormat.jm().format(d) : '—';
    final header = c.start != null
        ? '${DateFormat('EEEE, MMMM d').format(c.start!)} · ${tm(c.start)}${c.end != null ? ' – ${tm(c.end)}' : ''}'
        : '';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              c.subject.isEmpty ? 'Class' : c.subject,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              header,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _statTile('First joined', tm(c.firstJoin))),
              const SizedBox(width: 8),
              Expanded(child: _statTile('Last left', tm(c.lastLeave))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _statTile('Time in class', _fmtMins(c.presenceMinutes))),
              const SizedBox(width: 8),
              Expanded(
                  child: _statTile(
                      'Time with teacher', _fmtMins(c.teacherOverlapMinutes))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _statTile('Times joined', c.joinCount.toString())),
              const SizedBox(width: 8),
              Expanded(
                  child: _statTile(
                      'Teacher present', c.teacherPresent ? 'Yes' : 'No')),
            ]),
            const SizedBox(height: 16),
            Text(
              'Sessions',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            if (c.sessions.isEmpty)
              Text(
                'This student never joined this class.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              )
            else
              ...List.generate(c.sessions.length, (i) {
                final s = c.sessions[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${tm(s.join)} → ${tm(s.leave)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      _fmtMins(s.minutes),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ]),
                );
              }),
            if (c.sessions.length > 1) ...[
              const SizedBox(height: 4),
              Text(
                c.sessions.length == 2
                    ? 'Left and rejoined once'
                    : 'Left and rejoined ${c.sessions.length - 1} times',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
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
  final List<_ClassAttendance> classes;

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
    this.classes = const [],
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
      classes: [],
    );
  }
}

enum _ClassStatus { attended, late, leftEarly, missed, cancelled }

class _StatusStyle {
  final String label;
  final Color bg;
  final Color fg;
  final Color dot;
  const _StatusStyle(this.label, this.bg, this.fg, this.dot);
}

class _ClassSession {
  final DateTime? join;
  final DateTime? leave;
  final double minutes;
  const _ClassSession({this.join, this.leave, required this.minutes});
}

/// One class in the class-by-class list: the exact class and what happened.
class _ClassAttendance {
  final String shiftId;
  final DateTime? start;
  final DateTime? end;
  final String subject;
  final _ClassStatus status;
  final double? joinOffsetMinutes;
  final double presenceMinutes;
  final double teacherOverlapMinutes;
  final bool teacherPresent;
  final int joinCount;
  final DateTime? firstJoin;
  final DateTime? lastLeave;
  final List<_ClassSession> sessions;
  final bool teacherAbsent;

  const _ClassAttendance({
    required this.shiftId,
    required this.start,
    required this.end,
    required this.subject,
    required this.status,
    required this.joinOffsetMinutes,
    required this.presenceMinutes,
    required this.teacherOverlapMinutes,
    required this.teacherPresent,
    required this.joinCount,
    required this.firstJoin,
    required this.lastLeave,
    required this.sessions,
    required this.teacherAbsent,
  });
}
