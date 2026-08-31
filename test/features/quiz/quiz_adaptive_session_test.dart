import 'dart:math';

import 'package:alluwalacademyadmin/features/quiz/models/quiz_question.dart';
import 'package:alluwalacademyadmin/features/quiz/services/quiz_adaptive_session.dart';
import 'package:flutter_test/flutter_test.dart';

List<QuizQuestion> buildQuestions({
  int easy = 10,
  int medium = 10,
  int hard = 10,
}) {
  final questions = <QuizQuestion>[];
  void add(String difficulty, int count) {
    for (var i = 0; i < count; i++) {
      questions.add(QuizQuestion(
        id: '${difficulty}_$i',
        category: 'test',
        difficulty: difficulty,
        question: 'Q $difficulty $i',
        options: const ['a', 'b', 'c', 'd'],
        correctAnswerIndex: 0,
      ));
    }
  }

  add(QuizDifficulty.easy, easy);
  add(QuizDifficulty.medium, medium);
  add(QuizDifficulty.hard, hard);
  return questions;
}

QuizAdaptiveSession buildSession({
  List<QuizQuestion>? questions,
  Set<String> seen = const {},
  String startingDifficulty = QuizDifficulty.easy,
  int sessionLength = 10,
}) {
  return QuizAdaptiveSession(
    questions: questions ?? buildQuestions(),
    seenQuestionIds: seen,
    startingDifficulty: startingDifficulty,
    sessionLength: sessionLength,
    random: Random(42),
  );
}

void main() {
  group('QuizAdaptiveSession', () {
    test('starts at the given difficulty tier', () {
      final session =
          buildSession(startingDifficulty: QuizDifficulty.medium);
      expect(session.currentDifficulty, QuizDifficulty.medium);
      expect(session.nextQuestion()!.difficulty, QuizDifficulty.medium);
    });

    test('falls back to easy for an unknown stored tier', () {
      final session = buildSession(startingDifficulty: 'impossible');
      expect(session.currentDifficulty, QuizDifficulty.easy);
    });

    test('escalates difficulty after two consecutive correct answers', () {
      final session = buildSession();
      session.nextQuestion();
      session.recordAnswer(true);
      expect(session.currentDifficulty, QuizDifficulty.easy);
      session.nextQuestion();
      session.recordAnswer(true);
      expect(session.currentDifficulty, QuizDifficulty.medium);
      session.nextQuestion();
      session.recordAnswer(true);
      session.nextQuestion();
      session.recordAnswer(true);
      expect(session.currentDifficulty, QuizDifficulty.hard);
    });

    test('does not escalate past hard', () {
      final session = buildSession(startingDifficulty: QuizDifficulty.hard);
      for (var i = 0; i < 4; i++) {
        session.nextQuestion();
        session.recordAnswer(true);
      }
      expect(session.currentDifficulty, QuizDifficulty.hard);
    });

    test('steps down after two consecutive wrong answers', () {
      final session =
          buildSession(startingDifficulty: QuizDifficulty.hard);
      session.nextQuestion();
      session.recordAnswer(false);
      session.nextQuestion();
      session.recordAnswer(false);
      expect(session.currentDifficulty, QuizDifficulty.medium);
    });

    test('a wrong answer resets the correct streak', () {
      final session = buildSession();
      session.nextQuestion();
      session.recordAnswer(true);
      session.nextQuestion();
      session.recordAnswer(false);
      session.nextQuestion();
      session.recordAnswer(true);
      expect(session.currentDifficulty, QuizDifficulty.easy);
    });

    test('never repeats a question within a session', () {
      final session = buildSession();
      final ids = <String>{};
      QuizQuestion? question;
      while ((question = session.nextQuestion()) != null) {
        expect(ids.add(question!.id), isTrue,
            reason: 'question ${question.id} repeated');
      }
      expect(ids.length, 10);
    });

    test('avoids questions seen in previous sessions', () {
      final questions = buildQuestions(easy: 12, medium: 0, hard: 0);
      final seen = {for (var i = 0; i < 6; i++) 'easy_$i'};
      final session =
          buildSession(questions: questions, seen: seen, sessionLength: 6);
      final asked = <String>{};
      QuizQuestion? question;
      while ((question = session.nextQuestion()) != null) {
        asked.add(question!.id);
      }
      expect(asked.intersection(seen), isEmpty);
    });

    test('recycles seen questions once the pool is exhausted', () {
      final questions = buildQuestions(easy: 8, medium: 0, hard: 0);
      final seen = questions.map((q) => q.id).toSet();
      final session =
          buildSession(questions: questions, seen: seen, sessionLength: 5);
      var count = 0;
      while (session.nextQuestion() != null) {
        count++;
      }
      expect(count, 5);
    });

    test('borrows from adjacent tiers when the current tier runs out', () {
      final questions = buildQuestions(easy: 2, medium: 3, hard: 0);
      final session = buildSession(questions: questions, sessionLength: 5);
      final asked = <QuizQuestion>[];
      QuizQuestion? question;
      while ((question = session.nextQuestion()) != null) {
        asked.add(question!);
      }
      expect(asked.length, 5);
      expect(asked.where((q) => q.difficulty == QuizDifficulty.easy).length, 2);
      expect(
          asked.where((q) => q.difficulty == QuizDifficulty.medium).length, 3);
    });

    test('session is capped at sessionLength even with a big pool', () {
      final session = buildSession(sessionLength: 10);
      expect(session.totalQuestions, 10);
      var count = 0;
      while (session.nextQuestion() != null) {
        count++;
      }
      expect(count, 10);
      expect(session.hasNext, isFalse);
    });

    test('totalQuestions shrinks to the pool size for tiny pools', () {
      final questions = buildQuestions(easy: 3, medium: 0, hard: 0);
      final session = buildSession(questions: questions, sessionLength: 10);
      expect(session.totalQuestions, 3);
    });

    test('askedQuestionIds reflects everything served', () {
      final session = buildSession(sessionLength: 4);
      final expected = <String>{};
      QuizQuestion? question;
      while ((question = session.nextQuestion()) != null) {
        expected.add(question!.id);
      }
      expect(session.askedQuestionIds, expected);
    });
  });
}
