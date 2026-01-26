import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/employee_model.dart';
import '../../../core/models/subject.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../../core/widgets/timezone_selector_field.dart';
import 'create_shift_dialog.dart';

class BulkEditShiftDialog extends StatefulWidget {
  final List<TeachingShift> shifts;
  final List<Employee> teachers;
  final List<Employee> students;
  final List<Subject> subjects;
  final VoidCallback onApplied;
  final bool updateSeriesTemplate;

  const BulkEditShiftDialog({
    super.key,
    required this.shifts,
    required this.teachers,
    required this.students,
    required this.subjects,
    required this.onApplied,
    this.updateSeriesTemplate = false,
  });

  @override
  State<BulkEditShiftDialog> createState() => _BulkEditShiftDialogState();
}

class _BulkEditShiftDialogState extends State<BulkEditShiftDialog> {
  final Set<String> _selectedShiftIds = {};

  bool _changeTime = false;
  String _selectedTimezone = 'UTC';
  TimeOfDay _newStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _newEndTime = const TimeOfDay(hour: 10, minute: 0);

  bool _changeTeacher = false;
  Employee? _selectedTeacher;

  bool _changeStudents = false;
  final Set<String> _selectedStudentIds = {};

  bool _changeSubject = false;
  Subject? _selectedSubject;

  bool _updateNotes = false;
  late final TextEditingController _notesController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedShiftIds.addAll(widget.shifts.map((s) => s.id));

    if (widget.shifts.isNotEmpty) {
      final first = widget.shifts.first;
      _selectedTimezone = first.adminTimezone;
      final localStart =
          TimezoneUtils.convertToTimezone(first.shiftStart, _selectedTimezone);
      final localEnd =
          TimezoneUtils.convertToTimezone(first.shiftEnd, _selectedTimezone);
      _newStartTime = TimeOfDay.fromDateTime(localStart);
      _newEndTime = TimeOfDay.fromDateTime(localEnd);
    }

    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedShiftIds.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 860,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(selectedCount),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShiftPicker(),
                    const SizedBox(height: 14),
                    _buildEditForm(),
                  ],
                ),
              ),
            ),
            _buildActions(selectedCount),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int selectedCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xff0386FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.edit, color: Color(0xff0386FF), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bulk Edit Shifts',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Editing $selectedCount of ${widget.shifts.length} shifts',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          if (widget.updateSeriesTemplate) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xffF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xffF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Color(0xffD97706),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Changes will update the recurring template. All future shifts in this series will use the new settings.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShiftPicker() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          'Selected shifts',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xff374151),
          ),
        ),
        subtitle: Text(
          '${_selectedShiftIds.length} selected',
          style:
              GoogleFonts.inter(fontSize: 12, color: const Color(0xff6B7280)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Checkbox(
                  value: _selectedShiftIds.length == widget.shifts.length,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedShiftIds
                            .addAll(widget.shifts.map((s) => s.id));
                      } else {
                        _selectedShiftIds.clear();
                      }
                    });
                  },
                ),
                Text(
                  'Select all',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff374151),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 220,
            child: ListView.builder(
              itemCount: widget.shifts.length,
              itemBuilder: (context, index) {
                final shift = widget.shifts[index];
                final isSelected = _selectedShiftIds.contains(shift.id);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedShiftIds.add(shift.id);
                      } else {
                        _selectedShiftIds.remove(shift.id);
                      }
                    });
                  },
                  title: Text(
                    shift.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff111827),
                    ),
                  ),
                  subtitle: Text(
                    _formatShiftSchedule(shift),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xff6B7280),
                    ),
                  ),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final selectedShifts =
        widget.shifts.where((s) => _selectedShiftIds.contains(s.id)).toList();
    final selectedTimezones =
        selectedShifts.map((s) => s.adminTimezone).toSet();
    final hasMixedSelectedTimezones = selectedTimezones.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Changes to apply',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
        ),
        const SizedBox(height: 10),
        _buildToggleSection(
          title: 'Time',
          subtitle:
              'Set a new start/end time for each selected shift (date stays the same).',
          value: _changeTime,
          onChanged: (v) => setState(() => _changeTime = v),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimezoneSelector(
                showMixedWarning: hasMixedSelectedTimezones,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Start',
                      value: _newStartTime,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _newStartTime,
                        );
                        if (picked != null) {
                          setState(() => _newStartTime = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'End',
                      value: _newEndTime,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _newEndTime,
                        );
                        if (picked != null) {
                          setState(() => _newEndTime = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildToggleSection(
          title: 'Teacher',
          subtitle: 'Change the assigned teacher for all selected shifts.',
          value: _changeTeacher,
          onChanged: (v) => setState(() => _changeTeacher = v),
          child: _PickerField(
            label: 'Teacher',
            value: _selectedTeacher == null
                ? 'Select teacher'
                : '${_selectedTeacher!.firstName} ${_selectedTeacher!.lastName}',
            onTap: _pickTeacher,
          ),
        ),
        const SizedBox(height: 10),
        _buildToggleSection(
          title: 'Students',
          subtitle: 'Replace the student list for all selected shifts.',
          value: _changeStudents,
          onChanged: (v) => setState(() => _changeStudents = v),
          child: _PickerField(
            label: 'Students',
            value: _selectedStudentIds.isEmpty
                ? 'Select students'
                : '${_selectedStudentIds.length} selected',
            onTap: _pickStudents,
          ),
        ),
        const SizedBox(height: 10),
        _buildToggleSection(
          title: 'Subject',
          subtitle: 'Change the subject for all selected shifts.',
          value: _changeSubject,
          onChanged: (v) => setState(() => _changeSubject = v),
          child: _PickerField(
            label: 'Subject',
            value: _selectedSubject?.displayName ?? 'Select subject',
            onTap: _pickSubject,
          ),
        ),
        const SizedBox(height: 10),
        _buildToggleSection(
          title: 'Notes',
          subtitle: 'Set notes for all selected shifts (blank clears).',
          value: _updateNotes,
          onChanged: (v) => setState(() => _updateNotes = v),
          child: TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Enter notes…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xffE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xffE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xff0386FF), width: 2),
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.inter(fontSize: 13),
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleSection({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Switch(
                value: value,
                onChanged: _isSaving ? null : onChanged,
              ),
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
            ],
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: value ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !value,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(int selectedCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () {
                    Navigator.pop(context);
                  },
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xff6B7280),
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _isSaving ? null : _previewChanges,
            child: Text(
              'Preview',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xff0386FF),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _isSaving || selectedCount == 0 ? null : _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0386FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Apply',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _previewChanges() async {
    final updates = _buildUpdateMap();
    final summary = updates.keys.toList()..sort();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Preview changes',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          summary.isEmpty
              ? 'No changes selected.'
              : 'This will update ${_selectedShiftIds.length} shift(s):\n\n${summary.join('\n')}',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildUpdateMap() {
    final updates = <String, dynamic>{};
    if (_changeTime) {
      updates['shift_start_time'] = _newStartTime;
      updates['shift_end_time'] = _newEndTime;
      updates['timezone'] = _selectedTimezone;
    }
    if (_changeTeacher && _selectedTeacher != null) {
      updates['teacher_id'] = _selectedTeacher!.documentId;
    }
    if (_changeStudents) {
      updates['student_ids'] = _selectedStudentIds.toList();
    }
    if (_changeSubject && _selectedSubject != null) {
      updates['subject_id'] = _selectedSubject!.id;
    }
    if (_updateNotes) {
      final text = _notesController.text.trim();
      updates['notes'] = text.isEmpty ? null : text;
    }
    return updates;
  }

  Widget _buildTimezoneSelector({required bool showMixedWarning}) {
    final safeValue = TimezoneUtils.normalizeTimezone(_selectedTimezone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Timezone',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xff6B7280),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message:
                  'Times will be applied in this timezone for all selected shifts.',
              child: const Icon(
                Icons.info_outline,
                size: 14,
                color: Color(0xff9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TimezoneSelectorField(
          selectedTimezone: safeValue,
          borderRadius: BorderRadius.circular(10),
          borderColor: const Color(0xffE2E8F0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xff111827),
          ),
          onTimezoneSelected: (value) =>
              setState(() => _selectedTimezone = value),
        ),
        if (showMixedWarning)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xffF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xffF59E0B).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xffF59E0B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected shifts use multiple timezones. Applying time changes will set all selected shifts to $safeValue.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xff92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _apply() async {
    final updates = _buildUpdateMap();
    if (updates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one change to apply.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm template update if applicable
    if (widget.updateSeriesTemplate) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xffD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Update Recurring Template?',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will update the recurring template. Changes will affect:',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildConfirmationItem(
                icon: Icons.check_circle,
                text: '${_selectedShiftIds.length} selected shift(s)',
                color: const Color(0xff10B981),
              ),
              const SizedBox(height: 8),
              _buildConfirmationItem(
                icon: Icons.repeat,
                text: 'All future shifts in this series',
                color: const Color(0xff0386FF),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xff92400E),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The daily scheduler will generate new shifts using the updated template settings.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xff92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0386FF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Yes, Update Template',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);
    try {
      final conflicts = await ShiftService.checkBulkUpdateConflicts(
        _selectedShiftIds.toList(),
        updates,
      );

      if (!mounted) return;

      if (conflicts.isNotEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Conflicts detected',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'This change would create ${conflicts.length} conflict(s). Continue anyway?',
              style: GoogleFonts.inter(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Apply anyway'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        if (proceed != true) return;
      }

      await ShiftService.bulkUpdateShifts(
        _selectedShiftIds.toList(),
        updates,
        checkConflicts: false,
        updateSeriesTemplate: widget.updateSeriesTemplate,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onApplied();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.updateSeriesTemplate
                  ? 'Shifts and template updated successfully'
                  : 'Bulk update applied successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Bulk update failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildConfirmationItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xff374151),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTeacher() async {
    final selected = await showDialog<List<Employee>>(
      context: context,
      builder: (context) => EmployeeSelectionDialog(
        employees: widget.teachers,
        selectedIds: _selectedTeacher == null
            ? <String>{}
            : <String>{_selectedTeacher!.documentId},
        title: 'Select Teacher',
        idSelector: (t) => t.documentId,
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() => _selectedTeacher = selected.first);
  }

  Future<void> _pickSubject() async {
    final selected = await showDialog<Subject>(
      context: context,
      builder: (context) => _SearchSelectDialog<Subject>(
        title: 'Select Subject',
        items: widget.subjects,
        selected: _selectedSubject,
        itemLabel: (s) => s.displayName,
      ),
    );
    if (selected == null) return;
    setState(() => _selectedSubject = selected);
  }

  Future<void> _pickStudents() async {
    final selectedStudents = await showDialog<List<Employee>>(
      context: context,
      builder: (context) => EmployeeSelectionDialog(
        employees: widget.students,
        selectedIds: Set<String>.from(_selectedStudentIds),
        multiSelect: true,
        title: 'Select Students',
        idSelector: (s) => s.documentId,
      ),
    );
    if (selectedStudents == null) return;
    setState(() {
      _selectedStudentIds
        ..clear()
        ..addAll(selectedStudents.map((s) => s.documentId));
    });
  }

  String _formatShiftSchedule(TeachingShift shift) {
    String two(int n) => n.toString().padLeft(2, '0');
    final s = shift.shiftStart;
    final e = shift.shiftEnd;
    return '${s.year}-${two(s.month)}-${two(s.day)} ${two(s.hour)}:${two(s.minute)} - ${two(e.hour)}:${two(e.minute)}';
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffE2E8F0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.search, color: Color(0xff9CA3AF), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PickerField(
      label: label,
      value: value.format(context),
      onTap: onTap,
    );
  }
}

class _SearchSelectDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? selected;
  final String Function(T item) itemLabel;

  const _SearchSelectDialog({
    required this.title,
    required this.items,
    required this.selected,
    required this.itemLabel,
  });

  @override
  State<_SearchSelectDialog<T>> createState() => _SearchSelectDialogState<T>();
}

class _SearchSelectDialogState<T> extends State<_SearchSelectDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  late List<T> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.items;
      } else {
        _filtered = widget.items
            .where((item) => widget.itemLabel(item).toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff111827),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xff0386FF), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final item = _filtered[index];
                  final label = widget.itemLabel(item);
                  final isSelected =
                      widget.selected != null && item == widget.selected;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xff0386FF).withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xff0386FF)
                            : const Color(0xffE2E8F0),
                      ),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, item),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: Color(0xff0386FF), size: 18)
                            else
                              const Icon(Icons.circle_outlined,
                                  color: Color(0xff9CA3AF), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff111827),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
