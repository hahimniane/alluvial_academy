import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';

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
              title: 'Edit this shift only',
              subtitle: 'Quick edit or full editor for this shift.',
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
                    title: 'Edit all in series',
                    subtitle: 'Loading series…',
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
                  title: 'Edit all in series (${series.shifts.length})',
                  subtitle: 'Apply changes to all shifts in this recurring series.',
                  icon: Icons.repeat,
                  onTap: () => Navigator.pop(
                    context,
                    const ShiftEditOptionsResult(mode: ShiftEditOptionMode.series),
                  ),
                );
              },
            ),
            if (widget.shift.studentIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildOption(
                title: 'Edit all shifts for a student',
                subtitle: 'Bulk edit every class for the selected student.',
                icon: Icons.person_search,
                onTap: _pickStudentAll,
              ),
              const SizedBox(height: 10),
              _buildOption(
                title: 'Edit by time range (student)',
                subtitle: 'Find shifts for a student matching a time window.',
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
                  'Cancel',
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
                'Edit options',
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
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff111827),
                        ),
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
                if (trailing != null) trailing else const Icon(Icons.chevron_right),
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
      helpText: 'Select start time',
    );
    if (start == null) return;
    if (!mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Select end time',
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
          'Select student',
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
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    return result;
  }
}
