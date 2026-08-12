import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alluwalacademyadmin/features/zoom/services/class_roster_contact_service.dart';
import 'package:alluwalacademyadmin/features/zoom/widgets/admin_class_roster_contacts.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

void main() {
  testWidgets('shows student ID, parent name, and parent phone',
      (tester) async {
    const student = ClassStudentContact(
      accountId: 'student-account',
      studentId: 'STU-1042',
      name: 'Nafisatou Bah',
      parents: [
        ClassParentContact(
          id: 'parent-account',
          name: 'Mariam Bah',
          phone: '+1 313 555 0189',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: AdminClassRosterContacts(
              contacts: Future.value(const [student]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nafisatou Bah'), findsOneWidget);
    expect(find.text('Student ID: STU-1042'), findsOneWidget);
    expect(find.text('Parent: Mariam Bah'), findsOneWidget);
    expect(find.text('Phone: +1 313 555 0189'), findsOneWidget);
  });

  testWidgets('shows explicit fallbacks for incomplete contact records',
      (tester) async {
    const student = ClassStudentContact(
      accountId: 'student-account',
      studentId: 'student-account',
      name: 'Student Without Parent',
      parents: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AdminClassRosterContacts(
            contacts: Future.value(const [student]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Student ID: student-account'), findsOneWidget);
    expect(find.text('No parent linked'), findsOneWidget);
  });
}
