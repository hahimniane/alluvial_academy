import 'package:cloud_firestore/cloud_firestore.dart';

class JobOpportunity {
  final String id;
  final String enrollmentId;
  final String studentName;
  final String studentAge;
  final String subject;
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
  final String? sessionDuration;      // e.g., "60 minutes", "30 minutes"
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

  JobOpportunity({
    required this.id,
    required this.enrollmentId,
    required this.studentName,
    required this.studentAge,
    required this.subject,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enrollmentId': enrollmentId,
      'studentName': studentName,
      'studentAge': studentAge,
      'subject': subject,
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
    };
  }
  
  /// Helper to get formatted duration display (e.g. "1 hr" / "1 hr 30 mins" -> "60 min" / "90 min")
  String get durationDisplay {
    if (sessionDuration == null || sessionDuration!.isEmpty) return '60 min';
    final d = sessionDuration!.toLowerCase();
    if (d.contains('1 hr 30')) return '90 min';
    if (d.contains('2 hr 30')) return '150 min';
    if (d.contains('30 mins')) return '30 min';
    if (d.contains('1 hr')) return '60 min';
    if (d.contains('2 hrs')) return '120 min';
    if (d.contains('3 hrs')) return '180 min';
    if (d.contains('4 hrs')) return '240 min';
    final match = RegExp(r'(\d+)').firstMatch(sessionDuration!);
    return match != null ? '${match.group(1)} min' : sessionDuration!;
  }
  
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

