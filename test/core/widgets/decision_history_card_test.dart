import 'package:alluwalacademyadmin/core/models/decision_audit_event.dart';
import 'package:alluwalacademyadmin/core/widgets/decision_history_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget testApp(DecisionAuditEvent event) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DecisionHistoryEventTile(
          event: event,
          showEntityLabel: true,
        ),
      ),
    );
  }

  testWidgets('shows automation instead of a service account identity',
      (tester) async {
    const technicalEmail = '123-compute@developer.gserviceaccount.com';
    const event = DecisionAuditEvent(
      id: 'event-1',
      entityType: 'invoice',
      entityId: 'invoice-doc-id',
      entityLabel: 'INV-2026-001',
      action: 'invoice.payment_recorded',
      actorUid: technicalEmail,
      actorName: technicalEmail,
      actorEmail: technicalEmail,
      actorRole: '',
      actorKind: 'system',
      source: 'server',
      recordedAt: null,
      metadata: {},
    );

    await tester.pumpWidget(testApp(event));

    expect(find.text('By System automation'), findsOneWidget);
    expect(find.text(technicalEmail), findsNothing);
    expect(find.text('INV-2026-001'), findsOneWidget);
  });

  testWidgets('does not show a raw document id as the record label',
      (tester) async {
    const event = DecisionAuditEvent(
      id: 'event-2',
      entityType: 'invoice',
      entityId: 'invoice-doc-id',
      entityLabel: 'invoice-doc-id',
      action: 'invoice.created',
      actorUid: 'admin-1',
      actorName: 'Aminata Bah',
      actorEmail: 'aminata@example.com',
      actorRole: 'admin',
      actorKind: 'person',
      source: 'authenticated_write',
      recordedAt: null,
      metadata: {},
    );

    await tester.pumpWidget(testApp(event));

    expect(find.text('invoice-doc-id'), findsNothing);
    expect(find.text('By Aminata Bah'), findsOneWidget);
  });
}
