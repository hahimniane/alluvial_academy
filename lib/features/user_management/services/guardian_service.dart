import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

/// A single parent/guardian linked to a student.
class GuardianLink {
  final String id;
  final String name;
  final String? email;
  final String? phone;

  const GuardianLink({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });
}

/// Admin-side reads and mutations for the parent ⇄ student relationship.
///
/// Linking is performed server-side by `inviteParentForEnrollment`. Unlinking
/// goes through the `unlinkGuardianFromStudent` callable so the two-sided
/// `guardian_ids` / `children_ids` edges, enrollment metadata, and the audit
/// trail all stay consistent.
class GuardianService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// The parents currently linked to [studentUid].
  static Future<List<GuardianLink>> getStudentGuardians(String studentUid) async {
    final studentDoc =
        await _firestore.collection('users').doc(studentUid).get();
    if (!studentDoc.exists) return const [];

    final data = studentDoc.data() ?? {};
    final guardianIds = <String>{
      ...((data['guardian_ids'] as List?)?.map((e) => e.toString()) ?? []),
      ...((data['guardianIds'] as List?)?.map((e) => e.toString()) ?? []),
    }.where((id) => id.trim().isNotEmpty).toList();

    if (guardianIds.isEmpty) return const [];

    final guardians = <GuardianLink>[];
    for (final id in guardianIds) {
      try {
        final parentDoc =
            await _firestore.collection('users').doc(id).get();
        final parent = parentDoc.data() ?? {};
        final first = (parent['first_name'] ?? '').toString().trim();
        final last = (parent['last_name'] ?? '').toString().trim();
        final name = ('$first $last').trim();
        guardians.add(GuardianLink(
          id: id,
          name: name.isNotEmpty ? name : id,
          email: (parent['e-mail'] ?? parent['email'])?.toString(),
          phone: (parent['phone_number'] ?? parent['phone'])?.toString(),
        ));
      } catch (e) {
        AppLogger.error('GuardianService: failed to load guardian $id: $e');
        guardians.add(GuardianLink(id: id, name: id));
      }
    }

    guardians.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return guardians;
  }

  /// Sever the link between [parentUid] and [studentUid]. [reason] is optional
  /// and stored in the audit trail.
  static Future<void> unlinkGuardian({
    required String studentUid,
    required String parentUid,
    String? reason,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('unlinkGuardianFromStudent');
    await callable.call<Map<String, dynamic>>({
      'studentUid': studentUid,
      'parentUid': parentUid,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }
}
