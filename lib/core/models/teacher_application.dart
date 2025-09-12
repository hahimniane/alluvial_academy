import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherApplication {
  final String? id;
  final String firstName;
  final String lastName;
  final String email;
  final String countryOfOrigin;
  final String countryOfResidence;
  final List<String> languages;
  final String phoneNumber;
  final String countryCode;
  final String? additionalInfo;
  final DateTime submittedAt;
  final String status; // 'pending', 'reviewed', 'approved', 'rejected'
  final String? reviewNotes;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  TeacherApplication({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.countryOfOrigin,
    required this.countryOfResidence,
    required this.languages,
    required this.phoneNumber,
    required this.countryCode,
    this.additionalInfo,
    required this.submittedAt,
    this.status = 'pending',
    this.reviewNotes,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory TeacherApplication.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TeacherApplication(
      id: doc.id,
      firstName: data['first_name'] ?? '',
      lastName: data['last_name'] ?? '',
      email: data['email'] ?? '',
      countryOfOrigin: data['country_of_origin'] ?? '',
      countryOfResidence: data['country_of_residence'] ?? '',
      languages: List<String>.from(data['languages'] ?? []),
      phoneNumber: data['phone_number'] ?? '',
      countryCode: data['country_code'] ?? '',
      additionalInfo: data['additional_info'],
      submittedAt: (data['submitted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      reviewNotes: data['review_notes'],
      reviewedBy: data['reviewed_by'],
      reviewedAt: (data['reviewed_at'] as Timestamp?)?.toDate(),
    );
  }

  factory TeacherApplication.fromMap(Map<String, dynamic> data) {
    return TeacherApplication(
      id: data['id'],
      firstName: data['first_name'] ?? '',
      lastName: data['last_name'] ?? '',
      email: data['email'] ?? '',
      countryOfOrigin: data['country_of_origin'] ?? '',
      countryOfResidence: data['country_of_residence'] ?? '',
      languages: List<String>.from(data['languages'] ?? []),
      phoneNumber: data['phone_number'] ?? '',
      countryCode: data['country_code'] ?? '',
      additionalInfo: data['additional_info'],
      submittedAt: data['submitted_at'] is Timestamp 
          ? (data['submitted_at'] as Timestamp).toDate()
          : DateTime.parse(data['submitted_at'] ?? DateTime.now().toIso8601String()),
      status: data['status'] ?? 'pending',
      reviewNotes: data['review_notes'],
      reviewedBy: data['reviewed_by'],
      reviewedAt: data['reviewed_at'] is Timestamp 
          ? (data['reviewed_at'] as Timestamp).toDate()
          : data['reviewed_at'] != null ? DateTime.parse(data['reviewed_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'country_of_origin': countryOfOrigin,
      'country_of_residence': countryOfResidence,
      'languages': languages,
      'phone_number': phoneNumber,
      'country_code': countryCode,
      'additional_info': additionalInfo,
      'submitted_at': Timestamp.fromDate(submittedAt),
      'status': status,
      'review_notes': reviewNotes,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    };
  }

  TeacherApplication copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? countryOfOrigin,
    String? countryOfResidence,
    List<String>? languages,
    String? phoneNumber,
    String? countryCode,
    String? additionalInfo,
    DateTime? submittedAt,
    String? status,
    String? reviewNotes,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return TeacherApplication(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
      languages: languages ?? this.languages,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  String get fullName => '$firstName $lastName';

  String get languagesDisplay => languages.join(', ');
}