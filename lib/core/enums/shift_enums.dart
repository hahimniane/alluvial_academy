/// Shift status enum
enum ShiftStatus {
  scheduled,
  active,
  completed,
  partiallyCompleted,
  fullyCompleted,
  missed,
  cancelled,
}

/// Islamic subjects enum
enum IslamicSubject {
  quranStudies,
  hadithStudies,
  fiqh,
  arabicLanguage,
  islamicHistory,
  aqeedah,
  tafseer,
  seerah,
}

/// Recurrence pattern enum
enum RecurrencePattern {
  none,
  daily,
  weekly,
  monthly,
}

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
