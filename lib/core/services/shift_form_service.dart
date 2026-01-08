import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';
import 'form_config_service.dart';
import 'pilot_flag_service.dart';
import 'form_template_service.dart';

/// Service to manage the link between shifts/timesheets and readiness forms
class ShiftFormService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Get the readiness form ID from config (async, reads from Firestore)
  /// For PILOT users: returns the new daily template ID from form_templates
  /// For REGULAR users: returns the old readiness form ID from form collection
  static Future<String> getReadinessFormId() async {
    // Check if current user is in pilot mode
    final isPilot = await PilotFlagService.isCurrentUserPilot();
    
    if (isPilot) {
      AppLogger.debug('ShiftFormService: Pilot user - using new template system');
      // Try to get the active daily template ID
      try {
        final template = await FormTemplateService.getActiveDailyTemplate();
        if (template != null && template.id.isNotEmpty) {
          AppLogger.debug('ShiftFormService: Using pilot template ID: ${template.id}');
          return template.id;
        }
      } catch (e) {
        AppLogger.error('ShiftFormService: Error getting pilot template: $e');
      }
    }
    
    // Fallback to old config-based form ID
    return await FormConfigService.getReadinessFormId();
  }
  
  /// Synchronous getter for backward compatibility - uses cached value or fallback
  /// WARNING: This may return stale data. Prefer getReadinessFormId() when possible.
  @Deprecated('Use getReadinessFormId() instead for fresh config values')
  static String get readinessFormId => 'Ur1oW7SmFsMyNniTf6jS';

  /// Get the readiness form template
  /// For PILOT users: returns the new minimal template from form_templates
  /// For REGULAR users: returns the old form from form collection
  static Future<Map<String, dynamic>?> getReadinessFormTemplate() async {
    try {
      // Check if current user is in pilot mode
      final isPilot = await PilotFlagService.isCurrentUserPilot();
      
      if (isPilot) {
        AppLogger.debug('ShiftFormService: Pilot user - loading new template');
        // Try to get the active daily template
        final template = await FormTemplateService.getActiveDailyTemplate();
        if (template != null) {
          AppLogger.debug('ShiftFormService: Using pilot template: ${template.name}');
          // Convert FormTemplate to map format compatible with existing form UI
          return _convertTemplateToFormFormat(template);
        }
      }
      
      // Fallback to old form collection
      final formId = await FormConfigService.getReadinessFormId();
      final doc = await _firestore.collection('form').doc(formId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      AppLogger.error('ShiftFormService: Error getting readiness form template: $e');
      return null;
    }
  }
  
  /// Convert new FormTemplate format to old form format for UI compatibility
  static Map<String, dynamic> _convertTemplateToFormFormat(dynamic template) {
    // template is a FormTemplate object
    final fields = <Map<String, dynamic>>[];
    
    for (final field in template.fields) {
      fields.add({
        'id': field.id,
        'label': field.label,
        'type': _mapFieldType(field.type),
        'placeholder': field.placeholder ?? '',
        'required': field.required,
        'order': field.order,
        'options': field.options,
        'validation': field.validation,
      });
    }
    
    return {
      'id': template.id,
      'name': template.name,
      'description': template.description,
      'fields': fields,
      'isActive': template.isActive,
      'version': template.version,
      'isPilotTemplate': true, // Flag to identify new template system
    };
  }
  
  /// Map new field types to old field types for UI compatibility
  static String _mapFieldType(String newType) {
    switch (newType) {
      case 'text':
        return 'openEnded';
      case 'long_text':
        return 'longAnswer';
      case 'number':
        return 'number';
      case 'radio':
        return 'multipleChoice';
      case 'checkbox':
        return 'checkbox';
      case 'date':
        return 'date';
      case 'time':
        return 'time';
      case 'image':
        return 'image';
      default:
        return 'openEnded';
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
  /// Includes both completed shifts with timesheets AND missed shifts without timesheets
  static Future<List<Map<String, dynamic>>> getPendingFormsForTeacher() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final pendingForms = <Map<String, dynamic>>[];

      // 1. Get completed timesheet entries without form responses
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

      for (final doc in timesheetQuery.docs) {
        final data = doc.data();
        final formCompleted = data['form_completed'] ?? false;
        
        if (!formCompleted) {
          pendingForms.add({
            'timesheetId': doc.id,
            'shiftId': data['shift_id'] ?? data['shiftId'],
            'shiftTitle': data['shift_title'] ?? 'Unknown Shift',
            'clockInTime': data['clock_in_time'],
            'clockOutTime': data['clock_out_time'],
            'type': 'completed', // Has timesheet entry
          });
        }
      }

      // 2. Get missed shifts (no timesheet entries) that need forms
      // Look for shifts marked as "missed" in the last 7 days that don't have form responses
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final missedShiftsQuery = await _firestore
          .collection('teaching_shifts')
          .where('teacher_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'missed')
          .where('shift_end', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .get();

      for (final shiftDoc in missedShiftsQuery.docs) {
        final shiftData = shiftDoc.data();
        final shiftId = shiftDoc.id;
        
        // Check if form already exists for this shift
        final formResponseId = await getFormResponseForShift(shiftId);
        if (formResponseId != null) {
          continue; // Form already submitted
        }

        // Check if timesheet exists (if it does, it's already handled above)
        final timesheetCheck = await _firestore
            .collection('timesheet_entries')
            .where('shift_id', isEqualTo: shiftId)
            .where('teacher_id', isEqualTo: user.uid)
            .limit(1)
            .get();
        
        if (timesheetCheck.docs.isNotEmpty) {
          continue; // Has timesheet, already handled above
        }

        // This is a missed shift without timesheet - needs form
        final shiftStart = _asDateTime(shiftData['shift_start']);
        final shiftEnd = _asDateTime(shiftData['shift_end']);
        
        pendingForms.add({
          'shiftId': shiftId,
          'shiftTitle': shiftData['auto_generated_name'] ?? 
                       shiftData['custom_name'] ?? 
                       'Unknown Shift',
          'shiftStart': shiftStart,
          'shiftEnd': shiftEnd,
          'missedReason': shiftData['missed_reason'] ?? 'Teacher did not clock in',
          'type': 'missed', // No timesheet entry
        });
      }

      // Sort by shift end time (most recent first)
      pendingForms.sort((a, b) {
        final aTime = _asDateTime(a['shiftEnd']) ?? _asDateTime(a['clockOutTime']);
        final bTime = _asDateTime(b['shiftEnd']) ?? _asDateTime(b['clockOutTime']);
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

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

  /// Link a form response directly to a shift (for missed shifts without timesheet)
  static Future<bool> linkFormToShift({
    required String shiftId,
    required String formResponseId,
    double? reportedHours,
    String? formNotes,
  }) async {
    try {
      // Update the shift document to track form completion
      await _firestore.collection('teaching_shifts').doc(shiftId).update({
        'form_response_id': formResponseId,
        'form_completed': true,
        'form_completed_at': FieldValue.serverTimestamp(),
        'reported_hours': reportedHours,
        'form_notes': formNotes,
      });

      AppLogger.debug('ShiftFormService: Linked form $formResponseId to shift $shiftId');
      return true;
    } catch (e) {
      AppLogger.error('ShiftFormService: Error linking form to shift: $e');
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

      // Get form ID from config
      final formId = await getReadinessFormId();
      
      // Get user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Create form response document with yearMonth for monthly grouping
      final now = DateTime.now();
      final formResponseData = {
        'formId': formId,
        'userId': user.uid,
        'userEmail': user.email,
        'firstName': userData['first_name'] ?? '',
        'lastName': userData['last_name'] ?? '',
        'shiftId': shiftId,
        'timesheetId': timesheetId,
        'responses': formResponses,
        'reportedHours': reportedHours,
        'submittedAt': FieldValue.serverTimestamp(),
        'yearMonth': FormConfigService.getYearMonth(now), // For monthly grouping/audits
        'status': 'completed',
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
