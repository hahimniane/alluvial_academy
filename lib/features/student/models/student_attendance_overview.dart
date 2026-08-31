class StudentAttendanceOverview {
  const StudentAttendanceOverview({
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.students,
    required this.totals,
  });

  final String periodType;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final List<StudentAttendanceOverviewRow> students;
  final StudentAttendanceOverviewTotals totals;

  factory StudentAttendanceOverview.fromMap(Map<String, dynamic> map) {
    final rawStudents = map['students'];
    return StudentAttendanceOverview(
      periodType: (map['period_type'] ?? '').toString(),
      periodStart: DateTime.tryParse((map['period_start'] ?? '').toString()),
      periodEnd: DateTime.tryParse((map['period_end'] ?? '').toString()),
      students: rawStudents is List
          ? rawStudents
              .whereType<Map>()
              .map((item) => StudentAttendanceOverviewRow.fromMap(
                    item.map(
                      (key, value) => MapEntry(key.toString(), value),
                    ),
                  ))
              .toList()
          : const [],
      totals: StudentAttendanceOverviewTotals.fromMap(
        _asMap(map['totals']),
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }
}

class StudentAttendanceOverviewRow {
  const StudentAttendanceOverviewRow({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentPhone,
    required this.totalPresenceMinutes,
    required this.totalTeacherOverlapMinutes,
    required this.scheduledClasses,
    required this.attendedClasses,
    required this.absentClasses,
    required this.lateClasses,
    required this.attendanceRate,
    required this.punctualityRate,
  });

  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentPhone;
  final double totalPresenceMinutes;
  final double totalTeacherOverlapMinutes;
  final int scheduledClasses;
  final int attendedClasses;
  final int absentClasses;
  final int lateClasses;
  final double attendanceRate;
  final double punctualityRate;

  factory StudentAttendanceOverviewRow.fromMap(Map<String, dynamic> map) {
    return StudentAttendanceOverviewRow(
      studentId: (map['student_id'] ?? '').toString(),
      studentName: (map['student_name'] ?? '').toString(),
      studentEmail: (map['student_email'] ?? '').toString(),
      studentPhone: (map['student_phone'] ?? '').toString(),
      totalPresenceMinutes: _asDouble(map['total_presence_minutes']),
      totalTeacherOverlapMinutes:
          _asDouble(map['total_teacher_overlap_minutes']),
      scheduledClasses: _asInt(map['scheduled_classes']),
      attendedClasses: _asInt(map['attended_classes']),
      absentClasses: _asInt(map['absent_classes']),
      lateClasses: _asInt(map['late_classes']),
      attendanceRate: _asDouble(map['attendance_rate']),
      punctualityRate: _asDouble(map['punctuality_rate']),
    );
  }
}

class StudentAttendanceOverviewTotals {
  const StudentAttendanceOverviewTotals({
    required this.totalPresenceMinutes,
    required this.totalTeacherOverlapMinutes,
    required this.scheduledClasses,
    required this.attendedClasses,
    required this.absentClasses,
    required this.lateClasses,
    required this.attendanceRate,
  });

  final double totalPresenceMinutes;
  final double totalTeacherOverlapMinutes;
  final int scheduledClasses;
  final int attendedClasses;
  final int absentClasses;
  final int lateClasses;
  final double attendanceRate;

  factory StudentAttendanceOverviewTotals.fromMap(Map<String, dynamic> map) {
    return StudentAttendanceOverviewTotals(
      totalPresenceMinutes: _asDouble(map['total_presence_minutes']),
      totalTeacherOverlapMinutes:
          _asDouble(map['total_teacher_overlap_minutes']),
      scheduledClasses: _asInt(map['scheduled_classes']),
      attendedClasses: _asInt(map['attended_classes']),
      absentClasses: _asInt(map['absent_classes']),
      lateClasses: _asInt(map['late_classes']),
      attendanceRate: _asDouble(map['attendance_rate']),
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0;
}

int _asInt(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse((value ?? '').toString()) ?? 0;
}
