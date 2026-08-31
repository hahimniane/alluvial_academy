/// Bayanah live — the student's game screen.
///
/// Mirrors the web player: watch one event document so every device flips
/// together, hold a short "get ready" beat so any image is on screen before the
/// clock starts, then measure the answer on THIS device with a monotonic
/// stopwatch. Network lag therefore never costs points; the server only checks
/// the number is possible.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/bayanah_chime.dart';
import '../services/bayanah_service.dart';

// Kahoot-style colour + shape per answer: children track these far faster
// than four lines of text.
const _choiceColors = [
  Color(0xFFE21B3C),
  Color(0xFF1368CE),
  Color(0xFFD89E00),
  Color(0xFF26890C),
];
const _choiceShapes = ['▲', '◆', '●', '■'];

class BayanahPlayScreen extends StatefulWidget {
  const BayanahPlayScreen({super.key});

  @override
  State<BayanahPlayScreen> createState() => _BayanahPlayScreenState();
}

class _BayanahPlayScreenState extends State<BayanahPlayScreen> {
  final _service = BayanahService();
  final _codeCtrl = TextEditingController();

  String? _eventId;
  int? _bonus;
  bool _joining = false;
  String _error = '';

  // Per-question state
  String? _currentQuestionId;
  final Stopwatch _stopwatch = Stopwatch();
  bool _ready = false;
  int? _answered;
  int? _awarded;
  Timer? _prepTimer;
  Timer? _ticker;
  int _remainingMs = 0;
  String? _chimedFor;

  @override
  void initState() {
    super.initState();
    _findOpenGame();
  }

  @override
  void dispose() {
    _prepTimer?.cancel();
    _ticker?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// If a game is already running, skip the code entry entirely.
  Future<void> _findOpenGame() async {
    try {
      final open = await _service.findOpenEvent();
      if (open != null && mounted) {
        await _join(eventId: open.id);
      }
    } catch (_) {
      /* fall back to the code screen */
    }
  }

  Future<void> _join({String? code, String? eventId}) async {
    setState(() {
      _joining = true;
      _error = '';
    });
    try {
      final res = await _service.join(joinCode: code, eventId: eventId);
      if (!mounted) return;
      setState(() {
        _eventId = '${res['eventId']}';
        _bonus = (res['bonusPoints'] as num?)?.toInt() ?? 0;
        _joining = false;
      });
    } on FirebaseFunctionsException catch (e) {
      // Surface the message the function wrote, never the Dart stack.
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Could not join that game.';
        _joining = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not join that game. Check the code and try again.';
        _joining = false;
      });
    }
  }

  /// A new question arrived: hold briefly, then start this device's clock.
  void _onQuestion(BayanahLiveQuestion q) {
    if (_currentQuestionId == q.questionId) return;
    _currentQuestionId = q.questionId;
    _prepTimer?.cancel();
    _ticker?.cancel();
    _stopwatch
      ..reset()
      ..stop();
    setState(() {
      _ready = false;
      _answered = null;
      _awarded = null;
      _remainingMs = q.durationMs;
    });
    _prepTimer = Timer(Duration(milliseconds: q.prepMs), () {
      if (!mounted) return;
      _stopwatch
        ..reset()
        ..start();
      setState(() => _ready = true);
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        final left = q.durationMs - _stopwatch.elapsedMilliseconds;
        setState(() => _remainingMs = left > 0 ? left : 0);
      });
    });
  }

  Future<void> _answer(BayanahLiveQuestion q, int index) async {
    if (!_ready || _answered != null) return;
    final elapsed = _stopwatch.elapsedMilliseconds;
    HapticFeedback.selectionClick();
    setState(() => _answered = index);
    try {
      final res = await _service.submitAnswer(
        eventId: _eventId!,
        questionId: q.questionId,
        selectedIndex: index,
        elapsedMs: elapsed,
      );
      if (!mounted) return;
      setState(() => _awarded = (res['points'] as num?)?.toInt() ?? 0);
    } catch (_) {
      /* the reveal will show the truth */
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_eventId == null) return _joinScaffold();
    return StreamBuilder<BayanahEvent>(
      stream: _service.watchEvent(_eventId!),
      builder: (context, snap) {
        final event = snap.data;
        if (event == null) {
          return _dark(const Center(child: CircularProgressIndicator()));
        }
        // The host ended it: drop out of the game interface immediately,
        // whatever was on screen a moment ago.
        if (event.status == 'ended') return _finishedView(event);

        final q = event.currentQuestion;
        if (q != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onQuestion(q));
        }
        final reveal = event.reveal;
        if (q == null || event.status == 'lobby') return _lobby(event);
        if (reveal != null && reveal.questionId == q.questionId) {
          // Celebrate once per question, never on a replayed rebuild.
          if (_chimedFor != reveal.questionId &&
              _answered != null &&
              _answered == reveal.correctIndex) {
            _chimedFor = reveal.questionId;
            BayanahChime.playCorrect();
            HapticFeedback.mediumImpact();
          }
          return _revealView(event, q, reveal);
        }
        return _questionView(q);
      },
    );
  }

  Widget _dark(Widget child) => Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: SafeArea(child: child),
      );

  Widget _joinScaffold() => _dark(
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bayanah Live',
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: 6),
                const Text('Enter the game code your teacher shows',
                    style: TextStyle(color: Color(0xFFCBD5E1))),
                const SizedBox(height: 20),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: Colors.white),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '123456',
                      hintStyle: TextStyle(color: Color(0xFF475569)),
                      filled: true,
                      fillColor: Color(0xFF0F172A),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFCA5A5))),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7490),
                    minimumSize: const Size(240, 52),
                  ),
                  onPressed: _codeCtrl.text.trim().length != 6 || _joining
                      ? null
                      : () => _join(code: _codeCtrl.text.trim()),
                  child: _joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Join game',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );

  /// Final standings once the host ends the game.
  Widget _finishedView(BayanahEvent event) {
    _prepTimer?.cancel();
    _ticker?.cancel();
    return _dark(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text('🏁', style: TextStyle(fontSize: 52)),
            const Text('Game over',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            Text(event.title,
                style: const TextStyle(color: Color(0xFF94A3B8))),
            Expanded(child: _leaderboard()),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7490),
                    minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  setState(() {
                    _eventId = null;
                    _bonus = null;
                    _currentQuestionId = null;
                    _answered = null;
                    _awarded = null;
                    _codeCtrl.clear();
                  });
                },
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lobby(BayanahEvent event) => _dark(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(event.title,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 8),
              const Text("You're in. Wait for your teacher to start.",
                  style: TextStyle(color: Color(0xFFCBD5E1))),
              if ((_bonus ?? 0) > 0) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0E7490), Color(0xFF155E75)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('Head start for playing this month',
                          style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12)),
                      Text('+${_bonus!}',
                          style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text('${event.playerCount} players joined',
                  style: const TextStyle(color: Color(0xFF64748B))),
              if (event.status == 'ended') _leaderboard(),
            ],
          ),
        ),
      );

  Widget _questionView(BayanahLiveQuestion q) {
    final pct = (_remainingMs / (q.durationMs == 0 ? 1 : q.durationMs))
        .clamp(0.0, 1.0);
    return _dark(
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Question ${q.index + 1} of ${q.total}',
                style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const SizedBox(height: 10),
            Text(q.question,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(q.imageUrl!,
                    height: 160, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ],
            const SizedBox(height: 14),
            if (!_ready)
              const Expanded(
                child: Center(
                  child: Text('Get ready…',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFDE68A))),
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation(
                      pct > 0.3 ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    for (var i = 0; i < q.options.length; i++)
                      _choiceButton(q, i),
                  ],
                ),
              ),
              if (_answered != null)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Answer locked — waiting for everyone…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8))),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _choiceButton(BayanahLiveQuestion q, int i) {
    final chosen = _answered == i;
    final dimmed = _answered != null && !chosen;
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Material(
        color: _choiceColors[i % _choiceColors.length],
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _answered == null ? () => _answer(q, i) : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: chosen ? Colors.white : Colors.transparent, width: 4),
            ),
            child: Row(
              children: [
                Text(_choiceShapes[i % _choiceShapes.length],
                    style: const TextStyle(fontSize: 22, color: Colors.white)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(q.options[i],
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _revealView(
      BayanahEvent event, BayanahLiveQuestion q, BayanahReveal reveal) {
    final gotIt = _answered != null && _answered == reveal.correctIndex;
    return _dark(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(gotIt ? '🎉' : (_answered == null ? '⏱️' : '❌'),
                style: const TextStyle(fontSize: 58)),
            const SizedBox(height: 6),
            Text(
              gotIt
                  ? 'Correct!'
                  : (_answered == null ? 'Too slow' : 'Not this time'),
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
            if (gotIt && _awarded != null)
              Text('+$_awarded',
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFDE68A))),
            const SizedBox(height: 10),
            const SizedBox(height: 12),
            // The same four tiles, so the eye lands on the right one in place.
            Column(
              children: [
                for (var i = 0; i < q.options.length; i++)
                  _revealTile(q, reveal, i),
              ],
            ),
            if ((reveal.explanation ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reveal.explanation!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ],
            Expanded(child: _leaderboard()),
          ],
        ),
      ),
    );
  }

  /// One answer tile after the reveal: the correct choice stays bright with a
  /// tick, everything else fades, and your own pick keeps a white outline.
  Widget _revealTile(BayanahLiveQuestion q, BayanahReveal reveal, int i) {
    final isCorrect = i == reveal.correctIndex;
    final isMine = _answered == i;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _choiceColors[i % _choiceColors.length]
            .withValues(alpha: isCorrect ? 1 : 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isMine ? Colors.white : Colors.transparent, width: 3),
      ),
      child: Row(
        children: [
          Text(_choiceShapes[i % _choiceShapes.length],
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: isCorrect ? 1 : 0.6))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(q.options[i],
                style: TextStyle(
                    color: Colors.white.withValues(alpha: isCorrect ? 1 : 0.6),
                    fontWeight: isCorrect ? FontWeight.w900 : FontWeight.w600)),
          ),
          Icon(isCorrect ? Icons.check_circle_rounded : Icons.close_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: isCorrect ? 1 : 0.5)),
        ],
      ),
    );
  }

  Widget _leaderboard() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<List<BayanahPlayer>>(
      stream: _service.watchLeaderboard(_eventId!),
      builder: (context, snap) {
        final players = snap.data ?? [];
        if (players.isEmpty) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.only(top: 18),
          children: [
            const Text('LEADERBOARD',
                style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            for (var i = 0; i < players.length && i < 8; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: players[i].uid == uid
                      ? const Color(0xFF0E7490)
                      : const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: i < 3
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFF94A3B8))),
                    ),
                    Expanded(
                      child: Text(players[i].displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    Text('${players[i].totalPoints}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
