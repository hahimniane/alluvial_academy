import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../models/decision_audit_event.dart';
import '../services/decision_audit_service.dart';

class DecisionHistoryCard extends StatefulWidget {
  final String entityType;
  final String entityId;
  final String entityLabel;
  final List<DecisionAuditFallback> fallbackEvents;
  final int limit;

  const DecisionHistoryCard({
    super.key,
    required this.entityType,
    required this.entityId,
    this.entityLabel = '',
    this.fallbackEvents = const [],
    this.limit = 20,
  });

  @override
  State<DecisionHistoryCard> createState() => _DecisionHistoryCardState();
}

class _DecisionHistoryCardState extends State<DecisionHistoryCard> {
  final DecisionAuditService _service = DecisionAuditService();
  late Future<List<DecisionAuditEvent>> _fallbackFuture;

  @override
  void initState() {
    super.initState();
    _refreshFallbacks();
  }

  @override
  void didUpdateWidget(covariant DecisionHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entityType != widget.entityType ||
        oldWidget.entityId != widget.entityId ||
        oldWidget.entityLabel != widget.entityLabel ||
        oldWidget.fallbackEvents != widget.fallbackEvents) {
      _refreshFallbacks();
    }
  }

  void _refreshFallbacks() {
    _fallbackFuture = _service.resolveFallbacks(
      entityType: widget.entityType,
      entityId: widget.entityId,
      entityLabel: widget.entityLabel,
      fallbacks: widget.fallbackEvents,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entityId.trim().isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<DecisionAuditEvent>>(
      future: _fallbackFuture,
      builder: (context, fallbackSnapshot) {
        final fallbacks = fallbackSnapshot.data ?? const <DecisionAuditEvent>[];
        return StreamBuilder<List<DecisionAuditEvent>>(
          stream: _service.watchEntityHistory(
            entityType: widget.entityType,
            entityId: widget.entityId,
            limit: widget.limit,
          ),
          builder: (context, historySnapshot) {
            final events = _mergeEvents(
              historySnapshot.data ?? const <DecisionAuditEvent>[],
              fallbacks,
            );
            if (events.isEmpty) {
              if (historySnapshot.connectionState == ConnectionState.waiting &&
                  fallbackSnapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              return const SizedBox.shrink();
            }

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fact_check_outlined,
                          size: 19,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.decisionHistory,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  for (var index = 0; index < events.length; index++) ...[
                    DecisionHistoryEventTile(event: events[index]),
                    if (index != events.length - 1)
                      const Divider(height: 1, indent: 48),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<DecisionAuditEvent> _mergeEvents(
    List<DecisionAuditEvent> recorded,
    List<DecisionAuditEvent> fallbacks,
  ) {
    final recordedActions = recorded.map((event) => event.action).toSet();
    final merged = <DecisionAuditEvent>[
      ...recorded,
      ...fallbacks.where(
        (fallback) => !recordedActions.contains(fallback.action),
      ),
    ];
    merged.sort((a, b) {
      final aDate = a.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.recordedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return merged.take(widget.limit).toList(growable: false);
  }
}

class DecisionHistoryEventTile extends StatelessWidget {
  final DecisionAuditEvent event;
  final bool showEntityLabel;

  const DecisionHistoryEventTile({
    super.key,
    required this.event,
    this.showEntityLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actorName = _decisionActorDisplayName(l10n, event);
    final isSystem = actorName == l10n.decisionSystemAutomation;
    final entityLabel = event.entityLabel.trim();
    final hasReadableEntityLabel = showEntityLabel &&
        entityLabel.isNotEmpty &&
        entityLabel != event.entityId.trim();
    final date = event.recordedAt;
    final dateLabel = date == null
        ? ''
        : DateFormat.yMMMd(l10n.localeName).add_jm().format(date.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSystem ? Icons.settings_suggest_outlined : Icons.person_outline,
              size: 15,
              color: const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  decisionAuditActionLabel(l10n, event.action),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (hasReadableEntityLabel) ...[
                  const SizedBox(height: 3),
                  Text(
                    entityLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Tooltip(
                  message: _decisionActorTechnicalDetails(l10n, event),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSystem
                            ? Icons.settings_outlined
                            : Icons.account_circle_outlined,
                        size: 14,
                        color: const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.decisionMadeBy(actorName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (event.actorRole.trim().isNotEmpty && !isSystem)
                  Padding(
                    padding: const EdgeInsets.only(left: 18, top: 1),
                    child: Text(
                      event.actorRole.trim(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              dateLabel,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _decisionActorDisplayName(
  AppLocalizations l10n,
  DecisionAuditEvent event,
) {
  final kind = event.actorKind.trim().toLowerCase();
  final name = event.actorName.trim();
  final technicalValue =
      '${event.actorUid} ${event.actorEmail} $name'.toLowerCase();
  final isSystem = kind == 'system' ||
      technicalValue.contains('gserviceaccount.com') ||
      technicalValue.contains('firebase-adminsdk') ||
      technicalValue.contains('compute@developer');
  if (isSystem) return l10n.decisionSystemAutomation;
  final looksLikePhone = RegExp(r'^\+?[0-9][0-9 ()-]{6,}$').hasMatch(name);
  final looksLikeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(name);
  if (name.isNotEmpty && !looksLikePhone && !looksLikeEmail) return name;
  return l10n.decisionActorUnknown;
}

String _decisionActorTechnicalDetails(
  AppLocalizations l10n,
  DecisionAuditEvent event,
) {
  final details = <String>[
    if (event.actorEmail.trim().isNotEmpty &&
        !event.actorEmail.toLowerCase().contains('gserviceaccount.com'))
      event.actorEmail.trim(),
    if (event.actorRole.trim().isNotEmpty) event.actorRole.trim(),
    if (event.actorUid.trim().isNotEmpty &&
        !event.actorUid.toLowerCase().contains('gserviceaccount.com'))
      event.actorUid.trim(),
  ];
  if (details.isEmpty) return l10n.decisionTechnicalDetails;
  return '${l10n.decisionTechnicalDetails}: ${details.join(' · ')}';
}

String decisionAuditActionLabel(AppLocalizations l10n, String action) {
  return switch (action) {
    'user.created' => l10n.decisionActionUserCreated,
    'user.archived' => l10n.decisionActionUserArchived,
    'user.restored' => l10n.decisionActionUserRestored,
    'user.deleted' => l10n.decisionActionUserDeleted,
    'user.role_changed' => l10n.decisionActionUserRoleChanged,
    'user.guardian_links_changed' =>
      l10n.decisionActionUserGuardianLinksChanged,
    'shift.created' => l10n.decisionActionShiftCreated,
    'shift.deleted' => l10n.decisionActionShiftDeleted,
    'shift.cancelled' => l10n.decisionActionShiftCancelled,
    'shift.published' => l10n.decisionActionShiftPublished,
    'shift.unpublished' => l10n.decisionActionShiftUnpublished,
    'shift.rescheduled' => l10n.decisionActionShiftRescheduled,
    'shift.teacher_changed' => l10n.decisionActionShiftTeacherChanged,
    'shift.students_changed' => l10n.decisionActionShiftStudentsChanged,
    'shift.recording_permission_changed' =>
      l10n.decisionActionShiftRecordingPermissionChanged,
    'invoice.created' => l10n.decisionActionInvoiceCreated,
    'invoice.deleted' => l10n.decisionActionInvoiceDeleted,
    'invoice.paid' => l10n.decisionActionInvoicePaid,
    'invoice.cancelled' => l10n.decisionActionInvoiceCancelled,
    'invoice.reopened' => l10n.decisionActionInvoiceReopened,
    'invoice.amount_changed' => l10n.decisionActionInvoiceAmountChanged,
    'invoice.due_date_changed' => l10n.decisionActionInvoiceDueDateChanged,
    'invoice.cutoff_changed' => l10n.decisionActionInvoiceCutoffChanged,
    'invoice.payment_recorded' => l10n.decisionActionInvoicePaymentRecorded,
    'timesheet.deleted' => l10n.decisionActionTimesheetDeleted,
    'timesheet.approved' => l10n.decisionActionTimesheetApproved,
    'timesheet.rejected' => l10n.decisionActionTimesheetRejected,
    'timesheet.reopened' => l10n.decisionActionTimesheetReopened,
    'timesheet.edit_approved' => l10n.decisionActionTimesheetEditApproved,
    'timesheet.edit_rejected' => l10n.decisionActionTimesheetEditRejected,
    'timesheet.payment_changed' => l10n.decisionActionTimesheetPaymentChanged,
    'application.deleted' => l10n.decisionActionApplicationDeleted,
    'application.approved' => l10n.decisionActionApplicationApproved,
    'application.rejected' => l10n.decisionActionApplicationRejected,
    'application.status_changed' => l10n.decisionActionApplicationStatusChanged,
    'task.created' => l10n.decisionActionTaskCreated,
    'task.deleted' => l10n.decisionActionTaskDeleted,
    'task.archived' => l10n.decisionActionTaskArchived,
    'task.restored' => l10n.decisionActionTaskRestored,
    'task.assignees_changed' => l10n.decisionActionTaskAssigneesChanged,
    'task.due_date_changed' => l10n.decisionActionTaskDueDateChanged,
    'task.status_changed' => l10n.decisionActionTaskStatusChanged,
    'form_response.deleted' => l10n.decisionActionFormResponseDeleted,
    'form_response.accepted' => l10n.decisionActionFormResponseAccepted,
    'form_response.rejected' => l10n.decisionActionFormResponseRejected,
    'form_response.review_reset' => l10n.decisionActionFormResponseReviewReset,
    'form_response.review_changed' =>
      l10n.decisionActionFormResponseReviewChanged,
    'no_show.deleted' => l10n.decisionActionNoShowDeleted,
    'no_show.reviewed' => l10n.decisionActionNoShowReviewed,
    'no_show.reopened' => l10n.decisionActionNoShowReopened,
    'enrollment.deleted' => l10n.decisionActionEnrollmentDeleted,
    'enrollment.archived' => l10n.decisionActionEnrollmentArchived,
    'enrollment.restored' => l10n.decisionActionEnrollmentRestored,
    'enrollment.matched' => l10n.decisionActionEnrollmentMatched,
    'enrollment.status_changed' => l10n.decisionActionEnrollmentStatusChanged,
    'enrollment.parent_link_changed' =>
      l10n.decisionActionEnrollmentParentLinkChanged,
    'audit.deleted' => l10n.decisionActionAuditDeleted,
    'audit.status_changed' => l10n.decisionActionAuditStatusChanged,
    'audit.review_changed' => l10n.decisionActionAuditReviewChanged,
    'audit.compensation_changed' => l10n.decisionActionAuditCompensationChanged,
    'setting.created' => l10n.decisionActionSettingCreated,
    'setting.deleted' => l10n.decisionActionSettingDeleted,
    'setting.changed' => l10n.decisionActionSettingChanged,
    _ => l10n.decision,
  };
}
