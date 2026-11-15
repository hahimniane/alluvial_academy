import 'package:alluwalacademyadmin/core/services/parent_web_cutover.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParentWebCutover.allows (fails closed)', () {
    test('no document keeps every parent on Flutter', () {
      expect(ParentWebCutover.allows(null, 'p1'), isFalse);
    });

    test('off, unknown or missing mode keeps parents on Flutter', () {
      expect(ParentWebCutover.allows({'mode': 'off'}, 'p1'), isFalse);
      expect(ParentWebCutover.allows({'mode': 'everyone'}, 'p1'), isFalse);
      expect(ParentWebCutover.allows({'parentIds': ['p1']}, 'p1'), isFalse);
    });

    test('allowlist moves only the named parents', () {
      final data = {'mode': 'allowlist', 'parentIds': ['p1', 'p2']};
      expect(ParentWebCutover.allows(data, 'p1'), isTrue);
      expect(ParentWebCutover.allows(data, 'p3'), isFalse);
      expect(ParentWebCutover.allows({'mode': 'allowlist'}, 'p1'), isFalse);
      expect(ParentWebCutover.allows({'mode': 'allowlist', 'parentIds': 'p1'}, 'p1'), isFalse);
    });

    test('all moves everyone; mode is trimmed and case-insensitive', () {
      expect(ParentWebCutover.allows({'mode': 'all'}, 'anyone'), isTrue);
      expect(ParentWebCutover.allows({'mode': ' ALL '}, 'anyone'), isTrue);
      expect(ParentWebCutover.allows({'mode': 'Allowlist', 'parentIds': ['p1']}, 'p1'), isTrue);
    });

    test('an empty uid never moves', () {
      expect(ParentWebCutover.allows({'mode': 'all'}, ''), isFalse);
    });
  });
}
