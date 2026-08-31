import 'package:alluwalacademyadmin/core/models/decision_audit_event.dart';
import 'package:alluwalacademyadmin/features/audit/utils/decision_history_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const event = DecisionAuditEvent(
    id: 'event-1',
    entityType: 'invoice',
    entityId: 'INV-2048',
    entityLabel: 'July tuition',
    action: 'invoice.created',
    actorUid: 'admin-31',
    actorName: 'Aminata Diallo',
    actorEmail: 'aminata@example.com',
    actorRole: 'admin',
    source: 'firestore',
    recordedAt: null,
    metadata: {},
  );

  test('matches normalized actor name, email, and IDs', () {
    for (final query in [
      'Aminata Diallo',
      'AMINATA@EXAMPLE.COM',
      'admin31',
      'INV 2048',
    ]) {
      expect(
        matchesDecisionHistoryEvent(
          event: event,
          query: query,
          entityFilter: 'all',
        ),
        isTrue,
        reason: query,
      );
    }
  });

  test('matches decision context and applies entity filter', () {
    expect(
      matchesDecisionHistoryEvent(
        event: event,
        query: 'July tuition',
        entityFilter: 'invoice',
      ),
      isTrue,
    );
    expect(
      matchesDecisionHistoryEvent(
        event: event,
        query: '',
        entityFilter: 'user',
      ),
      isFalse,
    );
  });

  test('does not return unrelated people or decisions', () {
    expect(
      matchesDecisionHistoryEvent(
        event: event,
        query: 'Aissatou Diallo',
        entityFilter: 'all',
      ),
      isFalse,
    );
  });
}
