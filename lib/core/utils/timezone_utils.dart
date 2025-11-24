import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  static Future<String> detectUserTimezone() async {
    if (kIsWeb) {
      // On web, use JavaScript Intl API to get IANA timezone
      return _detectWebTimezone();
    } else {
      // On mobile/desktop, use flutter_timezone plugin
      try {
        final dynamic timezoneInfo = await FlutterTimezone.getLocalTimezone();
        // In version 5.0.1+, this returns TimezoneInfo, but in older versions it returned String.
        // We use dynamic to handle both cases safely or use toString() if identifier is missing.
        if (timezoneInfo is String) {
          return timezoneInfo;
        }
        // Assuming TimezoneInfo has an identifier property based on docs,
        // but if not, toString() often gives the ID or we can inspect it.
        // Let's try to access identifier via dynamic to avoid type errors if the analyzer is confused.
        try {
          return timezoneInfo.identifier as String;
        } catch (_) {
          return timezoneInfo.toString();
        }
      } catch (e) {
        AppLogger.error('Error detecting timezone: $e');
        return 'UTC';
      }
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
      AppLogger.error(
          'TimezoneUtils: Converting $localTime from $timezoneId to UTC: ${tzDateTime.toUtc()}');
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

  /// Format a conversion preview string (e.g., "10:00 AM (EST) ≈ 7:00 AM (PST)")
  static String formatConversion(
      DateTime dateTime, String fromTz, String toTz) {
    if (!_initialized) initializeTimezones();

    try {
      // Create a TZDateTime in the source timezone
      final fromLocation = tz.getLocation(fromTz);
      final fromTime = tz.TZDateTime(
        fromLocation,
        dateTime.year,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
        dateTime.minute,
      );

      // Convert to target timezone
      final toLocation = tz.getLocation(toTz);
      final toTime = tz.TZDateTime.from(fromTime, toLocation);

      final formatter = DateFormat('h:mm a');
      final fromAbbr = getTimezoneAbbreviation(fromTz);
      final toAbbr = getTimezoneAbbreviation(toTz);

      return '${formatter.format(fromTime)} ($fromAbbr) ≈ ${formatter.format(toTime)} ($toAbbr)';
    } catch (e) {
      AppLogger.error('Error formatting conversion: $e');
      return '';
    }
  }

  /// Get list of common timezones for dropdown
  static List<String> getCommonTimezones() {
    return [
      'UTC',
      'Africa/Abidjan',
      'Africa/Accra',
      'Africa/Algiers',
      'Africa/Cairo',
      'Africa/Casablanca',
      'Africa/Johannesburg',
      'Africa/Lagos',
      'Africa/Nairobi',
      'Africa/Tunis',
      'America/Anchorage',
      'America/Argentina/Buenos_Aires',
      'America/Bogota',
      'America/Caracas',
      'America/Chicago',
      'America/Denver',
      'America/Halifax',
      'America/Lima',
      'America/Los_Angeles',
      'America/Mexico_City',
      'America/New_York',
      'America/Phoenix',
      'America/Santiago',
      'America/Sao_Paulo',
      'America/St_Johns',
      'America/Toronto',
      'America/Vancouver',
      'Asia/Baghdad',
      'Asia/Bangkok',
      'Asia/Beirut',
      'Asia/Dhaka',
      'Asia/Dubai',
      'Asia/Hong_Kong',
      'Asia/Jakarta',
      'Asia/Karachi',
      'Asia/Kathmandu',
      'Asia/Kolkata',
      'Asia/Kuala_Lumpur',
      'Asia/Kuwait',
      'Asia/Manila',
      'Asia/Riyadh',
      'Asia/Seoul',
      'Asia/Shanghai',
      'Asia/Singapore',
      'Asia/Taipei',
      'Asia/Tehran',
      'Asia/Tokyo',
      'Asia/Yangon',
      'Australia/Adelaide',
      'Australia/Brisbane',
      'Australia/Darwin',
      'Australia/Melbourne',
      'Australia/Perth',
      'Australia/Sydney',
      'Europe/Amsterdam',
      'Europe/Athens',
      'Europe/Berlin',
      'Europe/Brussels',
      'Europe/Budapest',
      'Europe/Copenhagen',
      'Europe/Dublin',
      'Europe/Helsinki',
      'Europe/Istanbul',
      'Europe/Lisbon',
      'Europe/London',
      'Europe/Madrid',
      'Europe/Moscow',
      'Europe/Oslo',
      'Europe/Paris',
      'Europe/Prague',
      'Europe/Rome',
      'Europe/Stockholm',
      'Europe/Vienna',
      'Europe/Warsaw',
      'Europe/Zurich',
      'Pacific/Auckland',
      'Pacific/Fiji',
      'Pacific/Guam',
      'Pacific/Honolulu',
    ];
  }
}
