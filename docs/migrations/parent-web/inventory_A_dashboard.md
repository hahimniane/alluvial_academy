# Inventory A — Parent shell, home dashboard, child detail, profile, settings (Flutter, as of main @ 0a49330)

1. Scope: how a parent reaches the Flutter parent area, the shell (sidebar/header/role switch/sign-out), the home dashboard, the per-child detail screen with 4 tabs, Profile, Settings, and ParentService.
2. Sections: 1 Entry and routing · 2 Shell · 3 Home dashboard · 4 Child detail (Overview / Classes / Tasks / Progress + class card) · 5 Profile · 6 Settings · 7 ParentService reference · 8 Broken / dead / hard-coded · 9 Language dependence · 10 Next.js reuse map · 11 Owner questions.
3. Item count: 118 checklist items (A-001 … A-118). Each has What / Source / Data / Rules / Next.js / Platform. Shared queries are defined once as D-blocks, rules as R-blocks.
4. Biggest risk 1: two different "attendance" numbers live on the same page (shift-status based vs join based) and both must be reproduced exactly, including their known disagreement.
5. Biggest risk 2: every "all-time" figure and "Class History" silently covers only classes still in `teaching_shifts` (about the last 60 days); parents cannot read `teaching_shifts_archive`.
6. Biggest risk 3: multi-role accounts. Role choice lives in browser localStorage (`flutter.active_user_role`) and Next.js login already sends parent+student accounts to /student/. A parent cut-over changes who lands where.
7. Biggest risk 4: the shell is one Flutter page with 11 tabs kept alive in memory, no URLs, no Back between tabs. A Next.js version with real routes changes refresh, Back and deep-link behaviour by design.
8. Biggest risk 5: several things parents see today are broken or junk (Quran menu item does nothing, "Assigned By Assignedbyname", "Failed To Save Profile E", Profile back arrow). "Same as today" needs an owner decision per item (section 8).
9. Biggest risk 6: rules are wider than the UI (any signed-in user can list all classes; any parent can read every task). The Flutter UI is the only thing scoping data to the parent's own children, so the Next.js queries must scope identically.
10. Not covered here (other inventory parts): Invoices, Payments, Payment screen, Invoice detail, Parent Classes, Forms, Chat, Recordings, Curriculum Books, Quran reader, the video join screens themselves.

---

## 0. Conventions

**File short names** (all under `lib/`):

| Short | File |
|---|---|
| RBD | features/dashboard/screens/role_based_dashboard.dart |
| LAYOUT | features/parent/screens/parent_dashboard_layout.dart |
| SBC | features/dashboard/config/sidebar_config.dart |
| CSB | features/dashboard/widgets/custom_sidebar.dart |
| SBS | features/dashboard/services/sidebar_service.dart |
| SBL | features/dashboard/utils/sidebar_localization.dart |
| RSW | core/widgets/role_switcher.dart |
| URS | core/services/user_role_service.dart |
| PDS | features/parent/screens/parent_dashboard_screen.dart |
| PS | features/parent/services/parent_service.dart |
| FSC | features/parent/widgets/financial_summary_card.dart |
| CLW | features/parent/widgets/children_list_widget.dart |
| ICW | features/parent/widgets/invoice_card.dart |
| CCC | core/widgets/class_contacts_card.dart |
| SDS | features/parent/screens/student_detail_screen.dart |
| OVT | features/parent/widgets/student_overview_tab.dart |
| QSC | features/parent/widgets/student_quick_stats_card.dart |
| CLT | features/parent/widgets/student_classes_tab.dart |
| CAL | features/parent/widgets/attendance_calendar.dart |
| PPC | features/parent/widgets/parent_presence_card.dart |
| TKT | features/parent/widgets/student_tasks_tab.dart |
| TKC | features/parent/widgets/task_card.dart |
| PGT | features/parent/widgets/student_progress_tab.dart |
| PPS | features/parent/screens/parent_profile_screen.dart |
| RSS | features/settings/screens/role_settings_screen.dart |
| LNG | core/services/language_service.dart |
| CVS | core/services/class_video_service.dart |
| SHS | features/shift_management/services/shift_service.dart |

**Data blocks (D-)** — exact reads, referenced by items.

- **D1 Own user record.** `users/{auth.uid}` get. If missing: `users/{email lowercased}` get → `users where email == emailLower limit 1` → `users where e-mail == emailLower limit 1` → `users where phone_number == auth.phoneNumber limit 1`. Cached in memory 5 minutes per uid (URS:153-240). Fields used in this scope: `user_type`, `secondary_roles[]`, `is_admin_teacher`, `first_name`, `last_name`, `phone_number`, `e-mail`/`email`, `language_preference`, `is_adult_student`.
- **D2 Children of a parent.** `users where user_type == 'student' and guardian_ids array-contains {parentUid}` get. **Only if that returns zero docs**, a second query `users where user_type == 'student' and guardianIds array-contains {parentUid}`. Mapped to `{id: doc.id, name: "first_name last_name" or doc.id, studentCode: student_code | studentCode | student_id, kioskCode: kiosk_code, email: e-mail | email}`. Sorted by name with a case-sensitive string compare. One-shot, not live. A failure is rethrown (PS:32-80).
- **D3 Class history (one-shot).** `teaching_shifts where student_ids array-contains {childId} and shift_start < {end}` plus `shift_start >= {start}` **only when a start is passed**. No `shift_category` filter. Sorted newest first. On any error returns an empty list (so errors look like "no classes"). When called with no start date the "default 30 days" in the code is never applied: it returns every past class still in the collection (PS:286-325).
- **D4 Class stream (live).** `teaching_shifts where student_ids array-contains {childId}` snapshots; client keeps only `shift_category == teaching`; sorted oldest first; unparseable docs skipped; stream errors swallowed (SHS:2866-2899).
- **D5 Attendance report callable.** `getStudentAttendanceReport` (us-central1) payload `{studentId, periodType: 'weekly'|'monthly', forceRefresh: bool}` (`referenceDate` never sent from parent screens). Server: allowed if caller is the student, an admin, or listed in the student's `guardian_ids`/`guardianIds`; reads or generates `student_attendance_reports/{docId}`; week = Monday 00:00 UTC to next Monday, month = calendar month in UTC, both containing "now". Response `{success, cached, reportId, report}`; client uses `report.metrics.*`, `report.rates.*`, `report.averages.*`. Any failure returns null to the UI (PS:455-487; functions/handlers/attendance.js:724-739, 1228-1313).
- **D6 Financial summary (live).** Two listeners: `invoices where parent_id == {uid} orderBy issued_date desc limit 200` and `payments where parent_id == {uid} limit 500`. Emits only after both have delivered once (PS:105-158, 191-259).
- **D7 Tasks stream (live).** `tasks where assignedTo array-contains {childId}` snapshots, sorted `createdAt` desc client-side (features/tasks/services/task_service.dart `getStudentTasks`). `Task.fromFirestore` casts `dueDate` as Timestamp: one task with no due date errors the whole stream.
- **D8 Live presence callable.** `getRealtimeKitRoomPresence` payload `{shiftId}`. Server allows teacher / student / admin / parent of an assigned student. For Zoom classes it answers from the hub bot or `livekit_sessions`. Response used: `participantCount`, `participants[{identity, name, role, joinedAtIso, isPublisher}]` (CVS:471-489; functions/handlers/realtimekit.js:334-360, 749-824).
- **D9 Join callables.** `getZoomJoinInfo {shiftId, activeRole?, clientPlatform?}` or `getRealtimeKitJoinToken {shiftId, activeRole?}`; then the classroom sends `recordClassPresence` heartbeats (CVS:330-430, 541-780).
- **D10 Recent invoices (live).** `invoices where parent_id == {uid} orderBy due_date desc limit 5` merged with `invoices where student_id == {uid}` (no order, no limit), de-duplicated by id, sorted by due date desc, first 5. Emits only after both listeners delivered; an error on the second is treated as empty (features/parent/services/invoice_service.dart:15-80).
- **D11 Recent payments (live).** `payments where parent_id == {uid} orderBy created_at desc limit 5` (features/parent/services/payment_service.dart:14-37). Stream errors are swallowed.
- **D12 Class contacts callable.** `getClassContacts {}`; for a parent the server finds children with `users where guardian_ids array-contains uid` (no `guardianIds` fallback) and returns `children[{studentName, contacts[{name, relationship, phone, tel}]}]` (core/services/class_contacts_service.dart; functions/handlers/class_contacts.js:154-176).

**Rules blocks (R-)** — `firestore.rules` in repo root.

- **R1 users read:** any signed-in user may read any user doc (rules 276-279). Covers D1, D2, suspension query, "assigned by" lookups.
- **R2 users self-update:** owner may update own doc if `uid, user_type, role, is_admin_teacher, is_active, created_by_admin, password_reset_required, e-mail, deactivated_*` are unchanged (rules 284-318); a presence-only update (`is_online`, `last_seen`) is separately allowed (rules 160-164).
- **R3 teaching_shifts read:** `get` and `list` for any signed-in user (rules 469-478). No per-child restriction in rules.
- **R4 teaching_shifts_archive:** admin read only, no writes (rules 208-211). Parents cannot read archived classes.
- **R5 tasks read:** assigned user, admin, or any user whose `user_type`/`secondary_roles` contains `parent` (`isParentUser()`, rules 140-146, 610-618). Not limited to the parent's own children. Writes admin only.
- **R6 invoices read:** signed-in and (`parent_id` or `student_id` or `payer_id` == uid, or admin) (rules 1040-1045). Parent update limited to `payment_method_id`.
- **R7 payments read:** same three-field test (rules 1063-1069). No client writes.
- **R8 callables:** no Firestore rule; access is decided in the function (see each D-block).

**Next.js short names** (all under `apps/web/src/`): SHELL = `components/StudentDashboardHome.tsx` (exports `StudentShell`, `switchToRole`, `StudentAccessPrompt`); SESSION = `lib/studentSession.ts`; ROLES = `lib/userRoles.ts` + `lib/roles.ts`; I18N = `lib/i18n.ts` + `lib/localeStore.ts` + `components/LanguageSwitch.tsx`.

**Platform wording.** "Web shell only" means the item exists only inside LAYOUT, which native phones never show (RBD:324-328 returns `MobileDashboardScreen` first). "Both" means the widget is also reachable on phones.

---

## 1. Entry and routing

### A-001 Loading screen while the account is resolved
- **Sees/does:** Logo tile, blue spinner and the text for `loadingUserProfile` until the user record and role are known.
- **Source:** RBD:136-178, 373-420.
- **Data:** D1 polled once a second for up to 30 seconds until a doc with a non-empty `user_type` (or `userType`) is found.
- **Rules:** R1.
- **Next.js:** SESSION resolves the same record once and caches it in localStorage (`alluwal-student-session-v1`) so later navigations do not flash; a parent session needs the same pattern with a parent key. Differs: Flutter polls, Next resolves once.
- **Platform:** Both.

### A-002 "Account not set up" after 30 seconds
- **Sees/does:** Orange person-off icon, `accountNotSetUp` title, `yourAccountHasNotBeenSet` text, **Retry** (re-runs a one-shot role load with up to 3 retries 2 s apart) and **Sign Out**.
- **Source:** RBD:165-177, 233-291, 472-547.
- **Data:** D1. Sign Out: `FirebaseAuth.signOut()`, then web goes to `/` (public site), phone goes to in-app route `/`.
- **Rules:** R1.
- **Next.js:** SHELL `StudentAccessPrompt` (StudentDashboardHome.tsx:1069) is the nearest equivalent. Differs: wording and the Retry button.
- **Platform:** Both.

### A-003 Profile error screen
- **Sees/does:** Red error icon, `errorLoadingProfile`, `pleaseTrySigningOutAndSigning`, **Sign Out** button. Shown when the one-shot role load throws after 3 retries.
- **Source:** RBD:269-290, 422-470.
- **Data:** D1.
- **Rules:** R1.
- **Next.js:** none specific; reuse the access prompt.
- **Platform:** Both.

### A-004 Unknown role screen
- **Sees/does:** Orange help icon, `unknownUserRole`, a sentence naming the role string, **Sign Out**. Shown for any role other than admin, super_admin, teacher, student, parent, circle_member.
- **Source:** RBD:367-370, 549-599.
- **Data:** D1.
- **Rules:** R1.
- **Next.js:** none.
- **Platform:** Web (on phones every unknown role falls into the parent tab set, mobile_dashboard_screen.dart:589-599).

### A-005 Which role is active
- **Sees/does:** Nothing visible; decides the dashboard. Active role = the value saved in SharedPreferences `active_user_role` if the account still has that role, otherwise `user_type`. Roles an account has = `user_type` + `teacher` for any admin + `admin` for a teacher with `is_admin_teacher` + every entry of `secondary_roles` (lowercased).
- **Source:** URS:31-124; RBD:201-221.
- **Data:** D1; browser storage key `flutter.active_user_role` (JSON string) on web.
- **Rules:** R1.
- **Next.js:** ROLES `availableRoles` / `otherRolesOf` reproduce the same role set; SHELL `switchToRole` already writes `flutter.active_user_role`. Differs: Next has no notion of "active role" of its own; it routes by path.
- **Platform:** Both.

### A-006 Parent on the web gets the parent shell
- **Sees/does:** Active role `parent` on web renders LAYOUT (section 2).
- **Source:** RBD:357-362, 632-640.
- **Data:** none beyond A-005.
- **Rules:** n/a.
- **Next.js:** this is the switch-over point. Students use `_StudentWebRedirect` → `location.replace('/student/')` (RBD:349-356, core/utils/web_redirect_web.dart); teachers use `settings/teacher_web_cutover` staged redirect (RBD:647-704). A parent redirect would follow one of those two patterns.
- **Platform:** Web only.

### A-007 Parent on a phone gets bottom tabs, not the shell
- **Sees/does:** Native iOS/Android never shows LAYOUT. Tabs: Home, Classes, Chat, Forms, Tasks, Library (+ Circles if enabled). Home is the same `ParentDashboardScreen` (section 3) reached through `AdminDashboard` → `_buildParentDashboard()`. There is no Invoices/Payments tab on phones; those are reached from the home quick actions.
- **Source:** RBD:323-328; mobile_dashboard_screen.dart:589-599, 665-678; admin_dashboard_screen.dart:554-555, 1953-1955.
- **Data:** as section 3.
- **Rules:** as section 3.
- **Next.js:** not part of the web move; listed so nobody assumes the sidebar list is what phone parents have.
- **Platform:** Mobile only.

### A-008 Parent who is also a teacher
- **Sees/does:** If the active role is `teacher`: goes through the teacher cut-over check (teachers who are also admins stay on Flutter; others may be redirected to `/teacher/`). If the active role is `parent`: parent shell, with a role switcher showing both roles (A-023).
- **Source:** RBD:340-348, 667-692; URS:57-63.
- **Data:** D1; `settings/teacher_web_cutover` via `TeacherWebCutover.shouldUseWebConsole`.
- **Rules:** R1; settings read.
- **Next.js:** `dashboardPathForUser` (lib/userRoles.ts:35-55) sends a teacher-without-admin to `/teacher/` when the cut-over says so, **even if `user_type` is parent** with `secondary_roles: ['teacher']`. Check how the teacher console offers the way back to the parent area.
- **Platform:** Web.

### A-009 Parent who is also a student
- **Sees/does:** Active role `student` on web → immediate redirect to `/student/` (Next.js). Active role `parent` → parent shell with a two-chip switcher. From the Next.js student shell, "Switch to → Parent" writes `flutter.active_user_role = "parent"` and loads `/app/`.
- **Source:** RBD:349-356; apps/web/src/components/StudentDashboardHome.tsx:535-538, 805-834.
- **Data:** D1.
- **Rules:** R1.
- **Next.js:** `dashboardPathForUser` treats any account that has the student role and no admin/teacher role as "student only" → `/student/`, whatever `user_type` is. So a `user_type: parent` + `secondary_roles: ['student']` account that signs in through Next.js lands in the student dashboard first.
- **Platform:** Web.

### A-010 Adult students are not parents but share parent finance screens
- **Sees/does:** A student with `is_adult_student == true` gets a Finance section (Invoices, Payments) in the student sidebar; on phones an Invoices tab using `ParentInvoicesScreen(parentId: own uid)`. They never see the parent shell or the children list.
- **Source:** SBC:622-644; mobile_dashboard_screen.dart:560-572; apps/web/src/lib/userRoles.ts:31-33.
- **Data:** invoices matched on `student_id == uid` (the second listener in D10).
- **Rules:** R6, R7.
- **Next.js:** already ported for web students: `components/StudentInvoicesPage.tsx` (queries `parent_id == uid` and `student_id == uid`), `components/StudentPaymentsPage.tsx`. These are the closest reusable parent finance pieces.
- **Platform:** Both.

### A-011 Online presence heartbeat
- **Sees/does:** Nothing visible to the parent. While the dashboard is open the app marks the user online every 60 s (never more often than every 20 s) and offline when the tab is hidden/paused or the dashboard closes.
- **Source:** RBD:88-129.
- **Data:** write `users/{uid}.update({is_online: bool, last_seen: serverTimestamp})`.
- **Rules:** R2 (presence-only update).
- **Next.js:** check whether the student/teacher shells write `is_online`/`last_seen`; chat "online" dots for parents depend on it.
- **Platform:** Both.

### A-012 Role switch reloads the whole dashboard
- **Sees/does:** After a switch the screen shows the A-001 loader, then the dashboard for the new role.
- **Source:** RBD:293-301; LAYOUT:189-192, 212-215.
- **Data:** D1 (cache cleared first).
- **Rules:** R1.
- **Next.js:** SHELL `switchToRole` does a full page load to `/app/`.
- **Platform:** Web.

---

## 2. Shell: sidebar, header, role switcher, sign-out

### A-013 Two layouts at 900 px
- **Sees/does:** Window width ≥ 900: white top bar, fixed sidebar on the left, content on the right. Width < 900: top bar with a hamburger (tooltip `menu`) that opens the same sidebar as a drawer, always expanded; choosing an item closes the drawer.
- **Source:** LAYOUT:120-175.
- **Data:** none.
- **Rules:** n/a.
- **Next.js:** SHELL has a desktop sidebar (`lg:` breakpoint, 1024 px) and a mobile menu (`openStudentMobileMenu`). Differs: breakpoint 1024 vs 900.
- **Platform:** Web shell only.

### A-014 Top bar brand
- **Sees/does:** Logo image (40 px) + app title `appTitle` ("Alluwal Education Hub"). Clicking it returns to the Dashboard tab.
- **Source:** LAYOUT:226-252.
- **Data:** asset `assets/Alluwal_Education_Hub_Logo.png`.
- **Rules:** n/a.
- **Next.js:** SHELL sidebar brand; `/assets/Alluwal_Education_Hub_Logo.png` exists in the Next app.
- **Platform:** Web shell only.

### A-015 Screen index map (what each sidebar item opens)
- **Sees/does:** 0 Dashboard · 1 Invoices · 2 Payments · 3 Forms (`ParentFormsScreen`) · 4 Profile · 5 Settings · 6 Classes (`ParentClassesScreen`) · 7 Recordings (`ClassRecordingsScreen`) · 8 Circles (`TontineHomeScreen`, no sidebar item, see A-018) · 9 Curriculum Books · 10 Chat (`ChatPage`) · 11 Quran (`QuranReaderScreen`, unreachable, see A-019). Any other index shows the centred text `accessRestricted`.
- **Source:** LAYOUT:40, 85-118, 392-411.
- **Data:** per screen (other inventory parts).
- **Rules:** per screen.
- **Next.js:** student routes exist for forms, classes, recordings, curriculum-books, chat, quran, invoices, payments, profile under `apps/web/src/app/student/*`. Parent versions differ per screen (per-child data).
- **Platform:** Web shell only.

### A-016 All tabs are loaded at once and kept alive
- **Sees/does:** The shell builds all 11 screens when it opens (an `IndexedStack`), so every screen starts loading its data at sign-in, and switching tabs keeps each screen's scroll position, filters and loaded data. Coming back to Dashboard does not reload it. There is no URL per tab: browser Back does not move between tabs, and a page refresh always returns to Dashboard. The pushed screens (child detail, invoices from quick actions) cover the whole shell including the sidebar.
- **Source:** LAYOUT:152-163; PDS pushes via `Navigator.of(context).push`.
- **Data:** n/a.
- **Rules:** n/a.
- **Next.js:** SHELL uses real routes (`/student/...`). Differs by design: state is lost between pages, Back works, refresh stays on the page. Needs an explicit decision (section 11).
- **Platform:** Web shell only.

### A-017 Sidebar sections and items (default order)
- **Sees/does:** OVERVIEW: Dashboard · COMMUNICATION: Chat · LEARNING: Classes, Recordings, Curriculum Books, Quran · FINANCE: Invoices, Payments · FORMS: Forms · ACCOUNT: Profile, Settings. Section titles are upper-cased; each item has a coloured icon; the selected item has a light-blue background, bold label and a "…" icon.
- **Source:** SBC:479-603; CSB:511-726.
- **Data:** none.
- **Rules:** n/a.
- **Next.js:** SHELL `studentSections` (StudentDashboardHome.tsx:72-112) is the same shape. Parent differs in items and order (Chat second; Finance always shown; no Tasks/Quiz/Progress/AI Tutor/Surah Podcasts; has Profile and Settings items).
- **Platform:** Web shell only.

### A-018 Circles is hidden
- **Sees/does:** No Circles item for parents (`showCircles = false`), although screen 8 is still built in the background.
- **Source:** SBC:7, 559-566; LAYOUT:107-108.
- **Data:** whatever `TontineHomeScreen` loads at start-up.
- **Rules:** circles rules.
- **Next.js:** nothing to port while the flag is off.
- **Platform:** Web shell only.

### A-019 Quran item does nothing (broken)
- **Sees/does:** The Quran item is listed under LEARNING but clicking it has no effect: its index is 11 and the shell only accepts indexes 0-10 (`_screenCount = 11`), and screen 11 is never built.
- **Source:** SBC:532-538; LAYOUT:40, 113-114, 120-121, 157-160.
- **Data:** none.
- **Rules:** n/a.
- **Next.js:** `components/StudentQuranPage.tsx` exists for students. Owner decision needed: keep it dead, drop it, or make it work (section 11).
- **Platform:** Web shell only.

### A-020 Sidebar shows the wrong menu for an instant
- **Sees/does:** Until the role is loaded the sidebar is built with a null role, which falls back to the **student** menu; it then swaps to the parent menu. A click in that instant would hit a student index (for example student Chat = 5 = parent Settings).
- **Source:** LAYOUT:39, 49-60, 387; SBC:13-24; CSB:61-68.
- **Data:** D1.
- **Rules:** n/a.
- **Next.js:** do not reproduce.
- **Platform:** Web shell only.

### A-021 Collapse the sidebar to an icon rail
- **Sees/does:** Chevron in the sidebar header collapses it to a 72 px icon rail with tooltips; hovering the rail widens it to 200 px with labels; a chevron expands it again. The choice is remembered on this browser. In the drawer (narrow layout) it is always expanded and the chevron does nothing.
- **Source:** LAYOUT:62-83, 375-389; CSB:168-172, 728-1015.
- **Data:** SharedPreferences `parent_sidebar_collapsed` (web: localStorage `flutter.parent_sidebar_collapsed`).
- **Rules:** n/a.
- **Next.js:** check SHELL for a collapse control; if absent this is new work.
- **Platform:** Web shell only.

### A-022 Sidebar search, favourites, section folding, reorder, reset
- **Sees/does:** (a) "Search..." box filters sections/items by their displayed label, with a clear (x) button. (b) A star on each item pins it ("Pin"/"Unpin" tooltip); pinned items appear in a "Favorites" box above the list. (c) Clicking a section title folds/unfolds it; choosing an item folds the other sections unless the user opened them by hand. (d) The pencil icon switches to drag-to-reorder sections. (e) "Reset Layout" at the bottom restores order, folding and clears favourites. All of this is remembered on this browser.
- **Source:** CSB:77-165, 229-509; SBS:7-108.
- **Data:** SharedPreferences `admin_sidebar_preferences` (one key shared by every role on that browser: order, expansion, `favoritedItemIds`).
- **Rules:** n/a.
- **Next.js:** SHELL has favourites (`StudentSidebarFavorites`, `toggleFavoriteItem`). Search, reorder, section folding and reset need checking; storage key differs so existing parent preferences will not carry over.
- **Platform:** Web shell only.

### A-023 Role chip / role switcher in the top bar
- **Sees/does:** Small spinner while loading. One role: a single orange "Parent" chip (clicking it does nothing). Several roles: a pill group with one chip per role (Administrator red, Teacher blue, Parent orange, Student green); the active one is filled. Clicking another chip saves it as the active role, shows a floating snackbar "Switched to {Role} mode" for 2 s and reloads the dashboard (A-012). On failure: red snackbar `failedToSwitchRolePleaseTry`.
- **Source:** RSW:60-82, 187-375; URS:127-144, 294-311; LAYOUT:189-192, 212-215.
- **Data:** D1; writes SharedPreferences `active_user_role`.
- **Rules:** R1.
- **Next.js:** SHELL role pill + "Switch to" menu (StudentDashboardHome.tsx:805-840) and `ROLE_LABELS`. Differs: Next shows a dropdown of the *other* roles; Flutter shows all roles side by side. Role names and the snackbar are hard-coded English in Flutter.
- **Platform:** Web shell only (the widget is also used in other Flutter dashboards).

### A-024 Role switcher watches for role changes
- **Sees/does:** Every 30 s the switcher re-reads the user record from the server. If the account goes from several roles to one, it switches to the primary role, reloads, and shows an orange snackbar `adminPrivilegesHaveBeenRevoked` for 3 s (the text says "admin" even when a parent lost a different secondary role).
- **Source:** RSW:36, 84-185.
- **Data:** `users/{uid}` get with `Source.server`; fallback `users where e-mail == email limit 1`.
- **Rules:** R1.
- **Next.js:** no equivalent seen in SHELL (`useOtherRoles` reads once).
- **Platform:** Web shell only.

### A-025 Account menu in the top bar
- **Sees/does:** Round blue person icon (never a photo), the parent's "first last" name next to it on wide layouts only (falls back to "Parent"), a drop-down arrow. Menu: **Profile** (opens the Profile tab) and **Sign Out** in red.
- **Source:** LAYOUT:254-328.
- **Data:** D1 (`first_name`, `last_name`), re-read from the 5-minute cache on each rebuild.
- **Rules:** R1.
- **Next.js:** SHELL account menu with `StudentAvatar` (shows the profile photo when present) and language toggle. Differs: Flutter parent menu has no photo and no language entry.
- **Platform:** Web shell only.

### A-026 Sign out with confirmation
- **Sees/does:** Dialog titled `settingsSignOut` with `settingsSignOutConfirm` ("Are you sure you want to sign out?"), **Cancel** and a red **Sign Out**. On confirm: clears the role cache, replaces everything with the landing page, signs out of Firebase Auth, then on web leaves the Flutter app for the public site at `/`.
- **Source:** LAYOUT:330-373; core/utils/post_sign_out.dart:18-36.
- **Data:** `FirebaseAuth.signOut()`. The saved `active_user_role`, sidebar preferences and language stay in the browser. No `is_online: false` write is guaranteed (the heartbeat's offline write races the sign-out).
- **Rules:** n/a.
- **Next.js:** SHELL sign-out calls `clearStudentSession()`; a parent sign-out needs the same cache clear. Differs: check whether Next asks for confirmation.
- **Platform:** Web shell only.

### A-027 No unread badge for parents
- **Sees/does:** The sidebar supports a red dot on items, but the parent shell never passes any, so parents get no unread-chat dot.
- **Source:** CSB:15, 662; LAYOUT:376-388.
- **Data:** none.
- **Rules:** n/a.
- **Next.js:** SHELL shows a notification count on a bell; do not add a badge parents do not have today without asking.
- **Platform:** Web shell only.

### A-028 Text is selectable everywhere in the shell
- **Sees/does:** Content is wrapped in a selection area, so parents can select and copy text with the mouse. Because of that, mouse dragging does not scroll and does not trigger pull-to-refresh (see A-032).
- **Source:** LAYOUT:153-154; lib/main.dart:583-593.
- **Data:** n/a.
- **Rules:** n/a.
- **Next.js:** native browser behaviour.
- **Platform:** Web.

### A-029 Access-suspended screen is not used
- **Sees/does:** `AccessSuspendedScreen` ("Access Suspended … outstanding unpaid invoice", **Sign Out**) exists in the parent folder but nothing in the app opens it. A parent is never locked out; a parent with a suspended child sees the banner in A-034. (The file's own comment says it is for students.)
- **Source:** features/parent/screens/access_suspended_screen.dart:1-99 (no references anywhere in `lib/`).
- **Data:** none.
- **Rules:** n/a.
- **Next.js:** SESSION carries `accessSuspended` for students; nothing to port for parents.
- **Platform:** Dead code.

---

## 3. Home dashboard (`ParentDashboardScreen`)

### A-030 Which parent the dashboard is for
- **Sees/does:** Uses the signed-in uid. If no uid can be found the whole screen is one grey sentence: `unableToLoadParentAccountPlease` (English text is the auto-generated "Unable To Load Parent Account Please").
- **Source:** PDS:51-85, 124-136; LAYOUT:86-91.
- **Data:** D1 for the first name.
- **Rules:** R1.
- **Next.js:** SESSION pattern.
- **Platform:** Both.

### A-031 Greeting
- **Sees/does:** Heading "Welcome, {first_name}", or "Parent Dashboard" when the first name is empty. English only.
- **Source:** PDS:151-160.
- **Data:** D1 `first_name`.
- **Rules:** R1.
- **Next.js:** `StudentDashboardHome` greeting. Differs: wording.
- **Platform:** Both.

### A-032 Refresh
- **Sees/does:** Pull down to refresh (touch / trackpad). It re-runs the children query, restarts the money summary and suspension listeners, recomputes the family progress block, and asks the server to **regenerate** the attendance report (`forceRefresh: true`). Recent invoices and payments are live and are not touched. With a mouse on desktop there is no way to trigger it (no refresh button exists).
- **Source:** PDS:87-105, 142-145; lib/main.dart:583-593.
- **Data:** D2, D6, D3 per child, D5 with `forceRefresh: true`.
- **Rules:** R1, R3, R6, R7, R8.
- **Next.js:** `StudentProgressPage` has a refresh that calls the same callable with `forceRefresh`. A parent page needs an explicit refresh control to keep the "force regenerate" capability reachable.
- **Platform:** Both (gesture effectively touch-only).

### A-033 Section order on the page
- **Sees/does:** Top to bottom: greeting · suspension banner (only when needed) · money summary · two quick-action tiles · Family Progress Overview · Attendance Analytics · Children list · teachers' phone numbers · Recent Invoices · Recent Payments. Single column, 16 px padding, no maximum width.
- **Source:** PDS:148-511.
- **Data:** n/a.
- **Rules:** n/a.
- **Next.js:** new page inside a parent shell.
- **Platform:** Both.

### A-034 Suspension banner
- **Sees/does:** Only when at least one child is suspended: red box with a lock icon. Title "Platform access suspended" (one child) or "{n} students have been suspended". Body "{Name1, Name2} has/have lost platform access due to an unpaid invoice. Pay now to restore access immediately." Red button "View & pay invoices" opens the invoices screen filtered to Pending as a pushed page. Updates live. English only.
- **Source:** PDS:107-121, 162-243.
- **Data:** live `users where guardian_ids array-contains {uid} and access_suspended == true` (no `user_type` filter, no `guardianIds` fallback); name = `first_name last_name` or the doc id. `access_suspended` is set by functions/handlers/invoice_access.js.
- **Rules:** R1.
- **Next.js:** none for parents. SESSION reads `access_suspended` for the student's own record only.
- **Platform:** Both.

### A-035 Money summary card: Outstanding and Overdue
- **Sees/does:** Dark card titled `financialSummary` with a wallet icon and two boxes: `financialSummaryOutstanding` ("Outstanding") and `overdue`. For each invoice: paid = the larger of (sum of its `completed` payments) and the invoice's `paid_amount`; remaining = `total_amount` − paid; cancelled invoices and remaining ≤ 0 are skipped; Outstanding = sum of remaining; Overdue = sum of remaining where `due_date` is before now. Outstanding turns light blue when > 0, Overdue light red when > 0. Always formatted as US dollars (`$1,234.50`) whatever the invoice currency; mixed currencies are added without conversion. Updates live.
- **Source:** PDS:244-268; FSC:22-102; PS:105-158, 191-259.
- **Data:** D6. Invoice fields: `total_amount|totalAmount`, `paid_amount|paidAmount`, `status`, `due_date|dueDate`. Payment fields: `status`, `invoice_id|invoiceId`, `amount`.
- **Rules:** R6, R7. Needs the composite index `invoices(parent_id, issued_date desc)`.
- **Next.js:** `components/StudentInvoicesPage.tsx` loads the same invoices; `lib/finance/` may hold shared maths. Differs: no summary card exists for students; the summary counts only `parent_id == uid` invoices, while the invoice list (D10) also includes `student_id == uid`.
- **Platform:** Both.

### A-036 Money summary: Pay Now button
- **Sees/does:** Blue "Pay Now" button (card icon, text `payNow`) in the card header only when Outstanding > 0. Opens the invoices screen filtered to Pending as a pushed page.
- **Source:** PDS:254-265; FSC:63-78.
- **Data:** none extra.
- **Rules:** n/a.
- **Next.js:** link to the parent invoices route with a pending filter.
- **Platform:** Both.

### A-037 Money summary: loading and error
- **Sees/does:** No spinner and no error message: the card shows `$0.00` / `$0.00` until both listeners have answered, and keeps showing zeros if either fails. A total of more than 200 invoices or 500 payments is silently truncated.
- **Source:** PDS:246-250; PS:110-150.
- **Data:** D6.
- **Rules:** R6, R7.
- **Next.js:** decide whether to keep "zeros while loading" (a parent who owes money sees $0.00 for a moment) — section 11.
- **Platform:** Both.

### A-038 Quick action: Invoices
- **Sees/does:** White tile, receipt icon, title `invoices`, subtitle `viewAndPay` ("View And Pay"). Opens the full invoices screen (no filter) as a pushed page with its own back arrow, not the sidebar tab.
- **Source:** PDS:270-286, 2054-2121.
- **Data:** none.
- **Rules:** n/a.
- **Next.js:** link to the parent invoices route.
- **Platform:** Both.

### A-039 Quick action: Payments
- **Sees/does:** White tile, payments icon, title `payments`, subtitle `history`. Opens the payment history screen as a pushed page.
- **Source:** PDS:288-302.
- **Data:** none.
- **Rules:** n/a.
- **Next.js:** link to the parent payments route (`StudentPaymentsPage` is the student equivalent).
- **Platform:** Both.

### A-040 Family Progress: loading, error, empty
- **Sees/does:** Loading: dark-blue card with a white spinner and "Building family progress insights...". Error: red card "Failed to load progress insights: {raw error}". No children: grey card "Progress insights will appear here" / "Once classes are scheduled, you will see weekly and child-level progress charts." All English.
- **Source:** PDS:306-331, 934-966, 2244-2322.
- **Data:** D2 then D3 per child (30 days back to now).
- **Rules:** R1, R3.
- **Next.js:** none for a family view.
- **Platform:** Both.

### A-041 Family Progress: header and average ring
- **Sees/does:** Blue gradient card. Title `parentProgressTitle` ("Family Progress Overview"), subtitle `parentProgressSubtitle`. A white ring with "{n}%" and `parentProgressAvg` ("Avg"): the plain average of each child's 30-day attendance rate, counting only children with at least one completed/missed/cancelled class.
- **Source:** PDS:521-601, 1438-1532.
- **Data:** D3 per child with start = now − 30 days, end = now. Child rate = completed ÷ (completed + missed + cancelled), where completed = status `completed`, `fullyCompleted` or `partiallyCompleted`. Scheduled/active classes are ignored. This is the class's status (set by the teacher's clock-in), not whether the child joined.
- **Rules:** R3.
- **Next.js:** `StudentDashboardHome` has `countsTowardAttendance` / `attendedByStudent` helpers (lines 317-323) for one student — compare the formula before reusing; the parent version averages across children.
- **Platform:** Both.

### A-042 Family Progress: four metric tiles
- **Sees/does:** (1) `parentProgressChildren` = number of linked children, hint `parentProgressLinkedAccounts`. (2) `parentProgressClassesThisWeek` = classes of all children that started in the last 7×24 h, any status, hint `parentProgressLast7Days`. (3) `parentProgressLearningHours` = hours of completed classes in the last 30 days, one decimal (scheduled length, end − start), hint `parentProgressPast30Days`. (4) `parentProgressNeedsSupport` = number of children under 60 % attendance, hint `parentProgressAttendanceUnder60`; icon tint red when > 0, green when 0. Side by side when the card is ≥ 680 px wide, stacked below that.
- **Source:** PDS:562-600, 1534-1591, 2350-2353.
- **Data:** D3 per child.
- **Rules:** R3.
- **Next.js:** none.
- **Platform:** Both (stacking by width).

### A-043 Family Progress: Weekly Activity bars
- **Sees/does:** Box titled "Weekly Activity" with "{n} classes" on the right (always plural: "1 classes"). Seven bars for the last 7 calendar days ending today, each with its count above and a three-letter English day name below ("Mon"). Counts every class of every child that started that day up to today, any status. Bars animate in.
- **Source:** PDS:859-866, 1716-1828.
- **Data:** D3 per child.
- **Rules:** R3.
- **Next.js:** none; a small bar chart component is new work.
- **Platform:** Both.

### A-044 Family Progress: Top Subjects
- **Sees/does:** Only when there is at least one completed class: label `parentProgressTopSubjects` and up to 4 chips "{Subject} ({count})", ranked by completed-class count across all children in 30 days. Subject = `subject_display_name` or the legacy subject enum name; blank becomes "General".
- **Source:** PDS:582-594, 880-884, 1595-1632.
- **Data:** D3 per child.
- **Rules:** R3.
- **Next.js:** `lib/subjects.ts` for names.
- **Platform:** Both.

### A-045 Family Progress: Child Performance cards
- **Sees/does:** Label `parentProgressChildPerformance`, then one white card per child. Order: "Needs Support" first, then "Watch", then "On Track"; inside a group lowest attendance first. Each card: round initial, name, the child's top subject (or "No completed classes"), a coloured status pill — "On Track" (≥ 80 %), "Watch" (60-79 %, or no tracked classes), "Needs Support" (< 60 %); a green/red/grey bar split by completed/missed/cancelled counts (plain grey when nothing tracked); three figures: "Attendance" ("{n}%" or "--"), "Last 7 Days" ("{n} class"/"classes"), "Learning Hours" ("{x.x}h"); a trend line with arrow: "Stable vs previous week", "+{n} class activity vs previous week" or "-{n} class activity vs previous week" (last 7 days vs the 7 days before). All labels English. The cards are not clickable.
- **Source:** PDS:556-560, 811-932, 1643-1650, 1831-2052.
- **Data:** D3 per child.
- **Rules:** R3.
- **Next.js:** none; per-child card is new.
- **Platform:** Both.

### A-046 Attendance Analytics: loading, error, empty
- **Sees/does:** Loading: white card with spinner "Loading attendance analytics...". Error: red card "Failed to load attendance analytics: {raw error}". No children: grey card "Attendance analytics will appear here" / "Weekly and monthly attendance insights will show once classes and joins are recorded." English. A child whose report cannot be fetched is not an error: it appears with all zeros.
- **Source:** PDS:333-359, 603-622, 682-709, 968-998.
- **Data:** D2 then D5 per child.
- **Rules:** R8.
- **Next.js:** `components/StudentProgressPage.tsx` calls the same callable for one student (lines 267-290).
- **Platform:** Both.

### A-047 Attendance Analytics: Weekly / Monthly switch
- **Sees/does:** Title `parentAnalyticsTitle`, subtitle `parentAnalyticsSubtitleWeekly` or `…Monthly`, and two chips `parentAnalyticsWeekly` / `parentAnalyticsMonthly`. Starts on Weekly. Switching re-requests every child's report for the current UTC week (Mon-Sun) or current UTC month, using the server's cached report if one exists, and shows the loading card meanwhile. The choice is not remembered.
- **Source:** PDS:42, 763-809, 1000-1076, 1163-1190.
- **Data:** D5 with `forceRefresh: false`.
- **Rules:** R8.
- **Next.js:** `StudentProgressPage` has the same weekly/monthly toggle (lines 92, 167). Differs: one student vs each child in parallel.
- **Platform:** Both.

### A-048 Attendance Analytics: five family tiles
- **Sees/does:** (1) `studentAttendanceFamilyClassTime` = total presence minutes ÷ 60 as "{x.x} h". (2) `parentAnalyticsAttendanceAvg` = average of children's attendance rates, "{n}%". (3) `parentAnalyticsPunctualityAvg` = average punctuality, "{n}%". (4) `parentAnalyticsLateClasses` = sum of late classes. (5) `parentAnalyticsTeacherAbsent` = sum of "student present, teacher absent" classes. Averages count only children with at least one scheduled class in the period. In a row at ≥ 680 px, stacked below.
- **Source:** PDS:640-679, 1078-1140, 1192-1243.
- **Data:** D5 fields `metrics.total_student_presence_minutes`, `rates.attendance_rate` (fallback attended ÷ scheduled), `rates.punctuality_rate` (fallback on-time ÷ attended), `metrics.late_classes`, `metrics.student_present_teacher_absent_classes`; rates clamped to 0-1.
- **Rules:** R8.
- **Next.js:** `StudentProgressPage` `fetchAnalytics` parses the same fields with the same fallbacks. Differs: family totals/averages do not exist there.
- **Platform:** Both.

### A-049 Attendance Analytics: By Child cards
- **Sees/does:** Label `parentAnalyticsByChild`, one card per child, lowest attendance first (ties: more scheduled classes first). Each: name; pill `parentAnalyticsAttendancePercent` ("{n}% attendance"); inline figures Scheduled, Attended, Absent, Late (as a % of attended classes), Teacher Absent, Early Joins; two progress bars `parentAnalyticsAttendance` and `parentAnalyticsPunctuality` with "{n}%"; a small line "Avg join offset: {On time | x.x min early | x.x min late} • Class time: {x.x} h • Overlap: {x.x} min". Not clickable.
- **Source:** PDS:634-638, 711-761, 1152-1158, 1245-1436.
- **Data:** D5 fields `metrics.scheduled_classes`, `attended_classes`, `absent_classes`, `late_classes`, `on_time_classes`, `student_present_teacher_absent_classes`, `total_joins_before_start_events`, `total_student_presence_minutes`, `total_teacher_overlap_minutes`; `rates.late_rate`; `averages.average_join_offset_minutes` (negative = early).
- **Rules:** R8.
- **Next.js:** `StudentProgressPage` shows the same metrics as rows for one student (lines 246-256) plus a class-by-class list parents do not have today.
- **Platform:** Both.

### A-050 Children list
- **Sees/does:** White card headed by a family icon and `children`. One row per child (alphabetical): round initial, name (or "Student"), "ID: {student code or kiosk code}" when there is one, and a chevron. Clicking a row opens the child detail screen (section 4) as a pushed page. Loading: centred spinner. Error: red card "Failed to load children: {raw error}".
- **Source:** PDS:361-392; CLW:16-113.
- **Data:** D2.
- **Rules:** R1.
- **Next.js:** none. `lib/familyGroups.ts` and `components/UsersAdmin.tsx` use `guardian_ids` on the admin side.
- **Platform:** Both.

### A-051 Children list: empty state
- **Sees/does:** Grey info row with `noChildrenLinkedToThisParent` ("No Children Linked To This Parent"). No contact or next step is offered.
- **Source:** CLW:17-42.
- **Data:** D2.
- **Rules:** R1.
- **Next.js:** none.
- **Platform:** Both.

### A-052 Teachers' phone numbers card
- **Sees/does:** White card with a green phone icon, title `classContactsParentTitle` ("Your children's teachers") and helper `classContactsParentHelper`. For each child: the child's name and its teachers, each with name, "Teacher", phone number, a call button (opens `tel:`; tooltip "Call {name}") and a copy button (tooltip "Copy number", snackbar "Number copied"); "No phone number on file" when a child has no reachable teacher. The card takes no space while loading and when the parent has no children with contacts. If the call fails: "Could not load phone numbers." with **Retry**.
- **Source:** PDS:394-397; CCC:9-320; core/services/class_contacts_service.dart.
- **Data:** D12.
- **Rules:** R8.
- **Next.js:** `components/ClassContactsCard.tsx` + `lib/classContacts.ts` already exist and already parse the `children` groups. Likely reusable as is with the parent variant.
- **Platform:** Both.

### A-053 Recent Invoices: header and list
- **Sees/does:** Header `recentInvoices` with a "See all" link (English) that opens the full invoices screen as a pushed page. Below: up to 5 invoice cards, latest due date first. Loading: spinner. Error: red card "Failed to load invoices: {raw error}". Empty: grey card `noInvoicesYet` / `whenInvoicesAreCreatedTheyWill` (auto-generated English "When Invoices Are Created They Will").
- **Source:** PDS:398-468.
- **Data:** D10.
- **Rules:** R6. Needs composite index `invoices(parent_id, due_date desc)`.
- **Next.js:** `components/StudentInvoicesPage.tsx` (same two queries, lines 102 and 115).
- **Platform:** Both.

### A-054 Recent Invoices: what each card shows
- **Sees/does:** Coloured left bar and status badge: OVERDUE (red, whenever unpaid and past due), PAID (green), PENDING (amber), CANCELLED (grey). Invoice number (or "Invoice"). Billing period line when known. "Amount due" with the remaining balance in the invoice's own currency (green when zero). Due chip: "MMM d" (e.g. "Nov 5") or "{n} day(s) overdue" in red. For unpaid, non-cancelled invoices an access-cutoff strip when the cutoff is within 14 days or past: "Access cut off in {n} days", "Access cut off tomorrow", "Access suspended today", "Access suspended {n} day(s) ago" (cutoff = `access_cutoff_date`, else due date + 1 day). A full-width "Pay Now" button unless the invoice is fully paid or cancelled. Clicking the card opens the invoice detail; "Pay Now" opens the payment screen. No child name is shown on the dashboard cards. Text is selectable. All fixed labels English.
- **Source:** PDS:435-465; ICW:24-405; features/parent/models/invoice.dart:235-270.
- **Data:** invoice fields `invoice_number`, `status`, `total_amount`, `paid_amount`, `currency`, `due_date`, `period_start`/`period_end`/`period`, `access_cutoff_date`.
- **Rules:** R6.
- **Next.js:** `StudentInvoicesPage` card; `Pay` there calls `createPaymentSession {invoiceId}` (line 175). Compare badge rules and the cutoff strip one by one.
- **Platform:** Both.

### A-055 Recent Payments: header and list
- **Sees/does:** Header `recentPayments` with "See all" → payment history screen (pushed). One white card with up to 5 rows, newest first: a status dot (green completed, red failed, blue processing, amber pending), the amount formatted as dollars (ignores currency), a grey line "{STATUS} • {MMM d, yyyy}" (status in capitals, e.g. "COMPLETED • Nov 5, 2026"; date omitted if missing) and a chevron. Loading: spinner. Empty: `noPaymentsYet` / `paymentHistoryWillAppearOnceYou`. If the query fails the spinner never ends (the error is swallowed before it reaches the screen).
- **Source:** PDS:469-509, 2154-2242; payment_service.dart:14-37.
- **Data:** D11. Fields `amount`, `status`, `created_at`, `invoice_id`.
- **Rules:** R7. Needs composite index `payments(parent_id, created_at desc)`.
- **Next.js:** `components/StudentPaymentsPage.tsx` (line 81 queries by several owner fields).
- **Platform:** Both.

### A-056 Recent Payments: open the invoice behind a payment
- **Sees/does:** Clicking a payment row looks up its invoice. Found: opens the invoice detail. Not found: snackbar `invoiceNotFoundForThisPayment`. A payment with no invoice id does nothing. If the read is refused (invoice belongs to someone else) nothing happens and nothing is shown.
- **Source:** PDS:2191-2213.
- **Data:** `invoices/{invoice_id}` get.
- **Rules:** R6.
- **Next.js:** link to the invoice detail route.
- **Platform:** Both.

### A-057 Raw error text is shown to parents
- **Sees/does:** Every error card on this page prints the technical exception after an English prefix, e.g. "Failed to load children: [cloud_firestore/permission-denied] …".
- **Source:** PDS:316, 343, 373, 424, 496, 2297-2322.
- **Data:** n/a.
- **Rules:** n/a.
- **Next.js:** owner decision: keep raw text or use plain messages (section 11).
- **Platform:** Both.

---

## 4. Child detail (`StudentDetailScreen`) and its tabs

### A-058 Screen frame and tabs
- **Sees/does:** Full-page screen over the shell. White bar with a back arrow and the child's name as title. Four tabs: `overview`, `dashboardClasses` ("Classes"), `navTasks` ("Tasks"), `progress`. Tabs can be swiped. Each tab has its own pull-to-refresh that simply rebuilds the tab (re-running its one-shot loads). Tab choice is not remembered; reopening starts at Overview.
- **Source:** SDS:26-104.
- **Data:** receives `studentId`, `studentName`, `parentId` (the last is never used).
- **Rules:** n/a.
- **Next.js:** new route such as `/parent/children/{id}` with tab state. Nothing equivalent exists.
- **Platform:** Both.

### A-059 No check that the child belongs to the parent
- **Sees/does:** The screen shows whatever student id it is given. It is only reachable from the parent's own children list, so parents see only their children, but nothing on this screen or in rules R3/R5 enforces it.
- **Source:** SDS:10-20; R3, R5.
- **Data:** n/a.
- **Rules:** R3, R5 (wide).
- **Next.js:** a URL with a child id is user-editable, so the page must verify the id is in D2 before loading (stricter than today, same visible behaviour).
- **Platform:** Both.

### Overview tab

### A-060 Quick stats row
- **Sees/does:** White card with three figures: `totalClasses` = every past class of the child still in `teaching_shifts` (any status; see A-112); `studentQuickStatsAttendance` = 30-day completed ÷ (completed + missed + cancelled) as a whole percent; `studentQuickStatsTasksdone` = "{done}/{total}" tasks. Loading: spinner. Error: red card "Failed to load statistics: {raw error}".
- **Source:** OVT:44-74, 245-256; QSC:20-61; PS:328-394.
- **Data:** D3 (30 days) for the rate; D3 with no start for the total; first emission of D7 for tasks.
- **Rules:** R3, R5.
- **Next.js:** `StudentDashboardHome` `StatCard`s for the student's own numbers. Differs: definitions (compare formulas), per-child.
- **Platform:** Both.

### A-061 Today's Classes
- **Sees/does:** Heading "Today's Classes" (English). One class card (A-066…A-072) per class starting today (device-local midnight to midnight), earliest first. Empty: `noClassesToday` / `yourChildHasNoScheduledClasses`. A failed query looks the same as "no classes".
- **Source:** OVT:76-116; SHS:2981-3008.
- **Data:** `teaching_shifts where student_ids array-contains {childId} and shift_start >= startOfToday and shift_start < startOfTomorrow` one-shot; client keeps `teaching` category.
- **Rules:** R3. Composite index `teaching_shifts(student_ids array, shift_start)`.
- **Next.js:** `components/StudentClassesPage.tsx` (lines 113-115) runs the same query shape for the signed-in student. Parent version passes the child id.
- **Platform:** Both.

### A-062 Upcoming Classes preview
- **Sees/does:** Heading "Upcoming Classes". The first 5 classes starting from now within the next 7 days, earliest first, as class cards. A class already in progress is not here (it is in Today's Classes). Empty: `noUpcomingClasses` / `yourChildHasNoUpcomingClasses`.
- **Source:** OVT:119-161; SHS:2905-2978.
- **Data:** `teaching_shifts where student_ids array-contains {childId} and shift_start >= now and shift_start < now+7d` one-shot; if the index is missing, falls back to fetching all the child's classes and filtering in memory.
- **Rules:** R3.
- **Next.js:** `StudentClassesPage`.
- **Platform:** Both.

### A-063 Recent Activity
- **Sees/does:** Heading "Recent Activity". Up to two rows: (a) green school icon, `lastClassCompleted`, the subject, and "MMM dd, yyyy • h:mm a" of the most recent class whose status is exactly `completed`; (b) blue icon, `lastTaskCompleted`, the task title and its completion date "MMM dd, yyyy" (or "Recently"). Empty: `noRecentActivity` / `activityWillAppearHereAsYour`. Classes marked fully or partially completed are ignored here (a string test on the status name misses them), and a missing subject name prints the raw enum text (e.g. "IslamicSubject.quranStudies").
- **Source:** OVT:164-239.
- **Data:** D7; D3 with no start.
- **Rules:** R3, R5.
- **Next.js:** none.
- **Platform:** Both.

### Class card (`ParentPresenceCard`) — used in Overview and Classes tabs

### A-064 Status badge
- **Sees/does:** Badge with icon and text: "In Progress" (green) when status is active, or scheduled-but-clocked-in; "Completed" (grey) for completed / partially / fully completed; "Cancelled" (red); "Missed" (amber) for status missed **or** a still-`scheduled` class whose start time has passed; "Scheduled" (blue) otherwise. English only. Active cards have a thicker green border.
- **Source:** PPC:35-36, 71-127.
- **Data:** shift `status`, `clock_in_time`, `clock_out_time`, `shift_start`.
- **Rules:** R3.
- **Next.js:** `StudentClassesPage` status chips; compare the "scheduled but start passed = Missed" rule.
- **Platform:** Both.

### A-065 Card body
- **Sees/does:** Start time "h:mm a" top right; subject name (or raw enum text when no display name); "Teacher: {name}" (or "Unknown"); date "EEEE, MMM d, yyyy" (English day/month names). Times are in the device's time zone.
- **Source:** PPC:197-252.
- **Data:** shift `subject_display_name`/`subject`, `teacher_name`, `shift_start`.
- **Rules:** R3.
- **Next.js:** `StudentClassesPage` class rows; `lib/timezones.ts` for display.
- **Platform:** Both.

### A-066 Live participants panel
- **Sees/does:** Only on an in-progress card: a pill "{n} in class" next to the badge (when n > 0) and a panel `liveParticipants` with a green dot and "{n} in class" (a small spinner until the first answer). Each participant: mic icon (on/off), name, role ("teacher"/"student"), and how long they have been in ("Just joined", "12m", "1h 5m"). Nobody there: italic `noOneHasJoinedYet`. Under the panel: `tapAndHoldForMoreDetails`. Refreshes every 15 seconds. A parent can therefore see the names of the other students in a group class.
- **Source:** PPC:38-65, 163-195, 254-401, 457-461.
- **Data:** D8 on open and every 15 s, only if the class was already in progress when the card was first drawn.
- **Rules:** R8.
- **Next.js:** `lib/presenceReport.ts` and the teacher/admin class pages use presence; `StudentClassesPage` references the same callable set. No parent panel exists.
- **Platform:** Both.

### A-067 Join button
- **Sees/does:** Green full-width button with a camera icon: "Join Now" when the class is in progress, "Join Class" when not in progress but inside the window from 10 minutes before the start to 10 minutes after the end. Hidden otherwise, and hidden for classes without students or non-teaching shifts. Clicking anywhere on the card does the same as the button. It appears on history cards too if they are still inside the window.
- **Source:** PPC:72-75, 129-131, 403-431; CVS:282-290; teaching_shift.dart:239-240.
- **Data:** shift `shift_start`, `shift_end`, `shift_category`, `student_ids`.
- **Rules:** R3.
- **Next.js:** `StudentClassesPage` + `lib/zoomJoinRouting.ts`. Parent differs: joins a class the parent is not a member of.
- **Platform:** Both.

### A-068 What happens on Join
- **Sees/does:** Checks in order, each with a snackbar: class has no video (`classVideoJoinUnavailable`, orange); not signed in (`pleaseSignInAgainToJoin`, red); not allowed (`youAreNotAssignedToThis`, red — any account whose active role is parent passes this client check; the server decides); outside the window (`classVideoOpensInMinutes(n)` or `classVideoEnded`, orange). Then a "connecting" dialog, then the Zoom classroom screen (or the RealtimeKit screen for non-Zoom classes). A hub that is restarting shows a waiting dialog that retries by itself. Failures show the server's message or `classVideoConnectFailed` in red.
- **Source:** OVT:107-111; CLT:167-171; CVS:541-780.
- **Data:** D9 with `activeRole: 'parent'`. Server refuses unless the caller is the parent of an assigned student (realtimekit.js:334-344).
- **Rules:** R8.
- **Next.js:** `components/StudentClassroomPage.tsx`, `lib/classroomErrorText.ts`, `lib/classroomReconnect.ts`. Parent differs: must send the parent role and join for a specific child's class. Detailed join behaviour belongs to the Classes inventory part.
- **Platform:** Both (desktop web may prefer the Zoom desktop app, CVS:851-860).

### A-069 Long-press details sheet
- **Sees/does:** Press and hold a card (mouse: hold the button) → bottom sheet at 60 % height, draggable 40-90 %. Header: subject, a red "LIVE" pill when in progress, "EEEE, MMMM d, yyyy • h:mm a". Sections: **Teacher** (Name; "Clocked in" time; "Time in class" while live) · **Assigned Students ({n})** listing every assigned student's name (or "{n} assigned") · **Currently in Class ({n})** when someone is in (name, role or "Participant", "Joined h:mm a · 12m") · **Class Information** (Duration "{x.x} hours", Subject, Status as the raw status name in capitals e.g. "PARTIALLYCOMPLETED", Notes when the class has notes). A green "Join Class Now"/"Join Class" button when joining is possible. Labels English.
- **Source:** PPC:132, 438-455, 468-791.
- **Data:** shift `teacher_name`, `clock_in_time`, `student_ids`, `student_names`, `notes`, status; presence from A-066 as last fetched (not refreshed inside the sheet).
- **Rules:** R3.
- **Next.js:** `StudentProgressPage` has a `ClassDetailDialog`; contents differ. Note: `notes` are the admin/teacher's class notes and are shown to parents today.
- **Platform:** Both.

### A-070 Live panel can stay on a spinner
- **Sees/does:** If a card was already on screen as "Scheduled" and the class then starts (the Classes tab's Upcoming list is live), the card turns "In Progress" and shows the live panel, but the participant list never loads: the header spinner stays until the screen is reopened or refreshed.
- **Source:** PPC:38-47 (the 15 s timer is only started when the card is first created).
- **Data:** D8 never called in that case.
- **Rules:** n/a.
- **Next.js:** do not reproduce; start polling when the class becomes active.
- **Platform:** Both.

### Classes tab

### A-071 Upcoming / History switch
- **Sees/does:** Two-segment control "Upcoming" | "History" (English), Upcoming selected first. It changes the list below and its heading ("Upcoming Classes" / "Class History"). The calendar stays in both modes.
- **Source:** CLT:26-88, 90-131.
- **Data:** none.
- **Rules:** n/a.
- **Next.js:** `StudentClassesPage` — check its tab structure.
- **Platform:** Both.

### A-072 Attendance Calendar
- **Sees/does:** Heading "Attendance Calendar". A month grid for the **current month only** (no previous/next buttons), title "MMMM yyyy", columns Mon-Sun (English, week starts Monday). Each day with a class is tinted by its most significant class: completed (green) beats missed (red) beats cancelled (grey) beats scheduled (blue); a class in progress gives no tint. Today has a blue outline. Legend: Completed, Missed, Scheduled, None (cancelled has a tint but no legend entry). No loading state: the grid is blank until data arrives. Days are not clickable.
- **Source:** CLT:28, 62-75; CAL:21-216.
- **Data:** D4 (live, teaching classes only).
- **Rules:** R3.
- **Next.js:** none in the student pages; new component.
- **Platform:** Both.

### A-073 Upcoming list
- **Sees/does:** Every class of the child that has not ended yet (so a class in progress is included), earliest first, with no limit and no date cap, as class cards. Live: new or changed classes appear without refreshing. Loading: spinner. Empty: `noUpcomingClasses` / `yourChildHasNoUpcomingClasses`. Stream errors are swallowed, so an error shows as an endless spinner.
- **Source:** CLT:133-176.
- **Data:** D4 filtered `shift_end > now`.
- **Rules:** R3.
- **Next.js:** `StudentClassesPage` (bounded by a lower date, line 115). Differs: live listener vs one-shot; unlimited.
- **Platform:** Both.

### A-074 Class History list
- **Sees/does:** Every class that has started (start time before now) and is still in `teaching_shifts`, newest first, as class cards, no paging. A class in progress appears in both Upcoming and History. Not live (reloads on pull-to-refresh). Empty: `noClassHistory` / `completedClassesWillAppearHere`. A failed query looks like the empty state.
- **Source:** CLT:179-217; PS:286-325.
- **Data:** D3 with no start date (see D3 note: no 30-day limit is actually applied; no category filter).
- **Rules:** R3; R4 blocks the archive, so history stops at roughly 60 days.
- **Next.js:** `StudentClassesPage`; check whether students see more history than this. `lib/shifts.ts` may hold archive-aware readers for admin only.
- **Platform:** Both.

### Tasks tab

### A-075 Task counters
- **Sees/does:** White card with four numbers: "Total", "Completed" (status done), "Pending" (not done and due now or later), "Overdue" (not done and due before now). Hidden until the tasks have loaded. English.
- **Source:** TKT:42-66, 126-180.
- **Data:** D7.
- **Rules:** R5.
- **Next.js:** `components/StudentTasksPage.tsx` (line 369 `tasks where assignedTo array-contains uid limit 100`). Differs: Flutter has no limit.
- **Platform:** Both.

### A-076 Task filter
- **Sees/does:** Four-segment control "All" | "Pending" | "Completed" | "Overdue" using the same definitions as the counters. Starts on All; not remembered.
- **Source:** TKT:27, 183-259.
- **Data:** D7.
- **Rules:** R5.
- **Next.js:** `StudentTasksPage` has tabs ("my" etc.); mapping differs.
- **Platform:** Both.

### A-077 Task list and card
- **Sees/does:** Newest-created first. Each card: title (1 line), description (2 lines), priority badge "High"/"Med"/"Low", status badge "Done"/"In Progress"/"To Do", calendar icon + due date "MMM dd, yyyy" (red plus an `overdue` pill when late and not done), a paperclip with the number of attachments when there are any. Loading: spinner. Error: red card "Failed to load tasks: {raw error}". Empty: `noTasksFound` with "Your child has no tasks assigned." (All) or "No tasks match the selected filter."
- **Source:** TKT:73-120; TKC:22-239.
- **Data:** D7 fields `title`, `description`, `priority`, `status`, `dueDate`, `attachments[]`, `createdBy`, `createdAt`.
- **Rules:** R5.
- **Next.js:** `StudentTasksPage` cards. Parent version is strictly read-only.
- **Platform:** Both.

### A-078 "Assigned by" line (broken text)
- **Sees/does:** When the creator's name can be found, a line with a person icon shows the literal text "Assigned By Assignedbyname" (French: "Assigné par Nom"). The real name is looked up but never inserted.
- **Source:** TKT:103-114, 262-288; TKC:136-151; lib/l10n/app_en.arb:1222.
- **Data:** `users/{task.createdBy}` get per task (cached per tab while open).
- **Rules:** R1.
- **Next.js:** owner decision: show the real name (a fix) or drop the line (section 11).
- **Platform:** Both.

### A-079 Tasks are read-only for parents
- **Sees/does:** Cards do not open. A parent cannot see attachment files, comments, or change a status.
- **Source:** TKT:108-111 (no `onTap` passed); TKC:12, 31.
- **Data:** none.
- **Rules:** R5 (writes admin only).
- **Next.js:** `StudentTasksPage` lets the student update status via `updateAssignedTaskStatus` (line 147) — must be disabled in a parent view.
- **Platform:** Both.

### Progress tab

### A-080 Loading and error
- **Sees/does:** Loading: dark-blue card, white spinner, "Loading student progress insights...". Error: red card "Failed to load progress: {raw error}". Live: figures update when a class changes.
- **Source:** PGT:26-48, 898-929, 985-1010.
- **Data:** D4; only classes whose start is before now are counted.
- **Rules:** R3.
- **Next.js:** `components/StudentProgressPage.tsx` is the student's progress page but is built on the **join-based** server report (D5), not on class status. Not interchangeable (see A-111).
- **Platform:** Both.

### A-081 Hero card
- **Sees/does:** Blue gradient card: "{Child name} Progress", "A focused view of attendance, study volume, and class consistency.", and a ring with "{n}%" and "Attendance" = 30-day completed ÷ (completed + missed + cancelled). Shows 0 % when nothing is tracked (the breakdown card below shows "--" for the same case).
- **Source:** PGT:93-208, 232-333.
- **Data:** D4.
- **Rules:** R3.
- **Next.js:** none matching.
- **Platform:** Both.

### A-082 Four hero tiles
- **Sees/does:** "Classes (7d)" = classes started in the last 7×24 h (any status); "Hours (30d)" = hours of completed classes, one decimal; "Subjects" = distinct subjects with a class in the last 30 days; "Status" = "On Track" (≥ 80 %), "Watch" (60-79 % or no data), "Needs Support" (< 60 %) with matching tint. In a row at ≥ 620 px card width, stacked below.
- **Source:** PGT:137-167, 222-230, 336-388.
- **Data:** D4.
- **Rules:** R3.
- **Next.js:** none.
- **Platform:** Both (stacking by width).

### A-083 Weekly Activity bars and trend
- **Sees/does:** Same 7-bar chart as A-043 for this child ("Weekly Activity", "{n} classes", labels Mon…Sun). Below it a trend line: "Stable class activity vs previous week", "+{n} class activity vs previous week" or "-{n} class activity vs previous week".
- **Source:** PGT:145-156, 390-412, 468-585.
- **Data:** D4.
- **Rules:** R3.
- **Next.js:** none.
- **Platform:** Both.

### A-084 Attendance Breakdown (30 days)
- **Sees/does:** White card "Attendance Breakdown (30 days)" with "{n}%" (or "--" when nothing tracked), a green/red/grey split bar, and four figures: "Completed", "Missed", "Cancelled", "Tracked".
- **Source:** PGT:587-733.
- **Data:** D4.
- **Rules:** R3.
- **Next.js:** `StudentProgressPage` "Class Status Breakdown" section (line 237) is similar in intent but sourced from D5.
- **Platform:** Both.

### A-085 Subject Performance
- **Sees/does:** Heading "Subject Performance". Up to 6 subjects, most classes first, counted over every past class still in `teaching_shifts` (not just 30 days). Each card: subject name, chip "{n}% completed" (completed ÷ all past classes of that subject; green ≥ 80, amber ≥ 60, red below), a progress bar, and "Classes", "Completed", "Hours" ("{x.x}h"). Empty: `noSubjectData` / `subjectPerformanceWillAppearHereAs`.
- **Source:** PGT:63-84, 111-135, 174-186, 736-862.
- **Data:** D4.
- **Rules:** R3; R4 limits the range.
- **Next.js:** none.
- **Platform:** Both.

---

## 5. Profile (`ParentProfileScreen`)

### A-086 Loading
- **Sees/does:** Centred spinner while the record loads. If loading fails: red snackbar `failedToLoadProfileE` (literally "Failed To Load Profile E") and an empty form.
- **Source:** PPS:42-73, 134-140.
- **Data:** D1.
- **Rules:** R1.
- **Next.js:** `components/StudentProfilePage.tsx` reads the same record (lines 58-61).
- **Platform:** Web shell only (phones have no Profile entry in the parent tabs).

### A-087 Header card
- **Sees/does:** Round person icon (no photo), full name (or "Parent"), email. The name here only updates after a save, not while typing.
- **Source:** PPS:169-216.
- **Data:** D1 `first_name`, `last_name`, `e-mail|email` (else the sign-in email).
- **Rules:** R1.
- **Next.js:** `StudentProfilePage` shows a photo with upload to Storage `profile_pictures/{uid}/…` and writes `profile_picture_url`. Parent profile has **no** photo feature today.
- **Platform:** Web shell only.

### A-088 Editable fields
- **Sees/does:** Section `personalInformation`: First name and Last name side by side (both required; errors "First name is required" / "Last name is required" in English), Email (greyed out, hint "Email cannot be changed"), Phone (`userPhone`, optional, phone keyboard, no format check). Placeholder "Enter {label}".
- **Source:** PPS:219-287, 328-386.
- **Data:** D1.
- **Rules:** R1.
- **Next.js:** `StudentProfilePage` is read-only for name/phone. Parent needs an editable form: new work.
- **Platform:** Web shell only.

### A-089 Save
- **Sees/does:** Blue full-width button `timesheetSaveChanges` ("Save Changes"); shows a white spinner and is disabled while saving. Success: green floating snackbar with a tick, `profileUpdatedSuccessfully`, then the form reloads. Failure: red snackbar `failedToSaveProfileE` (literally "Failed To Save Profile E"; the real reason is not shown). The name in the top bar may not update until the shell redraws.
- **Source:** PPS:76-131, 289-320.
- **Data:** write `users/{auth.uid}.update({first_name, last_name, phone_number, updated_at: serverTimestamp})` (values trimmed). Always targets the doc whose id is the auth uid, even when D1 found the record under another id (then the save fails).
- **Rules:** R2.
- **Next.js:** none for parents. Check side effects of a phone change: `getClassContacts` reads `phone_number`, and rules mention a server-only `known_phones` collection.
- **Platform:** Web shell only.

### A-090 Back arrow inside a tab (looks broken)
- **Sees/does:** The Profile tab draws its own white bar titled `profileEditProfile` ("Edit Profile") with a back arrow, under the shell's top bar. The arrow calls "go back" although the screen was not opened as a page; with nothing above the dashboard this pops the dashboard itself. Needs a live check of what the parent actually sees.
- **Source:** PPS:144-158; LAYOUT:98-99.
- **Data:** n/a.
- **Rules:** n/a.
- **Next.js:** do not reproduce; owner to confirm (section 11).
- **Platform:** Web shell only.

---

## 6. Settings (`RoleSettingsScreen`, title "Parent Settings")

### A-091 Header
- **Sees/does:** Dark card with a gear icon, title `parentSettings` ("Parent Settings" / "Paramètres parent") and subtitle `accountSettingsBuildInfo` — auto-generated text "Account Settings Build Info" (French: "Configuration du compte Construisez l'information").
- **Source:** LAYOUT:100-102; RSS:16-37, 399-450.
- **Data:** none.
- **Rules:** n/a.
- **Next.js:** `components/TeacherSettingsPage.tsx` is the nearest settings page.
- **Platform:** Web shell only (phones use `MobileSettingsScreen`).

### A-092 Language
- **Sees/does:** Card with a globe icon, `languageTitle` ("Language"), `selectLanguageTitle` ("Choose language") and a two-button selector "English" | "Français" (Arabic exists in the code but is switched off). Choosing one changes the whole app at once, is saved on this browser, and is saved to the account so it follows the parent to other devices and to the Next.js pages.
- **Source:** RSS:43-146; LNG:20-24, 106-130.
- **Data:** SharedPreferences `language_code`; write `users/{uid}.update({language_preference: 'en'|'fr'})`. On sign-in the account value wins over the browser value (LNG:43-57).
- **Rules:** R2.
- **Next.js:** I18N — `lib/i18n.ts:34` writes `{language_preference, language_updated_at}` with merge; `components/LanguageSwitch.tsx`; SESSION carries `language`. Reusable. Differs: Next also writes `language_updated_at`.
- **Platform:** Web shell only.

### A-093 Change password
- **Sees/does:** Card "Change Password" / "Update your account password" with a blue "Change" button. Dialog "Change Password" with three fields, each with a show/hide eye: "Current Password" (required: "Enter your current password"), "New Password" ("Enter a new password"; "Password must be at least 6 characters"), "Confirm New Password" ("Passwords do not match"). Buttons "Cancel" and "Update Password" (spinner while saving). Success: dialog closes, green snackbar "Password changed successfully." Errors as a red snackbar: "Current password is incorrect." (code `wrong-password`), "New password is too weak." (`weak-password`), otherwise "Failed to change password." Any non-auth error just stops the spinner with no message; an account with no email cannot use it and gets no message. All English.
- **Source:** RSS:148-397.
- **Data:** Firebase Auth `reauthenticateWithCredential(EmailAuthProvider(email, currentPassword))` then `updatePassword(newPassword)`. No Firestore write.
- **Rules:** n/a.
- **Next.js:** `TeacherSettingsPage` has the same re-authenticate + `updatePassword` flow (lines 6-8, 173). Reusable. Note: current Firebase returns `invalid-credential` for a wrong password, which in Flutter falls into the generic "Failed to change password."
- **Platform:** Web shell only.

### A-094 Version line
- **Sees/does:** Card with the label `newVersion` ("New Version" — a mislabel) and the web build version string, or "Not set".
- **Source:** RSS:17-18, 453-486; core/constants/build_info.dart.
- **Data:** compile-time `WEB_BUILD_VERSION`.
- **Rules:** n/a.
- **Next.js:** owner decision whether parents need a version line.
- **Platform:** Web shell only.

### A-095 What Settings does not have
- **Sees/does:** No notification preferences, no delete-account, no sign-out button, no profile photo, no theme, no time-zone setting. The page is not scrollable (may clip on a very short window).
- **Source:** RSS:20-37 (the whole page is header + language + password + version).
- **Data:** n/a.
- **Rules:** n/a.
- **Next.js:** `TeacherSettingsPage` has notification preferences (`notificationPreferences.*`); do not add them for parents without asking.
- **Platform:** Web shell only.

---

## 7. `ParentService` reference (every method)

### A-096 `getParentChildren(parentId)`
- **Sees/does:** Feeds the children list, both dashboard analytics blocks, and the Parent Classes screen.
- **Source:** PS:32-80. Callers: PDS:65, 90; parent_classes_screen.dart:40.
- **Data:** D2. Link fields: the **child's** `guardian_ids` array contains the parent's uid; fallback `guardianIds` only when the first query is empty (a family with some children on each spelling would lose the `guardianIds` ones). Requires `user_type == 'student'` exactly.
- **Rules:** R1.
- **Next.js:** none for parents; `guardian_ids` is used in `components/UsersAdmin.tsx`, `lib/familyPause.ts`, `components/finance/invoices/data.ts`.
- **Platform:** Both.

### A-097 `isParentOfStudents(parentId, studentIds)`
- **Sees/does:** Not called from any screen (dead).
- **Source:** PS:83-101.
- **Data:** `users/{studentId}` get per id; checks `guardian_ids` + `guardianIds`.
- **Rules:** R1.
- **Next.js:** n/a.
- **Platform:** Dead code.

### A-098 `watchFinancialSummary(parentId)`
- **Sees/does:** Feeds A-035.
- **Source:** PS:105-158.
- **Data:** D6.
- **Rules:** R6, R7.
- **Next.js:** see A-035.
- **Platform:** Both.

### A-099 `getFinancialSummary(parentId)`
- **Sees/does:** One-shot version of the same sums, also returning `paid`. Not called from any screen (dead). The card deliberately shows no "total paid" (FSC:6-7).
- **Source:** PS:160-189.
- **Data:** D6 as gets.
- **Rules:** R6, R7.
- **Next.js:** n/a.
- **Platform:** Dead code.

### A-100 `getStudentUpcomingShifts(studentId)`
- **Sees/does:** Feeds A-062.
- **Source:** PS:262-271 → SHS:2905-2978.
- **Data:** see A-062. Errors return an empty list.
- **Rules:** R3.
- **Next.js:** see A-062.
- **Platform:** Both.

### A-101 `getStudentTodayShifts(studentId)`
- **Sees/does:** Feeds A-061.
- **Source:** PS:274-283 → SHS:2981-3008.
- **Data:** see A-061.
- **Rules:** R3.
- **Next.js:** see A-061.
- **Platform:** Both.

### A-102 `getStudentShiftsHistory(studentId, {startDate, endDate})`
- **Sees/does:** Feeds A-041…A-045, A-060, A-063, A-074.
- **Source:** PS:286-325.
- **Data:** D3.
- **Rules:** R3, R4.
- **Next.js:** `StudentClassesPage` query shape.
- **Platform:** Both.

### A-103 `getStudentAttendanceStats(studentId, {days = 30})`
- **Sees/does:** Feeds the Attendance figure in A-060. Returns totals and rate = completed ÷ (completed + missed + cancelled).
- **Source:** PS:328-394.
- **Data:** D3 (30 days).
- **Rules:** R3.
- **Next.js:** `StudentDashboardHome` attendance helpers (compare).
- **Platform:** Both.

### A-104 `getStudentSubjectStats(studentId)`
- **Sees/does:** Not called from any screen (dead). The Progress tab computes its own subject figures.
- **Source:** PS:397-451.
- **Data:** D3 with no start.
- **Rules:** R3.
- **Next.js:** n/a.
- **Platform:** Dead code.

### A-105 `getStudentAttendanceReport(studentId, {periodType, referenceDate, forceRefresh})`
- **Sees/does:** Feeds A-046…A-049. Also used by the Flutter student progress screen.
- **Source:** PS:455-487. Callers: PDS:698; features/student/screens/student_progress_screen.dart:85.
- **Data:** D5.
- **Rules:** R8.
- **Next.js:** `StudentProgressPage.fetchAnalytics`.
- **Platform:** Both.

### A-106 Writes and notifications made by this scope
- **Sees/does:** The only writes a parent triggers in sections 1-6: presence heartbeat (A-011), profile save (A-089), language (A-092), password in Firebase Auth (A-093), and the server-side report regeneration on refresh (A-032, writes `student_attendance_reports`). Local-only: `active_user_role`, `parent_sidebar_collapsed`, `admin_sidebar_preferences`, `language_code`. No push notification, email or Storage upload is triggered by any item in this inventory. Joining a class (A-068) has its own server side effects (attendance heartbeats).
- **Source:** as cited in each item.
- **Data:** as cited.
- **Rules:** R2, R8.
- **Next.js:** n/a.
- **Platform:** Both.

---

## 8. Broken, dead or hard-coded today (so "same as today" is judged honestly)

### A-107 Quran sidebar item is dead — see A-019.
- **Source:** LAYOUT:40, 120-121.
- **Next.js / decision:** section 11 Q3.

### A-108 Junk auto-generated English copy shown to parents
- **Sees/does:** "Assigned By Assignedbyname" (A-078) · "Failed To Save Profile E", "Failed To Load Profile E" (A-086, A-089) · "Account Settings Build Info" (A-091) · "New Version" as the version label (A-094) · "Unable To Load Parent Account Please" (A-030) · truncated sentences used as empty-state subtitles: "When Invoices Are Created They Will", "Payment History Will Appear Once You", "Activity Will Appear Here As Your", "Subject Performance Will Appear Here As" · Title-Cased sentences such as "No One Has Joined Yet", "Tap And Hold For More Details", "View And Pay", "No Children Linked To This Parent" · "Admin Privileges Have Been Revoked" shown for any lost secondary role (A-024) · "1 classes" (A-043).
- **Source:** lib/l10n/app_en.arb lines 1071, 1077, 1127, 1222, 1805, 1814, 2432, 2447, 2484, 2617, 3060, 3099, 3391, 3447, 3484.
- **Next.js / decision:** section 11 Q4.

### A-109 Two attendance definitions on one page
- **Sees/does:** Family Progress / child Overview / child Progress use **class status** (teacher-driven): completed ÷ (completed + missed + cancelled), 30 days. Attendance Analytics uses the **join-based** server report for the current UTC week or month. The same child can show, for example, 90 % in one block and 40 % in the next. Cancelled classes count against the child in the first definition.
- **Source:** PDS:892-893 vs PDS:729-730; PS:373-375; PGT:170-172.
- **Next.js / decision:** reproduce both exactly unless the owner chooses one (section 11 Q1).

### A-110 "Last class completed" misses most completed classes — see A-063.
- **Source:** OVT:197-198 (`status.toString().contains('completed')` does not match `fullyCompleted` / `partiallyCompleted`).

### A-111 Student progress page in Next.js is not the parent Progress tab
- **Sees/does:** The names match but the data does not: Next `StudentProgressPage` = join-based report (like A-046…A-049); Flutter parent Progress tab = class-status figures (A-080…A-085). Reusing the Next page for the per-child Progress tab would change every number.
- **Source:** apps/web/src/components/StudentProgressPage.tsx:267-290 vs PGT:93-208.

### A-112 "All-time" really means "not yet archived"
- **Sees/does:** Total Classes (A-060), Class History (A-074), Subject Performance (A-085), last class (A-063) and the calendar (A-072) read only `teaching_shifts`. Classes older than about 60 days are moved to `teaching_shifts_archive`, which parents cannot read, so these figures shrink over time.
- **Source:** PS:298-309; firestore.rules:208-211.
- **Next.js / decision:** section 11 Q2.

### A-113 Raw enum / status text leaks
- **Sees/does:** Subject shown as "IslamicSubject.xxx" when a class has no display name (A-063, A-065, A-069); status shown as "PARTIALLYCOMPLETED" in the details sheet (A-069); payment status shown as the raw name in capitals (A-055).
- **Source:** OVT:218; PPC:212, 514, 627; PDS:2185.

### A-114 Silent failures
- **Sees/does:** Money summary shows $0.00 on error (A-037); class lists show "no classes" on error (A-061, A-062, A-074); recent payments and the Upcoming list spin forever on error (A-055, A-073); a child's missing report shows as zeros (A-046); one task without a due date breaks the whole task list for that child (D7).
- **Source:** as cited.

### A-115 Dead code in scope
- **Sees/does:** `AccessSuspendedScreen` (A-029); widgets `ClassCard` (features/parent/widgets/class_card.dart) and `SubjectStatCard` (features/parent/widgets/subject_stat_card.dart) are referenced nowhere; service methods in A-097, A-099, A-104; `StudentDetailScreen.parentId` unused; `_ChildAttendanceAnalyticsSnapshot.hasReport`, `presenceCoverageRate`, `teacherOverlapRate` are computed but never displayed; `RoleBasedDashboard.TeacherDashboard`/`StudentDashboard` classes are marked deprecated.
- **Source:** grep over `lib/` shows no constructor calls for these.
- **Next.js:** do not port.

### A-116 Other rough edges
- **Sees/does:** Profile back arrow (A-090); live panel stuck on a spinner (A-070); sidebar flashes the student menu (A-020); role chip looks like a button but does nothing for single-role parents (A-023); summary mixes currencies and labels everything as dollars (A-035); recent-payment amounts ignore currency (A-055); calendar cannot change month (A-072); no refresh control for mouse users (A-032); sidebar preferences key is shared with other roles on the same browser (A-022); the children fallback to `guardianIds` only runs when `guardian_ids` finds nobody (A-096); the suspension banner and the contacts card never use the `guardianIds` spelling (A-034, D12).
- **Source:** as cited.

---

## 9. Where behaviour depends on app language

### A-117 What changes with the language and what does not
- **Sees/does:** Language is English or French (A-092).
  - **Translated** (via ARB keys): top-bar title/menu, sign-out dialog; sidebar section titles Overview, Communication, Learning, Finance and items Dashboard, Chat, Classes, Forms, Settings; money summary labels; quick-action tiles; Family Progress and Attendance Analytics labels (`parentProgress*`, `parentAnalytics*`); Children heading and empty state; contacts card; Recent Invoices/Payments headings and empty states; child-detail tab names; quick-stat labels; empty states in the tabs; profile labels and snackbars; settings title, language card.
  - **Always English** (hard-coded): greeting "Welcome, …"/"Parent Dashboard"; the whole suspension banner; "See all"; every loading and error sentence on the dashboard; "Weekly Activity", "{n} classes"; child card labels (Attendance, Last 7 Days, Learning Hours, On Track/Watch/Needs Support, trend sentences, "No completed classes", "General"); section headings in the child tabs (Today's Classes, Upcoming Classes, Recent Activity, Attendance Calendar, Class History, Subject Performance); Upcoming/History and task filter labels and counters; class-card status words, "Teacher: …", "{n} in class", Join buttons, the whole details sheet; calendar weekday names and legend; invoice card badges and cutoff text; task badges; all of the Progress tab hero; profile validation messages and hints; the whole change-password card and dialog; role names and "Switched to … mode"; sidebar items Recordings, Curriculum Books, Quran, Invoices, Payments, Profile, the section title Account, "Search...", "Favorites", "Pin"/"Unpin".
  - **Dates and numbers** never follow the language: `DateFormat`/`NumberFormat` run with the default locale (no `Intl.defaultLocale` is set anywhere), so day and month names are English and money is `$1,234.50` in French too.
  - **French strings that are wrong today:** "Assigné par Nom", "Participants vivants" (for Live Participants), "Personne ne s'est joint Encore", "Configuration du compte Construisez l'information", "Outstanding" untranslated in the money card.
- **Source:** SBL:6-101; lib/l10n/app_fr.arb lines 872, 1023, 2094, 2248, 4183; hard-coded strings as cited in each item.
- **Data:** `language_preference`.
- **Rules:** R2.
- **Next.js:** I18N uses source-keyed English strings with a French dictionary (`lib/translations`). A faithful port keeps the English text as keys; whether to translate the strings that are English-only today is an owner decision (section 11 Q5). `StudentDashboardHome` formats dates with `dateLocale()`, i.e. Next *does* localise dates — a visible difference from Flutter.
- **Platform:** Both.

---

## 10. Next.js reuse map (summary)

### A-118 What exists in `apps/web` and how the parent version differs
| Flutter piece | Existing Next.js file | Reusable? | How the parent version differs |
|---|---|---|---|
| Shell, sidebar, account menu, role pill | `components/StudentDashboardHome.tsx` (`StudentShell`) | Pattern yes, code needs generalising | Different menu (A-017), all roles shown (A-023), Profile + Settings items, collapse/search/reorder (A-021, A-022) to verify |
| Session / role lookup | `lib/studentSession.ts`, `lib/userRoles.ts`, `lib/roles.ts` | Yes with a parent variant | `dashboardPathForUser` must learn about parents (A-008, A-009) |
| Language | `lib/i18n.ts`, `lib/localeStore.ts`, `components/LanguageSwitch.tsx` | Yes | none |
| Change password | `components/TeacherSettingsPage.tsx` | Yes | parent page has no notification preferences (A-095) |
| Teachers' phone numbers | `components/ClassContactsCard.tsx`, `lib/classContacts.ts` | Yes | use the `children` groups |
| Attendance Analytics | `components/StudentProgressPage.tsx` (`fetchAnalytics`) | Parsing yes | one call per child, family averages, sorted child cards (A-048, A-049) |
| Recent invoices / payments, summary | `components/StudentInvoicesPage.tsx`, `components/StudentPaymentsPage.tsx`, `lib/finance/` | Queries yes | summary card and its maths are new (A-035); top-5 previews |
| Class cards, join | `components/StudentClassesPage.tsx`, `components/StudentClassroomPage.tsx`, `lib/zoomJoinRouting.ts`, `lib/classroomErrorText.ts`, `lib/classroomReconnect.ts` | Partly | per-child id, parent role on join, live participants panel, long-press sheet (A-066, A-069) |
| Tasks tab | `components/StudentTasksPage.tsx` | Card layout partly | read-only, per-child, different filters, no limit (A-075…A-079) |
| Profile | `components/StudentProfilePage.tsx` | Layout only | parent edits name/phone and has no photo (A-087…A-089) |
| Family Progress, child Progress tab, calendar, children list, suspension banner | none | No | new work (A-034, A-040…A-045, A-050, A-072, A-080…A-085) |

---

## 11. Questions only the owner can answer

1. **Two attendance numbers (A-109).** Keep both exactly as today, or show one definition everywhere? If both stay, should each be labelled so parents can tell them apart?
2. **History depth (A-112).** Is "about the last 60 days" the intended history for parents, or should parents see everything (which needs a server change so they can read archived classes)?
3. **Quran menu item (A-019).** Today it does nothing. Remove it, keep it dead, or make it open the Quran reader?
4. **Broken copy (A-108).** For each junk string: carry it over word for word, or fix it during the move? In particular "Assigned By Assignedbyname" — show the real name?
5. **English-only text (A-117).** Should strings that are English even in French today stay English after the move, or be translated? Should dates and money follow the language (they do not today)?
6. **Multi-role accounts (A-008, A-009).** For a person who is both parent and student, or parent and teacher: which dashboard should open first after sign-in, and where must the switch back to "Parent" appear?
7. **One page with tabs vs real pages (A-016).** Is it acceptable that the new parent area has a URL per screen (Back works, refresh stays put, but filters/scroll are not kept when moving between screens)?
8. **Money card while loading or on error (A-037).** Keep "$0.00" until data arrives, or show a loading/error state?
9. **Raw technical errors (A-057).** Keep showing them, or replace with plain sentences?
10. **Profile (A-087, A-090).** Should parents get a profile photo like students have on the web? And is the Profile back arrow something parents rely on?
11. **Privacy of the class card (A-066, A-069).** Parents can see other students' names in a group class and the class "Notes". Intended?
12. **Sidebar extras (A-021, A-022).** Are collapse, search, pin-to-favourites, drag-to-reorder and Reset Layout all used by parents, or can any be dropped?
13. **Mixed currencies (A-035, A-055).** Are all parent invoices in US dollars? If not, how should the summary behave?
