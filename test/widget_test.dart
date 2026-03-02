// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:alluwalacademyadmin/core/services/language_service.dart';
import 'package:alluwalacademyadmin/core/services/theme_service.dart';
import 'package:alluwalacademyadmin/main.dart';

void main() {
  testWidgets(
    'MyApp smoke test (builds)',
    (WidgetTester tester) async {
    final originalPlatformOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeService()),
            ChangeNotifierProvider(create: (_) => LanguageService()),
          ],
          child: const MyApp(),
        ),
      );

      // Allow initial connectivity checks/timeouts to complete.
      await tester.pump(const Duration(seconds: 6));

      expect(find.byType(MyApp), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Dispose tree and flush microtasks/timers before assertion teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = originalPlatformOverride;
    }
    },
    skip: true,
  );
}
