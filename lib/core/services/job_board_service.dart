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
      };
      
      // Remove null values
      jobData.removeWhere((key, value) => value == null);
      
      AppLogger.info('Creating job opportunity with data: ${jobData.keys.join(", ")}');
      AppLogger.info('Student details: name=${jobData['studentName']}, age=${jobData['studentAge']}, subject=${jobData['subject']}');
      
      final jobRef = await _jobCollection.add(jobData);
      AppLogger.info('Created job opportunity: ${jobRef.id}');
      
      // 6. Update enrollment status
      await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(enrollment.id)
          .update({
        'metadata.status': 'broadcasted',
        'metadata.broadcastedAt': FieldValue.serverTimestamp(),
        'metadata.jobId': jobRef.id,
      });
      
      AppLogger.info('Successfully broadcasted enrollment ${enrollment.id}, jobId: ${jobRef.id}');
    } catch (e) {
      final errorMessage = e.toString();
      AppLogger.error('Error broadcasting enrollment: $errorMessage');
      throw Exception('Failed to broadcast enrollment: $errorMessage');
    }
  }

  /// Allows a teacher to accept a job (via Cloud Function)
  Future<void> acceptJob(String jobId, String teacherId) async {
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

