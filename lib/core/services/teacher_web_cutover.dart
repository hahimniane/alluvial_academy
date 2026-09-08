import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../utils/app_logger.dart';

/// Who goes to the Next.js teacher console instead of the Flutter one.
///
/// The move is staged rather than thrown: a named group of teachers first, the
/// rest once that group has run a week without trouble. The decision lives in
/// one Firestore document so it can be widened, narrowed or undone without
/// shipping an app build:
///
/// ```
/// settings/teacher_web_cutover
///   mode: 'off' | 'allowlist' | 'all'
///   teacherIds: [uid, ...]   // used when mode == 'allowlist'
///   hold: bool               // true pauses the automatic promotion to 'all'
/// ```
///
/// Only the **web** build ever redirects. The native store apps keep their own
/// teacher screens whatever this says.
class TeacherWebCutover {
  static const String collection = 'settings';
  static const String docId = 'teacher_web_cutover';

  /// Cached for the life of the session: the answer decides one navigation.
  static bool? _cached;

  /// Whether [teacherId] should be sent to `/teacher/` on this device.
  ///
  /// Fails closed: any error, missing document or unreadable field leaves the
  /// teacher on Flutter, which is the app they have today.
  static Future<bool> shouldUseWebConsole(String teacherId) async {
    if (!kIsWeb || teacherId.isEmpty) return false;
    if (_cached != null) return _cached!;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .get(const GetOptions(source: Source.server));
      final data = snap.data();
      if (data == null) return _remember(false);
      final mode = (data['mode'] ?? 'off').toString().toLowerCase();
      if (mode == 'all') return _remember(true);
      if (mode != 'allowlist') return _remember(false);
      final ids = data['teacherIds'];
      final allowed = ids is List && ids.map((e) => e.toString()).contains(teacherId);
      return _remember(allowed);
    } catch (e) {
      AppLogger.debug('TeacherWebCutover: staying on Flutter ($e)');
      return _remember(false);
    }
  }

  static bool _remember(bool value) {
    _cached = value;
    return value;
  }

  /// Forget the cached decision (used when the signed-in person changes).
  static void reset() => _cached = null;
}
