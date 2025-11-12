import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
// Temporary debug script to check what's in the database
// You can add this to any screen to debug the form data
Future<void> debugFormData() async {
  AppLogger.debug('🔍 DEBUGGING FORM DATA...');

  try {
    // Check forms collection
    AppLogger.debug('\n📝 CHECKING FORMS COLLECTION:');
    final formsSnapshot =
        await FirebaseFirestore.instance.collection('form').get();

    AppLogger.debug('Total forms found: ${formsSnapshot.docs.length}');

    for (var doc in formsSnapshot.docs) {
      final data = doc.data();
      AppLogger.debug('Form ${doc.id}:');
      AppLogger.debug('  - title: ${data['title']}');
      AppLogger.debug('  - status: ${data['status']}');
      AppLogger.debug('  - createdBy: ${data['createdBy']}');
      AppLogger.debug('  - createdAt: ${data['createdAt']}');
    }

    // Check form_responses collection
    AppLogger.debug('\n📋 CHECKING FORM_RESPONSES COLLECTION:');
    final responsesSnapshot =
        await FirebaseFirestore.instance.collection('form_responses').get();

    AppLogger.debug('Total responses found: ${responsesSnapshot.docs.length}');

    for (var doc in responsesSnapshot.docs) {
      final data = doc.data();
      AppLogger.debug('Response ${doc.id}:');
      AppLogger.debug('  - formId: ${data['formId']}');
      AppLogger.debug('  - userEmail: ${data['userEmail']}');
      AppLogger.debug('  - status: ${data['status']}');
      AppLogger.debug('  - submittedAt: ${data['submittedAt']}');
      AppLogger.debug('  - userId: ${data['userId']}');

      // Check if corresponding form exists
      final formExists =
          formsSnapshot.docs.any((formDoc) => formDoc.id == data['formId']);
      AppLogger.debug('  - Has corresponding form: $formExists');
    }

    // Check if there are any active forms
    final activeFormsSnapshot = await FirebaseFirestore.instance
        .collection('form')
        .where('status', isEqualTo: 'active')
        .get();

    AppLogger.debug('\n✅ ACTIVE FORMS: ${activeFormsSnapshot.docs.length}');
    for (var doc in activeFormsSnapshot.docs) {
      final data = doc.data();
      AppLogger.debug('Active form ${doc.id}: ${data['title']}');
    }
  } catch (e) {
    AppLogger.debug('❌ ERROR: $e');
  }

  AppLogger.debug('🔍 DEBUG COMPLETE\n');
}
