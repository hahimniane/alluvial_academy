/// Recitation checking bridge — records audio and calls the same auth-checked
/// Firebase callables the web uses:
///  - `transcribeRecitation`  (Quran-tuned Whisper: transcript + word timings)
///  - `checkPronunciation`    (phoneme model: per-word ok/ending/sound/missed
///                             with harakah-level detail)
library;

import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';

class TranscribedWord {
  final String word;
  final double start;
  final double end;
  const TranscribedWord(this.word, this.start, this.end);
}

class TranscriptionResult {
  final String text;
  final List<TranscribedWord> words;
  const TranscriptionResult(this.text, this.words);
}

class PronVerdict {
  final String word;
  final String status; // ok | ending | sound | missed
  final String? expectedEnding; // fatha | damma | kasra
  final String? heardEnding;
  const PronVerdict(this.word, this.status, this.expectedEnding, this.heardEnding);
}

class RecitationService {
  final FirebaseFunctions _functions;
  RecitationService([FirebaseFunctions? functions])
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Wake the (scale-to-zero) pronunciation service so the first real check of
  /// a session doesn't hit a cold instance. Fire-and-forget.
  Future<void> warmPronunciation() async {
    try {
      await _functions
          .httpsCallable('checkPronunciation')
          .call<dynamic>({'warm': true});
    } catch (_) {/* non-fatal */}
  }

  Future<String> _fileToBase64(String path) async {
    final bytes = await File(path).readAsBytes();
    return base64Encode(bytes);
  }

  String _filenameFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) {
      return 'recitation.mp4';
    }
    if (lower.endsWith('.ogg') || lower.endsWith('.opus')) {
      return 'recitation.ogg';
    }
    if (lower.endsWith('.wav')) return 'recitation.wav';
    return 'recitation.webm';
  }

  Future<TranscriptionResult> transcribe(String audioPath) async {
    final audioBase64 = await _fileToBase64(audioPath);
    final result =
        await _functions.httpsCallable('transcribeRecitation').call<dynamic>({
      'audioBase64': audioBase64,
      'filename': _filenameFor(audioPath),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final words = ((data['words'] as List?) ?? [])
        .map((w) => TranscribedWord(
              '${w['word'] ?? ''}'.trim(),
              ((w['start'] as num?) ?? 0).toDouble(),
              ((w['end'] as num?) ?? 0).toDouble(),
            ))
        .toList();
    return TranscriptionResult('${data['text'] ?? ''}', words);
  }

  /// [words] must be the diacritized imlaei words of the passage, in order.
  Future<List<PronVerdict>> checkPronunciation(
      String audioPath, List<String> words) async {
    final audioBase64 = await _fileToBase64(audioPath);
    final result =
        await _functions.httpsCallable('checkPronunciation').call<dynamic>({
      'audioBase64': audioBase64,
      'filename': _filenameFor(audioPath),
      'words': words,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return ((data['words'] as List?) ?? [])
        .map((w) => PronVerdict(
              '${w['word'] ?? ''}',
              '${w['status'] ?? 'ok'}',
              w['expected_ending'] as String?,
              w['heard_ending'] as String?,
            ))
        .toList();
  }
}
