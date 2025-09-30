import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'app_settings';
  static const String _docId = 'global';

  /// Default global hourly rate for teachers (USD)
  static const double defaultTeacherHourlyRate = 4.0;

  /// Get the global teacher hourly rate from Firestore.
  /// Falls back to [defaultTeacherHourlyRate] if not set.
  static Future<double> getGlobalTeacherHourlyRate() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_docId).get();
      if (!doc.exists) return defaultTeacherHourlyRate;
      final data = doc.data() as Map<String, dynamic>;
      final num? raw = data['teacher_hourly_rate'] as num?;
      return (raw ?? defaultTeacherHourlyRate).toDouble();
    } catch (e) {
      print('SettingsService: Error fetching hourly rate: $e');
      return defaultTeacherHourlyRate;
    }
  }

  /// Set (create or update) the global teacher hourly rate.
  static Future<void> setGlobalTeacherHourlyRate(double rate) async {
    try {
      await _firestore.collection(_collection).doc(_docId).set({
        'teacher_hourly_rate': rate,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('SettingsService: Updated teacher hourly rate to $rate');
    } catch (e) {
      print('SettingsService: Error updating hourly rate: $e');
      rethrow;
    }
  }
}
