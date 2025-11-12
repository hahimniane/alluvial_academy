import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
// Simple debugging script to check form data in Firestore
// Run this in the console to check what data exists

Future<void> debugFormData() async {
  try {
    AppLogger.debug('=== DEBUGGING FORM DATA ===');
    
    // Check form templates
    AppLogger.debug('\n1. Checking form templates...');
    final formsSnapshot = await FirebaseFirestore.instance
        .collection('form')
        .get();
    
    AppLogger.debug('Total forms in collection: ${formsSnapshot.docs.length}');
    
    for (var doc in formsSnapshot.docs) {
      final data = doc.data();
      AppLogger.debug('Form ${doc.id}:');
      AppLogger.debug('  - title: ${data['title'] ?? 'No title'}');
      AppLogger.debug('  - status: ${data['status'] ?? 'No status'}');
      AppLogger.debug('  - createdBy: ${data['createdBy'] ?? 'Unknown'}');
      AppLogger.debug('  - createdAt: ${data['createdAt']}');
    }
    
    // Check active forms only
    AppLogger.debug('\n2. Checking ACTIVE form templates...');
    final activeFormsSnapshot = await FirebaseFirestore.instance
        .collection('form')
        .where('status', isEqualTo: 'active')
        .get();
    
    AppLogger.debug('Active forms: ${activeFormsSnapshot.docs.length}');
    
    // Check form responses
    AppLogger.debug('\n3. Checking form responses...');
    final responsesSnapshot = await FirebaseFirestore.instance
        .collection('form_responses')
        .get();
    
    AppLogger.debug('Total form responses: ${responsesSnapshot.docs.length}');
    
    for (var doc in responsesSnapshot.docs) {
      final data = doc.data();
      AppLogger.debug('Response ${doc.id}:');
      AppLogger.debug('  - formId: ${data['formId']}');
      AppLogger.debug('  - userEmail: ${data['userEmail']}');
      AppLogger.debug('  - status: ${data['status']}');
      AppLogger.debug('  - submittedAt: ${data['submittedAt']}');
    }
    
    // Check users collection
    AppLogger.debug('\n4. Checking users...');
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .limit(5) // Just first 5 for debugging
        .get();
    
    AppLogger.debug('Sample users (first 5): ${usersSnapshot.docs.length}');
    
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      AppLogger.debug('User ${doc.id}:');
      AppLogger.debug('  - email: ${data['e-mail'] ?? data['email'] ?? 'No email'}');
      AppLogger.debug('  - user_type: ${data['user_type'] ?? 'No role'}');
      AppLogger.debug('  - name: ${data['first_name'] ?? ''} ${data['last_name'] ?? ''}');
    }
    
    AppLogger.debug('\n=== DEBUG COMPLETE ===');
    
  } catch (e) {
    AppLogger.debug('ERROR in debugging: $e');
  }
}

// Usage: Call this function from your app's debug console or add it temporarily to a screen