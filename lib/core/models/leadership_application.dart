import 'package:cloud_firestore/cloud_firestore.dart';

class LeadershipApplication {
  final String? id;
  
  // Basic Information
  final String firstName;
  final String lastName;
  final String email;
  final String currentLocation; // Country and City
  final String gender; // 'Male', 'Female'
  final String phoneNumber; // WhatsApp
  final String countryCode;
  final String nationality;
  
  // Current Status
  final String currentStatus; // 'university_student', 'university_graduate', 'professional', 'other'
  final String? currentStatusOther;
  
  // Leadership Interest
  final String interestReason; // Why interested in leadership
  final String? relevantExperience; // Relevant leadership/management experience
  
  // Availability
  final String availabilityStart; // 'one_week', 'two_weeks', 'three_weeks', 'one_month', 'other'
  final String? availabilityStartOther;
  
  // Metadata
  final DateTime submittedAt;
  final String status; // 'pending', 'reviewed', 'approved', 'rejected'
  final String? reviewNotes;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  LeadershipApplication({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.currentLocation,
    required this.gender,
    required this.phoneNumber,
    required this.countryCode,
    required this.nationality,
    required this.currentStatus,
    this.currentStatusOther,
    required this.interestReason,
    this.relevantExperience,
    required this.availabilityStart,
    this.availabilityStartOther,
    required this.submittedAt,
    this.status = 'pending',
    this.reviewNotes,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory LeadershipApplication.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return LeadershipApplication(
      id: doc.id,
      firstName: data['first_name'] ?? data['firstName'] ?? '',
      lastName: data['last_name'] ?? data['lastName'] ?? '',
      email: data['email'] ?? '',
      currentLocation: data['current_location'] ?? data['currentLocation'] ?? '',
      gender: data['gender'] ?? '',
      phoneNumber: data['phone_number'] ?? data['phoneNumber'] ?? '',
      countryCode: data['country_code'] ?? data['countryCode'] ?? '',
      nationality: data['nationality'] ?? '',
      currentStatus: data['current_status'] ?? data['currentStatus'] ?? '',
      currentStatusOther: data['current_status_other'] ?? data['currentStatusOther'],
      interestReason: data['interest_reason'] ?? data['interestReason'] ?? '',
      relevantExperience: data['relevant_experience'] ?? data['relevantExperience'],
      availabilityStart: data['availability_start'] ?? data['availabilityStart'] ?? '',
      availabilityStartOther: data['availability_start_other'] ?? data['availabilityStartOther'],
      submittedAt: (data['submitted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      reviewNotes: data['review_notes'] ?? data['reviewNotes'],
      reviewedBy: data['reviewed_by'] ?? data['reviewedBy'],
      reviewedAt: (data['reviewed_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'firstName': firstName, // For backward compatibility
      'lastName': lastName,
      'email': email,
      'current_location': currentLocation,
      'currentLocation': currentLocation,
      'gender': gender,
      'phone_number': phoneNumber,
      'phoneNumber': phoneNumber,
      'country_code': countryCode,
      'countryCode': countryCode,
      'nationality': nationality,
      'current_status': currentStatus,
      'currentStatus': currentStatus,
      if (currentStatusOther != null) 'current_status_other': currentStatusOther,
      if (currentStatusOther != null) 'currentStatusOther': currentStatusOther,
      'interest_reason': interestReason,
      'interestReason': interestReason,
      if (relevantExperience != null) 'relevant_experience': relevantExperience,
      if (relevantExperience != null) 'relevantExperience': relevantExperience,
      'availability_start': availabilityStart,
      'availabilityStart': availabilityStart,
      if (availabilityStartOther != null) 'availability_start_other': availabilityStartOther,
      if (availabilityStartOther != null) 'availabilityStartOther': availabilityStartOther,
      'submitted_at': Timestamp.fromDate(submittedAt),
      'submittedAt': Timestamp.fromDate(submittedAt),
      'status': status,
      if (reviewNotes != null) 'review_notes': reviewNotes,
      if (reviewNotes != null) 'reviewNotes': reviewNotes,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedAt != null) 'reviewed_at': Timestamp.fromDate(reviewedAt!),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
    };
  }

  LeadershipApplication copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? currentLocation,
    String? gender,
    String? phoneNumber,
    String? countryCode,
    String? nationality,
    String? currentStatus,
    String? currentStatusOther,
    String? interestReason,
    String? relevantExperience,
    String? availabilityStart,
    String? availabilityStartOther,
    DateTime? submittedAt,
    String? status,
    String? reviewNotes,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return LeadershipApplication(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      currentLocation: currentLocation ?? this.currentLocation,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      nationality: nationality ?? this.nationality,
      currentStatus: currentStatus ?? this.currentStatus,
      currentStatusOther: currentStatusOther ?? this.currentStatusOther,
      interestReason: interestReason ?? this.interestReason,
      relevantExperience: relevantExperience ?? this.relevantExperience,
      availabilityStart: availabilityStart ?? this.availabilityStart,
      availabilityStartOther: availabilityStartOther ?? this.availabilityStartOther,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}
