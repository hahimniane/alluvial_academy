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
  
  /// Submit multiple enrollments for Parent/Guardian with multiple students
  /// Each student gets their own enrollment record but linked to the same parent
  Future<List<String>> submitMultipleEnrollments({
    required String parentName,
    required String email,
    required String phoneNumber,
    required String countryCode,
    required String countryName,
    required String city,
    required String whatsAppNumber,
    required String timeZone,
    required String preferredLanguage,
    required String role,
    required String? guardianId,
    required List<StudentInfo> students,
  }) async {
    final List<String> enrollmentIds = [];
    final String parentLinkId = DateTime.now().millisecondsSinceEpoch.toString();
    
    try {
      // Create individual enrollment for each student
      for (int i = 0; i < students.length; i++) {
        final student = students[i];
        
        final enrollmentData = {
          'subject': student.subject,
          'specificLanguage': student.specificLanguage,
          'gradeLevel': student.level ?? '',
          'contact': {
            'email': email,
            'phone': phoneNumber,
            'country': {'code': countryCode, 'name': countryName},
            'parentName': parentName,
            'city': city,
            'whatsApp': whatsAppNumber,
            if (guardianId != null) 'guardianId': guardianId,
          },
          'preferences': {
            'days': student.preferredDays ?? [],
            'timeSlots': student.preferredTimeSlots ?? [],
            'timeZone': timeZone,
            'preferredLanguage': preferredLanguage,
            'timeOfDayPreference': student.timeOfDayPreference,
          },
          'student': {
            'name': student.name,
            'age': student.age,
            if (student.gender != null) 'gender': student.gender,
          },
          'program': {
            'role': role,
            'classType': student.classType,
            'sessionDuration': student.sessionDuration,
          },
          'metadata': {
            'status': 'pending',
            'submittedAt': FieldValue.serverTimestamp(),
            'requiresApproval': true,
            'source': 'web_landing_page',
            'isAdult': false,
            // Link all students from same submission
            'parentLinkId': parentLinkId,
            'studentIndex': i,
            'totalStudents': students.length,
          },
        };
        
        final docRef = await _collection.add(enrollmentData);
        enrollmentIds.add(docRef.id);
      }
      
      return enrollmentIds;
    } catch (e) {
      throw Exception('Failed to submit enrollments: $e');
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

