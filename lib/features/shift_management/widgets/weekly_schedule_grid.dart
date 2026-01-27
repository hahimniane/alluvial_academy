import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/enums/shift_enums.dart';
import 'shift_block.dart';
import 'empty_cell_hover_indicator.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// ConnectTeam-inspired weekly schedule grid view
/// Shows users as rows, days as columns, with shift blocks
class WeeklyScheduleGrid extends StatefulWidget {
  final DateTime weekStart;
  final List<TeachingShift> shifts;
  final List<Employee> teachers;
  final List<Employee> leaders;
  final String scheduleTypeFilter; // 'all', 'teachers', 'leaders'
  final String searchQuery;
  final Function(String) onSearchChanged; // Callback when search changes
  final Function(TeachingShift) onShiftTap;
  final Function(TeachingShift)? onEditShift; // Edit shift callback
  final Function(String userId, DateTime date, TimeOfDay time) onCreateShift;
  final Function(String) onUserTap;
  final Function(DateTime)? onWeekChanged; // Week navigation callback
  final Set<String> selectedShiftIds; // Multi-select support
  final Function(String, bool)? onShiftSelectionChanged; // Selection callback
  final bool isSelectionMode; // Whether selection mode is active

  const WeeklyScheduleGrid({
    super.key,
    required this.weekStart,
    required this.shifts,
    required this.teachers,
    required this.leaders,
    required this.scheduleTypeFilter,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onShiftTap,
    this.onEditShift,
    required this.onCreateShift,
    required this.onUserTap,
    this.onWeekChanged,
    this.selectedShiftIds = const {},
    this.onShiftSelectionChanged,
    this.isSelectionMode = false,
  });

  @override
  State<WeeklyScheduleGrid> createState() => _WeeklyScheduleGridState();
}

class _WeeklyScheduleGridState extends State<WeeklyScheduleGrid> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    widget.onSearchChanged(_searchController.text);
  }

  @override
  void didUpdateWidget(WeeklyScheduleGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery && _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays();
    final filteredUsers = _getFilteredUsers();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive column widths
        final availableWidth = constraints.maxWidth;
        final userColumnWidth = (availableWidth * 0.18).clamp(120.0, 180.0);
        final weekNavWidth = widget.onWeekChanged != null ? 80.0 : 0.0;
        final dayColumnWidth = ((availableWidth - userColumnWidth - weekNavWidth) / 7).clamp(40.0, double.infinity);

        return Column(
          children: [
            // Header Row with Days - compact
            _buildDayHeaderRow(weekDays, userColumnWidth, dayColumnWidth),
            const Divider(height: 1, thickness: 1),
            // Scrollable User Rows
            Expanded(
              child: ListView.builder(
                itemCount: _buildGroupedUserList(filteredUsers).length,
                itemBuilder: (context, index) {
                  final item = _buildGroupedUserList(filteredUsers)[index];
                  if (item.isHeader) {
                    return _buildSectionHeader(item.title ?? '');
                  }
                  // FIX: Pass the weekNavWidth here
                  return _buildUserShiftRow(
                      item.user!, weekDays, userColumnWidth, dayColumnWidth, weekNavWidth);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<DateTime> _getWeekDays() {
    return List.generate(7, (index) {
      return widget.weekStart.add(Duration(days: index));
    });
  }

  List<Employee> _getFilteredUsers() {
    List<Employee> users = [];
    
    if (widget.scheduleTypeFilter == 'all' || widget.scheduleTypeFilter == 'teachers') {
      users.addAll(widget.teachers);
    }
    if (widget.scheduleTypeFilter == 'all' || widget.scheduleTypeFilter == 'leaders') {
      users.addAll(widget.leaders);
    }

    // Apply search filter
    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      users = users.where((user) {
        final fullName = '${user.firstName} ${user.lastName}'.toLowerCase();
        return fullName.contains(query) || user.email.toLowerCase().contains(query);
      }).toList();
    }

    // Sort by name
    users.sort((a, b) {
      final nameA = '${a.firstName} ${a.lastName}';
      final nameB = '${b.firstName} ${b.lastName}';
      return nameA.compareTo(nameB);
    });

    return users;
  }

  List<_GroupedItem> _buildGroupedUserList(List<Employee> users) {
    final items = <_GroupedItem>[];
    
    // Separate teachers and leaders
    final teachersList = users.where((u) => 
      u.userType == 'teacher' && !(u.isAdminTeacher)).toList();
    final leadersList = users.where((u) => 
      u.userType == 'admin' || u.isAdminTeacher).toList();

    // Add teachers section
    if (teachersList.isNotEmpty && (widget.scheduleTypeFilter == 'all' || widget.scheduleTypeFilter == 'teachers')) {
      items.add(_GroupedItem(isHeader: true, title: 'TEACHERS (${teachersList.length})'));
      for (var teacher in teachersList) {
        items.add(_GroupedItem(isHeader: false, user: teacher));
      }
    }

    // Add leaders section
    if (leadersList.isNotEmpty && (widget.scheduleTypeFilter == 'all' || widget.scheduleTypeFilter == 'leaders')) {
      items.add(_GroupedItem(isHeader: true, title: 'LEADERS (${leadersList.length})'));
      for (var leader in leadersList) {
        items.add(_GroupedItem(isHeader: false, user: leader));
      }
    }

    return items;
  }

  Widget _buildDayHeaderRow(List<DateTime> weekDays, double userColumnWidth, double dayColumnWidth) {
    final today = DateTime.now();
    final weekEnd = weekDays.last;
    
    return Container(
      height: 56, // Compact header height
      color: const Color(0xffFAFAFA),
      child: Row(
        children: [
          // User column header (no search bar - moved to parent)
          Container(
            width: userColumnWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xffE2E8F0))),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context)!.teachers,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xff6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '(${_getFilteredUsers().length})',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: const Color(0xff9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          // Week navigation and day columns
          Expanded(
            child: Row(
              children: [
                // Week navigation arrows
                if (widget.onWeekChanged != null)
                  Container(
                    width: 80,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Color(0xffE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 18),
                          color: const Color(0xff6B7280),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: AppLocalizations.of(context)!.previousWeek,
                          onPressed: () {
                            widget.onWeekChanged!(widget.weekStart.subtract(const Duration(days: 7)));
                          },
                        ),
                        Expanded(
                          child: Text(
                            '${DateFormat('EEE M/d').format(weekDays.first)} → ${DateFormat('EEE M/d').format(weekEnd)}',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xff374151),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          color: const Color(0xff6B7280),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: AppLocalizations.of(context)!.nextWeek,
                          onPressed: () {
                            widget.onWeekChanged!(widget.weekStart.add(const Duration(days: 7)));
                          },
                        ),
                      ],
                    ),
                  ),
                // Day columns
                ...weekDays.map((day) {
                  final isToday = day.year == today.year && 
                                 day.month == today.month && 
                                 day.day == today.day;
                  final stats = _calculateDayStats(_getShiftsForDay(day));
                  
                  return Container(
                    width: dayColumnWidth > 0 ? dayColumnWidth : 40.0,
                    decoration: BoxDecoration(
                      border: const Border(right: BorderSide(color: Color(0xffE2E8F0))),
                      color: isToday ? const Color(0xff0386FF).withOpacity(0.05) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Day name and date
                        Text(
                          DateFormat('EEE').format(day),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isToday ? const Color(0xff0386FF) : const Color(0xff374151),
                          ),
                        ),
                        Text(
                          DateFormat('M/d').format(day),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isToday ? const Color(0xff0386FF) : const Color(0xff6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Stats row - compact
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 10, color: const Color(0xff9CA3AF)),
                            const SizedBox(width: 2),
                            Text(
                              stats.totalHours,
                              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xff9CA3AF)),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.assignment, size: 10, color: const Color(0xff9CA3AF)),
                            const SizedBox(width: 2),
                            Text(
                              '${stats.shiftCount}',
                              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xff9CA3AF)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      height: 32, // Compact section header
      color: const Color(0xffF3F4F6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            title.startsWith('TEACHERS') ? Icons.school : Icons.admin_panel_settings,
            size: 14,
            color: const Color(0xff6B7280),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: const Color(0xff6B7280),
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // FIX: Update signature to accept weekNavWidth
  Widget _buildUserShiftRow(Employee user, List<DateTime> weekDays, 
      double userColumnWidth, double dayColumnWidth, double weekNavWidth) {
    
    // 1. Calculate the maximum number of shifts this user has on any single day this week
    int maxShifts = 0;
    for (var day in weekDays) {
      final shifts = _getUserShiftsForDay(user, day);
      if (shifts.length > maxShifts) {
        maxShifts = shifts.length;
      }
    }

    // 2. Define heights
    const double singleShiftHeight = 36.0; // Increased from 22 to 36 so text fits!
    const double gap = 4.0;
    
    // 3. Calculate dynamic height based on the busiest day
    // Minimum height is 80 (for aesthetics), otherwise grow to fit all shifts
    double contentHeight = (maxShifts * (singleShiftHeight + gap)) + 16.0; // 16 for padding
    double rowHeight = contentHeight < 80.0 ? 80.0 : contentHeight;

    return Container(
      height: rowHeight, // FIX: Use the calculated dynamic height
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch to fill height
        children: [
          // User info column (responsive width)
          Container(
            width: userColumnWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xffE2E8F0))),
            ),
            child: InkWell(
              onTap: () => widget.onUserTap(user.email),
              child: Row(
                children: [
                  // Avatar - compact
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xff0386FF).withOpacity(0.1),
                    child: Text(
                      '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff0386FF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${user.firstName} ${user.lastName}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xff111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 10, color: const Color(0xff9CA3AF)),
                            const SizedBox(width: 2),
                            Text(
                              _getUserTotalHours(user),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xff9CA3AF),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.assignment, size: 10, color: const Color(0xff9CA3AF)),
                            const SizedBox(width: 2),
                            Text(
                              '${_getUserShiftCount(user)}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xff9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // FIX: Add this Spacer to align rows with the header
          if (weekNavWidth > 0)
            Container(
              width: weekNavWidth,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Color(0xffE2E8F0))),
              ),
            ),

          // Day columns with shifts
          ...weekDays.map((day) {
            final now = DateTime.now();
            final dayStart = DateTime(day.year, day.month, day.day);
            final isPastDate = dayStart.isBefore(DateTime(now.year, now.month, now.day));
            
            return SizedBox(
              width: dayColumnWidth > 0 ? dayColumnWidth : 40.0,
              height: rowHeight, // Pass the dynamic height down
              child: _buildDayCell(user, day, isPastDate, singleShiftHeight, rowHeight),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDayCell(Employee user, DateTime day, bool isPastDate, double shiftHeight, double rowHeight) {
    final userShifts = _getUserShiftsForDay(user, day);
    
    return Container(
      height: rowHeight, // Use the row height from parent
      width: double.infinity, // Ensure full width
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: const Border(right: BorderSide(color: Color(0xffE2E8F0))),
        // Color-code past date cells with shifts
        color: isPastDate && userShifts.isNotEmpty 
            ? _getPastDateBackgroundColor(userShifts.first)
            : null,
      ),
      child: ClipRect(
        child: userShifts.isEmpty
            ? _buildEmptyCell(user, day, isPastDate, rowHeight)
            : userShifts.length == 1
                // Single shift - full height with hover actions
                ? SizedBox(
                    height: rowHeight - 4, // Account for padding
                    width: double.infinity,
                    child: ShiftBlock(
                      shift: userShifts.first,
                      onTap: () => widget.onShiftTap(userShifts.first),
                      onViewDetails: () => widget.onShiftTap(userShifts.first),
                      onEdit: widget.onEditShift != null && !isPastDate
                          ? () => widget.onEditShift!(userShifts.first)
                          : null,
                      onAddShift: !isPastDate 
                          ? () => widget.onCreateShift(user.email, day, const TimeOfDay(hour: 14, minute: 0))
                          : null,
                      teacherEmail: user.email,
                      compact: true,
                      isPastDate: isPastDate,
                      isSelected: widget.selectedShiftIds.contains(userShifts.first.id),
                      onSelectionChanged: widget.onShiftSelectionChanged != null
                          ? (selected) => widget.onShiftSelectionChanged!(userShifts.first.id, selected)
                          : null,
                      isSelectionMode: widget.isSelectionMode,
                    ),
                  )
                // Multiple shifts - show grouped view with better hover actions
                : _buildMultipleShiftsCell(user, day, userShifts, isPastDate, shiftHeight),
      ),
    );
  }

  Widget _buildMultipleShiftsCell(Employee user, DateTime day, List<TeachingShift> shifts, bool isPastDate, double shiftHeight) {
    const double spacing = 4.0; // More breathing room
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: shifts.asMap().entries.map((entry) {
        final index = entry.key;
        final shift = entry.value;
        return Container(
          height: shiftHeight, // Use the taller height (36.0)
          margin: EdgeInsets.only(bottom: index < shifts.length - 1 ? spacing : 0),
          child: ShiftBlock(
            shift: shift,
            onTap: () => widget.onShiftTap(shift),
            onViewDetails: () => _showMultipleShiftsMenu(user, day, shifts),
            onEdit: widget.onEditShift != null && !isPastDate
                ? () => widget.onEditShift!(shift)
                : null,
            onAddShift: !isPastDate 
                ? () => widget.onCreateShift(user.email, day, const TimeOfDay(hour: 14, minute: 0))
                : null,
            teacherEmail: user.email,
            compact: true,
            isPastDate: isPastDate,
            isSelected: widget.selectedShiftIds.contains(shift.id),
            onSelectionChanged: widget.onShiftSelectionChanged != null
                ? (selected) => widget.onShiftSelectionChanged!(shift.id, selected)
                : null,
            isSelectionMode: widget.isSelectionMode,
            showMultipleShiftsIndicator: true,
            shiftIndex: index + 1,
            totalShifts: shifts.length,
          ),
        );
      }).toList(),
    );
  }

  void _showMultipleShiftsMenu(Employee user, DateTime day, List<TeachingShift> shifts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${user.firstName} ${user.lastName} - ${DateFormat('EEE, M/d').format(day)}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${shifts.length} shifts scheduled',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xff6B7280),
                ),
              ),
              const SizedBox(height: 16),
              ...shifts.asMap().entries.map((entry) {
                final index = entry.key;
                final shift = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xffE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Shift #${index + 1}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            if (widget.onEditShift != null)
                              TextButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: Text(AppLocalizations.of(context)!.commonEdit),
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onEditShift!(shift);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('h:mma').format(shift.shiftStart)} - ${DateFormat('h:mma').format(shift.shiftEnd)}',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        Text(
                          shift.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xff6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (!_isPastDate(day))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppLocalizations.of(context)!.addAnotherShift2),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onCreateShift(user.email, day, const TimeOfDay(hour: 14, minute: 0));
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.commonClose,
              style: GoogleFonts.inter(color: const Color(0xff6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  bool _isPastDate(DateTime day) {
    final now = DateTime.now();
    final dayStart = DateTime(day.year, day.month, day.day);
    return dayStart.isBefore(DateTime(now.year, now.month, now.day));
  }

  Color _getPastDateBackgroundColor(TeachingShift shift) {
    switch (shift.status) {
      case ShiftStatus.missed:
        return const Color(0xFFFDE0E0); // Light red
      case ShiftStatus.completed:
      case ShiftStatus.fullyCompleted:
        return const Color(0xFFE6F7E8); // Light green
      case ShiftStatus.partiallyCompleted:
        return const Color(0xFFFFF7D1); // Light yellow
      case ShiftStatus.scheduled:
      case ShiftStatus.active:
        return const Color(0xFFDDEAFF); // Light blue
      case ShiftStatus.cancelled:
        return const Color(0xFFF3F4F6); // Light gray
    }
  }

  Widget _buildEmptyCell(Employee user, DateTime day, bool isPastDate, double cellHeight) {
    // Past dates: show blank, non-clickable cell
    if (isPastDate) {
      return Container(
        height: cellHeight,
        width: double.infinity,
        color: Colors.transparent,
      );
    }
    
    // Future dates: show hover indicator with add button
    return InkWell(
      onTap: () {
        // Create shift at default time (2 PM)
        widget.onCreateShift(user.email, day, const TimeOfDay(hour: 14, minute: 0));
      },
      child: Container(
        height: cellHeight,
        width: double.infinity, // Fill entire cell width
        alignment: Alignment.center,
        child: EmptyCellHoverIndicator(
          onTap: () => widget.onCreateShift(user.email, day, const TimeOfDay(hour: 14, minute: 0)),
        ),
      ),
    );
  }

  List<TeachingShift> _getShiftsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    return widget.shifts.where((shift) {
      final shiftDate = DateTime(
        shift.shiftStart.year,
        shift.shiftStart.month,
        shift.shiftStart.day,
      );
      return shiftDate.isAtSameMomentAs(dayStart) ||
          (shiftDate.isAfter(dayStart) && shiftDate.isBefore(dayEnd));
    }).toList();
  }

  List<TeachingShift> _getUserShiftsForDay(Employee user, DateTime day) {
    // Get user ID from email
    final userShifts = widget.shifts.where((shift) {
      // Match by teacher name (since we don't have direct email mapping here)
      final shiftTeacherName = shift.teacherName.toLowerCase();
      final userName = '${user.firstName} ${user.lastName}'.toLowerCase();
      return shiftTeacherName == userName;
    }).toList();
    
    return _getShiftsForDay(day).where((shift) {
      return userShifts.any((s) => s.id == shift.id);
    }).toList();
  }

  _DayStats _calculateDayStats(List<TeachingShift> dayShifts) {
    double totalHours = 0;
    final uniqueUsers = <String>{};
    
    for (var shift in dayShifts) {
      final duration = shift.shiftEnd.difference(shift.shiftStart);
      totalHours += duration.inHours + (duration.inMinutes % 60) / 60.0;
      uniqueUsers.add(shift.teacherId);
    }
    
    return _DayStats(
      totalHours: totalHours.toStringAsFixed(1),
      shiftCount: dayShifts.length,
      userCount: uniqueUsers.length,
    );
  }

  String _getUserTotalHours(Employee user) {
    final userShifts = widget.shifts.where((shift) {
      final shiftTeacherName = shift.teacherName.toLowerCase();
      final userName = '${user.firstName} ${user.lastName}'.toLowerCase();
      return shiftTeacherName == userName;
    }).toList();

    double totalHours = 0;
    for (var shift in userShifts) {
      final duration = shift.shiftEnd.difference(shift.shiftStart);
      totalHours += duration.inHours + (duration.inMinutes % 60) / 60.0;
    }
    return totalHours.toStringAsFixed(1);
  }

  int _getUserShiftCount(Employee user) {
    return widget.shifts.where((shift) {
      final shiftTeacherName = shift.teacherName.toLowerCase();
      final userName = '${user.firstName} ${user.lastName}'.toLowerCase();
      return shiftTeacherName == userName;
    }).length;
  }
}

class _GroupedItem {
  final bool isHeader;
  final String? title;
  final Employee? user;

  _GroupedItem({
    required this.isHeader,
    this.title,
    this.user,
  });
}

class _DayStats {
  final String totalHours;
  final int shiftCount;
  final int userCount;

  _DayStats({
    required this.totalHours,
    required this.shiftCount,
    required this.userCount,
  });
}
