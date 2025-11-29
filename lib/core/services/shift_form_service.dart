import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';

/// Service to manage the link between shifts/timesheets and readiness forms
class ShiftFormService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// The ID of the "Readiness Form" that teachers must fill after each class
  /// This should be configured in app settings, but we'll use a constant for now
  static const String readinessFormId = 'Ur1oW7SmFsMyNniTf6jS'; // From screenshot

  /// Get the readiness form template
  static Future<Map<String, dynamic>?> getReadinessFormTemplate() async {
    try {
      final doc = await _firestore.collection('form').doc(readinessFormId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      AppLogger.error('ShiftFormService: Error getting readiness form template: $e');
      return null;
    }
  }

  /// Check if a form response exists for a specific shift
  static Future<String?> getFormResponseForShift(String shiftId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Query form responses linked to this shift
      final query = await _firestore
          .collection('form_responses')
          .where('shiftId', isEqualTo: shiftId)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
      return null;
    } catch (e) {
      AppLogger.error('ShiftFormService: Error checking form response: $e');
      return null;
    }
  }

  /// Check if a teacher has pending (unfilled) forms for today
  static Future<List<Map<String, dynamic>>> getPendingFormsForTeacher() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Get today's completed timesheet entries without form responses
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final timesheetQuery = await _firestore
          .collection('timesheet_entries')
          .where('teacher_id', isEqualTo: user.uid)
          .where('clock_out_time', isNotEqualTo: null)
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('created_at', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      final pendingForms = <Map<String, dynamic>>[];

      for (final doc in timesheetQuery.docs) {
        final data = doc.data();
        final formCompleted = data['form_completed'] ?? false;
        
        if (!formCompleted) {
          pendingForms.add({
            'timesheetId': doc.id,
            'shiftId': data['shift_id'],
            'shiftTitle': data['shift_title'] ?? 'Unknown Shift',
            'clockInTime': data['clock_in_time'],
            'clockOutTime': data['clock_out_time'],
          });
        }
      }

      return pendingForms;
    } catch (e) {
      AppLogger.error('ShiftFormService: Error getting pending forms: $e');
      return [];
    }
  }

  /// Link a form response to a timesheet entry
  static Future<bool> linkFormToTimesheet({
    required String timesheetId,
    required String formResponseId,
    double? reportedHours,
    String? formNotes,
  }) async {
    try {
      await _firestore.collection('timesheet_entries').doc(timesheetId).update({
        'form_response_id': formResponseId,
        'form_completed': true,
        'reported_hours': reportedHours,
        'form_notes': formNotes,
        'form_completed_at': FieldValue.serverTimestamp(),
      });

      AppLogger.debug('ShiftFormService: Linked form $formResponseId to timesheet $timesheetId');
      return true;
    } catch (e) {
      AppLogger.error('ShiftFormService: Error linking form to timesheet: $e');
      return false;
    }
  }

  /// Submit a readiness form for a shift
  static Future<String?> submitReadinessForm({
    required String timesheetId,
    required String shiftId,
    required Map<String, dynamic> formResponses,
    double? reportedHours,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Create form response document
      final formResponseData = {
        'formId': readinessFormId,
        'userId': user.uid,
        'userEmail': user.email,
        'firstName': userData['first_name'] ?? '',
        'lastName': userData['last_name'] ?? '',
        'shiftId': shiftId,
        'timesheetId': timesheetId,
        'responses': formResponses,
        'reportedHours': reportedHours,
        'submittedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('form_responses').add(formResponseData);

      // Update timesheet entry with form link
      await linkFormToTimesheet(
        timesheetId: timesheetId,
        formResponseId: docRef.id,
        reportedHours: reportedHours,
      );

      AppLogger.debug('ShiftFormService: Submitted readiness form ${docRef.id}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('ShiftFormService: Error submitting readiness form: $e');
      return null;
    }
  }

  /// Get form completion statistics for export
  static Future<Map<String, dynamic>> getFormDataForTimesheet(String timesheetId) async {
    try {
      final timesheetDoc = await _firestore.collection('timesheet_entries').doc(timesheetId).get();
      if (!timesheetDoc.exists) return {};

      final data = timesheetDoc.data()!;
      final formResponseId = data['form_response_id'];

      if (formResponseId == null) {
        return {
          'formCompleted': false,
          'reportedHours': null,
          'formNotes': null,
        };
      }

      final formResponseDoc = await _firestore.collection('form_responses').doc(formResponseId).get();
      if (!formResponseDoc.exists) {
        return {
          'formCompleted': true,
          'reportedHours': data['reported_hours'],
          'formNotes': data['form_notes'],
        };
      }

      final formData = formResponseDoc.data()!;
      final responses = formData['responses'] as Map<String, dynamic>? ?? {};

      return {
        'formCompleted': true,
        'reportedHours': formData['reportedHours'] ?? data['reported_hours'],
        'formNotes': _extractFormNotes(responses),
        'formResponses': responses,
      };
    } catch (e) {
      AppLogger.error('ShiftFormService: Error getting form data for timesheet: $e');
      return {};
    }
  }

  /// Extract notes/comments from form responses
  static String? _extractFormNotes(Map<String, dynamic> responses) {
    // Look for common note field names
    final noteKeys = ['notes', 'comments', 'additional_notes', 'remarks'];
    for (final key in noteKeys) {
      if (responses.containsKey(key) && responses[key] != null) {
        return responses[key].toString();
      }
    }
    return null;
  }

  /// Get all form responses for a teacher within a date range (for export)
  static Future<Map<String, Map<String, dynamic>>> getFormResponsesForExport({
    required String teacherId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final query = await _firestore
          .collection('form_responses')
          .where('userId', isEqualTo: teacherId)
          .where('submittedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('submittedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final result = <String, Map<String, dynamic>>{};
      for (final doc in query.docs) {
        final data = doc.data();
        final timesheetId = data['timesheetId'] as String?;
        if (timesheetId != null) {
          result[timesheetId] = {
            'formResponseId': doc.id,
            'reportedHours': data['reportedHours'],
            'responses': data['responses'],
            'submittedAt': data['submittedAt'],
          };
        }
      }
      return result;
    } catch (e) {
      AppLogger.error('ShiftFormService: Error getting form responses for export: $e');
      return {};
    }
  }
}

