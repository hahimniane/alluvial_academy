/// Per-ayah recitation check — the mobile twin of the web RecitationCheck:
/// record the ayah, then check it in one of two modes:
///  - Words: Quran-tuned transcription → which words were recited (green /
///    amber ending / red), with the transcript shown.
///  - Pronunciation (beta): phoneme model → per-word ok/ending/sound/missed
///    with harakah-level corrections ("sounded like damma — should be kasra").
/// Includes compare playback: your recording vs the reciter, word and ayah.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:record/record.dart';

import '../logic/arabic_recitation.dart';
import '../services/quran_api.dart';
import '../services/recitation_service.dart';

const _harakahGlyph = {'fatha': 'ـَ', 'damma': 'ـُ', 'kasra': 'ـِ'};

enum _Phase { idle, recording, checking, done, error }

enum _Mode { words, pronunciation }

class RecitationCheckSheet extends StatefulWidget {
  final Verse verse;
  const RecitationCheckSheet({super.key, required this.verse});

  static Future<void> show(BuildContext context, Verse verse) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: RecitationCheckSheet(verse: verse),
      ),
    );
  }

  @override
  State<RecitationCheckSheet> createState() => _RecitationCheckSheetState();
}

class _RecitationCheckSheetState extends State<RecitationCheckSheet> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _service = RecitationService();

  _Phase _phase = _Phase.idle;
  _Mode _mode = _Mode.words;
  String? _recordingPath;
  String _error = '';
  String _heard = '';
  List<bool>? _wordCorrect; // words mode
  List<PronVerdict>? _pron; // pronunciation mode
  List<TranscribedWord> _timedWords = [];

  @override
  void initState() {
    super.initState();
    _service.warmPronunciation();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      setState(() {
        _error = 'Microphone access was blocked. Allow the mic and try again.';
        _phase = _Phase.error;
      });
      return;
    }
    final dir = await path_provider.getTemporaryDirectory();
    final path =
        '${dir.path}/recitation_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: path,
    );
    setState(() {
      _recordingPath = path;
      _phase = _Phase.recording;
      _wordCorrect = null;
      _pron = null;
      _heard = '';
    });
  }

  Future<void> _stopAndCheck() async {
    final path = await _recorder.stop();
    if (path == null) return;
    setState(() => _phase = _Phase.checking);
    await _analyze(path);
  }

  Future<void> _analyze(String path) async {
    try {
      if (_mode == _Mode.pronunciation) {
        final words = widget.verse.words
            .map((w) => w.imlaei.isNotEmpty ? w.imlaei : w.text)
            .toList();
        final verdicts = await _service.checkPronunciation(path, words);
        if (!mounted) return;
        setState(() {
          _pron = verdicts;
          _phase = _Phase.done;
        });
      } else {
        final result = await _service.transcribe(path);
        final expected =
            widget.verse.words.map((w) => normalizeArabic(w.text)).toList();
        final check = checkRecitation(expected, result.text);
        if (!mounted) return;
        setState(() {
          _heard = result.text;
          _timedWords = result.words;
          _wordCorrect = check.correct;
          _phase = _Phase.done;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't check that recitation. Please try again.";
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _switchMode(_Mode mode) async {
    setState(() => _mode = mode);
    final path = _recordingPath;
    if (_phase == _Phase.done && path != null) {
      setState(() => _phase = _Phase.checking);
      await _analyze(path);
    }
  }

  Future<void> _playUrl(String url) async {
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  Future<void> _playMyRecording() async {
    final path = _recordingPath;
    if (path == null) return;
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  /// Play just one word of the student's recording, via transcript timestamps.
  Future<void> _playMyWord(int wordIndex) async {
    final path = _recordingPath;
    if (path == null || _timedWords.isEmpty) return;
    final expected =
        widget.verse.words.map((w) => normalizeArabic(w.text)).toList();
    final spoken = _timedWords.map((w) => normalizeArabic(w.word)).toList();
    final pair = alignSpokenToExpected(expected, spoken);
    final si = wordIndex < pair.length ? pair[wordIndex] : null;
    if (si == null) {
      await _playMyRecording();
      return;
    }
    final word = _timedWords[si];
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    final startMs = ((word.start - 0.15).clamp(0, double.infinity) * 1000).toInt();
    final durMs = ((word.end - word.start + 0.3) * 1000).toInt();
    await _player.seek(Duration(milliseconds: startMs));
    Future.delayed(Duration(milliseconds: durMs), () {
      if (mounted) _player.stop();
    });
  }

  Color? _wordColor(int i) {
    if (_phase != _Phase.done) return null;
    if (_mode == _Mode.pronunciation) {
      final status = (_pron != null && i < _pron!.length) ? _pron![i].status : null;
      switch (status) {
        case 'ok':
          return const Color(0xFFDCFCE7);
        case 'ending':
          return const Color(0xFFFEF3C7);
        case 'sound':
          return const Color(0xFFFFEDD5);
        case 'missed':
          return const Color(0xFFFEE2E2);
      }
      return null;
    }
    final ok = (_wordCorrect != null && i < _wordCorrect!.length)
        ? _wordCorrect![i]
        : null;
    if (ok == null) return null;
    return ok ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
  }

  List<Widget> _pronNotes() {
    final pron = _pron;
    if (pron == null) return [];
    final notes = <Widget>[];
    for (final v in pron) {
      String? note;
      if (v.status == 'ending') {
        final heard =
            '${v.heardEnding ?? ''} (${_harakahGlyph[v.heardEnding] ?? ''})';
        final expected =
            '${v.expectedEnding ?? ''} (${_harakahGlyph[v.expectedEnding] ?? ''})';
        note = 'a harakah sounded like $heard — it should be $expected';
      } else if (v.status == 'sound') {
        note = 'a sound in this word needs checking';
      } else if (v.status == 'missed') {
        note = "this word wasn't heard clearly";
      }
      if (note != null) {
        notes.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '${v.word}  ',
                      style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    TextSpan(
                      text: '— $note',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ]),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ));
      }
    }
    return notes;
  }

  @override
  Widget build(BuildContext context) {
    final verse = widget.verse;
    final issues =
        _pron?.where((v) => v.status != 'ok').length ?? 0;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Check your recitation — Verse ${verse.verseKey}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            // Mode toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _modeChip('Words', _Mode.words),
                  _modeChip('Pronunciation β', _Mode.pronunciation),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // The ayah, words recolored once scored.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAF9),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < verse.words.length; i++)
                      GestureDetector(
                        onTap: _phase == _Phase.done && _mode == _Mode.words
                            ? () => _playMyWord(i)
                            : (verse.words[i].audioUrl.isNotEmpty
                                ? () => _playUrl(verse.words[i].audioUrl)
                                : null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _wordColor(i),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            verse.words[i].text,
                            style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 26,
                              height: 1.9,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (verse.audioUrl.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _playUrl(verse.audioUrl),
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                label: const Text('Hear the correct recitation'),
              ),
            if (_recordingPath != null && _phase == _Phase.done)
              OutlinedButton.icon(
                onPressed: _playMyRecording,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Play your recitation'),
              ),
            if (_phase == _Phase.done && _mode == _Mode.pronunciation) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issues == 0
                          ? 'No pronunciation issues caught. Ma sha Allah!'
                          : '$issues word(s) to review',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E)),
                    ),
                    ..._pronNotes(),
                    const SizedBox(height: 6),
                    const Text(
                      "Beta — catches clear vowel/ending mistakes. It's a practice aid, not a substitute for a teacher.",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
            if (_phase == _Phase.done && _mode == _Mode.words && _heard.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Heard: $_heard',
                textDirection: TextDirection.rtl,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            if (_phase == _Phase.error) ...[
              const SizedBox(height: 8),
              Text(_error,
                  style: const TextStyle(
                      color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 14),
            _actionButton(),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Green = right · amber = check the harakah · red = wrong word.',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, _Mode mode) {
    final selected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4)
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: selected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton() {
    switch (_phase) {
      case _Phase.recording:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              minimumSize: const Size.fromHeight(48)),
          onPressed: _stopAndCheck,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop & check'),
        );
      case _Phase.checking:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF94A3B8),
              minimumSize: const Size.fromHeight(48)),
          onPressed: null,
          icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          label: const Text('Checking your recitation…'),
        );
      case _Phase.done:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0E7490),
              minimumSize: const Size.fromHeight(48)),
          onPressed: _start,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        );
      case _Phase.idle:
      case _Phase.error:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0E7490),
              minimumSize: const Size.fromHeight(48)),
          onPressed: _start,
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Start reciting'),
        );
    }
  }
}
