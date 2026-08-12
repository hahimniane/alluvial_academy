import 'package:alluwalacademyadmin/core/utils/app_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSearch', () {
    test('normalizes names and supports exact-name mode', () {
      expect(
        AppSearch.matches(
          query: '  ALIOU   DIALLO ',
          names: const ['Aliou Diallo'],
          nameMode: SearchNameMode.exact,
        ),
        isTrue,
      );
      expect(
        AppSearch.matches(
          query: 'Aliou Diallo',
          names: const ['Aissatou Diallo'],
          nameMode: SearchNameMode.exact,
        ),
        isFalse,
      );
    });

    test('supports partial name and case-insensitive email searches', () {
      expect(
        AppSearch.matches(
          query: 'aliou',
          names: const ['Aliou Diallo'],
        ),
        isTrue,
      );
      expect(
        AppSearch.matches(
          query: 'DIALLO@EXAMPLE',
          emails: const ['aliou.diallo@example.com'],
        ),
        isTrue,
      );
    });

    test('normalizes phone numbers with optional country codes', () {
      expect(
        AppSearch.matches(
          query: '202 555 0147',
          phones: const ['+1 (202) 555-0147'],
        ),
        isTrue,
      );
      expect(
        AppSearch.matches(
          query: '+1 202-555-0147',
          phones: const ['2025550147'],
        ),
        isTrue,
      );
      expect(
        AppSearch.matches(
          query: '+44 20 7946 0958',
          phones: const ['020 7946 0958'],
        ),
        isTrue,
      );
    });

    test('supports IDs and contextual values', () {
      expect(
        AppSearch.matches(
          query: 'user-1042',
          ids: const ['parent-user-1042'],
        ),
        isTrue,
      );
      expect(
        AppSearch.matches(
          query: '2026-041',
          additionalValues: const ['INV-2026-041'],
        ),
        isTrue,
      );
      expect(
        AppSearch.matches(
          query: 'STU 2048',
          ids: const ['STU-2048'],
        ),
        isTrue,
      );
    });

    test('normalizes common user map field variants', () {
      final user = <String, dynamic>{
        'first_name': 'Aminata',
        'last_name': 'Bah',
        'e-mail': 'aminata@example.com',
        'mobile_phone': '+224 622 123 456',
        'student_code': 'STU-2048',
        'role': 'Student',
      };

      expect(
        AppSearch.matchesMap(query: 'Aminata Bah', data: user),
        isTrue,
      );
      expect(
        AppSearch.matchesMap(query: 'aminata@example', data: user),
        isTrue,
      );
      expect(
        AppSearch.matchesMap(query: '622123456', data: user),
        isTrue,
      );
      expect(
        AppSearch.matchesMap(query: 'STU-2048', data: user),
        isTrue,
      );
      expect(
        AppSearch.matchesMap(
          query: 'student',
          data: user,
          additionalValues: [user['role'].toString()],
        ),
        isTrue,
      );
    });

    test('rejects short phone fragments', () {
      expect(
        AppSearch.matches(
          query: '0147',
          phones: const ['+1 (202) 555-0147'],
        ),
        isFalse,
      );
    });
  });
}
