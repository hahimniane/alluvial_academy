import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/decision_audit_event.dart';

class DecisionAuditService {
  final FirebaseFirestore _firestore;

  DecisionAuditService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static String documentId(String entityType, String entityId) {
    final normalizedType =
        entityType.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final normalizedId = entityId.trim().replaceAll('/', '_');
    return '${normalizedType}__$normalizedId';
  }

  Stream<List<DecisionAuditEvent>> watchEntityHistory({
    required String entityType,
    required String entityId,
    int limit = 20,
  }) {
    return _firestore
        .collection('decision_audits')
        .doc(documentId(entityType, entityId))
        .collection('events')
        .orderBy('recorded_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(DecisionAuditEvent.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<DecisionAuditEvent>> watchRecentHistory({int limit = 200}) {
    return _firestore
        .collection('decision_audit_events')
        .orderBy('recorded_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(DecisionAuditEvent.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<List<DecisionAuditEvent>> resolveFallbacks({
    required String entityType,
    required String entityId,
    required String entityLabel,
    required List<DecisionAuditFallback> fallbacks,
  }) async {
    final results = <DecisionAuditEvent>[];
    for (var index = 0; index < fallbacks.length; index++) {
      final fallback = fallbacks[index];
      var actorName = fallback.actorName.trim();
      var actorEmail = fallback.actorEmail.trim();
      var actorRole = '';
      final actorUid = fallback.actorUid.trim();

      if (actorUid.isNotEmpty &&
          (actorName.isEmpty || actorEmail.isEmpty || actorRole.isEmpty)) {
        final actor = await _resolveActor(actorUid);
        actorName = actorName.isNotEmpty ? actorName : actor.name;
        actorEmail = actorEmail.isNotEmpty ? actorEmail : actor.email;
        actorRole = actor.role;
      }

      results.add(
        DecisionAuditEvent(
          id: 'legacy_${fallback.action}_$index',
          entityType: entityType,
          entityId: entityId,
          entityLabel: entityLabel,
          action: fallback.action,
          actorUid: actorUid,
          actorName: actorName,
          actorEmail: actorEmail,
          actorRole: actorRole,
          actorKind: actorUid.isEmpty ? 'system' : 'person',
          source: 'legacy_record',
          recordedAt: fallback.occurredAt,
          metadata: const {},
          isLegacyFallback: true,
        ),
      );
    }
    return results;
  }

  Future<({String name, String email, String role})> _resolveActor(
    String uid,
  ) async {
    try {
      var document = await _firestore.collection('users').doc(uid).get();
      if (!document.exists) {
        final query = await _firestore
            .collection('users')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) document = query.docs.first;
      }

      final data = document.data();
      if (data != null) {
        final firstName =
            (data['first_name'] ?? data['firstName'] ?? '').toString().trim();
        final lastName =
            (data['last_name'] ?? data['lastName'] ?? '').toString().trim();
        final storedName =
            (data['name'] ?? data['displayName'] ?? data['display_name'] ?? '')
                .toString()
                .trim();
        return (
          name: storedName.isNotEmpty
              ? storedName
              : '$firstName $lastName'.trim(),
          email: (data['e-mail'] ?? data['email'] ?? '').toString().trim(),
          role: (data['user_type'] ?? data['userType'] ?? data['role'] ?? '')
              .toString()
              .trim(),
        );
      }
    } catch (_) {}

    return (name: '', email: '', role: '');
  }
}
