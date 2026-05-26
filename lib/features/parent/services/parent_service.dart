import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:alluwalacademyadmin/features/parent/models/invoice.dart';
import 'package:alluwalacademyadmin/features/parent/models/payment.dart';
import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/features/shift_management/services/shift_service.dart';
import 'package:alluwalacademyadmin/features/shift_management/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ParentService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return value.map(
          (key, val) => MapEntry(key.toString(), val),
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getParentChildren(
      String parentId) async {
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
      final studentCode = (data['student_code'] ??
              data['studentCode'] ??
              data['student_id'] ??
              '')
          .toString();
      final kioskCode = (data['kiosk_code'] ?? '').toString();

      return <String, dynamic>{
        'id': doc.id,
        'name': name.isNotEmpty ? name : doc.id,
        'studentCode':
            studentCode.trim().isNotEmpty ? studentCode.trim() : null,
        'kioskCode': kioskCode.trim().isNotEmpty ? kioskCode.trim() : null,
        'email': (data['e-mail'] ?? data['email'])?.toString(),
      };
    }).toList();

    children.sort((a, b) =>
        (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return children;
  }

  /// Check if [parentId] is a guardian of any student in [studentIds].
  static Future<bool> isParentOfStudents(
      String parentId, List<String> studentIds) async {
    if (studentIds.isEmpty) return false;
    for (final studentId in studentIds) {
      try {
        final doc = await _firestore.collection('users').doc(studentId).get();
        if (!doc.exists) continue;
        final data = doc.data()!;
        final guardianIds = <String>[
          ...((data['guardian_ids'] as List?)?.cast<String>() ?? []),
          ...((data['guardianIds'] as List?)?.cast<String>() ?? []),
        ];
        if (guardianIds.contains(parentId)) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Real-time stream of financial totals — updates the moment any invoice
  /// or payment for this parent changes in Firestore.
  static Stream<Map<String, double>> watchFinancialSummary(String parentId) {
    final controller = StreamController<Map<String, double>>();
    QuerySnapshot<Object?>? invoiceSnapshot;
    QuerySnapshot<Object?>? paymentSnapshot;

    void emitSummary() {
      final invoices = invoiceSnapshot;
      final payments = paymentSnapshot;
      if (invoices == null || payments == null || controller.isClosed) {
        return;
      }

      controller.add(_computeFinancialSummary(
        invoiceDocs: invoices.docs,
        paymentDocs: payments.docs,
      ));
    }

    final invoiceSub = _firestore
        .collection('invoices')
        .where('parent_id', isEqualTo: parentId)
        .orderBy('issued_date', descending: true)
        .limit(200)
        .snapshots()
        .listen((snapshot) {
      invoiceSnapshot = snapshot;
      emitSummary();
    }, onError: (e) {
      AppLogger.error(
          'ParentService: watchFinancialSummary invoice stream error: $e');
      if (!controller.isClosed) controller.addError(e);
    });

    final paymentSub = _firestore
        .collection('payments')
        .where('parent_id', isEqualTo: parentId)
        .limit(500)
        .snapshots()
        .listen((snapshot) {
      paymentSnapshot = snapshot;
      emitSummary();
    }, onError: (e) {
      AppLogger.error(
          'ParentService: watchFinancialSummary payment stream error: $e');
      if (!controller.isClosed) controller.addError(e);
    });

    controller.onCancel = () async {
      await invoiceSub.cancel();
      await paymentSub.cancel();
    };

    return controller.stream;
  }

  static Future<Map<String, double>> getFinancialSummary(
      String parentId) async {
    try {
      // Keep this bounded to prevent large reads if a parent has a long history.
      final snapshot = await _firestore
          .collection('invoices')
          .where('parent_id', isEqualTo: parentId)
          .orderBy('issued_date', descending: true)
          .limit(200)
          .get();

      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('parent_id', isEqualTo: parentId)
          .limit(500)
          .get();

      return _computeFinancialSummary(
        invoiceDocs: snapshot.docs,
        paymentDocs: paymentsSnapshot.docs,
      );
    } catch (e) {
      AppLogger.error('ParentService: Error computing financial summary: $e');
      return {
        'outstanding': 0,
        'overdue': 0,
        'paid': 0,
      };
    }
  }

  static Map<String, double> _computeFinancialSummary({
    required List<QueryDocumentSnapshot<Object?>> invoiceDocs,
    required List<QueryDocumentSnapshot<Object?>> paymentDocs,
  }) {
    final completedPaidByInvoice = <String, double>{};
    double completedPaidWithoutInvoice = 0;

    for (final doc in paymentDocs) {
      try {
        final payment = Payment.fromFirestore(doc);
        if (payment.status != PaymentStatus.completed) continue;

        final invoiceId = payment.invoiceId.trim();
        if (invoiceId.isEmpty) {
          completedPaidWithoutInvoice += payment.amount;
          continue;
        }

        completedPaidByInvoice[invoiceId] =
            (completedPaidByInvoice[invoiceId] ?? 0) + payment.amount;
      } catch (e) {
        AppLogger.error(
            'ParentService: financial summary payment parse error for ${doc.id}: $e');
      }
    }

    double outstanding = 0;
    double overdue = 0;
    double paid = completedPaidWithoutInvoice;
    final matchedInvoiceIds = <String>{};
    final now = DateTime.now();

    for (final doc in invoiceDocs) {
      try {
        final invoice = Invoice.fromFirestore(doc);
        final completedPaid = completedPaidByInvoice[invoice.id] ?? 0;
        final effectivePaid = completedPaid > invoice.paidAmount
            ? completedPaid
            : invoice.paidAmount;

        paid += effectivePaid;
        matchedInvoiceIds.add(invoice.id);

        final remaining = invoice.totalAmount - effectivePaid;
        final cancelled = invoice.status == InvoiceStatus.cancelled;
        if (cancelled || remaining <= 0) continue;

        outstanding += remaining;
        if (invoice.dueDate.isBefore(now)) {
          overdue += remaining;
        }
      } catch (e) {
        AppLogger.error(
            'ParentService: financial summary invoice parse error for ${doc.id}: $e');
      }
    }

    for (final entry in completedPaidByInvoice.entries) {
      if (!matchedInvoiceIds.contains(entry.key)) {
        paid += entry.value;
      }
    }

    return {
      'outstanding': outstanding,
      'overdue': overdue,
      'paid': paid,
    };
  }

  /// Get upcoming shifts for a student (next 7 days)
  static Future<List<TeachingShift>> getStudentUpcomingShifts(
      String studentId) async {
    try {
      return await ShiftService.getUpcomingShiftsForStudent(studentId);
    } catch (e) {
      AppLogger.error(
          'ParentService: Error getting upcoming shifts for student: $e');
      return [];
    }
  }

  /// Get today's shifts for a student
  static Future<List<TeachingShift>> getStudentTodayShifts(
      String studentId) async {
    try {
      return await ShiftService.getTodayShiftsForStudent(studentId);
    } catch (e) {
      AppLogger.error(
          'ParentService: Error getting today\'s shifts for student: $e');
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
      final effectiveStartDate =
          startDate ?? now.subtract(const Duration(days: 30));
      final effectiveEndDate = endDate ?? now;

      // Query shifts where student is assigned and in date range
      Query query = _firestore
          .collection('teaching_shifts')
          .where('student_ids', arrayContains: studentId)
          .where('shift_start',
              isLessThan: Timestamp.fromDate(effectiveEndDate));

      if (startDate != null) {
        query = query.where('shift_start',
            isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStartDate));
      }

      final snapshot = await query.get();
      final shifts = snapshot.docs
          .map((doc) => TeachingShift.fromFirestore(doc))
          .where((shift) => shift.shiftStart.isBefore(effectiveEndDate))
          .where((shift) =>
              startDate == null || shift.shiftStart.isAfter(effectiveStartDate))
          .toList();

      shifts.sort(
          (a, b) => b.shiftStart.compareTo(a.shiftStart)); // Most recent first
      return shifts;
    } catch (e) {
      AppLogger.error(
          'ParentService: Error getting shifts history for student: $e');
      return [];
    }
  }

  /// Calculate attendance statistics for a student
  static Future<Map<String, dynamic>> getStudentAttendanceStats(
      String studentId,
      {int? days}) async {
    try {
      final now = DateTime.now();
      final daysToLookBack = days ?? 30;
      final startDate = now.subtract(Duration(days: daysToLookBack));

      // Get all shifts for the student in the date range
      final shifts = await getStudentShiftsHistory(studentId,
          startDate: startDate, endDate: now);

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
      final attendanceRate =
          totalPastClasses > 0 ? completed / totalPastClasses : 0.0;

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
  static Future<Map<String, Map<String, dynamic>>> getStudentSubjectStats(
      String studentId) async {
    try {
      // Get all shifts for the student
      final shifts = await getStudentShiftsHistory(studentId,
          startDate: null, endDate: DateTime.now());

      final Map<String, Map<String, dynamic>> subjectStats = {};

      for (final shift in shifts) {
        final subjectName =
            shift.subjectDisplayName ?? shift.subject.toString();

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

  /// Fetches advanced attendance analytics generated by Cloud Functions.
  /// Returns the `report` payload when available, otherwise `null`.
  static Future<Map<String, dynamic>?> getStudentAttendanceReport(
    String studentId, {
    String periodType = 'weekly',
    DateTime? referenceDate,
    bool forceRefresh = false,
  }) async {
    final normalizedStudentId = studentId.trim();
    if (normalizedStudentId.isEmpty) return null;

    try {
      final callable = _functions.httpsCallable('getStudentAttendanceReport');
      final result = await callable.call({
        'studentId': normalizedStudentId,
        'periodType': periodType.trim().toLowerCase(),
        if (referenceDate != null)
          'referenceDate': referenceDate.toUtc().toIso8601String(),
        'forceRefresh': forceRefresh,
      });

      final responseMap = _asMap(result.data);
      if (responseMap == null) return null;
      if (responseMap['success'] != true) return null;

      return _asMap(responseMap['report']);
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'ParentService: getStudentAttendanceReport failed (${e.code}): ${e.message}');
      return null;
    } catch (e) {
      AppLogger.error('ParentService: getStudentAttendanceReport error: $e');
      return null;
    }
  }
}
