import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enrollment_request.dart';
import '../models/job_opportunity.dart';

class JobBoardService {
  final CollectionReference _jobCollection = 
      FirebaseFirestore.instance.collection('job_board');
  final CollectionReference _enrollmentCollection = 
      FirebaseFirestore.instance.collection('enrollments');

  /// Creates a new job opportunity from an enrollment request
  Future<void> broadcastEnrollment(EnrollmentRequest enrollment) async {
    if (enrollment.id == null) throw Exception('Enrollment ID is missing');

    final jobData = {
      'enrollmentId': enrollment.id,
      'studentName': enrollment.studentName,
      'studentAge': enrollment.studentAge,
      'subject': enrollment.subject ?? 'General',
      'gradeLevel': enrollment.gradeLevel,
      'days': enrollment.preferredDays,
      'timeSlots': enrollment.preferredTimeSlots,
      'timeZone': enrollment.timeZone,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // 1. Create Job
    await _jobCollection.add(jobData);

    // 2. Update Enrollment Status
    await _enrollmentCollection.doc(enrollment.id).update({
      'metadata.status': 'broadcasted',
      'metadata.broadcastedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Allows a teacher to accept a job
  Future<void> acceptJob(String jobId, String teacherId) async {
    final jobDoc = await _jobCollection.doc(jobId).get();
    if (!jobDoc.exists) throw Exception('Job not found');
    
    final jobData = jobDoc.data() as Map<String, dynamic>;
    if (jobData['status'] != 'open') throw Exception('Job is no longer open');

    final enrollmentId = jobData['enrollmentId'];

    // Transaction to ensure atomicity
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // 1. Update Job Status
      transaction.update(_jobCollection.doc(jobId), {
        'status': 'accepted',
        'acceptedByTeacherId': teacherId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Enrollment Status
      transaction.update(_enrollmentCollection.doc(enrollmentId), {
        'metadata.status': 'matched',
        'metadata.matchedTeacherId': teacherId,
        'metadata.matchedAt': FieldValue.serverTimestamp(),
      });
      
      // 3. Create Notification for Admin (Stub - usually cloud function or here)
      final notificationRef = FirebaseFirestore.instance.collection('admin_notifications').doc();
      transaction.set(notificationRef, {
        'type': 'job_accepted',
        'jobId': jobId,
        'teacherId': teacherId,
        'enrollmentId': enrollmentId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'message': 'A teacher has accepted a new student request.',
      });
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
    return _jobCollection
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

