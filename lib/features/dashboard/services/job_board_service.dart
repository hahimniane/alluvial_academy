import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:alluwalacademyadmin/core/models/enrollment_request.dart';
import 'package:alluwalacademyadmin/features/dashboard/models/job_opportunity.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class JobBoardService {
  /// Job closed because a teacher submitted full availability; admin can still confirm match.
  static const String kClosedReasonTeacherFullyAvailable =
      'teacher_fully_available';

  final CollectionReference _jobCollection = 
      FirebaseFirestore.instance.collection('job_board');
  final CollectionReference _enrollmentCollection = 
      FirebaseFirestore.instance.collection('enrollments');

  /// Creates a new job opportunity from an enrollment request.
  /// [overrideDays], [overrideTimeSlots], [overrideTimeOfDay] let admin
  /// adjust the schedule before teachers see it.
  /// [scheduleTimezoneRef] records which IANA timezone the times refer to.
  /// [adminNotesForTeachers] are visible to teachers on the job board.
  Future<void> broadcastEnrollment(
    EnrollmentRequest enrollment, {
    List<String>? overrideDays,
    List<String>? overrideTimeSlots,
    String? overrideTimeOfDay,
    String? scheduleTimezoneRef,
    String? adminNotesForTeachers,
  }) async {
    if (enrollment.id == null) throw Exception('Enrollment ID is missing');

    try {
      // 1. Ensure admin is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be signed in as an admin to broadcast enrollments.');
      }
      
      AppLogger.info('Broadcasting enrollment ${enrollment.id} for user: ${user.uid}');
      
      // 2. Read the enrollment document fresh from Firestore to get all nested data
      final enrollmentDoc = await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(enrollment.id)
          .get();
      
      if (!enrollmentDoc.exists) {
        throw Exception('Enrollment ${enrollment.id} not found');
      }
      
      final enrollmentData = enrollmentDoc.data()!;
      
      // Extract nested data structures
      final contact = enrollmentData['contact'] as Map<String, dynamic>? ?? {};
      final country = contact['country'] as Map<String, dynamic>? ?? {};
      final preferences = enrollmentData['preferences'] as Map<String, dynamic>? ?? {};
      final metadata = enrollmentData['metadata'] as Map<String, dynamic>? ?? {};
      final student = enrollmentData['student'] as Map<String, dynamic>? ?? {};
      final program = enrollmentData['program'] as Map<String, dynamic>? ?? {};
      
      // 3. Check if already broadcasted or matched
      final currentStatus = metadata['status'] ?? 'pending';
      if (currentStatus == 'broadcasted' || currentStatus == 'matched') {
        throw Exception('Enrollment is already $currentStatus');
      }
      
      // 4. Extract all fields with proper fallbacks
      final originalDays = List<String>.from(preferences['days'] ?? enrollmentData['preferredDays'] ?? []);
      final originalTimeSlots = List<String>.from(preferences['timeSlots'] ?? enrollmentData['preferredTimeSlots'] ?? []);
      final originalTimeOfDay = preferences['timeOfDayPreference'] ?? enrollmentData['timeOfDayPreference'];

      final days = overrideDays ?? originalDays;
      final timeSlots = overrideTimeSlots ?? originalTimeSlots;
      final timeOfDay = overrideTimeOfDay ?? originalTimeOfDay;
      final studentTz = preferences['timeZone'] ?? enrollmentData['timeZone'] ?? 'UTC';
      final timezoneRef = (scheduleTimezoneRef != null && scheduleTimezoneRef.trim().isNotEmpty)
          ? scheduleTimezoneRef.trim()
          : studentTz;
      final nowTs = Timestamp.fromDate(DateTime.now());
      final broadcastSnapshot = <String, dynamic>{
        'days': days,
        'timeSlots': timeSlots,
        'timeOfDayPreference': timeOfDay,
        'timezoneRef': timezoneRef,
        if (adminNotesForTeachers != null) 'adminNotesForTeachers': adminNotesForTeachers,
        'broadcastedBy': user.uid,
        'broadcastedAt': nowTs,
      };
      
      // 5. Create job opportunity directly in Firestore with all student details
      final jobData = {
        'enrollmentId': enrollment.id,
        'studentName': student['name'] ?? enrollmentData['studentName'] ?? 'Student',
        'studentAge': student['age'] ?? enrollmentData['studentAge'] ?? 'N/A',
        'gender': student['gender'] ?? enrollmentData['gender'] ?? 'Not specified',
        'subject': enrollmentData['subject'] ?? 'General',
        'subject_display_name': enrollmentData['programTitle'] ?? enrollmentData['subject'] ?? 'General',
        'specificLanguage': enrollmentData['specificLanguage'],
        'gradeLevel': enrollmentData['gradeLevel'] ?? '',
        'days': days,
        'timeSlots': timeSlots,
        'timeZone': studentTz,
        'sessionDuration': program['sessionDuration'] ?? enrollmentData['sessionDuration'] ?? '60 minutes',
        'timeOfDayPreference': timeOfDay,
        'countryName': country['name'] ?? enrollmentData['countryName'] ?? '',
        'countryCode': country['code'] ?? enrollmentData['countryCode'] ?? '',
        'city': contact['city'] ?? enrollmentData['city'] ?? '',
        'classType': program['classType'] ?? enrollmentData['classType'],
        'preferredLanguage': preferences['preferredLanguage'] ?? enrollmentData['preferredLanguage'],
        'knowsZoom': student['knowsZoom'] ?? enrollmentData['knowsZoom'],
        'isAdult': metadata['isAdult'] ?? enrollmentData['isAdult'] ?? false,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'parentEmail': contact['email'],
        'parentName': contact['parentName'],
        'parentLinkId': metadata['parentLinkId'],
        'studentIndex': metadata['studentIndex'],
        'totalStudents': metadata['totalStudents'],
        'broadcastSnapshot': broadcastSnapshot,
        'scheduleTimezoneRef': timezoneRef,
        if (adminNotesForTeachers != null) 'adminNotesForTeachers': adminNotesForTeachers,
      };
      
      // Remove null values
      jobData.removeWhere((key, value) => value == null);
      
      AppLogger.info('Creating job opportunity with data: ${jobData.keys.join(", ")}');
      AppLogger.info('Student details: name=${jobData['studentName']}, age=${jobData['studentAge']}, subject=${jobData['subject']}');
      
      final jobRef = await _jobCollection.add(jobData);
      AppLogger.info('Created job opportunity: ${jobRef.id}');
      
      // 6. Update enrollment status with admin tracking
      final currentUser = FirebaseAuth.instance.currentUser;
      String? adminName;
      if (currentUser != null) {
        try {
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          if (adminDoc.exists) {
            final data = adminDoc.data() as Map<String, dynamic>;
            adminName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
            if (adminName.isEmpty) adminName = data['e-mail'] as String?;
          }
        } catch (e) {
          adminName = currentUser.email;
        }
      }
      
      final actionEntry = {
        'action': 'broadcasted',
        'status': 'broadcasted',
        'adminId': currentUser?.uid ?? 'system',
        'adminName': adminName ?? 'System',
        'adminEmail': currentUser?.email ?? '',
        'jobId': jobRef.id,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      };
      
      // Build schedule edit audit trail if admin changed anything
      final Map<String, dynamic>? scheduleEdits;
      final bool daysChanged = overrideDays != null && overrideDays.join(',') != originalDays.join(',');
      final bool slotsChanged = overrideTimeSlots != null && overrideTimeSlots.join(',') != originalTimeSlots.join(',');
      final bool todChanged = overrideTimeOfDay != null && overrideTimeOfDay != originalTimeOfDay;
      if (daysChanged || slotsChanged || todChanged) {
        scheduleEdits = {
          'editedAt': Timestamp.fromDate(DateTime.now()),
          if (daysChanged) 'originalDays': originalDays,
          if (daysChanged) 'newDays': overrideDays,
          if (slotsChanged) 'originalTimeSlots': originalTimeSlots,
          if (slotsChanged) 'newTimeSlots': overrideTimeSlots,
          if (todChanged) 'originalTimeOfDay': originalTimeOfDay,
          if (todChanged) 'newTimeOfDay': overrideTimeOfDay,
        };
      } else {
        scheduleEdits = null;
      }

      await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(enrollment.id)
          .update({
        'metadata.status': 'broadcasted',
        'metadata.broadcastedAt': FieldValue.serverTimestamp(),
        'metadata.jobId': jobRef.id,
        'metadata.broadcastedBy': currentUser?.uid,
        'metadata.broadcastedByName': adminName,
        'metadata.lastUpdated': FieldValue.serverTimestamp(),
        'metadata.updatedBy': currentUser?.uid,
        'metadata.updatedByName': adminName,
        'metadata.actionHistory': FieldValue.arrayUnion([actionEntry]),
        if (scheduleEdits != null) 'metadata.adminScheduleEdits': scheduleEdits,
        if (adminNotesForTeachers != null) 'metadata.adminNotesForTeachers': adminNotesForTeachers,
        'metadata.scheduleTimezoneRef': timezoneRef,
        'metadata.lastBroadcastSnapshot': broadcastSnapshot,
      });
      
      AppLogger.info('Successfully broadcasted enrollment ${enrollment.id}, jobId: ${jobRef.id}');
    } catch (e) {
      final errorMessage = e.toString();
      AppLogger.error('Error broadcasting enrollment: $errorMessage');
      throw Exception('Failed to broadcast enrollment: $errorMessage');
    }
  }

  /// Normalize selectedTimes to ensure it's a valid map of day -> time string
  Map<String, String>? _normalizeSelectedTimes(Map<String, String>? rawTimes) {
    if (rawTimes == null || rawTimes.isEmpty) return null;
    final normalized = <String, String>{};
    for (final entry in rawTimes.entries) {
      if (entry.key.isNotEmpty && entry.value.isNotEmpty) {
        normalized[entry.key] = entry.value;
      }
    }
    return normalized.isEmpty ? null : normalized;
  }

  CollectionReference<Map<String, dynamic>> _responsesRef(String jobId) {
    return FirebaseFirestore.instance
        .collection('job_board')
        .doc(jobId)
        .collection('responses');
  }

  Future<Map<String, dynamic>?> getTeacherResponse(
      String jobId, String teacherId) async {
    final doc = await _responsesRef(jobId).doc(teacherId).get();
    return doc.data();
  }

  /// Streams all teacher responses for a job. No server [orderBy] (avoids missing
  /// composite-index failures); sorted by [updatedAt] in memory.
  Stream<List<Map<String, dynamic>>> streamJobResponses(String jobId) {
    return _responsesRef(jobId).snapshots().map((snap) {
      final rows = snap.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'teacherId': doc.id,
          ...data,
        };
      }).toList();
      rows.sort((a, b) {
        final ta = a['updatedAt'];
        final tb = b['updatedAt'];
        if (ta is Timestamp && tb is Timestamp) {
          return tb.compareTo(ta);
        }
        if (ta is Timestamp) return -1;
        if (tb is Timestamp) return 1;
        return 0;
      });
      return rows;
    });
  }

  /// Teacher availability rules (job_board):
  /// - **partial**: job stays [status] `open`; every teacher may submit their own response doc.
  /// - **available** (fully): job becomes `closed` with [kClosedReasonTeacherFullyAvailable] and
  ///   disappears from the teacher job board until an admin reopens or declines that response.
  Future<void> submitTeacherResponse(
    String jobId, {
    required String availabilityStatus, // available | partial
    String? comment,
    List<String>? availableAlternatives,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to respond.');
    }

    const validStatuses = {'available', 'partial'};
    if (!validStatuses.contains(availabilityStatus)) {
      throw Exception('Invalid availability status.');
    }

    final normalizedComment = (comment ?? '').trim();
    if (availabilityStatus == 'partial' && normalizedComment.isEmpty) {
      throw Exception('Please add a comment for a partial availability response.');
    }

    final normalizedAlternatives = (availableAlternatives ?? const [])
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final db = FirebaseFirestore.instance;
    final jobRef = db.collection('job_board').doc(jobId);
    final userRef = db.collection('users').doc(user.uid);
    final responseRef = _responsesRef(jobId).doc(user.uid);

    await db.runTransaction((tx) async {
      final jobSnap = await tx.get(jobRef);
      if (!jobSnap.exists) throw Exception('Job not found.');
      final jobData = jobSnap.data()!;
      final st = (jobData['status'] ?? '').toString();
      if (st != 'open') {
        if (st == 'closed') {
          throw Exception('This opportunity is closed. Ask an admin to reopen it if needed.');
        }
        throw Exception(
            'This opportunity is not open for availability responses (current status: $st).');
      }

      if (((jobData['enrollmentId'] ?? '') as Object).toString().trim().isEmpty) {
        throw Exception('Job is missing enrollment reference.');
      }

      String teacherName = user.displayName ?? '';
      String teacherTimezone = 'UTC';
      final userSnap = await tx.get(userRef);
      if (userSnap.exists) {
        final profile = userSnap.data()!;
        final first = (profile['first_name'] ?? '').toString().trim();
        final last = (profile['last_name'] ?? '').toString().trim();
        final full = '$first $last'.trim();
        if (full.isNotEmpty) teacherName = full;
        teacherTimezone = (profile['timezone'] ?? 'UTC').toString();
      }
      if (teacherName.isEmpty) teacherName = user.email ?? 'Teacher';

      final existingResponse = await tx.get(responseRef);
      final prevStatus = existingResponse.data()?['availabilityStatus'] as String?;
      final nowTs = Timestamp.fromDate(DateTime.now());

      tx.set(responseRef, {
        'teacherId': user.uid,
        'teacherName': teacherName,
        'teacherEmail': user.email,
        'teacherTimezone': teacherTimezone,
        'availabilityStatus': availabilityStatus,
        'comment': normalizedComment,
        'availableAlternatives': normalizedAlternatives,
        'createdAt': existingResponse.exists
            ? (existingResponse.data()?['createdAt'] ?? nowTs)
            : nowTs,
        'updatedAt': nowTs,
        'adminRejected': FieldValue.delete(),
        'adminRejectedAt': FieldValue.delete(),
        'rejectedByAdminId': FieldValue.delete(),
        'adminRejectedNote': FieldValue.delete(),
      }, SetOptions(merge: true));

      // Client timestamps so Firestore rules see stable diffs (serverTimestamp is opaque in rules).
      final jobUpdates = <String, dynamic>{
        'lastResponseAt': nowTs,
        'lastResponseByTeacherId': user.uid,
      };
      if (prevStatus != null && prevStatus != availabilityStatus) {
        jobUpdates['responseCounts.$prevStatus'] = FieldValue.increment(-1);
      }
      if (prevStatus == null || prevStatus != availabilityStatus) {
        jobUpdates['responseCounts.$availabilityStatus'] = FieldValue.increment(1);
      }
      if (availabilityStatus == 'available') {
        jobUpdates['status'] = 'closed';
        jobUpdates['closedReason'] = kClosedReasonTeacherFullyAvailable;
        // Client timestamp so Firestore rules can validate [closedAt] (serverTimestamp is opaque in rules).
        jobUpdates['closedAt'] = Timestamp.fromDate(DateTime.now());
      }
      tx.update(jobRef, jobUpdates);

      // Do not update enrollments here: admin sees live data via job_board/{id}/responses,
      // and strict Firestore rules on metadata diffs + server timestamps often denied 2nd+ teachers.
      // confirmTeacherMatch still writes enrollment when an admin confirms.
    });
  }

  Future<void> confirmTeacherMatch(
    String jobId, {
    required String teacherId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('You must be signed in as admin to confirm matches.');
    }

    final db = FirebaseFirestore.instance;
    final jobRef = db.collection('job_board').doc(jobId);
    final responseRef = _responsesRef(jobId).doc(teacherId);

    await db.runTransaction((tx) async {
      final jobSnap = await tx.get(jobRef);
      if (!jobSnap.exists) throw Exception('Job not found.');
      final jobData = jobSnap.data()!;
      final jobStatus = (jobData['status'] ?? '').toString();
      if (jobStatus == 'accepted') {
        throw Exception('Job already accepted.');
      }
      if (jobStatus == 'closed') {
        final reason = (jobData['closedReason'] ?? '').toString();
        if (reason != kClosedReasonTeacherFullyAvailable) {
          throw Exception('Job is closed.');
        }
      } else if (jobStatus != 'open') {
        throw Exception('Job cannot be matched in its current state.');
      }

      final enrollmentId = (jobData['enrollmentId'] ?? '').toString();
      if (enrollmentId.isEmpty) throw Exception('Missing enrollment id.');

      final responseSnap = await tx.get(responseRef);
      if (!responseSnap.exists) {
        throw Exception('Teacher has not submitted a response yet.');
      }
      final response = responseSnap.data()!;
      if (response['adminRejected'] == true) {
        throw Exception(
            'This response was declined. The teacher must submit a new availability response.');
      }
      final teacherName = (response['teacherName'] ?? 'Teacher').toString();
      final availabilityStatus =
          (response['availabilityStatus'] ?? 'available').toString();
      final comment = (response['comment'] ?? '').toString();
      final alternatives = List<String>.from(
          (response['availableAlternatives'] as List?) ?? const <String>[]);

      tx.update(jobRef, {
        'status': 'accepted',
        'acceptedByTeacherId': teacherId,
        'acceptedAt': FieldValue.serverTimestamp(),
        'confirmedByAdminId': currentUser.uid,
        'confirmedByAdminAt': FieldValue.serverTimestamp(),
        'teacherResponseStatus': availabilityStatus,
        if (comment.isNotEmpty) 'teacherResponseComment': comment,
        if (alternatives.isNotEmpty) 'teacherResponseAlternatives': alternatives,
        'closedReason': FieldValue.delete(),
        'closedAt': FieldValue.delete(),
      });

      final enrollmentRef = db.collection('enrollments').doc(enrollmentId);
      tx.update(enrollmentRef, {
        'metadata.status': 'matched',
        'metadata.jobId': jobId,
        'metadata.matchedTeacherId': teacherId,
        'metadata.matchedTeacherName': teacherName,
        'metadata.matchedAt': FieldValue.serverTimestamp(),
        'metadata.matchedByAdminId': currentUser.uid,
        'metadata.latestTeacherResponseSummary': {
          'teacherId': teacherId,
          'teacherName': teacherName,
          'availabilityStatus': availabilityStatus,
          if (comment.isNotEmpty) 'comment': comment,
          if (alternatives.isNotEmpty) 'availableAlternatives': alternatives,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
        'metadata.lastUpdated': FieldValue.serverTimestamp(),
        'metadata.actionHistory': FieldValue.arrayUnion([
          {
            'action': 'admin_confirmed_match',
            'status': 'matched',
            'jobId': jobId,
            'teacherId': teacherId,
            'teacherName': teacherName,
            'adminId': currentUser.uid,
            'adminEmail': currentUser.email ?? '',
            'timestamp': Timestamp.fromDate(DateTime.now()),
          }
        ]),
      });
    });
  }

  /// Admin rejects a teacher's availability proposition.
  /// If the job was auto-closed because this teacher marked fully available,
  /// the job is re-opened so other teachers can respond again.
  Future<void> adminRejectTeacherResponse(
    String jobId,
    String teacherId, {
    String? note,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('You must be signed in to decline a response.');
    }
    final trimmed = (note ?? '').trim();
    final adminUid = currentUser.uid;
    final db = FirebaseFirestore.instance;
    final jobRef = db.collection('job_board').doc(jobId);
    final responseRef = _responsesRef(jobId).doc(teacherId);

    await db.runTransaction((tx) async {
      final jobSnap = await tx.get(jobRef);
      tx.update(responseRef, {
        'adminRejected': true,
        'adminRejectedAt': FieldValue.serverTimestamp(),
        'rejectedByAdminId': adminUid,
        if (trimmed.isNotEmpty) 'adminRejectedNote': trimmed,
      });
      if (!jobSnap.exists) return;
      final jd = jobSnap.data()!;
      if (jd['status'] == 'closed' &&
          (jd['closedReason'] ?? '').toString() ==
              kClosedReasonTeacherFullyAvailable &&
          (jd['lastResponseByTeacherId'] ?? '').toString() == teacherId) {
        tx.update(jobRef, {
          'status': 'open',
          'closedReason': FieldValue.delete(),
          'closedAt': FieldValue.delete(),
        });
      }
    });
  }

  /// Reopens the posting on the teacher job board after it was auto-closed because
  /// someone marked **fully available** ([kClosedReasonTeacherFullyAvailable]).
  /// Partial responses are unchanged; teachers can submit again.
  Future<void> adminReopenJobBoardForTeachers(String jobId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('You must be signed in as admin.');
    }
    final jobRef = _jobCollection.doc(jobId);
    String? enrollmentId;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(jobRef);
      if (!snap.exists) throw Exception('Job not found.');
      final d = snap.data() as Map<String, dynamic>;
      if ((d['status'] ?? '').toString() != 'closed') {
        throw Exception('This job is not closed; nothing to reopen.');
      }
      if ((d['closedReason'] ?? '').toString() !=
          kClosedReasonTeacherFullyAvailable) {
        throw Exception(
            'This job was not closed because a teacher marked fully available. Use the appropriate admin action for this case.');
      }
      enrollmentId = (d['enrollmentId'] ?? '').toString();
      tx.update(jobRef, {
        'status': 'open',
        'closedReason': FieldValue.delete(),
        'closedAt': FieldValue.delete(),
        'reopenedByAdminAt': FieldValue.serverTimestamp(),
        'reopenedByAdminId': currentUser.uid,
      });
    });

    final eid = enrollmentId;
    if (eid != null && eid.isNotEmpty) {
      String? adminName;
      try {
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (adminDoc.exists) {
          final data = adminDoc.data() as Map<String, dynamic>;
          adminName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
          if (adminName.isEmpty) adminName = data['e-mail'] as String?;
        }
      } catch (_) {
        adminName = currentUser.email;
      }
      await FirebaseFirestore.instance.collection('enrollments').doc(eid).update({
        'metadata.lastUpdated': FieldValue.serverTimestamp(),
        'metadata.updatedBy': currentUser.uid,
        'metadata.updatedByName': adminName,
        'metadata.actionHistory': FieldValue.arrayUnion([
          {
            'action': 'job_board_reopened_after_full_availability',
            'jobId': jobId,
            'adminId': currentUser.uid,
            'adminEmail': currentUser.email ?? '',
            'adminName': adminName ?? 'Admin',
            'timestamp': Timestamp.fromDate(DateTime.now()),
          }
        ]),
      });
    }
  }

  /// Allows a teacher to accept a job directly (No Cloud Function)
  /// Uses a Firestore WriteBatch to ensure all updates happen atomically.
  /// [selectedTimes] is an optional map of day -> time slot selected by teacher
  Future<void> acceptJob(String jobId, String teacherId, {Map<String, String>? selectedTimes}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to accept a job.');
    }

    try {
      final db = FirebaseFirestore.instance;
      
      // Normalize selected times
      final normalizedTimes = _normalizeSelectedTimes(selectedTimes);
      
      // 1. Get the Job Data to verify it's open
      final jobRef = db.collection('job_board').doc(jobId);
      final jobSnapshot = await jobRef.get();
      
      if (!jobSnapshot.exists) {
        throw Exception('Job not found');
      }
      
      final jobData = jobSnapshot.data() as Map<String, dynamic>;
      
      // SECURITY CHECK: Ensure job is open
      if (jobData['status'] != 'open') {
        throw Exception('Job is no longer open');
      }

      // 2. Prepare Data
      final enrollmentId = jobData['enrollmentId'] as String;
      final enrollmentRef = db.collection('enrollments').doc(enrollmentId);
      
      // Get teacher name safely
      String teacherName = 'Teacher';
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        teacherName = user.displayName!;
      } else {
        // Try to fetch from user profile
        try {
          final userDoc = await db.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final firstName = userData['first_name'] as String? ?? '';
            final lastName = userData['last_name'] as String? ?? '';
            final fullName = '$firstName $lastName'.trim();
            if (fullName.isNotEmpty) {
              teacherName = fullName;
            } else {
              teacherName = user.email ?? 'Unknown Teacher';
            }
          } else {
            teacherName = user.email ?? 'Unknown Teacher';
          }
        } catch (_) {
          teacherName = user.email ?? 'Unknown Teacher';
        }
      }

      // 3. START BATCH (Atomic Operation)
      final batch = db.batch();

      // --- A. Update Job Board (Accept) ---
      final jobUpdate = <String, dynamic>{
        'status': 'accepted',
        'acceptedByTeacherId': user.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      };
      
      if (normalizedTimes != null) {
        jobUpdate['teacherSelectedTimes'] = normalizedTimes;
      }
      
      batch.update(jobRef, jobUpdate);

      // --- B. Update Enrollment (Set Matched Status) ---
      final enrollmentUpdate = <String, dynamic>{
        'metadata.status': 'matched',
        'metadata.matchedTeacherId': user.uid,
        'metadata.matchedTeacherName': teacherName,
        'metadata.matchedAt': FieldValue.serverTimestamp(),
        'metadata.lastUpdated': FieldValue.serverTimestamp(),
      };
      
      if (normalizedTimes != null) {
        enrollmentUpdate['metadata.teacherSelectedTimes'] = normalizedTimes;
      }
      
      // Build action history entry
      final teacherActionEntry = {
        'action': 'teacher_accepted',
        'status': 'matched',
        'teacherId': user.uid,
        'teacherName': teacherName,
        if (normalizedTimes != null) 'selectedTimes': normalizedTimes,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      };
      
      enrollmentUpdate['metadata.actionHistory'] = FieldValue.arrayUnion([teacherActionEntry]);
      
      batch.update(enrollmentRef, enrollmentUpdate);

      // --- C. Create Admin Notification ---
      final notifRef = db.collection('admin_notifications').doc();
      final timeDetails = normalizedTimes != null
          ? normalizedTimes.entries.map((e) => '${e.key}: ${e.value}').join(', ')
          : 'No specific times selected';
      
      batch.set(notifRef, {
        'type': 'job_accepted',
        'jobId': jobId,
        'teacherId': user.uid,
        'teacherName': teacherName,
        'enrollmentId': enrollmentId,
        'studentName': jobData['studentName'] ?? 'Student',
        'subject': jobData['subject'] ?? 'Subject',
        if (normalizedTimes != null) 'teacherSelectedTimes': normalizedTimes,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'message': 'A teacher has accepted ${jobData['studentName'] ?? 'Student'} (${jobData['subject'] ?? 'Subject'}). Selected times: $timeDetails',
        'action_required': true,
      });

      // 4. Commit all changes at once
      await batch.commit();

      AppLogger.info('Successfully accepted job $jobId via direct Firestore batch. Selected times: ${normalizedTimes?.toString() ?? 'none'}');
      
    } on FirebaseException catch (e) {
      AppLogger.error('Error accepting job: $e');
      
      // Handle Permission Denied specifically
      if (e.code == 'permission-denied') {
         throw Exception('Permission denied. Please ask Admin to check Firestore Rules for "enrollments" and "job_board".');
      }
      if (e.code == 'not-found') {
        throw Exception('Job or enrollment not found.');
      }
      throw Exception('Failed to accept job: ${e.message ?? e.code}');
    } catch (e) {
      AppLogger.error('Error accepting job: $e');
      
      if (e.toString().toLowerCase().contains('permission-denied')) {
        throw Exception('Permission denied. Please ask Admin to check Firestore Rules.');
      }
      throw Exception('Failed to accept job: $e');
    }
  }

  /// When admin un-broadcasts an enrollment, close matching job_board entries
  /// so they no longer appear as open/accepted on the teacher job board.
  Future<void> unbroadcastEnrollment(String enrollmentId) async {
    final snap = await FirebaseFirestore.instance
        .collection('job_board')
        .where('enrollmentId', isEqualTo: enrollmentId)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update({'status': 'closed'});
    }
    if (snap.docs.isNotEmpty) {
      AppLogger.info('Unbroadcast: closed ${snap.docs.length} job(s) for enrollment $enrollmentId');
    }
  }

  /// Admin revokes teacher acceptance and re-broadcasts the job
  /// Clears all acceptance info and sets status back to 'open'
  Future<void> adminRevokeAcceptance(String jobId) async {
    try {
      final jobDoc = await _jobCollection.doc(jobId).get();
      if (!jobDoc.exists) throw Exception('Job not found');
      
      final jobData = jobDoc.data() as Map<String, dynamic>;
      final enrollmentId = jobData['enrollmentId'] as String?;
      final previousTeacherId = jobData['acceptedByTeacherId'];
      
      // 1. Clear acceptance fields on job_board and re-open
      await _jobCollection.doc(jobId).update({
        'status': 'open',
        'acceptedByTeacherId': FieldValue.delete(),
        'acceptedAt': FieldValue.delete(),
        'teacherSelectedTimes': FieldValue.delete(),
        'closedReason': FieldValue.delete(),
        'closedAt': FieldValue.delete(),
        'revokedAt': FieldValue.serverTimestamp(),
        'revokedByAdminId': FirebaseAuth.instance.currentUser?.uid,
      });
      
      // 2. Reset enrollment status to broadcasted
      if (enrollmentId != null && enrollmentId.isNotEmpty) {
        final currentUser = FirebaseAuth.instance.currentUser;
        String? adminName;
        if (currentUser != null) {
          try {
            final adminDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
            if (adminDoc.exists) {
              final data = adminDoc.data() as Map<String, dynamic>;
              adminName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
              if (adminName.isEmpty) adminName = data['e-mail'] as String?;
            }
          } catch (_) {
            adminName = currentUser.email;
          }
        }
        
        final revokeEntry = {
          'action': 'admin_revoked',
          'status': 'broadcasted',
          'adminId': currentUser?.uid ?? 'system',
          'adminName': adminName ?? 'Admin',
          'adminEmail': currentUser?.email ?? '',
          'previousTeacherId': previousTeacherId,
          'timestamp': Timestamp.fromDate(DateTime.now()),
        };
        
        await FirebaseFirestore.instance
            .collection('enrollments')
            .doc(enrollmentId)
            .update({
          'metadata.status': 'broadcasted',
          'metadata.matchedTeacherId': FieldValue.delete(),
          'metadata.matchedTeacherName': FieldValue.delete(),
          'metadata.matchedAt': FieldValue.delete(),
          'metadata.teacherSelectedTimes': FieldValue.delete(),
          'metadata.lastUpdated': FieldValue.serverTimestamp(),
          'metadata.updatedBy': currentUser?.uid,
          'metadata.updatedByName': adminName,
          'metadata.actionHistory': FieldValue.arrayUnion([revokeEntry]),
        });
      }
      
      AppLogger.info('Admin revoked acceptance for job $jobId. Job re-broadcasted.');
    } catch (e) {
      AppLogger.error('Error revoking acceptance: $e');
      throw Exception('Failed to revoke acceptance: $e');
    }
  }

  /// Admin closes the job without re-broadcasting (like archive: opportunity is closed for good).
  /// The job disappears from filled list and is not offered to teachers again.
  Future<void> adminCloseJob(String jobId) async {
    try {
      final jobDoc = await _jobCollection.doc(jobId).get();
      if (!jobDoc.exists) throw Exception('Job not found');

      final jobData = jobDoc.data() as Map<String, dynamic>;
      final enrollmentId = jobData['enrollmentId'] as String?;
      final previousTeacherId = jobData['acceptedByTeacherId'];
      final currentUser = FirebaseAuth.instance.currentUser;

      // 1. Close job and clear acceptance fields (no re-broadcast)
      await _jobCollection.doc(jobId).update({
        'status': 'closed',
        'acceptedByTeacherId': FieldValue.delete(),
        'acceptedAt': FieldValue.delete(),
        'teacherSelectedTimes': FieldValue.delete(),
        'closedByAdminAt': FieldValue.serverTimestamp(),
        'closedByAdminId': currentUser?.uid,
      });

      // 2. Add audit entry on enrollment
      if (enrollmentId != null && enrollmentId.isNotEmpty) {
        String? adminName;
        if (currentUser != null) {
          try {
            final adminDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
            if (adminDoc.exists) {
              final data = adminDoc.data() as Map<String, dynamic>;
              adminName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
              if (adminName.isEmpty) adminName = data['e-mail'] as String?;
            }
          } catch (_) {
            adminName = currentUser.email;
          }
        }
        final closeEntry = {
          'action': 'admin_closed',
          'jobId': jobId,
          'adminId': currentUser?.uid ?? 'system',
          'adminName': adminName ?? 'Admin',
          'adminEmail': currentUser?.email ?? '',
          'previousTeacherId': previousTeacherId,
          'timestamp': Timestamp.fromDate(DateTime.now()),
        };
        await FirebaseFirestore.instance
            .collection('enrollments')
            .doc(enrollmentId)
            .update({
          'metadata.lastUpdated': FieldValue.serverTimestamp(),
          'metadata.updatedBy': currentUser?.uid,
          'metadata.updatedByName': adminName,
          'metadata.actionHistory': FieldValue.arrayUnion([closeEntry]),
        });
      }

      AppLogger.info('Admin closed job $jobId (no re-broadcast).');
    } catch (e) {
      AppLogger.error('Error closing job: $e');
      throw Exception('Failed to close job: $e');
    }
  }

  /// Allows a teacher to withdraw from an accepted job directly (No Cloud Function)
  /// Uses a Firestore WriteBatch to ensure all updates happen atomically.
  Future<void> withdrawFromJob(String jobId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to withdraw from a job.');
    }

    try {
      final db = FirebaseFirestore.instance;
      
      // 1. Get the Job Data to verify ownership
      final jobRef = db.collection('job_board').doc(jobId);
      final jobSnapshot = await jobRef.get();
      
      if (!jobSnapshot.exists) {
        throw Exception('Job not found');
      }
      
      final jobData = jobSnapshot.data() as Map<String, dynamic>;
      
      // SECURITY CHECK: Ensure the current user is actually the one who accepted it
      if (jobData['acceptedByTeacherId'] != user.uid) {
        throw Exception('You can only withdraw from jobs you accepted.');
      }

      // Check job status
      if (jobData['status'] != 'accepted') {
        throw Exception('Can only withdraw from accepted jobs');
      }

      // 2. Prepare Data
      final enrollmentId = jobData['enrollmentId'] as String;
      final enrollmentRef = db.collection('enrollments').doc(enrollmentId);
      
      // Get teacher name safely
      String teacherName = 'Teacher';
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        teacherName = user.displayName!;
      } else {
        // Try to fetch from user profile
        try {
          final userDoc = await db.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final firstName = userData['first_name'] as String? ?? '';
            final lastName = userData['last_name'] as String? ?? '';
            final fullName = '$firstName $lastName'.trim();
            if (fullName.isNotEmpty) {
              teacherName = fullName;
            } else {
              teacherName = user.email ?? 'Teacher (${user.uid.substring(0, 8)})';
            }
          } else {
            teacherName = user.email ?? 'Teacher (${user.uid.substring(0, 8)})';
          }
        } catch (_) {
          teacherName = user.email ?? 'Teacher (${user.uid.substring(0, 8)})';
        }
      }

      // 3. START BATCH (Atomic Operation)
      final batch = db.batch();

      // --- A. Update Job Board (Re-open) ---
      batch.update(jobRef, {
        'status': 'open',
        'acceptedByTeacherId': FieldValue.delete(),
        'acceptedAt': FieldValue.delete(),
        'teacherSelectedTimes': FieldValue.delete(), // Clear teacher times
        'withdrawnAt': FieldValue.serverTimestamp(),
        'withdrawnByTeacherId': user.uid,
        'withdrawalHistory': FieldValue.arrayUnion([{
          'teacherId': user.uid,
          'teacherName': teacherName,
          'withdrawnAt': Timestamp.fromDate(DateTime.now()),
        }]),
      });

      // --- B. Update Enrollment (Reset Status) ---
      batch.update(enrollmentRef, {
        'metadata.status': 'broadcasted',
        'metadata.matchedTeacherId': FieldValue.delete(),
        'metadata.matchedTeacherName': FieldValue.delete(),
        'metadata.matchedAt': FieldValue.delete(),
        'metadata.teacherSelectedTimes': FieldValue.delete(),
        'metadata.lastWithdrawnBy': user.uid,
        'metadata.lastWithdrawnAt': FieldValue.serverTimestamp(),
        'metadata.actionHistory': FieldValue.arrayUnion([{
          'action': 'teacher_withdrawn',
          'status': 'broadcasted',
          'teacherId': user.uid,
          'teacherName': teacherName,
          'timestamp': Timestamp.fromDate(DateTime.now()),
        }]),
      });

      // --- C. Create Admin Notification ---
      final notifRef = db.collection('admin_notifications').doc();
      batch.set(notifRef, {
        'type': 'job_withdrawn',
        'jobId': jobId,
        'teacherId': user.uid,
        'teacherName': teacherName,
        'enrollmentId': enrollmentId,
        'studentName': jobData['studentName'] ?? 'Student',
        'subject': jobData['subject'] ?? 'Subject',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'message': '$teacherName has withdrawn from teaching ${jobData['studentName'] ?? 'Student'}. Job is now open again.',
        'action_required': false,
      });

      // 4. Commit all changes at once
      await batch.commit();

      AppLogger.info('Successfully withdrew from job $jobId via direct Firestore batch.');
      
    } on FirebaseException catch (e) {
      AppLogger.error('Error withdrawing from job: $e');
      
      // Handle Permission Denied specifically
      if (e.code == 'permission-denied') {
         throw Exception('Permission denied. Please ask Admin to check Firestore Rules for "enrollments" and "job_board".');
      }
      if (e.code == 'not-found') {
        throw Exception('Job or enrollment not found.');
      }
      throw Exception('Failed to withdraw: ${e.message ?? e.code}');
    } catch (e) {
      AppLogger.error('Error withdrawing from job: $e');
      
      if (e.toString().toLowerCase().contains('permission-denied')) {
        throw Exception('Permission denied. Please ask Admin to check Firestore Rules.');
      }
      throw Exception('Failed to withdraw from job: $e');
    }
  }

  /// Get jobs accepted by current teacher (for "My Accepted Jobs" view)
  Stream<List<JobOpportunity>> getMyAcceptedJobs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);
    
    return _jobCollection
        .where('status', isEqualTo: 'accepted')
        .where('acceptedByTeacherId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobOpportunity.fromFirestore(doc))
              .toList();
          jobs.sort((a, b) {
            if (a.acceptedAt == null && b.acceptedAt == null) return 0;
            if (a.acceptedAt == null) return 1;
            if (b.acceptedAt == null) return -1;
            return b.acceptedAt!.compareTo(a.acceptedAt!);
          });
          return jobs;
        });
  }

  /// Get stream of open jobs
  Stream<List<JobOpportunity>> getOpenJobs() {
    return _jobCollection
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobOpportunity.fromFirestore(doc))
              .toList();
          // Sort by createdAt in descending order (newest first)
          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return jobs;
        });
  }

  /// Get stream of all jobs (open + accepted) for teachers to see filled opportunities
  Stream<List<JobOpportunity>> getAllJobs() {
    final user = FirebaseAuth.instance.currentUser;
    AppLogger.info('JobBoardService.getAllJobs: Current user UID: ${user?.uid}, email: ${user?.email}');
    
    if (user == null) {
      AppLogger.error('JobBoardService.getAllJobs: No authenticated user!');
      return Stream.value([]);
    }
    
    return _jobCollection
        .snapshots()
        .handleError((error) {
          AppLogger.error('JobBoardService.getAllJobs error: $error');
        })
        .map((snapshot) {
          AppLogger.info('JobBoardService.getAllJobs: Received ${snapshot.docs.length} jobs');
          final jobs = snapshot.docs
              .map((doc) => JobOpportunity.fromFirestore(doc))
              .toList();
          // Sort by createdAt in descending order (newest first)
          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return jobs;
        });
  }

  /// One-time fetch of jobs accepted by a specific teacher (for conflict detection).
  Future<List<JobOpportunity>> getAcceptedJobsForTeacher(String teacherId) async {
    try {
      final snap = await _jobCollection
          .where('status', isEqualTo: 'accepted')
          .where('acceptedByTeacherId', isEqualTo: teacherId)
          .get();
      return snap.docs.map((d) => JobOpportunity.fromFirestore(d)).toList();
    } catch (e) {
      AppLogger.error('JobBoardService.getAcceptedJobsForTeacher: $e');
      return [];
    }
  }

  /// Get stream of accepted jobs for admin
  Stream<List<JobOpportunity>> getAcceptedJobs() {
    return _jobCollection
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobOpportunity.fromFirestore(doc))
              .toList();
          // Sort by acceptedAt in descending order (newest first)
          jobs.sort((a, b) {
            if (a.acceptedAt == null && b.acceptedAt == null) return 0;
            if (a.acceptedAt == null) return 1;
            if (b.acceptedAt == null) return -1;
            return b.acceptedAt!.compareTo(a.acceptedAt!);
          });
          return jobs;
        });
  }
}

