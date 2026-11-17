import 'package:alluwalacademyadmin/features/user_management/services/admin_users_web_cutover.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminUsersWebCutover.allows (fails closed)', () {
    test('no document keeps every admin on the Flutter screen', () {
      expect(AdminUsersWebCutover.allows(null, 'a1'), isFalse);
      expect(AdminUsersWebCutover.allows({}, 'a1'), isFalse);
    });

    test('off, unknown or missing mode keeps admins on Flutter', () {
      expect(AdminUsersWebCutover.allows({'mode': 'off', 'adminIds': ['a1']}, 'a1'), isFalse);
      expect(AdminUsersWebCutover.allows({'mode': 'everyone'}, 'a1'), isFalse);
      expect(AdminUsersWebCutover.allows({'adminIds': ['a1']}, 'a1'), isFalse);
    });

    test('allowlist moves only the named admins', () {
      final data = {'mode': 'allowlist', 'adminIds': ['a1', 'a2']};
      expect(AdminUsersWebCutover.allows(data, 'a1'), isTrue);
      expect(AdminUsersWebCutover.allows(data, 'a3'), isFalse);
      expect(AdminUsersWebCutover.allows({'mode': 'allowlist'}, 'a1'), isFalse);
      expect(AdminUsersWebCutover.allows({'mode': 'allowlist', 'adminIds': 'a1'}, 'a1'), isFalse);
      // The parent switch's key does not count here.
      expect(AdminUsersWebCutover.allows({'mode': 'allowlist', 'parentIds': ['a1']}, 'a1'), isFalse);
    });

    test('all moves everyone; mode is trimmed and case-insensitive', () {
      expect(AdminUsersWebCutover.allows({'mode': 'all'}, 'anyone'), isTrue);
      expect(AdminUsersWebCutover.allows({'mode': ' ALL '}, 'anyone'), isTrue);
      expect(AdminUsersWebCutover.allows({'mode': ' AllowList ', 'adminIds': ['a1']}, 'a1'), isTrue);
    });

    test('an empty uid never moves', () {
      expect(AdminUsersWebCutover.allows({'mode': 'all'}, ''), isFalse);
    });
  });

  test('off the web the switch is never read and the answer is no', () async {
    AdminUsersWebCutover.reset();
    expect(await AdminUsersWebCutover.shouldUseWebPage('a1'), isFalse);
  });
}
