import 'package:alluwalacademyadmin/features/quiz/models/quiz_competition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuizCompetitionSnapshot', () {
    test('parses leaderboard, own progress, and finalized winner', () {
      final snapshot = QuizCompetitionSnapshot.fromMap({
        'monthKey': '2026-07',
        'status': 'finalized',
        'minimumQuestions': 20,
        'minimumActiveDays': 3,
        'minimumAccuracy': 0.5,
        'minimumEligibleParticipants': 2,
        'requiredCategoryCount': 9,
        'countingStartDate': '2026-07-01',
        'countingEndDate': '2026-07-20',
        'lifetimeWins': 2,
        'divisionId': 'youth',
        'requiresDivision': false,
        'divisions': [
          {
            'id': 'youth',
            'participantCount': 8,
            'eligibleCount': 4,
            'winnerCount': 1,
          },
        ],
        'engagement': [
          {
            'uid': 'student-3',
            'displayName': 'Fatou K.',
            'divisionId': 'youth',
            'answeredCount': 0,
            'correctCount': 0,
            'activeDays': 0,
            'eligible': false,
            'status': 'not_started',
          },
        ],
        'leaderboard': [
          {
            'uid': 'student-1',
            'displayName': 'Amina D.',
            'answeredCount': 30,
            'correctCount': 24,
            'accuracy': 0.8,
            'activeDays': 5,
            'divisionId': 'youth',
            'eligible': true,
            'rank': 1,
          },
        ],
        'self': {
          'uid': 'student-2',
          'displayName': 'Musa B.',
          'answeredCount': 22,
          'correctCount': 18,
          'accuracy': 18 / 22,
          'activeDays': 4,
          'divisionId': 'youth',
          'eligible': true,
          'rank': 2,
        },
        'winners': [
          {
            'uid': 'student-1',
            'displayName': 'Amina D.',
            'answeredCount': 30,
            'correctCount': 24,
            'accuracy': 0.8,
            'activeDays': 5,
            'divisionId': 'youth',
            'eligible': true,
            'rank': 1,
          },
        ],
        'nearby': {
          'above': {
            'uid': 'student-1',
            'displayName': 'Amina D.',
            'rank': 1,
          },
          'below': {
            'uid': 'student-3',
            'displayName': 'Fatou K.',
            'rank': 3,
          },
        },
        'categoryInsights': [
          {
            'categoryId': 'five_pillars',
            'answeredCount': 4,
            'correctCount': 3,
            'accuracy': 0.75,
          },
        ],
      });

      expect(snapshot.monthKey, '2026-07');
      expect(snapshot.isFinalized, isTrue);
      expect(snapshot.leaderboard.single.displayName, 'Amina D.');
      expect(snapshot.self?.rank, 2);
      expect(snapshot.winner?.answeredCount, 30);
      expect(snapshot.winners, hasLength(1));
      expect(snapshot.divisionId, 'youth');
      expect(snapshot.divisions.single.eligibleCount, 4);
      expect(snapshot.engagement.single.status, 'not_started');
      expect(snapshot.requiredCategoryCount, 9);
      expect(snapshot.countingEndDate, '2026-07-20');
      expect(snapshot.lifetimeWins, 2);
      expect(snapshot.nearbyAbove?.displayName, 'Amina D.');
      expect(snapshot.nearbyBelow?.displayName, 'Fatou K.');
      expect(snapshot.categoryInsights.single.accuracy, 0.75);
    });

    test('uses safe defaults for a new month', () {
      final snapshot = QuizCompetitionSnapshot.fromMap({
        'monthKey': '2026-08',
      });

      expect(snapshot.status, 'open');
      expect(snapshot.minimumQuestions, 20);
      expect(snapshot.minimumActiveDays, 3);
      expect(snapshot.minimumAccuracy, 0.5);
      expect(snapshot.minimumEligibleParticipants, 2);
      expect(snapshot.divisionId, 'unassigned');
      expect(snapshot.requiresDivision, isTrue);
      expect(snapshot.leaderboard, isEmpty);
      expect(snapshot.self, isNull);
      expect(snapshot.winner, isNull);
    });
  });
}
