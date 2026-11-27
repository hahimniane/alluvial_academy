import 'package:cloud_firestore/cloud_firestore.dart';

/// A school announcement (Firestore `announcements`), shown on the teacher,
/// student, parent and admin home screens. Mirrors apps/web/src/lib/announcements.ts.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.pinned,
    required this.expiresAt,
    required this.createdAt,
    required this.createdByName,
    required this.published,
  });

  static const roles = ['teacher', 'student', 'parent', 'admin'];
  static const titleMax = 120;
  static const bodyMax = 2000;

  final String id;
  final String title;
  final String body;
  final List<String> audience;
  final bool pinned;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String createdByName;
  final bool published;

  /// A document as an Announcement, or null when it has no title.
  static Announcement? fromMap(String id, Map<String, dynamic> data) {
    final title = _text(data['title']);
    if (title.isEmpty) return null;
    final body = data['body'];
    return Announcement(
      id: id,
      title: title,
      body: body is String ? body.trim() : '',
      audience: audienceOf(data['audience']),
      pinned: data['pinned'] == true,
      expiresAt: _date(data['expires_at']),
      createdAt: _date(data['created_at']),
      createdByName: _text(data['created_by_name']),
      published: data['status'] == 'published',
    );
  }

  static List<String> audienceOf(Object? value) {
    if (value is! List) return const [];
    final wanted = value.map((e) => _text(e).toLowerCase()).toSet();
    return roles.where(wanted.contains).toList();
  }

  bool isActive(DateTime now) {
    if (!published) return false;
    final end = expiresAt;
    return end == null || end.isAfter(now);
  }

  static String _text(Object? value) => value is String ? value.trim() : '';

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}

/// Published, unexpired, addressed to [role]; pinned first, then newest first.
List<Announcement> activeAnnouncements(
  Iterable<Announcement> items,
  String role,
  DateTime now,
) {
  final list = items
      .where((item) => item.isActive(now) && item.audience.contains(role))
      .toList();
  list.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
    final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
    return bTime.compareTo(aTime);
  });
  return list;
}

/// The pinned announcement to pop up: the newest pinned one not yet seen.
Announcement? nextUnseenPinned(
  List<Announcement> active,
  Set<String> seenIds,
) {
  for (final item in active) {
    if (item.pinned && !seenIds.contains(item.id)) return item;
  }
  return null;
}

/// Why an announcement draft cannot be sent yet, or null when it can.
enum AnnouncementDraftProblem {
  titleMissing,
  titleTooLong,
  bodyMissing,
  bodyTooLong,
  noAudience
}

AnnouncementDraftProblem? announcementDraftProblem({
  required String title,
  required String body,
  required Iterable<String> audience,
}) {
  final cleanTitle = title.trim();
  final cleanBody = body.trim();
  if (cleanTitle.isEmpty) return AnnouncementDraftProblem.titleMissing;
  if (cleanTitle.length > Announcement.titleMax) {
    return AnnouncementDraftProblem.titleTooLong;
  }
  if (cleanBody.isEmpty) return AnnouncementDraftProblem.bodyMissing;
  if (cleanBody.length > Announcement.bodyMax) {
    return AnnouncementDraftProblem.bodyTooLong;
  }
  if (!audience.any(Announcement.roles.contains)) {
    return AnnouncementDraftProblem.noAudience;
  }
  return null;
}
