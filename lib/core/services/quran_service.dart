import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/quran_models.dart';
import '../utils/app_logger.dart';

class QuranService {
  static const String _baseUrl = 'https://api.alquran.cloud/v1';
  static const Duration _timeout = Duration(seconds: 12);

  static List<QuranSurah>? _surahCache;
  static final Map<String, QuranSurahContent> _contentCache = {};

  static Future<List<QuranSurah>> getSurahs({bool forceRefresh = false}) async {
    if (!forceRefresh && _surahCache != null) return _surahCache!;

    final uri = Uri.parse('$_baseUrl/surah');

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load surah list (HTTP ${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) {
        throw Exception('Unexpected surah list response');
      }

      final surahs = (decoded['data'] as List)
          .whereType<Map>()
          .map((raw) => QuranSurah.fromMap(Map<String, dynamic>.from(raw)))
          .where((s) => s.number > 0)
          .toList(growable: false);

      _surahCache = surahs;
      return surahs;
    } catch (e, st) {
      AppLogger.error('QuranService: Error loading surah list: $e', stackTrace: st);
      rethrow;
    }
  }

  static Future<QuranSurahContent> getSurahContent(
    int surahNumber, {
    String arabicEdition = 'quran-uthmani',
    String translationEdition = 'en.sahih',
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey(surahNumber, arabicEdition, translationEdition);
    if (!forceRefresh && _contentCache.containsKey(key)) {
      return _contentCache[key]!;
    }

    final uri = Uri.parse(
      '$_baseUrl/surah/$surahNumber/editions/$arabicEdition,$translationEdition',
    );

    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load surah $surahNumber (HTTP ${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) {
        throw Exception('Unexpected surah response');
      }

      final editions = (decoded['data'] as List).whereType<Map>().toList();
      if (editions.length < 2) {
        throw Exception('Surah response missing editions');
      }

      Map<dynamic, dynamic>? findEdition(String identifier) {
        for (final item in editions) {
          final edition = item['edition'];
          if (edition is Map && edition['identifier']?.toString() == identifier) {
            return item;
          }
        }
        return null;
      }

      final arabic = findEdition(arabicEdition) ?? editions.first;
      final translation = findEdition(translationEdition) ??
          (editions.length > 1 ? editions[1] : editions.first);

      final arabicAyahsRaw = arabic['ayahs'];
      final translationAyahsRaw = translation['ayahs'];
      if (arabicAyahsRaw is! List || translationAyahsRaw is! List) {
        throw Exception('Surah response missing ayah lists');
      }

      final translationByNumber = <int, String>{};
      for (final raw in translationAyahsRaw.whereType<Map>()) {
        final numberInSurah = (raw['numberInSurah'] as num?)?.toInt();
        if (numberInSurah == null) continue;
        translationByNumber[numberInSurah] = (raw['text']?.toString() ?? '').trim();
      }

      final ayahs = <QuranAyah>[];
      for (final raw in arabicAyahsRaw.whereType<Map>()) {
        final numberInSurah = (raw['numberInSurah'] as num?)?.toInt();
        if (numberInSurah == null) continue;

        final arabicText = _cleanAyahText(raw['text']?.toString() ?? '');
        final translationText = translationByNumber[numberInSurah] ?? '';
        ayahs.add(
          QuranAyah(
            numberInSurah: numberInSurah,
            arabicText: arabicText,
            translation: translationText,
          ),
        );
      }

      final surahs = await getSurahs();
      final surah = surahs.firstWhere(
        (s) => s.number == surahNumber,
        orElse: () => const QuranSurah(
          number: 0,
          nameArabic: '',
          englishName: '',
          englishNameTranslation: '',
          numberOfAyahs: 0,
          revelationType: '',
        ),
      );

      final result = QuranSurahContent(
        surah: surahNumber == surah.number
            ? surah
            : QuranSurah(
                number: surahNumber,
                nameArabic: surah.nameArabic,
                englishName: surah.englishName.isEmpty ? 'Surah $surahNumber' : surah.englishName,
                englishNameTranslation: surah.englishNameTranslation,
                numberOfAyahs: ayahs.length,
                revelationType: surah.revelationType,
              ),
        ayahs: ayahs,
        arabicEdition: arabicEdition,
        translationEdition: translationEdition,
      );

      _contentCache[key] = result;
      return result;
    } catch (e, st) {
      AppLogger.error('QuranService: Error loading surah $surahNumber: $e', stackTrace: st);
      rethrow;
    }
  }

  static String _cacheKey(int surahNumber, String arabic, String translation) {
    return '$surahNumber|$arabic|$translation';
  }

  static String _cleanAyahText(String raw) {
    return raw.replaceAll('\ufeff', '').trim();
  }
}

