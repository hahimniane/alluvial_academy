import 'package:flutter/material.dart';

/// Represents a quiz category
class QuizCategory {
  final String id;
  final String name;
  final String nameAr; // Arabic name
  final String description;
  final IconData icon;
  final Color color;
  final String assetPath; // JSON file path
  final int totalQuestions;
  final int completedQuestions;

  const QuizCategory({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.description,
    required this.icon,
    required this.color,
    required this.assetPath,
    this.totalQuestions = 0,
    this.completedQuestions = 0,
  });

  double get progress => totalQuestions > 0 
      ? completedQuestions / totalQuestions 
      : 0.0;

  bool get isCompleted => completedQuestions >= totalQuestions && totalQuestions > 0;

  /// Default Islamic quiz categories for kids
  static List<QuizCategory> get defaultCategories => [
    QuizCategory(
      id: 'five_pillars',
      name: 'Five Pillars',
      nameAr: 'أركان الإسلام',
      description: 'Learn about the 5 pillars of Islam',
      icon: Icons.mosque_rounded,
      color: const Color(0xFF4CAF50), // Green
      assetPath: 'assets/quizzes/five_pillars.json',
    ),
    QuizCategory(
      id: 'prophets',
      name: 'Prophets',
      nameAr: 'الأنبياء',
      description: 'Stories of the Prophets',
      icon: Icons.auto_stories_rounded,
      color: const Color(0xFF2196F3), // Blue
      assetPath: 'assets/quizzes/prophets.json',
    ),
    QuizCategory(
      id: 'quran_basics',
      name: 'Quran Basics',
      nameAr: 'أساسيات القرآن',
      description: 'Learn about the Holy Quran',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF9C27B0), // Purple
      assetPath: 'assets/quizzes/quran_basics.json',
    ),
    QuizCategory(
      id: 'daily_duas',
      name: 'Daily Duas',
      nameAr: 'أدعية يومية',
      description: 'Everyday prayers and supplications',
      icon: Icons.front_hand_rounded,
      color: const Color(0xFFFF9800), // Orange
      assetPath: 'assets/quizzes/daily_duas.json',
    ),
    QuizCategory(
      id: 'islamic_history',
      name: 'Islamic History',
      nameAr: 'التاريخ الإسلامي',
      description: 'Important events in Islamic history',
      icon: Icons.history_edu_rounded,
      color: const Color(0xFF795548), // Brown
      assetPath: 'assets/quizzes/islamic_history.json',
    ),
    QuizCategory(
      id: 'arabic_basics',
      name: 'Arabic Letters',
      nameAr: 'الحروف العربية',
      description: 'Learn Arabic letters and words',
      icon: Icons.translate_rounded,
      color: const Color(0xFF00BCD4), // Cyan
      assetPath: 'assets/quizzes/arabic_basics.json',
    ),
  ];
}
