import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/features/shift_management/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/features/shift_management/services/shift_trade_service.dart';
import 'package:alluwalacademyadmin/features/shift_management/services/shift_trading.dart';
import '../../../core/widgets/timezone_selector_field.dart';
import 'package:alluwalacademyadmin/core/utils/app_logger.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Compact dialog for teachers to report schedule issues and fix timezone
class ReportScheduleIssueDialog extends StatefulWidget {
  final TeachingShift shift;

  /// Finds the days of a recurring class that can be offered together.
  /// Tests pass their own; the app looks them up.
  final Future<List<TeachingShift>> Function(TeachingShift opened)?
      offerChoicesLoader;

  const ReportScheduleIssueDialog({
    super.key,
    required this.shift,
    this.offerChoicesLoader,
  });

  @override
  State<ReportScheduleIssueDialog> createState() =>
      _ReportScheduleIssueDialogState();
}

class _ReportScheduleIssueDialogState extends State<ReportScheduleIssueDialog> {
  String? _selectedTimezone;
  String? _issueType; // 'timezone', 'incorrect_time', 'other'
  DateTime? _correctedStartTime;
  DateTime? _correctedEndTime;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  String? _currentUserTimezone;

  // Offering a recurring class: the days of the series that can go together.
  List<TeachingShift> _offerChoices = const [];
  Set<String> _offerTicked = <String>{};
  bool _offerChoicesLoading = false;
  bool _offerChoicesLoaded = false;

  bool get _isDuty => ShiftTrading.isLeadershipDuty(widget.shift);

  bool get _isSeries => (widget.shift.templateId?.trim() ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadCurrentTimezone();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTimezone() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final timezone = userDoc.data()?['timezone'] as String?;
        setState(() {
          _currentUserTimezone = timezone ?? 'UTC';
          _selectedTimezone = timezone ?? 'UTC';
        });
      }
    } catch (e) {
      AppLogger.error('Error loading timezone: $e');
    }
  }

  /// Loads the other upcoming days of this recurring class, once.
  Future<void> _loadOfferChoices() async {
    if (_offerChoicesLoaded || _offerChoicesLoading) return;
    setState(() {
      _offerChoicesLoading = true;
      _offerChoices = [widget.shift];
      _offerTicked = ShiftTrading.pickOnlyThis(widget.shift);
    });
    final loader =
        widget.offerChoicesLoader ?? ShiftTradeService.seriesOfferChoices;
    final choices =
        _isSeries ? await loader(widget.shift) : <TeachingShift>[widget.shift];
    if (!mounted) return;
    setState(() {
      _offerChoices = choices;
      _offerChoicesLoading = false;
      _offerChoicesLoaded = true;
    });
  }

  String _offerDayLabel(TeachingShift shift) {
    final locale = AppLocalizations.of(context)!.localeName;
    final day = DateFormat('EEE, MMM d', locale).format(shift.shiftStart);
    final from = DateFormat.jm(locale).format(shift.shiftStart);
    final to = DateFormat.jm(locale).format(shift.shiftEnd);
    return '$day · $from – $to';
  }

  String _offerFailureText(ShiftOfferFailure? failure) {
    final l10n = AppLocalizations.of(context)!;
    switch (failure) {
      case ShiftOfferFailure.alreadyStarted:
        return l10n.shiftOfferFailStarted;
      case ShiftOfferFailure.notScheduled:
        return l10n.shiftOfferFailNotScheduled;
      case ShiftOfferFailure.notYours:
        return l10n.shiftOfferFailNotYours;
      case ShiftOfferFailure.notFound:
        return l10n.shiftOfferFailNotFound;
      case ShiftOfferFailure.other:
      case null:
        return l10n.shiftOfferFailOther;
    }
  }

  /// Offers the ticked days with one call. Returns true when at least one day
  /// is on offer afterwards, so the caller knows whether to file the report.
  Future<bool> _submitOffer() async {
    final l10n = AppLocalizations.of(context)!;
    final ids = _offerChoicesLoaded
        ? ShiftTrading.idsToOffer(ticked: _offerTicked, choices: _offerChoices)
        : <String>[widget.shift.id];
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.shiftOfferPickADay),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    final List<ShiftOfferResult> results;
    try {
      results = await ShiftTradeService.setOffers(shiftIds: ids, offered: true);
    } catch (e) {
      AppLogger.error('Error offering shifts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shiftOfferNotSaved),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    final offeredCount = results.where((r) => r.ok).length;
    final failed = results.where((r) => !r.ok).toList();
    if (!mounted) return offeredCount > 0;

    if (failed.isNotEmpty) {
      final byId = {for (final s in _offerChoices) s.id: s};
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            l10n.shiftOfferSomeFailedTitle,
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _offerDayLabel(byId[r.shiftId] ?? widget.shift),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          _offerFailureText(r.failure),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      );
    }

    if (offeredCount == 0 && mounted) {
      // Nothing went through: show the days as they stand now.
      _offerChoicesLoaded = false;
      _loadOfferChoices();
    }

    if (offeredCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.shiftOfferPosted(offeredCount)),
          backgroundColor: Colors.green,
        ),
      );
    }
    return offeredCount > 0;
  }

  Future<void> _submitReport() async {
    if (_issueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectAnIssueType),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Offering goes through the server, which checks every day on its own.
      // The report below is filed only when something is actually on offer.
      if (_issueType == 'publish') {
        final offered = await _submitOffer();
        if (!offered) return;
      }

      final reportData = {
        'shift_id': widget.shift.id,
        'teacher_id': user.uid,
        'teacher_name': widget.shift.teacherName,
        'issue_type': _issueType,
        'reported_at': FieldValue.serverTimestamp(),
        'notes': _notesController.text.trim(),
      };

      // Add timezone update if changed
      if (_issueType == 'timezone' &&
          _selectedTimezone != null &&
          _selectedTimezone != _currentUserTimezone) {
        // Update user timezone
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'timezone': _selectedTimezone,
          'timezone_updated_at': FieldValue.serverTimestamp(),
        });

        // Also update via Cloud Function for consistency
        try {
          await FirebaseFunctions.instance
              .httpsCallable('updateUserTimezone')
              .call({
            'timezone': _selectedTimezone,
          });
        } catch (e) {
          AppLogger.debug(
              'Cloud function call failed, using direct update: $e');
        }

        reportData['old_timezone'] = _currentUserTimezone;
        reportData['new_timezone'] = _selectedTimezone;
      }

      // Add corrected times if provided
      if (_issueType == 'incorrect_time') {
        if (_correctedStartTime != null) {
          reportData['corrected_start_time'] =
              Timestamp.fromDate(_correctedStartTime!);
        }
        if (_correctedEndTime != null) {
          reportData['corrected_end_time'] =
              Timestamp.fromDate(_correctedEndTime!);
        }
        reportData['current_start_time'] =
            Timestamp.fromDate(widget.shift.shiftStart);
        reportData['current_end_time'] =
            Timestamp.fromDate(widget.shift.shiftEnd);
      }

      // Save report to Firestore
      try {
        await FirebaseFirestore.instance
            .collection('schedule_issue_reports')
            .add(reportData);
      } catch (e) {
        // The offer itself is already posted; a missing report must not make
        // it look as if it failed.
        if (_issueType != 'publish') rethrow;
        AppLogger.error('Error saving the offer report: $e');
      }

      if (mounted) {
        // An offer has already said what happened, day by day.
        if (_issueType != 'publish') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _issueType == 'timezone'
                    ? 'Timezone updated! Schedule will refresh.'
                    : 'Issue reported! Admin will review and fix it.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        Navigator.pop(context, true); // Return true to indicate refresh needed
      }
    } catch (e) {
      AppLogger.error('Error submitting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorE),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.report_problem,
                      color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.reportScheduleIssue,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Issue Type Selection
            Text(
              AppLocalizations.of(context)!.whatSTheIssue,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            _buildIssueTypeOption(
                'timezone', 'My timezone is wrong', Icons.access_time),
            const SizedBox(height: 8),
            _buildIssueTypeOption(
                'incorrect_time', 'Shift time is incorrect', Icons.schedule),
            const SizedBox(height: 8),
            // Only a class that has not started can be handed to another
            // teacher, and only once.
            if (!widget.shift.isPublished &&
                widget.shift.status == ShiftStatus.scheduled &&
                widget.shift.shiftStart.isAfter(DateTime.now())) ...[
              _buildIssueTypeOption(
                  'publish',
                  _isDuty
                      ? AppLocalizations.of(context)!.shiftOfferDutyToLeaders
                      : AppLocalizations.of(context)!.offerShiftToOtherTeachers,
                  Icons.public),
              const SizedBox(height: 8),
            ],
            _buildIssueTypeOption('other', 'Other issue', Icons.info_outline),

            const SizedBox(height: 20),

            // Which days to offer (a recurring class can go several at once)
            if (_issueType == 'publish' && _isSeries) ...[
              _buildOfferDaysPicker(),
              const SizedBox(height: 12),
            ],

            // Timezone Selection (if timezone issue)
            if (_issueType == 'timezone') ...[
              Text(
                AppLocalizations.of(context)!.selectYourCorrectTimezone,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              TimezoneSelectorField(
                selectedTimezone: _selectedTimezone ?? 'UTC',
                borderRadius: BorderRadius.circular(8),
                borderColor: const Color(0xFFE2E8F0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                textStyle: GoogleFonts.inter(fontSize: 14),
                onTimezoneSelected: (value) =>
                    setState(() => _selectedTimezone = value),
              ),
              const SizedBox(height: 12),
            ],

            // Corrected Times (if incorrect time issue)
            if (_issueType == 'incorrect_time') ...[
              Text(
                AppLocalizations.of(context)!.whatShouldTheCorrectTimesBe,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTimePicker(
                      'Start Time',
                      _correctedStartTime ?? widget.shift.shiftStart,
                      (time) => setState(() => _correctedStartTime = time),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTimePicker(
                      'End Time',
                      _correctedEndTime ?? widget.shift.shiftEnd,
                      (time) => setState(() => _correctedEndTime = time),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Notes
            Text(
              AppLocalizations.of(context)!.additionalNotesOptional,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.explainTheIssue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0386FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        AppLocalizations.of(context)!.timesheetSubmit,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        )),
      ),
    );
  }

  Widget _buildIssueTypeOption(String value, String label, IconData icon) {
    final isSelected = _issueType == value;
    return InkWell(
      onTap: () {
        setState(() => _issueType = value);
        if (value == 'publish') _loadOfferChoices();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0386FF).withOpacity(0.1)
              : const Color(0xFFF8FAFC),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0386FF) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF0386FF)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0386FF)
                      : const Color(0xFF374151),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF0386FF), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferDaysPicker() {
    final l10n = AppLocalizations.of(context)!;
    final opened = widget.shift;
    final hasOthers = _offerChoices.length > 1;

    Widget quickPick(String label, Set<String> Function() pick) {
      return ActionChip(
        label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
        visualDensity: VisualDensity.compact,
        onPressed: () => setState(() => _offerTicked = pick()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shiftOfferWhichDays,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        if (_offerChoicesLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          if (hasOthers) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                quickPick(l10n.shiftOfferOnlyThis,
                    () => ShiftTrading.pickOnlyThis(opened)),
                quickPick(
                    l10n.shiftOfferNextThree,
                    () => ShiftTrading.pickNext(
                        opened: opened, choices: _offerChoices, count: 3)),
                quickPick(
                    l10n.shiftOfferThisWeek,
                    () => ShiftTrading.pickSameWeek(
                        opened: opened, choices: _offerChoices)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _offerChoices.length,
              itemBuilder: (context, index) {
                final day = _offerChoices[index];
                final alreadyOffered = day.isPublished;
                return CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  value: alreadyOffered || _offerTicked.contains(day.id),
                  onChanged: alreadyOffered
                      ? null
                      : (ticked) => setState(() {
                            if (ticked == true) {
                              _offerTicked.add(day.id);
                            } else {
                              _offerTicked.remove(day.id);
                            }
                          }),
                  title: Text(
                    _offerDayLabel(day),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  subtitle: alreadyOffered
                      ? Text(
                          l10n.shiftOfferAlreadyOffered,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF6B7280),
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimePicker(
      String label, DateTime initialTime, Function(DateTime) onTimeSelected) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: initialTime,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(initialTime),
          );
          if (time != null) {
            final selectedDateTime = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
            onTimeSelected(selectedDateTime);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, h:mm a').format(initialTime),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
