import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/core/utils/platform_utils.dart';

void main() {
  group('PlatformUtils', () {
    group('detectPlatform', () {
      test('should return a platform string when detected', () {
        // Note: Platform depends on test environment
        // Web: flutter test -d chrome returns 'web'
        // Normal: flutter test returns the host platform (macos, linux, windows)
        final platform = PlatformUtils.detectPlatform();
        expect(platform, isNotNull);
        expect(platform, isNotEmpty);
        // Platform should be one of the supported platforms
        final validPlatforms = ['web', 'android', 'ios', 'macos', 'windows', 'linux', 'fuchsia'];
        expect(validPlatforms.contains(platform), isTrue);
      });

      test('should return a valid platform string', () {
        final platform = PlatformUtils.detectPlatform();
        final validPlatforms = ['web', 'android', 'ios', 'macos', 'windows', 'linux', 'fuchsia'];
        expect(validPlatforms.contains(platform), isTrue);
      });

      test('should never return null or empty string', () {
        final platform = PlatformUtils.detectPlatform();
        expect(platform, isNotNull);
        expect(platform, isNotEmpty);
      });
    });

    group('getPlatformDisplayName', () {
      test('should return human-readable names', () {
        final displayName = PlatformUtils.getPlatformDisplayName();
        expect(displayName, isNotNull);
        expect(displayName, isNotEmpty);
        
        // Should be one of the known display names
        final validNames = [
          'Web Browser',
          'Android',
          'iOS',
          'macOS',
          'Windows',
          'Linux',
          'Unknown Platform'
        ];
        expect(validNames.contains(displayName), isTrue);
      });

      test('should return different values for different platforms', () {
        // This is a basic consistency check
        final displayName = PlatformUtils.getPlatformDisplayName();
        final platform = PlatformUtils.detectPlatform();
        
        // Verify the display name matches the platform
        if (platform == 'web') {
          expect(displayName, 'Web Browser');
        } else if (platform == 'android') {
          expect(displayName, 'Android');
        } else if (platform == 'ios') {
          expect(displayName, 'iOS');
        }
      });
    });

    group('isMobile', () {
      test('should return false on web', () {
        if (kIsWeb) {
          expect(PlatformUtils.isMobile(), isFalse);
        }
      });

      test('should return boolean value', () {
        final result = PlatformUtils.isMobile();
        expect(result, isA<bool>());
      });

      test('should be mutually exclusive with isDesktop on non-web', () {
        if (!kIsWeb) {
          final isMobile = PlatformUtils.isMobile();
          final isDesktop = PlatformUtils.isDesktop();
          
          // Should be one or the other, not both
          if (isMobile) {
            expect(isDesktop, isFalse);
          } else if (isDesktop) {
            expect(isMobile, isFalse);
          }
        }
      });
    });

    group('isDesktop', () {
      test('should return false on web', () {
        if (kIsWeb) {
          expect(PlatformUtils.isDesktop(), isFalse);
        }
      });

      test('should return boolean value', () {
        final result = PlatformUtils.isDesktop();
        expect(result, isA<bool>());
      });

      test('should return true for desktop platforms', () {
        final platform = PlatformUtils.detectPlatform();
        final isDesktop = PlatformUtils.isDesktop();
        
        if (platform == 'macos' || platform == 'windows' || platform == 'linux') {
          expect(isDesktop, isTrue);
        }
      });
    });

    group('Platform consistency', () {
      test('detect and display methods should be consistent', () {
        final platform = PlatformUtils.detectPlatform();
        final displayName = PlatformUtils.getPlatformDisplayName();
        
        // Map of expected relationships
        final expectedMappings = {
          'web': 'Web Browser',
          'android': 'Android',
          'ios': 'iOS',
          'macos': 'macOS',
          'windows': 'Windows',
          'linux': 'Linux',
        };
        
        if (expectedMappings.containsKey(platform)) {
          expect(displayName, expectedMappings[platform]);
        }
      });

      test('multiple calls should return same platform', () {
        final platform1 = PlatformUtils.detectPlatform();
        final platform2 = PlatformUtils.detectPlatform();
        final platform3 = PlatformUtils.detectPlatform();
        
        expect(platform1, platform2);
        expect(platform2, platform3);
      });

      test('multiple calls to display name should be consistent', () {
        final name1 = PlatformUtils.getPlatformDisplayName();
        final name2 = PlatformUtils.getPlatformDisplayName();
        
        expect(name1, name2);
      });
    });
  });
}

