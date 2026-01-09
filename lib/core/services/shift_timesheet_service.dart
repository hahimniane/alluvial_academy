import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/teaching_shift.dart';
import '../enums/shift_enums.dart';
import 'location_service.dart';
import 'shift_service.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ShiftTimesheetService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if teacher has a valid shift for clock-in or active shift for clock-out
  /// Also returns information about programmed clock-in availability
  static Future<Map<String, dynamic>> getValidShiftForClockIn(
      String teacherId) async {
    try {
      AppLogger.debug(
          'ShiftTimesheetService: Checking for valid shift for teacher $teacherId');
      final now = DateTime.now();
      final nowUtc = now.toUtc();
      AppLogger.debug('ShiftTimesheetService: Current local time: $now');
      AppLogger.debug('ShiftTimesheetService: Current UTC time: $nowUtc');
      AppLogger.debug(
          'ShiftTimesheetService: Current timezone: ${now.timeZoneName}');
      AppLogger.debug(
          'ShiftTimesheetService: Current UTC offset: ${now.timeZoneOffset}');

      // First check if teacher has an active shift (already clocked in)
      final activeShift = await getActiveShift(teacherId);
      AppLogger.debug(
          'ShiftTimesheetService: getActiveShift returned: ${activeShift != null ? "shift ${activeShift.id}" : "null"}');

      if (activeShift != null) {
        // Defensive check: ensure the shift is truly active (no clockOutTime)
        AppLogger.debug(
            'ShiftTimesheetService: Checking activeShift.clockOutTime: ${activeShift.clockOutTime}');

        if (activeShift.clockOutTime != null) {
          AppLogger.debug(
              'ShiftTimesheetService: ⚠️ UNEXPECTED: activeShift has clockOutTime set (should not happen). Ignoring as active.');
          AppLogger.debug(
              'ShiftTimesheetService: clockOutTime value: ${activeShift.clockOutTime}');
          // Treat as no active shift - fall through to check for valid shifts
        } else {
          AppLogger.debug(
              'ShiftTimesheetService: ✅ Found genuinely active shift ${activeShift.id} - ${activeShift.displayName}');
          return {
            'shift': activeShift,
            'canClockIn': false,
            'canClockOut': true,
            'status': 'active',
            'message':
                'You are currently clocked in to ${activeShift.displayName}',
          };
        }
      }

      // Check for all shifts that could be clocked in
      final snapshot = await _firestore
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: teacherId)
          .get();

      AppLogger.debug(
          'ShiftTimesheetService: Found ${snapshot.docs.length} total shifts for teacher');

      List<TeachingShift> validShifts = [];

      for (var doc in snapshot.docs) {
        final shift = TeachingShift.fromFirestore(doc);

        // CONSISTENT TIME HANDLING - Always use UTC for comparisons
        final shiftStartUtc = shift.shiftStart.toUtc();
        final shiftEndUtc = shift.shiftEnd.toUtc();
        // NO GRACE PERIOD - Clock-in only during exact shift time
        final clockInWindowUtc = shiftStartUtc;
        final clockOutWindowUtc = shiftEndUtc;

        AppLogger.debug('ShiftTimesheetService: Shift ${shift.id}:');
        AppLogger.debug('  - Display Name: ${shift.displayName}');
        AppLogger.debug('  - Status: ${shift.status.name}');
        AppLogger.debug('  - Shift Start (UTC): $shiftStartUtc');
        AppLogger.debug('  - Shift End (UTC): $shiftEndUtc');
        AppLogger.debug(
            '  - Clock-in Window (UTC): $clockInWindowUtc to $clockOutWindowUtc');
        AppLogger.debug(
            '  - Current UTC time in window: ${nowUtc.isAfter(clockInWindowUtc) && nowUtc.isBefore(clockOutWindowUtc)}');

        // Allow clock-in 1 minute before shift start until shift end
        // Use inclusive comparison (!isBefore and !isAfter) to include exact start/end times
        // Add 1 minute buffer to start time to allow early clock-in
        final bufferedStartUtc = clockInWindowUtc.subtract(const Duration(minutes: 1));
        
        if (!nowUtc.isBefore(bufferedStartUtc) &&
            !nowUtc.isAfter(clockOutWindowUtc)) {
          AppLogger.debug(
              'ShiftTimesheetService: ✅ VALID SHIFT FOUND: ${shift.id} - ${shift.displayName}');
          validShifts.add(shift);
        } else {
          AppLogger.debug(
              'ShiftTimesheetService: ❌ Shift not valid for clock-in - outside time window');
        }
      }

      if (validShifts.isNotEmpty) {
        final shift = validShifts.first;

        // Check if we're in the programming window (1 minute before start) or shift has started
        final nowUtc = DateTime.now().toUtc();
        final shiftStartUtc = shift.shiftStart.toUtc();
        final programmingWindowStart = shiftStartUtc.subtract(const Duration(minutes: 1));

        // Can program clock-in: within 1 minute before shift start
        final canProgramClockIn = !nowUtc.isBefore(programmingWindowStart) &&
                                 nowUtc.isBefore(shiftStartUtc);
        
        // Can clock in NOW: shift has started (current time is at or after shift start)
        final canClockInNow = !nowUtc.isBefore(shiftStartUtc);

        AppLogger.debug('ShiftTimesheetService: Clock-in status for shift ${shift.id}:');
        AppLogger.debug('  - canProgramClockIn: $canProgramClockIn');
        AppLogger.debug('  - canClockInNow: $canClockInNow');
        AppLogger.debug('  - nowUtc: $nowUtc');
        AppLogger.debug('  - shiftStartUtc: $shiftStartUtc');

        return {
          'shift': shift,
          'canClockIn': canClockInNow, // TRUE when shift has started
          'canProgramClockIn': canProgramClockIn, // Can program clock-in (before shift starts)
          'canClockOut': false,
          'status': 'scheduled',
          'message': canClockInNow
              ? 'Ready to clock in to ${shift.displayName}'
              : (canProgramClockIn
                  ? 'Ready to program clock-in for ${shift.displayName} (starts at ${DateFormat('h:mm a').format(shift.shiftStart)})'
                  : 'Clock-in window opens at ${DateFormat('h:mm a').format(shiftStartUtc.subtract(const Duration(minutes: 1)).toLocal())}'),
        };
      }

      AppLogger.debug(
          'ShiftTimesheetService: No valid shifts found for clock-in');
      return {
        'shift': null,
        'canClockIn': false,
        'canClockOut': false,
        'status': 'none',
        'message': 'No valid shifts available for clock-in at this time',
      };
    } catch (e) {
      AppLogger.error('Error checking for valid shift: $e');
      return {
        'shift': null,
        'canClockIn': false,
        'canClockOut': false,
        'status': 'error',
        'message': 'Error checking shift availability: $e',
      };
    }
  }

  /// Program a clock-in to happen exactly at shift start time
  /// This allows teachers to "program" their clock-in during the 1-minute window
  /// before shift start, and it will execute automatically at exactly 00 seconds
  static Future<Map<String, dynamic>> programClockIn(
      String teacherId, String shiftId,
      {required LocationData location, String? platform}) async {
    try {
      AppLogger.debug(
          'ShiftTimesheetService: Programming clock-in for shift $shiftId at exact start time');

      // Validate that we're within the programming window (1 minute before start)
      final shift = await _validateShiftForClockIn(teacherId, shiftId);
      if (shift == null) {
        AppLogger.error('ShiftTimesheetService: ❌ Cannot program clock-in - outside programming window');
        return {
          'success': false,
          'message': 'Can only program clock-in within 1 minute before shift start',
          'shift': null,
        };
      }

      // Check if already clocked in or has open timesheet
      final existingOpenTimesheet = await _findOpenTimesheetEntry(
        teacherId: teacherId,
        shiftId: shiftId,
        useOrderBy: false,
      );

      if (existingOpenTimesheet.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Already clocked in to this shift',
          'shift': shift,
        };
      }

      // Create a programmed clock-in entry
      final programmedData = {
        'teacher_id': teacherId,
        'shift_id': shiftId,
        'type': 'programmed_clock_in',
        'scheduled_execution_time': shift.shiftStart,
        'location_latitude': location.latitude,
        'location_longitude': location.longitude,
        'location_address': location.address,
        'location_neighborhood': location.neighborhood,
        'platform': platform ?? 'unknown',
        'created_at': DateTime.now(),
        'status': 'scheduled', // Will be executed by cloud function
      };

      // Store in a new collection for programmed clock-ins
      final docRef = await _firestore.collection('programmed_clock_ins').add(programmedData);

      AppLogger.debug('ShiftTimesheetService: ✅ Clock-in programmed successfully: ${docRef.id}');

      return {
        'success': true,
        'message': 'Clock-in programmed for ${shift.displayName} at ${DateFormat('h:mm a').format(shift.shiftStart)}',
        'shift': shift,
        'programmedId': docRef.id,
        'executionTime': shift.shiftStart,
      };
    } catch (e) {
      AppLogger.error('ShiftTimesheetService: ❌ Error programming clock-in: $e');
      return {
        'success': false,
        'message': 'Error programming clock-in: $e',
        'shift': null,
      };
    }
  }

  /// Execute programmed clock-ins (called by cloud function at scheduled times)
  static Future<void> executeProgrammedClockIns() async {
    try {
      AppLogger.debug('ShiftTimesheetService: Executing programmed clock-ins...');

      final now = DateTime.now().toUtc();
      final startWindow = now.subtract(const Duration(seconds: 30)); // 30 seconds buffer
      final endWindow = now.add(const Duration(seconds: 30));

      // Find programmed clock-ins ready for execution
      final snapshot = await _firestore
          .collection('programmed_clock_ins')
          .where('status', isEqualTo: 'scheduled')
          .where('scheduled_execution_time', isGreaterThanOrEqualTo: startWindow)
          .where('scheduled_execution_time', isLessThanOrEqualTo: endWindow)
          .get();

      AppLogger.debug('ShiftTimesheetService: Found ${snapshot.docs.length} programmed clock-ins to execute');

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final shiftId = data['shift_id'];
          final teacherId = data['teacher_id'];

          // Create location data from stored values
          final location = LocationData(
            latitude: data['location_latitude'],
            longitude: data['location_longitude'],
            address: data['location_address'],
            neighborhood: data['location_neighborhood'],
          );

          // Execute the actual clock-in
          final result = await clockInToShift(
            teacherId,
            shiftId,
            location: location,
            platform: data['platform'],
          );

          if (result['success']) {
            // Mark as executed
            await doc.reference.update({
              'status': 'executed',
              'executed_at': FieldValue.serverTimestamp(),
              'actual_execution_time': DateTime.now(),
            });
            AppLogger.debug('ShiftTimesheetService: ✅ Executed programmed clock-in ${doc.id}');
          } else {
            // Mark as failed
            await doc.reference.update({
              'status': 'failed',
              'failed_at': FieldValue.serverTimestamp(),
              'failure_reason': result['message'],
            });
            AppLogger.error('ShiftTimesheetService: ❌ Failed to execute programmed clock-in ${doc.id}: ${result['message']}');
          }
        } catch (e) {
          AppLogger.error('ShiftTimesheetService: ❌ Error executing programmed clock-in ${doc.id}: $e');
          await doc.reference.update({
            'status': 'error',
            'error_at': FieldValue.serverTimestamp(),
            'error_message': e.toString(),
          });
        }
      }
    } catch (e) {
      AppLogger.error('ShiftTimesheetService: ❌ Error in executeProgrammedClockIns: $e');
    }
  }

  /// Clock in to a shift with location validation and timesheet creation
  static Future<Map<String, dynamic>> clockInToShift(
      String teacherId, String shiftId,
      {required LocationData location, String? platform}) async {
    try {
      AppLogger.debug(
          'ShiftTimesheetService: Starting clock-in process for shift $shiftId');
      AppLogger.debug('ShiftTimesheetService: Teacher ID: $teacherId');
      AppLogger.debug(
          'ShiftTimesheetService: Location: ${location.neighborhood}');

      // Validate the shift timing and eligibility
      AppLogger.debug(
          'ShiftTimesheetService: Validating shift for clock-in...');
      final shift = await _validateShiftForClockIn(teacherId, shiftId);
      if (shift == null) {
        AppLogger.error(
            'ShiftTimesheetService: ❌ Shift validation failed - no valid shift found');
        return {
          'success': false,
          'message': 'Shift not found or not valid for clock-in right now',
          'shift': null,
        };
      }

      AppLogger.debug('ShiftTimesheetService: ✅ Shift validation passed');
      AppLogger.debug(
          'ShiftTimesheetService: Shift name: ${shift.displayName}');
      AppLogger.debug(
          'ShiftTimesheetService: Shift status: ${shift.status.name}');

      // Check if already clocked in (check for open timesheet)
      AppLogger.debug(
          'ShiftTimesheetService: Checking for existing open timesheet entries...');
      AppLogger.debug(
          'ShiftTimesheetService: Query params - teacherId: $teacherId, shiftId: $shiftId');

      final existingOpenTimesheet = await _findOpenTimesheetEntry(
        teacherId: teacherId,
        shiftId: shiftId,
        useOrderBy: false,
      );

      AppLogger.debug(
          'ShiftTimesheetService: Query returned ${existingOpenTimesheet.docs.length} documents');

      if (existingOpenTimesheet.docs.isNotEmpty) {
        // Log details about the found timesheet entry
        final existingEntry =
            existingOpenTimesheet.docs.first.data() as Map<String, dynamic>?;
        final existingDocId = existingOpenTimesheet.docs.first.id;
        final endTimeValue = existingEntry?['end_time'];

        AppLogger.debug(
            'ShiftTimesheetService: Found timesheet entry: $existingDocId');
        AppLogger.debug(
            'ShiftTimesheetService: end_time value: "$endTimeValue" (type: ${endTimeValue.runtimeType})');
        AppLogger.debug(
            'ShiftTimesheetService: end_time isEmpty: ${endTimeValue == ""}');
        AppLogger.debug(
            'ShiftTimesheetService: end_time isNull: ${endTimeValue == null}');

        // CRITICAL FIX: Validate that the timesheet is actually open
        // The query should only find entries where end_time is '' or null,
        // but we add this safety check to handle edge cases
        final isActuallyOpen = (endTimeValue == null || endTimeValue == '');

        if (!isActuallyOpen) {
          // This shouldn't happen, but if it does, log it as a warning and allow clock-in
          AppLogger.error(
              'ShiftTimesheetService: ⚠️ WARNING: Query returned timesheet with non-empty end_time: "$endTimeValue"');
          AppLogger.error(
              'ShiftTimesheetService: ⚠️ This indicates a bug in _findOpenTimesheetEntry query logic');
          AppLogger.error(
              'ShiftTimesheetService: Treating as closed and allowing clock-in to proceed');
          // Don't return error - allow clock-in to proceed
        } else {
          // Timesheet is genuinely open (end_time is empty or null)
          AppLogger.debug(
              'ShiftTimesheetService: ❌ Already has open timesheet for this shift');
          AppLogger.debug(
              'ShiftTimesheetService: Existing timesheet entry: $existingDocId');
          return {
            'success': false,
            'message': 'You are already clocked in to this shift',
            'shift': shift,
          };
        }
      }

      AppLogger.debug(
          'ShiftTimesheetService: ✅ No open timesheet found, proceeding with clock-in');

      AppLogger.debug('ShiftTimesheetService: ✅ Location validated');

      // Create timesheet entry FIRST (to ensure we have a record)
      AppLogger.debug('ShiftTimesheetService: Creating timesheet entry...');
      final timesheetEntry = await _createTimesheetEntryFromShift(
          shift, location,
          isClockIn: true, platform: platform);

      // Then update shift status (if this fails, we still have the timesheet)
      AppLogger.debug('ShiftTimesheetService: Updating shift status...');
      try {
        final clockInSuccess =
            await ShiftService.clockIn(teacherId, shiftId, platform: platform);
        if (!clockInSuccess) {
          AppLogger.debug(
              'ShiftTimesheetService: ⚠️ ShiftService.clockIn returned false, but continuing with timesheet');
          // Don't fail entirely - we have the timesheet entry
        }
      } catch (e) {
        AppLogger.error(
            'ShiftTimesheetService: ⚠️ ShiftService.clockIn error: $e, but continuing');
        // Continue anyway - the timesheet is what matters
      }

      AppLogger.error(
          'ShiftTimesheetService: ✅ Clock-in successful, timesheet entry created');

      return {
        'success': true,
        'message': 'Successfully clocked in to ${shift.displayName}',
        'shift': shift,
        'timesheetEntry': timesheetEntry,
        'clockInTime': DateTime.now(),
      };
    } catch (e) {
      AppLogger.error(
          'ShiftTimesheetService: ❌ Exception during shift clock-in: $e');
      return {
        'success': false,
        'message': 'Error during clock-in: $e',
        'shift': null,
      };
    }
  }

  /// Clock out from a shift with location and timesheet update
  static Future<Map<String, dynamic>> clockOutFromShift(
      String teacherId, String shiftId,
      {required LocationData location, String? platform}) async {
    try {
      AppLogger.debug(
          'ShiftTimesheetService: Starting clock-out process for shift $shiftId');

      // Validate the shift exists
      final doc =
          await _firestore.collection('teaching_shifts').doc(shiftId).get();
      if (!doc.exists) {
        return {
          'success': false,
          'message': 'Shift not found for clock-out.',
          'shift': null
        };
      }
      final shift = TeachingShift.fromFirestore(doc);
      if (shift.teacherId != teacherId) {
        return {
          'success': false,
          'message': 'You are not assigned to this shift.',
          'shift': null
        };
      }

      // Check for an open timesheet entry (both '' and null)
      final openTimesheetQuery = await _findOpenTimesheetEntry(
        teacherId: teacherId,
        shiftId: shiftId,
        useOrderBy: false,
      );

      if (openTimesheetQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No active clock-in found for this shift.',
          'shift': null,
        };
      }

      // Update timesheet entry with clock-out data FIRST
      final timesheetEntry =
          await _updateTimesheetEntryWithClockOut(shift, location, platform: platform);

      // Then update shift status (if this fails, we still have the timesheet)
      try {
        var clockOutSuccess = await ShiftService.clockOut(teacherId, shiftId);
        
        // Retry if failed
        if (!clockOutSuccess) {
          AppLogger.debug('ShiftTimesheetService: First clock-out attempt failed, retrying...');
          await Future.delayed(const Duration(milliseconds: 500));
          clockOutSuccess = await ShiftService.clockOut(teacherId, shiftId);
        }

        if (!clockOutSuccess) {
          AppLogger.error(
              'ShiftTimesheetService: ⚠️ ShiftService.clockOut failed after retry. Shift status may be out of sync.');
        }
      } catch (e) {
        AppLogger.error(
            'ShiftTimesheetService: ⚠️ ShiftService.clockOut error: $e, but continuing');
      }

      AppLogger.error(
          'ShiftTimesheetService: Clock-out successful, timesheet entry updated');

      return {
        'success': true,
        'message': 'Successfully clocked out from ${shift.displayName}',
        'shift': shift,
        'timesheetEntry': timesheetEntry,
        'clockOutTime': DateTime.now(),
      };
    } catch (e) {
      AppLogger.error('Error during shift clock-out: $e');
      return {
        'success': false,
        'message': 'Error during clock-out: $e',
        'shift': null,
      };
    }
  }

  /// Auto clock-out from shift (for automatic logout)
  static Future<Map<String, dynamic>> autoClockOutFromShift(
      String teacherId, String shiftId,
      {required LocationData location}) async {
    try {
      AppLogger.debug(
          'ShiftTimesheetService: Starting auto clock-out process for shift $shiftId');

      // Validate the shift
      final doc =
          await _firestore.collection('teaching_shifts').doc(shiftId).get();
      if (!doc.exists) {
        return {
          'success': false,
          'message': 'Shift not found for auto clock-out.',
          'shift': null
        };
      }
      final shift = TeachingShift.fromFirestore(doc);
      if (shift.teacherId != teacherId) {
        return {
          'success': false,
          'message': 'You are not assigned to this shift for auto clock-out.',
          'shift': null
        };
      }

      // Check for an open timesheet entry (both '' and null)
      final openTimesheetQuery = await _findOpenTimesheetEntry(
        teacherId: teacherId,
        shiftId: shiftId,
        useOrderBy: false,
      );

      if (openTimesheetQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No active clock-in found for auto clock-out.',
          'shift': null,
        };
      }

      // Update timesheet entry with auto clock-out data
      final timesheetEntry =
          await _updateTimesheetEntryWithAutoClockOut(shift, location);

      // Update shift status
      try {
        await ShiftService.clockOut(teacherId, shiftId);
      } catch (e) {
        AppLogger.error(
            'ShiftTimesheetService: ⚠️ ShiftService.clockOut error during auto-logout: $e');
      }

      AppLogger.error(
          'ShiftTimesheetService: Auto clock-out successful, timesheet entry updated');

      return {
        'success': true,
        'message': 'Automatically clocked out from ${shift.displayName}',
        'shift': shift,
        'timesheetEntry': timesheetEntry,
        'clockOutTime': shift.clockOutDeadline,
      };
    } catch (e) {
      AppLogger.error('Error during shift auto clock-out: $e');
      return {
        'success': false,
        'message': 'Error during auto clock-out: $e',
        'shift': null,
      };
    }
  }

  /// Validate shift for clock-in (single clock-in per shift)
  static Future<TeachingShift?> _validateShiftForClockIn(
      String teacherId, String shiftId) async {
    try {
      AppLogger.debug(
          'ShiftTimesheetService: _validateShiftForClockIn starting...');
      AppLogger.debug(
          'ShiftTimesheetService: Looking for shift $shiftId for teacher $teacherId');

      final doc =
          await _firestore.collection('teaching_shifts').doc(shiftId).get();
      if (!doc.exists) {
        AppLogger.debug(
            'ShiftTimesheetService: ❌ Shift document does not exist');
        return null;
      }

      AppLogger.debug('ShiftTimesheetService: ✅ Shift document found');
      final shift = TeachingShift.fromFirestore(doc);

      // Check if it's the right teacher
      if (shift.teacherId != teacherId) {
        AppLogger.debug(
            'ShiftTimesheetService: ❌ Teacher ID mismatch - expected ${shift.teacherId}, got $teacherId');
        return null;
      }

      AppLogger.debug('ShiftTimesheetService: ✅ Teacher ID matches');

      // CONSISTENT UTC TIME HANDLING (no grace period)
      final nowUtc = DateTime.now().toUtc();
      final shiftStartUtc = shift.shiftStart.toUtc();
      final shiftEndUtc = shift.shiftEnd.toUtc();

      AppLogger.debug('ShiftTimesheetService: Clock-in validation:');
      AppLogger.debug('  - Current UTC time: $nowUtc');
      AppLogger.debug('  - Shift start (UTC): $shiftStartUtc');
      AppLogger.debug('  - Shift end (UTC): $shiftEndUtc');
      AppLogger.debug('  - Shift Status: ${shift.status.name}');
      
      // Allow clock-in 1 minute before shift start
      final clockInWindowStartUtc = shiftStartUtc.subtract(const Duration(minutes: 1));
      AppLogger.debug('  - Clock-in window start (UTC): $clockInWindowStartUtc (1 minute before shift start)');
      AppLogger.debug(
          '  - nowUtc.isBefore(clockInWindowStartUtc): ${nowUtc.isBefore(clockInWindowStartUtc)}');
      AppLogger.debug(
          '  - nowUtc.isAfter(shiftEndUtc): ${nowUtc.isAfter(shiftEndUtc)}');

      final withinWindow =
          !nowUtc.isBefore(clockInWindowStartUtc) && !nowUtc.isAfter(shiftEndUtc);

      AppLogger.debug('  - withinWindow result: $withinWindow');

      if (withinWindow) {
        AppLogger.debug(
            'ShiftTimesheetService: ✅ Shift validated for clock-in - within time window');
        return shift;
      }

      AppLogger.debug(
          'ShiftTimesheetService: ❌ Shift not within valid time window');
      AppLogger.error(
          'ShiftTimesheetService: Current UTC $nowUtc is not between $clockInWindowStartUtc (1 min before shift start) and $shiftEndUtc');
      return null;
    } catch (e) {
      AppLogger.error(
          'ShiftTimesheetService: ❌ Exception in validating shift: $e');
      return null;
    }
  }

  /// Create timesheet entry from shift clock-in
  static Future<Map<String, dynamic>> _createTimesheetEntryFromShift(
      TeachingShift shift, LocationData location,
      {required bool isClockIn, String? platform}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final date = DateFormat('MMM dd, yyyy').format(now);
      final time = DateFormat('h:mm a').format(now);

      // Improve human-readable address if needed
      try {
        final addr = location.address.toLowerCase();
        final neigh = location.neighborhood.toLowerCase();
        final looksLikeCoords = addr.startsWith('location:') ||
            neigh.startsWith('coordinates:') ||
            neigh == 'gps coordinates' ||
            RegExp(r'^-?\d+\.\d+').hasMatch(location.address);
        if (looksLikeCoords) {
          final improved = await LocationService.coordinatesToLocation(
              location.latitude, location.longitude);
          if (improved != null) {
            location = LocationData(
              latitude: location.latitude,
              longitude: location.longitude,
              address: improved.address,
              neighborhood: improved.neighborhood,
            );
          }
        }
      } catch (_) {}

      // Build shift type string for export (ConnectTeam-style)
      final shiftTypeString = _buildShiftTypeString(shift);

      // Create timesheet entry data with proper clock-in timestamp
      final entryData = {
        'teacher_id': user.uid,
        'teacher_email': user.email,
        'teacher_name': shift.teacherName,
        'shift_id': shift.id,
        'date': date,
        'student_name': shift.studentNames.isNotEmpty
            ? shift.studentNames.join(', ')
            : 'No students assigned',
        'start_time': time,
        'end_time': '',
        'total_hours': '00:00',
        'hourly_rate': shift.hourlyRate, // Add hourly rate from shift
        'description':
            'Teaching session: ${shift.subjectDisplayName} - ${shift.displayName}',
        'status': 'pending', // Changed: Immediately set to pending on clock-in (not draft)
        'source': 'shift_clock_in',
        'completion_method': 'pending',
        // Store the actual clock-in timestamp for persistence
        'clock_in_timestamp': Timestamp.fromDate(now),
        // Platform tracking
        'clock_in_platform': platform ?? 'unknown',
        // Location data
        'clock_in_latitude': location.latitude,
        'clock_in_longitude': location.longitude,
        'clock_in_address': location.address,
        'clock_in_neighborhood': location.neighborhood,
        'clock_out_latitude': null,
        'clock_out_longitude': null,
        'clock_out_address': null,
        'clock_out_neighborhood': null,
        // NEW: Export fields for ConnectTeam-style export
        'shift_title': shift.displayName, // CRITICAL: Cached shift display name
        'shift_type': shiftTypeString, // Formatted type string
        'scheduled_start': Timestamp.fromDate(shift.shiftStart),
        'scheduled_end': Timestamp.fromDate(shift.shiftEnd),
        'scheduled_duration_minutes': shift.scheduledDurationMinutes,
        'employee_notes': '', // Empty initially, can be filled later
        'manager_notes': '', // Empty initially, admin can add later
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Save to Firebase
      final docRef =
          await _firestore.collection('timesheet_entries').add(entryData);

      AppLogger.error(
          'ShiftTimesheetService: Created timesheet entry ${docRef.id} for shift ${shift.id}');

      return {
        'documentId': docRef.id,
        ...entryData,
      };
    } catch (e) {
      AppLogger.error('Error creating timesheet entry: $e');
      rethrow;
    }
  }

  /// Update timesheet entry with clock-out data
  static Future<Map<String, dynamic>> _updateTimesheetEntryWithClockOut(
      TeachingShift shift, LocationData location, {String? platform}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Find the most recent open timesheet entry (both '' and null)
      final querySnapshot = await _findOpenTimesheetEntry(
        teacherId: user.uid,
        shiftId: shift.id,
        useOrderBy: true,
      );

      if (querySnapshot.docs.isEmpty) {
        throw Exception('No timesheet entry found for this shift');
      }

      final docRef = querySnapshot.docs.first.reference;
      final docData = querySnapshot.docs.first.data() as Map<String, dynamic>?;

      final now = DateTime.now(); // Actual clock out time
      
      // --- FIX 1: CAP PAYMENT TIME TO SCHEDULED DURATION ---
      // For calculation purposes, cap both start and end times to scheduled shift window
      // This prevents overpayment for early clock-ins or late clock-outs
      DateTime effectiveEndTime = now;
      if (now.isAfter(shift.shiftEnd)) {
        AppLogger.debug(
            'ShiftTimesheetService: Clock-out is after shift end. Capping calculation time.');
        effectiveEndTime = shift.shiftEnd;
      }

      // Calculate total hours using the stored clock-in timestamp
      DateTime startDateTime;
      if (docData?['clock_in_timestamp'] != null) {
        startDateTime = (docData!['clock_in_timestamp'] as Timestamp).toDate();
      } else {
        // Fallback to parsing the time string
        final startTime = docData?['start_time'] as String? ?? '';
        if (startTime.isNotEmpty) {
          startDateTime = DateFormat('h:mm a').parse(startTime);
          // Adjust to today's date
          startDateTime = DateTime(now.year, now.month, now.day,
              startDateTime.hour, startDateTime.minute);
        } else {
          // If no start time, use shift start as fallback
          startDateTime = shift.shiftStart;
        }
      }

      // Cap start time to shift start (no payment for early clock-ins)
      DateTime effectiveStartTime = startDateTime;
      if (startDateTime.isBefore(shift.shiftStart)) {
        AppLogger.debug(
            'ShiftTimesheetService: Clock-in is before shift start. Capping calculation time.');
        effectiveStartTime = shift.shiftStart;
      }

      // Calculate duration using the EFFECTIVE (capped) times
      Duration rawDuration = effectiveEndTime.difference(effectiveStartTime);
      
      // Cap total duration to scheduled shift duration (prevent overpayment)
      final scheduledDuration = shift.shiftEnd.difference(shift.shiftStart);
      final validDuration = rawDuration > scheduledDuration 
          ? scheduledDuration 
          : (rawDuration.isNegative ? Duration.zero : rawDuration);
      
      AppLogger.debug(
          'ShiftTimesheetService: Payment calculation - Actual: ${rawDuration.inMinutes} min, Scheduled: ${scheduledDuration.inMinutes} min, Billable: ${validDuration.inMinutes} min');
      
      // Format the display string based on the CAPPED end time
      final endTimeString = DateFormat('h:mm a').format(effectiveEndTime);
      
      final totalHours =
          '${validDuration.inHours.toString().padLeft(2, '0')}:${(validDuration.inMinutes % 60).toString().padLeft(2, '0')}:${(validDuration.inSeconds % 60).toString().padLeft(2, '0')}';

      // --- FIX 2: CALCULATE PAY AND SAVE TO DB ---
      double hourlyRate = shift.hourlyRate;
      if (hourlyRate <= 0) {
        // Fallback to rate stored in timesheet if shift rate is missing
        hourlyRate = (docData?['hourly_rate'] as num?)?.toDouble() ?? 0.0;
      }

      final double hoursWorked = validDuration.inSeconds / 3600.0;
      final double calculatedPay = hoursWorked * hourlyRate;

      AppLogger.debug(
          'ShiftTimesheetService: Updating timesheet ${docRef.id} with clock-out data...');
      AppLogger.debug('ShiftTimesheetService: Setting end_time to: "$endTimeString"');
      AppLogger.debug(
          'ShiftTimesheetService: Setting total_hours to: $totalHours');
      AppLogger.debug(
          'ShiftTimesheetService: Actual clock-out time: ${now.toIso8601String()}, Effective (capped) time: ${effectiveEndTime.toIso8601String()}');
      AppLogger.debug(
          'ShiftTimesheetService: Calculated payment - Hours: $hoursWorked, Rate: \$$hourlyRate, Pay: \$$calculatedPay');

      // --- FIX 3: SAVE PAYMENT DATA AND UPDATE STATUS ---
      // Update the timesheet entry
      await docRef.update({
        'end_time': endTimeString,
        'total_hours': totalHours,
        'clock_out_timestamp': Timestamp.fromDate(now), // Save ACTUAL time for audit
        'effective_end_timestamp': Timestamp.fromDate(effectiveEndTime), // Save PAID time
        
        // SAVE PAYMENT DATA SO ADMIN PANEL SEES IT
        'total_pay': calculatedPay,
        'payment_amount': calculatedPay, // Saving as both keys to be safe with legacy admin code
        'hourly_rate': hourlyRate, // Ensure rate is locked in
        
        // UPDATE STATUS
        'status': 'pending', // Changed from 'draft' to 'pending'
        'completion_method': 'manual',
        
        // Location data
        'clock_out_latitude': location.latitude,
        'clock_out_longitude': location.longitude,
        'clock_out_address': location.address,
        'clock_out_neighborhood': location.neighborhood,
        'clock_out_platform': platform ?? 'unknown',
        'updated_at': FieldValue.serverTimestamp(),
      });

      AppLogger.info(
          'ShiftTimesheetService: ✅ Updated timesheet entry ${docRef.id} with clock-out data');
      AppLogger.info(
          'ShiftTimesheetService: ✅ Timesheet end_time set to: "$endTimeString" (should not be empty)');

      // Verify the update persisted correctly (CRITICAL)
      try {
        // Force get from server to ensure we're not reading cache
        final verifyDoc = await docRef.get(const GetOptions(source: Source.server));
        final verifyData = verifyDoc.data() as Map<String, dynamic>?;
        final verifiedEndTime = verifyData?['end_time'];
        AppLogger.debug(
            'ShiftTimesheetService: Verification - end_time in database: "$verifiedEndTime"');

        if (verifiedEndTime == null || verifiedEndTime == '') {
          throw Exception('Clock-out verification failed: end_time not persisted in database');
        }
      } catch (verifyError) {
        AppLogger.error('ShiftTimesheetService: Verification failed: $verifyError');
        
        // If it's a "not found" or "value missing" error, rethrow to prevent false success
        if (verifyError.toString().contains('end_time not persisted')) {
          rethrow;
        }
        // For network errors during verification (e.g. offline), we proceed cautiously
        // but log the warning. The update() call didn't throw, so it's likely pending.
      }

      return {
        'documentId': docRef.id,
        if (docData != null) ...docData,
        'end_time': endTimeString,
        'total_hours': totalHours,
        'status': 'pending',
        'total_pay': calculatedPay,
        'payment_amount': calculatedPay,
        'clock_out_latitude': location.latitude,
        'clock_out_longitude': location.longitude,
        'clock_out_address': location.address,
        'clock_out_neighborhood': location.neighborhood,
      };
    } catch (e) {
      AppLogger.error('Error updating timesheet entry: $e');
      rethrow;
    }
  }

  /// Update timesheet entry with auto clock-out data
  static Future<Map<String, dynamic>> _updateTimesheetEntryWithAutoClockOut(
      TeachingShift shift, LocationData location) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Find the most recent open timesheet entry (both '' and null)
      final querySnapshot = await _findOpenTimesheetEntry(
        teacherId: user.uid,
        shiftId: shift.id,
        useOrderBy: true,
      );

      if (querySnapshot.docs.isEmpty) {
        throw Exception('No timesheet entry found for this shift');
      }

      final docRef = querySnapshot.docs.first.reference;
      final docData = querySnapshot.docs.first.data() as Map<String, dynamic>?;

      // Use shift end time (NOT +15 minutes) for auto clock-out - no overtime allowed
      final autoClockOutTimeUtc = shift.shiftEnd.toUtc();
      final autoClockOutTimeLocal = autoClockOutTimeUtc.toLocal();
      final effectiveEndTime = autoClockOutTimeLocal; // Already capped at shift end
      final endTime = DateFormat('h:mm a').format(effectiveEndTime);
      
      AppLogger.debug(
          'ShiftTimesheetService: Auto clock-out capped at shift end time: ${effectiveEndTime.toIso8601String()}');

      // Calculate total hours using stored clock-in timestamp
      DateTime startDateTime;
      if (docData?['clock_in_timestamp'] != null) {
        startDateTime = (docData!['clock_in_timestamp'] as Timestamp).toDate();
      } else {
        // Fallback to parsing the time string
        final startTime = docData?['start_time'] as String? ?? '';
        if (startTime.isNotEmpty) {
          startDateTime = DateFormat('h:mm a').parse(startTime);
          // Adjust to today's date
          startDateTime = DateTime(effectiveEndTime.year, effectiveEndTime.month, effectiveEndTime.day,
              startDateTime.hour, startDateTime.minute);
        } else {
          // If no start time, use shift start as fallback
          startDateTime = shift.shiftStart;
        }
      }

      // Cap start time to shift start (no payment for early clock-ins)
      DateTime effectiveStartTime = startDateTime;
      if (startDateTime.isBefore(shift.shiftStart)) {
        AppLogger.debug(
            'ShiftTimesheetService: Auto clock-out - Clock-in was before shift start. Capping calculation time.');
        effectiveStartTime = shift.shiftStart;
      }

      // Calculate duration using effective (capped) times
      Duration rawDuration = effectiveEndTime.difference(effectiveStartTime);
      
      // Cap total duration to scheduled shift duration (prevent overpayment)
      final scheduledDuration = shift.shiftEnd.difference(shift.shiftStart);
      final validDuration = rawDuration > scheduledDuration 
          ? scheduledDuration 
          : (rawDuration.isNegative ? Duration.zero : rawDuration);
      
      AppLogger.debug(
          'ShiftTimesheetService: Auto clock-out payment calculation - Actual: ${rawDuration.inMinutes} min, Scheduled: ${scheduledDuration.inMinutes} min, Billable: ${validDuration.inMinutes} min');
      final totalHours =
          '${validDuration.inHours.toString().padLeft(2, '0')}:${(validDuration.inMinutes % 60).toString().padLeft(2, '0')}:${(validDuration.inSeconds % 60).toString().padLeft(2, '0')}';

      // Calculate payment for auto clock-out
      double hourlyRate = shift.hourlyRate;
      if (hourlyRate <= 0) {
        hourlyRate = (docData?['hourly_rate'] as num?)?.toDouble() ?? 0.0;
      }
      final double hoursWorked = validDuration.inSeconds / 3600.0;
      final double calculatedPay = hoursWorked * hourlyRate;

      // Update the timesheet entry
      await docRef.update({
        'end_time': endTime,
        'total_hours': totalHours,
        'clock_out_timestamp': Timestamp.fromDate(autoClockOutTimeUtc), // Actual time
        'effective_end_timestamp': Timestamp.fromDate(effectiveEndTime), // Effective (capped) time
        
        // SAVE PAYMENT DATA SO ADMIN PANEL SEES IT
        'total_pay': calculatedPay,
        'payment_amount': calculatedPay,
        'hourly_rate': hourlyRate,
        
        'clock_out_latitude': location.latitude,
        'clock_out_longitude': location.longitude,
        'clock_out_address': location.address,
        'clock_out_neighborhood': location.neighborhood,
        'clock_out_platform': 'auto', // Auto clock-out
        'completion_method': 'auto_logout',
        'auto_logout_time': Timestamp.fromDate(autoClockOutTimeUtc),
        'status': 'pending', // Auto-submit on clock-out
        'updated_at': FieldValue.serverTimestamp(),
      });

      AppLogger.info(
          'ShiftTimesheetService: Updated timesheet entry ${docRef.id} with auto clock-out data');

      return {
        'documentId': docRef.id,
        if (docData != null) ...docData,
        'end_time': endTime,
        'total_hours': totalHours,
        'status': 'pending',
        'total_pay': calculatedPay,
        'payment_amount': calculatedPay,
        'clock_out_latitude': location.latitude,
        'clock_out_longitude': location.longitude,
        'clock_out_address': location.address,
        'clock_out_neighborhood': location.neighborhood,
        'completion_method': 'auto_logout',
        'auto_logout_time': autoClockOutTimeUtc,
      };
    } catch (e) {
      AppLogger.error('Error updating timesheet entry with auto clock-out: $e');
      rethrow;
    }
  }

  /// Helper method to find open timesheet entries consistently
  /// Checks both end_time == '' and end_time == null to handle legacy data
  static Future<QuerySnapshot> _findOpenTimesheetEntry({
    required String teacherId,
    String? shiftId,
    bool useOrderBy = true,
  }) async {
    // Build base query
    var query = _firestore
        .collection('timesheet_entries')
        .where('teacher_id', isEqualTo: teacherId);

    // Add shift_id filter if provided
    if (shiftId != null) {
      query = query.where('shift_id', isEqualTo: shiftId);
    }

    // Try with end_time == '' first
    var tempQuery = query.where('end_time', isEqualTo: '');
    if (useOrderBy) {
      tempQuery = tempQuery.orderBy('created_at', descending: true);
    }
    tempQuery = tempQuery.limit(1);

    var result = await tempQuery.get();

    // Fallback to end_time == null for legacy entries
    if (result.docs.isEmpty) {
      tempQuery = query.where('end_time', isEqualTo: null);
      if (useOrderBy) {
        tempQuery = tempQuery.orderBy('created_at', descending: true);
      }
      tempQuery = tempQuery.limit(1);
      result = await tempQuery.get();
    }

    return result;
  }

  /// Get active shift for teacher (if any)
  static Future<TeachingShift?> getActiveShift(String teacherId) async {
    try {
      // Check for open timesheet entries (both '' and null)
      final openTimesheetQuery = await _findOpenTimesheetEntry(
        teacherId: teacherId,
        useOrderBy: false,
      );

      if (openTimesheetQuery.docs.isEmpty) {
        AppLogger.debug(
            'ShiftTimesheetService: No open timesheet entries found');
        return null;
      }

      // Get the shift ID from the open timesheet entry
      final openEntry =
          openTimesheetQuery.docs.first.data() as Map<String, dynamic>?;
      final shiftId = openEntry?['shift_id'] as String?;

      if (shiftId == null) {
        AppLogger.debug(
            'ShiftTimesheetService: No shift_id found in open timesheet entry');
        return null;
      }

      // Get the actual shift
      final shiftDoc =
          await _firestore.collection('teaching_shifts').doc(shiftId).get();
      if (!shiftDoc.exists) {
        AppLogger.debug('ShiftTimesheetService: Shift $shiftId not found');
        return null;
      }

      final shift = TeachingShift.fromFirestore(shiftDoc);

      // Don't treat as active if shift already has clock_out_time
      if (shift.clockOutTime != null) {
        AppLogger.debug(
            'ShiftTimesheetService: Shift ${shift.id} already has clock_out_time, not active');
        return null;
      }

      AppLogger.error(
          'ShiftTimesheetService: Found active shift with open timesheet: ${shift.id}');
      return shift;
    } catch (e) {
      AppLogger.error('Error getting active shift: $e');
      return null;
    }
  }

  /// Get current open session with proper timestamp handling
  static Future<Map<String, dynamic>?> getOpenSession(String teacherId) async {
    try {
      // Find the most recent open timesheet entry
      var openTimesheetQuery = await _firestore
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: teacherId)
          .where('end_time', isEqualTo: '')
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      // Fallback for legacy entries with null end_time
      if (openTimesheetQuery.docs.isEmpty) {
        openTimesheetQuery = await _firestore
            .collection('timesheet_entries')
            .where('teacher_id', isEqualTo: teacherId)
            .where('end_time', isEqualTo: null)
            .orderBy('created_at', descending: true)
            .limit(1)
            .get();
      }

      if (openTimesheetQuery.docs.isEmpty) {
        return null;
      }

      final openEntryDoc = openTimesheetQuery.docs.first;
      final openEntry = openEntryDoc.data();
      final shiftId = openEntry['shift_id'] as String?;

      if (shiftId == null) {
        return null;
      }

      // Load the associated shift
      final shiftDoc =
          await _firestore.collection('teaching_shifts').doc(shiftId).get();
      if (!shiftDoc.exists) return null;

      final shift = TeachingShift.fromFirestore(shiftDoc);

      // Don't resume if shift already has clock_out_time (already clocked out)
      if (shift.clockOutTime != null) {
        AppLogger.debug(
            'ShiftTimesheetService: Shift ${shift.id} already has clock_out_time, not resuming session');
        return null;
      }

      // Get the clock-in timestamp - prioritize the stored timestamp
      DateTime? startDateTime;

      // First try the clock_in_timestamp field
      if (openEntry['clock_in_timestamp'] != null) {
        startDateTime = (openEntry['clock_in_timestamp'] as Timestamp).toDate();
      }
      // Then try created_at timestamp
      else if (openEntry['created_at'] != null) {
        startDateTime = (openEntry['created_at'] as Timestamp).toDate();
      }
      // Finally fallback to parsing date and time strings
      else {
        final dateStr = openEntry['date'] as String?;
        final timeStr = openEntry['start_time'] as String?;
        if (dateStr != null && timeStr != null) {
          try {
            startDateTime =
                DateFormat('MMM dd, yyyy h:mm a').parse('$dateStr $timeStr');
          } catch (_) {
            // If parsing fails, use current time as fallback
            startDateTime = DateTime.now();
          }
        }
      }

      return {
        'shift': shift,
        'timesheetEntryId': openEntryDoc.id,
        'timesheetEntry': openEntry,
        'clockInTime': startDateTime ?? DateTime.now(),
      };
    } catch (e) {
      AppLogger.error('Error getting open session: $e');
      return null;
    }
  }

  /// Get timesheet entry for a specific shift
  static Future<Map<String, dynamic>?> getTimesheetEntryForShift(
      String shiftId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _firestore
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: shiftId)
          .where('teacher_id', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return {
        'documentId': snapshot.docs.first.id,
        ...snapshot.docs.first.data(),
      };
    } catch (e) {
      AppLogger.error('Error getting timesheet entry for shift: $e');
      return null;
    }
  }

  /// Get actual payment amount from timesheet for a shift
  /// Returns the sum of all payment_amount from timesheet entries for this shift
  static Future<double> getActualPaymentForShift(String shiftId) async {
    try {
      // Get all timesheet entries for this shift (not just for current user, for admin view)
      final snapshot = await _firestore
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: shiftId)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      double totalPayment = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Prefer payment_amount, fallback to total_pay
        final payment = (data['payment_amount'] as num?)?.toDouble() ??
            (data['total_pay'] as num?)?.toDouble() ??
            0.0;
        totalPayment += payment;
      }

      return totalPayment;
    } catch (e) {
      AppLogger.error('Error getting actual payment for shift: $e');
      return 0.0;
    }
  }

  /// OPTIMIZATION: Batch get payments for multiple shifts in a single query
  /// This is much faster than calling getActualPaymentForShift multiple times
  static Future<Map<String, double>> getActualPaymentsForShifts(List<String> shiftIds) async {
    if (shiftIds.isEmpty) return {};
    
    try {
      // Use 'in' query to get all timesheet entries for all shifts at once
      // Note: Firestore 'in' queries are limited to 10 items, so we need to batch
      final paymentMap = <String, double>{};
      
      // Initialize all shift IDs with 0.0
      for (final shiftId in shiftIds) {
        paymentMap[shiftId] = 0.0;
      }
      
      // Process in batches of 10 (Firestore 'in' query limit)
      for (int i = 0; i < shiftIds.length; i += 10) {
        final batch = shiftIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection('timesheet_entries')
            .where('shift_id', whereIn: batch)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final shiftId = data['shift_id'] as String?;
          if (shiftId == null || !paymentMap.containsKey(shiftId)) continue;
          
          // Prefer payment_amount, fallback to total_pay
          final payment = (data['payment_amount'] as num?)?.toDouble() ??
              (data['total_pay'] as num?)?.toDouble() ??
              0.0;
          paymentMap[shiftId] = (paymentMap[shiftId] ?? 0.0) + payment;
        }
      }
      
      return paymentMap;
    } catch (e) {
      AppLogger.error('Error batch getting payments for shifts: $e');
      // Fallback: return map with zeros
      return {for (var id in shiftIds) id: 0.0};
    }
  }

  /// Build shift type string for ConnectTeam-style export
  /// Format: "Stu - Student Name - Teacher Name (1hr 2days weekly)"
  static String _buildShiftTypeString(TeachingShift shift) {
    final parts = <String>[];

    // Student info (if teaching category)
    if (shift.category == ShiftCategory.teaching && shift.studentNames.isNotEmpty) {
      parts.add('Stu - ${shift.studentNames.first}');
    } else if (shift.category != ShiftCategory.teaching) {
      // For leader shifts, use role
      parts.add(shift.leaderRole ?? 'Leader');
    }

    // Teacher/Leader name
    parts.add(shift.teacherName);

    // Schedule info
    final duration = shift.shiftDurationHours;
    String scheduleInfo;
    if (shift.enhancedRecurrence.type != EnhancedRecurrenceType.none) {
      final days = shift.enhancedRecurrence.selectedWeekdays.length;
      scheduleInfo = '${duration.toStringAsFixed(0)}hr ${days}days weekly';
    } else if (shift.recurrence != RecurrencePattern.none) {
      scheduleInfo = '${duration.toStringAsFixed(0)}hr ${shift.recurrence.name}';
    } else {
      scheduleInfo = '${duration.toStringAsFixed(0)}hr one-time';
    }
    parts.add('($scheduleInfo)');

    return parts.join(' - ');
  }
}
