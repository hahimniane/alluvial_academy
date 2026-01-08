import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff_leaderboard.dart';
import '../utils/app_logger.dart';

/// Service for generating and managing staff leaderboards
class LeaderboardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _leaderboardCollection = 'staff_leaderboards';
  static const String _auditCollection = 'teacher_audits';
  static const String _taskCollection = 'tasks';
  static const String _formResponsesCollection = 'form_responses';

  /// Generate monthly leaderboard from audit data
  static Future<MonthlyLeaderboard> generateLeaderboard(String yearMonth) async {
    try {
      AppLogger.info('LeaderboardService: Generating leaderboard for $yearMonth');
      
      // Get all audits for the month
      final auditsSnapshot = await _firestore
          .collection(_auditCollection)
          .where('yearMonth', isEqualTo: yearMonth)
          .get();

      if (auditsSnapshot.docs.isEmpty) {
        AppLogger.warning('LeaderboardService: No audits found for $yearMonth');
        return MonthlyLeaderboard(
          yearMonth: yearMonth,
          teachers: [],
          generatedAt: DateTime.now(),
        );
      }

      // Get previous month data for comparison
      final previousYearMonth = _getPreviousMonth(yearMonth);
      final previousAudits = await _getPreviousMonthScores(previousYearMonth);

      // Build teacher entries
      final teacherEntries = <LeaderboardEntry>[];
      
      for (var doc in auditsSnapshot.docs) {
        final data = doc.data();
        final oderId = data['oderId'] ?? data['userId'] ?? '';
        final previousScore = previousAudits[oderId] ?? 0.0;
        
        teacherEntries.add(LeaderboardEntry.fromAudit(
          data,
          overallRank: 0, // Will be set after sorting
          attendanceRank: 0,
          formComplianceRank: 0,
          qualityRank: 0,
          previousMonthScore: previousScore,
        ));
      }

      // Sort and assign rankings
      final rankedTeachers = _assignRankings(teacherEntries, previousAudits);

      // Determine awards
      final awards = _determineAwards(rankedTeachers);

      // Get coach/admin data from task completion
      final coaches = await _getCoachLeaderboard(yearMonth);
      final admins = await _getAdminLeaderboard(yearMonth);

      final leaderboard = MonthlyLeaderboard(
        yearMonth: yearMonth,
        teachers: rankedTeachers,
        coaches: coaches,
        admins: admins,
        monthlyAwards: awards,
        generatedAt: DateTime.now(),
      );

      // Save to Firestore
      await _saveLeaderboard(leaderboard);

      return leaderboard;
    } catch (e) {
      AppLogger.error('LeaderboardService: Error generating leaderboard: $e');
      rethrow;
    }
  }

  /// Get cached leaderboard for a month
  static Future<MonthlyLeaderboard?> getLeaderboard(String yearMonth) async {
    try {
      final doc = await _firestore
          .collection(_leaderboardCollection)
          .doc(yearMonth)
          .get();

      if (!doc.exists) return null;
      return MonthlyLeaderboard.fromMap(doc.data()!);
    } catch (e) {
      AppLogger.error('LeaderboardService: Error getting leaderboard: $e');
      return null;
    }
  }

  /// Get top performers across all time
  static Future<List<LeaderboardEntry>> getAllTimeTopPerformers({int limit = 10}) async {
    try {
      // Aggregate scores from all months
      final snapshot = await _firestore
          .collection(_leaderboardCollection)
          .orderBy('generatedAt', descending: true)
          .limit(12) // Last 12 months
          .get();

      final aggregateScores = <String, _AggregateScore>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final teachers = data['teachers'] as List<dynamic>? ?? [];
        
        for (var teacher in teachers) {
          final teacherData = teacher as Map<String, dynamic>;
          final oderId = teacherData['oderId'] ?? '';
          final score = (teacherData['overallScore'] as num?)?.toDouble() ?? 0;
          
          aggregateScores.putIfAbsent(oderId, () => _AggregateScore(
            oderId: oderId,
            name: teacherData['name'] ?? '',
            email: teacherData['email'] ?? '',
          ));
          aggregateScores[oderId]!.addScore(score);
        }
      }

      // Calculate average scores and rank
      final entries = aggregateScores.values
          .map((a) => LeaderboardEntry(
                oderId: a.oderId,
                name: a.name,
                email: a.email,
                role: 'teacher',
                yearMonth: 'all-time',
                overallScore: a.averageScore,
                attendanceScore: 0,
                formComplianceScore: 0,
                teachingQualityScore: 0,
                totalShifts: 0,
                completedShifts: 0,
                missedShifts: 0,
                lateArrivals: 0,
                formsSubmitted: 0,
                formsRequired: 0,
                overallRank: 0,
                attendanceRank: 0,
                formComplianceRank: 0,
                qualityRank: 0,
                performanceTier: _getTierFromScore(a.averageScore),
              ))
          .toList()
        ..sort((a, b) => b.overallScore.compareTo(a.overallScore));

      // Assign ranks
      for (var i = 0; i < entries.length; i++) {
        entries[i] = LeaderboardEntry(
          oderId: entries[i].oderId,
          name: entries[i].name,
          email: entries[i].email,
          role: entries[i].role,
          yearMonth: entries[i].yearMonth,
          overallScore: entries[i].overallScore,
          attendanceScore: entries[i].attendanceScore,
          formComplianceScore: entries[i].formComplianceScore,
          teachingQualityScore: entries[i].teachingQualityScore,
          totalShifts: entries[i].totalShifts,
          completedShifts: entries[i].completedShifts,
          missedShifts: entries[i].missedShifts,
          lateArrivals: entries[i].lateArrivals,
          formsSubmitted: entries[i].formsSubmitted,
          formsRequired: entries[i].formsRequired,
          overallRank: i + 1,
          attendanceRank: 0,
          formComplianceRank: 0,
          qualityRank: 0,
          performanceTier: entries[i].performanceTier,
        );
      }

      return entries.take(limit).toList();
    } catch (e) {
      AppLogger.error('LeaderboardService: Error getting all-time top performers: $e');
      return [];
    }
  }

  /// Get leave request statistics for a user
  static Future<Map<String, int>> getLeaveRequestStats(String oderId, String yearMonth) async {
    try {
      // Query form_responses for leave requests
      final snapshot = await _firestore
          .collection(_formResponsesCollection)
          .where('userId', isEqualTo: oderId)
          .where('formId', isEqualTo: 'leave_request')
          .where('yearMonth', isEqualTo: yearMonth)
          .get();

      int total = 0;
      int approved = 0;
      int pending = 0;
      int rejected = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        total++;
        final status = data['status'] as String? ?? 'pending';
        switch (status) {
          case 'approved':
            approved++;
            break;
          case 'rejected':
            rejected++;
            break;
          default:
            pending++;
        }
      }

      return {
        'total': total,
        'approved': approved,
        'pending': pending,
        'rejected': rejected,
      };
    } catch (e) {
      AppLogger.error('LeaderboardService: Error getting leave stats: $e');
      return {'total': 0, 'approved': 0, 'pending': 0, 'rejected': 0};
    }
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  static String _getPreviousMonth(String yearMonth) {
    final parts = yearMonth.split('-');
    int year = int.parse(parts[0]);
    int month = int.parse(parts[1]);
    
    month--;
    if (month < 1) {
      month = 12;
      year--;
    }
    
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, double>> _getPreviousMonthScores(String yearMonth) async {
    final scores = <String, double>{};
    
    try {
      final previousLeaderboard = await getLeaderboard(yearMonth);
      if (previousLeaderboard != null) {
        for (var teacher in previousLeaderboard.teachers) {
          scores[teacher.oderId] = teacher.overallScore;
        }
      }
    } catch (_) {
      // Ignore errors - previous data may not exist
    }
    
    return scores;
  }

  static List<LeaderboardEntry> _assignRankings(
    List<LeaderboardEntry> entries,
    Map<String, double> previousScores,
  ) {
    if (entries.isEmpty) return entries;

    // Sort by different criteria to assign ranks
    final byOverall = List<LeaderboardEntry>.from(entries)
      ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
    final byAttendance = List<LeaderboardEntry>.from(entries)
      ..sort((a, b) => b.attendanceScore.compareTo(a.attendanceScore));
    final byFormCompliance = List<LeaderboardEntry>.from(entries)
      ..sort((a, b) => b.formComplianceScore.compareTo(a.formComplianceScore));
    final byQuality = List<LeaderboardEntry>.from(entries)
      ..sort((a, b) => b.teachingQualityScore.compareTo(a.teachingQualityScore));

    // Create lookup for ranks
    final overallRanks = <String, int>{};
    final attendanceRanks = <String, int>{};
    final formRanks = <String, int>{};
    final qualityRanks = <String, int>{};

    for (var i = 0; i < byOverall.length; i++) {
      overallRanks[byOverall[i].oderId] = i + 1;
      attendanceRanks[byAttendance[i].oderId] = i + 1;
      formRanks[byFormCompliance[i].oderId] = i + 1;
      qualityRanks[byQuality[i].oderId] = i + 1;
    }

    // Calculate previous ranks for rank change
    final previousRanks = <String, int>{};
    final previousEntries = entries.map((e) => MapEntry(
      e.oderId, 
      previousScores[e.oderId] ?? 0.0,
    )).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    for (var i = 0; i < previousEntries.length; i++) {
      previousRanks[previousEntries[i].key] = i + 1;
    }

    // Build final list with all ranks
    return entries.map((e) {
      final currentRank = overallRanks[e.oderId] ?? entries.length;
      final prevRank = previousRanks[e.oderId] ?? currentRank;
      
      return LeaderboardEntry(
        oderId: e.oderId,
        name: e.name,
        email: e.email,
        role: e.role,
        yearMonth: e.yearMonth,
        overallScore: e.overallScore,
        attendanceScore: e.attendanceScore,
        formComplianceScore: e.formComplianceScore,
        teachingQualityScore: e.teachingQualityScore,
        taskCompletionScore: e.taskCompletionScore,
        parentSatisfactionScore: e.parentSatisfactionScore,
        totalShifts: e.totalShifts,
        completedShifts: e.completedShifts,
        missedShifts: e.missedShifts,
        lateArrivals: e.lateArrivals,
        formsSubmitted: e.formsSubmitted,
        formsRequired: e.formsRequired,
        tasksCompleted: e.tasksCompleted,
        tasksAssigned: e.tasksAssigned,
        leaveRequestsTotal: e.leaveRequestsTotal,
        leaveRequestsApproved: e.leaveRequestsApproved,
        overallRank: currentRank,
        attendanceRank: attendanceRanks[e.oderId] ?? entries.length,
        formComplianceRank: formRanks[e.oderId] ?? entries.length,
        qualityRank: qualityRanks[e.oderId] ?? entries.length,
        previousMonthScore: e.previousMonthScore,
        scoreChange: e.scoreChange,
        rankChange: prevRank - currentRank, // Positive = improved
        awards: e.awards,
        performanceTier: e.performanceTier,
      );
    }).toList()
      ..sort((a, b) => a.overallRank.compareTo(b.overallRank));
  }

  static Map<AwardType, String> _determineAwards(List<LeaderboardEntry> teachers) {
    if (teachers.isEmpty) return {};
    
    final awards = <AwardType, String>{};
    
    // Teacher of the Month - best overall
    final best = teachers.first;
    if (best.overallScore >= 75) {
      awards[AwardType.teacherOfTheMonth] = best.oderId;
    }
    
    // Most Reliable - best attendance
    final byAttendance = List<LeaderboardEntry>.from(teachers)
      ..sort((a, b) => b.attendanceScore.compareTo(a.attendanceScore));
    if (byAttendance.first.attendanceScore >= 90) {
      awards[AwardType.mostReliable] = byAttendance.first.oderId;
    }
    
    // Most Diligent - best form compliance
    final byCompliance = List<LeaderboardEntry>.from(teachers)
      ..sort((a, b) => b.formComplianceScore.compareTo(a.formComplianceScore));
    if (byCompliance.first.formComplianceScore >= 95) {
      awards[AwardType.mostDiligent] = byCompliance.first.oderId;
    }
    
    // Top Rated - best coach evaluation
    final byQuality = List<LeaderboardEntry>.from(teachers)
      ..sort((a, b) => b.teachingQualityScore.compareTo(a.teachingQualityScore));
    if (byQuality.first.teachingQualityScore >= 80) {
      awards[AwardType.topRated] = byQuality.first.oderId;
    }
    
    // Most Improved - biggest positive change
    final byImprovement = List<LeaderboardEntry>.from(teachers)
      ..sort((a, b) => b.scoreChange.compareTo(a.scoreChange));
    if (byImprovement.first.scoreChange >= 10) {
      awards[AwardType.mostImproved] = byImprovement.first.oderId;
    }
    
    return awards;
  }

  static Future<List<LeaderboardEntry>> _getCoachLeaderboard(String yearMonth) async {
    // TODO: Implement coach leaderboard from their completed audits and tasks
    return [];
  }

  static Future<List<LeaderboardEntry>> _getAdminLeaderboard(String yearMonth) async {
    // TODO: Implement admin leaderboard from their task completion
    return [];
  }

  static Future<void> _saveLeaderboard(MonthlyLeaderboard leaderboard) async {
    await _firestore
        .collection(_leaderboardCollection)
        .doc(leaderboard.yearMonth)
        .set(leaderboard.toMap());
  }

  static String _getTierFromScore(double score) {
    if (score >= 90) return 'excellent';
    if (score >= 75) return 'good';
    if (score >= 60) return 'needsImprovement';
    return 'critical';
  }
}

/// Helper class for aggregating scores
class _AggregateScore {
  final String oderId;
  final String name;
  final String email;
  final List<double> scores = [];

  _AggregateScore({
    required this.oderId,
    required this.name,
    required this.email,
  });

  void addScore(double score) => scores.add(score);

  double get averageScore {
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }
}
