import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../utils/app_logger.dart';

/// Student login passwords.
///
/// They live in `student_credentials/{uid}`, which only admins and the
/// student's own guardians can read and only Cloud Functions write. Older
/// accounts may still carry a copy on the user document (`temp_password`)
/// until the migration removes it, so readers fall back to it.
class StudentCredentialsService {
  StudentCredentialsService._();

  static const String collection = 'student_credentials';
  static const String _legacyField = 'temp_password';

  /// The stored password for [studentId], or '' when none is stored.
  /// [userData] is the student's user document, for the legacy fallback,
  /// which is also used when the store cannot be read.
  static Future<String> readPassword(
    String studentId,
    Map<String, dynamic> userData, {
    FirebaseFirestore? firestore,
  }) async {
    Map<String, dynamic>? credential;
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      final snap = await db.collection(collection).doc(studentId).get();
      credential = snap.data();
    } catch (e) {
      AppLogger.warning('Could not read the stored student password: $e');
    }
    return pickPassword(credential, userData);
  }

  /// The store's password when it has one, else the legacy user-doc copy.
  static String pickPassword(
    Map<String, dynamic>? credential,
    Map<String, dynamic> userData,
  ) {
    final stored = credential?['password'];
    if (stored is String && stored.trim().isNotEmpty) return stored;
    final legacy = userData[_legacyField];
    if (legacy is String && legacy.trim().isNotEmpty) return legacy;
    return '';
  }

  /// After a student changed their own password in Firebase Auth: keep the
  /// copy admins and guardians see in step. Never throws; the password change
  /// itself already succeeded.
  static Future<void> recordOwnPassword(String newPassword) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('recordOwnStudentPassword')
          .call(<String, dynamic>{'password': newPassword});
    } catch (e) {
      AppLogger.warning('Could not record the new student password: $e');
    }
  }
}
