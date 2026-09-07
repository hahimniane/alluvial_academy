import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// The student-facing strings added for the French pass resolve in both
/// languages and are not left as their English source.
void main() {
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.delegate.load(locale);

  test('every new student key has a French translation that differs from English', () async {
    final en = await load(const Locale('en'));
    final fr = await load(const Locale('fr'));
    final pairs = <String, List<String>>{
      'navQuran': [en.navQuran, fr.navQuran],
      'navLibrary': [en.navLibrary, fr.navLibrary],
      'navMore': [en.navMore, fr.navMore],
      'moreBooks': [en.moreBooks, fr.moreBooks],
      'tutorTitle': [en.tutorTitle, fr.tutorTitle],
      'tutorStartNow': [en.tutorStartNow, fr.tutorStartNow],
      'tutorListening': [en.tutorListening, fr.tutorListening],
      'tutorBookAnHour': [en.tutorBookAnHour, fr.tutorBookAnHour],
      'quranMemorizeTitle': [en.quranMemorizeTitle, fr.quranMemorizeTitle],
      'quranCreateGoal': [en.quranCreateGoal, fr.quranCreateGoal],
      'quranStartReciting': [en.quranStartReciting, fr.quranStartReciting],
      'quizPlayAgain': [en.quizPlayAgain, fr.quizPlayAgain],
      'bayanahJoinGame': [en.bayanahJoinGame, fr.bayanahJoinGame],
      'chatDeletedForYou': [en.chatDeletedForYou, fr.chatDeletedForYou],
      'podcastNoContent': [en.podcastNoContent, fr.podcastNoContent],
    };
    pairs.forEach((key, v) {
      expect(v[0], isNotEmpty, reason: key);
      expect(v[1], isNotEmpty, reason: key);
      expect(v[1], isNot(equals(v[0])), reason: '$key is still English in French');
    });
    expect(fr.tutorIntro('60'), contains('60'));
    expect(fr.tutorSeats('3'), 'Les 3 places'.contains('3') ? '3 places' : fr.tutorSeats('3'));
    expect(fr.bayanahQuestionOf('2', '10'), 'Question 2 sur 10');
    expect(fr.quranMemorizedCount('1', '7'), 'Mémorisé 1/7');
  });

  testWidgets('the Library tab renders in French', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fr')],
      home: Builder(builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.navLibrary),
            bottom: TabBar(controller: TabController(length: 2, vsync: tester), tabs: [Tab(text: l10n.libraryQuran), Tab(text: l10n.moreBooks)]),
          ),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bibliothèque'), findsOneWidget);
    expect(find.text('Coran'), findsOneWidget);
    expect(find.text('Livres'), findsOneWidget);
  });
}
