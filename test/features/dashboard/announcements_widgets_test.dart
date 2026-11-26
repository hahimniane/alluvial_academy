import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alluwalacademyadmin/core/models/announcement.dart';
import 'package:alluwalacademyadmin/core/widgets/announcements_card.dart';
import 'package:alluwalacademyadmin/features/dashboard/widgets/admin_cards/announcements_admin_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Announcement _item({bool pinned = false, String body = 'Line one\nLine two'}) =>
    Announcement(
      id: 'a1',
      title: 'Bayana update',
      body: body,
      audience: Announcement.roles,
      pinned: pinned,
      expiresAt: null,
      createdAt: DateTime(2026, 11, 20),
      createdByName: 'School office',
      published: true,
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'a tile shows the title, byline and the message with its line breaks',
      (tester) async {
    await tester.pumpWidget(_app(AnnouncementTile(
        item: _item(pinned: true), expanded: false, onToggle: () {})));
    expect(find.text('Bayana update'), findsOneWidget);
    expect(find.text('School office · Nov 20, 2026'), findsOneWidget);
    expect(find.text('Line one\nLine two'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('a long message folds behind Show more', (tester) async {
    var toggled = false;
    await tester.pumpWidget(_app(AnnouncementTile(
      item: _item(body: 'word ' * 80),
      expanded: false,
      onToggle: () => toggled = true,
    )));
    await tester.tap(find.text('Show more'));
    expect(toggled, isTrue);
  });

  testWidgets('the pop-up closes on Got it, in French too', (tester) async {
    await tester.pumpWidget(_app(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AnnouncementPopup(item: _item(pinned: true))),
          child: const Text('open'),
        ),
      ),
      locale: const Locale('fr'),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('ANNONCE'), findsOneWidget);
    expect(find.text('Bayana update'), findsOneWidget);
    await tester.tap(find.text('Compris'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnouncementPopup), findsNothing);
  });

  testWidgets('the new-announcement form says what is missing before posting',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const SizedBox()));
    showDialog<void>(
      context: tester.element(find.byType(SizedBox).first),
      builder: (_) => const NewAnnouncementDialog(),
    );
    await tester.pumpAndSettle();

    expect(find.text('New announcement'), findsOneWidget);
    for (final label in ['Teachers', 'Students', 'Parents', 'Admins']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Pin to the top'), findsOneWidget);
    expect(find.text('Show until'), findsOneWidget);
    expect(find.text('No end date'), findsOneWidget);
    expect(find.text('Send as a phone notification too'), findsOneWidget);

    await tester.tap(find.text('Post'));
    await tester.pump();
    expect(find.text('Add a title.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Bayana update');
    await tester.tap(find.text('Post'));
    await tester.pump();
    expect(find.text('Write a message.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Message'), 'Starts Friday.');
    for (final label in ['Teachers', 'Students', 'Parents', 'Admins']) {
      await tester.tap(find.text(label));
    }
    await tester.tap(find.text('Post'));
    await tester.pump();
    expect(find.text('Choose at least one group.'), findsOneWidget);
  });
}
