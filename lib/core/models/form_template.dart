import 'package:cloud_firestore/cloud_firestore.dart';

/// Form frequency types
enum FormFrequency {
  perSession, // Daily Class Report - filled after each session
  weekly, // Weekly Summary - once per week (available Sun-Mon-Tue)
  monthly, // Monthly Review - once per month
  onDemand, // Available anytime - for feedback, assessments, complaints
}

/// Form categories for organization
enum FormCategory {
  teaching, // Daily/Weekly/Monthly teaching reports
  studentAssessment, // Student evaluations and progress
  feedback, // Leadership feedback, complaints
  administrative, // Leave requests, incident reports
  other, // Miscellaneous forms
}

/// Extension for category display
extension FormCategoryExtension on FormCategory {
  String get displayName {
    switch (this) {
      case FormCategory.teaching:
        return 'Teaching Reports';
      case FormCategory.studentAssessment:
        return 'Student Assessment';
      case FormCategory.feedback:
        return 'Feedback & Complaints';
      case FormCategory.administrative:
        return 'Administrative';
      case FormCategory.other:
        return 'Other Forms';
    }
  }
  
  String get icon {
    switch (this) {
      case FormCategory.teaching:
        return '📚';
      case FormCategory.studentAssessment:
        return '📊';
      case FormCategory.feedback:
        return '💬';
      case FormCategory.administrative:
        return '📋';
      case FormCategory.other:
        return '📄';
    }
  }
}

/// Extension to check form availability based on frequency
extension FormFrequencyAvailability on FormFrequency {
  /// Check if the form is available to fill based on current day
  /// Weekly forms: Only available Sunday, Monday, Tuesday
  /// Monthly forms: Available last 3 days of month and first 3 days of next month
  /// Daily & OnDemand forms: Always available
  bool get isAvailableToday {
    final now = DateTime.now();
    switch (this) {
      case FormFrequency.perSession:
      case FormFrequency.onDemand:
        return true; // Always available
      case FormFrequency.weekly:
        // Sunday = 7, Monday = 1, Tuesday = 2
        final dayOfWeek = now.weekday;
        return dayOfWeek == DateTime.sunday || 
               dayOfWeek == DateTime.monday || 
               dayOfWeek == DateTime.tuesday;
      case FormFrequency.monthly:
        // Available last 3 days of month or first 3 days of next month
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final dayOfMonth = now.day;
        return dayOfMonth >= daysInMonth - 2 || dayOfMonth <= 3;
    }
  }

  /// Get the next available date for this form type
  DateTime get nextAvailableDate {
    final now = DateTime.now();
    switch (this) {
      case FormFrequency.perSession:
      case FormFrequency.onDemand:
        return now; // Available now
      case FormFrequency.weekly:
        // Find next Sunday
        final daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
        if (daysUntilSunday == 0 && now.weekday != DateTime.sunday) {
          return now.add(const Duration(days: 7));
        }
        return now.add(Duration(days: daysUntilSunday));
      case FormFrequency.monthly:
        // Find last 3 days of current month
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        if (now.day < daysInMonth - 2) {
          return DateTime(now.year, now.month, daysInMonth - 2);
        }
        return now;
    }
  }

  /// Human-readable message about when the form is available
  String get availabilityMessage {
    switch (this) {
      case FormFrequency.perSession:
        return 'Available after each class session';
      case FormFrequency.weekly:
        return isAvailableToday 
            ? 'Available now (Sunday - Tuesday)' 
            : 'Available Sunday, Monday, and Tuesday only';
      case FormFrequency.monthly:
        return isAvailableToday 
            ? 'Available now (end/start of month)' 
            : 'Available last 3 days of month or first 3 days of next month';
      case FormFrequency.onDemand:
        return 'Available anytime';
    }
  }
}

/// Auto-fill rule types - predefined fields the system can populate automatically
/// Note: Firestore templates can use custom string sourceField values beyond this enum
enum AutoFillField {
  teacherName, // From authenticated user
  teacherEmail, // From authenticated user
  sessionDate, // From shift/timesheet
  sessionTime, // From shift/timesheet (start-end)
  scheduledDuration, // From shift definition
  actualDuration, // Calculated from clock-in/out
  className, // From shift title
  subject, // From shift/job metadata
  // Extended fields for Firestore templates
  shiftId, // Shift ID
  weekEndingDate, // Week ending date
  weekShiftsCount, // Number of shifts in week
  weekCompletedClasses, // Completed classes in week
  monthDate, // Month date
  monthTotalClasses, // Total classes in month
  monthCompletedClasses, // Completed classes in month
}

/// Represents an auto-fill rule for a form field
/// Supports both enum-based and string-based sourceField for Firestore compatibility
class AutoFillRule {
  final String fieldId;
  final String sourceFieldString; // String-based for Firestore compatibility
  final bool editable; // Can user override the auto-filled value?

  const AutoFillRule({
    required this.fieldId,
    required this.sourceFieldString,
    this.editable = false,
  });

  /// Constructor from enum (for code-defined templates)
  factory AutoFillRule.fromEnum({
    required String fieldId,
    required AutoFillField sourceField,
    bool editable = false,
  }) {
    return AutoFillRule(
      fieldId: fieldId,
      sourceFieldString: sourceField.name,
      editable: editable,
    );
  }

  /// Get the AutoFillField enum if it matches, null otherwise
  AutoFillField? get sourceFieldEnum {
    try {
      return AutoFillField.values.firstWhere(
        (e) => e.name == sourceFieldString,
      );
    } catch (_) {
      return null; // Custom string field not in enum
    }
  }

  Map<String, dynamic> toMap() => {
        'fieldId': fieldId,
        'sourceField': sourceFieldString,
        'editable': editable,
      };

  factory AutoFillRule.fromMap(Map<String, dynamic> map) => AutoFillRule(
        fieldId: map['fieldId'] as String? ?? '',
        sourceFieldString: map['sourceField'] as String? ?? 'teacherName',
        editable: map['editable'] as bool? ?? false,
      );
}

/// Represents a form field definition
class FormFieldDefinition {
  final String id;
  final String label;
  final String type; // text, long_text, dropdown, radio, number, date, etc.
  final String? placeholder;
  final bool required;
  final int order;
  final List<String>? options; // For dropdown/radio
  final Map<String, dynamic>? conditionalLogic;
  final Map<String, dynamic>? validation;

  const FormFieldDefinition({
    required this.id,
    required this.label,
    required this.type,
    this.placeholder,
    this.required = false,
    this.order = 0,
    this.options,
    this.conditionalLogic,
    this.validation,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'type': type,
        'placeholder': placeholder,
        'required': required,
        'order': order,
        if (options != null) 'options': options,
        if (conditionalLogic != null) 'conditionalLogic': conditionalLogic,
        if (validation != null) 'validation': validation,
      };

  factory FormFieldDefinition.fromMap(String id, Map<String, dynamic> map) =>
      FormFieldDefinition(
        id: id,
        label: map['label'] as String? ?? '',
        type: map['type'] as String? ?? 'text',
        placeholder: map['placeholder'] as String?,
        required: map['required'] as bool? ?? false,
        order: map['order'] as int? ?? 0,
        options: (map['options'] as List<dynamic>?)?.cast<String>(),
        conditionalLogic: map['conditionalLogic'] as Map<String, dynamic>?,
        validation: map['validation'] as Map<String, dynamic>?,
      );
}

/// Form template model with versioning and frequency support
class FormTemplate {
  final String id;
  final String name;
  final String? description;
  final FormFrequency frequency;
  final FormCategory category; // NEW: For organizing forms
  final int version;
  final List<FormFieldDefinition> fields;
  final List<AutoFillRule> autoFillRules;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? subjectId; // Optional: link to specific subject/class
  final List<String>? allowedRoles; // NEW: Restrict who can fill the form

  const FormTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.frequency,
    this.category = FormCategory.other,
    this.version = 1,
    required this.fields,
    this.autoFillRules = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.subjectId,
    this.allowedRoles,
  });

  /// Total field count (excluding auto-filled hidden fields)
  int get visibleFieldCount =>
      fields.where((f) => !_isAutoFilledHidden(f.id)).length;

  bool _isAutoFilledHidden(String fieldId) {
    final rule = autoFillRules.where((r) => r.fieldId == fieldId).firstOrNull;
    return rule != null && !rule.editable;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'frequency': frequency.name,
        'category': category.name,
        'version': version,
        'fields': {for (var f in fields) f.id: f.toMap()},
        'autoFillRules': autoFillRules.map((r) => r.toMap()).toList(),
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'createdBy': createdBy,
        'subjectId': subjectId,
        if (allowedRoles != null) 'allowedRoles': allowedRoles,
      };

  factory FormTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse fields - support both Map and List formats
    List<FormFieldDefinition> fields = [];
    final rawFields = data['fields'];
    
    if (rawFields is Map<String, dynamic>) {
      // Format: { "field_id": { ... field data ... } }
      fields = rawFields.entries
          .map((e) => FormFieldDefinition.fromMap(e.key, e.value as Map<String, dynamic>))
          .toList();
    } else if (rawFields is List) {
      // Format: [ { "id": "field_id", ... } ]
      fields = rawFields.asMap().entries.map((entry) {
        final fieldData = entry.value as Map<String, dynamic>;
        final fieldId = fieldData['id'] as String? ?? 'field_${entry.key}';
        return FormFieldDefinition.fromMap(fieldId, fieldData);
      }).toList();
    }
    
    fields.sort((a, b) => a.order.compareTo(b.order));

    // Parse auto-fill rules
    final rulesData = data['autoFillRules'] as List<dynamic>? ?? [];
    final autoFillRules =
        rulesData.map((r) => AutoFillRule.fromMap(r as Map<String, dynamic>)).toList();

    return FormTemplate(
      id: doc.id,
      name: data['name'] as String? ?? 'Untitled',
      description: data['description'] as String?,
      frequency: FormFrequency.values.firstWhere(
        (e) => e.name == data['frequency'],
        orElse: () => FormFrequency.perSession,
      ),
      category: FormCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => FormCategory.other,
      ),
      version: data['version'] as int? ?? 1,
      fields: fields,
      autoFillRules: autoFillRules,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String?,
      subjectId: data['subjectId'] as String?,
      allowedRoles: (data['allowedRoles'] as List<dynamic>?)?.cast<String>(),
    );
  }

  FormTemplate copyWith({
    String? id,
    String? name,
    String? description,
    FormFrequency? frequency,
    FormCategory? category,
    int? version,
    List<FormFieldDefinition>? fields,
    List<AutoFillRule>? autoFillRules,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? subjectId,
    List<String>? allowedRoles,
  }) =>
      FormTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        frequency: frequency ?? this.frequency,
        category: category ?? this.category,
        version: version ?? this.version,
        fields: fields ?? this.fields,
        autoFillRules: autoFillRules ?? this.autoFillRules,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
        subjectId: subjectId ?? this.subjectId,
        allowedRoles: allowedRoles ?? this.allowedRoles,
      );
}

