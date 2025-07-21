import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/teaching_shift.dart';
import '../models/employee_model.dart';
import 'location_service.dart';
import 'shift_service.dart';

class ShiftTimesheetService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if teacher has a valid shift for clock-in or active shift for clock-out
  static Future<Map<String, dynamic>> getValidShiftForClockIn(
      String teacherId) async {
    try {
      print(
          'ShiftTimesheetService: Checking for valid shift for teacher $teacherId');
      final now = DateTime.now();
      print('ShiftTimesheetService: Current local time: $now');
      print('ShiftTimesheetService: Current timezone: ${now.timeZoneName}');
      print('ShiftTimesheetService: Current UTC offset: ${now.timeZoneOffset}');

      // First check if teacher has an active shift (already clocked in)
      final activeShift = await getActiveShift(teacherId);
      if (activeShift != null) {
        print(
            'ShiftTimesheetService: Found active shift ${activeShift.id} - ${activeShift.displayName}');
        print(
            'ShiftTimesheetService: Active shift can clock out: ${activeShift.canClockOut}');
        return {
          'shift': activeShift,
          'canClockIn': false,
          'canClockOut':
              true, // If we found an active timesheet, they can clock out
          'status': 'active',
          'message':
              'You are currently clocked in to ${activeShift.displayName}',
        };
      }

      // Check for all shifts that could be clocked in
      final snapshot = await _firestore
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: teacherId)
          .get();

      print(
          'ShiftTimesheetService: Found ${snapshot.docs.length} total shifts for teacher');

      List<TeachingShift> validShifts = [];

      for (var doc in snapshot.docs) {
        final shift = TeachingShift.fromFirestore(doc);

        // Convert shift times to local timezone for comparison
        final shiftStartLocal = shift.shiftStart.toLocal();
        final shiftEndLocal = shift.shiftEnd.toLocal();
        final clockInWindow =
            shiftStartLocal.subtract(const Duration(minutes: 15));
        final clockOutWindow = shiftEndLocal.add(const Duration(minutes: 15));

        print('ShiftTimesheetService: Shift ${shift.id}:');
        print('  - Display Name: ${shift.displayName}');
        print('  - Status: ${shift.status.name}');
        print('  - Shift Start (stored): ${shift.shiftStart}');
        print('  - Shift End (stored): ${shift.shiftEnd}');
        print('  - Shift Start (local): $shiftStartLocal');
        print('  - Shift End (local): $shiftEndLocal');
        print('  - Clock-in Window (local): $clockInWindow');
        print('  - Clock-out Window (local): $clockOutWindow');
        print(
            '  - Current time in window: ${now.isAfter(clockInWindow) && now.isBefore(clockOutWindow)}');
        print('  - canClockIn: ${shift.canClockIn}');
        print('  - isClockedIn: ${shift.isClockedIn}');
        print('  - Is scheduled: ${shift.status == ShiftStatus.scheduled}');

        // Allow clock-in during entire shift window (15 min before to 15 min after)
        // Allow multiple clock-ins throughout the shift duration
        if (now.isAfter(clockInWindow) && now.isBefore(clockOutWindow)) {
          print(
              'ShiftTimesheetService: ✅ VALID SHIFT FOUND: ${shift.id} - ${shift.displayName}');
          validShifts.add(shift);
        } else {
          print(
              'ShiftTimesheetService: ❌ Shift not valid for clock-in - outside time window');
          print(
              'ShiftTimesheetService: Current time: $now, Window: $clockInWindow to $clockOutWindow');
        }
      }

      if (validShifts.isNotEmpty) {
        // Return the first valid shift
        final shift = validShifts.first;
        return {
          'shift': shift,
          'canClockIn': true,
          'canClockOut': false,
          'status': 'scheduled',
          'message': 'Ready to clock in to ${shift.displayName}',
        };
      }

      print('ShiftTimesheetService: No valid shifts found for clock-in');
      return {
        'shift': null,
        'canClockIn': false,
        'canClockOut': false,
        'status': 'none',
        'message': 'No valid shifts available for clock-in at this time',
      };
    } catch (e) {
      print('Error checking for valid shift: $e');
      return {
        'shift': null,
        'canClockIn': false,
        'canClockOut': false,
        'status': 'error',
        'message': 'Error checking shift availability: $e',
      };
    }
  }

  /// Clock in to a shift with location validation and timesheet creation
  static Future<Map<String, dynamic>> clockInToShift(
      String teacherId, String shiftId,
      {required LocationData location}) async {
    try {
      print(
          'ShiftTimesheetService: Starting clock-in process for shift $shiftId');

      // First validate the shift timing and eligibility (allow multiple clock-ins)
      final shift = await _validateShiftForMultipleClockIn(teacherId, shiftId);
      if (shift == null) {
        return {
          'success': false,
          'message': 'No valid shift found for clock-in',
          'shift': null,
        };
      }

      // Get location and validate
      if (location == null) {
        return {
          'success': false,
          'message': 'Location is required for clock-in',
          'shift': null,
        };
      }

      // Perform clock-in (this will update shift status to active)
      final clockInSuccess = await ShiftService.clockIn(teacherId, shiftId);
      if (!clockInSuccess) {
        return {
          'success': false,
          'message': 'Failed to clock in to shift',
          'shift': null,
        };
      }

      // Create timesheet entry (always create new entry for each clock-in)
      final timesheetEntry = await _createTimesheetEntryFromShift(
          shift, location,
          isClockIn: true);

      print(
          'ShiftTimesheetService: Clock-in successful, timesheet entry created');

      return {
        'success': true,
        'message': 'Successfully clocked in to ${shift.displayName}',
        'shift': shift,
        'timesheetEntry': timesheetEntry,
        'clockInTime': DateTime.now(),
      };
    } catch (e) {
      print('Error during shift clock-in: $e');
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
      {required LocationData location}) async {
    try {
      print(
          'ShiftTimesheetService: Starting clock-out process for shift $shiftId');

      // Validate the shift is valid for clock-out by checking for an open timesheet entry
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

      // Check for an open timesheet entry to validate if we can clock out.
      final openTimesheetQuery = await _firestore
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: shiftId)
          .where('teacher_id', isEqualTo: teacherId)
          .where('end_time', isEqualTo: '')
          .limit(1)
          .get();

      if (openTimesheetQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Couldn\'t find a valid shift to clock out.',
          'shift': null,
        };
      }

      // Perform clock-out
      final clockOutSuccess = await ShiftService.clockOut(teacherId, shiftId);
      if (!clockOutSuccess) {
        return {
          'success': false,
          'message': 'Failed to clock out from shift',
          'shift': null,
        };
      }

      // Update timesheet entry with clock-out data
      final timesheetEntry =
          await _updateTimesheetEntryWithClockOut(shift, location);

      print(
          'ShiftTimesheetService: Clock-out successful, timesheet entry updated');

      return {
        'success': true,
        'message': 'Successfully clocked out from ${shift.displayName}',
        'shift': shift,
        'timesheetEntry': timesheetEntry,
        'clockOutTime': DateTime.now(),
      };
    } catch (e) {
      print('Error during shift clock-out: $e');
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
      print(
          'ShiftTimesheetService: Starting auto clock-out process for shift $shiftId');

      // Validate the shift is valid for clock-out by checking for an open timesheet entry
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

      // Check for an open timesheet entry to validate if we can clock out.
      final openTimesheetQuery = await _firestore
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: shiftId)
          .where('teacher_id', isEqualTo: teacherId)
          .where('end_time', isEqualTo: '')
          .limit(1)
          .get();

      if (openTimesheetQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Couldn\'t find an active clock-in for auto clock-out.',
          'shift': null,
        };
      }

      // Perform clock-out
      final clockOutSuccess = await ShiftService.clockOut(teacherId, shiftId);
      if (!clockOutSuccess) {
        return {
          'success': false,
          'message': 'Failed to auto clock out from shift',
          'shift': null,
        };
      }

      // Update timesheet entry with auto clock-out data
      final timesheetEntry =
          await _updateTimesheetEntryWithAutoClockOut(shift, location);

      print(
          'ShiftTimesheetService: Auto clock-out successful, timesheet entry updated');

      return {
        'success': true,
        'message': 'Automatically clocked out from ${shift.displayName}',
        'shift': shift,
        'timesheetEntry': timesheetEntry,
        'clockOutTime': shift.clockOutDeadline,
      };
    } catch (e) {
      print('Error during shift auto clock-out: $e');
      return {
        'success': false,
        'message': 'Error during auto clock-out: $e',
        'shift': null,
      };
    }
  }

  /// Validate shift for clock-in (allowing multiple clock-ins within window)
  static Future<TeachingShift?> _validateShiftForMultipleClockIn(
      String teacherId, String shiftId) async {
    try {
      final doc =
          await _firestore.collection('teaching_shifts').doc(shiftId).get();
      if (!doc.exists) return null;

      final shift = TeachingShift.fromFirestore(doc);

      // Check if it's the right teacher
      if (shift.teacherId != teacherId) return null;

      final now = DateTime.now();
      // Convert shift times to local timezone for comparison
      final shiftStartLocal = shift.shiftStart.toLocal();
      final shiftEndLocal = shift.shiftEnd.toLocal();
      final clockInWindow =
          shiftStartLocal.subtract(const Duration(minutes: 15));
      final clockOutWindow = shiftEndLocal.add(const Duration(minutes: 15));

      print('ShiftTimesheetService: Multiple clock-in validation:');
      print('  - Current local time: $now');
      print('  - Shift Start (local): $shiftStartLocal');
      print('  - Shift End (local): $shiftEndLocal');
      print('  - Clock-in Window: $clockInWindow');
      print('  - Clock-out Window: $clockOutWindow');

      // Allow clock-in during entire shift window regardless of current clock status
      // This enables multiple clock-in/out cycles throughout the shift duration
      if (now.isAfter(clockInWindow) && now.isBefore(clockOutWindow)) {
        print(
            'ShiftTimesheetService: ✅ Shift validated for multiple clock-in - within extended time window');
        return shift;
      }

      print('ShiftTimesheetService: Shift not within valid time window');
      return null;
    } catch (e) {
      print('Error validating shift for multiple clock-in: $e');
      return null;
    }
  }

  /// Create timesheet entry from shift clock-in
  static Future<Map<String, dynamic>> _createTimesheetEntryFromShift(
      TeachingShift shift, LocationData location,
      {required bool isClockIn}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // The logic to close incomplete entries has been removed to allow for multiple,
      // distinct timesheet entries per shift, each completed upon its own clock-out.

      final now = DateTime.now();
      final date = DateFormat('MMM dd, yyyy').format(now);
      final time = DateFormat('h:mm a').format(now);

      // Create timesheet entry data
      final entryData = {
        'teacher_id': user.uid,
        'teacher_email': user.email,
        'shift_id': shift.id, // Link to the shift
        'date': date,
        'student_name': shift.studentNames.isNotEmpty
            ? shift.studentNames.join(', ')
            : 'No students assigned',
        'start_time': time,
        'end_time': '', // Will be filled on clock-out
        'total_hours': '00:00', // Will be calculated on clock-out
        'description':
            'Teaching session: ${shift.subjectDisplayName} - ${shift.displayName}',
        'status': 'draft',
        'source': 'shift_clock_in',
        'completion_method': 'pending', // Will be updated on clock-out
        // Location data
        'clock_in_latitude': location.latitude,
        'clock_in_longitude': location.longitude,
        'clock_in_address': location.address,
        'clock_in_neighborhood': location.neighborhood,
        'clock_out_latitude': null,
        'clock_out_longitude': null,
        'clock_out_address': null,
        'clock_out_neighborhood': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Save to Firebase
      final docRef =
          await _firestore.collection('timesheet_entries').add(entryData);

      print(
          'ShiftTimesheetService: Created timesheet entry ${docRef.id} for shift ${shift.id}');

      return {
        'documentId': docRef.id,
        ...entryData,
      };
    } catch (e) {
      print('Error creating timesheet entry: $e');
      throw e;
    }
  }

  /// Update timesheet entry with clock-out data
  static Future<Map<String, dynamic>> _updateTimesheetEntryWithClockOut(
      TeachingShift shift, LocationData location) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Find the MOST RECENT timesheet entry for this shift that hasn't been clocked out
      final querySnapshot = await _firestore
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: shift.id)
          .where('teacher_id', isEqualTo: user.uid)
          .where('end_time', isEqualTo: '') // Not yet clocked out
          .orderBy('created_at', descending: true) // Get the most recent entry
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('No timesheet entry found for this shift');
      }

      final docRef = querySnapshot.docs.first.reference;
      final docData = querySnapshot.docs.first.data();

      final now = DateTime.now();
      final endTime = DateFormat('h:mm a').format(now);

      // Calculate total hours
      final startTime = docData['start_time'] as String;
      final startDateTime = DateFormat('h:mm a').parse(startTime);
      final endDateTime = DateFormat('h:mm a').parse(endTime);
      final duration = endDateTime.difference(startDateTime);
      final totalHours =
          '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}';

      // Update the timesheet entry
      await docRef.update({
        'end_time': endTime,
        'total_hours': totalHours,
        'clock_out_latitude': location.latitude,
        'clock_out_longitude': location.longitude,
        'clock_out_address': location.address,
        'clock_out_neighborhood': location.neighborhood,
        'completion_method': 'manual', // Mark as manual clock-out
        'updated_at': FieldValue.serverTimestamp(),
      });

      print(
          'ShiftTimesheetService: Updated timesheet entry ${docRef.id} with clock-out data');

      return {
        'documentId': docRef.id,
        ...docData,
        'end_time': endTime,
        'total_hours': totalHours,
        'clock_out_latitude': location.latitude,
        'clock_out_longitude': location.longitude,
        'clock_out_address': location.address,
        'clock_out_neighborhood': location.neighborhood,
      };
    } catch (e) {
      print('Error updating timesheet entry: $e');
      throw e;
    }
  }

  /// Update timesheet entry with auto clock-out data (uses shift end time)
  static Future<Map<String, dynamic>> _updateTimesheetEntryWithAutoClockOut(
      TeachingShift shift, LocationData location) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Find the MOST RECENT timesheet entry for this shift that hasn't been clocked out
      final querySnapshot = await _firestore
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: shift.id)
          .where('teacher_id', isEqualTo: user.uid)
          .where('end_time', isEqualTo: '') // Not yet clocked out
          .orderBy('created_at', descending: true) // Get the most recent entry
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('No timesheet entry found for this shift');
      }

      final docRef = querySnapshot.docs.first.reference;
      final docData = querySnapshot.docs.first.data();

      // Use shift end time + 15 minutes for auto clock-out
      final autoClockOutTime = shift.clockOutDeadline;
      final endTime = DateFormat('h:mm a').format(autoClockOutTime);

      // Calculate total hours based on actual clock-in to auto clock-out time
      final startTime = docData['start_time'] as String;
      final startDateTime = DateFormat('h:mm a').parse(startTime);
      final endDateTime = DateFormat('h:mm a').parse(endTime);
      final duration = endDateTime.difference(startDateTime);
      final totalHours =
          '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}';

      // Update the timesheet entry
      await docRef.update({
        'end_time': endTime,
        'total_hours': totalHours,
        'clock_out_latitude': location.latitude,
        'clock_out_longitude': location.longitude,
        'clock_out_address': location.address,
        'clock_out_neighborhood': location.neighborhood,
        'completion_method': 'auto_logout', // Mark as auto-logout
        'auto_logout_time': Timestamp.fromDate(autoClockOutTime),
        'updated_at': FieldValue.serverTimestamp(),
      });

      print(
          'ShiftTimesheetService: Updated timesheet entry ${docRef.id} with auto clock-out data');

      return {
        'documentId': docRef.id,
        ...docData,
        'end_time': endTime,
        'total_hours': totalHours,
        'clock_out_latitude': location.latitude,
        'clock_out_longitude': location.longitude,
        'clock_out_address': location.address,
        'clock_out_neighborhood': location.neighborhood,
        'completion_method': 'auto_logout',
        'auto_logout_time': autoClockOutTime,
      };
    } catch (e) {
      print('Error updating timesheet entry with auto clock-out: $e');
      throw e;
    }
  }

  /// Get active shift for teacher (if any) - only if currently has an open timesheet
  static Future<TeachingShift?> getActiveShift(String teacherId) async {
    try {
      // Instead of checking shift.isClockedIn, check for open timesheet entries
      final openTimesheetQuery = await _firestore
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: teacherId)
          .where('end_time', isEqualTo: '') // Open timesheet entry
          .limit(1)
          .get();

      if (openTimesheetQuery.docs.isEmpty) {
        print('ShiftTimesheetService: No open timesheet entries found');
        return null;
      }

      // Get the shift ID from the open timesheet entry
      final openEntry = openTimesheetQuery.docs.first.data();
      final shiftId = openEntry['shift_id'] as String?;

      if (shiftId == null) {
        print(
            'ShiftTimesheetService: No shift_id found in open timesheet entry');
        return null;
      }

      // Get the actual shift
      final shiftDoc =
          await _firestore.collection('teaching_shifts').doc(shiftId).get();
      if (!shiftDoc.exists) {
        print('ShiftTimesheetService: Shift $shiftId not found');
        return null;
      }

      final shift = TeachingShift.fromFirestore(shiftDoc);
      print(
          'ShiftTimesheetService: Found active shift with open timesheet: ${shift.id}');
      return shift;
    } catch (e) {
      print('Error getting active shift: $e');
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
      print('Error getting timesheet entry for shift: $e');
      return null;
    }
  }
}
