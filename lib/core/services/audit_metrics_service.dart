import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teacher_audit_metrics.dart';
import '../utils/app_logger.dart';

/// Service for computing and retrieving teacher audit metrics
class AuditMetricsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _metricsCollection = 'audit_metrics';
  static const String _pilotMetricsCollection = 'pilot_audit_metrics';

  /// Get metrics for a specific teacher and month
  static Future<TeacherAuditMetrics?> getMetrics({
    required String oderId,
    required String yearMonth,
    bool pilotOnly = false,
  }) async {
    try {
      final collection = pilotOnly ? _pilotMetricsCollection : _metricsCollection;
      final docId = '${oderId}_$yearMonth';

      final doc = await _firestore.collection(collection).doc(docId).get();
      if (doc.exists) {
        return TeacherAuditMetrics.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      AppLogger.error('AuditMetricsService: Error getting metrics: $e');
      return null;
    }
  }

  /// Get all metrics for a month (all teachers)
  static Future<List<TeacherAuditMetrics>> getAllMetricsForMonth(
    String yearMonth, {
    bool pilotOnly = false,
  }) async {
    try {
      final collection = pilotOnly ? _pilotMetricsCollection : _metricsCollection;

      final snapshot = await _firestore
          .collection(collection)
          .where('yearMonth', isEqualTo: yearMonth)
          .orderBy('overallScore', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TeacherAuditMetrics.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.error('AuditMetricsService: Error getting all metrics: $e');
      return [];
    }
  }

  /// Get metrics for a teacher across multiple months
  static Future<List<TeacherAuditMetrics>> getMetricsHistory({
    required String oderId,
    int months = 6,
    bool pilotOnly = false,
  }) async {
    try {
      final collection = pilotOnly ? _pilotMetricsCollection : _metricsCollection;

      final snapshot = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: oderId)
          .orderBy('yearMonth', descending: true)
          .limit(months)
          .get();

      return snapshot.docs
          .map((doc) => TeacherAuditMetrics.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.error('AuditMetricsService: Error getting metrics history: $e');
      return [];
    }
  }

  /// Get metrics filtered by performance tier
  static Future<List<TeacherAuditMetrics>> getMetricsByTier({
    required String yearMonth,
    required PerformanceTier tier,
    bool pilotOnly = false,
  }) async {
    try {
      final collection = pilotOnly ? _pilotMetricsCollection : _metricsCollection;

      final snapshot = await _firestore
          .collection(collection)
          .where('yearMonth', isEqualTo: yearMonth)
          .where('performanceTier', isEqualTo: tier.name)
          .orderBy('overallScore', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TeacherAuditMetrics.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.error('AuditMetricsService: Error getting metrics by tier: $e');
      return [];
    }
  }

  /// Get summary statistics for a month
  static Future<Map<String, dynamic>> getMonthSummary(
    String yearMonth, {
    bool pilotOnly = false,
  }) async {
    try {
      final metrics = await getAllMetricsForMonth(yearMonth, pilotOnly: pilotOnly);

      if (metrics.isEmpty) {
        return {
          'totalTeachers': 0,
          'avgOverallScore': 0.0,
          'avgCompletionRate': 0.0,
          'avgPunctualityRate': 0.0,
          'avgFormComplianceRate': 0.0,
          'tierCounts': <String, int>{},
          'totalFlags': 0,
        };
      }

      final tierCounts = <String, int>{};
      for (final tier in PerformanceTier.values) {
        tierCounts[tier.displayName] = metrics.where((m) => m.performanceTier == tier).length;
      }

      return {
        'totalTeachers': metrics.length,
        'avgOverallScore': metrics.map((m) => m.overallScore).reduce((a, b) => a + b) / metrics.length,
        'avgCompletionRate': metrics.map((m) => m.completionRate).reduce((a, b) => a + b) / metrics.length,
        'avgPunctualityRate': metrics.map((m) => m.punctualityRate).reduce((a, b) => a + b) / metrics.length,
        'avgFormComplianceRate': metrics.map((m) => m.formComplianceRate).reduce((a, b) => a + b) / metrics.length,
        'tierCounts': tierCounts,
        'totalFlags': metrics.map((m) => m.flags.length).reduce((a, b) => a + b),
      };
    } catch (e) {
      AppLogger.error('AuditMetricsService: Error getting month summary: $e');
      return {};
    }
  }

  /// Compute and save metrics for a specific teacher and month
  /// This is typically called by a Cloud Function or script
  static Future<TeacherAuditMetrics?> computeAndSaveMetrics({
    required String oderId,
    required String teacherEmail,
    required String teacherName,
    required String yearMonth,
    bool pilotOnly = false,
  }) async {
    try {
      // Parse yearMonth to get date range
      final parts = yearMonth.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      // 1. Get schedule metrics from teaching_shifts
      final shiftsSnapshot = await _firestore
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: oderId)
          .where('shift_start', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('shift_start', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      int scheduledClasses = shiftsSnapshot.docs.length;
      int completedClasses = 0;
      int missedClasses = 0;
      int cancelledClasses = 0;
      final flags = <AuditFlagDetail>[];

      for (final doc in shiftsSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        switch (status) {
          case 'completed':
          case 'fullyCompleted':
          case 'partiallyCompleted':
            completedClasses++;
            break;
          case 'missed':
            missedClasses++;
            flags.add(AuditFlagDetail(
              type: AuditFlag.missedClass,
              description: 'Missed class: ${doc.data()['auto_generated_name'] ?? 'Unknown'}',
              date: (doc.data()['shift_start'] as Timestamp?)?.toDate(),
              shiftId: doc.id,
            ));
            break;
          case 'cancelled':
            cancelledClasses++;
            break;
        }
      }

      final completionRate = scheduledClasses > 0
          ? (completedClasses / scheduledClasses) * 100
          : 0.0;

      // 2. Get punctuality metrics from timesheet_entries
      // Query only by teacher_id (to avoid index requirement), then filter by date in memory
      final timesheetSnapshot = await _firestore
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: oderId)
          .get();

      // Filter by date in memory to avoid needing a composite index
      final timesheetDocs = timesheetSnapshot.docs.where((doc) {
        final createdAt = doc.data()['created_at'] as Timestamp?;
        if (createdAt == null) return false;
        final docDate = createdAt.toDate();
        return docDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            docDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();

      int totalClockIns = timesheetDocs.length;
      int onTimeClockIns = 0;
      int lateClockIns = 0;
      int earlyClockIns = 0;
      double totalDeltaMinutes = 0;

      for (final doc in timesheetDocs) {
        final data = doc.data();
        final clockInTimestamp = data['clock_in_timestamp'] as Timestamp?;
        final shiftId = data['shift_id'] as String?;

        if (clockInTimestamp != null && shiftId != null) {
          // Get the shift to compare times
          final shiftDoc = await _firestore.collection('teaching_shifts').doc(shiftId).get();
          if (shiftDoc.exists) {
            final shiftStart = (shiftDoc.data()?['shift_start'] as Timestamp?)?.toDate();
            if (shiftStart != null) {
              final clockInTime = clockInTimestamp.toDate();
              final deltaMinutes = clockInTime.difference(shiftStart).inMinutes.toDouble();
              totalDeltaMinutes += deltaMinutes;

              if (deltaMinutes <= 0) {
                earlyClockIns++;
                onTimeClockIns++;
              } else if (deltaMinutes <= 5) {
                onTimeClockIns++;
              } else {
                lateClockIns++;
                flags.add(AuditFlagDetail(
                  type: AuditFlag.lateClockIn,
                  description: 'Late clock-in by ${deltaMinutes.round()} minutes',
                  date: clockInTime,
                  shiftId: shiftId,
                ));
              }
            }
          }
        }
      }

      final avgClockInDeltaMinutes = totalClockIns > 0 ? totalDeltaMinutes / totalClockIns : 0.0;
      final punctualityRate = totalClockIns > 0 ? (onTimeClockIns / totalClockIns) * 100 : 100.0;

      // 3. Get form compliance metrics
      final formsSnapshot = await _firestore
          .collection('form_responses')
          .where('userId', isEqualTo: oderId)
          .where('yearMonth', isEqualTo: yearMonth)
          .get();

      int formsSubmitted = formsSnapshot.docs.length;
      int formsRequired = completedClasses + missedClasses; // Forms required for all classes
      int formsOnTime = 0;
      int formsMissing = formsRequired - formsSubmitted;
      if (formsMissing < 0) formsMissing = 0;

      // Check if forms were submitted on time (within 24h of shift)
      for (final doc in formsSnapshot.docs) {
        final submittedAt = (doc.data()['submittedAt'] as Timestamp?)?.toDate();
        final shiftId = doc.data()['shiftId'] as String?;

        if (submittedAt != null && shiftId != null) {
          final shiftDoc = await _firestore.collection('teaching_shifts').doc(shiftId).get();
          if (shiftDoc.exists) {
            final shiftEnd = (shiftDoc.data()?['shift_end'] as Timestamp?)?.toDate();
            if (shiftEnd != null) {
              final hoursAfter = submittedAt.difference(shiftEnd).inHours;
              if (hoursAfter <= 24) {
                formsOnTime++;
              }
            }
          }
        }
      }

      if (formsMissing > 0) {
        flags.add(AuditFlagDetail(
          type: AuditFlag.missingForm,
          description: '$formsMissing form(s) not submitted',
          date: DateTime.now(),
        ));
      }

      final formComplianceRate = formsRequired > 0
          ? (formsSubmitted / formsRequired) * 100
          : 100.0;

      // 4. Get student outcome metrics (placeholder - depends on your quiz/assignment structure)
      // TODO: Implement actual quiz/assignment/attendance queries
      double avgQuizScore = 0;
      int totalQuizzesTaken = 0;
      double assignmentCompletionRate = 0;
      int totalAssignmentsGiven = 0;
      int totalAssignmentsSubmitted = 0;
      double attendanceRate = 0;
      int totalStudentsEnrolled = 0;
      int avgStudentsPresent = 0;

      // For now, use placeholder values or skip if no data
      // These will be computed when quiz/assignment collections are properly structured

      // 5. Calculate overall score
      final overallScore = TeacherAuditMetrics.calculateOverallScore(
        completionRate: completionRate,
        punctualityRate: punctualityRate,
        formComplianceRate: formComplianceRate,
        avgQuizScore: avgQuizScore,
        assignmentCompletionRate: assignmentCompletionRate,
        attendanceRate: attendanceRate,
      );

      final performanceTier = PerformanceTierExtension.fromScore(overallScore);

      // 6. Create metrics object
      final metrics = TeacherAuditMetrics(
        id: '${oderId}_$yearMonth',
        oderId: oderId,
        teacherEmail: teacherEmail,
        teacherName: teacherName,
        yearMonth: yearMonth,
        scheduledClasses: scheduledClasses,
        completedClasses: completedClasses,
        missedClasses: missedClasses,
        cancelledClasses: cancelledClasses,
        completionRate: completionRate,
        totalClockIns: totalClockIns,
        onTimeClockIns: onTimeClockIns,
        lateClockIns: lateClockIns,
        earlyClockIns: earlyClockIns,
        avgClockInDeltaMinutes: avgClockInDeltaMinutes,
        punctualityRate: punctualityRate,
        formsRequired: formsRequired,
        formsSubmitted: formsSubmitted,
        formsOnTime: formsOnTime,
        formsMissing: formsMissing,
        formComplianceRate: formComplianceRate,
        avgQuizScore: avgQuizScore,
        totalQuizzesTaken: totalQuizzesTaken,
        assignmentCompletionRate: assignmentCompletionRate,
        totalAssignmentsGiven: totalAssignmentsGiven,
        totalAssignmentsSubmitted: totalAssignmentsSubmitted,
        attendanceRate: attendanceRate,
        totalStudentsEnrolled: totalStudentsEnrolled,
        avgStudentsPresent: avgStudentsPresent,
        overallScore: overallScore,
        performanceTier: performanceTier,
        flags: flags,
        lastUpdated: DateTime.now(),
        periodStart: startDate,
        periodEnd: endDate,
      );

      // 7. Save to Firestore
      final collection = pilotOnly ? _pilotMetricsCollection : _metricsCollection;
      await _firestore.collection(collection).doc(metrics.id).set(metrics.toMap());

      AppLogger.info('AuditMetricsService: Computed and saved metrics for $teacherEmail ($yearMonth)');
      return metrics;
    } catch (e) {
      AppLogger.error('AuditMetricsService: Error computing metrics: $e');
      return null;
    }
  }

  /// Get available months with metrics
  static Future<List<String>> getAvailableMonths({bool pilotOnly = false}) async {
    try {
      final collection = pilotOnly ? _pilotMetricsCollection : _metricsCollection;

      final snapshot = await _firestore
          .collection(collection)
          .orderBy('yearMonth', descending: true)
          .get();

      final months = snapshot.docs
          .map((doc) => doc.data()['yearMonth'] as String?)
          .where((m) => m != null)
          .cast<String>()
          .toSet()
          .toList();

      return months;
    } catch (e) {
      AppLogger.error('AuditMetricsService: Error getting available months: $e');
      return [];
    }
  }

  /// Get all teachers with metrics
  static Future<List<Map<String, String>>> getTeachersWithMetrics({bool pilotOnly = false}) async {
    try {
      final collection = pilotOnly ? _pilotMetricsCollection : _metricsCollection;

      final snapshot = await _firestore.collection(collection).get();

      final teachersMap = <String, Map<String, String>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final oderId = data['userId'] as String?;
        if (oderId != null && !teachersMap.containsKey(oderId)) {
          teachersMap[oderId] = {
            'userId': oderId,
            'email': data['teacherEmail'] ?? '',
            'name': data['teacherName'] ?? '',
          };
        }
      }

      return teachersMap.values.toList();
    } catch (e) {
      AppLogger.error('AuditMetricsService: Error getting teachers: $e');
      return [];
    }
  }
}

