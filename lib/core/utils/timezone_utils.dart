import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

import 'web_timezone_detector.dart'
    if (dart.library.io) 'web_timezone_detector_stub.dart';

class TimezoneUtils {
  static bool _initialized = false;

  /// Initialize timezone database (call once at app startup)
  static void initializeTimezones() {
    if (!_initialized) {
      tz.initializeTimeZones();
      _initialized = true;
    }
  }

  /// Detect user's timezone based on platform
  static String detectUserTimezone() {
    if (kIsWeb) {
      // On web, use JavaScript Intl API to get IANA timezone
      return _detectWebTimezone();
    } else {
      // On mobile/desktop, use system's local timezone
      return DateTime.now().timeZoneName;
    }
  }

  /// Web-specific timezone detection using JS interop
  static String _detectWebTimezone() {
    try {
      return detectWebTimezone();
    } catch (e) {
      AppLogger.error('Error detecting web timezone: $e');
      return 'UTC';
    }
  }

  /// Convert a UTC DateTime to a specific timezone
  static DateTime convertToTimezone(DateTime utcTime, String timezoneId) {
    if (!_initialized) initializeTimezones();

    try {
      final location = tz.getLocation(timezoneId);
      return tz.TZDateTime.from(utcTime.toUtc(), location);
    } catch (e) {
      AppLogger.error('Error converting to timezone $timezoneId: $e');
      return utcTime;
    }
  }

  /// Convert a local DateTime in a specific timezone to UTC
  static DateTime convertToUtc(DateTime localTime, String timezoneId) {
    if (!_initialized) initializeTimezones();

    try {
      // If timezone is UTC, return as-is
      if (timezoneId == 'UTC') {
        return localTime.toUtc();
      }

      final location = tz.getLocation(timezoneId);
      final tzDateTime = tz.TZDateTime(
        location,
        localTime.year,
        localTime.month,
        localTime.day,
        localTime.hour,
        localTime.minute,
        localTime.second,
        localTime.millisecond,
        localTime.microsecond,
      );
      AppLogger.error('TimezoneUtils: Converting $localTime from $timezoneId to UTC: ${tzDateTime.toUtc()}');
      return tzDateTime.toUtc();
    } catch (e) {
      AppLogger.error('Error converting from timezone $timezoneId: $e');
      AppLogger.error('TimezoneUtils: Falling back to treating as local time');
      // Fallback: treat as local time and convert to UTC
      return localTime;
    }
  }

  /// Format DateTime with timezone info
  static String formatWithTimezone(DateTime dateTime, String timezoneId) {
    final converted = convertToTimezone(dateTime, timezoneId);
    final formatter = DateFormat('MMM dd, yyyy h:mm a');
    return '${formatter.format(converted)} ${getTimezoneAbbreviation(timezoneId)}';
  }

  /// Get timezone abbreviation (e.g., EST, PST)
  static String getTimezoneAbbreviation(String timezoneId) {
    try {
      final location = tz.getLocation(timezoneId);
      final now = tz.TZDateTime.now(location);
      return now.timeZone.abbreviation;
    } catch (e) {
      return timezoneId.split('/').last;
    }
  }

  /// Get list of common timezones for dropdown
  static List<String> getCommonTimezones() {
    return [
      'UTC',
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
      'America/Toronto',
      'America/Vancouver',
      'America/Mexico_City',
      'America/Sao_Paulo',
      'Europe/London',
      'Europe/Paris',
      'Europe/Berlin',
      'Europe/Moscow',
      'Africa/Cairo',
      'Africa/Johannesburg',
      'Asia/Dubai',
      'Asia/Karachi',
      'Asia/Kolkata',
      'Asia/Bangkok',
      'Asia/Shanghai',
      'Asia/Tokyo',
      'Asia/Seoul',
      'Australia/Sydney',
      'Australia/Melbourne',
      'Pacific/Auckland',
    ];
  }
}
