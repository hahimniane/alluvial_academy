import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to persist and restore app routes across refreshes
/// 
/// On web: Uses browser URL and localStorage
/// On mobile: Uses SharedPreferences
class RoutePersistenceService {
  static const String _routeKey = 'last_route_path';
  static const String _routeNameKey = 'last_route_name';

  /// Save the current route
  static Future<void> saveRoute(String routePath, {String? routeName}) async {
    try {
      if (kIsWeb) {
        // On web, save to localStorage via dart:html
        // Also update browser URL if possible
        try {
          // Use shared_preferences which works on web via localStorage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_routeKey, routePath);
          if (routeName != null) {
            await prefs.setString(_routeNameKey, routeName);
          }
        } catch (e) {
          debugPrint('RoutePersistenceService: Error saving route to localStorage: $e');
        }
      } else {
        // On mobile, use SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_routeKey, routePath);
        if (routeName != null) {
          await prefs.setString(_routeNameKey, routeName);
        }
      }
    } catch (e) {
      debugPrint('RoutePersistenceService: Error saving route: $e');
    }
  }

  /// Get the last saved route
  static Future<String?> getLastRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_routeKey);
    } catch (e) {
      debugPrint('RoutePersistenceService: Error getting last route: $e');
      return null;
    }
  }

  /// Get the last saved route name
  static Future<String?> getLastRouteName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_routeNameKey);
    } catch (e) {
      debugPrint('RoutePersistenceService: Error getting last route name: $e');
      return null;
    }
  }

  /// Clear saved route (e.g., on logout)
  static Future<void> clearRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_routeKey);
      await prefs.remove(_routeNameKey);
    } catch (e) {
      debugPrint('RoutePersistenceService: Error clearing route: $e');
    }
  }

  /// Get current route from URL (web only)
  static String? getCurrentRouteFromUrl() {
    if (!kIsWeb) return null;
    
    try {
      // On web, we can use window.location.pathname
      // But since we don't have dart:html imported, we'll rely on SharedPreferences
      // and implement URL sync separately
      return null;
    } catch (e) {
      debugPrint('RoutePersistenceService: Error getting route from URL: $e');
      return null;
    }
  }
}

