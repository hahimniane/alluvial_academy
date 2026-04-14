import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/features/audit/models/teacher_audit_full.dart';
import 'package:alluwalacademyadmin/features/audit/services/teacher_audit_service.dart';
import 'package:alluwalacademyadmin/features/shift_management/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';

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
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<TeacherDashboardMonthSnapshot?> loadCurrentSnapshot({
    required List<TeachingShift> shifts,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final now = DateTime.now();
    final yearMonth = DateFormat('yyyy-MM').format(now);

    final timesheetsFuture = _firestore
        .collection('timesheet_entries')
        .where('teacher_id', isEqualTo: user.uid)
        .get();
    final formsFuture = _firestore
        .collection('form_responses')
        .where('userId', isEqualTo: user.uid)
        .get();
    final latestAuditFuture =
        _loadLatestVisibleAudit(user.uid, preferredYearMonth: yearMonth);

    final results = await Future.wait([
      timesheetsFuture,
      formsFuture,
      latestAuditFuture,
    ]);

    final timesheetsSnapshot =
        results[0] as QuerySnapshot<Map<String, dynamic>>;
    final formsSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final latestAudit = results[2] as TeacherAuditFull?;

    final monthShifts = shifts.where((shift) {
      final shiftStart = shift.shiftStart.toLocal();
      return shift.category == ShiftCategory.teaching &&
          shiftStart.year == now.year &&
          shiftStart.month == now.month;
    }).toList();

    final monthShiftById = {
      for (final shift in monthShifts) shift.id: shift,
    };

    double hoursTaught = 0;
    int lateClockIns = 0;

    for (final doc in timesheetsSnapshot.docs) {
      final data = doc.data();
      final clockIn = _extractTimestamp(
        data['clock_in_timestamp'] ?? data['clock_in_time'] ?? data['clock_in'],
      );
      if (clockIn == null || !_matchesYearMonth(clockIn.toLocal(), yearMonth)) {
        continue;
      }

      final workedHours = _extractWorkedHours(data, clockIn);
      if (workedHours > 0) {
        hoursTaught += workedHours;
      }

      final shiftId =
          (data['shift_id'] as String?) ?? (data['shiftId'] as String?);
      if (shiftId == null) continue;
      final shift = monthShiftById[shiftId];
      if (shift == null) continue;

      final deltaMinutes =
          clockIn.toLocal().difference(shift.shiftStart.toLocal()).inMinutes;
      if (deltaMinutes > 5) {
        lateClockIns += 1;
      }
    }

    final absences =
        monthShifts.where((shift) => shift.status == ShiftStatus.missed).length;
    final excusedAbsences =
        latestAudit?.yearMonth == yearMonth ? latestAudit!.excusedAbsences : 0;

    return TeacherDashboardMonthSnapshot(
      yearMonth: yearMonth,
      hoursTaught: hoursTaught,
      submittedForms: formsSnapshot.docs
          .where((doc) => (doc.data()['yearMonth'] as String?) == yearMonth)
          .length,
      lateClockIns: lateClockIns,
      absences: absences,
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

  static bool _matchesYearMonth(DateTime value, String yearMonth) {
    return DateFormat('yyyy-MM').format(value) == yearMonth;
  }

  static DateTime? _extractTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static double _extractWorkedHours(
    Map<String, dynamic> data,
    DateTime clockIn,
  ) {
    final workedMinutes = (data['worked_minutes'] as num?)?.toDouble() ??
        (data['workedMinutes'] as num?)?.toDouble();
    if (workedMinutes != null && workedMinutes > 0) {
      return workedMinutes / 60.0;
    }

    final totalHours = (data['total_hours'] ?? data['totalHours'])?.toString();
    if (totalHours != null && totalHours.isNotEmpty) {
      final parts = totalHours.split(':');
      if (parts.length >= 2) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        final seconds = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
        return hours + (minutes / 60.0) + (seconds / 3600.0);
      }
    }

    final effectiveEnd = _extractTimestamp(
      data['effective_end_timestamp'] ?? data['clock_out_timestamp'],
    );
    if (effectiveEnd == null) return 0;

    final duration = effectiveEnd.difference(clockIn);
    if (duration.isNegative) return 0;
    return duration.inSeconds / 3600.0;
  }
}
