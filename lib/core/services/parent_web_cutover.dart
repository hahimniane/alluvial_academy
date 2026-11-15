import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import '../utils/app_logger.dart';

/// Who goes to the Next.js parent area at `/parent/` instead of the Flutter
/// parent dashboard.
///
/// Staged the same way as teachers (see [TeacherWebCutover]): a named group of
/// parents first, then everyone. One Firestore document decides, so the move
/// can be widened, narrowed or undone without shipping an app build:
///
/// ```
/// settings/parent_web_cutover
///   mode: 'off' | 'allowlist' | 'all'
///   parentIds: [uid, ...]   // used when mode == 'allowlist'
/// ```
///
/// Only the **web** build ever redirects. The native store apps keep their own
/// parent screens whatever this says. The Next.js side reads the same document
/// (`apps/web/src/lib/parentCutover.ts`) and also fails closed.
class ParentWebCutover {
  static const String collection = 'settings';
  static const String docId = 'parent_web_cutover';

  /// Cached for the uid it was read for: the answer decides one navigation.
  static String? _cachedUid;
  static bool? _cached;

  /// Whether [parentId] should be sent to `/parent/` on this device.
  ///
  /// Fails closed: off the web, an empty uid, a missing document, any error or
  /// an unknown mode leaves the parent on Flutter, which is what they have today.
  static Future<bool> shouldUseWebArea(String parentId) async {
    if (!kIsWeb || parentId.isEmpty) return false;
    if (_cached != null && _cachedUid == parentId) return _cached!;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .get(const GetOptions(source: Source.server));
      return _remember(parentId, allows(snap.data(), parentId));
    } catch (e) {
      AppLogger.debug('ParentWebCutover: staying on Flutter ($e)');
      return _remember(parentId, false);
    }
  }

  /// The decision itself, separate from the read so it can be tested.
  @visibleForTesting
  static bool allows(Map<String, dynamic>? data, String parentId) {
    if (data == null || parentId.isEmpty) return false;
    final mode = (data['mode'] ?? 'off').toString().trim().toLowerCase();
    if (mode == 'all') return true;
    if (mode != 'allowlist') return false;
    final ids = data['parentIds'];
    return ids is List && ids.map((e) => e.toString()).contains(parentId);
  }

  static bool _remember(String uid, bool value) {
    _cachedUid = uid;
    _cached = value;
    return value;
  }

  /// Forget the cached decision.
  static void reset() {
    _cachedUid = null;
    _cached = null;
  }
}
