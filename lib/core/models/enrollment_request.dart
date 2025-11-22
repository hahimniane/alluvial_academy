import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  factory EnrollmentRequest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle nested structure
    final contact = data['contact'] as Map<String, dynamic>? ?? {};
    final country = contact['country'] as Map<String, dynamic>? ?? {};
    final preferences = data['preferences'] as Map<String, dynamic>? ?? {};
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    
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
      },
      'preferences': {
        'days': preferredDays,
        'timeSlots': preferredTimeSlots,
        'timeZone': timeZone,
      },
      'metadata': {
        'submittedAt': Timestamp.fromDate(submittedAt),
        'status': status,
        'source': 'web_landing_page',
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
        if (reviewNotes != null) 'reviewNotes': reviewNotes,
      },
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
    );
  }
}

