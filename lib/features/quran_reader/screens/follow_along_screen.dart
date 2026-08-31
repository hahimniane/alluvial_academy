/// "Recite from memory" — mobile twin of the web RecitationFollowAlong in
/// record mode: record the whole selection, then the Quran-tuned transcription
/// + phoneme pronunciation check run together and the analysis REPLAYS — words
/// light up, slips buzz (skipped/out-of-order ayahs), pronunciation flags turn
/// words amber/orange with harakah-level notes, and flagged words offer
/// compare playback (you vs the reciter).
library;

import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

import '../logic/arabic_recitation.dart';
import '../services/quran_api.dart';
import '../services/recitation_service.dart';

const _harakahGlyph = {'fatha': 'ـَ', 'damma': 'ـُ', 'kasra': 'ـِ'};

enum _Phase { idle, listening, recording, checking, replaying, done, error }

enum _FollowMode { live, record }

class FollowAlongScreen extends StatefulWidget {
  final String title;
  final List<Verse> verses;
  const FollowAlongScreen(
      {super.key, required this.title, required this.verses});

  @override
  State<FollowAlongScreen> createState() => _FollowAlongScreenState();
}

class _FollowAlongScreenState extends State<FollowAlongScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _service = RecitationService();

  // Live follow-along (on-device speech recognition, like the web's live mode).
  final _speech = stt.SpeechToText();
  bool _liveAvailable = false;
  String _liveUnavailableNote = '';
  String? _localeId;
  _FollowMode _followMode = _FollowMode.record;
  bool _liveActive = false;
  final List<String> _committedTokens = [];
  String _partial = '';
  AyahFollowMatcher? _liveMatcher;

  // Parallel per-ayah recording during LIVE mode: the speech recognizer gives
  // us word tracking, but pronunciation/harakah checking needs the audio, so
  // each ayah is recorded and sent to the phoneme model as the student moves
  // on (same design as the web follow-along).
  bool _livePronEnabled = true;
  int _segAyah = 0;
  DateTime _segStarted = DateTime.now();
  final Map<int, String> _segPaths = {}; // ayah -> recorded clip (compare playback)
  int _pronPending = 0;

  _Phase _phase = _Phase.idle;
  String _error = '';
  String? _recordingPath;
  List<List<bool>> _wordDone = [];
  List<AyahStatus> _ayahStatus = [];
  int _slips = 0;

  /// `"$vi:$di"` -> 'ending' | 'sound'
  final Map<String, String> _pronFlags = {};
  final List<String> _pronNotes = [];
  List<TranscribedWord> _timedWords = [];
  ({int vi, int di})? _pickWord;
  bool _abortReplay = false;

  late final List<List<String>> _ayahTokens = widget.verses
      .map((v) => v.words
          .map((w) => normalizeArabic(w.text))
          .where((t) => t.isNotEmpty)
          .toList())
      .toList();

  // Flat expected token stream + map back to (verse, tokenIndex) — the live
  // highlighter re-aligns everything recited so far on each update, so it
  // keeps following even after a mistake (same approach as the web).
  late final List<String> _flatExpected = [
    for (final toks in _ayahTokens) ...toks,
  ];
  late final List<({int vi, int tok})> _flatToAyah = [
    for (var vi = 0; vi < _ayahTokens.length; vi++)
      for (var t = 0; t < _ayahTokens[vi].length; t++) (vi: vi, tok: t),
  ];

  @override
  void initState() {
    super.initState();
    _service.warmPronunciation();
    _resetBoards();
    _initSpeech();
  }

  /// Simulators/emulators have no microphone input device. The speech plugin
  /// asks the audio engine for an input format anyway and dereferences a null
  /// audio unit — a hard segfault (EXC_BAD_ACCESS) that Dart can't catch. So
  /// live mode is only offered on real hardware.
  Future<bool> _hasMicrophoneHardware() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) return (await info.iosInfo).isPhysicalDevice;
      if (Platform.isAndroid) return (await info.androidInfo).isPhysicalDevice;
    } catch (_) {
      /* unknown — assume real hardware */
    }
    return true;
  }

  Future<void> _initSpeech() async {
    if (!await _hasMicrophoneHardware()) {
      if (!mounted) return;
      setState(() {
        _liveAvailable = false;
        _followMode = _FollowMode.record;
        _liveUnavailableNote =
            'Live follow-along needs a real phone — a simulator has no microphone input.';
      });
      return;
    }
    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          // The OS recognizer stops on silence — keep listening until the
          // student taps stop or reaches the end (web does the same restart).
          if ((status == 'done' || status == 'notListening') &&
              _liveActive &&
              mounted &&
              _phase == _Phase.listening) {
            _commitPartial();
            _listen();
          }
        },
        onError: (_) {
          if (_liveActive && mounted && _phase == _Phase.listening) _listen();
        },
      );
      if (!ok) return;
      final locales = await _speech.locales();
      String? arabic;
      for (final l in locales) {
        final id = l.localeId.toLowerCase();
        if (id == 'ar-sa' || id == 'ar_sa') {
          arabic = l.localeId;
          break;
        }
        if (arabic == null && id.startsWith('ar')) arabic = l.localeId;
      }
      if (!mounted) return;
      setState(() {
        _liveAvailable = true;
        _localeId = arabic;
        _followMode = _FollowMode.live;
      });
    } catch (_) {
      /* live mode unavailable — record mode remains */
    }
  }

  void _resetBoards() {
    _wordDone = widget.verses
        .map((v) => List<bool>.filled(v.words.length, false))
        .toList();
    _ayahStatus = List<AyahStatus>.generate(widget.verses.length,
        (i) => i == 0 ? AyahStatus.current : AyahStatus.pending);
    _slips = 0;
    _pronFlags.clear();
    _pronNotes.clear();
    _pickWord = null;
  }

  @override
  void dispose() {
    _abortReplay = true;
    _liveActive = false;
    _speech.stop();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ───────────────────────────── LIVE mode ─────────────────────────────

  /// Hand the iOS audio session over to recording BEFORE touching the mic.
  ///
  /// audioplayers configures the session as `playback` (output only) when the
  /// reader plays an ayah. Speech recognition then asks the audio engine for an
  /// input format that doesn't exist and the app dies with a segfault inside
  /// AVAudioEngine — a crash no Dart try/catch can intercept. Switching the
  /// category to `playAndRecord` first is what keeps the mic usable.
  Future<void> _enableRecordingSession() async {
    try {
      await _player.stop();
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      // Let the OS actually apply the new category before the engine starts.
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } catch (_) {
      /* keep going — worst case the OS refuses and we surface an error */
    }
  }

  /// Start recording the ayah the student is on. Failure is non-fatal: word
  /// tracking and skip detection keep working, we just can't grade sounds.
  Future<void> _startSegmentRecorder() async {
    if (!_livePronEnabled) return;
    try {
      if (!await _recorder.hasPermission()) {
        _livePronEnabled = false;
        return;
      }
      final dir = await path_provider.getTemporaryDirectory();
      final path =
          '${dir.path}/seg_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
        path: path,
      );
      _segStarted = DateTime.now();
    } catch (_) {
      _livePronEnabled = false;
      if (mounted) {
        setState(() => _liveUnavailableNote =
            'Pronunciation checking is off — the mic is busy with live tracking.');
      }
    }
  }

  /// Close the current ayah's clip, send it for pronunciation checking, and
  /// begin the next one. Guarded against recognizer jitter with a minimum
  /// segment length so we never cut an ayah into useless slivers.
  Future<void> _rotateSegment(int nextAyah) async {
    if (!_livePronEnabled) {
      _segAyah = nextAyah;
      return;
    }
    if (DateTime.now().difference(_segStarted) <
        const Duration(milliseconds: 1200)) {
      return;
    }
    final finished = _segAyah;
    _segAyah = nextAyah;
    try {
      final path = await _recorder.stop();
      if (path != null) {
        _segPaths[finished] = path;
        unawaited(_checkAyahPronunciation(finished, path));
      }
    } catch (_) {
      /* ignore — keep following */
    }
    await _startSegmentRecorder();
  }

  /// Phoneme-model check for one ayah; flags land a couple of seconds behind
  /// the voice, exactly like the web.
  Future<void> _checkAyahPronunciation(int vi, String path) async {
    if (vi < 0 || vi >= widget.verses.length) return;
    final verse = widget.verses[vi];
    if (verse.words.isEmpty) return;
    if (mounted) setState(() => _pronPending++);
    try {
      final own =
          verse.words.map((w) => w.imlaei.isNotEmpty ? w.imlaei : w.text).toList();
      // Include the next ayah's words as context: the clip usually catches the
      // first words of the following ayah, and giving the aligner those slots
      // keeps this ayah's verdicts clean. Only this ayah's verdicts are used.
      final context = vi + 1 < widget.verses.length
          ? widget.verses[vi + 1].words
              .map((w) => w.imlaei.isNotEmpty ? w.imlaei : w.text)
              .toList()
          : <String>[];
      final verdicts =
          await _service.checkPronunciation(path, [...own, ...context]);
      if (!mounted) return;
      var flagged = false;
      final flags = <String, String>{};
      final notes = <String>[];
      for (var di = 0; di < own.length && di < verdicts.length; di++) {
        final v = verdicts[di];
        if (v.status == 'ending') {
          flags['$vi:$di'] = 'ending';
          final heard =
              '${v.heardEnding ?? ''} (${_harakahGlyph[v.heardEnding] ?? ''})';
          final expected =
              '${v.expectedEnding ?? ''} (${_harakahGlyph[v.expectedEnding] ?? ''})';
          notes.add(
              '${v.word} — a harakah sounded like $heard — it should be $expected');
          flagged = true;
        } else if (v.status == 'sound') {
          flags['$vi:$di'] = 'sound';
          notes.add('${v.word} — a sound in this word needs checking');
          flagged = true;
        }
      }
      if (flagged) {
        setState(() {
          _pronFlags.addAll(flags);
          _pronNotes.addAll(notes);
        });
        HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 180));
        HapticFeedback.heavyImpact();
      }
    } catch (_) {
      /* non-fatal */
    } finally {
      if (mounted) setState(() => _pronPending--);
    }
  }

  Future<void> _startLive() async {
    await _enableRecordingSession();
    if (!mounted) return;
    // Never call into the recognizer without permission: on iOS the audio
    // engine crashes rather than returning an error.
    final ready = await _speech.hasPermission ||
        await _speech.initialize(onStatus: (_) {}, onError: (_) {});
    if (!ready) {
      if (!mounted) return;
      setState(() {
        _error =
            'Allow microphone and speech recognition to follow your recitation live.';
        _phase = _Phase.error;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _resetBoards();
      _committedTokens.clear();
      _partial = '';
      _liveMatcher = AyahFollowMatcher(_ayahTokens);
      _liveActive = true;
      _phase = _Phase.listening;
      _error = '';
      _livePronEnabled = true;
      _segAyah = 0;
      _segPaths.clear();
      _pronPending = 0;
    });
    _listen();
    await _startSegmentRecorder();
  }

  void _listen() {
    if (!_liveActive || !mounted) return;
    _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        localeId: _localeId,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 60),
      ),
    );
  }

  void _commitPartial() {
    if (_partial.trim().isEmpty) return;
    _commitTokens(tokenize(_partial));
    _partial = '';
  }

  void _commitTokens(List<String> tokens) {
    final matcher = _liveMatcher;
    if (matcher == null) return;
    var slipped = false;
    for (final token in tokens) {
      _committedTokens.add(token);
      if (matcher.push(token) == FollowEvent.slip && !slipped) {
        slipped = true;
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!_liveActive || !mounted) return;
    if (result.finalResult) {
      _commitTokens(tokenize(result.recognizedWords));
      _partial = '';
    } else {
      _partial = result.recognizedWords;
    }
    _updateLiveBoards();
  }

  /// Stateless re-alignment of everything recited so far → word highlights that
  /// keep tracking after mistakes; ayah statuses/slips come from the matcher.
  void _updateLiveBoards() {
    final matcher = _liveMatcher;
    if (matcher == null) return;
    final recited = [..._committedTokens, ...tokenize(_partial)];
    final res = checkRecitation(_flatExpected, recited.join(' '));
    var last = -1;
    final done = List.generate(
        _ayahTokens.length, (vi) => List<bool>.filled(_ayahTokens[vi].length, false));
    for (var i = 0; i < res.correct.length; i++) {
      if (res.correct[i]) {
        final at = _flatToAyah[i];
        done[at.vi][at.tok] = true;
        last = i;
      }
    }
    setState(() {
      _ayahStatus = List.of(matcher.ayahStatus);
      _slips = matcher.slips;
      for (var vi = 0; vi < widget.verses.length; vi++) {
        var tok = 0;
        for (var di = 0; di < widget.verses[vi].words.length; di++) {
          if (normalizeArabic(widget.verses[vi].words[di].text).isEmpty) {
            continue;
          }
          _wordDone[vi][di] = tok < done[vi].length && done[vi][tok];
          tok++;
        }
      }
    });
    // Moving to a new ayah closes that ayah's clip and sends it for checking.
    if (matcher.currentAyah != _segAyah) unawaited(_rotateSegment(matcher.currentAyah));

    if (last >= _flatExpected.length - 1) _finishLive();
  }

  /// Stop recording and check whatever ayah the student ended on.
  Future<void> _finalizeSegment() async {
    if (!_livePronEnabled) return;
    try {
      final path = await _recorder.stop();
      if (path != null) {
        _segPaths[_segAyah] = path;
        unawaited(_checkAyahPronunciation(_segAyah, path));
      }
    } catch (_) {
      /* ignore */
    }
  }

  void _finishLive() {
    _liveActive = false;
    _speech.stop();
    unawaited(_finalizeSegment());
    if (!mounted) return;
    setState(() => _phase = _Phase.done);
    HapticFeedback.mediumImpact();
  }

  void _stopLive() {
    _liveActive = false;
    _speech.stop();
    _commitPartial();
    unawaited(_finalizeSegment());
    setState(() => _phase = _Phase.done);
  }

  Future<void> _start() async {
    await _enableRecordingSession();
    if (!await _recorder.hasPermission()) {
      setState(() {
        _error = 'Microphone access was blocked. Allow the mic and try again.';
        _phase = _Phase.error;
      });
      return;
    }
    final dir = await path_provider.getTemporaryDirectory();
    final path =
        '${dir.path}/follow_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: path,
    );
    setState(() {
      _resetBoards();
      _recordingPath = path;
      _phase = _Phase.recording;
    });
  }

  Future<void> _stopAndAnalyze() async {
    final path = await _recorder.stop();
    if (path == null) return;
    setState(() => _phase = _Phase.checking);
    try {
      final allWords = widget.verses
          .expand((v) =>
              v.words.map((w) => w.imlaei.isNotEmpty ? w.imlaei : w.text))
          .toList();
      final results = await Future.wait([
        _service.transcribe(path),
        _service
            .checkPronunciation(path, allWords)
            .then<List<PronVerdict>?>((v) => v)
            .catchError((_) => null),
      ]);
      final transcription = results[0] as TranscriptionResult;
      final pron = results[1] as List<PronVerdict>?;
      _timedWords = transcription.words;
      if (pron != null) _applyPronFlags(pron);
      await _replay(transcription.text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't check that recitation. Please try again.";
        _phase = _Phase.error;
      });
    }
  }

  void _applyPronFlags(List<PronVerdict> verdicts) {
    // Flat index -> (verse, word) across the whole selection.
    final flat = <({int vi, int di})>[];
    for (var vi = 0; vi < widget.verses.length; vi++) {
      for (var di = 0; di < widget.verses[vi].words.length; di++) {
        flat.add((vi: vi, di: di));
      }
    }
    for (var i = 0; i < verdicts.length && i < flat.length; i++) {
      final v = verdicts[i];
      final at = flat[i];
      if (v.status == 'ending') {
        _pronFlags['${at.vi}:${at.di}'] = 'ending';
        final heard = '${v.heardEnding ?? ''} (${_harakahGlyph[v.heardEnding] ?? ''})';
        final expected =
            '${v.expectedEnding ?? ''} (${_harakahGlyph[v.expectedEnding] ?? ''})';
        _pronNotes.add(
            '${v.word} — a harakah sounded like $heard — it should be $expected');
      } else if (v.status == 'sound') {
        _pronFlags['${at.vi}:${at.di}'] = 'sound';
        _pronNotes.add('${v.word} — a sound in this word needs checking');
      }
    }
  }

  /// Animated replay: walk the transcript through the ayah matcher so words
  /// light up in sequence and slips buzz, like watching the live session back.
  Future<void> _replay(String transcript) async {
    final matcher = AyahFollowMatcher(_ayahTokens);
    _abortReplay = false;
    setState(() => _phase = _Phase.replaying);
    final tokens = tokenize(transcript);
    for (final token in tokens) {
      if (_abortReplay || !mounted) return;
      final event = matcher.push(token);
      if (event == FollowEvent.slip) {
        HapticFeedback.heavyImpact();
      }
      setState(() {
        _syncFromMatcher(matcher);
      });
      await Future.delayed(const Duration(milliseconds: 110));
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.done);
    if (_pronNotes.isNotEmpty) HapticFeedback.mediumImpact();
  }

  void _syncFromMatcher(AyahFollowMatcher m) {
    _ayahStatus = List.of(m.ayahStatus);
    _slips = m.slips;
    // Map token-level done flags back onto display word indexes.
    for (var vi = 0; vi < widget.verses.length; vi++) {
      var tok = 0;
      for (var di = 0; di < widget.verses[vi].words.length; di++) {
        if (normalizeArabic(widget.verses[vi].words[di].text).isEmpty) continue;
        if (tok < m.wordDone[vi].length) {
          _wordDone[vi][di] = m.wordDone[vi][tok];
        }
        tok++;
      }
    }
  }

  Future<void> _playUrl(String url) async {
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  Future<void> _playMyWord(int vi, int di) async {
    // Live mode keeps one clip per ayah; record mode keeps the whole take.
    final segPath = _segPaths[vi];
    if (segPath != null) {
      await _player.stop();
      await _player.play(DeviceFileSource(segPath));
      return;
    }
    final path = _recordingPath;
    if (path == null || _timedWords.isEmpty) return;
    final expected = <String>[];
    final map = <({int vi, int di})>[];
    for (var v = 0; v < widget.verses.length; v++) {
      for (var d = 0; d < widget.verses[v].words.length; d++) {
        expected.add(normalizeArabic(widget.verses[v].words[d].text));
        map.add((vi: v, di: d));
      }
    }
    final spoken = _timedWords.map((w) => normalizeArabic(w.word)).toList();
    final pair = alignSpokenToExpected(expected, spoken);
    int? si;
    for (var i = 0; i < map.length; i++) {
      if (map[i].vi == vi && map[i].di == di) {
        si = pair[i];
        break;
      }
    }
    if (si == null) return;
    final word = _timedWords[si];
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    await _player.seek(Duration(
        milliseconds:
            ((word.start - 0.15).clamp(0, double.infinity) * 1000).toInt()));
    Future.delayed(
        Duration(milliseconds: ((word.end - word.start + 0.3) * 1000).toInt()),
        () {
      if (mounted) _player.stop();
    });
  }

  Color? _wordBg(int vi, int di) {
    final flag = _pronFlags['$vi:$di'];
    if (flag == 'ending') return const Color(0xFFFEF3C7);
    if (flag == 'sound') return const Color(0xFFFFEDD5);
    return null;
  }

  Color _wordFg(int vi, int di) {
    final flag = _pronFlags['$vi:$di'];
    if (flag == 'ending') return const Color(0xFF92400E);
    if (flag == 'sound') return const Color(0xFF9A3412);
    if (_ayahStatus[vi] == AyahStatus.missed) return const Color(0xFFB91C1C);
    if (_wordDone[vi][di]) return const Color(0xFF166534);
    return const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    final doneCount =
        _ayahStatus.where((s) => s == AyahStatus.done).length;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recite from memory',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(widget.title,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text('$doneCount done',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A))),
                const Spacer(),
                if (_slips > 0)
                  Text('$_slips slips',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626))),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                children: [
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 8,
                      children: [
                        for (var vi = 0; vi < widget.verses.length; vi++) ...[
                          for (var di = 0;
                              di < widget.verses[vi].words.length;
                              di++)
                            GestureDetector(
                              onTap: _pronFlags.containsKey('$vi:$di')
                                  ? () =>
                                      setState(() => _pickWord = (vi: vi, di: di))
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _wordBg(vi, di),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.verses[vi].words[di].text,
                                  style: TextStyle(
                                    fontFamily: 'Amiri',
                                    fontSize: 24,
                                    height: 1.9,
                                    color: _wordFg(vi, di),
                                  ),
                                ),
                              ),
                            ),
                          _ayahBadge(vi),
                        ],
                      ],
                    ),
                  ),
                  if (_pronNotes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pronunciation to review',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF92400E))),
                          for (final note in _pronNotes)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(note,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF92400E))),
                            ),
                          const SizedBox(height: 4),
                          const Text(
                              'Tap a highlighted word above to compare your pronunciation.',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFFB45309))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_pickWord != null) _compareBar(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_liveAvailable && (_phase == _Phase.idle || _phase == _Phase.done))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SegmentedButton<_FollowMode>(
                        style: const ButtonStyle(
                            visualDensity: VisualDensity.compact),
                        segments: const [
                          ButtonSegment(
                              value: _FollowMode.live,
                              icon: Icon(Icons.graphic_eq_rounded, size: 15),
                              label: Text('Live')),
                          ButtonSegment(
                              value: _FollowMode.record,
                              icon: Icon(Icons.fiber_manual_record_rounded,
                                  size: 15),
                              label: Text('Record & check')),
                        ],
                        selected: {_followMode},
                        onSelectionChanged: (s) =>
                            setState(() => _followMode = s.first),
                      ),
                    ),
                  if (_liveUnavailableNote.isNotEmpty &&
                      (_phase == _Phase.idle || _phase == _Phase.done))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _liveUnavailableNote,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309)),
                      ),
                    ),
                  if (_pronPending > 0)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 11,
                              height: 11,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF0E7490))),
                          SizedBox(width: 6),
                          Text('Checking pronunciation…',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0E7490))),
                        ],
                      ),
                    ),
                  if (_phase == _Phase.listening && _partial.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _partial,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 15,
                            color: Color(0xFF0E7490),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (_phase == _Phase.error)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error,
                          style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600)),
                    ),
                  _mainButton(),
                  const SizedBox(height: 6),
                  Text(
                    _followMode == _FollowMode.live
                        ? 'Follows your voice live — repeat freely; skips buzz right away.'
                        : 'Recite the selection, then it checks pronunciation and replays where you slipped.',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ayahBadge(int vi) {
    Color border;
    Color? bg;
    Color fg;
    switch (_ayahStatus[vi]) {
      case AyahStatus.missed:
        border = const Color(0xFFDC2626);
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case AyahStatus.done:
        border = const Color(0xFF16A34A);
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case AyahStatus.current:
        border = const Color(0xFF0E7490);
        bg = const Color(0xFFCFF3F0);
        fg = const Color(0xFF0E7490);
        break;
      case AyahStatus.pending:
        border = const Color(0xFF0E7490).withValues(alpha: 0.3);
        fg = const Color(0xFF0E7490);
        break;
    }
    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: border),
      ),
      child: Text('${widget.verses[vi].verseNumber}',
          style: TextStyle(fontSize: 12, color: fg),
          textDirection: TextDirection.ltr),
    );
  }

  Widget _compareBar() {
    final pick = _pickWord!;
    final verse = widget.verses[pick.vi];
    final word = verse.words[pick.di];
    return Container(
      color: const Color(0xFFFFFBEB),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(word.text,
                  style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E))),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _pickWord = null),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          Row(
            children: [
              _compareButton('You · word', Icons.mic_rounded,
                  () => _playMyWord(pick.vi, pick.di)),
              const SizedBox(width: 6),
              _compareButton(
                  'Reciter · word',
                  Icons.volume_up_rounded,
                  word.audioUrl.isEmpty ? null : () => _playUrl(word.audioUrl),
                  filled: true),
              const SizedBox(width: 6),
              _compareButton(
                  'Reciter · ayah',
                  Icons.volume_up_rounded,
                  verse.audioUrl.isEmpty
                      ? null
                      : () => _playUrl(verse.audioUrl),
                  filled: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compareButton(String label, IconData icon, VoidCallback? onTap,
      {bool filled = false}) {
    return Expanded(
      child: filled
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7490),
                  padding: const EdgeInsets.symmetric(vertical: 10)),
              onPressed: onTap,
              icon: Icon(icon, size: 14),
              label: Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800)))
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10)),
              onPressed: onTap,
              icon: Icon(icon, size: 14),
              label: Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800))),
    );
  }

  Widget _mainButton() {
    switch (_phase) {
      case _Phase.listening:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              minimumSize: const Size.fromHeight(50)),
          onPressed: _stopLive,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop'),
        );
      case _Phase.recording:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              minimumSize: const Size.fromHeight(50)),
          onPressed: _stopAndAnalyze,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop & check'),
        );
      case _Phase.checking:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF94A3B8),
              minimumSize: const Size.fromHeight(50)),
          onPressed: null,
          icon: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          label: const Text('Checking your recitation…'),
        );
      case _Phase.replaying:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              minimumSize: const Size.fromHeight(50)),
          onPressed: () {
            _abortReplay = true;
            setState(() => _phase = _Phase.done);
          },
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop'),
        );
      case _Phase.done:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0E7490),
              minimumSize: const Size.fromHeight(50)),
          onPressed: _followMode == _FollowMode.live ? _startLive : _start,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Start over'),
        );
      case _Phase.idle:
      case _Phase.error:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0E7490),
              minimumSize: const Size.fromHeight(50)),
          onPressed: _followMode == _FollowMode.live ? _startLive : _start,
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Start reciting'),
        );
    }
  }
}
