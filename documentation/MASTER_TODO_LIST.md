# Master To-Do List
## Alluvial Academy - Complete Implementation Roadmap

**Created:** November 28, 2025  
**Total Estimated Time:** 4-6 weeks  
**Priority:** High

---

## 📊 Summary of Work

| Phase | Description | Effort | Status |
|-------|-------------|--------|--------|
| Phase 0 | Database Preparation | 1 day | ⏳ Pending |
| Phase 1 | Timesheet Export Enhancement | 2-3 days | ⏳ Pending |
| Phase 2 | Leader Schedule Support | 3-4 days | ⏳ Pending |
| Phase 3 | Shift UI Redesign | 5-7 days | ⏳ Pending |
| Phase 4 | Tasks UI Redesign | 3-4 days | ⏳ Pending |
| Phase 5 | Testing & Polish | 2-3 days | ⏳ Pending |

---

## Phase 0: Database Preparation (Day 1)

### 0.1 Review & Backup
- [ ] **0.1.1** Export current `teaching_shifts` collection as backup
- [ ] **0.1.2** Export current `timesheet_entries` collection as backup
- [ ] **0.1.3** Export current `tasks` collection as backup
- [ ] **0.1.4** Review current Firestore security rules

### 0.2 Data Model Updates (Flutter Code)
- [ ] **0.2.1** Add `shiftCategory` enum to `lib/core/enums/shift_enums.dart`
  ```dart
  enum ShiftCategory { teaching, leadership, meeting, training }
  ```
- [ ] **0.2.2** Update `TeachingShift` model in `lib/core/models/teaching_shift.dart`
  - Add `category` field (ShiftCategory)
  - Add `leaderRole` field (String?)
  - Update `toFirestore()` method
  - Update `fromFirestore()` factory
  - Update `copyWith()` method
- [ ] **0.2.3** Update `TimesheetEntry` model in `lib/features/time_clock/models/timesheet_entry.dart`
  - Add `shiftTitle` field (String?)
  - Add `shiftType` field (String?)
  - Add `clockOutPlatform` field (String?)
  - Add `scheduledStart` field (DateTime?)
  - Add `scheduledEnd` field (DateTime?)
  - Add `scheduledDurationMinutes` field (int?)
  - Add `employeeNotes` field (String?)
  - Add `managerNotes` field (String?)
- [ ] **0.2.4** Update `Task` model in `lib/features/tasks/models/task.dart`
  - Add `isArchived` field (bool)
  - Add `archivedAt` field (Timestamp?)
  - Add `startDate` field (DateTime?)
  - Update `toFirestore()` method
  - Update `fromFirestore()` factory

### 0.3 Optional: Create Firestore Indexes
- [ ] **0.3.1** Create index: `teaching_shifts` (shift_category ASC, shift_start ASC)
- [ ] **0.3.2** Create index: `tasks` (isArchived ASC, createdAt DESC)

---

## Phase 1: Timesheet Export Enhancement (Days 2-4)

### 1.1 Update Clock-In Service
- [ ] **1.1.1** Modify `ShiftTimesheetService.createTimesheetEntry()` in `lib/core/services/shift_timesheet_service.dart`
  - Add `shift_title` from shift.displayName
  - Add `shift_type` formatted string
  - Add `scheduled_start` from shift.shiftStart
  - Add `scheduled_end` from shift.shiftEnd
  - Add `scheduled_duration_minutes` from shift

### 1.2 Update Clock-Out Service
- [ ] **1.2.1** Modify clock-out in `ShiftTimesheetService`
  - Add `clock_out_platform` parameter
  - Store platform used for clock-out

### 1.3 Create ConnectTeam-Style Export
- [ ] **1.3.1** Create new file `lib/core/services/connectteam_export_service.dart`
  - Implement all columns from ConnectTeam format
  - Calculate daily totals
  - Calculate weekly totals
  - Calculate differences (scheduled vs actual)
  - Generate multi-sheet Excel
- [ ] **1.3.2** Update `AdminTimesheetReview` screen in `lib/features/time_clock/screens/admin_timesheet_review.dart`
  - Add "Export (ConnectTeam Style)" button
  - Call new export service

### 1.4 Add Notes Fields
- [ ] **1.4.1** Add employee notes field to timesheet entry UI
- [ ] **1.4.2** Add manager notes field (admin only) to timesheet review UI

### 1.5 Testing
- [ ] **1.5.1** Test clock-in captures all new fields
- [ ] **1.5.2** Test clock-out captures platform
- [ ] **1.5.3** Test export generates correct columns
- [ ] **1.5.4** Verify calculations are correct

---

## Phase 2: Leader Schedule Support (Days 5-8)

### 2.1 Update Create Shift Dialog
- [ ] **2.1.1** Modify `CreateShiftDialog` in `lib/features/shift_management/widgets/create_shift_dialog.dart`
  - Add category selector (Teacher/Leader toggle)
  - Show/hide student selection based on category
  - Add leader role dropdown (for leader shifts)
  - Update form validation

### 2.2 Update Shift Service
- [ ] **2.2.1** Modify `ShiftService.createShift()` in `lib/core/services/shift_service.dart`
  - Accept `category` parameter
  - Accept `leaderRole` parameter
  - Validate leader shifts don't require students
  - Save new fields to Firestore

### 2.3 Update Shift List/Grid Display
- [ ] **2.3.1** Modify shift display to show category icon
- [ ] **2.3.2** Add section headers (TEACHERS / LEADERS) in grid view
- [ ] **2.3.3** Update shift card to display role for leader shifts

### 2.4 Update User Queries
- [ ] **2.4.1** Create `getAvailableLeaders()` method in `ShiftService`
  - Query users where `user_type == 'admin'` OR `is_admin_teacher == true`
- [ ] **2.4.2** Use leader query in create shift dialog

### 2.5 Testing
- [ ] **2.5.1** Test creating teacher shift (existing functionality)
- [ ] **2.5.2** Test creating leader shift (new functionality)
- [ ] **2.5.3** Test editing shifts
- [ ] **2.5.4** Test shift display in grid/list

---

## Phase 3: Shift UI Redesign (Days 9-15)

### 3.1 Compact Header
- [ ] **3.1.1** Create `CompactShiftHeader` widget in `lib/features/shift_management/widgets/compact_shift_header.dart`
  - Week navigation (< Aug 7-13 >)
  - View options dropdown
  - Actions dropdown (Settings, Subjects, Pay, DST)
  - Add shift button with dropdown (Teacher/Leader)

### 3.2 Weekly Grid View
- [ ] **3.2.1** Create `WeeklyScheduleGrid` widget in `lib/features/shift_management/widgets/weekly_schedule_grid.dart`
  - Day columns with statistics
  - User rows grouped by type (Teachers/Leaders)
  - Search/filter users
  - Empty cell click to create shift

### 3.3 Shift Block Component
- [ ] **3.3.1** Create `ShiftBlock` widget in `lib/features/shift_management/widgets/shift_block.dart`
  - Color-coded by subject
  - Time range display
  - Subject/role name
  - Student count (for teachers)
  - Click to view/edit

### 3.4 Update Main Screen
- [ ] **3.4.1** Refactor `ShiftManagementScreen` in `lib/features/shift_management/screens/shift_management_screen.dart`
  - Replace header with compact header
  - Add view mode toggle (Grid/Week/List)
  - Integrate weekly grid view
  - Move stats to collapsible section
  - Add schedule type filter (All/Teachers/Leaders)

### 3.5 Subject Colors
- [ ] **3.5.1** Create color constants for subjects in `lib/core/constants/shift_colors.dart`
- [ ] **3.5.2** Apply colors to shift blocks

### 3.6 Mobile Responsiveness
- [ ] **3.6.1** Ensure grid view works on smaller screens
- [ ] **3.6.2** Add horizontal scroll for narrow viewports

### 3.7 Testing
- [ ] **3.7.1** Test all view modes (Grid/Week/List)
- [ ] **3.7.2** Test filtering by schedule type
- [ ] **3.7.3** Test click to create shift
- [ ] **3.7.4** Test responsive behavior

---

## Phase 4: Tasks UI Redesign (Days 16-19)

### 4.1 Tab Navigation
- [ ] **4.1.1** Add TabController to `QuickTasksScreen` in `lib/features/tasks/screens/quick_tasks_screen.dart`
- [ ] **4.1.2** Create tabs: "Created By Me", "My Tasks", "All Tasks", "Archived"
- [ ] **4.1.3** Add task count badges to each tab
- [ ] **4.1.4** Filter tasks based on selected tab

### 4.2 View Toggle
- [ ] **4.2.1** Add view toggle (List / Dates)
- [ ] **4.2.2** Implement list view layout (table-like)

### 4.3 Grouped List View
- [ ] **4.3.1** Create `GroupedTaskList` widget in `lib/features/tasks/widgets/grouped_task_list.dart`
  - Group by assignee
  - Show progress indicator (X/Y Done)
  - Collapsible groups
  - Table headers (Status, Sub-tasks, Label, Start date, Due date)

### 4.4 Overdue Badge
- [ ] **4.4.1** Create `OverdueBadge` widget
- [ ] **4.4.2** Add overdue count to toolbar
- [ ] **4.4.3** Style with red background and count

### 4.5 Archive Functionality
- [ ] **4.5.1** Update `TaskService` to support archiving
- [ ] **4.5.2** Add archive action to task menu
- [ ] **4.5.3** Filter archived tasks in query

### 4.6 Start Date Field
- [ ] **4.6.1** Add start date picker to `AddEditTaskDialog`
- [ ] **4.6.2** Display start date in list view

### 4.7 Testing
- [ ] **4.7.1** Test all tabs show correct tasks
- [ ] **4.7.2** Test view toggle (List/Grid)
- [ ] **4.7.3** Test grouping by assignee
- [ ] **4.7.4** Test archive functionality
- [ ] **4.7.5** Test overdue badge count

---

## Phase 5: Testing & Polish (Days 20-22)

### 5.1 Integration Testing
- [ ] **5.1.1** Test complete shift creation flow (teacher)
- [ ] **5.1.2** Test complete shift creation flow (leader)
- [ ] **5.1.3** Test clock-in → clock-out → export flow
- [ ] **5.1.4** Test task creation → assignment → completion flow

### 5.2 Data Validation
- [ ] **5.2.1** Verify all new fields are saved correctly
- [ ] **5.2.2** Verify export contains all required columns
- [ ] **5.2.3** Verify calculations are accurate

### 5.3 UI Polish
- [ ] **5.3.1** Fix any responsive layout issues
- [ ] **5.3.2** Ensure consistent styling
- [ ] **5.3.3** Add loading states where needed
- [ ] **5.3.4** Add error handling

### 5.4 Performance
- [ ] **5.4.1** Test with large data sets
- [ ] **5.4.2** Optimize queries if needed
- [ ] **5.4.3** Add pagination if needed

### 5.5 Documentation
- [ ] **5.5.1** Update user documentation
- [ ] **5.5.2** Document new features for admin training

---

## 🚀 Deployment Checklist

Before deploying to production:

- [ ] All tests pass
- [ ] Code reviewed
- [ ] Database backups completed
- [ ] Version number incremented (`./increment_version.sh`)
- [ ] Build successful (`flutter build web --release`)
- [ ] Upload `build/web/` to Hostinger
- [ ] Verify deployment works
- [ ] Monitor for errors

---

## 📁 Files to Create

| File Path | Purpose |
|-----------|---------|
| `lib/core/constants/shift_colors.dart` | Subject/status color constants |
| `lib/core/services/connectteam_export_service.dart` | ConnectTeam-style export |
| `lib/features/shift_management/widgets/compact_shift_header.dart` | Compact header |
| `lib/features/shift_management/widgets/weekly_schedule_grid.dart` | Weekly grid view |
| `lib/features/shift_management/widgets/shift_block.dart` | Shift block component |
| `lib/features/tasks/widgets/grouped_task_list.dart` | Grouped task list |

---

## 📁 Files to Modify

| File Path | Changes |
|-----------|---------|
| `lib/core/enums/shift_enums.dart` | Add ShiftCategory enum |
| `lib/core/models/teaching_shift.dart` | Add category, leaderRole fields |
| `lib/features/time_clock/models/timesheet_entry.dart` | Add export fields |
| `lib/features/tasks/models/task.dart` | Add archive, startDate fields |
| `lib/core/services/shift_service.dart` | Support category, getAvailableLeaders |
| `lib/core/services/shift_timesheet_service.dart` | Capture shift details for export |
| `lib/features/shift_management/widgets/create_shift_dialog.dart` | Add category selector |
| `lib/features/shift_management/screens/shift_management_screen.dart` | New header, grid view |
| `lib/features/time_clock/screens/admin_timesheet_review.dart` | New export button |
| `lib/features/tasks/screens/quick_tasks_screen.dart` | Tabs, list view |
| `lib/features/tasks/services/task_service.dart` | Archive support |

---

## 🎯 Quick Start: What to Do First

1. **Review DATABASE_MODIFICATIONS_REQUIRED.md** - Understand all database changes
2. **Update data models** (Phase 0.2) - No database migration needed yet
3. **Update clock-in service** (Phase 1.1) - New records will have all fields
4. **Create export service** (Phase 1.3) - Get exports working first

This order allows you to:
- See immediate value from exports
- No risk to existing data
- Incremental improvements

---

## ❓ Questions to Answer

1. Do you want to backfill existing timesheet entries with shift titles?
2. What specific leader roles do you need? (I listed some defaults)
3. Do you want the Tasks "Archived" feature or is that optional?
4. Any specific date format preferences for exports?

---

*This is the master to-do list. Check off items as you complete them.*

