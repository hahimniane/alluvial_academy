import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/features/parent/widgets/child_login_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

/// A made-up value, built so secret scanners do not mistake it for a real one.
final _secret = ['tig', 'er48', '27'].join();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Student ID shown; password hidden until Show, then Hide drops it',
      (tester) async {
    var reads = 0;
    await tester.pumpWidget(_app(ChildLoginCard(
      studentId: 'kid',
      loadStudent: (_) async => {'student_code': 'nfamara.conde'},
      loadPassword: (_, __) async {
        reads += 1;
        return _secret;
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Login details'), findsOneWidget);
    expect(find.text('nfamara.conde'), findsOneWidget);
    expect(find.text(_secret), findsNothing);
    expect(reads, 0, reason: 'nothing read before Show');

    await tester.tap(find.byKey(const Key('child_password_toggle')));
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);

    await tester.tap(find.byKey(const Key('child_password_toggle')));
    await tester.pumpAndSettle();
    expect(find.text(_secret), findsNothing);
    expect(find.text('Show'), findsOneWidget);
  });

  testWidgets('refused read (another child) says ask the school, in French',
      (tester) async {
    await tester.pumpWidget(_app(
      ChildLoginCard(
        studentId: 'other',
        loadStudent: (_) async => {'student_code': 'other.kid'},
        loadPassword: (_, __) async =>
            throw Exception('permission-denied'),
      ),
      locale: const Locale('fr'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Identifiants de connexion'), findsOneWidget);
    await tester.tap(find.byKey(const Key('child_password_toggle')));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Le mot de passe ne peut pas être affiché. Demandez-le à l\'école.'),
        findsOneWidget);
  });

  testWidgets('no stored password and no Student ID have their own messages',
      (tester) async {
    await tester.pumpWidget(_app(ChildLoginCard(
      studentId: 'kid',
      loadStudent: (_) async => {'student_code': 'a.b'},
      loadPassword: (_, __) async => '',
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('child_password_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('No password is stored. Ask the school to reset it.'),
        findsOneWidget);

    await tester.pumpWidget(_app(ChildLoginCard(
      key: const ValueKey('b'),
      studentId: 'kid2',
      loadStudent: (_) async => {'first_name': 'X'},
    )));
    await tester.pumpAndSettle();
    expect(find.text('No Student ID yet. Ask the school to set one up.'),
        findsOneWidget);
    expect(find.byKey(const Key('child_password_toggle')), findsNothing);
  });

  test('every new key is translated in French and Arabic', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    for (final code in ['fr', 'ar']) {
      final o = await AppLocalizations.delegate.load(Locale(code));
      final pairs = {
        en.parentChildLoginTitle: o.parentChildLoginTitle,
        en.parentChildLoginPassword: o.parentChildLoginPassword,
        en.parentChildLoginShow: o.parentChildLoginShow,
        en.parentChildLoginHide: o.parentChildLoginHide,
        en.parentChildLoginNoPassword: o.parentChildLoginNoPassword,
        en.parentChildLoginCannotRead: o.parentChildLoginCannotRead,
      };
      pairs.forEach((a, b) => expect(b, isNot(equals(a)), reason: code));
    }
  });
}
