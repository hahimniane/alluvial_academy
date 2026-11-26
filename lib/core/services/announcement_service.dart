import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/announcement.dart';
import 'user_role_service.dart';

/// Reads and writes `announcements` and the per-user
/// `users/{uid}/announcement_reads` marks behind the pinned pop-up.
class AnnouncementService {
  AnnouncementService._();

  static const _fetchLimit = 20;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('announcements');

  /// Published announcements addressed to [role], newest first. The audience
  /// and status filters are what the Firestore rule checks.
  static Future<List<Announcement>> fetchForRole(String role) async {
    final snap = await _collection
        .where('audience', arrayContains: role)
        .where('status', isEqualTo: 'published')
        .orderBy('created_at', descending: true)
        .limit(_fetchLimit)
        .get();
    return _parse(snap.docs);
  }

  /// Every published announcement, newest first (admins only).
  static Future<List<Announcement>> fetchAllPublished() async {
    final snap = await _collection
        .where('status', isEqualTo: 'published')
        .orderBy('created_at', descending: true)
        .limit(_fetchLimit)
        .get();
    return _parse(snap.docs);
  }

  static List<Announcement> _parse(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) => Announcement.fromMap(doc.id, doc.data()))
        .whereType<Announcement>()
        .toList();
  }

  static Future<void> create({
    required String title,
    required String body,
    required List<String> audience,
    required bool pinned,
    required DateTime? expiresAt,
    required bool sendPush,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userData = await UserRoleService.getCurrentUserData();
    final name = [
      (userData?['first_name'] ?? '').toString().trim(),
      (userData?['last_name'] ?? '').toString().trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    await _collection.add({
      'title': title.trim(),
      'body': body.trim(),
      'audience': Announcement.roles.where(audience.contains).toList(),
      'pinned': pinned,
      'expires_at': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'send_push': sendPush,
      'status': 'published',
      'created_at': FieldValue.serverTimestamp(),
      'created_by': uid,
      'created_by_name': name,
    });
  }

  static Future<void> archive(String id) {
    return _collection.doc(id).update({
      'status': 'archived',
      'archived_at': FieldValue.serverTimestamp(),
      'archived_by': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
  }

  /// Which of [ids] the signed-in user has already seen. An unreadable mark
  /// counts as seen, so a failed read never repeats the pop-up.
  static Future<Set<String>> seenIds(Iterable<String> ids) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return ids.toSet();
    final reads =
        _db.collection('users').doc(uid).collection('announcement_reads');
    final seen = <String>{};
    await Future.wait(ids.map((id) async {
      try {
        final snap = await reads.doc(id).get();
        if (snap.exists) seen.add(id);
      } catch (_) {
        seen.add(id);
      }
    }));
    return seen;
  }

  static Future<void> markSeen(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('announcement_reads')
        .doc(id)
        .set({'read_at': FieldValue.serverTimestamp()});
  }
}
