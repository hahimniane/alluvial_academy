// Stub implementation - Islamic calendar service temporarily disabled
import 'dart:async';

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

class IslamicCalendarService {
  static Future<HijriDate> getCurrentHijriDate() async {
    // Stub implementation
    return HijriDate(
      day: 1,
      month: 1,
      year: 1446,
      monthName: 'Service Disabled',
      fullDate: 'Islamic Calendar Service Disabled',
    );
  }

  static Future<Map<String, dynamic>> getCurrentMonthInfo() async {
    // Stub implementation
    return {
      'name': 'Service Disabled',
      'year': 1446,
    };
  }

  static Future<List<IslamicEvent>> getUpcomingEvents() async {
    // Stub implementation
    return [];
  }
}
