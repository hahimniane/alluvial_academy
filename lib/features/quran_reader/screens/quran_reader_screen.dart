/// Quran reader — mobile twin of the web student dashboard's Quran page
/// (apps/web/src/components/StudentQuranPage.tsx). Same data (quran.com open
/// API), same memorization/goal document, same recitation checkers, so a
/// student can move between web and the app without losing anything:
///  - Surah/Juz browsing with search, reciter choice
///  - Reading (mushaf-style) and Translation modes, tap a word to hear it
///  - Ayah playback, repeat each-ayah / range
///  - Memorized ticks + goal plan (synced via quran_memorization/{uid})
///  - Per-ayah recitation check (Words / Pronunciation β)
///  - "Recite from memory" follow-along (record → check → replay)
library;

import 'dart:async' show unawaited;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/goal_reminder_service.dart';
import '../services/memorization_service.dart';
import '../services/quran_api.dart';
import '../widgets/goal_sheet.dart';
import '../widgets/recitation_check_sheet.dart';
import 'follow_along_screen.dart';

enum _NavKind { surah, juz, goal }

enum _ViewMode { reading, translation }

class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final _api = QuranApi();
  final _memService = MemorizationService();
  final _ayahPlayer = AudioPlayer();
  final _wordPlayer = AudioPlayer();

  List<Chapter> _chapters = [];
  List<ReciterOption> _reciters = fallbackReciters;
  int _reciter = 7;
  _NavKind _navKind = _NavKind.surah;
  int _navId = 1;
  List<AyahRef> _goalRefs = [];
  List<Verse> _verses = [];
  bool _loading = true;
  String _loadError = '';
  _ViewMode _mode = _ViewMode.reading;

  MemorizationState _mem = const MemorizationState({}, null, {});

  // Playback
  int? _playingIndex;
  int _repeatEach = 1;
  int _repeatsLeft = 1;
  int? _rangeFrom;
  int? _rangeTo;

  @override
  void initState() {
    super.initState();
    _ayahPlayer.onPlayerComplete.listen((_) => _onAyahComplete());
    _bootstrap();
  }

  @override
  void dispose() {
    _ayahPlayer.dispose();
    _wordPlayer.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait([
        _api.chapters(),
        _api.reciters(),
        _memService.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _chapters = results[0] as List<Chapter>;
        _reciters = results[1] as List<ReciterOption>;
        _mem = results[2] as MemorizationState;
      });
      // Keep the daily reminder alive across reinstalls / timezone changes.
      final reminder = _mem.reminder;
      if (reminder != null && reminder.enabled && _mem.plan != null) {
        unawaited(GoalReminderService.schedule(
          hour: reminder.hour,
          minute: reminder.minute,
          perDay: _mem.plan!.perDay,
        ));
      }
      await _loadSelection();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = "Couldn't load the Quran. Check your connection.";
      });
    }
  }

  Future<void> _loadSelection() async {
    setState(() {
      _loading = true;
      _loadError = '';
      _verses = [];
      _stopPlayback();
    });
    try {
      List<Verse> verses;
      if (_navKind == _NavKind.goal) {
        verses = [];
        for (final ref in _goalRefs) {
          final v =
              await _api.verseByKey('${ref.surahId}:${ref.ayah}', _reciter);
          if (v != null) verses.add(v);
        }
      } else if (_navKind == _NavKind.juz) {
        verses = await _api.versesByJuz(_navId, _reciter);
      } else {
        verses = await _api.versesByChapter(_navId, _reciter);
      }
      if (!mounted) return;
      setState(() {
        _verses = verses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = "Couldn't load this selection. Try again.";
      });
    }
  }

  // ---- Memorization ----

  Future<void> _toggleMemorized(Verse verse) async {
    final already = _mem.isMemorized(verse.chapterId, verse.verseNumber);
    setState(() {
      final set = _mem.memorized.putIfAbsent(verse.chapterId, () => <int>{});
      if (already) {
        set.remove(verse.verseNumber);
      } else {
        set.add(verse.verseNumber);
      }
    });
    await _memService.toggle(verse.chapterId, verse.verseNumber,
        nowMemorized: !already);
  }

  void _openGoalSheet() {
    GoalSheet.show(
      context,
      chapters: _chapters,
      currentPlan: _mem.plan,
      alreadyMemorized: _mem.totalMemorized,
      onSave: (scope, perDay) async {
        final hadPlan = _mem.plan != null;
        await _memService.savePlan(scope, perDay);
        final fresh = await _memService.load();
        if (!mounted) return;
        setState(() => _mem = fresh);
        _enterGoalMode();
        // First goal → offer the daily reminder right away.
        if (!hadPlan && !(fresh.reminder?.enabled ?? false)) {
          unawaited(_offerReminder(perDay));
        }
      },
      onClear: () async {
        await _memService.clearPlan();
        await GoalReminderService.cancel();
        await _memService.saveReminder(enabled: false, hour: 20, minute: 0);
        final fresh = await _memService.load();
        if (!mounted) return;
        setState(() {
          _mem = fresh;
          if (_navKind == _NavKind.goal) {
            _navKind = _NavKind.surah;
            _navId = 1;
          }
        });
        await _loadSelection();
      },
    );
  }

  Future<void> _offerReminder(int perDay) async {
    if (!mounted) return;
    final wantsIt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Daily reminder?'),
        content: const Text(
            "Memorization sticks when it's daily. Want a gentle reminder each evening?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7490)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Set reminder')),
        ],
      ),
    );
    if (wantsIt == true) await _pickReminderTime();
  }

  Future<void> _pickReminderTime() async {
    if (!mounted) return;
    final reminder = _mem.reminder;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: reminder?.hour ?? 20, minute: reminder?.minute ?? 0),
      helpText: 'Daily reminder time',
    );
    if (picked == null || !mounted) return;
    final granted = await GoalReminderService.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Notifications are blocked — allow them in Settings to get reminders.')));
      return;
    }
    await GoalReminderService.schedule(
      hour: picked.hour,
      minute: picked.minute,
      perDay: _mem.plan?.perDay ?? 1,
    );
    await _memService.saveReminder(
        enabled: true, hour: picked.hour, minute: picked.minute);
    final fresh = await _memService.load();
    if (!mounted) return;
    setState(() => _mem = fresh);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Daily reminder set for ${picked.format(context)} — you can change it anytime with the bell.')));
  }

  Future<void> _onBellTap() async {
    final reminder = _mem.reminder;
    if (reminder == null || !reminder.enabled) {
      await _pickReminderTime();
      return;
    }
    final time = TimeOfDay(hour: reminder.hour, minute: reminder.minute);
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Daily reminder'),
        content: Text('Reminding you every day at ${time.format(context)}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'off'),
              child: const Text('Turn off',
                  style: TextStyle(color: Color(0xFFDC2626)))),
          TextButton(
              onPressed: () => Navigator.pop(context, 'change'),
              child: const Text('Change time')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7490)),
              onPressed: () => Navigator.pop(context, 'keep'),
              child: const Text('Keep')),
        ],
      ),
    );
    if (action == 'off') {
      await GoalReminderService.cancel();
      await _memService.saveReminder(
          enabled: false, hour: reminder.hour, minute: reminder.minute);
      final fresh = await _memService.load();
      if (!mounted) return;
      setState(() => _mem = fresh);
    } else if (action == 'change') {
      await _pickReminderTime();
    }
  }

  /// Load today's target ayahs (the next unmemorized ones) into the reader.
  void _enterGoalMode() {
    final plan = _mem.plan;
    if (plan == null) return;
    final seq = scopeSequence(plan.scope, _chapters);
    final targets = seq
        .where((r) => !_mem.isMemorized(r.surahId, r.ayah))
        .take(plan.perDay < 1 ? 1 : plan.perDay)
        .toList();
    setState(() {
      _goalRefs = targets;
      _navKind = _NavKind.goal;
    });
    _loadSelection();
  }

  // ---- Playback ----

  void _stopPlayback() {
    _ayahPlayer.stop();
    _playingIndex = null;
  }

  Future<void> _playFrom(int index) async {
    if (index < 0 || index >= _verses.length) return;
    final url = _verses[index].audioUrl;
    if (url.isEmpty) return;
    setState(() {
      _playingIndex = index;
      _repeatsLeft = _repeatEach;
    });
    await _ayahPlayer.stop();
    await _ayahPlayer.play(UrlSource(url));
  }

  void _onAyahComplete() {
    final i = _playingIndex;
    if (i == null) return;
    if (_repeatsLeft > 1) {
      _repeatsLeft -= 1;
      _ayahPlayer.play(UrlSource(_verses[i].audioUrl));
      return;
    }
    var next = i + 1;
    // Range loop: after the range's last ayah, go back to its first.
    if (_rangeFrom != null && _rangeTo != null && i + 1 > _rangeTo! - 1) {
      next = _rangeFrom! - 1;
    }
    if (next < _verses.length && next >= 0) {
      _repeatsLeft = _repeatEach;
      setState(() => _playingIndex = next);
      _ayahPlayer.play(UrlSource(_verses[next].audioUrl));
    } else {
      setState(() => _playingIndex = null);
    }
  }

  Future<void> _playWord(QuranWord word) async {
    if (word.audioUrl.isEmpty) return;
    await _wordPlayer.stop();
    await _wordPlayer.play(UrlSource(word.audioUrl));
  }

  // ---- Pickers ----

  Future<void> _openSurahPicker() async {
    final result = await showModalBottomSheet<(_NavKind, int)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SurahJuzPicker(chapters: _chapters),
    );
    if (result != null) {
      setState(() {
        _navKind = result.$1;
        _navId = result.$2;
      });
      await _loadSelection();
    }
  }

  void _openRepeatSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Repeat',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Repeat each ayah'),
                    Expanded(
                      child: Slider(
                        value: _repeatEach.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '$_repeatEach×',
                        onChanged: (v) {
                          setSheet(() {});
                          setState(() => _repeatEach = v.round());
                        },
                      ),
                    ),
                    Text('$_repeatEach×',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                Row(
                  children: [
                    const Text('Loop ayahs'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _rangeFrom,
                        decoration:
                            const InputDecoration(labelText: 'from'),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('—')),
                          for (var i = 1; i <= _verses.length; i++)
                            DropdownMenuItem(value: i, child: Text('$i')),
                        ],
                        onChanged: (v) {
                          setSheet(() {});
                          setState(() => _rangeFrom = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _rangeTo,
                        decoration: const InputDecoration(labelText: 'to'),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('—')),
                          for (var i = 1; i <= _verses.length; i++)
                            DropdownMenuItem(value: i, child: Text('$i')),
                        ],
                        onChanged: (v) {
                          setSheet(() {});
                          setState(() => _rangeTo = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E7490)),
                  onPressed: () {
                    Navigator.pop(context);
                    if (_rangeFrom != null) _playFrom(_rangeFrom! - 1);
                  },
                  child: const Text('Play'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Build ----

  String get _title {
    if (_navKind == _NavKind.goal) return "Today's memorization";
    if (_navKind == _NavKind.juz) return 'Juz $_navId';
    final c = _chapters.where((c) => c.id == _navId).toList();
    return c.isEmpty ? 'Quran' : '${c.first.nameSimple} · ${c.first.nameArabic}';
  }

  String _scopeLabel(PlanScope scope) {
    if (scope.kind == ScopeKind.quran) return 'the Quran';
    if (scope.kind == ScopeKind.juz) return 'Juz ${scope.id}';
    final c = _chapters.where((c) => c.id == scope.id).toList();
    return c.isEmpty ? 'Surah ${scope.id}' : c.first.nameSimple;
  }

  /// The memorization hero — the one place for goals: create, track, practice,
  /// and the daily-reminder bell.
  Widget _goalHero(MemorizationPlan? plan, int todayCount) {
    const gradient = LinearGradient(
      colors: [Color(0xFF0E7490), Color(0xFF155E75)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    if (plan == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Memorize the Quran',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "A few ayahs a day — we'll split it up, track you, and remind you.",
              style: TextStyle(color: Color(0xFFCFFAFE), fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0E7490),
                  minimumSize: const Size.fromHeight(42),
                ),
                onPressed: _openGoalSheet,
                icon: const Icon(Icons.flag_rounded, size: 17),
                label: const Text('Create my goal',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      );
    }

    final seq = scopeSequence(plan.scope, _chapters);
    final scopeDone =
        seq.where((r) => _mem.isMemorized(r.surahId, r.ayah)).length;
    final scopeTotal = seq.isEmpty ? 1 : seq.length;
    final pct = (scopeDone / scopeTotal).clamp(0.0, 1.0);
    final goalMet = todayCount >= plan.perDay;
    final streak = _mem.streak;
    final bellOn = _mem.reminder?.enabled ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 14),
      decoration: BoxDecoration(
        gradient: goalMet
            ? const LinearGradient(
                colors: [Color(0xFF15803D), Color(0xFF166534)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goalMet
                      ? 'Done for today 🎉'
                      : "Today · $todayCount of ${plan.perDay} ayahs",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
              ),
              if (streak > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('🔥 $streak day${streak == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: bellOn ? 'Daily reminder on' : 'Set daily reminder',
                onPressed: _onBellTap,
                icon: Icon(
                    bellOn
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: bellOn ? const Color(0xFFFDE68A) : Colors.white,
                    size: 20),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit goal',
                onPressed: _openGoalSheet,
                icon: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFDE68A)),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$scopeDone of $scopeTotal ayahs of ${_scopeLabel(plan.scope)} · ${(pct * 100).round()}%',
            style: const TextStyle(color: Color(0xFFCFFAFE), fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: goalMet
                    ? const Color(0xFF166534)
                    : const Color(0xFF0E7490),
                minimumSize: const Size.fromHeight(40),
              ),
              onPressed: _enterGoalMode,
              icon: Icon(
                  goalMet
                      ? Icons.replay_rounded
                      : Icons.play_arrow_rounded,
                  size: 18),
              label: Text(
                  goalMet ? 'Review anyway' : "Practice today's ayahs",
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0E7490),
        side: const BorderSide(color: Color(0xFFA5F3FC)),
        backgroundColor: const Color(0xFFECFEFF),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
    );
  }

  Widget _modeIcon(IconData icon, _ViewMode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 4)
                ]
              : null,
        ),
        child: Icon(icon,
            size: 17,
            color: selected
                ? const Color(0xFF0E7490)
                : const Color(0xFF94A3B8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memorizedInView = _verses
        .where((v) => _mem.isMemorized(v.chapterId, v.verseNumber))
        .length;
    final plan = _mem.plan;
    final todayCount = _mem.dailyLog[todayStr()] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _openSurahPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                  child: Text(_title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800))),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: _playingIndex != null ? 'Stop' : 'Play surah',
            onPressed: _verses.isEmpty
                ? null
                : () => _playingIndex != null
                    ? setState(_stopPlayback)
                    : _playFrom(0),
            icon: Icon(
              _playingIndex != null
                  ? Icons.stop_circle_rounded
                  : Icons.play_circle_fill_rounded,
              color: const Color(0xFF0E7490),
              size: 28,
            ),
          ),
          IconButton(
            tooltip: 'Repeat',
            onPressed: _verses.isEmpty ? null : _openRepeatSheet,
            icon: const Icon(Icons.repeat_rounded),
          ),
          PopupMenuButton<int>(
            tooltip: 'Reciter',
            icon: const Icon(Icons.record_voice_over_rounded),
            onSelected: (id) {
              setState(() => _reciter = id);
              _loadSelection();
            },
            itemBuilder: (_) => _reciters
                .map((r) => PopupMenuItem(
                    value: r.id,
                    child: Text(r.name,
                        style: TextStyle(
                            fontWeight: r.id == _reciter
                                ? FontWeight.w800
                                : FontWeight.w400))))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _goalHero(plan, todayCount),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                _pillButton(
                  icon: Icons.mic_rounded,
                  label: 'Recite from memory',
                  onTap: _verses.isEmpty
                      ? null
                      : () {
                          _stopPlayback();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => FollowAlongScreen(
                                  title: _title, verses: _verses)));
                        },
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _modeIcon(Icons.menu_book_rounded, _ViewMode.reading),
                      _modeIcon(
                          Icons.translate_rounded, _ViewMode.translation),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_verses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text('Memorized $memorizedInView/${_verses.length}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${_mem.totalMemorized} ayahs total',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError),
            TextButton(
                onPressed: _loadSelection, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_mode == _ViewMode.reading) return _readingView();
    return _translationView();
  }

  Widget _readingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 10,
          children: [
            for (var vi = 0; vi < _verses.length; vi++) ...[
              for (final word in _verses[vi].words)
                GestureDetector(
                  onTap: () => _playWord(word),
                  child: Text(
                    word.text,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 26,
                      height: 1.95,
                      color: _playingIndex == vi
                          ? const Color(0xFF0E7490)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              _verseBadge(vi),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verseBadge(int vi) {
    final verse = _verses[vi];
    final memorized = _mem.isMemorized(verse.chapterId, verse.verseNumber);
    return GestureDetector(
      onTap: () => _showVerseActions(vi),
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: memorized ? const Color(0xFFDCFCE7) : null,
          border: Border.all(
              color: memorized
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF0E7490).withValues(alpha: 0.35)),
        ),
        child: Text('${verse.verseNumber}',
            style: TextStyle(
                fontSize: 12,
                color: memorized
                    ? const Color(0xFF166534)
                    : const Color(0xFF0E7490)),
            textDirection: TextDirection.ltr),
      ),
    );
  }

  Widget _translationView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _verses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, vi) {
        final verse = _verses[vi];
        final memorized = _mem.isMemorized(verse.chapterId, verse.verseNumber);
        final playing = _playingIndex == vi;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: playing ? const Color(0xFFECFEFF) : const Color(0xFFFAFAF9),
            border: Border.all(
                color:
                    playing ? const Color(0xFFA5F3FC) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: [
                    for (final word in verse.words)
                      GestureDetector(
                        onTap: () => _playWord(word),
                        child: Text(word.text,
                            style: const TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 24,
                                height: 1.8)),
                      ),
                  ],
                ),
              ),
              if (verse.translation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(verse.translation,
                    style: const TextStyle(
                        fontSize: 13.5, color: Color(0xFF475569))),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(verse.verseKey,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0E7490))),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: playing ? 'Stop' : 'Play verse',
                    onPressed: () =>
                        playing ? setState(_stopPlayback) : _playFrom(vi),
                    icon: Icon(
                        playing
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_rounded,
                        color: const Color(0xFF0E7490)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Check your recitation',
                    onPressed: () => RecitationCheckSheet.show(context, verse),
                    icon: const Icon(Icons.mic_rounded,
                        color: Color(0xFF0E7490)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip:
                        memorized ? 'Memorized' : 'Mark memorized',
                    onPressed: () => _toggleMemorized(verse),
                    icon: Icon(
                        memorized
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: memorized
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVerseActions(int vi) {
    final verse = _verses[vi];
    final memorized = _mem.isMemorized(verse.chapterId, verse.verseNumber);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.play_circle_rounded, color: Color(0xFF0E7490)),
              title: Text('Play verse ${verse.verseKey}'),
              onTap: () {
                Navigator.pop(context);
                _playFrom(vi);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_rounded, color: Color(0xFF0E7490)),
              title: const Text('Check your recitation'),
              onTap: () {
                Navigator.pop(context);
                RecitationCheckSheet.show(context, verse);
              },
            ),
            ListTile(
              leading: Icon(
                  memorized
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: memorized
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF94A3B8)),
              title: Text(memorized ? 'Memorized ✓ (tap to unmark)' : 'Mark memorized'),
              onTap: () {
                Navigator.pop(context);
                _toggleMemorized(verse);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahJuzPicker extends StatefulWidget {
  final List<Chapter> chapters;
  const _SurahJuzPicker({required this.chapters});

  @override
  State<_SurahJuzPicker> createState() => _SurahJuzPickerState();
}

class _SurahJuzPickerState extends State<_SurahJuzPicker> {
  var _tab = 0;
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.chapters
        .where((c) =>
            _query.isEmpty ||
            c.nameSimple.toLowerCase().contains(_query.toLowerCase()) ||
            c.nameArabic.contains(_query) ||
            '${c.id}' == _query)
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Surah')),
              ButtonSegment(value: 1, label: Text('Juz')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          if (_tab == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search surah…',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          Expanded(
            child: _tab == 0
                ? ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: const Color(0xFFECFEFF),
                            child: Text('${c.id}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0E7490)))),
                        title: Text(c.nameSimple),
                        subtitle: Text(
                            '${c.translatedName} · ${c.versesCount} verses'),
                        trailing: Text(c.nameArabic,
                            style: const TextStyle(
                                fontFamily: 'Amiri', fontSize: 18)),
                        onTap: () => Navigator.pop(
                            context, (_NavKind.surah, c.id)),
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: 30,
                    itemBuilder: (context, i) => ListTile(
                      leading: CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFFECFEFF),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF0E7490)))),
                      title: Text('Juz ${i + 1}'),
                      onTap: () =>
                          Navigator.pop(context, (_NavKind.juz, i + 1)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
