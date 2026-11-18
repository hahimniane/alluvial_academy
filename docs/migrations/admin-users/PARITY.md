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

## Slice B2 — side-panel actions, Next sign-in checks

Every write goes to `users/{documentId}` (U-053 fixed); each action runs once
per click (double-clicks and repeat clicks while it runs do nothing); errors
say what to do ("you appear to be offline…", "you don't have permission…").
Tested on alluwal-dev with throwaway / fictional accounts (`zz_b_*`,
`zz_users_*`); Zoom and class changes on dev classes only.

| ID | Item | Result | Evidence |
|---|---|---|---|
| U-034/035 | Which actions a person gets | differs (design) | Side panel instead of row icons. Access switches for active people only: AI Tutor (students, teachers, admin-teachers), Tontine (everyone), Zoom (teachers). Make admin-teacher for ACTIVE teachers only (Flutter also offered it on archived ones). Remove admin access for admin-teachers. Archive / Restore, Delete… for everyone. Edit arrives with slice D (absent, not dead). Unit tests. |
| U-036 | Feedback | differs (design) | Toast at the bottom (dark = done, red = failed, longer); dialog errors stay in the dialog so the admin can retry. |
| U-037 | Stored password | differs (D1) | Login section: Student ID, login email, Password •••• with Show / Hide, "Only admins and this student's parent can see it." Show reads `student_credentials/{id}`, else the legacy user-doc field. Dev: seed student with only the legacy field → Show displayed it; after `migrate_student_credentials.js --apply --delete-legacy` the field was gone and Show displayed the same value from the store. The password is read only on Show and dropped on Hide or when another person is opened; never in the list state or the export. |
| U-038–040 | Reset password | differs (design, D1b, fix) | Dialog per design (optional typed password with show/hide eye, same 6–128 / no-spaces checks inline; names the guardians who get the email, or says to share it). Result: "New password ready" + Copy + who was emailed / "Share it with the student or their parent." + Student ID; afterwards the Login section's password goes back behind Show. Dev: a too-short password was refused inline; blank → generated `word####`; a double-click made one server call (function log). |
| U-041/042 | AI Tutor / Tontine | pass (+fix) | One click, no confirmation; "Tontine turned on for Aminata"; by document id; `updated_at` is the server time. Dev double-click flipped once. |
| U-043–045 | Zoom | pass (+fix, dev only) | Turning on: host radios (the same two accounts) + "Or type another host email", the teacher's current host pre-selected (Flutter always picked the first); "All of them" / "Only some students' classes" (students of the teacher's upcoming teaching classes); submit disabled until one is ticked. Turning off asks first (Flutter did not), since it moves every upcoming class back. Messages "Zoom turned on/off for {name}. N upcoming classes updated." (0/1/n). Dev: off → the teacher's 4 upcoming teaching classes went to `realtimekit`, past and non-teaching untouched; on with one student → only that student's 2 upcoming classes went to `zoom`, host kept. `setTeacherZoomEnabled` unchanged. |
| U-046 | Make admin-teacher | pass (+fix) | Design dialog; transaction re-checks the person is still a teacher; real errors shown (Flutter swallowed them). Dev: moved to the Admins tab, toast "… is now an admin-teacher." |
| U-047 | Remove admin access | pass (+guard) | Design dialog; refuses your own account ("You can't remove your own admin access."). Dev: back to Users. |
| U-048 | Archive | pass (+guard) | Design dialog (the admin-pay bullet only for admins/admin-teachers); same fields as Flutter by document id; refuses your own account. Dev: archived teacher refused at the Next sign-in. |
| U-049 | Restore | pass | Restores and clears the `deactivated_*` fields; says admin pay does not restart by itself (true today). Dev: restored teacher signed in on Next. |
| U-050–052 | Delete | differs (D3, design) | Self → "You can't delete your own account." (also refused by the server). Dialog per design: email, role · status, "Also delete this teacher's/student's upcoming classes" (past classes, timesheets, class reports kept), type DELETE (lower-case refused). Active → archived first, then `deleteUserAccount({userId, deleteClasses})`; if the delete then fails, the message says they are archived and can be restored. Dev: active teacher with 2 past + 2 upcoming classes, a timesheet and a class report → deleted; 2 upcoming classes gone; past classes, timesheet, report kept; one server call for a double-click; panel closed. |
| panel | Recent decisions | pass | Last 5 of `decision_audits/user__{id}/events` + the user doc's own created/archived/restored fallbacks, as EditUser's DecisionHistoryCard merges them; actor by name, never an email/phone; "No decisions recorded yet." |
| D4 | Next sign-in | differs (fix) | `/student/login` and `/teacher/login` now do what Flutter's AuthService does after sign-in: an archived account is signed out with "Your account has been archived. Please contact an administrator for assistance."; otherwise `last_login` is written (uid document, else the one whose `e-mail` matches). A read error lets the person in, as Flutter does. Dev: archived throwaway teacher refused and signed out; after Restore the same login landed on `/teacher/` and `last_login` was set. |
| narrow | Dialogs at 375 px | pass | Dialogs fit (343 px), no horizontal scroll. |

## Slice C — Add users (S6), duplicate warning (F3), Enroll a family (F6)

Tested on alluwal-dev with throwaway people (last names `Zzc…`, emails at
`zzc.test.alluwal.invalid`, ids `zz_c_*`), removed afterwards with
`slicec_dev.cjs undo`; the class step on a dev class only. The three account
callables were deployed to alluwal-dev by hand. Dev has no mail key, so every
welcome / parent email failed there; the messages said so.

| ID / # | Item | Result | Evidence |
|---|---|---|---|
| U-060–062 | Way in, header | differs (design) | "Add users" (primary) and "Enroll a family" beside Export. Modal per AddUser design; full screen below 768 px (checked at 375 px: no horizontal scroll). |
| U-061 | Closing | differs (fix) | Never closes on an outside click; Cancel / × / Escape with something typed ask "Discard what you typed?". Closing is blocked while creating (Flutter let the sheet close mid-save). |
| U-063/064/104 | "Learn more", banner, broken strings | differs (fix) | Replaced by one plain subtitle; no broken auto-generated sentences. |
| U-065/066 | Rows, remove | differs (fix) | "Person N" cards with stable ids (Flutter's remove-by-position bug not ported). "+ Add another person" copies the last row's type and phone country. Up to 25 per save (server limit). |
| U-067/068 | Names, type | differs (design) | Type chips Admin / Teacher / Student / Parent. First row starts as Student (Flutter defaulted to Admin; a mis-click no longer creates an admin). Changing type resets minor/adult and the parent, as in Flutter. |
| U-069 | Kiosk code | pass (+fix) | Same format (initials + AD/TC/PR + 3 random digits + digits 9–13 of the clock), crypto random digits; kept while the initials and type fit. Uniqueness checked against every user already in the page's list (no extra reads) and within the save; a clash makes a new code instead of an error. Not shown for students: the server never stores a student's kiosk code (U-069), so showing one would be false. |
| U-070 / D4 | Hourly rate | differs (D4) | Admin / teacher rows only, optional, no pre-filled value (Flutter showed 15.00 and saved nothing); 0–1000, two decimals. Saved as `users.hourly_rate` by `createUserWithEmail` / `createMultipleUsers`; never for parents/students. Dev: 4.50 typed → `hourly_rate: 4.5`. |
| U-071/079 | Phone | differs (fix) | Country picker (common countries first, then all) + number; checked per country (lengths/leading digits for the school's countries from libphonenumber metadata, otherwise Flutter's 4–15 digits). Stored E.164 (`+224621123456`) with `country_code` `+224` (Flutter stored the text as typed and `"1"` vs `"+1"`). Spaces, dashes, brackets, a typed/pasted `+224` or `00224`, and a leading trunk 0 are accepted. Dev: GN `0621 12 34 56` → `+224621123456`; SL `076 123 456` → `+23276123456`; US `(347) 555-0187` → `+13475550187`. |
| U-072/102 | Email | pass | Required except for a minor ("Email (optional for minors)"); a minor's typed email is still sent (same as today). Format checked; trimmed and lower-cased. Two rows with the same email (any case/spaces) are stopped before sending: "Same email as Person 2." |
| U-073–076 | Minor / adult, parent | pass (+fix) | Minor needs a parent ("Pick the parent or guardian.", dev: refused before any call). Parent picker = the page's parent picker over ACTIVE parents (Flutter: `user_type == parent && is_active`), search by name, email, phone or ID (dev: found by `0622 000 111`). Live list, so a parent created minutes ago is pickable (Flutter loaded once per row). |
| U-077/078 | Which rows count, required fields | differs (fix) | Same counting rule; every problem shown under its field for every person at once (Flutter: first row only, one snackbar). |
| U-083 | Which callable | pass | 1 student → `createStudentAccount`; 1 other → `createUserWithEmail`; 2+ → `createMultipleUsers`. |
| U-084–086 | Student login preview | differs (fix) | Inline "They will log in with" box mirrors `students.js` exactly: a–z/0–9 only, ten per part, accents dropped not translated, then `1first.last`…`9first.last` against every stored `student_code` and earlier rows of the same save. Shows "Already this parent's child … nothing new is created" when the server's same-child rule will return an existing account. A name with no Latin letter is refused (client and now server). Dev: `Aïcha` + `Zzc-N'Diaye` → preview and server `acha.zzcndiaye`; same name as an adult → `1acha.zzcndiaye` both; two same-name rows in one batch → `x` and `1x`. A sign-in account without a profile can still move the real ID; the result shows the real one. |
| U-087/088 | Child already exists | differs (fix) | "… is already this parent's child (Student ID …). Nothing new was created." (Flutter said it was "linked"; nothing is linked). |
| U-089/090 / D4 | Student messages | differs (D4) | Minor: "Student ID x. The login was emailed to the parent." / "…could not be sent. The password is under Show in the student's panel." / parent without email: "no one was emailed". Adult: "No email is sent to adult students: give them this Student ID. Their password is under Show in their panel." (Flutter claimed a welcome email). The Flutter screen's adult message was corrected the same way. |
| U-091/092 | Admin / teacher / parent messages | pass (+fix) | "Welcome email with their login sent to x." or "…but the welcome email could not be sent, so they have no login details yet." |
| U-093 / D4 | Several people at once | differs (D4, server fix) | `createMultipleUsers` read the v2 request wrongly (crashed before creating anyone). Now: rows in order, each reported by `index`; one bad row never stops the others; students go through the same creation as `createStudentAccount` with the verified caller (they all failed "Authentication required" before); a minor without a parent is refused per row; parents get their family code and it is in their welcome email; 300 s timeout; at most 25. Results view: "2 of 3 done, 1 not created." with a line per person and "Fix the ones not created" (keeps only those). The Flutter sheet now lists refused rows instead of "N users created". Dev: 5-row batch → 3 created, duplicate email and parentless minor refused by index; UI batch of 3 mixed (student + teacher + parent) all created; UI batch with an email that already had an account → that row refused, others created. |
| U-094 | Errors | differs (fix) | In the admin's words per person ("This email already belongs to an account."); a lost answer for a batch says some may have been created and to check the list. |
| U-095 | Busy, double-click | pass | "Creating…", buttons disabled, one call per press (dev: double-clicked "Create anyway" → exactly 3 accounts). |
| U-096 | After success | pass | New people appear in the list by themselves (live listener). |
| U-097 / gate | Who can add | pass | Page: admins only. Server: `verifyCallableCallerIsAdmin` on all three. Dev: a signed-in teacher calling each → `permission-denied`; unauthenticated POST → JSON `UNAUTHENTICATED` (invoker bindings live). |
| U-100 | `created_by_uid` | differs (fix) | Set for every path, single students included (was null). |
| sensitive | Passwords | differs (fix) | `createStudentAccount` no longer returns the generated password (no client used it) and `createMultipleUsers` never returns one; it lives only in `student_credentials`. The Add / Enroll code never names a password (unit-tested guard). |
| F3 | Duplicate warning | new | Before creating, each person is compared with everyone in the page's live list (no extra reads): name with accents/case/spacing/punctuation ignored and in either order, email (both `e-mail` and `email` fields, any case), phone in every stored shape (E.164, national + country code with or without plus, `00`, trunk 0, brackets; plus same last 9 digits). Matches are listed with why ("same phone"), archived ones marked; "Open" shows the person in the side panel while the form waits behind a "Back to Add users" button (nothing lost); "Create anyway" goes ahead. Accounts that exist only in sign-in (no profile) are caught by the server per row. Dev: `(347) 555-0187` matched a seed parent stored as `3475550187` + `+1`; a same-name student matched; a parent email matched an existing parent. |
| F6 | Enroll a family | new | One form: student (minor/adult, phone; an adult's email; a minor's own email is not asked, U-102) + parent: new, already here, or none for an adult. Order: new parent first (`createUserWithEmail`), then the student with that parent (`createStudentAccount`, which links both sides and emails the parent the child's login and returns the parent's existing same-name child instead of a second account), then the optional class step, enabled only once the student account exists and is in the class list. The class step opens the schedule's own `ShiftEditorDialog` with the student pre-selected (subject required by the editor). Partial failure: what was created is shown and kept; "Try the student again" never re-creates the parent. Parent email already taken → "Nothing was created" + "Use <parent>, who has this email" when that parent is in the list. Dev: (1) taken parent email → nothing created → used the existing parent → student created and linked → class step skipped; (2) new parent + minor, student call forced to fail once → parent shown as created, retry created the student linked to that one parent (no second parent) → "Add a class" → no subject → "Pick a subject." → Quran Studies, Dec 28 → class saved with only that student. |
| narrow | 375 px | pass | Add users and Enroll a family full screen, no horizontal scroll. |
