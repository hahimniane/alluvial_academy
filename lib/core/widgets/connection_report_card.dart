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
  /// Enough to start a conversation, few enough to read at a glance.
  static const int _maxNames = 6;

  String _period = 'weekly';
  bool _loading = true;
  List<PresenceReport> _teachers = const [];

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // Only those with something to show, worst first, and only a handful: a
    // long list of zeroes buries the few names that need a conversation, and an
    // unbounded list would overflow the column this sits in.
    final withDrops =
        _teachers.where((t) => t.counted.drops > 0).take(_maxNames).toList();

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
                l10n.connectionOverviewEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              )
            else
              ...withDrops.map((teacher) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
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
                  )),
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
