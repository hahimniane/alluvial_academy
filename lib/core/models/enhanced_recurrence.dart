import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;

import '../enums/shift_enums.dart';
import '../utils/timezone_utils.dart';

/// Enhanced recurrence configuration
class EnhancedRecurrence {
  final EnhancedRecurrenceType type;
  final DateTime? endDate;

  // Daily recurrence settings
  final List<DateTime> excludedDates; // Specific dates to exclude
  final List<WeekDay>
      excludedWeekdays; // Days of week to exclude (e.g., weekends)

  // Weekly recurrence settings
  final List<WeekDay> selectedWeekdays; // Which days of the week to repeat

  // Monthly recurrence settings
  final List<int> selectedMonthDays; // Which days of the month (1-31)

  // Yearly recurrence settings (for future expansion)
  final List<int> selectedMonths; // Which months (1-12)

  const EnhancedRecurrence({
    this.type = EnhancedRecurrenceType.none,
    this.endDate,
    this.excludedDates = const [],
    this.excludedWeekdays = const [],
    this.selectedWeekdays = const [],
    this.selectedMonthDays = const [],
    this.selectedMonths = const [],
  });

  /// Check if this configuration is valid
  bool get isValid {
    switch (type) {
      case EnhancedRecurrenceType.none:
        return true;
      case EnhancedRecurrenceType.daily:
        return true; // Daily is always valid (exclusions are optional)
      case EnhancedRecurrenceType.weekly:
        return selectedWeekdays.isNotEmpty;
      case EnhancedRecurrenceType.monthly:
        return selectedMonthDays.isNotEmpty;
      case EnhancedRecurrenceType.yearly:
        return selectedMonths.isNotEmpty;
    }
  }

  /// Get human-readable description
  String get description {
    switch (type) {
      case EnhancedRecurrenceType.none:
        return 'No recurrence';
      case EnhancedRecurrenceType.daily:
        String desc = 'Daily';
        if (excludedWeekdays.isNotEmpty) {
          final excludedNames =
              excludedWeekdays.map((day) => day.shortName).join(', ');
          desc += ' (excluding $excludedNames)';
        }
        if (excludedDates.isNotEmpty) {
          desc += ' (${excludedDates.length} specific dates excluded)';
        }
        return desc;
      case EnhancedRecurrenceType.weekly:
        final dayNames =
            selectedWeekdays.map((day) => day.shortName).join(', ');
        return 'Weekly on $dayNames';
      case EnhancedRecurrenceType.monthly:
        if (selectedMonthDays.length <= 3) {
          final dayNumbers = selectedMonthDays
              .map((day) => '$day${_getOrdinalSuffix(day)}')
              .join(', ');
          return 'Monthly on $dayNumbers';
        } else {
          return 'Monthly on ${selectedMonthDays.length} selected days';
        }
      case EnhancedRecurrenceType.yearly:
        final monthNames =
            selectedMonths.map((month) => _getMonthName(month)).join(', ');
        return 'Yearly in $monthNames';
    }
  }

  /// Helper to get ordinal suffix (1st, 2nd, 3rd, etc.)
  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  /// Helper to get month name
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'excludedDates':
          excludedDates.map((date) => Timestamp.fromDate(date)).toList(),
      'excludedWeekdays': excludedWeekdays.map((day) => day.value).toList(),
      'selectedWeekdays': selectedWeekdays.map((day) => day.value).toList(),
      'selectedMonthDays': selectedMonthDays,
      'selectedMonths': selectedMonths,
    };
  }

  /// Create from Firestore document
  factory EnhancedRecurrence.fromFirestore(Map<String, dynamic> data) {
    return EnhancedRecurrence(
      type: EnhancedRecurrenceType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => EnhancedRecurrenceType.none,
      ),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      excludedDates: (data['excludedDates'] as List<dynamic>? ?? [])
          .cast<Timestamp>()
          .map((timestamp) => timestamp.toDate())
          .toList(),
      excludedWeekdays: (data['excludedWeekdays'] as List<dynamic>? ?? [])
          .cast<int>()
          .map(
              (value) => WeekDay.values.firstWhere((day) => day.value == value))
          .toList(),
      selectedWeekdays: (data['selectedWeekdays'] as List<dynamic>? ?? [])
          .cast<int>()
          .map(
              (value) => WeekDay.values.firstWhere((day) => day.value == value))
          .toList(),
      selectedMonthDays:
          (data['selectedMonthDays'] as List<dynamic>? ?? []).cast<int>(),
      selectedMonths:
          (data['selectedMonths'] as List<dynamic>? ?? []).cast<int>(),
    );
  }

  /// Copy with new values
  EnhancedRecurrence copyWith({
    EnhancedRecurrenceType? type,
    DateTime? endDate,
    List<DateTime>? excludedDates,
    List<WeekDay>? excludedWeekdays,
    List<WeekDay>? selectedWeekdays,
    List<int>? selectedMonthDays,
    List<int>? selectedMonths,
  }) {
    return EnhancedRecurrence(
      type: type ?? this.type,
      endDate: endDate ?? this.endDate,
      excludedDates: excludedDates ?? this.excludedDates,
      excludedWeekdays: excludedWeekdays ?? this.excludedWeekdays,
      selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
      selectedMonthDays: selectedMonthDays ?? this.selectedMonthDays,
      selectedMonths: selectedMonths ?? this.selectedMonths,
    );
  }

  /// Check if a specific date should be excluded
  bool isDateExcluded(DateTime date) {
    // Check excluded specific dates
    for (final excludedDate in excludedDates) {
      if (date.year == excludedDate.year &&
          date.month == excludedDate.month &&
          date.day == excludedDate.day) {
        return true;
      }
    }

    // Check excluded weekdays
    // Note: This method doesn't have timezone context, so it uses date.weekday
    // which is based on the DateTime's timezone context. For accurate results,
    // ensure the date is already in the correct timezone before calling this.
    final weekday =
        WeekDay.values.firstWhere((day) => day.value == date.weekday);
    if (excludedWeekdays.contains(weekday)) {
      return true;
    }

    return false;
  }

  /// Generate next occurrence dates based on the recurrence pattern
  /// 
  /// [timezoneId] is the timezone to use for weekday calculations (e.g., "America/New_York")
  /// If not provided, uses the system timezone (for backward compatibility)
  List<DateTime> generateOccurrences(DateTime startDate, int maxCount, {String? timezoneId}) {
    if (type == EnhancedRecurrenceType.none || !isValid) {
      return [startDate];
    }

    final List<DateTime> occurrences = [];
    DateTime currentDate = startDate;
    int count = 0;

    // Helper function to get weekday in the specified timezone
    // The date parameter represents a date/time already in the target timezone context
    int getWeekdayInTimezone(DateTime date, String? tzId) {
      if (tzId == null || tzId == 'UTC') {
        return date.weekday;
      }
      try {
        TimezoneUtils.initializeTimezones();
        final location = tz.getLocation(tzId);
        // Create a TZDateTime directly in the target timezone using the date components
        // This ensures the weekday is calculated in the correct timezone
        final tzDate = tz.TZDateTime(
          location,
          date.year,
          date.month,
          date.day,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        );
        return tzDate.weekday;
      } catch (e) {
        // Fallback to regular weekday if timezone conversion fails
        return date.weekday;
      }
    }

    while (count < maxCount &&
        (endDate == null || currentDate.isBefore(endDate!))) {
      switch (type) {
        case EnhancedRecurrenceType.daily:
          if (!isDateExcluded(currentDate)) {
            occurrences.add(currentDate);
            count++;
          }
          currentDate = currentDate.add(const Duration(days: 1));
          break;

        case EnhancedRecurrenceType.weekly:
          // Use timezone-aware weekday calculation
          final weekdayValue = getWeekdayInTimezone(currentDate, timezoneId);
          final weekday = WeekDay.values
              .firstWhere((day) => day.value == weekdayValue);
          if (selectedWeekdays.contains(weekday) &&
              !isDateExcluded(currentDate)) {
            occurrences.add(currentDate);
            count++;
          }
          currentDate = currentDate.add(const Duration(days: 1));
          break;

        case EnhancedRecurrenceType.monthly:
          if (selectedMonthDays.contains(currentDate.day) &&
              !isDateExcluded(currentDate)) {
            occurrences.add(currentDate);
            count++;
          }
          // Move to next day, handle month boundaries
          currentDate = currentDate.add(const Duration(days: 1));
          break;

        case EnhancedRecurrenceType.yearly:
          if (selectedMonths.contains(currentDate.month) &&
              !isDateExcluded(currentDate)) {
            occurrences.add(currentDate);
            count++;
          }
          currentDate = currentDate.add(const Duration(days: 1));
          break;

        case EnhancedRecurrenceType.none:
          break;
      }

      // Safety check to prevent infinite loops
      if (currentDate.year > startDate.year + 10) break;
    }

    return occurrences;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancedRecurrence &&
        other.type == type &&
        other.endDate == endDate &&
        _listEquals(other.excludedDates, excludedDates) &&
        _listEquals(other.excludedWeekdays, excludedWeekdays) &&
        _listEquals(other.selectedWeekdays, selectedWeekdays) &&
        _listEquals(other.selectedMonthDays, selectedMonthDays) &&
        _listEquals(other.selectedMonths, selectedMonths);
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      endDate,
      Object.hashAll(excludedDates),
      Object.hashAll(excludedWeekdays),
      Object.hashAll(selectedWeekdays),
      Object.hashAll(selectedMonthDays),
      Object.hashAll(selectedMonths),
    );
  }
}
