import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/pricing_plan_ids.dart';

/// Split a full name into (firstName, lastName). Everything before the first
/// space is treated as the first name; everything after is the last name.
/// Empty input yields two empty strings. Single-word names have empty lastName.
/// Used at submission time so the admin-side account creator has explicit
/// fields to read and does not have to re-split on its own.
({String firstName, String lastName}) splitFullName(String? raw) {
  final fullName = (raw ?? '').trim();
  if (fullName.isEmpty) {
    return (firstName: '', lastName: '');
  }
  final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return (firstName: '', lastName: '');
  if (parts.length == 1) return (firstName: parts.first, lastName: '');
  return (firstName: parts.first, lastName: parts.sublist(1).join(' '));
}

/// Derive whether a student is an adult from their age string.
/// Returns true for age >= 18. Non-numeric / empty strings return false.
bool studentIsAdultFromAge(String? age) {
  final parsed = int.tryParse((age ?? '').trim());
  if (parsed == null) return false;
  return parsed >= 18;
}

class StudentInfo {
  final String name;
  final String age;
  final String? gender;
  
  // Individual program details for each student
  final String? subject;
  final String? specificLanguage;
  final String? level;
  final String? classType;
  final String? sessionDuration;
  final int? hoursPerWeek;
  final String? timeOfDayPreference;
  final List<String>? preferredDays;
  final List<String>? preferredTimeSlots;
  /// V2 pricing track for this student ([PricingPlanIds]). Used for multi-student when programs differ.
  final String? trackId;

  StudentInfo({
    required this.name,
    required this.age,
    this.gender,
    this.subject,
    this.specificLanguage,
    this.level,
    this.classType,
    this.sessionDuration,
    this.hoursPerWeek,
    this.timeOfDayPreference,
    this.preferredDays,
    this.preferredTimeSlots,
    this.trackId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      if (gender != null) 'gender': gender,
      if (subject != null) 'subject': subject,
      if (specificLanguage != null) 'specificLanguage': specificLanguage,
      if (level != null) 'level': level,
      if (classType != null) 'classType': classType,
      if (sessionDuration != null) 'sessionDuration': sessionDuration,
      if (hoursPerWeek != null) 'hoursPerWeek': hoursPerWeek,
      if (timeOfDayPreference != null) 'timeOfDayPreference': timeOfDayPreference,
      if (preferredDays != null && preferredDays!.isNotEmpty) 'preferredDays': preferredDays,
      if (preferredTimeSlots != null && preferredTimeSlots!.isNotEmpty) 'preferredTimeSlots': preferredTimeSlots,
      if (trackId != null) 'trackId': trackId,
    };
  }

  factory StudentInfo.fromMap(Map<String, dynamic> map) {
    return StudentInfo(
      name: map['name'] ?? '',
      age: map['age'] ?? '',
      gender: map['gender'],
      subject: map['subject'],
      specificLanguage: map['specificLanguage'],
      level: map['level'],
      classType: map['classType'],
      sessionDuration: map['sessionDuration'],
      hoursPerWeek: map['hoursPerWeek'] as int?,
      timeOfDayPreference: map['timeOfDayPreference'],
      preferredDays: map['preferredDays'] != null 
          ? List<String>.from(map['preferredDays']) 
          : null,
      preferredTimeSlots: map['preferredTimeSlots'] != null 
          ? List<String>.from(map['preferredTimeSlots']) 
          : null,
      trackId: map['trackId'] as String?,
    );
  }
}

class EnrollmentRequest {
  final String? id;
  final String? subject;
  final String? specificLanguage; // For African languages
  final String gradeLevel;
  final String email;
  final String phoneNumber;
  final String countryCode;
  final String countryName;
  final List<String> preferredDays;
  final List<String> preferredTimeSlots;
  final DateTime submittedAt;
  final String status; // 'pending', 'contacted', 'enrolled'
  final String timeZone; // User's local timezone
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  
  // Additional fields for enhanced enrollment form
  final String? studentName;
  final String? studentAge;
  final String? role; // 'student', 'parent', etc.
  final String? preferredLanguage;
  final String? parentName;
  final String? city;
  final String? whatsAppNumber;
  final String? gender;
  final bool? knowsZoom;
  final String? classType;
  final String? sessionDuration;
  final String? timeOfDayPreference;
  final String? guardianId; // Linked parent ID if available
  final bool isAdult; // Flag to indicate if the student is an adult
  
  // Multi-student support (new)
  final List<StudentInfo>? students;

  /// User-friendly program name (e.g. "Islamic Studies") from the catalog category.
  /// Falls back to [subject] for display when null (legacy enrollments).
  final String? programTitle;

  /// Selected pricing tier from landing (stable id + display label at submit locale).
  final String? pricingPlanId;
  final String? pricingPlanLabel;
  final String? trackId;
  final int? hoursPerWeek;
  final String? schedulingNotes;

  /// Days for admin UI: top-level [preferredDays], else first non-empty student list.
  List<String> get resolvedPreferredDays {
    if (preferredDays.isNotEmpty) return preferredDays;
    final list = students;
    if (list == null) return const [];
    for (final s in list) {
      final d = s.preferredDays;
      if (d != null && d.isNotEmpty) return d;
    }
    return const [];
  }

  /// Time slots for admin UI: top-level [preferredTimeSlots], else first non-empty student list.
  List<String> get resolvedPreferredTimeSlots {
    if (preferredTimeSlots.isNotEmpty) return preferredTimeSlots;
    final list = students;
    if (list == null) return const [];
    for (final s in list) {
      final t = s.preferredTimeSlots;
      if (t != null && t.isNotEmpty) return t;
    }
    return const [];
  }

  /// Timezone string for chips (empty if unknown).
  String get resolvedTimeZoneDisplay => timeZone.trim();

  EnrollmentRequest({
    this.id,
    required this.subject,
    this.specificLanguage,
    required this.gradeLevel,
    required this.email,
    required this.phoneNumber,
    required this.countryCode,
    required this.countryName,
    required this.preferredDays,
    required this.preferredTimeSlots,
    required this.submittedAt,
    this.status = 'pending',
    required this.timeZone,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    // Additional fields
    this.studentName,
    this.studentAge,
    this.role,
    this.preferredLanguage,
    this.parentName,
    this.city,
    this.whatsAppNumber,
    this.gender,
    this.knowsZoom,
    this.classType,
    this.sessionDuration,
    this.timeOfDayPreference,
    this.guardianId,
    this.isAdult = false,
    this.students,
    this.programTitle,
    this.pricingPlanId,
    this.pricingPlanLabel,
    this.trackId,
    this.hoursPerWeek,
    this.schedulingNotes,
  });

  factory EnrollmentRequest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle nested structure
    final contact = data['contact'] as Map<String, dynamic>? ?? {};
    final country = contact['country'] as Map<String, dynamic>? ?? {};
    final preferences = data['preferences'] as Map<String, dynamic>? ?? {};
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    final student = data['student'] as Map<String, dynamic>? ?? {};
    final program = data['program'] as Map<String, dynamic>? ?? {};
    final pricing = data['pricing'] as Map<String, dynamic>? ??
        metadata['pricing'] as Map<String, dynamic>? ??
        {};
    final legacyPlanId = metadata['pricingPlanId'] as String?;
    final resolvedTrackId =
        (pricing['trackId'] as String?) ?? metadata['trackId'] as String? ?? legacyToTrack(legacyPlanId);
    final resolvedHoursPerWeek =
        pricing['hoursPerWeek'] as int? ?? program['hoursPerWeek'] as int?;
    
    return EnrollmentRequest(
      id: doc.id,
      subject: data['subject'],
      specificLanguage: data['specificLanguage'],
      gradeLevel: data['gradeLevel'] ?? '',
      email: contact['email'] ?? '',
      phoneNumber: contact['phone'] ?? '',
      countryCode: country['code'] ?? '',
      countryName: country['name'] ?? '',
      preferredDays: List<String>.from(preferences['days'] ?? []),
      preferredTimeSlots: List<String>.from(preferences['timeSlots'] ?? []),
      submittedAt: (metadata['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: metadata['status'] ?? 'pending',
      timeZone: preferences['timeZone'] ?? '',
      reviewedBy: metadata['reviewedBy'],
      reviewedAt: (metadata['reviewedAt'] as Timestamp?)?.toDate(),
      reviewNotes: metadata['reviewNotes'],
      // Additional fields
      studentName: student['name'] ?? data['studentName'],
      studentAge: student['age'] ?? data['studentAge'],
      role: program['role'] ?? data['role'],
      preferredLanguage: preferences['preferredLanguage'] ?? data['preferredLanguage'],
      parentName: contact['parentName'] ?? data['parentName'],
      city: contact['city'] ?? data['city'],
      whatsAppNumber: contact['whatsApp'] ?? data['whatsAppNumber'],
      gender: student['gender'] ?? data['gender'],
      knowsZoom: student['knowsZoom'] ?? data['knowsZoom'],
      classType: program['classType'] ?? data['classType'],
      sessionDuration: program['sessionDuration'] ?? data['sessionDuration'],
      hoursPerWeek: resolvedHoursPerWeek,
      timeOfDayPreference: preferences['timeOfDayPreference'] ?? data['timeOfDayPreference'],
      schedulingNotes: preferences['schedulingNotes'] as String?,
      guardianId: contact['guardianId'] ?? data['guardianId'],
      isAdult: metadata['isAdult'] ?? false,
      programTitle: data['programTitle'] as String?,
      pricingPlanId: legacyPlanId,
      pricingPlanLabel: metadata['pricingPlanLabel'] as String?,
      trackId: resolvedTrackId,
      // Handle multi-student format
      students: data['students'] != null
          ? (data['students'] as List).map((e) => StudentInfo.fromMap(e as Map<String, dynamic>)).toList()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      if (programTitle != null) 'programTitle': programTitle,
      'specificLanguage': specificLanguage,
      'gradeLevel': gradeLevel,
      'contact': {
        'email': email,
        'phone': phoneNumber,
        'country': {'code': countryCode, 'name': countryName},
        if (parentName != null) 'parentName': parentName,
        if (city != null) 'city': city,
        if (whatsAppNumber != null) 'whatsApp': whatsAppNumber,
        if (guardianId != null) 'guardianId': guardianId,
      },
      'preferences': {
        'days': preferredDays,
        'timeSlots': preferredTimeSlots,
        'timeZone': timeZone,
        if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
        if (timeOfDayPreference != null) 'timeOfDayPreference': timeOfDayPreference,
        if (schedulingNotes != null && schedulingNotes!.trim().isNotEmpty)
          'schedulingNotes': schedulingNotes!.trim(),
      },
      'student': () {
        final split = splitFullName(studentName);
        return {
          if (studentName != null) 'name': studentName,
          if (split.firstName.isNotEmpty) 'firstName': split.firstName,
          if (split.lastName.isNotEmpty) 'lastName': split.lastName,
          if (studentAge != null) 'age': studentAge,
          if (gender != null) 'gender': gender,
          if (knowsZoom != null) 'knowsZoom': knowsZoom,
        };
      }(),
      // Multi-student support
      if (students != null && students!.isNotEmpty) 'students': students!.map((s) => s.toMap()).toList(),
      'program': {
        if (role != null) 'role': role,
        if (classType != null) 'classType': classType,
        if (sessionDuration != null) 'sessionDuration': sessionDuration,
        if (hoursPerWeek != null) 'hoursPerWeek': hoursPerWeek,
      },
      if (trackId != null || hoursPerWeek != null)
        'pricing': {
          if (trackId != null) 'trackId': trackId,
          if (hoursPerWeek != null) 'hoursPerWeek': hoursPerWeek,
        },
      'metadata': {
        'submittedAt': Timestamp.fromDate(submittedAt),
        'status': status,
        'source': 'web_landing_page',
        'isAdult': isAdult,
        if (pricingPlanId != null) 'pricingPlanId': pricingPlanId,
        if (pricingPlanLabel != null) 'pricingPlanLabel': pricingPlanLabel,
        if (trackId != null) 'trackId': trackId,
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
        if (reviewNotes != null) 'reviewNotes': reviewNotes,
      },
      // Also include at top level for backward compatibility and job board service
      if (studentName != null) 'studentName': studentName,
      if (studentAge != null) 'studentAge': studentAge,
    };
  }

  EnrollmentRequest copyWith({
    String? id,
    String? subject,
    String? specificLanguage,
    String? gradeLevel,
    String? email,
    String? phoneNumber,
    String? countryCode,
    String? countryName,
    List<String>? preferredDays,
    List<String>? preferredTimeSlots,
    DateTime? submittedAt,
    String? status,
    String? timeZone,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewNotes,
    String? studentName,
    String? studentAge,
    String? role,
    String? preferredLanguage,
    String? parentName,
    String? city,
    String? whatsAppNumber,
    String? gender,
    bool? knowsZoom,
    String? classType,
    String? sessionDuration,
    String? timeOfDayPreference,
    String? guardianId,
    bool? isAdult,
    List<StudentInfo>? students,
    String? programTitle,
    String? pricingPlanId,
    String? pricingPlanLabel,
    String? trackId,
    int? hoursPerWeek,
    String? schedulingNotes,
  }) {
    return EnrollmentRequest(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      specificLanguage: specificLanguage ?? this.specificLanguage,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      preferredDays: preferredDays ?? this.preferredDays,
      preferredTimeSlots: preferredTimeSlots ?? this.preferredTimeSlots,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      timeZone: timeZone ?? this.timeZone,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      studentName: studentName ?? this.studentName,
      studentAge: studentAge ?? this.studentAge,
      role: role ?? this.role,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      parentName: parentName ?? this.parentName,
      city: city ?? this.city,
      whatsAppNumber: whatsAppNumber ?? this.whatsAppNumber,
      gender: gender ?? this.gender,
      knowsZoom: knowsZoom ?? this.knowsZoom,
      classType: classType ?? this.classType,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      timeOfDayPreference: timeOfDayPreference ?? this.timeOfDayPreference,
      guardianId: guardianId ?? this.guardianId,
      isAdult: isAdult ?? this.isAdult,
      students: students ?? this.students,
      programTitle: programTitle ?? this.programTitle,
      pricingPlanId: pricingPlanId ?? this.pricingPlanId,
      pricingPlanLabel: pricingPlanLabel ?? this.pricingPlanLabel,
      trackId: trackId ?? this.trackId,
      hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      schedulingNotes: schedulingNotes ?? this.schedulingNotes,
    );
  }
}

