# Admin Users page — parity record (Flutter → Next.js)

Checklist IDs come from the Users inventory (U-001 … U-153). Slice A:
**S0 (frame + switch)** and **S1 (read-only list)**, plus decision **D2**
("First class" replaces the Kiosk Code column). Slice B1: the student password
store (**D1**, **D1b**), the delete scope (**D3**) and the rules fixes they need.
Later slices add their rows.

Tested on **alluwal-dev** with fictional seed people (ids `zz_users_*`, see
"Test data" below), the dev switch on `allowlist` for the dev test admin only.
No production data was read or written. Production keeps the switch absent
(= off), so every admin still gets the Flutter screen.

Result key: **pass** = same behaviour; **differs (D#/design)** = changed on
purpose, with the decision; **could not test** = reason given.

## Decisions applied in this slice

| # | What | Where it shows |
|---|---|---|
| D2 | "First class" column = date of the student's first attended class. Definition: earliest `shift_start` of a teaching class (category `teaching`, the default) listing the student in `student_ids` with status `completed`, `fullyCompleted` or `partiallyCompleted` — the same "attended their first class" signal that creates the family's first invoice (`finance_billing.js` `COMPLETED_STATUSES`). Stored on `users/{id}.first_class_at` (+ `first_class_shift_id`) by the `recordStudentFirstClass` trigger (only ever moves the date earlier; one user read per student when a class completes) and filled for history by `functions/dev-scripts/backfill_student_first_class.js`, which reads live **and** archived classes through `utils/shifts_in_range.js`. The page reads no classes for it. Students without one show "Not yet". Kiosk code stays in the side panel and in the export. | Users table, side panel |
| D4 | Visible filter state as the design shows: type / minor-adult / status / parent are chips that combine; the active parent is a chip with ×; "Admins" is the Admins tab (today's Admins filter empties the Users tab). | Filter row |
| design | Name + email in one column, sortable by name; click a row → side panel; narrow window → cards + full-screen panel. | Whole page |

## S0 — entry, access, frame

| ID | Item | Result | Evidence |
|---|---|---|---|
| U-001 | Sidebar People → Users opens the page inside the dashboard | pass | `dashboard.dart` case 1 → `AdminUsersEntry`: web + switch allows → `AdminUsersWebFrame` (iframe `/admin/users/?embed=1`, same pattern as Finance/Shifts); otherwise `UserManagementScreen`. Native builds always get `UserManagementScreen`. Flutter dev build (`--dart-define=FIREBASE_ENV=dev`) served beside the Next dev server, signed in as the dev admin: switch on → the Next page inside the Flutter sidebar/top bar, session kept; switch off → the old Flutter Users screen. |
| U-002 | Who can open it | pass | Next gate = `isCurrentUserAdmin` (same as Finance/Shifts and the Flutter role switcher, incl. `secondary_roles: admin`). Non-admin → "Users is for administrators."; signed out → "Sign in to see users." |
| U-003 | Page chrome | differs (design) | Title "Users" + one-line subtitle, tabs, filter row, white card. Flutter title strip replaced by the design header. |
| U-004 | Toolbar | differs (design/D4) | Export top right; search; type chips; status chips (incl. "Never logged in", replacing the orange button); "Filter by parent". "Add users" arrives with slice C (absent, not dead). |
| U-057 | Embed pattern | pass | `/admin/users` added to `NATIVE_ADMIN_PREFIXES`; standalone visit → `location.replace("/app/")` (verified in browser); embed detection `window.self !== window.top` or `?embed`; COEP `.htaccess` added for `admin/users` in `package-hostinger.mjs`; Firebase auth stays on `browserLocalPersistence` (shared `lib/firebase.ts`). |
| switch | `settings/admin_users_web_cutover` {mode off\|allowlist\|all, adminIds} | pass | Flutter `AdminUsersWebCutover.allows` + Next `adminUsersCutoverAllows` fail closed (missing doc, unknown mode, empty uid, read error → Flutter screen); unit tests both sides. Dev: switch deleted → Next page shows "Reload the page to open Users." and loads no users; switch on → page. |

## S1 — the list

| ID | Item | Result | Evidence |
|---|---|---|---|
| U-005 | Whole `users` collection, live, no limit | pass (+fix) | `onSnapshot(collection('users'))`, no limit. Live: renaming a seed user via Admin SDK showed on the open page within ~1 s. Fix: a listener error shows "Users could not be loaded." + Try again (Flutter spins forever). |
| U-006 | Doc → row mapping | pass | `mapUserDoc` reads named fields only (Flutter's fields + `guardian_ids/guardianIds`, `children_ids/childrenIds`, `first_class_at`); kiosk/student-code fallbacks, `is_active` default true, `??` semantics for the adult flag and student code — unit tests. A seeded `temp_password` never appears in page state, DOM or exports (checked in browser). Non-string names no longer break the page (Flutter would throw). |
| U-007 | Parent links | pass | Built from the one live listener (students' `guardian_ids` ∪ `guardianIds`; parents' `children_ids` not used), first guardian for the Parent / Parent Email columns. Seed: Mariama Zz-Barry → 2 students (one via `guardian_ids`, one via `guardianIds`); Abdoulaye Zz-Sylla → 1 (the student with two guardians). |
| U-008 | This week's classes | pass | Monday 00:00 local + 7×24 h, as Dart computes it; teaching only, cancelled skipped, shared classes split per student, teachers A→Z. Seed: Aminata = 0.5 (shared) + 1.5 (missed counts) = "2 hrs", cancelled class ignored; 45-minute `duration_minutes` class → "0.8 hrs"; leadership class ignored. |
| U-009 | Read cost | differs (fix) | One users listener; parent links derived from it (no second "all students" query per change); the week's classes are a live listener instead of a re-query every 30 s; documents whose shown fields did not change (presence heartbeats) cause no re-render. First class costs no reads (stored field). |
| U-010 | Loading state | pass | Spinner until the first snapshot; counts show "…". |
| U-011 | Tabs with counts after filters | pass | Users 45 / Admins 11 on dev = direct Admin-SDK count (`seed_users_dev.js counts`) = the Flutter screen (dev build, switch off) USERS (45) / ADMINS (11). Secondary-role admin stays on Users (seed `Second Zz-Role`). |
| U-012 | Admins banner / empty states | differs (design) | No "Admin Role Management" banner (broken auto-generated text). Empty: "No one matches these filters" + Clear filters, or "No admins yet"/"No users yet". |
| U-013 | Grid behaviour | differs (design) | Sortable by name (A→Z default, toggle), row click opens the panel. No selection/pagination (same). |
| U-014 | Columns | differs (D2/design) | Name+email · Phone · Type · Student ID · Parent (+parent email) · Teacher · this week (teachers · hours) · First class · Added · Last login. Every value of today's columns is still shown; Kiosk Code moved to the panel and the export (D2). |
| U-015 | Type pill | differs (design) | Readable labels (Student / Adult student / Teacher / Parent / Admin / Super admin / other types humanised), same colour families. |
| U-016 | Student ID | pass | `student_code → studentCode → student_id → kiosk code (→ doc id)`; blank for non-students. |
| U-017 | Kiosk Code column | differs (D2) | Replaced by First class; Flutter's kiosk value (incl. the uid fallback) shown in the panel and exported unchanged. |
| U-018 | Parent / Parent Email | pass | First guardian's name and email, in one cell. Seed student with a guardian id that has no account shows "—" (Flutter: blank). |
| U-019 | Teacher / Weekly Hours | pass | Same formulas (one decimal, none when whole, blank at 0), shown as "Teacher · 2 hrs". |
| U-020 | Date Added / Last Login | differs (design) | Shown as "Sep 4, 2026"; full Dart text on hover; missing Date Added shows "—" instead of "Never". Export keeps the exact Dart text (`2026-11-15 14:03:22.123[456]`, "Never"). |
| U-021 | Archived rows | differs (design) | Name struck through + one "Archived" badge (not one per cell); Admins tab styled the same way. |
| U-022 | Admins grid | differs (design) | Name+email · Phone · Role · Admin type (Admin-teacher / Full admin) · Last login. |
| U-023 | Filter menu items | differs (D4) | Chips: Everyone/Teachers/Students/Parents; Minors/Adults under Students; Any status/Active/Archived/Never logged in; Admins = the Admins tab. Current choice always highlighted. |
| U-024 | What each filter does | differs (D4) | Type, minor/adult and parent narrow the Users tab; status and search narrow both tabs (same split as Flutter) — but they now combine. Dev counts, browser vs direct count: Teachers 11, Students 20, Minors 18, Adults 2, Parents 13, Archived 3/1, Never logged in 37/6, Active 42/10, Teachers+Active 10. All equal. |
| U-025 | Never logged in rule | pass | Same placeholder list on the Last Login text (unit test); chip replaces the orange button. Flutter's orange button on the same data: USERS (37) / ADMINS (6); Next chip: 37 / 6. Note: dev test admin shows "Never" — the Next login does not write `last_login` yet (slice B, D4). |
| U-026 | Filter state oddities | differs (D4) | Picking a parent clears type/status/search **visibly** and switches to the Users tab; the parent chip shows who is selected. |
| U-027 | Search box | pass | Filters both tabs on each keystroke; placeholder "Search name, email, phone or Student ID". |
| U-028 | Search matching | pass | TypeScript port of `AppSearch` (`lib/appSearch.ts`, unit tests). Browser on dev: "zz-barry" 3, "aminata zz" 1, "zz.aminata"/"zzaminata" 1, "646-555-0110" and "+1 (646) 555 0110" 1, "teacher" 11 users + 1 admin-teacher, "李" 1, kiosk code, document id, "0612345678" and "612345678" (leading zero) 1, "6465550" 0 (same as Dart: 7 digits but no end match). |
| U-029 | Export button / format choice | differs (design) | Menu with Excel (.xlsx) / CSV (.csv) instead of a dialog; empty list → "No data to export". Toast confirms the download. |
| U-030 | Export content | pass | Users-tab rows shown (also when the Admins tab is open), grid order, the 13 headers, `employees.xlsx` (sheet "Sheet1") / `employees.csv` (UTF-8, no BOM, quoted only when needed, CRLF). Browser on dev with Students: 20 rows, values checked (student ID, kiosk = uid fallback, parent, teacher list quoted, "0.5 hrs", Dart dates). Header row not bold in the xlsx (shared writer) — cosmetic. |
| U-031 | Filter by parent — layout | differs (design) | Popover: search, "N parents", initial tile, name, email, student count, selected tick, Clear parent filter. Link student / Manage linked students arrive with slice D (absent, not dead). |
| U-032 | Parent list data | pass | Every `user_type == 'parent'` (archived flagged), count from students' guardian fields, most students first then name; search = `AppSearch.matchesMap` fields (phone with country code found: "347 555 0187"). |
| U-033 | Picking a parent | differs (D4) | Lists that parent's students; visible chip with ×. |
| U-059 | Localisation | differs | English only, like the other Next admin screens (Shifts, Finance); Flutter has FR/AR for these labels. Broken auto-generated sentences are gone. **Owner to confirm** at the parity pass. |

## Side panel (design; read-only in slice A)

Shows: name, type, Active/Archived; email, phone, kiosk code, added, last login,
title, other roles; students: Student ID, login email (`student_code@…`, or
"Not available"), every guardian (click → their panel), teacher this week,
hours, first class; parents: linked students (students' guardian fields ∪
the parent's `children_ids`, like "Linked Students"); admins: admin type;
active users: AI Tutor / Tontine / Zoom (with host) as On/Off. No action buttons
yet — they arrive with slice B, so nothing on the page is a dead control. No
password is read or shown (D1 is slice B).

## Narrow window

At < 768 px the table becomes cards (initials, name, type · Student ID · parent /
parent · N students / type · phone; corner: hours this week or last login,
"Never" in orange; archived struck through with "Type · Archived" in red).
Status and parent filters sit behind "More filters". Tapping a card opens the
panel full screen; Escape or × closes it. Between 768 and 1280 px the panel
opens as a right-hand drawer; from 1280 px it sits beside the table.

## Test data and scripts (dev only)

`~/alluwal-scratch/users-migration/seed_users_dev.js` (not in the repo):
16 fictional users — parent with 2 children (one link per spelling), student
with 2 guardians, archived parent/teacher/adult student/admin, never-logged-in
users, minor and adult students (`is_adult_student` and `isAdultStudent`), an
admin-teacher, a super admin, a teacher with `secondary_roles: [admin]`, a user
with no phone, unicode names (`Ŝéku Zz-Ndiaye 李`), a doc with only a few fields
and string dates, a doc with a numeric first name and a guardian id that has no
account — plus 8 live classes (this week: shared, missed, cancelled,
duration-only, non-teaching; past completed / partially completed / missed) and
1 archived fully-completed class. `undo` removes all of it and the dev switch.

## Slice B1 — student passwords, delete scope, rules (server + Flutter readers)

| ID / # | Item | Result | Evidence |
|---|---|---|---|
| D1 | Where a student's password lives | differs (D1) | `student_credentials/{uid}` `{password, source: created\|reset\|self\|migrated, updated_by, updated_at}`, written only by Cloud Functions (`services/student_credentials.js`). Rules: read by admins (incl. super admins and admin-teachers) and by a parent (`user_type == 'parent'`) whom the STUDENT's doc lists in `guardian_ids` or `guardianIds`; no client writes (also excluded from the admin fallback rule). Never on `users/{uid}` again. |
| D1 | Writers | differs (D1) | `createStudentAccount` and `resetStudentPassword` write the store in the same batch as the user doc and stop writing `temp_password` (reset also deletes a stale legacy copy). The Flutter self-service password changes (dashboard, profile, role settings screen; the phone settings screen never stored it) call the new `recordOwnStudentPassword` callable after Firebase Auth accepted the new password; students only, everyone else gets `recorded: false`. |
| D1 | Readers | pass (fallback) | Flutter web + phone "View Login Credentials" and `syncAllStudentPasswords` read the store first and fall back to the legacy `temp_password` (`StudentCredentialsService.readPassword`, `pickStoredPassword`). |
| D1 | Migration | — | `functions/dev-scripts/migrate_student_credentials.js --project <id> [--apply] [--delete-legacy] [--include-non-students]`: dry run by default, never overwrites a stored password, deletes a student's legacy field only once the store holds one, prints counts only. |
| D1b | Generated passwords | differs (D1b) | `generateEasyPassword`: one of 170 common words + 4 digits (`tiger4827`), `crypto.randomInt`, never a word that overlaps the person's names or Student ID. Used for new students and resets. Typed passwords: 6–128 characters, no leading/trailing spaces (unchanged). The strong generator for staff/parents now uses `crypto.randomInt` too. |
| U-039 | Who may reset | differs (fix, D4) | Same gate as create/delete (`verifyCallableCallerIsAdmin`): admins, **super admins** (refused before), admin-teachers, admin claims. Teachers/parents/students refused (dev E2E). |
| U-039 | Guardian emails | differs (fix) | Guardians under `guardian_ids` **and** `guardianIds` are emailed (only `guardian_ids` before); the result names who was emailed (`emailedTo`). |
| U-052 | Delete target | differs (fix, U-053) | `deleteUserAccount` takes `userId` (document id); the email lookup stays only for older app builds. The sign-in-account fallback by email deletes an account only if it belongs to that same profile (a minor created with the parent's address no longer takes the parent's login with it). |
| U-050 | Self delete | differs (fix) | Refused on the server too ("You cannot delete your own account"). |
| D3 | "Also delete classes" | differs (D3) | Upcoming classes only (`shift_start` after now): a teacher's are deleted; a student is removed from upcoming group classes, upcoming solo classes are deleted. Past and running classes, every timesheet and every class report are kept. Timesheets are no longer deleted at all (pay records). Returns `upcomingClassesDeleted / upcomingClassesUpdated / classesKept`. Flutter labels now say "upcoming classes" and the footer says what is removed and kept (EN/FR/AR). |
| rules | Self-update holes | differs (fix) | Found while securing the store, all proven on dev before the fix and refused after: (1) `isFcmTokenOnlyUpdate` / `isPresenceOnlyUpdate` / `isLastKnownLocationOnlyUpdate` used `changedKeys()`, which ignores ADDED fields, so any signed-in user could add `role: 'admin'` or `is_admin_teacher: true` to their own document and become an admin; now `affectedKeys()`. (2) The owner check read the written data, so writing your own address into another user's `email` made you its owner; the owner is now checked on the stored document too. (3) `is_admin`, `isAdmin`, `is_super_admin`, `isSuperAdmin`, `userType`, `secondary_roles(Roles)`, `guardian_ids/guardianIds`, `children_ids/childrenIds`, `ai_tutor_enabled`, `tontine_enabled` are locked on self-update (no app screen writes them on the person's own document). (4) Phone sign-up may create only the circle-member fields. `title` and `kiosk_code` stay self-editable (not proven unused). Legacy `temp_password` self-writes from older phone builds stay allowed until the phone release is in use. |
| gate | `adminEmail` in callables | differs (fix) | `verifyCallableCallerIsAdmin` no longer trusts a caller-supplied `adminEmail`; only the verified token identifies the caller. |
