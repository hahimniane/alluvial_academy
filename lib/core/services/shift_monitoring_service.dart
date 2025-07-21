import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/teaching_shift.dart';
import '../models/employee_model.dart';
import 'location_service.dart';
import 'shift_service.dart';
import 'shift_timesheet_service.dart';

class ShiftMonitoringService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Monitor all shifts and handle auto clock-outs and missed shifts
  static Future<Map<String, dynamic>> monitorShiftsAndHandleOverdues() async {
    try {
      print('ShiftMonitoringService: Starting shift monitoring...');

      final now = DateTime.now();
      final results = <String, dynamic>{
        'autoClockOuts': <Map<String, dynamic>>[],
        'missedShifts': <Map<String, dynamic>>[],
        'totalProcessed': 0,
        'errors': <String>[],
      };

      // Get all active shifts that might need auto clock-out
      final activeShiftsSnapshot = await _firestore
          .collection('teaching_shifts')
          .where('status', isEqualTo: 'active')
          .get();

      print(
          'ShiftMonitoringService: Found ${activeShiftsSnapshot.docs.length} active shifts');

      // Process active shifts for auto clock-out
      for (var doc in activeShiftsSnapshot.docs) {
        try {
          final shift = TeachingShift.fromFirestore(doc);

          // Check if shift needs auto clock-out (15 minutes past end time)
          if (shift.needsAutoLogout) {
            print(
                'ShiftMonitoringService: Processing auto clock-out for shift ${shift.id}');

            final autoClockOutResult = await _performAutoClockOut(shift);
            if (autoClockOutResult['success']) {
              (results['autoClockOuts'] as List<Map<String, dynamic>>).add({
                'shiftId': shift.id,
                'teacherName': shift.teacherName,
                'teacherId': shift.teacherId,
                'shiftName': shift.displayName,
                'clockOutTime': autoClockOutResult['clockOutTime'],
                'message': autoClockOutResult['message'],
              });
            } else {
              (results['errors'] as List<String>).add(
                  'Auto clock-out failed for shift ${shift.id}: ${autoClockOutResult['message']}');
            }
          }

          results['totalProcessed'] = (results['totalProcessed'] as int) + 1;
        } catch (e) {
          print(
              'ShiftMonitoringService: Error processing active shift ${doc.id}: $e');
          (results['errors'] as List<String>)
              .add('Error processing shift ${doc.id}: $e');
        }
      }

      // Get all scheduled shifts that might be missed
      final scheduledShiftsSnapshot = await _firestore
          .collection('teaching_shifts')
          .where('status', isEqualTo: 'scheduled')
          .get();

      print(
          'ShiftMonitoringService: Found ${scheduledShiftsSnapshot.docs.length} scheduled shifts');

      // Process scheduled shifts for missed shift detection
      for (var doc in scheduledShiftsSnapshot.docs) {
        try {
          final shift = TeachingShift.fromFirestore(doc);

          // Check if shift is missed (15 minutes past end time and never clocked in)
          if (shift.hasExpired && shift.clockInTime == null) {
            print(
                'ShiftMonitoringService: Processing missed shift ${shift.id}');

            final missedShiftResult = await _handleMissedShift(shift);
            if (missedShiftResult['success']) {
              (results['missedShifts'] as List<Map<String, dynamic>>).add({
                'shiftId': shift.id,
                'teacherName': shift.teacherName,
                'teacherId': shift.teacherId,
                'shiftName': shift.displayName,
                'scheduledTime': shift.shiftStart,
                'missedTime': now,
                'message': missedShiftResult['message'],
              });
            } else {
              (results['errors'] as List<String>).add(
                  'Missed shift processing failed for shift ${shift.id}: ${missedShiftResult['message']}');
            }
          }

          results['totalProcessed'] = (results['totalProcessed'] as int) + 1;
        } catch (e) {
          print(
              'ShiftMonitoringService: Error processing scheduled shift ${doc.id}: $e');
          (results['errors'] as List<String>)
              .add('Error processing scheduled shift ${doc.id}: $e');
        }
      }

      // Generate admin report if there are any issues
      if ((results['autoClockOuts'] as List).isNotEmpty ||
          (results['missedShifts'] as List).isNotEmpty) {
        await _generateAdminReport(results);
      }

      print('ShiftMonitoringService: Monitoring completed. Results: $results');
      return results;
    } catch (e) {
      print('ShiftMonitoringService: Error in monitoring: $e');
      return {
        'autoClockOuts': <Map<String, dynamic>>[],
        'missedShifts': <Map<String, dynamic>>[],
        'totalProcessed': 0,
        'errors': ['Critical error in monitoring: $e'],
      };
    }
  }

  /// Perform auto clock-out for a shift
  static Future<Map<String, dynamic>> _performAutoClockOut(
      TeachingShift shift) async {
    try {
      print(
          'ShiftMonitoringService: Performing auto clock-out for shift ${shift.id}');

      // Try to get a reasonable location (use last known or default)
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation();
      } catch (e) {
        print(
            'ShiftMonitoringService: Could not get location for auto clock-out, using default');
        // Use a default location for auto clock-out
        location = LocationData(
          latitude: 0.0,
          longitude: 0.0,
          address: 'Auto clock-out location unavailable',
          neighborhood: 'System Generated',
        );
      }

      // Use the shift timesheet service for auto clock-out
      final result = await ShiftTimesheetService.autoClockOutFromShift(
        shift.teacherId,
        shift.id,
        location: location!,
      );

      if (result['success']) {
        // Also mark the shift as completed in the shifts collection
        await _firestore.collection('teaching_shifts').doc(shift.id).update({
          'status': ShiftStatus.completed.name,
          'clock_out_time': Timestamp.fromDate(shift.clockOutDeadline),
          'last_modified': FieldValue.serverTimestamp(),
          'auto_clock_out': true,
          'auto_clock_out_reason':
              'System auto clock-out - teacher exceeded time limit',
        });

        print(
            'ShiftMonitoringService: Auto clock-out successful for shift ${shift.id}');
        return {
          'success': true,
          'message': 'Auto clock-out completed successfully',
          'clockOutTime': shift.clockOutDeadline,
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Unknown error during auto clock-out',
        };
      }
    } catch (e) {
      print(
          'ShiftMonitoringService: Error in auto clock-out for shift ${shift.id}: $e');
      return {
        'success': false,
        'message': 'Error during auto clock-out: $e',
      };
    }
  }

  /// Handle missed shift
  static Future<Map<String, dynamic>> _handleMissedShift(
      TeachingShift shift) async {
    try {
      print('ShiftMonitoringService: Handling missed shift ${shift.id}');

      // Mark shift as missed
      await _firestore.collection('teaching_shifts').doc(shift.id).update({
        'status': ShiftStatus.missed.name,
        'missed_at': FieldValue.serverTimestamp(),
        'last_modified': FieldValue.serverTimestamp(),
        'missed_reason': 'Teacher did not clock in within allowed window',
      });

      // Create a missed shift report entry
      await _firestore.collection('missed_shift_reports').add({
        'shift_id': shift.id,
        'teacher_id': shift.teacherId,
        'teacher_name': shift.teacherName,
        'shift_name': shift.displayName,
        'scheduled_start': Timestamp.fromDate(shift.shiftStart),
        'scheduled_end': Timestamp.fromDate(shift.shiftEnd),
        'clock_in_window_start': Timestamp.fromDate(shift.clockInWindowStart),
        'clock_in_window_end': Timestamp.fromDate(shift.clockOutDeadline),
        'missed_at': FieldValue.serverTimestamp(),
        'student_names': shift.studentNames,
        'subject': shift.subject.name,
        'hourly_rate': shift.hourlyRate,
        'potential_payment_lost': shift.totalPayment,
        'status': 'reported',
        'admin_notified': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      print('ShiftMonitoringService: Missed shift handled for ${shift.id}');
      return {
        'success': true,
        'message': 'Missed shift processed and reported',
      };
    } catch (e) {
      print(
          'ShiftMonitoringService: Error handling missed shift ${shift.id}: $e');
      return {
        'success': false,
        'message': 'Error processing missed shift: $e',
      };
    }
  }

  /// Generate comprehensive admin report
  static Future<void> _generateAdminReport(Map<String, dynamic> results) async {
    try {
      print('ShiftMonitoringService: Generating admin report');

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('h:mm a').format(now);

      // Calculate summary statistics
      final autoClockOuts = results['autoClockOuts'] as List;
      final missedShifts = results['missedShifts'] as List;
      final errors = results['errors'] as List;

      double totalLostPayment = 0.0;
      for (var missed in missedShifts) {
        // Calculate potential lost payment from shift data
        try {
          final shiftDoc = await _firestore
              .collection('teaching_shifts')
              .doc(missed['shiftId'])
              .get();
          if (shiftDoc.exists) {
            final shift = TeachingShift.fromFirestore(shiftDoc);
            totalLostPayment += shift.totalPayment;
          }
        } catch (e) {
          print('Error calculating lost payment for ${missed['shiftId']}: $e');
        }
      }

      // Create admin report document
      await _firestore.collection('admin_reports').add({
        'report_type': 'shift_monitoring',
        'report_date': dateStr,
        'report_time': timeStr,
        'generated_at': FieldValue.serverTimestamp(),

        // Summary statistics
        'summary': {
          'total_shifts_processed': results['totalProcessed'],
          'auto_clock_outs_performed': autoClockOuts.length,
          'missed_shifts_detected': missedShifts.length,
          'errors_encountered': errors.length,
          'total_potential_payment_lost': totalLostPayment,
        },

        // Detailed data
        'auto_clock_outs': autoClockOuts,
        'missed_shifts': missedShifts,
        'errors': errors,

        // Admin action required
        'requires_admin_attention':
            (missedShifts.isNotEmpty || errors.isNotEmpty),
        'priority_level': _calculatePriorityLevel(
            autoClockOuts.length, missedShifts.length, errors.length),

        // Status
        'status': 'pending_review',
        'reviewed_by': null,
        'reviewed_at': null,
        'admin_notes': '',
      });

      // Create individual notifications for each missed shift (for immediate admin attention)
      for (var missed in missedShifts) {
        await _firestore.collection('admin_notifications').add({
          'type': 'missed_shift',
          'title': 'Missed Shift Alert',
          'message':
              '${missed['teacherName']} missed shift: ${missed['shiftName']}',
          'shift_id': missed['shiftId'],
          'teacher_id': missed['teacherId'],
          'teacher_name': missed['teacherName'],
          'created_at': FieldValue.serverTimestamp(),
          'read': false,
          'priority': 'high',
          'action_required': true,
        });
      }

      // Create notifications for auto clock-outs (for admin awareness)
      for (var autoClockOut in autoClockOuts) {
        await _firestore.collection('admin_notifications').add({
          'type': 'auto_clock_out',
          'title': 'Auto Clock-out Performed',
          'message':
              '${autoClockOut['teacherName']} was automatically clocked out from: ${autoClockOut['shiftName']}',
          'shift_id': autoClockOut['shiftId'],
          'teacher_id': autoClockOut['teacherId'],
          'teacher_name': autoClockOut['teacherName'],
          'created_at': FieldValue.serverTimestamp(),
          'read': false,
          'priority': 'medium',
          'action_required': false,
        });
      }

      print('ShiftMonitoringService: Admin report generated successfully');
    } catch (e) {
      print('ShiftMonitoringService: Error generating admin report: $e');
    }
  }

  /// Calculate priority level based on issues found
  static String _calculatePriorityLevel(
      int autoClockOuts, int missedShifts, int errors) {
    if (errors > 0 || missedShifts > 2) {
      return 'high';
    } else if (missedShifts > 0 || autoClockOuts > 3) {
      return 'medium';
    } else {
      return 'low';
    }
  }

  /// Get missed shift reports for admin review
  static Future<List<Map<String, dynamic>>> getMissedShiftReports({
    DateTime? startDate,
    DateTime? endDate,
    String? teacherId,
  }) async {
    try {
      Query query = _firestore.collection('missed_shift_reports');

      if (startDate != null) {
        query = query.where('missed_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('missed_at',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      if (teacherId != null) {
        query = query.where('teacher_id', isEqualTo: teacherId);
      }

      final snapshot = await query.orderBy('missed_at', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting missed shift reports: $e');
      return [];
    }
  }

  /// Get admin notifications
  static Future<List<Map<String, dynamic>>> getAdminNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection('admin_notifications');

      if (unreadOnly) {
        query = query.where('read', isEqualTo: false);
      }

      final snapshot = await query
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error getting admin notifications: $e');
      return [];
    }
  }

  /// Mark admin notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('admin_notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'read_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Run monitoring (this should be called periodically, e.g., every 15 minutes)
  static Future<void> runPeriodicMonitoring() async {
    try {
      print('ShiftMonitoringService: Running periodic monitoring...');
      final results = await monitorShiftsAndHandleOverdues();

      // Log results
      print('ShiftMonitoringService: Periodic monitoring completed:');
      print('  - Auto clock-outs: ${results['autoClockOuts'].length}');
      print('  - Missed shifts: ${results['missedShifts'].length}');
      print('  - Errors: ${results['errors'].length}');
      print('  - Total processed: ${results['totalProcessed']}');
    } catch (e) {
      print('ShiftMonitoringService: Error in periodic monitoring: $e');
    }
  }
}
