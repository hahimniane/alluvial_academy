import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/teaching_shift.dart';
import '../models/employee_model.dart';
import '../models/enhanced_recurrence.dart';
import 'wage_management_service.dart';
import '../enums/shift_enums.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class ShiftService {
  /// Service responsible for managing teaching shifts, including creation,
  /// modification, deletion, and status updates (clock-in/out).
  /// It interacts with Firestore 'teaching_shifts' collection and Cloud Functions.
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static FirebaseFunctions get _functions => FirebaseFunctions.instance;

  // Collection reference
  static CollectionReference get _shiftsCollection =>
      _firestore.collection('teaching_shifts');

  /// Check if a shift overlaps with any existing shift for the same teacher.
  ///
  /// This method prevents double-booking by:
  /// 1. Defining a search window (start of day to end of day + buffer).
  /// 2. Querying Firestore for shifts within that window.
  /// 3. Iterating through results to check for time overlaps.
  ///
  /// Returns `true` if a conflict exists, `false` otherwise.
  static Future<bool> hasConflictingShift({
    required String teacherId,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    String? excludeShiftId, // For updates, exclude the current shift
  }) async {
    try {
      AppLogger.debug('ShiftService: Checking for overlapping shifts...');
      AppLogger.debug('  Teacher ID: $teacherId');
      AppLogger.debug('  New Shift: $shiftStart to $shiftEnd');

      // Normalize day boundaries in the same timezone context as the shift.
      // When shifts are stored in UTC we keep the boundaries in UTC as well.
      final isUtc = shiftStart.isUtc;
      final startOfDay = isUtc
          ? DateTime.utc(shiftStart.year, shiftStart.month, shiftStart.day)
          : DateTime(shiftStart.year, shiftStart.month, shiftStart.day);
      final endOfDay = isUtc
          ? DateTime.utc(shiftStart.year, shiftStart.month, shiftStart.day)
              .add(const Duration(days: 1))
          : startOfDay.add(const Duration(days: 1));

      // Expand the search window by one day on each side to safely capture
      // cross-midnight shifts (e.g. 11:30 PM - 1:00 AM).
      final rangeStart = startOfDay.subtract(const Duration(days: 1));
      final rangeEnd = endOfDay.add(const Duration(days: 1));

      AppLogger.debug('  Query window: $rangeStart → $rangeEnd');

      List<QueryDocumentSnapshot> docs;
      try {
        final snapshot = await _shiftsCollection
            .where('teacher_id', isEqualTo: teacherId)
            .where('shift_start',
                isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
            .where('shift_start', isLessThan: Timestamp.fromDate(rangeEnd))
            .get();
        docs = snapshot.docs;
      } on FirebaseException catch (firestoreError) {
        final missingIndex = firestoreError.code == 'failed-precondition' &&
            (firestoreError.message?.contains('index') ?? false);
        AppLogger.error(
            'ShiftService: Firestore query failed (${firestoreError.code}): ${firestoreError.message}');

        if (missingIndex) {
          // If the composite index (teacher_id + shift_start) is missing, fall
          // back to scanning all shifts for the teacher so the conflict check
          // still runs (at the cost of extra reads).
          AppLogger.debug(
              'ShiftService: Missing composite index for teacher_id + shift_start. Falling back to full teacher scan.');
          final fallbackSnapshot = await _shiftsCollection
              .where('teacher_id', isEqualTo: teacherId)
              .get();
          docs = fallbackSnapshot.docs;
        } else {
          rethrow;
        }
      }

      if (docs.isEmpty) {
        AppLogger.debug('ShiftService: ✅ No shifts found in query window');
        return false;
      }

      AppLogger.debug(
          'ShiftService: Found ${docs.length} potential existing shifts for overlap analysis');

      // Check each shift for overlap
      for (var doc in docs) {
        // Skip if this is the shift we're updating
        if (excludeShiftId != null && doc.id == excludeShiftId) {
          continue;
        }

        final existingShift = TeachingShift.fromFirestore(doc);

        // Check if shifts overlap
        // Two shifts overlap if:
        // - New shift starts before existing ends AND
        // - New shift ends after existing starts
        final overlaps = shiftStart.isBefore(existingShift.shiftEnd) &&
            shiftEnd.isAfter(existingShift.shiftStart);

        if (overlaps) {
          AppLogger.debug('ShiftService: ❌ OVERLAP DETECTED!');
          AppLogger.debug('  Existing shift: ${existingShift.displayName}');
          AppLogger.debug(
              '  Existing time: ${existingShift.shiftStart} to ${existingShift.shiftEnd}');
          AppLogger.debug('  New shift time: $shiftStart to $shiftEnd');
          AppLogger.error('  Status: ${existingShift.status.name}');
          return true;
        }
      }

      AppLogger.error('ShiftService: ✅ No overlapping shifts found');
      return false;
    } catch (e) {
      AppLogger.error('ShiftService: Error checking for conflicts: $e');
      // Propagate the error so shift creation is blocked until validation succeeds.
      rethrow;
    }
  }

  static Future<void> _scheduleShiftLifecycleTasks(TeachingShift shift,
      {bool cancel = false}) async {
    try {
      final callable = _functions.httpsCallable('scheduleShiftLifecycle');
      final payload = {
        'shiftId': shift.id,
        'teacherId': shift.teacherId,
        'shiftStart': shift.shiftStart.toUtc().toIso8601String(),
        'shiftEnd': shift.shiftEnd.toUtc().toIso8601String(),
        'status': shift.status.name,
        'cancel': cancel,
        'adminTimezone': shift.adminTimezone,
        'teacherTimezone': shift.teacherTimezone,
      };
      AppLogger.debug(
          'ShiftService: Scheduling lifecycle tasks for shift ${shift.id} (cancel=$cancel)');
      await callable.call(payload);
      AppLogger.error('ShiftService: Lifecycle tasks scheduled successfully');
    } on FirebaseFunctionsException catch (e) {
      AppLogger.error(
          'ShiftService: Cloud Functions error while scheduling lifecycle tasks: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      AppLogger.error(
          'ShiftService: Unexpected error while scheduling lifecycle tasks: $e');
      rethrow;
    }
  }

  /// Create a new teaching shift.
  ///
  /// Steps:
  /// 1. Validates that the user is authenticated.
  /// 2. Checks for conflicting shifts using [hasConflictingShift].
  /// 3. Fetches teacher and student details (names, rates, etc.).
  /// 4. Generates an auto-name for the shift.
  /// 5. Creates the shift document in Firestore.
  /// 6. Schedules lifecycle tasks (e.g., auto-clock-out) via Cloud Functions.
  /// 7. Creates recurring shifts if a recurrence pattern is specified.
  static Future<String> createShift({
    required String teacherId,
    required List<String> studentIds,
    List<String>? studentNames,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required String adminTimezone,
    required IslamicSubject subject,
    String? subjectId,
    String? subjectDisplayName,
    String? customName,
    String? notes,
    RecurrencePattern recurrence = RecurrencePattern.none,
    EnhancedRecurrence? enhancedRecurrence,
    DateTime? recurrenceEndDate,
    Map<String, dynamic>? recurrenceSettings,
    DateTime? originalLocalStart,
    DateTime? originalLocalEnd,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Check for conflicting shifts at the exact same time
      final hasConflict = await hasConflictingShift(
        teacherId: teacherId,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
      );

      if (hasConflict) {
        throw Exception(
            'This shift overlaps with an existing shift for this teacher. '
            'Please choose a different time that doesn\'t overlap with existing shifts.');
      }

      // Get teacher information
      final teacherDoc =
          await _firestore.collection('users').doc(teacherId).get();
      if (!teacherDoc.exists) throw Exception('Teacher not found');

      final teacherData = teacherDoc.data() as Map<String, dynamic>;
      final teacherName =
          '${teacherData['first_name']} ${teacherData['last_name']}';
      final teacherTimezone = teacherData['timezone'] ?? 'UTC';
      // Use effective hourly rate considering overrides
      final hourlyRate =
          await WageManagementService.getEffectiveWageForUser(teacherId);

      // Get student information
      final finalStudentNames = <String>[];
      if (studentNames != null && studentNames.isNotEmpty) {
        // Use provided student names if available
        finalStudentNames.addAll(studentNames);
      } else {
        // Fall back to querying the database for student names
        for (String studentId in studentIds) {
          final studentDoc =
              await _firestore.collection('users').doc(studentId).get();
          if (studentDoc.exists) {
            final studentData = studentDoc.data() as Map<String, dynamic>;
            finalStudentNames.add(
                '${studentData['first_name']} ${studentData['last_name']}');
          }
        }
      }

      // Generate auto name
      final autoGeneratedName = TeachingShift.generateAutoName(
        teacherName: teacherName,
        subject: subject,
        studentNames: finalStudentNames,
      );

      // Create shift document
      final shiftDoc = _shiftsCollection.doc();
      final shift = TeachingShift(
        id: shiftDoc.id,
        teacherId: teacherId,
        teacherName: teacherName,
        studentIds: studentIds,
        studentNames: finalStudentNames,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        adminTimezone: adminTimezone,
        teacherTimezone: teacherTimezone,
        subject: subject,
        subjectId: subjectId,
        subjectDisplayName: subjectDisplayName,
        autoGeneratedName: autoGeneratedName,
        customName: customName,
        hourlyRate: hourlyRate,
        status: ShiftStatus.scheduled,
        createdByAdminId: currentUser.uid,
        createdAt: DateTime.now(),
        recurrence: recurrence,
        enhancedRecurrence: enhancedRecurrence ?? const EnhancedRecurrence(),
        recurrenceEndDate: recurrenceEndDate,
        recurrenceSettings: recurrenceSettings,
        notes: notes,
      );

      try {
        await shiftDoc.set(shift.toFirestore());
        await _scheduleShiftLifecycleTasks(shift);
      } catch (scheduleError) {
        // Roll back the created shift if scheduling fails so we don't leave
        // orphaned records without lifecycle automation.
        try {
          await shiftDoc.delete();
        } catch (cleanupError) {
          AppLogger.error(
              'ShiftService: Failed to delete shift after scheduling error: $cleanupError');
        }
        rethrow;
      }

      // Create recurring shifts if specified
      final effectiveRecurrence =
          enhancedRecurrence ?? const EnhancedRecurrence();
      if (recurrence != RecurrencePattern.none ||
          effectiveRecurrence.type != EnhancedRecurrenceType.none) {
        // Use provided end date or default to 1 year from now if not specified
        final endDate = effectiveRecurrence.endDate ??
            recurrenceEndDate ??
            DateTime.now().add(const Duration(days: 365));
        await _createRecurringShifts(
            shift, endDate, originalLocalStart, originalLocalEnd);
      }

      AppLogger.error('Shift created successfully: ${shift.displayName}');
      return shiftDoc.id;
    } catch (e) {
      AppLogger.error('Error creating shift: $e');
      throw Exception('Failed to create shift: $e');
    }
  }

  /// Create recurring shifts based on enhanced recurrence pattern.
  ///
  /// This handles generating future shift instances based on:
  /// - [EnhancedRecurrence]: Specific days of the week, end date, exclusions.
  /// - [RecurrencePattern]: Legacy simple patterns (daily, weekly, monthly).
  ///
  /// It checks for conflicts for each occurrence and skips if a conflict exists.
  static Future<void> _createRecurringShifts(
    TeachingShift baseShift,
    DateTime endDate,
    DateTime? originalLocalStart,
    DateTime? originalLocalEnd,
  ) async {
    try {
      final List<TeachingShift> recurringShifts = [];
      final enhancedRecurrence = baseShift.enhancedRecurrence;

      // Use enhanced recurrence if available, otherwise fall back to old pattern
      if (enhancedRecurrence.type != EnhancedRecurrenceType.none) {
        AppLogger.debug(
            'Creating recurring shifts for base shift: ${baseShift.shiftStart} to ${baseShift.shiftEnd}');
        AppLogger.debug(
            'Selected weekdays: ${enhancedRecurrence.selectedWeekdays.map((d) => d.name).join(', ')}');

        // Generate occurrences using enhanced recurrence
        final occurrences = enhancedRecurrence.generateOccurrences(
          baseShift.shiftStart
              .add(const Duration(days: 1)), // Start from next day
          100, // Max occurrences
        );

        AppLogger.debug('Generated ${occurrences.length} occurrence dates');

        for (final occurrence in occurrences) {
          if (occurrence.isAfter(endDate)) break;

          // Skip if date is excluded
          if (enhancedRecurrence.isDateExcluded(occurrence)) {
            continue;
          }

          // Create shift start and end times for this occurrence
          // Use original local times if available, otherwise fall back to base shift times
          final localStartTime = originalLocalStart ?? baseShift.shiftStart;
          final localEndTime = originalLocalEnd ?? baseShift.shiftEnd;

          final shiftStart = DateTime(
            occurrence.year,
            occurrence.month,
            occurrence.day,
            localStartTime.hour,
            localStartTime.minute,
            localStartTime.second,
            localStartTime.millisecond,
          );
          final shiftEnd = DateTime(
            occurrence.year,
            occurrence.month,
            occurrence.day,
            localEndTime.hour,
            localEndTime.minute,
            localEndTime.second,
            localEndTime.millisecond,
          );

          // Check if a shift already exists at this exact time
          final hasConflict = await hasConflictingShift(
            teacherId: baseShift.teacherId,
            shiftStart: shiftStart,
            shiftEnd: shiftEnd,
          );

          if (hasConflict) {
            AppLogger.debug(
                'Skipping recurring shift - conflict detected at $shiftStart');
            continue; // Skip this occurrence
          }

          // Debug logging to track time preservation
          AppLogger.debug(
              'Creating recurring shift: ${occurrence.toString().substring(0, 10)} ${shiftStart.hour}:${shiftStart.minute.toString().padLeft(2, '0')} - ${shiftEnd.hour}:${shiftEnd.minute.toString().padLeft(2, '0')}');

          // Create recurring shift
          final recurringShift = baseShift.copyWith(
            id: _shiftsCollection.doc().id,
            shiftStart: shiftStart,
            shiftEnd: shiftEnd,
            createdAt: DateTime.now(),
          );

          recurringShifts.add(recurringShift);
        }
      } else {
        // Fall back to old recurrence pattern logic
        final localStartTime = originalLocalStart ?? baseShift.shiftStart;
        final localEndTime = originalLocalEnd ?? baseShift.shiftEnd;
        DateTime currentDate = baseShift.shiftStart;
        int maxRecurringShifts = 50;
        int createdCount = 0;

        while (currentDate.isBefore(endDate) &&
            createdCount < maxRecurringShifts) {
          DateTime nextDate;

          switch (baseShift.recurrence) {
            case RecurrencePattern.daily:
              nextDate = currentDate.add(const Duration(days: 1));
              break;
            case RecurrencePattern.weekly:
              nextDate = currentDate.add(const Duration(days: 7));
              break;
            case RecurrencePattern.monthly:
              nextDate = DateTime(
                currentDate.year,
                currentDate.month + 1,
                currentDate.day,
                currentDate.hour,
                currentDate.minute,
              );
              break;
            default:
              return;
          }

          if (nextDate.isAfter(endDate)) break;

          // Use original local times for consistent timing
          final nextShiftStart = DateTime(
            nextDate.year,
            nextDate.month,
            nextDate.day,
            localStartTime.hour,
            localStartTime.minute,
            localStartTime.second,
            localStartTime.millisecond,
          );
          final nextShiftEnd = DateTime(
            nextDate.year,
            nextDate.month,
            nextDate.day,
            localEndTime.hour,
            localEndTime.minute,
            localEndTime.second,
            localEndTime.millisecond,
          );

          // Check for conflicts before creating
          final hasConflict = await hasConflictingShift(
            teacherId: baseShift.teacherId,
            shiftStart: nextShiftStart,
            shiftEnd: nextShiftEnd,
          );

          if (!hasConflict) {
            final recurringShift = baseShift.copyWith(
              id: _shiftsCollection.doc().id,
              shiftStart: nextShiftStart,
              shiftEnd: nextShiftEnd,
              createdAt: DateTime.now(),
            );

            recurringShifts.add(recurringShift);
          } else {
            AppLogger.debug(
                'Skipping recurring shift - conflict detected at $nextShiftStart');
          }

          currentDate = nextDate;
          createdCount++;
        }
      }

      // Batch write all recurring shifts
      if (recurringShifts.isNotEmpty) {
        final batch = _firestore.batch();
        for (final shift in recurringShifts) {
          final docRef = _shiftsCollection.doc(shift.id);
          batch.set(docRef, shift.toFirestore());
        }
        await batch.commit();
        AppLogger.debug(
            'ShiftService: Scheduling lifecycle tasks for ${recurringShifts.length} recurring shifts');
        final schedulingFutures = recurringShifts
            .map((shift) => _scheduleShiftLifecycleTasks(shift))
            .toList();
        await Future.wait(schedulingFutures);
        AppLogger.error(
            'Created ${recurringShifts.length} recurring shifts using ${enhancedRecurrence.type != EnhancedRecurrenceType.none ? "enhanced" : "legacy"} recurrence');
      }
    } catch (e) {
      AppLogger.error('Error creating recurring shifts: $e');
    }
  }

  /// Get shifts for a specific teacher
  static Stream<List<TeachingShift>> getTeacherShifts(String teacherId) {
    return _shiftsCollection
        .where('teacher_id', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
      final shifts =
          snapshot.docs.map((doc) => TeachingShift.fromFirestore(doc)).toList();

      // Sort by shift_start since we can't use orderBy in query without index
      shifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));

      return shifts;
    });
  }

  /// Get all shifts (admin view)
  static Stream<List<TeachingShift>> getAllShifts() {
    return _shiftsCollection.snapshots().map((snapshot) {
      final shifts =
          snapshot.docs.map((doc) => TeachingShift.fromFirestore(doc)).toList();

      // Sort by shift_start for consistent ordering
      shifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));

      return shifts;
    });
  }

  /// Get shifts for today
  static Future<List<TeachingShift>> getTodayShifts(String teacherId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _shiftsCollection
          .where('teacher_id', isEqualTo: teacherId)
          .where('shift_start',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('shift_start', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      return snapshot.docs
          .map((doc) => TeachingShift.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting today\'s shifts: $e');
      return [];
    }
  }

  /// Get current active shift for teacher
  static Future<TeachingShift?> getCurrentActiveShift(String teacherId) async {
    try {
      final snapshot = await _shiftsCollection
          .where('teacher_id', isEqualTo: teacherId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final shift = TeachingShift.fromFirestore(snapshot.docs.first);

      // Verify shift is actually current
      if (shift.isCurrentlyActive || shift.canClockIn) {
        return shift;
      }

      return null;
    } catch (e) {
      AppLogger.error('Error getting current active shift: $e');
      return null;
    }
  }

  /// Update shift status
  static Future<void> updateShiftStatus(
      String shiftId, ShiftStatus status) async {
    try {
      // First, update the Firestore status
      await _shiftsCollection.doc(shiftId).update({
        'status': status.name,
        'last_modified': Timestamp.fromDate(DateTime.now()),
      });
      AppLogger.info('Shift status updated in Firestore to: ${status.name}');

      // Then, attempt to reschedule lifecycle tasks (non-blocking)
      try {
        final snapshot = await _shiftsCollection.doc(shiftId).get();
        if (snapshot.exists) {
          final shift = TeachingShift.fromFirestore(snapshot);
          final shouldCancel = status == ShiftStatus.cancelled;
          await _scheduleShiftLifecycleTasks(shift, cancel: shouldCancel);
          AppLogger.info(
              'Lifecycle tasks rescheduled successfully for shift $shiftId');
        }
      } catch (scheduleError) {
        // Log the error but don't fail the entire operation
        // The status update was successful, tasks scheduling is optional
        AppLogger.warning(
            'Warning: Failed to reschedule lifecycle tasks for shift $shiftId: $scheduleError. '
            'Status update was successful.');
      }
    } catch (e) {
      AppLogger.error('Error updating shift status: $e');
      throw Exception('Failed to update shift status');
    }
  }

  /// Delete a shift
  static Future<void> deleteShift(String shiftId) async {
    try {
      TeachingShift? existingShift;
      final snapshot = await _shiftsCollection.doc(shiftId).get();
      if (snapshot.exists) {
        existingShift = TeachingShift.fromFirestore(snapshot);
      }
      if (existingShift != null) {
        try {
          await _scheduleShiftLifecycleTasks(existingShift, cancel: true);
        } catch (scheduleError) {
          AppLogger.error(
              'ShiftService: Warning - unable to cancel lifecycle tasks for shift $shiftId: $scheduleError');
        }
      }

      await _shiftsCollection.doc(shiftId).delete();
      AppLogger.error('Shift deleted successfully');
    } catch (e) {
      AppLogger.error('Error deleting shift: $e');
      throw Exception('Failed to delete shift');
    }
  }

  /// Delete multiple shifts at once
  static Future<void> deleteMultipleShifts(List<String> shiftIds) async {
    try {
      AppLogger.debug('ShiftService: Deleting ${shiftIds.length} shifts');

      // Use a batch to delete all shifts atomically
      final batch = FirebaseFirestore.instance.batch();
      final schedulingFutures = <Future<void>>[];

      for (String shiftId in shiftIds) {
        final docRef = _shiftsCollection.doc(shiftId);
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          final shift = TeachingShift.fromFirestore(snapshot);
          schedulingFutures.add(_scheduleShiftLifecycleTasks(shift,
                  cancel: true)
              .catchError((error) => AppLogger.error(
                  'ShiftService: Warning - unable to cancel lifecycle tasks for shift ${shift.id}: $error')));
        }
        batch.delete(docRef);
      }

      await batch.commit();
      if (schedulingFutures.isNotEmpty) {
        await Future.wait(schedulingFutures);
      }
      AppLogger.error(
          'ShiftService: Successfully deleted ${shiftIds.length} shifts');
    } catch (e) {
      AppLogger.error('Error deleting multiple shifts: $e');
      throw Exception('Failed to delete multiple shifts');
    }
  }

  /// Delete all shifts for a specific teacher
  static Future<int> deleteAllShiftsByTeacher(String teacherId) async {
    try {
      AppLogger.debug(
          'ShiftService: Deleting all shifts for teacher: $teacherId');

      // Get all shifts for this teacher
      final querySnapshot = await _shiftsCollection
          .where('teacher_id', isEqualTo: teacherId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        AppLogger.debug(
            'ShiftService: No shifts found for teacher: $teacherId');
        return 0;
      }

      // Use a batch to delete all shifts atomically
      final batch = FirebaseFirestore.instance.batch();
      final schedulingFutures = <Future<void>>[];

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        final shift = TeachingShift.fromFirestore(doc);
        schedulingFutures.add(_scheduleShiftLifecycleTasks(shift, cancel: true)
            .catchError((error) => AppLogger.error(
                'ShiftService: Warning - unable to cancel lifecycle tasks for shift ${shift.id}: $error')));
        batch.delete(doc.reference);
      }

      await batch.commit();
      if (schedulingFutures.isNotEmpty) {
        await Future.wait(schedulingFutures);
      }

      final deletedCount = querySnapshot.docs.length;
      AppLogger.error(
          'ShiftService: Successfully deleted $deletedCount shifts for teacher: $teacherId');
      return deletedCount;
    } catch (e) {
      AppLogger.error('Error deleting shifts by teacher: $e');
      throw Exception('Failed to delete teacher shifts');
    }
  }

  /// Update shift details
  static Future<void> updateShift(TeachingShift shift) async {
    try {
      await _shiftsCollection.doc(shift.id).update(shift.toFirestore());
      final shouldCancel = shift.status == ShiftStatus.cancelled;
      await _scheduleShiftLifecycleTasks(shift, cancel: shouldCancel);
      AppLogger.error('Shift updated successfully');
    } catch (e) {
      AppLogger.error('Error updating shift: $e');
      throw Exception('Failed to update shift');
    }
  }

  /// Clock in to a shift.
  ///
  /// Validations:
  /// 1. Shift exists and belongs to the teacher.
  /// 2. Current time is within the allowed clock-in window (e.g., 15 mins before/after).
  /// 3. Teacher does not have another *active* and *clocked-in* session.
  ///
  /// Updates:
  /// - Sets `status` to `active`.
  /// - Sets `clock_in_time` (if not already set).
  /// - Clears `clock_out_time`.
  static Future<bool> clockIn(String teacherId, String shiftId,
      {String? platform}) async {
    try {
      AppLogger.debug(
          'ShiftService: Attempting clock-in for teacher $teacherId, shift $shiftId');

      final doc = await _shiftsCollection.doc(shiftId).get();
      if (!doc.exists) {
        AppLogger.debug('ShiftService: ❌ Shift not found: $shiftId');
        return false;
      }

      AppLogger.debug('ShiftService: ✅ Shift document found');
      final shift = TeachingShift.fromFirestore(doc);

      // Validation checks
      if (shift.teacherId != teacherId) {
        AppLogger.debug(
            'ShiftService: ❌ Teacher ID mismatch: expected ${shift.teacherId}, got $teacherId');
        return false;
      }

      AppLogger.debug('ShiftService: ✅ Teacher ID matches');

      // Allow clock-in if within time window (15 min before to 15 min after shift)
      AppLogger.debug('ShiftService: Checking clock-in window...');
      AppLogger.debug('ShiftService: shift.canClockIn = ${shift.canClockIn}');
      if (!shift.canClockIn) {
        AppLogger.debug('ShiftService: ❌ Clock-in window not available');
        AppLogger.debug('ShiftService: Current time: ${DateTime.now()}');
        AppLogger.debug('ShiftService: Shift start: ${shift.shiftStart}');
        AppLogger.debug('ShiftService: Shift end: ${shift.shiftEnd}');
        return false;
      }

      AppLogger.debug('ShiftService: ✅ Clock-in window is available');

      // Allow multiple clock-ins within the same shift window
      // Remove status and isClockedIn checks to enable multiple entries

      // Check if teacher has any OTHER ongoing sessions (not just "active" status)
      // We only block if the teacher is actually clocked in to another shift.
      AppLogger.debug('ShiftService: Checking for other ongoing sessions...');
      final activeShiftsSnapshot = await _shiftsCollection
          .where('teacher_id', isEqualTo: teacherId)
          .where('status', isEqualTo: 'active')
          .get();

      // Convert to TeachingShift models and keep only those that represent an
      // actual open session (isClockedIn) and are not merely awaiting auto-logout.
      final otherOngoingSessions = activeShiftsSnapshot.docs
          .where((doc) => doc.id != shiftId) // exclude the target shift
          .map((doc) => TeachingShift.fromFirestore(doc))
          .where((s) => s.isClockedIn && !s.needsAutoLogout)
          .toList();

      AppLogger.debug(
          'ShiftService: Found ${activeShiftsSnapshot.docs.length} total active-status shifts');
      AppLogger.debug(
          'ShiftService: Found ${otherOngoingSessions.length} other ongoing sessions that block clock-in');

      if (otherOngoingSessions.isNotEmpty) {
        AppLogger.debug('ShiftService: ❌ Teacher has another ongoing session');
        for (var otherShift in otherOngoingSessions) {
          AppLogger.debug(
              'ShiftService: Blocking due to shift: ${otherShift.id}');
        }
        return false;
      }

      AppLogger.debug('ShiftService: ✅ No conflicting active shifts');

      // Perform clock-in
      final now = DateTime.now();
      AppLogger.debug('ShiftService: Performing clock-in update...');

      // Update shift with clock-in time and set status to active
      final updateData = <String, dynamic>{
        'last_modified': Timestamp.fromDate(now),
        'status': ShiftStatus.active.name, // Always set to active on clock-in
        'clock_out_time': null, // Clear any previous clock-out time
      };

      // Set clock_in_time on first clock-in or when re-activating a completed shift
      if (shift.status != ShiftStatus.active || shift.clockInTime == null) {
        AppLogger.debug(
            'ShiftService: Setting shift status to active (clock-in)');
        updateData['clock_in_time'] = Timestamp.fromDate(now);
      } else {
        AppLogger.debug(
            'ShiftService: Re-activating shift (subsequent session)');
      }

      // Store platform information if provided
      if (platform != null) {
        updateData['last_clock_in_platform'] = platform;
        AppLogger.debug('ShiftService: Recording clock-in platform: $platform');
      }

      await _shiftsCollection.doc(shiftId).update(updateData);

      AppLogger.error('ShiftService: ✅ Clock-in successful at $now');
      return true;
    } catch (e) {
      AppLogger.error('ShiftService: ❌ Exception during clock-in: $e');
      return false;
    }
  }

  /// Clock out from a shift.
  ///
  /// Updates:
  /// - Sets `clock_out_time` to now.
  /// - Updates `last_modified`.
  ///
  /// Note: The actual timesheet entry calculation is handled by [ShiftTimesheetService].
  /// This method primarily updates the shift status to allow the teacher to start new shifts.
  static Future<bool> clockOut(String teacherId, String shiftId) async {
    try {
      AppLogger.debug(
          'ShiftService: Attempting clock-out for teacher $teacherId, shift $shiftId');

      final doc = await _shiftsCollection.doc(shiftId).get();
      if (!doc.exists) {
        AppLogger.debug('Shift not found: $shiftId');
        return false;
      }

      final shift = TeachingShift.fromFirestore(doc);

      // Validation checks
      if (shift.teacherId != teacherId) {
        AppLogger.debug(
            'Teacher ID mismatch: expected ${shift.teacherId}, got $teacherId');
        return false;
      }

      // No need to check isClockedIn here, as the timesheet service handles this.
      // This allows multiple clock-outs as long as there's an open timesheet entry.

      // Perform clock-out
      final now = DateTime.now();

      // Mark shift as completed when clocking out to allow immediate clock-in to other shifts
      // This prevents the issue where teachers can't clock in to their next class
      // because the previous shift is still marked as "active"
      await _shiftsCollection.doc(shiftId).update({
        'last_modified': Timestamp.fromDate(now),
        'clock_out_time': Timestamp.fromDate(now),
      });

      AppLogger.error('Clock-out successful at $now');
      return true;
    } catch (e) {
      AppLogger.error('Error during clock-out: $e');
      return false;
    }
  }

  /// Check if teacher can clock in to a shift
  static Future<bool> canTeacherClockIn(
      String teacherId, String shiftId) async {
    try {
      final doc = await _shiftsCollection.doc(shiftId).get();
      if (!doc.exists) return false;

      final shift = TeachingShift.fromFirestore(doc);

      // Check if it's the right teacher
      if (shift.teacherId != teacherId) return false;

      // Check if within clock-in window and not already clocked in
      return shift.canClockIn &&
          shift.status == ShiftStatus.scheduled &&
          !shift.isClockedIn;
    } catch (e) {
      AppLogger.error('Error checking clock-in eligibility: $e');
      return false;
    }
  }

  /// Auto-logout expired shifts (for teachers who didn't clock out)
  static Future<void> autoLogoutExpiredShifts() async {
    try {
      final snapshot =
          await _shiftsCollection.where('status', isEqualTo: 'active').get();

      int expiredCount = 0;

      for (final doc in snapshot.docs) {
        final shift = TeachingShift.fromFirestore(doc);

        if (shift.needsAutoLogout) {
          try {
            await _scheduleShiftLifecycleTasks(shift);
            expiredCount++;
            AppLogger.error(
                'Auto-logout lifecycle sync requested for shift ${shift.id} (clock-in at ${shift.clockInTime})');
          } catch (e) {
            AppLogger.error(
                'ShiftService: Error scheduling lifecycle sync for expired shift ${shift.id}: $e');
          }
        }
      }

      AppLogger.error('Auto-logout processed $expiredCount expired shifts');
    } catch (e) {
      AppLogger.error('Error auto-logging out expired shifts: $e');
    }
  }

  /// Get shifts that need auto-logout (for monitoring)
  static Future<List<TeachingShift>> getShiftsNeedingAutoLogout() async {
    try {
      final snapshot =
          await _shiftsCollection.where('status', isEqualTo: 'active').get();

      final shifts = snapshot.docs
          .map((doc) => TeachingShift.fromFirestore(doc))
          .where((shift) => shift.needsAutoLogout)
          .toList();

      return shifts;
    } catch (e) {
      AppLogger.error('Error getting shifts needing auto-logout: $e');
      return [];
    }
  }

  /// Get available teachers for shift assignment.
  ///
  /// Tries to fetch active teachers first. If no active teachers are found,
  /// it falls back to fetching all teachers (ignoring `is_active` flag)
  /// to handle cases where the flag might be missing or incorrect.
  static Future<List<Employee>> getAvailableTeachers() async {
    try {
      AppLogger.debug('ShiftService: Querying for teachers...');
      final snapshot = await _firestore
          .collection('users')
          .where('user_type', isEqualTo: 'teacher')
          .where('is_active', isEqualTo: true)
          .get();

      AppLogger.debug(
          'ShiftService: Teachers query returned ${snapshot.docs.length} documents');

      if (snapshot.docs.isEmpty) {
        // Try without the is_active filter to see if that's the issue
        AppLogger.debug(
            'ShiftService: Retrying teachers query without is_active filter...');
        final retrySnapshot = await _firestore
            .collection('users')
            .where('user_type', isEqualTo: 'teacher')
            .get();
        AppLogger.debug(
            'ShiftService: Retry returned ${retrySnapshot.docs.length} teacher documents');

        // Print first few docs for debugging
        for (int i = 0; i < retrySnapshot.docs.length && i < 3; i++) {
          final doc = retrySnapshot.docs[i];
          AppLogger.debug('Teacher doc $i: ${doc.data()}');
        }

        return EmployeeDataSource.mapSnapshotToEmployeeList(retrySnapshot);
      }

      return EmployeeDataSource.mapSnapshotToEmployeeList(snapshot);
    } catch (e) {
      AppLogger.error('Error getting available teachers: $e');
      return [];
    }
  }

  /// Get available students for shift assignment
  static Future<List<Employee>> getAvailableStudents() async {
    try {
      AppLogger.debug('ShiftService: Querying for students...');
      final snapshot = await _firestore
          .collection('users')
          .where('user_type', isEqualTo: 'student')
          .where('is_active', isEqualTo: true)
          .get();

      AppLogger.debug(
          'ShiftService: Students query returned ${snapshot.docs.length} documents');

      if (snapshot.docs.isEmpty) {
        // Try without the is_active filter to see if that's the issue
        AppLogger.debug(
            'ShiftService: Retrying students query without is_active filter...');
        final retrySnapshot = await _firestore
            .collection('users')
            .where('user_type', isEqualTo: 'student')
            .get();
        AppLogger.debug(
            'ShiftService: Retry returned ${retrySnapshot.docs.length} student documents');

        // Print first few docs for debugging
        for (int i = 0; i < retrySnapshot.docs.length && i < 3; i++) {
          final doc = retrySnapshot.docs[i];
          AppLogger.debug('Student doc $i: ${doc.data()}');
        }

        return EmployeeDataSource.mapSnapshotToEmployeeList(retrySnapshot);
      }

      return EmployeeDataSource.mapSnapshotToEmployeeList(snapshot);
    } catch (e) {
      AppLogger.error('Error getting available students: $e');
      return [];
    }
  }

  /// Convert shift time to teacher's timezone
  static DateTime convertToTeacherTimezone(
    DateTime adminTime,
    String teacherTimezone,
  ) {
    // For now, this is a simplified conversion
    // In production, you'd use a proper timezone library like timezone

    // Common timezone offsets (simplified)
    final timezoneOffsets = {
      'UTC': 0,
      'EST': -5, // Eastern Standard Time
      'PST': -8, // Pacific Standard Time
      'AST': 3, // Saudi Arabia Standard Time
      'GMT': 0, // Greenwich Mean Time
      'CET': 1, // Central European Time
    };

    final offset = timezoneOffsets[teacherTimezone] ?? 0;
    return adminTime.add(Duration(hours: offset));
  }

  /// Get shift statistics (admin view - all shifts)
  static Future<Map<String, dynamic>> getShiftStatistics() async {
    try {
      final snapshot = await _shiftsCollection.get();
      final shifts =
          snapshot.docs.map((doc) => TeachingShift.fromFirestore(doc)).toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      return {
        'total_shifts': shifts.length,
        'scheduled_shifts':
            shifts.where((s) => s.status == ShiftStatus.scheduled).length,
        'active_shifts':
            shifts.where((s) => s.status == ShiftStatus.active).length,
        'completed_shifts': shifts
            .where((s) =>
                s.status == ShiftStatus.completed ||
                s.status == ShiftStatus.partiallyCompleted ||
                s.status == ShiftStatus.fullyCompleted)
            .length,
        'missed_shifts':
            shifts.where((s) => s.status == ShiftStatus.missed).length,
        'today_shifts': shifts
            .where((s) =>
                s.shiftStart.isAfter(today) && s.shiftStart.isBefore(tomorrow))
            .length,
        'upcoming_shifts': shifts
            .where((s) =>
                s.shiftStart.isAfter(now) && s.status == ShiftStatus.scheduled)
            .length,
      };
    } catch (e) {
      AppLogger.error('Error getting shift statistics: $e');
      return {};
    }
  }

  /// Get shift statistics for a specific teacher
  static Future<Map<String, dynamic>> getTeacherShiftStatistics(
      String teacherId) async {
    try {
      final snapshot = await _shiftsCollection
          .where('teacher_id', isEqualTo: teacherId)
          .get();
      final shifts =
          snapshot.docs.map((doc) => TeachingShift.fromFirestore(doc)).toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      return {
        'total_shifts': shifts.length,
        'scheduled_shifts':
            shifts.where((s) => s.status == ShiftStatus.scheduled).length,
        'active_shifts':
            shifts.where((s) => s.status == ShiftStatus.active).length,
        'completed_shifts': shifts
            .where((s) =>
                s.status == ShiftStatus.completed ||
                s.status == ShiftStatus.partiallyCompleted ||
                s.status == ShiftStatus.fullyCompleted)
            .length,
        'missed_shifts':
            shifts.where((s) => s.status == ShiftStatus.missed).length,
        'today_shifts': shifts
            .where((s) =>
                s.shiftStart.isAfter(today) && s.shiftStart.isBefore(tomorrow))
            .length,
        'upcoming_shifts': shifts
            .where((s) =>
                s.shiftStart.isAfter(now) && s.status == ShiftStatus.scheduled)
            .length,
      };
    } catch (e) {
      AppLogger.error('Error getting teacher shift statistics: $e');
      return {};
    }
  }

  /// Get all shifts for a specific teacher with timezone conversion
  static Future<List<TeachingShift>> getShiftsForTeacher(
    String teacherId, {
    String? teacherTimezone,
    int? limitDays,
  }) async {
    try {
      AppLogger.debug('ShiftService: Getting shifts for teacher $teacherId');

      // Temporarily remove orderBy to avoid index requirement
      var query = _shiftsCollection.where('teacher_id', isEqualTo: teacherId);

      // Optionally limit to upcoming shifts within X days
      if (limitDays != null) {
        final futureLimit = DateTime.now().add(Duration(days: limitDays));
        query = query.where('shift_start',
            isLessThan: Timestamp.fromDate(futureLimit));
      }

      final snapshot = await query.get();
      AppLogger.debug(
          'ShiftService: Found ${snapshot.docs.length} shifts for teacher');

      // Debug: Print ALL shift documents for this teacher
      if (snapshot.docs.isNotEmpty) {
        AppLogger.debug(
            'ShiftService: All ${snapshot.docs.length} shifts for teacher $teacherId:');
        for (int i = 0; i < snapshot.docs.length; i++) {
          final doc = snapshot.docs[i];
          final data = doc.data() as Map<String, dynamic>;
          AppLogger.debug('  ${i + 1}. Shift ID: ${doc.id}');
          AppLogger.debug('     Teacher ID: ${data['teacher_id']}');
          AppLogger.debug('     Name: ${data['auto_generated_name']}');
          AppLogger.debug('     Subject: ${data['subject']}');
          AppLogger.debug('     Date: ${data['shift_start']}');
          AppLogger.debug('     Recurrence: ${data['recurrence']}');
          AppLogger.info('     Created: ${data['created_at']}');
          AppLogger.debug('');
        }

        // Check for duplicates
        final duplicateNames = <String, int>{};
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['auto_generated_name'] as String? ?? 'Unknown';
          duplicateNames[name] = (duplicateNames[name] ?? 0) + 1;
        }

        AppLogger.debug('ShiftService: Duplicate analysis:');
        duplicateNames.forEach((name, count) {
          if (count > 1) {
            AppLogger.debug('  - "$name" appears $count times');
          }
        });
      } else {
        AppLogger.debug(
            'ShiftService: No shifts found for teacher_id: $teacherId');
      }

      final shifts =
          snapshot.docs.map((doc) => TeachingShift.fromFirestore(doc)).toList();

      // Sort by shift_start since we can't use orderBy in query without index
      shifts.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));

      // Convert to teacher's timezone if specified
      if (teacherTimezone != null) {
        // Note: In a real app, you'd use a proper timezone library like timezone
        // For now, we'll just note the timezone in the shift object
        return shifts
            .map((shift) => shift.copyWith(
                  teacherTimezone: teacherTimezone,
                ))
            .toList();
      }

      return shifts;
    } catch (e) {
      AppLogger.error('Error getting shifts for teacher: $e');
      return [];
    }
  }

  /// Get upcoming shifts for teacher (next 7 days)
  static Future<List<TeachingShift>> getUpcomingShiftsForTeacher(
    String teacherId, {
    String? teacherTimezone,
  }) async {
    return getShiftsForTeacher(
      teacherId,
      teacherTimezone: teacherTimezone,
      limitDays: 7,
    );
  }

  /// Check if teacher has any active shifts right now
  static Future<bool> hasActiveShift(String teacherId) async {
    try {
      final activeShift = await getCurrentActiveShift(teacherId);
      return activeShift != null;
    } catch (e) {
      AppLogger.error('Error checking active shift: $e');
      return false;
    }
  }

  /// Clean up duplicate shifts for a teacher (EMERGENCY FUNCTION)
  static Future<void> cleanupDuplicateShifts(String teacherId) async {
    try {
      AppLogger.debug('ShiftService: Starting cleanup for teacher $teacherId');

      final snapshot = await _shiftsCollection
          .where('teacher_id', isEqualTo: teacherId)
          .get();

      AppLogger.debug(
          'ShiftService: Found ${snapshot.docs.length} total shifts');

      // Group by auto_generated_name and date
      final shiftGroups = <String, List<QueryDocumentSnapshot>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['auto_generated_name'] as String? ?? 'Unknown';
        final date = (data['shift_start'] as Timestamp?)?.toDate();
        final key = '$name-${date?.day}/${date?.month}/${date?.year}';

        if (!shiftGroups.containsKey(key)) {
          shiftGroups[key] = [];
        }
        shiftGroups[key]!.add(doc);
      }

      // Delete duplicates (keep only the first one of each group)
      int deletedCount = 0;
      final batch = _firestore.batch();

      for (var group in shiftGroups.values) {
        if (group.length > 1) {
          AppLogger.debug('Found ${group.length} duplicates of same shift');
          // Keep the first one, delete the rest
          for (int i = 1; i < group.length; i++) {
            batch.delete(group[i].reference);
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
        AppLogger.error('ShiftService: Deleted $deletedCount duplicate shifts');
      } else {
        AppLogger.error('ShiftService: No duplicates found to clean up');
      }
    } catch (e) {
      AppLogger.error('Error cleaning up duplicate shifts: $e');
      throw Exception('Failed to cleanup duplicate shifts');
    }
  }

  /// Adjust all future/scheduled shifts by the specified number of hours.
  ///
  /// This is a utility for bulk-updating shift times, typically used for
  /// Daylight Saving Time (DST) adjustments.
  ///
  /// @param adjustmentHours: Positive to add hours, negative to subtract hours
  /// @param onlyFutureShifts: If true, only adjusts shifts that haven't started yet
  static Future<Map<String, dynamic>> adjustAllShiftTimes({
    required int adjustmentHours,
    bool onlyFutureShifts = true,
    String? adminUserId,
  }) async {
    try {
      AppLogger.debug(
          'ShiftService: Starting DST adjustment of $adjustmentHours hour(s)');

      final now = DateTime.now().toUtc();
      int totalShifts = 0;
      int adjustedShifts = 0;
      int skippedShifts = 0;
      List<String> errors = [];

      // Build query based on parameters
      Query query = _shiftsCollection;

      if (onlyFutureShifts) {
        // Only get shifts that haven't started yet
        query =
            query.where('shift_start', isGreaterThan: Timestamp.fromDate(now));
      }

      // Only get scheduled shifts (not completed, cancelled, or missed)
      query = query.where('status', isEqualTo: 'scheduled');

      final snapshot = await query.get();
      totalShifts = snapshot.docs.length;

      AppLogger.debug(
          'ShiftService: Found $totalShifts shifts to potentially adjust');

      if (totalShifts == 0) {
        return {
          'success': true,
          'totalShifts': 0,
          'adjustedShifts': 0,
          'skippedShifts': 0,
          'message': 'No eligible shifts found for DST adjustment',
        };
      }

      // Process shifts in batches to avoid timeout
      const batchSize = 500;
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final shift = TeachingShift.fromFirestore(doc);

          // Skip if shift is not scheduled
          if (shift.status != ShiftStatus.scheduled) {
            skippedShifts++;
            AppLogger.debug('Skipping non-scheduled shift: ${shift.id}');
            continue;
          }

          // Skip if shift has already been clocked in
          if (shift.clockInTime != null) {
            skippedShifts++;
            AppLogger.debug('Skipping clocked-in shift: ${shift.id}');
            continue;
          }

          // Adjust the shift times
          final adjustedStartTime =
              shift.shiftStart.add(Duration(hours: adjustmentHours));
          final adjustedEndTime =
              shift.shiftEnd.add(Duration(hours: adjustmentHours));

          // Update the document
          batch.update(doc.reference, {
            'shift_start': Timestamp.fromDate(adjustedStartTime),
            'shift_end': Timestamp.fromDate(adjustedEndTime),
            'last_modified': Timestamp.now(),
            'dst_adjustment_applied': true,
            'dst_adjustment_hours': adjustmentHours,
            'dst_adjustment_date': Timestamp.now(),
            'dst_adjusted_by': adminUserId ?? 'system',
          });

          adjustedShifts++;
          batchCount++;

          // Commit batch if it reaches the limit
          if (batchCount >= batchSize) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
            AppLogger.debug(
                'ShiftService: Committed batch of $batchSize shifts');
          }
        } catch (e) {
          AppLogger.error('Error processing shift ${doc.id}: $e');
          errors.add('Shift ${doc.id}: $e');
          skippedShifts++;
        }
      }

      // Commit remaining batch
      if (batchCount > 0) {
        await batch.commit();
        AppLogger.debug(
            'ShiftService: Committed final batch of $batchCount shifts');
      }

      final message = adjustmentHours > 0
          ? 'Added $adjustmentHours hour(s) to $adjustedShifts shifts'
          : 'Subtracted ${-adjustmentHours} hour(s) from $adjustedShifts shifts';

      AppLogger.error('ShiftService: DST adjustment complete. $message');

      return {
        'success': errors.isEmpty,
        'totalShifts': totalShifts,
        'adjustedShifts': adjustedShifts,
        'skippedShifts': skippedShifts,
        'errors': errors,
        'message': message,
      };
    } catch (e) {
      AppLogger.error('ShiftService: Error during DST adjustment: $e');
      throw Exception('Failed to adjust shift times: $e');
    }
  }
}
