# Comprehensive Shift & Tasks Redesign Proposal
## Alluvial Academy Admin Panel - ConnectTeam-Inspired Improvements

**Document Created:** November 28, 2025  
**Purpose:** Strategic roadmap for improving Shift Management, Timesheet Export, and Task Management based on ConnectTeam inspiration

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Phase 1: Shift Management UI Redesign](#phase-1-shift-management-ui-redesign)
4. [Phase 2: Leader Schedule Management](#phase-2-leader-schedule-management)
5. [Phase 3: Enhanced Timesheet Export](#phase-3-enhanced-timesheet-export)
6. [Phase 4: Tasks Interface Redesign](#phase-4-tasks-interface-redesign)
7. [Technical Implementation Strategy](#technical-implementation-strategy)
8. [UI/UX Design Guidelines](#uiux-design-guidelines)
9. [Data Model Updates](#data-model-updates)
10. [Priority & Timeline](#priority--timeline)

---

## Executive Summary

This proposal outlines a comprehensive redesign of the Shift Management and Task Management features in the Alluvial Academy admin panel. The goal is to create a **user-friendly, ConnectTeam-inspired interface** that:

- ✅ Organizes shifts in a clear weekly grid (teachers as rows, days as columns)
- ✅ Supports both **Teacher** and **Leader** schedules
- ✅ Links teacher schedule information to clock-in records
- ✅ Exports detailed timesheets in Excel format (ConnectTeam-style)
- ✅ Provides a modern task management interface with tabs and grouping

---

## Current State Analysis

### Current Shift Management Screen Issues

Based on analysis of `lib/features/shift_management/screens/shift_management_screen.dart`:

| Issue | Impact | Solution |
|-------|--------|----------|
| Header takes too much vertical space | Reduces content visibility | Compact header with collapsible stats |
| Too many action buttons in header | Visual clutter, hard to find actions | Move to dropdown menu or toolbar |
| DataGrid view is dense and hard to scan | Poor UX for quick scheduling | Weekly grid view (ConnectTeam-style) |
| No visual distinction between shift types | Can't quickly identify teacher vs leader shifts | Color-coded shift blocks |
| Search + Delete Teacher + Select all in one row | Overwhelming UI | Separate action areas |
| Stats cards take full width | Wastes space on large screens | Compact horizontal scrollable or collapsible |

### Current Tasks Screen Issues

Based on analysis of `lib/features/tasks/screens/quick_tasks_screen.dart`:

| Issue | Impact | Solution |
|-------|--------|----------|
| No tab organization | Hard to find relevant tasks | Add tabs: "Created By Me", "My Tasks", "All Tasks", "Archived" |
| Grid-only view | Not suitable for task lists | Add List view option |
| No grouping by assignee | Hard to see workload distribution | Add "Group by: Assigned to" |
| No overdue counter | Can't see urgency at a glance | Add prominent overdue badge |

### Current Timesheet Export Issues

Based on analysis of `lib/features/time_clock/screens/admin_timesheet_review.dart`:

| Issue | Impact | Solution |
|-------|--------|----------|
| Missing shift title in export | Can't identify which class was taught | Add "Scheduled shift title" column |
| No daily/weekly totals | Manual calculation needed | Add computed columns |
| No device tracking | Can't verify clock-in method | Add Start-device, End-device columns |
| Missing difference columns | Can't see variance from scheduled | Add Daily difference, Total difference |

---

## Phase 1: Shift Management UI Redesign

### 1.1 New Layout Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ HEADER BAR (Compact - 60px)                                                  │
│ ┌──────────┐  ┌─────────┐  ┌──────────────┐       ┌─────────┐ ┌───────────┐ │
│ │📅 Shifts │  │< Week > │  │ Aug 7 - 13   │       │ Actions▼│ │ +Add    ▼│ │
│ └──────────┘  └─────────┘  └──────────────┘       └─────────┘ └───────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│ TOOLBAR (40px)                                                               │
│ ┌───────────────┐ ┌────────┐ ┌──────────────────┐ ┌────────────────────────┐│
│ │View options ▼ │ │ ≡ Filter│ │ Search Teacher Q │ │Schedule Type: All ▼   ││
│ └───────────────┘ └────────┘ └──────────────────┘ └────────────────────────┘│
├─────────────────────────────────────────────────────────────────────────────┤
│ SCHEDULE GRID                                                                │
│ ┌─────────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐ │
│ │             │ Mon 8/7 │ Tue 8/8 │ Wed 8/9 │ Thu 8/10│ Fri 8/11│ Sat 8/12│ │
│ │ Search users│ ⏰ --   │ ⏰ 08:00│ ⏰ 27:00│ ⏰ --   │ ⏰ 26:00│ ⏰ --   │ │
│ │      Q      │ 📋 0 👥0│ 📋 1 👥1│ 📋 3 👥3│ 📋 0 👥0│ 📋 3 👥3│ 📋 0 👥0│ │
│ ├─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤ │
│ │ TEACHERS    │         │         │         │         │         │         │ │
│ ├─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤ │
│ │ 👤 Emily D. │         │         │         │░░░░░░░░░│┌───────┐│         │ │
│ │ ⏰-- 📋0    │         │         │         │ Sick    ││10:30a-││         │ │
│ │             │         │         │         │ All day ││7:30p  ││         │ │
│ │             │         │         │         │░░░░░░░░░│└───────┘│         │ │
│ ├─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤ │
│ │ 👤 Jessica M│         │         │┌───────┐│         │┌───────┐│         │ │
│ │ ⏰09:00 📋1 │         │         ││8a - 5p││         ││10:30a-││         │ │
│ │             │         │         ││Arabic ││         ││7:30p  ││         │ │
│ │             │         │         │└───────┘│         │└───────┘│         │ │
│ ├─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤ │
│ │ LEADERS     │         │         │         │         │         │         │ │
│ ├─────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤ │
│ │ 👤 Admin 1  │         │┌───────┐│         │         │         │         │ │
│ │ ⏰09:00 📋1 │         ││9a - 5p││         │         │         │         │ │
│ │             │         ││Admin  ││         │         │         │         │ │
│ └─────────────┴─────────┴└───────┘┴─────────┴─────────┴─────────┴─────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Breakdown

#### A. Compact Header Bar
```dart
// New: Compact header with essential controls
Widget _buildCompactHeader() {
  return Container(
    height: 60,
    padding: EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
    ),
    child: Row(
      children: [
        // Icon + Title
        Icon(Icons.schedule, color: primaryBlue),
        SizedBox(width: 12),
        Text('Shift Management', style: titleStyle),
        Spacer(),
        // Week Navigation
        _buildWeekNavigator(),
        Spacer(),
        // Actions Dropdown
        _buildActionsDropdown(),
        SizedBox(width: 12),
        // Add Shift Button
        _buildAddShiftButton(),
      ],
    ),
  );
}
```

#### B. Schedule Type Selector
```dart
// New: Filter between Teacher and Leader schedules
enum ScheduleType { all, teachers, leaders }

Widget _buildScheduleTypeSelector() {
  return DropdownButton<ScheduleType>(
    value: _selectedScheduleType,
    items: [
      DropdownMenuItem(value: ScheduleType.all, child: Text('All Schedules')),
      DropdownMenuItem(value: ScheduleType.teachers, child: Text('Teachers Only')),
      DropdownMenuItem(value: ScheduleType.leaders, child: Text('Leaders Only')),
    ],
    onChanged: (value) => setState(() => _selectedScheduleType = value!),
  );
}
```

#### C. Weekly Grid View (ConnectTeam-Style)
```dart
// Inspired by schedule_grid_view.dart from testing
Widget _buildWeeklyScheduleGrid() {
  return Column(
    children: [
      // Header Row with Days
      _buildDayHeaderRow(),
      // Divider
      Divider(height: 1),
      // Scrollable Teacher/Leader Rows
      Expanded(
        child: ListView.builder(
          itemCount: _groupedUsers.length,
          itemBuilder: (context, index) {
            final group = _groupedUsers[index];
            if (group.isHeader) {
              return _buildSectionHeader(group.title); // "TEACHERS" or "LEADERS"
            }
            return _buildUserShiftRow(group.user);
          },
        ),
      ),
    ],
  );
}
```

### 1.3 Shift Block Design

```dart
// Color-coded shift blocks
Widget _buildShiftBlock(TeachingShift shift) {
  final blockColor = _getSubjectColor(shift.subjectId);
  
  return Container(
    margin: EdgeInsets.all(4),
    padding: EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: blockColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: blockColor.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time range
        Text(
          '${_formatTime(shift.shiftStart)} - ${_formatTime(shift.shiftEnd)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: blockColor,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        // Subject/Role name
        Text(
          shift.subjectDisplayName ?? 'General',
          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
        ),
        // Students count (for teachers)
        if (shift.studentNames.isNotEmpty)
          Text(
            '${shift.studentNames.length} students',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
      ],
    ),
  );
}
```

---

## Phase 2: Leader Schedule Management

### 2.1 Concept

Leaders (admins, coordinators) have schedules that are different from teacher schedules:
- **No students assigned** (they manage, not teach)
- **Different role types**: Admin duties, Coordination, Meetings, etc.
- **Different tracking needs**: Project-based vs. class-based

### 2.2 Data Model Extension

```dart
// Add to TeachingShift model or create new LeaderShift
enum ShiftCategory {
  teaching,    // Teacher teaching students
  leadership,  // Leader/admin duties
  meeting,     // Meetings
  training,    // Training sessions
}

// Add field to TeachingShift
final ShiftCategory category;

// Firestore field: 'shift_category': 'teaching' | 'leadership' | 'meeting' | 'training'
```

### 2.3 Create Shift Dialog Enhancement

```dart
// Add category selector to CreateShiftDialog
Widget _buildCategorySelector() {
  return Row(
    children: [
      Text('Schedule Type:', style: labelStyle),
      SizedBox(width: 16),
      SegmentedButton<ShiftCategory>(
        segments: [
          ButtonSegment(
            value: ShiftCategory.teaching,
            label: Text('Teacher'),
            icon: Icon(Icons.school),
          ),
          ButtonSegment(
            value: ShiftCategory.leadership,
            label: Text('Leader'),
            icon: Icon(Icons.admin_panel_settings),
          ),
        ],
        selected: {_selectedCategory},
        onSelectionChanged: (selected) {
          setState(() {
            _selectedCategory = selected.first;
            // If leader selected, hide student selection
            // Show role selection instead
          });
        },
      ),
    ],
  );
}

// For Leaders: Show Role dropdown instead of Students
Widget _buildLeaderRoleSelector() {
  return DropdownButtonFormField<String>(
    decoration: InputDecoration(labelText: 'Role/Duty'),
    items: [
      DropdownMenuItem(value: 'admin', child: Text('Administration')),
      DropdownMenuItem(value: 'coordination', child: Text('Coordination')),
      DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
      DropdownMenuItem(value: 'training', child: Text('Staff Training')),
      DropdownMenuItem(value: 'planning', child: Text('Curriculum Planning')),
    ],
    onChanged: (value) => setState(() => _selectedRole = value),
  );
}
```

### 2.4 UI Separation in Grid

```dart
// Group users by role for grid display
List<UserGroup> _buildGroupedUserList() {
  final teachers = _users.where((u) => u.userType == 'teacher').toList();
  final leaders = _users.where((u) => 
    u.userType == 'admin' || u.isAdminTeacher == true
  ).toList();
  
  return [
    UserGroup(isHeader: true, title: 'TEACHERS', users: []),
    ...teachers.map((t) => UserGroup(isHeader: false, user: t)),
    UserGroup(isHeader: true, title: 'LEADERS', users: []),
    ...leaders.map((l) => UserGroup(isHeader: false, user: l)),
  ];
}

// Section header styling
Widget _buildSectionHeader(String title) {
  return Container(
    height: 40,
    color: Color(0xffF3F4F6),
    padding: EdgeInsets.symmetric(horizontal: 16),
    alignment: Alignment.centerLeft,
    child: Row(
      children: [
        Icon(
          title == 'TEACHERS' ? Icons.school : Icons.admin_panel_settings,
          size: 18,
          color: Color(0xff6B7280),
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xff6B7280),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}
```

---

## Phase 3: Enhanced Timesheet Export

### 3.1 ConnectTeam-Style Excel Structure

Based on the screenshots provided, the export should have these columns:

```
Sheet: "All Employees" (Summary view)
├── A: First name
├── B: Last name  
├── C: Scheduled shift title       ← NEW (from shift data)
├── D: Type                        ← e.g., "Stu - Mamadou Bobo - Teacher Name (1hr 2days weekly)"
├── E: Sub-job                     ← No sub-job / specific job category
├── F: Start Date                  ← e.g., "05/31/2025 Sat"
├── G: In                          ← Clock-in time e.g., "05:59 PM"
├── H: Start - device              ← "Mobile" or "Web"
├── I: End Date                    ← e.g., "05/31/2025 Sat"
├── J: Out                         ← Clock-out time e.g., "07:01 PM"
├── K: End - device                ← "Auto clocked out" / "Mobile" / "Web"
├── L: Employee notes              ← Notes from employee
├── M: Manager notes               ← Notes from admin
├── N: Shift hours                 ← e.g., "01:02"
├── O: Daily total hours           ← Sum for that day e.g., "03:04"
├── P: Daily scheduled             ← Scheduled hours e.g., "03:00"
├── Q: Daily difference            ← Difference e.g., "00:04" or "-00:01"
├── R: Weekly total hours          ← Sum for week e.g., "06:02"
├── S: Total paid time off hours   ← e.g., "24:11"
├── T: Total Paid Hours            ← e.g., "24:11"
├── U: Total scheduled             ← e.g., "30:00"
├── V: Total difference            ← e.g., "-05:49"
├── W: Total Regular               ← e.g., "24:11"
├── X: Total overtime              ← (if applicable)
├── Y: Total unpaid time off hours ← (if applicable)
```

### 3.2 Implementation

```dart
// In admin_timesheet_review.dart or new timesheet_export_service.dart

class ConnectTeamStyleExporter {
  static Future<void> exportTimesheets({
    required List<TimesheetEntry> entries,
    required DateTimeRange dateRange,
    required BuildContext context,
  }) async {
    // Group entries by employee
    final groupedByEmployee = _groupByEmployee(entries);
    
    // Prepare multi-sheet data
    final sheetsHeaders = <String, List<String>>{};
    final sheetsData = <String, List<List<dynamic>>>{};
    
    // Sheet 1: All Employees (Summary)
    sheetsHeaders['All Employees'] = [
      'First name', 'Last name', 'Scheduled shift title', 'Type',
      'Sub-job', 'Start Date', 'In', 'Start - device', 'End Date',
      'Out', 'End - device', 'Employee notes', 'Manager notes',
      'Shift hours', 'Daily total hours', 'Daily scheduled',
      'Daily difference', 'Weekly total hours', 'Total paid time off hours',
      'Total Paid Hours', 'Total scheduled', 'Total difference',
      'Total Regular', 'Total overtime', 'Total unpaid time off hours',
    ];
    
    final allEmployeesData = <List<dynamic>>[];
    
    for (final employeeGroup in groupedByEmployee.entries) {
      final employee = employeeGroup.key;
      final employeeEntries = employeeGroup.value;
      
      // Calculate aggregates
      final totals = _calculateEmployeeTotals(employeeEntries);
      
      for (final entry in employeeEntries) {
        allEmployeesData.add([
          employee.firstName,
          employee.lastName,
          entry.shiftTitle ?? '',  // ← Critical: Include shift title!
          entry.shiftType ?? '',   // e.g., "Stu - Student Name - Teacher (schedule)"
          entry.subJob ?? 'No sub-job',
          _formatDate(entry.startDate),
          _formatTime(entry.clockInTime),
          entry.clockInDevice ?? '',
          _formatDate(entry.endDate),
          _formatTime(entry.clockOutTime),
          entry.clockOutDevice ?? '',
          entry.employeeNotes ?? '',
          entry.managerNotes ?? '',
          _formatDuration(entry.shiftHours),
          _formatDuration(entry.dailyTotalHours),
          _formatDuration(entry.dailyScheduled),
          _formatDifference(entry.dailyDifference),
          _formatDuration(totals.weeklyTotal),
          _formatDuration(totals.paidTimeOff),
          _formatDuration(totals.totalPaidHours),
          _formatDuration(totals.totalScheduled),
          _formatDifference(totals.totalDifference),
          _formatDuration(totals.totalRegular),
          _formatDuration(totals.totalOvertime),
          _formatDuration(totals.unpaidTimeOff),
        ]);
      }
      
      // Add per-employee sheet
      sheetsHeaders[employee.fullName] = sheetsHeaders['All Employees']!;
      sheetsData[employee.fullName] = employeeEntries.map((e) => [
        // Same columns but only for this employee
      ]).toList();
    }
    
    sheetsData['All Employees'] = allEmployeesData;
    
    // Generate Excel file
    ExportHelpers.showExportDialog(
      context,
      sheetsHeaders,
      sheetsData,
      'timesheets_${DateFormat('yyyy-MM-dd').format(dateRange.start)}_to_${DateFormat('yyyy-MM-dd').format(dateRange.end)}',
    );
  }
  
  static String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
  
  static String _formatDifference(Duration d) {
    final isNegative = d.isNegative;
    final abs = d.abs();
    final hours = abs.inHours.toString().padLeft(2, '0');
    final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return '${isNegative ? '-' : ''}$hours:$minutes';
  }
}
```

### 3.3 Key Enhancement: Link Shift Title to Clock-In

The critical missing piece is **linking the scheduled shift title to clock-in records**.

```dart
// When creating timesheet entry from clock-in
Future<void> createTimesheetEntry(ClockInRecord clockIn) async {
  // Find the corresponding shift
  final shift = await _findShiftForClockIn(clockIn);
  
  return TimesheetEntry(
    userId: clockIn.userId,
    clockInTime: clockIn.clockInTime,
    clockOutTime: clockIn.clockOutTime,
    shiftId: shift?.id,
    
    // ← CRITICAL: Store shift title for export
    shiftTitle: shift?.displayName ?? 'Unscheduled',
    shiftType: _buildShiftTypeString(shift),
    
    clockInDevice: clockIn.device,
    clockOutDevice: clockIn.clockOutDevice,
  );
}

String _buildShiftTypeString(TeachingShift? shift) {
  if (shift == null) return 'Unscheduled';
  
  // Format: "Stu - Student Name - Teacher (schedule info)"
  final studentPart = shift.studentNames.isNotEmpty 
      ? 'Stu - ${shift.studentNames.first}' 
      : 'General';
  final teacherPart = shift.teacherName;
  final schedulePart = '${shift.shiftDurationHours.toStringAsFixed(0)}hr ${_getDaysInfo(shift)}';
  
  return '$studentPart - $teacherPart ($schedulePart)';
}
```

---

## Phase 4: Tasks Interface Redesign

### 4.1 New Layout Structure (ConnectTeam-Style)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ HEADER                                                                       │
│ ┌──────────────┐                                   ┌─────────┐ ┌───────────┐│
│ │ ☑ Quick Tasks│  Permissions 👤👤                 │◎ Labels │ │≡ Activity ││
│ └──────────────┘                                   └─────────┘ └───────────┘│
├─────────────────────────────────────────────────────────────────────────────┤
│ TABS                                                                         │
│ ┌────────────────────┐ ┌──────────────┐ ┌───────────────┐ ┌─────────────┐   │
│ │Tasks Created By Me │ │⚡ My Tasks   │ │ All Tasks (46)│ │ Archived (0)│   │
│ │        (7)         │ │     (31)     │ │               │ │             │   │
│ └────────────────────┘ └──────────────┘ └───────────────┘ └─────────────┘   │
├─────────────────────────────────────────────────────────────────────────────┤
│ TOOLBAR                                                                      │
│ ┌──────┐ ┌───────┐ ┌──────────────┐ ┌────┐ ┌───────────────┐ ┌────────────┐│
│ │≡ List│ │📅Dates│ │Group by      │ │ ≡  │ │ 05/27 to 06/24│ │Date created││
│ └──────┘ └───────┘ │Assigned to ▼ │ └────┘ └───────────────┘ └────────────┘│
│                    └──────────────┘                                         │
│                                      🔍 Search          ⓫ 11 overdue tasks  │
├─────────────────────────────────────────────────────────────────────────────┤
│ TASK LIST                                                                    │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │ ☐  × 👤 Chernor Diallo    ⟳ 1/2 Done    Status  Sub-tasks  Label  ...  │ │
│ ├─────────────────────────────────────────────────────────────────────────┤ │
│ │ 🟡│ Follow-up on potential clients    Open 💬¹    --    4/17 → 4/18    │ │
│ │   │                                                      (overdue)      │ │
│ ├─────────────────────────────────────────────────────────────────────────┤ │
│ │ ⊕ Add task                                                              │ │
│ ├─────────────────────────────────────────────────────────────────────────┤ │
│ │ ☐  × 👤 Mohammed Bah      ⟳ 0/4 Done                                   │ │
│ ├─────────────────────────────────────────────────────────────────────────┤ │
│ │ 🟡│ Report cards - end of semester   Open  --  Leadership  5/16 → 6/6  │ │
│ │ 🟡│ Market our Adlam program         Open  --  Promotion   5/16 → 6/8  │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Component Breakdown

#### A. Tab System

```dart
class _QuickTasksScreenState extends State<QuickTasksScreen>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }
  
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Color(0xff0386FF),
        unselectedLabelColor: Color(0xff6B7280),
        indicatorColor: Color(0xff0386FF),
        tabs: [
          _buildTab('Tasks Created By Me', _createdByMeCount),
          _buildTab('My Tasks', _myTasksCount),
          _buildTab('All Tasks', _allTasksCount),
          _buildTab('Archived', _archivedCount),
        ],
      ),
    );
  }
  
  Widget _buildTab(String title, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Color(0xff0386FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xff0386FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

#### B. View Toggle (List vs Dates/Calendar)

```dart
Widget _buildViewToggle() {
  return ToggleButtons(
    isSelected: [_viewMode == 'list', _viewMode == 'dates'],
    onPressed: (index) {
      setState(() => _viewMode = index == 0 ? 'list' : 'dates');
    },
    borderRadius: BorderRadius.circular(8),
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [Icon(Icons.list, size: 18), SizedBox(width: 4), Text('List')],
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [Icon(Icons.calendar_today, size: 18), SizedBox(width: 4), Text('Dates')],
        ),
      ),
    ],
  );
}
```

#### C. Grouped Task List (by Assignee)

```dart
Widget _buildGroupedTaskList(List<Task> tasks) {
  // Group tasks by assignee
  final grouped = <String, List<Task>>{};
  for (final task in tasks) {
    for (final assigneeId in task.assignedTo) {
      grouped.putIfAbsent(assigneeId, () => []).add(task);
    }
  }
  
  return ListView.builder(
    itemCount: grouped.length,
    itemBuilder: (context, index) {
      final assigneeId = grouped.keys.elementAt(index);
      final assigneeTasks = grouped[assigneeId]!;
      final completedCount = assigneeTasks.where((t) => t.status == TaskStatus.done).length;
      
      return _buildAssigneeGroup(
        assigneeId: assigneeId,
        tasks: assigneeTasks,
        completedCount: completedCount,
      );
    },
  );
}

Widget _buildAssigneeGroup({
  required String assigneeId,
  required List<Task> tasks,
  required int completedCount,
}) {
  return Column(
    children: [
      // Assignee Header
      Container(
        padding: EdgeInsets.all(16),
        color: Color(0xffF9FAFB),
        child: Row(
          children: [
            Checkbox(value: false, onChanged: null), // Multi-select
            SizedBox(width: 8),
            _buildUserAvatar(assigneeId),
            SizedBox(width: 12),
            FutureBuilder<String>(
              future: _getUserName(assigneeId),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? 'Loading...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                );
              },
            ),
            SizedBox(width: 16),
            // Progress indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xffE2E8F0)),
              ),
              child: Text(
                '⟳ $completedCount/${tasks.length} Done',
                style: TextStyle(fontSize: 12, color: Color(0xff6B7280)),
              ),
            ),
            Spacer(),
            // Table headers
            _buildTableHeader('Status', 80),
            _buildTableHeader('Sub-tasks', 80),
            _buildTableHeader('Label', 100),
            _buildTableHeader('Start date', 120),
            _buildTableHeader('Due date', 120),
          ],
        ),
      ),
      // Task rows
      ...tasks.map((task) => _buildTaskRow(task)),
      // Add task button
      _buildAddTaskRow(assigneeId),
    ],
  );
}
```

#### D. Overdue Tasks Badge

```dart
Widget _buildOverdueBadge(int count) {
  if (count == 0) return SizedBox.shrink();
  
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          'overdue tasks',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
```

---

## Technical Implementation Strategy

### Recommended Approach: Incremental Migration

Rather than rewriting everything at once, I recommend an **incremental approach**:

```
Phase 1: UI Polish (Week 1-2)
├── 1a. Compact header redesign
├── 1b. Move stats to collapsible section
├── 1c. Add schedule type filter (teacher/leader/all)
└── 1d. Improve mobile responsiveness

Phase 2: Grid View (Week 3-4)
├── 2a. Implement weekly grid component
├── 2b. Add shift blocks with color coding
├── 2c. Click-to-create on empty cells
└── 2d. Drag-and-drop shift moving

Phase 3: Leader Schedules (Week 5)
├── 3a. Add shift category to model
├── 3b. Update create dialog
├── 3c. Group grid by user type
└── 3d. Add leader-specific roles

Phase 4: Timesheet Export (Week 6)
├── 4a. Add shift title to clock-in records
├── 4b. Create ConnectTeam-style exporter
├── 4c. Add daily/weekly calculations
└── 4d. Multi-sheet Excel generation

Phase 5: Tasks Redesign (Week 7-8)
├── 5a. Add tab navigation
├── 5b. Implement list view
├── 5c. Add grouping by assignee
└── 5d. Add overdue badge
```

### Files to Modify/Create

| File | Action | Purpose |
|------|--------|---------|
| `lib/features/shift_management/screens/shift_management_screen.dart` | Modify | Compact header, add grid view |
| `lib/features/shift_management/widgets/weekly_schedule_grid.dart` | Create | New ConnectTeam-style grid |
| `lib/features/shift_management/widgets/compact_shift_header.dart` | Create | New compact header |
| `lib/features/shift_management/widgets/shift_block.dart` | Create | Color-coded shift block |
| `lib/core/models/teaching_shift.dart` | Modify | Add shift category |
| `lib/features/shift_management/widgets/create_shift_dialog.dart` | Modify | Add category selector |
| `lib/core/services/timesheet_export_service.dart` | Create | ConnectTeam-style export |
| `lib/features/tasks/screens/quick_tasks_screen.dart` | Modify | Tab navigation, list view |
| `lib/features/tasks/widgets/grouped_task_list.dart` | Create | Assignee-grouped list |

---

## UI/UX Design Guidelines

### Color Palette

```dart
// Primary Colors (keep existing)
const primaryBlue = Color(0xff0386FF);
const backgroundGrey = Color(0xffF8FAFC);

// Subject Colors (for shift blocks)
const Map<String, Color> subjectColors = {
  'quran': Color(0xff10B981),      // Green
  'hadith': Color(0xffF59E0B),     // Amber
  'fiqh': Color(0xff8B5CF6),       // Purple
  'arabic': Color(0xff3B82F6),     // Blue
  'history': Color(0xffEF4444),    // Red
  'aqeedah': Color(0xff06B6D4),    // Cyan
  'tafseer': Color(0xffEC4899),    // Pink
  'seerah': Color(0xffF97316),     // Orange
  'leadership': Color(0xff6366F1), // Indigo (for leader shifts)
  'admin': Color(0xff64748B),      // Slate (for admin duties)
};

// Status Colors
const Map<String, Color> statusColors = {
  'scheduled': Color(0xff3B82F6),  // Blue
  'active': Color(0xffF59E0B),     // Amber
  'completed': Color(0xff10B981),  // Green
  'missed': Color(0xffEF4444),     // Red
  'cancelled': Color(0xff6B7280),  // Gray
};

// Time-off Colors
const unavailableColor = Color(0xffFEE2E2);     // Light red
const vacationColor = Color(0xffFEF3C7);        // Light yellow
const sickLeaveColor = Color(0xffFCE7F3);       // Light pink
```

### Typography

```dart
// Keep existing Google Fonts Inter
// Title: 28px bold
// Subtitle: 16px regular
// Label: 14px semi-bold
// Body: 14px regular
// Caption: 12px regular
// Badge: 12px bold
```

### Spacing

```dart
// Standard spacing scale
const spacing4 = 4.0;
const spacing8 = 8.0;
const spacing12 = 12.0;
const spacing16 = 16.0;
const spacing20 = 20.0;
const spacing24 = 24.0;
const spacing32 = 32.0;

// Component heights
const headerHeight = 60.0;
const toolbarHeight = 50.0;
const rowHeight = 80.0;
const dayColumnWidth = 140.0;
const userColumnWidth = 200.0;
```

---

## Data Model Updates

### TeachingShift Extensions

```dart
// Add to TeachingShift class

// Shift category for teacher vs leader distinction
enum ShiftCategory { teaching, leadership, meeting, training }
final ShiftCategory category;

// Role for leader shifts (replaces students)
final String? leaderRole; // 'admin', 'coordination', 'meeting', etc.

// Firestore mapping
Map<String, dynamic> toFirestore() {
  return {
    // ... existing fields ...
    'shift_category': category.name,
    'leader_role': leaderRole,
  };
}
```

### Timesheet/ClockIn Extensions

```dart
// Add to time entry or timesheet model

// Link to scheduled shift for export
final String? shiftId;
final String? shiftTitle;       // Cached shift display name
final String? shiftType;        // Formatted type string
final String? clockInDevice;    // 'Mobile', 'Web', 'Kiosk'
final String? clockOutDevice;   // 'Mobile', 'Web', 'Auto clocked out'
final String? employeeNotes;    // Notes from employee
final String? managerNotes;     // Notes from admin
```

### Task Extensions (Optional)

```dart
// Add for better ConnectTeam parity

// Archive status
final bool isArchived;
final DateTime? archivedAt;

// Sub-tasks (if not already present)
final List<SubTask> subTasks;

class SubTask {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? completedAt;
}
```

---

## Priority & Timeline

### Critical Path (Must Have)

| Priority | Feature | Impact | Effort |
|----------|---------|--------|--------|
| P0 | Compact header redesign | High - Immediate UX improvement | Low |
| P0 | Shift title in timesheet export | High - Critical for tracking | Medium |
| P1 | Weekly grid view | High - Main UX improvement | High |
| P1 | Leader schedule support | Medium - New capability | Medium |
| P2 | Tasks tab navigation | Medium - Better organization | Medium |
| P2 | ConnectTeam-style export | Medium - Better reporting | Medium |

### Recommended Execution Order

```
Week 1: 🎯 Quick Wins
├── Compact header
├── Collapsible stats
└── Schedule type filter dropdown

Week 2: 📊 Export Enhancement
├── Add shiftTitle to clock-in records
├── Create ConnectTeam-style export
└── Add device tracking columns

Week 3-4: 📅 Grid View
├── Weekly grid component
├── Color-coded shift blocks
└── Click-to-create functionality

Week 5: 👥 Leader Schedules
├── Add category to model
├── Update create dialog
└── Group by user type in grid

Week 6-7: ✅ Tasks Redesign
├── Tab navigation
├── List view
├── Grouped by assignee
└── Overdue badge

Week 8: 🔧 Polish & Testing
├── Mobile responsiveness
├── Edge case handling
└── Performance optimization
```

---

## Success Metrics

After implementation, measure:

1. **Time to create shift** - Should decrease by 50%
2. **Time to find shift** - Should decrease with grid view
3. **Export accuracy** - All columns populated correctly
4. **User satisfaction** - Survey feedback
5. **Mobile usability** - Responsive design score

---

## Appendix: Screenshot Reference Analysis

### ConnectTeam Shift Grid Features Observed:
- ✅ Weekly calendar navigation
- ✅ Color-coded shift blocks by job type
- ✅ Time range display (10:30a - 7:30p)
- ✅ Location display (Skyfleet > Office)
- ✅ User conflict indicator (⚠️ User is unavailable)
- ✅ Published shifts indicator
- ✅ Day statistics (hours, shifts, users)
- ✅ "Shifts without users" row
- ✅ User search with count

### ConnectTeam Timesheet Export Features Observed:
- ✅ Employee name columns (First, Last)
- ✅ Scheduled shift title
- ✅ Type description (detailed)
- ✅ Device tracking (Mobile, Auto clocked out)
- ✅ Daily totals and scheduled comparison
- ✅ Weekly totals
- ✅ Difference columns (positive/negative)
- ✅ Multiple sheets per employee

### ConnectTeam Tasks Features Observed:
- ✅ Tab navigation with counts
- ✅ Grouping by assignee
- ✅ Progress indicator (X/Y Done)
- ✅ List view with columns
- ✅ Overdue counter badge (red circle)
- ✅ Label badges (Leadership, Promotion)
- ✅ Date range columns (Start → Due)
- ✅ Sub-tasks column
- ✅ Add task inline

---

*Document prepared for Alluvial Academy development team*
*Last updated: November 28, 2025*

