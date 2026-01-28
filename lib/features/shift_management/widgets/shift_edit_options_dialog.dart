import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

enum ShiftEditOptionMode {
  single,
  series,
  studentAll,
  studentTimeRange,
}

class ShiftEditOptionsResult {
  final ShiftEditOptionMode mode;
  final String? studentId;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  const ShiftEditOptionsResult({
    required this.mode,
    this.studentId,
    this.startTime,
    this.endTime,
  });
}

class ShiftEditOptionsDialog extends StatefulWidget {
  final TeachingShift shift;

  const ShiftEditOptionsDialog({
    super.key,
    required this.shift,
  });

  @override
  State<ShiftEditOptionsDialog> createState() => _ShiftEditOptionsDialogState();
}

class _ShiftEditOptionsDialogState extends State<ShiftEditOptionsDialog> {
  late final Future<({String seriesId, List<TeachingShift> shifts})?>
      _seriesFuture;

  @override
  void initState() {
    super.initState();
    _seriesFuture = ShiftService.getRecurringSeriesByShift(widget.shift.id);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildOption(
              title: AppLocalizations.of(context)!.editThisShiftOnly,
              subtitle: AppLocalizations.of(context)!.quickEditOrFullEditorFor,
              icon: Icons.edit,
              onTap: () => Navigator.pop(
                context,
                const ShiftEditOptionsResult(mode: ShiftEditOptionMode.single),
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<({String seriesId, List<TeachingShift> shifts})?>(
              future: _seriesFuture,
              builder: (context, snapshot) {
                final series = snapshot.data;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildOption(
                    title: AppLocalizations.of(context)!.editAllInSeries,
                    subtitle: AppLocalizations.of(context)!.loadingSeries,
                    icon: Icons.repeat,
                    onTap: null,
                    trailing: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                if (series == null || series.shifts.length <= 1) {
                  return const SizedBox.shrink();
                }

                return _buildOption(
                  title: AppLocalizations.of(context)!
                      .editAllInSeriesCount(series.shifts.length),
                  subtitle:
                      AppLocalizations.of(context)!.applyChangesToAllShiftsAnd,
                  icon: Icons.repeat,
                  onTap: () => Navigator.pop(
                    context,
                    const ShiftEditOptionsResult(mode: ShiftEditOptionMode.series),
                  ),
                  badge: AppLocalizations.of(context)!.shiftUpdatesTemplate,
                );
              },
            ),
            if (widget.shift.studentIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildOption(
                title: AppLocalizations.of(context)!.editAllShiftsForAStudent,
                subtitle: AppLocalizations.of(context)!.bulkEditEveryClassForThe,
                icon: Icons.person_search,
                onTap: _pickStudentAll,
              ),
              const SizedBox(height: 10),
              _buildOption(
                title: AppLocalizations.of(context)!.editByTimeRangeStudent,
                subtitle: AppLocalizations.of(context)!.findShiftsForAStudentMatching,
                icon: Icons.schedule,
                onTap: _pickStudentTimeRange,
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLocalizations.of(context)!.commonCancel,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xff0386FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.tune, color: Color(0xff0386FF), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.editOptions,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xff111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.shift.displayName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xff6B7280),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 20),
        ),
      ],
    );
  }

  Widget _buildOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    Widget? trailing,
    String? badge,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xff0386FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xff0386FF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xff111827),
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffF59E0B)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xffD97706),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing
                else
                  const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickStudentAll() async {
    final studentId = await _pickStudentId();
    if (studentId == null) return;
    if (!mounted) return;
    Navigator.pop(
      context,
      ShiftEditOptionsResult(
        mode: ShiftEditOptionMode.studentAll,
        studentId: studentId,
      ),
    );
  }

  Future<void> _pickStudentTimeRange() async {
    final studentId = await _pickStudentId();
    if (studentId == null) return;
    if (!mounted) return;

    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: AppLocalizations.of(context)!.selectStartTime,
    );
    if (start == null) return;
    if (!mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: AppLocalizations.of(context)!.selectEndTime,
    );
    if (end == null) return;

    if (!mounted) return;
    Navigator.pop(
      context,
      ShiftEditOptionsResult(
        mode: ShiftEditOptionMode.studentTimeRange,
        studentId: studentId,
        startTime: start,
        endTime: end,
      ),
    );
  }

  Future<String?> _pickStudentId() async {
    if (widget.shift.studentIds.length == 1) return widget.shift.studentIds.first;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)!.selectStudent2,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < widget.shift.studentIds.length; i++)
              ListTile(
                title: Text(
                  widget.shift.studentNames.length > i
                      ? widget.shift.studentNames[i]
                      : widget.shift.studentIds[i],
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(context, widget.shift.studentIds[i]),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
        ],
      ),
    );

    return result;
  }
}
