#!/usr/bin/env dart
// Script to clean up orphaned timesheet entries (where the shift no longer exists)
// Run with: dart run scripts/cleanup_orphaned_timesheets.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart' as firebase_options;

Future<void> main() async {
  print('🔧 Orphaned Timesheet Cleanup Script');
  print('=====================================\n');

  try {
    // Initialize Firebase
    print('📡 Initializing Firebase...');
    await Firebase.initializeApp(
      options: firebase_options.DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized\n');

    final firestore = FirebaseFirestore.instance;
    final timesheetCollection = firestore.collection('timesheet_entries');
    final shiftsCollection = firestore.collection('teaching_shifts');

    // Get all timesheet entries
    print('📋 Fetching all timesheet entries...');
    final timesheetSnapshot = await timesheetCollection.get();
    print('   Found ${timesheetSnapshot.docs.length} timesheet entries\n');

    if (timesheetSnapshot.docs.isEmpty) {
      print('✅ No timesheet entries found. Nothing to clean up.');
      exit(0);
    }

    // Check each timesheet entry
    print('🔍 Checking for orphaned entries...');
    final orphanedEntries = <String, String>{}; // timesheetId -> shiftId
    int checkedCount = 0;
    int batchCount = 0;
    WriteBatch batch = firestore.batch();
    const batchSize = 500; // Firestore batch limit

    for (var doc in timesheetSnapshot.docs) {
      final data = doc.data();
      final shiftId = data['shift_id'] as String? ?? data['shiftId'] as String?;

      if (shiftId == null || shiftId.isEmpty) {
        // Timesheet without shift_id - consider it orphaned
        orphanedEntries[doc.id] = 'no_shift_id';
        batch.delete(doc.reference);
        batchCount++;
        
        // Commit batch if we reach the limit
        if (batchCount >= batchSize) {
          await batch.commit();
          print('   Committed batch of $batchCount deletions...');
          batch = firestore.batch(); // Create new batch
          batchCount = 0;
        }
        checkedCount++;
        continue;
      }

      // Check if shift exists
      final shiftDoc = await shiftsCollection.doc(shiftId).get();
      if (!shiftDoc.exists) {
        orphanedEntries[doc.id] = shiftId;
        batch.delete(doc.reference);
        batchCount++;
        
        // Commit batch if we reach the limit
        if (batchCount >= batchSize) {
          await batch.commit();
          print('   Committed batch of $batchCount deletions...');
          batch = firestore.batch(); // Create new batch
          batchCount = 0;
        }
      }

      checkedCount++;
      if (checkedCount % 100 == 0) {
        print('   Checked $checkedCount/${timesheetSnapshot.docs.length} entries...');
      }
    }

    // Commit remaining batch
    if (batchCount > 0) {
      await batch.commit();
      print('   Committed final batch of $batchCount deletions...');
    }

    print('\n📊 Cleanup Summary:');
    print('   Total entries checked: $checkedCount');
    print('   Orphaned entries found: ${orphanedEntries.length}');
    print('   Entries deleted: ${orphanedEntries.length}');

    if (orphanedEntries.isNotEmpty) {
      print('\n🗑️  Deleted orphaned timesheet IDs:');
      orphanedEntries.forEach((timesheetId, shiftId) {
        print('   - $timesheetId (shift: ${shiftId == 'no_shift_id' ? 'MISSING' : shiftId})');
      });
    }

    print('\n✅ Cleanup completed successfully!');
  } catch (e, stackTrace) {
    print('\n❌ Error during cleanup: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

