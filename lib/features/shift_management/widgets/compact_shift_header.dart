import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../core/enums/shift_enums.dart';
import 'package:alluwalacademyadmin/l10n/app_localizations.dart';

/// Compact header for shift management screen (ConnectTeam-inspired)
/// Height: 60px, contains essential controls only
class CompactShiftHeader extends StatelessWidget {
  final DateTime currentWeekStart;
  final Function(DateTime) onWeekChanged;
  final Function(String) onViewOptionSelected;
  final Function(String) onActionSelected;
  final Function(String) onAddSelected;
  final VoidCallback onRefresh;
  final bool isAdmin;

  const CompactShiftHeader({
    super.key,
    required this.currentWeekStart,
    required this.onWeekChanged,
    required this.onViewOptionSelected,
    required this.onActionSelected,
    required this.onAddSelected,
    required this.onRefresh,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final weekEnd = currentWeekStart.add(const Duration(days: 6));

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        children: [
          // Icon + Title
          const Icon(Icons.schedule, color: Color(0xff0386FF), size: 24),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context)!.navShifts,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xff111827),
            ),
          ),
          const SizedBox(width: 24),

          // Week Navigator
          _buildWeekNavigator(weekEnd),

          const Spacer(),

          // View Options Dropdown
          _buildViewOptionsDropdown(context),

          const SizedBox(width: 12),

          // Actions Dropdown (Settings, Subjects, Pay, DST)
          if (isAdmin) ...[
            _buildActionsDropdown(context),
            const SizedBox(width: 12),
          ],

          // Add Shift Button with Dropdown
          if (isAdmin) ...[
            _buildAddShiftButton(context),
            const SizedBox(width: 12),
          ],

          // Refresh
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: Color(0xff6B7280)),
            tooltip: AppLocalizations.of(context)!.commonRefresh,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigator(DateTime weekEnd) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              onWeekChanged(currentWeekStart.subtract(const Duration(days: 7)));
            },
            icon: const Icon(Icons.chevron_left, size: 20),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${DateFormat('MMM d').format(currentWeekStart)} - ${DateFormat('d').format(weekEnd)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              onWeekChanged(currentWeekStart.add(const Duration(days: 7)));
            },
            icon: const Icon(Icons.chevron_right, size: 20),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          Builder(
            builder: (context) => IconButton(
              onPressed: () async {
                // Show date picker to jump to specific week
                final date = await showDatePicker(
                  context: context,
                  initialDate: currentWeekStart,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  // Find Monday of that week
                  final monday = date.subtract(Duration(days: date.weekday - 1));
                  onWeekChanged(monday);
                }
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              tooltip: AppLocalizations.of(context)!.jumpToDate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewOptionsDropdown(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onViewOptionSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.viewOptions,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'grid', child: Text(AppLocalizations.of(context)!.gridView)),
        PopupMenuItem(value: 'week', child: Text(AppLocalizations.of(context)!.weekCalendar)),
        PopupMenuItem(value: 'list', child: Text(AppLocalizations.of(context)!.listView)),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'teachers', child: Text(AppLocalizations.of(context)!.teachersOnly)),
        PopupMenuItem(value: 'leaders', child: Text(AppLocalizations.of(context)!.leadersOnly)),
        PopupMenuItem(value: 'all', child: Text(AppLocalizations.of(context)!.allSchedules)),
      ],
    );
  }

  Widget _buildActionsDropdown(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onActionSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xff0386FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.timesheetActions,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xff0386FF),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xff0386FF)),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _menuItem(Icons.subject, 'Manage Subjects', 'subjects'),
        _menuItem(Icons.attach_money, 'Pay Settings', 'pay'),
        _menuItem(Icons.access_time, 'DST Adjustment', 'dst'),
        const PopupMenuDivider(),
        _menuItem(Icons.copy_all, 'Duplicate Week', 'duplicate_week'),
        _menuItem(Icons.checklist, 'Bulk Select', 'select'),
        _menuItem(Icons.person_remove, 'Delete Teacher Shifts', 'delete_teacher'),
      ],
      // Ensure menu is scrollable if it gets too long
      constraints: const BoxConstraints(maxHeight: 400),
    );
  }

  Widget _buildAddShiftButton(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onAddSelected,
      child: ElevatedButton.icon(
        onPressed: null, // Handled by popup
        icon: const Icon(Icons.add, size: 18),
        label: Text(AppLocalizations.of(context)!.add),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff0386FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      itemBuilder: (context) => [
        _menuItem(Icons.school, 'Teacher Shift', 'teacher_shift'),
        _menuItem(Icons.admin_panel_settings, 'Leader Shift', 'leader_shift'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(IconData icon, String text, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xff6B7280)),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

