import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

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
    QuizCategory(
      id: 'seerah',
      name: 'Life of the Prophet',
      nameAr: 'السيرة النبوية',
      description: 'The life story of Prophet Muhammad ﷺ',
      icon: Icons.star_rounded,
      color: const Color(0xFF009688), // Teal
      assetPath: 'assets/quizzes/seerah.json',
    ),
    QuizCategory(
      id: 'sahaba',
      name: 'The Companions',
      nameAr: 'الصحابة',
      description: 'The companions of the Prophet ﷺ',
      icon: Icons.groups_rounded,
      color: const Color(0xFF3F51B5), // Indigo
      assetPath: 'assets/quizzes/sahaba.json',
    ),
    QuizCategory(
      id: 'islamic_manners',
      name: 'Islamic Manners',
      nameAr: 'الآداب الإسلامية',
      description: 'Good manners and character (adab)',
      icon: Icons.volunteer_activism_rounded,
      color: const Color(0xFFE91E63), // Pink
      assetPath: 'assets/quizzes/islamic_manners.json',
    ),
  ];
}

/// Category names and descriptions in the app language, keyed by the
/// category id; unknown ids fall back to the English in the model.
String localizedQuizCategoryName(AppLocalizations l10n, QuizCategory c) => switch (c.id) {
  'five_pillars' => l10n.quizCat_five_pillars_name, 'prophets' => l10n.quizCat_prophets_name, 'quran_basics' => l10n.quizCat_quran_basics_name,
  'daily_duas' => l10n.quizCat_daily_duas_name, 'islamic_history' => l10n.quizCat_islamic_history_name, 'arabic_basics' => l10n.quizCat_arabic_letters_name,
  'seerah' => l10n.quizCat_prophet_life_name, 'sahaba' => l10n.quizCat_companions_name, 'islamic_manners' => l10n.quizCat_islamic_manners_name,
  _ => c.name,
};

String localizedQuizCategoryDescription(AppLocalizations l10n, QuizCategory c) => switch (c.id) {
  'five_pillars' => l10n.quizCat_five_pillars_desc, 'prophets' => l10n.quizCat_prophets_desc, 'quran_basics' => l10n.quizCat_quran_basics_desc,
  'daily_duas' => l10n.quizCat_daily_duas_desc, 'islamic_history' => l10n.quizCat_islamic_history_desc, 'arabic_basics' => l10n.quizCat_arabic_letters_desc,
  'seerah' => l10n.quizCat_prophet_life_desc, 'sahaba' => l10n.quizCat_companions_desc, 'islamic_manners' => l10n.quizCat_islamic_manners_desc,
  _ => c.description,
};

/// The encouragement line for a result, in the app language.
String localizedEncouragement(AppLocalizations l10n, int percentage) {
  if (percentage >= 90) return l10n.quizEncourage90;
  if (percentage >= 80) return l10n.quizEncourage80;
  if (percentage >= 70) return l10n.quizEncourage70;
  if (percentage >= 60) return l10n.quizEncourage60;
  if (percentage >= 50) return l10n.quizEncourage50;
  return l10n.quizEncourage0;
}
