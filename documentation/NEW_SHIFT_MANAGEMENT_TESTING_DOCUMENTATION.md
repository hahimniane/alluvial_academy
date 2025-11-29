# New Shift Management System - Testing Documentation

## Overview
This document preserves all the work done on a new ConnectTeam-inspired shift management system that was being tested. The goal was to redesign the shift management UI and functionality to be more modern and feature-rich.

**Date Created:** November 28, 2025  
**Purpose:** Reference for future implementation of improved shift management UI

---

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Data Models](#data-models)
3. [Firebase Collections](#firebase-collections)
4. [Services](#services)
5. [UI Components](#ui-components)
6. [Cloud Functions](#cloud-functions)
7. [Color Scheme & UI Design](#color-scheme--ui-design)
8. [Features Implemented](#features-implemented)
9. [Files Created](#files-created)

---

## Architecture Overview

### Design Inspiration: ConnectTeam
The new system was inspired by ConnectTeam's shift management interface, featuring:
- **Grid-based weekly view** with teachers as rows and days as columns
- **Color-coded shifts** by subject or status
- **Activity logging** for all shift actions
- **Task/objective tracking** within shifts
- **Shift claiming/publishing** workflow
- **Real-time notifications** via FCM

### Key Differences from Current System
| Feature | Current System | New System |
|---------|----------------|------------|
| View Style | List view | Grid view (ConnectTeam style) |
| Status Workflow | Simple | Full workflow (scheduled → confirmed → active → completed) |
| Claiming | Not available | Teachers can claim published shifts |
| Tasks | Not available | Tasks/objectives per shift |
| Activity Log | Not available | Full audit trail |
| Notifications | Basic | Rich FCM notifications for all events |

---

## Data Models

### ShiftNew (`lib/core/models/shift_new.dart`)

```dart
/// Shift Status Enum
enum ShiftStatusNew {
  scheduled,    // Shift is scheduled, awaiting confirmation
  confirmed,    // Teacher confirmed the shift
  active,       // Shift is currently in progress (clocked in)
  completed,    // Shift completed successfully
  missed,       // Teacher didn't show up
  cancelled,    // Shift was cancelled
  published,    // Shift is available for teachers to claim
  claimed,      // A teacher claimed the shift (awaiting approval)
}

/// Status Colors
- scheduled: Colors.blue
- confirmed: Colors.green
- active: Colors.orange
- completed: Colors.teal
- missed: Colors.red
- cancelled: Colors.grey
- published: Colors.purple
- claimed: Colors.amber
```

#### Key Fields
```dart
// Time & Timezone
final DateTime startUtc;           // UTC start time
final DateTime endUtc;             // UTC end time
final String timezone;             // Timezone ID (e.g., 'America/New_York')
final double durationHours;        // Pre-calculated duration

// Teacher Info
final String assignedTo;           // Teacher User ID
final String? teacherName;         // Cached for display
final String? teacherTimezone;     // Teacher's local timezone

// Students
final List<String> studentIds;
final List<String> studentNames;   // Cached for display

// Subject/Job (with color coding)
final String? subjectId;
final String? subjectName;
final String? subjectColor;        // Hex color for visual coding

// Claim/Publish Feature
final bool isPublished;            // Available for teachers to claim
final bool allowClaiming;          // Enable claim feature
final bool requireApprovalForClaim;
final String? claimedBy;
final DateTime? claimedAt;
final String? originalTeacherId;   // Before claim

// Tasks/Objectives
final List<ShiftTask> tasks;

// Activity Log
final List<ShiftActivity> activityLog;
```

### ShiftTask
```dart
class ShiftTask {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedBy;
}
```

### ShiftActivity
```dart
class ShiftActivity {
  final String id;
  final ShiftActivityType type;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final String? note;
}

enum ShiftActivityType {
  created,
  edited,
  published,
  claimed,
  confirmed,
  rejected,
  clockedIn,
  clockedOut,
  taskCompleted,
  cancelled,
}
```

### SwapRequestNew (`lib/core/models/swap_request_new.dart`)
```dart
class SwapRequestNew {
  final String id;
  final String shiftId;
  final String requesterId;
  final List<String> candidates;
  final String? selectedCandidateId;
  final String status; // pending, accepted, rejected, cancelled
  final DateTime createdAtUtc;
  final DateTime? respondedAtUtc;
}
```

### TimeEntryNew (`lib/core/models/time_entry_new.dart`)
```dart
class TimeEntryNew {
  final String id;
  final String userId;
  final String shiftId;
  final DateTime? clockInUtc;
  final DateTime? clockOutUtc;
  final String? clockInDevice;
  final String? clockOutDevice;
  final String? location;
}
```

### UserNew (`lib/core/models/user_new.dart`)
```dart
class UserNew {
  final String id;
  final String firstName;
  final String lastName;
  final String role; // teacher, coach, admin
  final String timezone;
  final String email;
  final String phone;
  final bool isAdmin;
}
```

### JobOpportunity (`lib/core/models/job_opportunity.dart`)
```dart
class JobOpportunity {
  final String id;
  final String enrollmentId;
  final String studentName;
  final String studentAge;
  final String subject;
  final String gradeLevel;
  final List<String> days;
  final List<String> timeSlots;
  final String timeZone;
  final String status; // 'open', 'accepted', 'closed'
  final DateTime createdAt;
  final String? acceptedByTeacherId;
  final DateTime? acceptedAt;
}
```

---

## Firebase Collections

### Test Collections Created
| Collection Name | Purpose | Used By |
|-----------------|---------|---------|
| `shifts_new` | Main shift data for testing | ShiftServiceNew |
| `time_entries_new` | Clock in/out records | TimeEntryNew model |
| `users_new` | Optional test users (mostly used production `users`) | Export functions |
| `job_board` | Job opportunities for teachers | JobBoardService |
| `admin_notifications` | Notifications for job acceptance | JobBoardService |

### Firestore Field Mapping (shifts_new)
```javascript
{
  shift_template_id: String,
  shift_title: String,
  start_utc: Timestamp,
  end_utc: Timestamp,
  timezone: String,
  duration_hours: Number,
  assigned_to: String,          // Teacher UID
  teacher_name: String,
  teacher_timezone: String,
  student_ids: Array<String>,
  student_names: Array<String>,
  subject_id: String,
  subject_name: String,
  subject_color: String,        // Hex color
  created_by: String,
  created_at_utc: Timestamp,
  last_modified_utc: Timestamp,
  last_modified_by: String,
  zoom_link: String,
  notes: String,
  location: String,
  recurrence_rule: String,      // RRULE format
  recurrence_instance_index: Number,
  recurrence_end_date: Timestamp,
  recurrence_count: Number,
  status: String,               // One of ShiftStatusNew
  requires_confirmation: Boolean,
  confirmed_at: Timestamp,
  confirmed_by: String,
  clock_in_time: Timestamp,
  clock_out_time: Timestamp,
  clock_in_platform: String,
  is_published: Boolean,
  allow_claiming: Boolean,
  require_approval_for_claim: Boolean,
  claimed_by: String,
  claimed_at: Timestamp,
  original_teacher_id: String,
  original_teacher_name: String,
  tasks: Array<Map>,
  activity_log: Array<Map>,
  notification_sent: Boolean,
  custom_notification_message: String,
}
```

---

## Services

### ShiftServiceNew (`lib/core/services/shift_service_new.dart`)

#### Collection Name
```dart
static const String _collectionName = 'shifts_new';
```

#### Key Methods

**CRUD Operations:**
```dart
Future<String> createShift(ShiftNew shift)
Future<String> createShiftAuto({...}) // With auto-generated ID
Stream<List<ShiftNew>> getAllShifts(DateTime start, DateTime end)
Stream<List<ShiftNew>> getShiftsForTeacher(String teacherId, DateTime start, DateTime end)
Future<ShiftNew?> getShiftById(String shiftId)
Stream<List<ShiftNew>> getPublishedShifts()
Future<void> updateShift(ShiftNew shift)
Future<void> updateShiftStatus(String shiftId, ShiftStatusNew status)
Future<void> deleteShift(String shiftId)
Future<void> deleteMultipleShifts(List<String> shiftIds)
```

**Clock In/Out (ConnectTeam style):**
```dart
Future<bool> clockIn(String shiftId, {String? platform})
Future<bool> clockOut(String shiftId)
```

**Confirm/Reject:**
```dart
Future<bool> confirmShift(String shiftId)
Future<bool> rejectShift(String shiftId, {String? reason})
```

**Claim/Publish:**
```dart
Future<bool> publishShift(String shiftId, {String? customMessage})
Future<bool> claimShift(String shiftId, {String? note})
Future<bool> approveClaimedShift(String shiftId)
```

**Tasks:**
```dart
Future<bool> completeTask(String shiftId, String taskId)
```

**Helpers:**
```dart
Future<List<Employee>> getAvailableTeachers()
Future<List<Employee>> getAvailableStudents()
Future<Map<String, dynamic>?> getUserDetails(String userId)
Future<Map<String, dynamic>> getShiftStatistics()
```

### JobBoardService (`lib/core/services/job_board_service.dart`)

```dart
Future<void> broadcastEnrollment(EnrollmentRequest enrollment)
Future<void> acceptJob(String jobId, String teacherId)
Stream<List<JobOpportunity>> getOpenJobs()
Stream<List<JobOpportunity>> getAllJobs()
Stream<List<JobOpportunity>> getAcceptedJobs()
```

---

## UI Components

### Screen: ShiftListScreenNew
**Path:** `lib/features/shift_management_new/screens/shift_list_screen_new.dart`

**Features:**
- Statistics cards row (Total, Scheduled, Confirmed, Active, Completed, Published, Today)
- Date navigation (Previous/Next, Today button)
- View mode tabs (Day, Week, Month)
- Display mode toggle (Grid vs List view)
- Floating Action Button for new shift
- Published/Open shifts bottom sheet

**State Variables:**
```dart
DateTime _selectedDate = DateTime.now();
String _viewMode = 'week'; // 'day', 'week', 'month'
String _displayMode = 'grid'; // 'grid' or 'list'
Map<String, dynamic> _statistics = {};
List<Employee> _teachers = [];
```

### Widget: ScheduleGridView
**Path:** `lib/features/shift_management_new/widgets/schedule_grid_view.dart`

**ConnectTeam-style Grid Features:**
- Teachers as rows, days as columns
- Search/filter teachers
- Header row with day statistics
- "Shifts without users" row for unassigned shifts
- Teacher avatar with initials
- Color-coded shift blocks
- Click cell to create shift for that teacher/date
- Click shift to view/edit details

**Grid Cell Design:**
```dart
// Shift Block
Container(
  margin: const EdgeInsets.only(bottom: 4),
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    color: blockColor.withOpacity(0.15),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: blockColor.withOpacity(0.3)),
  ),
  // Contains: Status indicator dot, Subject name, Time range, Students
)
```

### Widget: ShiftCardNew
**Path:** `lib/features/shift_management_new/widgets/shift_card_new.dart`

**Features:**
- Color bar at top (subject/status color)
- Status badge
- Time display with timezone
- Teacher info
- Students list
- Subject info
- Zoom link indicator
- Notes section
- Task progress bar
- Action buttons (Clock In/Out, Confirm/Reject, Claim, Publish, Edit, Delete)

**Action Buttons Shown Based on State:**
- `canClockIn` → Clock In button
- `canClockOut` → Clock Out button
- `status == scheduled && requiresConfirmation` → Confirm/Reject buttons
- `isClaimable` → Claim button
- `status == claimed` (Admin) → Approve button
- `status == scheduled/confirmed` (Admin) → Publish button
- Always (Admin) → Edit, Delete buttons

### Widget: CreateShiftDialogNew
**Path:** `lib/features/shift_management_new/widgets/create_shift_dialog_new.dart`

**Form Fields:**
- Shift Title (text)
- Teacher Selection (searchable list with avatars)
- Student Selection (multi-select with checkboxes)
- Subject Selection (dropdown)
- Date picker
- Timezone dropdown
- Start/End time pickers
- Recurrence (None, Daily, Weekly) with count
- Notes (multiline text)

**Pre-population Support:**
```dart
final ShiftNew? shiftToEdit;
final DateTime? preSelectedDate;
final String? preSelectedTeacherId;
```

---

## Cloud Functions

### File: `functions/new_implementation.js`

#### onShiftCreateNew
**Trigger:** `shifts_new/{shiftId}` document created

**Actions:**
1. Send FCM notification to assigned teacher
2. Generate recurrence instances if RRULE present

**Recurrence Generation:**
- Uses `rrule` library for RRULE parsing
- Uses `luxon` for timezone-aware date calculations
- Generates up to 6 months of occurrences
- Handles batch writes (400 per batch)
- Properly handles DST transitions

#### onShiftUpdateNew
**Trigger:** `shifts_new/{shiftId}` document updated

**Notifications Sent For:**
| Status | Title | Icon |
|--------|-------|------|
| confirmed | Shift Confirmed | ✅ |
| cancelled | Shift Cancelled | ❌ |
| claimed | Shift Claimed | 🙋 |
| published | Shift Available | 📢 |
| completed | Shift Completed | ✅ |
| missed | Shift Missed | ⚠️ |

**Also notifies for:**
- Time changes
- Student changes
- Subject changes

#### exportTimesheet
**Type:** Callable function

**Params:**
```javascript
{
  startDate: ISOString,
  endDate: ISOString,
  timeZone: String
}
```

**Excel Columns Generated:**
- Employee ID, First Name, Last Name, Role
- Shift ID, Shift Title
- Start UTC, End UTC, Timezone
- Start Local, End Local
- Duration (Hrs)
- Clock In UTC, Clock Out UTC
- Clock In Device, Clock Out Device
- Clock In Location
- Notes, Zoom Link
- Created By, Created At UTC
- Recurrence Rule, Instance Index
- Status

---

## Color Scheme & UI Design

### Primary Colors
```dart
const Color primaryBlue = Color(0xff0386FF);
const Color backgroundGrey = Color(0xffF8FAFC);
const Color textDark = Color(0xff111827);
const Color textMedium = Color(0xff374151);
const Color textLight = Color(0xff6B7280);
const Color borderGrey = Color(0xffE2E8F0);
```

### Subject Colors (Hex)
```dart
'quran_studies': '#10B981',    // Green
'hadith_studies': '#F59E0B',   // Amber
'fiqh': '#8B5CF6',             // Purple
'arabic_language': '#3B82F6',  // Blue
'islamic_history': '#EF4444',  // Red
'aqeedah': '#06B6D4',          // Cyan
'tafseer': '#EC4899',          // Pink
'seerah': '#F97316',           // Orange
'default': '#0386FF',          // Primary Blue
```

### Status Colors
```dart
scheduled: Colors.blue
confirmed: Colors.green
active: Colors.orange
completed: Colors.teal
missed: Colors.red
cancelled: Colors.grey
published: Colors.purple
claimed: Colors.amber
```

### UI Patterns

**Statistics Card:**
```dart
Container(
  margin: const EdgeInsets.only(right: 12),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: color.withOpacity(0.1),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: color.withOpacity(0.3)),
  ),
)
```

**Status Badge:**
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: statusColor.withOpacity(0.15),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: statusColor.withOpacity(0.3)),
  ),
)
```

**View Mode Button (Selected):**
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
  decoration: BoxDecoration(
    color: const Color(0xff0386FF),
    borderRadius: BorderRadius.circular(8),
  ),
)
```

**Avatar Colors (Based on Name):**
```dart
final colors = [
  Colors.blue, Colors.green, Colors.orange, Colors.purple,
  Colors.teal, Colors.pink, Colors.indigo, Colors.cyan,
];
return colors[name.codeUnitAt(0) % colors.length];
```

---

## Features Implemented

### Completed
- [x] ShiftNew model with all fields
- [x] ShiftServiceNew with CRUD operations
- [x] Grid view (ConnectTeam style)
- [x] List view alternative
- [x] Shift card with actions
- [x] Create shift dialog
- [x] Teacher/Student searchable selection
- [x] Clock in/out functionality
- [x] Confirm/Reject workflow
- [x] Publish/Claim workflow
- [x] Task completion tracking
- [x] Activity logging
- [x] FCM notifications (Cloud Functions)
- [x] Recurrence generation (Cloud Functions)
- [x] Timesheet export (Cloud Functions)
- [x] Statistics dashboard
- [x] Date navigation
- [x] View mode switching

### Partially Completed
- [ ] Edit shift dialog (stub only)
- [ ] Swap request workflow
- [ ] Time entry detailed management

### Not Started
- [ ] Mobile-optimized views
- [ ] Offline support
- [ ] Bulk shift operations
- [ ] Shift templates

---

## Files Created

### Models
- `lib/core/models/shift_new.dart`
- `lib/core/models/swap_request_new.dart`
- `lib/core/models/time_entry_new.dart`
- `lib/core/models/user_new.dart`
- `lib/core/models/job_opportunity.dart`

### Services
- `lib/core/services/shift_service_new.dart`
- `lib/core/services/job_board_service.dart`

### Screens
- `lib/features/shift_management_new/screens/shift_list_screen_new.dart`
- `lib/features/dashboard/screens/teacher_job_board_screen.dart`
- `lib/features/enrollment_management/screens/filled_opportunities_screen.dart`

### Widgets
- `lib/features/shift_management_new/widgets/create_shift_dialog_new.dart`
- `lib/features/shift_management_new/widgets/shift_card_new.dart`
- `lib/features/shift_management_new/widgets/schedule_grid_view.dart`

### Cloud Functions
- `functions/new_implementation.js`

### Documentation
- `documentation/NEW_SYSTEM_INSTRUCTIONS.md`
- `specifications.txt`

---

## How to Reuse This Work

### To Apply the Grid View to Existing System:
1. Study `schedule_grid_view.dart` for the grid layout pattern
2. Apply the color coding scheme to existing shift cards
3. Implement the statistics row at the top

### To Apply Status Workflow:
1. Add new status values to existing shift model
2. Implement confirm/reject/publish/claim methods
3. Update UI to show appropriate action buttons

### To Apply UI Styling:
1. Use the color scheme defined above
2. Apply the statistics card pattern
3. Use the status badge pattern
4. Apply the subject color coding

### To Enable Notifications:
1. Deploy `onShiftCreateNew` and `onShiftUpdateNew` cloud functions
2. Ensure FCM tokens are stored in user documents
3. Update triggers to use production collection names

---

## Important Notes

1. **Test Collection**: All data was stored in `shifts_new` collection, not production `teaching_shifts`
2. **Production Users**: The system used production `users` collection for teacher/student data
3. **Timezone Handling**: Proper UTC storage with timezone-aware display conversions
4. **Activity Logging**: All actions create activity log entries for audit trail
5. **Recurrence**: Uses RRULE format compatible with RFC 5545

---

## Cleanup Required

### Firebase Collections to Delete (if testing data no longer needed):
- `shifts_new`
- `time_entries_new`
- `users_new` (if created)
- `swap_requests_new` (if created)

### Note
The `job_board` and `admin_notifications` collections may be kept if the job board feature is desired.

---

*Documentation created: November 28, 2025*
*Purpose: Preserve testing work for future reference when improving shift management UI*

