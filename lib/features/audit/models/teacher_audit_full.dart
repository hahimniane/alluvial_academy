import 'package:cloud_firestore/cloud_firestore.dart';

/// Single audit factor (one of 16 mandatory factors from Excel model)
class AuditFactor {
  final String id;
  final String title;
  final String description; // From 'Key.csv'

  // Mutable fields for the audit
  String outcome;
  int rating; // 0-5 (0=Critical … 5=Excellent). Use [isNotApplicable] for true N/A (excluded from score).
  String paycutRecommendation;
  String coachActionPlan;
  String mentorReview;
  String ceoReview;

  /// When true, factor is excluded from coach score denominator (distinct from rating 0 = Critical).
  bool isNotApplicable;

  AuditFactor({
    required this.id,
    required this.title,
    required this.description,
    this.outcome = '',
    this.rating = 5,
    this.paycutRecommendation = '',
    this.coachActionPlan = '',
    this.mentorReview = '',
    this.ceoReview = '',
    this.isNotApplicable = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'outcome': outcome,
        'rating': rating,
        'paycutRecommendation': paycutRecommendation,
        'coachActionPlan': coachActionPlan,
        'mentorReview': mentorReview,
        'ceoReview': ceoReview,
        'isNotApplicable': isNotApplicable,
      };

  /// Convert legacy 1-9 ratings to 0-5 scale on read
  static int _migrateRating(int raw) {
    if (raw > 5) return (raw * 5 / 9).round().clamp(0, 5);
    return raw.clamp(0, 5);
  }

  factory AuditFactor.fromMap(Map<String, dynamic> map) {
    return AuditFactor(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      outcome: map['outcome'] ?? '',
      rating: _migrateRating(map['rating']?.toInt() ?? 5),
      paycutRecommendation: map['paycutRecommendation'] ?? '',
      coachActionPlan: map['coachActionPlan'] ?? '',
      mentorReview: map['mentorReview'] ?? '',
      ceoReview: map['ceoReview'] ?? '',
      isNotApplicable: map['isNotApplicable'] == true,
    );
  }

  AuditFactor copyWith({
    String? outcome,
    int? rating,
    String? paycutRecommendation,
    String? coachActionPlan,
    String? mentorReview,
    String? ceoReview,
    bool? isNotApplicable,
  }) {
    return AuditFactor(
      id: id,
      title: title,
      description: description,
      outcome: outcome ?? this.outcome,
      rating: rating ?? this.rating,
      paycutRecommendation: paycutRecommendation ?? this.paycutRecommendation,
      coachActionPlan: coachActionPlan ?? this.coachActionPlan,
      mentorReview: mentorReview ?? this.mentorReview,
      ceoReview: ceoReview ?? this.ceoReview,
      isNotApplicable: isNotApplicable ?? this.isNotApplicable,
    );
  }
}

/// Complete teacher audit model based on the legacy Google Sheets system
/// Includes automatic metrics + coach evaluation + admin review
class TeacherAuditFull {
  final String id; // {userId}_{yearMonth}
  final String oderId;
  final String teacherEmail;
  final String teacherName;
  final String yearMonth;

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 1: AUTOMATIC METRICS (calculated from system data)
  // ════════════════════════════════════════════════════════════════════════

  // Hours taught by subject
  final Map<String, double>
      hoursTaughtBySubject; // {"Quran": 10.5, "Arabic": 5.0}
  final double
      totalHoursTaught; // Total scheduled hours (legacy - kept for compatibility)

  // New detailed hours metrics
  final double totalScheduledHours; // Total hours programmed/scheduled
  final double
      totalWorkedHours; // Total hours actually worked (from workedMinutes in shifts)
  final double
      totalFormHours; // Total hours reported in readiness forms (from duration field)

  // Schedule metrics
  final int totalClassesScheduled;
  final int totalClassesCompleted;
  final int totalClassesMissed;
  final int totalClassesCancelled;
  final int excusedAbsences; // Shifts covered by approved leave requests
  final double completionRate;

  // Punctuality
  final int totalClockIns;
  final int onTimeClockIns;
  final int lateClockIns;
  final double avgLatencyMinutes;
  final double punctualityRate;

  // Forms
  final int readinessFormsRequired;
  final int readinessFormsSubmitted;
  final double formComplianceRate;

  // Meetings
  final int staffMeetingsScheduled;
  final int staffMeetingsMissed;
  final int meetingLateArrivals;

  // Academic
  final int quizzesGiven;
  final int assignmentsGiven;
  final bool midtermCompleted;
  final bool finalExamCompleted;
  final String
      semesterProjectStatus; // "Not started", "In progress", "Completed"

  // Tasks
  final int overdueTasks;
  final int totalTasksAssigned;
  final int acknowledgedTasks;
  final int weeklyRecordingsSent;

  // Connecteam/System metrics
  final int connecteamSignIns;
  final int classRemindersSet;
  final int internetDropOffs;

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 2: COACH EVALUATION (filled by coach/admin)
  // ════════════════════════════════════════════════════════════════════════

  /// Legacy coach evaluation (kept for backward compatibility)
  final CoachEvaluation? coachEvaluation;

  /// New 16-factor audit model (matches Excel structure)
  final List<AuditFactor> auditFactors;

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 3: PAYMENT CALCULATION
  // ════════════════════════════════════════════════════════════════════════

  final PaymentSummary? paymentSummary;

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 4: REVIEW WORKFLOW
  // ════════════════════════════════════════════════════════════════════════

  final AuditStatus status;
  final ReviewChain? reviewChain;

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 5: FLAGS AND ISSUES
  // ════════════════════════════════════════════════════════════════════════

  final List<AuditIssue> issues;

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 5.1: CHANGE LOG (append-only edit history)
  // ════════════════════════════════════════════════════════════════════════

  final List<AuditChangeEntry> changeLog;

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 5.5: DETAILED DATA (from script)
  // ════════════════════════════════════════════════════════════════════════

  final List<Map<String, dynamic>> detailedShifts; // Full shift details
  final List<Map<String, dynamic>> detailedTimesheets; // Full timesheet details
  final List<Map<String, dynamic>> detailedForms; // Full form responses
  /// Non-teaching forms (assignments/quizzes/assessments/etc.) for separate UI tabs.
  final List<Map<String, dynamic>> detailedFormsNonTeaching;

  /// Forms submitted in the month with no schedule associated (auditor sees same total as All Submissions).
  final List<Map<String, dynamic>> detailedFormsNoSchedule;

  /// Forms rejected as duplicates (second+ per shift). Each map includes 'rejectionReason': 'duplicate'.
  final List<Map<String, dynamic>> detailedFormsRejected;

  /// Admin accepts forms that failed auto rules; ids are `form_responses` doc ids.
  final List<AdminFormAcceptanceOverride> adminFormAcceptanceOverrides;

  /// When the teacher confirmed they read the payslip view for this month.
  final DateTime? teacherAcknowledgedAt;

  /// Optional 1:1 chat between coach/admin and teacher for this audit (Firestore `chats` doc id).
  final String? discussionChatId;

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 6: OVERALL SCORE
  // ════════════════════════════════════════════════════════════════════════

  final double automaticScore; // From system data (0-100)
  final double coachScore; // From coach evaluation (0-100)
  final double overallScore; // Weighted combination
  final String performanceTier;

  // Metadata
  final DateTime lastUpdated;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const TeacherAuditFull({
    required this.id,
    required this.oderId,
    required this.teacherEmail,
    required this.teacherName,
    required this.yearMonth,
    required this.hoursTaughtBySubject,
    required this.totalHoursTaught,
    this.totalScheduledHours = 0,
    this.totalWorkedHours = 0,
    this.totalFormHours = 0,
    required this.totalClassesScheduled,
    required this.totalClassesCompleted,
    required this.totalClassesMissed,
    required this.totalClassesCancelled,
    this.excusedAbsences = 0,
    required this.completionRate,
    required this.totalClockIns,
    required this.onTimeClockIns,
    required this.lateClockIns,
    required this.avgLatencyMinutes,
    required this.punctualityRate,
    required this.readinessFormsRequired,
    required this.readinessFormsSubmitted,
    required this.formComplianceRate,
    required this.staffMeetingsScheduled,
    required this.staffMeetingsMissed,
    required this.meetingLateArrivals,
    required this.quizzesGiven,
    required this.assignmentsGiven,
    required this.midtermCompleted,
    required this.finalExamCompleted,
    required this.semesterProjectStatus,
    required this.overdueTasks,
    this.totalTasksAssigned = 0,
    this.acknowledgedTasks = 0,
    required this.weeklyRecordingsSent,
    required this.connecteamSignIns,
    required this.classRemindersSet,
    required this.internetDropOffs,
    this.coachEvaluation,
    this.auditFactors = const [],
    this.paymentSummary,
    required this.status,
    this.reviewChain,
    required this.issues,
    this.changeLog = const [],
    this.detailedShifts = const [],
    this.detailedTimesheets = const [],
    this.detailedForms = const [],
    this.detailedFormsNonTeaching = const [],
    this.detailedFormsNoSchedule = const [],
    this.detailedFormsRejected = const [],
    this.adminFormAcceptanceOverrides = const [],
    this.teacherAcknowledgedAt,
    this.discussionChatId,
    required this.automaticScore,
    required this.coachScore,
    required this.overallScore,
    required this.performanceTier,
    required this.lastUpdated,
    this.periodStart,
    this.periodEnd,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'oderId': oderId,
        'userId': oderId,
        'teacherEmail': teacherEmail,
        'teacherName': teacherName,
        'yearMonth': yearMonth,
        'hoursTaughtBySubject': hoursTaughtBySubject,
        'totalHoursTaught': totalHoursTaught,
        'totalScheduledHours': totalScheduledHours,
        'totalWorkedHours': totalWorkedHours,
        'totalFormHours': totalFormHours,
        'totalClassesScheduled': totalClassesScheduled,
        'totalClassesCompleted': totalClassesCompleted,
        'totalClassesMissed': totalClassesMissed,
        'totalClassesCancelled': totalClassesCancelled,
        'excusedAbsences': excusedAbsences,
        'completionRate': completionRate,
        'totalClockIns': totalClockIns,
        'onTimeClockIns': onTimeClockIns,
        'lateClockIns': lateClockIns,
        'avgLatencyMinutes': avgLatencyMinutes,
        'punctualityRate': punctualityRate,
        'readinessFormsRequired': readinessFormsRequired,
        'readinessFormsSubmitted': readinessFormsSubmitted,
        'formComplianceRate': formComplianceRate,
        'staffMeetingsScheduled': staffMeetingsScheduled,
        'staffMeetingsMissed': staffMeetingsMissed,
        'meetingLateArrivals': meetingLateArrivals,
        'quizzesGiven': quizzesGiven,
        'assignmentsGiven': assignmentsGiven,
        'midtermCompleted': midtermCompleted,
        'finalExamCompleted': finalExamCompleted,
        'semesterProjectStatus': semesterProjectStatus,
        'overdueTasks': overdueTasks,
        'totalTasksAssigned': totalTasksAssigned,
        'acknowledgedTasks': acknowledgedTasks,
        'weeklyRecordingsSent': weeklyRecordingsSent,
        'connecteamSignIns': connecteamSignIns,
        'classRemindersSet': classRemindersSet,
        'internetDropOffs': internetDropOffs,
        'coachEvaluation': coachEvaluation?.toMap(),
        'auditFactors': auditFactors.map((f) => f.toMap()).toList(),
        'paymentSummary': paymentSummary?.toMap(),
        'status': status.name,
        'reviewChain': reviewChain?.toMap(),
        'issues': issues.map((i) => i.toMap()).toList(),
        'changeLog': changeLog.map((e) => e.toMap()).toList(),
        'detailedShifts': detailedShifts,
        'detailedTimesheets': detailedTimesheets,
        'detailedForms': detailedForms,
        'detailedFormsNonTeaching': detailedFormsNonTeaching,
        'detailedFormsNoSchedule': detailedFormsNoSchedule,
        'detailedFormsRejected': detailedFormsRejected,
        'adminFormAcceptanceOverrides':
            adminFormAcceptanceOverrides.map((e) => e.toMap()).toList(),
        'teacherAcknowledgedAt': teacherAcknowledgedAt != null
            ? Timestamp.fromDate(teacherAcknowledgedAt!)
            : null,
        'discussionChatId': discussionChatId,
        'automaticScore': automaticScore,
        'coachScore': coachScore,
        'overallScore': overallScore,
        'performanceTier': performanceTier,
        'lastUpdated': Timestamp.fromDate(lastUpdated),
        'periodStart':
            periodStart != null ? Timestamp.fromDate(periodStart!) : null,
        'periodEnd': periodEnd != null ? Timestamp.fromDate(periodEnd!) : null,
      };

  factory TeacherAuditFull.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeacherAuditFull.fromMap(data, doc.id);
  }

  factory TeacherAuditFull.fromMap(Map<String, dynamic> data, String docId) {
    return TeacherAuditFull(
      id: docId,
      oderId: data['userId'] ?? '',
      teacherEmail: data['teacherEmail'] ?? '',
      teacherName: data['teacherName'] ?? '',
      yearMonth: data['yearMonth'] ?? '',
      hoursTaughtBySubject: Map<String, double>.from(
          (data['hoursTaughtBySubject'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, (v as num).toDouble()))),
      totalHoursTaught: (data['totalHoursTaught'] ?? 0).toDouble(),
      totalScheduledHours: (data['totalScheduledHours'] ?? 0).toDouble(),
      totalWorkedHours: (data['totalWorkedHours'] ?? 0).toDouble(),
      totalFormHours: (data['totalFormHours'] ?? 0).toDouble(),
      totalClassesScheduled: data['totalClassesScheduled'] ?? 0,
      totalClassesCompleted: data['totalClassesCompleted'] ?? 0,
      totalClassesMissed: data['totalClassesMissed'] ?? 0,
      totalClassesCancelled: data['totalClassesCancelled'] ?? 0,
      excusedAbsences: data['excusedAbsences'] ?? 0,
      completionRate: (data['completionRate'] ?? 0).toDouble(),
      totalClockIns: data['totalClockIns'] ?? 0,
      onTimeClockIns: data['onTimeClockIns'] ?? 0,
      lateClockIns: data['lateClockIns'] ?? 0,
      avgLatencyMinutes: (data['avgLatencyMinutes'] ?? 0).toDouble(),
      punctualityRate: (data['punctualityRate'] ?? 0).toDouble(),
      readinessFormsRequired: data['readinessFormsRequired'] ?? 0,
      readinessFormsSubmitted: data['readinessFormsSubmitted'] ?? 0,
      formComplianceRate: (data['formComplianceRate'] ?? 0).toDouble(),
      staffMeetingsScheduled: data['staffMeetingsScheduled'] ?? 0,
      staffMeetingsMissed: data['staffMeetingsMissed'] ?? 0,
      meetingLateArrivals: data['meetingLateArrivals'] ?? 0,
      quizzesGiven: data['quizzesGiven'] ?? 0,
      assignmentsGiven: data['assignmentsGiven'] ?? 0,
      midtermCompleted: data['midtermCompleted'] ?? false,
      finalExamCompleted: data['finalExamCompleted'] ?? false,
      semesterProjectStatus: data['semesterProjectStatus'] ?? 'Not started',
      overdueTasks: data['overdueTasks'] ?? 0,
      totalTasksAssigned: data['totalTasksAssigned'] ?? 0,
      acknowledgedTasks: data['acknowledgedTasks'] ?? 0,
      weeklyRecordingsSent: data['weeklyRecordingsSent'] ?? 0,
      connecteamSignIns: data['connecteamSignIns'] ?? 0,
      classRemindersSet: data['classRemindersSet'] ?? 0,
      internetDropOffs: data['internetDropOffs'] ?? 0,
      coachEvaluation: data['coachEvaluation'] != null
          ? CoachEvaluation.fromMap(data['coachEvaluation'])
          : null,
      auditFactors: (data['auditFactors'] as List<dynamic>?)
              ?.map((f) => AuditFactor.fromMap(f as Map<String, dynamic>))
              .toList() ??
          getDefaultAuditFactors(),
      paymentSummary: data['paymentSummary'] != null
          ? PaymentSummary.fromMap(data['paymentSummary'])
          : null,
      status: AuditStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => AuditStatus.pending,
      ),
      reviewChain: data['reviewChain'] != null
          ? ReviewChain.fromMap(data['reviewChain'])
          : null,
      issues: (data['issues'] as List<dynamic>?)
              ?.map((i) => AuditIssue.fromMap(i))
              .toList() ??
          [],
      changeLog: (data['changeLog'] as List<dynamic>?)
              ?.map((e) => AuditChangeEntry.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      detailedShifts: (data['detailedShifts'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      detailedTimesheets: (data['detailedTimesheets'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      detailedForms: (data['detailedForms'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      detailedFormsNonTeaching:
          (data['detailedFormsNonTeaching'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [],
      detailedFormsNoSchedule:
          (data['detailedFormsNoSchedule'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [],
      detailedFormsRejected: (data['detailedFormsRejected'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      adminFormAcceptanceOverrides:
          (data['adminFormAcceptanceOverrides'] as List<dynamic>?)
                  ?.map((e) => AdminFormAcceptanceOverride.fromMap(
                      e as Map<String, dynamic>))
                  .toList() ??
              [],
      teacherAcknowledgedAt:
          (data['teacherAcknowledgedAt'] as Timestamp?)?.toDate(),
      discussionChatId: data['discussionChatId']?.toString(),
      automaticScore: (data['automaticScore'] ?? 0).toDouble(),
      coachScore: (data['coachScore'] ?? 0).toDouble(),
      overallScore: (data['overallScore'] ?? 0).toDouble(),
      performanceTier: data['performanceTier'] ?? 'needsImprovement',
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodStart: (data['periodStart'] as Timestamp?)?.toDate(),
      periodEnd: (data['periodEnd'] as Timestamp?)?.toDate(),
    );
  }

  /// Get the 16 mandatory audit factors (matches Excel structure)
  static List<AuditFactor> getDefaultAuditFactors() {
    return [
      AuditFactor(
        id: 'exam',
        title: 'Exam Quality',
        description:
            'Quality and relevance of test questions drawn for students.',
      ),
      AuditFactor(
        id: 'midterm',
        title: 'Midterm',
        description:
            'Evaluation of midterm content, difficulty, and relevance.',
      ),
      AuditFactor(
        id: 'quiz_goal',
        title: 'Monthly Quiz Goal',
        description: 'Is the teacher meeting the required number of quizzes?',
      ),
      AuditFactor(
        id: 'assignment_goal',
        title: 'Weekly Assignment Goal',
        description:
            'Are students receiving and completing weekly assignments?',
      ),
      AuditFactor(
        id: 'tasks_compliance',
        title: 'Tasks Compliance',
        description: 'Compliance with administrative tasks and deadlines.',
      ),
      AuditFactor(
        id: 'class_engagement',
        title: 'Class Engagement',
        description: 'Are students involved or disengaged?',
      ),
      AuditFactor(
        id: 'readiness_accuracy',
        title: 'Class Readiness Sheet: Overall Compliance & Accuracy',
        description:
            'Accuracy and consistency of reporting in the readiness form.',
      ),
      AuditFactor(
        id: 'readiness_comments',
        title:
            'Class Readiness Sheet: Soundness and clarity of Comments/Feedback',
        description: 'Clarity and soundness of feedback/comments.',
      ),
      AuditFactor(
        id: 'attendance',
        title: 'Teacher Attendance & Lateness (meetings & class)',
        description: 'Punctuality for classes, meetings, and workshops.',
      ),
      AuditFactor(
        id: 'contribution',
        title: 'Teacher contribution: meetings, events, & class',
        description: 'Contribution to meetings, events, and Academy culture.',
      ),
      AuditFactor(
        id: 'device_env',
        title: 'Stability of: Teacher\'s Device, Internet & Class Environment',
        description:
            'Stability of internet and suitability of class environment.',
      ),
      AuditFactor(
        id: 'energy',
        title: 'Teacher\'s energy, creativity and fondness during work',
        description:
            'Friendliness, fondness, and creative techniques in class.',
      ),
      AuditFactor(
        id: 'curriculum',
        title: 'Monthly Curriculum Compliance',
        description: 'Is the teacher in line with the curriculum timeline?',
      ),
      AuditFactor(
        id: 'communication',
        title: 'Monthly response to communication: WhatsApp & Email',
        description: 'Responsiveness to WhatsApp and Email (Admin/Coach).',
      ),
      AuditFactor(
        id: 'conduct',
        title: 'Code of Conduct Compliance: any infractions?',
        description: 'Compliance with internal policy and bylaws.',
      ),
      AuditFactor(
        id: 'student_attendance',
        title: 'Monthly Student Attendance sheet: all done',
        description: 'Accuracy of student attendance logging.',
      ),
    ];
  }

  /// Sum of ratings for factors that are not marked N/A.
  int get auditFactorTotalScore => auditFactors
      .where((f) => !f.isNotApplicable)
      .fold(0, (sum, factor) => sum + factor.rating);

  /// Percentage from applicable factors only (0–100%).
  double get auditFactorPercentageScore {
    final applicable = auditFactors.where((f) => !f.isNotApplicable).toList();
    if (applicable.isEmpty) return 0.0;
    final maxScore = applicable.length * 5;
    return (auditFactorTotalScore / maxScore) * 100;
  }

  /// Fields that admins can edit in-app with change tracking.
  static const Map<String, Type> editableFields = {
    'totalClassesMissed': int,
    'totalClassesCancelled': int,
    'staffMeetingsScheduled': int,
    'staffMeetingsMissed': int,
    'meetingLateArrivals': int,
    'quizzesGiven': int,
    'assignmentsGiven': int,
    'overdueTasks': int,
    'weeklyRecordingsSent': int,
    'classRemindersSet': int,
    'internetDropOffs': int,
    'midtermCompleted': bool,
    'finalExamCompleted': bool,
    'semesterProjectStatus': String,
  };

  /// Get the current value of an editable field by name.
  dynamic getEditableFieldValue(String field) {
    switch (field) {
      case 'totalClassesMissed':
        return totalClassesMissed;
      case 'totalClassesCancelled':
        return totalClassesCancelled;
      case 'staffMeetingsScheduled':
        return staffMeetingsScheduled;
      case 'staffMeetingsMissed':
        return staffMeetingsMissed;
      case 'meetingLateArrivals':
        return meetingLateArrivals;
      case 'quizzesGiven':
        return quizzesGiven;
      case 'assignmentsGiven':
        return assignmentsGiven;
      case 'overdueTasks':
        return overdueTasks;
      case 'weeklyRecordingsSent':
        return weeklyRecordingsSent;
      case 'classRemindersSet':
        return classRemindersSet;
      case 'internetDropOffs':
        return internetDropOffs;
      case 'midtermCompleted':
        return midtermCompleted;
      case 'finalExamCompleted':
        return finalExamCompleted;
      case 'semesterProjectStatus':
        return semesterProjectStatus;
      default:
        return null;
    }
  }
}

/// Coach evaluation section - filled manually by coach/admin
class CoachEvaluation {
  final String coachId;
  final String coachName;
  final DateTime evaluatedAt;

  // Ratings (1-9 scale, 1=worst, 9=best)
  final int readinessFormAccuracy; // 1-9
  final int classBayanaDone; // 1-9 or N/A
  final int leftCommentInReadinessForm; // Yes/No -> 9/0
  final int hoursFullyReported; // Always/Sometimes/Never -> 9/5/0
  final int groupBayanaAbsenteeStudents; // Yes/No
  final int teacherNicenessPositiveEnergy; // 1-9
  final int communicationResponsiveness; // 1-9
  final int classRemindersFrequency; // 10+/5-10/1-5/0 -> 9/7/5/0
  final int curriculumCompliance; // Compliant/Partial/Non-compliant -> 9/5/0

  // Coach self-evaluation
  final int coachCommunicationResponsiveness; // 1-9
  final bool followedUpOnLastMonthIssues;
  final bool documentedComplaintsAndPayCuts;
  final int timesReviewedGroupChat;
  final int coachRelationshipRating; // 1-9

  // Text fields
  final String payoutRepercussionRecommendation;
  final String actionablePlanToPreventRecurrence;
  final String additionalNotes;

  const CoachEvaluation({
    required this.coachId,
    required this.coachName,
    required this.evaluatedAt,
    required this.readinessFormAccuracy,
    required this.classBayanaDone,
    required this.leftCommentInReadinessForm,
    required this.hoursFullyReported,
    required this.groupBayanaAbsenteeStudents,
    required this.teacherNicenessPositiveEnergy,
    required this.communicationResponsiveness,
    required this.classRemindersFrequency,
    required this.curriculumCompliance,
    required this.coachCommunicationResponsiveness,
    required this.followedUpOnLastMonthIssues,
    required this.documentedComplaintsAndPayCuts,
    required this.timesReviewedGroupChat,
    required this.coachRelationshipRating,
    required this.payoutRepercussionRecommendation,
    required this.actionablePlanToPreventRecurrence,
    required this.additionalNotes,
  });

  double get totalScore {
    // Calculate total from ratings (max = 9 * number of rated fields)
    double sum = 0;
    int count = 0;

    void addScore(int score, {int max = 9}) {
      if (score >= 0) {
        sum += (score / max) * 9;
        count++;
      }
    }

    addScore(readinessFormAccuracy);
    addScore(classBayanaDone);
    addScore(leftCommentInReadinessForm);
    addScore(hoursFullyReported);
    addScore(groupBayanaAbsenteeStudents);
    addScore(teacherNicenessPositiveEnergy);
    addScore(communicationResponsiveness);
    addScore(classRemindersFrequency);
    addScore(curriculumCompliance);

    return count > 0 ? (sum / count) * 100 / 9 : 0;
  }

  Map<String, dynamic> toMap() => {
        'coachId': coachId,
        'coachName': coachName,
        'evaluatedAt': Timestamp.fromDate(evaluatedAt),
        'readinessFormAccuracy': readinessFormAccuracy,
        'classBayanaDone': classBayanaDone,
        'leftCommentInReadinessForm': leftCommentInReadinessForm,
        'hoursFullyReported': hoursFullyReported,
        'groupBayanaAbsenteeStudents': groupBayanaAbsenteeStudents,
        'teacherNicenessPositiveEnergy': teacherNicenessPositiveEnergy,
        'communicationResponsiveness': communicationResponsiveness,
        'classRemindersFrequency': classRemindersFrequency,
        'curriculumCompliance': curriculumCompliance,
        'coachCommunicationResponsiveness': coachCommunicationResponsiveness,
        'followedUpOnLastMonthIssues': followedUpOnLastMonthIssues,
        'documentedComplaintsAndPayCuts': documentedComplaintsAndPayCuts,
        'timesReviewedGroupChat': timesReviewedGroupChat,
        'coachRelationshipRating': coachRelationshipRating,
        'payoutRepercussionRecommendation': payoutRepercussionRecommendation,
        'actionablePlanToPreventRecurrence': actionablePlanToPreventRecurrence,
        'additionalNotes': additionalNotes,
      };

  factory CoachEvaluation.fromMap(Map<String, dynamic> map) {
    return CoachEvaluation(
      coachId: map['coachId'] ?? '',
      coachName: map['coachName'] ?? '',
      evaluatedAt:
          (map['evaluatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readinessFormAccuracy: map['readinessFormAccuracy'] ?? 0,
      classBayanaDone: map['classBayanaDone'] ?? 0,
      leftCommentInReadinessForm: map['leftCommentInReadinessForm'] ?? 0,
      hoursFullyReported: map['hoursFullyReported'] ?? 0,
      groupBayanaAbsenteeStudents: map['groupBayanaAbsenteeStudents'] ?? 0,
      teacherNicenessPositiveEnergy: map['teacherNicenessPositiveEnergy'] ?? 0,
      communicationResponsiveness: map['communicationResponsiveness'] ?? 0,
      classRemindersFrequency: map['classRemindersFrequency'] ?? 0,
      curriculumCompliance: map['curriculumCompliance'] ?? 0,
      coachCommunicationResponsiveness:
          map['coachCommunicationResponsiveness'] ?? 0,
      followedUpOnLastMonthIssues: map['followedUpOnLastMonthIssues'] ?? false,
      documentedComplaintsAndPayCuts:
          map['documentedComplaintsAndPayCuts'] ?? false,
      timesReviewedGroupChat: map['timesReviewedGroupChat'] ?? 0,
      coachRelationshipRating: map['coachRelationshipRating'] ?? 0,
      payoutRepercussionRecommendation:
          map['payoutRepercussionRecommendation'] ?? '',
      actionablePlanToPreventRecurrence:
          map['actionablePlanToPreventRecurrence'] ?? '',
      additionalNotes: map['additionalNotes'] ?? '',
    );
  }
}

/// Admin override: accept a teaching form that failed automatic rules (no_shift / no_timesheet).
class AdminFormAcceptanceOverride {
  final String formResponseId;
  final String reason;
  final String adminId;
  final String adminName;
  final DateTime acceptedAt;

  const AdminFormAcceptanceOverride({
    required this.formResponseId,
    required this.reason,
    required this.adminId,
    required this.adminName,
    required this.acceptedAt,
  });

  Map<String, dynamic> toMap() => {
        'formResponseId': formResponseId,
        'reason': reason,
        'adminId': adminId,
        'adminName': adminName,
        'acceptedAt': Timestamp.fromDate(acceptedAt),
      };

  factory AdminFormAcceptanceOverride.fromMap(Map<String, dynamic> map) {
    return AdminFormAcceptanceOverride(
      formResponseId: map['formResponseId']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      adminId: map['adminId']?.toString() ?? '',
      adminName: map['adminName']?.toString() ?? '',
      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Advance payment pulled from advance-pay template submissions (`form_responses`).
class AdvancePayment {
  final String formResponseId;
  final double amount;
  final DateTime submittedAt;

  const AdvancePayment({
    required this.formResponseId,
    required this.amount,
    required this.submittedAt,
  });

  Map<String, dynamic> toMap() => {
        'formResponseId': formResponseId,
        'amount': amount,
        'submittedAt': Timestamp.fromDate(submittedAt),
      };

  factory AdvancePayment.fromMap(Map<String, dynamic> map) {
    return AdvancePayment(
      formResponseId: map['formResponseId']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      submittedAt:
          (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Coach-entered payment line during evaluation (penalty subtracts, bonus adds).
class PaymentAdjustmentLine {
  final String id;
  final String type; // 'penalty' | 'bonus'
  final double amount;
  final String reason;
  final String? factorId;
  final DateTime createdAt;
  final String createdById;
  final String createdByName;

  const PaymentAdjustmentLine({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    this.factorId,
    required this.createdAt,
    required this.createdById,
    required this.createdByName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'reason': reason,
        if (factorId != null) 'factorId': factorId,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdById': createdById,
        'createdByName': createdByName,
      };

  factory PaymentAdjustmentLine.fromMap(Map<String, dynamic> map) {
    return PaymentAdjustmentLine(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'penalty',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      reason: map['reason']?.toString() ?? '',
      factorId: map['factorId']?.toString(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdById: map['createdById']?.toString() ?? '',
      createdByName: map['createdByName']?.toString() ?? '',
    );
  }
}

/// Payment summary with hourly rates by subject
class PaymentSummary {
  final Map<String, SubjectPayment> paymentsBySubject;
  final double totalGrossPayment;
  final double totalPenalties;
  final double totalBonuses;
  final double totalNetPayment;
  final double adminAdjustment; // Manual adjustment (round up/down)
  final String adjustmentReason;
  final String adminId;
  final DateTime? adjustedAt;
  // Individual shift payment adjustments: shiftId -> adjusted amount
  final Map<String, double> shiftPaymentAdjustments;

  /// Coach evaluation adjustments; net = [netWithCoachLines] (gross − auto penalties + auto bonuses + adminAdjustment ± lines).
  final List<PaymentAdjustmentLine> coachAdjustmentLines;

  /// Confirmed advance payments (deducted after coach lines for displayed net).
  final List<AdvancePayment> advancePayments;

  const PaymentSummary({
    required this.paymentsBySubject,
    required this.totalGrossPayment,
    required this.totalPenalties,
    required this.totalBonuses,
    required this.totalNetPayment,
    required this.adminAdjustment,
    required this.adjustmentReason,
    required this.adminId,
    this.adjustedAt,
    this.shiftPaymentAdjustments = const {},
    this.coachAdjustmentLines = const [],
    this.advancePayments = const [],
  });

  /// Automated subtotal before coach lines (same basis used when first computing pay).
  double get automatedNetBase =>
      totalGrossPayment - totalPenalties + totalBonuses + adminAdjustment;

  /// Apply coach penalty (subtract) and bonus (add) lines on top of [automatedNetBase].
  double netWithCoachLines() {
    var delta = 0.0;
    for (final l in coachAdjustmentLines) {
      if (l.type == 'bonus') {
        delta += l.amount;
      } else {
        delta -= l.amount;
      }
    }
    return automatedNetBase + delta;
  }

  double get totalAdvanceDeduction =>
      advancePayments.fold(0.0, (s, a) => s + a.amount.abs());

  /// Stored [totalNetPayment] should match this after any payment-affecting update.
  double netAfterAdvances() => netWithCoachLines() - totalAdvanceDeduction;

  Map<String, dynamic> toMap() => {
        'paymentsBySubject':
            paymentsBySubject.map((k, v) => MapEntry(k, v.toMap())),
        'totalGrossPayment': totalGrossPayment,
        'totalPenalties': totalPenalties,
        'totalBonuses': totalBonuses,
        'totalNetPayment': totalNetPayment,
        'adminAdjustment': adminAdjustment,
        'adjustmentReason': adjustmentReason,
        'adminId': adminId,
        'adjustedAt':
            adjustedAt != null ? Timestamp.fromDate(adjustedAt!) : null,
        'shiftPaymentAdjustments': shiftPaymentAdjustments,
        'coachAdjustmentLines':
            coachAdjustmentLines.map((e) => e.toMap()).toList(),
        'advancePayments': advancePayments.map((e) => e.toMap()).toList(),
      };

  factory PaymentSummary.fromMap(Map<String, dynamic> map) {
    final paymentsMap = map['paymentsBySubject'] as Map<String, dynamic>? ?? {};
    final adjustmentsMap =
        map['shiftPaymentAdjustments'] as Map<String, dynamic>? ?? {};
    final linesRaw = map['coachAdjustmentLines'] as List<dynamic>? ??
        map['adjustmentLines'] as List<dynamic>? ??
        const [];
    final lines = <PaymentAdjustmentLine>[];
    for (final e in linesRaw) {
      if (e is Map<String, dynamic>) {
        lines.add(PaymentAdjustmentLine.fromMap(e));
      } else if (e is Map) {
        lines.add(PaymentAdjustmentLine.fromMap(Map<String, dynamic>.from(e)));
      }
    }
    final advRaw = map['advancePayments'] as List<dynamic>? ?? const [];
    final advances = <AdvancePayment>[];
    for (final e in advRaw) {
      if (e is Map<String, dynamic>) {
        advances.add(AdvancePayment.fromMap(e));
      } else if (e is Map) {
        advances.add(AdvancePayment.fromMap(Map<String, dynamic>.from(e)));
      }
    }
    return PaymentSummary(
      paymentsBySubject: paymentsMap.map((k, v) =>
          MapEntry(k, SubjectPayment.fromMap(v as Map<String, dynamic>))),
      totalGrossPayment: (map['totalGrossPayment'] ?? 0).toDouble(),
      totalPenalties: (map['totalPenalties'] ?? 0).toDouble(),
      totalBonuses: (map['totalBonuses'] ?? 0).toDouble(),
      totalNetPayment: (map['totalNetPayment'] ?? 0).toDouble(),
      adminAdjustment: (map['adminAdjustment'] ?? 0).toDouble(),
      adjustmentReason: map['adjustmentReason'] ?? '',
      adminId: map['adminId'] ?? '',
      adjustedAt: (map['adjustedAt'] as Timestamp?)?.toDate(),
      shiftPaymentAdjustments: adjustmentsMap.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      coachAdjustmentLines: lines,
      advancePayments: advances,
    );
  }

  PaymentSummary copyWith({
    Map<String, SubjectPayment>? paymentsBySubject,
    double? totalGrossPayment,
    double? totalPenalties,
    double? totalBonuses,
    double? totalNetPayment,
    double? adminAdjustment,
    String? adjustmentReason,
    String? adminId,
    DateTime? adjustedAt,
    Map<String, double>? shiftPaymentAdjustments,
    List<PaymentAdjustmentLine>? coachAdjustmentLines,
    List<AdvancePayment>? advancePayments,
  }) {
    return PaymentSummary(
      paymentsBySubject: paymentsBySubject ?? this.paymentsBySubject,
      totalGrossPayment: totalGrossPayment ?? this.totalGrossPayment,
      totalPenalties: totalPenalties ?? this.totalPenalties,
      totalBonuses: totalBonuses ?? this.totalBonuses,
      totalNetPayment: totalNetPayment ?? this.totalNetPayment,
      adminAdjustment: adminAdjustment ?? this.adminAdjustment,
      adjustmentReason: adjustmentReason ?? this.adjustmentReason,
      adminId: adminId ?? this.adminId,
      adjustedAt: adjustedAt ?? this.adjustedAt,
      shiftPaymentAdjustments:
          shiftPaymentAdjustments ?? this.shiftPaymentAdjustments,
      coachAdjustmentLines: coachAdjustmentLines ?? this.coachAdjustmentLines,
      advancePayments: advancePayments ?? this.advancePayments,
    );
  }

  /// Get maximum allowed payment per hour for a subject
  static double getMaxHourlyRate(String subjectName) {
    final subjectLower = subjectName.toLowerCase();
    // Quran-related subjects: max $4/hour
    if (subjectLower.contains('quran') ||
        subjectLower.contains('qur\'an') ||
        subjectLower.contains('tajweed') ||
        subjectLower.contains('hifz') ||
        subjectLower.contains('memorization')) {
      return 4.0;
    }
    // All other subjects (English, Math, etc.): max $5/hour
    return 5.0;
  }

  /// Get maximum allowed payment for a shift based on hours and subject
  static double getMaxShiftPayment(String subjectName, double hours) {
    return getMaxHourlyRate(subjectName) * hours;
  }
}

/// Payment details for a single subject
class SubjectPayment {
  final String subjectName;
  final double hoursTaught;
  final double hourlyRate;
  final double grossAmount;
  final double penalties;
  final double bonuses;
  final double netAmount;

  const SubjectPayment({
    required this.subjectName,
    required this.hoursTaught,
    required this.hourlyRate,
    required this.grossAmount,
    required this.penalties,
    required this.bonuses,
    required this.netAmount,
  });

  Map<String, dynamic> toMap() => {
        'subjectName': subjectName,
        'hoursTaught': hoursTaught,
        'hourlyRate': hourlyRate,
        'grossAmount': grossAmount,
        'penalties': penalties,
        'bonuses': bonuses,
        'netAmount': netAmount,
      };

  factory SubjectPayment.fromMap(Map<String, dynamic> map) {
    return SubjectPayment(
      subjectName: map['subjectName'] ?? '',
      hoursTaught: (map['hoursTaught'] ?? 0).toDouble(),
      hourlyRate: (map['hourlyRate'] ?? 0).toDouble(),
      grossAmount: (map['grossAmount'] ?? 0).toDouble(),
      penalties: (map['penalties'] ?? 0).toDouble(),
      bonuses: (map['bonuses'] ?? 0).toDouble(),
      netAmount: (map['netAmount'] ?? 0).toDouble(),
    );
  }
}

/// Audit status in the review workflow
enum AuditStatus {
  pending, // Initial state, auto metrics computed
  coachReview, // Unused — reserved for future workflow
  coachSubmitted, // Coach submitted, waiting for CEO
  ceoReview, // Unused — reserved for future workflow
  ceoApproved, // CEO approved, waiting for Founder
  founderReview, // Unused — reserved for future workflow
  completed, // Fully approved
  disputed, // Teacher disputed something
}

/// Review chain tracking who reviewed and when
class ReviewChain {
  final ReviewEntry? teacherReview;
  final ReviewEntry? coachReview;
  final ReviewEntry? ceoReview;
  final ReviewEntry? founderReview;
  final TeacherDispute? teacherDispute;

  const ReviewChain({
    this.teacherReview,
    this.coachReview,
    this.ceoReview,
    this.founderReview,
    this.teacherDispute,
  });

  Map<String, dynamic> toMap() => {
        'teacherReview': teacherReview?.toMap(),
        'coachReview': coachReview?.toMap(),
        'ceoReview': ceoReview?.toMap(),
        'founderReview': founderReview?.toMap(),
        'teacherDispute': teacherDispute?.toMap(),
      };

  factory ReviewChain.fromMap(Map<String, dynamic> map) {
    return ReviewChain(
      teacherReview: map['teacherReview'] != null
          ? ReviewEntry.fromMap(map['teacherReview'])
          : null,
      coachReview: map['coachReview'] != null
          ? ReviewEntry.fromMap(map['coachReview'])
          : null,
      ceoReview: map['ceoReview'] != null
          ? ReviewEntry.fromMap(map['ceoReview'])
          : null,
      founderReview: map['founderReview'] != null
          ? ReviewEntry.fromMap(map['founderReview'])
          : null,
      teacherDispute: map['teacherDispute'] != null
          ? TeacherDispute.fromMap(map['teacherDispute'])
          : null,
    );
  }
}

/// Single review entry
class ReviewEntry {
  final String reviewerId;
  final String reviewerName;
  final String role;
  final DateTime reviewedAt;
  final String status; // approved, rejected, needs_revision
  final String notes;
  final String signature;

  const ReviewEntry({
    required this.reviewerId,
    required this.reviewerName,
    required this.role,
    required this.reviewedAt,
    required this.status,
    required this.notes,
    required this.signature,
  });

  Map<String, dynamic> toMap() => {
        'reviewerId': reviewerId,
        'reviewerName': reviewerName,
        'role': role,
        'reviewedAt': Timestamp.fromDate(reviewedAt),
        'status': status,
        'notes': notes,
        'signature': signature,
      };

  factory ReviewEntry.fromMap(Map<String, dynamic> map) {
    return ReviewEntry(
      reviewerId: map['reviewerId'] ?? '',
      reviewerName: map['reviewerName'] ?? '',
      role: map['role'] ?? '',
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? '',
      notes: map['notes'] ?? '',
      signature: map['signature'] ?? '',
    );
  }
}

/// Teacher dispute/correction request
class TeacherDispute {
  final String teacherId;
  final DateTime disputedAt;
  final String field; // Which field is being disputed
  final String reason;
  final dynamic suggestedValue;
  final String status; // pending, accepted, rejected
  final String adminResponse;
  final DateTime? resolvedAt;

  const TeacherDispute({
    required this.teacherId,
    required this.disputedAt,
    required this.field,
    required this.reason,
    this.suggestedValue,
    required this.status,
    required this.adminResponse,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() => {
        'teacherId': teacherId,
        'disputedAt': Timestamp.fromDate(disputedAt),
        'field': field,
        'reason': reason,
        'suggestedValue': suggestedValue,
        'status': status,
        'adminResponse': adminResponse,
        'resolvedAt':
            resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      };

  factory TeacherDispute.fromMap(Map<String, dynamic> map) {
    return TeacherDispute(
      teacherId: map['teacherId'] ?? '',
      disputedAt: (map['disputedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      field: map['field'] ?? '',
      reason: map['reason'] ?? '',
      suggestedValue: map['suggestedValue'],
      status: map['status'] ?? 'pending',
      adminResponse: map['adminResponse'] ?? '',
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Individual audit issue/flag
class AuditIssue {
  final String type;
  final String description;
  final String severity; // low, medium, high, critical
  final DateTime? date;
  final String? shiftId;
  final double? penaltyAmount;

  const AuditIssue({
    required this.type,
    required this.description,
    required this.severity,
    this.date,
    this.shiftId,
    this.penaltyAmount,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'description': description,
        'severity': severity,
        'date': date?.toIso8601String(),
        'shiftId': shiftId,
        'penaltyAmount': penaltyAmount,
      };

  factory AuditIssue.fromMap(Map<String, dynamic> map) {
    return AuditIssue(
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      severity: map['severity'] ?? 'low',
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      shiftId: map['shiftId'],
      penaltyAmount: (map['penaltyAmount'] as num?)?.toDouble(),
    );
  }
}

/// Single entry in the append-only audit change log.
/// Tracks admin edits to editable audit fields.
class AuditChangeEntry {
  final String field;
  final dynamic oldValue;
  final dynamic newValue;
  final String reason;
  final String adminId;
  final String adminName;
  final DateTime changedAt;

  const AuditChangeEntry({
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.reason,
    required this.adminId,
    required this.adminName,
    required this.changedAt,
  });

  Map<String, dynamic> toMap() => {
        'field': field,
        'oldValue': oldValue,
        'newValue': newValue,
        'reason': reason,
        'adminId': adminId,
        'adminName': adminName,
        'changedAt': Timestamp.fromDate(changedAt),
      };

  factory AuditChangeEntry.fromMap(Map<String, dynamic> map) {
    return AuditChangeEntry(
      field: map['field'] ?? '',
      oldValue: map['oldValue'],
      newValue: map['newValue'],
      reason: map['reason'] ?? '',
      adminId: map['adminId'] ?? '',
      adminName: map['adminName'] ?? '',
      changedAt: (map['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Subject hourly rate configuration (admin-managed)
class SubjectHourlyRate {
  final String subjectId;
  final String subjectName;
  final double hourlyRate;
  final double penaltyRatePerMissedClass;
  final double bonusRatePerExcellence;
  final bool isActive;
  final DateTime updatedAt;
  final String updatedBy;

  const SubjectHourlyRate({
    required this.subjectId,
    required this.subjectName,
    required this.hourlyRate,
    required this.penaltyRatePerMissedClass,
    required this.bonusRatePerExcellence,
    required this.isActive,
    required this.updatedAt,
    required this.updatedBy,
  });

  Map<String, dynamic> toMap() => {
        'subjectId': subjectId,
        'subjectName': subjectName,
        'hourlyRate': hourlyRate,
        'penaltyRatePerMissedClass': penaltyRatePerMissedClass,
        'bonusRatePerExcellence': bonusRatePerExcellence,
        'isActive': isActive,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'updatedBy': updatedBy,
      };

  factory SubjectHourlyRate.fromMap(Map<String, dynamic> map, String docId) {
    return SubjectHourlyRate(
      subjectId: docId,
      subjectName: map['subjectName'] ?? '',
      hourlyRate: (map['hourlyRate'] ?? 0).toDouble(),
      penaltyRatePerMissedClass:
          (map['penaltyRatePerMissedClass'] ?? 0).toDouble(),
      bonusRatePerExcellence: (map['bonusRatePerExcellence'] ?? 0).toDouble(),
      isActive: map['isActive'] ?? true,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'] ?? '',
    );
  }
}
