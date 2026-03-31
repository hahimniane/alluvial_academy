import 'package:cloud_firestore/cloud_firestore.dart';

/// Performance tier based on overall score
enum PerformanceTier {
  excellent,   // >= 90%
  good,        // >= 75%
  needsImprovement, // >= 60%
  critical,    // < 60%
}

extension PerformanceTierExtension on PerformanceTier {
  String get displayName {
    switch (this) {
      case PerformanceTier.excellent:
        return 'Excellent';
      case PerformanceTier.good:
        return 'Good';
      case PerformanceTier.needsImprovement:
        return 'Needs Improvement';
      case PerformanceTier.critical:
        return 'Critical';
    }
  }

  String get emoji {
    switch (this) {
      case PerformanceTier.excellent:
        return '🏆';
      case PerformanceTier.good:
        return '✅';
      case PerformanceTier.needsImprovement:
        return '⚠️';
      case PerformanceTier.critical:
        return '🔴';
    }
  }

  static PerformanceTier fromScore(double score) {
    if (score >= 90) return PerformanceTier.excellent;
    if (score >= 75) return PerformanceTier.good;
    if (score >= 60) return PerformanceTier.needsImprovement;
    return PerformanceTier.critical;
  }

  static PerformanceTier fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'excellent':
        return PerformanceTier.excellent;
      case 'good':
        return PerformanceTier.good;
      case 'needsimprovement':
      case 'needs_improvement':
        return PerformanceTier.needsImprovement;
      case 'critical':
        return PerformanceTier.critical;
      default:
        return PerformanceTier.needsImprovement;
    }
  }
}

/// Audit flag types for issues
enum AuditFlag {
  missedClass,
  lateClockIn,
  missingForm,
  lowAttendance,
  lowQuizScores,
}

/// Individual audit flag with details
class AuditFlagDetail {
  final AuditFlag type;
  final String description;
  final DateTime? date;
  final String? shiftId;

  const AuditFlagDetail({
    required this.type,
    required this.description,
    this.date,
    this.shiftId,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'description': description,
        'date': date?.toIso8601String(),
        'shiftId': shiftId,
      };

  factory AuditFlagDetail.fromMap(Map<String, dynamic> map) {
    return AuditFlagDetail(
      type: AuditFlag.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AuditFlag.missedClass,
      ),
      description: map['description'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      shiftId: map['shiftId'],
    );
  }
}

/// Complete audit metrics for a teacher for a specific month
class TeacherAuditMetrics {
  final String id; // {userId}_{yearMonth}
  final String oderId;
  final String teacherEmail;
  final String teacherName;
  final String yearMonth; // "2026-01"

  // Schedule Metrics
  final int scheduledClasses;
  final int completedClasses;
  final int missedClasses;
  final int cancelledClasses;
  final double completionRate; // (completed / scheduled) * 100

  // Punctuality Metrics
  final int totalClockIns;
  final int onTimeClockIns;
  final int lateClockIns; // > 5 min late
  final int earlyClockIns;
  final double avgClockInDeltaMinutes; // Negative = early, Positive = late
  final double punctualityRate; // (onTime / total) * 100

  // Form Compliance Metrics
  final int formsRequired;
  final int formsSubmitted;
  final int formsOnTime; // Submitted within 24h of shift
  final int formsMissing;
  final double formComplianceRate; // (submitted / required) * 100

  // Student Outcome Metrics
  final double avgQuizScore; // 0-100
  final int totalQuizzesTaken;
  final double assignmentCompletionRate; // % of assignments submitted by students
  final int totalAssignmentsGiven;
  final int totalAssignmentsSubmitted;
  final double attendanceRate; // % average attendance per class
  final int totalStudentsEnrolled;
  final int avgStudentsPresent;

  // Overall
  final double overallScore; // Weighted average 0-100
  final PerformanceTier performanceTier;

  // Flags and issues
  final List<AuditFlagDetail> flags;

  // Metadata
  final DateTime lastUpdated;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const TeacherAuditMetrics({
    required this.id,
    required this.oderId,
    required this.teacherEmail,
    required this.teacherName,
    required this.yearMonth,
    required this.scheduledClasses,
    required this.completedClasses,
    required this.missedClasses,
    required this.cancelledClasses,
    required this.completionRate,
    required this.totalClockIns,
    required this.onTimeClockIns,
    required this.lateClockIns,
    required this.earlyClockIns,
    required this.avgClockInDeltaMinutes,
    required this.punctualityRate,
    required this.formsRequired,
    required this.formsSubmitted,
    required this.formsOnTime,
    required this.formsMissing,
    required this.formComplianceRate,
    required this.avgQuizScore,
    required this.totalQuizzesTaken,
    required this.assignmentCompletionRate,
    required this.totalAssignmentsGiven,
    required this.totalAssignmentsSubmitted,
    required this.attendanceRate,
    required this.totalStudentsEnrolled,
    required this.avgStudentsPresent,
    required this.overallScore,
    required this.performanceTier,
    required this.flags,
    required this.lastUpdated,
    this.periodStart,
    this.periodEnd,
  });

  /// Calculate overall score with weights
  /// Completion: 30%, Punctuality: 20%, Form Compliance: 15%, Student Outcomes: 35%
  static double calculateOverallScore({
    required double completionRate,
    required double punctualityRate,
    required double formComplianceRate,
    required double avgQuizScore,
    required double assignmentCompletionRate,
    required double attendanceRate,
  }) {
    // Student outcomes is average of quiz, assignment, and attendance
    final studentOutcomes =
        (avgQuizScore + assignmentCompletionRate + attendanceRate) / 3;

    return (completionRate * 0.30) +
        (punctualityRate * 0.20) +
        (formComplianceRate * 0.15) +
        (studentOutcomes * 0.35);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': oderId,
        'teacherEmail': teacherEmail,
        'teacherName': teacherName,
        'yearMonth': yearMonth,
        'scheduledClasses': scheduledClasses,
        'completedClasses': completedClasses,
        'missedClasses': missedClasses,
        'cancelledClasses': cancelledClasses,
        'completionRate': completionRate,
        'totalClockIns': totalClockIns,
        'onTimeClockIns': onTimeClockIns,
        'lateClockIns': lateClockIns,
        'earlyClockIns': earlyClockIns,
        'avgClockInDeltaMinutes': avgClockInDeltaMinutes,
        'punctualityRate': punctualityRate,
        'formsRequired': formsRequired,
        'formsSubmitted': formsSubmitted,
        'formsOnTime': formsOnTime,
        'formsMissing': formsMissing,
        'formComplianceRate': formComplianceRate,
        'avgQuizScore': avgQuizScore,
        'totalQuizzesTaken': totalQuizzesTaken,
        'assignmentCompletionRate': assignmentCompletionRate,
        'totalAssignmentsGiven': totalAssignmentsGiven,
        'totalAssignmentsSubmitted': totalAssignmentsSubmitted,
        'attendanceRate': attendanceRate,
        'totalStudentsEnrolled': totalStudentsEnrolled,
        'avgStudentsPresent': avgStudentsPresent,
        'overallScore': overallScore,
        'performanceTier': performanceTier.name,
        'flags': flags.map((f) => f.toMap()).toList(),
        'lastUpdated': Timestamp.fromDate(lastUpdated),
        'periodStart': periodStart != null ? Timestamp.fromDate(periodStart!) : null,
        'periodEnd': periodEnd != null ? Timestamp.fromDate(periodEnd!) : null,
      };

  factory TeacherAuditMetrics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeacherAuditMetrics.fromMap(data, doc.id);
  }

  factory TeacherAuditMetrics.fromMap(Map<String, dynamic> data, String docId) {
    final flagsList = (data['flags'] as List<dynamic>?)
            ?.map((f) => AuditFlagDetail.fromMap(f as Map<String, dynamic>))
            .toList() ??
        [];

    return TeacherAuditMetrics(
      id: docId,
      oderId: data['userId'] ?? '',
      teacherEmail: data['teacherEmail'] ?? '',
      teacherName: data['teacherName'] ?? '',
      yearMonth: data['yearMonth'] ?? '',
      scheduledClasses: data['scheduledClasses'] ?? 0,
      completedClasses: data['completedClasses'] ?? 0,
      missedClasses: data['missedClasses'] ?? 0,
      cancelledClasses: data['cancelledClasses'] ?? 0,
      completionRate: (data['completionRate'] ?? 0).toDouble(),
      totalClockIns: data['totalClockIns'] ?? 0,
      onTimeClockIns: data['onTimeClockIns'] ?? 0,
      lateClockIns: data['lateClockIns'] ?? 0,
      earlyClockIns: data['earlyClockIns'] ?? 0,
      avgClockInDeltaMinutes: (data['avgClockInDeltaMinutes'] ?? 0).toDouble(),
      punctualityRate: (data['punctualityRate'] ?? 0).toDouble(),
      formsRequired: data['formsRequired'] ?? 0,
      formsSubmitted: data['formsSubmitted'] ?? 0,
      formsOnTime: data['formsOnTime'] ?? 0,
      formsMissing: data['formsMissing'] ?? 0,
      formComplianceRate: (data['formComplianceRate'] ?? 0).toDouble(),
      avgQuizScore: (data['avgQuizScore'] ?? 0).toDouble(),
      totalQuizzesTaken: data['totalQuizzesTaken'] ?? 0,
      assignmentCompletionRate:
          (data['assignmentCompletionRate'] ?? 0).toDouble(),
      totalAssignmentsGiven: data['totalAssignmentsGiven'] ?? 0,
      totalAssignmentsSubmitted: data['totalAssignmentsSubmitted'] ?? 0,
      attendanceRate: (data['attendanceRate'] ?? 0).toDouble(),
      totalStudentsEnrolled: data['totalStudentsEnrolled'] ?? 0,
      avgStudentsPresent: data['avgStudentsPresent'] ?? 0,
      overallScore: (data['overallScore'] ?? 0).toDouble(),
      performanceTier: PerformanceTierExtension.fromString(data['performanceTier']),
      flags: flagsList,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodStart: (data['periodStart'] as Timestamp?)?.toDate(),
      periodEnd: (data['periodEnd'] as Timestamp?)?.toDate(),
    );
  }

  /// Create an empty metrics object for a teacher/month
  factory TeacherAuditMetrics.empty({
    required String oderId,
    required String teacherEmail,
    required String teacherName,
    required String yearMonth,
  }) {
    return TeacherAuditMetrics(
      id: '${oderId}_$yearMonth',
      oderId: oderId,
      teacherEmail: teacherEmail,
      teacherName: teacherName,
      yearMonth: yearMonth,
      scheduledClasses: 0,
      completedClasses: 0,
      missedClasses: 0,
      cancelledClasses: 0,
      completionRate: 0,
      totalClockIns: 0,
      onTimeClockIns: 0,
      lateClockIns: 0,
      earlyClockIns: 0,
      avgClockInDeltaMinutes: 0,
      punctualityRate: 0,
      formsRequired: 0,
      formsSubmitted: 0,
      formsOnTime: 0,
      formsMissing: 0,
      formComplianceRate: 0,
      avgQuizScore: 0,
      totalQuizzesTaken: 0,
      assignmentCompletionRate: 0,
      totalAssignmentsGiven: 0,
      totalAssignmentsSubmitted: 0,
      attendanceRate: 0,
      totalStudentsEnrolled: 0,
      avgStudentsPresent: 0,
      overallScore: 0,
      performanceTier: PerformanceTier.needsImprovement,
      flags: [],
      lastUpdated: DateTime.now(),
    );
  }
}

