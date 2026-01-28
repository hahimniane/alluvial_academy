import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';

/// Service for managing quiz data and logic
class QuizService {
  // Cache loaded questions
  final Map<String, List<QuizQuestion>> _cache = {};

  /// Get questions for a specific category
  Future<List<QuizQuestion>> getQuestionsForCategory(String categoryId) async {
    // Check cache first
    if (_cache.containsKey(categoryId)) {
      return _shuffleQuestions(_cache[categoryId]!);
    }

    // Load from asset file
    final assetPath = _getAssetPath(categoryId);
    
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final questionsJson = jsonData['questions'] as List;
      
      final questions = questionsJson
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
      
      // Cache the questions
      _cache[categoryId] = questions;
      
      return _shuffleQuestions(questions);
    } catch (e) {
      // Return default questions if asset fails to load
      return _getDefaultQuestions(categoryId);
    }
  }

  String _getAssetPath(String categoryId) {
    switch (categoryId) {
      case 'five_pillars':
        return 'assets/quizzes/five_pillars.json';
      case 'prophets':
        return 'assets/quizzes/prophets.json';
      case 'quran_basics':
        return 'assets/quizzes/quran_basics.json';
      case 'daily_duas':
        return 'assets/quizzes/daily_duas.json';
      case 'islamic_history':
        return 'assets/quizzes/islamic_history.json';
      case 'arabic_basics':
        return 'assets/quizzes/arabic_basics.json';
      default:
        return 'assets/quizzes/$categoryId.json';
    }
  }

  List<QuizQuestion> _shuffleQuestions(List<QuizQuestion> questions) {
    final shuffled = List<QuizQuestion>.from(questions);
    shuffled.shuffle();
    // Return first 10 questions for a quiz session
    return shuffled.take(10).toList();
  }

  /// Get default questions when asset files are not available
  List<QuizQuestion> _getDefaultQuestions(String categoryId) {
    switch (categoryId) {
      case 'five_pillars':
        return _fivePillarsQuestions;
      case 'prophets':
        return _prophetsQuestions;
      case 'quran_basics':
        return _quranBasicsQuestions;
      case 'daily_duas':
        return _dailyDuasQuestions;
      case 'islamic_history':
        return _islamicHistoryQuestions;
      case 'arabic_basics':
        return _arabicBasicsQuestions;
      default:
        return [];
    }
  }

  // Default Five Pillars questions
  static final List<QuizQuestion> _fivePillarsQuestions = [
    const QuizQuestion(
      id: 'fp_001',
      category: 'five_pillars',
      difficulty: 'easy',
      question: 'How many pillars of Islam are there?',
      options: ['3', '4', '5', '6'],
      correctAnswerIndex: 2,
      explanation: 'There are 5 pillars of Islam: Shahada, Salah, Zakat, Sawm, and Hajj.',
    ),
    const QuizQuestion(
      id: 'fp_002',
      category: 'five_pillars',
      difficulty: 'easy',
      question: 'What is the first pillar of Islam?',
      options: ['Salah (Prayer)', 'Shahada (Declaration of Faith)', 'Zakat (Charity)', 'Sawm (Fasting)'],
      correctAnswerIndex: 1,
      explanation: 'Shahada is the declaration that there is no god but Allah and Muhammad is His messenger.',
    ),
    const QuizQuestion(
      id: 'fp_003',
      category: 'five_pillars',
      difficulty: 'easy',
      question: 'How many times a day do Muslims pray?',
      options: ['3 times', '4 times', '5 times', '7 times'],
      correctAnswerIndex: 2,
      explanation: 'Muslims pray 5 times a day: Fajr, Dhuhr, Asr, Maghrib, and Isha.',
    ),
    const QuizQuestion(
      id: 'fp_004',
      category: 'five_pillars',
      difficulty: 'easy',
      question: 'What is Zakat?',
      options: ['Fasting', 'Prayer', 'Charity', 'Pilgrimage'],
      correctAnswerIndex: 2,
      explanation: 'Zakat is the obligatory charity that Muslims give to help those in need.',
    ),
    const QuizQuestion(
      id: 'fp_005',
      category: 'five_pillars',
      difficulty: 'easy',
      question: 'During which month do Muslims fast?',
      options: ['Muharram', 'Ramadan', 'Shawwal', 'Dhul Hijjah'],
      correctAnswerIndex: 1,
      explanation: 'Ramadan is the holy month during which Muslims fast from dawn to sunset.',
    ),
    const QuizQuestion(
      id: 'fp_006',
      category: 'five_pillars',
      difficulty: 'medium',
      question: 'What is the pilgrimage to Mecca called?',
      options: ['Umrah', 'Hajj', 'Salah', 'Tawaf'],
      correctAnswerIndex: 1,
      explanation: 'Hajj is the annual pilgrimage to Mecca that every able Muslim should perform at least once.',
    ),
    const QuizQuestion(
      id: 'fp_007',
      category: 'five_pillars',
      difficulty: 'medium',
      question: 'Which prayer is performed before sunrise?',
      options: ['Dhuhr', 'Asr', 'Fajr', 'Isha'],
      correctAnswerIndex: 2,
      explanation: 'Fajr is the dawn prayer performed before sunrise.',
    ),
    const QuizQuestion(
      id: 'fp_008',
      category: 'five_pillars',
      difficulty: 'easy',
      question: 'What do Muslims do during Sawm (fasting)?',
      options: ['Pray extra prayers', 'Give charity', 'Not eat or drink from dawn to sunset', 'Visit Mecca'],
      correctAnswerIndex: 2,
      explanation: 'During Sawm, Muslims abstain from food and drink from dawn until sunset.',
    ),
  ];

  // Default Prophets questions
  static final List<QuizQuestion> _prophetsQuestions = [
    const QuizQuestion(
      id: 'pr_001',
      category: 'prophets',
      difficulty: 'easy',
      question: 'Who was the first Prophet in Islam?',
      options: ['Prophet Muhammad', 'Prophet Ibrahim', 'Prophet Adam', 'Prophet Nuh'],
      correctAnswerIndex: 2,
      explanation: 'Prophet Adam (peace be upon him) was the first human and the first Prophet.',
    ),
    const QuizQuestion(
      id: 'pr_002',
      category: 'prophets',
      difficulty: 'easy',
      question: 'Who is the last Prophet in Islam?',
      options: ['Prophet Isa', 'Prophet Musa', 'Prophet Muhammad', 'Prophet Ibrahim'],
      correctAnswerIndex: 2,
      explanation: 'Prophet Muhammad (peace be upon him) is the last and final Prophet.',
    ),
    const QuizQuestion(
      id: 'pr_003',
      category: 'prophets',
      difficulty: 'easy',
      question: 'Which Prophet built the Kaaba with his son?',
      options: ['Prophet Nuh', 'Prophet Ibrahim', 'Prophet Musa', 'Prophet Sulaiman'],
      correctAnswerIndex: 1,
      explanation: 'Prophet Ibrahim and his son Ismail built the Kaaba in Mecca.',
    ),
    const QuizQuestion(
      id: 'pr_004',
      category: 'prophets',
      difficulty: 'medium',
      question: 'Which Prophet survived the great flood with his Ark?',
      options: ['Prophet Adam', 'Prophet Nuh', 'Prophet Yunus', 'Prophet Dawud'],
      correctAnswerIndex: 1,
      explanation: 'Prophet Nuh (Noah) built an Ark and survived the great flood with the believers.',
    ),
    const QuizQuestion(
      id: 'pr_005',
      category: 'prophets',
      difficulty: 'easy',
      question: 'Which Prophet was swallowed by a whale?',
      options: ['Prophet Musa', 'Prophet Yunus', 'Prophet Ayyub', 'Prophet Yusuf'],
      correctAnswerIndex: 1,
      explanation: 'Prophet Yunus (Jonah) was swallowed by a whale and prayed to Allah for forgiveness.',
    ),
    const QuizQuestion(
      id: 'pr_006',
      category: 'prophets',
      difficulty: 'medium',
      question: 'Which Prophet could talk to animals?',
      options: ['Prophet Dawud', 'Prophet Sulaiman', 'Prophet Yusuf', 'Prophet Isa'],
      correctAnswerIndex: 1,
      explanation: 'Prophet Sulaiman (Solomon) was given the ability to understand and communicate with animals.',
    ),
  ];

  // Default Quran Basics questions
  static final List<QuizQuestion> _quranBasicsQuestions = [
    const QuizQuestion(
      id: 'qb_001',
      category: 'quran_basics',
      difficulty: 'easy',
      question: 'How many chapters (Surahs) are in the Quran?',
      options: ['100', '114', '120', '150'],
      correctAnswerIndex: 1,
      explanation: 'The Quran has 114 Surahs (chapters).',
    ),
    const QuizQuestion(
      id: 'qb_002',
      category: 'quran_basics',
      difficulty: 'easy',
      question: 'What is the first Surah of the Quran?',
      options: ['Al-Baqarah', 'Al-Fatiha', 'Al-Ikhlas', 'An-Nas'],
      correctAnswerIndex: 1,
      explanation: 'Al-Fatiha is the opening chapter of the Quran.',
    ),
    const QuizQuestion(
      id: 'qb_003',
      category: 'quran_basics',
      difficulty: 'easy',
      question: 'In which month was the Quran revealed?',
      options: ['Shawwal', 'Ramadan', 'Muharram', 'Rajab'],
      correctAnswerIndex: 1,
      explanation: 'The Quran was first revealed to Prophet Muhammad in the month of Ramadan.',
    ),
    const QuizQuestion(
      id: 'qb_004',
      category: 'quran_basics',
      difficulty: 'medium',
      question: 'Who brought the Quran to Prophet Muhammad?',
      options: ['Angel Mikail', 'Angel Jibril', 'Angel Israfil', 'Angel Azrael'],
      correctAnswerIndex: 1,
      explanation: 'Angel Jibril (Gabriel) brought the revelation of the Quran to Prophet Muhammad.',
    ),
    const QuizQuestion(
      id: 'qb_005',
      category: 'quran_basics',
      difficulty: 'easy',
      question: 'What is the longest Surah in the Quran?',
      options: ['Al-Fatiha', 'Al-Baqarah', 'Al-Imran', 'An-Nisa'],
      correctAnswerIndex: 1,
      explanation: 'Al-Baqarah (The Cow) is the longest Surah with 286 verses.',
    ),
  ];

  // Default Daily Duas questions
  static final List<QuizQuestion> _dailyDuasQuestions = [
    const QuizQuestion(
      id: 'dd_001',
      category: 'daily_duas',
      difficulty: 'easy',
      question: 'What do we say before eating?',
      options: ['Alhamdulillah', 'Bismillah', 'SubhanAllah', 'Astaghfirullah'],
      correctAnswerIndex: 1,
      explanation: 'We say "Bismillah" (In the name of Allah) before eating.',
    ),
    const QuizQuestion(
      id: 'dd_002',
      category: 'daily_duas',
      difficulty: 'easy',
      question: 'What do we say after eating?',
      options: ['Bismillah', 'Alhamdulillah', 'MashaAllah', 'InshaAllah'],
      correctAnswerIndex: 1,
      explanation: 'We say "Alhamdulillah" (All praise is due to Allah) after eating.',
    ),
    const QuizQuestion(
      id: 'dd_003',
      category: 'daily_duas',
      difficulty: 'easy',
      question: 'What does "As-salamu Alaykum" mean?',
      options: ['Goodbye', 'Peace be upon you', 'Thank you', 'Please'],
      correctAnswerIndex: 1,
      explanation: '"As-salamu Alaykum" means "Peace be upon you" and is the Islamic greeting.',
    ),
    const QuizQuestion(
      id: 'dd_004',
      category: 'daily_duas',
      difficulty: 'easy',
      question: 'What do we say when we sneeze?',
      options: ['SubhanAllah', 'Alhamdulillah', 'Allahu Akbar', 'Astaghfirullah'],
      correctAnswerIndex: 1,
      explanation: 'We say "Alhamdulillah" when we sneeze, thanking Allah.',
    ),
    const QuizQuestion(
      id: 'dd_005',
      category: 'daily_duas',
      difficulty: 'easy',
      question: 'What do we say before going to sleep?',
      options: ['Bismillah', 'Allahumma bismika amutu wa ahya', 'SubhanAllah', 'Allahu Akbar'],
      correctAnswerIndex: 1,
      explanation: 'Before sleeping, we say "Allahumma bismika amutu wa ahya" (O Allah, in Your name I die and live).',
    ),
  ];

  // Default Islamic History questions
  static final List<QuizQuestion> _islamicHistoryQuestions = [
    const QuizQuestion(
      id: 'ih_001',
      category: 'islamic_history',
      difficulty: 'easy',
      question: 'What is the Hijrah?',
      options: ['A prayer', 'Migration from Mecca to Medina', 'A battle', 'A festival'],
      correctAnswerIndex: 1,
      explanation: 'The Hijrah was Prophet Muhammad\'s migration from Mecca to Medina in 622 CE.',
    ),
    const QuizQuestion(
      id: 'ih_002',
      category: 'islamic_history',
      difficulty: 'easy',
      question: 'Which city is known as the birthplace of Prophet Muhammad?',
      options: ['Medina', 'Jerusalem', 'Mecca', 'Damascus'],
      correctAnswerIndex: 2,
      explanation: 'Prophet Muhammad was born in Mecca, Saudi Arabia.',
    ),
    const QuizQuestion(
      id: 'ih_003',
      category: 'islamic_history',
      difficulty: 'easy',
      question: 'What is Eid al-Fitr?',
      options: ['Day of sacrifice', 'Festival after Ramadan', 'Friday prayer', 'Night of Power'],
      correctAnswerIndex: 1,
      explanation: 'Eid al-Fitr is the festival celebrating the end of Ramadan.',
    ),
    const QuizQuestion(
      id: 'ih_004',
      category: 'islamic_history',
      difficulty: 'medium',
      question: 'What is Eid al-Adha?',
      options: ['End of Ramadan', 'Festival of Sacrifice', 'New Year', 'Prophet\'s birthday'],
      correctAnswerIndex: 1,
      explanation: 'Eid al-Adha is the Festival of Sacrifice, commemorating Prophet Ibrahim\'s willingness to sacrifice his son.',
    ),
    const QuizQuestion(
      id: 'ih_005',
      category: 'islamic_history',
      difficulty: 'medium',
      question: 'What is Laylat al-Qadr?',
      options: ['First day of Ramadan', 'Night of Power', 'Day of Arafah', 'Last day of Hajj'],
      correctAnswerIndex: 1,
      explanation: 'Laylat al-Qadr (Night of Power) is the night when the Quran was first revealed.',
    ),
  ];

  // Default Arabic Basics questions
  static final List<QuizQuestion> _arabicBasicsQuestions = [
    const QuizQuestion(
      id: 'ab_001',
      category: 'arabic_basics',
      difficulty: 'easy',
      question: 'What is the first letter of the Arabic alphabet?',
      options: ['Ba', 'Alif', 'Ta', 'Jim'],
      correctAnswerIndex: 1,
      explanation: 'Alif (أ) is the first letter of the Arabic alphabet.',
    ),
    const QuizQuestion(
      id: 'ab_002',
      category: 'arabic_basics',
      difficulty: 'easy',
      question: 'How many letters are in the Arabic alphabet?',
      options: ['24', '26', '28', '30'],
      correctAnswerIndex: 2,
      explanation: 'The Arabic alphabet has 28 letters.',
    ),
    const QuizQuestion(
      id: 'ab_003',
      category: 'arabic_basics',
      difficulty: 'easy',
      question: 'What does "Allah" mean?',
      options: ['Prophet', 'God', 'Angel', 'Book'],
      correctAnswerIndex: 1,
      explanation: 'Allah is the Arabic word for God.',
    ),
    const QuizQuestion(
      id: 'ab_004',
      category: 'arabic_basics',
      difficulty: 'easy',
      question: 'In which direction do you read Arabic?',
      options: ['Left to right', 'Right to left', 'Top to bottom', 'Bottom to top'],
      correctAnswerIndex: 1,
      explanation: 'Arabic is read from right to left.',
    ),
    const QuizQuestion(
      id: 'ab_005',
      category: 'arabic_basics',
      difficulty: 'easy',
      question: 'What does "Shukran" mean?',
      options: ['Hello', 'Goodbye', 'Thank you', 'Please'],
      correctAnswerIndex: 2,
      explanation: 'Shukran means "Thank you" in Arabic.',
    ),
  ];
}
