import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../audit/models/teacher_audit_full.dart';
import '../../audit/services/teacher_audit_service.dart';
import 'package:alluwalacademyadmin/core/services/teacher_metrics_service.dart';
import '../../shift_management/models/teaching_shift.dart';

class TeacherDashboardMonthSnapshot {
  final String yearMonth;
  final double hoursTaught;
  final int submittedForms;
  final int lateClockIns;
  final int absences;
  final int excusedAbsences;
  final TeacherAuditFull? latestVisibleAudit;

  const TeacherDashboardMonthSnapshot({
    required this.yearMonth,
    required this.hoursTaught,
    required this.submittedForms,
    required this.lateClockIns,
    required this.absences,
    required this.excusedAbsences,
    required this.latestVisibleAudit,
  });

  DateTime get monthStart => DateTime.parse('$yearMonth-01');

  bool get hasAudit => latestVisibleAudit != null;
}

class TeacherDashboardMetricsService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<TeacherDashboardMonthSnapshot?> loadCurrentSnapshot({
    required List<TeachingShift> shifts,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final now = DateTime.now();
    final yearMonth = DateFormat('yyyy-MM').format(now);
    final metricsFuture = TeacherMetricsService.aggregate(
      teacherId: user.uid,
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
    final latestAuditFuture =
        _loadLatestVisibleAudit(user.uid, preferredYearMonth: yearMonth);
    final results = await Future.wait([metricsFuture, latestAuditFuture]);
    final metrics = results[0] as TeacherBasicMetrics;
    final latestAudit = results[1] as TeacherAuditFull?;
    final excusedAbsences =
        latestAudit?.yearMonth == yearMonth ? latestAudit!.excusedAbsences : 0;

    return TeacherDashboardMonthSnapshot(
      yearMonth: yearMonth,
      hoursTaught: metrics.hoursWorked,
      submittedForms: metrics.formsSubmitted,
      lateClockIns: metrics.lateClockIns,
      absences: metrics.missedClasses,
      excusedAbsences: excusedAbsences,
      latestVisibleAudit: latestAudit,
    );
  }

  static Future<TeacherAuditFull?> _loadLatestVisibleAudit(
    String teacherId, {
    required String preferredYearMonth,
  }) async {
    final months =
        await TeacherAuditService.getAvailableYearMonthsForTeacher(teacherId);
    if (months.isEmpty) return null;

    final orderedMonths = <String>[
      if (months.contains(preferredYearMonth)) preferredYearMonth,
      ...months.where((month) => month != preferredYearMonth).toList()
        ..sort((a, b) => b.compareTo(a)),
    ];

    for (final yearMonth in orderedMonths) {
      final audit = await TeacherAuditService.getAudit(
          oderId: teacherId, yearMonth: yearMonth);
      if (audit != null &&
          TeacherAuditService.isTeacherVisibleStatus(audit.status)) {
        return audit;
      }
    }
    return null;
  }
}
