import 'package:flutter_test/flutter_test.dart';
import 'package:alluwalacademyadmin/core/utils/timezone_utils.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUp(() {
    tz.initializeTimeZones();
  });

  group('Timezone Handling Tests', () {
    test('should correctly convert local time to UTC for a specific timezone',
        () {
      // Arrange
      const String timezoneId = 'America/New_York';
      // Create a date: 2023-01-01 10:00:00 in New York
      // New York is UTC-5 in January (Standard Time)
      final DateTime localTime = DateTime(2023, 1, 1, 10, 0, 0);

      // Act
      final DateTime utcTime =
          TimezoneUtils.convertToUtc(localTime, timezoneId);

      // Assert
      // 10:00 NY + 5 hours = 15:00 UTC
      final expectedUtc = DateTime.utc(2023, 1, 1, 15, 0, 0);
      expect(utcTime, equals(expectedUtc));
    });

    test('should correctly handle Daylight Saving Time', () {
      // Arrange
      const String timezoneId = 'America/New_York';
      // Create a date: 2023-06-01 10:00:00 in New York
      // New York is UTC-4 in June (Daylight Saving Time)
      final DateTime localTime = DateTime(2023, 6, 1, 10, 0, 0);

      // Act
      final DateTime utcTime =
          TimezoneUtils.convertToUtc(localTime, timezoneId);

      // Assert
      // 10:00 NY + 4 hours = 14:00 UTC
      final expectedUtc = DateTime.utc(2023, 6, 1, 14, 0, 0);
      expect(utcTime, equals(expectedUtc));
    });

    test('should handle UTC timezone correctly', () {
      // Arrange
      const String timezoneId = 'UTC';
      final DateTime localTime = DateTime(2023, 1, 1, 10, 0, 0);

      // Act
      final DateTime utcTime =
          TimezoneUtils.convertToUtc(localTime, timezoneId);

      // Assert
      final expectedUtc = DateTime.utc(2023, 1, 1, 10, 0, 0);
      expect(utcTime, equals(expectedUtc));
    });
  });
}
