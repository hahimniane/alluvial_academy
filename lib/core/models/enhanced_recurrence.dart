import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced recurrence types
enum EnhancedRecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

/// Days of the week (1 = Monday, 7 = Sunday)
enum WeekDay {
  monday(1, 'Monday', 'Mon'),
  tuesday(2, 'Tuesday', 'Tue'),
  wednesday(3, 'Wednesday', 'Wed'),
  thursday(4, 'Thursday', 'Thu'),
  friday(5, 'Friday', 'Fri'),
  saturday(6, 'Saturday', 'Sat'),
  sunday(7, 'Sunday', 'Sun');

  const WeekDay(this.value, this.fullName, this.shortName);
  final int value;
  final String fullName;
  final String shortName;
}

/// Enhanced recurrence configuration
class EnhancedRecurrence {
  final EnhancedRecurrenceType type;
  final DateTime? endDate;
  
  // Daily recurrence settings
  final List<DateTime> excludedDates; // Specific dates to exclude
  final List<WeekDay> excludedWeekdays; // Days of week to exclude (e.g., weekends)
  
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
          final excludedNames = excludedWeekdays.map((day) => day.shortName).join(', ');
          desc += ' (excluding $excludedNames)';
        }
        if (excludedDates.isNotEmpty) {
          desc += ' (${excludedDates.length} specific dates excluded)';
        }
        return desc;
      case EnhancedRecurrenceType.weekly:
        final dayNames = selectedWeekdays.map((day) => day.shortName).join(', ');
        return 'Weekly on $dayNames';
      case EnhancedRecurrenceType.monthly:
        if (selectedMonthDays.length <= 3) {
          final dayNumbers = selectedMonthDays.map((day) => '$day${_getOrdinalSuffix(day)}').join(', ');
          return 'Monthly on $dayNumbers';
        } else {
          return 'Monthly on ${selectedMonthDays.length} selected days';
        }
      case EnhancedRecurrenceType.yearly:
        final monthNames = selectedMonths.map((month) => _getMonthName(month)).join(', ');
        return 'Yearly in $monthNames';
    }
  }

  /// Helper to get ordinal suffix (1st, 2nd, 3rd, etc.)
  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  /// Helper to get month name
  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'excludedDates': excludedDates.map((date) => Timestamp.fromDate(date)).toList(),
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
          .map((value) => WeekDay.values.firstWhere((day) => day.value == value))
          .toList(),
      selectedWeekdays: (data['selectedWeekdays'] as List<dynamic>? ?? [])
          .cast<int>()
          .map((value) => WeekDay.values.firstWhere((day) => day.value == value))
          .toList(),
      selectedMonthDays: (data['selectedMonthDays'] as List<dynamic>? ?? [])
          .cast<int>(),
      selectedMonths: (data['selectedMonths'] as List<dynamic>? ?? [])
          .cast<int>(),
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
    final weekday = WeekDay.values.firstWhere((day) => day.value == date.weekday);
    if (excludedWeekdays.contains(weekday)) {
      return true;
    }

    return false;
  }

  /// Generate next occurrence dates based on the recurrence pattern
  List<DateTime> generateOccurrences(DateTime startDate, int maxCount) {
    if (type == EnhancedRecurrenceType.none || !isValid) {
      return [startDate];
    }

    final List<DateTime> occurrences = [];
    DateTime currentDate = startDate;
    int count = 0;

    while (count < maxCount && (endDate == null || currentDate.isBefore(endDate!))) {
      switch (type) {
        case EnhancedRecurrenceType.daily:
          if (!isDateExcluded(currentDate)) {
            occurrences.add(currentDate);
            count++;
          }
          currentDate = currentDate.add(const Duration(days: 1));
          break;

        case EnhancedRecurrenceType.weekly:
          final weekday = WeekDay.values.firstWhere((day) => day.value == currentDate.weekday);
          if (selectedWeekdays.contains(weekday) && !isDateExcluded(currentDate)) {
            occurrences.add(currentDate);
            count++;
          }
          currentDate = currentDate.add(const Duration(days: 1));
          break;

        case EnhancedRecurrenceType.monthly:
          if (selectedMonthDays.contains(currentDate.day) && !isDateExcluded(currentDate)) {
            occurrences.add(currentDate);
            count++;
          }
          // Move to next day, handle month boundaries
          currentDate = currentDate.add(const Duration(days: 1));
          break;

        case EnhancedRecurrenceType.yearly:
          if (selectedMonths.contains(currentDate.month) && !isDateExcluded(currentDate)) {
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