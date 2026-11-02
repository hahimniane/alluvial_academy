import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin audit KPIs for admin/super_admin users in a given month.
class AdminAudit {
  final String id; // {adminId}_{yearMonth}
  final String adminId;
  final String adminName;
  final String adminEmail;
  final String yearMonth;

  /// Submissions per form template or legacy form id (`templateId ?? formId`).
  final Map<String, int> formsBreakdown;

  final int formsSubmitted;

  final int totalTasksAssigned;
  final int tasksCompleted;
  final int tasksOverdue;
  final int tasksAcknowledged;

  /// Tasks with `dueDate` in month where `createdBy == adminId` (excludes drafts).
  final int tasksCreatedByAdmin;

  /// Mean days from task `createdAt` to `completedAt` for completed assigned tasks.
  final double avgTaskCompletionDays;

  /// Label counts for tasks assigned to this admin in the month (capped server-side).
  final Map<String, int> tasksByLabel;

  /// 0–100: Tier-1 recurring form ratios vs expected volumes for the month.
  final int formComplianceScore;

  /// 0–100: completion vs overdue vs initiative (tasks created).
  final int taskEfficiencyScore;

  /// Weighted blend of form + task scores.
  final int overallScore;

  /// 0–100: sum(subTaskIds.length) for assigned tasks in month / max(1, totalTasksAssigned).
  final int subTasksRatio;

  /// CEO-only notes; not overwritten by [toFirestoreRegenerationMap].
  final String ceoNotes;

  /// Optional monthly bonus amount (USD) entered by the CEO; not overwritten by regeneration.
  final double ceoBonusMonthlyUsd;

  /// Optional monthly pay cut amount (USD) entered by the CEO; not overwritten by regeneration.
  final double ceoPaycutMonthlyUsd;

  /// Explanation when bonus or pay cut applies; not overwritten by regeneration.
  final String ceoAdjustmentRationale;

  /// Leadership hours this month from the leader's leadership timesheets (computed).
  final double leadershipHours;

  /// What those leadership timesheets come to, in USD (computed; a guide for [leaderBasePayUsd]).
  final double leadershipHoursPayUsd;

  /// Pay for the month entered by the CEO (USD). Final pay = this + bonus − pay cut.
  final double leaderBasePayUsd;

  /// 'approved' once the CEO approved the month's pay; Finance then counts [leaderNetPayUsd].
  final String leaderPayStatus;

  /// Final pay locked at approval.
  final double leaderNetPayUsd;
  final String leaderPayApprovedByName;
  final DateTime? leaderPayApprovedAt;

  bool get leaderPayApproved => leaderPayStatus == 'approved';

  /// Pay + bonus − pay cut, never below zero.
  double get leaderFinalPayUsd {
    final v = leaderBasePayUsd + ceoBonusMonthlyUsd - ceoPaycutMonthlyUsd;
    return v < 0 ? 0 : v;
  }

  /// Manual CEO evaluation scores (criterion id → 0–5). Omitted ids = N/A. Not overwritten by regeneration.
  final Map<String, int> adminEvalScores;

  /// Optional evaluator comments by section (theme id, [themeAllId], or [tasksEvalSectionId]).
  final Map<String, String> adminEvalSectionComments;

  final DateTime lastUpdated;

  const AdminAudit({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.adminEmail,
    required this.yearMonth,
    this.formsBreakdown = const {},
    this.formsSubmitted = 0,
    this.totalTasksAssigned = 0,
    this.tasksCompleted = 0,
    this.tasksOverdue = 0,
    this.tasksAcknowledged = 0,
    this.tasksCreatedByAdmin = 0,
    this.avgTaskCompletionDays = 0,
    this.tasksByLabel = const {},
    this.formComplianceScore = 0,
    this.taskEfficiencyScore = 0,
    this.overallScore = 0,
    this.subTasksRatio = 0,
    this.ceoNotes = '',
    this.ceoBonusMonthlyUsd = 0,
    this.ceoPaycutMonthlyUsd = 0,
    this.ceoAdjustmentRationale = '',
    this.leadershipHours = 0,
    this.leadershipHoursPayUsd = 0,
    this.leaderBasePayUsd = 0,
    this.leaderPayStatus = '',
    this.leaderNetPayUsd = 0,
    this.leaderPayApprovedByName = '',
    this.leaderPayApprovedAt,
    this.adminEvalScores = const {},
    this.adminEvalSectionComments = const {},
    required this.lastUpdated,
  });

  /// Fields written when regenerating computed KPIs only. Must **not** include manual data
  /// ([ceoNotes], bonus/paycut, [adminEvalScores], [adminEvalSectionComments]); leaving them out
  /// ensures a merge write does not replace those top-level fields.
  Map<String, dynamic> toFirestoreRegenerationMap() => {
        'adminId': adminId,
        'adminName': adminName,
        'adminEmail': adminEmail,
        'yearMonth': yearMonth,
        'formsBreakdown': formsBreakdown,
        'formsSubmitted': formsSubmitted,
        'totalTasksAssigned': totalTasksAssigned,
        'tasksCompleted': tasksCompleted,
        'tasksOverdue': tasksOverdue,
        'tasksAcknowledged': tasksAcknowledged,
        'tasksCreatedByAdmin': tasksCreatedByAdmin,
        'avgTaskCompletionDays': avgTaskCompletionDays,
        'tasksByLabel': tasksByLabel,
        'formComplianceScore': formComplianceScore,
        'taskEfficiencyScore': taskEfficiencyScore,
        'overallScore': overallScore,
        'subTasksRatio': subTasksRatio,
        'leadershipHours': leadershipHours,
        'leadershipHoursPayUsd': leadershipHoursPayUsd,
        'lastUpdated': Timestamp.fromDate(lastUpdated),
      };

  /// Full map including CEO-written fields (e.g. after loading or manual update).
  Map<String, dynamic> toMap() => {
        ...toFirestoreRegenerationMap(),
        'ceoNotes': ceoNotes,
        'ceoBonusMonthlyUsd': ceoBonusMonthlyUsd,
        'ceoPaycutMonthlyUsd': ceoPaycutMonthlyUsd,
        'ceoAdjustmentRationale': ceoAdjustmentRationale,
        'leaderBasePayUsd': leaderBasePayUsd,
        'adminEvalScores': adminEvalScores,
        'adminEvalSectionComments': adminEvalSectionComments,
      };

  static Map<String, int> _parseStringIntMap(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    final out = <String, int>{};
    for (final e in raw.entries) {
      final k = e.key;
      final v = e.value;
      if (k is String && v is num) {
        out[k] = v.toInt();
      }
    }
    return out;
  }

  static Map<String, int> _parseEvalScoresMap(dynamic raw) {
    final m = _parseStringIntMap(raw);
    return {
      for (final e in m.entries) e.key: e.value.clamp(0, 5),
    };
  }

  static Map<String, String> _parseStringStringMap(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    final out = <String, String>{};
    for (final e in raw.entries) {
      if (e.key is String) {
        out[e.key as String] = e.value?.toString() ?? '';
      }
    }
    return out;
  }

  factory AdminAudit.fromMap(Map<String, dynamic> data, String docId) {
    return AdminAudit(
      id: docId,
      adminId: data['adminId'] ?? '',
      adminName: data['adminName'] ?? '',
      adminEmail: data['adminEmail'] ?? '',
      yearMonth: data['yearMonth'] ?? '',
      formsBreakdown: _parseStringIntMap(data['formsBreakdown']),
      formsSubmitted: (data['formsSubmitted'] as num?)?.toInt() ?? 0,
      totalTasksAssigned: (data['totalTasksAssigned'] as num?)?.toInt() ?? 0,
      tasksCompleted: (data['tasksCompleted'] as num?)?.toInt() ?? 0,
      tasksOverdue: (data['tasksOverdue'] as num?)?.toInt() ?? 0,
      tasksAcknowledged: (data['tasksAcknowledged'] as num?)?.toInt() ?? 0,
      tasksCreatedByAdmin:
          (data['tasksCreatedByAdmin'] as num?)?.toInt() ?? 0,
      avgTaskCompletionDays:
          (data['avgTaskCompletionDays'] as num?)?.toDouble() ?? 0,
      tasksByLabel: _parseStringIntMap(data['tasksByLabel']),
      formComplianceScore:
          (data['formComplianceScore'] as num?)?.toInt() ?? 0,
      taskEfficiencyScore:
          (data['taskEfficiencyScore'] as num?)?.toInt() ?? 0,
      overallScore: (data['overallScore'] as num?)?.toInt() ?? 0,
      subTasksRatio: (data['subTasksRatio'] as num?)?.toInt() ?? 0,
      ceoNotes: data['ceoNotes']?.toString() ?? '',
      ceoBonusMonthlyUsd:
          (data['ceoBonusMonthlyUsd'] as num?)?.toDouble() ?? 0,
      ceoPaycutMonthlyUsd:
          (data['ceoPaycutMonthlyUsd'] as num?)?.toDouble() ?? 0,
      ceoAdjustmentRationale: data['ceoAdjustmentRationale']?.toString() ?? '',
      leadershipHours: (data['leadershipHours'] as num?)?.toDouble() ?? 0,
      leadershipHoursPayUsd:
          (data['leadershipHoursPayUsd'] as num?)?.toDouble() ?? 0,
      leaderBasePayUsd: (data['leaderBasePayUsd'] as num?)?.toDouble() ?? 0,
      leaderPayStatus: data['leaderPayStatus']?.toString() ?? '',
      leaderNetPayUsd: (data['leaderNetPayUsd'] as num?)?.toDouble() ?? 0,
      leaderPayApprovedByName:
          data['leaderPayApprovedByName']?.toString() ?? '',
      leaderPayApprovedAt: data['leaderPayApprovedAt'] is Timestamp
          ? (data['leaderPayApprovedAt'] as Timestamp).toDate()
          : null,
      adminEvalScores: _parseEvalScoresMap(data['adminEvalScores']),
      adminEvalSectionComments: _parseStringStringMap(data['adminEvalSectionComments']),
      lastUpdated: data['lastUpdated'] is Timestamp
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory AdminAudit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminAudit.fromMap(data, doc.id);
  }

  AdminAudit copyWith({
    String? id,
    String? adminId,
    String? adminName,
    String? adminEmail,
    String? yearMonth,
    Map<String, int>? formsBreakdown,
    int? formsSubmitted,
    int? totalTasksAssigned,
    int? tasksCompleted,
    int? tasksOverdue,
    int? tasksAcknowledged,
    int? tasksCreatedByAdmin,
    double? avgTaskCompletionDays,
    Map<String, int>? tasksByLabel,
    int? formComplianceScore,
    int? taskEfficiencyScore,
    int? overallScore,
    int? subTasksRatio,
    String? ceoNotes,
    double? ceoBonusMonthlyUsd,
    double? ceoPaycutMonthlyUsd,
    String? ceoAdjustmentRationale,
    double? leadershipHours,
    double? leadershipHoursPayUsd,
    double? leaderBasePayUsd,
    String? leaderPayStatus,
    double? leaderNetPayUsd,
    String? leaderPayApprovedByName,
    DateTime? leaderPayApprovedAt,
    Map<String, int>? adminEvalScores,
    Map<String, String>? adminEvalSectionComments,
    DateTime? lastUpdated,
  }) {
    return AdminAudit(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      adminName: adminName ?? this.adminName,
      adminEmail: adminEmail ?? this.adminEmail,
      yearMonth: yearMonth ?? this.yearMonth,
      formsBreakdown: formsBreakdown ?? this.formsBreakdown,
      formsSubmitted: formsSubmitted ?? this.formsSubmitted,
      totalTasksAssigned: totalTasksAssigned ?? this.totalTasksAssigned,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      tasksOverdue: tasksOverdue ?? this.tasksOverdue,
      tasksAcknowledged: tasksAcknowledged ?? this.tasksAcknowledged,
      tasksCreatedByAdmin: tasksCreatedByAdmin ?? this.tasksCreatedByAdmin,
      avgTaskCompletionDays:
          avgTaskCompletionDays ?? this.avgTaskCompletionDays,
      tasksByLabel: tasksByLabel ?? this.tasksByLabel,
      formComplianceScore: formComplianceScore ?? this.formComplianceScore,
      taskEfficiencyScore: taskEfficiencyScore ?? this.taskEfficiencyScore,
      overallScore: overallScore ?? this.overallScore,
      subTasksRatio: subTasksRatio ?? this.subTasksRatio,
      ceoNotes: ceoNotes ?? this.ceoNotes,
      ceoBonusMonthlyUsd: ceoBonusMonthlyUsd ?? this.ceoBonusMonthlyUsd,
      ceoPaycutMonthlyUsd: ceoPaycutMonthlyUsd ?? this.ceoPaycutMonthlyUsd,
      ceoAdjustmentRationale:
          ceoAdjustmentRationale ?? this.ceoAdjustmentRationale,
      leadershipHours: leadershipHours ?? this.leadershipHours,
      leadershipHoursPayUsd:
          leadershipHoursPayUsd ?? this.leadershipHoursPayUsd,
      leaderBasePayUsd: leaderBasePayUsd ?? this.leaderBasePayUsd,
      leaderPayStatus: leaderPayStatus ?? this.leaderPayStatus,
      leaderNetPayUsd: leaderNetPayUsd ?? this.leaderNetPayUsd,
      leaderPayApprovedByName:
          leaderPayApprovedByName ?? this.leaderPayApprovedByName,
      leaderPayApprovedAt: leaderPayApprovedAt ?? this.leaderPayApprovedAt,
      adminEvalScores: adminEvalScores ?? this.adminEvalScores,
      adminEvalSectionComments:
          adminEvalSectionComments ?? this.adminEvalSectionComments,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
