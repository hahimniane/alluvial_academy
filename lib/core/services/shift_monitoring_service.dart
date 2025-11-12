import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/teaching_shift.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ShiftMonitoringService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Future<Map<String, dynamic>> monitorShiftsAndHandleOverdues() async {
    final results = <String, dynamic>{
      'lifecyclesTriggered': 0,
      'errors': <String>[],
    };

    try {
      final nowUtc = DateTime.now().toUtc();
      AppLogger.debug(
          'ShiftMonitoringService: Running lifecycle reconciliation sweep at $nowUtc');

      final scheduledSnapshot = await _firestore
          .collection('teaching_shifts')
          .where('status', isEqualTo: ShiftStatus.scheduled.name)
          .get();

      for (final doc in scheduledSnapshot.docs) {
        final shift = TeachingShift.fromFirestore(doc);
        if (shift.shouldBeMarkedAsMissed(nowUtcOverride: nowUtc)) {
          await _requestLifecycleSync(shift);
          results['lifecyclesTriggered'] =
              (results['lifecyclesTriggered'] as int) + 1;
        }
      }

      final activeSnapshot = await _firestore
          .collection('teaching_shifts')
          .where('status', isEqualTo: ShiftStatus.active.name)
          .get();

      for (final doc in activeSnapshot.docs) {
        final shift = TeachingShift.fromFirestore(doc);
        final shiftEndUtc = shift.shiftEnd.toUtc();
        if (nowUtc.isAfter(shiftEndUtc) || shift.needsAutoLogout) {
          await _requestLifecycleSync(shift);
          results['lifecyclesTriggered'] =
              (results['lifecyclesTriggered'] as int) + 1;
        }
      }

      AppLogger.error('ShiftMonitoringService: Reconciliation completed: $results');
    } catch (e) {
      AppLogger.error('ShiftMonitoringService: Error during reconciliation: $e');
      (results['errors'] as List<String>).add(e.toString());
    }

    return results;
  }

  static Future<void> _requestLifecycleSync(TeachingShift shift,
      {bool cancel = false}) async {
    try {
      final callable = _functions.httpsCallable('scheduleShiftLifecycle');
      await callable.call({
        'shiftId': shift.id,
        'teacherId': shift.teacherId,
        'shiftStart': shift.shiftStart.toUtc().toIso8601String(),
        'shiftEnd': shift.shiftEnd.toUtc().toIso8601String(),
        'status': shift.status.name,
        'cancel': cancel,
        'adminTimezone': shift.adminTimezone,
        'teacherTimezone': shift.teacherTimezone,
      });
      AppLogger.error(
          'ShiftMonitoringService: Lifecycle sync requested for shift ${shift.id} (cancel=$cancel)');
    } catch (e) {
      AppLogger.error(
          'ShiftMonitoringService: Error requesting lifecycle sync for shift ${shift.id}: $e');
      throw e;
    }
  }

  static Future<void> runPeriodicMonitoring() async {
    try {
      AppLogger.debug('ShiftMonitoringService: Running periodic reconciliation...');
      final results = await monitorShiftsAndHandleOverdues();
      AppLogger.error(
          'ShiftMonitoringService: Reconciliation results: lifecyclesTriggered=${results['lifecyclesTriggered']}, errors=${(results['errors'] as List).length}');
    } catch (e) {
      AppLogger.error('ShiftMonitoringService: Error in periodic monitoring: $e');
    }
  }
}
