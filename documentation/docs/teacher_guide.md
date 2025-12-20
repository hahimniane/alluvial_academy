# Alluwal Education Hub – Teacher Guide (v1.0)

> This guide is generated directly from the current code-base (commit `{{<commit_hash>}}`).  It reflects exactly what teachers see in the live application.

---

## 1. Logging In
1. Open the web URL supplied by your administrator.
2. Click **Sign In**.
3. Enter your e-mail and password.
4. A successful login lands you on the **Dashboard** and shows a blue **Teacher** badge at the top-right.

If you forgot your password, click **Forgot password?** on the sign-in form.

---

## 2. Main Navigation
According to `UserRoleService.getAvailableFeatures('teacher')`, teachers have *five* sections:

| Menu Label | Icon (Material) | Purpose |
|------------|-----------------|---------|
| Dashboard  | `Icons.dashboard` | Quick statistics, upcoming shifts, tasks summary |
| Chat       | `Icons.chat`      | Secure messaging with students / staff |
| Time Clock | `Icons.access_time` | Clock-in / Clock-out & timesheets |
| Forms      | `Icons.description` | View / submit school forms |
| Tasks      | `Icons.check_box` | Manage tasks assigned to you |

Access these from the left sidebar (or the *hamburger* menu on mobile).

---

## 3. Shifts & Clock-In/Out
### 3.1 Checking Your Shifts
* **Dashboard → Upcoming Shifts** widget shows the next classes.
* A shift is *ready* 15 min before start time (`TeachingShift.canClockIn`).

### 3.2 Clock-In
1. Go to **Time Clock**.
2. The app automatically detects your next valid shift (`ShiftTimesheetService.getValidShiftForClockIn`).
3. Press **Clock In**.
   * Your browser location is captured and stored with the timesheet entry.
   * A running timer appears.

### 3.3 Clock-Out
1. When finished, press **Stop** (the button turns red while clocked-in).
2. The system:
   * Calls `ShiftTimesheetService.clockOutFromShift` – recording end time & location.
   * Generates a timesheet row in **Time Clock → Timesheet Table**.

> If you forget, an **auto-logout** runs 15 min after shift end and closes the session for you (`ShiftService.autoLogoutExpiredShifts`).

---

## 4. Chat
* Located at **Chat** in the sidebar.
* Supports 1-on-1 and group rooms (`features/chat`).
* Drag-and-drop files <25 MB.

---

## 5. Tasks
* Open **Tasks**.
* Tasks list comes from Firestore collection `tasks`.
* Mark complete via the checkbox, or upload attachments.

---

## 6. Forms
Forms appear under **Forms**.  Complete digital forms (permission slips, surveys) and submit – responses are stored in Firestore.

---

## 7. Troubleshooting
| Symptom | What to Do |
|---------|-----------|
| *Clock-In Disabled* | You are outside the 15 min window or already clocked-in. |
| *Active Shift Exists* | Wait for auto-logout or ask an admin to force clock-out. |
| *Location Error* | Allow location access in your browser settings. |

---

## 8. Support
E-mail: support@alluwal.edu

Happy teaching!  Your punctuality and diligence keep our virtual classrooms thriving. 