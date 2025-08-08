import 'package:cloud_firestore/cloud_firestore.dart';

// Simple debugging script to check form data in Firestore
// Run this in the console to check what data exists

Future<void> debugFormData() async {
  try {
    print('=== DEBUGGING FORM DATA ===');
    
    // Check form templates
    print('\n1. Checking form templates...');
    final formsSnapshot = await FirebaseFirestore.instance
        .collection('form')
        .get();
    
    print('Total forms in collection: ${formsSnapshot.docs.length}');
    
    for (var doc in formsSnapshot.docs) {
      final data = doc.data();
      print('Form ${doc.id}:');
      print('  - title: ${data['title'] ?? 'No title'}');
      print('  - status: ${data['status'] ?? 'No status'}');
      print('  - createdBy: ${data['createdBy'] ?? 'Unknown'}');
      print('  - createdAt: ${data['createdAt']}');
    }
    
    // Check active forms only
    print('\n2. Checking ACTIVE form templates...');
    final activeFormsSnapshot = await FirebaseFirestore.instance
        .collection('form')
        .where('status', isEqualTo: 'active')
        .get();
    
    print('Active forms: ${activeFormsSnapshot.docs.length}');
    
    // Check form responses
    print('\n3. Checking form responses...');
    final responsesSnapshot = await FirebaseFirestore.instance
        .collection('form_responses')
        .get();
    
    print('Total form responses: ${responsesSnapshot.docs.length}');
    
    for (var doc in responsesSnapshot.docs) {
      final data = doc.data();
      print('Response ${doc.id}:');
      print('  - formId: ${data['formId']}');
      print('  - userEmail: ${data['userEmail']}');
      print('  - status: ${data['status']}');
      print('  - submittedAt: ${data['submittedAt']}');
    }
    
    // Check users collection
    print('\n4. Checking users...');
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .limit(5) // Just first 5 for debugging
        .get();
    
    print('Sample users (first 5): ${usersSnapshot.docs.length}');
    
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      print('User ${doc.id}:');
      print('  - email: ${data['e-mail'] ?? data['email'] ?? 'No email'}');
      print('  - user_type: ${data['user_type'] ?? 'No role'}');
      print('  - name: ${data['first_name'] ?? ''} ${data['last_name'] ?? ''}');
    }
    
    print('\n=== DEBUG COMPLETE ===');
    
  } catch (e) {
    print('ERROR in debugging: $e');
  }
}

// Usage: Call this function from your app's debug console or add it temporarily to a screen