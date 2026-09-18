import 'package:flutter/material.dart';

import 'package:alluwalacademyadmin/core/services/presence_report_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// A teacher's own connection during class.
///
/// Shown so somebody can act before their next lesson — move rooms, use a
/// hotspot, switch to mobile data. Everything here is their own connection:
/// interruptions the classroom system caused are counted apart and named as
/// ours, because a teacher should never read our hub restarting as their line
/// failing.
class ConnectionReportCard extends StatefulWidget {
  const ConnectionReportCard({super.key, this.uid});

  /// Whose report to show. Null means the signed-in person's own.
  final String? uid;

  @override
  State<ConnectionReportCard> createState() => _ConnectionReportCardState();
}

class _ConnectionReportCardState extends State<ConnectionReportCard> {
  String _period = 'weekly';
  bool _loading = true;
  PresenceReport? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report = await PresenceReportService.forPerson(
      uid: widget.uid,
      periodType: _period,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final report = _report;
    final counted = report?.counted ?? const PresenceTally();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_tethering, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.connectionReportTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _PeriodToggle(
                  period: _period,
                  onChanged: (next) {
                    setState(() => _period = next);
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.connectionReportSubtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else if (report == null || !report.hasAnything)
              Text(
                l10n.connectionReportNothingYet,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              )
            else ...[
              if (counted.drops == 0)
                Text(l10n.connectionReportHeld, style: theme.textTheme.bodyMedium),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Stat(
                    label: l10n.connectionReportTimesDropped,
                    value: '${counted.drops}',
                  ),
                  _Stat(
                    label: l10n.connectionReportTimeLost,
                    value: PresenceReportService.formatDuration(counted.secondsLost),
                  ),
                  _Stat(
                    label: l10n.connectionReportLongest,
                    value: PresenceReportService.formatDuration(counted.longestSeconds),
                  ),
                ],
              ),
              if (counted.neverReturned > 0) ...[
                const SizedBox(height: 12),
                _Note(
                  text: l10n.connectionReportNeverReturned(counted.neverReturned),
                  tone: Colors.amber.shade100,
                  textColor: Colors.amber.shade900,
                ),
              ],
              if (report.occasions.isNotEmpty)
                _OccasionList(occasions: report.occasions),
              if (report.platformDrops > 0) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.connectionReportOurFault(report.platformDrops),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The classes a set of totals is made of.
///
/// Collapsed by default: somebody checking a normal week wants the three
/// numbers, and only wants the detail when a figure looks wrong to them. Open,
/// it answers the two questions anybody actually asks — which day, and which
/// student was waiting.
class _OccasionList extends StatefulWidget {
  const _OccasionList({required this.occasions});

  final List<PresenceOccasion> occasions;

  @override
  State<_OccasionList> createState() => _OccasionListState();
}

class _OccasionListState extends State<_OccasionList> {
  bool _open = false;

  String _when(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[local.weekday - 1]} ${local.day} ${months[local.month - 1]}, '
        '${_clock(local)}';
  }

  String _clock(DateTime at) {
    final local = at.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1),
        TextButton(
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
          onPressed: () => setState(() => _open = !_open),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _open
                      ? l10n.connectionOccasionsHide
                      : l10n.connectionOccasionsShow(widget.occasions.length),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20),
            ],
          ),
        ),
        if (_open)
          ...widget.occasions.map((occasion) {
            final students = occasion.studentLine;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _when(occasion.startedAt),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${l10n.connectionOccasionDrops(occasion.drops)} · '
                        '${PresenceReportService.formatDuration(occasion.secondsLost)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                  if (occasion.className != null && occasion.className!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(occasion.className!, style: theme.textTheme.bodyMedium),
                  ],
                  if (students.isNotEmpty)
                    Text(
                      l10n.connectionOccasionWith(students),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                  const SizedBox(height: 8),
                  ...occasion.spells.map((spell) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            spell.from == null ? '' : _clock(spell.from!),
                            spell.returned
                                ? l10n.connectionSpellBack(
                                    PresenceReportService.formatDuration(spell.seconds ?? 0))
                                : l10n.connectionSpellNeverBack,
                            if (spell.isOurs) l10n.connectionSpellOurSide,
                          ].where((part) => part.isNotEmpty).join(' — '),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      )),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChanged});

  final String period;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<String>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(value: 'weekly', label: Text(l10n.connectionReportThisWeek)),
        ButtonSegment(value: 'monthly', label: Text(l10n.connectionReportThisMonth)),
      ],
      selected: {period},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.tone, required this.textColor});

  final String text;
  final Color tone;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: TextStyle(color: textColor)),
    );
  }
}

/// Every teacher's connection for a period, worst first.
///
/// For administrators, and the point of it is a conversation rather than a
/// ranking: somebody near the top needs help with their line, not a mark
/// against their name. Interruptions the classroom system caused are excluded
/// from these figures entirely.
class ConnectionOverviewCard extends StatefulWidget {
  const ConnectionOverviewCard({super.key});

  @override
  State<ConnectionOverviewCard> createState() => _ConnectionOverviewCardState();
}

class _ConnectionOverviewCardState extends State<ConnectionOverviewCard> {
  /// How tall the list may grow before it scrolls inside the card.
  static const double _listMaxHeight = 460;

  String _period = 'weekly';
  bool _loading = true;
  List<PresenceReport> _teachers = const [];
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final teachers = await PresenceReportService.overview(periodType: _period);
    if (!mounted) return;
    setState(() {
      _teachers = teachers;
      _loading = false;
    });
  }

  /// Everyone who dropped out, worst first, narrowed by the search box.
  ///
  /// Nobody is hidden by a cap: the whole point of looking here is to find one
  /// teacher, and a list that quietly stopped at six would answer "they are
  /// fine" for the seventh.
  List<PresenceReport> get _visible {
    final query = _query.trim().toLowerCase();
    return _teachers.where((teacher) {
      if (teacher.counted.drops == 0) return false;
      if (query.isEmpty) return true;
      final name = (teacher.name ?? teacher.uid).toLowerCase();
      if (name.contains(query)) return true;
      // A name half-remembered is often a class or a student instead.
      return teacher.occasions.any((occasion) =>
          (occasion.className ?? '').toLowerCase().contains(query) ||
          occasion.students.any((s) => s.toLowerCase().contains(query)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final withDrops = _visible;
    final anyoneDropped = _teachers.any((t) => t.counted.drops > 0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_tethering, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.connectionOverviewTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _PeriodToggle(
                  period: _period,
                  onChanged: (next) {
                    setState(() => _period = next);
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.connectionOverviewSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 16),
            if (!_loading && anyoneDropped) ...[
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: l10n.connectionOverviewSearchHint,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else if (withDrops.isEmpty)
              Text(
                anyoneDropped
                    ? l10n.connectionOverviewNoMatch(_query)
                    : l10n.connectionOverviewEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _listMaxHeight),
                child: ListView(
                  shrinkWrap: true,
                  children: withDrops.map((teacher) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    teacher.name ?? teacher.uid,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    l10n.connectionOverviewClasses(teacher.classes),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: theme.hintColor),
                                  ),
                                ],
                              ),
                            ),
                            _Pill(
                              label: '${teacher.counted.drops}',
                              sub: l10n.connectionReportTimesDropped,
                            ),
                            const SizedBox(width: 8),
                            _Pill(
                              label: PresenceReportService
                                  .formatDuration(teacher.counted.secondsLost),
                              sub: l10n.connectionReportTimeLost,
                            ),
                          ],
                        ),
                        // The classes behind this teacher's figure, so a
                        // conversation about it can start from the record
                        // rather than from the total.
                        if (teacher.occasions.isNotEmpty)
                          _OccasionList(occasions: teacher.occasions),
                      ],
                    ),
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.sub});

  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(sub, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
      ],
    );
  }
}
