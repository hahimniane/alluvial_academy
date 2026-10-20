import 'package:alluwalacademyadmin/core/services/class_contacts_service.dart';
import 'package:alluwalacademyadmin/core/widgets/class_contacts_card.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('ClassContacts.fromMap', () {
    test('reads each role\'s section', () {
      final contacts = ClassContacts.fromMap({
        'students': [
          {
            'studentName': 'Fatou Bah',
            'contacts': [
              {
                'name': 'Mariama Bah',
                'relationship': 'parent',
                'phone': '+44 7981234567',
                'tel': '+447981234567',
              },
            ],
          },
        ],
        'children': [
          {'studentName': 'Zeyna Ly', 'contacts': []},
        ],
        'teachers': [
          {
            'name': 'Amina Diallo',
            'relationship': 'teacher',
            'phone': '+224 621 00 00 01',
            'tel': '+224621000001',
          },
        ],
      });
      expect(contacts.students.single.contacts.single.relationship,
          ClassContactRelationship.parent);
      expect(contacts.children.single.contacts, isEmpty);
      expect(contacts.teachers.single.telUri.toString(), 'tel:+224621000001');
    });

    test('drops entries with no dialable number or unknown relationship', () {
      final contacts = ClassContacts.fromMap({
        'teachers': [
          {'name': 'A', 'relationship': 'teacher', 'phone': '', 'tel': ''},
          {'name': 'B', 'relationship': 'cousin', 'tel': '+15550100099'},
          {'name': 'C', 'relationship': 'teacher', 'tel': 'javascript:1'},
          'junk',
        ],
      });
      expect(contacts.teachers, isEmpty);
      expect(ClassContacts.fromMap(null).students, isEmpty);
    });
  });

  Widget app(Widget child) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('lists each student with their parents and a call button',
      (tester) async {
    await tester.pumpWidget(app(const ClassContactGroupList(groups: [
      ClassContactGroup(studentName: 'Fatou Bah', contacts: [
        ClassContact(
          name: 'Mariama Bah',
          relationship: ClassContactRelationship.parent,
          phone: '+44 7981234567',
          tel: '+447981234567',
        ),
      ]),
      ClassContactGroup(studentName: 'Zeyna Ly', contacts: []),
    ])));
    await tester.pump();

    expect(find.text('Fatou Bah'), findsOneWidget);
    expect(find.text('Mariama Bah · Parent'), findsOneWidget);
    expect(find.text('+44 7981234567'), findsOneWidget);
    expect(find.byTooltip('Call Mariama Bah'), findsOneWidget);
    expect(find.byTooltip('Copy number'), findsOneWidget);
    expect(find.text('No phone number on file'), findsOneWidget);
  });
}
