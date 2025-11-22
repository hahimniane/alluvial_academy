import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherApplication {
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
  final String currentStatus; // 'university_student', 'high_school_student', 'university_graduate', 'other'
  final String? currentStatusOther;
  
  // Teaching Program
  final List<String> teachingPrograms; // ['english', 'islamic_studies', 'adult_literacy', 'adlam', 'other']
  final String? teachingProgramOther;
  final List<String>? englishSubjects; // If English program selected
  
  // Languages
  final List<String> languages;
  
  // Time & Schedule
  final String timeDiscipline; // '100%', '50%', '<30%', 'day_person'
  final String scheduleBalance; // '100%', '50%', '>30%', 'not_at_all', 'n/a'
  
  // Islamic Studies Specific (if Islamic Studies selected)
  final String? tajwidLevel; // 'yes', 'no', 'average', 'n/a'
  final String? quranMemorization; // 'hafiz', '50%_or_more', '35%_or_less', 'less_than_juzu_anma', 'n/a'
  final String? arabicProficiency; // 'excellent', 'intermediate', 'beginner', 'n/a'
  
  // Motivation & Experience
  final String interestReason; // 100-400 words
  final String electricityAccess; // 'always', 'sometimes', 'rarely', 'never'
  final String teachingComfort; // 'very_comfortable', 'comfortable', 'less_comfortable', 'uncomfortable'
  final String studentInteractionGuarantee; // 'yes_always', 'sometimes', 'maybe_try', 'no_cant'
  final String availabilityStart; // 'one_week', 'two_weeks', 'three_weeks', 'one_month', 'other'
  final String? availabilityStartOther;
  
  // Technical
  final String teachingDevice; // 'computer', 'tablet', 'phone', 'no_device'
  final String internetAccess; // 'always', 'often', 'rarely', 'not_at_all'
  
  // Scenarios
  final String? scenarioNonParticipatingStudent; // 100-300 words
  
  // Additional
  final String? feedbackOnForm;
  
  // Legacy fields (for backward compatibility)
  final String countryOfOrigin;
  final String countryOfResidence;
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
    required this.currentLocation,
    required this.gender,
    required this.phoneNumber,
    required this.countryCode,
    required this.nationality,
    required this.currentStatus,
    this.currentStatusOther,
    required this.teachingPrograms,
    this.teachingProgramOther,
    this.englishSubjects,
    required this.languages,
    required this.timeDiscipline,
    required this.scheduleBalance,
    this.tajwidLevel,
    this.quranMemorization,
    this.arabicProficiency,
    required this.interestReason,
    required this.electricityAccess,
    required this.teachingComfort,
    required this.studentInteractionGuarantee,
    required this.availabilityStart,
    this.availabilityStartOther,
    required this.teachingDevice,
    required this.internetAccess,
    this.scenarioNonParticipatingStudent,
    this.feedbackOnForm,
    // Legacy
    this.countryOfOrigin = '',
    this.countryOfResidence = '',
    this.additionalInfo,
    required this.submittedAt,
    this.status = 'pending',
    this.reviewNotes,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory TeacherApplication.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Handle both new and legacy formats
    return TeacherApplication(
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
      teachingPrograms: List<String>.from(data['teaching_programs'] ?? data['teachingPrograms'] ?? []),
      teachingProgramOther: data['teaching_program_other'] ?? data['teachingProgramOther'],
      englishSubjects: data['english_subjects'] != null 
          ? List<String>.from(data['english_subjects']) 
          : (data['englishSubjects'] != null ? List<String>.from(data['englishSubjects']) : null),
      languages: List<String>.from(data['languages'] ?? []),
      timeDiscipline: data['time_discipline'] ?? data['timeDiscipline'] ?? '',
      scheduleBalance: data['schedule_balance'] ?? data['scheduleBalance'] ?? '',
      tajwidLevel: data['tajwid_level'] ?? data['tajwidLevel'],
      quranMemorization: data['quran_memorization'] ?? data['quranMemorization'],
      arabicProficiency: data['arabic_proficiency'] ?? data['arabicProficiency'],
      interestReason: data['interest_reason'] ?? data['interestReason'] ?? '',
      electricityAccess: data['electricity_access'] ?? data['electricityAccess'] ?? '',
      teachingComfort: data['teaching_comfort'] ?? data['teachingComfort'] ?? '',
      studentInteractionGuarantee: data['student_interaction_guarantee'] ?? data['studentInteractionGuarantee'] ?? '',
      availabilityStart: data['availability_start'] ?? data['availabilityStart'] ?? '',
      availabilityStartOther: data['availability_start_other'] ?? data['availabilityStartOther'],
      teachingDevice: data['teaching_device'] ?? data['teachingDevice'] ?? '',
      internetAccess: data['internet_access'] ?? data['internetAccess'] ?? '',
      scenarioNonParticipatingStudent: data['scenario_non_participating_student'] ?? data['scenarioNonParticipatingStudent'],
      feedbackOnForm: data['feedback_on_form'] ?? data['feedbackOnForm'],
      // Legacy
      countryOfOrigin: data['country_of_origin'] ?? '',
      countryOfResidence: data['country_of_residence'] ?? '',
      additionalInfo: data['additional_info'] ?? data['additionalInfo'],
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
      'email': email,
      'current_location': currentLocation,
      'gender': gender,
      'phone_number': phoneNumber,
      'country_code': countryCode,
      'nationality': nationality,
      'current_status': currentStatus,
      if (currentStatusOther != null) 'current_status_other': currentStatusOther,
      'teaching_programs': teachingPrograms,
      if (teachingProgramOther != null) 'teaching_program_other': teachingProgramOther,
      if (englishSubjects != null) 'english_subjects': englishSubjects,
      'languages': languages,
      'time_discipline': timeDiscipline,
      'schedule_balance': scheduleBalance,
      if (tajwidLevel != null) 'tajwid_level': tajwidLevel,
      if (quranMemorization != null) 'quran_memorization': quranMemorization,
      if (arabicProficiency != null) 'arabic_proficiency': arabicProficiency,
      'interest_reason': interestReason,
      'electricity_access': electricityAccess,
      'teaching_comfort': teachingComfort,
      'student_interaction_guarantee': studentInteractionGuarantee,
      'availability_start': availabilityStart,
      if (availabilityStartOther != null) 'availability_start_other': availabilityStartOther,
      'teaching_device': teachingDevice,
      'internet_access': internetAccess,
      if (scenarioNonParticipatingStudent != null) 'scenario_non_participating_student': scenarioNonParticipatingStudent,
      if (feedbackOnForm != null) 'feedback_on_form': feedbackOnForm,
      // Legacy fields for backward compatibility
      'country_of_origin': countryOfOrigin.isNotEmpty ? countryOfOrigin : currentLocation,
      'country_of_residence': countryOfResidence.isNotEmpty ? countryOfResidence : currentLocation,
      if (additionalInfo != null) 'additional_info': additionalInfo,
      'submitted_at': Timestamp.fromDate(submittedAt),
      'status': status,
      if (reviewNotes != null) 'review_notes': reviewNotes,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (reviewedAt != null) 'reviewed_at': Timestamp.fromDate(reviewedAt!),
    };
  }

  TeacherApplication copyWith({
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
    List<String>? teachingPrograms,
    String? teachingProgramOther,
    List<String>? englishSubjects,
    List<String>? languages,
    String? timeDiscipline,
    String? scheduleBalance,
    String? tajwidLevel,
    String? quranMemorization,
    String? arabicProficiency,
    String? interestReason,
    String? electricityAccess,
    String? teachingComfort,
    String? studentInteractionGuarantee,
    String? availabilityStart,
    String? availabilityStartOther,
    String? teachingDevice,
    String? internetAccess,
    String? scenarioNonParticipatingStudent,
    String? feedbackOnForm,
    String? countryOfOrigin,
    String? countryOfResidence,
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
      currentLocation: currentLocation ?? this.currentLocation,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      nationality: nationality ?? this.nationality,
      currentStatus: currentStatus ?? this.currentStatus,
      currentStatusOther: currentStatusOther ?? this.currentStatusOther,
      teachingPrograms: teachingPrograms ?? this.teachingPrograms,
      teachingProgramOther: teachingProgramOther ?? this.teachingProgramOther,
      englishSubjects: englishSubjects ?? this.englishSubjects,
      languages: languages ?? this.languages,
      timeDiscipline: timeDiscipline ?? this.timeDiscipline,
      scheduleBalance: scheduleBalance ?? this.scheduleBalance,
      tajwidLevel: tajwidLevel ?? this.tajwidLevel,
      quranMemorization: quranMemorization ?? this.quranMemorization,
      arabicProficiency: arabicProficiency ?? this.arabicProficiency,
      interestReason: interestReason ?? this.interestReason,
      electricityAccess: electricityAccess ?? this.electricityAccess,
      teachingComfort: teachingComfort ?? this.teachingComfort,
      studentInteractionGuarantee: studentInteractionGuarantee ?? this.studentInteractionGuarantee,
      availabilityStart: availabilityStart ?? this.availabilityStart,
      availabilityStartOther: availabilityStartOther ?? this.availabilityStartOther,
      teachingDevice: teachingDevice ?? this.teachingDevice,
      internetAccess: internetAccess ?? this.internetAccess,
      scenarioNonParticipatingStudent: scenarioNonParticipatingStudent ?? this.scenarioNonParticipatingStudent,
      feedbackOnForm: feedbackOnForm ?? this.feedbackOnForm,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
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
  
  bool get isIslamicStudiesProgram => teachingPrograms.contains('islamic_studies');
  bool get isEnglishProgram => teachingPrograms.contains('english');
  bool get isAdultLiteracyProgram => teachingPrograms.contains('adult_literacy');
  bool get isAdlamProgram => teachingPrograms.contains('adlam');
}
