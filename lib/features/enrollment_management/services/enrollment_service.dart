import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/enrollment_request.dart';
import 'pricing_quote_service.dart';
import 'public_site_cms_service.dart';

class EnrollmentService {
  final CollectionReference _collection = 
      FirebaseFirestore.instance.collection('enrollments');

  Map<String, dynamic>? _extractPricingMap(Map<String, dynamic>? snapshot) {
    if (snapshot == null) return null;
    if (snapshot['version'] == 2) {
      return {
        if (snapshot['trackId'] != null) 'trackId': snapshot['trackId'],
        if (snapshot['hoursPerWeek'] != null)
          'hoursPerWeek': snapshot['hoursPerWeek'],
        if (snapshot['hourlyRateUsd'] != null)
          'hourlyRate': snapshot['hourlyRateUsd'],
        if (snapshot['discountApplied'] != null)
          'discountApplied': snapshot['discountApplied'],
        if (snapshot['monthlyEstimateUsd'] != null)
          'monthlyEstimate': snapshot['monthlyEstimateUsd'],
      };
    }
    // Legacy v1 snapshots - surface the fields the admin card already reads so
    // the enrollment list does not render blank pricing for older docs.
    return {
      if (snapshot['planId'] != null) 'planId': snapshot['planId'],
      if (snapshot['hourlyRateUsd'] != null)
        'hourlyRate': snapshot['hourlyRateUsd'],
      if (snapshot['monthlyEstimateUsd'] != null)
        'monthlyEstimate': snapshot['monthlyEstimateUsd'],
      if (snapshot['hoursPerWeek'] != null)
        'hoursPerWeek': snapshot['hoursPerWeek'],
    };
  }

  Future<void> submitEnrollment(EnrollmentRequest request) async {
    // Do not wrap in try/catch - rethrow so callers can distinguish network,
    // permission, and validation errors, and so stack traces are preserved.
    final data = request.toMap();
    final existingMetadata = data['metadata'] as Map<String, dynamic>? ?? {};
    final quoteOverrides =
        await PublicSiteCmsService.getPlanOverridesForQuotes();
    final pricingSnapshot = request.trackId != null
        ? PricingQuoteService.buildSnapshotV2(
            trackId: request.trackId,
            hoursPerWeek: request.hoursPerWeek,
            cmsOverrides: quoteOverrides,
          )
        : PricingQuoteService.buildSnapshot(
            planId: request.pricingPlanId,
            preferredDays: request.preferredDays,
            sessionDuration: request.sessionDuration,
            numericPlanOverrides: quoteOverrides,
          );
    final pricingMap = _extractPricingMap(pricingSnapshot);
    if (pricingMap != null) {
      data['pricing'] = pricingMap;
    }

    data['metadata'] = {
      ...existingMetadata,
      if (pricingSnapshot != null) 'pricingSnapshot': pricingSnapshot,
      if (request.trackId != null) 'trackId': request.trackId,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'requiresApproval': true,
    };
    await _collection.add(data);
  }
  
  /// Submit multiple enrollments for Parent/Guardian with multiple students
  /// Each student gets their own enrollment record but linked to the same parent
  Future<List<String>> submitMultipleEnrollments({
    required String parentName,
    required String email,
    required String phoneNumber,
    required String countryCode,
    required String countryName,
    required String city,
    required String whatsAppNumber,
    required String timeZone,
    required String preferredLanguage,
    required String role,
    required String? guardianId,
    required List<StudentInfo> students,
    String? programTitle,
    String? pricingPlanId,
    String? pricingPlanLabel,
    String? trackId,
    int? hoursPerWeek,
    String? schedulingNotes,
  }) async {
    final List<String> enrollmentIds = [];
    // Use a Firestore-generated id instead of millisecondsSinceEpoch to avoid
    // collisions between concurrent submissions.
    final String parentLinkId = _collection.doc().id;
    final notesTrimmed = schedulingNotes?.trim();
    final notesOut = (notesTrimmed != null && notesTrimmed.isNotEmpty)
        ? notesTrimmed
        : null;

    // Rethrow so callers see real FirebaseException codes rather than a wrapped
    // Exception that loses the stack trace and error code.
    final quoteOverrides =
        await PublicSiteCmsService.getPlanOverridesForQuotes();
    for (int i = 0; i < students.length; i++) {
        final student = students[i];

        final resolvedHours = student.hoursPerWeek ?? hoursPerWeek;
        final effectiveTrackId = student.trackId ?? trackId;
        final pricingSnapshot = effectiveTrackId != null
            ? PricingQuoteService.buildSnapshotV2(
                trackId: effectiveTrackId,
                hoursPerWeek: resolvedHours,
                cmsOverrides: quoteOverrides,
              )
            : PricingQuoteService.buildSnapshot(
                planId: pricingPlanId,
                preferredDays: student.preferredDays ?? const [],
                sessionDuration: student.sessionDuration,
                numericPlanOverrides: quoteOverrides,
              );
        final pricingMap = _extractPricingMap(pricingSnapshot);

        final nameSplit = splitFullName(student.name);
        final isAdultStudent = studentIsAdultFromAge(student.age);
        // Per-student programTitle: fall back to the shared programTitle when
        // siblings share the same subject; otherwise use the student's subject
        // so each doc reflects what this specific child enrolled in.
        final perStudentProgramTitle = student.subject?.trim().isNotEmpty == true
            ? student.subject
            : programTitle;

        final enrollmentData = {
          'subject': student.subject,
          if (perStudentProgramTitle != null)
            'programTitle': perStudentProgramTitle,
          'specificLanguage': student.specificLanguage,
          'gradeLevel': student.level ?? '',
          'contact': {
            'email': email,
            'phone': phoneNumber,
            'country': {'code': countryCode, 'name': countryName},
            'parentName': parentName,
            'city': city,
            'whatsApp': whatsAppNumber,
            if (guardianId != null) 'guardianId': guardianId,
          },
          'preferences': {
            'days': student.preferredDays ?? [],
            'timeSlots': student.preferredTimeSlots ?? [],
            'timeZone': timeZone,
            'preferredLanguage': preferredLanguage,
            'timeOfDayPreference': student.timeOfDayPreference,
            if (notesOut != null) 'schedulingNotes': notesOut,
          },
          'student': {
            'name': student.name,
            if (nameSplit.firstName.isNotEmpty)
              'firstName': nameSplit.firstName,
            if (nameSplit.lastName.isNotEmpty) 'lastName': nameSplit.lastName,
            'age': student.age,
            if (student.gender != null) 'gender': student.gender,
          },
          'program': {
            'role': role,
            'classType': student.classType,
            'sessionDuration': student.sessionDuration,
            if (resolvedHours != null) 'hoursPerWeek': resolvedHours,
          },
          if (pricingMap != null) 'pricing': pricingMap,
          'metadata': {
            'status': 'pending',
            'submittedAt': FieldValue.serverTimestamp(),
            'requiresApproval': true,
            'source': 'web_landing_page',
            'isAdult': isAdultStudent,
            if (pricingPlanId != null) 'pricingPlanId': pricingPlanId,
            if (pricingPlanLabel != null) 'pricingPlanLabel': pricingPlanLabel,
            if (effectiveTrackId != null) 'trackId': effectiveTrackId,
            if (pricingSnapshot != null) 'pricingSnapshot': pricingSnapshot,
            'parentLinkId': parentLinkId,
            'studentIndex': i,
            'totalStudents': students.length,
          },
        };
        
      final docRef = await _collection.add(enrollmentData);
      enrollmentIds.add(docRef.id);
    }

    return enrollmentIds;
  }

  /// Looks up an existing parent user by email or code.
  ///
  /// Returns one of:
  /// - `{ 'found': true, ...parentData }` when a valid parent is found.
  /// - `{ 'found': false }` when the lookup succeeded but no matching parent.
  /// - `{ 'found': false, 'error': '<code>' }` when the callable itself failed.
  ///
  /// UI code can now distinguish "parent not found" from "network / server
  /// error" instead of getting `null` for both.
  Future<Map<String, dynamic>> checkParentIdentity(String identifier) async {
    final trimmedIdentifier = identifier.trim();
    if (trimmedIdentifier.isEmpty) {
      return {'found': false, 'error': 'empty_identifier'};
    }

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('findUserByEmailOrCode')
          .call({'identifier': trimmedIdentifier});

      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['found'] == true) return data;
      return {'found': false};
    } on FirebaseFunctionsException catch (e) {
      return {
        'found': false,
        'error': e.code,
        if (e.message != null) 'errorMessage': e.message,
      };
    } catch (e) {
      return {'found': false, 'error': 'unknown', 'errorMessage': e.toString()};
    }
  }
}

