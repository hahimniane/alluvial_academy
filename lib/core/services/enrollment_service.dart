import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/enrollment_request.dart';

class EnrollmentService {
  final CollectionReference _collection = 
      FirebaseFirestore.instance.collection('enrollments');

  Future<void> submitEnrollment(EnrollmentRequest request) async {
    try {
      // Create enrollment with "pending" status - requires admin approval to broadcast
      final data = request.toMap();
      final existingMetadata = data['metadata'] as Map<String, dynamic>? ?? {};
      
      data['metadata'] = {
        ...existingMetadata,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'requiresApproval': true,
      };
      await _collection.add(data);
    } catch (e) {
      throw Exception('Failed to submit enrollment: $e');
    }
  }

  Future<Map<String, dynamic>?> checkParentIdentity(String identifier) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('findUserByEmailOrCode')
          .call({'identifier': identifier});
      
      final data = result.data as Map<String, dynamic>;
      if (data['found'] == true) {
        return data;
      }
      return null;
    } catch (e) {
      print('Error checking parent identity: $e');
      return null;
    }
  }
}

