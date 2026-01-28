/// Represents the result of a completed quiz
class QuizResult {
  final String categoryId;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final Duration timeTaken;
  final DateTime completedAt;
  final List<QuestionResult> questionResults;

  const QuizResult({
    required this.categoryId,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.timeTaken,
    required this.completedAt,
    required this.questionResults,
  });

  double get scorePercentage => totalQuestions > 0 
      ? (correctAnswers / totalQuestions) * 100 
      : 0.0;

  int get score => correctAnswers;

  String get grade {
    final percentage = scorePercentage;
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  String get encouragement {
    final percentage = scorePercentage;
    if (percentage >= 90) return 'Excellent! MashaAllah!';
    if (percentage >= 80) return 'Great job! Keep learning!';
    if (percentage >= 70) return 'Good work! You\'re doing well!';
    if (percentage >= 60) return 'Nice try! Practice more!';
    if (percentage >= 50) return 'Keep going! You can do it!';
    return 'Don\'t give up! Try again!';
  }

  int get starsEarned {
    final percentage = scorePercentage;
    if (percentage >= 90) return 3;
    if (percentage >= 70) return 2;
    if (percentage >= 50) return 1;
    return 0;
  }
}

/// Result for a single question
class QuestionResult {
  final String questionId;
  final int selectedAnswerIndex;
  final int correctAnswerIndex;
  final bool isCorrect;
  final Duration timeTaken;

  const QuestionResult({
    required this.questionId,
    required this.selectedAnswerIndex,
    required this.correctAnswerIndex,
    required this.isCorrect,
    required this.timeTaken,
  });
}
