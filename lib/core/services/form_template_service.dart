import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/form_template.dart';
import '../utils/app_logger.dart';

/// Service for managing form templates with versioning and frequency support
class FormTemplateService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _templatesCollection = 'form_templates';
  static const String _configCollection = 'settings';
  static const String _configDoc = 'form_config';

  // ============================================================
  // DEFAULT MINIMAL TEMPLATES
  // ============================================================

  /// Daily Class Report - filled after each session
  /// Maximum 5 required fields as per requirements
  static FormTemplate get defaultDailyClassReport => FormTemplate(
        id: 'daily_class_report',
        name: 'Daily Class Report',
        description: 'Quick report after each teaching session',
        frequency: FormFrequency.perSession,
        category: FormCategory.teaching,
        version: 1,
        allowedRoles: ['teacher'],
        fields: [
          // Field 1: Lesson Completed (Required)
          const FormFieldDefinition(
            id: 'lesson_completed',
            label: 'What lesson/topic did you cover today?',
            type: 'text',
            placeholder: 'e.g., Surah Al-Fatiha verses 1-3',
            required: true,
            order: 1,
          ),
          // Field 2: Student Attendance (Required)
          const FormFieldDefinition(
            id: 'students_present',
            label: 'How many students attended?',
            type: 'number',
            placeholder: 'Number of students present',
            required: true,
            order: 2,
            validation: {'min': 0, 'max': 100},
          ),
          // Field 3: Session Quality (Required)
          const FormFieldDefinition(
            id: 'session_quality',
            label: 'How did the session go?',
            type: 'radio',
            required: true,
            order: 3,
            options: ['Excellent', 'Good', 'Average', 'Challenging'],
          ),
          // Field 4: Issues/Concerns (Optional)
          const FormFieldDefinition(
            id: 'issues',
            label: 'Any issues or concerns?',
            type: 'long_text',
            placeholder: 'Leave empty if none',
            required: false,
            order: 4,
          ),
          // Field 5: Next Session Plan (Optional)
          const FormFieldDefinition(
            id: 'next_plan',
            label: 'Plan for next session',
            type: 'text',
            placeholder: 'What will you cover next?',
            required: false,
            order: 5,
          ),
        ],
        autoFillRules: [
          // These fields are auto-filled and hidden from the form
          AutoFillRule.fromEnum(
            fieldId: '_teacher_name',
            sourceField: AutoFillField.teacherName,
            editable: false,
          ),
          AutoFillRule.fromEnum(
            fieldId: '_session_date',
            sourceField: AutoFillField.sessionDate,
            editable: false,
          ),
          AutoFillRule.fromEnum(
            fieldId: '_class_name',
            sourceField: AutoFillField.className,
            editable: false,
          ),
          AutoFillRule.fromEnum(
            fieldId: '_actual_duration',
            sourceField: AutoFillField.actualDuration,
            editable: false,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// Weekly Summary - once per week
  /// Maximum 3 required fields
  static FormTemplate get defaultWeeklySummary => FormTemplate(
        id: 'weekly_summary',
        name: 'Weekly Summary',
        description: 'End of week teaching summary',
        frequency: FormFrequency.weekly,
        category: FormCategory.teaching,
        version: 1,
        allowedRoles: ['teacher'],
        fields: [
          // Field 1: Overall Progress (Required)
          const FormFieldDefinition(
            id: 'weekly_progress',
            label: 'How would you rate this week overall?',
            type: 'radio',
            required: true,
            order: 1,
            options: ['Excellent', 'Good', 'Needs Improvement'],
          ),
          // Field 2: Key Achievements (Required)
          const FormFieldDefinition(
            id: 'achievements',
            label: 'What were the key achievements this week?',
            type: 'long_text',
            placeholder: 'Summarize student progress, milestones reached, etc.',
            required: true,
            order: 2,
          ),
          // Field 3: Challenges (Optional)
          const FormFieldDefinition(
            id: 'challenges',
            label: 'Any challenges or support needed?',
            type: 'long_text',
            placeholder: 'Leave empty if none',
            required: false,
            order: 3,
          ),
        ],
        autoFillRules: [
          AutoFillRule.fromEnum(
            fieldId: '_teacher_name',
            sourceField: AutoFillField.teacherName,
            editable: false,
          ),
          AutoFillRule.fromEnum(
            fieldId: '_week_ending',
            sourceField: AutoFillField.weekEndingDate,
            editable: false,
          ),
          AutoFillRule.fromEnum(
            fieldId: '_week_shifts_count',
            sourceField: AutoFillField.weekShiftsCount,
            editable: false,
          ),
          AutoFillRule.fromEnum(
            fieldId: '_week_completed_classes',
            sourceField: AutoFillField.weekCompletedClasses,
            editable: false,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// Monthly Review - once per month
  /// Maximum 3 required fields
  static FormTemplate get defaultMonthlyReview => FormTemplate(
        id: 'monthly_review',
        name: 'Monthly Review',
        description: 'End of month teaching review',
        frequency: FormFrequency.monthly,
        category: FormCategory.teaching,
        version: 1,
        allowedRoles: ['teacher'],
        fields: [
          // Field 1: Month Rating (Required)
          const FormFieldDefinition(
            id: 'month_rating',
            label: 'How would you rate this month?',
            type: 'radio',
            required: true,
            order: 1,
            options: ['Excellent', 'Good', 'Average', 'Challenging'],
          ),
          // Field 2: Goals Met (Required)
          const FormFieldDefinition(
            id: 'goals_met',
            label: 'Were your teaching goals met?',
            type: 'radio',
            required: true,
            order: 2,
            options: [
              'Yes, all goals',
              'Most goals',
              'Some goals',
              'Few goals'
            ],
          ),
          // Field 3: Comments (Optional)
          const FormFieldDefinition(
            id: 'comments',
            label: 'Additional comments for admin',
            type: 'long_text',
            placeholder: 'Any feedback, requests, or concerns',
            required: false,
            order: 3,
          ),
        ],
        autoFillRules: [
          AutoFillRule.fromEnum(
            fieldId: '_teacher_name',
            sourceField: AutoFillField.teacherName,
            editable: false,
          ),
          AutoFillRule.fromEnum(
            fieldId: '_month',
            sourceField: AutoFillField.monthDate,
            editable: false,
          ),
          AutoFillRule.fromEnum(
            fieldId: '_month_total_classes',
            sourceField: AutoFillField.monthTotalClasses,
            editable: false,
          ),
          AutoFillRule.fromEnum(
            fieldId: '_month_completed',
            sourceField: AutoFillField.monthCompletedClasses,
            editable: false,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  // ============================================================
  // ON-DEMAND TEMPLATES (Feedback, Assessment, Administrative)
  // ============================================================

  /// Teacher Feedback & Complaints - available anytime
  static FormTemplate get defaultTeacherFeedback => FormTemplate(
        id: 'teacher_feedback',
        name: 'Teacher Feedback & Complaints',
        description:
            'Submit feedback, suggestions, or complaints to leadership',
        frequency: FormFrequency.onDemand,
        category: FormCategory.feedback,
        version: 1,
        allowedRoles: ['teacher', 'coach'],
        fields: const [
          FormFieldDefinition(
            id: 'feedback_type',
            label: 'Type of Feedback',
            type: 'radio',
            required: true,
            order: 1,
            options: ['Suggestion', 'Complaint', 'Praise', 'Question'],
          ),
          FormFieldDefinition(
            id: 'subject',
            label: 'Subject/Topic',
            type: 'text',
            placeholder: 'Brief topic of your feedback',
            required: true,
            order: 2,
          ),
          FormFieldDefinition(
            id: 'description',
            label: 'Detailed Description',
            type: 'long_text',
            placeholder: 'Please provide details about your feedback...',
            required: true,
            order: 3,
          ),
          FormFieldDefinition(
            id: 'urgency',
            label: 'How urgent is this?',
            type: 'radio',
            required: true,
            order: 4,
            options: ['Low', 'Medium', 'High', 'Critical'],
          ),
          FormFieldDefinition(
            id: 'anonymous',
            label: 'Submit anonymously?',
            type: 'radio',
            required: false,
            order: 5,
            options: ['No, include my name', 'Yes, keep anonymous'],
          ),
        ],
        autoFillRules: [
          AutoFillRule.fromEnum(
            fieldId: '_teacher_name',
            sourceField: AutoFillField.teacherName,
            editable: false,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// Leadership Feedback - feedback TO leaders FROM teachers
  static FormTemplate get defaultLeadershipFeedback => FormTemplate(
        id: 'leadership_feedback',
        name: 'Feedback for Leaders',
        description: 'Rate and provide feedback about your coach/supervisor',
        frequency: FormFrequency.onDemand,
        category: FormCategory.feedback,
        version: 1,
        allowedRoles: ['teacher'],
        fields: const [
          FormFieldDefinition(
            id: 'leader_rating',
            label: 'How would you rate your coach/leader overall?',
            type: 'radio',
            required: true,
            order: 1,
            options: [
              'Excellent',
              'Good',
              'Average',
              'Needs Improvement',
              'Poor'
            ],
          ),
          FormFieldDefinition(
            id: 'communication',
            label: 'How effective is their communication?',
            type: 'radio',
            required: true,
            order: 2,
            options: ['Excellent', 'Good', 'Average', 'Needs Improvement'],
          ),
          FormFieldDefinition(
            id: 'support_quality',
            label: 'How helpful is the support you receive?',
            type: 'radio',
            required: true,
            order: 3,
            options: ['Very Helpful', 'Somewhat Helpful', 'Not Helpful', 'N/A'],
          ),
          FormFieldDefinition(
            id: 'suggestions',
            label: 'Any suggestions for improvement?',
            type: 'long_text',
            placeholder: 'What could be done better?',
            required: false,
            order: 4,
          ),
        ],
        autoFillRules: [
          AutoFillRule.fromEnum(
            fieldId: '_teacher_name',
            sourceField: AutoFillField.teacherName,
            editable: false,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// Student Assessment - for evaluating student progress
  static FormTemplate get defaultStudentAssessment => FormTemplate(
        id: 'student_assessment',
        name: 'Student Assessment',
        description:
            'Evaluate student progress and skills at enrollment or semester end',
        frequency: FormFrequency.onDemand,
        category: FormCategory.studentAssessment,
        version: 1,
        allowedRoles: ['teacher', 'coach', 'admin'],
        fields: const [
          FormFieldDefinition(
            id: 'student_name',
            label: 'Student Name',
            type: 'text',
            placeholder: 'Enter student full name',
            required: true,
            order: 1,
          ),
          FormFieldDefinition(
            id: 'assessment_type',
            label: 'Assessment Type',
            type: 'radio',
            required: true,
            order: 2,
            options: [
              'Initial (New Student)',
              'Mid-Semester',
              'End of Semester'
            ],
          ),
          FormFieldDefinition(
            id: 'surahs_known',
            label: 'How many Surahs does this student know?',
            type: 'number',
            placeholder: 'Number of Surahs',
            required: true,
            order: 3,
            validation: {'min': 0, 'max': 114},
          ),
          FormFieldDefinition(
            id: 'reading_level',
            label: 'Arabic Reading Level',
            type: 'radio',
            required: true,
            order: 4,
            options: [
              'Not Started',
              'Beginner',
              'Intermediate',
              'Advanced',
              'Fluent'
            ],
          ),
          FormFieldDefinition(
            id: 'writing_level',
            label: 'Arabic Writing Level',
            type: 'radio',
            required: true,
            order: 5,
            options: [
              'Not Started',
              'Beginner',
              'Intermediate',
              'Advanced',
              'Fluent'
            ],
          ),
          FormFieldDefinition(
            id: 'overall_level',
            label: 'Overall Student Level',
            type: 'radio',
            required: true,
            order: 6,
            options: ['Beginner', 'Intermediate', 'Advanced'],
          ),
          FormFieldDefinition(
            id: 'hadiths_known',
            label: 'How many Hadiths does this student know?',
            type: 'number',
            placeholder: 'Number of Hadiths',
            required: false,
            order: 7,
            validation: {'min': 0},
          ),
          FormFieldDefinition(
            id: 'reading_rating',
            label: 'Rate reading skills (1-5)',
            type: 'radio',
            required: true,
            order: 8,
            options: [
              '1 - Very Poor',
              '2 - Poor',
              '3 - Average',
              '4 - Good',
              '5 - Excellent'
            ],
          ),
          FormFieldDefinition(
            id: 'writing_rating',
            label: 'Rate writing skills (1-5)',
            type: 'radio',
            required: true,
            order: 9,
            options: [
              '1 - Very Poor',
              '2 - Poor',
              '3 - Average',
              '4 - Good',
              '5 - Excellent'
            ],
          ),
          FormFieldDefinition(
            id: 'additional_notes',
            label: 'Additional Notes',
            type: 'long_text',
            placeholder: 'Any additional observations about the student...',
            required: false,
            order: 10,
          ),
        ],
        autoFillRules: [
          AutoFillRule.fromEnum(
            fieldId: '_teacher_name',
            sourceField: AutoFillField.teacherName,
            editable: false,
          ),
          AutoFillRule.fromEnum(
            fieldId: '_session_date',
            sourceField: AutoFillField.sessionDate,
            editable: false,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// Incident Report - for reporting issues
  static FormTemplate get defaultIncidentReport => FormTemplate(
        id: 'incident_report',
        name: 'Incident Report',
        description: 'Report an incident or issue that occurred',
        frequency: FormFrequency.onDemand,
        category: FormCategory.administrative,
        version: 1,
        allowedRoles: ['teacher', 'coach', 'admin'],
        fields: const [
          FormFieldDefinition(
            id: 'incident_date',
            label: 'Date of Incident',
            type: 'date',
            required: true,
            order: 1,
          ),
          FormFieldDefinition(
            id: 'incident_type',
            label: 'Type of Incident',
            type: 'radio',
            required: true,
            order: 2,
            options: [
              'Technical Issue',
              'Student Behavior',
              'Parent Concern',
              'Scheduling Conflict',
              'Other'
            ],
          ),
          FormFieldDefinition(
            id: 'description',
            label: 'Describe what happened',
            type: 'long_text',
            placeholder: 'Please provide a detailed description...',
            required: true,
            order: 3,
          ),
          FormFieldDefinition(
            id: 'people_involved',
            label: 'Who was involved?',
            type: 'text',
            placeholder: 'Names of people involved',
            required: false,
            order: 4,
          ),
          FormFieldDefinition(
            id: 'action_taken',
            label: 'What action did you take?',
            type: 'long_text',
            placeholder: 'Describe any immediate action taken...',
            required: false,
            order: 5,
          ),
          FormFieldDefinition(
            id: 'followup_needed',
            label: 'Is follow-up needed?',
            type: 'radio',
            required: true,
            order: 6,
            options: ['Yes - Urgent', 'Yes - Non-urgent', 'No'],
          ),
        ],
        autoFillRules: [
          AutoFillRule.fromEnum(
            fieldId: '_teacher_name',
            sourceField: AutoFillField.teacherName,
            editable: false,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// Leave Request Form - for requesting time off
  static FormTemplate get defaultLeaveRequest => FormTemplate(
        id: 'leave_request',
        name: 'Leave Request',
        description: 'Request time off or absence from scheduled shifts',
        frequency: FormFrequency.onDemand,
        category: FormCategory.administrative,
        version: 1,
        allowedRoles: ['teacher', 'coach'],
        fields: const [
          FormFieldDefinition(
            id: 'leave_type',
            label: 'Type of Leave',
            type: 'radio',
            required: true,
            order: 1,
            options: [
              'Sick Leave',
              'Personal Emergency',
              'Family Emergency',
              'Religious Holiday',
              'Pre-planned Absence',
              'Other'
            ],
          ),
          FormFieldDefinition(
            id: 'start_date',
            label: 'Start Date',
            type: 'date',
            required: true,
            order: 2,
          ),
          FormFieldDefinition(
            id: 'end_date',
            label: 'End Date',
            type: 'date',
            required: true,
            order: 3,
          ),
          FormFieldDefinition(
            id: 'affected_shifts',
            label: 'Number of shifts affected',
            type: 'number',
            placeholder: 'How many classes will be missed?',
            required: true,
            order: 4,
            validation: {'min': 1},
          ),
          FormFieldDefinition(
            id: 'reason',
            label: 'Reason for Leave',
            type: 'long_text',
            placeholder: 'Please explain the reason for your request...',
            required: true,
            order: 5,
          ),
          FormFieldDefinition(
            id: 'advance_notice',
            label: 'How much advance notice are you providing?',
            type: 'radio',
            required: true,
            order: 6,
            options: ['Same day', '1-2 days', '3-7 days', 'More than 1 week'],
          ),
          FormFieldDefinition(
            id: 'coverage_arranged',
            label: 'Have you arranged for coverage?',
            type: 'radio',
            required: true,
            order: 7,
            options: [
              'Yes - another teacher will cover',
              'No - need admin help',
              'Classes should be cancelled'
            ],
          ),
        ],
        autoFillRules: [
          AutoFillRule.fromEnum(
            fieldId: '_teacher_name',
            sourceField: AutoFillField.teacherName,
            editable: false,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  // ============================================================
  // ADMIN-SPECIFIC TEMPLATES
  // ============================================================

  /// Coach Performance Review - Admin evaluates coaches monthly
  static FormTemplate get defaultCoachPerformanceReview => FormTemplate(
        id: 'coach_performance_review',
        name: 'Coach Performance Review',
        description:
            'Monthly evaluation of coach/supervisor performance (Admin only)',
        frequency: FormFrequency.monthly,
        category: FormCategory.feedback,
        version: 1,
        allowedRoles: ['admin'],
        fields: const [
          FormFieldDefinition(
            id: 'coach_name',
            label: 'Coach Name',
            type: 'text',
            placeholder: 'Name of coach being reviewed',
            required: true,
            order: 1,
          ),
          FormFieldDefinition(
            id: 'teachers_managed',
            label: 'Number of Teachers Managed',
            type: 'number',
            required: true,
            order: 2,
            validation: {'min': 0},
          ),
          FormFieldDefinition(
            id: 'audits_completed',
            label: 'Audits Completed This Month',
            type: 'number',
            required: true,
            order: 3,
            validation: {'min': 0},
          ),
          FormFieldDefinition(
            id: 'audit_timeliness',
            label: 'Audit Timeliness',
            type: 'radio',
            required: true,
            order: 4,
            options: [
              'All on time',
              'Most on time (>80%)',
              'Some delays (<80%)',
              'Significant delays'
            ],
          ),
          FormFieldDefinition(
            id: 'teacher_support_quality',
            label: 'Quality of Teacher Support',
            type: 'radio',
            required: true,
            order: 5,
            options: ['Excellent', 'Good', 'Average', 'Needs Improvement'],
          ),
          FormFieldDefinition(
            id: 'response_time',
            label: 'Average Response Time to Issues',
            type: 'radio',
            required: true,
            order: 6,
            options: [
              'Same day',
              'Within 24 hours',
              '24-48 hours',
              'More than 48 hours'
            ],
          ),
          FormFieldDefinition(
            id: 'teacher_retention',
            label: 'Teacher Retention in Team',
            type: 'radio',
            required: true,
            order: 7,
            options: [
              'All retained',
              'Minor turnover (1-2)',
              'Moderate turnover (3+)',
              'High turnover'
            ],
          ),
          FormFieldDefinition(
            id: 'overall_rating',
            label: 'Overall Coach Rating (1-10)',
            type: 'radio',
            required: true,
            order: 8,
            options: [
              '10 - Outstanding',
              '9 - Excellent',
              '8 - Very Good',
              '7 - Good',
              '6 - Satisfactory',
              '5 - Average',
              '4 - Below Average',
              '3 - Poor',
              '2 - Very Poor',
              '1 - Unacceptable'
            ],
          ),
          FormFieldDefinition(
            id: 'strengths',
            label: 'Key Strengths',
            type: 'long_text',
            placeholder: 'What does this coach do well?',
            required: false,
            order: 9,
          ),
          FormFieldDefinition(
            id: 'areas_improvement',
            label: 'Areas for Improvement',
            type: 'long_text',
            placeholder: 'What should this coach work on?',
            required: false,
            order: 10,
          ),
          FormFieldDefinition(
            id: 'action_plan',
            label: 'Action Plan for Next Month',
            type: 'long_text',
            placeholder: 'Specific goals or actions...',
            required: false,
            order: 11,
          ),
        ],
        autoFillRules: const [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// Admin Self-Assessment - Admins evaluate their own performance
  static FormTemplate get defaultAdminSelfAssessment => FormTemplate(
        id: 'admin_self_assessment',
        name: 'Admin Self-Assessment',
        description: 'Monthly self-evaluation for administrators and coaches',
        frequency: FormFrequency.monthly,
        category: FormCategory.feedback,
        version: 1,
        allowedRoles: ['admin', 'coach'],
        fields: const [
          FormFieldDefinition(
            id: 'tasks_completed',
            label: 'Tasks Completed This Month',
            type: 'number',
            required: true,
            order: 1,
            validation: {'min': 0},
          ),
          FormFieldDefinition(
            id: 'tasks_overdue',
            label: 'Tasks Currently Overdue',
            type: 'number',
            required: true,
            order: 2,
            validation: {'min': 0},
          ),
          FormFieldDefinition(
            id: 'teachers_supported',
            label: 'Number of Teachers You Supported',
            type: 'number',
            required: true,
            order: 3,
            validation: {'min': 0},
          ),
          FormFieldDefinition(
            id: 'issues_resolved',
            label: 'Issues/Problems Resolved',
            type: 'number',
            required: true,
            order: 4,
            validation: {'min': 0},
          ),
          FormFieldDefinition(
            id: 'self_rating',
            label: 'Rate Your Performance This Month',
            type: 'radio',
            required: true,
            order: 5,
            options: ['Excellent', 'Good', 'Average', 'Below expectations'],
          ),
          FormFieldDefinition(
            id: 'biggest_achievement',
            label: 'Biggest Achievement This Month',
            type: 'long_text',
            placeholder: 'Describe your main accomplishment...',
            required: true,
            order: 6,
          ),
          FormFieldDefinition(
            id: 'biggest_challenge',
            label: 'Biggest Challenge Faced',
            type: 'long_text',
            placeholder: 'What was your main challenge?',
            required: false,
            order: 7,
          ),
          FormFieldDefinition(
            id: 'support_needed',
            label: 'Support Needed from Leadership',
            type: 'long_text',
            placeholder: 'What additional support would help you?',
            required: false,
            order: 8,
          ),
          FormFieldDefinition(
            id: 'goals_next_month',
            label: 'Goals for Next Month',
            type: 'long_text',
            placeholder: 'What do you plan to accomplish?',
            required: true,
            order: 9,
          ),
        ],
        autoFillRules: [
          AutoFillRule.fromEnum(
            fieldId: '_admin_name',
            sourceField: AutoFillField.teacherName,
            editable: false,
          ),
        ],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  /// Parent Feedback Form - For parents to evaluate teachers
  static FormTemplate get defaultParentFeedback => FormTemplate(
        id: 'parent_feedback',
        name: 'Parent/Guardian Feedback',
        description:
            'Collect feedback from parents about their child\'s teacher',
        frequency: FormFrequency.onDemand,
        category: FormCategory.studentAssessment,
        version: 1,
        allowedRoles: ['admin', 'parent'],
        fields: const [
          FormFieldDefinition(
            id: 'teacher_name',
            label: 'Teacher Name',
            type: 'text',
            required: true,
            order: 1,
          ),
          FormFieldDefinition(
            id: 'child_name',
            label: 'Child\'s Name',
            type: 'text',
            required: true,
            order: 2,
          ),
          FormFieldDefinition(
            id: 'overall_satisfaction',
            label: 'Overall Satisfaction with Teacher',
            type: 'radio',
            required: true,
            order: 3,
            options: [
              'Very Satisfied',
              'Satisfied',
              'Neutral',
              'Dissatisfied',
              'Very Dissatisfied'
            ],
          ),
          FormFieldDefinition(
            id: 'communication_quality',
            label: 'Quality of Communication',
            type: 'radio',
            required: true,
            order: 4,
            options: ['Excellent', 'Good', 'Average', 'Poor'],
          ),
          FormFieldDefinition(
            id: 'child_progress',
            label: 'Is your child making progress?',
            type: 'radio',
            required: true,
            order: 5,
            options: [
              'Significant progress',
              'Some progress',
              'Little progress',
              'No progress'
            ],
          ),
          FormFieldDefinition(
            id: 'punctuality',
            label: 'Teacher Punctuality',
            type: 'radio',
            required: true,
            order: 6,
            options: [
              'Always on time',
              'Usually on time',
              'Sometimes late',
              'Often late'
            ],
          ),
          FormFieldDefinition(
            id: 'recommendation',
            label: 'Would you recommend this teacher?',
            type: 'radio',
            required: true,
            order: 7,
            options: [
              'Definitely yes',
              'Probably yes',
              'Not sure',
              'Probably no',
              'Definitely no'
            ],
          ),
          FormFieldDefinition(
            id: 'comments',
            label: 'Additional Comments',
            type: 'long_text',
            placeholder: 'Any other feedback or suggestions...',
            required: false,
            order: 8,
          ),
        ],
        autoFillRules: const [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  // ============================================================
  // TEMPLATE MANAGEMENT
  // ============================================================

  /// Get all form templates
  /// [forceRefresh] - If true, forces reload from server, bypassing cache
  static Future<List<FormTemplate>> getAllTemplates(
      {bool forceRefresh = false}) async {
    try {
      final getOptions = forceRefresh
          ? const GetOptions(source: Source.server)
          : const GetOptions(source: Source.cache);

      // Try to order by updatedAt first (most recently updated), fallback to createdAt
      try {
        final snapshot = await _firestore
            .collection(_templatesCollection)
            .orderBy('updatedAt', descending: true)
            .get(getOptions);

        final templates = snapshot.docs
            .map((doc) => FormTemplate.fromFirestore(doc))
            .toList();

        AppLogger.debug(
            'FormTemplateService: getAllTemplates loaded ${templates.length} templates');
        // Also sort by version as secondary sort to ensure latest version is first
        templates.sort((a, b) {
          // First by updatedAt (most recent first)
          final dateCompare = b.updatedAt.compareTo(a.updatedAt);
          if (dateCompare != 0) return dateCompare;
          // Then by version (highest first)
          return b.version.compareTo(a.version);
        });
        return templates;
      } catch (e) {
        // If updatedAt index doesn't exist, fallback to createdAt
        AppLogger.debug(
            'FormTemplateService: updatedAt index not available, using createdAt: $e');
        final snapshot = await _firestore
            .collection(_templatesCollection)
            .orderBy('createdAt', descending: true)
            .get(getOptions);

        final templates = snapshot.docs
            .map((doc) => FormTemplate.fromFirestore(doc))
            .toList();
        // Sort by version as secondary sort
        templates.sort((a, b) {
          // First by createdAt (most recent first)
          final dateCompare = b.createdAt.compareTo(a.createdAt);
          if (dateCompare != 0) return dateCompare;
          // Then by version (highest first)
          return b.version.compareTo(a.version);
        });
        return templates;
      }
    } catch (e) {
      AppLogger.error('FormTemplateService: Error fetching templates: $e');
      // If cache fails, try server
      if (!forceRefresh) {
        try {
          final snapshot = await _firestore
              .collection(_templatesCollection)
              .orderBy('createdAt', descending: true)
              .get(const GetOptions(source: Source.server));
          return snapshot.docs
              .map((doc) => FormTemplate.fromFirestore(doc))
              .toList();
        } catch (e2) {
          AppLogger.error(
              'FormTemplateService: Error fetching from server: $e2');
          return [];
        }
      }
      return [];
    }
  }

  /// Get active templates by frequency
  /// [forceRefresh] - If true, forces reload from server, bypassing cache
  static Future<List<FormTemplate>> getTemplatesByFrequency(
      FormFrequency frequency,
      {bool forceRefresh = false}) async {
    try {
      final getOptions = forceRefresh
          ? const GetOptions(source: Source.server)
          : const GetOptions(source: Source.cache);

      final snapshot = await _firestore
          .collection(_templatesCollection)
          .where('frequency', isEqualTo: frequency.name)
          .where('isActive', isEqualTo: true)
          .get(getOptions);

      return snapshot.docs
          .map((doc) => FormTemplate.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.error(
          'FormTemplateService: Error fetching templates by frequency: $e');
      // If cache fails, try server
      if (!forceRefresh) {
        try {
          final snapshot = await _firestore
              .collection(_templatesCollection)
              .where('frequency', isEqualTo: frequency.name)
              .where('isActive', isEqualTo: true)
              .get(const GetOptions(source: Source.server));
          return snapshot.docs
              .map((doc) => FormTemplate.fromFirestore(doc))
              .toList();
        } catch (e2) {
          AppLogger.error(
              'FormTemplateService: Error fetching from server: $e2');
          return [];
        }
      }
      return [];
    }
  }

  /// Get template by ID
  /// [forceRefresh] - If true, forces reload from server, bypassing cache
  static Future<FormTemplate?> getTemplate(String templateId,
      {bool forceRefresh = true}) async {
    try {
      // Always use server source to ensure latest version
      final getOptions = forceRefresh
          ? const GetOptions(source: Source.server)
          : const GetOptions(source: Source.serverAndCache);

      final doc = await _firestore
          .collection(_templatesCollection)
          .doc(templateId)
          .get(getOptions);

      if (doc.exists) {
        return FormTemplate.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      AppLogger.error('FormTemplateService: Error fetching template: $e');
      return null;
    }
  }

  static String _normalizeTemplateName(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _isNewerTemplate(FormTemplate candidate, FormTemplate current) {
    if (candidate.version != current.version) {
      return candidate.version > current.version;
    }
    return candidate.updatedAt.isAfter(current.updatedAt);
  }

  static List<FormTemplate> _latestActiveTemplatesByName(
      List<FormTemplate> templates) {
    final Map<String, FormTemplate> latestByName = {};
    for (final template in templates) {
      if (!template.isActive) continue;
      final normalizedName = _normalizeTemplateName(template.name);
      final existing = latestByName[normalizedName];
      if (existing == null || _isNewerTemplate(template, existing)) {
        latestByName[normalizedName] = template;
      }
    }
    return latestByName.values.toList();
  }

  /// Get the currently active daily class report template
  /// [forceRefresh] - If true, forces reload from server, bypassing cache
  static Future<FormTemplate?> getActiveDailyTemplate(
      {bool forceRefresh = true}) async {
    try {
      // Always use server source to ensure latest version
      final getOptions = forceRefresh
          ? const GetOptions(source: Source.server)
          : const GetOptions(source: Source.serverAndCache);

      // Load active daily candidates first and compute latest by name.
      // This keeps auto-popup aligned with manual form selection logic.
      final allTemplates = await getTemplatesByFrequency(
        FormFrequency.perSession,
        forceRefresh: forceRefresh,
      );

      AppLogger.debug(
          'FormTemplateService: getActiveDailyTemplate - Found ${allTemplates.length} perSession templates');

      final templates = _latestActiveTemplatesByName(allTemplates);
      AppLogger.debug(
          'FormTemplateService: After deduplication, ${templates.length} unique perSession templates');

      templates.sort((a, b) {
        final versionCompare = b.version.compareTo(a.version);
        if (versionCompare != 0) return versionCompare;
        return b.updatedAt.compareTo(a.updatedAt);
      });

      FormTemplate? latestDailyReport;
      if (templates.isNotEmpty) {
        latestDailyReport = templates.firstWhere(
          (t) =>
              t.name.toLowerCase().contains('daily') &&
              (t.name.toLowerCase().contains('class') ||
                  t.name.toLowerCase().contains('report')),
          orElse: () => templates.first,
        );
      }

      // Respect explicit config when it's valid, except when it points to an older
      // version of the same template name.
      final configDoc = await _firestore
          .collection(_configCollection)
          .doc(_configDoc)
          .get(getOptions);

      if (configDoc.exists) {
        final dailyTemplateId = configDoc.data()?['dailyTemplateId'] as String?;
        if (dailyTemplateId != null && dailyTemplateId.isNotEmpty) {
          final configuredTemplate =
              await getTemplate(dailyTemplateId, forceRefresh: forceRefresh);
          if (configuredTemplate != null &&
              configuredTemplate.isActive &&
              configuredTemplate.frequency == FormFrequency.perSession) {
            if (latestDailyReport != null &&
                _normalizeTemplateName(configuredTemplate.name) ==
                    _normalizeTemplateName(latestDailyReport.name) &&
                _isNewerTemplate(latestDailyReport, configuredTemplate)) {
              AppLogger.warning(
                'FormTemplateService: dailyTemplateId=$dailyTemplateId is older than '
                'latest "${latestDailyReport.name}" (cfg v${configuredTemplate.version} '
                'vs latest v${latestDailyReport.version}); using latest ID=${latestDailyReport.id}',
              );
              return latestDailyReport;
            }
            return configuredTemplate;
          }

          if (configuredTemplate != null) {
            AppLogger.warning(
              'FormTemplateService: Ignoring stale dailyTemplateId=$dailyTemplateId '
              '(isActive=${configuredTemplate.isActive}, frequency=${configuredTemplate.frequency.name})',
            );
          }
        }
      }

      if (latestDailyReport != null) {
        AppLogger.debug(
          'FormTemplateService: Selected daily template fallback: '
          '${latestDailyReport.name} (Version: ${latestDailyReport.version}, ID: ${latestDailyReport.id})',
        );
        return latestDailyReport;
      }

      // No template available in Firestore.
      return null;
    } catch (e) {
      AppLogger.error(
          'FormTemplateService: Error getting active daily template: $e');
      return null;
    }
  }

  /// Get the currently active weekly template
  /// [forceRefresh] - If true, forces reload from server, bypassing cache
  static Future<FormTemplate?> getActiveWeeklyTemplate(
      {bool forceRefresh = true}) async {
    try {
      // Always use server source to ensure latest version
      final getOptions = forceRefresh
          ? const GetOptions(source: Source.server)
          : const GetOptions(source: Source.serverAndCache);

      // First check config for specified template
      final configDoc = await _firestore
          .collection(_configCollection)
          .doc(_configDoc)
          .get(getOptions);

      if (configDoc.exists) {
        final weeklyTemplateId =
            configDoc.data()?['weeklyTemplateId'] as String?;
        if (weeklyTemplateId != null) {
          final template =
              await getTemplate(weeklyTemplateId, forceRefresh: forceRefresh);
          if (template != null &&
              template.isActive &&
              template.frequency == FormFrequency.weekly) {
            return template;
          }
          if (template != null) {
            AppLogger.warning(
              'FormTemplateService: Ignoring stale weeklyTemplateId=$weeklyTemplateId '
              '(isActive=${template.isActive}, frequency=${template.frequency.name})',
            );
          }
        }
      }

      // Fallback: get any active weekly template (force refresh to get latest)
      final allTemplates = await getTemplatesByFrequency(
        FormFrequency.weekly,
        forceRefresh: forceRefresh,
      );

      if (allTemplates.isNotEmpty) {
        // Filter to keep only latest version of each template by normalized name
        final Map<String, FormTemplate> latestTemplatesByName = {};
        for (var template in allTemplates) {
          if (!template.isActive) continue;

          // Normalize template name for comparison
          final normalizedName = template.name
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ');

          if (!latestTemplatesByName.containsKey(normalizedName)) {
            latestTemplatesByName[normalizedName] = template;
          } else {
            final existing = latestTemplatesByName[normalizedName]!;
            // Keep the one with higher version, or if same version, keep the one with later updatedAt
            if (template.version > existing.version) {
              latestTemplatesByName[normalizedName] = template;
            } else if (template.version == existing.version) {
              if (template.updatedAt.isAfter(existing.updatedAt)) {
                latestTemplatesByName[normalizedName] = template;
              }
            }
          }
        }

        final templates = latestTemplatesByName.values.toList();

        // Sort by version (highest first) and updatedAt (most recent first) to get latest
        templates.sort((a, b) {
          final versionCompare = b.version.compareTo(a.version);
          if (versionCompare != 0) return versionCompare;
          return b.updatedAt.compareTo(a.updatedAt);
        });

        // Prefer "Weekly Summary" if it exists (after deduplication, this will be the latest version)
        // Otherwise, use the first template (highest version overall)
        final weeklyReport = templates.firstWhere(
          (t) {
            final nameLower = t.name.toLowerCase();
            return nameLower.contains('weekly summary') ||
                (nameLower.contains('weekly') && nameLower.contains('summary'));
          },
          orElse: () =>
              templates.first, // Returns the template with highest version
        );

        AppLogger.debug(
            'FormTemplateService: Selected weekly template: ${weeklyReport.name} (Version: ${weeklyReport.version}, ID: ${weeklyReport.id})');
        AppLogger.debug(
            'FormTemplateService: Available weekly templates after dedup: ${templates.map((t) => '${t.name} v${t.version}').join(", ")}');

        return weeklyReport;
      }

      // Last resort: return default
      return defaultWeeklySummary;
    } catch (e) {
      AppLogger.error(
          'FormTemplateService: Error getting active weekly template: $e');
      return defaultWeeklySummary;
    }
  }

  /// Get the currently active monthly template
  /// [forceRefresh] - If true, forces reload from server, bypassing cache
  static Future<FormTemplate?> getActiveMonthlyTemplate(
      {bool forceRefresh = true}) async {
    try {
      // Always use server source to ensure latest version
      final getOptions = forceRefresh
          ? const GetOptions(source: Source.server)
          : const GetOptions(source: Source.serverAndCache);

      // First check config for specified template
      final configDoc = await _firestore
          .collection(_configCollection)
          .doc(_configDoc)
          .get(getOptions);

      if (configDoc.exists) {
        final monthlyTemplateId =
            configDoc.data()?['monthlyTemplateId'] as String?;
        if (monthlyTemplateId != null) {
          final template =
              await getTemplate(monthlyTemplateId, forceRefresh: forceRefresh);
          if (template != null &&
              template.isActive &&
              template.frequency == FormFrequency.monthly) {
            return template;
          }
          if (template != null) {
            AppLogger.warning(
              'FormTemplateService: Ignoring stale monthlyTemplateId=$monthlyTemplateId '
              '(isActive=${template.isActive}, frequency=${template.frequency.name})',
            );
          }
        }
      }

      // Fallback: get any active monthly template (force refresh to get latest)
      final allTemplates = await getTemplatesByFrequency(
        FormFrequency.monthly,
        forceRefresh: forceRefresh,
      );

      if (allTemplates.isNotEmpty) {
        // Filter to keep only latest version of each template by normalized name
        final Map<String, FormTemplate> latestTemplatesByName = {};
        for (var template in allTemplates) {
          if (!template.isActive) continue;

          // Normalize template name for comparison
          final normalizedName = template.name
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ');

          if (!latestTemplatesByName.containsKey(normalizedName)) {
            latestTemplatesByName[normalizedName] = template;
          } else {
            final existing = latestTemplatesByName[normalizedName]!;
            // Keep the one with higher version, or if same version, keep the one with later updatedAt
            if (template.version > existing.version) {
              latestTemplatesByName[normalizedName] = template;
            } else if (template.version == existing.version) {
              if (template.updatedAt.isAfter(existing.updatedAt)) {
                latestTemplatesByName[normalizedName] = template;
              }
            }
          }
        }

        final templates = latestTemplatesByName.values.toList();

        // Sort by version (highest first) and updatedAt (most recent first) to get latest
        templates.sort((a, b) {
          final versionCompare = b.version.compareTo(a.version);
          if (versionCompare != 0) return versionCompare;
          return b.updatedAt.compareTo(a.updatedAt);
        });

        // After deduplication and sorting, the first template is the latest version
        // This ensures we always get the highest version number
        final monthlyReport = templates.first;

        AppLogger.debug(
            'FormTemplateService: Selected monthly template: ${monthlyReport.name} (Version: ${monthlyReport.version}, ID: ${monthlyReport.id})');
        AppLogger.debug(
            'FormTemplateService: Available monthly templates: ${templates.map((t) => '${t.name} v${t.version}').join(", ")}');

        return monthlyReport;
      }

      // Last resort: return default
      return defaultMonthlyReview;
    } catch (e) {
      AppLogger.error(
          'FormTemplateService: Error getting active monthly template: $e');
      return defaultMonthlyReview;
    }
  }

  /// Create or update a template
  static Future<String> saveTemplate(FormTemplate template) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final data = template.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();

      if (template.id.isEmpty || template.id.startsWith('default_')) {
        // Create new template
        data['createdAt'] = FieldValue.serverTimestamp();
        data['createdBy'] = user?.uid;
        final docRef =
            await _firestore.collection(_templatesCollection).add(data);
        AppLogger.info('FormTemplateService: Created template ${docRef.id}');
        AppLogger.debug(
            'FormTemplateService: Created NEW template - name: ${template.name}, id: ${docRef.id}');
        return docRef.id;
      } else {
        // Update existing template (increment version)
        data['version'] = FieldValue.increment(1);
        await _firestore.collection(_templatesCollection).doc(template.id).set(
              data,
              SetOptions(merge: true),
            );
        AppLogger.info('FormTemplateService: Updated template ${template.id}');
        AppLogger.debug(
            'FormTemplateService: UPDATED existing template - name: ${template.name}, id: ${template.id}');
        return template.id;
      }
    } catch (e) {
      AppLogger.error('FormTemplateService: Error saving template: $e');
      rethrow;
    }
  }

  /// Save a template with explicit versioning logic
  /// - Finds all existing templates with the same name
  /// - Deactivates them (isActive = false)
  /// - Creates a NEW document for the new version with incremented version number
  /// - Ensures only this new version is active
  static Future<String> saveTemplateWithVersioning(
      FormTemplate template) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Find all existing templates with the same name (case-insensitive)
      // We read ALL templates because we need to check names and find max version
      // This might be expensive if there are thousands, but for form templates it's fine
      final snapshot = await _firestore.collection(_templatesCollection).get();

      final normalizedName = template.name.trim().toLowerCase();
      int maxVersion = 0;
      final batch = _firestore.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docName = (data['name'] as String? ?? '').trim().toLowerCase();

        if (docName == normalizedName) {
          // Track max version
          final version = data['version'] as int? ?? 0;
          if (version > maxVersion) maxVersion = version;

          // Deactivate if currently active
          if (data['isActive'] == true) {
            batch.update(doc.reference, {'isActive': false});
          }
        }
      }

      // 2. Create new template as a NEW document
      final newVersion = maxVersion + 1;

      final newTemplateData = template.toMap();
      newTemplateData['version'] = newVersion;
      newTemplateData['isActive'] = true;
      newTemplateData['createdAt'] = FieldValue.serverTimestamp();
      newTemplateData['updatedAt'] = FieldValue.serverTimestamp();
      newTemplateData['createdBy'] = user?.uid;

      // Ensure we don't reuse an old ID if one was passed by mistake
      // We want a fresh document ID for the new version
      newTemplateData.remove('id');

      final newDocRef = _firestore.collection(_templatesCollection).doc();
      batch.set(newDocRef, newTemplateData);

      // Keep active template config in sync when creating a new version.
      final configField = switch (template.frequency) {
        FormFrequency.perSession => 'dailyTemplateId',
        FormFrequency.weekly => 'weeklyTemplateId',
        FormFrequency.monthly => 'monthlyTemplateId',
        FormFrequency.onDemand => null,
      };
      if (configField != null) {
        batch.set(
          _firestore.collection(_configCollection).doc(_configDoc),
          {
            configField: newDocRef.id,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      AppLogger.info(
          'FormTemplateService: Saved new version ($newVersion) of "${template.name}" and deactivated others.');

      AppLogger.debug(
          'FormTemplateService: Versioning Save - Name: ${template.name}, New Version: $newVersion, New ID: ${newDocRef.id}');

      return newDocRef.id;
    } catch (e) {
      AppLogger.error(
          'FormTemplateService: Error saving template with versioning: $e');
      rethrow;
    }
  }

  /// Set the active template for a frequency type
  static Future<void> setActiveTemplate(
      FormFrequency frequency, String templateId) async {
    try {
      final fieldName = switch (frequency) {
        FormFrequency.perSession => 'dailyTemplateId',
        FormFrequency.weekly => 'weeklyTemplateId',
        FormFrequency.monthly => 'monthlyTemplateId',
        FormFrequency.onDemand =>
          null, // On-demand forms don't have active template config
      };

      // On-demand forms don't need active template configuration
      if (fieldName == null) {
        AppLogger.info(
            'FormTemplateService: On-demand forms do not require active template configuration');
        return;
      }

      await _firestore.collection(_configCollection).doc(_configDoc).set(
        {fieldName: templateId, 'lastUpdated': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      AppLogger.info('FormTemplateService: Set $fieldName to $templateId');
    } catch (e) {
      AppLogger.error('FormTemplateService: Error setting active template: $e');
      rethrow;
    }
  }

  /// Initialize default templates if they don't exist
  static Future<void> ensureDefaultTemplatesExist() async {
    try {
      final existing = await getAllTemplates();
      if (existing.isEmpty) {
        AppLogger.info('FormTemplateService: Creating default templates...');

        // Create default templates
        final dailyId = await saveTemplate(defaultDailyClassReport);
        await saveTemplate(defaultWeeklySummary);
        await saveTemplate(defaultMonthlyReview);

        // Set daily as active
        await setActiveTemplate(FormFrequency.perSession, dailyId);

        AppLogger.info('FormTemplateService: Default templates created');
      }
    } catch (e) {
      AppLogger.error('FormTemplateService: Error ensuring defaults: $e');
    }
  }

  /// Deactivate a template (soft delete)
  static Future<void> deactivateTemplate(String templateId) async {
    try {
      await _firestore.collection(_templatesCollection).doc(templateId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('FormTemplateService: Deactivated template $templateId');
    } catch (e) {
      AppLogger.error('FormTemplateService: Error deactivating template: $e');
      rethrow;
    }
  }

  // ============================================================
  // AUTO-FILL UTILITIES
  // ============================================================

  /// Apply auto-fill rules to a form submission context
  /// Supports all Firestore template sourceField values (string-based)
  static Map<String, dynamic> applyAutoFill({
    required List<AutoFillRule> rules,
    required String teacherName,
    required String teacherEmail,
    String? className,
    DateTime? sessionDate,
    Duration? actualDuration,
    Duration? scheduledDuration,
    String? subject,
    // Extended fields for new templates
    String? shiftId,
    String? shiftSubject,
    List<String>? shiftStudentNames,
    String? shiftDuration,
    String? shiftClassType,
    String? clockInTime,
    String? clockOutTime,
    DateTime? weekEndingDate,
    int? weekShiftsCount,
    int? weekCompletedClasses,
    DateTime? monthDate,
    int? monthTotalClasses,
    int? monthCompletedClasses,
  }) {
    final autoFilledValues = <String, dynamic>{};

    for (final rule in rules) {
      final sourceField = rule.sourceFieldString;
      dynamic value;

      // Map sourceField string to actual value
      switch (sourceField) {
        // Basic fields
        case 'teacherName':
          value = teacherName;
          break;
        case 'teacherEmail':
          value = teacherEmail;
          break;
        case 'className':
          value = className;
          break;
        case 'sessionDate':
          value = sessionDate?.toIso8601String();
          break;
        case 'sessionTime':
          value = sessionDate != null
              ? '${sessionDate.hour}:${sessionDate.minute.toString().padLeft(2, '0')}'
              : null;
          break;
        case 'actualDuration':
          value = actualDuration != null
              ? '${actualDuration.inHours}h ${actualDuration.inMinutes % 60}m'
              : null;
          break;
        case 'scheduledDuration':
          value = scheduledDuration != null
              ? '${scheduledDuration.inHours}h ${scheduledDuration.inMinutes % 60}m'
              : null;
          break;
        case 'subject':
          value = subject;
          break;

        // Shift-related fields (for Daily Class Report)
        case 'shiftId':
          value = shiftId;
          break;
        case 'shift.subjectDisplayName':
          value = shiftSubject;
          break;
        case 'shift.studentNames':
          value = shiftStudentNames?.join(', ');
          break;
        case 'shift.duration':
          value = shiftDuration;
          break;
        case 'shift.classType':
          value = shiftClassType;
          break;
        case 'shift.clockInTime':
          value = clockInTime;
          break;
        case 'shift.clockOutTime':
          value = clockOutTime;
          break;

        // Weekly Summary fields
        case 'weekEndingDate':
          value = weekEndingDate?.toIso8601String();
          break;
        case 'weekShiftsCount':
          value = weekShiftsCount?.toString();
          break;
        case 'weekCompletedClasses':
          value = weekCompletedClasses?.toString();
          break;

        // Monthly Review fields
        case 'monthDate':
          value = monthDate != null
              ? '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}'
              : null;
          break;
        case 'monthTotalClasses':
          value = monthTotalClasses?.toString();
          break;
        case 'monthCompletedClasses':
          value = monthCompletedClasses?.toString();
          break;

        default:
          // Unknown field - try to use as is
          AppLogger.debug(
              'FormTemplateService: Unknown sourceField: $sourceField');
          value = null;
      }

      if (value != null) {
        autoFilledValues[rule.fieldId] = value;
      }
    }

    return autoFilledValues;
  }
}
