import 'package:alluwalacademyadmin/core/services/language_service.dart';
import 'package:alluwalacademyadmin/core/widgets/language_switcher.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switches between English and French and persists the choice',
      (tester) async {
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
            home: const Scaffold(body: LanguageSwitcher()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EN'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('public-language-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FR — French'));
    await tester.pumpAndSettle();

    expect(service.locale, const Locale('fr'));
    expect(find.text('FR'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('language_code'),
      'fr',
    );
  });
}
