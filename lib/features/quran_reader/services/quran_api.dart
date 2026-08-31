/// quran.com open API v4 client — mirrors the web reader's usage
/// (apps/web/src/components/StudentQuranPage.tsx): word-by-word Uthmani +
/// imlaei text, per-word and per-ayah audio, translations, reciters.
/// Open API: CORS/no-auth, so it works directly from the app.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

const _base = 'https://api.quran.com/api/v4';
const audioCdn = 'https://verses.quran.com/';
const translationId = 20; // Saheeh International (131 returns empty on open API)

/// Juz start points: [surah, ayah] for each juz (index 0 = juz 1). Final
/// sentinel marks the end. Keep identical to the web JUZ_START table.
const List<List<int>> juzStart = [
  [1, 1], [2, 142], [2, 253], [3, 93], [4, 24], [4, 148], [5, 82], [6, 111],
  [7, 88], [8, 41], [9, 93], [11, 6], [12, 53], [15, 1], [17, 1], [18, 75],
  [21, 1], [23, 1], [25, 21], [27, 56], [29, 46], [33, 31], [36, 28], [39, 32],
  [41, 47], [46, 1], [51, 31], [58, 1], [67, 1], [78, 1], [115, 1],
];

class Chapter {
  final int id;
  final String nameArabic;
  final String nameSimple;
  final String translatedName;
  final int versesCount;
  final String revelationPlace;
  Chapter({
    required this.id,
    required this.nameArabic,
    required this.nameSimple,
    required this.translatedName,
    required this.versesCount,
    required this.revelationPlace,
  });
}

class QuranWord {
  final int position;
  final String text; // uthmani
  final String imlaei; // standard orthography (feeds the pronunciation checker)
  final String translation;
  final String transliteration;
  final String audioUrl;
  QuranWord({
    required this.position,
    required this.text,
    required this.imlaei,
    required this.translation,
    required this.transliteration,
    required this.audioUrl,
  });
}

class Verse {
  final String verseKey;
  final int chapterId;
  final int verseNumber;
  final List<QuranWord> words;
  final String translation;
  final String audioUrl;
  final List<List<num>> segments; // [wordPosition, startMs, endMs]
  Verse({
    required this.verseKey,
    required this.chapterId,
    required this.verseNumber,
    required this.words,
    required this.translation,
    required this.audioUrl,
    required this.segments,
  });
}

class ReciterOption {
  final int id;
  final String name;
  const ReciterOption(this.id, this.name);
}

const fallbackReciters = [
  ReciterOption(7, 'Mishari Rashid al-Afasy'),
  ReciterOption(1, 'AbdulBaset AbdulSamad (Murattal)'),
  ReciterOption(3, 'Abdur-Rahman as-Sudais'),
  ReciterOption(4, 'Abu Bakr al-Shatri'),
  ReciterOption(5, 'Hani ar-Rifai'),
  ReciterOption(6, 'Mahmoud Khalil Al-Husary'),
  ReciterOption(9, 'Mohamed Siddiq al-Minshawi (Murattal)'),
  ReciterOption(10, 'Sa`ud ash-Shuraym'),
];

class QuranApi {
  final http.Client _client;
  QuranApi([http.Client? client]) : _client = client ?? http.Client();

  Future<dynamic> _getJson(String path) async {
    final res = await _client
        .get(Uri.parse('$_base$path'))
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception('quran.com API ${res.statusCode} for $path');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<List<Chapter>> chapters() async {
    final data = await _getJson('/chapters?language=en');
    final list = (data['chapters'] as List?) ?? [];
    return list
        .map((c) => Chapter(
              id: (c['id'] as num).toInt(),
              nameArabic: '${c['name_arabic'] ?? ''}',
              nameSimple: '${c['name_simple'] ?? ''}',
              translatedName: '${(c['translated_name']?['name']) ?? ''}',
              versesCount: ((c['verses_count'] as num?) ?? 0).toInt(),
              revelationPlace: '${c['revelation_place'] ?? ''}',
            ))
        .toList();
  }

  Future<List<ReciterOption>> reciters() async {
    try {
      final data = await _getJson('/resources/recitations?language=en');
      final list = (data['recitations'] as List?) ?? [];
      final out = list
          .map((r) => ReciterOption(
                (r['id'] as num).toInt(),
                '${r['reciter_name'] ?? ''}${(r['style'] ?? '') != '' && r['style'] != null ? ' (${r['style']})' : ''}',
              ))
          .where((r) => r.name.trim().isNotEmpty)
          .toList();
      return out.isEmpty ? fallbackReciters : out;
    } catch (_) {
      return fallbackReciters;
    }
  }

  Verse _mapVerse(Map<String, dynamic> v) {
    final rawWords = (v['words'] as List?) ?? [];
    final words = rawWords
        .where((w) => w['char_type_name'] == 'word')
        .map<QuranWord>((w) => QuranWord(
              position: ((w['position'] as num?) ?? 0).toInt(),
              text: '${w['text_uthmani'] ?? w['text'] ?? ''}',
              imlaei: '${w['text_imlaei'] ?? ''}',
              translation: '${(w['translation']?['text']) ?? ''}',
              transliteration: '${(w['transliteration']?['text']) ?? ''}',
              audioUrl:
                  w['audio_url'] != null ? '$audioCdn${w['audio_url']}' : '',
            ))
        .toList();
    final audio = (v['audio'] as Map?) ?? {};
    final key = '${v['verse_key'] ?? ''}';
    final segments = ((audio['segments'] as List?) ?? [])
        .whereType<List>()
        .map((s) => s.whereType<num>().toList())
        .toList();
    return Verse(
      verseKey: key,
      chapterId: int.tryParse(key.split(':').first) ?? 0,
      verseNumber: ((v['verse_number'] as num?) ?? 0).toInt(),
      words: words,
      translation: _stripHtml(
          '${(((v['translations'] as List?)?.isNotEmpty ?? false) ? v['translations'][0]['text'] : '') ?? ''}'),
      audioUrl: audio['url'] != null ? '$audioCdn${audio['url']}' : '',
      segments: segments,
    );
  }

  static const _wordParams =
      'words=true&word_fields=text_uthmani,text_imlaei,audio_url&fields=text_uthmani'
      '&translations=$translationId&word_translation_language=en';

  Future<List<Verse>> versesByChapter(int chapterId, int reciterId) async {
    final out = <Verse>[];
    var page = 1;
    while (true) {
      final data = await _getJson(
          '/verses/by_chapter/$chapterId?$_wordParams&audio=$reciterId&per_page=50&page=$page');
      final verses = (data['verses'] as List?) ?? [];
      out.addAll(verses.map((v) => _mapVerse(Map<String, dynamic>.from(v))));
      final pagination = (data['pagination'] as Map?) ?? {};
      if (pagination['next_page'] == null || verses.isEmpty) break;
      page = (pagination['next_page'] as num).toInt();
      if (page > 40) break;
    }
    return out;
  }

  Future<List<Verse>> versesByJuz(int juzId, int reciterId) async {
    final out = <Verse>[];
    var page = 1;
    while (true) {
      final data = await _getJson(
          '/verses/by_juz/$juzId?$_wordParams&audio=$reciterId&per_page=50&page=$page');
      final verses = (data['verses'] as List?) ?? [];
      out.addAll(verses.map((v) => _mapVerse(Map<String, dynamic>.from(v))));
      final pagination = (data['pagination'] as Map?) ?? {};
      if (pagination['next_page'] == null || verses.isEmpty) break;
      page = (pagination['next_page'] as num).toInt();
      if (page > 40) break;
    }
    return out;
  }

  Future<Verse?> verseByKey(String key, int reciterId) async {
    final data =
        await _getJson('/verses/by_key/$key?$_wordParams&audio=$reciterId');
    final v = data['verse'];
    return v == null ? null : _mapVerse(Map<String, dynamic>.from(v));
  }

  static String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}
