import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import '../../../core/utils/app_logger.dart';

/// Which admins see the Next.js Users page (embedded in the dashboard) instead
/// of [UserManagementScreen] on the web.
///
/// One Firestore document decides, so the move can be widened, narrowed or
/// undone without shipping an app build:
///
/// ```
/// settings/admin_users_web_cutover
///   mode: 'off' | 'allowlist' | 'all'
///   adminIds: [uid, ...]   // used when mode == 'allowlist'
/// ```
///
/// Only the web build ever switches. The Next.js page reads the same document
/// (`apps/web/src/lib/adminUsers.ts` adminUsersCutoverAllows) and also fails
/// closed.
class AdminUsersWebCutover {
  static const String collection = 'settings';
  static const String docId = 'admin_users_web_cutover';

  static String? _cachedUid;
  static bool? _cached;

  /// Whether [adminId] gets the Next.js Users page on this device.
  ///
  /// Fails closed: off the web, an empty uid, a missing document, any error or
  /// an unknown mode keeps the Flutter Users screen, which is what admins have
  /// today.
  static Future<bool> shouldUseWebPage(String adminId) async {
    if (!kIsWeb || adminId.isEmpty) return false;
    if (_cached != null && _cachedUid == adminId) return _cached!;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .get(const GetOptions(source: Source.server));
      return _remember(adminId, allows(snap.data(), adminId));
    } catch (e) {
      AppLogger.debug('AdminUsersWebCutover: staying on Flutter ($e)');
      return _remember(adminId, false);
    }
  }

  /// The decision itself, separate from the read so it can be tested.
  @visibleForTesting
  static bool allows(Map<String, dynamic>? data, String adminId) {
    if (data == null || adminId.isEmpty) return false;
    final mode = (data['mode'] ?? 'off').toString().trim().toLowerCase();
    if (mode == 'all') return true;
    if (mode != 'allowlist') return false;
    final ids = data['adminIds'];
    return ids is List && ids.map((e) => e.toString()).contains(adminId);
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
