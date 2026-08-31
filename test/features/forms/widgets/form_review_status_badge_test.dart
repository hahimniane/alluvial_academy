import 'package:alluwalacademyadmin/features/forms/utils/form_review_status.dart';
import 'package:alluwalacademyadmin/features/forms/widgets/form_review_status_badge.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildBadge(Object? status) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: FormReviewStatusBadge(status: status)),
      ),
    );
  }

  testWidgets('shows Not reviewed for a missing decision', (tester) async {
    await tester.pumpWidget(buildBadge(null));
    await tester.pumpAndSettle();

    expect(find.text('Not reviewed'), findsOneWidget);
  });

  testWidgets('shows the accepted decision', (tester) async {
    await tester.pumpWidget(buildBadge(FormReviewStatus.accepted));
    await tester.pumpAndSettle();

    expect(find.text('Accepted'), findsOneWidget);
  });
}
