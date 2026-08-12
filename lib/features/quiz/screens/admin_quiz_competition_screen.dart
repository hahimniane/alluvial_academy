import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../config/quiz_competition_divisions.dart';
import '../models/quiz_competition.dart';
import '../services/quiz_competition_service.dart';

class AdminQuizCompetitionScreen extends StatefulWidget {
  const AdminQuizCompetitionScreen({super.key});

  @override
  State<AdminQuizCompetitionScreen> createState() =>
      _AdminQuizCompetitionScreenState();
}

class _AdminQuizCompetitionScreenState
    extends State<AdminQuizCompetitionScreen> {
  final QuizCompetitionService _service = QuizCompetitionService();
  late String _monthKey;
  String _divisionId = 'early_learners';
  late Future<QuizCompetitionSnapshot> _future;
  bool _finalizing = false;

  @override
  void initState() {
    super.initState();
    _monthKey = _keyFor(DateTime.now());
    _future = _service.loadLeaderboard(
      monthKey: _monthKey,
      divisionId: _divisionId,
    );
  }

  String _keyFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _engagementLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'qualified':
        return l10n.quizCompetitionStatusQualified;
      case 'participating':
        return l10n.quizCompetitionStatusParticipating;
      case 'needs_encouragement':
        return l10n.quizCompetitionStatusNeedsEncouragement;
      default:
        return l10n.quizCompetitionStatusNotStarted;
    }
  }

  Color _engagementColor(String status) {
    switch (status) {
      case 'qualified':
        return const Color(0xFF047857);
      case 'participating':
        return const Color(0xFF2563EB);
      case 'needs_encouragement':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _load(String monthKey, {String? divisionId}) {
    setState(() {
      _monthKey = monthKey;
      _divisionId = divisionId ?? _divisionId;
      _future = _service.loadLeaderboard(
        monthKey: monthKey,
        divisionId: _divisionId,
      );
    });
  }

  DateTime _dateForKey(String value) =>
      DateTime.tryParse(value) ?? DateTime.now();

  String _dateKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _setWindow(QuizCompetitionSnapshot competition) async {
    final l10n = AppLocalizations.of(context)!;
    final monthStart = DateTime.tryParse('${competition.monthKey}-01');
    if (monthStart == null) return;
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
    final start = await showDatePicker(
      context: context,
      firstDate: monthStart,
      lastDate: monthEnd,
      initialDate: _dateForKey(competition.countingStartDate),
      helpText: l10n.quizCompetitionCountingStart,
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      firstDate: start,
      lastDate: monthEnd,
      initialDate: _dateForKey(competition.countingEndDate),
      helpText: l10n.quizCompetitionCountingEnd,
    );
    if (end == null || !mounted) return;
    try {
      await _service.setCompetitionWindow(
        monthKey: competition.monthKey,
        startDate: _dateKey(start),
        endDate: _dateKey(end),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizCompetitionWindowSaved)),
      );
      _load(competition.monthKey);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewActionFailed(error.toString()))),
      );
    }
  }

  Future<void> _assignDivision(
    QuizCompetitionSnapshot competition,
    QuizCompetitionEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    var selectedDivision = quizCompetitionDivisionIds.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.quizCompetitionAssignDivisionTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.displayName),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedDivision,
                decoration: InputDecoration(
                  labelText: l10n.quizCompetitionAssignDivision,
                  border: const OutlineInputBorder(),
                ),
                items: quizCompetitionDivisionIds
                    .map((id) => DropdownMenuItem(
                          value: id,
                          child: Text(quizCompetitionDivisionLabel(l10n, id)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedDivision = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: l10n.quizCompetitionAssignDivisionReason,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.quizCompetitionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.quizCompetitionAssignDivision),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }
    try {
      await _service.assignDivision(
        studentUid: entry.uid,
        monthKey: competition.monthKey,
        divisionId: selectedDivision,
        reason: reasonController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizCompetitionAssignDivisionSaved)),
      );
      _load(competition.monthKey, divisionId: 'unassigned');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewActionFailed(error.toString()))),
      );
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _chooseMonth() async {
    final parts = _monthKey.split('-');
    final initial = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (selected != null) _load(_keyFor(selected));
  }

  Future<void> _finalize(QuizCompetitionSnapshot snapshot) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.quizCompetitionFinalizeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.quizCompetitionFinalizeBody),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: l10n.quizCompetitionFinalizeReason,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.quizCompetitionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.quizCompetitionFinalize),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _finalizing = true);
    try {
      await _service.finalize(
        monthKey: snapshot.monthKey,
        reason: controller.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizCompetitionFinalized)),
      );
      _load(snapshot.monthKey);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizReviewActionFailed(error.toString()))),
      );
    } finally {
      controller.dispose();
      if (mounted) setState(() => _finalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.quizCompetitionAdminTitle)),
      body: FutureBuilder<QuizCompetitionSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => _load(_monthKey),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.quizCompetitionRetry),
              ),
            );
          }
          final competition = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.quizCompetitionMonth(competition.monthKey),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _chooseMonth,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(l10n.quizCompetitionChooseMonth),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.quizCompetitionFairRules(
                competition.minimumQuestions,
                competition.minimumActiveDays,
                (competition.minimumAccuracy * 100).round(),
                competition.minimumEligibleParticipants,
              )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.quizCompetitionCountingWindow(
                      competition.countingStartDate,
                      competition.countingEndDate,
                    )),
                  ),
                  TextButton.icon(
                    onPressed: () => _setWindow(competition),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(l10n.quizCompetitionSetWindow),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: competition.divisionId,
                decoration: InputDecoration(
                  labelText: l10n.quizCompetitionDivision(
                    quizCompetitionDivisionLabel(
                      l10n,
                      competition.divisionId,
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: competition.divisions
                    .map((division) => DropdownMenuItem(
                          value: division.id,
                          child: Text(
                            '${quizCompetitionDivisionLabel(l10n, division.id)} — '
                            '${l10n.quizCompetitionDivisionSummary(division.participantCount, division.eligibleCount)}',
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _load(competition.monthKey, divisionId: value);
                  }
                },
              ),
              const SizedBox(height: 20),
              Text(
                l10n.quizCompetitionParticipationTitle,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (competition.engagement.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(l10n.quizCompetitionParticipationEmpty),
                )
              else
                ...competition.engagement.map((student) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.school_outlined),
                        ),
                        title: Text(student.displayName),
                        subtitle: Text(l10n.quizCompetitionEntryStats(
                          student.answeredCount,
                          student.correctCount,
                          student.activeDays,
                        )),
                        trailing: Chip(
                          label: Text(
                            _engagementLabel(l10n, student.status),
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: _engagementColor(student.status),
                          side: BorderSide.none,
                        ),
                      ),
                    )),
              const SizedBox(height: 20),
              if (competition.winners.isNotEmpty)
                Card(
                  color: const Color(0xFFFFF7D6),
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events,
                        color: Color(0xFFF59E0B)),
                    title: Text(competition.winners.length == 1
                        ? l10n.quizCompetitionWinner(
                            competition.winners.first.displayName)
                        : l10n.quizCompetitionCoWinners(competition.winners
                            .map((winner) => winner.displayName)
                            .join(', '))),
                    subtitle: Text(l10n.quizCompetitionAnswered(
                        competition.winners.first.answeredCount)),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                l10n.quizCompetitionLeaderboard,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (competition.leaderboard.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    l10n.quizCompetitionNoParticipants,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...competition.leaderboard.map((entry) => Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${entry.rank}')),
                        title: Text(entry.displayName),
                        subtitle: Text(l10n.quizCompetitionEntryStats(
                          entry.answeredCount,
                          entry.correctCount,
                          entry.activeDays,
                        )),
                        trailing: competition.divisionId == 'unassigned'
                            ? TextButton(
                                onPressed: () =>
                                    _assignDivision(competition, entry),
                                child: Text(l10n.quizCompetitionAssignDivision),
                              )
                            : entry.eligible
                                ? const Icon(Icons.verified,
                                    color: Color(0xFF10B981))
                                : null,
                      ),
                    )),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _finalizing ? null : () => _finalize(competition),
                icon: _finalizing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.emoji_events),
                label: Text(competition.isFinalized
                    ? l10n.quizCompetitionRefinalize
                    : l10n.quizCompetitionFinalize),
              ),
            ],
          );
        },
      ),
    );
  }
}
