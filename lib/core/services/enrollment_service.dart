import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enrollment_request.dart';

class EnrollmentService {
  final CollectionReference _collection = 
      FirebaseFirestore.instance.collection('enrollments');

  Future<void> submitEnrollment(EnrollmentRequest request) async {
    try {
      await _collection.add(request.toMap());
    } catch (e) {
      throw Exception('Failed to submit enrollment: $e');
    }
  }
}

