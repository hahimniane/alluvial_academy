import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alluwalacademyadmin/core/models/employee_model.dart';
import 'package:alluwalacademyadmin/core/utils/app_search.dart';
import 'package:alluwalacademyadmin/features/shift_management/models/teaching_shift.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

enum BulkRecordingTargetScope {
  allTeaching,
  teacher,
  student,
  selected,
}

enum BulkRecordingTimeScope {
  activeUpcoming,
  upcoming,
  active,
  past,
  all,
}

class BulkRecordingPermissionResult {
  BulkRecordingPermissionResult({
    required this.enabled,
    required this.shifts,
  });

  final bool enabled;
  final List<TeachingShift> shifts;
}

class BulkRecordingPermissionDialog extends StatefulWidget {
  const BulkRecordingPermissionDialog({
    super.key,
    required this.allShifts,
    required this.selectedShiftIds,
    required this.teachers,
    required this.students,
  });

  final List<TeachingShift> allShifts;
  final Set<String> selectedShiftIds;
  final List<Employee> teachers;
  final List<Employee> students;

  @override
  State<BulkRecordingPermissionDialog> createState() =>
      _BulkRecordingPermissionDialogState();
}

class _BulkRecordingPermissionDialogState
    extends State<BulkRecordingPermissionDialog> {
  BulkRecordingTargetScope _targetScope = BulkRecordingTargetScope.allTeaching;
  BulkRecordingTimeScope _timeScope = BulkRecordingTimeScope.activeUpcoming;
  bool _enabled = true;
  String? _teacherId;
  String? _studentId;
  String _teacherSearch = '';
  String _studentSearch = '';

  List<TeachingShift> get _matchingShifts {
    final now = DateTime.now();
    return widget.allShifts.where((shift) {
      if (!shift.hasVideoCall) return false;

      switch (_targetScope) {
        case BulkRecordingTargetScope.allTeaching:
          break;
        case BulkRecordingTargetScope.teacher:
          if (_teacherId == null || shift.teacherId != _teacherId) return false;
          break;
        case BulkRecordingTargetScope.student:
          if (_studentId == null || !shift.studentIds.contains(_studentId)) {
            return false;
          }
          break;
        case BulkRecordingTargetScope.selected:
          if (!widget.selectedShiftIds.contains(shift.id)) return false;
          break;
      }

      switch (_timeScope) {
        case BulkRecordingTimeScope.activeUpcoming:
          return shift.shiftEnd.isAfter(now);
        case BulkRecordingTimeScope.upcoming:
          return shift.shiftStart.isAfter(now);
        case BulkRecordingTimeScope.active:
          return shift.shiftStart.isBefore(now) && shift.shiftEnd.isAfter(now);
        case BulkRecordingTimeScope.past:
          return shift.shiftEnd.isBefore(now);
        case BulkRecordingTimeScope.all:
          return true;
      }
    }).toList()
      ..sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
  }

  bool get _scopeReady {
    if (_targetScope == BulkRecordingTargetScope.teacher) {
      return _teacherId != null;
    }
    if (_targetScope == BulkRecordingTargetScope.student) {
      return _studentId != null;
    }
    if (_targetScope == BulkRecordingTargetScope.selected) {
      return widget.selectedShiftIds.isNotEmpty;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shifts = _matchingShifts;
    final alreadyEnabled =
        shifts.where((shift) => shift.realtimeKitRecordingEnabled).length;
    final alreadyDisabled = shifts.length - alreadyEnabled;
    final willChange = _enabled ? alreadyDisabled : alreadyEnabled;
    final canApply = _scopeReady && shifts.isNotEmpty && willChange > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(l10n),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 720;
                      final config = _buildConfiguration(l10n);
                      final preview = _buildPreview(
                        l10n,
                        shifts,
                        alreadyEnabled,
                        alreadyDisabled,
                        willChange,
                      );
                      if (!isWide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            config,
                            const SizedBox(height: 16),
                            preview,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: config),
                          const SizedBox(width: 18),
                          Expanded(child: preview),
                        ],
                      );
                    },
                  ),
                ),
              ),
              _buildFooter(l10n, shifts, canApply),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 18, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0E72ED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.video_library_outlined,
              color: Color(0xFF0E72ED),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.bulkClassRecordingTitle,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.bulkClassRecordingSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            tooltip: l10n.commonClose,
          ),
        ],
      ),
    );
  }

  Widget _buildConfiguration(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          title: l10n.bulkClassRecordingAccess,
          icon: Icons.tune,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _segmented<bool>(
                value: _enabled,
                options: [
                  _SegmentOption(
                    value: true,
                    label: l10n.bulkClassRecordingEnable,
                    icon: Icons.fiber_manual_record,
                  ),
                  _SegmentOption(
                    value: false,
                    label: l10n.bulkClassRecordingDisable,
                    icon: Icons.block,
                  ),
                ],
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.bulkClassRecordingScope,
                style: _labelStyle,
              ),
              const SizedBox(height: 8),
              _scopeGrid(l10n),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_targetScope == BulkRecordingTargetScope.teacher) ...[
          _personPicker(
            title: l10n.bulkClassRecordingChooseTeacher,
            searchHint: l10n.bulkClassRecordingSearchTeacher,
            people: widget.teachers,
            selectedId: _teacherId,
            search: _teacherSearch,
            onSearchChanged: (value) => setState(() => _teacherSearch = value),
            onSelected: (person) =>
                setState(() => _teacherId = person.documentId),
          ),
          const SizedBox(height: 14),
        ],
        if (_targetScope == BulkRecordingTargetScope.student) ...[
          _personPicker(
            title: l10n.bulkClassRecordingChooseStudent,
            searchHint: l10n.bulkClassRecordingSearchStudent,
            people: widget.students,
            selectedId: _studentId,
            search: _studentSearch,
            onSearchChanged: (value) => setState(() => _studentSearch = value),
            onSelected: (person) =>
                setState(() => _studentId = person.documentId),
          ),
          const SizedBox(height: 14),
        ],
        _panel(
          title: l10n.bulkClassRecordingTimeWindow,
          icon: Icons.schedule_outlined,
          child: _timeScopeList(l10n),
        ),
      ],
    );
  }

  Widget _scopeGrid(AppLocalizations l10n) {
    final options = [
      _SegmentOption(
        value: BulkRecordingTargetScope.allTeaching,
        label: l10n.bulkClassRecordingScopeAllTeachers,
        icon: Icons.groups_outlined,
      ),
      _SegmentOption(
        value: BulkRecordingTargetScope.teacher,
        label: l10n.bulkClassRecordingScopeTeacher,
        icon: Icons.person_outline,
      ),
      _SegmentOption(
        value: BulkRecordingTargetScope.student,
        label: l10n.bulkClassRecordingScopeStudent,
        icon: Icons.school_outlined,
      ),
      _SegmentOption(
        value: BulkRecordingTargetScope.selected,
        label: l10n.bulkClassRecordingScopeSelected,
        icon: Icons.checklist,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final selected = option.value == _targetScope;
        return InkWell(
          onTap: () => setState(() => _targetScope = option.value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 150,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0E72ED)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  option.icon,
                  size: 18,
                  color: selected
                      ? const Color(0xFF0E72ED)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected
                          ? const Color(0xFF0E3A8A)
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _timeScopeList(AppLocalizations l10n) {
    final options = [
      _SegmentOption(
        value: BulkRecordingTimeScope.activeUpcoming,
        label: l10n.bulkClassRecordingTimeActiveUpcoming,
        icon: Icons.event_available_outlined,
      ),
      _SegmentOption(
        value: BulkRecordingTimeScope.upcoming,
        label: l10n.bulkClassRecordingTimeUpcoming,
        icon: Icons.upcoming_outlined,
      ),
      _SegmentOption(
        value: BulkRecordingTimeScope.active,
        label: l10n.bulkClassRecordingTimeActive,
        icon: Icons.play_circle_outline,
      ),
      _SegmentOption(
        value: BulkRecordingTimeScope.past,
        label: l10n.bulkClassRecordingTimePast,
        icon: Icons.history,
      ),
      _SegmentOption(
        value: BulkRecordingTimeScope.all,
        label: l10n.bulkClassRecordingTimeAll,
        icon: Icons.all_inclusive,
      ),
    ];

    return Column(
      children: options.map((option) {
        final selected = option.value == _timeScope;
        return InkWell(
          onTap: () => setState(() => _timeScope = option.value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF0FDF4) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFF10B981)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  option.icon,
                  size: 18,
                  color: selected
                      ? const Color(0xFF047857)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle,
                      color: Color(0xFF10B981), size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreview(
    AppLocalizations l10n,
    List<TeachingShift> shifts,
    int alreadyEnabled,
    int alreadyDisabled,
    int willChange,
  ) {
    final sample = shifts.take(5).toList();
    return _panel(
      title: l10n.bulkClassRecordingPreview,
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _metric(
                  l10n.bulkClassRecordingMatched,
                  shifts.length.toString(),
                  const Color(0xFF0E72ED),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  l10n.bulkClassRecordingWillChange,
                  willChange.toString(),
                  _enabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metric(
                  l10n.bulkClassRecordingAlreadyEnabled,
                  alreadyEnabled.toString(),
                  const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  l10n.bulkClassRecordingAlreadyDisabled,
                  alreadyDisabled.toString(),
                  const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  _enabled ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _enabled
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _enabled ? Icons.check_circle_outline : Icons.block,
                  color: _enabled
                      ? const Color(0xFF047857)
                      : const Color(0xFFDC2626),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _enabled
                        ? l10n.bulkClassRecordingEnableSummary(willChange)
                        : l10n.bulkClassRecordingDisableSummary(willChange),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _enabled
                          ? const Color(0xFF047857)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(l10n.bulkClassRecordingSampleClasses, style: _labelStyle),
          const SizedBox(height: 8),
          if (sample.isEmpty)
            _emptyPreview(l10n)
          else
            ...sample.map((shift) => _shiftPreviewRow(shift)),
          if (shifts.length > sample.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.bulkClassRecordingMoreClasses(
                    shifts.length - sample.length),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    AppLocalizations l10n,
    List<TeachingShift> shifts,
    bool canApply,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.bulkClassRecordingFooterNote,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(96, 44),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.commonCancel),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: canApply
                ? () => Navigator.pop(
                      context,
                      BulkRecordingPermissionResult(
                        enabled: _enabled,
                        shifts: shifts,
                      ),
                    )
                : null,
            icon: Icon(_enabled ? Icons.check_circle_outline : Icons.block,
                size: 18),
            label: Text(
              _enabled
                  ? l10n.bulkClassRecordingApplyEnable
                  : l10n.bulkClassRecordingApplyDisable,
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(132, 44),
              backgroundColor:
                  _enabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              disabledForegroundColor: const Color(0xFF94A3B8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personPicker({
    required String title,
    required String searchHint,
    required List<Employee> people,
    required String? selectedId,
    required String search,
    required ValueChanged<String> onSearchChanged,
    required ValueChanged<Employee> onSelected,
  }) {
    final filtered = people
        .where((person) => AppSearch.matches(
              query: search,
              names: [
                '${person.firstName} ${person.lastName}',
                '${person.lastName} ${person.firstName}',
              ],
              emails: [person.email],
              phones: [
                person.mobilePhone,
                '${person.countryCode}${person.mobilePhone}',
              ],
              ids: [
                person.documentId,
                person.studentCode,
                person.kioskCode,
              ],
            ))
        .take(8)
        .toList();

    return _panel(
      title: title,
      icon: Icons.manage_search,
      child: Column(
        children: [
          TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0E72ED)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...filtered.map((person) {
            final isSelected = selectedId == person.documentId;
            final initials = _initials(person);
            return InkWell(
              onTap: () => onSelected(person),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0E72ED)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isSelected
                          ? const Color(0xFF0E72ED)
                          : const Color(0xFFE2E8F0),
                      child: Text(
                        initials,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${person.firstName} ${person.lastName}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            person.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: Color(0xFF0E72ED), size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _segmented<T>({
    required T value,
    required List<_SegmentOption<T>> options,
    required ValueChanged<T> onChanged,
  }) {
    return Row(
      children: options.map((option) {
        final selected = option.value == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: option == options.last ? 0 : 8,
            ),
            child: InkWell(
              onTap: () => onChanged(option.value),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      option.icon,
                      size: 17,
                      color: selected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              selected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF475569), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftPreviewRow(TeachingShift shift) {
    final enabled = shift.realtimeKitRecordingEnabled;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 36,
            decoration: BoxDecoration(
              color:
                  enabled ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, h:mm a')
                      .format(shift.shiftStart.toLocal()),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            enabled ? Icons.fiber_manual_record : Icons.radio_button_unchecked,
            color: enabled ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _emptyPreview(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.bulkClassRecordingNoMatches,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(Employee person) {
    final first = person.firstName.trim();
    final last = person.lastName.trim();
    final a = first.isNotEmpty ? first[0] : '';
    final b = last.isNotEmpty ? last[0] : '';
    final initials = '$a$b'.toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  TextStyle get _labelStyle => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF475569),
      );
}

class _SegmentOption<T> {
  _SegmentOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}
