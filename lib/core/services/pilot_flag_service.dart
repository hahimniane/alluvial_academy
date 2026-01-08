import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';

/// Service to manage pilot/beta testing flags for specific users
/// Allows testing new features (like new form templates) on selected users
/// without impacting other users
class PilotFlagService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache to avoid repeated Firestore reads
  static bool? _cachedIsPilot;
  static String? _cachedUserId;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Pilot user for testing (Aliou Diallo)
  static const String pilotUserId = 'Thz8PIVUGpS5cjlIYBJAemjoQxw1';
  static const String pilotUserEmail = 'aliou9716@gmail.com';

  /// Check if the current user is in pilot mode
  static Future<bool> isCurrentUserPilot() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Check cache
    if (_cachedIsPilot != null &&
        _cachedUserId == user.uid &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedIsPilot!;
    }

    try {
      final configDoc = await _firestore
          .collection('settings')
          .doc('pilot_flags')
          .get();

      if (configDoc.exists) {
        final data = configDoc.data();
        final pilotUserIds = (data?['pilotEnabledForUserIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final isPilot = pilotUserIds.contains(user.uid);

        // Update cache
        _cachedIsPilot = isPilot;
        _cachedUserId = user.uid;
        _cacheTime = DateTime.now();

        AppLogger.debug(
            'PilotFlagService: User ${user.email} isPilot = $isPilot');
        return isPilot;
      }

      // No config exists, create default with Aliou as pilot
      await _createDefaultPilotConfig();
      
      final isPilot = user.uid == pilotUserId;
      _cachedIsPilot = isPilot;
      _cachedUserId = user.uid;
      _cacheTime = DateTime.now();
      
      return isPilot;
    } catch (e) {
      AppLogger.error('PilotFlagService: Error checking pilot status: $e');
      // Fallback: check hardcoded pilot user
      return user.uid == pilotUserId;
    }
  }

  /// Create default pilot config with Aliou
  static Future<void> _createDefaultPilotConfig() async {
    try {
      await _firestore.collection('settings').doc('pilot_flags').set({
        'pilotEnabledForUserIds': [pilotUserId],
        'pilotUserEmails': [pilotUserEmail],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'description':
            'Pilot flags for testing new features. Add user UIDs to pilotEnabledForUserIds to enable pilot mode.',
      });
      AppLogger.info('PilotFlagService: Created default pilot config');
    } catch (e) {
      AppLogger.error('PilotFlagService: Error creating default config: $e');
    }
  }

  /// Add a user to pilot mode (admin function)
  static Future<bool> addUserToPilot(String userId, {String? email}) async {
    try {
      await _firestore.collection('settings').doc('pilot_flags').set({
        'pilotEnabledForUserIds': FieldValue.arrayUnion([userId]),
        if (email != null) 'pilotUserEmails': FieldValue.arrayUnion([email]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Clear cache
      _clearCache();

      AppLogger.info('PilotFlagService: Added user $userId to pilot');
      return true;
    } catch (e) {
      AppLogger.error('PilotFlagService: Error adding user to pilot: $e');
      return false;
    }
  }

  /// Remove a user from pilot mode (admin function)
  static Future<bool> removeUserFromPilot(String userId, {String? email}) async {
    try {
      await _firestore.collection('settings').doc('pilot_flags').update({
        'pilotEnabledForUserIds': FieldValue.arrayRemove([userId]),
        if (email != null) 'pilotUserEmails': FieldValue.arrayRemove([email]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Clear cache
      _clearCache();

      AppLogger.info('PilotFlagService: Removed user $userId from pilot');
      return true;
    } catch (e) {
      AppLogger.error('PilotFlagService: Error removing user from pilot: $e');
      return false;
    }
  }

  /// Get all pilot users
  static Future<List<Map<String, String>>> getPilotUsers() async {
    try {
      final configDoc = await _firestore
          .collection('settings')
          .doc('pilot_flags')
          .get();

      if (!configDoc.exists) return [];

      final data = configDoc.data();
      final userIds = (data?['pilotEnabledForUserIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final emails = (data?['pilotUserEmails'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      return List.generate(
        userIds.length,
        (i) => {
          'userId': userIds[i],
          'email': i < emails.length ? emails[i] : '',
        },
      );
    } catch (e) {
      AppLogger.error('PilotFlagService: Error getting pilot users: $e');
      return [];
    }
  }

  /// Clear the cache (useful after config updates)
  static void _clearCache() {
    _cachedIsPilot = null;
    _cachedUserId = null;
    _cacheTime = null;
  }

  /// Force clear cache (public)
  static void clearCache() => _clearCache();
}

