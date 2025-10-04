import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShiftWageMigration {
  static const String _migrationKey = 'shift_wage_migration_4_dollar_per_hour_completed';
  static const double _hourlyRate = 4.0; // $4 per hour

  /// Run the one-time migration to update all teacher shifts to $4 per hour
  static Future<void> runMigration() async {
    try {
      // Check if migration has already been completed
      final prefs = await SharedPreferences.getInstance();
      final hasRun = prefs.getBool(_migrationKey) ?? false;
      
      if (hasRun) {
        print('✅ Shift wage migration already completed. Skipping.');
        return;
      }

      print('🔄 Starting shift wage migration to \$$_hourlyRate per hour...');
      
      // Get all teaching shifts
      final firestore = FirebaseFirestore.instance;
      final shiftsCollection = firestore.collection('teaching_shifts');
      
      // Use batch writes for efficiency
      WriteBatch batch = firestore.batch();
      int updateCount = 0;
      int batchCount = 0;
      
      final querySnapshot = await shiftsCollection.get();
      
      print('📊 Found ${querySnapshot.docs.length} shifts to update');
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Calculate shift duration in hours
        final shiftStart = data['shift_start'] as Timestamp?;
        final shiftEnd = data['shift_end'] as Timestamp?;
        
        if (shiftStart != null && shiftEnd != null) {
          final startTime = shiftStart.toDate();
          final endTime = shiftEnd.toDate();
          final durationInHours = endTime.difference(startTime).inMinutes / 60.0;
          final wagePerShift = durationInHours * _hourlyRate;
          
          // Update both hourly rate and calculated wage per shift
          batch.update(doc.reference, {
            'hourly_rate': _hourlyRate,
            'wage_per_shift': wagePerShift,
            'wage_migration_timestamp': FieldValue.serverTimestamp(),
            'wage_migration_note': 'Migrated to \$$_hourlyRate per hour on ${DateTime.now().toIso8601String()}'
          });
          
          updateCount++;
          
          // Firestore batch limit is 500 operations
          if (updateCount % 500 == 0) {
            await batch.commit();
            batchCount++;
            print('  ✓ Batch $batchCount committed (500 shifts)');
            batch = firestore.batch(); // Start new batch
          }
        }
      }
      
      // Commit any remaining updates
      if (updateCount % 500 != 0) {
        await batch.commit();
        print('  ✓ Final batch committed (${updateCount % 500} shifts)');
      }
      
      // Mark migration as completed
      await prefs.setBool(_migrationKey, true);
      
      print('✅ Shift wage migration completed successfully!');
      print('📊 Total shifts updated: $updateCount');
      print('💵 All shifts now have hourly rate: \$$_hourlyRate per hour');
      
    } catch (e) {
      print('❌ Error during shift wage migration: $e');
      print('⚠️  Migration will retry on next app start');
    }
  }
  
  /// Check if migration has been completed
  static Future<bool> isMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationKey) ?? false;
  }
  
  /// Force reset migration (for testing only)
  static Future<void> resetMigration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationKey);
    print('🔄 Migration reset. Will run on next app start.');
  }
}
