import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/features/parent/widgets/financial_summary_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

void main() {
  testWidgets('shows what is owed now and no total of everything paid',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FinancialSummaryCard(outstanding: 120, overdue: 40),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('\$120.00'), findsOneWidget);
    expect(find.text('\$40.00'), findsOneWidget);
    expect(find.text('Paid'), findsNothing);
  });
}
