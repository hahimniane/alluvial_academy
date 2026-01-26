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
/// Note: This enum is legacy - new subjects should use the dynamic `subjects` collection
/// The `other` value is used for non-Islamic subjects like English, Maths, etc.
enum IslamicSubject {
  quranStudies,
  hadithStudies,
  fiqh,
  arabicLanguage,
  islamicHistory,
  aqeedah,
  tafseer,
  seerah,
  other, // For non-Islamic subjects (English, Maths, Science, etc.)
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

/// Shift category enum - distinguishes between teaching and leadership schedules
enum ShiftCategory {
  teaching,    // Regular teacher-student class
  leadership,  // Admin/leader duties
  meeting,     // Scheduled meetings
  training,    // Staff training sessions
}

/// Video provider enum - determines which video platform is used for the class
enum VideoProvider {
  livekit,  // Default - uses LiveKit for video calls
  @Deprecated('Zoom support has been removed. All shifts use LiveKit.')
  zoom,     // Legacy - no longer supported
}