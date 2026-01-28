import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/enrollment_request.dart';
import '../models/job_opportunity.dart';
import '../utils/app_logger.dart';

class JobBoardService {
  final CollectionReference _jobCollection = 
      FirebaseFirestore.instance.collection('job_board');
  final CollectionReference _enrollmentCollection = 
      FirebaseFirestore.instance.collection('enrollments');

  /// Creates a new job opportunity from an enrollment request
  /// Uses direct Firestore write (bypasses Cloud Function IAM issues)
  Future<void> broadcastEnrollment(EnrollmentRequest enrollment) async {
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
      final days = List<String>.from(preferences['days'] ?? enrollmentData['preferredDays'] ?? []);
      final timeSlots = List<String>.from(preferences['timeSlots'] ?? enrollmentData['preferredTimeSlots'] ?? []);
      
      // 5. Create job opportunity directly in Firestore with all student details
      final jobData = {
        'enrollmentId': enrollment.id,
        'studentName': student['name'] ?? enrollmentData['studentName'] ?? 'Student',
        'studentAge': student['age'] ?? enrollmentData['studentAge'] ?? 'N/A',
        'gender': student['gender'] ?? enrollmentData['gender'] ?? 'Not specified',
        'subject': enrollmentData['subject'] ?? 'General',
        'specificLanguage': enrollmentData['specificLanguage'],
        'gradeLevel': enrollmentData['gradeLevel'] ?? '',
        'days': days,
        'timeSlots': timeSlots,
        'timeZone': preferences['timeZone'] ?? enrollmentData['timeZone'] ?? 'UTC',
        'sessionDuration': program['sessionDuration'] ?? enrollmentData['sessionDuration'] ?? '60 minutes',
        'timeOfDayPreference': preferences['timeOfDayPreference'] ?? enrollmentData['timeOfDayPreference'],
        'countryName': country['name'] ?? enrollmentData['countryName'] ?? '',
        'countryCode': country['code'] ?? enrollmentData['countryCode'] ?? '',
        'city': contact['city'] ?? enrollmentData['city'] ?? '',
        'classType': program['classType'] ?? enrollmentData['classType'],
        'preferredLanguage': preferences['preferredLanguage'] ?? enrollmentData['preferredLanguage'],
        'knowsZoom': student['knowsZoom'] ?? enrollmentData['knowsZoom'],
        'isAdult': metadata['isAdult'] ?? enrollmentData['isAdult'] ?? false,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        // Parent/Family grouping info
        'parentEmail': contact['email'],
        'parentName': contact['parentName'],
        'parentLinkId': metadata['parentLinkId'],
        'studentIndex': metadata['studentIndex'],
        'totalStudents': metadata['totalStudents'],
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
      });
      
      AppLogger.info('Successfully broadcasted enrollment ${enrollment.id}, jobId: ${jobRef.id}');
    } catch (e) {
      final errorMessage = e.toString();
      AppLogger.error('Error broadcasting enrollment: $errorMessage');
      throw Exception('Failed to broadcast enrollment: $errorMessage');
    }
  }

  /// Allows a teacher to accept a job (via Cloud Function)
  /// [selectedTimes] is an optional map of day -> time slot selected by teacher
  Future<void> acceptJob(String jobId, String teacherId, {Map<String, String>? selectedTimes}) async {
    try {
      // Ensure user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be signed in to accept a job.');
      }
      
      // Refresh the ID token to ensure it's valid
      await user.getIdToken(true); // Force refresh
      
      // Use the correct region (us-central1) for the function call
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('acceptJob');
      
      final result = await callable.call(<String, dynamic>{
        'jobId': jobId,
        if (selectedTimes != null) 'selectedTimes': selectedTimes,
      });

      if (result.data['success'] != true) {
        throw Exception(result.data['message'] ?? 'Unknown error accepting job');
      }
      
      AppLogger.info('Successfully accepted job $jobId. Awaiting admin scheduling.');
    } catch (e) {
      AppLogger.error('Error accepting job: $e');
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

  /// Allows a teacher to withdraw from an accepted job (re-broadcasts it)
  Future<void> withdrawFromJob(String jobId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be signed in to withdraw from a job.');
      }
      
      // Refresh the ID token to ensure it's valid
      await user.getIdToken(true);
      
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('withdrawFromJob');
      
      final result = await callable.call(<String, dynamic>{
        'jobId': jobId,
      });

      if (result.data['success'] != true) {
        throw Exception(result.data['message'] ?? 'Unknown error withdrawing from job');
      }
      
      AppLogger.info('Successfully withdrew from job $jobId. Job re-broadcasted.');
    } catch (e) {
      AppLogger.error('Error withdrawing from job: $e');
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

