/// Represents a single quiz question
class QuizQuestion {
  final String id;
  final String category;
  final String difficulty; // easy, medium, hard
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String? explanation;
  final String? imageUrl;

  const QuizQuestion({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
    this.imageUrl,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      category: json['category'] as String,
      difficulty: json['difficulty'] as String? ?? 'easy',
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswerIndex: json['correctAnswer'] as int,
      explanation: json['explanation'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'difficulty': difficulty,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswerIndex,
      'explanation': explanation,
      'imageUrl': imageUrl,
    };
  }

  String get correctAnswer => options[correctAnswerIndex];

  bool isCorrect(int selectedIndex) => selectedIndex == correctAnswerIndex;
}
