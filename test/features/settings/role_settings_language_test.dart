import 'package:alluwalacademyadmin/core/services/language_service.dart';
import 'package:alluwalacademyadmin/features/settings/screens/role_settings_screen.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('parent settings switch the app to French at once and keep it',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final service = LanguageService();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: service,
        child: Consumer<LanguageService>(
          builder: (context, language, _) => MaterialApp(
            locale: language.locale,
            supportedLocales: LanguageService.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const RoleSettingsScreen(title: 'Settings'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('role-settings-language'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Language')),
        findsOneWidget);

    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();

    expect(service.locale, const Locale('fr'));
    expect(find.descendant(of: card, matching: find.text('Langue')),
        findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('language_code'),
      'fr',
    );

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(service.locale, const Locale('en'));
  });
}
