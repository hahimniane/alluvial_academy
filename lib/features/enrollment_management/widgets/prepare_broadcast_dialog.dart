import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/enrollment_request.dart';
import '../../../core/services/job_board_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Data collected from the broadcast preparation dialog.
class BroadcastPrepareResult {
  final List<String> days;
  final List<String> timeSlots;
  final String? timeOfDayPreference;
  final String scheduleTimezoneRef;
  final String? adminNotesForTeachers;

  const BroadcastPrepareResult({
    required this.days,
    required this.timeSlots,
    this.timeOfDayPreference,
    required this.scheduleTimezoneRef,
    this.adminNotesForTeachers,
  });
}

class PrepareAndBroadcastDialog extends StatefulWidget {
  final EnrollmentRequest enrollment;

  const PrepareAndBroadcastDialog({
    super.key,
    required this.enrollment,
  });

  @override
  State<PrepareAndBroadcastDialog> createState() => _PrepareAndBroadcastDialogState();
}

class _PrepareAndBroadcastDialogState extends State<PrepareAndBroadcastDialog> {
  late List<String> _selectedDays;
  late List<String> _timeSlots;
  late String? _timeOfDay;
  late String _scheduleTimezone;
  final _adminNotesController = TextEditingController();
  bool _isBroadcasting = false;

  static const _allDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  static const _timeOfDayOptions = [
    'Morning (8am-12pm)',
    'Afternoon (12pm-5pm)',
    'Evening (5pm-9pm)',
    'Flexible',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.enrollment;
    _selectedDays = List<String>.from(e.preferredDays);
    _timeSlots = List<String>.from(e.preferredTimeSlots);
    _timeOfDay = e.timeOfDayPreference;
    _scheduleTimezone = e.timeZone.isNotEmpty ? e.timeZone : 'UTC';
  }

  @override
  void dispose() {
    _adminNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.enrollment;
    final screenW = MediaQuery.of(context).size.width;
    final dialogWidth = screenW > 900 ? 680.0 : (screenW * 0.92).clamp(340.0, 680.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStudentSummary(e),
                    const SizedBox(height: 20),
                    if (e.schedulingNotes != null && e.schedulingNotes!.trim().isNotEmpty)
                      _buildSchedulingNotes(e.schedulingNotes!),
                    _buildSectionTitle(AppLocalizations.of(context)!.prepareBroadcastScheduleForTeachers, Icons.calendar_month),
                    const SizedBox(height: 12),
                    _buildDayChips(),
                    const SizedBox(height: 16),
                    _buildTimeSlotEditor(),
                    const SizedBox(height: 16),
                    _buildTimeOfDayDropdown(),
                    const SizedBox(height: 20),
                    _buildSectionTitle(AppLocalizations.of(context)!.prepareBroadcastTimezoneReference, Icons.public),
                    const SizedBox(height: 8),
                    _buildTimezoneSelector(),
                    const SizedBox(height: 20),
                    _buildSectionTitle(AppLocalizations.of(context)!.prepareBroadcastNotesForTeachers, Icons.note_alt_outlined),
                    const SizedBox(height: 8),
                    _buildAdminNotesField(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildDialogActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        color: Color(0xffEFF6FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff3B82F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sensors, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.prepareBroadcastTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!.prepareBroadcastSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSummary(EnrollmentRequest e) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff3B82F6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xff3B82F6), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.studentName ?? 'Student',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    e.programTitle ?? e.subject,
                    if (e.gradeLevel.isNotEmpty) e.gradeLevel,
                    if (e.sessionDuration != null) e.sessionDuration,
                    if (e.classType != null) e.classType,
                  ].whereType<String>().join(' • '),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xff64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulingNotes(String notes) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xffFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xffFCD34D)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.campaign, color: Color(0xffD97706), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.prepareBroadcastParentStudentNotes,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff92400E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notes.trim(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xff78350F),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xff475569)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xff1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildDayChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allDays.map((day) {
        final selected = _selectedDays.contains(day);
        return FilterChip(
          label: Text(
            day.substring(0, 3),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xff475569),
            ),
          ),
          selected: selected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _selectedDays.add(day);
              } else {
                _selectedDays.remove(day);
              }
            });
          },
          selectedColor: const Color(0xff3B82F6),
          backgroundColor: const Color(0xffF1F5F9),
          checkmarkColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected ? const Color(0xff3B82F6) : const Color(0xffCBD5E1),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSlotEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.prepareBroadcastTimeSlots,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xff475569),
          ),
        ),
        const SizedBox(height: 8),
        if (_timeSlots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xffFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffFCA5A5)),
            ),
            child: Text(
              AppLocalizations.of(context)!.prepareBroadcastNoTimeSlots,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xff991B1B)),
            ),
          )
        else
          ...List.generate(_timeSlots.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Color(0xff94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xffF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffE2E8F0)),
                      ),
                      child: Text(
                        _timeSlots[i],
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff1E293B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => setState(() => _timeSlots.removeAt(i)),
                    icon: const Icon(Icons.close, size: 16, color: Color(0xffEF4444)),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    tooltip: AppLocalizations.of(context)!.prepareBroadcastRemoveSlot,
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffCBD5E1)),
                ),
                child: Text(
                  AppLocalizations.of(context)!.prepareBroadcastPickSlotHint,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xff64748B)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _pickAndAddTimeSlot,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(AppLocalizations.of(context)!.prepareBroadcastPickTime),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickAndAddTimeSlot() async {
    final l = AppLocalizations.of(context)!;
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
      helpText: l.prepareBroadcastPickStartTime,
    );
    if (start == null || !mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (start.hour + 1) % 24,
        minute: start.minute,
      ),
      helpText: l.prepareBroadcastPickEndTime,
    );
    if (end == null || !mounted) return;

    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) {
      _showError(AppLocalizations.of(context)!.prepareBroadcastEndBeforeStart);
      return;
    }

    final slot = '${_formatTime(start)} - ${_formatTime(end)}';
    if (_timeSlots.contains(slot)) {
      _showError(AppLocalizations.of(context)!.prepareBroadcastSlotAlreadyExists);
      return;
    }

    for (final existing in _timeSlots) {
      final parsed = _parseRange(existing);
      if (parsed == null) continue;
      final overlaps =
          startMinutes < parsed.$2 && endMinutes > parsed.$1;
      if (overlaps) {
        _showError(AppLocalizations.of(context)!.prepareBroadcastOverlapError(existing));
        return;
      }
    }

    setState(() {
      _timeSlots.add(slot);
    });
  }

  String _formatTime(TimeOfDay time) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(
      time,
      alwaysUse24HourFormat: false,
    );
  }

  (int, int)? _parseRange(String value) {
    final parts = value.split(' - ');
    if (parts.length != 2) return null;
    final start = _parseTime(parts.first.trim());
    final end = _parseTime(parts.last.trim());
    if (start == null || end == null) return null;
    return (start, end);
  }

  int? _parseTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(value.trim());
    if (match == null) return null;
    final hourRaw = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();
    if (hourRaw == null || minute == null) return null;
    var hour = hourRaw % 12;
    if (period == 'PM') hour += 12;
    return hour * 60 + minute;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildTimeOfDayDropdown() {
    return Row(
      children: [
        Text(
          AppLocalizations.of(context)!.prepareBroadcastGeneralPreference,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xff475569),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _timeOfDayOptions.contains(_timeOfDay) ? _timeOfDay : null,
            items: _timeOfDayOptions.map((opt) {
              return DropdownMenuItem(value: opt, child: Text(opt, style: GoogleFonts.inter(fontSize: 13)));
            }).toList(),
            onChanged: (v) => setState(() => _timeOfDay = v),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xffCBD5E1)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimezoneSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.prepareBroadcastTimesAreIn,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xff0C4A6E),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _scheduleTimezone,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.public, size: 18, color: Color(0xff0284C7)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xffBAE6FD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xffBAE6FD)),
              ),
              helperText: AppLocalizations.of(context)!.prepareBroadcastTimezoneHelper,
              helperStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xff64748B)),
            ),
            onChanged: (v) => _scheduleTimezone = v.trim(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNotesField() {
    return TextField(
      controller: _adminNotesController,
      maxLines: 3,
      style: GoogleFonts.inter(fontSize: 13),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.prepareBroadcastAdminNotesHint,
        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xff94A3B8)),
        isDense: true,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xff3B82F6), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDialogActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Row(
        children: [
          TextButton(
            onPressed: _isBroadcasting ? null : () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.commonCancel,
              style: GoogleFonts.inter(color: const Color(0xff64748B)),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _isBroadcasting ? null : () => _doBroadcast(context),
            icon: _isBroadcasting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sensors, size: 18),
            label: Text(
              _isBroadcasting
                  ? AppLocalizations.of(context)!.prepareBroadcastBroadcasting
                  : AppLocalizations.of(context)!.prepareBroadcastBroadcastToTeachers,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doBroadcast(BuildContext context) async {
    if (_selectedDays.isEmpty) {
      _showError(AppLocalizations.of(context)!.prepareBroadcastSelectDayFirst);
      return;
    }
    if (_timeSlots.isEmpty) {
      _showError(AppLocalizations.of(context)!.prepareBroadcastAddTimeSlotFirst);
      return;
    }
    setState(() => _isBroadcasting = true);
    try {
      final adminNotes = _adminNotesController.text.trim();
      await JobBoardService().broadcastEnrollment(
        widget.enrollment,
        overrideDays: _selectedDays,
        overrideTimeSlots: _timeSlots,
        overrideTimeOfDay: _timeOfDay,
        scheduleTimezoneRef: _scheduleTimezone,
        adminNotesForTeachers: adminNotes.isEmpty ? null : adminNotes,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.broadcastLiveTeachersCanNowSee),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.length > 120 ? '${msg.substring(0, 120)}...' : msg),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isBroadcasting = false);
      }
    }
  }
}
