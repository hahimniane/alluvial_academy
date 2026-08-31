class QuizCompetitionEntry {
  const QuizCompetitionEntry({
    required this.uid,
    required this.displayName,
    required this.answeredCount,
    required this.correctCount,
    required this.accuracy,
    required this.activeDays,
    required this.categoriesAttemptedCount,
    required this.divisionId,
    required this.eligible,
    required this.rank,
  });

  final String uid;
  final String displayName;
  final int answeredCount;
  final int correctCount;
  final double accuracy;
  final int activeDays;
  final int categoriesAttemptedCount;
  final String divisionId;
  final bool eligible;
  final int rank;

  factory QuizCompetitionEntry.fromMap(Map<String, dynamic> map) {
    return QuizCompetitionEntry(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Student',
      answeredCount: (map['answeredCount'] as num?)?.toInt() ?? 0,
      correctCount: (map['correctCount'] as num?)?.toInt() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      activeDays: (map['activeDays'] as num?)?.toInt() ?? 0,
      categoriesAttemptedCount:
          (map['categoriesAttemptedCount'] as num?)?.toInt() ?? 0,
      divisionId: map['divisionId'] as String? ?? 'unassigned',
      eligible: map['eligible'] == true,
      rank: (map['rank'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuizCompetitionDivisionSummary {
  const QuizCompetitionDivisionSummary({
    required this.id,
    required this.participantCount,
    required this.eligibleCount,
    required this.winnerCount,
  });

  final String id;
  final int participantCount;
  final int eligibleCount;
  final int winnerCount;

  factory QuizCompetitionDivisionSummary.fromMap(Map<String, dynamic> map) {
    return QuizCompetitionDivisionSummary(
      id: map['id'] as String? ?? 'unassigned',
      participantCount: (map['participantCount'] as num?)?.toInt() ?? 0,
      eligibleCount: (map['eligibleCount'] as num?)?.toInt() ?? 0,
      winnerCount: (map['winnerCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuizCompetitionEngagement {
  const QuizCompetitionEngagement({
    required this.uid,
    required this.displayName,
    required this.divisionId,
    required this.answeredCount,
    required this.correctCount,
    required this.activeDays,
    required this.eligible,
    required this.status,
  });

  final String uid;
  final String displayName;
  final String divisionId;
  final int answeredCount;
  final int correctCount;
  final int activeDays;
  final bool eligible;
  final String status;

  factory QuizCompetitionEngagement.fromMap(Map<String, dynamic> map) {
    return QuizCompetitionEngagement(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Student',
      divisionId: map['divisionId'] as String? ?? 'unassigned',
      answeredCount: (map['answeredCount'] as num?)?.toInt() ?? 0,
      correctCount: (map['correctCount'] as num?)?.toInt() ?? 0,
      activeDays: (map['activeDays'] as num?)?.toInt() ?? 0,
      eligible: map['eligible'] == true,
      status: map['status'] as String? ?? 'not_started',
    );
  }
}

class QuizCompetitionCategoryInsight {
  const QuizCompetitionCategoryInsight({
    required this.categoryId,
    required this.answeredCount,
    required this.correctCount,
    required this.accuracy,
  });

  final String categoryId;
  final int answeredCount;
  final int correctCount;
  final double accuracy;

  factory QuizCompetitionCategoryInsight.fromMap(Map<String, dynamic> map) {
    return QuizCompetitionCategoryInsight(
      categoryId: map['categoryId'] as String? ?? '',
      answeredCount: (map['answeredCount'] as num?)?.toInt() ?? 0,
      correctCount: (map['correctCount'] as num?)?.toInt() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
    );
  }
}

class QuizCompetitionSnapshot {
  const QuizCompetitionSnapshot({
    required this.monthKey,
    required this.status,
    required this.minimumQuestions,
    required this.minimumActiveDays,
    required this.minimumAccuracy,
    required this.minimumEligibleParticipants,
    required this.requiredCategoryCount,
    required this.countingStartDate,
    required this.countingEndDate,
    required this.lifetimeWins,
    required this.divisionId,
    required this.requiresDivision,
    required this.divisions,
    required this.leaderboard,
    required this.winners,
    required this.engagement,
    required this.categoryInsights,
    this.self,
    this.winner,
    this.nearbyAbove,
    this.nearbyBelow,
  });

  final String monthKey;
  final String status;
  final int minimumQuestions;
  final int minimumActiveDays;
  final double minimumAccuracy;
  final int minimumEligibleParticipants;
  final int requiredCategoryCount;
  final String countingStartDate;
  final String countingEndDate;
  final int lifetimeWins;
  final String divisionId;
  final bool requiresDivision;
  final List<QuizCompetitionDivisionSummary> divisions;
  final List<QuizCompetitionEntry> leaderboard;
  final List<QuizCompetitionEntry> winners;
  final List<QuizCompetitionEngagement> engagement;
  final List<QuizCompetitionCategoryInsight> categoryInsights;
  final QuizCompetitionEntry? self;
  final QuizCompetitionEntry? winner;
  final QuizCompetitionEntry? nearbyAbove;
  final QuizCompetitionEntry? nearbyBelow;

  bool get isFinalized => status == 'finalized';

  factory QuizCompetitionSnapshot.fromMap(Map<String, dynamic> map) {
    final leaderboard = (map['leaderboard'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => QuizCompetitionEntry.fromMap(
              Map<String, dynamic>.from(entry),
            ))
        .toList();
    final self = map['self'];
    final winner = map['winner'];
    final nearby = map['nearby'];
    final winners = (map['winners'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => QuizCompetitionEntry.fromMap(
              Map<String, dynamic>.from(entry),
            ))
        .toList();
    final divisions = (map['divisions'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => QuizCompetitionDivisionSummary.fromMap(
              Map<String, dynamic>.from(entry),
            ))
        .toList();
    final engagement = (map['engagement'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => QuizCompetitionEngagement.fromMap(
              Map<String, dynamic>.from(entry),
            ))
        .toList();
    final categoryInsights = (map['categoryInsights'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => QuizCompetitionCategoryInsight.fromMap(
              Map<String, dynamic>.from(entry),
            ))
        .toList();
    final divisionId = map['divisionId'] as String? ?? 'unassigned';
    return QuizCompetitionSnapshot(
      monthKey: map['monthKey'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      minimumQuestions: (map['minimumQuestions'] as num?)?.toInt() ?? 20,
      minimumActiveDays: (map['minimumActiveDays'] as num?)?.toInt() ?? 3,
      minimumAccuracy: (map['minimumAccuracy'] as num?)?.toDouble() ?? 0.5,
      minimumEligibleParticipants:
          (map['minimumEligibleParticipants'] as num?)?.toInt() ?? 2,
      requiredCategoryCount:
          (map['requiredCategoryCount'] as num?)?.toInt() ?? 9,
      countingStartDate: map['countingStartDate'] as String? ?? '',
      countingEndDate: map['countingEndDate'] as String? ?? '',
      lifetimeWins: (map['lifetimeWins'] as num?)?.toInt() ?? 0,
      divisionId: divisionId,
      requiresDivision:
          map['requiresDivision'] == true || divisionId == 'unassigned',
      divisions: divisions,
      leaderboard: leaderboard,
      winners: winners,
      engagement: engagement,
      categoryInsights: categoryInsights,
      self: self is Map
          ? QuizCompetitionEntry.fromMap(Map<String, dynamic>.from(self))
          : null,
      winner: winner is Map
          ? QuizCompetitionEntry.fromMap(Map<String, dynamic>.from(winner))
          : (winners.isEmpty ? null : winners.first),
      nearbyAbove: nearby is Map && nearby['above'] is Map
          ? QuizCompetitionEntry.fromMap(
              Map<String, dynamic>.from(nearby['above'] as Map))
          : null,
      nearbyBelow: nearby is Map && nearby['below'] is Map
          ? QuizCompetitionEntry.fromMap(
              Map<String, dynamic>.from(nearby['below'] as Map))
          : null,
    );
  }
}
