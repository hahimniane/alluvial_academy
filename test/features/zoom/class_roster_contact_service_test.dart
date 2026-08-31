import 'package:flutter_test/flutter_test.dart';

import 'package:alluwalacademyadmin/features/zoom/services/class_roster_contact_service.dart';

void main() {
  group('ClassRosterContactParser', () {
    test('reads names from snake_case and camelCase user records', () {
      expect(
        ClassRosterContactParser.displayName(
          {
            'first_name': 'Aliou',
            'last_name': 'Diallo',
          },
          fallback: 'fallback',
        ),
        'Aliou Diallo',
      );
      expect(
        ClassRosterContactParser.displayName(
          {
            'firstName': 'Aissatou',
            'lastName': 'Bah',
          },
          fallback: 'fallback',
        ),
        'Aissatou Bah',
      );
    });

    test('uses the student code and falls back to the account ID', () {
      expect(
        ClassRosterContactParser.studentId(
          {'student_code': 'STU-1042'},
          fallback: 'firebase-uid',
        ),
        'STU-1042',
      );
      expect(
        ClassRosterContactParser.studentId(
          const {},
          fallback: 'firebase-uid',
        ),
        'firebase-uid',
      );
    });

    test('combines and deduplicates legacy guardian link fields', () {
      expect(
        ClassRosterContactParser.guardianIds({
          'guardian_ids': ['parent-1', 'parent-2'],
          'guardianIds': ['parent-2', 'parent-3'],
          'parent_id': 'parent-4',
        }),
        ['parent-1', 'parent-2', 'parent-3', 'parent-4'],
      );
    });

    test('reads supported parent phone fields and ignores blank values', () {
      expect(
        ClassRosterContactParser.phoneNumber({
          'phone_number': ' ',
          'mobilePhone': '+1 313 555 0189',
        }),
        '+1 313 555 0189',
      );
      expect(ClassRosterContactParser.phoneNumber(const {}), isNull);
    });
  });

  test('student contact keeps a visible fallback when profile data is sparse',
      () {
    const parent = ClassParentContact(
      id: 'parent-1',
      name: 'Mariam Diallo',
      phone: '+1 313 555 0100',
    );

    final contact = ClassStudentContact.fromUserData(
      accountId: 'student-account-id',
      data: const {},
      fallbackName: 'Aliou Diallo',
      parents: const [parent],
    );

    expect(contact.name, 'Aliou Diallo');
    expect(contact.studentId, 'student-account-id');
    expect(contact.parents.single.name, 'Mariam Diallo');
    expect(contact.parents.single.phone, '+1 313 555 0100');
  });
}
