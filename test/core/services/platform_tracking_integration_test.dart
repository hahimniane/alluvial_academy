import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/core/utils/platform_utils.dart';

/// Integration tests for platform tracking feature
/// These tests verify the end-to-end flow of platform detection and storage
void main() {
  group('Platform Tracking Integration Tests', () {
    group('Clock-in Flow', () {
      test('should detect platform before clock-in', () {
        // Simulate the flow in TimeClockScreen
        final platform = PlatformUtils.detectPlatform();
        
        expect(platform, isNotNull);
        expect(platform, isNotEmpty);
        expect(platform, isA<String>());
      });

      test('should provide consistent platform throughout clock-in process', () {
        // Detect platform at start of clock-in
        final platformAtStart = PlatformUtils.detectPlatform();
        
        // Simulate some processing time
        final platformDuringProcess = PlatformUtils.detectPlatform();
        
        // Verify platform hasn't changed
        expect(platformDuringProcess, platformAtStart);
      });

      test('should handle platform detection in different contexts', () {
        // Test that platform detection works regardless of when/where it's called
        final contexts = <String, String>{};
        
        contexts['initial'] = PlatformUtils.detectPlatform();
        contexts['second'] = PlatformUtils.detectPlatform();
        contexts['third'] = PlatformUtils.detectPlatform();
        
        // All should be the same
        expect(contexts['initial'], contexts['second']);
        expect(contexts['second'], contexts['third']);
      });
    });

    group('Platform Validation', () {
      test('should only return known platform values', () {
        final platform = PlatformUtils.detectPlatform();
        final validPlatforms = [
          'web',
          'android',
          'ios',
          'macos',
          'windows',
          'linux',
          'fuchsia'
        ];
        
        expect(validPlatforms.contains(platform), isTrue,
            reason: 'Platform "$platform" is not in the valid platforms list');
      });

      test('should never return "unknown" from detectPlatform', () {
        final platform = PlatformUtils.detectPlatform();
        expect(platform, isNot('unknown'));
        expect(platform, isNot('Unknown'));
      });

      test('platform string should be lowercase', () {
        final platform = PlatformUtils.detectPlatform();
        expect(platform, platform.toLowerCase(),
            reason: 'Platform should be lowercase for consistency');
      });
    });

    group('Display Name Mapping', () {
      test('should map platforms to proper display names', () {
        final platform = PlatformUtils.detectPlatform();
        final displayName = PlatformUtils.getPlatformDisplayName();
        
        // Create expected mapping
        final expectedMappings = {
          'web': 'Web Browser',
          'android': 'Android',
          'ios': 'iOS',
          'macos': 'macOS',
          'windows': 'Windows',
          'linux': 'Linux',
        };
        
        if (expectedMappings.containsKey(platform)) {
          expect(displayName, expectedMappings[platform],
              reason: 'Display name for "$platform" should be "${expectedMappings[platform]}"');
        }
      });

      test('display name should be human-readable', () {
        final displayName = PlatformUtils.getPlatformDisplayName();
        
        // Should contain at least one capital letter and no underscores
        expect(displayName.contains(RegExp(r'[A-Z]')), isTrue,
            reason: 'Display name should have capital letters');
        expect(displayName.contains('_'), isFalse,
            reason: 'Display name should not have underscores');
      });
    });

    group('Platform-specific Behavior', () {
      test('web platform should not be mobile', () {
        final platform = PlatformUtils.detectPlatform();
        if (platform == 'web') {
          expect(PlatformUtils.isMobile(), isFalse);
        }
      });

      test('web platform should not be desktop', () {
        final platform = PlatformUtils.detectPlatform();
        if (platform == 'web') {
          expect(PlatformUtils.isDesktop(), isFalse);
        }
      });

      test('android should be identified as mobile', () {
        final platform = PlatformUtils.detectPlatform();
        if (platform == 'android') {
          expect(PlatformUtils.isMobile(), isTrue);
          expect(PlatformUtils.isDesktop(), isFalse);
        }
      });

      test('ios should be identified as mobile', () {
        final platform = PlatformUtils.detectPlatform();
        if (platform == 'ios') {
          expect(PlatformUtils.isMobile(), isTrue);
          expect(PlatformUtils.isDesktop(), isFalse);
        }
      });

      test('desktop platforms should be identified correctly', () {
        final platform = PlatformUtils.detectPlatform();
        final desktopPlatforms = ['macos', 'windows', 'linux'];
        
        if (desktopPlatforms.contains(platform)) {
          expect(PlatformUtils.isDesktop(), isTrue);
          expect(PlatformUtils.isMobile(), isFalse);
        }
      });
    });

    group('Error Handling', () {
      test('should handle repeated calls without errors', () {
        expect(() {
          for (int i = 0; i < 100; i++) {
            PlatformUtils.detectPlatform();
          }
        }, returnsNormally);
      });

      test('should handle concurrent calls', () async {
        final futures = List.generate(
          10,
          (index) => Future(() => PlatformUtils.detectPlatform()),
        );

        final results = await Future.wait(futures);
        
        // All results should be the same platform
        expect(results, isNotEmpty);
        expect(results.every((r) => r == results.first), isTrue);
      });

      test('should not throw exceptions', () {
        expect(() => PlatformUtils.detectPlatform(), returnsNormally);
        expect(() => PlatformUtils.getPlatformDisplayName(), returnsNormally);
        expect(() => PlatformUtils.isMobile(), returnsNormally);
        expect(() => PlatformUtils.isDesktop(), returnsNormally);
      });
    });

    group('Data Integrity', () {
      test('platform string should be suitable for database storage', () {
        final platform = PlatformUtils.detectPlatform();
        
        // Should not contain special characters
        expect(platform.contains(' '), isFalse);
        expect(platform.contains('\n'), isFalse);
        expect(platform.contains('\t'), isFalse);
        expect(platform.contains('/'), isFalse);
        expect(platform.contains('\\'), isFalse);
      });

      test('platform string should be of reasonable length', () {
        final platform = PlatformUtils.detectPlatform();
        
        expect(platform.length, lessThan(20),
            reason: 'Platform string should be short for efficient storage');
        expect(platform.length, greaterThan(2),
            reason: 'Platform string should be descriptive');
      });

      test('should return consistent results for querying', () {
        // Simulate multiple components checking platform
        final results = <String>[];
        
        for (int i = 0; i < 5; i++) {
          results.add(PlatformUtils.detectPlatform());
        }
        
        // All results should be identical
        expect(results.toSet().length, 1,
            reason: 'Platform detection should return consistent results');
      });
    });

    group('Real-world Scenarios', () {
      test('should support clock-in analytics workflow', () {
        // Step 1: Detect platform
        final platform = PlatformUtils.detectPlatform();
        expect(platform, isNotNull);
        
        // Step 2: Get display name for UI
        final displayName = PlatformUtils.getPlatformDisplayName();
        expect(displayName, isNotNull);
        
        // Step 3: Check if mobile for responsive behavior
        final isMobile = PlatformUtils.isMobile();
        expect(isMobile, isA<bool>());
        
        // All operations should complete without errors
      });

      test('should support filtering by platform', () {
        final platform = PlatformUtils.detectPlatform();
        
        // Simulate filtering logic
        final webClockIns = platform == 'web';
        final mobileClockIns = platform == 'android' || platform == 'ios';
        final desktopClockIns = platform == 'macos' || 
                                 platform == 'windows' || 
                                 platform == 'linux';
        
        // Should be exactly one category
        final categoryCounts = [webClockIns, mobileClockIns, desktopClockIns]
            .where((category) => category)
            .length;
        
        expect(categoryCounts, lessThanOrEqualTo(1),
            reason: 'Platform should fit into at most one category');
      });

      test('should support platform-based troubleshooting', () {
        final platform = PlatformUtils.detectPlatform();
        final displayName = PlatformUtils.getPlatformDisplayName();
        
        // Create a mock error report
        final errorReport = {
          'platform': platform,
          'platform_display': displayName,
          'is_mobile': PlatformUtils.isMobile(),
          'is_desktop': PlatformUtils.isDesktop(),
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        // Verify all fields are populated
        expect(errorReport['platform'], isNotNull);
        expect(errorReport['platform_display'], isNotNull);
        expect(errorReport['is_mobile'], isA<bool>());
        expect(errorReport['is_desktop'], isA<bool>());
      });
    });

    group('Performance', () {
      test('should detect platform quickly', () {
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 1000; i++) {
          PlatformUtils.detectPlatform();
        }
        
        stopwatch.stop();
        
        // Should complete 1000 calls in less than 1 second
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
            reason: 'Platform detection should be fast');
      });

      test('should not accumulate memory with repeated calls', () {
        // This is a basic check - more thorough memory testing would require profiling
        expect(() {
          for (int i = 0; i < 10000; i++) {
            PlatformUtils.detectPlatform();
            PlatformUtils.getPlatformDisplayName();
            PlatformUtils.isMobile();
            PlatformUtils.isDesktop();
          }
        }, returnsNormally);
      });
    });
  });
}

