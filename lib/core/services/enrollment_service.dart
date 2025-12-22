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
    // Validate identifier before calling function
    final trimmedIdentifier = identifier.trim();
    if (trimmedIdentifier.isEmpty) {
      print('⚠️ checkParentIdentity: Empty identifier provided');
      return null;
    }
    
    print('🔍 checkParentIdentity: Looking up identifier: "$trimmedIdentifier" (length: ${trimmedIdentifier.length})');
    
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('findUserByEmailOrCode')
          .call({'identifier': trimmedIdentifier});
      
      final data = result.data as Map<String, dynamic>;
      if (data['found'] == true) {
        print('✅ checkParentIdentity: Found user: ${data['firstName']} ${data['lastName']}');
        return data;
      }
      print('❌ checkParentIdentity: User not found');
      return null;
    } on FirebaseFunctionsException catch (e) {
      // Handle Firebase Functions errors safely
      final errorMessage = e.message ?? e.code ?? 'Firebase Functions error';
      final errorDetails = e.details?.toString() ?? '';
      print('❌ Error checking parent identity: $errorMessage');
      if (errorDetails.isNotEmpty) {
        print('   Details: $errorDetails');
      }
      return null;
    } catch (e) {
      // Handle any other errors safely - extract only the message
      try {
        final errorMessage = e.toString().split(':').last.trim();
        print('❌ Error checking parent identity: $errorMessage');
      } catch (_) {
        print('❌ Error checking parent identity: Unknown error occurred');
      }
      return null;
    }
  }
}

