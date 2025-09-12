import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/timezone_utils.dart';

class TimezoneService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Update user timezone on login if different from stored value
  static Future<void> updateUserTimezoneOnLogin() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) return;

      // Detect current timezone
      final detectedTimezone = TimezoneUtils.detectUserTimezone();

      // Get user document
      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: currentUser.email!.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) return;

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;
      final storedTimezone = userData['timezone'];

      // Update if timezone is different or not set
      if (storedTimezone != detectedTimezone) {
        await userDoc.reference.update({
          'timezone': detectedTimezone,
          'timezone_last_updated': FieldValue.serverTimestamp(),
        });
        print(
            'Updated user timezone from $storedTimezone to $detectedTimezone');
      }
    } catch (e) {
      print('Error updating user timezone: $e');
    }
  }

  /// Get user timezone by user ID
  static Future<String?> getUserTimezone(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['timezone'] as String?;
    } catch (e) {
      print('Error getting user timezone: $e');
      return null;
    }
  }

  /// Get current user's timezone
  static Future<String> getCurrentUserTimezone() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        return TimezoneUtils.detectUserTimezone();
      }

      final QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('e-mail', isEqualTo: currentUser.email!.toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return TimezoneUtils.detectUserTimezone();
      }

      final userData = userQuery.docs.first.data() as Map<String, dynamic>;
      return userData['timezone'] ?? TimezoneUtils.detectUserTimezone();
    } catch (e) {
      print('Error getting current user timezone: $e');
      return TimezoneUtils.detectUserTimezone();
    }
  }
}
