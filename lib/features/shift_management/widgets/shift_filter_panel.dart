import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/enums/shift_enums.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/models/subject.dart';
import 'create_shift_dialog.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

class ShiftFilterPanel extends StatefulWidget {
  final List<Employee> teachers;
  final List<Employee> students;
  final List<Subject> subjects;

  final String? selectedTeacherId;
  final String? selectedStudentId;
  final String? selectedSubjectId;
  final DateTimeRange? dateRange;
  final TimeOfDay? timeRangeStart;
  final TimeOfDay? timeRangeEnd;
  final ShiftStatus? statusFilter;

  final VoidCallback onClear;
  final void Function({
    String? teacherId,
    String? studentId,
    String? subjectId,
    DateTimeRange? dateRange,
    TimeOfDay? timeStart,
    TimeOfDay? timeEnd,
    ShiftStatus? status,
  }) onApply;

  const ShiftFilterPanel({
    super.key,
    required this.teachers,
    required this.students,
    required this.subjects,
    required this.selectedTeacherId,
    required this.selectedStudentId,
    required this.selectedSubjectId,
    required this.dateRange,
    required this.timeRangeStart,
    required this.timeRangeEnd,
    required this.statusFilter,
    required this.onClear,
    required this.onApply,
  });

  @override
  State<ShiftFilterPanel> createState() => _ShiftFilterPanelState();
}

class _ShiftFilterPanelState extends State<ShiftFilterPanel> {
  String? _teacherId;
  String? _studentId;
  String? _subjectId;
  DateTimeRange? _dateRange;
  TimeOfDay? _timeStart;
  TimeOfDay? _timeEnd;
  ShiftStatus? _status;

  @override
  void initState() {
    super.initState();
    _teacherId = widget.selectedTeacherId;
    _studentId = widget.selectedStudentId;
    _subjectId = widget.selectedSubjectId;
    _dateRange = widget.dateRange;
    _timeStart = widget.timeRangeStart;
    _timeEnd = widget.timeRangeEnd;
    _status = widget.statusFilter;
  }

  @override
  void didUpdateWidget(covariant ShiftFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTeacherId != widget.selectedTeacherId) {
      _teacherId = widget.selectedTeacherId;
    }
    if (oldWidget.selectedStudentId != widget.selectedStudentId) {
      _studentId = widget.selectedStudentId;
    }
    if (oldWidget.selectedSubjectId != widget.selectedSubjectId) {
      _subjectId = widget.selectedSubjectId;
    }
    if (oldWidget.dateRange != widget.dateRange) _dateRange = widget.dateRange;
    if (oldWidget.timeRangeStart != widget.timeRangeStart) {
      _timeStart = widget.timeRangeStart;
    }
    if (oldWidget.timeRangeEnd != widget.timeRangeEnd) {
      _timeEnd = widget.timeRangeEnd;
    }
    if (oldWidget.statusFilter != widget.statusFilter) {
      _status = widget.statusFilter;
    }
  }

  Employee? _getSelectedTeacher() {
    if (_teacherId == null) return null;
    for (final t in widget.teachers) {
      if (t.documentId == _teacherId) return t;
    }
    return null;
  }

  Employee? _getSelectedStudent() {
    if (_studentId == null) return null;
    for (final s in widget.students) {
      if (s.documentId == _studentId) return s;
    }
    return null;
  }

  Subject? _getSelectedSubject() {
    if (_subjectId == null) return null;
    for (final s in widget.subjects) {
      if (s.id == _subjectId) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedTeacher = _getSelectedTeacher();
    final selectedStudent = _getSelectedStudent();
    final selectedSubject = _getSelectedSubject();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
        color: Color(0xffF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.filters,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (widget.teachers.isNotEmpty || _teacherId != null)
                _FilterField(
                  label: AppLocalizations.of(context)!.roleTeacher,
                  value: selectedTeacher != null
                      ? '${selectedTeacher.firstName} ${selectedTeacher.lastName}'
                      : 'All',
                  icon: Icons.person_outline,
                  onTap: widget.teachers.isEmpty ? null : _pickTeacher,
                ),
              _FilterField(
                label: AppLocalizations.of(context)!.roleStudent,
                value: selectedStudent != null
                    ? '${selectedStudent.firstName} ${selectedStudent.lastName}'
                    : 'All',
                icon: Icons.person,
                onTap: widget.students.isEmpty ? null : _pickStudent,
              ),
              _FilterField(
                label: AppLocalizations.of(context)!.subject,
                value: selectedSubject != null
                    ? selectedSubject.displayName
                    : 'All',
                icon: Icons.school,
                onTap: widget.subjects.isEmpty ? null : _pickSubject,
              ),
              _FilterField(
                label: AppLocalizations.of(context)!.dateRange,
                value: _dateRange == null
                    ? 'Any'
                    : '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
                icon: Icons.date_range,
                onTap: _pickDateRange,
              ),
              _FilterField(
                label: AppLocalizations.of(context)!.shiftStartTime,
                value: _timeStart == null ? 'Any' : _timeStart!.format(context),
                icon: Icons.schedule,
                onTap: _pickStartTime,
              ),
              _FilterField(
                label: AppLocalizations.of(context)!.shiftEndTime,
                value: _timeEnd == null ? 'Any' : _timeEnd!.format(context),
                icon: Icons.schedule,
                onTap: _pickEndTime,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.userStatus,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xff374151),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(null, 'All'),
              _buildStatusChip(ShiftStatus.scheduled, 'Scheduled'),
              _buildStatusChip(ShiftStatus.active, 'Active'),
              _buildStatusChip(ShiftStatus.partiallyCompleted, 'Partial'),
              _buildStatusChip(ShiftStatus.fullyCompleted, 'Full'),
              _buildStatusChip(ShiftStatus.missed, 'Missed'),
              _buildStatusChip(ShiftStatus.cancelled, 'Cancelled'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _teacherId = null;
                    _studentId = null;
                    _subjectId = null;
                    _dateRange = null;
                    _timeStart = null;
                    _timeEnd = null;
                    _status = null;
                  });
                  widget.onClear();
                },
                child: Text(
                  AppLocalizations.of(context)!.clearAll2,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff6B7280),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  widget.onApply(
                    teacherId: _teacherId,
                    studentId: _studentId,
                    subjectId: _subjectId,
                    dateRange: _dateRange,
                    timeStart: _timeStart,
                    timeEnd: _timeEnd,
                    status: _status,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0386FF),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.commonApply,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ShiftStatus? status, String label) {
    final selected = _status == status;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xff374151),
        ),
      ),
      selected: selected,
      selectedColor: const Color(0xff0386FF),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xffE2E8F0)),
      onSelected: (_) {
        setState(() {
          _status = status;
        });
      },
    );
  }

  Future<void> _pickTeacher() async {
    final selected = await showDialog<List<Employee>>(
      context: context,
      builder: (context) => EmployeeSelectionDialog(
        employees: widget.teachers,
        selectedIds: _teacherId == null ? <String>{} : <String>{_teacherId!},
        title: AppLocalizations.of(context)!.selectTeacher,
        idSelector: (t) => t.documentId,
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      _teacherId = selected.first.documentId;
    });
  }

  Future<void> _pickStudent() async {
    final selected = await showDialog<List<Employee>>(
      context: context,
      builder: (context) => EmployeeSelectionDialog(
        employees: widget.students,
        selectedIds: _studentId == null ? <String>{} : <String>{_studentId!},
        title: AppLocalizations.of(context)!.selectStudent,
        idSelector: (s) => s.documentId,
      ),
    );
    if (selected == null || selected.isEmpty) return;
    setState(() {
      _studentId = selected.first.documentId;
    });
  }

  Future<void> _pickSubject() async {
    final selected = await showDialog<Subject>(
      context: context,
      builder: (context) => _SearchSelectDialog<Subject>(
        title: AppLocalizations.of(context)!.selectSubject,
        items: widget.subjects,
        selected: _getSelectedSubject(),
        itemLabel: (s) => s.displayName,
      ),
    );
    if (selected == null) return;
    setState(() {
      _subjectId = selected.id;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
    );
    if (range == null) return;
    setState(() {
      _dateRange = range;
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeStart ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      _timeStart = picked;
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeEnd ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      _timeEnd = picked;
    });
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }
}

class _FilterField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _FilterField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xff6B7280)),
                const SizedBox(width: 8),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xff9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
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
        width: 460,
        height: 560,
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
                hintText: AppLocalizations.of(context)!.search,
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
            Text(
              '${_filtered.length} found',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xff6B7280),
              ),
            ),
            const SizedBox(height: 8),
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
