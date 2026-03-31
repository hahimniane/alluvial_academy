import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// Controls whether teachers can host/join classes from the native mobile app
/// (iOS/Android).
///
/// Data model:
/// - `app_settings/global.mobile_classes_allow_all_teachers` (bool)
/// - `users/<uid>.mobile_classes_enabled` (bool)
class MobileClassesAccessService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _settingsCollection = 'app_settings';
  static const String _settingsDocId = 'global';
  static const String _fieldAllowAllTeachers = 'mobile_classes_allow_all_teachers';

  static const String _usersCollection = 'users';
  static const String _fieldTeacherEnabled = 'mobile_classes_enabled';

  static Stream<bool> watchAllowAllTeachers() {
    return _firestore
        .collection(_settingsCollection)
        .doc(_settingsDocId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      return data?[_fieldAllowAllTeachers] == true;
    });
  }

  static Future<bool> getAllowAllTeachers() async {
    try {
      final doc = await _firestore
          .collection(_settingsCollection)
          .doc(_settingsDocId)
          .get();
      final data = doc.data();
      return data?[_fieldAllowAllTeachers] == true;
    } catch (e) {
      AppLogger.error('MobileClassesAccessService: Failed to read allow-all setting: $e');
      return false;
    }
  }

  static Future<void> setAllowAllTeachers(bool allowAll) async {
    await _firestore
        .collection(_settingsCollection)
        .doc(_settingsDocId)
        .set({
      _fieldAllowAllTeachers: allowAll,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<bool> watchTeacherEnabled(String teacherId) {
    return _firestore
        .collection(_usersCollection)
        .doc(teacherId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      return data?[_fieldTeacherEnabled] == true;
    });
  }

  static Future<bool> getTeacherEnabled(String teacherId) async {
    try {
      final doc =
          await _firestore.collection(_usersCollection).doc(teacherId).get();
      final data = doc.data();
      return data?[_fieldTeacherEnabled] == true;
    } catch (e) {
      AppLogger.error('MobileClassesAccessService: Failed to read teacher enable flag (teacherId=$teacherId): $e');
      return false;
    }
  }

  static Future<bool> getTeacherEnabledForIdentity({
    required String uid,
    String? email,
  }) async {
    try {
      // Prefer the UID-keyed document.
      final docByUid =
          await _firestore.collection(_usersCollection).doc(uid).get();
      if (docByUid.exists) {
        final data = docByUid.data();
        return data?[_fieldTeacherEnabled] == true;
      }

      final normalizedEmail = email?.trim().toLowerCase();
      if (normalizedEmail == null || normalizedEmail.isEmpty) return false;

      // Some deployments key user documents by email.
      final docByEmail = await _firestore
          .collection(_usersCollection)
          .doc(normalizedEmail)
          .get();
      if (docByEmail.exists) {
        final data = docByEmail.data();
        return data?[_fieldTeacherEnabled] == true;
      }

      // Fallback: query by email field variants.
      final q1 = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) {
        final data = q1.docs.first.data();
        return data[_fieldTeacherEnabled] == true;
      }

      final q2 = await _firestore
          .collection(_usersCollection)
          .where('e-mail', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) {
        final data = q2.docs.first.data();
        return data[_fieldTeacherEnabled] == true;
      }

      return false;
    } catch (e) {
      AppLogger.error(
          'MobileClassesAccessService: Failed to resolve teacher enable flag (uid=$uid): $e');
      return false;
    }
  }

  static Future<void> setTeacherEnabled({
    required String teacherId,
    required bool enabled,
  }) async {
    await _firestore.collection(_usersCollection).doc(teacherId).set({
      _fieldTeacherEnabled: enabled,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Returns true if this teacher is allowed to host/join classes from the
  /// native mobile app.
  static Future<bool> canTeacherHostFromMobile({
    required String uid,
    String? email,
  }) async {
    final allowAll = await getAllowAllTeachers();
    if (allowAll) return true;
    return getTeacherEnabledForIdentity(uid: uid, email: email);
  }
}
