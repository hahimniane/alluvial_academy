import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/shift_service.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/enums/shift_enums.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/weekday_localization.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Dialog for managing shift templates (schedules)
/// Allows: view, deactivate/reactivate, reassign teacher, modify days
class TemplateManagementDialog extends StatefulWidget {
  final String? initialTeacherId;
  final VoidCallback? onTemplateUpdated;

  const TemplateManagementDialog({
    super.key,
    this.initialTeacherId,
    this.onTemplateUpdated,
  });

  @override
  State<TemplateManagementDialog> createState() =>
      _TemplateManagementDialogState();
}

class _TemplateManagementDialogState extends State<TemplateManagementDialog> {
  List<Map<String, dynamic>> _templates = [];
  List<TeachingShift> _scheduleShifts = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  bool _showInactive = false;
  String? _filterTeacherId;
  String _searchQuery = '';
  bool _viewTemplates = true;
  StreamSubscription<List<TeachingShift>>? _scheduleSubscription;

  @override
  void initState() {
    super.initState();
    _filterTeacherId = widget.initialTeacherId;
    _loadTeachers();
    _loadTemplates();
  }

  @override
  void dispose() {
    _scheduleSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    try {
      final teachers = await ShiftService.getAvailableTeachers();
      if (mounted) {
        setState(() {
          _teachers = teachers
              .map((t) => {
                    'id': t.documentId,
                    'name': '${t.firstName} ${t.lastName}'.trim(),
                  })
              .where((t) => (t['name'] as String).isNotEmpty)
              .toList()
            ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        });
      }
    } catch (e) {
      AppLogger.error('TemplateManagement: Failed to load teachers: $e');
    }
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final templates = await ShiftService.getShiftTemplates(
        teacherId: _filterTeacherId,
        activeOnly: !_showInactive,
      );
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('TemplateManagement: Failed to load templates: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToSchedule() {
    _scheduleSubscription?.cancel();
    if (_filterTeacherId == null || _filterTeacherId!.isEmpty) {
      setState(() => _scheduleShifts = []);
      return;
    }
    _scheduleSubscription = ShiftService.getTeacherShifts(_filterTeacherId!)
        .listen((shifts) {
      if (mounted) {
        setState(() => _scheduleShifts = shifts);
      }
    }, onError: (e) {
      AppLogger.error('TemplateManagement: Schedule stream error: $e');
      if (mounted) setState(() => _scheduleShifts = []);
    });
  }

  /// Group templates by student - OPTIMIZED VERSION
  /// Returns: Map with key = "teacherName|studentName" and value = GroupedTemplate
  Map<String, GroupedTemplate> get _groupedTemplates {
    final q = _searchQuery.trim().toLowerCase();
    final grouped = <String, GroupedTemplate>{};

    for (final template in _templates) {
      final teacherName = template['teacher_name'] as String? ?? '';
      final studentNames = (template['student_names'] as List<dynamic>?) ?? [];
      
      // Filter by search query
      if (q.isNotEmpty) {
        final teacherMatch = teacherName.toLowerCase().contains(q);
        final studentMatch = studentNames.any(
          (name) => (name?.toString() ?? '').toLowerCase().contains(q)
        );
        if (!teacherMatch && !studentMatch) continue;
      }

      // Group by teacher + student combination
      for (final studentName in studentNames) {
        final key = '$teacherName|${studentName ?? ""}';
        
        if (!grouped.containsKey(key)) {
          grouped[key] = GroupedTemplate(
            teacherName: teacherName,
            teacherId: template['teacher_id'] as String?,
            studentName: studentName?.toString() ?? '',
            studentIds: template['student_ids'] as List<dynamic>? ?? [],
            isActive: template['is_active'] as bool? ?? true,
            templateIds: [],
            weekdays: {},
            startTime: template['start_time'] as String?,
            endTime: template['end_time'] as String?,
          );
        }

        final group = grouped[key]!;
        group.templateIds.add(template['id'] as String);

        // Add weekdays from enhanced_recurrence.selectedWeekdays
        final recurrence = template['enhanced_recurrence'] as Map<String, dynamic>?;
        final selectedWeekdays = _parseSelectedWeekdays(recurrence);
        for (final day in selectedWeekdays) {
          group.weekdays[day] = template['id'] as String;
        }
      }
    }

    return grouped;
  }

  /// Parse selectedWeekdays from template recurrence (handles int, num, list).
  static List<int> _parseSelectedWeekdays(Map<String, dynamic>? recurrence) {
    if (recurrence == null) return [];
    final raw = recurrence['selectedWeekdays'];
    if (raw is! List) return [];
    final out = <int>[];
    for (final e in raw) {
      if (e is int && e >= 1 && e <= 7) {
        out.add(e);
      } else if (e is num) {
        final i = e.toInt();
        if (i >= 1 && i <= 7) out.add(i);
      }
    }
    return out;
  }

  List<GroupedTemplate> get _filteredGroupedTemplates {
    final grouped = _groupedTemplates.values.toList();
    grouped.sort((a, b) {
      final teacherCompare = a.teacherName.compareTo(b.teacherName);
      if (teacherCompare != 0) return teacherCompare;
      return a.studentName.compareTo(b.studentName);
    });
    return grouped;
  }

  Map<String, List<TeachingShift>> get _shiftsByStudent {
    final q = _searchQuery.trim().toLowerCase();
    final map = <String, List<TeachingShift>>{};
    for (final shift in _scheduleShifts) {
      for (var i = 0; i < shift.studentIds.length; i++) {
        final sid = shift.studentIds[i];
        final sname = i < shift.studentNames.length
            ? shift.studentNames[i]
            : sid;
        final key = '$sid|$sname';
        if (q.isEmpty ||
            sname.toLowerCase().contains(q) ||
            shift.teacherName.toLowerCase().contains(q)) {
          map.putIfAbsent(key, () => []).add(shift);
        }
      }
      if (shift.studentIds.isEmpty && shift.studentNames.isNotEmpty) {
        final sname = shift.studentNames.join(', ');
        final key = '|$sname';
        if (q.isEmpty || sname.toLowerCase().contains(q)) {
          map.putIfAbsent(key, () => []).add(shift);
        }
      }
    }
    for (final list in map.values) {
      list.sort((a, b) => a.shiftStart.compareTo(b.shiftStart));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 640,
        height: 560,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.event_repeat, color: Color(0xFF0386FF), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.shiftTemplateManagement,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.showInactive,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
                    Switch(
                      value: _showInactive,
                      onChanged: (v) {
                        setState(() => _showInactive = v);
                        _loadTemplates();
                      },
                      activeColor: const Color(0xFF0386FF),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filters
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _filterTeacherId,
                        hint: Text(l10n.shiftTemplateFilterTeacher,
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF))),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l10n.shiftTemplateAllTeachers,
                                style: GoogleFonts.inter(fontSize: 13)),
                          ),
                          ..._teachers.map((t) => DropdownMenuItem(
                                value: t['id'] as String?,
                                child: Text(t['name'] as String,
                                    style: GoogleFonts.inter(fontSize: 13)),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() => _filterTeacherId = v);
                          if (_viewTemplates) {
                            _loadTemplates();
                          } else {
                            _subscribeToSchedule();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: l10n.shiftTemplateSearchPlaceholder,
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Toggle buttons
            Row(
              children: [
                _toggleButton(
                  l10n.shiftTemplateViewTemplates,
                  _viewTemplates,
                  () {
                    setState(() => _viewTemplates = true);
                    _loadTemplates();
                  },
                ),
                const SizedBox(width: 8),
                _toggleButton(
                  l10n.shiftTemplateViewSchedule,
                  !_viewTemplates,
                  () {
                    setState(() => _viewTemplates = false);
                    _subscribeToSchedule();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _viewTemplates
                      ? _buildGroupedTemplatesList(context, l10n)
                      : _buildScheduleList(context, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedTemplatesList(BuildContext context, AppLocalizations l10n) {
    final grouped = _filteredGroupedTemplates;
    
    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              l10n.shiftNoTemplatesFound,
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        return _buildGroupedTemplateCard(context, l10n, grouped[index]);
      },
    );
  }

  Widget _buildGroupedTemplateCard(
    BuildContext context,
    AppLocalizations l10n,
    GroupedTemplate group,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: group.isActive ? const Color(0xFFE5E7EB) : const Color(0xFFEF4444).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Active indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: group.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              
              // Teacher name
              Expanded(
                child: Text(
                  group.teacherName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),

              // Actions menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF9CA3AF)),
                onSelected: (value) => _handleTemplateAction(context, l10n, value, group),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'modify',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 18, color: Color(0xFF0386FF)),
                        const SizedBox(width: 8),
                        Text(l10n.shiftTemplateModifyDays),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reassign',
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Text(l10n.shiftReassignTeacher),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: group.isActive ? 'deactivate' : 'reactivate',
                    child: Row(
                      children: [
                        Icon(
                          group.isActive ? Icons.cancel : Icons.check_circle,
                          size: 18,
                          color: group.isActive ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Text(group.isActive ? l10n.shiftTemplateDeactivate : l10n.shiftTemplateReactivate),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Student name
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.studentName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Time and weekdays on same row
          Row(
            children: [
              // Time
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Text(
                    '${group.startTime ?? "00:00"} - ${group.endTime ?? "00:00"}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Weekday chips (localized)
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _buildWeekdayChips(context, l10n, group.weekdays.keys.toList()..sort()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeekdayChips(BuildContext context, AppLocalizations l10n, List<int> weekdays) {
    return weekdays.map((dayValue) {
      String label;
      try {
        final day = WeekDay.values.firstWhere((d) => d.value == dayValue);
        label = day.localizedShortName(l10n);
      } catch (_) {
        label = '$dayValue';
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0386FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF0386FF).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0386FF),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildScheduleList(BuildContext context, AppLocalizations l10n) {
    final byStudent = _shiftsByStudent;
    if (byStudent.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              l10n.shiftNoTemplatesFound,
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    final entries = byStudent.entries.toList()
      ..sort((a, b) {
        final aName = a.key.split('|').last;
        final bName = b.key.split('|').last;
        return aName.compareTo(bName);
      });

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final studentName = entry.key.split('|').last;
        final shifts = entry.value;
        return _buildScheduleCard(context, l10n, studentName, shifts);
      },
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    AppLocalizations l10n,
    String studentName,
    List<TeachingShift> shifts,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  studentName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...shifts.map((shift) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0386FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        WeekDay.values
                            .firstWhere((d) => d.value == shift.shiftStart.weekday)
                            .localizedShortName(l10n),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0386FF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${shift.shiftStart.hour.toString().padLeft(2, '0')}:${shift.shiftStart.minute.toString().padLeft(2, '0')} - ${shift.shiftEnd.hour.toString().padLeft(2, '0')}:${shift.shiftEnd.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0386FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0386FF) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Row(
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTemplateAction(
    BuildContext context,
    AppLocalizations l10n,
    String action,
    GroupedTemplate group,
  ) {
    switch (action) {
      case 'modify':
        _showModifyDaysDialog(context, l10n, group);
        break;
      case 'reassign':
        _showReassignDialog(context, l10n, group);
        break;
      case 'deactivate':
        _deactivateTemplates(context, l10n, group);
        break;
      case 'reactivate':
        _reactivateTemplates(context, l10n, group);
        break;
    }
  }

  Future<void> _deactivateTemplates(
    BuildContext context,
    AppLocalizations l10n,
    GroupedTemplate group,
  ) async {
    try {
      for (final templateId in group.templateIds) {
        await ShiftService.deactivateShiftTemplate(templateId,
            reason: 'admin_deactivated');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shiftTemplateDeactivated),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      widget.onTemplateUpdated?.call();
      _loadTemplates();
    } catch (e) {
      AppLogger.error('Failed to deactivate templates: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shiftReassignError),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _reactivateTemplates(
    BuildContext context,
    AppLocalizations l10n,
    GroupedTemplate group,
  ) async {
    try {
      for (final templateId in group.templateIds) {
        await ShiftService.reactivateShiftTemplate(templateId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shiftTemplateReactivated),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      widget.onTemplateUpdated?.call();
      _loadTemplates();
    } catch (e) {
      AppLogger.error('Failed to reactivate templates: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shiftReassignError),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showReassignDialog(
    BuildContext context,
    AppLocalizations l10n,
    GroupedTemplate group,
  ) {
    String? selectedTeacherId = group.teacherId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.shiftReassignTeacher),
        content: StatefulBuilder(
          builder: (context, setDialogState) => DropdownButton<String?>(
            isExpanded: true,
            value: selectedTeacherId,
            items: _teachers
                .where((t) => t['id'] != group.teacherId)
                .map((t) => DropdownMenuItem(
                      value: t['id'] as String?,
                      child: Text(t['name'] as String),
                    ))
                .toList(),
            onChanged: (v) => setDialogState(() => selectedTeacherId = v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: selectedTeacherId == null
                ? null
                : () async {
                    Navigator.pop(ctx);
                    try {
                      final teacher = _teachers
                          .firstWhere((t) => t['id'] == selectedTeacherId);
                      final newTeacherName = teacher['name'] as String;
                      for (final templateId in group.templateIds) {
                        await ShiftService.reassignShiftTemplate(
                          templateId,
                          newTeacherId: selectedTeacherId!,
                          newTeacherName: newTeacherName,
                        );
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.shiftReassignSuccess),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                      widget.onTemplateUpdated?.call();
                      _loadTemplates();
                    } catch (e) {
                      AppLogger.error('Failed to reassign teacher: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.shiftReassignError),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0386FF),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  void _showModifyDaysDialog(
    BuildContext context,
    AppLocalizations l10n,
    GroupedTemplate group,
  ) {
    final selectedDays = Set<int>.from(group.weekdays.keys);
    TimeOfDay newStartTime = _parseTime(group.startTime ?? '00:00');
    TimeOfDay newEndTime = _parseTime(group.endTime ?? '00:00');
    bool useDifferentTimesPerDay = false;
    Map<int, (TimeOfDay, TimeOfDay)> perDayTimes = {};

    TimeOfDay startForDay(int day) => perDayTimes[day]?.$1 ?? newStartTime;
    TimeOfDay endForDay(int day) => perDayTimes[day]?.$2 ?? newEndTime;
    void setPerDayTime(int day, TimeOfDay start, TimeOfDay end) {
      perDayTimes[day] = (start, end);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.shiftTemplateModifyDays),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.shiftSelectDays,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: WeekDay.values.map((day) {
                      final isSelected = selectedDays.contains(day.value);
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            if (isSelected) {
                              selectedDays.remove(day.value);
                              perDayTimes.remove(day.value);
                            } else {
                              selectedDays.add(day.value);
                              if (useDifferentTimesPerDay) {
                                perDayTimes[day.value] =
                                    (newStartTime, newEndTime);
                              }
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0386FF)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0386FF)
                                  : const Color(0xFFD1D5DB),
                            ),
                          ),
                          child: Text(
                            day.localizedShortName(l10n),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Switch(
                        value: useDifferentTimesPerDay,
                        onChanged: (v) {
                          setDialogState(() {
                            useDifferentTimesPerDay = v;
                            if (v) {
                              for (final d in selectedDays) {
                                perDayTimes[d] ??=
                                    (newStartTime, newEndTime);
                              }
                            }
                          });
                        },
                        activeColor: const Color(0xFF0386FF),
                      ),
                      Text(l10n.shiftDifferentTimePerDay,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!useDifferentTimesPerDay) ...[
                    Text(l10n.shiftTimeLabel,
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _timeChip(ctx, setDialogState,
                              newStartTime, (t) => newStartTime = t),
                        ),
                        Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('→',
                                style: GoogleFonts.inter(
                                    color: Color(0xFF9CA3AF)))),
                        Expanded(
                          child: _timeChip(ctx, setDialogState,
                              newEndTime, (t) => newEndTime = t),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(l10n.shiftTimePerDayLabel,
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    ...(selectedDays.toList()..sort()).map((dayValue) {
                      final day = WeekDay.values
                          .firstWhere((d) => d.value == dayValue);
                      final start = startForDay(dayValue);
                      final end = endForDay(dayValue);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 36,
                                child: Text(day.localizedShortName(l10n),
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _timeChip(ctx, setDialogState, start,
                                  (t) => setPerDayTime(
                                      dayValue, t, end)),
                            ),
                            Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                child: Text('→',
                                    style: GoogleFonts.inter(
                                        color: Color(0xFF9CA3AF)))),
                            Expanded(
                              child: _timeChip(ctx, setDialogState, end,
                                  (t) => setPerDayTime(
                                      dayValue, start, t)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: selectedDays.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        for (final templateId in group.templateIds) {
                          List<Map<String, dynamic>>? weekdayTimeSlots;
                          if (useDifferentTimesPerDay &&
                              perDayTimes.isNotEmpty) {
                            weekdayTimeSlots = perDayTimes.entries
                                .map((e) => {
                                      'weekday': e.key,
                                      'start_hour': e.value.$1.hour,
                                      'start_minute': e.value.$1.minute,
                                      'end_hour': e.value.$2.hour,
                                      'end_minute': e.value.$2.minute,
                                    })
                                .toList();
                          }
                          String? startTimeStr;
                          String? endTimeStr;
                          if (!useDifferentTimesPerDay ||
                              weekdayTimeSlots == null) {
                            startTimeStr =
                                '${newStartTime.hour.toString().padLeft(2, '0')}:${newStartTime.minute.toString().padLeft(2, '0')}';
                            endTimeStr =
                                '${newEndTime.hour.toString().padLeft(2, '0')}:${newEndTime.minute.toString().padLeft(2, '0')}';
                          }
                          await ShiftService.updateShiftTemplateDays(
                            templateId,
                            selectedWeekdays: selectedDays.toList()..sort(),
                            startTime: startTimeStr,
                            endTime: endTimeStr,
                            weekdayTimeSlots: weekdayTimeSlots,
                            useDifferentTimesPerDay:
                                useDifferentTimesPerDay
                                    ? true
                                    : null,
                          );
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(l10n.shiftScheduleUpdatedSuccess),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                        widget.onTemplateUpdated?.call();
                        _loadTemplates();
                      } catch (e) {
                        AppLogger.error(
                            'Failed to modify template days: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(l10n.shiftScheduleUpdateFailed),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0386FF),
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(
    BuildContext ctx,
    void Function(void Function()) setDialogState,
    TimeOfDay value,
    void Function(TimeOfDay) onPicked,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: ctx,
          initialTime: value,
        );
        if (picked != null) {
          setDialogState(() => onPicked(picked));
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value.format(ctx),
          style: GoogleFonts.inter(fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }
}

/// Grouped template model for displaying multiple days per student
class GroupedTemplate {
  final String teacherName;
  final String? teacherId;
  final String studentName;
  final List<dynamic> studentIds;
  final bool isActive;
  final List<String> templateIds;
  final Map<int, String> weekdays; // weekday -> templateId
  final String? startTime;
  final String? endTime;

  GroupedTemplate({
    required this.teacherName,
    required this.teacherId,
    required this.studentName,
    required this.studentIds,
    required this.isActive,
    required this.templateIds,
    required this.weekdays,
    required this.startTime,
    required this.endTime,
  });
}