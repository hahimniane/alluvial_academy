import 'package:alluwalacademyadmin/features/user_management/utils/parent_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parent selector search', () {
    final parent = buildParentSearchRecord(
      documentId: 'parent-uid-1042',
      data: const {
        'first_name': 'Nene',
        'last_name': 'Diallo',
        'email': 'nene.diallo@example.com',
        'country_code': '+224',
        'phone_number': '622 123 456',
        'kiosk_code': 'PAR-2048',
        'unrelated_field': 'preserved',
      },
      studentCount: 5,
    );

    test('preserves the parent record and builds canonical display fields', () {
      expect(parent['name'], 'Nene Diallo');
      expect(parent['email'], 'nene.diallo@example.com');
      expect(parent['phone_number'], '+224622 123 456');
      expect(parent['id'], 'parent-uid-1042');
      expect(parent['studentCount'], 5);
      expect(parent['unrelated_field'], 'preserved');
    });

    test('finds a parent by partial name', () {
      expect(matchesParentSearch(parent, 'nene'), isTrue);
      expect(matchesParentSearch(parent, 'DIALLO'), isTrue);
    });

    test('finds a parent by email, local phone, full phone, and IDs', () {
      expect(matchesParentSearch(parent, 'nene.diallo@example'), isTrue);
      expect(matchesParentSearch(parent, '622123456'), isTrue);
      expect(matchesParentSearch(parent, '+224 622 123 456'), isTrue);
      expect(matchesParentSearch(parent, 'parent-uid-1042'), isTrue);
      expect(matchesParentSearch(parent, 'PAR-2048'), isTrue);
    });

    test('supports legacy parent field variants', () {
      final legacyParent = buildParentSearchRecord(
        documentId: 'legacy-parent',
        data: const {
          'displayName': 'Aminata Bah',
          'e-mail': 'aminata@yahoo.com',
          'countryCode': '+1',
          'mobilePhone': '+1 (202) 555-0147',
          'kioskCode': 'PARENT-77',
        },
        studentCount: 1,
      );

      expect(matchesParentSearch(legacyParent, 'Aminata'), isTrue);
      expect(matchesParentSearch(legacyParent, 'aminata@yahoo'), isTrue);
      expect(matchesParentSearch(legacyParent, '2025550147'), isTrue);
      expect(matchesParentSearch(legacyParent, 'PARENT-77'), isTrue);
    });

    test('does not return unrelated parents', () {
      expect(matchesParentSearch(parent, 'Aissatou Barry'), isFalse);
    });
  });
}
