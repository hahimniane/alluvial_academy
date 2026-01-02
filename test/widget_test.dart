// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'package:alluwalacademyadmin/core/services/theme_service.dart';
import 'package:alluwalacademyadmin/main.dart';
import 'package:alluwalacademyadmin/screens/landing_page.dart';

void main() {
  testWidgets('MyApp smoke test (builds)', (WidgetTester tester) async {
    final originalPlatformOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeService(),
          child: const MyApp(),
        ),
      );

      // LandingPage uses FadeInSlide widgets that schedule short, one-shot
      // timers. Advance enough time for them to complete.
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MyApp), findsOneWidget);
      expect(find.byType(LandingPage), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = originalPlatformOverride;
    }
  });
}
