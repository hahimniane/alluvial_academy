/// Bayanah live event — admin authoring and the host console.
///
/// Two jobs in one place: write the questions beforehand, then on the day run
/// the game from the host view (project it) while students play on their own
/// devices. Everything the host clicks writes to one small document that every
/// player is already watching, so screens change together.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/bayanah_service.dart';

const _teal = Color(0xFF0E7490);
const _ink = Color(0xFF0F172A);

class BayanahAdminScreen extends StatefulWidget {
  const BayanahAdminScreen({super.key});

  @override
  State<BayanahAdminScreen> createState() => _BayanahAdminScreenState();
}

class _BayanahAdminScreenState extends State<BayanahAdminScreen> {
  final _service = BayanahService();

  Future<void> _createEvent() async {
    final titleCtrl = TextEditingController(text: 'Bayanah Competition');
    DateTime? date = DateTime.now();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('New Bayanah event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Event day'),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setLocal(() => date = picked);
                    },
                    child: Text(date == null
                        ? 'Pick a date'
                        : '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _teal),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    if (created != true || !mounted) return;
    final d = date;
    await _service.createEvent(
      title: titleCtrl.text.trim(),
      eventDate: d == null
          ? null
          : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Bayanah live game',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'New event',
            onPressed: _createEvent,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: StreamBuilder<List<BayanahEvent>>(
        stream: _service.watchEvents(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data ?? [];
          if (events.isEmpty) {
            return _empty(onCreate: _createEvent);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _eventCard(events[i]),
          );
        },
      ),
    );
  }

  Widget _empty({required VoidCallback onCreate}) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 48, color: _teal),
            const SizedBox(height: 10),
            const Text('No Bayanah events yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Create one, add your questions, then run it on the day.',
                style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create event'),
            ),
          ],
        ),
      );

  Widget _eventCard(BayanahEvent e) {
    final statusColor = switch (e.status) {
      'live' => const Color(0xFF16A34A),
      'lobby' => _teal,
      'ended' => const Color(0xFF64748B),
      _ => const Color(0xFF94A3B8),
    };
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(e.title,
            style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 10,
            children: [
              _chip(e.status.toUpperCase(), statusColor),
              Text('Code ${e.joinCode}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${e.questionCount} questions'),
              Text('${e.playerCount} players'),
              if (e.eventDate != null) Text(e.eventDate!),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BayanahEventScreen(eventId: e.id),
        )),
      ),
    );
  }

  static Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}

/// One event: questions on the left, host controls + leaderboard on the right.
class BayanahEventScreen extends StatefulWidget {
  final String eventId;
  const BayanahEventScreen({super.key, required this.eventId});

  @override
  State<BayanahEventScreen> createState() => _BayanahEventScreenState();
}

class _BayanahEventScreenState extends State<BayanahEventScreen> {
  final _service = BayanahService();
  bool _busy = false;
  /// The timer you last used — new questions start there so a whole round can
  /// share one length without retyping, while any question can still differ.
  int _lastDurationMs = 20000;

  /// Reveal the answer by itself the moment the timer runs out.
  bool _autoReveal = true;
  Timer? _autoRevealTimer;
  String? _armedQuestionId;
  /// Repaints the host panel once a second so the countdown and the Reveal
  /// button's enabled state stay honest while a question is open.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _autoRevealTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  /// Arm (or cancel) the automatic reveal for whatever question is on screen.
  void _syncAutoReveal(BayanahEvent e) {
    final q = e.currentQuestion;
    final open = q != null && e.reveal == null && e.questionStartedAt != null;
    if (!open || !_autoReveal) {
      _autoRevealTimer?.cancel();
      _autoRevealTimer = null;
      _armedQuestionId = open ? _armedQuestionId : null;
      return;
    }
    if (_armedQuestionId == q.questionId) return; // already counting down
    _armedQuestionId = q.questionId;
    _autoRevealTimer?.cancel();
    // Fire just after the students' clock expires; the server refuses anything
    // earlier, so a small cushion avoids a pointless rejected call.
    final elapsed = DateTime.now().difference(e.questionStartedAt!).inMilliseconds;
    final waitMs = (q.prepMs + q.durationMs + 400) - elapsed;
    _autoRevealTimer = Timer(
      Duration(milliseconds: waitMs > 0 ? waitMs : 0),
      () {
        if (!mounted || !_autoReveal) return;
        _service.reveal(widget.eventId).catchError((_) {});
      },
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Something went wrong')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Something went wrong')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editQuestion([BayanahQuestion? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _QuestionDialog(
        eventId: widget.eventId,
        service: _service,
        existing: existing,
        defaultDurationMs: _lastDurationMs,
        onDurationChosen: (ms) => _lastDurationMs = ms,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question saved')));
    }
  }

  Future<void> _draftWithAi() async {
    final added = await showDialog<int>(
      context: context,
      builder: (_) => _AiDraftDialog(
        eventId: widget.eventId,
        service: _service,
        durationMs: _lastDurationMs,
      ),
    );
    if (added != null && added > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $added questions')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BayanahEvent>(
      stream: _service.watchEvent(widget.eventId),
      builder: (context, snap) {
        final event = snap.data;
        if (event != null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _syncAutoReveal(event));
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(event?.title ?? 'Bayanah',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              if (event != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Text('Code ${event.joinCode}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: _teal)),
                  ),
                ),
            ],
          ),
          floatingActionButton: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'ai',
                backgroundColor: const Color(0xFF7C3AED),
                onPressed: _draftWithAi,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Draft with AI'),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.extended(
                heroTag: 'add',
                backgroundColor: _teal,
                onPressed: () => _editQuestion(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add question'),
              ),
            ],
          ),
          body: event == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth > 880;
                    final questions = _questionsList();
                    final host = _hostPanel(event);
                    if (!wide) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [host, const SizedBox(height: 16), questions],
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: questions),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: host),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _questionsList() => StreamBuilder<List<BayanahQuestion>>(
        stream: _service.watchQuestions(widget.eventId),
        builder: (context, snap) {
          final questions = snap.data ?? [];
          if (questions.isEmpty) {
            return _panel(
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text('No questions yet — add your first one.',
                      style: TextStyle(color: Color(0xFF64748B))),
                ),
              ),
            );
          }
          return _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${questions.length} questions',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 8),
                for (final q in questions) _questionRow(q),
              ],
            ),
          );
        },
      );

  Widget _questionRow(BayanahQuestion q) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAF9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFECFEFF),
              child: Text('${q.order + 1}',
                  style: const TextStyle(fontSize: 12, color: _teal)),
            ),
            const SizedBox(width: 10),
            if ((q.imageUrl ?? '').isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(q.imageUrl!,
                    height: 34, width: 46, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '✓ ${q.options.isNotEmpty && q.correctIndex < q.options.length ? q.options[q.correctIndex] : '—'}'
                    '  ·  ${(q.durationMs / 1000).round()}s  ·  ${q.points} pts',
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: () => _editQuestion(q),
              icon: const Icon(Icons.edit_rounded, size: 18),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => _run(() =>
                  _service.deleteQuestion(widget.eventId, q.id)),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Color(0xFFDC2626)),
            ),
          ],
        ),
      );

  Widget _hostPanel(BayanahEvent e) {
    final live = e.status == 'live';
    final open = e.currentQuestion != null && e.reveal == null;
    return Column(
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Host controls',
                      style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                  const Spacer(),
                  Text('${e.playerCount} joined',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: _teal)),
                ],
              ),
              const SizedBox(height: 10),
              if (e.status == 'draft' || e.status == 'ended')
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  onPressed: _busy || e.questionCount == 0
                      ? null
                      : () => _run(() =>
                          _service.setStatus(widget.eventId, 'lobby')),
                  icon: const Icon(Icons.meeting_room_rounded),
                  label: Text(e.questionCount == 0
                      ? 'Add a question first'
                      : 'Open lobby'),
                ),
              if (e.status == 'lobby')
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A)),
                  onPressed: _busy
                      ? null
                      : () => _run(() => _service.nextQuestion(widget.eventId)),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start first question'),
                ),
              if (live) ...[
                Row(
                  children: [
                    Text(
                      e.currentQuestion == null
                          ? 'Ready'
                          : 'Question ${e.currentQuestion!.index + 1} of ${e.currentQuestion!.total}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    if (open) _countdownChip(e),
                  ],
                ),
                const SizedBox(height: 6),
                if (e.currentQuestion != null)
                  Text(e.currentQuestion!.question,
                      style: const TextStyle(fontSize: 13)),
                if ((e.currentQuestion?.imageUrl ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(e.currentQuestion!.imageUrl!,
                          height: 120, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Switch(
                      value: _autoReveal,
                      onChanged: (v) => setState(() {
                        _autoReveal = v;
                        if (!v) {
                          _autoRevealTimer?.cancel();
                          _autoRevealTimer = null;
                          _armedQuestionId = null;
                        }
                      }),
                    ),
                    const Expanded(
                      child: Text('Reveal automatically when time is up',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy || !open || !_canRevealNow(e)
                            ? null
                            : () => _run(() => _service.reveal(widget.eventId)),
                        icon: const Icon(Icons.visibility_rounded, size: 18),
                        label: Text(_canRevealNow(e) ? 'Reveal' : 'Reveal (wait)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _teal),
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  final finished = await _service
                                      .nextQuestion(widget.eventId);
                                  if (finished && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Game finished 🎉')));
                                  }
                                }),
                        icon: const Icon(Icons.skip_next_rounded, size: 18),
                        label: const Text('Next'),
                      ),
                    ),
                  ],
                ),
                if (e.reveal != null) ...[
                  const SizedBox(height: 10),
                  _revealBars(e),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() =>
                          _service.setStatus(widget.eventId, 'ended')),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('End game'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          child: StreamBuilder<List<BayanahPlayer>>(
            stream: _service.watchLeaderboard(widget.eventId),
            builder: (context, snap) {
              final players = snap.data ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Leaderboard',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                  const SizedBox(height: 8),
                  if (players.isEmpty)
                    const Text('Nobody has joined yet.',
                        style: TextStyle(color: Color(0xFF64748B)))
                  else
                    for (var i = 0; i < players.length; i++)
                      _leaderRow(i + 1, players[i]),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// The server refuses an early reveal; mirror that here so the button simply
  /// isn't clickable while students are still answering.
  Widget _countdownChip(BayanahEvent e) {
    final q = e.currentQuestion;
    final startedAt = e.questionStartedAt;
    if (q == null || startedAt == null) return const SizedBox.shrink();
    final elapsed =
        DateTime.now().difference(startedAt).inMilliseconds - q.prepMs;
    final left = ((q.durationMs - elapsed) / 1000).ceil();
    final counting = left > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: counting ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        counting ? '${left}s left' : "time's up",
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: counting ? const Color(0xFF166534) : const Color(0xFFB91C1C),
        ),
      ),
    );
  }

  bool _canRevealNow(BayanahEvent e) {
    final q = e.currentQuestion;
    final startedAt = e.questionStartedAt;
    if (q == null || startedAt == null) return false;
    final elapsed =
        DateTime.now().difference(startedAt).inMilliseconds - q.prepMs;
    return elapsed >= q.durationMs;
  }

  Widget _revealBars(BayanahEvent e) {
    final reveal = e.reveal!;
    final options = e.currentQuestion?.options ?? const <String>[];
    final total = reveal.counts.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  i == reveal.correctIndex
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 15,
                  color: i == reveal.correctIndex
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFCBD5E1),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(options[i], style: const TextStyle(fontSize: 12))),
                SizedBox(
                  width: 90,
                  child: LinearProgressIndicator(
                    value: total == 0
                        ? 0
                        : (i < reveal.counts.length ? reveal.counts[i] : 0) / total,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation(
                        i == reveal.correctIndex
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(width: 6),
                Text('${i < reveal.counts.length ? reveal.counts[i] : 0}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _leaderRow(int rank, BayanahPlayer p) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text('$rank',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: rank <= 3 ? _teal : const Color(0xFF94A3B8))),
            ),
            Expanded(
              child: Text(p.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (p.bonusPoints > 0)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: 'Head start from playing this month',
                  child: Text('+${p.bonusPoints}',
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309))),
                ),
              ),
            Text('${p.totalPoints}',
                style: const TextStyle(fontWeight: FontWeight.w900, color: _ink)),
          ],
        ),
      );

  static Widget _panel({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: child,
      );
}

/// Add / edit one question.
class _QuestionDialog extends StatefulWidget {
  final String eventId;
  final BayanahService service;
  final BayanahQuestion? existing;
  final int defaultDurationMs;
  final ValueChanged<int>? onDurationChosen;
  const _QuestionDialog({
    required this.eventId,
    required this.service,
    this.existing,
    this.defaultDurationMs = 20000,
    this.onDurationChosen,
  });

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late final TextEditingController _question =
      TextEditingController(text: widget.existing?.question ?? '');
  late final List<TextEditingController> _options = List.generate(
    4,
    (i) => TextEditingController(
      text: (widget.existing != null && i < widget.existing!.options.length)
          ? widget.existing!.options[i]
          : '',
    ),
  );
  late int _correct = widget.existing?.correctIndex ?? 0;
  late double _seconds =
      ((widget.existing?.durationMs ?? widget.defaultDurationMs) / 1000).toDouble();
  late final TextEditingController _explanation =
      TextEditingController(text: widget.existing?.explanation ?? '');
  late String? _imageUrl = widget.existing?.imageUrl;
  bool _uploading = false;
  bool _saving = false;
  String _error = '';

  /// Pick a picture and upload it. Kept small on purpose: a heavy image would
  /// still be decoding when the question opens, and the countdown waits for
  /// nobody — the 2MB ceiling plus the "get ready" beat keeps that safe.
  Future<void> _pickImage() async {
    setState(() {
      _error = '';
      _uploading = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // bytes work on web and mobile alike
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) {
        setState(() => _uploading = false);
        return;
      }
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        setState(() {
          _error = 'That image is ${(bytes.lengthInBytes / 1048576).toStringAsFixed(1)}MB. '
              'Please use one under 2MB so it loads instantly for every student.';
          _uploading = false;
        });
        return;
      }
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final url = await widget.service.uploadQuestionImage(
        bytes: bytes,
        fileName: file.name,
        contentType: ext == 'png'
            ? 'image/png'
            : ext == 'webp'
                ? 'image/webp'
                : ext == 'gif'
                    ? 'image/gif'
                    : 'image/jpeg',
      );
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Upload failed: $e';
        _uploading = false;
      });
    }
  }

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    _explanation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final options = _options
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (_question.text.trim().length < 3) {
      setState(() => _error = 'Write the question first.');
      return;
    }
    if (options.length < 2) {
      setState(() => _error = 'Give at least two answer choices.');
      return;
    }
    if (_correct >= options.length) {
      setState(() => _error = 'Pick which choice is the correct one.');
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      widget.onDurationChosen?.call((_seconds * 1000).round());
      await widget.service.saveQuestion(
        eventId: widget.eventId,
        questionId: widget.existing?.id,
        question: _question.text.trim(),
        options: options,
        correctIndex: _correct,
        durationMs: (_seconds * 1000).round(),
        explanation: _explanation.text.trim(),
        imageUrl: _imageUrl,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is FirebaseFunctionsException
              ? (e.message ?? 'Could not save the question.')
              : 'Could not save the question.';
          _saving = false;
        });
      }
    }
  }

  Widget _imagePicker() {
    if (_imageUrl != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(_imageUrl!,
                height: 64, width: 96, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                      height: 64,
                      width: 96,
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.broken_image_outlined, size: 18),
                    )),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Picture added — students see it with the question.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          TextButton.icon(
            onPressed: _uploading ? null : () => setState(() => _imageUrl = null),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Remove'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _uploading ? null : _pickImage,
        icon: _uploading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.image_outlined, size: 18),
        label: Text(_uploading ? 'Uploading…' : 'Add a picture (optional)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.existing == null ? 'New question' : 'Edit question'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _question,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Answer choices — tap the circle to mark the correct one',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _correct = i),
                        icon: Icon(
                          _correct == i
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: _correct == i
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _options[i],
                          decoration: InputDecoration(
                            labelText: i < 2
                                ? 'Choice ${i + 1}'
                                : 'Choice ${i + 1} (optional)',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              _imagePicker(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Time to answer'),
                  Expanded(
                    child: Slider(
                      value: _seconds,
                      min: 5,
                      max: 60,
                      divisions: 11,
                      label: '${_seconds.round()}s',
                      onChanged: (v) => setState(() => _seconds = v),
                    ),
                  ),
                  Text('${_seconds.round()}s',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              TextField(
                controller: _explanation,
                decoration: const InputDecoration(
                  labelText: 'Explanation shown after the reveal (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error,
                      style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _teal),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Draft questions with AI, then keep the ones you like.
///
/// Nothing is written until the admin ticks a draft and saves, so the AI never
/// puts a question in front of students that a human hasn't read.
class _AiDraftDialog extends StatefulWidget {
  final String eventId;
  final BayanahService service;
  final int durationMs;
  const _AiDraftDialog({
    required this.eventId,
    required this.service,
    required this.durationMs,
  });

  @override
  State<_AiDraftDialog> createState() => _AiDraftDialogState();
}

class _AiDraftDialogState extends State<_AiDraftDialog> {
  final _topic = TextEditingController();
  int _count = 8;
  String _age = 'children aged 8-12';
  String _difficulty = 'easy';
  bool _loading = false;
  bool _saving = false;
  String _error = '';
  List<Map<String, dynamic>> _drafts = [];
  final Set<int> _picked = {};

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_topic.text.trim().length < 3) {
      setState(() => _error = 'Say what the questions should be about.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
      _drafts = [];
      _picked.clear();
    });
    try {
      final drafts = await widget.service.draftQuestions(
        eventId: widget.eventId,
        topic: _topic.text.trim(),
        count: _count,
        ageGroup: _age,
        difficulty: _difficulty,
      );
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _picked.addAll(List.generate(drafts.length, (i) => i)); // keep all by default
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is FirebaseFunctionsException
            ? (e.message ?? 'The AI could not draft questions right now.')
            : 'The AI could not draft questions right now. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _savePicked() async {
    if (_picked.isEmpty) return;
    setState(() => _saving = true);
    try {
      final chosen = _picked.toList()..sort();
      final payload = chosen.map((i) {
        final d = _drafts[i];
        return {
          'question': d['question'],
          'options': d['options'],
          'correctIndex': d['correctIndex'],
          'durationMs': widget.durationMs,
          if ((d['explanation'] ?? '').toString().isNotEmpty)
            'explanation': d['explanation'],
        };
      }).toList();
      final saved = await widget.service
          .saveQuestionsBatch(eventId: widget.eventId, questions: payload);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is FirebaseFunctionsException
              ? (e.message ?? 'Could not save those questions.')
              : 'Could not save those questions.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C3AED)),
          const SizedBox(width: 8),
          const Text('Draft questions with AI'),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _topic,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'What should the questions be about?',
                  hintText: 'e.g. the life of Prophet Ibrahim, for our Bayanah',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: _count,
                    onChanged: (v) => setState(() => _count = v ?? 8),
                    items: [3, 5, 8, 10, 12, 15]
                        .map((n) => DropdownMenuItem(
                            value: n, child: Text('$n questions')))
                        .toList(),
                  ),
                  DropdownButton<String>(
                    value: _age,
                    onChanged: (v) => setState(() => _age = v ?? _age),
                    items: const [
                      DropdownMenuItem(
                          value: 'children aged 5-8', child: Text('Ages 5–8')),
                      DropdownMenuItem(
                          value: 'children aged 8-12', child: Text('Ages 8–12')),
                      DropdownMenuItem(
                          value: 'teenagers aged 13-17', child: Text('Teens')),
                      DropdownMenuItem(value: 'adults', child: Text('Adults')),
                    ],
                  ),
                  DropdownButton<String>(
                    value: _difficulty,
                    onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
                    items: const [
                      DropdownMenuItem(value: 'easy', child: Text('Easy')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'hard', child: Text('Hard')),
                    ],
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED)),
                    onPressed: _loading ? null : _generate,
                    icon: _loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(_loading ? 'Writing…' : 'Generate'),
                  ),
                ],
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error,
                      style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600)),
                ),
              if (_drafts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text('${_picked.length} of ${_drafts.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        if (_picked.length == _drafts.length) {
                          _picked.clear();
                        } else {
                          _picked
                            ..clear()
                            ..addAll(List.generate(_drafts.length, (i) => i));
                        }
                      }),
                      child: Text(_picked.length == _drafts.length
                          ? 'Clear all'
                          : 'Select all'),
                    ),
                  ],
                ),
                for (var i = 0; i < _drafts.length; i++) _draftTile(i),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _teal),
          onPressed: _picked.isEmpty || _saving ? null : _savePicked,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('Add ${_picked.length} question${_picked.length == 1 ? '' : 's'}'),
        ),
      ],
    );
  }

  Widget _draftTile(int i) {
    final d = _drafts[i];
    final options = ((d['options'] as List?) ?? []).map((o) => '$o').toList();
    final correct = (d['correctIndex'] as num?)?.toInt() ?? 0;
    final selected = _picked.contains(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0FDFA) : const Color(0xFFFAFAF9),
        border: Border.all(
            color: selected ? _teal : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (v) => setState(() {
          if (v == true) {
            _picked.add(i);
          } else {
            _picked.remove(i);
          }
        }),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('${d['question']}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < options.length; j++)
                Text(
                  '${j == correct ? '✓' : '·'} ${options[j]}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: j == correct ? FontWeight.w800 : FontWeight.w400,
                    color: j == correct
                        ? const Color(0xFF166534)
                        : const Color(0xFF475569),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
