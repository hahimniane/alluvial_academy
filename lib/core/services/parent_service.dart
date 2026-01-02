import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/models/invoice.dart';
import 'package:alluwalacademyadmin/core/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/core/services/shift_service.dart';
import 'package:alluwalacademyadmin/core/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ParentService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> getParentChildren(String parentId) async {
    final students = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    Future<void> queryField(String fieldName) async {
      final snapshot = await _firestore
          .collection('users')
          .where('user_type', isEqualTo: 'student')
          .where(fieldName, arrayContains: parentId)
          .get();
      students.addAll(snapshot.docs);
    }

    try {
      await queryField('guardian_ids');
      if (students.isEmpty) {
        await queryField('guardianIds');
      }
    } catch (e) {
      AppLogger.error('ParentService: Error loading children: $e');
      rethrow;
    }

    final children = students.map((doc) {
      final data = doc.data();
      final first = (data['first_name'] ?? '').toString().trim();
      final last = (data['last_name'] ?? '').toString().trim();
      final name = ('$first $last').trim();
      final studentCode =
          (data['student_code'] ?? data['studentCode'] ?? data['student_id'] ?? '').toString();
      final kioskCode = (data['kiosk_code'] ?? '').toString();

      return <String, dynamic>{
        'id': doc.id,
        'name': name.isNotEmpty ? name : doc.id,
        'studentCode': studentCode.trim().isNotEmpty ? studentCode.trim() : null,
        'kioskCode': kioskCode.trim().isNotEmpty ? kioskCode.trim() : null,
        'email': (data['e-mail'] ?? data['email'])?.toString(),
      };
    }).toList();

    children.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return children;
  }

  static Future<Map<String, double>> getFinancialSummary(String parentId) async {
    try {
      // Keep this bounded to prevent large reads if a parent has a long history.
      final snapshot = await _firestore
          .collection('invoices')
          .where('parent_id', isEqualTo: parentId)
          .orderBy('issued_date', descending: true)
          .limit(200)
          .get();

      double outstanding = 0;
      double overdue = 0;
      double paid = 0;
      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final invoice = Invoice.fromFirestore(doc);
        paid += invoice.paidAmount;

        final remaining = invoice.remainingBalance;
        final cancelled = invoice.status == InvoiceStatus.cancelled;
        if (cancelled || invoice.isFullyPaid) continue;

        outstanding += remaining;
        if (invoice.dueDate.isBefore(now)) {
          overdue += remaining;
        }
      }

      return {
        'outstanding': outstanding,
        'overdue': overdue,
        'paid': paid,
      };
    } catch (e) {
      AppLogger.error('ParentService: Error computing financial summary: $e');
      return {
        'outstanding': 0,
        'overdue': 0,
        'paid': 0,
      };
    }
  }

  /// Get upcoming shifts for a student (next 7 days)
  static Future<List<TeachingShift>> getStudentUpcomingShifts(String studentId) async {
    try {
      return await ShiftService.getUpcomingShiftsForStudent(studentId);
    } catch (e) {
      AppLogger.error('ParentService: Error getting upcoming shifts for student: $e');
      return [];
    }
  }

  /// Get today's shifts for a student
  static Future<List<TeachingShift>> getStudentTodayShifts(String studentId) async {
    try {
      return await ShiftService.getTodayShiftsForStudent(studentId);
    } catch (e) {
      AppLogger.error('ParentService: Error getting today\'s shifts for student: $e');
      return [];
    }
  }

  /// Get historical shifts for a student with optional date range
  static Future<List<TeachingShift>> getStudentShiftsHistory(
    String studentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final effectiveStartDate = startDate ?? now.subtract(const Duration(days: 30));
      final effectiveEndDate = endDate ?? now;

      // Query shifts where student is assigned and in date range
      Query query = _firestore
          .collection('teaching_shifts')
          .where('student_ids', arrayContains: studentId)
          .where('shift_start', isLessThan: Timestamp.fromDate(effectiveEndDate));

      if (startDate != null) {
        query = query.where('shift_start', isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStartDate));
      }

      final snapshot = await query.get();
      final shifts = snapshot.docs
          .map((doc) => TeachingShift.fromFirestore(doc))
          .where((shift) => shift.shiftStart.isBefore(effectiveEndDate))
          .where((shift) => startDate == null || shift.shiftStart.isAfter(effectiveStartDate))
          .toList();

      shifts.sort((a, b) => b.shiftStart.compareTo(a.shiftStart)); // Most recent first
      return shifts;
    } catch (e) {
      AppLogger.error('ParentService: Error getting shifts history for student: $e');
      return [];
    }
  }

  /// Calculate attendance statistics for a student
  static Future<Map<String, dynamic>> getStudentAttendanceStats(String studentId, {int? days}) async {
    try {
      final now = DateTime.now();
      final daysToLookBack = days ?? 30;
      final startDate = now.subtract(Duration(days: daysToLookBack));

      // Get all shifts for the student in the date range
      final shifts = await getStudentShiftsHistory(studentId, startDate: startDate, endDate: now);

      if (shifts.isEmpty) {
        return {
          'totalClasses': 0,
          'completedClasses': 0,
          'missedClasses': 0,
          'cancelledClasses': 0,
          'attendanceRate': 0.0,
        };
      }

      int completed = 0;
      int missed = 0;
      int cancelled = 0;

      for (final shift in shifts) {
        switch (shift.status) {
          case ShiftStatus.completed:
          case ShiftStatus.fullyCompleted:
          case ShiftStatus.partiallyCompleted:
            completed++;
            break;
          case ShiftStatus.missed:
            missed++;
            break;
          case ShiftStatus.cancelled:
            cancelled++;
            break;
          default:
            // scheduled, active - count as pending, not in attendance calculation
            break;
        }
      }

      final totalPastClasses = completed + missed + cancelled;
      final attendanceRate = totalPastClasses > 0 ? completed / totalPastClasses : 0.0;

      return {
        'totalClasses': shifts.length,
        'completedClasses': completed,
        'missedClasses': missed,
        'cancelledClasses': cancelled,
        'attendanceRate': attendanceRate,
      };
    } catch (e) {
      AppLogger.error('ParentService: Error calculating attendance stats: $e');
      return {
        'totalClasses': 0,
        'completedClasses': 0,
        'missedClasses': 0,
        'cancelledClasses': 0,
        'attendanceRate': 0.0,
      };
    }
  }

  /// Get subject performance statistics for a student
  static Future<Map<String, Map<String, dynamic>>> getStudentSubjectStats(String studentId) async {
    try {
      // Get all shifts for the student
      final shifts = await getStudentShiftsHistory(studentId, startDate: null, endDate: DateTime.now());

      final Map<String, Map<String, dynamic>> subjectStats = {};

      for (final shift in shifts) {
        final subjectName = shift.subjectDisplayName ?? shift.subject.toString();
        
        if (!subjectStats.containsKey(subjectName)) {
          subjectStats[subjectName] = {
            'count': 0,
            'completedCount': 0,
            'missedCount': 0,
            'cancelledCount': 0,
            'totalHours': 0.0,
          };
        }

        final stats = subjectStats[subjectName]!;
        stats['count'] = (stats['count'] as int) + 1;

        // Count by status
        switch (shift.status) {
          case ShiftStatus.completed:
          case ShiftStatus.fullyCompleted:
          case ShiftStatus.partiallyCompleted:
            stats['completedCount'] = (stats['completedCount'] as int) + 1;
            break;
          case ShiftStatus.missed:
            stats['missedCount'] = (stats['missedCount'] as int) + 1;
            break;
          case ShiftStatus.cancelled:
            stats['cancelledCount'] = (stats['cancelledCount'] as int) + 1;
            break;
          default:
            break;
        }

        // Calculate hours
        final duration = shift.shiftEnd.difference(shift.shiftStart);
        final hours = duration.inMinutes / 60.0;
        stats['totalHours'] = (stats['totalHours'] as double) + hours;
      }

      return subjectStats;
    } catch (e) {
      AppLogger.error('ParentService: Error getting subject stats: $e');
      return {};
    }
  }
}
