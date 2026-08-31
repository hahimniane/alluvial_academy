import 'package:alluwalacademyadmin/core/models/decision_audit_event.dart';
import 'package:alluwalacademyadmin/core/services/decision_audit_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses an immutable actor snapshot and metadata', () {
    final event = DecisionAuditEvent.fromMap({
      'entity_type': 'shift',
      'entity_id': 'shift-1',
      'entity_label': 'Quran Studies',
      'action': 'shift.created',
      'actor_uid': 'admin-1',
      'actor_name': 'Aminata Bah',
      'actor_email': 'aminata@example.com',
      'actor_role': 'admin',
      'actor_kind': 'person',
      'recorded_at': Timestamp.fromDate(DateTime.utc(2026, 7, 18, 14)),
      'metadata': {'source': 'manual'},
    });

    expect(event.entityType, 'shift');
    expect(event.action, 'shift.created');
    expect(event.actorName, 'Aminata Bah');
    expect(event.actorKind, 'person');
    expect(event.recordedAt?.toUtc(), DateTime.utc(2026, 7, 18, 14));
    expect(event.metadata['source'], 'manual');
  });

  test('builds the same safe history document ID as the backend', () {
    expect(
      DecisionAuditService.documentId('invoice', 'INV/2026'),
      'invoice__INV_2026',
    );
  });
}
