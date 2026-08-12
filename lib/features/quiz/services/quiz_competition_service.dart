import 'package:cloud_functions/cloud_functions.dart';

import '../models/quiz_competition.dart';

class QuizCompetitionService {
  QuizCompetitionService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<void> recordAnswer({
    required String questionId,
    required String categoryId,
    required int selectedAnswerIndex,
  }) async {
    await _functions.httpsCallable('recordQuizCompetitionAnswer').call({
      'questionId': questionId,
      'categoryId': categoryId,
      'selectedAnswerIndex': selectedAnswerIndex,
    });
  }

  Future<QuizCompetitionSnapshot> loadLeaderboard({
    String? monthKey,
    String? divisionId,
  }) async {
    final result =
        await _functions.httpsCallable('getQuizCompetitionLeaderboard').call({
      if (monthKey != null) 'monthKey': monthKey,
      if (divisionId != null) 'divisionId': divisionId,
    });
    return QuizCompetitionSnapshot.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<void> assignDivision({
    required String studentUid,
    required String monthKey,
    required String divisionId,
    required String reason,
  }) async {
    await _functions.httpsCallable('setQuizCompetitionDivision').call({
      'studentUid': studentUid,
      'monthKey': monthKey,
      'divisionId': divisionId,
      'reason': reason.trim(),
    });
  }

  Future<void> setCompetitionWindow({
    required String monthKey,
    required String startDate,
    required String endDate,
  }) async {
    await _functions.httpsCallable('setQuizCompetitionWindow').call({
      'monthKey': monthKey,
      'startDate': startDate,
      'endDate': endDate,
    });
  }

  Future<void> setOwnAge({
    required int birthMonth,
    required int birthYear,
  }) async {
    await _functions.httpsCallable('setOwnQuizCompetitionAge').call({
      'birthMonth': birthMonth,
      'birthYear': birthYear,
    });
  }

  Future<void> finalize({
    required String monthKey,
    String? reason,
    String? winnerUid,
  }) async {
    await _functions.httpsCallable('finalizeQuizCompetition').call({
      'monthKey': monthKey,
      if (reason != null && reason.trim().isNotEmpty)
        'overrideReason': reason.trim(),
      if (winnerUid != null && winnerUid.isNotEmpty)
        'overrideWinnerUid': winnerUid,
    });
  }
}
