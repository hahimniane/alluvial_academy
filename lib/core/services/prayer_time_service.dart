import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

class PrayerTime {
  final String name;
  final DateTime time;
  final bool isNext;

  PrayerTime({
    required this.name,
    required this.time,
    this.isNext = false,
  });
}

class PrayerTimeService {
  static const String _cacheKeyPrefix = 'prayer_times_';
  static const String _locationCacheKey = 'cached_prayer_location';
  static const Duration _cacheValidDuration = Duration(hours: 12);

  static PrayerTime? _nextPrayer;
  static DateTime? _cacheTime;
  static List<PrayerTime>? _cachedPrayers;

  /// Get prayer times for today based on user location
  static Future<List<PrayerTime>> getTodayPrayerTimes() async {
    try {
      // Check cache first
      if (_isValidCache()) {
        print('PrayerTimeService: Using cached prayer times');
        return _cachedPrayers!;
      }

      // Try to get cached data first as fallback
      final fallbackPrayers = await _getCachedPrayerTimes();

      // Get user location with timeout
      LocationData? location;
      try {
        location = await LocationService.getCurrentLocation(interactive: false)
            .timeout(const Duration(seconds: 15), onTimeout: () {
          print('PrayerTimeService: Location request timed out');
          return null;
        });
      } catch (e) {
        print('PrayerTimeService: Location service error: $e');
        location = null;
      }

      if (location == null) {
        print(
            'PrayerTimeService: Could not get location, using cached or default times');
        return fallbackPrayers ?? _getDefaultPrayerTimes();
      }

      // Fetch prayer times from Al Adhan API
      final prayerTimes =
          await _fetchPrayerTimesFromAPI(location.latitude, location.longitude);

      if (prayerTimes != null) {
        _cachedPrayers = prayerTimes;
        _cacheTime = DateTime.now();
        await _cachePrayerTimes(prayerTimes, location);
        return prayerTimes;
      }

      // Fallback to cached data or default times
      return fallbackPrayers ?? _getDefaultPrayerTimes();
    } catch (e) {
      print('PrayerTimeService: Error getting prayer times: $e');
      // Try to get cached data or return default times
      final cachedPrayers = await _getCachedPrayerTimes();
      return cachedPrayers ?? _getDefaultPrayerTimes();
    }
  }

  /// Get the next prayer time and how long until it
  static Future<String> getNextPrayerInfo() async {
    try {
      final prayerTimes = await getTodayPrayerTimes();
      final now = DateTime.now();

      // Find the next prayer
      for (final prayer in prayerTimes) {
        if (prayer.time.isAfter(now)) {
          final duration = prayer.time.difference(now);

          if (duration.inHours > 0) {
            return '${prayer.name} in ${duration.inHours}h ${duration.inMinutes % 60}m';
          } else if (duration.inMinutes > 0) {
            return '${prayer.name} in ${duration.inMinutes}m';
          } else {
            return '${prayer.name} now';
          }
        }
      }

      // If no prayer today, check tomorrow
      final tomorrowPrayers = await getTomorrowPrayerTimes();
      if (tomorrowPrayers.isNotEmpty) {
        final firstPrayer = tomorrowPrayers.first;
        final duration = firstPrayer.time.difference(now);
        return '${firstPrayer.name} in ${duration.inHours}h';
      }

      return 'Fajr tomorrow';
    } catch (e) {
      print('PrayerTimeService: Error getting next prayer: $e');
      return 'Prayer times unavailable';
    }
  }

  /// Fetch prayer times from Al Adhan API
  static Future<List<PrayerTime>?> _fetchPrayerTimesFromAPI(
      double latitude, double longitude) async {
    try {
      final today = DateTime.now();
      final timestamp = (today.millisecondsSinceEpoch / 1000).round();

      // Using Al Adhan API with automatic calculation method
      final url = 'https://api.aladhan.com/v1/timings/$timestamp'
          '?latitude=$latitude&longitude=$longitude&method=2';

      print('PrayerTimeService: Fetching from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final timings = data['data']['timings'] as Map<String, dynamic>;

        return _parsePrayerTimes(timings, today);
      } else {
        print('PrayerTimeService: API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('PrayerTimeService: Network error: $e');
      return null;
    }
  }

  /// Parse prayer times from API response
  static List<PrayerTime> _parsePrayerTimes(
      Map<String, dynamic> timings, DateTime date) {
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final prayers = <PrayerTime>[];

    for (final name in prayerNames) {
      final timeString = timings[name] as String?;
      if (timeString != null) {
        try {
          final timeParts = timeString.split(':');
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);

          final prayerTime = DateTime(
            date.year,
            date.month,
            date.day,
            hour,
            minute,
          );

          prayers.add(PrayerTime(
            name: name,
            time: prayerTime,
          ));
        } catch (e) {
          print('PrayerTimeService: Error parsing time for $name: $e');
        }
      }
    }

    return prayers;
  }

  /// Get tomorrow's prayer times
  static Future<List<PrayerTime>> getTomorrowPrayerTimes() async {
    try {
      LocationData? location =
          await LocationService.getCurrentLocation(interactive: false);
      if (location == null) {
        return [];
      }

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final timestamp = (tomorrow.millisecondsSinceEpoch / 1000).round();

      final url = 'https://api.aladhan.com/v1/timings/$timestamp'
          '?latitude=${location.latitude}&longitude=${location.longitude}&method=2';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final timings = data['data']['timings'] as Map<String, dynamic>;
        return _parsePrayerTimes(timings, tomorrow);
      }

      return [];
    } catch (e) {
      print('PrayerTimeService: Error getting tomorrow prayers: $e');
      return [];
    }
  }

  /// Cache prayer times locally
  static Future<void> _cachePrayerTimes(
      List<PrayerTime> prayers, LocationData location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final cacheKey =
          '$_cacheKeyPrefix${today.year}_${today.month}_${today.day}';

      final cacheData = {
        'prayers': prayers
            .map((p) => {
                  'name': p.name,
                  'time': p.time.millisecondsSinceEpoch,
                })
            .toList(),
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(cacheKey, json.encode(cacheData));
      print('PrayerTimeService: Cached prayer times for today');
    } catch (e) {
      print('PrayerTimeService: Error caching prayer times: $e');
    }
  }

  /// Get cached prayer times
  static Future<List<PrayerTime>?> _getCachedPrayerTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final cacheKey =
          '$_cacheKeyPrefix${today.year}_${today.month}_${today.day}';

      final cachedString = prefs.getString(cacheKey);
      if (cachedString == null) return null;

      final cacheData = json.decode(cachedString) as Map<String, dynamic>;
      final cachedAt =
          DateTime.fromMillisecondsSinceEpoch(cacheData['cached_at'] as int);

      // Check if cache is still valid (within 12 hours)
      if (DateTime.now().difference(cachedAt) > _cacheValidDuration) {
        return null;
      }

      final prayersData = cacheData['prayers'] as List;
      return prayersData
          .map((p) => PrayerTime(
                name: p['name'] as String,
                time: DateTime.fromMillisecondsSinceEpoch(p['time'] as int),
              ))
          .toList();
    } catch (e) {
      print('PrayerTimeService: Error reading cached prayer times: $e');
      return null;
    }
  }

  /// Check if we have valid cached prayer times
  static bool _isValidCache() {
    return _cachedPrayers != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheValidDuration;
  }

  /// Get default prayer times (approximate) when location/API is unavailable
  static List<PrayerTime> _getDefaultPrayerTimes() {
    final now = DateTime.now();
    return [
      PrayerTime(
          name: 'Fajr', time: DateTime(now.year, now.month, now.day, 5, 30)),
      PrayerTime(
          name: 'Dhuhr', time: DateTime(now.year, now.month, now.day, 12, 15)),
      PrayerTime(
          name: 'Asr', time: DateTime(now.year, now.month, now.day, 15, 30)),
      PrayerTime(
          name: 'Maghrib', time: DateTime(now.year, now.month, now.day, 18, 0)),
      PrayerTime(
          name: 'Isha', time: DateTime(now.year, now.month, now.day, 19, 30)),
    ];
  }

  /// Clear prayer time cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((key) => key.startsWith(_cacheKeyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
      _cachedPrayers = null;
      _cacheTime = null;
      print('PrayerTimeService: Cache cleared');
    } catch (e) {
      print('PrayerTimeService: Error clearing cache: $e');
    }
  }

  /// Get all prayer times for display
  static Future<List<PrayerTime>> getAllTodayPrayers() async {
    return await getTodayPrayerTimes();
  }

  /// Check if it's currently prayer time (within 5 minutes)
  static Future<bool> isCurrentlyPrayerTime() async {
    try {
      final prayers = await getTodayPrayerTimes();
      final now = DateTime.now();

      for (final prayer in prayers) {
        final diff = prayer.time.difference(now).abs();
        if (diff.inMinutes <= 5) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Silent background initialization that doesn't block or show errors
  static Future<void> initializeInBackground() async {
    try {
      print('PrayerTimeService: Starting background initialization...');
      await getTodayPrayerTimes();
      print('PrayerTimeService: Background initialization completed');
    } catch (e) {
      print('PrayerTimeService: Background initialization failed: $e');
      // Silently fail - this is background initialization
    }
  }
}
