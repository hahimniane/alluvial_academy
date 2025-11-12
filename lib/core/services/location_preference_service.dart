import 'package:shared_preferences/shared_preferences.dart';

import 'package:alluwalacademyadmin/core/utils/app_logger.dart';

class LocationPreferenceService {
  static const String _hasAskedForLocationKey = 'has_asked_for_location';
  static const String _locationPermissionDeniedKey =
      'location_permission_denied';
  static const String _lastLocationRequestKey = 'last_location_request';

  /// Mark that we've asked for location permission
  static Future<void> markLocationAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasAskedForLocationKey, true);
      await prefs.setInt(
          _lastLocationRequestKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.error('LocationPreferenceService: Error marking location asked: $e');
    }
  }

  /// Check if we've already asked for location permission recently
  static Future<bool> hasAskedForLocationRecently() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAsked = prefs.getBool(_hasAskedForLocationKey) ?? false;
      final lastRequest = prefs.getInt(_lastLocationRequestKey) ?? 0;

      if (!hasAsked) return false;

      // Check if it was within the last hour
      final lastRequestTime = DateTime.fromMillisecondsSinceEpoch(lastRequest);
      final hourAgo = DateTime.now().subtract(const Duration(hours: 1));

      return lastRequestTime.isAfter(hourAgo);
    } catch (e) {
      AppLogger.error('LocationPreferenceService: Error checking location asked: $e');
      return false;
    }
  }

  /// Mark that location permission was denied
  static Future<void> markLocationDenied() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_locationPermissionDeniedKey, true);
    } catch (e) {
      AppLogger.error('LocationPreferenceService: Error marking location denied: $e');
    }
  }

  /// Check if location permission was previously denied
  static Future<bool> wasLocationDenied() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_locationPermissionDeniedKey) ?? false;
    } catch (e) {
      AppLogger.error('LocationPreferenceService: Error checking location denied: $e');
      return false;
    }
  }

  /// Clear location preferences (for testing or reset)
  static Future<void> clearPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hasAskedForLocationKey);
      await prefs.remove(_locationPermissionDeniedKey);
      await prefs.remove(_lastLocationRequestKey);
    } catch (e) {
      AppLogger.error('LocationPreferenceService: Error clearing preferences: $e');
    }
  }

  /// Check if we should skip location request (already denied or asked recently)
  static Future<bool> shouldSkipLocationRequest() async {
    final denied = await wasLocationDenied();
    final recentlyAsked = await hasAskedForLocationRecently();

    return denied || recentlyAsked;
  }
}
