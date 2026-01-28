import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceStatus {
  final bool isOnline;
  final DateTime? lastSeen;

  const PresenceStatus({
    required this.isOnline,
    required this.lastSeen,
  });
}

class PresenceUtils {
  static const Duration onlineThreshold = Duration(minutes: 2);

  static DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static PresenceStatus resolvePresence(Map<String, dynamic> data) {
    final lastSeen = parseTimestamp(data['last_seen']) ??
        parseTimestamp(data['last_login']);
    final now = DateTime.now();
    final recentlyActive =
        lastSeen != null && now.difference(lastSeen) <= onlineThreshold;

    final onlineFlag = data['is_online'];
    bool isOnline;
    if (onlineFlag is bool) {
      // Treat stale "is_online" as offline if last_seen is old.
      isOnline = onlineFlag && (recentlyActive || lastSeen == null);
    } else {
      isOnline = recentlyActive;
    }

    return PresenceStatus(isOnline: isOnline, lastSeen: lastSeen);
  }
}
