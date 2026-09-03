import 'package:cloud_firestore/cloud_firestore.dart';

import 'enrollment_slots.dart';

class JobOpportunity {
  final String id;
  final String enrollmentId;
  final String studentName;
  final String studentAge;
  final String subject;
  /// User-friendly program name; falls back to [subject] when null.
  final String? subjectDisplayName;
  final String gradeLevel;
  final List<String> days;
  final List<String> timeSlots;
  final String timeZone;
  final String status; // 'open', 'accepted', 'closed', 'withdrawn'
  final DateTime createdAt;
  final String? acceptedByTeacherId;
  final DateTime? acceptedAt;
  final bool isAdult;
  
  // Additional fields from enrollment
  final String? sessionDuration;      // e.g., "60 minutes", "1.5 hours"
  /// Class length in minutes. Newer jobs carry this; older ones only have the
  /// label above, which [durationDisplay] parses.
  final int? sessionMinutes;
  /// Classes a week the family asked for.
  final int? sessionsPerWeek;
  /// The part of the day the family chose, e.g. "Evening".
  final String? block;
  /// Every child in an exclusive family class. Empty for a single student.
  final List<Map<String, String>> classRoster;
  final String? classType;            // e.g., "Individual", "Group"
  final String? gender;               // Student gender
  final String? specificLanguage;     // For language courses
  final String? countryName;
  final String? city;
  final String? preferredLanguage;    // Teaching language preference
  final String? timeOfDayPreference;  // e.g., "Morning", "Afternoon"
  final bool? knowsZoom;
  
  // Parent/Family info for grouping
  final String? parentEmail;
  final String? parentName;
  final String? parentLinkId;         // Links multiple students from same parent
  final int? studentIndex;            // Position in multi-student submission
  final int? totalStudents;           // Total students in submission
  
  // Teacher's selected time preferences (day -> time slot)
  final Map<String, String>? teacherSelectedTimes;

  /// IANA timezone that the listed days/timeSlots refer to (set by admin at broadcast time).
  final String? scheduleTimezoneRef;

  /// Admin notes visible to teachers on the job board.
  final String? adminNotesForTeachers;

  /// Teacher UIDs this job was broadcast to. Null/empty = visible to all teachers.
  final List<String>? targetTeacherIds;

  /// Display names matching [targetTeacherIds], for admin views.
  final List<String>? targetTeacherNames;

  JobOpportunity({
    required this.id,
    required this.enrollmentId,
    required this.studentName,
    required this.studentAge,
    required this.subject,
    this.subjectDisplayName,
    required this.gradeLevel,
    required this.days,
    required this.timeSlots,
    required this.timeZone,
    required this.status,
    required this.createdAt,
    this.acceptedByTeacherId,
    this.acceptedAt,
    this.isAdult = false,
    // Additional fields
    this.sessionDuration,
    this.sessionMinutes,
    this.sessionsPerWeek,
    this.block,
    this.classRoster = const [],
    this.classType,
    this.gender,
    this.specificLanguage,
    this.countryName,
    this.city,
    this.preferredLanguage,
    this.timeOfDayPreference,
    this.knowsZoom,
    this.parentEmail,
    this.parentName,
    this.parentLinkId,
    this.studentIndex,
    this.totalStudents,
    this.teacherSelectedTimes,
    this.scheduleTimezoneRef,
    this.adminNotesForTeachers,
    this.targetTeacherIds,
    this.targetTeacherNames,
  });

  static List<String> _daysToList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    final s = value.toString().trim();
    if (s.isEmpty) return [];
    return s.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
  }

  static List<String> _timeSlotsToList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    final s = value.toString().trim();
    if (s.isEmpty) return [];
    return [s];
  }

  factory JobOpportunity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobOpportunity(
      id: doc.id,
      enrollmentId: data['enrollmentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentAge: data['studentAge'] ?? '',
      subject: data['subject'] ?? '',
      subjectDisplayName: data['subject_display_name'] as String?,
      gradeLevel: data['gradeLevel'] ?? '',
      days: _daysToList(data['days']),
      timeSlots: _timeSlotsToList(data['timeSlots']),
      timeZone: data['timeZone'] ?? '',
      status: data['status'] ?? 'open',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedByTeacherId: data['acceptedByTeacherId'],
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      isAdult: data['isAdult'] ?? false,
      // Additional fields
      sessionDuration: data['sessionDuration'],
      sessionMinutes: (data['sessionMinutes'] as num?)?.toInt(),
      sessionsPerWeek: (data['sessionsPerWeek'] as num?)?.toInt(),
      block: data['block'] as String?,
      classRoster: ((data['classRoster'] as List<dynamic>?) ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => {
                'name': (e['name'] ?? '').toString(),
                'age': (e['age'] ?? '').toString(),
                'level': (e['level'] ?? '').toString(),
              })
          .where((e) => e['name']!.isNotEmpty)
          .toList(),
      classType: data['classType'],
      gender: data['gender'],
      specificLanguage: data['specificLanguage'],
      countryName: data['countryName'],
      city: data['city'],
      preferredLanguage: data['preferredLanguage'],
      timeOfDayPreference: data['timeOfDayPreference'],
      knowsZoom: data['knowsZoom'],
      parentEmail: data['parentEmail'],
      parentName: data['parentName'],
      parentLinkId: data['parentLinkId'],
      studentIndex: data['studentIndex'],
      totalStudents: data['totalStudents'],
      teacherSelectedTimes: data['teacherSelectedTimes'] != null 
          ? Map<String, String>.from(data['teacherSelectedTimes']) 
          : null,
      scheduleTimezoneRef: data['scheduleTimezoneRef'] as String?,
      adminNotesForTeachers: data['adminNotesForTeachers'] as String?,
      targetTeacherIds: data['targetTeacherIds'] != null
          ? List<String>.from(data['targetTeacherIds'])
          : null,
      targetTeacherNames: data['targetTeacherNames'] != null
          ? List<String>.from(data['targetTeacherNames'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enrollmentId': enrollmentId,
      'studentName': studentName,
      'studentAge': studentAge,
      'subject': subject,
      if (subjectDisplayName != null) 'subject_display_name': subjectDisplayName,
      'gradeLevel': gradeLevel,
      'days': days,
      'timeSlots': timeSlots,
      'timeZone': timeZone,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'isAdult': isAdult,
      if (acceptedByTeacherId != null) 'acceptedByTeacherId': acceptedByTeacherId,
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (sessionDuration != null) 'sessionDuration': sessionDuration,
      if (classType != null) 'classType': classType,
      if (gender != null) 'gender': gender,
      if (specificLanguage != null) 'specificLanguage': specificLanguage,
      if (countryName != null) 'countryName': countryName,
      if (city != null) 'city': city,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
      if (timeOfDayPreference != null) 'timeOfDayPreference': timeOfDayPreference,
      if (knowsZoom != null) 'knowsZoom': knowsZoom,
      if (parentEmail != null) 'parentEmail': parentEmail,
      if (parentName != null) 'parentName': parentName,
      if (parentLinkId != null) 'parentLinkId': parentLinkId,
      if (studentIndex != null) 'studentIndex': studentIndex,
      if (totalStudents != null) 'totalStudents': totalStudents,
      if (teacherSelectedTimes != null) 'teacherSelectedTimes': teacherSelectedTimes,
      if (scheduleTimezoneRef != null) 'scheduleTimezoneRef': scheduleTimezoneRef,
      if (adminNotesForTeachers != null) 'adminNotesForTeachers': adminNotesForTeachers,
      if (targetTeacherIds != null) 'targetTeacherIds': targetTeacherIds,
      if (targetTeacherNames != null) 'targetTeacherNames': targetTeacherNames,
    };
  }

  /// Whether this job should appear on [teacherId]'s job board.
  /// Jobs without targeting are visible to everyone.
  bool isVisibleToTeacher(String teacherId) {
    final targets = targetTeacherIds;
    if (targets == null || targets.isEmpty) return true;
    return targets.contains(teacherId);
  }
  
  /// Best display name for the program/subject.
  String get displaySubject => subjectDisplayName ?? subject;

  /// Helper to get formatted duration display (e.g. "1 hr" / "1 hr 30 mins" -> "60 min" / "90 min")
  String get durationDisplay => sessionLabel(effectiveSessionMinutes);

  /// How long each class runs. Prefers the stored number; falls back to
  /// reading the label. The old ladder of string matches turned an unlisted
  /// label like "1.5 hours" into "1 min".
  int get effectiveSessionMinutes =>
      sessionMinutes ?? minutesFromDurationLabel(sessionDuration);
  
  /// Check if this job belongs to a multi-student submission
  bool get isPartOfMultiStudent => parentLinkId != null && totalStudents != null && totalStudents! > 1;
  
  /// Check if teacher has selected specific times
  bool get hasTeacherSelectedTimes => teacherSelectedTimes != null && teacherSelectedTimes!.isNotEmpty;
  
  /// Get formatted teacher selected times
  String get formattedTeacherTimes {
    if (!hasTeacherSelectedTimes) return 'No times selected';
    return teacherSelectedTimes!.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
  }
}

