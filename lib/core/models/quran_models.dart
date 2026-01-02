class QuranSurah {
  final int number;
  final String nameArabic;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;

  const QuranSurah({
    required this.number,
    required this.nameArabic,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  factory QuranSurah.fromMap(Map<String, dynamic> map) {
    return QuranSurah(
      number: (map['number'] as num?)?.toInt() ?? 0,
      nameArabic: map['name']?.toString() ?? '',
      englishName: map['englishName']?.toString() ?? '',
      englishNameTranslation: map['englishNameTranslation']?.toString() ?? '',
      numberOfAyahs: (map['numberOfAyahs'] as num?)?.toInt() ?? 0,
      revelationType: map['revelationType']?.toString() ?? '',
    );
  }

  String get label => '$number. $englishName';
}

class QuranAyah {
  final int numberInSurah;
  final String arabicText;
  final String translation;

  const QuranAyah({
    required this.numberInSurah,
    required this.arabicText,
    required this.translation,
  });
}

class QuranSurahContent {
  final QuranSurah surah;
  final List<QuranAyah> ayahs;
  final String arabicEdition;
  final String translationEdition;

  const QuranSurahContent({
    required this.surah,
    required this.ayahs,
    required this.arabicEdition,
    required this.translationEdition,
  });
}

