import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/services/form_draft_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Debug screen to help diagnose Firestore draft issues
class DebugFirestoreScreen extends StatefulWidget {
  const DebugFirestoreScreen({super.key});

  @override
  State<DebugFirestoreScreen> createState() => _DebugFirestoreScreenState();
}

class _DebugFirestoreScreenState extends State<DebugFirestoreScreen> {
  final FormDraftService _draftService = FormDraftService();
  String _debugOutput = 'Ready to run tests...\n';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.debugFirestoreDrafts,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: _runBasicTests,
                  child: Text(AppLocalizations.of(context)!.runBasicTests),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _testDraftCreation,
                  child: Text(AppLocalizations.of(context)!.testDraftCreation),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _clearOutput,
                  child: Text(AppLocalizations.of(context)!.commonClear),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugOutput,
                    style: GoogleFonts.sourceCodePro(fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearOutput() {
    setState(() {
      _debugOutput = 'Ready to run tests...\n';
    });
  }

  void _log(String message) {
    setState(() {
      _debugOutput += '${DateTime.now().toIso8601String()}: $message\n';
    });
  }

  Future<void> _runBasicTests() async {
    _log('=== STARTING BASIC TESTS ===');

    // Test 1: Check authentication
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _log('❌ ERROR: No authenticated user');
      return;
    }
    _log('✅ Authenticated user: ${user.uid}');
    _log('   Email: ${user.email}');

    // Test 2: Test Firestore connection
    _log('Testing Firestore connection...');
    try {
      final connectionTest = await _draftService.testConnection();
      _log(connectionTest
          ? '✅ Firestore connection successful'
          : '❌ Firestore connection failed');
    } catch (e) {
      _log('❌ Firestore connection error: $e');
    }

    // Test 3: Check collection access
    _log('Testing collection access...');
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('form_drafts').limit(1).get();
      _log('✅ Can access form_drafts collection');
      _log('   Documents found: ${snapshot.docs.length}');
    } catch (e) {
      _log('❌ Collection access error: $e');
    }

    // Test 4: Check user-specific query
    _log('Testing user-specific query...');
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('form_drafts')
          .where('createdBy', isEqualTo: user.uid)
          .limit(1)
          .get();
      _log('✅ User query successful');
      _log('   User documents found: ${snapshot.docs.length}');
    } catch (e) {
      _log('❌ User query error: $e');
      if (e.toString().contains('index')) {
        _log(
            '⚠️  This might be an index issue. Check Firestore console for index creation.');
      }
    }

    // Test 5: Check ordered query (this might need an index)
    _log('Testing ordered query (potential index issue)...');
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('form_drafts')
          .where('createdBy', isEqualTo: user.uid)
          .orderBy('lastModifiedAt', descending: true)
          .limit(1)
          .get();
      _log('✅ Ordered query successful');
      _log('   User documents found: ${snapshot.docs.length}');
    } catch (e) {
      _log('❌ Ordered query error: $e');
      if (e.toString().contains('index') ||
          e.toString().contains('requires an index')) {
        _log(
            '🔥 INDEX REQUIRED: You need to create a composite index in Firestore!');
        _log('   Collection: form_drafts');
        _log('   Fields: createdBy (Ascending), lastModifiedAt (Descending)');
        _log(
            '   Go to: https://console.firebase.google.com/ → Your Project → Firestore → Indexes');
      }
    }

    // Test 6: Test draft service stream
    _log('Testing draft service stream...');
    try {
      final streamTest = _draftService.getUserDrafts();
      final firstValue = await streamTest.first;
      _log('✅ Draft service stream successful');
      _log('   Drafts found: ${firstValue.length}');
    } catch (e) {
      _log('❌ Draft service stream error: $e');
    }

    _log('=== BASIC TESTS COMPLETED ===');
  }

  Future<void> _testDraftCreation() async {
    _log('=== TESTING DRAFT CREATION ===');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _log('❌ ERROR: No authenticated user');
      return;
    }

    try {
      // Create a test draft
      _log('Creating test draft...');
      final draftId = await _draftService.saveDraft(
        title: 'Test Draft ${DateTime.now().millisecondsSinceEpoch}',
        description: 'This is a test draft for debugging',
        fields: {
          'testField1': {
            'type': 'text',
            'label': 'Test Field',
            'required': false,
          }
        },
      );
      _log('✅ Test draft created with ID: $draftId');

      // Try to retrieve the draft
      _log('Retrieving test draft...');
      final retrievedDraft = await _draftService.getDraft(draftId);
      if (retrievedDraft != null) {
        _log('✅ Test draft retrieved successfully');
        _log('   Title: ${retrievedDraft.title}');
        _log('   Fields count: ${retrievedDraft.fields.length}');
      } else {
        _log('❌ Failed to retrieve test draft');
      }

      // Clean up - delete the test draft
      _log('Cleaning up test draft...');
      await _draftService.deleteDraft(draftId);
      _log('✅ Test draft cleaned up');
    } catch (e) {
      _log('❌ Draft creation test error: $e');
    }

    _log('=== DRAFT CREATION TEST COMPLETED ===');
  }
}
