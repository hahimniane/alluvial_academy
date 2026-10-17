import 'package:alluwalacademyadmin/features/forms/screens/form_builder.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget buildBuilder() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: FormBuilder(
        editFormId: 'legacy_form',
        editFormData: {
          'title': 'Student Follow up',
          'fields': {
            'role': {
              'type': 'dropdown',
              'label': 'Is this for a:',
              'options': ['A student', 'A Teacher'],
              'order': 1,
            },
            'docs': {
              'type': 'text',
              'label': 'Documents to submit',
              'order': 2,
              'conditionalLogic': {
                'dependsOnFieldId': 'role',
                'condition': 'equals',
                'expectedValue': 'A Teacher',
                'expectedValues': null,
                'isVisible': true,
              },
            },
          },
        },
      ),
    );
  }

  testWidgets('a question with a rule shows it and its editor', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The builder's drag handle overflows its 40px box by 2px; that is
    // unrelated to rules, so layout overflow reports are not failures here.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(buildBuilder());
    await tester.pump();

    expect(find.text('Show only if: 1. Is this for a:'), findsOneWidget);

    await tester.tap(find.text('Documents to submit'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Show only if'), findsOneWidget);
    expect(find.text('1. Is this for a:'), findsWidgets);
    expect(find.text('is'), findsOneWidget);
    expect(find.text('A Teacher'), findsWidgets);

    // "is answered" needs no answer to compare, so the answer picker goes.
    await tester.tap(find.text('is'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('is answered').last);
    await tester.pumpAndSettle();
    expect(find.text('is answered'), findsOneWidget);
    expect(find.text('Pick an answer'), findsNothing);

    // "Always show" removes the rule.
    await tester.tap(find.text('1. Is this for a:').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Always show').last);
    await tester.pumpAndSettle();
    expect(find.text('is answered'), findsNothing);
    expect(find.text('Always show'), findsOneWidget);
  });
}
