import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// The student AI tutor, hands-free.
///
/// The phone listens and speaks with its own engines, so nothing is billed per
/// minute. The student starts a session and simply talks: when they pause,
/// what they said goes to the tutor, the answer is read aloud and listening
/// resumes. Tapping the conversation while the tutor talks interrupts it.
/// There is no push-to-talk; the only button ends the session.
class StudentAiTutorScreen extends StatefulWidget {
  const StudentAiTutorScreen({super.key});

  @override
  State<StudentAiTutorScreen> createState() => _StudentAiTutorScreenState();
}

enum _Phase { idle, listening, thinking, speaking }

class _Lang {
  const _Lang(this.id, this.label, this.locale);
  final String id;
  final String label;
  final String locale;
}

const _langs = [
  _Lang('en', 'English', 'en-US'),
  _Lang('fr', 'Français', 'fr-FR'),
  _Lang('ar', 'العربية', 'ar-SA'),
];

const _blue = Color(0xff0E72ED);

class _Message {
  _Message(this.role, this.text);
  final String role; // 'user' | 'assistant'
  final String text;
  Map<String, String> toJson() => {'role': role, 'text': text};
}

class _Slot {
  _Slot.fromJson(Map<dynamic, dynamic> j)
      : slotKey = j['slotKey'] as String,
        start = DateTime.parse(j['startIso'] as String).toLocal(),
        seatsLeft = (j['seatsLeft'] as num).toInt(),
        mine = j['mine'] == true;
  final String slotKey;
  final DateTime start;
  final int seatsLeft;
  final bool mine;
}

class _Booking {
  _Booking.fromJson(Map<dynamic, dynamic> j)
      : id = j['id'] as String,
        start = DateTime.parse(j['startIso'] as String).toLocal();
  final String id;
  final DateTime start;
}

class _Availability {
  _Availability.fromJson(Map<dynamic, dynamic> j)
      : settings = Map<String, dynamic>.from(j['settings'] as Map),
        slots = (j['slots'] as List).map((s) => _Slot.fromJson(s as Map)).toList(),
        myBookings = (j['myBookings'] as List).map((b) => _Booking.fromJson(b as Map)).toList(),
        canStartNow = j['canStartNow'] == true,
        activeSessionId = (j['activeSession'] as Map?)?['id'] as String?;
  final Map<String, dynamic> settings;
  final List<_Slot> slots;
  final List<_Booking> myBookings;
  final bool canStartNow;
  final String? activeSessionId;
  int get seats => (settings['seats'] as num?)?.toInt() ?? 10;
  int get sessionMinutes => (settings['sessionMinutes'] as num?)?.toInt() ?? 60;
  int get maxBookingsPerDay => (settings['maxBookingsPerDay'] as num?)?.toInt() ?? 2;
  String get window => '${settings['windowStart'] ?? '15:00'}–${settings['windowEnd'] ?? '23:00'}';
}

class _StudentAiTutorScreenState extends State<StudentAiTutorScreen> {
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  final _functions = FirebaseFunctions.instance;
  final _scroll = ScrollController();
  final _typed = TextEditingController();

  _Availability? _avail;
  String? _notice;
  String? _busy;
  bool _speechReady = false;

  String? _sessionId;
  DateTime? _expiresAt;
  final List<_Message> _messages = [];
  _Phase _phase = _Phase.idle;
  _Lang _lang = _langs.first;
  String _heard = '';
  bool _alive = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _loadAvailability();
  }

  @override
  void dispose() {
    _alive = false;
    _clock?.cancel();
    _speech.stop();
    _tts.stop();
    _scroll.dispose();
    _typed.dispose();
    super.dispose();
  }

  Future<T> _call<T>(String name, [Map<String, dynamic> data = const {}]) async {
    final res = await _functions.httpsCallable(name).call<dynamic>(data);
    return res.data as T;
  }

  String _errorText(Object e) =>
      e is FirebaseFunctionsException ? (e.message ?? 'Something went wrong.') : 'Something went wrong.';

  Future<void> _loadAvailability() async {
    try {
      final data = await _call<Map<dynamic, dynamic>>('aiTutorGetAvailability', {'days': 2});
      if (mounted) setState(() => _avail = _Availability.fromJson(data));
    } catch (e) {
      if (mounted) setState(() => _notice = _errorText(e));
    }
  }

  void _tick() {
    if (!mounted) return;
    final exp = _expiresAt;
    if (_sessionId != null && exp != null && !exp.isAfter(DateTime.now())) {
      _notice = 'Your hour is up. Book another one to continue.';
      _endSession();
      return;
    }
    if (_sessionId != null) setState(() {});
  }

  // ------------------------------------------------------- the voice loop --

  Future<bool> _ensureSpeech() async {
    if (_speechReady) return true;
    try {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          // The OS recognizer stops on silence; that is our turn boundary.
          if ((status == 'done' || status == 'notListening') && _alive && mounted && _phase == _Phase.listening) {
            _onListenEnded();
          }
        },
        onError: (err) {
          if (!mounted) return;
          if (err.permanent) {
            setState(() {
              _notice = 'Microphone access is blocked. Allow the microphone in Settings, or type below.';
              _alive = false;
              _phase = _Phase.idle;
            });
          }
        },
      );
    } catch (_) {
      _speechReady = false;
    }
    return _speechReady;
  }

  void _listen() {
    if (!_alive || !mounted || !_speechReady) return;
    setState(() {
      _phase = _Phase.listening;
      _heard = '';
    });
    _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        localeId: _lang.locale,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 2),
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult r) {
    if (!mounted || _phase != _Phase.listening) return;
    setState(() => _heard = r.recognizedWords);
    if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
      _submit(r.recognizedWords);
    }
  }

  void _onListenEnded() {
    // Silence with nothing said: keep listening. A final result already
    // triggered _submit through _onSpeechResult.
    if (_heard.trim().isEmpty) {
      Future<void>.delayed(const Duration(milliseconds: 250), _listen);
    }
  }

  Future<void> _speak(String text, String langId) async {
    final lang = _langs.firstWhere((l) => l.id == langId, orElse: () => _langs.first);
    try {
      await _tts.setLanguage(lang.locale);
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
    } catch (_) {
      // No voice for this language on the device; the text is still on screen.
    }
  }

  Future<void> _submit(String text) async {
    final sid = _sessionId;
    final clean = text.trim();
    if (sid == null || clean.isEmpty || _phase == _Phase.thinking) return;
    await _speech.stop();
    setState(() {
      _heard = '';
      _phase = _Phase.thinking;
      _messages.add(_Message('user', clean));
    });
    _scrollToEnd();
    try {
      final res = await _call<Map<dynamic, dynamic>>('aiTutorTurn', {
        'sessionId': sid,
        'messages': _messages.map((m) => m.toJson()).toList(),
      });
      if (!mounted) return;
      final reply = res['reply'] as String;
      setState(() {
        _messages.add(_Message('assistant', reply));
        _expiresAt = DateTime.parse(res['expiresAt'] as String).toLocal();
        _phase = _Phase.speaking;
      });
      _scrollToEnd();
      if (!_alive) return;
      await _speak(reply, res['language'] as String? ?? 'en');
      if (_alive && _phase == _Phase.speaking) _listen();
    } catch (e) {
      if (!mounted) return;
      final msg = _errorText(e);
      setState(() => _notice = msg);
      if (RegExp(r'hour is up|has ended', caseSensitive: false).hasMatch(msg)) {
        await _endSession();
        return;
      }
      if (_alive) _listen();
    }
  }

  Future<void> _startSession() async {
    setState(() {
      _busy = 'start';
      _notice = null;
    });
    try {
      final res = await _call<Map<dynamic, dynamic>>('aiTutorStartSession');
      final ready = await _ensureSpeech();
      if (!mounted) return;
      final name = res['studentName'] as String? ?? '';
      final greeting = "Assalamu alaikum $name. I'm Alluwal, your tutor. What are we working on today?";
      setState(() {
        _sessionId = res['sessionId'] as String;
        _expiresAt = DateTime.parse(res['expiresAt'] as String).toLocal();
        _messages
          ..clear()
          ..add(_Message('assistant', greeting));
        _alive = true;
        _phase = ready ? _Phase.speaking : _Phase.idle;
        if (!ready) _notice = 'Voice is not available on this device. Type your questions below.';
      });
      if (ready) {
        await _speak(greeting, 'en');
        if (_alive && _phase == _Phase.speaking) _listen();
      }
    } catch (e) {
      if (mounted) setState(() => _notice = _errorText(e));
      await _loadAvailability();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _endSession() async {
    _alive = false;
    await _speech.stop();
    await _tts.stop();
    final sid = _sessionId;
    if (mounted) {
      setState(() {
        _phase = _Phase.idle;
        _sessionId = null;
      });
    }
    if (sid != null) {
      try {
        await _call<dynamic>('aiTutorEndSession', {'sessionId': sid});
      } catch (_) {
        // The sweeper closes it.
      }
    }
    await _loadAvailability();
  }

  /// Tapping while the tutor speaks interrupts it and hands the floor back.
  Future<void> _interrupt() async {
    if (_phase != _Phase.speaking) return;
    await _tts.stop();
    _listen();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  // ------------------------------------------------------------- booking --

  Future<void> _book(String slotKey) async {
    setState(() {
      _busy = slotKey;
      _notice = null;
    });
    try {
      await _call<dynamic>('aiTutorBookSlot', {'slotKey': slotKey});
      await _loadAvailability();
    } catch (e) {
      if (mounted) setState(() => _notice = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _cancel(String bookingId) async {
    setState(() => _busy = bookingId);
    try {
      await _call<dynamic>('aiTutorCancelBooking', {'bookingId': bookingId});
      await _loadAvailability();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // -------------------------------------------------------------- render --

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff0F172A),
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.smart_toy_rounded, color: _blue),
          SizedBox(width: 8),
          Text('AI Tutor', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      body: SafeArea(
        child: Column(children: [
          if (_notice != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffFFFBEB),
                border: Border.all(color: const Color(0xffFDE68A)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_notice!, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xff78350F))),
            ),
          Expanded(child: _sessionId != null ? _buildSession() : _buildLobby()),
        ]),
      ),
    );
  }

  Widget _buildSession() {
    final remaining = _expiresAt == null ? Duration.zero : _expiresAt!.difference(DateTime.now());
    final secs = remaining.isNegative ? 0 : remaining.inSeconds;
    final clock = '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    final status = switch (_phase) {
      _Phase.listening => 'Listening…',
      _Phase.thinking => 'Thinking…',
      _Phase.speaking => 'Speaking — tap to interrupt',
      _Phase.idle => 'Ready',
    };
    final dot = switch (_phase) {
      _Phase.listening => const Color(0xff10B981),
      _Phase.speaking => _blue,
      _ => const Color(0xffFBBF24),
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _card(),
          child: Row(children: [
            Stack(children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_blue, Color(0xff6366F1)]),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Alluwal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(status, style: const TextStyle(color: Color(0xff64748B), fontSize: 13)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xffF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Text(clock, style: const TextStyle(fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _interrupt,
            child: Container(
              decoration: _card(),
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                children: [
                  for (final m in _messages) _bubble(m.text, mine: m.role == 'user'),
                  if (_heard.isNotEmpty) _bubble(_heard, mine: true, draft: true),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xffF1F5F9), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final l in _langs)
                  GestureDetector(
                    onTap: () {
                      setState(() => _lang = l);
                      if (_phase == _Phase.listening) {
                        _speech.stop().then((_) => _listen());
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _lang == l ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _lang == l ? [const BoxShadow(color: Color(0x14000000), blurRadius: 4)] : null,
                      ),
                      child: Text(l.label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _lang == l ? _blue : const Color(0xff64748B))),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _endSession,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xffDC2626),
              side: const BorderSide(color: Color(0xffFECACA)),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('End', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _typed,
              textInputAction: TextInputAction.send,
              onSubmitted: _sendTyped,
              decoration: InputDecoration(
                hintText: 'Or type a question…',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xffCBD5E1))),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _sendTyped(_typed.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ]),
      ]),
    );
  }

  void _sendTyped(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _typed.clear();
    _tts.stop();
    _submit(t);
  }

  Widget _bubble(String text, {required bool mine, bool draft = false}) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: draft
              ? Colors.white
              : mine
                  ? _blue
                  : const Color(0xffF1F5F9),
          border: draft ? Border.all(color: const Color(0xff93C5FD)) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: draft
                ? const Color(0xff1D4ED8)
                : mine
                    ? Colors.white
                    : const Color(0xff334155),
          ),
        ),
      ),
    );
  }

  Widget _buildLobby() {
    final a = _avail;
    final canStart = a != null && (a.canStartNow || a.activeSessionId != null);
    final byDay = <String, List<_Slot>>{};
    for (final s in a?.slots ?? const <_Slot>[]) {
      byDay.putIfAbsent(DateFormat('EEEE, MMM d').format(s.start), () => []).add(s);
    }
    final hour = DateFormat('h a');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_blue, Color(0xff6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Color(0x380E72ED), blurRadius: 40, offset: Offset(0, 18))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hands-free tutoring', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Just talk. Alluwal listens and answers.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              'Ask about a lesson, practise a surah, get help with homework — in English, French or Arabic. Sessions are up to ${a?.sessionMinutes ?? 60} minutes.',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 18),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
              ElevatedButton.icon(
                onPressed: canStart && _busy != 'start' ? _startSession : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _blue,
                  disabledBackgroundColor: Colors.white60,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _busy == 'start'
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.mic_rounded, size: 18),
                label: Text(a?.activeSessionId != null ? 'Continue session' : 'Start now',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Text(
                a == null
                    ? 'Checking seats…'
                    : canStart
                        ? 'A seat is free right now.'
                        : 'All ${a.seats} seats are busy — book an hour below.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ]),
          ]),
        ),
        if (a != null && a.myBookings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _card(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your booked hours', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 8),
              for (final b in a.myBookings)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xffF8FAFC), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.event_rounded, size: 16, color: _blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${DateFormat('EEEE, MMM d').format(b.start)} · ${hour.format(b.start)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    TextButton(
                      onPressed: _busy == b.id ? null : () => _cancel(b.id),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xffDC2626), fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ]),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _card(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Book an hour', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
              if (a != null)
                Text('${a.window} · up to ${a.maxBookingsPerDay} a day',
                    style: const TextStyle(color: Color(0xff64748B), fontWeight: FontWeight.w600, fontSize: 12)),
            ]),
            for (final entry in byDay.entries) ...[
              const SizedBox(height: 12),
              Text(entry.key.toUpperCase(),
                  style: const TextStyle(color: Color(0xff94A3B8), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in entry.value)
                    SizedBox(
                      width: 100,
                      child: OutlinedButton(
                        onPressed: s.mine || s.seatsLeft == 0 || _busy == s.slotKey ? null : () => _book(s.slotKey),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff0F172A),
                          disabledForegroundColor: s.mine ? _blue : const Color(0xff94A3B8),
                          backgroundColor: s.mine ? const Color(0xffEFF6FF) : Colors.white,
                          side: BorderSide(color: s.mine ? _blue : const Color(0xffE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(hour.format(s.start), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text(
                            s.mine
                                ? 'Booked'
                                : s.seatsLeft == 0
                                    ? 'Full'
                                    : '${s.seatsLeft} seats',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xff64748B)),
                          ),
                        ]),
                      ),
                    ),
                ],
              ),
            ],
            if (a != null && a.slots.isEmpty) ...[
              const SizedBox(height: 12),
              const Text('No hours left to book in the next two days.', style: TextStyle(color: Color(0xff64748B), fontSize: 14)),
            ],
          ]),
        ),
      ],
    );
  }

  BoxDecoration _card() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
      );
}
