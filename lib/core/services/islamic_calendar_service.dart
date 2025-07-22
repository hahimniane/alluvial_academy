import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class IslamicEvent {
  final String name;
  final String emoji;
  final DateTime date;
  final int daysUntil;
  final String description;

  IslamicEvent({
    required this.name,
    required this.emoji,
    required this.date,
    required this.daysUntil,
    required this.description,
  });
}

class HijriDate {
  final int day;
  final int month;
  final int year;
  final String monthName;
  final String fullDate;

  HijriDate({
    required this.day,
    required this.month,
    required this.year,
    required this.monthName,
    required this.fullDate,
  });
}

class IslamicCalendarService {
  static const String _hijriCacheKey = 'hijri_date_cache';
  static const String _eventsCacheKey = 'islamic_events_cache';
  static const Duration _cacheValidDuration = Duration(hours: 24);

  static HijriDate? _cachedHijriDate;
  static List<IslamicEvent>? _cachedEvents;
  static DateTime? _cacheTime;

  static const Map<int, String> _hijriMonths = {
    1: 'Muharram',
    2: 'Safar',
    3: 'Rabi\' al-awwal',
    4: 'Rabi\' al-thani',
    5: 'Jumada al-awwal',
    6: 'Jumada al-thani',
    7: 'Rajab',
    8: 'Sha\'ban',
    9: 'Ramadan',
    10: 'Shawwal',
    11: 'Dhu al-Qi\'dah',
    12: 'Dhu al-Hijjah',
  };

  /// Get current Hijri date
  static Future<HijriDate> getCurrentHijriDate() async {
    try {
      // Check cache first
      if (_isValidHijriCache()) {
        print('IslamicCalendarService: Using cached Hijri date');
        return _cachedHijriDate!;
      }

      // Fetch from Al Adhan API
      final today = DateTime.now();
      final timestamp = (today.millisecondsSinceEpoch / 1000).round();

      final url = 'https://api.aladhan.com/v1/gToHCalendar/$timestamp';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hijriData = data['data'];

        final hijriDate = HijriDate(
          day: hijriData['hijri']['day'] as int,
          month: hijriData['hijri']['month']['number'] as int,
          year: hijriData['hijri']['year'] as int,
          monthName: hijriData['hijri']['month']['en'] as String,
          fullDate:
              '${hijriData['hijri']['day']} ${hijriData['hijri']['month']['en']} ${hijriData['hijri']['year']} AH',
        );

        _cachedHijriDate = hijriDate;
        _cacheTime = DateTime.now();
        await _cacheHijriDate(hijriDate);

        return hijriDate;
      }

      // Fallback to cached or approximate date
      final cached = await _getCachedHijriDate();
      return cached ?? _getApproximateHijriDate();
    } catch (e) {
      print('IslamicCalendarService: Error getting Hijri date: $e');
      final cached = await _getCachedHijriDate();
      return cached ?? _getApproximateHijriDate();
    }
  }

  /// Get upcoming Islamic events
  static Future<List<IslamicEvent>> getUpcomingEvents() async {
    try {
      // Check cache first
      if (_isValidEventsCache()) {
        print('IslamicCalendarService: Using cached events');
        return _cachedEvents!;
      }

      final hijriDate = await getCurrentHijriDate();
      final events = await _generateIslamicEvents(hijriDate);

      _cachedEvents = events;
      await _cacheEvents(events);

      return events;
    } catch (e) {
      print('IslamicCalendarService: Error getting events: $e');
      final cached = await _getCachedEvents();
      return cached ?? _getDefaultEvents();
    }
  }

  /// Generate Islamic events based on current Hijri date
  static Future<List<IslamicEvent>> _generateIslamicEvents(
      HijriDate hijriDate) async {
    final events = <IslamicEvent>[];
    final now = DateTime.now();

    // Calculate important Islamic dates for this year
    final islamicDates = _getImportantIslamicDates(hijriDate.year);

    for (final eventData in islamicDates) {
      final eventDate = await _hijriToGregorian(
        eventData['day'] as int,
        eventData['month'] as int,
        hijriDate.year,
      );

      if (eventDate != null && eventDate.isAfter(now)) {
        final daysUntil = eventDate.difference(now).inDays;

        events.add(IslamicEvent(
          name: eventData['name'] as String,
          emoji: eventData['emoji'] as String,
          date: eventDate,
          daysUntil: daysUntil,
          description: eventData['description'] as String,
        ));
      }
    }

    // Sort by date
    events.sort((a, b) => a.date.compareTo(b.date));

    // Return only next 5 events
    return events.take(5).toList();
  }

  /// Get important Islamic dates for a Hijri year
  static List<Map<String, dynamic>> _getImportantIslamicDates(int hijriYear) {
    return [
      {
        'name': 'Laylat al-Qadr (Night of Power)',
        'emoji': '🌙',
        'day': 27,
        'month': 9, // Ramadan
        'description': 'The night when the Quran was first revealed',
      },
      {
        'name': 'Eid al-Fitr',
        'emoji': '🕌',
        'day': 1,
        'month': 10, // Shawwal
        'description': 'Festival of Breaking the Fast',
      },
      {
        'name': 'Day of Arafah',
        'emoji': '🕋',
        'day': 9,
        'month': 12, // Dhu al-Hijjah
        'description': 'The most important day of Hajj',
      },
      {
        'name': 'Eid al-Adha',
        'emoji': '🐐',
        'day': 10,
        'month': 12, // Dhu al-Hijjah
        'description': 'Festival of Sacrifice',
      },
      {
        'name': 'Islamic New Year',
        'emoji': '🎊',
        'day': 1,
        'month': 1, // Muharram
        'description': 'Beginning of the Islamic year',
      },
      {
        'name': 'Day of Ashura',
        'emoji': '🤲',
        'day': 10,
        'month': 1, // Muharram
        'description': 'Day of fasting and remembrance',
      },
      {
        'name': 'Mawlid an-Nabi',
        'emoji': '🌟',
        'day': 12,
        'month': 3, // Rabi' al-awwal
        'description': 'Birthday of Prophet Muhammad (PBUH)',
      },
      {
        'name': 'Laylat al-Mi\'raj',
        'emoji': '✨',
        'day': 27,
        'month': 7, // Rajab
        'description': 'Night Journey and Ascension',
      },
      {
        'name': 'Laylat al-Bara\'ah',
        'emoji': '🌟',
        'day': 15,
        'month': 8, // Sha'ban
        'description': 'Night of Forgiveness',
      },
    ];
  }

  /// Convert Hijri date to Gregorian (approximate)
  static Future<DateTime?> _hijriToGregorian(
      int day, int month, int year) async {
    try {
      // Use Al Adhan API for accurate conversion
      final url = 'https://api.aladhan.com/v1/hToGCalendar/$month/$year';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final monthData = data['data'] as List;

        // Find the specific day
        for (final dayData in monthData) {
          if (dayData['hijri']['day'] == day) {
            final gregorianData = dayData['gregorian'];
            return DateTime(
              gregorianData['year'] as int,
              gregorianData['month']['number'] as int,
              gregorianData['day'] as int,
            );
          }
        }
      }

      // Fallback to approximate conversion
      return _approximateHijriToGregorian(day, month, year);
    } catch (e) {
      print('IslamicCalendarService: Error converting date: $e');
      return _approximateHijriToGregorian(day, month, year);
    }
  }

  /// Approximate Hijri to Gregorian conversion
  static DateTime _approximateHijriToGregorian(int day, int month, int year) {
    // This is a simplified conversion - the Al Adhan API provides more accuracy
    const hijriEpoch = 227015; // Julian day of 1 Muharram 1 AH
    const avgHijriYear = 354.36667; // Average Hijri year length
    const avgHijriMonth = 29.53056; // Average Hijri month length

    final totalDays =
        (year - 1) * avgHijriYear + (month - 1) * avgHijriMonth + day - 1;

    final julianDay = hijriEpoch + totalDays;
    final gregorianDay = julianDay - 1721425.5; // Convert to Gregorian

    final approximateDate = DateTime.fromMillisecondsSinceEpoch(
      (gregorianDay * 24 * 60 * 60 * 1000).round(),
      isUtc: true,
    );

    return approximateDate.toLocal();
  }

  /// Cache Hijri date
  static Future<void> _cacheHijriDate(HijriDate hijriDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'day': hijriDate.day,
        'month': hijriDate.month,
        'year': hijriDate.year,
        'monthName': hijriDate.monthName,
        'fullDate': hijriDate.fullDate,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(_hijriCacheKey, json.encode(cacheData));
    } catch (e) {
      print('IslamicCalendarService: Error caching Hijri date: $e');
    }
  }

  /// Get cached Hijri date
  static Future<HijriDate?> _getCachedHijriDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_hijriCacheKey);
      if (cachedString == null) return null;

      final cacheData = json.decode(cachedString) as Map<String, dynamic>;
      final cachedAt =
          DateTime.fromMillisecondsSinceEpoch(cacheData['cached_at'] as int);

      if (DateTime.now().difference(cachedAt) > _cacheValidDuration) {
        return null;
      }

      return HijriDate(
        day: cacheData['day'] as int,
        month: cacheData['month'] as int,
        year: cacheData['year'] as int,
        monthName: cacheData['monthName'] as String,
        fullDate: cacheData['fullDate'] as String,
      );
    } catch (e) {
      print('IslamicCalendarService: Error reading cached Hijri date: $e');
      return null;
    }
  }

  /// Cache events
  static Future<void> _cacheEvents(List<IslamicEvent> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'events': events
            .map((e) => {
                  'name': e.name,
                  'emoji': e.emoji,
                  'date': e.date.millisecondsSinceEpoch,
                  'daysUntil': e.daysUntil,
                  'description': e.description,
                })
            .toList(),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(_eventsCacheKey, json.encode(cacheData));
    } catch (e) {
      print('IslamicCalendarService: Error caching events: $e');
    }
  }

  /// Get cached events
  static Future<List<IslamicEvent>?> _getCachedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_eventsCacheKey);
      if (cachedString == null) return null;

      final cacheData = json.decode(cachedString) as Map<String, dynamic>;
      final cachedAt =
          DateTime.fromMillisecondsSinceEpoch(cacheData['cached_at'] as int);

      if (DateTime.now().difference(cachedAt) > _cacheValidDuration) {
        return null;
      }

      final eventsData = cacheData['events'] as List;
      return eventsData
          .map((e) => IslamicEvent(
                name: e['name'] as String,
                emoji: e['emoji'] as String,
                date: DateTime.fromMillisecondsSinceEpoch(e['date'] as int),
                daysUntil: e['daysUntil'] as int,
                description: e['description'] as String,
              ))
          .toList();
    } catch (e) {
      print('IslamicCalendarService: Error reading cached events: $e');
      return null;
    }
  }

  /// Check if Hijri cache is valid
  static bool _isValidHijriCache() {
    return _cachedHijriDate != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheValidDuration;
  }

  /// Check if events cache is valid
  static bool _isValidEventsCache() {
    return _cachedEvents != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheValidDuration;
  }

  /// Get approximate Hijri date when API is unavailable
  static HijriDate _getApproximateHijriDate() {
    // Simplified calculation - actual implementation would be more complex
    final now = DateTime.now();
    final year = now.year;
    final approximateHijriYear = ((year - 622) * 1.0307).round() + 1;

    return HijriDate(
      day: 15,
      month: 8,
      year: approximateHijriYear,
      monthName: 'Sha\'ban',
      fullDate: '15 Sha\'ban $approximateHijriYear AH',
    );
  }

  /// Get default events when API is unavailable
  static List<IslamicEvent> _getDefaultEvents() {
    final now = DateTime.now();
    return [
      IslamicEvent(
        name: 'Laylat al-Qadr',
        emoji: '🌙',
        date: now.add(const Duration(days: 30)),
        daysUntil: 30,
        description: 'The Night of Power',
      ),
      IslamicEvent(
        name: 'Eid al-Fitr',
        emoji: '🕌',
        date: now.add(const Duration(days: 45)),
        daysUntil: 45,
        description: 'Festival of Breaking the Fast',
      ),
    ];
  }

  /// Clear all caches
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hijriCacheKey);
      await prefs.remove(_eventsCacheKey);
      _cachedHijriDate = null;
      _cachedEvents = null;
      _cacheTime = null;
    } catch (e) {
      print('IslamicCalendarService: Error clearing cache: $e');
    }
  }

  /// Get Hijri month name by number
  static String getHijriMonthName(int month) {
    return _hijriMonths[month] ?? 'Unknown';
  }

  /// Get current Hijri month info
  static Future<Map<String, dynamic>> getCurrentMonthInfo() async {
    final hijriDate = await getCurrentHijriDate();
    return {
      'name': hijriDate.monthName,
      'number': hijriDate.month,
      'year': hijriDate.year,
    };
  }
}
