import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle form template migrations and auto-refresh
class FormMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _versionKey = 'form_template_version';
  static const int _currentVersion = 2;

  /// Check if forms need to be refreshed and migrate if necessary
  static Future<bool> checkAndMigrateIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt(_versionKey) ?? 0;
      
      // Get server version
      final configDoc = await _firestore
          .collection('app_config')
          .doc('version')
          .get();
      
      final serverVersion = configDoc.exists 
          ? (configDoc.data()?['formTemplateVersion'] as int? ?? _currentVersion)
          : _currentVersion;
      
      if (localVersion < serverVersion) {
        if (kDebugMode) {
          print('📝 Form templates need update: $localVersion -> $serverVersion');
        }
        
        // Clear form cache
        await _clearFormCache();
        
        // Update local version
        await prefs.setInt(_versionKey, serverVersion);
        
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking form migration: $e');
      }
      return false;
    }
  }

  /// Clear cached form data to force refresh
  static Future<void> _clearFormCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear any cached form data
      final keys = prefs.getKeys().where((k) => 
        k.startsWith('form_') || 
        k.startsWith('template_')
      );
      
      for (var key in keys) {
        await prefs.remove(key);
      }
      
      if (kDebugMode) {
        print('🗑️ Form cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing form cache: $e');
      }
    }
  }

  /// Create new user-friendly form templates in Firebase
  static Future<void> createNewFormTemplates() async {
    final batch = _firestore.batch();
    
    for (var entry in _newFormTemplates.entries) {
      final docRef = _firestore.collection('form_templates').doc(entry.key);
      batch.set(docRef, {
        ...entry.value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    
    await batch.commit();
    
    // Update version
    await _firestore.collection('app_config').doc('version').set({
      'formTemplateVersion': _currentVersion,
      'lastUpdated': FieldValue.serverTimestamp(),
      'forceRefresh': true,
    }, SetOptions(merge: true));
    
    if (kDebugMode) {
      print('✅ New form templates created');
    }
  }

  /// Get active form templates by type
  static Future<List<Map<String, dynamic>>> getActiveTemplatesByType(String frequency) async {
    try {
      final snapshot = await _firestore
          .collection('form_templates')
          .where('isActive', isEqualTo: true)
          .where('frequency', isEqualTo: frequency)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching templates: $e');
      }
      return [];
    }
  }

  /// Get the daily class report template
  static Future<Map<String, dynamic>?> getDailyTemplate() async {
    final templates = await getActiveTemplatesByType('perSession');
    return templates.isNotEmpty ? templates.first : null;
  }

  /// Get the weekly summary template
  static Future<Map<String, dynamic>?> getWeeklyTemplate() async {
    final templates = await getActiveTemplatesByType('weekly');
    return templates.isNotEmpty ? templates.first : null;
  }

  /// Get the monthly review template
  static Future<Map<String, dynamic>?> getMonthlyTemplate() async {
    final templates = await getActiveTemplatesByType('monthly');
    return templates.isNotEmpty ? templates.first : null;
  }

  /// Map old field ID to new field ID
  static String mapFieldId(String oldFieldId) {
    return _fieldMapping[oldFieldId] ?? oldFieldId;
  }

  /// New user-friendly form templates - SHIFT-BASED
  static final Map<String, Map<String, dynamic>> _newFormTemplates = {
    'daily_class_report': {
      'name': 'Daily Class Report',
      'description': 'Post-class report linked to a specific shift',
      'frequency': 'perSession',
      'isActive': true,
      'version': 3,
      'requiresShift': true, // NEW: Form must be linked to a shift
      'autoFillRules': [
        {'fieldId': '_shift_id', 'sourceField': 'shiftId', 'editable': false},
        {'fieldId': '_shift_subject', 'sourceField': 'shift.subjectDisplayName', 'editable': false},
        {'fieldId': '_shift_students', 'sourceField': 'shift.studentNames', 'editable': false},
        {'fieldId': '_shift_duration', 'sourceField': 'shift.duration', 'editable': false},
        {'fieldId': '_shift_class_type', 'sourceField': 'shift.classType', 'editable': false},
        {'fieldId': '_clock_in_time', 'sourceField': 'shift.clockInTime', 'editable': false},
        {'fieldId': '_clock_out_time', 'sourceField': 'shift.clockOutTime', 'editable': false},
      ],
      'fields': [
        // Shift data is auto-filled, teacher only needs to verify/update
        {
          'id': 'actual_duration',
          'label': 'Actual class duration (hours)',
          'type': 'number',
          'order': 1,
          'required': true,
          'placeholder': 'Actual time spent (may differ from scheduled)',
          'validation': {'min': 0.25, 'max': 4},
          'defaultFromShift': 'duration',
        },
        {
          'id': 'students_attended',
          'label': 'Which students attended?',
          'type': 'multi_select',
          'order': 2,
          'required': true,
          'optionsFromShift': 'studentNames', // Options come from shift
          'placeholder': 'Select students who attended',
        },
        {
          'id': 'lesson_covered',
          'label': 'What lesson/topic did you teach?',
          'type': 'text',
          'order': 3,
          'required': true,
          'placeholder': 'e.g., Surah Al-Fatiha verses 1-3',
        },
        {
          'id': 'used_curriculum',
          'label': 'Did you use the official curriculum?',
          'type': 'radio',
          'order': 4,
          'required': true,
          'options': ['Yes, Used Official Curriculum', 'No, Used Own Content', 'Partially Used', 'Not Sure'],
        },
        {
          'id': 'session_quality',
          'label': 'How did the session go?',
          'type': 'radio',
          'order': 5,
          'required': true,
          'options': ['Excellent', 'Good', 'Average', 'Challenging'],
        },
        {
          'id': 'teacher_notes',
          'label': 'Additional notes or observations',
          'type': 'long_text',
          'order': 6,
          'required': false,
          'placeholder': 'Any important observations, student progress, or concerns',
        },
      ],
    },
    'weekly_summary': {
      'name': 'Weekly Summary',
      'description': 'End of week teaching summary and reflection',
      'frequency': 'weekly',
      'isActive': true,
      'version': 3,
      'requiresShift': false, // Weekly summary is not tied to a specific shift
      'autoFillRules': [
        {'fieldId': '_teacher_name', 'sourceField': 'teacherName', 'editable': false},
        {'fieldId': '_week_ending', 'sourceField': 'weekEndingDate', 'editable': false},
        {'fieldId': '_week_shifts_count', 'sourceField': 'weekShiftsCount', 'editable': false},
        {'fieldId': '_week_completed_classes', 'sourceField': 'weekCompletedClasses', 'editable': false},
      ],
      'fields': [
        {
          'id': 'weekly_rating',
          'label': 'How would you rate this week overall?',
          'type': 'radio',
          'order': 1,
          'required': true,
          'options': ['Excellent', 'Good', 'Average', 'Challenging'],
        },
        {
          'id': 'classes_completed',
          'label': 'How many classes did you complete this week?',
          'type': 'number',
          'order': 2,
          'required': true,
          'validation': {'min': 0, 'max': 50},
          'defaultFromSystem': 'weekCompletedClasses',
        },
        {
          'id': 'absences_this_week',
          'label': 'How many classes did you miss?',
          'type': 'radio',
          'order': 3,
          'required': true,
          'options': ['0 (None)', '1 class', '2 classes', '3 classes', '4+ classes'],
        },
        {
          'id': 'video_recording_done',
          'label': 'Did you complete your weekly post-class video recording?',
          'type': 'radio',
          'order': 4,
          'required': true,
          'options': ['Yes', 'No', 'N/A'],
        },
        {
          'id': 'achievements',
          'label': 'Key achievements this week',
          'type': 'long_text',
          'order': 5,
          'required': true,
          'placeholder': 'Student progress, milestones reached, improvements, etc.',
        },
        {
          'id': 'challenges',
          'label': 'Any challenges or support needed?',
          'type': 'long_text',
          'order': 6,
          'required': false,
          'placeholder': 'Leave empty if none',
        },
        {
          'id': 'coach_helpfulness',
          'label': 'How helpful was your coach this week?',
          'type': 'radio',
          'order': 7,
          'required': true,
          'options': ['Very Helpful', 'Somewhat Helpful', 'Not Helpful', 'Please Change My Coach', 'N/A'],
        },
      ],
    },
    'monthly_review': {
      'name': 'Monthly Review',
      'description': 'End of month teaching review and student attendance summary',
      'frequency': 'monthly',
      'isActive': true,
      'version': 3,
      'requiresShift': false, // Monthly review is not tied to a specific shift
      'autoFillRules': [
        {'fieldId': '_teacher_name', 'sourceField': 'teacherName', 'editable': false},
        {'fieldId': '_month', 'sourceField': 'monthDate', 'editable': false},
        {'fieldId': '_month_total_classes', 'sourceField': 'monthTotalClasses', 'editable': false},
        {'fieldId': '_month_completed', 'sourceField': 'monthCompletedClasses', 'editable': false},
      ],
      'fields': [
        {
          'id': 'month_rating',
          'label': 'How would you rate this month?',
          'type': 'radio',
          'order': 1,
          'required': true,
          'options': ['Excellent', 'Good', 'Average', 'Challenging'],
        },
        {
          'id': 'goals_met',
          'label': 'Were your teaching goals met?',
          'type': 'radio',
          'order': 2,
          'required': true,
          'options': ['Yes, All Goals', 'Most Goals', 'Some Goals', 'Few Goals'],
        },
        {
          'id': 'bayana_completed',
          'label': 'Did you have Group Bayana with students this month?',
          'type': 'radio',
          'order': 3,
          'required': true,
          'options': ['Yes', 'No', 'N/A'],
        },
        {
          'id': 'student_attendance_summary',
          'label': 'Student attendance issues this month',
          'type': 'long_text',
          'order': 4,
          'required': false,
          'placeholder': 'List students who were frequently absent or late, or who missed Bayana',
        },
        {
          'id': 'monthly_achievements',
          'label': 'Key achievements this month',
          'type': 'long_text',
          'order': 5,
          'required': true,
          'placeholder': 'Student progress, improvements, milestones, curriculum completion, etc.',
        },
        {
          'id': 'comments_for_admin',
          'label': 'Comments or requests for admin',
          'type': 'long_text',
          'order': 6,
          'required': false,
          'placeholder': 'Feedback, requests, concerns, suggestions',
        },
      ],
    },
  };

  /// Field mapping from old bilingual IDs to new English IDs
  static final Map<String, String> _fieldMapping = {
    '1754405971187': 'device_used',
    '1754406115874': 'class_type',
    '1754406288023': 'class_day',
    '1754406414139': 'class_duration',
    '1754406457284': 'students_present',
    '1754406487572': 'students_absent',
    '1754406512129': 'students_late',
    '1754406537658': 'video_recording_done',
    '1754406625835': 'teacher_arrival',
    '1754406729715': 'absences_this_week',
    '1754406826688': 'clock_in_time',
    '1754406914911': 'clock_out_time',
    '1754407016623': 'bayana_completed',
    '1754407079872': 'outside_schedule',
    '1754407111959': 'outside_schedule_reason',
    '1754407141413': 'students_missed_bayana',
    '1754407184691': 'lesson_covered',
    '1754407218568': 'student_submissions',
    '1754407297953': 'used_curriculum',
    '1754407417507': 'coach_helpfulness',
    '1754407509366': 'teacher_notes',
    '1756564707506': 'subject_taught',
    '1762629945642': 'teacher_name_selection',
    '1764288691217': 'host_name',
  };
}

