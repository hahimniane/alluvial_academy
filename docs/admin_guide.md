# Alluwal Education Hub – Administrator Guide (v1.0)

> Generated from live codebase; covers features available to users with the `admin` role (`UserRoleService.getAvailableFeatures('admin')`).

---

## 1. Logging In
1. Navigate to the web URL.
2. Sign in with your administrator credentials.
3. A gray **Administrator** badge appears top-right after login.

---

## 2. Main Navigation
Admins have access to seven features:

| Menu Label | Material Icon | Module |
|------------|---------------|---------|
| Dashboard | `Icons.dashboard` | Overall statistics & quick actions |
| User Management | `Icons.people` | Create / edit / deactivate users |
| Shift Management | `Icons.schedule` | Create, monitor & edit teaching shifts |
| Chat | `Icons.chat` | School-wide messaging (all rooms) |
| Time Clock Review | `Icons.access_time` | Approve / reject teacher timesheets (`AdminTimesheetReview`) |
| Forms / Form Builder | `Icons.description` / builder icon | Publish forms and collect responses |
| Tasks | `Icons.check_box` | Assign tasks to staff / students |
| Reports | `Icons.bar_chart` | Export CSV / PDF datasets |

The sidebar auto-collapses — preference saved in `SharedPreferences` (`sidebar_collapsed`).

---

## 3. User Management
Implemented in `features/user_management`.

1. **User List Screen** – Search and filter by role/status.
2. **Add User Screen** – Fields: name, e-mail, role, hourly rate, timezone.
3. **Edit User** – Click the **edit** pencil; toggle **Active** to deactivate.

Data source: Firestore collection `users`.

---

## 4. Shift Management
Screens under `features/shift_management`.

### 4.1 Create Shift
1. Click **Shift Management** → **Create Shift**.
2. Select teacher, students (multi-select), subject, date/time.
3. Optional recurrence (daily / weekly / monthly) – handled by `ShiftService._createRecurringShifts`.
4. Save → Notifications go to teacher & students.

### 4.2 Monitor Shifts
* Tabs: **Scheduled**, **Active**, **Completed**, **Missed**.
* “Auto-Logout Pending” tag appears for shifts stuck active after deadline.

### 4.3 Manual Overrides
From shift detail dialog:
* **Force Clock-Out** – calls `ShiftService.clockOut`.
* **Mark Completed / Cancelled** – updates status.

---

## 5. Time Clock Review
Located at `features/time_clock/screens/admin_timesheet_review.dart`.

1. Filter by teacher & date range.
2. Review each entry → Approve (locks record) or Reject (sends back to teacher).
3. Export table to CSV/PDF.

---

## 6. Chat Oversight
Admins can enter any chat thread via **Chat Page** and pin announcements.

---

## 7. Forms & Form Builder
* **Forms** – View submissions.
* **Form Builder** – Create new Google-Forms-style forms (Flutter package `form_builder`).

---

## 8. Tasks
Located in `features/tasks`.

1. Click **Tasks**.
2. **Quick Tasks Screen** lists all tasks.
3. Assign task → select assignees, due date, attach files.

---

## 9. Reports
* Export CSV/PDF via the **Export Widget** (`shared/widgets/export_widget.dart`).
* Available datasets: Shifts, Timesheets, Users, Attendance.

---

## 10. Troubleshooting
| Scenario | Resolution |
|----------|-----------|
| Teacher stuck clocked-in | Click **Force Clock-Out** in Shift Management |
| Duplicate shifts | Use **Clean Duplicates** button (calls `ShiftService.cleanupDuplicateShifts`) |
| User can’t sign in | Verify user document exists & role assigned |

---

## 11. Support & Contact
E-mail: admin-support@alluwal.edu | Phone: +XX-XXX-XXXX

Thank you for keeping the academy running smoothly! 