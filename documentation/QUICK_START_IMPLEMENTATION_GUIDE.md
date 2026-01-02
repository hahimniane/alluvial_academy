# Quick Start Implementation Guide
## Alluvial Academy - Priority Features

**Created:** November 28, 2025  
**Purpose:** Step-by-step guide for implementing priority features

---

## 🎯 Top 3 Priority Items

Based on your requirements, here are the **most critical** items to tackle first:

| # | Feature | Why Critical | Estimated Effort |
|---|---------|--------------|------------------|
| 1 | **Timesheet Export with Shift Title** | Can't track which classes were worked | 1-2 days |
| 2 | **Leader Schedule Support** | New capability needed immediately | 2-3 days |
| 3 | **Weekly Grid UI** | Current UI is cluttered | 3-5 days |

---

## 1️⃣ Priority 1: Timesheet Export Enhancement

### Problem
When you export timesheets, you don't see which scheduled shift the clock-in was for. The ConnectTeam export shows:
- "Scheduled shift title"
- "Type" (e.g., "Stu - Mamadou Bobo - Teacher (1hr 2days weekly)")

### Solution: Link Clock-In to Shift

#### Step 1: Update Clock-In Service

```dart
// In lib/core/services/clock_service.dart (or wherever clock-in happens)

Future<void> clockIn({
  required String userId,
  required String shiftId, // ← Ensure this is passed
}) async {
  // Get the shift details
  final shift = await ShiftService.getShiftById(shiftId);
  
  await FirebaseFirestore.instance.collection('time_entries').add({
    'user_id': userId,
    'shift_id': shiftId,
    'clock_in_time': FieldValue.serverTimestamp(),
    'clock_in_device': _getDeviceType(), // 'Mobile', 'Web'
    
    // ← NEW: Store shift info for export
    'shift_title': shift?.displayName ?? 'Unscheduled',
    'shift_type': _buildShiftTypeString(shift),
    'scheduled_start': shift?.shiftStart,
    'scheduled_end': shift?.shiftEnd,
    'scheduled_duration_minutes': shift?.scheduledDurationMinutes,
  });
}

String _buildShiftTypeString(TeachingShift? shift) {
  if (shift == null) return 'Unscheduled';
  
  final parts = <String>[];
  
  // Student info
  if (shift.studentNames.isNotEmpty) {
    parts.add('Stu - ${shift.studentNames.first}');
  }
  
  // Teacher info
  parts.add(shift.teacherName);
  
  // Schedule info
  final duration = shift.shiftDurationHours;
  final days = shift.enhancedRecurrence.frequency != 'none' 
      ? '${shift.enhancedRecurrence.interval}days weekly'
      : 'one-time';
  parts.add('(${duration.toStringAsFixed(0)}hr $days)');
  
  return parts.join(' - ');
}
```

#### Step 2: Update Export Function

```dart
// In lib/features/time_clock/screens/admin_timesheet_review.dart

void _exportTimesheetsConnectTeamStyle() {
  final headers = [
    'First name',
    'Last name',
    'Scheduled shift title',  // ← NEW
    'Type',                    // ← NEW
    'Sub-job',
    'Start Date',
    'In',
    'Start - device',         // ← NEW
    'End Date',
    'Out',
    'End - device',           // ← NEW
    'Employee notes',
    'Manager notes',
    'Shift hours',
    'Daily total hours',
    'Daily scheduled',
    'Daily difference',
    'Weekly total hours',
    'Total Paid Hours',
    'Total scheduled',
    'Total difference',
  ];
  
  final rows = _filteredTimesheets.map((entry) {
    return [
      entry.firstName,
      entry.lastName,
      entry.shiftTitle ?? '',           // ← From time_entry
      entry.shiftType ?? '',            // ← From time_entry
      'No sub-job',
      DateFormat('MM/dd/yyyy E').format(entry.startDate),
      DateFormat('hh:mm a').format(entry.clockInTime),
      entry.clockInDevice ?? 'Mobile',
      DateFormat('MM/dd/yyyy E').format(entry.endDate),
      DateFormat('hh:mm a').format(entry.clockOutTime),
      entry.clockOutDevice ?? 'Auto clocked out',
      entry.employeeNotes ?? '',
      entry.managerNotes ?? '',
      _formatDuration(entry.workedDuration),
      _formatDuration(entry.dailyTotal),
      _formatDuration(entry.dailyScheduled),
      _formatDifference(entry.dailyDifference),
      _formatDuration(entry.weeklyTotal),
      _formatDuration(entry.totalPaid),
      _formatDuration(entry.totalScheduled),
      _formatDifference(entry.totalDifference),
    ];
  }).toList();
  
  ExportHelpers.showExportDialog(context, headers, rows, 'timesheet_export');
}
```

---

## 2️⃣ Priority 2: Leader Schedule Support

### Problem
Currently, only teachers can have shifts. Leaders (admins, coordinators) also need schedules for:
- Administrative duties
- Meetings
- Coordination
- Training

### Solution: Add Shift Category

#### Step 1: Update Model

```dart
// In lib/core/models/teaching_shift.dart

enum ShiftCategory {
  teaching,    // Regular teacher-student class
  leadership,  // Admin/leader duties
  meeting,     // Scheduled meetings
  training,    // Staff training
}

class TeachingShift {
  // ... existing fields ...
  
  // NEW: Shift category
  final ShiftCategory category;
  
  // NEW: Role for leader shifts (replaces students for non-teaching)
  final String? leaderRole;
  
  TeachingShift({
    // ... existing params ...
    this.category = ShiftCategory.teaching,
    this.leaderRole,
  });
  
  // Update toFirestore()
  Map<String, dynamic> toFirestore() {
    return {
      // ... existing fields ...
      'shift_category': category.name,
      'leader_role': leaderRole,
    };
  }
  
  // Update fromFirestore()
  factory TeachingShift.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeachingShift(
      // ... existing fields ...
      category: ShiftCategory.values.firstWhere(
        (e) => e.name == data['shift_category'],
        orElse: () => ShiftCategory.teaching,
      ),
      leaderRole: data['leader_role'],
    );
  }
}
```

#### Step 2: Update Create Dialog

```dart
// In lib/features/shift_management/widgets/create_shift_dialog.dart

class _CreateShiftDialogState extends State<CreateShiftDialog> {
  ShiftCategory _selectedCategory = ShiftCategory.teaching;
  String? _selectedLeaderRole;
  
  // ... existing state ...
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        child: Column(
          children: [
            // ... existing header ...
            
            // NEW: Category selector at top
            _buildCategorySelector(),
            
            Divider(),
            
            // Show different fields based on category
            if (_selectedCategory == ShiftCategory.teaching)
              _buildTeacherFields()  // Existing: Teacher + Students
            else
              _buildLeaderFields(),  // NEW: Leader + Role
            
            // ... rest of form ...
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategorySelector() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Text('Schedule Type:', style: labelStyle),
          SizedBox(width: 16),
          SegmentedButton<ShiftCategory>(
            segments: [
              ButtonSegment(
                value: ShiftCategory.teaching,
                label: Text('Teacher Class'),
                icon: Icon(Icons.school),
              ),
              ButtonSegment(
                value: ShiftCategory.leadership,
                label: Text('Leader Duty'),
                icon: Icon(Icons.admin_panel_settings),
              ),
            ],
            selected: {_selectedCategory},
            onSelectionChanged: (selected) {
              setState(() {
                _selectedCategory = selected.first;
              });
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildLeaderFields() {
    return Column(
      children: [
        // Leader selector (same as teacher selector but show admins/admin-teachers)
        _buildLeaderSelector(),
        SizedBox(height: 16),
        // Role/duty type
        DropdownButtonFormField<String>(
          value: _selectedLeaderRole,
          decoration: InputDecoration(
            labelText: 'Duty Type',
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: 'admin', child: Text('Administration')),
            DropdownMenuItem(value: 'coordination', child: Text('Coordination')),
            DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
            DropdownMenuItem(value: 'training', child: Text('Staff Training')),
            DropdownMenuItem(value: 'planning', child: Text('Curriculum Planning')),
            DropdownMenuItem(value: 'outreach', child: Text('Community Outreach')),
          ],
          onChanged: (value) => setState(() => _selectedLeaderRole = value),
        ),
      ],
    );
  }
  
  Future<List<Employee>> _getLeaders() async {
    // Get admins and admin-teachers
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('is_active', isEqualTo: true)
        .get();
    
    return snapshot.docs
        .map((doc) => Employee.fromFirestore(doc))
        .where((e) => 
            e.userType == 'admin' || 
            (e.userType == 'teacher' && e.isAdminTeacher == true))
        .toList();
  }
}
```

#### Step 3: Update Grid View to Show Both

```dart
// In shift_management_screen.dart

Widget _buildUserList() {
  return StreamBuilder<List<Employee>>(
    stream: _getUsersStream(),
    builder: (context, snapshot) {
      final users = snapshot.data ?? [];
      
      // Separate teachers and leaders
      final teachers = users.where((u) => u.userType == 'teacher').toList();
      final leaders = users.where((u) => 
          u.userType == 'admin' || u.isAdminTeacher == true).toList();
      
      return ListView(
        children: [
          // Teachers section
          _buildSectionHeader('TEACHERS', Icons.school),
          ...teachers.map((t) => _buildUserRow(t)),
          
          // Leaders section
          _buildSectionHeader('LEADERS', Icons.admin_panel_settings),
          ...leaders.map((l) => _buildUserRow(l)),
        ],
      );
    },
  );
}

Widget _buildSectionHeader(String title, IconData icon) {
  return Container(
    height: 40,
    color: Color(0xffF3F4F6),
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Color(0xff6B7280)),
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

## 3️⃣ Priority 3: UI Cleanup - Compact Header

### Quick Win: Reduce Header Space

#### Before vs After

```
BEFORE (takes ~200px):
┌────────────────────────────────────────────────────────────────┐
│ [Icon] Shift Management                                        │
│ Manage Islamic education teaching shifts and schedules         │
│                                                                 │
│ [+ Create Shift] [⚙️] [Select] [Search Teacher...] [Delete...] │
│                                                                 │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                           │
│ │Total │ │Active│ │Today │ │Upcoming                          │
│ │ 245  │ │  12  │ │  8   │ │  45  │                           │
│ └──────┘ └──────┘ └──────┘ └──────┘                           │
└────────────────────────────────────────────────────────────────┘

AFTER (takes ~60px):
┌────────────────────────────────────────────────────────────────┐
│ 📅 Shifts │ < Aug 7-13 > │ [View▼] │ [Actions▼] │ [+ Add▼] │ 🔄│
└────────────────────────────────────────────────────────────────┘
```

#### Implementation

```dart
// Replace _buildHeader() in shift_management_screen.dart

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
        Icon(Icons.schedule, color: Color(0xff0386FF), size: 24),
        SizedBox(width: 12),
        Text(
          'Shifts',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xff111827),
          ),
        ),
        
        SizedBox(width: 24),
        
        // Week Navigator
        _buildWeekNavigator(),
        
        Spacer(),
        
        // View Options Dropdown
        _buildViewOptionsDropdown(),
        
        SizedBox(width: 12),
        
        // Actions Dropdown (Settings, Subjects, Pay, DST)
        _buildActionsDropdown(),
        
        SizedBox(width: 12),
        
        // Add Shift Button
        _buildAddShiftButton(),
        
        SizedBox(width: 12),
        
        // Refresh
        IconButton(
          onPressed: _refreshData,
          icon: Icon(Icons.refresh, color: Color(0xff6B7280)),
          tooltip: 'Refresh',
        ),
      ],
    ),
  );
}

Widget _buildWeekNavigator() {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Color(0xffE2E8F0)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _previousWeek,
          icon: Icon(Icons.chevron_left, size: 20),
          constraints: BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${DateFormat('MMM d').format(_weekStart)} - ${DateFormat('d').format(_weekEnd)}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
        ),
        IconButton(
          onPressed: _nextWeek,
          icon: Icon(Icons.chevron_right, size: 20),
          constraints: BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        IconButton(
          onPressed: () => _showDatePicker(),
          icon: Icon(Icons.calendar_today, size: 18),
          constraints: BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    ),
  );
}

Widget _buildViewOptionsDropdown() {
  return PopupMenuButton<String>(
    onSelected: _onViewOptionSelected,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xffE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('View options', style: GoogleFonts.inter(fontSize: 14)),
          SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    ),
    itemBuilder: (context) => [
      PopupMenuItem(value: 'grid', child: Text('Grid View')),
      PopupMenuItem(value: 'week', child: Text('Week Calendar')),
      PopupMenuItem(value: 'list', child: Text('List View')),
      PopupMenuDivider(),
      PopupMenuItem(value: 'teachers', child: Text('Teachers Only')),
      PopupMenuItem(value: 'leaders', child: Text('Leaders Only')),
      PopupMenuItem(value: 'all', child: Text('All Schedules')),
    ],
  );
}

Widget _buildActionsDropdown() {
  return PopupMenuButton<String>(
    onSelected: _onActionSelected,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xff0386FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Actions',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Color(0xff0386FF),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 20, color: Color(0xff0386FF)),
        ],
      ),
    ),
    itemBuilder: (context) => [
      PopupMenuItem(value: 'subjects', child: _menuItem(Icons.subject, 'Manage Subjects')),
      PopupMenuItem(value: 'pay', child: _menuItem(Icons.attach_money, 'Pay Settings')),
      PopupMenuItem(value: 'dst', child: _menuItem(Icons.access_time, 'DST Adjustment')),
      PopupMenuDivider(),
      PopupMenuItem(value: 'select', child: _menuItem(Icons.checklist, 'Bulk Select')),
      PopupMenuItem(value: 'delete_teacher', child: _menuItem(Icons.person_remove, 'Delete Teacher Shifts')),
    ],
  );
}

Widget _buildAddShiftButton() {
  return PopupMenuButton<String>(
    onSelected: _onAddSelected,
    child: ElevatedButton.icon(
      onPressed: null, // Handled by popup
      icon: Icon(Icons.add, size: 18),
      label: Text('Add'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xff0386FF),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    itemBuilder: (context) => [
      PopupMenuItem(value: 'teacher_shift', child: _menuItem(Icons.school, 'Teacher Shift')),
      PopupMenuItem(value: 'leader_shift', child: _menuItem(Icons.admin_panel_settings, 'Leader Shift')),
    ],
  );
}

Widget _menuItem(IconData icon, String text) {
  return Row(
    children: [
      Icon(icon, size: 18, color: Color(0xff6B7280)),
      SizedBox(width: 8),
      Text(text),
    ],
  );
}
```

---

## 📋 Implementation Checklist

### Phase 1: Export Enhancement (1-2 days)
- [ ] Add `shift_title` field to time_entries collection
- [ ] Add `shift_type` field to time_entries collection  
- [ ] Add `clock_in_device` field to time_entries
- [ ] Add `clock_out_device` field to time_entries
- [ ] Update clock-in service to populate new fields
- [ ] Update export function with new columns
- [ ] Test export with sample data

### Phase 2: Leader Schedules (2-3 days)
- [ ] Add `shift_category` enum to model
- [ ] Add `leader_role` field to model
- [ ] Update Firestore mapping
- [ ] Add category selector to create dialog
- [ ] Add leader role dropdown
- [ ] Update user list to separate teachers/leaders
- [ ] Test creating leader shifts

### Phase 3: UI Cleanup (1-2 days)
- [ ] Replace header with compact version
- [ ] Move actions to dropdown
- [ ] Add view options dropdown
- [ ] Add week navigator
- [ ] Remove stats cards (or make collapsible)
- [ ] Test responsive behavior

---

## 🚀 Getting Started

Run these commands to start implementation:

```bash
# Create a feature branch
git checkout -b feat/shift-management-redesign

# Make changes incrementally
# After each change:
flutter analyze
flutter test
git add .
git commit -m "feat: [description]"
```

Remember the build rule:
```bash
# For production releases
./increment_version.sh && flutter build web --release --pwa-strategy=none
```

---

*This guide focuses on the highest-impact, lowest-effort improvements first.*
