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
      final nowUtc = now.toUtc();
      print('ShiftTimesheetService: Current local time: $now');
      print('ShiftTimesheetService: Current UTC time: $nowUtc');
      print('ShiftTimesheetService: Current timezone: ${now.timeZoneName}');
      print('ShiftTimesheetService: Current UTC offset: ${now.timeZoneOffset}');

      // First check if teacher has an active shift (already clocked in)
      final activeShift = await getActiveShift(teacherId);
      if (activeShift != null) {
        print(
            'ShiftTimesheetService: Found active shift ${activeShift.id} - ${activeShift.displayName}');
        return {
          'shift': activeShift,
          'canClockIn': false,
          'canClockOut': true,
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

        // CONSISTENT TIME HANDLING - Always use UTC for comparisons
        final shiftStartUtc = shift.shiftStart.toUtc();
        final shiftEndUtc = shift.shiftEnd.toUtc();
        // NO GRACE PERIOD - Clock-in only during exact shift time
        final clockInWindowUtc = shiftStartUtc;
        final clockOutWindowUtc = shiftEndUtc;

        print('ShiftTimesheetService: Shift ${shift.id}:');
        print('  - Display Name: ${shift.displayName}');
        print('  - Status: ${shift.status.name}');
        print('  - Shift Start (UTC): $shiftStartUtc');
        print('  - Shift End (UTC): $shiftEndUtc');
        print(
            '  - Clock-in Window (UTC): $clockInWindowUtc to $clockOutWindowUtc');
        print(
            '  - Current UTC time in window: ${nowUtc.isAfter(clockInWindowUtc) && nowUtc.isBefore(clockOutWindowUtc)}');

        // Allow clock-in only during exact shift time (no grace period)
        if (nowUtc.isAfter(clockInWindowUtc) &&
            nowUtc.isBefore(clockOutWindowUtc)) {
          print(
              'ShiftTimesheetService: ✅ VALID SHIFT FOUND: ${shift.id} - ${shift.displayName}');
          validShifts.add(shift);
        } else {
          print(
              'ShiftTimesheetService: ❌ Shift not valid for clock-in - outside time window');
        }
      }

      if (validShifts.isNotEmpty) {
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
      print('ShiftTimesheetService: Teacher ID: $teacherId');
      print('ShiftTimesheetService: Location: ${location.neighborhood}');

      // Validate the shift timing and eligibility
      print('ShiftTimesheetService: Validating shift for clock-in...');
      final shift = await _validateShiftForClockIn(teacherId, shiftId);
      if (shift == null) {
        print(
            'ShiftTimesheetService: ❌ Shift validation failed - no valid shift found');
        return {
          'success': false,
          'message': 'Shift not found or not valid for clock-in right now',
          'shift': null,
        };
      }

      print('ShiftTimesheetService: ✅ Shift validation passed');
      print('ShiftTimesheetService: Shift name: ${shift.displayName}');
      print('ShiftTimesheetService: Shift status: ${shift.status.name}');

      // Check if already clocked in (check for open timesheet)
      final existingOpenTimesheet = await _firestore
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: shiftId)
          .where('teacher_id', isEqualTo: teacherId)
          .where('end_time', isEqualTo: '')
          .limit(1)
          .get();

      if (existingOpenTimesheet.docs.isNotEmpty) {
        print(
            'ShiftTimesheetService: ❌ Already has open timesheet for this shift');
        return {
          'success': false,
          'message': 'You are already clocked in to this shift',
          'shift': shift,
        };
      }

      print('ShiftTimesheetService: ✅ Location validated');

      // Create timesheet entry FIRST (to ensure we have a record)
      print('ShiftTimesheetService: Creating timesheet entry...');
      final timesheetEntry = await _createTimesheetEntryFromShift(
          shift, location,
          isClockIn: true);

      // Then update shift status (if this fails, we still have the timesheet)
      print('ShiftTimesheetService: Updating shift status...');
      try {
        final clockInSuccess = await ShiftService.clockIn(teacherId, shiftId);
        if (!clockInSuccess) {
          print(
              'ShiftTimesheetService: ⚠️ ShiftService.clockIn returned false, but continuing with timesheet');
          // Don't fail entirely - we have the timesheet entry
        }
      } catch (e) {
        print(
            'ShiftTimesheetService: ⚠️ ShiftService.clockIn error: $e, but continuing');
        // Continue anyway - the timesheet is what matters
      }

      print(
          'ShiftTimesheetService: ✅ Clock-in successful, timesheet entry created');

      return {
        'success': true,
        'message': 'Successfully clocked in to ${shift.displayName}',
        'shift': shift,
        'timesheetEntry': timesheetEntry,
        'clockInTime': DateTime.now(),
      };
    } catch (e) {
      print('ShiftTimesheetService: ❌ Exception during shift clock-in: $e');
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

      // Check for an open timesheet entry
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
          'message': 'No active clock-in found for this shift.',
          'shift': null,
        };
      }

      // Update timesheet entry with clock-out data FIRST
      final timesheetEntry =
          await _updateTimesheetEntryWithClockOut(shift, location);

      // Then update shift status (if this fails, we still have the timesheet)
      try {
        final clockOutSuccess = await ShiftService.clockOut(teacherId, shiftId);
        if (!clockOutSuccess) {
          print(
              'ShiftTimesheetService: ⚠️ ShiftService.clockOut returned false, but continuing');
        }
      } catch (e) {
        print(
            'ShiftTimesheetService: ⚠️ ShiftService.clockOut error: $e, but continuing');
      }

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

      // Check for an open timesheet entry
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
        print(
            'ShiftTimesheetService: ⚠️ ShiftService.clockOut error during auto-logout: $e');
      }

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

  /// Validate shift for clock-in (single clock-in per shift)
  static Future<TeachingShift?> _validateShiftForClockIn(
      String teacherId, String shiftId) async {
    try {
      print('ShiftTimesheetService: _validateShiftForClockIn starting...');
      print(
          'ShiftTimesheetService: Looking for shift $shiftId for teacher $teacherId');

      final doc =
          await _firestore.collection('teaching_shifts').doc(shiftId).get();
      if (!doc.exists) {
        print('ShiftTimesheetService: ❌ Shift document does not exist');
        return null;
      }

      print('ShiftTimesheetService: ✅ Shift document found');
      final shift = TeachingShift.fromFirestore(doc);

      // Check if it's the right teacher
      if (shift.teacherId != teacherId) {
        print(
            'ShiftTimesheetService: ❌ Teacher ID mismatch - expected ${shift.teacherId}, got $teacherId');
        return null;
      }

      print('ShiftTimesheetService: ✅ Teacher ID matches');

      // CONSISTENT UTC TIME HANDLING
      final nowUtc = DateTime.now().toUtc();
      final shiftStartUtc = shift.shiftStart.toUtc();
      final shiftEndUtc = shift.shiftEnd.toUtc();
      // NO GRACE PERIOD - Clock-in only during exact shift time
      final clockInWindowUtc = shiftStartUtc;
      final clockOutWindowUtc = shiftEndUtc;

      print('ShiftTimesheetService: Clock-in validation:');
      print('  - Current UTC time: $nowUtc');
      print('  - Shift Start (UTC): $shiftStartUtc');
      print('  - Shift End (UTC): $shiftEndUtc');
      print(
          '  - Clock-in Window (UTC): $clockInWindowUtc to $clockOutWindowUtc');
      print('  - Shift Status: ${shift.status.name}');
      print(
          '  - Time check: nowUtc.isAfter(clockInWindowUtc) = ${nowUtc.isAfter(clockInWindowUtc)}');
      print(
          '  - Time check: nowUtc.isBefore(clockOutWindowUtc) = ${nowUtc.isBefore(clockOutWindowUtc)}');

      // Allow clock-in only during exact shift time (no grace period)
      if (nowUtc.isAfter(clockInWindowUtc) &&
          nowUtc.isBefore(clockOutWindowUtc)) {
        print(
            'ShiftTimesheetService: ✅ Shift validated for clock-in - within time window');
        return shift;
      }

      print('ShiftTimesheetService: ❌ Shift not within valid time window');
      print(
          'ShiftTimesheetService: Current UTC $nowUtc is not between $clockInWindowUtc and $clockOutWindowUtc');
      return null;
    } catch (e) {
      print('ShiftTimesheetService: ❌ Exception in validating shift: $e');
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
        'hourly_rate': shift.hourlyRate,  // Add hourly rate from shift
        'description':
            'Teaching session: ${shift.subjectDisplayName} - ${shift.displayName}',
        'status': 'draft',
        'source': 'shift_clock_in',
        'completion_method': 'pending',
        // Store the actual clock-in timestamp for persistence
        'clock_in_timestamp': Timestamp.fromDate(now),
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
      rethrow;
    }
  }

  /// Update timesheet entry with clock-out data
  static Future<Map<String, dynamic>> _updateTimesheetEntryWithClockOut(
      TeachingShift shift, LocationData location) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Find the most recent open timesheet entry
      final querySnapshot = await _firestore
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: shift.id)
          .where('teacher_id', isEqualTo: user.uid)
          .where('end_time', isEqualTo: '')
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('No timesheet entry found for this shift');
      }

      final docRef = querySnapshot.docs.first.reference;
      final docData = querySnapshot.docs.first.data();

      final now = DateTime.now();
      final endTime = DateFormat('h:mm a').format(now);

      // Calculate total hours using the stored clock-in timestamp
      DateTime startDateTime;
      if (docData['clock_in_timestamp'] != null) {
        startDateTime = (docData['clock_in_timestamp'] as Timestamp).toDate();
      } else {
        // Fallback to parsing the time string
        final startTime = docData['start_time'] as String;
        startDateTime = DateFormat('h:mm a').parse(startTime);
        // Adjust to today's date
        startDateTime = DateTime(now.year, now.month, now.day,
            startDateTime.hour, startDateTime.minute);
      }

      final duration = now.difference(startDateTime);
      final totalHours =
          '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}';

      // Update the timesheet entry
      await docRef.update({
        'end_time': endTime,
        'total_hours': totalHours,
        'clock_out_timestamp': Timestamp.fromDate(now),
        'clock_out_latitude': location.latitude,
        'clock_out_longitude': location.longitude,
        'clock_out_address': location.address,
        'clock_out_neighborhood': location.neighborhood,
        'completion_method': 'manual',
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
      rethrow;
    }
  }

  /// Update timesheet entry with auto clock-out data
  static Future<Map<String, dynamic>> _updateTimesheetEntryWithAutoClockOut(
      TeachingShift shift, LocationData location) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Find the most recent open timesheet entry
      final querySnapshot = await _firestore
          .collection('timesheet_entries')
          .where('shift_id', isEqualTo: shift.id)
          .where('teacher_id', isEqualTo: user.uid)
          .where('end_time', isEqualTo: '')
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('No timesheet entry found for this shift');
      }

      final docRef = querySnapshot.docs.first.reference;
      final docData = querySnapshot.docs.first.data();

      // Use shift end time + 15 minutes for auto clock-out
      final autoClockOutTimeUtc = shift.clockOutDeadline;
      final autoClockOutTimeLocal = autoClockOutTimeUtc.toLocal();
      final endTime = DateFormat('h:mm a').format(autoClockOutTimeLocal);

      // Calculate total hours using stored clock-in timestamp
      DateTime startDateTime;
      if (docData['clock_in_timestamp'] != null) {
        startDateTime = (docData['clock_in_timestamp'] as Timestamp).toDate();
      } else {
        // Fallback to parsing the time string
        final startTime = docData['start_time'] as String;
        startDateTime = DateFormat('h:mm a').parse(startTime);
      }

      final duration = autoClockOutTimeLocal.difference(startDateTime);
      final totalHours =
          '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}';

      // Update the timesheet entry
      await docRef.update({
        'end_time': endTime,
        'total_hours': totalHours,
        'clock_out_timestamp': Timestamp.fromDate(autoClockOutTimeUtc),
        'clock_out_latitude': location.latitude,
        'clock_out_longitude': location.longitude,
        'clock_out_address': location.address,
        'clock_out_neighborhood': location.neighborhood,
        'completion_method': 'auto_logout',
        'auto_logout_time': Timestamp.fromDate(autoClockOutTimeUtc),
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
        'auto_logout_time': autoClockOutTimeUtc,
      };
    } catch (e) {
      print('Error updating timesheet entry with auto clock-out: $e');
      rethrow;
    }
  }

  /// Get active shift for teacher (if any)
  static Future<TeachingShift?> getActiveShift(String teacherId) async {
    try {
      // Check for open timesheet entries
      final openTimesheetQuery = await _firestore
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: teacherId)
          .where('end_time', isEqualTo: '')
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
      print('Error getting open session: $e');
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
