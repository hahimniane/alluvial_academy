import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

import '../constants/pricing_plan_ids.dart'
    show PricingPlanIds, kAfterSchoolTutoringSubject;

/// Subject strings must match [ProgramSelectionPage] / enrollment expectations.
const String kIslamicProgramSubject =
    'Islamic Program (Arabic, Quran, etc...)';
const String kAfroLanguagesSubject =
    'AfroLanguages (Pular, Mandingo, Swahili, Wolof, etc...)';
const String kAdultLiteracySubject =
    'Adult Literacy (Reading and Writing English & French, etc...)';

/// One row in the unified catalog (localized strings resolved via [AppLocalizations]).
class ProgramItem {
  const ProgramItem({
    required this.id,
    required this.title,
    required this.description,
    required this.features,
    required this.ageGroupLabel,
    required this.emoji,
    required this.accentColor,
    required this.enrollSubject,
    required this.trackId,
    this.enrollLanguage,
    this.isLanguageSelection = false,
  });

  final String id;
  final String title;
  final String description;
  final List<String> features;
  final String ageGroupLabel;
  final String emoji;
  final Color accentColor;
  final String enrollSubject;
  final String trackId;
  final String? enrollLanguage;
  final bool isLanguageSelection;
}

class ProgramCategory {
  const ProgramCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.emoji,
    required this.color,
    required this.programs,
    required this.enrollSubject,
    required this.trackId,
    this.isLanguageSelection = false,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String emoji;
  final Color color;
  final List<ProgramItem> programs;

  /// Used when the entire program is selected for enrollment.
  final String enrollSubject;
  final String trackId;
  final bool isLanguageSelection;
}

class _RawProgram {
  const _RawProgram({
    required this.id,
    required this.categoryId,
    required this.trackId,
    required this.enrollSubject,
    required this.emoji,
    required this.accentArgb,
    this.enrollLanguage,
    this.isLanguageSelection = false,
  });

  final String id;
  final String categoryId;
  final String trackId;
  final String enrollSubject;
  final String? enrollLanguage;
  final bool isLanguageSelection;
  final String emoji;
  final int accentArgb;
}

abstract final class ProgramCatalog {
  static const String catIslamic = 'islamic';
  static const String catLanguages = 'languages';
  static const String catEnglish = 'english';
  static const String catMath = 'math';
  static const String catProgramming = 'programming';
  static const String catAfterSchool = 'afterschool';

  static const List<String> categoryIds = [
    catIslamic,
    catLanguages,
    catEnglish,
    catMath,
    catProgramming,
    catAfterSchool,
  ];

  static const List<_RawProgram> _rawPrograms = [
    // Islamic — track islamic
    _RawProgram(
      id: 'islam_quran',
      categoryId: catIslamic,
      trackId: PricingPlanIds.islamic,
      enrollSubject: kIslamicProgramSubject,
      emoji: '📖',
      accentArgb: 0xFF3B82F6,
    ),
    _RawProgram(
      id: 'islam_hadith',
      categoryId: catIslamic,
      trackId: PricingPlanIds.islamic,
      enrollSubject: kIslamicProgramSubject,
      emoji: '📚',
      accentArgb: 0xFF10B981,
    ),
    _RawProgram(
      id: 'islam_arabic',
      categoryId: catIslamic,
      trackId: PricingPlanIds.islamic,
      enrollSubject: kIslamicProgramSubject,
      emoji: '🇸🇦',
      accentArgb: 0xFFF59E0B,
    ),
    _RawProgram(
      id: 'islam_tawhid',
      categoryId: catIslamic,
      trackId: PricingPlanIds.islamic,
      enrollSubject: kIslamicProgramSubject,
      emoji: '☪️',
      accentArgb: 0xFF8B5CF6,
    ),
    _RawProgram(
      id: 'islam_tafsir',
      categoryId: catIslamic,
      trackId: PricingPlanIds.islamic,
      enrollSubject: kIslamicProgramSubject,
      emoji: '📜',
      accentArgb: 0xFFEF4444,
    ),
    _RawProgram(
      id: 'islam_fiqh',
      categoryId: catIslamic,
      trackId: PricingPlanIds.islamic,
      enrollSubject: kIslamicProgramSubject,
      emoji: '🕌',
      accentArgb: 0xFF06B6D4,
    ),
    // Languages — tutoring; English/French/Adlam use language-selection dropdown
    _RawProgram(
      id: 'lang_english',
      categoryId: catLanguages,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: 'English',
      emoji: '🇬🇧',
      accentArgb: 0xFF3B82F6,
      isLanguageSelection: true,
    ),
    _RawProgram(
      id: 'lang_french',
      categoryId: catLanguages,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: 'French',
      emoji: '🇫🇷',
      accentArgb: 0xFF6366F1,
      isLanguageSelection: true,
    ),
    _RawProgram(
      id: 'lang_adlam',
      categoryId: catLanguages,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: 'Adlam',
      emoji: '🔤',
      accentArgb: 0xFF8B5CF6,
      isLanguageSelection: true,
    ),
    _RawProgram(
      id: 'lang_swahili',
      categoryId: catLanguages,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfroLanguagesSubject,
      enrollLanguage: 'Swahili',
      emoji: '🇹🇿',
      accentArgb: 0xFF10B981,
    ),
    _RawProgram(
      id: 'lang_yoruba',
      categoryId: catLanguages,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfroLanguagesSubject,
      enrollLanguage: 'Yoruba',
      emoji: '🇳🇬',
      accentArgb: 0xFF8B5CF6,
    ),
    _RawProgram(
      id: 'lang_amharic',
      categoryId: catLanguages,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfroLanguagesSubject,
      enrollLanguage: 'Amharic',
      emoji: '🇪🇹',
      accentArgb: 0xFFEF4444,
    ),
    _RawProgram(
      id: 'lang_wolof',
      categoryId: catLanguages,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfroLanguagesSubject,
      enrollLanguage: 'Wolof',
      emoji: '🇸🇳',
      accentArgb: 0xFF06B6D4,
    ),
    _RawProgram(
      id: 'lang_hausa',
      categoryId: catLanguages,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfroLanguagesSubject,
      enrollLanguage: 'Hausa',
      emoji: '🇳🇬',
      accentArgb: 0xFFF59E0B,
    ),
    // English & literacy topics — adult literacy subject
    _RawProgram(
      id: 'lit_grammar',
      categoryId: catEnglish,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAdultLiteracySubject,
      emoji: '📝',
      accentArgb: 0xFF10B981,
    ),
    _RawProgram(
      id: 'lit_reading',
      categoryId: catEnglish,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAdultLiteracySubject,
      emoji: '📖',
      accentArgb: 0xFF3B82F6,
    ),
    _RawProgram(
      id: 'lit_creative',
      categoryId: catEnglish,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAdultLiteracySubject,
      emoji: '✍️',
      accentArgb: 0xFF8B5CF6,
    ),
    _RawProgram(
      id: 'lit_academic',
      categoryId: catEnglish,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAdultLiteracySubject,
      emoji: '📄',
      accentArgb: 0xFFEF4444,
    ),
    _RawProgram(
      id: 'lit_literature',
      categoryId: catEnglish,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAdultLiteracySubject,
      emoji: '📚',
      accentArgb: 0xFF06B6D4,
    ),
    _RawProgram(
      id: 'lit_testprep',
      categoryId: catEnglish,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAdultLiteracySubject,
      emoji: '🎯',
      accentArgb: 0xFFF59E0B,
    ),
    // Math — after-school subject (legacy page behavior)
    _RawProgram(
      id: 'math_elem',
      categoryId: catMath,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfterSchoolTutoringSubject,
      emoji: '➕',
      accentArgb: 0xFF10B981,
    ),
    _RawProgram(
      id: 'math_algebra',
      categoryId: catMath,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfterSchoolTutoringSubject,
      emoji: '🔢',
      accentArgb: 0xFFF59E0B,
    ),
    _RawProgram(
      id: 'math_geometry',
      categoryId: catMath,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfterSchoolTutoringSubject,
      emoji: '📐',
      accentArgb: 0xFF8B5CF6,
    ),
    _RawProgram(
      id: 'math_trig',
      categoryId: catMath,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfterSchoolTutoringSubject,
      emoji: '📏',
      accentArgb: 0xFFEF4444,
    ),
    _RawProgram(
      id: 'math_calc',
      categoryId: catMath,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfterSchoolTutoringSubject,
      emoji: '∫',
      accentArgb: 0xFF06B6D4,
    ),
    _RawProgram(
      id: 'math_stats',
      categoryId: catMath,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfterSchoolTutoringSubject,
      emoji: '📊',
      accentArgb: 0xFF3B82F6,
    ),
    // Programming
    _RawProgram(
      id: 'code_kids',
      categoryId: catProgramming,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: 'Coding',
      emoji: '🧒',
      accentArgb: 0xFFF59E0B,
    ),
    _RawProgram(
      id: 'code_web',
      categoryId: catProgramming,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: 'Coding',
      emoji: '🌐',
      accentArgb: 0xFF3B82F6,
    ),
    _RawProgram(
      id: 'code_mobile',
      categoryId: catProgramming,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: 'Coding',
      emoji: '📱',
      accentArgb: 0xFF10B981,
    ),
    _RawProgram(
      id: 'code_python',
      categoryId: catProgramming,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: 'Coding',
      emoji: '🐍',
      accentArgb: 0xFF8B5CF6,
    ),
    _RawProgram(
      id: 'code_game',
      categoryId: catProgramming,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: 'Coding',
      emoji: '🎮',
      accentArgb: 0xFFEF4444,
    ),
    _RawProgram(
      id: 'code_cs',
      categoryId: catProgramming,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: 'Coding',
      emoji: '💻',
      accentArgb: 0xFF06B6D4,
    ),
    // After-school / K–12 bands
    _RawProgram(
      id: 'as_elem',
      categoryId: catAfterSchool,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfterSchoolTutoringSubject,
      emoji: '🎒',
      accentArgb: 0xFF10B981,
    ),
    _RawProgram(
      id: 'as_middle',
      categoryId: catAfterSchool,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfterSchoolTutoringSubject,
      emoji: '📘',
      accentArgb: 0xFF3B82F6,
    ),
    _RawProgram(
      id: 'as_high',
      categoryId: catAfterSchool,
      trackId: PricingPlanIds.tutoring,
      enrollSubject: kAfterSchoolTutoringSubject,
      emoji: '🎓',
      accentArgb: 0xFF8B5CF6,
    ),
  ];

  static String? categoryIdForProgram(String programId) {
    for (final r in _rawPrograms) {
      if (r.id == programId) return r.categoryId;
    }
    return null;
  }

  static ProgramItem? findProgramById(AppLocalizations loc, String programId) {
    for (final r in _rawPrograms) {
      if (r.id == programId) return _toItem(loc, r);
    }
    return null;
  }

  /// Maps landing search subjects to unified deep link; `programId` may be null (category only).
  static ({String categoryId, String? programId})? landingSearchRoute(
      String subject) {
    switch (subject) {
      case kIslamicProgramSubject:
        return (categoryId: catIslamic, programId: null);
      case kAfroLanguagesSubject:
        return (categoryId: catLanguages, programId: null);
      case kAfterSchoolTutoringSubject:
        return (categoryId: catAfterSchool, programId: null);
      case kAdultLiteracySubject:
        return (categoryId: catEnglish, programId: null);
      case 'Coding':
        return (categoryId: catProgramming, programId: null);
      case 'Entrepreneurship':
        return null;
      default:
        return null;
    }
  }

  static List<ProgramCategory> categories(AppLocalizations loc) {
    final items = _rawPrograms.map((r) => _toItem(loc, r)).toList();
    final byCat = <String, List<ProgramItem>>{};
    for (var i = 0; i < _rawPrograms.length; i++) {
      final cid = _rawPrograms[i].categoryId;
      byCat.putIfAbsent(cid, () => []).add(items[i]);
    }

    ProgramCategory cat(
      String id,
      String title,
      String description,
      String emoji,
      IconData icon,
      Color color, {
      required String enrollSubject,
      required String trackId,
      bool isLanguageSelection = false,
    }) {
      return ProgramCategory(
        id: id,
        title: title,
        description: description,
        emoji: emoji,
        icon: icon,
        color: color,
        programs: List<ProgramItem>.unmodifiable(byCat[id] ?? const []),
        enrollSubject: enrollSubject,
        trackId: trackId,
        isLanguageSelection: isLanguageSelection,
      );
    }

    return [
      cat(
        catIslamic,
        loc.unifiedCatIslamicTitle,
        loc.unifiedCatIslamicDesc,
        '🕌',
        Icons.mosque_rounded,
        const Color(0xFF3B82F6),
        enrollSubject: kIslamicProgramSubject,
        trackId: PricingPlanIds.islamic,
      ),
      cat(
        catLanguages,
        loc.unifiedCatLanguagesTitle,
        loc.unifiedCatLanguagesDesc,
        '🌍',
        Icons.language_rounded,
        const Color(0xFFF59E0B),
        enrollSubject: kAfroLanguagesSubject,
        trackId: PricingPlanIds.tutoring,
        isLanguageSelection: true,
      ),
      cat(
        catEnglish,
        loc.unifiedCatEnglishTitle,
        loc.unifiedCatEnglishDesc,
        '📖',
        Icons.menu_book_rounded,
        const Color(0xFFF59E0B),
        enrollSubject: kAdultLiteracySubject,
        trackId: PricingPlanIds.tutoring,
      ),
      cat(
        catMath,
        loc.unifiedCatMathTitle,
        loc.unifiedCatMathDesc,
        '📐',
        Icons.functions_rounded,
        const Color(0xFF3B82F6),
        enrollSubject: kAfterSchoolTutoringSubject,
        trackId: PricingPlanIds.tutoring,
      ),
      cat(
        catProgramming,
        loc.unifiedCatProgrammingTitle,
        loc.unifiedCatProgrammingDesc,
        '💻',
        Icons.code_rounded,
        const Color(0xFF111827),
        enrollSubject: 'Coding',
        trackId: PricingPlanIds.tutoring,
      ),
      cat(
        catAfterSchool,
        loc.unifiedCatAfterSchoolTitle,
        loc.unifiedCatAfterSchoolDesc,
        '🎒',
        Icons.school_rounded,
        const Color(0xFF10B981),
        enrollSubject: kAfterSchoolTutoringSubject,
        trackId: PricingPlanIds.tutoring,
      ),
    ];
  }

  static ProgramItem _toItem(AppLocalizations loc, _RawProgram r) {
    final t = _strings(loc, r.id);
    return ProgramItem(
      id: r.id,
      title: t.title,
      description: t.desc,
      features: [t.f1, t.f2, t.f3],
      ageGroupLabel: t.age,
      emoji: r.emoji,
      accentColor: Color(r.accentArgb),
      enrollSubject: r.enrollSubject,
      trackId: r.trackId,
      enrollLanguage: r.enrollLanguage,
      isLanguageSelection: r.isLanguageSelection,
    );
  }

  static ({String title, String desc, String age, String f1, String f2, String f3})
      _strings(AppLocalizations loc, String id) {
    switch (id) {
      case 'islam_quran':
        return (
          title: loc.unifiedProgIslamQuranTitle,
          desc: loc.unifiedProgIslamQuranDesc,
          age: loc.unifiedProgIslamQuranAge,
          f1: loc.unifiedProgIslamQuranFeat1,
          f2: loc.unifiedProgIslamQuranFeat2,
          f3: loc.unifiedProgIslamQuranFeat3,
        );
      case 'islam_hadith':
        return (
          title: loc.unifiedProgIslamHadithTitle,
          desc: loc.unifiedProgIslamHadithDesc,
          age: loc.unifiedProgIslamHadithAge,
          f1: loc.unifiedProgIslamHadithFeat1,
          f2: loc.unifiedProgIslamHadithFeat2,
          f3: loc.unifiedProgIslamHadithFeat3,
        );
      case 'islam_arabic':
        return (
          title: loc.unifiedProgIslamArabicTitle,
          desc: loc.unifiedProgIslamArabicDesc,
          age: loc.unifiedProgIslamArabicAge,
          f1: loc.unifiedProgIslamArabicFeat1,
          f2: loc.unifiedProgIslamArabicFeat2,
          f3: loc.unifiedProgIslamArabicFeat3,
        );
      case 'islam_tawhid':
        return (
          title: loc.unifiedProgIslamTawhidTitle,
          desc: loc.unifiedProgIslamTawhidDesc,
          age: loc.unifiedProgIslamTawhidAge,
          f1: loc.unifiedProgIslamTawhidFeat1,
          f2: loc.unifiedProgIslamTawhidFeat2,
          f3: loc.unifiedProgIslamTawhidFeat3,
        );
      case 'islam_tafsir':
        return (
          title: loc.unifiedProgIslamTafsirTitle,
          desc: loc.unifiedProgIslamTafsirDesc,
          age: loc.unifiedProgIslamTafsirAge,
          f1: loc.unifiedProgIslamTafsirFeat1,
          f2: loc.unifiedProgIslamTafsirFeat2,
          f3: loc.unifiedProgIslamTafsirFeat3,
        );
      case 'islam_fiqh':
        return (
          title: loc.unifiedProgIslamFiqhTitle,
          desc: loc.unifiedProgIslamFiqhDesc,
          age: loc.unifiedProgIslamFiqhAge,
          f1: loc.unifiedProgIslamFiqhFeat1,
          f2: loc.unifiedProgIslamFiqhFeat2,
          f3: loc.unifiedProgIslamFiqhFeat3,
        );
      case 'lang_english':
        return (
          title: loc.unifiedProgLangEnglishTitle,
          desc: loc.unifiedProgLangEnglishDesc,
          age: loc.unifiedProgLangEnglishAge,
          f1: loc.unifiedProgLangEnglishFeat1,
          f2: loc.unifiedProgLangEnglishFeat2,
          f3: loc.unifiedProgLangEnglishFeat3,
        );
      case 'lang_french':
        return (
          title: loc.unifiedProgLangFrenchTitle,
          desc: loc.unifiedProgLangFrenchDesc,
          age: loc.unifiedProgLangFrenchAge,
          f1: loc.unifiedProgLangFrenchFeat1,
          f2: loc.unifiedProgLangFrenchFeat2,
          f3: loc.unifiedProgLangFrenchFeat3,
        );
      case 'lang_adlam':
        return (
          title: loc.unifiedProgLangAdlamTitle,
          desc: loc.unifiedProgLangAdlamDesc,
          age: loc.unifiedProgLangAdlamAge,
          f1: loc.unifiedProgLangAdlamFeat1,
          f2: loc.unifiedProgLangAdlamFeat2,
          f3: loc.unifiedProgLangAdlamFeat3,
        );
      case 'lang_swahili':
        return (
          title: loc.unifiedProgLangSwahiliTitle,
          desc: loc.unifiedProgLangSwahiliDesc,
          age: loc.unifiedProgLangSwahiliAge,
          f1: loc.unifiedProgLangSwahiliFeat1,
          f2: loc.unifiedProgLangSwahiliFeat2,
          f3: loc.unifiedProgLangSwahiliFeat3,
        );
      case 'lang_yoruba':
        return (
          title: loc.unifiedProgLangYorubaTitle,
          desc: loc.unifiedProgLangYorubaDesc,
          age: loc.unifiedProgLangYorubaAge,
          f1: loc.unifiedProgLangYorubaFeat1,
          f2: loc.unifiedProgLangYorubaFeat2,
          f3: loc.unifiedProgLangYorubaFeat3,
        );
      case 'lang_amharic':
        return (
          title: loc.unifiedProgLangAmharicTitle,
          desc: loc.unifiedProgLangAmharicDesc,
          age: loc.unifiedProgLangAmharicAge,
          f1: loc.unifiedProgLangAmharicFeat1,
          f2: loc.unifiedProgLangAmharicFeat2,
          f3: loc.unifiedProgLangAmharicFeat3,
        );
      case 'lang_wolof':
        return (
          title: loc.unifiedProgLangWolofTitle,
          desc: loc.unifiedProgLangWolofDesc,
          age: loc.unifiedProgLangWolofAge,
          f1: loc.unifiedProgLangWolofFeat1,
          f2: loc.unifiedProgLangWolofFeat2,
          f3: loc.unifiedProgLangWolofFeat3,
        );
      case 'lang_hausa':
        return (
          title: loc.unifiedProgLangHausaTitle,
          desc: loc.unifiedProgLangHausaDesc,
          age: loc.unifiedProgLangHausaAge,
          f1: loc.unifiedProgLangHausaFeat1,
          f2: loc.unifiedProgLangHausaFeat2,
          f3: loc.unifiedProgLangHausaFeat3,
        );
      case 'lit_grammar':
        return (
          title: loc.unifiedProgLitGrammarTitle,
          desc: loc.unifiedProgLitGrammarDesc,
          age: loc.unifiedProgLitGrammarAge,
          f1: loc.unifiedProgLitGrammarFeat1,
          f2: loc.unifiedProgLitGrammarFeat2,
          f3: loc.unifiedProgLitGrammarFeat3,
        );
      case 'lit_reading':
        return (
          title: loc.unifiedProgLitReadingTitle,
          desc: loc.unifiedProgLitReadingDesc,
          age: loc.unifiedProgLitReadingAge,
          f1: loc.unifiedProgLitReadingFeat1,
          f2: loc.unifiedProgLitReadingFeat2,
          f3: loc.unifiedProgLitReadingFeat3,
        );
      case 'lit_creative':
        return (
          title: loc.unifiedProgLitCreativeTitle,
          desc: loc.unifiedProgLitCreativeDesc,
          age: loc.unifiedProgLitCreativeAge,
          f1: loc.unifiedProgLitCreativeFeat1,
          f2: loc.unifiedProgLitCreativeFeat2,
          f3: loc.unifiedProgLitCreativeFeat3,
        );
      case 'lit_academic':
        return (
          title: loc.unifiedProgLitAcademicTitle,
          desc: loc.unifiedProgLitAcademicDesc,
          age: loc.unifiedProgLitAcademicAge,
          f1: loc.unifiedProgLitAcademicFeat1,
          f2: loc.unifiedProgLitAcademicFeat2,
          f3: loc.unifiedProgLitAcademicFeat3,
        );
      case 'lit_literature':
        return (
          title: loc.unifiedProgLitLiteratureTitle,
          desc: loc.unifiedProgLitLiteratureDesc,
          age: loc.unifiedProgLitLiteratureAge,
          f1: loc.unifiedProgLitLiteratureFeat1,
          f2: loc.unifiedProgLitLiteratureFeat2,
          f3: loc.unifiedProgLitLiteratureFeat3,
        );
      case 'lit_testprep':
        return (
          title: loc.unifiedProgLitTestprepTitle,
          desc: loc.unifiedProgLitTestprepDesc,
          age: loc.unifiedProgLitTestprepAge,
          f1: loc.unifiedProgLitTestprepFeat1,
          f2: loc.unifiedProgLitTestprepFeat2,
          f3: loc.unifiedProgLitTestprepFeat3,
        );
      case 'math_elem':
        return (
          title: loc.unifiedProgMathElemTitle,
          desc: loc.unifiedProgMathElemDesc,
          age: loc.unifiedProgMathElemAge,
          f1: loc.unifiedProgMathElemFeat1,
          f2: loc.unifiedProgMathElemFeat2,
          f3: loc.unifiedProgMathElemFeat3,
        );
      case 'math_algebra':
        return (
          title: loc.unifiedProgMathAlgebraTitle,
          desc: loc.unifiedProgMathAlgebraDesc,
          age: loc.unifiedProgMathAlgebraAge,
          f1: loc.unifiedProgMathAlgebraFeat1,
          f2: loc.unifiedProgMathAlgebraFeat2,
          f3: loc.unifiedProgMathAlgebraFeat3,
        );
      case 'math_geometry':
        return (
          title: loc.unifiedProgMathGeometryTitle,
          desc: loc.unifiedProgMathGeometryDesc,
          age: loc.unifiedProgMathGeometryAge,
          f1: loc.unifiedProgMathGeometryFeat1,
          f2: loc.unifiedProgMathGeometryFeat2,
          f3: loc.unifiedProgMathGeometryFeat3,
        );
      case 'math_trig':
        return (
          title: loc.unifiedProgMathTrigTitle,
          desc: loc.unifiedProgMathTrigDesc,
          age: loc.unifiedProgMathTrigAge,
          f1: loc.unifiedProgMathTrigFeat1,
          f2: loc.unifiedProgMathTrigFeat2,
          f3: loc.unifiedProgMathTrigFeat3,
        );
      case 'math_calc':
        return (
          title: loc.unifiedProgMathCalcTitle,
          desc: loc.unifiedProgMathCalcDesc,
          age: loc.unifiedProgMathCalcAge,
          f1: loc.unifiedProgMathCalcFeat1,
          f2: loc.unifiedProgMathCalcFeat2,
          f3: loc.unifiedProgMathCalcFeat3,
        );
      case 'math_stats':
        return (
          title: loc.unifiedProgMathStatsTitle,
          desc: loc.unifiedProgMathStatsDesc,
          age: loc.unifiedProgMathStatsAge,
          f1: loc.unifiedProgMathStatsFeat1,
          f2: loc.unifiedProgMathStatsFeat2,
          f3: loc.unifiedProgMathStatsFeat3,
        );
      case 'code_kids':
        return (
          title: loc.unifiedProgCodeKidsTitle,
          desc: loc.unifiedProgCodeKidsDesc,
          age: loc.unifiedProgCodeKidsAge,
          f1: loc.unifiedProgCodeKidsFeat1,
          f2: loc.unifiedProgCodeKidsFeat2,
          f3: loc.unifiedProgCodeKidsFeat3,
        );
      case 'code_web':
        return (
          title: loc.unifiedProgCodeWebTitle,
          desc: loc.unifiedProgCodeWebDesc,
          age: loc.unifiedProgCodeWebAge,
          f1: loc.unifiedProgCodeWebFeat1,
          f2: loc.unifiedProgCodeWebFeat2,
          f3: loc.unifiedProgCodeWebFeat3,
        );
      case 'code_mobile':
        return (
          title: loc.unifiedProgCodeMobileTitle,
          desc: loc.unifiedProgCodeMobileDesc,
          age: loc.unifiedProgCodeMobileAge,
          f1: loc.unifiedProgCodeMobileFeat1,
          f2: loc.unifiedProgCodeMobileFeat2,
          f3: loc.unifiedProgCodeMobileFeat3,
        );
      case 'code_python':
        return (
          title: loc.unifiedProgCodePythonTitle,
          desc: loc.unifiedProgCodePythonDesc,
          age: loc.unifiedProgCodePythonAge,
          f1: loc.unifiedProgCodePythonFeat1,
          f2: loc.unifiedProgCodePythonFeat2,
          f3: loc.unifiedProgCodePythonFeat3,
        );
      case 'code_game':
        return (
          title: loc.unifiedProgCodeGameTitle,
          desc: loc.unifiedProgCodeGameDesc,
          age: loc.unifiedProgCodeGameAge,
          f1: loc.unifiedProgCodeGameFeat1,
          f2: loc.unifiedProgCodeGameFeat2,
          f3: loc.unifiedProgCodeGameFeat3,
        );
      case 'code_cs':
        return (
          title: loc.unifiedProgCodeCsTitle,
          desc: loc.unifiedProgCodeCsDesc,
          age: loc.unifiedProgCodeCsAge,
          f1: loc.unifiedProgCodeCsFeat1,
          f2: loc.unifiedProgCodeCsFeat2,
          f3: loc.unifiedProgCodeCsFeat3,
        );
      case 'as_elem':
        return (
          title: loc.unifiedProgAsElemTitle,
          desc: loc.unifiedProgAsElemDesc,
          age: loc.unifiedProgAsElemAge,
          f1: loc.unifiedProgAsElemFeat1,
          f2: loc.unifiedProgAsElemFeat2,
          f3: loc.unifiedProgAsElemFeat3,
        );
      case 'as_middle':
        return (
          title: loc.unifiedProgAsMiddleTitle,
          desc: loc.unifiedProgAsMiddleDesc,
          age: loc.unifiedProgAsMiddleAge,
          f1: loc.unifiedProgAsMiddleFeat1,
          f2: loc.unifiedProgAsMiddleFeat2,
          f3: loc.unifiedProgAsMiddleFeat3,
        );
      case 'as_high':
        return (
          title: loc.unifiedProgAsHighTitle,
          desc: loc.unifiedProgAsHighDesc,
          age: loc.unifiedProgAsHighAge,
          f1: loc.unifiedProgAsHighFeat1,
          f2: loc.unifiedProgAsHighFeat2,
          f3: loc.unifiedProgAsHighFeat3,
        );
      default:
        return (
          title: '',
          desc: '',
          age: '',
          f1: '',
          f2: '',
          f3: '',
        );
    }
  }
}
