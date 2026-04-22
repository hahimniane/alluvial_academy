import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../constants/pricing_plan_ids.dart';
import '../models/employee_model.dart';
import '../models/public_site_cms_models.dart';
import '../utils/app_logger.dart';
import 'shift_service.dart';

/// Thrown when [saveTeamMember] validation fails (caller maps to localized UI).
class PublicSiteCmsValidationException implements Exception {
  final String code;
  PublicSiteCmsValidationException(this.code);
  @override
  String toString() => 'PublicSiteCmsValidationException($code)';
}

/// One row from [searchDirectoryUsers] for the team user picker.
class PublicSiteDirectoryUser {
  final String uid;
  final String docId;
  final String email;
  final String displayName;
  final String userType;

  const PublicSiteDirectoryUser({
    required this.uid,
    required this.docId,
    required this.email,
    required this.displayName,
    required this.userType,
  });

  factory PublicSiteDirectoryUser.fromJson(Map<String, dynamic> map) {
    return PublicSiteDirectoryUser(
      uid: '${map['uid'] ?? ''}',
      docId: '${map['docId'] ?? ''}',
      email: '${map['email'] ?? ''}',
      displayName: '${map['displayName'] ?? ''}',
      userType: '${map['userType'] ?? ''}',
    );
  }
}

/// Firestore-backed CMS for public pricing display + enrollment quotes, and team directory.
abstract final class PublicSiteCmsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Cached payload from [getPublicSiteMarketingBundle] (callable, Admin SDK read).
  /// Used when there is no [FirebaseAuth.currentUser] so the public site still
  /// loads after logout even if Firestore security rules only allow signed-in reads.
  static Map<String, dynamic>? _guestBundle;
  static DateTime? _guestBundleFetchedAt;
  static const Duration _guestBundleTtl = Duration(seconds: 45);

  /// Throttle [syncAdminClaimForPublicSiteStorage] (ID token refresh).
  static DateTime? _lastStorageClaimSync;

  static bool get _needsGuestMarketingRead =>
      FirebaseAuth.instance.currentUser == null;

  static Future<Map<String, dynamic>?> _guestMarketingBundleFromCallable() async {
    final now = DateTime.now();
    final cached = _guestBundle;
    final at = _guestBundleFetchedAt;
    if (cached != null &&
        at != null &&
        now.difference(at) < _guestBundleTtl) {
      return cached;
    }
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getPublicSiteMarketingBundle')
          .call();
      final data = result.data;
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data as Map);
      _guestBundle = map;
      _guestBundleFetchedAt = now;
      return map;
    } on FirebaseFunctionsException catch (e, st) {
      AppLogger.debug(
        'PublicSiteCmsService.getPublicSiteMarketingBundle: ${e.code} ${e.message}\n$st',
      );
      return null;
    } catch (e, st) {
      AppLogger.debug(
        'PublicSiteCmsService.getPublicSiteMarketingBundle: $e\n$st',
      );
      return null;
    }
  }

  /// Public team page only lists rows that are active, named, and linked to a real user.
  static bool teamMemberVisibleOnPublicSite(PublicSiteTeamMember m) {
    final link = m.linkedUserUid?.trim() ?? '';
    return m.active && m.name.isNotEmpty && link.isNotEmpty;
  }

  static List<PublicSiteTeamMember> _teamMembersFromBundleList(
    List<dynamic>? teamRaw,
  ) {
    if (teamRaw == null) return const [];
    final list = <PublicSiteTeamMember>[];
    for (final raw in teamRaw) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
      final id = (m.remove('id') ?? '').toString();
      if (id.isEmpty) continue;
      list.add(PublicSiteTeamMember.fromDoc(id, m));
    }
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list
        .where(teamMemberVisibleOnPublicSite)
        .toList(growable: false);
  }

  static const String pricingCollection = 'public_site_cms_pricing';
  static const String pricingDocId = 'main';
  static const String teamCollection = 'public_site_cms_team';
  static const String socialCollection = 'public_site_cms_social';
  static const String socialDocId = 'main';
  static const String landingCollection = 'public_site_cms_landing';
  static const String landingDocId = 'main';

  /// Merged plan display for landing (rates + optional bullets per plan).
  static Future<PublicSiteCmsPricingDoc> getPricingDoc() async {
    if (_needsGuestMarketingRead) {
      final bundle = await _guestMarketingBundleFromCallable();
      final raw = bundle?['pricing'];
      if (raw is Map) {
        return PublicSiteCmsPricingDoc.fromFirestore(
          Map<String, dynamic>.from(raw as Map),
        );
      }
      // Callable not deployed yet, or failed — try Firestore if rules allow guest read.
      try {
        final snap =
            await _db.collection(pricingCollection).doc(pricingDocId).get();
        if (snap.exists && snap.data() != null) {
          return PublicSiteCmsPricingDoc.fromFirestore(snap.data()!);
        }
      } catch (_) {}
      return const PublicSiteCmsPricingDoc();
    }
    try {
      final snap =
          await _db.collection(pricingCollection).doc(pricingDocId).get();
      if (!snap.exists || snap.data() == null) {
        return const PublicSiteCmsPricingDoc();
      }
      return PublicSiteCmsPricingDoc.fromFirestore(snap.data()!);
    } catch (e, st) {
      AppLogger.debug('PublicSiteCmsService.getPricingDoc: $e\n$st');
      return const PublicSiteCmsPricingDoc();
    }
  }

  static Future<void> savePricingDoc(PublicSiteCmsPricingDoc doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to save pricing');
    }
    await _db
        .collection(pricingCollection)
        .doc(pricingDocId)
        .set(doc.toFirestore(), SetOptions(merge: true));
  }

  /// Header social icons (Instagram, Facebook, TikTok) — public read, admin write.
  static Future<PublicSiteSocialDoc> getSocialDoc() async {
    if (_needsGuestMarketingRead) {
      final bundle = await _guestMarketingBundleFromCallable();
      final raw = bundle?['social'];
      if (raw is Map) {
        return PublicSiteSocialDoc.fromFirestore(
          Map<String, dynamic>.from(raw as Map),
        );
      }
      try {
        final snap =
            await _db.collection(socialCollection).doc(socialDocId).get();
        if (snap.exists && snap.data() != null) {
          return PublicSiteSocialDoc.fromFirestore(snap.data()!);
        }
      } catch (_) {}
      return const PublicSiteSocialDoc();
    }
    try {
      final snap =
          await _db.collection(socialCollection).doc(socialDocId).get();
      if (!snap.exists || snap.data() == null) {
        return const PublicSiteSocialDoc();
      }
      return PublicSiteSocialDoc.fromFirestore(snap.data()!);
    } catch (e, st) {
      AppLogger.debug('PublicSiteCmsService.getSocialDoc: $e\n$st');
      return const PublicSiteSocialDoc();
    }
  }

  /// Single broadcast stream so [StreamBuilder] widgets do not tear down and
  /// recreate Firestore listeners on every parent rebuild (fixes web
  /// `LateInitializationError: onSnapshotUnsubscribe` and related SDK asserts).
  ///
  /// Broadcast streams do not replay the last event to new subscribers; after
  /// sign-out call [invalidatePublicCmsFirestoreBroadcastCaches] so the next
  /// listener (e.g. [ModernHeader] on the landing page) attaches to a fresh
  /// Firestore subscription and receives current data.
  static Stream<PublicSiteSocialDoc>? _socialDocBroadcast;

  /// Drop cached [socialDocStream] / [landingDocStream] listeners (e.g. after
  /// [FirebaseAuth.signOut]) so public UI is not stuck on stale snapshots.
  static void invalidatePublicCmsFirestoreBroadcastCaches() {
    _socialDocBroadcast = null;
    _landingDocBroadcast = null;
    _teamMembersBroadcast = null;
    _guestBundle = null;
    _guestBundleFetchedAt = null;
  }

  static Stream<PublicSiteSocialDoc> socialDocStream() {
    if (_needsGuestMarketingRead) {
      return Stream.fromFuture(getSocialDoc());
    }
    return _socialDocBroadcast ??= _db
        .collection(socialCollection)
        .doc(socialDocId)
        .snapshots()
        .map(
      (snap) {
        if (!snap.exists || snap.data() == null) {
          return const PublicSiteSocialDoc();
        }
        return PublicSiteSocialDoc.fromFirestore(snap.data()!);
      },
    ).asBroadcastStream();
  }

  static Future<void> saveSocialDoc(PublicSiteSocialDoc doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to save social links');
    }
    await _db
        .collection(socialCollection)
        .doc(socialDocId)
        .set(doc.toFirestore(), SetOptions(merge: true));
  }

  /// Landing hero (background + three images) — public read, admin write.
  static Future<PublicSiteLandingDoc> getLandingDoc() async {
    if (_needsGuestMarketingRead) {
      final bundle = await _guestMarketingBundleFromCallable();
      final raw = bundle?['landing'];
      if (raw is Map) {
        return PublicSiteLandingDoc.fromFirestore(
          Map<String, dynamic>.from(raw as Map),
        );
      }
      try {
        final snap =
            await _db.collection(landingCollection).doc(landingDocId).get();
        if (snap.exists && snap.data() != null) {
          return PublicSiteLandingDoc.fromFirestore(snap.data()!);
        }
      } catch (_) {}
      return const PublicSiteLandingDoc();
    }
    try {
      final snap =
          await _db.collection(landingCollection).doc(landingDocId).get();
      if (!snap.exists || snap.data() == null) {
        return const PublicSiteLandingDoc();
      }
      return PublicSiteLandingDoc.fromFirestore(snap.data()!);
    } catch (e, st) {
      AppLogger.debug('PublicSiteCmsService.getLandingDoc: $e\n$st');
      return const PublicSiteLandingDoc();
    }
  }

  static Stream<PublicSiteLandingDoc>? _landingDocBroadcast;

  static Stream<PublicSiteLandingDoc> landingDocStream() {
    if (_needsGuestMarketingRead) {
      return Stream.fromFuture(getLandingDoc());
    }
    return _landingDocBroadcast ??= _db
        .collection(landingCollection)
        .doc(landingDocId)
        .snapshots()
        .map(
      (snap) {
        if (!snap.exists || snap.data() == null) {
          return const PublicSiteLandingDoc();
        }
        return PublicSiteLandingDoc.fromFirestore(snap.data()!);
      },
    ).asBroadcastStream();
  }

  /// Sniff bytes then fall back to file name so Storage serves a correct `Content-Type`
  /// (wrong type breaks `Image.network` on web for PNG/WebP from pickers with odd names).
  static String _inferImageContentType(Uint8List bytes, String fileName) {
    if (bytes.length >= 12) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
      if (bytes.length >= 4 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      if (bytes.length >= 6 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          (bytes[3] == 0x38 || bytes[3] == 0x39)) {
        return 'image/gif';
      }
      final riff = String.fromCharCodes(bytes.sublist(0, 4));
      final webp = String.fromCharCodes(bytes.sublist(8, 12));
      if (riff == 'RIFF' && webp == 'WEBP') {
        return 'image/webp';
      }
    }
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  static Future<void> saveLandingDoc(PublicSiteLandingDoc doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to save landing hero');
    }
    await _db
        .collection(landingCollection)
        .doc(landingDocId)
        .set(doc.toFirestore(), SetOptions(merge: true));
  }

  /// Hero image for landing; path under [public_site_assets] (world-readable).
  static Future<String> uploadLandingHeroImage({
    required String slotId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Must be signed in');
    await syncAdminClaimForPublicSiteStorage(force: true);
    await user.getIdToken(true);
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    // Owner-scoped path (see storage.rules `public_site_assets/cms/{uploaderUid}/…`)
    // so writes succeed like profile_pictures/{uid}/… without Storage→Firestore lookups.
    final path =
        'public_site_assets/cms/${user.uid}/landing/${slotId}_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = FirebaseStorage.instance.ref(path);
    final lower = fileName.toLowerCase();
    final String contentType;
    if (lower.endsWith('.png')) {
      contentType = 'image/png';
    } else if (lower.endsWith('.webp')) {
      contentType = 'image/webp';
    } else if (lower.endsWith('.gif')) {
      contentType = 'image/gif';
    } else {
      contentType = 'image/jpeg';
    }
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// For enrollment quote math (numeric overrides only).
  static Future<Map<String, Map<String, dynamic>>> getPlanOverridesForQuotes() async {
    final doc = await getPricingDoc();
    return doc.planOverridesForQuotes();
  }

  static Stream<List<PublicSiteTeamMember>>? _teamMembersBroadcast;

  static Stream<List<PublicSiteTeamMember>> teamMembersStream() {
    return _teamMembersBroadcast ??= _db.collection(teamCollection).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PublicSiteTeamMember.fromDoc(d.id, d.data()))
          .where(teamMemberVisibleOnPublicSite)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    }).asBroadcastStream();
  }

  /// All team documents for the admin CMS (includes inactive / unlinked drafts).
  static Stream<List<PublicSiteTeamMember>> teamMembersAdminCmsStream() {
    return _db.collection(teamCollection).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PublicSiteTeamMember.fromDoc(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    });
  }

  static Future<List<PublicSiteTeamMember>> loadTeamMembersForPublic() async {
    if (_needsGuestMarketingRead) {
      final bundle = await _guestMarketingBundleFromCallable();
      final raw = bundle?['teamMembers'];
      if (raw is List) {
        return _teamMembersFromBundleList(raw);
      }
      try {
        final snap = await _db.collection(teamCollection).get();
        final list = snap.docs
            .map((d) => PublicSiteTeamMember.fromDoc(d.id, d.data()))
            .where(teamMemberVisibleOnPublicSite)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return list;
      } catch (_) {}
      return const [];
    }
    try {
      final snap = await _db.collection(teamCollection).get();
      final list = snap.docs
          .map((d) => PublicSiteTeamMember.fromDoc(d.id, d.data()))
          .where(teamMemberVisibleOnPublicSite)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    } catch (e, st) {
      AppLogger.debug('PublicSiteCmsService.loadTeamMembersForPublic: $e\n$st');
      return const [];
    }
  }

  static Future<int> countTeamMembers() async {
    if (_needsGuestMarketingRead) {
      final bundle = await _guestMarketingBundleFromCallable();
      final raw = bundle?['teamMembers'];
      if (raw is List) return raw.length;
      try {
        final snap = await _db.collection(teamCollection).get();
        return snap.docs.length;
      } catch (_) {}
      return 0;
    }
    try {
      final snap = await _db.collection(teamCollection).get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> saveTeamMember(PublicSiteTeamMember member) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Must be signed in');

    final link = member.linkedUserUid?.trim() ?? '';
    if (member.active && link.isEmpty) {
      throw PublicSiteCmsValidationException('linked_user_required');
    }
    if (member.city.trim().isEmpty) {
      throw PublicSiteCmsValidationException('city_required');
    }
    if (link.isNotEmpty) {
      final dup = await _db
          .collection(teamCollection)
          .where('linkedUserUid', isEqualTo: link)
          .limit(8)
          .get();
      for (final d in dup.docs) {
        if (d.id != member.id) {
          throw PublicSiteCmsValidationException('duplicate_linked_user');
        }
      }
    }

    await _db
        .collection(teamCollection)
        .doc(member.id)
        .set(member.toFirestore(), SetOptions(merge: true));
  }

  /// Admin directory search: Firestore `users` by UID / email (same fields as the
  /// legacy callable) plus in-memory match over shift-assignment pools (teachers +
  /// leaders), matching [ShiftService.getAvailableTeachers] / [getAvailableLeaders].
  static Future<List<PublicSiteDirectoryUser>> searchDirectoryUsers(String query) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('Must be signed in');
    }
    final raw = query.trim();
    if (raw.length < 2) return const [];

    const maxResults = 25;
    final qLower = raw.toLowerCase();
    final seen = <String>{};
    final out = <PublicSiteDirectoryUser>[];

    void add(PublicSiteDirectoryUser row) {
      if (out.length >= maxResults) return;
      final key = row.uid.isNotEmpty ? row.uid : row.docId;
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      out.add(row);
    }

    PublicSiteDirectoryUser? rowFromUserDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
      if (!doc.exists) return null;
      final d = doc.data()!;
      if (d['is_active'] == false) return null;
      final uidField = (d['uid']?.toString().trim().isNotEmpty == true)
          ? d['uid'].toString().trim()
          : doc.id;
      final email = (d['e-mail'] ?? d['email'] ?? '').toString();
      final fn = (d['first_name'] ?? d['first-name'] ?? '').toString();
      final ln = (d['last_name'] ?? d['last-name'] ?? '').toString();
      final displayName = '${fn.trim()} ${ln.trim()}'.trim().isNotEmpty
          ? '${fn.trim()} ${ln.trim()}'.trim()
          : (email.isNotEmpty ? email : uidField);
      final userType = (d['user_type'] ?? d['userType'] ?? d['role'] ?? '').toString();
      return PublicSiteDirectoryUser(
        uid: uidField,
        docId: doc.id,
        email: email,
        displayName: displayName,
        userType: userType,
      );
    }

    bool matchesQuery(PublicSiteDirectoryUser u) {
      final hay = '${u.displayName} ${u.email} ${u.uid}'.toLowerCase();
      return hay.contains(qLower);
    }

    if (raw.length >= 20) {
      try {
        final snap = await _db.collection('users').doc(raw).get();
        final row = rowFromUserDoc(snap);
        if (row != null) add(row);
      } catch (e, st) {
        AppLogger.debug('PublicSiteCmsService.searchDirectoryUsers uid doc: $e\n$st');
      }
    }

    try {
      final exactEmail = await _db
          .collection('users')
          .where('e-mail', isEqualTo: qLower)
          .limit(maxResults)
          .get();
      for (final d in exactEmail.docs) {
        final row = rowFromUserDoc(d);
        if (row != null) add(row);
      }
    } catch (e, st) {
      AppLogger.debug('PublicSiteCmsService.searchDirectoryUsers exact email: $e\n$st');
    }

    try {
      final prefixSnap = await _db
          .collection('users')
          .where('e-mail', isGreaterThanOrEqualTo: qLower)
          .where('e-mail', isLessThanOrEqualTo: '$qLower\uf8ff')
          .limit(maxResults)
          .get();
      for (final d in prefixSnap.docs) {
        final row = rowFromUserDoc(d);
        if (row != null) add(row);
      }
    } catch (e, st) {
      AppLogger.debug('PublicSiteCmsService.searchDirectoryUsers email prefix: $e\n$st');
    }

    if (out.length < maxResults) {
      try {
        final empResults = await Future.wait([
          ShiftService.getAvailableTeachers(),
          ShiftService.getAvailableLeaders(),
        ]);
        final byId = <String, Employee>{};
        for (final list in empResults) {
          for (final e in list) {
            byId.putIfAbsent(e.documentId, () => e);
          }
        }
        for (final e in byId.values) {
          if (!e.isActive) continue;
          final name = '${e.firstName} ${e.lastName}'.trim();
          final display =
              name.isNotEmpty ? name : (e.email.isNotEmpty ? e.email : e.documentId);
          final row = PublicSiteDirectoryUser(
            uid: e.documentId,
            docId: e.documentId,
            email: e.email,
            displayName: display,
            userType: e.userType,
          );
          if (!matchesQuery(row)) continue;
          add(row);
        }
      } catch (e, st) {
        AppLogger.debug('PublicSiteCmsService.searchDirectoryUsers shift pools: $e\n$st');
      }
    }

    return out;
  }

  /// Same JSON as the public Team page fallback ([assets/data/staff.json]).
  static const String bundledStaffAssetPath = 'assets/data/staff.json';

  /// Writes bundled staff rows into [teamCollection] using each row's `id` as the
  /// document id so the admin CMS matches the former default website list.
  ///
  /// When [skipIfDocExists] is true, existing documents are left unchanged (counts
  /// as skipped). Safe to run multiple times.
  static Future<({int imported, int skipped})> importBundledStaffJsonToFirestore({
    bool skipIfDocExists = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Must be signed in');

    final jsonString = await rootBundle.loadString(bundledStaffAssetPath);
    final decoded = json.decode(jsonString);
    if (decoded is! List<dynamic>) {
      throw FormatException('Expected a JSON array in $bundledStaffAssetPath');
    }

    var imported = 0;
    var skipped = 0;

    for (final raw in decoded) {
      if (raw is! Map) continue;
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      final id = (map['id'] ?? '').toString();
      if (id.isEmpty) continue;

      if (skipIfDocExists) {
        final existing = await _db.collection(teamCollection).doc(id).get();
        if (existing.exists) {
          skipped++;
          continue;
        }
      }

      final langsRaw = map['languages'];
      final langs = langsRaw is List
          ? langsRaw.map((e) => e.toString()).toList()
          : const <String>[];

      final photo = map['photoAsset']?.toString().trim();
      final member = PublicSiteTeamMember(
        id: id,
        name: (map['name'] ?? '').toString(),
        role: (map['role'] ?? '').toString(),
        city: (map['city'] ?? '').toString(),
        education: (map['education'] ?? '').toString(),
        bio: (map['bio'] ?? '').toString(),
        languages: langs,
        whyAlluwal: (map['whyAlluwal'] ?? '').toString(),
        imageUrl: null,
        photoAsset: (photo != null && photo.isNotEmpty) ? photo : null,
        linkedUserUid: null,
        category: (map['category'] ?? 'teacher').toString(),
        sortOrder: map['sortOrder'] is int
            ? map['sortOrder'] as int
            : int.tryParse('${map['sortOrder']}') ?? 0,
        active: false,
      );

      await _db
          .collection(teamCollection)
          .doc(id)
          .set(member.toFirestore(), SetOptions(merge: true));
      imported++;
    }

    _guestBundle = null;
    _guestBundleFetchedAt = null;

    return (imported: imported, skipped: skipped);
  }

  static Future<void> deleteTeamMember(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Must be signed in');

    // Pick up the Storage object (if any) before we wipe the Firestore doc so
    // deleted team members don't leave orphaned avatars in Storage forever.
    String? imageUrl;
    try {
      final snap = await _db.collection(teamCollection).doc(id).get();
      imageUrl = snap.data()?['imageUrl']?.toString();
    } catch (_) {
      imageUrl = null;
    }

    await _db.collection(teamCollection).doc(id).delete();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      } catch (_) {
        // Best-effort cleanup — don't fail the delete if the object is gone.
      }
    }
  }

  /// Calls [syncPublicSiteAdminClaim] and refreshes the ID token so Storage rules see `admin` / `isAdmin` claims.
  /// Storage also allows admins via Firestore `users/*` lookup, but claims avoid edge cases after role changes.
  ///
  /// When [force] is true (e.g. before each upload), always re-call the function so new `is_admin_teacher`
  /// or role changes are not blocked by the throttle window.
  static Future<void> syncAdminClaimForPublicSiteStorage({bool force = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastStorageClaimSync != null &&
        now.difference(_lastStorageClaimSync!) < const Duration(minutes: 50)) {
      return;
    }
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('syncPublicSiteAdminClaim')
          .call();
      await user.getIdToken(true);
      _lastStorageClaimSync = now;
    } on FirebaseFunctionsException catch (e, st) {
      // Upload may still succeed: storage.rules allows admins via Firestore users/*.
      AppLogger.debug(
        'PublicSiteCmsService.syncAdminClaimForPublicSiteStorage: ${e.code} ${e.message}\n$st',
      );
    } catch (e, st) {
      AppLogger.debug('PublicSiteCmsService.syncAdminClaimForPublicSiteStorage: $e\n$st');
    }
  }

  /// Uploads image; returns public download URL. Path is world-readable per storage.rules.
  static Future<String> uploadTeamPhoto({
    required String memberId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Must be signed in');
    await syncAdminClaimForPublicSiteStorage(force: true);
    await user.getIdToken(true);
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path =
        'public_site_assets/cms/${user.uid}/team/${memberId}_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = FirebaseStorage.instance.ref(path);
    final contentType = _inferImageContentType(bytes, fileName);
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
    final snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }

  /// V2 tracks shown as top-level cards in the admin pricing editor.
  static List<String> primaryPricingTrackIds() => [
        PricingPlanIds.islamic,
        PricingPlanIds.tutoring,
        PricingPlanIds.group,
      ];

  /// Plan keys written from the admin pricing editor (three public tracks only).
  static List<String> allPricingPlanIds() => primaryPricingTrackIds();
}
