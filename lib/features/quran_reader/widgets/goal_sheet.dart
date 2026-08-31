/// Memorization plan setup — mobile twin of the web goal dialog: choose what
/// to memorize (whole Quran / a surah / a juz) and a daily pace; we estimate
/// the finish time. Saved to the shared `quran_memorization/{uid}` doc.
library;

import 'package:flutter/material.dart';

import '../services/memorization_service.dart';
import '../services/quran_api.dart';

String humanDuration(int days) {
  if (days < 30) return days == 1 ? '1 day' : '$days days';
  if (days < 730) {
    final m = (days / 30.44).round().clamp(1, 24);
    return m == 1 ? '1 month' : '$m months';
  }
  final years = ((days / 365.25) * 10).round() / 10;
  return '$years years';
}

class GoalSheet extends StatefulWidget {
  final List<Chapter> chapters;
  final MemorizationPlan? currentPlan;
  final int alreadyMemorized;
  final void Function(PlanScope scope, int perDay) onSave;
  final VoidCallback? onClear;

  const GoalSheet({
    super.key,
    required this.chapters,
    required this.currentPlan,
    required this.alreadyMemorized,
    required this.onSave,
    this.onClear,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Chapter> chapters,
    required MemorizationPlan? currentPlan,
    required int alreadyMemorized,
    required void Function(PlanScope scope, int perDay) onSave,
    VoidCallback? onClear,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GoalSheet(
        chapters: chapters,
        currentPlan: currentPlan,
        alreadyMemorized: alreadyMemorized,
        onSave: onSave,
        onClear: onClear,
      ),
    );
  }

  @override
  State<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<GoalSheet> {
  late ScopeKind _kind;
  late int _id;
  late int _perDay;

  @override
  void initState() {
    super.initState();
    final plan = widget.currentPlan;
    _kind = plan?.scope.kind ?? ScopeKind.surah;
    _id = plan?.scope.id ?? 1;
    _perDay = plan?.perDay ?? 3;
    if (_kind == ScopeKind.quran) _id = 0;
  }

  int get _totalAyahs =>
      scopeSequence(PlanScope(_kind, _id), widget.chapters).length;

  @override
  Widget build(BuildContext context) {
    final total = _totalAyahs;
    final days = total == 0 ? 0 : (total / _perDay).ceil();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Memorization plan',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              "Pick what to memorize and your daily pace — we'll estimate how long it takes and show you a little each day.",
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            SegmentedButton<ScopeKind>(
              segments: const [
                ButtonSegment(value: ScopeKind.surah, label: Text('Surah')),
                ButtonSegment(value: ScopeKind.juz, label: Text('Juz')),
                ButtonSegment(
                    value: ScopeKind.quran, label: Text('Whole Quran')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _id = _kind == ScopeKind.quran ? 0 : 1;
              }),
            ),
            const SizedBox(height: 12),
            if (_kind == ScopeKind.surah)
              DropdownButtonFormField<int>(
                initialValue: _id,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Surah', border: OutlineInputBorder()),
                items: widget.chapters
                    .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.id}. ${c.nameSimple} (${c.versesCount})',
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _id = v ?? 1),
              ),
            if (_kind == ScopeKind.juz)
              DropdownButtonFormField<int>(
                initialValue: _id,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Juz', border: OutlineInputBorder()),
                items: [
                  for (var j = 1; j <= 30; j++)
                    DropdownMenuItem(value: j, child: Text('Juz $j'))
                ],
                onChanged: (v) => setState(() => _id = v ?? 1),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Ayahs per day',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Expanded(
                  child: Slider(
                    value: _perDay.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$_perDay',
                    onChanged: (v) => setState(() => _perDay = v.round()),
                  ),
                ),
                Text('$_perDay',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                border: Border.all(color: const Color(0xFFBBF7D0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                total == 0
                    ? 'Loading…'
                    : 'At $_perDay ayahs/day: $total ayahs · about ${humanDuration(days)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xFF166534)),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7490),
                  minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                widget.onSave(PlanScope(_kind, _id), _perDay);
                Navigator.of(context).pop();
              },
              child: Text(widget.currentPlan == null
                  ? 'Start memorizing'
                  : 'Update goal'),
            ),
            if (widget.currentPlan != null && widget.onClear != null)
              TextButton(
                onPressed: () {
                  widget.onClear!();
                  Navigator.of(context).pop();
                },
                child: const Text('Stop plan',
                    style: TextStyle(color: Color(0xFFDC2626))),
              ),
          ],
        ),
      ),
    );
  }
}
