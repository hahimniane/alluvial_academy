import 'package:cloud_firestore/cloud_firestore.dart';

class DecisionAuditEvent {
  final String id;
  final String entityType;
  final String entityId;
  final String entityLabel;
  final String action;
  final String actorUid;
  final String actorName;
  final String actorEmail;
  final String actorRole;
  final String actorKind;
  final String source;
  final DateTime? recordedAt;
  final Map<String, dynamic> metadata;
  final bool isLegacyFallback;

  const DecisionAuditEvent({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entityLabel,
    required this.action,
    required this.actorUid,
    required this.actorName,
    required this.actorEmail,
    required this.actorRole,
    this.actorKind = '',
    required this.source,
    required this.recordedAt,
    required this.metadata,
    this.isLegacyFallback = false,
  });

  factory DecisionAuditEvent.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return DecisionAuditEvent.fromMap(
      document.data() ?? const <String, dynamic>{},
      id: document.id,
    );
  }

  factory DecisionAuditEvent.fromMap(
    Map<String, dynamic> data, {
    String id = '',
    bool isLegacyFallback = false,
  }) {
    return DecisionAuditEvent(
      id: id,
      entityType: (data['entity_type'] ?? data['entityType'] ?? '').toString(),
      entityId: (data['entity_id'] ?? data['entityId'] ?? '').toString(),
      entityLabel:
          (data['entity_label'] ?? data['entityLabel'] ?? '').toString(),
      action: (data['action'] ?? '').toString(),
      actorUid: (data['actor_uid'] ?? data['actorUid'] ?? '').toString(),
      actorName: (data['actor_name'] ?? data['actorName'] ?? '').toString(),
      actorEmail: (data['actor_email'] ?? data['actorEmail'] ?? '').toString(),
      actorRole: (data['actor_role'] ?? data['actorRole'] ?? '').toString(),
      actorKind: (data['actor_kind'] ?? data['actorKind'] ?? '').toString(),
      source: (data['source'] ?? '').toString(),
      recordedAt: _dateTime(data['recorded_at'] ?? data['recordedAt']),
      metadata: Map<String, dynamic>.from(
        data['metadata'] is Map ? data['metadata'] as Map : const {},
      ),
      isLegacyFallback: isLegacyFallback,
    );
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class DecisionAuditFallback {
  final String action;
  final String actorUid;
  final String actorName;
  final String actorEmail;
  final DateTime? occurredAt;

  const DecisionAuditFallback({
    required this.action,
    this.actorUid = '',
    this.actorName = '',
    this.actorEmail = '',
    this.occurredAt,
  });
}
