import 'package:cloud_firestore/cloud_firestore.dart';

class StudentInfo {
  final String name;
  final String age;
  final String? gender;

  StudentInfo({
    required this.name,
    required this.age,
    this.gender,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      if (gender != null) 'gender': gender,
    };
  }

  factory StudentInfo.fromMap(Map<String, dynamic> map) {
    return StudentInfo(
      name: map['name'] ?? '',
      age: map['age'] ?? '',
      gender: map['gender'],
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
      timeOfDayPreference: preferences['timeOfDayPreference'] ?? data['timeOfDayPreference'],
      guardianId: contact['guardianId'] ?? data['guardianId'],
      isAdult: metadata['isAdult'] ?? false,
      // Handle multi-student format
      students: data['students'] != null
          ? (data['students'] as List).map((e) => StudentInfo.fromMap(e as Map<String, dynamic>)).toList()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
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
      },
      'student': {
        if (studentName != null) 'name': studentName,
        if (studentAge != null) 'age': studentAge,
        if (gender != null) 'gender': gender,
        if (knowsZoom != null) 'knowsZoom': knowsZoom,
      },
      // Multi-student support
      if (students != null && students!.isNotEmpty) 'students': students!.map((s) => s.toMap()).toList(),
      'program': {
        if (role != null) 'role': role,
        if (classType != null) 'classType': classType,
        if (sessionDuration != null) 'sessionDuration': sessionDuration,
      },
      'metadata': {
        'submittedAt': Timestamp.fromDate(submittedAt),
        'status': status,
        'source': 'web_landing_page',
        'isAdult': isAdult,
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
    );
  }
}

