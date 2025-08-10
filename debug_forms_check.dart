import 'dart:async';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

// Temporary debug script to check what's in the database
// You can add this to any screen to debug the form data
Future<void> debugFormData() async {
  print('🔍 DEBUGGING FORM DATA...');

  try {
    // Check forms collection
    print('\n📝 CHECKING FORMS COLLECTION:');
    final formsSnapshot =
        await FirebaseFirestore.instance.collection('form').get();

    print('Total forms found: ${formsSnapshot.docs.length}');

    for (var doc in formsSnapshot.docs) {
      final data = doc.data();
      print('Form ${doc.id}:');
      print('  - title: ${data['title']}');
      print('  - status: ${data['status']}');
      print('  - createdBy: ${data['createdBy']}');
      print('  - createdAt: ${data['createdAt']}');
    }

    // Check form_responses collection
    print('\n📋 CHECKING FORM_RESPONSES COLLECTION:');
    final responsesSnapshot =
        await FirebaseFirestore.instance.collection('form_responses').get();

    print('Total responses found: ${responsesSnapshot.docs.length}');

    for (var doc in responsesSnapshot.docs) {
      final data = doc.data();
      print('Response ${doc.id}:');
      print('  - formId: ${data['formId']}');
      print('  - userEmail: ${data['userEmail']}');
      print('  - status: ${data['status']}');
      print('  - submittedAt: ${data['submittedAt']}');
      print('  - userId: ${data['userId']}');

      // Check if corresponding form exists
      final formExists =
          formsSnapshot.docs.any((formDoc) => formDoc.id == data['formId']);
      print('  - Has corresponding form: $formExists');
    }

    // Check if there are any active forms
    final activeFormsSnapshot = await FirebaseFirestore.instance
        .collection('form')
        .where('status', isEqualTo: 'active')
        .get();

    print('\n✅ ACTIVE FORMS: ${activeFormsSnapshot.docs.length}');
    for (var doc in activeFormsSnapshot.docs) {
      final data = doc.data();
      print('Active form ${doc.id}: ${data['title']}');
    }
  } catch (e) {
    print('❌ ERROR: $e');
  }

  print('🔍 DEBUG COMPLETE\n');
}
