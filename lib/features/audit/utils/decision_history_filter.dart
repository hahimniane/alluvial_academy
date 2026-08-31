import '../../../core/models/decision_audit_event.dart';
import '../../../core/utils/app_search.dart';

bool matchesDecisionHistoryEvent({
  required DecisionAuditEvent event,
  required String query,
  required String entityFilter,
}) {
  if (entityFilter != 'all' && event.entityType != entityFilter) {
    return false;
  }

  return AppSearch.matches(
    query: query,
    names: [event.actorName],
    emails: [event.actorEmail],
    ids: [event.actorUid, event.entityId],
    additionalValues: [
      event.entityLabel,
      event.action,
      event.actorRole,
    ],
  );
}
