import 'package:cloud_firestore/cloud_firestore.dart';

/// Ranking categories for leaderboard
enum RankingCategory {
  overall, // Combined score
  attendance, // Punctuality + completion rate
  formCompliance, // Form submission rate
  teachingQuality, // Coach evaluation scores
  taskCompletion, // Task completion rate (for admins)
  parentSatisfaction, // Parent feedback scores
}

extension RankingCategoryExtension on RankingCategory {
  String get displayName {
    switch (this) {
      case RankingCategory.overall:
        return 'Overall Performance';
      case RankingCategory.attendance:
        return 'Attendance & Punctuality';
      case RankingCategory.formCompliance:
        return 'Form Compliance';
      case RankingCategory.teachingQuality:
        return 'Teaching Quality';
      case RankingCategory.taskCompletion:
        return 'Task Completion';
      case RankingCategory.parentSatisfaction:
        return 'Parent Satisfaction';
    }
  }

  String get icon {
    switch (this) {
      case RankingCategory.overall:
        return '🏆';
      case RankingCategory.attendance:
        return '⏰';
      case RankingCategory.formCompliance:
        return '📋';
      case RankingCategory.teachingQuality:
        return '⭐';
      case RankingCategory.taskCompletion:
        return '✅';
      case RankingCategory.parentSatisfaction:
        return '👨‍👩‍👧';
    }
  }
}

/// Award types for recognition
enum AwardType {
  teacherOfTheMonth, // Best overall teacher
  mostReliable, // Best attendance
  mostDiligent, // Best form compliance
  topRated, // Best coach evaluation
  mostImproved, // Biggest improvement from previous month
  adminOfTheMonth, // Best admin performance
  coachOfTheMonth, // Best coach performance
}

extension AwardTypeExtension on AwardType {
  String get displayName {
    switch (this) {
      case AwardType.teacherOfTheMonth:
        return '🏆 Teacher of the Month';
      case AwardType.mostReliable:
        return '⏰ Most Reliable';
      case AwardType.mostDiligent:
        return '📋 Most Diligent';
      case AwardType.topRated:
        return '⭐ Top Rated';
      case AwardType.mostImproved:
        return '📈 Most Improved';
      case AwardType.adminOfTheMonth:
        return '🎯 Admin of the Month';
      case AwardType.coachOfTheMonth:
        return '👑 Coach of the Month';
    }
  }
}

/// Individual leaderboard entry for a staff member
class LeaderboardEntry {
  final String oderId;
  final String name;
  final String email;
  final String role; // 'teacher', 'coach', 'admin'
  final String yearMonth;
  
  // Scores (0-100)
  final double overallScore;
  final double attendanceScore;
  final double formComplianceScore;
  final double teachingQualityScore;
  final double taskCompletionScore;
  final double parentSatisfactionScore;
  
  // Raw metrics for context
  final int totalShifts;
  final int completedShifts;
  final int missedShifts;
  final int lateArrivals;
  final int formsSubmitted;
  final int formsRequired;
  final int tasksCompleted;
  final int tasksAssigned;
  final int leaveRequestsTotal;
  final int leaveRequestsApproved;
  
  // Rankings (position in leaderboard)
  final int overallRank;
  final int attendanceRank;
  final int formComplianceRank;
  final int qualityRank;
  
  // Improvement tracking
  final double previousMonthScore;
  final double scoreChange;
  final int rankChange; // Positive = improved, negative = dropped
  
  // Awards earned this month
  final List<AwardType> awards;
  
  // Performance tier
  final String performanceTier;
  
  const LeaderboardEntry({
    required this.oderId,
    required this.name,
    required this.email,
    required this.role,
    required this.yearMonth,
    required this.overallScore,
    required this.attendanceScore,
    required this.formComplianceScore,
    required this.teachingQualityScore,
    this.taskCompletionScore = 0,
    this.parentSatisfactionScore = 0,
    required this.totalShifts,
    required this.completedShifts,
    required this.missedShifts,
    required this.lateArrivals,
    required this.formsSubmitted,
    required this.formsRequired,
    this.tasksCompleted = 0,
    this.tasksAssigned = 0,
    this.leaveRequestsTotal = 0,
    this.leaveRequestsApproved = 0,
    required this.overallRank,
    required this.attendanceRank,
    required this.formComplianceRank,
    required this.qualityRank,
    this.previousMonthScore = 0,
    this.scoreChange = 0,
    this.rankChange = 0,
    this.awards = const [],
    required this.performanceTier,
  });

  Map<String, dynamic> toMap() => {
    'oderId': oderId,
    'name': name,
    'email': email,
    'role': role,
    'yearMonth': yearMonth,
    'overallScore': overallScore,
    'attendanceScore': attendanceScore,
    'formComplianceScore': formComplianceScore,
    'teachingQualityScore': teachingQualityScore,
    'taskCompletionScore': taskCompletionScore,
    'parentSatisfactionScore': parentSatisfactionScore,
    'totalShifts': totalShifts,
    'completedShifts': completedShifts,
    'missedShifts': missedShifts,
    'lateArrivals': lateArrivals,
    'formsSubmitted': formsSubmitted,
    'formsRequired': formsRequired,
    'tasksCompleted': tasksCompleted,
    'tasksAssigned': tasksAssigned,
    'leaveRequestsTotal': leaveRequestsTotal,
    'leaveRequestsApproved': leaveRequestsApproved,
    'overallRank': overallRank,
    'attendanceRank': attendanceRank,
    'formComplianceRank': formComplianceRank,
    'qualityRank': qualityRank,
    'previousMonthScore': previousMonthScore,
    'scoreChange': scoreChange,
    'rankChange': rankChange,
    'awards': awards.map((a) => a.name).toList(),
    'performanceTier': performanceTier,
  };

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      oderId: map['oderId'] ?? map['userId'] ?? '',
      name: map['name'] ?? map['teacherName'] ?? '',
      email: map['email'] ?? map['teacherEmail'] ?? '',
      role: map['role'] ?? 'teacher',
      yearMonth: map['yearMonth'] ?? '',
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0,
      attendanceScore: (map['attendanceScore'] as num?)?.toDouble() ?? 0,
      formComplianceScore: (map['formComplianceScore'] as num?)?.toDouble() ?? 0,
      teachingQualityScore: (map['teachingQualityScore'] as num?)?.toDouble() ?? 0,
      taskCompletionScore: (map['taskCompletionScore'] as num?)?.toDouble() ?? 0,
      parentSatisfactionScore: (map['parentSatisfactionScore'] as num?)?.toDouble() ?? 0,
      totalShifts: map['totalShifts']?.toInt() ?? 0,
      completedShifts: map['completedShifts']?.toInt() ?? 0,
      missedShifts: map['missedShifts']?.toInt() ?? 0,
      lateArrivals: map['lateArrivals']?.toInt() ?? 0,
      formsSubmitted: map['formsSubmitted']?.toInt() ?? 0,
      formsRequired: map['formsRequired']?.toInt() ?? 0,
      tasksCompleted: map['tasksCompleted']?.toInt() ?? 0,
      tasksAssigned: map['tasksAssigned']?.toInt() ?? 0,
      leaveRequestsTotal: map['leaveRequestsTotal']?.toInt() ?? 0,
      leaveRequestsApproved: map['leaveRequestsApproved']?.toInt() ?? 0,
      overallRank: map['overallRank']?.toInt() ?? 0,
      attendanceRank: map['attendanceRank']?.toInt() ?? 0,
      formComplianceRank: map['formComplianceRank']?.toInt() ?? 0,
      qualityRank: map['qualityRank']?.toInt() ?? 0,
      previousMonthScore: (map['previousMonthScore'] as num?)?.toDouble() ?? 0,
      scoreChange: (map['scoreChange'] as num?)?.toDouble() ?? 0,
      rankChange: map['rankChange']?.toInt() ?? 0,
      awards: (map['awards'] as List<dynamic>?)
          ?.map((a) => AwardType.values.firstWhere(
                (e) => e.name == a,
                orElse: () => AwardType.teacherOfTheMonth,
              ))
          .toList() ?? [],
      performanceTier: map['performanceTier'] ?? 'needsImprovement',
    );
  }

  /// Create from TeacherAuditFull
  factory LeaderboardEntry.fromAudit(Map<String, dynamic> audit, {
    required int overallRank,
    required int attendanceRank,
    required int formComplianceRank,
    required int qualityRank,
    double previousMonthScore = 0,
    int rankChange = 0,
    List<AwardType> awards = const [],
  }) {
    final overallScore = (audit['overallScore'] as num?)?.toDouble() ?? 0;
    
    return LeaderboardEntry(
      oderId: audit['oderId'] ?? audit['userId'] ?? '',
      name: audit['teacherName'] ?? '',
      email: audit['teacherEmail'] ?? '',
      role: 'teacher',
      yearMonth: audit['yearMonth'] ?? '',
      overallScore: overallScore,
      attendanceScore: _calculateAttendanceScore(audit),
      formComplianceScore: (audit['formComplianceRate'] as num?)?.toDouble() ?? 0,
      teachingQualityScore: (audit['coachScore'] as num?)?.toDouble() ?? 0,
      totalShifts: audit['totalClassesScheduled']?.toInt() ?? 0,
      completedShifts: audit['totalClassesCompleted']?.toInt() ?? 0,
      missedShifts: audit['totalClassesMissed']?.toInt() ?? 0,
      lateArrivals: audit['lateClockIns']?.toInt() ?? 0,
      formsSubmitted: audit['readinessFormsSubmitted']?.toInt() ?? 0,
      formsRequired: audit['readinessFormsRequired']?.toInt() ?? 0,
      overallRank: overallRank,
      attendanceRank: attendanceRank,
      formComplianceRank: formComplianceRank,
      qualityRank: qualityRank,
      previousMonthScore: previousMonthScore,
      scoreChange: overallScore - previousMonthScore,
      rankChange: rankChange,
      awards: awards,
      performanceTier: audit['performanceTier'] ?? 'needsImprovement',
    );
  }

  static double _calculateAttendanceScore(Map<String, dynamic> audit) {
    final completionRate = (audit['completionRate'] as num?)?.toDouble() ?? 0;
    final punctualityRate = (audit['punctualityRate'] as num?)?.toDouble() ?? 0;
    // Weight: 60% completion, 40% punctuality
    return (completionRate * 0.6) + (punctualityRate * 0.4);
  }

  /// Get badge color based on rank
  String get rankBadge {
    if (overallRank == 1) return '🥇';
    if (overallRank == 2) return '🥈';
    if (overallRank == 3) return '🥉';
    if (overallRank <= 5) return '🏅';
    return '';
  }

  /// Get trend indicator
  String get trendIndicator {
    if (rankChange > 0) return '📈 +$rankChange';
    if (rankChange < 0) return '📉 $rankChange';
    return '➡️ No change';
  }
}

/// Monthly leaderboard containing all rankings
class MonthlyLeaderboard {
  final String yearMonth;
  final List<LeaderboardEntry> teachers;
  final List<LeaderboardEntry> coaches;
  final List<LeaderboardEntry> admins;
  final Map<AwardType, String> monthlyAwards; // AwardType -> user ID
  final DateTime generatedAt;

  const MonthlyLeaderboard({
    required this.yearMonth,
    required this.teachers,
    this.coaches = const [],
    this.admins = const [],
    this.monthlyAwards = const {},
    required this.generatedAt,
  });

  /// Get top performers by category
  List<LeaderboardEntry> getTopByCategory(RankingCategory category, {int limit = 3}) {
    final allEntries = [...teachers, ...coaches, ...admins];
    
    switch (category) {
      case RankingCategory.overall:
        allEntries.sort((a, b) => b.overallScore.compareTo(a.overallScore));
        break;
      case RankingCategory.attendance:
        allEntries.sort((a, b) => b.attendanceScore.compareTo(a.attendanceScore));
        break;
      case RankingCategory.formCompliance:
        allEntries.sort((a, b) => b.formComplianceScore.compareTo(a.formComplianceScore));
        break;
      case RankingCategory.teachingQuality:
        allEntries.sort((a, b) => b.teachingQualityScore.compareTo(a.teachingQualityScore));
        break;
      case RankingCategory.taskCompletion:
        allEntries.sort((a, b) => b.taskCompletionScore.compareTo(a.taskCompletionScore));
        break;
      case RankingCategory.parentSatisfaction:
        allEntries.sort((a, b) => b.parentSatisfactionScore.compareTo(a.parentSatisfactionScore));
        break;
    }
    
    return allEntries.take(limit).toList();
  }

  /// Get teacher of the month (best overall teacher)
  LeaderboardEntry? get teacherOfTheMonth {
    if (teachers.isEmpty) return null;
    return teachers.reduce((a, b) => a.overallScore >= b.overallScore ? a : b);
  }

  /// Get most improved teacher
  LeaderboardEntry? get mostImprovedTeacher {
    if (teachers.isEmpty) return null;
    return teachers.reduce((a, b) => a.scoreChange >= b.scoreChange ? a : b);
  }

  /// Get teachers needing attention (bottom performers)
  List<LeaderboardEntry> get teachersNeedingAttention {
    return teachers.where((t) => 
      t.performanceTier == 'critical' || 
      t.performanceTier == 'needsImprovement'
    ).toList();
  }

  Map<String, dynamic> toMap() => {
    'yearMonth': yearMonth,
    'teachers': teachers.map((t) => t.toMap()).toList(),
    'coaches': coaches.map((c) => c.toMap()).toList(),
    'admins': admins.map((a) => a.toMap()).toList(),
    'monthlyAwards': monthlyAwards.map((k, v) => MapEntry(k.name, v)),
    'generatedAt': Timestamp.fromDate(generatedAt),
  };

  factory MonthlyLeaderboard.fromMap(Map<String, dynamic> map) {
    return MonthlyLeaderboard(
      yearMonth: map['yearMonth'] ?? '',
      teachers: (map['teachers'] as List<dynamic>?)
          ?.map((t) => LeaderboardEntry.fromMap(t as Map<String, dynamic>))
          .toList() ?? [],
      coaches: (map['coaches'] as List<dynamic>?)
          ?.map((c) => LeaderboardEntry.fromMap(c as Map<String, dynamic>))
          .toList() ?? [],
      admins: (map['admins'] as List<dynamic>?)
          ?.map((a) => LeaderboardEntry.fromMap(a as Map<String, dynamic>))
          .toList() ?? [],
      monthlyAwards: (map['monthlyAwards'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(
                AwardType.values.firstWhere((e) => e.name == k),
                v as String,
              )) ?? {},
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
