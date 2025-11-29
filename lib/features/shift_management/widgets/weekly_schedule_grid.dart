import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/teaching_shift.dart';
import '../../../core/models/employee_model.dart';
import '../../../core/enums/shift_enums.dart';
import 'shift_block.dart';
import 'empty_cell_hover_indicator.dart';

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
    if (oldWidget.searchQuery != widget.searchQuery) {
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
        final dayColumnWidth = (availableWidth - userColumnWidth) / 7;

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
                  return _buildUserShiftRow(item.user!, weekDays, userColumnWidth, dayColumnWidth);
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
    
    return Container(
      height: 56, // Compact header height
      color: const Color(0xffFAFAFA),
      child: Row(
        children: [
          // Search users column header - Functional search field
          Container(
            width: userColumnWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xffE2E8F0))),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xff374151),
              ),
              decoration: InputDecoration(
                hintText: 'Search users',
                hintStyle: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xff9CA3AF),
                ),
                prefixIcon: const Icon(Icons.search, size: 14, color: Color(0xff6B7280)),
                suffixIcon: widget.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14, color: Color(0xff6B7280)),
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearchChanged('');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          // Day columns
          ...weekDays.map((day) {
            final isToday = day.year == today.year && 
                           day.month == today.month && 
                           day.day == today.day;
            final stats = _calculateDayStats(_getShiftsForDay(day));
            
            return Container(
              width: dayColumnWidth,
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

  Widget _buildUserShiftRow(Employee user, List<DateTime> weekDays, double userColumnWidth, double dayColumnWidth) {
    return Container(
      height: 60, // Fixed height to avoid constraint issues
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          // Day columns with shifts
          ...weekDays.map((day) {
            return SizedBox(
              width: dayColumnWidth,
              child: _buildDayCell(user, day),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDayCell(Employee user, DateTime day) {
    final userShifts = _getUserShiftsForDay(user, day);
    
    return SizedBox(
      height: 60, // Fixed height to match row height
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xffE2E8F0))),
        ),
        child: userShifts.isEmpty
            ? _buildEmptyCell(user, day)
            : userShifts.length == 1
                // Single shift - full height with hover actions
                ? ShiftBlock(
                    shift: userShifts.first,
                    onTap: () => widget.onShiftTap(userShifts.first),
                    onViewDetails: () => widget.onShiftTap(userShifts.first),
                    onEdit: widget.onEditShift != null 
                        ? () => widget.onEditShift!(userShifts.first)
                        : null,
                    onAddShift: () => widget.onCreateShift(user.email, day, const TimeOfDay(hour: 14, minute: 0)),
                    teacherEmail: user.email,
                    compact: true,
                  )
                // Multiple shifts - scrollable list
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: userShifts.map((shift) {
                        return SizedBox(
                          height: 36, // Fixed height per shift block
                          child: ShiftBlock(
                            shift: shift,
                            onTap: () => widget.onShiftTap(shift),
                            onViewDetails: () => widget.onShiftTap(shift),
                            onEdit: widget.onEditShift != null 
                                ? () => widget.onEditShift!(shift)
                                : null,
                            onAddShift: () => widget.onCreateShift(user.email, day, const TimeOfDay(hour: 14, minute: 0)),
                            teacherEmail: user.email,
                            compact: true,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyCell(Employee user, DateTime day) {
    return InkWell(
      onTap: () {
        // Create shift at default time (2 PM)
        widget.onCreateShift(user.email, day, const TimeOfDay(hour: 14, minute: 0));
      },
      child: Container(
        height: 60,
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
