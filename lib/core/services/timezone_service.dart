import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/timezone_utils.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class _ResolvedUserDoc {
  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> data;

  const _ResolvedUserDoc(this.ref, this.data);
}

class TimezoneService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _usersCollection = 'users';

  static Future<_ResolvedUserDoc?> _resolveCurrentUserDoc() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    final users = _firestore.collection(_usersCollection);

    // 1) Prefer UID document (best for security rules + direct lookups).
    final uidDoc = await users.doc(currentUser.uid).get();
    final uidData = uidDoc.data();
    if (uidDoc.exists && uidData != null) {
      return _ResolvedUserDoc(uidDoc.reference, uidData);
    }

    // 2) Fallback: query by stored uid field (covers legacy/non-UID doc IDs).
    final uidQuery =
        await users.where('uid', isEqualTo: currentUser.uid).limit(1).get();
    if (uidQuery.docs.isNotEmpty) {
      final doc = uidQuery.docs.first;
      return _ResolvedUserDoc(doc.reference, doc.data());
    }

    // 3) Legacy fallback: query by email (covers older schemas).
    final email = currentUser.email?.toLowerCase();
    if (email == null) return null;

    final emailQuery =
        await users.where('e-mail', isEqualTo: email).limit(1).get();
    if (emailQuery.docs.isNotEmpty) {
      final doc = emailQuery.docs.first;
      return _ResolvedUserDoc(doc.reference, doc.data());
    }

    return null;
  }

  /// Update user timezone on login if different from stored value
  static Future<void> updateUserTimezoneOnLogin() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Detect current timezone
      final detectedTimezone = await TimezoneUtils.detectUserTimezone();

      final resolved = await _resolveCurrentUserDoc();
      if (resolved == null) return;

      final storedTimezone = resolved.data['timezone'];

      // Update if timezone is different or not set
      if (storedTimezone != detectedTimezone) {
        await resolved.ref.update({
          'timezone': detectedTimezone,
          'timezone_last_updated': FieldValue.serverTimestamp(),
        });
        AppLogger.debug(
            'TimezoneService: updated user timezone from $storedTimezone to $detectedTimezone');
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        AppLogger.debug(
            'TimezoneService: skipping timezone update (permission denied)');
        return;
      }
      AppLogger.error('TimezoneService: error updating user timezone: $e');
    } catch (e) {
      AppLogger.error('TimezoneService: error updating user timezone: $e');
    }
  }

  /// Get user timezone by user ID
  static Future<String?> getUserTimezone(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['timezone'] as String?;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        AppLogger.debug(
            'TimezoneService: cannot read user timezone (permission denied)');
        return null;
      }
      AppLogger.error('TimezoneService: error getting user timezone: $e');
      return null;
    } catch (e) {
      AppLogger.error('TimezoneService: error getting user timezone: $e');
      return null;
    }
  }

  /// Get current user's timezone
  static Future<String> getCurrentUserTimezone() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return await TimezoneUtils.detectUserTimezone();
      }

      final resolved = await _resolveCurrentUserDoc();
      final storedTimezone = resolved?.data['timezone'];
      if (storedTimezone is String && storedTimezone.isNotEmpty) {
        return storedTimezone;
      }

      return await TimezoneUtils.detectUserTimezone();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return await TimezoneUtils.detectUserTimezone();
      }
      AppLogger.error('TimezoneService: error getting current user timezone: $e');
      return await TimezoneUtils.detectUserTimezone();
    } catch (e) {
      AppLogger.error('TimezoneService: error getting current user timezone: $e');
      return await TimezoneUtils.detectUserTimezone();
    }
  }
}
