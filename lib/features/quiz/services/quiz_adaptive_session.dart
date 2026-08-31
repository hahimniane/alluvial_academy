import 'dart:math';

import '../models/quiz_question.dart';

/// Adaptive question picker for a single quiz session.
///
/// Difficulty climbs after consecutive correct answers and steps back down
/// after consecutive wrong ones. Questions the student has already seen in
/// past sessions are avoided until the whole pool has been seen.
class QuizAdaptiveSession {
  QuizAdaptiveSession({
    required List<QuizQuestion> questions,
    Set<String> seenQuestionIds = const {},
    String startingDifficulty = QuizDifficulty.easy,
    this.sessionLength = 10,
    Random? random,
  }) : _random = random ?? Random() {
    _tierIndex = QuizDifficulty.tiers.indexOf(startingDifficulty);
    if (_tierIndex < 0) _tierIndex = 0;
    for (final tier in QuizDifficulty.tiers) {
      _unseen[tier] = [];
      _seen[tier] = [];
    }
    for (final question in questions) {
      final tier = QuizDifficulty.tiers.contains(question.difficulty)
          ? question.difficulty
          : QuizDifficulty.easy;
      (seenQuestionIds.contains(question.id) ? _seen : _unseen)[tier]!
          .add(question);
    }
    for (final tier in QuizDifficulty.tiers) {
      _unseen[tier]!.shuffle(_random);
      _seen[tier]!.shuffle(_random);
    }
    _totalAvailable = questions.length;
  }

  final int sessionLength;
  final Random _random;

  final Map<String, List<QuizQuestion>> _unseen = {};
  final Map<String, List<QuizQuestion>> _seen = {};
  final List<QuizQuestion> _asked = [];

  int _tierIndex = 0;
  int _correctStreak = 0;
  int _wrongStreak = 0;
  int _totalAvailable = 0;

  static const int _streakToAdvance = 2;

  String get currentDifficulty => QuizDifficulty.tiers[_tierIndex];

  int get totalQuestions =>
      sessionLength < _totalAvailable ? sessionLength : _totalAvailable;

  bool get hasNext => _asked.length < totalQuestions;

  List<QuizQuestion> get askedQuestions => List.unmodifiable(_asked);

  Set<String> get askedQuestionIds => _asked.map((q) => q.id).toSet();

  /// Returns the next question at (or nearest to) the current difficulty,
  /// or null when the session is complete.
  QuizQuestion? nextQuestion() {
    if (!hasNext) return null;
    final question = _takeFromTier(_tierIndex);
    if (question == null) return null;
    _asked.add(question);
    return question;
  }

  /// Records whether the last question was answered correctly and adjusts
  /// the difficulty tier for upcoming questions.
  void recordAnswer(bool isCorrect) {
    if (isCorrect) {
      _correctStreak++;
      _wrongStreak = 0;
      if (_correctStreak >= _streakToAdvance &&
          _tierIndex < QuizDifficulty.tiers.length - 1) {
        _tierIndex++;
        _correctStreak = 0;
      }
    } else {
      _wrongStreak++;
      _correctStreak = 0;
      if (_wrongStreak >= _streakToAdvance && _tierIndex > 0) {
        _tierIndex--;
        _wrongStreak = 0;
      }
    }
  }

  QuizQuestion? _takeFromTier(int preferredTier) {
    // Try the preferred tier first, then the closest tiers (easier first),
    // preferring unseen questions everywhere before recycling seen ones.
    final order = _tierSearchOrder(preferredTier);
    for (final tier in order) {
      final pool = _unseen[QuizDifficulty.tiers[tier]]!;
      if (pool.isNotEmpty) return pool.removeLast();
    }
    for (final tier in order) {
      final pool = _seen[QuizDifficulty.tiers[tier]]!;
      if (pool.isNotEmpty) return pool.removeLast();
    }
    return null;
  }

  List<int> _tierSearchOrder(int preferred) {
    final order = <int>[preferred];
    for (var distance = 1; distance < QuizDifficulty.tiers.length; distance++) {
      if (preferred - distance >= 0) order.add(preferred - distance);
      if (preferred + distance < QuizDifficulty.tiers.length) {
        order.add(preferred + distance);
      }
    }
    return order;
  }
}

class QuizDifficulty {
  static const String easy = 'easy';
  static const String medium = 'medium';
  static const String hard = 'hard';
  static const List<String> tiers = [easy, medium, hard];
}
