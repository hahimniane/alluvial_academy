# Inventory C — Classes, Recordings, Curriculum Books, Quran, Chat, Circles, Notifications, and the cut-over mechanics (Flutter parent area, main @ 0a49330)

1. Scope: what a PARENT gets today in Classes, Recordings, Curriculum Books, Quran, Chat, Circles and Notifications, the Next.js student counterparts, how the student and teacher cut-overs work, and production numbers. Read-only; nothing in the repo or database was changed.
2. Size: 239 checklist items — Classes 30 (C-001…030), Recordings 27 (C-200…226), Books 11 (C-300…310), Quran 27 (C-330…356), Chat 72 (C-400…484), Circles 4 (C-500…503), Notifications 50 (C-600…649), Next.js/cut-over 18 (C-700…732) — plus 33 production facts (N-01…33). Each item has what the parent sees, source file:line, data, rules, Next.js counterpart and platform.
3. Audience size: 118 parent accounts; about 24 used the product in the last 30 days; 53 have never signed in; 53 have more than one child; 2 are also students; none is also a teacher or admin.
4. Biggest gap 1 — Classes: the student page cannot be reused as is. Parents need child resolution, sibling grouping, cancelled classes, full history (student page keeps 24 hours), the Flutter status words, the live participant panel and the details sheet (section 1, table in 7.1).
5. Biggest gap 2 — Class join: on Flutter web a parent joins on `/app/zoom_meeting.html`, which is cross-origin isolated; the Next.js classroom uses `/zoom_meeting.html`, which is not (live check). Same page file, different Zoom SDK mode (C-024). Documented only; no Zoom change is proposed.
6. Biggest gap 3 — Chat: contact resolution, leader contacts, the composer lock and several message features differ between Flutter and the Next.js student chat; 48 parents sit in group chats, so group features are in scope (section 4, N-24).
7. Things that are already dead or empty for web parents: the Quran menu item does nothing (C-330); Circles is hidden by a compile-time constant (C-500); Recordings has zero recordings in production (N-27); there is no notification bell and no browser push (C-600 onward). "Same as today" needs an owner decision on each.
8. The parent ↔ child link lives in two places that disagree for 3 parents: `guardian_ids` on the student (Classes, dashboard, join permission) and `children_ids` on the parent (chat contacts first) (N-13…N-20).
9. Cut-over pattern to copy: the teacher one — a `settings/…_web_cutover` document with `off | allowlist | all`, read fail-closed in Flutter and applied in `role_based_dashboard.dart`; plus a parent branch in `dashboardPathForUser`, per-page role gates, and the shared-session rule in `firebase.ts` (section 7). The student redirect has no switch at all.
10. Not covered here: parent shell, home dashboard, child detail, profile, settings (inventory A); invoices, payments, forms (inventory B).

Sections: 1 Classes · 2 Recordings · 3a Curriculum Books · 3b Quran · 4 Chat · 5 Circles · 6 Notifications · 7 Next.js side and cut-over mechanics · 8 Production numbers · 9 Top risks · 10 Questions for the owner. Each section ends with its own "Broken / dead / hard-coded today" list.

---

## 1. Classes (parent)

> Short names: `PCS` = `lib/features/parent/screens/parent_classes_screen.dart`; `CVS` = `lib/core/services/class_video_service.dart` (re-exported by `lib/features/livekit/services/video_call_service.dart`, whose single line is the export; `VideoCallService` is a thin wrapper class at `CVS:253-275`); `PS` = `lib/features/parent/services/parent_service.dart`; `SS` = `lib/features/shift_management/services/shift_service.dart`; `TS` = `lib/features/shift_management/models/teaching_shift.dart`; `ZMW` = `lib/core/widgets/zoom_meeting_screen_web.dart`; `ZJ` = `functions/handlers/zoom.js`; `RK` = `functions/handlers/realtimekit.js`; `FR` = `firestore.rules`; `SCP` = `apps/web/src/components/StudentClassesPage.tsx`; `SCR` = `apps/web/src/components/StudentClassroomPage.tsx`.
> `PCS` imports no file from `lib/features/parent/widgets/` (imports are `PCS:1-14`). The widgets `class_card.dart` and `student_classes_tab.dart` in that folder belong to the child-detail screen (inventory A), not to this screen.
> Nothing in this section proposes a change to class or Zoom behaviour. It records what happens today.

### 1.1 Reaching the screen and resolving children

**C-001 — Web entry: sidebar "Learning > Classes"**
- **Parent sees/does:** Sidebar item "Classes" (videocam icon) shows the Classes screen inside the parent shell. The screen has its own white app bar titled with l10n `navClasses`, no back arrow, and a refresh icon on the right.
- **Source:** `lib/features/dashboard/config/sidebar_config.dart:508-515` (item, `screenIndex: 6`); `lib/features/parent/screens/parent_dashboard_layout.dart:103-104` (6 → `const ParentClassesScreen()`), `:152-163` (IndexedStack builds screens 0..10 at once, so this screen's child lookup and class listeners start when the parent dashboard opens, not when the item is clicked); `PCS:54-74` (app bar).
- **Data:** none for navigation.
- **Rules:** n/a.
- **Next.js:** no parent route exists (`apps/web/src/app/` has no `parent/`; live `https://alluwaleducationhub.org/parent/` returns 404). Student equivalent: `/student/classes/` (`apps/web/src/app/student/classes/page.tsx` → `SCP`).
- **Platform:** web.

**C-002 — Phone entry: bottom tab "Classes"**
- **Parent sees/does:** On iOS/Android the second bottom tab ("Classes", school icon) shows the same `ParentClassesScreen`.
- **Source:** `lib/features/dashboard/screens/role_based_dashboard.dart:323-328` (native → `MobileDashboardScreen`); `lib/features/dashboard/screens/mobile_dashboard_screen.dart:589-598` (parent screens, index 1), `:665-678` (parent tabs).
- **Data / Rules:** as below.
- **Next.js:** n/a (phones stay on Flutter).
- **Platform:** mobile.

**C-003 — Whose classes: children are the students whose `guardian_ids` contain the parent's uid**
- **Parent sees/does:** The screen lists classes of every child linked to the signed-in account. Children are sorted by name; each child is `{id, name ("first last", or the doc id when both are blank), studentCode, kioskCode, email}`.
- **Source:** `PCS:33-50`; `PS:32-80`.
- **Data:** `users` where `user_type == 'student'` AND `guardian_ids` array-contains `<auth uid>` (no limit, no order). Only when that returns zero docs: the same query on `guardianIds`. The parent's own `children_ids` field is NOT used here (chat uses it first — see C-414; recordings use the union — see C-203). Uses `FirebaseAuth.currentUser.uid`, not the role service.
- **Rules:** `FR:276-279` (`users`: read for any signed-in user).
- **Next.js:** `SCP:111-116` queries the signed-in student's own uid. A parent page must first run this child query, then one class query per child. Production: 0 parents depend on the `guardianIds` fallback; 3 parents have a child in `guardian_ids` that is missing from their `children_ids` (section 8).
- **Platform:** both.

**C-004 — First load spinner**
- **Parent sees/does:** A centred spinner while children load.
- **Source:** `PCS:25`, `:77-78`.
- **Next.js:** `SCP:163-169` ("Loading your classes…").
- **Platform:** both.

**C-005 — No children, or the child lookup failed**
- **Parent sees/does:** School icon and the text "No children linked to your account" (English only, hard-coded). The same screen appears when the lookup throws: the error is swallowed and the list stays empty. Not signed in → same empty screen.
- **Source:** `PCS:34-38` (no uid), `:47-49` (catch → not loading, list empty), `:79-80`, `:95-113`.
- **Data:** production: 6 parent accounts have zero linked children (section 8).
- **Next.js:** none. `SCP:170-179` shows "No Classes Right Now" for a student with no classes; there is no "no children" state.
- **Platform:** both.

**C-006 — Refresh icon and pull-to-refresh only re-read the children list**
- **Parent sees/does:** Tapping refresh (or pulling down) re-runs the child lookup without showing the spinner. Class data does not need it (live listeners, C-007). If the set of child ids is unchanged nothing visibly happens.
- **Source:** `PCS:69-72`, `:81-82` (RefreshIndicator), `:33-50` (`_loading` is never set back to true), `:198-206` (listeners are rebuilt only when the joined child ids differ).
- **Next.js:** `SCP` has no refresh control (live listener).
- **Platform:** both; pull-to-refresh is a touch gesture.

### 1.2 Which classes are listed

**C-007 — One live listener per child on `teaching_shifts`, teaching classes only, no date bound**
- **Parent sees/does:** Every class of each child that is still in `teaching_shifts`, updating live. Leader-duty, meeting and training shifts are hidden.
- **Source:** `PCS:218-260`; `SS:2866-2899`.
- **Data:** per child: `teaching_shifts` where `student_ids` array-contains `<childId>`, `.snapshots()`, no `orderBy`, no `limit`, no date filter. Client keeps `category == ShiftCategory.teaching` (`shift_category` defaults to `teaching` when absent, `TS:589`) and sorts by `shift_start`. Documents that fail to parse are skipped silently (`SS:2874-2879`). A listener error just ends that child's loading state (`PCS:251-255`).
- **Rules:** `FR:469-477` (`teaching_shifts`: get and list for any signed-in user). `FR:208-211`: `teaching_shifts_archive` is admin-read only, so classes older than 60 days (`functions/handlers/shift_archive.js:11`, `RETENTION_DAYS = 60`) are not visible to a parent.
- **Next.js:** `SCP:105-128` adds `shift_start >= now − 2 days` and drops `status == cancelled`. A parent page that copies it would lose (a) history older than 2 days and (b) cancelled classes — see C-012, C-016.
- **Platform:** both.

**C-008 — Siblings in the same class share one card**
- **Parent sees/does:** When two or more children are in the same class, one card is shown and the line with the people icon lists all their names, comma-separated. One Join button serves all of them.
- **Source:** `PCS:288-312` (grouping; when several shift docs share a key the card keeps the first one, replaced by a later one only if the later one is joinable and the kept one is not), `:314-344` (key), `:659-672` (names line).
- **Data:** group key, first non-empty of: `livekit:<livekit_room_name>`; `zoom:<zoom_meeting_id>:<breakout_room_key or breakout_room_name>`; `hub:<hub_meeting_id>:<breakout key or name>`; else `fallback:<teacher_id>:<subject_id or lower-cased subject_display_name or subject enum name>:<start ms>:<end ms>`.
- **Next.js:** none (`SCP` is single-student). A parent page needs this grouping or siblings show duplicate cards.
- **Platform:** both.

**C-009 — "Upcoming" / "History" switch**
- **Parent sees/does:** A two-button pill at the top right of the list: "Upcoming" (default) and "History" (English only). Under it, a header row with a school icon and the l10n `navClasses` title.
- **Source:** `PCS:171`, `:380-404`, `:427-471`.
- **Next.js:** `SCP:182-197` has "Upcoming" / "Past" tabs with a count on Past; contents differ (C-010, C-012).
- **Platform:** both.

**C-010 — Upcoming list: what is in it and its order**
- **Parent sees/does:** Every class whose end time is still in the future, including cancelled ones. Order: classes in progress first, then classes that can be joined now, then by start time ascending. Not grouped by day; no "Today" heading.
- **Source:** `PCS:350-366`.
- **Next.js:** `SCP:130-147`, `:199-207` splits into "Today" and "Upcoming Classes" sections, start-time order only, cancelled removed. Differences to close: order (live/joinable first), cancelled classes shown, no day sections.
- **Platform:** both.

**C-011 — Upcoming empty state**
- **Parent sees/does:** A grey row with an info icon and "No upcoming classes".
- **Source:** `PCS:413-415`, `:917-937`.
- **Next.js:** `SCP:200-201` ("No upcoming classes" + subtitle).
- **Platform:** both.

**C-012 — History list**
- **Parent sees/does:** Every class whose end time has passed, newest first, with its status pill (C-014). Reaches back only as far as `teaching_shifts` still holds the class (about 60 days, C-007). Empty state: "No class history".
- **Source:** `PCS:368-371`, `:413-415`.
- **Next.js:** `SCP:138-146`, `:208-213`: "Past" shows only classes that ended in the last 24 hours ("Last 24 hours"). A parent page needs the full list.
- **Platform:** both.

**C-013 — Spinner while the first class snapshot is pending**
- **Parent sees/does:** A spinner under the header until the first child's classes arrive. After that, a child whose listener is still loading simply contributes nothing yet.
- **Source:** `PCS:374-375`, `:408-412`.
- **Next.js:** `SCP:163-169`.
- **Platform:** both.

### 1.3 The class card

**C-014 — Status pill**
- **Parent sees/does:** Coloured pill, English only: `active` → green "In Progress"; `completed` / `partiallyCompleted` / `fullyCompleted` → grey "Completed"; `cancelled` → red "Cancelled"; `missed` → amber "Missed"; `scheduled` → green "In Progress" when the teacher is clocked in, amber "Missed" when the start time has passed, otherwise blue "Scheduled". Consequence: a class that has started but whose teacher has not clocked in reads "Missed" while its Join button is showing.
- **Source:** `PCS:485-518`, `:546-568`; clocked-in definition `TS:365-369` (`clock_in_time` set, `clock_out_time` null, and status `active`).
- **Data:** `teaching_shifts.status`, `clock_in_time`, `clock_out_time`, `shift_start`.
- **Next.js:** `SCP:263-276`: "Live" / "Join Now" / "Ended" / "Starting now" / "Upcoming". No Completed / Cancelled / Missed wording, and "live" also reads an `is_clocked_in` field (`SCP:338`) that the Flutter model derives instead. A parent page needs the Flutter mapping.
- **Platform:** both.

**C-015 — Card content**
- **Parent sees/does:** Start time at top right (`h:mm a`, device time zone); class name (`subject_display_name`); "Teacher: <teacher_name>" ("Teacher: Unknown" when blank); date (`EEEE, MMM d, yyyy`); children's names (C-008). No end time, no duration, no countdown text on this card.
- **Source:** `PCS:605-612`, `:618-625`, `:629-641`, `:645-656`, `:659-672`.
- **Data:** `subject_display_name`, `teacher_name`, `shift_start`.
- **Next.js:** `SCP:278-300` shows name, teacher, start–end time and a countdown ("Starting in 15 min", "Tomorrow"…, `SCP:342-359`). The Flutter parent card has no countdown; the Flutter 30-second timer (`PCS:188-191`) only re-evaluates the Join button and the "time in class" figures. Dates are not shown on the Next card at all (only the time), which matters for a parent list that spans weeks.
- **Platform:** both.

**C-016 — Cancelled classes stay visible**
- **Parent sees/does:** A cancelled class shows in Upcoming until its end time and then in History, with the red "Cancelled" pill. A Join button still appears on it during the join window (C-019 does not look at status); the server decides (C-024).
- **Source:** `PCS:350-371` (no status filter), `:479`.
- **Next.js:** `SCP:121` removes cancelled classes.
- **Platform:** both.

**C-017 — Live participant count and panel (classes in progress)**
- **Parent sees/does:** On a class in progress: a green "N in class" chip beside the status pill when N > 0, and a green "Live participants" panel listing each person in the room — name (or identity), role, a mic icon (on/off) and how long they have been in ("Just joined", "12m", "1h 5m"). While the first fetch is pending the panel shows a small spinner; with nobody in the room it shows l10n `noOneHasJoinedYet`. Under the panel: l10n `tapAndHoldForMoreDetails` (this hint appears only on classes in progress). The parent therefore sees the names of everyone in the room, including other families' children.
- **Source:** `PCS:520-521`, `:569-603`, `:675-829`, `:911-915`; fetch `PCS:243-249`, `:262-280` (every 15 s for each in-progress class, one request at a time per class); `CVS:471-490`; `lib/features/livekit/services/livekit_service.dart:648-670`.
- **Data:** callable `getRealtimeKitRoomPresence` `{shiftId}` → `{success, roomName, participantCount, participants:[{identity, name, role, joinedAtIso, isPublisher}], inJoinWindow, generatedAtIso}`. Server: `RK:749-827`; authorises through the same teacher / student / admin / guardian check as joining (`RK:762`); for Zoom classes it answers from the hub bot's roster, else from open windows in `livekit_sessions` where `shift_id == shiftId` (`RK:670-740`).
- **Rules:** callable only.
- **Next.js:** the classes list has no participant count or panel. `SCR:166-184` polls the same callable every 10 s, but only inside a RealtimeKit classroom after connecting.
- **Platform:** both.

**C-018 — Long-press opens a details sheet**
- **Parent sees/does:** Pressing and holding any card (mouse: press and hold) fetches presence once more and opens a bottom sheet: class name, a "LIVE" badge when in progress, full date and time; "Teacher" (name, "Clocked in" time, "Time in class"); "Assigned Students (N)" listing every student name on the class (all classmates, not only the parent's children; "N assigned" when names are missing); "Currently in Class (N)" with name, role and "Joined h:mm a · duration"; "Class Information" (duration in hours with one decimal, subject, status in capitals, notes when present); and a "Join Class Now" / "Join Class" button when joinable. Section labels are English only.
- **Source:** `PCS:536`, `:881-909`, `:944-1153`.
- **Data:** `getRealtimeKitRoomPresence` (C-017); shift fields `teacher_name`, `clock_in_time`, `student_ids`, `student_names`, `notes`, `status`.
- **Next.js:** none.
- **Platform:** both.

### 1.4 Joining a class

**C-019 — When the Join button shows**
- **Parent sees/does:** A full-width green button "Join Now" (class in progress) or "Join Class" appears when the class is in progress, or when now is between 10 minutes before the start and 10 minutes after the end and the class is a teaching class with at least one student. Tapping anywhere on such a card also joins.
- **Source:** `PCS:479`, `:535`, `:832-860`; `CVS:282-291`; `TS:239-240` (`hasVideoCall`).
- **Next.js:** `SCP:36-46`, `:251-253`, `:301-316` — same window; label "Join"; a link to `/student/classroom/?shiftId=…` (`SCP:33`).
- **Platform:** both.

**C-020 — Client checks before the server is asked**
- **Parent sees/does:** In order: class without video → orange "class video unavailable" message; not signed in → red "please sign in again"; the account's active role must be `parent` (or admin / teacher) when the uid is not the class's teacher or student, else red "you are not assigned to this"; outside the 10-minute window → orange "class ended" or "opens in N minutes" (this also fires for a class still marked in progress more than 10 minutes after its end, where the button is showing); then a blocking "Connecting to class" dialog.
- **Source:** `CVS:541-657`, `:867-886`; `PCS:867-879` (calls `joinClass(context, shift, isTeacher: false)`; the `isTeacher` argument is not used by `joinClass`).
- **Data:** active role from `UserRoleService` (browser/phone preference `active_user_role`, falling back to `users.user_type`; `lib/core/services/user_role_service.dart:14`, `:77-98`). The client check does not test that the parent is a guardian of a student in the class; the server does (C-021).
- **Next.js:** `SCR:79-94` requires the student role (`resolveStudentSession(...).isStudent`), then `SCR:109-118`, `:405-415` checks the window ("Class opens in N minutes" / "This class has ended" / "Class time is not set."). A parent page needs its own role gate.
- **Platform:** both.

**C-021 — Server authorisation and the role a parent joins with**
- **Parent sees/does:** The parent is admitted only when their uid is in `guardian_ids` or `guardianIds` of at least one student on the class. They join as a normal attendee: classroom role `parent`, Zoom SDK role 0 (never host), under their own profile name. With hub routing they are placed automatically in the class's own breakout room. Refusals arrive as the server's sentence in a red bar: "You are not allowed to join this class", "You can join 10 minutes before the class starts. Please wait N minute(s).", "The class window has ended", "Shift not found".
- **Source:** `CVS:377-418` (callable + error mapping), `:841-849` (active role); `ZJ:4574-4600`, `ZJ:316-343` (`getAccessForUser`), `ZJ:266-286` (guardian lookup: one `users/{studentId}` read per student on the class), `ZJ:296-314` (role resolution: the requested role is honoured only when the caller really holds it; otherwise teacher → admin → parent → student), `ZJ:32-33`, `ZJ:378-411` (window), `ZJ:4719-4720` (role, `sdkRole = 0`), `ZJ:4749-4758` (hub member record written with role and names), `ZJ:4830` (`autoJoinBreakoutRoom` when hub).
- **Data:** callable `getZoomJoinInfo` `{shiftId, activeRole: 'parent', clientPlatform: 'native_mobile' (phones only)}` → `{success, meetingNumber, password, signature, sdkKey, displayName, nativeDisplayName, routingDisplayName, userRole, customerKey, shiftName, joinUrl, routingMode, hubMeetingId, breakoutRoomName, breakoutRoomKey, autoJoinBreakoutRoom, classEndsAtIso, presenceToken, joinWindow, …}`.
- **Rules:** callable (Admin SDK).
- **Next.js:** `SCR:119-131` calls the same callable with `{shiftId, clientPlatform: "web"}` and no `activeRole`. For a parent-only account the server still resolves `parent`. For a parent who is also the class's student, or an admin, the missing `activeRole` changes which role is chosen (teacher → admin → parent → student order), so a parent page should send `activeRole: "parent"` as Flutter does.
- **Platform:** both.

**C-022 — A parent's presence is not counted as attendance**
- **Parent sees/does:** Nothing visible. A parent joining does not create or extend an attendance record for the child, and gets no presence token.
- **Source:** `ZJ:4771-4786` (attendance is recorded only when the uid is the class's teacher or one of its students), `ZJ:4796-4798` (token only for those), `ZJ:6128-6160` (`recordClassPresence` refuses anyone else: "Not a participant of this class").
- **Data:** none written for a parent except the hub member record (C-021).
- **Next.js:** `SCR:469-479` wires the presence heartbeat only when a token is returned, so the same holds. A child who attends through the parent's login is not marked present in either app.
- **Platform:** both.

**C-023 — Student suspension does not block a parent**
- **Parent sees/does:** No lock or "suspended" text on this screen. The server blocks only a caller whose resolved role is `student` and whose own account is suspended; a parent joining a suspended child's class is admitted.
- **Source:** no occurrence of "suspend" in `PCS`; `ZJ:333-339`, `ZJ:288-294`.
- **Next.js:** `SCP:82-90`, `:156-161`, `:301-306` shows "Class Access Suspended" and replaces Join with "Suspended" for a suspended student. Whether the parent web list should show anything is an owner question (the parent home dashboard has its own suspension banner — inventory A-034, inventory B section J).
- **Platform:** both.

**C-024 — Zoom on the web: the browser leaves the app for the meeting page**
- **Parent sees/does:** After "Connecting to class", the whole browser tab navigates to the Zoom web meeting page (`/app/zoom_meeting.html`), where the class runs. Parents always stay in the browser: the hand-off to the Zoom desktop app is for teacher and admin roles only. Leaving the meeting returns to the Flutter app's URL, which reloads the app and lands on the parent home dashboard, not on Classes.
- **Source:** `CVS:660-732`, `:851-865` (desktop app only for `teacher` / `admin` / `super_admin` / `admin_teacher` on hub-routed classes); `ZMW:58-106` (parameters; `returnUrl` = current URL without join parameters, `ZMW:71`), `ZMW:161-165` (`window.location.assign`); meeting page `web/zoom_meeting.html:693-697`, `:978-988` (return on leave).
- **Data:** URL hash parameters: `sdkKey, signature, meetingNumber, password, displayName, customerKey, returnUrl, embedded=0`, localized texts, `classEndsAt`, `classEndingSoonText`, `classEndedText`, `breakoutRoomName`, `breakoutRoomKey`, `autoJoinBreakoutRoom=1`. No presence parameters are sent from Flutter web.
- **Rules:** n/a. Hosting: `/app/` answers with `Cross-Origin-Opener-Policy: same-origin` and, for `zoom_meeting.html`, `Cross-Origin-Embedder-Policy: require-corp` (`web/.htaccess:6-25`; confirmed live by HEAD request on 2026-11-14).
- **Next.js:** `SCR:129`, `:442-481` navigates to the root copy `/zoom_meeting.html` (`apps/web/public/zoom_meeting.html`, byte-identical to `web/zoom_meeting.html`) with `returnUrl = /student/classes/`. Two differences: (1) the return lands on the Classes page; (2) the root copy is served WITHOUT the two cross-origin headers (live HEAD request shows neither), so `window.crossOriginIsolated` is false there and the page starts the Zoom SDK with `disableCORP: true` (`web/zoom_meeting.html:1538`). `web/.htaccess:8-11,17-22` says isolation is what enables shared-screen viewing on iPhone, whiteboard, annotations and virtual backgrounds. Web students already run this way; a parent moved to Next would change from the isolated page to the non-isolated one. Document only — any change here is a Zoom change and needs the owner's explicit request.
- **Platform:** web. On phones `lib/core/widgets/zoom_meeting_screen_io.dart` runs the native path.

**C-025 — "Classroom is reconnecting" waiting room**
- **Parent sees/does:** When the server answers that the class's hub is coming back, a dialog titled l10n `classroomReconnectingTitle` holds the parent, counts down when the server gave a time, retries by itself (every 15 s when no time is known), and offers "Try again" and "Close". Success continues into the meeting; Close abandons the join.
- **Source:** `CVS:361-375`, `:402-408`, `:670-687`; `lib/core/widgets/classroom_reconnecting_dialog.dart:9-12`, `:56-104`, `:119-170`; server `ZJ:4703-4712` (error `unavailable`, details `{reason: 'classroom_reconnecting', expectedBackAtIso}`).
- **Next.js:** `SCR:146-155`, `:297-306` with `apps/web/src/components/ClassroomReconnecting.tsx` and `apps/web/src/lib/classroomReconnect.ts` (same 15 s blind retry). Back link goes to `/student/classes/`.
- **Platform:** both.

**C-026 — Join errors**
- **Parent sees/does:** A red bar with the server's own sentence, or l10n `classVideoConnectFailed`; on a timeout / no network, l10n `classVideoSlowConnection`. Missing meeting number, signature or SDK key → the same generic failure. An unexpected exception → l10n `classJoinFailed(<error>)`; the screen's own catch adds "Failed to join: <error>" (English).
- **Source:** `CVS:303-325` (`joinErrorText`), `:689-705`, `:767-778`; `PCS:867-879`.
- **Next.js:** `SCR:146-155`, `:297-327` full-screen "Could not join class" with "Reconnect" and "Back to Classes"; text from `apps/web/src/lib/classroomErrorText.ts`.
- **Platform:** both.

**C-027 — Non-Zoom (RealtimeKit) classes**
- **Parent sees/does:** For a class whose `video_provider` is not `zoom`, the meeting opens inside the app in a black screen with the class name in the app bar (an embedded page on web). A parent cannot enter a class the teacher has locked.
- **Source:** `CVS:734-766`, `:327-359`; `lib/core/widgets/realtimekit_meeting_screen_web.dart:26-60`; `RK:565` (locked room refuses `student`, `parent`, `guest`).
- **Data:** callable `getRealtimeKitJoinToken` `{shiftId, activeRole}` → `{success, authToken, displayName, shiftName, roomLocked}`; page `realtimekit_meeting.html#token=…`.
- **Next.js:** `SCR:133-145`, `:285-295` (same callable without `activeRole`, same page in an iframe) plus a header with reconnect, lock and roster buttons (`SCR:269-281`) that the Flutter screen does not have; lock and remove are refused by the server for anyone but the teacher or an admin (`RK:839-843`). Production: all 3,389 teaching classes dated in the last 30 days or later have `video_provider: zoom`, so this path is unused today.
- **Platform:** both.

**C-028 — Link `?joinShift=<id>` opens a class after sign-in**
- **Parent sees/does:** Opening the Flutter web app with `?joinShift=<shiftId>` signs in as usual and then runs the same join (C-020 onward). A link to a class that no longer exists → red l10n `thisClassLinkIsNoLonger`.
- **Source:** `lib/core/services/join_link_service.dart` (`initFromUri`, `consumePendingShiftId`); `lib/main.dart:439-444`, `:855-892`.
- **Next.js:** `/student/classroom/?shiftId=<id>` is the direct equivalent for students. No `joinShift` handling exists on the Next side; old links would keep opening Flutter.
- **Platform:** web only (`initFromUri` returns early off the web).

**C-029 — Guest links: parents cannot create them**
- **Parent sees/does:** No "copy guest link" or "contacts" control on this screen (no occurrence of "guest", "copyJoinLink" or "contact" in `PCS`). The only caller of `copyJoinLink` is the teacher/admin Zoom screen. A parent who is handed a guest link (`?guestShift=<id>`) can open it like anyone, without signing in.
- **Source:** `lib/features/zoom/screens/zoom_screen.dart:1746` (only caller); `CVS:781-792`, `:794-839`; `lib/main.dart:434-437`; `lib/features/livekit/screens/guest_join_screen.dart:27`.
- **Data:** HTTP GET `https://us-central1-<project>.cloudfunctions.net/getRealtimeKitGuestJoin?shiftId=…&name=…`.
- **Next.js:** `/classroom/join/` (`apps/web/src/app/classroom/join/page.tsx` → `GuestClassroomJoinPage.tsx:20-23`, reads `guestShift` or `shiftId`, and `name`).
- **Platform:** web. The class contacts card (teacher/admin contact buttons) lives on the parent home dashboard — inventory A (`core/widgets/class_contacts_card.dart`).

**C-030 — Text on the screen is selectable**
- **Parent sees/does:** Text can be selected and copied with the mouse.
- **Source:** `PCS:75-76`, `:537`.
- **Next.js:** ordinary web text.
- **Platform:** web.

### Broken / dead / hard-coded today (classes)

1. English-only strings on a localized app: "No children linked to your account" (`PCS:103`), "Upcoming" / "History" (`PCS:437-438`), "No upcoming classes" / "No class history" (`PCS:415`), all status words (`PCS:488-516`), "Teacher: … Unknown" (`PCS:635`), "N in class" (`PCS:593`, `:710`), "Join Now" / "Join Class" (`PCS:840`), "Failed to join: …" (`PCS:875`), every label in the details sheet (`PCS:1053-1131`), "Just joined" (`PCS:914`).
2. A failed child lookup is indistinguishable from "no children" (`PCS:47-49`).
3. The refresh button does nothing visible when the child list is unchanged (`PCS:198-206`).
4. A started class whose teacher has not clocked in reads "Missed" while it is joinable (`PCS:505-512` with `:479`).
5. A cancelled class can show a Join button during its window (`PCS:479` ignores status).
6. A class still marked in progress more than 10 minutes after its end shows "Join Now", and tapping it answers "class ended" (`PCS:479` vs `CVS:642-653`).
7. When `subject_display_name` is missing the card prints the Dart enum text (`shift.subject.toString()`, `PCS:619`, `:992`) (for example `IslamicSubject.<name>`).
8. The comment "countdown timers" on the 30-second timer (`PCS:188`) describes nothing on screen: the parent card has no countdown.
9. `isTeacher: false` is passed to `joinClass` and ignored (`PCS:869`, `CVS:541-545`).
10. History silently ends at about 60 days (archive is admin-only, `FR:208-211`).
11. The participant panel and the details sheet show other children's names to any parent with a child in the class (`PCS:675-819`, `:1074-1086`).

---


Repo: `/Users/hashimniane/alluwal-work/base` at commit `0a49330`. Read-only inventory; nothing was run against a database or a device. Every statement is from reading source unless marked UNVERIFIED.

Paths are relative to the repo root. `lib/` = Flutter app, `functions/` = Cloud Functions, `apps/web/src/` = Next.js site.

## 2–3 overview. Where a parent reaches Recordings, Curriculum Books and Quran

| Screen | Flutter WEB (parent) | Flutter NATIVE phone (parent) | Next.js today |
|---|---|---|---|
| Recordings | Sidebar "Learning > Recordings" (index 7) — works | **Not reachable** (no tab, no menu entry) | `/student/recordings/`, `/teacher/recordings/` only; no parent route |
| Curriculum Books | Sidebar "Learning > Curriculum Books" (index 9) — works | Bottom tab "Library" > tab "Books" | `/student/curriculum-books/`, `/teacher/curriculum-books/` only |
| Quran | Sidebar "Learning > Quran" (index 11) — **does nothing** | Bottom tab "Library" > tab "Qur'an" (default tab) | `/student/quran/`, `/teacher/quran/` only |

There is no `apps/web/src/app/parent/` directory at this commit.

---

## 2. Recordings (parent)

### C-200 — Web entry point
- **Parent sees/does:** In the sidebar section "Learning", item "Recordings" (icon video_library_outlined). Clicking it shows the recordings screen inside the parent shell (the shell's app bar and sidebar stay). On screens narrower than 900 px the sidebar is a drawer and closes after the tap.
- **Source:** `lib/features/dashboard/config/sidebar_config.dart:519-524` (item, `screenIndex: 7`); `lib/features/parent/screens/parent_dashboard_layout.dart:105-106` (7 → `const ClassRecordingsScreen()`), `:120-132` (tap handler), `:155-161` (IndexedStack builds all screens 0..10 up front, so the recordings list is requested as soon as the parent dashboard opens, not when the item is clicked).
- **Data:** none for navigation.
- **Rules:** n/a.
- **Next.js:** none for parents. Student nav has the same item at `apps/web/src/components/StudentDashboardHome.tsx:95` → `/student/recordings/`.
- **Platform:** web-only.

### C-201 — Native phone: recordings are not reachable by a parent
- **Parent sees/does:** Nothing. A parent's phone tabs are Home, Classes, Chat, Forms, Tasks, Library (+ Circles when enabled). None opens recordings, and the Library hub holds only Qur'an and Books.
- **Source:** `lib/features/dashboard/screens/role_based_dashboard.dart:323-328` (every native user gets `MobileDashboardScreen`); `lib/features/dashboard/screens/mobile_dashboard_screen.dart:589-599` (parent screens), `:665-678` (parent tabs); `lib/features/quran_reader/screens/library_hub_screen.dart:22-32`. Every constructor call of `ClassRecordingsScreen` in `lib/`: `parent_dashboard_layout.dart:106` (web), `dashboard.dart:371` (admin web), `mobile_dashboard_screen.dart:1363` (inside `_AdminMoreScreen`, class starts `:1282`), `student_classes_screen.dart:424`, `teacher_home_screen.dart:799`, `admin_classes_screen.dart:212`, `zoom_screen.dart:849`. None is on a parent's phone path.
- **Data / Rules:** n/a.
- **Next.js:** n/a.
- **Platform:** mobile-only gap.

### C-202 — Loading the list
- **Parent sees/does:** A centred blue spinner on a light-grey page while the list loads (no header, no search bar).
- **Source:** `lib/features/recordings/screens/class_recordings_screen.dart:149-163`, `:807-816`; `lib/features/recordings/services/class_recording_service.dart:165-175`.
- **Data:** callable `listClassRecordings` (region us-central1) with `{ limit: 200, activeRole: <current active role, lower-cased> }`. `activeRole` comes from `UserRoleService.getCurrentUserRole()` and is omitted when empty.
- **Rules:** callable only; see C-203.
- **Next.js:** `apps/web/src/components/StudentRecordingsPage.tsx:435-437` sends `{ limit: 200, activeRole: "student" }` (hard-coded). Loading shows `LoadingRecordings` inside the shell with the header already drawn (`:175-176`). A parent page must send `activeRole: "parent"` (or omit it — the server then uses the primary role).
- **Platform:** both (screen code); reachable on web only.

### C-203 — Which recordings a parent gets (server authorisation)
- **Parent sees/does:** Only recordings of classes whose `student_ids` contain at least one of the parent's children.
- **Source:** `functions/handlers/livekit.js:2758-2847` (list), `:745-772` (`_resolveParentStudentIds`), `:728-731`, `:733-743`, `:547-562` (`_resolveEffectiveRole`), `:518-545` (available roles); export `functions/index.js:593`.
- **Data:**
  - Auth required (`unauthenticated` otherwise).
  - Role: reads `users/{uid}`; available roles = `user_type || userType || role`, plus `secondary_roles`/`secondaryRoles` (admins also get `teacher`; admin-teachers also get `admin`). The requested `activeRole` must be in that set or the call fails `permission-denied` "Requested role is not available for this user". With no `activeRole`, the primary role is used.
  - Children = union of (a) the parent's own `children_ids` / `childrenIds` and (b) every `users` doc where `guardian_ids` array-contains uid, and again where `guardianIds` array-contains uid (limit 1000 each; docs whose role is set and is not `student` are skipped). For each such doc the ids added are doc id, `uid`, `auth_uid`, `authUid`, `auth_user_id`, `authUserId`.
  - No children → returns `{ success: true, role: "parent", recordings: [], hasMore: false, scannedCount: 0 }`.
  - Query: collection `class_recordings`, `where('student_ids','array-contains-any', <chunk of 10 child ids>)`, `.limit(scanLimit)` per chunk, **no orderBy**; results de-duplicated by doc id. `scanLimit` defaults to 500 (client never sends it).
  - Any other role → `permission-denied` "Only students, parents, teachers, and admins can view class recordings".
- **Rules:** `firestore.rules` has no match for `class_recordings` (grep returns nothing), so clients cannot read the collection directly; access is only through the callable (Admin SDK).
- **Next.js:** same callable; the student page passes `activeRole: "student"` so the server runs the `student_ids array-contains uid` branch (`livekit.js:2808-2811`). For a parent the branch above already exists server-side — no backend change needed to list.
- **Platform:** both.

### C-204 — What the server strips, hides and sorts
- **Parent sees/does:** Never sees recordings with no file path, expired recordings, or failed recordings. Sees at most 100 recordings, newest first. In each recording the student list contains only the parent's own children (classmates' ids are removed).
- **Source:** `functions/handlers/livekit.js:2764-2773` (limit clamped to **1..100**, default 30), `:2849-2913` (map/filter/sort), `:2866-2871` (student id trimming), `:2901-2903` (filters; `includeFailed` honoured for admins only), `:2906-2911` (`canPlay`), `:887-900` (sort: startedAt → requestedAt → shiftStart → updatedAt, descending), `:2915-2921` (`slice(0, limit)`, `hasMore`).
- **Data:** per item returned: `recordingId, shiftId, segmentId, shiftName, subjectName, teacherId, teacherName, studentIds, status, error, filePath (merged path if present), bucket, egressType, mergeStatus, mergedFilePath, shiftStartIso, shiftEndIso, requestedAtIso, startedAtIso, failedAtIso, updatedAtIso, deleteAfterIso, canPlay`. `canPlay` = status is not `starting`/`failed` AND (no merge status OR merge status `completed` with a merged file).
- **Rules:** n/a.
- **Next.js:** identical (same callable). Note both clients ask for 200 and silently get 100; neither uses `hasMore` (`class_recording_service.dart:201` parses it, the screen never reads it; the web page does not read it at all).
- **Platform:** both.

### C-205 — Names shown for children and teachers
- **Parent sees/does:** Child cards show the child's name; if the user doc cannot be resolved the raw user id is shown.
- **Source:** `class_recordings_screen.dart:174`, `:202-219`, `:274-281`; `class_recording_service.dart:271-345`.
- **Data:** direct Firestore read: `users` where `documentId in <chunk of 10>` for every teacher id and every (visible) student id. Name = `first_name`/`firstName` + `last_name`/`lastName`, else `name`/`displayName`, else `e-mail`/`email`, else the id. The same doc's email and phone (`phone_number`, `phoneNumber`, `mobile_phone`, `mobilePhone`, `phone`) are kept in memory for search (C-210, C-212). Failures are swallowed (names fall back to ids).
- **Rules:** `firestore.rules:276-279` — any signed-in user may read any `users` doc.
- **Next.js:** `StudentRecordingsPage.tsx:448-467` resolves **student ids only** (not teachers); name = first+last (also `first-name`/`last-name`) else `display_name`/`displayName`/`name`; on failure shows "Student abc123" (`:710-712`) instead of the raw id; does not keep email/phone.
- **Platform:** both.

### C-206 — List failed to load
- **Parent sees/does:** Full-page white card with a red error icon, the error text, and a blue "Try Again" button that reloads. Text is the server's message when there is one (e.g. "Authentication required", "Requested role is not available for this user"), else "<code>: failed to load recordings", else "Failed to load recordings" / "Unexpected response from server".
- **Source:** `class_recordings_screen.dart:166-172`, `:818-825`, `:1586-1645`; `class_recording_service.dart:176-180`, `:203-213`.
- **Data:** none.
- **Next.js:** `StudentRecordingsPage.tsx:114-115`, `:173`, `:392-405` — an error card with "Try Again" is rendered **above** the normal content (header and the empty/list area stay visible), not as a replacement page.
- **Platform:** both.

### C-207 — No recordings
- **Parent sees/does:** Card with a video icon, "No recordings yet", "Class recordings will appear here after sessions are recorded." Search bar is hidden. Header still shows "Students" / "0 students" and the refresh button.
- **Source:** `class_recordings_screen.dart:742-746`, `:921-928`, `:1527-1584`.
- **Next.js:** `StudentRecordingsPage.tsx:177-178`, `:354-366` (same title and subtitle, `:362-363`).
- **Platform:** both.

### C-208 — Header: title, subtitle, back, refresh
- **Parent sees/does:** A white header row: back arrow (only when drilled in), title, grey subtitle, refresh icon on the right. For a parent (non-admin) the levels are Students → Dates → Shifts → Fragments (the admin-only "Teachers" level is skipped).
  - Students level: title "Students", subtitle "N student(s)".
  - Dates level: "Dates", "N date(s) with recordings".
  - Shifts level: "Shifts", "N shift(s) on this date".
  - Fragments level: the class name (fallback "Recording Fragments"), "N fragment(s) · EEE, MMM d · h:mm a".
- **Source:** `class_recordings_screen.dart:132-147`, `:761-803`, `:841-886`.
- **Next.js:** `StudentRecordingsPage.tsx:129-156`, `:615-627`. Fragments-level title is always "Recording Fragments" (never the class name).
- **Platform:** both.

### C-209 — Level 1: one card per child
- **Parent sees/does:** A card per child that has at least one recording (children with none do not appear): child name, "N recording(s)", "Latest: MMM d, yyyy". Sorted by latest recording date, newest first, then name A–Z. A recording of a class shared by two siblings is counted under each sibling. Tapping a card opens that child's dates. Pull-to-refresh reloads.
- **Source:** `class_recordings_screen.dart:375-433`, `:991-1030`, `:1147-1229`.
- **Data:** client-side grouping of `studentIds` from C-204. A recording with an empty student list would go under "Unknown Student" (`:381-386`, `:275`).
- **Next.js:** `StudentRecordingsPage.tsx:215-226`, `:495-510` — same grouping and sort; for a student this level shows one card (themselves). No pull-to-refresh (refresh button only).
- **Platform:** both.

### C-210 — Search at the child level
- **Parent sees/does:** Search box "Search student..." filters the child cards as you type. Matches on name (contains), email (contains), user id (contains), and phone (when the query looks like a phone number with 7+ digits). No match → card "No students found" / "Try a different search term."
- **Source:** `class_recordings_screen.dart:406-417`, `:748-759`, `:888-919`, `:993-999`; `lib/core/utils/app_search.dart:7-66`.
- **Next.js:** `StudentRecordingsPage.tsx:158-171`, `:508` — **name contains only**.
- **Platform:** both.

### C-211 — Level 2: dates
- **Parent sees/does:** A card per calendar day (device local time) on which the selected child has recordings: "EEEE, MMM d, yyyy" (or "Unknown date"), "N recording(s)". Newest day first. Search box "Search date..." matches the long or short date text; empty → "No recording dates found".
- **Source:** `class_recordings_screen.dart:291-303`, `:442-485`, `:1032-1070`. Date used = `startedAt ?? requestedAt ?? shiftStart ?? updatedAt` (`class_recording_service.dart:65-66`).
- **Next.js:** `StudentRecordingsPage.tsx:229-240`, `:512-526`, `:672-674` — date used = `startedAt ?? requestedAt ?? updatedAt` (**no `shiftStart` fallback**; `shiftStartIso` is not even parsed, `:487-490`). Search matches the long date only.
- **Platform:** both.

### C-212 — Level 3: classes ("Shifts") on that day
- **Parent sees/does:** A card per class session: class name, "N fragment(s) · Ready: M · <subject>", and the latest fragment time "EEE, MMM d · h:mm a". Newest first, then name. Search "Search class or subject..." matches class name, subject, class id, teacher id, teacher name, teacher email, teacher phone. Empty → "No shifts found".
- **Source:** `class_recordings_screen.dart:494-563`, `:1072-1113`.
- **Data:** grouped by `shiftId` (key `shift:<id>`), or per recording when there is no shift id.
- **Next.js:** `StudentRecordingsPage.tsx:243-254`, `:528-541` — same card; search matches **class name and subject only**.
- **Platform:** both.

### C-213 — Level 4: fragments of one class session
- **Parent sees/does:** A summary card (class name; chips "N fragments", "M ready", subject; date/time) followed by one card per fragment, oldest first. Each fragment card: a numbered square, title "Fragment N" (or "Full Recording" when there is only one), date/time, status chip, retention chip, optional error line, and the play button. No search bar on this level.
- **Source:** `class_recordings_screen.dart:1115-1145`, `:1231-1287`, `:1314-1404`, `:506-519`, `:742-745`.
- **Next.js:** `StudentRecordingsPage.tsx:257-291`, `:324-351` — fragment title is "Recording {index} of {total}"; no numbered square (icon instead).
- **Platform:** both.

### C-214 — Status chip
- **Parent sees/does:** "Processing" (amber) when status is `starting` or merge status is `pending`/`merging`; "Ready" (green) for `active`/`complete`/`ended`; "Failed" (red) for `failed` (never reaches a parent — C-204); otherwise the raw status in grey, or "Unknown".
- **Source:** `class_recordings_screen.dart:642-688`, `:1387-1402`.
- **Next.js:** `StudentRecordingsPage.tsx:337`, `:635-642` — same labels; colours: Ready green, Failed red, everything else amber.
- **Platform:** both.

### C-215 — Auto-delete countdown
- **Parent sees/does:** A chip with a bin icon: "Auto-deletes in about N month(s)" (≥28 days), "…in N week(s)" (≥14 days), "…in N days" (≥2), "…in N hours" (≥2), "…in N minutes" (≥2), "…in less than a minute", "Deleting soon" (past due), or "Auto-delete schedule unavailable"; followed by " · MMM d, yyyy" (the deletion date). Colour: red when under 3 days or past due, amber under 14 days, teal otherwise, grey when unknown.
- **Source:** `class_recordings_screen.dart:585-640`, `:1320-1324`, `:1406-1437`.
- **Data:** `deleteAfterIso` from the server = stored `delete_after` or base date + 2 calendar months (`livekit.js:28`, `:606-628`). A daily job at 03:30 UTC deletes expired recordings and their files (`livekit.js:3153-3160`).
- **Next.js:** `StudentRecordingsPage.tsx:338`, `:644-661` — same wording down to hours, then "Auto-deletes soon" (no minutes tier); **no deletion date and no colour coding** (always grey).
- **Platform:** both.

### C-216 — Error line on a fragment
- **Parent sees/does:** If the recording carries an `error` string, it is shown in small red text (max 2 lines).
- **Source:** `class_recordings_screen.dart:1438-1449`.
- **Next.js:** `StudentRecordingsPage.tsx:346` (red box, no line limit).
- **Platform:** both.

### C-217 — Play button states
- **Parent sees/does:** Full-width blue button. "Play Recording" (enabled) when `canPlay`; "Loading..." with a spinner while the link is fetched (disabled); "Processing..." (disabled, grey) when processing; "Not Ready Yet" (disabled, grey) otherwise.
- **Source:** `class_recordings_screen.dart:1481-1520`.
- **Next.js:** `StudentRecordingsPage.tsx:341-344` — small button on the right: "Play" / "Hide" / "Unavailable", spinner icon while loading.
- **Platform:** both.

### C-218 — Getting the playback link (server authorisation for a parent)
- **Parent sees/does:** Tapping "Play Recording" fetches a link and opens the inline player.
- **Source:** `class_recordings_screen.dart:690-725`; `class_recording_service.dart:216-269`; `functions/handlers/livekit.js:2933-3145`; export `functions/index.js:594-595`.
- **Data:** callable `getClassRecordingPlaybackUrl` with `{ recordingId, activeRole }`. Server:
  - reads `class_recordings/{recordingId}` (`not-found` "Recording not found"; `failed-precondition` "Recording file path is missing").
  - resolves the effective role as in C-203; for `parent`, access requires that one of the recording's `student_ids` is in the parent's child set (`:2977-2989`) — else `permission-denied` "You are not allowed to access this recording".
  - expired → the server **deletes the recording's files and document** and throws "This recording has expired and is no longer available." (`:2991-3004`).
  - merge `pending`/`merging` → "Recording is being processed"; merge `failed` → "Recording processing failed"; file missing → "Recording is not available yet. Please try again shortly." (and two similar variants `:3099-3114`).
  - link = Cloud Storage v4 signed URL, read-only, 15-minute expiry, `responseDisposition: inline` (`:3020-3032`). If signing fails it falls back to a Firebase download-token URL with **no expiry** (`:3033-3042`).
  - writes `last_playback_requested_at`, `last_playback_requested_by` (the parent's uid) and `updated_at` on the recording document (`:3072-3076`, `:3128-3132`).
  - returns `{ success, recordingId, shiftId, filePath, url, contentType, sizeBytes, expiresAtIso, trackFiles? }`. The client uses only `url` (and parses `expiresAtIso` but never uses it).
- **Storage:** bucket = the recording's `bucket`, else env `LIVEKIT_RECORDING_GCP_BUCKET`, else the default Firebase bucket (`:636-649`, `:3014-3017`). Object path pattern `<prefix>/<yyyy>/<mm>/<dd>/<shiftId>/<room>_<timestamp>` with prefix `class-recordings` unless overridden (`:369`, `:927-928`); merged file path comes from `functions/scripts/merge-worker.js`. `storage.rules` has no rule for that prefix (grep for "recordings" returns nothing), so files are reachable only through the signed link. Recordings are LiveKit egress files; no Zoom-cloud or R2 path is involved in this screen (grep for `zoom_recordings` / `r2.cloudflarestorage` in `functions/` returns nothing).
- **Rules:** callable only.
- **Next.js:** `StudentRecordingsPage.tsx:543-577` — same callable with `activeRole: "student"`. A parent page must send `"parent"`; the server branch exists.
- **Platform:** both.

### C-219 — Playback link failed
- **Parent sees/does:** A red floating snackbar with the server's message (list in C-218) or "Unable to load recording" / "Invalid recording ID" / "Playback URL not available" / "Failed to open recording"; the button returns to "Play Recording".
- **Source:** `class_recordings_screen.dart:713-717`, `:727-740`; `class_recording_service.dart:219-268`.
- **Next.js:** `StudentRecordingsPage.tsx:573-574` — the message is put in the page-level error card (C-206) whose "Try Again" button **reloads the whole list and resets the drill-down**.
- **Platform:** both.

### C-220 — Inline player
- **Parent sees/does:** The player opens inside the fragment card (no new tab, no external app). While it initialises: dark box with a spinner. Then: video (max height 360 px on web, 300 px on phones); tap the video to show/hide controls; play/pause; back 10 s / forward 10 s; a seek slider; elapsed and total time; a full-screen button that opens a black full-screen page with the same controls, the title and a back/exit button. Below the player a grey "Close Player" button collapses it. Only one fragment is expanded at a time; starting one player pauses another. If the video cannot load: grey box "Failed to load video" (or "Video player not available. Try rebuilding the app.") with a "Retry" button that retries the same link.
- **Source:** `class_recordings_screen.dart:1451-1480`; `lib/features/surah_podcast/widgets/video_player_widget.dart:34` (10 s), `:50-71` (init/error), `:95-123`, `:125-140` (full screen), `:144-185` (error box), `:187-202` (loading), `:209` (heights), `:288-365` (controls), `:396-646` (full-screen page).
- **Data:** streams the signed link directly.
- **Next.js:** `StudentRecordingsPage.tsx:347-349` — the browser's native `<video controls preload="metadata">`. Differences: no ±10 s buttons, no custom full-screen page (browser full screen instead), "Hide" on the same button instead of "Close Player"; on a load error the page shows "This recording could not be played. Refresh its playback link and try again." (`:192`). The native control bar in Chromium includes a Download entry (no `controlsList="nodownload"` on the tag) — the Flutter player offers no download.
- **Platform:** both.

### C-221 — Playback links are remembered until refresh
- **Parent sees/does:** Closing and reopening a fragment reuses the link already fetched (no second request). Links are forgotten on refresh.
- **Source:** `class_recordings_screen.dart:129`, `:699-705`, `:198`.
- **Next.js:** same (`StudentRecordingsPage.tsx:556-559`, `:612`).
- **Platform:** both.

### C-222 — Refresh
- **Parent sees/does:** The refresh icon (every level) or pull-to-refresh (list levels) reloads everything and returns to the first level with search cleared, players closed and links forgotten.
- **Source:** `class_recordings_screen.dart:155-200`, `:878-882`, `:959-961`, `:1001-1003`, `:1042-1044`, `:1082-1084`, `:1125-1127`.
- **Next.js:** refresh button only (`StudentRecordingsPage.tsx:152-154`, `:408-433`).
- **Platform:** both.

### C-223 — Back
- **Parent sees/does:** The back arrow goes up one level (fragments → shifts → dates → children) and clears the search filter; leaving the fragments level closes the player. There is no back arrow on the first level.
- **Source:** `class_recordings_screen.dart:137-147`, `:221-245`, `:847-854`.
- **Next.js:** `StudentRecordingsPage.tsx:141-147`, `:580-597` (same).
- **Platform:** both.

### C-224 — Actions a parent does NOT have
- **Parent sees/does:** No download, share, delete, rename, upload, transcript or comment action anywhere on the screen — for any role. There is no delete callable for recordings; deletion happens only by the retention job or by the expired-on-playback path (C-218).
- **Source:** whole file `class_recordings_screen.dart` (1646 lines read; the only buttons are back, refresh, level cards, Play Recording, Close Player, Try Again, and the player controls); `functions/handlers/livekit.js:662-712` (`_deleteClassRecordingAssets` is called only from `:2993`, `:3193`, `:3232`).
- **Next.js:** none on the student/teacher pages either, except the browser's own download entry noted in C-220. `RecordingsAdmin.tsx` also has no delete (grep).
- **Platform:** both.

### C-225 — Dual-role accounts
- **Parent sees/does:** The list follows the role currently selected in the role switcher: the same person switched to "teacher" sees their own classes' recordings; switched to "parent" sees their children's.
- **Source:** `class_recording_service.dart:169-175`, `:224-230`; `livekit.js:547-562`; switcher in `parent_dashboard_layout.dart:189-192`, `:212-215`.
- **Next.js:** each page hard-codes its role (`StudentRecordingsPage.tsx:437`, `:564`; `TeacherRecordingsPage.tsx:425`, `:552`; `RecordingsAdmin.tsx:304`).
- **Platform:** both.

### C-226 — Language
- **Parent sees/does:** Every string on the recordings screen is English regardless of the app language, except the error card's "Try Again" button.
- **Source:** hard-coded literals throughout `class_recordings_screen.dart` (e.g. `:748-803`, `:923-926`, `:1498-1505`); only `:1631` uses `AppLocalizations`.
- **Next.js:** all strings go through `useT()` (en/fr) in `StudentRecordingsPage.tsx`.
- **Platform:** both.

---

## 3a. Curriculum Books (parent)

### C-300 — Web entry point
- **Parent sees/does:** Sidebar "Learning > Curriculum Books" (icon menu_book) opens the books page inside the parent shell.
- **Source:** `lib/features/dashboard/config/sidebar_config.dart:525-531` (`screenIndex: 9`); `lib/features/parent/screens/parent_dashboard_layout.dart:109-110`.
- **Data / Rules:** none.
- **Next.js:** none for parents. Student nav item at `apps/web/src/components/StudentDashboardHome.tsx:102` → `/student/curriculum-books/`; teacher at `TeacherDashboardHome.tsx:132`.
- **Platform:** web-only.

### C-301 — Native phone entry point
- **Parent sees/does:** Bottom tab "Library" (6th tab) opens a page titled "Library" with two tabs, "Qur'an" (first, shown by default) and "Books". "Books" is this same curriculum screen.
- **Source:** `lib/features/dashboard/screens/mobile_dashboard_screen.dart:596`, `:672`; `lib/features/quran_reader/screens/library_hub_screen.dart:16-33`; labels `lib/l10n/app_en.arb:7718-7722`. `LibraryHubScreen` is used by exactly two roles on phones: teachers (`mobile_dashboard_screen.dart:544`) and parents (`:596`). Students and admins reach the two screens separately through their own tabs / "More" grids.
- **Next.js:** n/a.
- **Platform:** mobile-only.

### C-302 — Page header
- **Parent sees/does:** A light gradient panel: badge "Shared Learning Materials", heading "Curriculum Books", paragraph "These are the Arabic curriculum PowerPoints used across classes. Teachers, students, parents, and administrators can open or download them from here.", and three chips "All roles", "PowerPoint files", "Arabic curriculum". Text on the page is selectable. No loading, empty or error state exists (the list is built into the app).
- **Source:** `lib/features/curriculum/screens/curriculum_books_screen.dart:57-104`, `:106-198`.
- **Data:** none.
- **Next.js:** `apps/web/src/components/StudentCurriculumBooksPage.tsx:110-124` — same badge, heading, paragraph and chips (translated through `useT`).
- **Platform:** both.

### C-303 — Phone-only notice
- **Parent sees/does:** On phones/tablets only, an orange info box: "On phones and tablets, these PowerPoint books open in your browser or presentation app."
- **Source:** `curriculum_books_screen.dart:158-184` (`if (!kIsWeb)`).
- **Next.js:** none (and none is needed for a web page).
- **Platform:** mobile-only.

### C-304 — The list of books (hard-coded)
- **Parent sees/does:** Exactly four cards, always in this order, identical for every role and every child:
  1. الحُرُوفُ الهِجَائِيَّةُ وَالمَفْتُوحَةُ — "Alphabet and open-vowel practice" — `alphabet_and_fatha.pdf` / `.pptx` — teal `#0F766E`
  2. الحُرُوفُ المَضْمُومَةُ — "Damma lessons" — `damma_lessons.pdf` / `.pptx` — blue `#2563EB`
  3. الحروف المفتوحة — "Open-vowel reading practice" — `open_letters_practice.pdf` / `.pptx` — amber `#D97706`
  4. الحروف المكسورة — "Kasra lessons" — `kasra_lessons.pdf` / `.pptx` — violet `#7C3AED`
  Two columns at ≥1100 px wide, otherwise one.
- **Source:** `curriculum_books_screen.dart:11-55` (list), `:59-60`, `:77-94` (grid).
- **Data:** no Firestore, no callable. Files at `https://storage.googleapis.com/alluwal-academy.firebasestorage.app/curriculum/<file>`.
- **Rules:** `storage.rules:112-116` — `match /curriculum/{fileName}`: `allow read: if true; allow write: if request.auth != null;`. Whether the plain `storage.googleapis.com/...` URL (which bypasses Firebase rules and needs the objects to be public in Cloud Storage) is served publicly is UNVERIFIED — not fetched.
- **Next.js:** `StudentCurriculumBooksPage.tsx:30-69` — the same four books, same order, same URLs and descriptions, also hard-coded (third copy in `TeacherCurriculumBooksPage.tsx:32-65`, fourth in `CurriculumBooksAdmin.tsx:25-58`).
- **Platform:** both.

### C-305 — A book card
- **Parent sees/does:** Coloured slideshow icon, Arabic title (Cairo font), English subtitle in the book's colour, a one-sentence English description, and two buttons: filled "Open" and outlined "Download".
- **Source:** `curriculum_books_screen.dart:227-329`.
- **Next.js:** `StudentCurriculumBooksPage.tsx:225-269` (same content; "Open" has a book icon instead of an open-in-new icon).
- **Platform:** both.

### C-306 — "Open" on the web
- **Parent sees/does:** Opens the PDF version in a **new browser tab** (`<pdfUrl>#view=Fit`). If the browser refuses, a snackbar "Unable to open this curriculum book right now."
- **Source:** `curriculum_books_screen.dart:375-384`, `:407-416`.
- **Next.js:** `StudentCurriculumBooksPage.tsx:129`, `:150-199` — **different**: "Open" shows the book in an in-page reader dialog (Google Docs viewer in an iframe, `https://docs.google.com/gview?embedded=true&url=<pdfUrl>`), with "New tab" (the Flutter-web behaviour) and "Download" buttons (both hidden below the `sm` breakpoint), a close button and Esc to close. `TeacherCurriculumBooksPage.tsx:179` still links straight to `<pdfUrl>#view=Fit` (the Flutter-web behaviour).
- **Platform:** web-only.

### C-307 — "Open" on a phone
- **Parent sees/does:** Pushes a full-screen in-app viewer: app bar with the book's English subtitle and a download icon; the PDF rendered through Google's document viewer in a WebView; a spinner until the page finishes loading. Back returns to the list. No error state if the viewer fails to load (the spinner stops on page-finished only).
- **Source:** `curriculum_books_screen.dart:385-391`, `:419-475` (`https://docs.google.com/gview?embedded=true&url=<encoded pdfUrl>`).
- **Next.js:** n/a (phone app). The student web reader (C-306) uses the same Google viewer URL.
- **Platform:** mobile-only.

### C-308 — "Download"
- **Parent sees/does:** Opens the **PowerPoint (.pptx)** file: on the web in a new tab (the browser downloads it); on a phone through the external browser / presentation app. Same failure snackbar as C-306. The phone viewer's download icon does the same (no failure message there).
- **Source:** `curriculum_books_screen.dart:394-405`, `:457-463`.
- **Next.js:** `StudentCurriculumBooksPage.tsx:257-266` — plain link to the `.pptx` in a new tab; no failure message.
- **Platform:** both (different launch mode).

### C-309 — Things this screen does not have
- **Parent sees/does:** No search, no categories or filters, no per-child assignment or progress, no "last opened", no role differences, no sign-in dependency (the screen makes no authenticated request), no admin-managed list.
- **Source:** whole file `curriculum_books_screen.dart` (495 lines read).
- **Next.js:** same on the student page; `CurriculumBooksAdmin.tsx` is also a static list (grep for `collection`/`doc(` finds none).
- **Platform:** both.

### C-310 — Language
- **Parent sees/does:** All text is English (plus the Arabic titles) whatever the app language, except the "Download" button label.
- **Source:** literals at `curriculum_books_screen.dart:129`, `:140`, `:150`, `:173`, `:190-192`, `:312`, `:411`; `:319` is the only localized string.
- **Next.js:** all strings through `useT()` (en/fr), except book subtitles/descriptions which are passed as data.
- **Platform:** both.

---

## 3b. Quran (parent)

Short answers first:
- **Is the Quran reader gated by role?** No. Nothing in `lib/features/quran_reader/**` reads the user's role (grep for `UserRoleService` / `role` finds nothing). Recitation checks and memorization are available to whoever can open the screen.
- **Server-side role checks?** None. `transcribeRecitation` and `checkPronunciation` only require a signed-in user. `quran_memorization/{userId}` is readable/writable only by that same uid.
- **Whose data?** Always the signed-in user's own uid — for a parent, the **parent's own** memorization, goal, streak and reminder. There is **no per-child state** and no way to view a child's memorization (rules would refuse it).
- **Web parents today:** cannot open the reader at all (C-330).

Web reader reference: `apps/web/src/components/QuranReaderPage.tsx` (shared reader), wrapped by `StudentQuranPage.tsx` (57 lines) and `TeacherQuranPage.tsx` (72 lines). The wrapper only resolves access + uid and supplies the shell (`QuranReaderPage.tsx:156-160`), so a parent wrapper is the same shape as `TeacherQuranPage.tsx:24-70` with a parent gate and parent shell.

### C-330 — Web entry point is dead
- **Parent sees/does:** Sidebar "Learning > Quran" is visible. Clicking it does nothing: the page does not change and the item does not highlight.
- **Source:** `lib/features/dashboard/config/sidebar_config.dart:532-538` (`screenIndex: 11`); `lib/features/parent/screens/parent_dashboard_layout.dart:40` (`_screenCount = 11`), `:120-121` (`if (index < 0 || index >= _screenCount) return;`), `:155-161` (IndexedStack generated for 0..10 only), `:113-114` (the `case 11` that would return `QuranReaderScreen` is never reached); the sidebar passes the raw `screenIndex` (`lib/features/dashboard/widgets/custom_sidebar.dart:637`, `:913`).
- **Data / Rules:** none.
- **Next.js:** none for parents.
- **Platform:** web-only. Confirmed by reading; not clicked in a browser.

### C-331 — Native phone entry point
- **Parent sees/does:** Bottom tab "Library" → tab "Qur'an" (default). The reader is embedded under the Library app bar and tab bar, with its own app bar below them.
- **Source:** `mobile_dashboard_screen.dart:596`, `:672`; `library_hub_screen.dart:16-33`.
- **Next.js:** n/a.
- **Platform:** mobile-only.

### C-332 — Opening the reader
- **Parent sees/does:** A spinner, then Surah 1 (Al-Fatihah) in Reading mode with reciter id 7. If the first load fails: "Couldn't load the Quran. Check your connection." with a "Try again" link (which retries only the verse load).
- **Source:** `lib/features/quran_reader/screens/quran_reader_screen.dart:43-52`, `:77-106`, `:835-850`; text `lib/l10n/app_en.arb:7898`.
- **Data:** in parallel: `GET https://api.quran.com/api/v4/chapters?language=en`; `GET …/resources/recitations?language=en` (falls back to a built-in list of 8 reciters on failure, `quran_api.dart:83-92`, `:123-138`); Firestore `get quran_memorization/{own uid}` (`memorization_service.dart:131-172`). 25 s timeout per API call (`quran_api.dart:98-106`). Nothing is cached locally; selection, mode and reciter are not remembered between visits.
- **Rules:** `firestore.rules:1275-1277` — `allow read, write: if isSignedIn() && request.auth.uid == userId`.
- **Next.js:** `QuranReaderPage.tsx:219-244` (memorization doc), `:358-392` (chapters + reciters; built-in fallback list has 3 reciters with ids 7, 2, 3 — Flutter's has 8 with ids 7, 1, 3, 4, 5, 6, 9, 10). If chapters fail the web shows no error (reader stays usable with fallbacks); verse-load errors show the raw error message (`:468-471`, `:745-746`) and no retry button.
- **Platform:** both (screen code).

### C-333 — Surah / Juz picker
- **Parent sees/does:** The app-bar title ("<name> · <Arabic name>", "Juz N" or "Today's memorization") with a drop-down arrow opens a bottom sheet with a Surah | Juz switch. Surah tab: search field (matches English name contains, Arabic name contains, or exact number) and the list of 114 surahs (number, English name, "<meaning> · N verses", Arabic name). Juz tab: Juz 1–30. Choosing one loads it.
- **Source:** `quran_reader_screen.dart:360-376`, `:476-481`, `:717-730`, `:1062-1150`.
- **Data:** `GET /verses/by_chapter/{id}?words=true&word_fields=text_uthmani,text_imlaei,audio_url&fields=text_uthmani&translations=20&word_translation_language=en&audio={reciter}&per_page=50&page=N` or `/verses/by_juz/{id}?…`, following `pagination.next_page` up to 40 pages (`quran_api.dart:172-206`).
- **Next.js:** `QuranReaderPage.tsx:598-605` (picker button in the controls row labelled "N. Name"), `:1092-1152` — search also matches the English meaning; "No surah found" empty text; Juz shown as a grid; current selection highlighted. API params omit `word_translation_language=en` (`:439`) and there is no 40-page cap.
- **Platform:** both.

### C-334 — Loading / failing a selection
- **Parent sees/does:** Spinner while verses load; on failure "Couldn't load this selection. Try again." with a "Try again" link. Any playing audio stops when the selection changes.
- **Source:** `quran_reader_screen.dart:109-142`, `:835-850`; `app_en.arb:7899`.
- **Next.js:** `QuranReaderPage.tsx:406-477`, `:738-746` — "Loading the Quran…"; error text is the raw exception message; no retry control.
- **Platform:** both.

### C-335 — Reciter
- **Parent sees/does:** App-bar voice icon opens a menu of reciters (name plus style in brackets, current one bold). Choosing one reloads the current selection with that reciter's audio.
- **Source:** `quran_reader_screen.dart:752-768`; `quran_api.dart:123-138`.
- **Next.js:** `QuranReaderPage.tsx:606-617` (a `<select>`).
- **Platform:** both.

### C-336 — Play the whole selection / Stop
- **Parent sees/does:** App-bar play button plays from the first ayah and continues ayah by ayah to the end; while playing it becomes a stop button. Disabled when nothing is loaded. There is no pause/resume and no word-by-word highlight; the ayah being played is tinted teal (Reading) or outlined (Translation). The view does not auto-scroll.
- **Source:** `quran_reader_screen.dart:313-350`, `:732-746`, `:875-877`, `:926-933`.
- **Data:** ayah audio `https://verses.quran.com/<audio.url>` (`quran_api.dart:12`, `:167`).
- **Next.js:** `QuranReaderPage.tsx:496-553`, `:618-626`, `:479-494`, `:564-567`, `:899-910` — Play starts at the repeat range's first ayah; **adds** pause/resume, a bottom "Playing verse X" bar, word-by-word yellow highlighting from timing segments, and auto-scroll to the playing ayah.
- **Platform:** both.

### C-337 — Repeat
- **Parent sees/does:** App-bar repeat icon opens a sheet: "Repeat each ayah" slider 1×–10×; "Loop ayahs" with "from" and "to" drop-downs (— or 1..N); a "Play" button that closes the sheet and starts at "from" (does nothing if "from" is —). With both ends set, playback loops that range endlessly until stopped.
- **Source:** `quran_reader_screen.dart:58-61`, `:330-350`, `:378-472`.
- **Next.js:** `QuranReaderPage.tsx:31`, `:628-655`, `:974-1019` — a pop-over with "Repeat each ayah" (1, 2, 3, 5, 7, 10, ∞), "Play from ayah … to …" (defaults 1..N, reset on each load `:465-466`), "Repeat this range" (same options, finite by default) and "Done"; the Repeat button is tinted when any setting is non-default.
- **Platform:** both.

### C-338 — Reading / Translation switch
- **Parent sees/does:** Two icon buttons (book, translate) switch between Reading (mushaf-style flowing text) and Translation (one card per ayah). Not remembered.
- **Source:** `quran_reader_screen.dart:28`, `:52`, `:680-703`, `:794-806`, `:851-852`.
- **Next.js:** `QuranReaderPage.tsx:667-668` (text chips "Reading" / "Translation").
- **Platform:** both.

### C-339 — Reading mode
- **Parent sees/does:** Right-to-left Uthmani text (Amiri, 26 pt). Tapping a word plays that word's audio. After each ayah a round badge with the ayah number (Latin digits), green when memorized. Tapping the badge opens a sheet with three actions: "Play verse <key>", "Check recitation", "Mark memorized" / "Memorized — tap to unmark".
- **Source:** `quran_reader_screen.dart:352-356`, `:855-915`, `:1012-1058`.
- **Data:** word audio `https://verses.quran.com/<word.audio_url>` (`quran_api.dart:150-151`).
- **Next.js:** `QuranReaderPage.tsx:747-816` — 30 px text; tapping a word plays it **and** opens a bottom bar with the word, its transliteration and English meaning (`:555-562`, `:880-897`); the ayah-end marker uses Arabic-Indic digits and plays the ayah directly; separate inline tick (memorize) and mic (check) icons instead of an action sheet; in Juz view a "﴾ surah name ﴿" divider is shown where a new surah starts (`:755-761`).
- **Platform:** both.

### C-340 — Translation mode
- **Parent sees/does:** A card per ayah: the Arabic words (each tappable to hear it), the English translation (Saheeh International, resource id 20, HTML stripped), the verse key (e.g. 2:255), and three icon buttons: play/stop this ayah, microphone (check recitation), memorized toggle (green tick when memorized).
- **Source:** `quran_reader_screen.dart:918-1009`; `quran_api.dart:13`, `:165-166`, `:215-216`.
- **Next.js:** `QuranReaderPage.tsx:818-876` — adds a transliteration line (`:871`); play button pauses/resumes; memorize is a labelled chip "Memorize" / "Memorized"; shows the ayah number (verse key only in Juz view).
- **Platform:** both.

### C-341 — Marking an ayah memorized
- **Parent sees/does:** The tick flips immediately; the "Memorized x/y" line and the goal progress bar update. Un-ticking reverses it.
- **Source:** `quran_reader_screen.dart:146-158`; `memorization_service.dart:187-201`.
- **Data:** `quran_memorization/{own uid}` `set(merge)`: `memorized.<surahId>` arrayUnion/arrayRemove `[ayah]`, `daily_log.<YYYY-MM-DD local>` increment ±1 (nested map), `updated_at` serverTimestamp. No error handling: a failed write leaves the tick shown locally.
- **Rules:** `firestore.rules:1275-1277`.
- **Next.js:** `QuranReaderPage.tsx:246-276` — same document; also updates today's count locally. The daily-count write uses the key `` [`daily_log.${day}`] `` inside `setDoc(..., { merge: true })` (`:269`) while reads use the nested map `data.daily_log` (`:236`) — see "Broken" list.
- **Platform:** both.

### C-342 — Memorized counters
- **Parent sees/does:** Under the controls: green tick + "Memorized x/y" for the loaded selection, and on the right the parent's total memorized ayahs.
- **Source:** `quran_reader_screen.dart:708-712`, `:811-828`.
- **Next.js:** `QuranReaderPage.tsx:684-697` (adds a green progress bar).
- **Platform:** both.

### C-343 — Goal panel when there is no goal
- **Parent sees/does:** A teal panel at the top of the reader (always visible): sparkle icon, title "Memorize the Quran", the line "A few ayahs a day — we'll split it up, track you, and remind you.", and a white "Create my goal" button.
- **Source:** `quran_reader_screen.dart:492-544`, `:773-776`; `app_en.arb:7813-7814`, `:7913`.
- **Next.js:** `QuranReaderPage.tsx:656-665` — a small "Goal" chip in the controls row instead of a panel.
- **Platform:** both.

### C-344 — Goal sheet (create / edit)
- **Parent sees/does:** Bottom sheet "Memorization plan": Surah | Juz | Whole Quran switch (default Surah 1, or the saved plan); a surah drop-down ("N. Name (verses)") or a juz drop-down; "Ayahs per day" slider 1–20 (default 3); an estimate line (ayahs per day, total ayahs, duration in days / months / years); "Start memorizing" (or "Update goal"); and, when a plan exists, "Stop plan".
- **Source:** `lib/features/quran_reader/widgets/goal_sheet.dart:12-20`, `:67-83`, `:85-205`; opened from `quran_reader_screen.dart:160-193`.
- **Next.js:** `QuranReaderPage.tsx:1022-1089` — modal; default scope follows what is currently open (`:1032-1035`); per-day is a − / + stepper from 1 to 50; also shows "finish around <date>".
- **Platform:** both.

### C-345 — Saving a goal
- **Parent sees/does:** The sheet closes, the reader switches to "Today's memorization" (C-347), and — the first time a goal is created with no reminder set — a dialog offers a daily reminder (C-349).
- **Source:** `quran_reader_screen.dart:166-177`; `memorization_service.dart:203-214`.
- **Data:** `quran_memorization/{own uid}` merge: `plan: { scope: "quran" | "surah:<id>" | "juz:<id>", perDay, startDate: "YYYY-MM-DD" }`, `updated_at`. Then the doc is re-read.
- **Next.js:** `QuranReaderPage.tsx:278-320` (same fields; no reminder offer).
- **Platform:** both.

### C-346 — Goal panel when a goal exists
- **Parent sees/does:** The top panel shows "Today · n of perDay ayahs" (or "Done for today 🎉", and the panel turns green, when today's count ≥ perDay); a "🔥 N day(s)" streak chip when > 0; a bell icon (yellow when a reminder is on); a pencil (edit goal); a progress bar and the line "x of y ayahs of <scope> · p%"; and a button "Practice today's ayahs" (or "Review anyway" when today's goal is met) that loads today's ayahs.
- **Source:** `quran_reader_screen.dart:546-657`, `:483-488`, `:712`; streak = consecutive days (ending today or yesterday) with at least **one** ayah logged (`memorization_service.dart:110-120`).
- **Next.js:** the Goal chip shows "Today n/perDay" (`QuranReaderPage.tsx:656-665`); the fuller banner appears **only inside goal mode** (`:711-732`): "Today's memorization · n/perDay today", "x of y ayahs · ~duration left", streak, "Change goal", "Browse Quran". Streak on the web counts days where the count reached **perDay** (`:344-353`). No bell.
- **Platform:** both.

### C-347 — "Today's memorization" (goal mode)
- **Parent sees/does:** The reader loads exactly the next `perDay` not-yet-memorized ayahs of the plan's scope (in mushaf order) with every normal tool available (play, repeat, word tap, tick, recitation check, recite from memory). Title "Today's memorization".
- **Source:** `quran_reader_screen.dart:296-309`, `:118-124`; ordering `memorization_service.dart:55-89`; juz boundaries `quran_api.dart:17-22`.
- **Data:** one `GET /verses/by_key/{surah}:{ayah}?…&audio={reciter}` per ayah, sequentially (`quran_api.dart:208-213`).
- **Next.js:** `QuranReaderPage.tsx:304-313`, `:441-449`; when nothing is left it shows "You've memorized this whole selection. Ma sha Allah! 🎉" (`:734-736`) — the Flutter reader shows an empty page in that case (no dedicated text).
- **Platform:** both.

### C-348 — Stopping a goal
- **Parent sees/does:** "Stop plan" in the goal sheet removes the goal, cancels the phone reminder, and returns the reader to Surah 1 if it was in goal mode. Memorized ticks are kept.
- **Source:** `quran_reader_screen.dart:178-192`; `memorization_service.dart:216-223`, `:174-185`.
- **Data:** merge `plan: delete`; then merge `reminder: { enabled: false, hour: 20, minute: 0 }`.
- **Next.js:** `QuranReaderPage.tsx:293-300`, `:1085` (deletes `plan` only; never touches `reminder`).
- **Platform:** both.

### C-349 — Daily reminder (phone only)
- **Parent sees/does:**
  - After creating a first goal: dialog "Memorization sticks when it's daily. Want a gentle reminder each evening?" with "Not now" / "Set reminder".
  - Bell with no reminder: a time picker (default 20:00), then the OS notification permission prompt. If refused: snackbar "Notifications are blocked — allow them in Settings to get reminders." If granted: snackbar "Daily reminder set for <time> — you can change it anytime with the bell."
  - Bell with a reminder on: dialog showing the time with "Turn off", "Change time", "Keep".
  - Every day at that local time the phone shows a local notification titled "Quran time 📖": "Today's goal: N ayah(s). A little every day goes far — you've got this."
  - Each time the reader opens with a goal and an enabled reminder, the notification is re-scheduled.
- **Source:** `quran_reader_screen.dart:90-98`, `:196-293`; `lib/features/quran_reader/services/goal_reminder_service.dart:16-20`, `:23-37`, `:40-90`, `:92-95`; `app_en.arb:7900`, `:7902`.
- **Data:** `quran_memorization/{own uid}.reminder = { enabled, hour, minute }`. Local notification id 78011, Android channel `quran_goal_reminders`, repeating daily, inexact. No push/FCM and no server involvement.
- **Rules:** as C-341.
- **Next.js:** **none** — the web reader neither reads nor writes `reminder` (grep `reminder` in `QuranReaderPage.tsx`: no match).
- **Platform:** mobile-only. On Flutter web `_supported` is false, so the bell would always end in the "Notifications are blocked" snackbar (`goal_reminder_service.dart:20-24`).

### C-350 — "Recite from memory" (whole selection)
- **Parent sees/does:** A pill button under the goal panel (disabled when nothing is loaded) stops playback and opens a full screen titled "Recite from memory" with the selection name. The screen shows "N done" and "N slips", the whole selection as greyed-out words with numbered ayah badges, and a big "Start reciting" button with a hint line. Two ways of working, switchable with a Live | Record & check control when live is available:
  - **Live** (default on a real phone with speech recognition): the phone's own speech recognizer follows the voice in Arabic; recited words turn green; a skipped or out-of-order ayah turns red and triggers a strong vibration plus the system alert sound ("slip"); the text being heard is shown; the recognizer restarts itself after silences; reaching the last word ends the session automatically; "Stop" ends it. In parallel each ayah is recorded and sent for a pronunciation check when the reciter moves on; flags arrive a couple of seconds later with a double vibration, and "Checking pronunciation…" shows while any are pending.
  - **Record & check**: records the whole take; "Stop & check" sends it; then the result is replayed as an animation (about 9 words a second) with the same colours and vibrations; "Stop" interrupts the replay.
  - After either: flagged words are amber (harakah) or orange (sound); a "pronunciation review" list gives a line per flagged word ("<word> — a harakah sounded like damma (ـُ) — it should be kasra (ـِ)" / "<word> — a sound in this word needs checking"); tapping a flagged word opens a compare bar with "You · word", the reciter's word, and the reciter's ayah; "Start over" restarts.
  - Errors: microphone refused → "Microphone access was blocked. Allow the mic and try again."; speech permission refused → "Allow microphone and speech recognition to follow your recitation live."; check failed → "We couldn't check that recitation. Please try again."; on a simulator: "Live follow-along needs a real phone — a simulator has no microphone input."; if the per-ayah recorder cannot start: "Pronunciation checking is off — the mic is busy with live tracking."
- **Source:** `quran_reader_screen.dart:781-792`; `lib/features/quran_reader/screens/follow_along_screen.dart:42-99`, `:112-171` (live availability, Arabic locale choice), `:204-231` (audio session), `:235-339` (per-ayah recording + check), `:342-488` (live), `:490-541` (record), `:543-605` (flags + replay), `:612-651` (compare playback), `:653-667` (colours), `:670-895` (layout), `:898-936` (ayah badges), `:939-1010` (compare bar), `:1013-1077` (main button); matching logic `lib/features/quran_reader/logic/arabic_recitation.dart:14-239`; texts `app_en.arb:7978-8004`.
- **Data:** callables `transcribeRecitation` and `checkPronunciation` (C-353). Recordings are AAC `.m4a`, mono, written to the app's temporary directory (`follow_`/`seg_<ms>.m4a`) and never uploaded to Storage by the client. Nothing is written to Firestore; a recitation result does not tick ayahs as memorized.
- **Next.js:** `apps/web/src/components/RecitationFollowAlong.tsx` opened from `QuranReaderPage.tsx:698-708`, `:947-959`. Differences: the mode is chosen automatically and cannot be switched (`:65` — live when the browser has speech recognition, else record, else an "unsupported browser" message `:824`); slips beep (with a mute button `:797`) instead of vibrating; shows "Ayah n of total" (`:810`); the compare bar has four buttons including "You · ayah" (`:890-920`); recordings are browser `MediaRecorder` blobs.
- **Platform:** both in code; on Flutter the recording path uses `dart:io` files, so it works on phones only (UNVERIFIED on Flutter web — parents cannot reach it there anyway).

### C-351 — Check one ayah: "Words" mode
- **Parent sees/does:** From the microphone icon (Translation mode) or the ayah badge sheet (Reading mode): a bottom sheet "Check your recitation — Verse <key>" with a Words | Pronunciation (beta) switch, the ayah's words, "Hear the correct recitation" (plays the reciter's ayah), and "Start reciting". Recording → "Stop & check" → "Checking your recitation…" → result: each word turns green (recited) or red (not matched), the transcript is shown as "Heard: …", "Play your recitation" replays the recording, tapping a word replays just that word from the parent's own recording, and the button becomes "Try again". Legend: "Green = right · amber = check the harakah · red = wrong word." Before a result, tapping a word plays the reciter's word.
- **Source:** `lib/features/quran_reader/widgets/recitation_check_sheet.dart:30-44`, `:77-139`, `:151-185`, `:187-208`, `:266-425`, `:462-506`; `app_en.arb:7999`.
- **Data:** callable `transcribeRecitation` `{ audioBase64, filename: "recitation.mp4" }` → `{ text, words: [{ word, start, end }] }` (`recitation_service.dart:55-83`). Matching is done on the device (`arabic_recitation.dart:69-99`, `:101-…`).
- **Next.js:** `apps/web/src/components/RecitationCheck.tsx` opened from `QuranReaderPage.tsx:937-945`. Differences: Words mode also marks **amber "Ending to check"** words and shows "You recited x of y words" (`:201-222`, `:332-365`) — the Flutter Words mode is green/red only; has "Done"/"Close" buttons; "Recording isn't available in this browser…" fallback (`:379`); the words in the sheet are **not tappable at all** (plain spans, `:270-274`) — so neither "tap a word to hear the reciter's word" nor "tap a word to replay your own word" exists on the web.
- **Platform:** both in code; phones only in practice on Flutter.

### C-352 — Check one ayah: "Pronunciation (beta)" mode
- **Parent sees/does:** Same sheet, second mode: words turn green (ok), amber (ending), orange (sound) or red (missed); a box says "No pronunciation issues caught. Ma sha Allah!" or "N word(s) to review" with a line per flagged word (same wording as C-350, plus "this word wasn't heard clearly") and the note "Beta — catches clear vowel/ending mistakes. It's a practice aid, not a substitute for a teacher." Switching mode after a result re-checks the **same recording** in the other mode without re-recording.
- **Source:** `recitation_check_sheet.dart:108-120`, `:142-149`, `:189-201`, `:210-263`, `:365-396`.
- **Data:** callable `checkPronunciation` `{ audioBase64, filename, words: [imlaei text of each word, falling back to Uthmani] }` → `{ words: [{ word, status: ok|ending|sound|missed, expected_ending, heard_ending }] }` (`recitation_service.dart:86-104`). A warm-up call `{ warm: true }` is sent when the sheet opens (`:42-48`, sheet `:67`).
- **Next.js:** `RecitationCheck.tsx:98-105`, `:258-261`, `:289-327` (same modes and wording; warm-up is done by the follow-along component `RecitationFollowAlong.tsx:146-148`).
- **Platform:** as C-351.

### C-353 — The two recitation callables and how they authorise a parent
- **Parent sees/does:** n/a (backend).
- **Source:** `functions/handlers/quran_asr.js:24-72`; `functions/handlers/quran_phoneme.js:25-41`, `:43-130`; exports `functions/index.js:653-654`.
- **Data:**
  - `transcribeRecitation`: requires `request.auth` only ("Sign in to check your recitation."); no role check; audio ≤ 9 MB; forwards to the private Cloud Run service `quran-asr-…run.app/transcribe`; returns `{ text, words, duration }`; errors "Transcription failed (status)".
  - `checkPronunciation`: requires `request.auth` only; no role check; `words` must be 1–120 strings under 60 chars; forwards to `quran-phoneme-…run.app/check` with one retry on 5xx; errors "Pronunciation check failed (status)". **Side effect:** every real check saves the caller's audio and the verdict to the default Storage bucket at `recitation_debug/{uid}/{timestamp}.{mp4|ogg|webm}` and `.json` (`quran_phoneme.js:25-41`, `:120-122`) and logs the uid and verdicts.
- **Rules:** callable-level auth only. `storage.rules` has no entry for `recitation_debug` (grep), so those files are not client-readable.
- **Next.js:** same two callables, same payloads (`RecitationCheck.tsx:99`, `:105`; `RecitationFollowAlong.tsx:234`, `:335`, `:619-620`). A parent is accepted as-is.
- **Platform:** both.

### C-354 — Whose data, and per-child state
- **Parent sees/does:** Everything in the reader (ticks, totals, goal, streak, reminder) belongs to the signed-in account. A parent sees their own progress, never a child's; there is no child picker.
- **Source:** `memorization_service.dart:131-136` (`FirebaseAuth.instance.currentUser?.uid`); `firestore.rules:1275-1277`; grep for `quran_memorization` in `lib/` finds only the quran_reader files (and an unrelated string in `website/models/teacher_application.dart`).
- **Data:** document `quran_memorization/{uid}`: `memorized { "<surahId>": [ayah…] }`, `plan { scope, perDay, startDate }`, `daily_log { "YYYY-MM-DD": count }`, `reminder { enabled, hour, minute }`, `updated_at`.
- **Next.js:** `QuranReaderPage.tsx:224`, `:266`, `:284`, `:298` — same document keyed by the `uid` the wrapper passes in. Passing the parent's uid reproduces the Flutter behaviour exactly.
- **Platform:** both.

### C-355 — Things the reader does not have
- **Parent sees/does:** No bookmarks, no "continue where you left off", no translation language choice (English Saheeh International only), no tafsir, no font-size control, no offline download, no sharing, no verse search (surah-name search only), no teacher/parent view of someone else's progress.
- **Source:** whole `lib/features/quran_reader/**` read (grep for `SharedPreferences`, `bookmark`, `last_read`, `lastRead` finds nothing).
- **Next.js:** same absences in `QuranReaderPage.tsx`. `apps/web/src/components/QuranAmbientPlayer.tsx` is unrelated to the dashboard reader: it renders only on public marketing pages (`:61`, `:138`), uses mp3quran.net audio and `localStorage`, and no other source file references it (grep) — UNVERIFIED whether it is mounted anywhere at this commit.
- **Platform:** both.

### C-356 — Language
- **Parent sees/does:** Most reader text follows the app language (82 `quran*` strings exist in English and French; an Arabic file also exists). Still English-only: the goal-sheet intro sentence, the reminder-set snackbar, "the Quran" scope label, "from"/"to" labels, "N done"/"N slips", "You · word", "🔥 N day(s)", the pronunciation note sentences, the beta disclaimer, "N word(s) to review", "Live follow-along needs a real phone…", and the phone notification text.
- **Source:** `lib/l10n/app_en.arb` / `app_fr.arb` (82 matches each); literals at `goal_sheet.dart:104`, `quran_reader_screen.dart:250`, `:424`, `:441`, `:484`, `:591`; `follow_along_screen.dart:130`, `:318`, `:322`, `:693`, `:700`, `:966`; `recitation_check_sheet.dart:221-225`, `:380`, `:388`; `goal_reminder_service.dart:64-68`.
- **Next.js:** everything through `useT()` (en/fr).
- **Platform:** both.

---

### Broken / dead / hard-coded today

Each line is from reading the code; none was reproduced on a device or against production data.

**Navigation**
1. **Parent "Quran" sidebar item does nothing on Flutter web.** `parent_dashboard_layout.dart:40` (`_screenCount = 11`), `:121` (early return for index ≥ 11), `:157-160` (stack built for 0..10) versus `sidebar_config.dart:536` (`screenIndex: 11`). `case 11` at `:113-114` is unreachable.
2. **Parents cannot reach Recordings on phones.** `mobile_dashboard_screen.dart:589-599`, `:665-678`; `library_hub_screen.dart:28-33`. So "what parents have today" for recordings is the web screen only.

**Recordings**
3. **The client asks for 200 recordings, the server caps at 100, and `hasMore` is ignored.** `class_recordings_screen.dart:163`; `functions/handlers/livekit.js:2768-2770`, `:2918-2919`; `class_recording_service.dart:201` (parsed, never read by the screen). Same on the web (`StudentRecordingsPage.tsx:437`). There is no "load more" anywhere.
4. **The parent query has no ordering before its 500-document scan cap.** `livekit.js:2831-2835` (`array-contains-any` + `.limit(scanLimit)`, no `orderBy`), `:2771-2773`. If one chunk of children ever matches more than 500 stored recordings, which ones are dropped is decided by document id, not by date. (Bounded in practice by the 2-month retention; actual volumes UNVERIFIED.)
5. **Search box keeps its text after drilling in.** The `TextField` has no controller (`class_recordings_screen.dart:891-892`), while every drill/back sets `_searchQuery = ''` (`:227-242`, `:1023`, `:1063`, `:1106`). The filter is cleared but the box still shows the old text.
6. **Playback links are cached with no regard to their 15-minute expiry.** `class_recordings_screen.dart:699-705` reuses the cached link; `class_recording_service.dart:249-251` parses `expiresAtIso` but nothing uses it; `livekit.js:3022`. After 15 minutes, reopening a fragment gives "Failed to load video", and "Retry" retries the same dead link (`video_player_widget.dart:165-167`); only the page refresh fixes it. Same caching on the web (`StudentRecordingsPage.tsx:556-559`).
7. **Fallback playback link never expires.** If URL signing fails the server mints/reuses a permanent Firebase download token and returns that URL (`livekit.js:3033-3042`).
8. **Asking to play an expired recording deletes it.** `livekit.js:2991-3004` — any authorised caller (including a parent) triggers deletion of the files and the document.
9. **Every play request rewrites `updated_at` on the recording.** `livekit.js:3072-3076`, `:3128-3132`; the admin list orders by `updated_at` (`:2797`).
10. **Teacher contact details are loaded into a parent's browser for search.** `class_recording_service.dart:318-336` reads the teacher's whole user document (email, phone) and `class_recordings_screen.dart:538-547` searches on them. Allowed by `firestore.rules:279` (any signed-in user reads any user doc).
11. **Dead code:** `ClassRecordingService.getStudentNamesForShift` is never called (`class_recording_service.dart:349-394`; grep). `_ShiftBucket.teacherName` is computed but only used for search — the teacher's name is never displayed to a parent (`class_recordings_screen.dart:530`, `:542`).
12. **Hard-coded English** throughout the recordings screen (C-226).

**Curriculum Books**
13. **The book list is hard-coded in four places.** `lib/features/curriculum/screens/curriculum_books_screen.dart:14-55`; `apps/web/src/components/StudentCurriculumBooksPage.tsx:32-69`; `TeacherCurriculumBooksPage.tsx:32-65`; `CurriculumBooksAdmin.tsx:25-58`. Adding a book needs a code change and an app release.
14. **The phone notice contradicts the phone behaviour.** It says books "open in your browser or presentation app" (`curriculum_books_screen.dart:173`), but "Open" shows the PDF in an in-app viewer (`:385-391`, `:444-445`); only "Download" leaves the app.
15. **The page says "PowerPoint" but "Open" shows a PDF.** `curriculum_books_screen.dart:150`, `:191` versus `:378`, `:445`.
16. **Any signed-in user may overwrite the curriculum files.** `storage.rules:113-116` (`allow write: if request.auth != null`).
17. **Unused field:** `_CurriculumBook.fileName` (`curriculum_books_screen.dart:22`, `:483`) is never read.
18. **Web "Open" already differs between roles and from Flutter web:** student = in-page reader (`StudentCurriculumBooksPage.tsx:150-199`), teacher = new tab (`TeacherCurriculumBooksPage.tsx:179`), Flutter web = new tab (`curriculum_books_screen.dart:376-381`).

**Quran**
19. **"Today · n of N" does not move when an ayah is ticked (Flutter).** `_toggleMemorized` updates only the memorized set (`quran_reader_screen.dart:146-157`); today's count is read from `_mem.dailyLog` (`:712`), which is refreshed only when the document is re-read (goal save/clear, reminder change, reopening the screen).
20. **Web daily counts are written to a different field from the one that is read.** `QuranReaderPage.tsx:269` writes the key `` `daily_log.${day}` `` through `setDoc(..., { merge: true })`; with `setDoc` a dotted key is a literal field name, not a path into the `daily_log` map that `:236` reads and that Flutter writes (`memorization_service.dart:198`). Expected effect: on the web, today's count and streak reset on reload and never reach the phone app. Based on Firestore SDK semantics; the production document was not inspected — UNVERIFIED against data.
21. **Streak means two different things.** Flutter: consecutive days with at least 1 ayah (`memorization_service.dart:110-120`). Web: consecutive days that reached the daily target (`QuranReaderPage.tsx:344-353`).
22. **Un-ticking can push a day's count below zero** in the stored document (`memorization_service.dart:198`; web `QuranReaderPage.tsx:269` — the web clamps only its local copy, `:261`).
23. **Repeat range is not reset when the selection changes (Flutter).** `_rangeFrom` / `_rangeTo` (`quran_reader_screen.dart:60-61`) survive `_loadSelection` (`:109-115`); the drop-downs then receive an `initialValue` that may not be among their items (`:422`, `:440`). Runtime effect UNVERIFIED. With only "from" set, nothing loops (`:340`).
24. **Each recitation check stores the user's voice recording server-side** at `recitation_debug/{uid}/…` with no retention logic in this handler (`functions/handlers/quran_phoneme.js:25-41`, `:120-122`). Applies to any parent who uses the check.
25. **Reminder is phone-only and invisible to the web.** `goal_reminder_service.dart:20`; no `reminder` handling in `QuranReaderPage.tsx`.
26. **Words-mode legend mentions amber, but Flutter Words mode never shows amber.** `app_en.arb:7999` versus `recitation_check_sheet.dart:203-207` (green/red only).
27. **No message when today's goal list is empty (Flutter).** `quran_reader_screen.dart:296-309`, `:855-886` — an empty page; the web shows a completion message (`QuranReaderPage.tsx:734-736`).
28. **Hard-coded English fragments** inside an otherwise localized reader (C-356).

### Questions for the owner

1. **Quran for parents on the web.** Today the parent's "Quran" sidebar item is dead on the web and works on phones (Library tab). Should the new parent web area include the Quran reader (matching the phone app), or leave it out (matching what web parents actually get today)?
2. **If yes — whose progress?** The reader tracks the signed-in person. Is a parent's own memorization/goal what you want there, or did you expect parents to see their children's progress? (The second does not exist anywhere today and the database rules forbid it.)
3. **Recordings on phones.** Parents have no way to open recordings in the phone app. Is that intended? (It does not block the web rebuild, but it is the opposite of the web.)
4. **Recordings list size.** A parent sees at most the 100 newest recordings with no "load more". Keep exactly that on the new page?
5. **Playback.** The Flutter player has no download button. A plain browser video player offers "Download" in its menu. Must the new parent page block downloading?
6. **Teacher details.** Today a parent can search recordings by a teacher's email or phone number (the data is loaded into the page). Keep, or limit to the teacher's name?
7. **Opening a book on the web.** Flutter web opens the PDF in a new tab; the student web page opens it in a reader inside the page. Which one should the parent page do?
8. **Daily reminder.** The goal reminder is a phone notification and does not exist on the web. Confirm the parent web reader should simply have no bell.
9. **Recitation recordings.** Each pronunciation check keeps a copy of the voice recording on the server for tuning. Are you comfortable with that applying to parents?
10. **Daily-goal count on the web (item 20 above).** Should it be fixed before the reader is given to another role, or carried over as-is?

---

## 4. Chat (parent)

> Inventory of what a PARENT gets from the Flutter chat today. Repo `/Users/hashimniane/alluwal-work/base` @ `0a49330`. Paths are relative to the repo root. `CS` = `lib/features/chat/services/chat_service.dart`, `CPS` = `lib/features/chat/services/chat_permission_service.dart`, `CP` = `lib/features/chat/screens/chat_page.dart`, `CSC` = `lib/features/chat/screens/chat_screen.dart`, `MB` = `lib/features/chat/widgets/message_bubble.dart`, `FR` = `firestore.rules`, `SR` = `storage.rules`.
> The same code serves all roles; a parent is "non-admin" everywhere (`UserRoleService.isAdmin()` is true only for `admin`/`super_admin`, `lib/core/services/user_role_service.dart:243-247`).

### 4.1 Entry points and shell

**C-400 — Web entry: sidebar "Chat" opens the chat page inside the parent shell**
- **Parent sees/does:** Sidebar item "Chat" (screenIndex 10) shows `ChatPage` in the content area next to the sidebar. All 11 parent screens (indexes 0–10) are built at once in an `IndexedStack` and kept alive, so the chat list listener and the contacts load start as soon as the parent dashboard loads, not when Chat is first clicked; tab, search text and scroll position survive switching to another sidebar item.
- **Source:** `lib/features/parent/screens/parent_dashboard_layout.dart:85-116` (case 10 → `const ChatPage()` at :112), `:152-164` (IndexedStack); sidebar item `lib/features/dashboard/config/sidebar_config.dart:499-502`.
- **Data:** see C-404, C-412..C-414.
- **Rules:** n/a.
- **Next.js:** none for parents. Student equivalent is the route `apps/web/src/app/student/chat/page.tsx` rendering `StudentChatPage` (see 4.11). No other parent screen links into chat: `ChatScreen` is constructed only from `ChatPage`, push-notification taps and the (teacher/admin) audit screens.
- **Platform:** web only (native uses C-402).

**C-401 — Web sidebar shows NO unread indicator for Chat**
- **Parent sees/does:** No dot/count on the "Chat" sidebar item, whatever the unread state. The only unread signal on web is the per-row pill inside the Recent tab (C-405); there is no browser push either (C-464).
- **Source:** `CustomSidebar` supports `badgeScreenIndices` (`lib/features/dashboard/widgets/custom_sidebar.dart:15,26,662,994`) but `ParentDashboardLayout._buildSideMenu` does not pass it (`parent_dashboard_layout.dart:375-388`). The only caller that passes it is the admin dashboard (`lib/features/dashboard/screens/dashboard.dart:1852`).
- **Data:** none.
- **Next.js:** n/a.
- **Platform:** web only.

**C-402 — Native phone entry: bottom-nav "Chat" tab with an unread badge**
- **Parent sees/does:** On iOS/Android every role gets `MobileDashboardScreen`; a parent's bottom-nav screens are, in order, `AdminDashboard`, `ParentClassesScreen`, **`ChatPage`** (index 2, label l10n `navChat`), `ParentFormsScreen`, `QuickTasksScreen`, `LibraryHubScreen` (+ `TontineHomeScreen` if enabled). The Chat tab icon carries a green pill with the total unread count (sum of `unreadCount` over all rows of `getUserChats()`, i.e. 1:1 + groups + Admin Support), "99+" above 99, hidden at 0.
- **Source:** `lib/features/dashboard/screens/role_based_dashboard.dart:323-328` (native → MobileDashboardScreen); `lib/features/dashboard/screens/mobile_dashboard_screen.dart:588-597` (parent screens), `:669` (nav item `isChat: true`), `:1190-1191`, `:1235-1277` (badge).
- **Data:** same stream as C-404 (a second, independent listener on `chats`).
- **Next.js:** n/a (native stays on Flutter).
- **Platform:** mobile only.

**C-403 — Chat page layout: two tabs + one search box; no "Create Group" button for parents**
- **Parent sees/does:** Segmented tab bar "Recent" / "Contacts" (l10n `chatRecentChats` / `chatMyContacts`), a search field (hint l10n `chatSearchConversations`, fallback "Search conversations...") that filters whichever tab is showing, then the tab content (swipeable `TabBarView`). The floating "Create Group" button is rendered only when `_isAdmin`; a parent never sees it. Whole page is wrapped in `SelectionArea` (text is selectable on web).
- **Source:** `CP:88-123` (layout, FAB gate :120), `:125-181` (tabs), `:183-223` (search), `:50-55` (`_isAdmin`).
- **Data:** none.
- **Next.js:** `StudentChatPage` has the same two tabs + search — see C-470.
- **Platform:** both.

### 4.2 Recent tab (conversation list)

**C-404 — Recent list: which conversations appear, ordering, live updates**
- **Parent sees/does:** Every chat doc whose `participants` contains the parent's uid AND that has a `last_message` map: 1:1 chats, group chats the parent was added to, and the parent's own Admin Support thread. Sorted by last-message time, newest first. Updates live. A 1:1 row is dropped when the other user's `users` doc no longer exists; any row is dropped when no visible last message can be resolved (C-409). No pagination, no limit.
- **Source:** `CS:107-130` (`getUserChats`), `:157-159` (`_hasRecentMessage`), `:327-407` (`_processChatSnapshot`; user-doc requirement :388), `CP:253-281`, `:407-420`.
- **Data:** listener `chats.where('participants', arrayContains: uid).snapshots()` (no orderBy, no limit; client-side sort). Other users fetched with `users.where(documentId, whereIn: <=30 ids>)` in batches of 30 (`CS:409-427`). Per chat, per snapshot: one `get()` of unread messages (C-408) and possibly one of the last 20 messages (C-409).
- **Rules:** `FR:657` `allow read: if isSignedIn()` on `chats/{chatId}` (any signed-in user can read ANY chat doc; the participant filter is client-side only). `users` read `FR:279`.
- **Next.js:** `StudentChatPage` — see C-470.
- **Platform:** both.

**C-405 — Recent row content**
- **Parent sees/does:** Per row: 56px rounded avatar (profile picture, else initials; group icon for groups); green online dot (non-group, online); name (falls back to e-mail when the name is blank); blue unread pill (count, "99+" above 99) when > 0; a coloured chip under the name — for a group "Group Chat" (l10n `groupChat`) + "N members"; otherwise the leader job title if any (C-460) else the role label ("Administrator" / "Teacher" / "Student" / "Parent" / raw role); if `role` is null the e-mail is shown instead; last-message preview (max 2 lines) with a time chip: "now", "Nm", "Nh", "Nd", else "D/M".
- **Source:** `lib/features/chat/widgets/chat_user_list_item.dart:22-118`, `:120-208` (avatar/online dot), `:210-242` (unread pill), `:244-320` (chip; leader title :301), `:322-362`, `:396-411` (time format), `:379-394` (role labels).
- **Data:** fields of `users/{otherUid}`: `first_name`, `last_name`, `email`/`e-mail`, phone variants, `profile_picture_url`→`profile_picture`, `user_type`, `title`, `is_online`, `last_seen`/`last_login` (`CS:449-479`).
- **Next.js:** see C-470.
- **Platform:** both.

**C-406 — Admin Support row in Recent**
- **Parent sees/does:** Once the parent's support thread has at least one message, it appears as a normal row named "Admin Support" with chip "Administrator" (role `'admin'`, no title → no leader title), initials avatar "AS", no online dot, last-message preview/time and its own unread pill. Tapping it opens the support thread (C-417). Before any message exists there is no row (the thread is reachable only from the Contacts tab card, C-412).
- **Source:** `CS:366-387` (row built with id `admin_support`), `CP:848-858` (`_openChat` routes `admin_support` to `_openAdminSupportChatAsUser`).
- **Data:** chat doc `chats/{sorted(uid,'admin_support') joined by '_'}`, `participants: [uid,'admin_support']`, `chat_type: 'admin_support'`.
- **Next.js:** `StudentChatPage`/`TeacherChatPage` `normalizeChat` — see C-470.
- **Platform:** both.

**C-407 — Group rows in Recent; long-press opens group info**
- **Parent sees/does:** A parent cannot create a group but can be a member of one (an admin adds them — the admin picker lists every user, C-450). The group row shows group name (fallback "Unnamed Group"), "Group Chat" chip, member count, preview, unread pill. Tap opens the group conversation; long-press opens the `GroupInfoDialog` (C-451).
- **Source:** `CS:336-348`, `:429-447`; `CP:408-415`, `:1007-1012`.
- **Data:** chat doc with `chat_type: 'group'`, `group_name`, `group_description`, `participants[]`, `admin_ids[]`, `created_by`, `created_at`, `updated_at`, `last_message`.
- **Next.js:** `StudentChatPage` lists groups — see C-470.
- **Platform:** both (long-press on web = mouse press-and-hold).

**C-408 — Unread count per conversation (`ChatService.isIncomingFor`)**
- **Parent sees/does:** The pill counts messages with `is_read == false` that are "incoming for me" and not hidden-for-me. For a parent the rule reduces to "sender is not me" — in 1:1, in groups, and in their own Admin Support thread (the member reads everything that is not theirs; the staff-side special case only applies when the viewer is NOT the member). Consequences: in a group, `is_read` is a single shared flag, so once ANY member opens the group the messages stop counting as unread for everybody; `system` messages ("X created this group", "A added B") count as unread.
- **Source:** `CS:60-75` (`isIncomingFor`), `:1400-1421` (`_getUnreadCount`), `:181-185` (hidden-for-me).
- **Data:** `chats/{id}/messages.where('is_read', isEqualTo: false).get()` — one query per chat on every `chats` snapshot; no limit. The list refreshes because opening a chat writes `last_read_by.{uid}` on the chat doc (C-422).
- **Rules:** `FR:676` messages read for any signed-in user.
- **Next.js:** `StudentChatPage` — see C-471.
- **Platform:** both.

**C-409 — Last-message preview text**
- **Parent sees/does:** Preview is the `content` of `last_message` (text; or "📷 Photo"/caption, "🎥 Video"/caption, "📎 <file name>", "🎤 Voice message", location name). If that message was deleted for everyone: "You deleted this message" (deleted by me), "This message was deleted by admin <name>" (group admin deleted someone else's), else "This message was deleted". If the last message was hidden with "Delete for me", the newest of the last 20 messages that is not hidden for me is used instead; if none, the row disappears.
- **Source:** `CS:187-244` (`_extractVisibleLastMessage`, `_resolveVisibleLastMessage`, `_recentMessagePreview`).
- **Data:** `chats/{id}.last_message` (full copy of the message map); fallback `messages.orderBy('timestamp', desc).limit(20).get()`.
- **Next.js:** see C-470.
- **Platform:** both.

**C-410 — Recent tab states**
- **Parent sees/does:** Not signed in → "Please sign in / Authentication required to view chats". First load → spinner with l10n `loadingMessages`. Stream error containing `permission-denied` → "Access denied / Please sign in to view chats"; any other error → l10n `somethingWentWrong` + "Error loading chats". Empty → l10n `chatNoConversations` ("No conversations yet") + `chatStartConversation` ("Start a conversation by browsing all users"). Search with no hit → `chatNoChatsFound` ("No chats found") + `chatTryDifferentSearch`. Note: errors inside the snapshot mapper are swallowed and yield an empty list (`CS:125-128`), so a failed unread/user fetch shows as "No conversations yet", not as an error.
- **Source:** `CP:253-306`, `:660-799`.
- **Next.js:** see C-470.
- **Platform:** both.

**C-411 — Search (both tabs)**
- **Parent sees/does:** Typing filters rows client-side by: name contains (normalised), e-mail contains, uid/doc-id contains, or phone match when the query looks like a phone number with ≥ 7 digits. For groups the "e-mail" is the group description. On the Contacts tab the Admin Support card is kept when the lower-cased query is a substring of `"admin support"`. Message bodies are NOT searched; there is no in-conversation search anywhere.
- **Source:** `CP:43-47`, `:286-292`, `:446-458`, `:567-575`; `lib/core/utils/app_search.dart:7-66`.
- **Next.js:** see C-470.
- **Platform:** both.

### 4.3 Contacts tab (who a parent can message)

**C-412 — "Support" section: Admin Support card (always first for non-admins)**
- **Parent sees/does:** Header "Support" with a red headset icon, then a card "Admin Support" / "Message the school administrators" with a chevron. Tapping creates the support chat doc if missing (or repairs a corrupted one) and opens the thread (C-417). If the create call fails the error is only logged and the screen opens anyway. The card is shown even while/if the contact groups are empty.
- **Source:** `CP:456-505`, `:577-622`, `:862-887`; `CS:539-567` (`getOrCreateAdminSupportChat`).
- **Data:** `chats/{chatId}.get()`; if absent `set({participants:[uid,'admin_support'], chat_type:'admin_support', created_at, updated_at})`; if present but wrong → `update({participants, chat_type})`.
- **Rules:** create `FR:661-663` (uid in participants); update `FR:666-668`.
- **Next.js:** `StudentChatPage` has an Admin Support contact — see C-472.
- **Platform:** both.

**C-413 — "Administrators" group: every leader, messageable 1:1**
- **Parent sees/does:** A group "Administrators" (count chip) listing every user whose `user_type` is `admin`, `super_admin`, `ceo` or `founder`, plus every user with `is_admin_teacher == true` (teachers with admin rights). No `is_active` filter — deactivated admins are listed too. Each row shows avatar, name, online dot and the leader title or role chip (C-460). Tapping opens a personal 1:1 chat with that admin (not the shared inbox); `canMessage` is always true when either side is a privileged admin.
- **Source:** `CPS:191-194`, `:462-486` (`_getAdminUsers`), `:31-39` (`_isPrivilegedAdmin`), `:60-62`.
- **Data:** `users.where('user_type', whereIn:['admin','super_admin','ceo','founder']).get()` + `users.where('is_admin_teacher', isEqualTo:true).get()`.
- **Rules:** `FR:279` (any signed-in user may read/list `users`).
- **Next.js:** student page — see C-472.
- **Platform:** both.

**C-414 — "Teachers" group: teachers of the parent's children (exact resolution)**
- **Parent sees/does:** A group "Teachers" listing each teacher who has at least one non-cancelled class with one of the parent's children whose `shift_end` is later than now − 30 days (so: classes in the last 30 days or any future class). Children are taken from `users/{parent}.children_ids`; ONLY if that array is empty/missing does it fall back to students whose `guardian_ids` contains the parent. A child present only in `guardian_ids` is ignored when `children_ids` is non-empty. Archived shifts are not consulted (parents cannot read the archive). Other parents, the parent's own children, and unrelated students/teachers are never listed. Groups with no members are removed, so a parent with no current teacher sees only Support + Administrators.
- **Source:** `CPS:228-232`, `:610-664` (`_getParentChildrenTeachers`), lookback constant `:27`.
- **Data:** `users/{parentId}.get()` → `children_ids`; fallback `users.where('user_type','==','student').where('guardian_ids', arrayContains: parentId).get()`; per child `teaching_shifts.where('student_ids', arrayContains: childId).get()` (no date filter server-side, no limit — reads every live shift of every child; filters `status != 'cancelled'`, `teacher_id != null`, `shift_end > now-30d` on the client); then `users.where(documentId, whereIn: teacherIds).get()` in ONE query (not batched — see Broken B-3).
- **Rules:** `teaching_shifts` list `FR:477` (`isSignedIn()`); `users` `FR:279`.
- **Next.js:** student page resolves contacts differently — see C-472.
- **Platform:** both.

**C-415 — Contacts tab behaviour and states**
- **Parent sees/does:** Contacts are loaded once when the page is created (i.e. at dashboard load on web); they refresh only by pull-to-refresh (`RefreshIndicator`; with a mouse on web there is no visible refresh control — UNVERIFIED in a browser) or by reloading the app. Loading → spinner. Not signed in → "Please sign in / Authentication required to view contacts". If the search hides everything including the support card → "No contacts match your search / Try a different search term". The "No contacts available…" empty state is admin-only. If contact loading throws, the result is an empty map: the parent silently sees only the Admin Support card. Contact rows have no last-message line and no long-press action for a parent (long-press "Direct Message / Support Chat" sheet is admin-only).
- **Source:** `CP:57-79`, `:423-565` (long-press gate :555-556), `CPS:256-260`.
- **Next.js:** see C-472.
- **Platform:** both.

**C-416 — Who a parent may actually message (`canMessage`) — enforced in the UI only**
- **Parent sees/does:** Opening a 1:1 runs `canMessage(parent, other)`: allowed if the other user is a privileged admin (admin/super_admin/ceo/founder/admin-teacher); allowed if the other is a `teacher` with an active teaching relationship (same 30-day rule) to one of the parent's children; otherwise refused ("Parents can't message students or other parents directly"). Extra unlock: if the open thread already contains a message from the other person, the composer unlocks regardless (reply right). When refused the composer is replaced by a red locked bar (l10n `chatTeachingRelationshipOnly`); while checking, a "Checking chat permissions…" bar is shown. Nothing server-side enforces this (rules allow any signed-in user to create a chat they are in and post as themselves).
- **Source:** `CPS:42-106` (parent branch :86-93), `:264-338`; `CSC:221-275`, `:179-195` (inbound unlock), `:912-983`, `:2027-2040`.
- **Data:** `users/{a}`, `users/{b}` gets; `teaching_shifts.where('teacher_id','==',t).where('student_ids', arrayContains: child).get()` per child (equality + array-contains; `firestore.indexes.json` has no composite index for it).
- **Rules:** `FR:661-663`, `FR:680-681` — no relationship check.
- **Next.js:** student page has no `canMessage` gate — see C-473.
- **Platform:** both.

### 4.4 Opening a conversation; header; Admin Support thread

**C-417 — Admin Support thread (parent side)**
- **Parent sees/does:** Opens from the Contacts card (C-412), the Recent row (C-406) or a push tap (C-463). Header: name "Admin Support", avatar initials "AS", status line = l10n `roleAdmin` ("Administrator"); never online / last-seen. A pale-blue banner above the composer reads "Admin Support". Composer is always enabled (no permission check). The parent's messages are right-aligned blue. Every admin reply is ALSO right-aligned, in teal, with the replying admin's real name above it in teal and no avatar (the "other admin" styling fires for the member too because `_supportRealUserId` is the parent's own uid). Read ticks show only on the parent's own messages. All message features of 4.5/4.6 apply. Opening marks every not-mine unread message read (C-422).
- **Source:** `CP:862-887`; `CSC:132-139` (effective chat id), `:235-241` (always allowed, context "Admin Support"), `:883-890` (`isOtherAdmin`), `MB:63-72`, `:101-116`.
- **Data:** chat doc id `[uid,'admin_support'].sort().join('_')`; messages keep the real admin as `sender_id`/`sender_name`; no admin is in `participants`.
- **Rules:** parent reads/creates/updates as participant `FR:657-668`; messages `FR:676-684`.
- **Next.js:** `StudentChatPage` support thread — see C-472/C-474.
- **Platform:** both.

**C-418 — Opening any conversation: full-screen route, header, no call buttons**
- **Parent sees/does:** Tapping a row pushes `ChatScreen` as a new full-screen `MaterialPageRoute` via `Navigator.of(context)` (the parent layout declares no nested navigator, so on web it covers the whole dashboard including the sidebar — UNVERIFIED visually; the back arrow returns to the list). Header: back button, 44px avatar (picture / initials / group icon), online dot, name, status line, and a ⋮ menu. Status line for a person: green "Online" chip (l10n `chatOnline`) if online; else, if a last-seen time is known, the text "Last sent <just now | N min ago | N hr ago | N days ago | on D/M>" (wording says "sent" but the value is the user's `last_seen`); else the leader title / role label (l10n `roleAdmin` / `roleTeacher` / `roleStudent` / `roleParent`); else "Offline". Presence shown here is the snapshot taken when the list row was built — it does not update while the conversation is open. For a group the status line is a green chip with the group description (or "Group chat"). There are NO audio/video call buttons, no search, no profile view.
- **Source:** `CP:848-858`; `CSC:515-688` (app bar), `:690-757` (status), `:2817-2832` (last-seen format).
- **Data:** none beyond the `ChatUser` passed in.
- **Next.js:** see C-474.
- **Platform:** both.

**C-419 — Relationship banner above the composer (1:1)**
- **Parent sees/does:** A thin pale-blue strip with an icon and text: with a teacher of their child → "Parent of your student" (the label is written from the teacher's point of view but is shown to the parent as-is); with a user whose `user_type` is admin/super_admin → "Administrator"; with someone who has no formal relationship but has already written in the thread → "Administrator" (privileged), "Staff / coach" (teacher) or "Conversation"; otherwise no strip.
- **Source:** `CPS:341-421`; `CSC:256-263`, `:998-1022`, `:2084-2091`.
- **Data:** same reads as C-416.
- **Next.js:** none (see C-474).
- **Platform:** both.

### 4.5 Message list and bubbles

**C-420 — Message list: newest 50 only, live, no pagination**
- **Parent sees/does:** Live list, newest at the bottom (reversed `ListView`). Only the newest 50 messages of the conversation are ever loaded; there is no "load older" — anything older than the 50th message is unreachable in the app. Messages the parent removed with "Delete for me" are filtered out (and still count toward the 50). States: spinner while connecting; on error a red icon + l10n `chatErrorLoadingMessages`; empty → chat-bubble illustration, l10n `startTheConversation` and "Send a message to begin chatting with <name>".
- **Source:** `CS:482-513`; `CSC:782-909`.
- **Data:** `chats/{chatId}/messages.orderBy('timestamp', descending:true).limit(50).snapshots()`. `chatId` = `[uid, otherUid].sort().join('_')` for 1:1, the doc id for groups, the support id for Admin Support. (Any id containing `_` is treated as a ready chat id, `CS:490-500`.)
- **Rules:** `FR:676`.
- **Next.js:** see C-475.
- **Platform:** both.

**C-421 — Bubble layout and timestamps**
- **Parent sees/does:** Incoming: left, white bubble, small avatar (`sender_profile_picture` or initials), sender name in blue above the bubble (shown in 1:1 as well as groups). Own: right, blue bubble. Under the content: italic "edited " if edited, then time — "HH:mm" today, "Yesterday HH:mm", else "D/M HH:mm" (24h, device local time; no day separators). `system` messages (group created / added / removed / left) are centred grey pills. A message deleted for everyone shows an italic placeholder: "You deleted this message" / "This message was deleted by admin <name>" / "This message was deleted". Bubble max width 70% of the screen.
- **Source:** `MB:58-168`, `:170-190`, `:192-238`, `:299-340`, `:1074-1112`, `:1593-1609`; `lib/features/chat/models/chat_message.dart:198-207`.
- **Data:** message fields, see C-467.
- **Next.js:** see C-475.
- **Platform:** both.

**C-422 — Read receipts and mark-as-read**
- **Parent sees/does:** Own messages show one grey ✓ (sent) or a green ✓✓ (`is_read == true`). Opening a conversation — and any later snapshot that contains an unread message from someone else — marks all unread incoming, not-hidden messages read and stamps `last_read_by.<uid>` on the chat doc (this write is what makes the list's unread pill refresh). In a group the flag is shared: ✓✓ appears as soon as ANY other member opens the group, and one member reading clears the unread count for all.
- **Source:** `CSC:197-204`, `:817-833`; `CS:1352-1392`; `MB:1101-1110`.
- **Data:** `messages.where('is_read','==',false).get()` → batch `update({is_read:true})` (single batch; > 500 unread would fail); `chats/{id}.update({'last_read_by.<uid>': serverTimestamp})` (errors ignored).
- **Rules:** message update `FR:684` (any signed-in user may update any message); chat update `FR:666-668`.
- **Next.js:** see C-471.
- **Platform:** both.

**C-423 — Text rendering: mentions highlighted, links not clickable**
- **Parent sees/does:** Message text is plain. `@Name` / `@All` tokens are styled as mentions. URLs are not linkified (cannot be tapped/clicked); the whole screen is a `SelectionArea`, so on web text can be selected and copied with the mouse.
- **Source:** `MB:285-297`, `:342-390`; `CSC:372-373`. (`url_launcher` is used only for files and maps, `MB:887-895`, `:1064-1071`.)
- **Next.js:** see C-475.
- **Platform:** both.

### 4.6 Composer and message actions

**C-424 — Send a text message**
- **Parent sees/does:** Multi-line field (grows to 120px), hint "Type a message..." (or "Reply to <name>..."), sentence capitalisation. While the field is empty the right button is a microphone (C-435); once non-blank it becomes a blue send button. Text is trimmed; blank is ignored. The field clears immediately, the list scrolls to the bottom, focus returns to the field. If the write fails the error is only logged — the typed text is gone and nothing tells the parent. (`onSubmitted` also sends; with a multi-line field on web/desktop the Enter key inserts a newline — UNVERIFIED in a browser.)
- **Source:** `CSC:1144-1226`, `:2023-2082`; `CS:570-645`.
- **Data:** reads `users/{uid}` (for `first_name`/`last_name`/`profile_picture`) and `chats/{chatId}`; if the chat doc is missing → `set({participants:[uid, other], chat_type:'individual', created_at, updated_at, last_message})` (support id → `participants:[member,'admin_support'], chat_type:'admin_support'`), else `update({updated_at, last_message})`; then `messages.add({sender_id, sender_name (name or e-mail or 'Unknown'), sender_profile_picture, content, timestamp: serverTimestamp, is_read:false, message_type:'text', metadata})`. The create fires `onChatMessageCreated` (4.9).
- **Rules:** `FR:661-668`, `FR:680-681` (`sender_id == auth.uid`).
- **Next.js:** see C-476.
- **Platform:** both.

**C-425 — Message context menu (long-press only)**
- **Parent sees/does:** Long-pressing a bubble (press-and-hold with the mouse on web; there is no right-click or hover menu) opens a popup: "React" (l10n `chatReact`), "Reply" (`chatReply`), "Copy" (`commonCopy`; text messages only), "Forward" (`chatForward`), "Edit" (own text messages only), "Delete" (`commonDelete`; always present). For a message already deleted for everyone only "Delete" remains. System pills have no menu.
- **Source:** `MB:73-74`, `:1444-1558`, `:1560-1591`.
- **Next.js:** see C-477.
- **Platform:** both.

**C-426 — Reply (quote)**
- **Parent sees/does:** "Reply" shows a preview bar above the composer ("Replying to <sender>" + up to 2 lines of the original, ✕ to cancel). The sent message carries a quote block (sender name + original text) above its bubble. Tapping the quote does nothing (no jump to the original). Only text sends carry the quote; attachments sent while a reply is pending do not, and the pending reply stays until a text is sent or it is cancelled.
- **Source:** `CSC:1234-1304`, `:2042-2052`, `:2067-2070`, `:2093-2098`; `MB:118-121`, `:1115-1160`.
- **Data:** `metadata.reply_to = {message_id, content, sender_name}`.
- **Next.js:** see C-477.
- **Platform:** both.

**C-427 — Reactions**
- **Parent sees/does:** "React" opens a bottom sheet with six quick emojis 👍 ❤️ 😂 🎉 😮 😢 and a "More" tile that opens a full emoji picker. One reaction per user per message; choosing the same emoji again removes it, choosing another replaces it. Under the bubble, chips show each emoji with its count (the parent's own highlighted); tapping a chip toggles that emoji for the parent. Failure → red snackbar "Failed to update reaction". Not available on deleted messages.
- **Source:** `MB:47-55`, `:1164-1386`, `:1388-1442`; `CSC:2357-2378`; `CS:1709-1778`.
- **Data:** `messages/{id}.update({'reactions.<uid>': emoji})` / `FieldValue.delete()`.
- **Rules:** `FR:684`.
- **Next.js:** see C-477.
- **Platform:** both.

**C-428 — Copy**
- **Parent sees/does:** "Copy" puts the message text on the clipboard and shows a green snackbar (l10n `chatCopied`) for 2 s.
- **Source:** `MB:1568-1580`.
- **Next.js:** see C-477.
- **Platform:** both.

**C-429 — Forward**
- **Parent sees/does:** "Forward" opens a dialog "Forward Message" with a preview ("Message:"), "Select a chat:" and the parent's Recent conversations (same stream as the Recent tab) minus the current one; "No other chats available" when empty; groups are tagged "Group". Choosing one and pressing "Forward" sends a new message there with the same content, type and metadata (media reuse the same file URL — nothing is re-uploaded) plus `forwarded: true` and `original_sender`. Success → green snackbar "Message forwarded". The receiving bubble shows NO "forwarded" label (the flag is stored but never rendered). Forwarding to the "Admin Support" row is broken (see B-1).
- **Source:** `CSC:2275-2287`, `:3652-3904`; `CS:1677-1706`.
- **Data:** as C-424 with `metadata.forwarded`, `metadata.original_sender`.
- **Next.js:** see C-477.
- **Platform:** both.

**C-430 — Edit own text message**
- **Parent sees/does:** "Edit" (own, non-deleted, text only; no time limit) opens a dialog "Edit Message" with the text prefilled (hint "Edit your message..."), Cancel / "Save". Empty or unchanged text closes without writing. Success → green "Message edited"; failure → red "Failed to edit message". The bubble then shows "edited".
- **Source:** `MB:1448-1451`; `CSC:2289-2355`; `CS:822-872`.
- **Data:** `messages/{id}.update({content, is_edited:true, edited_at})`; then, if the chat's `last_message.sender_id` is the parent, `chats/{id}.update({'last_message.content': newContent})` — even when the edited message is not the last one (see B-5).
- **Rules:** `FR:684`, `FR:666-668`.
- **Next.js:** see C-477.
- **Platform:** both.

**C-431 — Delete for me / Delete for everyone**
- **Parent sees/does:** "Delete" opens a bottom sheet. "Delete for me — Remove this message from your view only." is offered for any message (own or received); after it a snackbar (l10n `chatDeletedForYou`) offers "Undo", which restores it. "Delete for everyone — Replace this message with a deleted placeholder." is offered only for the parent's own, non-system, not-yet-deleted messages sent within the last 2 days (a group admin can also remove others' messages in a group: "Remove this message for everyone in the group."). Success → green "Message deleted"; failure → red "Could not delete for everyone. The time limit may have expired." Deleting for everyone blanks content/metadata/reactions and recomputes the chat's last message.
- **Source:** `CSC:2100-2273`; `CS:17` (2-day window), `:1548-1606`, `:1609-1674`, `:1463-1483`.
- **Data:** for-me: `messages/{id}.update({'deleted_for_users.<uid>': true})` (undo: `FieldValue.delete()`), then `chats/{id}.update({'visibility_updated_at.<uid>': serverTimestamp})`. For-everyone: `messages/{id}.update({content:'', message_type:'deleted', metadata:{}, reactions:{}, is_edited:false, edited_at: delete, deleted_for_everyone:true, deleted_by, deleted_by_name, deleted_by_admin, deleted_at})`, then `last_message` = newest message doc (or removed) + `updated_at`. Uploaded files are NOT removed from Storage.
- **Rules:** `FR:684`, `FR:666-668`.
- **Next.js:** see C-477.
- **Platform:** both.

**C-432 — Attachment menu ("+")**
- **Parent sees/does:** A "+" button left of the field opens a menu: "Photo" (l10n `chatPhoto`), "Camera" (`chatCamera`), "Video", "Document" (`chatDocument`), "Location" (`chatLocation`). While an upload is running further picks are ignored. Any thrown error → red snackbar "Failed to send attachment". No client-side size check anywhere; the only limits are the Storage rules (C-468), and an over-limit upload just surfaces as "Failed to send image/video/file".
- **Source:** `CSC:1053-1140`, `:1306-1331`.
- **Next.js:** see C-478.
- **Platform:** both.

**C-433 — Photo / Camera**
- **Parent sees/does:** Gallery or camera picker (image resized to max 1920×1920, quality 85) → full-screen preview with an "Add a caption..." field and a send button (back = cancel) → snackbar "Sending image..." → "Image sent!" or "Failed to send image". The message shows the image (max height 250) with the caption under it; preview text in lists is the caption or "📷 Photo". On web "Camera" uses the browser's file/capture input (UNVERIFIED in a browser).
- **Source:** `CSC:1333-1373`; `lib/features/chat/screens/media_preview_screen.dart:16-282` (caption :227-262); `CS:648-692`; `MB:392-448`.
- **Data:** Storage `chat_images/{uid}/{epochMs}_{originalName}` with `contentType: image/{ext}`; message `message_type:'image'`, `content: caption | '📷 Photo'`, `metadata:{file_url, file_name, file_size, mime_type, caption?}`.
- **Rules:** `SR:63-69` (owner write, < 10 MB; any signed-in read).
- **Next.js:** see C-478.
- **Platform:** both.

**C-434 — Video**
- **Parent sees/does:** Gallery picker only (max duration 5 min, enforced by the picker where supported) → same preview/caption screen with a playable preview → "Sending video..." → "Video sent!" / "Failed to send video". The whole file is read into memory before upload. The bubble shows a muted inline preview with an "Open video" overlay; tapping opens a full-screen player (caption shown).
- **Source:** `CSC:1375-1413`; `CS:774-819`; `MB:450-516`, `:897-907`, `:1612-1815`, `:1817-2037`.
- **Data:** Storage `chat_videos/{uid}/video_{epochMs}_{originalName}`, `contentType: video/{ext}`; message `message_type:'video'`, `content: caption | '🎥 Video'`, `metadata:{file_url, file_name, file_size, mime_type, caption?}`.
- **Rules:** `SR:81-87` (< 100 MB).
- **Next.js:** see C-478.
- **Platform:** both.

**C-435 — Voice notes: record on phones; NOT sendable on web**
- **Parent sees/does:** With an empty field the right button is a microphone. Tap → snackbar "Hold to record a voice message". Press-and-hold starts recording (microphone permission required, else "Microphone permission is required"); the composer becomes: trash (cancel), pulsing red dot + l10n `chatRecording` + mm:ss, send. Releasing the hold (or pressing send) stops and sends; under 1 s → "Recording too short"; auto-stops and sends at 120 s. **On web the recording runs but the send step always stops with the red snackbar "Voice upload from web is not supported yet" — a parent on the web app cannot send voice notes.** On phones: iOS records WAV (16 kHz mono) first choice, Android AAC/m4a.
- **Source:** `CSC:1191-1225`, `:1704-1801`, `:1813-1955`, `:1957-1990` (web refusal :1963-1966); `CS:731-771`, `:910-936`.
- **Data:** Storage `chat_voice/{uid}/voice_{epochMs}.{wav|m4a}` with audio contentType; message `message_type:'voice'`, `content:'🎤 Voice message'`, `metadata:{file_url, file_name, file_size, duration (s), mime_type}`.
- **Rules:** `SR:90-96` (< 5 MB).
- **Next.js:** see C-478.
- **Platform:** recording/sending mobile only; playback both (C-436).

**C-436 — Playing received voice notes**
- **Parent sees/does:** Voice bubbles show a play/pause button, a static pseudo-waveform and the duration/position; no scrubbing, no speed control. Web playback failure shows "Unsupported audio format for this browser." (format errors) or "Unable to play voice message."
- **Source:** `MB:258-283`; `lib/features/chat/widgets/voice_message_player.dart:41-135`, `:187-339`.
- **Next.js:** see C-478.
- **Platform:** both.

**C-437 — Documents**
- **Parent sees/does:** "Document" opens the file picker limited to pdf, doc, docx, xls, xlsx, ppt, pptx, txt, zip, rar. No preview/caption step: "Sending file..." → "File sent!" / "Failed to send file". The bubble is a file card (icon by extension, name, formatted size); tapping opens the download URL externally (new browser tab on web).
- **Source:** `CSC:1415-1460`; `CS:695-728`; `MB:811-895`.
- **Data:** Storage `chat_files/{uid}/{epochMs}_{originalName}` (no contentType set); message `message_type:'file'`, `content:'📎 <name>'`, `metadata:{file_url, file_name (original), file_size}`.
- **Rules:** `SR:72-78` (< 25 MB).
- **Next.js:** see C-478.
- **Platform:** both.

**C-438 — Location**
- **Parent sees/does:** "Location" asks for location permission ("Location permission is required" / "Location permission permanently denied. Please enable in settings." / "Please enable location services"), shows "Getting your location...", reverse-geocodes, then a sheet "Share location" → "Send current location" with place name and area (falls back to "Current location" + coordinates to 5 decimals) and Cancel. Sent → "Location sent!"; any failure → "Failed to get location". The bubble is a "Pinned location" card; tapping it: on web opens `https://www.google.com/maps/search/?api=1&query=lat,lng`; on phones offers the installed map apps ("Choose map app").
- **Source:** `CSC:1462-1702`; `CS:1829-1853`; `MB:518-809`, `:909-1072`.
- **Data:** message `message_type:'location'`, `content: name`, `metadata:{latitude, longitude, location_name, location_subtitle}`. No Storage.
- **Next.js:** see C-478.
- **Platform:** both (map chooser mobile only).

**C-439 — Viewing images**
- **Parent sees/does:** Tapping an image opens it in a dialog with pinch/scroll zoom and a close button. No download/save/share button.
- **Source:** `CSC:1992-2021`; `MB:396-400`.
- **Next.js:** see C-478.
- **Platform:** both.

**C-440 — Conversation ⋮ menu (1:1 and Admin Support): Clear chat, Block user**
- **Parent sees/does:** Two entries: "Clear chat" (l10n `chatClearChat`) and "Block user" (`chatBlockUser`). (A third, "Insert audit template", exists only when the screen is opened with a template — never for parents.)
  - Clear chat: confirm dialog (`chatClearChatConfirm`, Cancel / `commonClear`) then tries to hard-delete EVERY message of the conversation for both sides. Result: green "Chat cleared" or red "Failed to clear chat" — see B-4 (under the repo rules it fails whenever the conversation contains a message from the other person).
  - Block user: dialog "Are you sure you want to block <name>? They will no longer be able to send you messages." (Cancel / l10n `block`), or the "Unblock User" variant when already blocked; snackbars "<name> blocked" / "<name> unblocked" / "Failed to block user". Blocking only records the uid; nothing in the Flutter app or the backend stops the blocked person's messages or notifications (B-6). In the Admin Support thread the "user" blocked is the literal id `admin_support`.
- **Source:** `CSC:630-677`, `:2380-2421`, `:2423-2483`, `:2485-2621`; `CS:1781-1826`, `:1858-1919`.
- **Data:** clear: `messages.get()` → batch delete → `chats/{id}.update({last_message: delete, updated_at})`. Block: `users/{uid}.update({blocked_users: arrayUnion([otherId])})` / `arrayRemove`.
- **Rules:** message delete `FR:687-688` (sender only); `users` self-update `FR:285-309`.
- **Next.js:** see C-479.
- **Platform:** both.

**C-441 — Features that do NOT exist in the Flutter chat (verified absent)**
- **Parent sees/does:** No typing indicator; no in-conversation or message-content search; no audio/video call buttons; no report/flag action; no pin, star, mute or archive of conversations; no "forwarded" label; no delivery state beyond the two ticks; no per-member read list in groups; no drafts; no link previews; no paste/drag-and-drop of files.
- **Source:** no matches for `typing` in `lib/features/chat/**`; app bar actions contain only the ⋮ menu (`CSC:630-679`); menu actions enumerated at `MB:1444-1558`.
- **Next.js:** n/a.
- **Platform:** both.

**C-442 — Own presence heartbeat (what other people see about the parent)**
- **Parent sees/does:** Nothing visible to the parent. While the dashboard is open and the app is in the foreground, the app writes `is_online: true` + `last_seen` every minute (throttled to ≥ 20 s); on pause/hide/close it writes `is_online: false`. Others see a user as online only if `is_online` is true AND `last_seen` is within 2 minutes (falls back to `last_login`).
- **Source:** `lib/features/dashboard/screens/role_based_dashboard.dart:54-55`, `:80-128`; `lib/core/utils/presence_utils.dart:13-47`.
- **Data:** `users/{uid}.update({is_online, last_seen: serverTimestamp})`.
- **Rules:** `FR:160-164`, `FR:317`.
- **Next.js:** see C-480.
- **Platform:** both.

### 4.7 Groups (parent as a member)

**C-450 — Group membership and group conversation**
- **Parent sees/does:** Parents cannot create groups (button hidden, and `createGroupChat` throws unless the active role is `admin`). An admin can put any user — parents included — into a group (the create and add-member pickers stream the whole `users` collection). In a group conversation the composer is always enabled; typing `@` opens a suggestion strip with "@All" and the other members (filtered as the parent types); choosing one inserts `@Name `. Everything in 4.5/4.6 applies. The group ⋮ menu shows, for EVERY member: "Clear chat", "Group Info" (l10n `groupInfo`), "Edit Group", "Add members" (`chatAddMembers`), "Manage Members", "Leave Group". For a non-admin member "Edit Group" and "Add members" only produce the red snackbars "Only group administrators can edit group info" / "Only group administrators can add members".
- **Source:** `CP:120`; `CS:939-1003`, `:78-104`; `lib/features/chat/screens/group_creation_screen.dart:431`; `CSC:286-352`, `:394-513` (mentions), `:2516-2603` (menu), `:2623-2651`, `:2699-2723`.
- **Data:** group members via `users.where(documentId, whereIn: 10 ids)` batches (`CS:1295-1350`); `isGroupAdmin` = uid in `admin_ids` or own `user_type == 'admin'` (`CS:1107-1138`).
- **Rules:** `FR:657-668`.
- **Next.js:** see C-481.
- **Platform:** both.

**C-451 — Group info (two different dialogs)**
- **Parent sees/does:** (a) Long-press on a group row in Recent → `GroupInfoDialog`: group name, description, "Created by <name>" (l10n `createdBy`), "Members (N)" and the member names (creator tagged with l10n `admin`; unknown → `commonUnknownUser`). (b) ⋮ → "Group Info" inside the conversation → a plain dialog titled l10n `chatGroupInfo` with three lines "Name: …", "Description: … | No description", "Members: N" and Close.
- **Source:** `CP:1007-1012`; `lib/features/chat/widgets/group_info_dialog.dart:28-60`, `:95-275`; `CSC:2653-2697`.
- **Data:** (a) `users.where(documentId, whereIn: <all participant ids>)` in one query (`CS:1507-1543`) — more than 30 members makes it fail and every member shows as unknown; (b) `chats/{id}.get()`.
- **Next.js:** see C-481.
- **Platform:** both.

**C-452 — "Manage Members" (read-only list for a parent)**
- **Parent sees/does:** Dialog "Group Members": each member with avatar, name, tags "You" / "Creator" / "Admin", and role; "No members found" when empty. The remove button ("Remove from group") appears only for group admins, never on admins or oneself.
- **Source:** `CSC:2725-2742`, `:3357-3650`.
- **Data:** `getGroupMembers` (C-450).
- **Next.js:** see C-481.
- **Platform:** both.

**C-453 — Leave group**
- **Parent sees/does:** ⋮ → "Leave Group" → confirm 'Are you sure you want to leave "<group>"? You will no longer receive messages from this group.' (Cancel / "Leave"). On success: green "You have left the group" and the conversation closes; otherwise red "Failed to leave group". If the leaver was the only group admin, the first other participant is promoted to admin first; an emptied group is deleted. See B-7: under the repo rules the "X left" system message cannot be written, so the parent IS removed from the group but sees "Failed to leave group" and stays on the screen.
- **Source:** `CSC:2744-2788`; `CS:1231-1292`, `:1019-1035`.
- **Data:** `chats/{id}.update({participants: arrayRemove([uid]), admin_ids: arrayRemove([uid]), updated_at})`, then `messages.add({sender_id:'system', sender_name:'', content:'<name> left', timestamp, is_read:false, message_type:'system'})` + `chats/{id}.update({updated_at, last_message})`.
- **Rules:** `FR:666-668`, `FR:680-681`.
- **Next.js:** see C-481.
- **Platform:** both.

### 4.8 Leader job titles

**C-460 — Leader job title shown instead of the generic role**
- **Parent sees/does:** For a contact whose `user_type` is `admin`, `super_admin`, `ceo` or `founder` and whose user doc has a non-empty `title` other than "Admin"/"Administrator" (any case), the title (e.g. a job title set on the admin Edit User screen) replaces the generic "Administrator" label: in the coloured chip of every list row (Recent and Contacts) and in the conversation header's status line when the person is neither online nor has a last-seen time. Admin-teachers (`user_type: teacher`, `is_admin_teacher: true`) keep "Teacher". It is not shown next to sender names inside bubbles, nor in the forward picker or group member lists.
- **Source:** `lib/features/chat/models/chat_user.dart:9-11`, `:75-95`; `chat_user_list_item.dart:301`; `CSC:746-750`; populated from `users.title` at `CS:99`, `:314`, `:469`, `CPS:681`.
- **Data:** `users/{uid}.title`, `users/{uid}.user_type`.
- **Next.js:** `apps/web/src/lib/leaderTitle.ts` — see C-482.
- **Platform:** both.

### 4.9 Push notifications

**C-461 — Who is notified when a message is created (`onChatMessageCreated`)**
- **Parent sees/does:** (a) Someone writes to the parent in a 1:1 or a group → the parent's registered devices get a push. (b) An admin replies in the parent's Admin Support thread → the parent gets a push titled "Admin Support". (c) The parent writes in their Admin Support thread → every user with `user_type` `admin` or `super_admin` whose `is_active` is not `false` gets a push (ceo / founder / admin-teachers are not included); nobody else. (d) The parent writes in a 1:1/group → every other participant. Recipients with `notificationPreferences.chatEnabled === false` are skipped. Invalid tokens are pruned from the recipient's user doc.
- **Source:** `functions/handlers/chat.js:17-22` (`supportRouting`), `:28-262`; exported `functions/index.js:315`.
- **Data:** trigger `onDocumentCreated('chats/{chatId}/messages/{messageId}')`; reads `users/{sender}`, `chats/{chatId}`, recipients' `users` docs (`fcmTokens[] {token, platform}` or legacy `fcmToken`).
- **Rules:** server-side (Admin SDK).
- **Next.js:** unchanged — any client that writes the same message doc triggers it (`StudentChatPage.tsx:1252`).
- **Platform:** both (server).

**C-462 — Push payload**
- **Parent sees/does:** Title: sender's name (1:1); "<group name>: <sender>" (group); "Admin Support" (admin → member); "Admin Support · <sender>" (member → admins). Body: message content, truncated to 100 chars + "..." (Android and iOS show the full content). For attachments the body is the placeholder text ("📷 Photo", "🎤 Voice message", "📎 name", caption…).
- **Source:** `functions/handlers/chat.js:157-211`.
- **Data:** `data = {type:'chat_message', chatId, senderId, senderName, senderProfilePicture, messagePreview, fullMessage, chatType ('individual'|'group'|'admin_support'), groupName, click_action:'FLUTTER_NOTIFICATION_CLICK'}`; Android channel `chat_messages`, high priority; APNs `badge: 1` (always 1, not a real count), sound default, category `chat_message`.
- **Next.js:** n/a.
- **Platform:** both (server).

**C-463 — Tapping a chat push on a phone**
- **Parent sees/does:** Tap (app in background) or tap on the in-app local notification (app in foreground) opens the conversation directly: `chatType == 'admin_support'` and the parent is the thread's member → the Admin Support thread; group → the group (name from `groupName`, fallback "Group Chat"); otherwise a 1:1 with the sender (name and picture from the payload; no role, presence or title, so the header shows "Offline"). In the foreground a local notification is shown unless the open conversation matches (see B-2: the match only works for groups and the support thread, never for 1:1). Cold start (app was terminated): the payload is parked in `_pendingNavigation`; the only consumer found is the admin web dashboard (`dashboard.dart:165`) — UNVERIFIED on a device whether a parent lands in the chat.
- **Source:** `lib/core/services/notification_service.dart:259-270`, `:273-390`, `:392-412`, `:431-531`; `CSC:164`.
- **Data:** payload of C-462.
- **Next.js:** n/a (native stays on Flutter).
- **Platform:** mobile only.

**C-464 — No push and no in-app alert on Flutter web**
- **Parent sees/does:** On the web app there is no browser notification, sound, title-bar count or toast for a new message. Push is initialised only on native Android/iOS; there is no messaging service worker in `web/`. Together with C-401, a parent on web learns of a new message only by opening the Chat screen (or from their phone).
- **Source:** `lib/core/services/notification_service.dart:36-37` (`_supportsFirebaseMessagingPush = !kIsWeb && (Android || iOS)`), `:70-86`; `web/` contains no `firebase-messaging-sw.js`.
- **Next.js:** same — no `firebase/messaging` import anywhere in `apps/web/src`.
- **Platform:** web only.

**C-465 — Chat notification on/off preference**
- **Parent sees/does:** A "chat messages" switch (l10n `chatMessagesLabel`) on the Notification Preferences screen, reachable from the mobile Settings screen. Saving calls a callable that stores the preference; when off, the parent gets no chat pushes (C-461). (Whether the web parent Settings screen exposes it belongs to the Settings part; the only navigation found is from `mobile_settings_screen.dart`.)
- **Source:** `lib/features/settings/screens/notification_preferences_screen.dart:25`, `:47-58`, `:81-82`, `:413-476`; `lib/features/settings/screens/mobile_settings_screen.dart:1109-1119`; `lib/core/services/notification_preferences_service.dart:345-382`; `functions/handlers/chat.js:267-302`.
- **Data:** callable `updateChatNotificationPreference({chatEnabled: boolean})` → `users/{uid}.notificationPreferences = {chatEnabled, chatUpdatedAt}` (merge); cached in SharedPreferences.
- **Next.js:** teachers have a direct write of `notificationPreferences.chatEnabled` in `apps/web/src/components/TeacherSettingsPage.tsx:150`; nothing for students/parents.
- **Platform:** mobile (web UNVERIFIED — see Settings part).

### 4.10 Data model, Storage and rules (reference)

**C-466 — `chats/{chatId}` document**
- **Parent sees/does:** n/a (reference).
- **Data:** id = `[uidA, uidB].sort().join('_')` (1:1), `[uid,'admin_support'].sort().join('_')` (support), auto-id (group). Fields: `participants: string[]`; `chat_type: 'individual' | 'admin_support' | 'group'`; `created_at`, `updated_at`; `last_message: {…full message map…}` (absent until the first message; removed by clear/delete); `last_read_by: {uid: timestamp}`; `visibility_updated_at: {uid: timestamp}`; group only: `group_name`, `group_description`, `admin_ids[]`, `created_by`.
- **Source:** `CS:516-567`, `:607-642`, `:980-989`, `:1386-1388`, `:1455-1457`, `:1473-1481`.
- **Rules:** `FR:646-671` — read: any signed-in user (`:657`); create: uid in `participants` (or admin for a support chat) (`:661-663`); update: uid in existing `participants` (or admin on a support chat) (`:666-668`); delete: admin (`:671`).
- **Next.js:** same shape written by `StudentChatPage.tsx:1186-1253`.
- **Platform:** both.

**C-467 — `chats/{chatId}/messages/{id}` document**
- **Data:** `sender_id`, `sender_name`, `sender_profile_picture`, `content`, `timestamp` (server), `is_read: bool` (one shared flag), `message_type: 'text' | 'image' | 'video' | 'voice' | 'file' | 'location' | 'system' | 'deleted'`, `metadata: {file_url, file_name, file_size, mime_type, caption, duration, latitude, longitude, location_name, location_subtitle, reply_to:{message_id, content, sender_name}, forwarded, original_sender}`; later writes: `reactions: {uid: emoji}`, `is_edited`, `edited_at`, `deleted_for_users: {uid: true}`, `deleted_for_everyone`, `deleted_by`, `deleted_by_name`, `deleted_by_admin`, `deleted_at`.
- **Source:** `lib/features/chat/models/chat_message.dart:49-108`; writers listed in 4.6.
- **Rules:** `FR:674-689` — read: any signed-in user (`:676`); create: `sender_id == auth.uid` (`:680-681`); update: any signed-in user (`:684`); delete: sender only (`:687-688`).
- **Queries used by a parent:** `orderBy('timestamp', desc).limit(50)` (live); `where('is_read','==',false)` (get); `orderBy('timestamp', desc).limit(20)` and `.limit(1)` (get); `where('sender_id','==',other).limit(1)` (permission fallback, `CPS:443-449`). No composite index for `chats`/`messages` exists in `firestore.indexes.json` (none is needed by these).
- **Platform:** both.

**C-468 — Storage paths and limits**
- **Data:** `chat_images/{uid}/{epochMs}_{name}` < 10 MB (`SR:63-69`); `chat_files/{uid}/{epochMs}_{name}` < 25 MB (`SR:72-78`); `chat_videos/{uid}/video_{epochMs}_{name}` < 100 MB (`SR:81-87`); `chat_voice/{uid}/voice_{epochMs}.{ext}` < 5 MB (`SR:90-96`). Write: owner folder only; read: any signed-in user. Messages store the long-lived download URL. Files are never deleted by the app.
- **Source:** `CS:657-661`, `:703-707`, `:741-745`, `:784-788`.
- **Next.js:** same four folders, name `{epochMs}_{sanitised name}` (`StudentChatPage.tsx:364-369`).
- **Platform:** both.

**C-469 — Other collections touched**
- **Data:** `users/{uid}`: `blocked_users[]` (C-440), `is_online`, `last_seen` (C-442), `fcmTokens[]`/`fcmToken`, `notificationPreferences.chatEnabled` (C-465), `children_ids[]` (parent) / `guardian_ids[]` (student), `title`, `user_type`, `is_admin_teacher`. `teaching_shifts` (`student_ids[]`, `teacher_id`, `shift_end`, `status`). `chat_permissions/{sortedIds}_teacher_parent` and `…_teacher_student` are written by the `onShiftStatusChangeChat` / `onShiftCreatedChat` triggers but read by no client and have no rules match (default deny) — dead data. There is no presence, typing or blocked collection.
- **Source:** `functions/handlers/chat.js:308-460`; `functions/index.js:318-319`; no `chat_permissions` match in `firestore.rules`; no reference in `lib/` or `apps/web/src`.
- **Platform:** both.

### 4.11 Next.js side today (student web chat) and the gap to a parent version

`SCP` = `apps/web/src/components/StudentChatPage.tsx` (route `apps/web/src/app/student/chat/page.tsx:1-5`). `TeacherChatPage.tsx` is the older sibling (same list/contacts model, a plain bubble with no message actions; its contacts are the teacher's students and those students' `guardian_ids` parents — so teachers on the Next console already write to parents through the same `chats` docs). `ChatAdmin.tsx` is the staff inbox.

**C-470 — Next.js list (Recent) vs Flutter C-404..C-411**
- **Next.js:** `SCP:1080-1105` live `chats` listener with `limit(80)` (Flutter: no limit); row requires a non-empty `last_message.content` string (`SCP:1261-1263`) — a chat whose last message was deleted for everyone (content `''`) disappears, where Flutter shows "This message was deleted". Preview is the raw content: no "You deleted…" variants, no fallback when the last message is hidden-for-me. Names: `group_name`, else the other user's name fetched per user (`SCP:389-419`); a missing user doc shows "Unknown User" (Flutter drops the row). Row (`SCP:641-652`) = initials avatar, name, preview, unread pill — NO profile picture, online dot, role chip / leader title, or time chip. Search (`SCP:213-219`) matches name, e-mail and last-message text (Flutter: name, e-mail, uid, phone; not message text). States: "Loading messages...", "No conversations yet" / "No chats found" with the same sub-copy; no error state (failures render as empty). Tabs "Recent Chats" / "My Contacts", placeholder "Search conversations and users..." (`SCP:427-451`). No long-press group info.
- **Platform:** web.

**C-471 — Next.js unread and read handling vs Flutter C-408 / C-422**
- **Next.js:** unread = unread docs (`limit(100)`) whose sender is not me (`SCP:1107-1113`) — equivalent to `isIncomingFor` for a member, but capped at 100 and it does not exclude messages hidden with delete-for-me. `markChatRead` runs only when a conversation is opened (`SCP:250-252`, `:270`, `:296`; `:1115-1127`), not when new messages arrive while it is open (Flutter re-marks on every snapshot) — so incoming messages in an open panel stay unread for the sender and re-inflate the pill. Bubbles render no ✓/✓✓ at all (`SCP:959-962`). Staff side: `ChatAdmin.tsx` reads a non-existent `unread_count` field and never writes `is_read` (`ChatAdmin.tsx:264`, `:420`), so a parent's ticks turn green only when an admin opens the thread in Flutter.
- **Platform:** web.

**C-472 — Next.js contacts vs Flutter C-412..C-415**
- **Next.js:** Support card with the same title/subtitle and the same `"admin support".includes(term)` rule (`SCP:588-606`, `:625-639`, `:283-297`). Administrators = `user_type == 'admin'` and `== 'super_admin'` only, `limit(50)` each (`SCP:1138-1147`) — no ceo / founder / admin-teachers. Relationship contacts are the STUDENT's own teachers: `teaching_shifts where student_ids array-contains <own uid>` `limit(120)` (plus a camelCase twin), not cancelled, `shift_end` ≥ now−30d or missing (`SCP:1159-1185`; Flutter requires a non-null `shift_end`). Contact row = initials, name, title-or-role pill (`SCP:654-665`); no online dot, no picture. Deep link `?contact=<uid>` opens that contact (`SCP:273-281`; Flutter has none). Loaded once per sign-in; no refresh control.
- **Parent difference:** resolve teachers through the parent's children (`children_ids`, else `guardian_ids` fallback — C-414), not through `student_ids contains <own uid>`; include the wider leader set (C-413).
- **Platform:** web.

**C-473 — Next.js has no `canMessage` gate (Flutter C-416)**
- **Next.js:** none. Any row opens with the composer enabled; there is no "Checking chat permissions…" state, no locked bar, no inbound-message unlock.
- **Platform:** web.

**C-474 — Next.js conversation shell vs Flutter C-417..C-419**
- **Next.js:** a right-hand panel (460px on desktop, list still visible; full screen on phones) closed with the back arrow / browser Back (`SCP:299-302`, `:161-171`, `:751-756`). Header (`SCP:757-776`): initials avatar, name, sub-line "School administrators" (support) / leader title / e-mail / "Group chat" / "Conversation"; a "Block"/"Unblock" button for 1:1. No ⋮ menu, no online / last-seen, no relationship banner, no group description. In the support thread admin replies render on the LEFT in white with the admin's name (`SCP:922-925`) — Flutter shows them on the right in teal (C-417).
- **Platform:** web.

**C-475 — Next.js message list and bubbles vs Flutter C-420..C-423**
- **Next.js:** same query (newest 50, live; `SCP:177-198`); drops empty text messages (`:187`) and hidden-for-me (`:800`). No avatars. Time is hour:minute only for every message, however old (`SCP:1474-1476`; Flutter adds "Yesterday" / "D/M"). "edited · " marker. Deleted placeholder is always "This message was deleted" (`SCP:911-918`). `system` messages render as ordinary incoming bubbles labelled "Sender" (`SCP:925`); `location` messages show only the place name as text — no map card, no link (`SCP:934-939`). Images are a plain `<img>` (no tap-to-zoom); video and voice use native browser controls (so voice has seeking, unlike Flutter); files are a named link (no size/icon). The `content` line is always printed under media ("📷 Photo", caption…). No mention styling. Loading "Loading conversation...", empty "No messages yet" + "Send a message to begin chatting with {name}.", error "Unable to load this conversation.".
- **Platform:** web.

**C-476 — Next.js send vs Flutter C-424**
- **Next.js:** Enter sends, Shift+Enter = newline (`SCP:852-857`); on failure the draft is restored and "Message could not be sent. Please try again." is shown (`SCP:351-353`); offline guard (`SCP:1224`). Same doc writes (`SCP:1205-1253`) except `sender_profile_picture` = Firebase Auth `photoURL` or null (Flutter: `users.profile_picture`), so messages sent from Next usually carry no avatar in the Flutter apps.
- **Platform:** web.

**C-477 — Next.js message actions vs Flutter C-425..C-431**
- **Next.js:** a "…" button revealed on hover/focus (`SCP:992-1000`) opens: the six quick reactions (no "More" emoji picker), Reply, Edit (own messages of ANY type, edited inline in the composer under "Editing message"; does not patch `chats.last_message.content`; `SCP:1310-1316`), "Delete for everyone" (own; confirm dialog; NO 2-day limit; does not recompute `last_message`; `SCP:1326-1339`), "Delete for me" (confirm dialog; no Undo; `SCP:1319-1323`). Reply quote and reaction chips match Flutter's data. **Missing:** Copy, Forward, the full emoji picker, Undo after delete-for-me, group-admin delete.
- **Platform:** web.

**C-478 — Next.js attachments vs Flutter C-432..C-439**
- **Next.js:** one paperclip that accepts any file; the message type comes from the MIME type (`SCP:359-387`, `:844-845`). No Photo/Camera/Video/Document/Location menu, no caption/preview step (no `metadata.caption`), no extension whitelist, no location sharing. Voice: a mic button toggles recording (click to start, click to stop = send; no cancel, no 120 s auto-stop, no 1 s minimum) and uploads `voice_<ms>.webm` to `chat_voice` (`SCP:722-749`, `:846-848`) — i.e. the Next page CAN send voice notes from a browser, which the Flutter web app cannot (C-435). Whether a WebM voice note plays in the iOS/Android Flutter apps is UNVERIFIED (`voice_message_player.dart:172-173` only maps the MIME type). Errors: "Attachment could not be sent. Please try again." / "Microphone access is required to record a voice message.".
- **Platform:** web.

**C-479 — Next.js clear / block vs Flutter C-440**
- **Next.js:** no "Clear chat". Block is a header button (1:1 only — not in the support thread or groups, `SCP:304-309`); blocking asks for confirmation with the same sentence, unblocking is immediate; while blocked a banner "You blocked {name}. Unblock to resume the conversation." shows and the composer is hidden (`SCP:779-783`, `:817`). Flutter changes nothing after blocking.
- **Platform:** web.

**C-480 — Next.js presence vs Flutter C-442**
- **Next.js:** none. The student pages neither write `is_online` / `last_seen` nor display anyone's presence (no reference in `SCP` or `StudentDashboardHome.tsx`). A parent moved to Next would always appear offline to teachers/admins in Flutter unless a heartbeat is added.
- **Platform:** web.

**C-481 — Next.js groups vs Flutter C-450..C-453**
- **Next.js:** group rows are listed and can be read and written (`chatType: 'group'`, `SCP:337`). Missing: member-count chip, `@` mention suggestions and styling, group info, member list, "Leave Group", and the (admin-only) edit/add/remove dialogs.
- **Platform:** web.

**C-482 — Next.js leader title vs Flutter C-460**
- **Next.js:** `apps/web/src/lib/leaderTitle.ts:8-17` mirrors `ChatUser.leaderTitleFor`. Shown on Contacts rows (`SCP:660`) and in the conversation header when the counterpart is found in the loaded contacts (`SCP:236-249`, `:760`). Not shown on Recent rows (Flutter shows it there) and lost in the header when the counterpart is not among the contacts.
- **Platform:** web.

**C-483 — Next.js shell: access gate, nav badge, push**
- **Next.js:** `StudentChatPage` admits only `session.isStudent` (`SCP:126-133`) inside `StudentShell`; a parent is shown the access-denied prompt. The student nav item "Chat" (`apps/web/src/components/StudentDashboardHome.tsx:108`) has no unread badge. No web push (C-464).
- **Platform:** web.

**C-484 — How a parent version has to differ from `StudentChatPage` (summary of the gaps above)**
- **Must change (different behaviour for parents):** access gate + shell (C-483); contact resolution via children (C-472 / C-414) and the full leader set incl. ceo/founder/admin-teachers (C-413); `canMessage` lock states + inbound unlock (C-416 / C-473); relationship banner (C-419).
- **Must add (Flutter has it, Next student page does not):** profile pictures, online dot, last-seen/status line, role chip + leader title on Recent rows, time chips (C-405, C-418); deleted-message preview variants and hidden-last-message fallback (C-409); uid/phone search (C-411); re-mark-as-read while open and ✓/✓✓ ticks (C-422); day-aware timestamps, system pills, avatars in bubbles (C-421); mention styling and suggestions (C-423, C-450); Copy, Forward, full emoji picker, Undo delete-for-me, 2-day delete window + `last_message` recompute, text-only edit + `last_message.content` patch (C-427..C-431); Photo/Camera/Video/Document/Location menu, caption preview screen, extension whitelist, location card with map link, image zoom (C-432..C-439); Clear chat and Block in a ⋮ menu incl. in the support thread (C-440); presence heartbeat (C-442); group info / members / leave (C-451..C-453).
- **Already better or different in Next (decide, do not silently keep or drop):** voice sending from the browser (C-478), composer hidden when blocked (C-479), send-failure message with draft restore (C-476), `?contact=` deep link (C-472), `limit(80)` chats / `limit(100)` unread caps (C-470, C-471), support-thread bubble side (C-474).

### Broken / dead / hard-coded today (chat)

- **B-1 Forwarding to "Admin Support" goes to the wrong document.** The forward picker passes the row id `admin_support` (`CSC:3740-3742`, `:3864-3868`); `sendMessage` treats any id containing `_` as a ready chat id (`CS:579-580`) and `humanUserIdFromAdminSupportChatDocId('admin_support')` is null (`CS:33`), so it creates/updates `chats/admin_support` as an `individual` chat with `participants:[uid,'admin_support']` (`CS:628-634`). The message never reaches the parent's real thread `chats/{uid}_admin_support…`; a second parent doing the same is rejected by the update rule (`FR:666-668`). Also, inside the support thread the current chat is not excluded from the picker (ids differ).
- **B-2 Foreground push suppression never matches for 1:1 chats.** `ChatScreen` registers `_effectiveChatId`, which for a 1:1 is the OTHER USER'S UID (`CSC:153-154`, `:164`), while the push carries the chat DOC id (`functions/handlers/chat.js:180`; compared at `notification_service.dart:316-318`). A parent looking at a 1:1 still gets a local notification for each incoming message (phones).
- **B-3 Unbatched `whereIn`.** `_getParentChildrenTeachers` fetches all teacher ids in one `whereIn` (`CPS:658-661`; limit 30) — more than 30 distinct teachers throws, the catch returns `{}` (`CPS:256-260`) and the parent's Contacts tab silently shows only the Admin Support card. Same pattern in `getUserNames` used by `GroupInfoDialog` (`CS:1513-1516`).
- **B-4 "Clear chat" is destructive and normally fails.** It hard-deletes every message for both sides (`CS:1781-1826`), but the rules let a user delete only their own messages (`FR:687-688`), and it is one atomic batch — so with any message from the other person it shows "Failed to clear chat"; when every message is the parent's own it wipes the thread for the other side too. (The batch object is also reused after commit past 500 docs, `CS:1798-1813`.)
- **B-5 Editing an old message rewrites the list preview.** `editMessage` sets `chats.last_message.content` whenever the last message's sender is the editor, without checking it is the same message (`CS:855-865`).
- **B-6 Block has no effect.** `blocked_users` is written (`CS:1858-1885`) and read only to label the dialog (`CS:1888-1903`); no client filter, rule or function uses it — blocked users can still message and trigger pushes. In the support thread it "blocks" the literal `admin_support` (`CSC:2425`).
- **B-7 System messages cannot be written under the repo rules.** `_sendSystemMessage` creates a message with `sender_id: 'system'` (`CS:1019-1035`) but `FR:680-681` requires `sender_id == auth.uid`. Consequence for a parent: "Leave Group" removes them from `participants` (`CS:1268-1272`) and then throws → "Failed to leave group" and the screen stays open (`CSC:2769-2778`). (Same failure after group create / add / remove for admins.) Verified against `firestore.rules` in the repo; the deployed rules were not checked.
- **B-8 Voice notes on web are a dead end.** The mic button and the whole recording UI are shown, then sending always ends with "Voice upload from web is not supported yet" (`CSC:1963-1966`).
- **B-9 Support thread: admin replies are styled as "other admin" for the member** — right-aligned teal — because `_supportRealUserId` is the member's own uid (`CSC:139`, `:887-890`).
- **B-10 Wrong-perspective / mislabelled copy.** "Parent of your student" is shown to the parent (`CPS:398-399`); the status line says "Last sent …" for a last-seen time (`CSC:737`, `chat_user_list_item.dart:101`); the empty Recent state says "Start a conversation by browsing all users" although parents cannot browse users (`CP:301-302`); the snackbar shown when sending without permission uses l10n `youDonTHavePermissionTo`, whose English value is literally "You Don THave Permission To" (`lib/l10n/app_en.arb:3508`, used at `CSC:2032`).
- **B-11 Silent failures.** A failed text send is only logged and the text is lost (`CSC:2054-2064`); errors in the chat-list mapper become "No conversations yet" (`CS:125-128`); contact-load errors become an empty Contacts tab (`CPS:256-260`).
- **B-12 Only the newest 50 messages are reachable** (`CS:506-507`); no pagination.
- **B-13 Group read state is one shared flag** (`is_read`), so ticks and unread counts are wrong in groups by design (`CS:1366-1382`, `:1400-1421`).
- **B-14 Chat access control is UI-only.** Any signed-in user can read every chat doc and message (`FR:657`, `:676`), update any message (`FR:684`), create a chat with anyone (`FR:661-663`) and read every uploaded chat file (`SR:64`, `:73`, `:82`, `:91`). `canMessage` exists only in the Flutter client.
- **B-15 Presence shown in a conversation header is frozen** at the moment the list row was built (`CSC:582`, `:713`); a conversation opened from a push has no presence/role at all (`notification_service.dart:505-516`).
- **B-16 Admin Support pushes skip some leaders.** Recipients are `user_type in ['admin','super_admin']` (`functions/handlers/chat.js:82-88`), while the app treats ceo / founder / admin-teachers as administrators too (`CPS:31-39`). The Contacts "Administrators" list has no `is_active` filter (`CPS:462-486`).
- **B-17 Hard-coded English (not localised) in parent-visible chat UI**, e.g. "Admin Support", "Message the school administrators", "Support", group headers "Administrators"/"Teachers", "Please sign in", "No contacts match your search", "Type a message...", "Replying to …", "Video", "Edit", "Edit Message", "Save", "Delete for me", "Delete for everyone", "Undo", "Forward Message", "Select a chat:", "Leave Group", "Group Members", "Checking chat permissions…", every snackbar ("Sending image...", "Image sent!", "Failed to send …", "Hold to record a voice message", …) (`CP:235-236`, `:427-465`, `:491`, `:603-611`; `CSC:945`, `:1102`, `:1165-1166`, `:1264`, `:1357-1368`, `:1810`, `:2155-2189`, `:2295-2345`, `:2751-2781`).
- **B-18 Dead code / data.** `lib/features/chat/widgets/chat_message_bubble.dart` is an empty file; `_isUserOnline` is unused in both services (`CS:1489-1504`, `CPS:687-702`); `getGroupChats` has no caller (`CS:1006-1017`); `chat_permissions` is written by two triggers and read by nothing (C-469); legacy `chat_messages` / `chat_rooms` rules are open to every signed-in user (`FR:626-640`) and no code reads or writes those collections (the only `chat_messages` string in `lib`/`functions` is the Android notification channel id); `metadata.forwarded` / `original_sender` are stored but never displayed; APNs `badge` is always 1 (`functions/handlers/chat.js:201`).
- **B-19 Cost pattern.** Every change to any of the parent's chat docs re-runs one unread query per conversation (`CS:341`, `:374`, `:393`); on web the page is built at dashboard load (C-400), on phones the nav badge adds a second identical listener (C-402).

### Memory-note staleness (chat)

Checked `project_alluwal_admin_support_chat.md` (dated 2026-10-16) against the code at `0a49330`:

| Claim | Status |
|---|---|
| Thread = `chats/{sorted(uid,'admin_support')}`, `participants [member,'admin_support']`, `chat_type 'admin_support'`; no admin is a participant; messages keep the real admin as sender | TRUE — `CS:47-50`, `:539-552`, `:595-605` |
| Admins read them via `getAdminSupportChats` / web `ChatAdmin` | TRUE — `CS:134-155`; `ChatAdmin.tsx:379` |
| Member's thread is a normal Recent row "Admin Support" in Flutter and in Student/Teacher Next pages | TRUE — `CS:366-387`; `StudentChatPage.tsx:1255-1276`; `TeacherChatPage.tsx` carries `isSupport` |
| `isIncomingFor` drives mark-as-read and unread counts | TRUE in Flutter (`CS:60-75`, `:1377`, `:1415`, `:1443`). Not implemented by name on Next: member pages use `sender !== me` (equivalent for a member); `ChatAdmin.tsx` has no `is_read` handling at all (C-471) |
| Push `supportRouting`: member → all active admin/super_admin; admin → member titled "Admin Support" | TRUE — `functions/handlers/chat.js:17-22`, `:79-93`, `:158-162`. Missing from the note: admins' copy is titled "Admin Support · <sender>"; ceo/founder/admin-teachers are not notified (B-16) |
| Flutter push tap opens the support thread | TRUE — `notification_service.dart:464-488` |
| Audit messages go through `getOrCreateAdminSupportChatForUser` | TRUE as far as checked — `teacher_audit_service.dart:3069` (teacher-only; not a parent feature) |
| "admin Flutter web v314" | STALE — web is at v332 (`git log`: `988a732 Bump Flutter web to v332`) |
| "Native apps NOT released — last store release 1.1.8 … tapping on an old app opens a personal chat" | UNVERIFIABLE from code; `pubspec.yaml:6` is now `1.2.2+12200`, so the note is at least out of date about the app version in the repo |

Not in the note but relevant: the member-side styling quirk B-9, the forward bug B-1 and the suppression bug B-2 all involve the support thread.

Leader job title: implemented in `lib/features/chat/models/chat_user.dart:75-95` and mirrored in `apps/web/src/lib/leaderTitle.ts`; the local git history is squashed (`git log -- lib/features/chat` shows only `f05c8fd`), so the introducing commit could not be identified.

### Questions for the owner (chat)

1. **Voice notes on web.** Flutter web refuses to send them (C-435); the Next student page sends WebM. Should parents on the new web be able to send voice notes — and has anyone confirmed a WebM note plays in the phone apps?
2. **Who counts as an administrator contact?** Flutter lists admin, super_admin, ceo, founder and admin-teachers (including deactivated ones) as personal 1:1 contacts (C-413); the Next student page lists only admin + super_admin. Which list is right for parents?
3. **`children_ids` vs `guardian_ids`.** Flutter uses the student's `guardian_ids` only when the parent's `children_ids` is empty (C-414). Which field is the source of truth for "my children"?
4. **Clear chat and Block.** Clear chat mostly fails and is destructive when it works (B-4); Block does nothing (B-6). Reproduce as-is, fix, or leave out of the parent web?
5. **Support thread layout.** Parents currently see admin replies on the right in teal (B-9); the Next student page shows them on the left. Which one should parents get?
6. **Message lock for non-related teachers.** Keep the Flutter rule (composer locked unless the teacher currently teaches a child or has written first, C-416)? The Next student page has no lock.
7. **Unread indicator and alerts on web.** Flutter web has no sidebar badge and no web push (C-401, C-464); phones have both. Should the new parent web add a badge?
8. **50-message cap.** Older history is unreachable today (B-12). Same on the new page, or add "load older"?
9. **Groups.** Are any parents actually in group chats in production? If yes the parent page needs group info / members / leave / mentions (C-450..C-453); "Leave Group" is currently broken under the repo rules (B-7).
10. **Delete-for-everyone window.** Flutter enforces 2 days; the Next student page has no limit. Which rule applies?

---

## 5. Circles (parent)

**C-500 — Web: Circles is hidden from the parent sidebar**
- **Parent sees/does:** No "Circles" item. It would sit under "Finance" after "Payments".
- **Source (proof):** `lib/features/dashboard/config/sidebar_config.dart:6-7` — comment "Circles (savings) is hidden for all roles for now; flip to re-enable." and `static const bool showCircles = false;`; the parent entry is wrapped in `if (showCircles)` at `:559-566` (`screenIndex: 8`). The same constant gates the admin, teacher and student menus (`:272`, `:449`, `:700`). It is a compile-time constant, not a remote flag: showing Circles on Flutter web needs a new build.
- **Data:** none.
- **Next.js:** no parent or student Circles page. A teacher one exists (`apps/web/src/components/TeacherCirclesPage.tsx`, gated on `tontine_enabled`).
- **Platform:** web.

**C-501 — Web: the hidden screen still loads for every parent**
- **Parent sees/does:** Nothing. `TontineHomeScreen` is index 8 of the shell's IndexedStack, so it is built when the parent dashboard opens and opens two Firestore listeners (pending invites and the user's circles) plus a role read, although no menu item can show it.
- **Source:** `lib/features/parent/screens/parent_dashboard_layout.dart:107-108`, `:155-161`; `lib/features/tontine/screens/tontine_home_screen.dart:30-38`, `:63-68` (`TontineService.getPendingInvitesForUser`, `getUserCircles`).
- **Rules:** `firestore.rules:1190-1197` (`circles`: read for any signed-in user).
- **Next.js:** nothing to copy; a Next parent area would simply not make these reads.
- **Platform:** web.

**C-502 — Phones: Circles appears for a parent only when their own account has `tontine_enabled: true`**
- **Parent sees/does:** A seventh bottom tab "Circles" (groups icon) opening `TontineHomeScreen`, only when the flag is on for that user. The flag is watched live, so an admin switching it changes the tabs without a restart. `SidebarConfig.showCircles` is not consulted on phones.
- **Source:** `lib/features/dashboard/screens/mobile_dashboard_screen.dart:80`, `:127`, `:150-170` (live listener on `users/{uid}`), `:597` (screen), `:674-676` (tab). Admins set the flag in user management (`lib/features/user_management/screens/user_management_screen.dart:1402`, `edit_user_screen.dart:152`).
- **Data:** `users/{uid}.tontine_enabled`. Production: 1 of 118 parent accounts has it on (section 8).
- **Next.js:** n/a (phones stay on Flutter).
- **Platform:** mobile.

**C-503 — What this means for the web move**
- **Parent sees/does today on web:** no Circles at all. Matching today's web behaviour means building no Circles page for parents. The one parent with the flag on sees Circles on the phone app only.
- **Source:** C-500, C-502.
- **Platform:** web.

---

## 6. Notifications (parent)

Repo: `/Users/hashimniane/alluwal-work/base` at `0a49330`. Paths are relative to it. `fn/` = `functions/`.
"Native" = the iOS/Android store app. "Web" = the Flutter web build at `/app/`.

**One-paragraph truth:** a parent on the WEB gets no notifications of any kind inside the app: no bell, no list, no badge, no browser push. Everything a parent "receives" is (a) a phone push on the native app, (b) an e-mail, or (c) the unread counter on the native Chat tab. There is no notification inbox anywhere, on any platform, for any role.

### 6.1 Where a parent sees notifications

- **C-600 — Parent web shell has no bell, no notification list, no badges.**
  - **Parent sees/does:** AppBar shows only logo (tap = go to Dashboard, index 0), `RoleSwitcher`, and a profile popup with exactly two entries: Profile (index 4) and Sign out. Compact (<900 px) adds a hamburger. No bell icon, no unread count, no sidebar dots.
  - **Source:** `lib/features/parent/screens/parent_dashboard_layout.dart:177-223` (AppBar), `:254-327` (profile menu), `:375-389` (`CustomSidebar(selectedIndex, onItemSelected, isCollapsed, onToggleCollapse, userRole)` — no `badgeScreenIndices`); the badge feature exists but defaults empty: `lib/features/dashboard/widgets/custom_sidebar.dart:15,26,662,994`.
  - **Data:** none.
  - **Rules:** n/a.
  - **Next.js:** none (no parent area). Student shell has a decorative bell, see C-647.
  - **Platform:** web-only.

- **C-601 — Parent on web receives no push at all (browser push is not built).**
  - **Parent sees/does:** never gets a browser permission prompt; never gets a browser notification; no foreground toast when a message/invoice arrives.
  - **Source:** push is hard-gated to native: `lib/core/services/notification_service.dart:36-37` (`_supportsFirebaseMessagingPush => !kIsWeb && (Android||iOS)`), `lib/main.dart:67-70,237-239,256-268` (service only initialised when `_isNativeMobilePlatform`). No `firebase-messaging-sw.js` in `web/` (dir holds only `index.html, manifest.json, icons, favicon, logos, privacy-policy.html, *_meeting.html`); no VAPID key anywhere in the repo (grep `vapid` = 0 hits outside build output); `web/index.html:103-110` actively unregisters every service worker in its cache-cleanup path.
  - **Data:** `saveTokenToFirestore` returns immediately on web (`notification_service.dart:674`), so a web-only parent has no `fcmTokens` entry.
  - **Rules:** n/a.
  - **Next.js:** none — no `firebase/messaging`, no service worker, no VAPID in `apps/web` (grep = 0 hits in `src/` and `public/`).
  - **Platform:** web-only.

- **C-602 — Native shell for a parent: bottom tabs, no bell, no notification screen.**
  - **Parent sees/does:** `RoleBasedDashboard` returns `MobileDashboardScreen` for every role on native. Parent tabs: Home, Classes, Chat, Forms, Tasks, Library (+ Circles when `users/{uid}.tontine_enabled`). Header has only the logo/title and the avatar (opens profile sheet: Profile, Settings, Help, Sign out). No bell. The only notification screen in the app (`MobileNotificationScreen`) is the ADMIN "send notification" composer, reachable only from the admin "More" grid.
  - **Source:** `lib/features/dashboard/screens/role_based_dashboard.dart:323-328`; `lib/features/dashboard/screens/mobile_dashboard_screen.dart:589-598` (parent screens), `:665-677` (parent nav items), `:960-968` (header actions = avatar only), `:1323-1328` (admin-only Notify tile).
  - **Data:** `users/{uid}` snapshot listener for `ai_tutor_enabled` / `tontine_enabled` (`:156-176`).
  - **Rules:** n/a.
  - **Next.js:** none.
  - **Platform:** mobile-only.

- **C-603 — Native Chat tab shows an unread counter (the only in-app "notification" a parent has).**
  - **Parent sees/does:** green pill on the Chat tab icon with the sum of `unreadCount` over all chats; `99+` above 99; hidden at 0. Updates live.
  - **Source:** `lib/features/dashboard/screens/mobile_dashboard_screen.dart:1235-1278` (stream `ChatService.getUserChats()`), tab flagged `isChat: true` at `:669`.
  - **Data:** whatever `ChatService.getUserChats()` reads (chat part owns the query).
  - **Rules:** chat rules (chat part).
  - **Next.js:** `apps/web/src/components/StudentChatPage.tsx:649` shows per-chat unread pills inside the chat page only; there is no unread total on the student nav. A parent version would lack a nav-level counter unless built.
  - **Platform:** mobile-only (the parent WEB sidebar shows no chat badge, C-600).

- **C-604 — There is no in-app notification inbox / history for parents.**
  - **Parent sees/does:** nothing. A push that is missed or dismissed cannot be found again in the app.
  - **Source:** no Dart code reads a per-user notification collection (grep of `lib/` for `collection('notifications')`, `notification_history`, `user_notifications` = 0 reader hits). Server writes a log to `notification_history` (`fn/handlers/payments.js:495,767`, `fn/handlers/finance_invoices.js:72`, `fn/handlers/notifications.js:293`) but nothing shows it to the recipient; the admin history panel reads a DIFFERENT collection, `admin_notifications` (`lib/features/notifications/screens/send_notification_screen.dart:857,997`).
  - **Data:** `notification_history` docs: `{sentBy, sentAt, recipientType, recipientIds[], title, body, additionalData{type,…}, emailRequested, results{…}}`.
  - **Rules:** `firestore.rules:763-771` defines `/notifications/{id}` (owner read by `userId`, admin write) but nothing writes or reads it. `notification_history` has no rule of its own; it falls to the catch-all `firestore.rules:1346-1351` (admin-only read/write), so a parent cannot read it.
  - **Next.js:** none.
  - **Platform:** both.

### 6.2 Push registration (native only)

- **C-605 — OS permission prompt at app launch.**
  - **Parent sees/does:** on first launch the OS asks to allow notifications (alert, badge, sound; not provisional). Declining is only logged; the app shows no follow-up and no in-app "turn on notifications" prompt.
  - **Source:** `lib/core/services/notification_service.dart:65-94` (initialize), `:97-125` (`requestPermission`); called from `lib/main.dart:256-257` before `runApp`, i.e. before sign-in. Android permission declared `android/app/src/main/AndroidManifest.xml:13`.
  - **Data:** none.
  - **Rules:** n/a.
  - **Next.js:** none.
  - **Platform:** mobile-only.

- **C-606 — Device token saved on app launch when already signed in.**
  - **Parent sees/does:** invisible. 2 s after launch (5 s on iOS) the token is written if a user is signed in. Exactly one token per platform is kept: all existing entries with the same `platform` are replaced.
  - **Source:** `lib/main.dart:89-119,266-267`; `lib/core/services/notification_service.dart:673-807` (iOS waits for the APNs token up to 5×2 s, `:686-708`).
  - **Data:** `users/{uid}.fcmTokens = [{token, platform: 'ios'|'android', lastUpdated: Timestamp}]`, `users/{uid}.lastTokenUpdate = serverTimestamp`. Creates the user doc with `set(merge)` if missing (`:766-774`).
  - **Rules:** `firestore.rules:150-156` (`isFcmTokenOnlyUpdate`: only `fcmTokens`,`lastTokenUpdate` changed) used at `:313` for the owner.
  - **Next.js:** none.
  - **Platform:** mobile-only.

- **C-607 — Token refresh is auto-saved.**
  - **Parent sees/does:** invisible.
  - **Source:** `lib/core/services/notification_service.dart:576-593` (`onTokenRefresh` → `saveTokenToFirestore` when a user is signed in).
  - **Data/Rules:** as C-606.
  - **Next.js:** none. **Platform:** mobile-only.

- **C-608 — One account per device token (server).**
  - **Parent sees/does:** when a second account signs in on the same phone and registers the token, the previous account stops receiving pushes on that phone.
  - **Source:** `fn/handlers/fcm_token_ownership.js:58-96` (trigger on `users/{userId}` writes; exported `fn/index.js:79-80`).
  - **Data:** `fcm_token_owners/{token with '/'→'_'} = {uid, updated_at}`; removes the token from the previous owner's `fcmTokens` in a transaction (`:41-56`).
  - **Rules:** server-only.
  - **Next.js:** none. **Platform:** mobile-only.

- **C-609 — Sign-out does not unregister the phone.**
  - **Parent sees/does:** after signing out on the phone the parent keeps receiving pushes for that account until another account registers the same token (C-608) or the token dies.
  - **Source:** token removal exists only in `AuthService.signOut` (`lib/core/services/auth_service.dart:556-565`), whose only caller is `lib/features/dashboard/widgets/top_nav_bar.dart:23`. The parent's real sign-out buttons call `FirebaseAuth.instance.signOut()` directly: native `lib/features/dashboard/screens/mobile_dashboard_screen.dart:750`, `lib/features/settings/screens/mobile_settings_screen.dart:1555`; web `lib/features/parent/screens/parent_dashboard_layout.dart:369`; suspended screen `lib/features/parent/screens/access_suspended_screen.dart:71`.
  - **Data:** `users/{uid}.fcmTokens` unchanged on sign-out.
  - **Next.js:** n/a (no tokens). **Platform:** mobile-only.

- **C-610 — Dead tokens are pruned by some senders only.**
  - **Source:** chat `fn/handlers/chat.js:220-247`; new-invoice push `fn/handlers/payments.js:590-619`. Not pruned by: invoice reminder (`fn/handlers/finance_billing.js:1157-1169`), invoice updated/cancelled (`fn/handlers/finance_invoices.js:59-71`), parent-linked (`fn/handlers/enrollments.js:1243-1254`), admin broadcast (`fn/handlers/notifications.js:182-211`), circles (`fn/handlers/circles.js:84-109`).
  - **Platform:** mobile-only.

- **C-611 — Android notification channels created by the app.**
  - **Source:** `lib/core/services/notification_service.dart:160-199`: `high_importance_channel` (default; also manifest default `AndroidManifest.xml:78-79`), `chat_messages`, `class_reminders`; `prayer_times` (`lib/core/services/prayer_notification_service.dart:37-38,95-113`); `quran_goal_reminders` (`lib/features/quran_reader/services/goal_reminder_service.dart:17`). No `calls` channel is created although the call push targets it (C-632).
  - **Platform:** mobile-only (Android).

### 6.3 Foreground display and tap handling (native only)

- **C-612 — Push while the app is open is shown as a system banner.**
  - **Parent sees/does:** any push carrying a `notification` block is re-shown as a local notification (title/body as sent). Chat pushes use channel `chat_messages` and expand to the full message (`data.fullMessage`, summary "Chat"); everything else uses `high_importance_channel`. iOS also presents alert/badge/sound natively. No in-app toast/snackbar.
  - **Source:** `lib/core/services/notification_service.dart:273-380`, `:248-256`.
  - **Platform:** mobile-only.

- **C-613 — No banner for the chat the parent is currently reading.**
  - **Source:** `lib/core/services/notification_service.dart:316-321`; set/cleared by `lib/features/chat/screens/chat_screen.dart:164,358`.
  - **Platform:** mobile-only.

- **C-614 — Tapping a chat push opens that conversation.**
  - **Parent sees/does:** (app running or backgrounded) pushes a `ChatScreen` on top of the current screen. Direct chat: opened by `senderId` with `senderName` and avatar. Group chat: opened by `chatId`, title `groupName` or "Group Chat". Admin Support: opens the support thread titled "Admin Support" (subtitle "Message the school administrators"). If `senderId`/`senderName` (direct) or `chatId` (group) is missing the tap does nothing.
  - **Source:** `lib/core/services/notification_service.dart:383-389` (background tap), `:415-429` (tap on the foreground banner), `:432-532` (routing; support `:464-488`; direct/group `:490-527`); navigator key wired at `lib/main.dart:476`.
  - **Data:** payload keys `type, chatId, senderId, senderName, senderProfilePicture, chatType, groupName` (C-618).
  - **Next.js:** none. **Platform:** mobile-only.

- **C-615 — Tapping a push that cold-starts the app lands on Home, not on the target.**
  - **Parent sees/does:** app opens on the Home tab; the conversation is not opened.
  - **Source:** initial message is only stored (`notification_service.dart:392-402`); the only consumer `processPendingNavigation()` is called from `lib/features/dashboard/screens/dashboard.dart:163-166`, the web/desktop `DashboardPage`, which the native shell never builds (native returns `MobileDashboardScreen` first, `role_based_dashboard.dart:323-328`; `MobileDashboardScreen` has no such call); `getPendingNavigation()` (`notification_service.dart:569-573`) has no caller.
  - **Platform:** mobile-only.

- **C-616 — Tapping any non-chat push only opens/foregrounds the app.**
  - **Parent sees/does:** no navigation for `invoice_created`, `invoice_reminder`, `invoice_updated`, `invoice_cancelled`, `parent_linked`, `admin_notification`, `circle_*`, `incoming_call`. The parent must find the invoice/child manually.
  - **Source:** `lib/core/services/notification_service.dart:528-531` → `_handleNotificationNavigation` `:535-563` handles only `form_required`/`pending_forms`/`chat_message`/`no_show_report` (and only stores them); `audit_notification` `:435-452` is teacher-only. `_navigateBasedOnMessage` `:596-635` has no caller.
  - **Platform:** mobile-only.

- **C-617 — Background/terminated handler does nothing but log.**
  - **Source:** `lib/core/services/notification_service.dart:17-22`, registered `lib/main.dart:237-239`. The OS shows the push itself.
  - **Platform:** mobile-only.

### 6.4 Notification types a parent account can receive (Cloud Functions)

All pushes read tokens from `users/{uid}.fcmTokens[].token` (some also the legacy scalar `fcmToken`). A parent with no native app install receives no push; only the e-mail leg (where one exists) reaches them.

- **C-618 — New chat message.**
  - **Parent sees/does:** push titled with the sender's name (direct) or `"{groupName}: {senderName}"` (group); body = message text (preview cut at 100 chars + "…"; Android/iOS show the full text). Not sent to the sender. Not sent when the parent turned chat notifications off (C-640).
  - **Source:** `fn/handlers/chat.js:28-262`, export `fn/index.js:315`.
  - **Data:** trigger `chats/{chatId}/messages/{messageId}` create. Recipients = `chats/{chatId}.participants` minus sender minus `'admin_support'` (`:92`). Skips users with `notificationPreferences.chatEnabled === false` (`:118-124`). Payload `notification{title, body}`; `data{type:'chat_message', chatId, senderId, senderName, senderProfilePicture, messagePreview, fullMessage, chatType, groupName, click_action}`; Android channel `chat_messages`; APNs `badge:1`, category `chat_message` (`:172-211`).
  - **Tap:** C-614 / C-615.
  - **Rules:** server-side.
  - **Next.js:** none (student chat has no push). **Platform:** mobile-only.

- **C-619 — Reply in the Admin Support thread.**
  - **Parent sees/does:** when any admin answers the parent's Admin Support thread: push titled exactly "Admin Support" (never the admin's name). When the parent writes, every active admin is pushed "Admin Support · {parent name}".
  - **Source:** `fn/handlers/chat.js:17-22,79-93,158-162`.
  - **Data:** thread participants `[memberUid, 'admin_support']`; `chatType` in payload comes from `chats/{chatId}.chat_type`.
  - **Tap:** opens the support thread (`notification_service.dart:464-488`) only if `data.chatType == 'admin_support'`.
  - **Platform:** mobile-only.

- **C-620 — New invoice.**
  - **Parent sees/does:** e-mail "New invoice from Alluwal Education Hub: {number}" with the invoice PDF attached and a pay-now link, AND a push "New invoice available" / "{number} is ready. Amount due: {amount}." For engine invoices (`kind` `first_month` or `monthly`) NOTHING is sent unless Finance setting `parent_messages_enabled` is true (invoice is stamped `notification_status:'suppressed'`). Other invoices (manual / one-off) always notify.
  - **Source:** trigger `fn/handlers/payments.js:1213-1244` (`onInvoiceCreated`, export `fn/index.js:167`); `_notifyInvoiceRecipient` `:628-796`; push `:550-626`; e-mail `fn/services/email/senders.js:11-34`.
  - **Data:** recipient = first existing user among `invoice.parent_id|parentId|payer_id|payerId`, then `invoice.student_id|studentId` (`:629-659`). Push `data{type:'invoice_created', invoiceId, invoiceNumber, click_action}`, channel `high_importance_channel`. Writes on the invoice: `notification_status ('sent'|'failed'|'suppressed'), notification_result{success, reason, payer_id, email_sent, push_sent, errors[], push}, notification_sent_at | notification_failed_at` (`:802-823`); adds a `notification_history` doc (`:767-787`); mints `pay_link_token` if missing (`:692-707`).
  - **Tap:** none (C-616). The Flutter `Invoice` model parses `notification_status` (`lib/features/parent/models/invoice.dart:90,179-180`) but no parent screen displays it.
  - **Rules:** server-side.
  - **Next.js:** none. **Platform:** push mobile-only; e-mail both.

- **C-621 — Invoice due reminders (automatic, daily 09:00 New York).**
  - **Parent sees/does:** once N days before the due date ("Invoice {number} is due in {N} days" / "{amount} is due on {date}.") and once on the due date ("Invoice {number} is due today" / "{amount} is due today."), by e-mail (from billing@, with a "Pay {amount}" button when a pay link exists) and push. Only while `parent_messages_enabled` is true; skipped for paid/cancelled/zero-balance invoices. There is NO overdue (after due date) reminder.
  - **Source:** `fn/handlers/finance_billing.js:1178-1235` (run), `:1110-1171` (send), schedule `:1248-1254`, export `fn/index.js:753`.
  - **Data:** query `invoices` where `due_date >= today(NY)` and `< today + reminder_days_before + 1`. Recipient = first existing of `invoice.parent_id`, `invoice.student_id`. Claim flag `invoices/{id}.reminders_sent.{before|due} = {at, days_until_due, email, push}`. Push `data{type:'invoice_reminder', invoiceId, click_action}` with no Android channel / APNs sound block.
  - **Tap:** none (C-616).
  - **Next.js:** none. **Platform:** push mobile-only; e-mail both.

- **C-622 — Manual invoice reminder sent by an admin.**
  - **Parent sees/does:** receives the SAME message as a new invoice again (e-mail "New invoice from…" + push "New invoice available"), not a "reminder" wording.
  - **Source:** `fn/handlers/finance_invoices.js:520-551` → `payments._notifyInvoiceRecipient` (`:102-104`); export `fn/index.js:767-769`. Refused when parent messages are off or nothing is owed.
  - **Data:** appends `invoices/{id}.reminders[] {at, kind:'manual', by, by_name, sent}`.
  - **Platform:** push mobile-only; e-mail both.

- **C-623 — Invoice updated.**
  - **Parent sees/does:** push only: "Invoice updated" / "Your invoice {number} was updated. New total {amount}." Only while `parent_messages_enabled`. No e-mail (code TODO `finance_invoices.js:45`).
  - **Source:** `fn/handlers/finance_invoices.js:384-396`, sender `:47-90`.
  - **Data:** recipient `invoice.parent_id|parentId` ONLY (no student fallback, `:118`). `data{type:'invoice_updated', invoiceId, invoiceNumber, click_action}`; `notification_history` doc.
  - **Tap:** none. **Platform:** mobile-only.

- **C-624 — Invoice cancelled.**
  - **Parent sees/does:** push only: "Invoice cancelled" / "Your invoice {number} was cancelled. Nothing is owed on it." Only while `parent_messages_enabled`.
  - **Source:** `fn/handlers/finance_invoices.js:500-511`.
  - **Data:** as C-623 with `type:'invoice_cancelled'`.
  - **Tap:** none. **Platform:** mobile-only.

- **C-625 — Payment received.**
  - **Parent sees/does:** e-mail only, "Payment received: {number}" with amount, date, method and the invoice PDF (now showing Paid / Remaining balance). NO push. Not gated by `parent_messages_enabled`. Sent for Stripe checkout, Stripe payment-intent, Payoneer and admin-recorded manual payments.
  - **Source:** `fn/handlers/payments.js:390-536`; callers `:1742, 2308, 2424, 2455`; e-mail `fn/services/email/senders.js:94-115`.
  - **Data:** recipient = first existing of payment/invoice `parent_id`, then `student_id` (`:391-411,1466-1472`). On failure stamps `payments/{id}.receipt_email_status:'failed', receipt_email_error, receipt_email_to, receipt_email_failed_at`. Adds `notification_history` with `additionalData.type:'payment_completed'` (`:495-517`).
  - **Platform:** e-mail (both).

- **C-626 — Payment failed / checkout expired: the parent is told nothing by notification.**
  - **Source:** `fn/handlers/payments.js:1487-1499` (status set to `failed`, no send), webhook branches `:2362, 2464`.
  - **Platform:** both.

- **C-627 — Child linked to the parent ("account is ready").**
  - **Parent sees/does:** when an admin links a student to the parent during enrolment: e-mail — new parent account: "Set up your Alluwal Education Hub parent account" with a set-password button; existing parent account: "{student}'s account is ready on Alluwal Education Hub" with a button to `https://alluwaleducationhub.org/app/`. Plus, for a parent who already has the app, push "{student}'s account is ready" / "{student} is|are now on your Alluwal parent dashboard."
  - **Source:** `fn/handlers/enrollments.js:996-1271` (e-mail `:1187-1228`, push `:1232-1258`), export `fn/index.js:333-335`.
  - **Data:** recipient = the parent uid just linked (`users/{studentUid}.guardian_ids` arrayUnion parentUid `:1149-1153`; enrollment `contact.guardianId`, `metadata.parentInviteStatus 'invited'|'linked'`, `metadata.parentUserId`). Push `data{type:'parent_linked', studentUid, enrollmentId}`, no channel/sound block.
  - **Tap:** none (C-616).
  - **Next.js:** none. **Platform:** push mobile-only; e-mail both.

- **C-628 — Announcement sent by an admin.**
  - **Parent sees/does:** push with the admin's free-text title and body; optional e-mail "📢 {title}" (web composer only; the phone composer never e-mails). Targets: one user, selected users, a whole role (`teacher`/`student`/`parent`/`admin`), or — phone composer — "everyone" (the phone itself lists all `users` where `is_active == true` and sends them as `selected` ids, `mobile_notification_screen.dart:111-118`).
  - **Source:** server `fn/handlers/notifications.js:15-340` (export `fn/index.js:96-98`); composers `lib/features/notifications/screens/send_notification_screen.dart:205-213,453-465`, `lib/features/notifications/screens/mobile_notification_screen.dart:109-133,597-600`, Next.js `apps/web/src/components/NotificationsAdmin.tsx:126-134`.
  - **Data:** role target = `users` where `user_type == recipientRole` AND `is_active == true` (`:87-92`) — a parent whose doc lacks `is_active:true`, or who is a parent only through `secondary_roles`, is NOT reached. Payload `notification{title, body}`, `data{type:'admin_notification', timestamp, …notificationData}`, channel `high_importance_channel`. Log: `notification_history` (`:293-310`).
  - **Tap:** none (C-616).
  - **Rules:** none; see Broken B-3 for the missing caller check.
  - **Next.js:** admin composer exists; no parent-side surface.
  - **Platform:** push mobile-only; e-mail both.

- **C-629 — Class reminders / class changes: a parent does NOT receive them.**
  - **Parent sees/does:** nothing. "📚 Class Starting Soon!" (`type:'class_reminder'`), "📝 Class Updated" (`type:'class'`), "👨‍🏫 New Teacher Assigned" (`type:'shift', action:'teacher_changed'`) go to the STUDENT accounts in `teaching_shifts.student_ids` only; guardians are never looked up. The e-mail to parents on class assignment is switched off in code.
  - **Source:** `fn/handlers/shifts.js:3056-3092`, `:955-1009`, `:1564-1583`; `fn/services/notifications/fcm.js:154-220,229-285`; `fn/services/email/shift_notifications.js:29-31,314-315` (`SEND_PARENT_SHIFT_EMAILS = false`). `grep -i guardian fn/handlers/shifts.js` = no notification code.
  - **Platform:** both.

- **C-630 — Access suspended / restored for unpaid invoices: no notification.**
  - **Parent sees/does:** no push, no e-mail when access is cut or restored; the parent only discovers it on the suspended screen (billing part).
  - **Source:** `fn/handlers/invoice_access.js` — whole file (497 lines) contains no `messaging()`, `sendMail`, `sendEmail`, `transporter` or `fcm` reference (grep count 0); triggers `onInvoiceWrite`, `checkAccessCutoffs` exported `fn/index.js:195-196`.
  - **Platform:** both.

- **C-631 — Savings-circle (tontine) pushes, if the parent is a circle member.**
  - **Parent sees/does:** pushes of types `circle_activated`, `circle_contribution_submitted`, `circle_cycle_ready_for_payout`, `circle_completed`, `circle_next_cycle_started`, `circle_member_joined`, `open_circle_available`, `circle_invite`, `circle_invite_reminder` (invites also by SMS/e-mail).
  - **Source:** `fn/handlers/circles.js:65-110` (sender), types at `:189,264,292,357,381,414,516,613,696`; SMS `fn/handlers/circles.js:5`.
  - **Data:** recipients = circle member uids. `high_importance_channel`.
  - **Tap:** none (C-616). Detail belongs to the tontine part.
  - **Platform:** mobile-only.

- **C-632 — Incoming audio/video call push.**
  - **Parent sees/does:** intended: "Incoming Audio Call"/"Incoming Video Call" / "{caller} is calling you". In practice not delivered: it reads only the legacy scalar `users/{uid}.fcmToken`, which the app never writes.
  - **Source:** `fn/handlers/direct_calls.js:101-142`; caller `lib/features/livekit/services/livekit_service.dart:476`. No Dart code listens to `direct_calls` or handles `incoming_call` (grep = only that one call site). How the callee is otherwise alerted: UNVERIFIED (chat part).
  - **Data:** `direct_calls` doc `{room_name, caller_id, caller_name, recipient_id, recipient_name, is_audio_only, status:'ringing', created_at}`; `data{type:'incoming_call', callId, roomName, callerId, callerName, isAudioOnly}`; channel `calls` (never created).
  - **Platform:** mobile-only.

- **C-633 — WhatsApp replies to a parent's payment proof.**
  - **Parent sees/does:** WhatsApp text replies (proof found / invoice paid) on the number the proof came from; only while `parent_messages_enabled` and WhatsApp secrets are set.
  - **Source:** `fn/handlers/finance_bank.js:373-402`, call sites `:625,1129,1277`. Out of app; listed for completeness.
  - **Platform:** WhatsApp.

- **C-634 — E-mails a parent can receive (out of scope, listed).**
  - Welcome e-mail with credentials when an admin creates the account: `fn/handlers/users.js:111,265` → `fn/services/email/senders.js:225-231`.
  - "🎓 Student Account Created for {child}" to each guardian with the child's credentials: `fn/handlers/students.js:335`, `fn/handlers/password.js:387` → `senders.js:294-300`.
  - Password reset: `senders.js:157-163`.
  - Task e-mails when the parent is an assignee/commenter (assignment, status, comment, 2-days-before recurring reminder): `fn/handlers/tasks.js:54,161,470,798`; triggered from Flutter `lib/features/tasks/services/task_service.dart:115,182,237`, `lib/features/tasks/services/task_comment_service.dart:192`. E-mail only, no push.
  - Enrolment request received (to the e-mail typed on the public enrolment form, usually the parent, before any account exists): `fn/handlers/enrollments.js:75-104` (one student), `:242-341` (several). `:455-472` goes to admins.
  - Circle invite e-mail: `senders.js:681-713`.
  - Invoice / payment / reminder / parent-linked / announcement e-mails: C-620, C-621, C-625, C-627, C-628.

- **C-635 — Pushes that exist but never target a parent account (do not port).**
  - Teacher shift pushes (`type:'shift'`, `fn/handlers/shifts.js:297-1218,3039`), form-required (`fn/handlers/forms.js:160`), audit (`fn/handlers/notifications.js:346-709`), makeup request (`fn/handlers/reschedule_requests.js:293-345`), no-show report (admins, `fn/handlers/no_show.js:592-753`), Zoom hub alerts (admins, `fn/handlers/zoom.js:2324-2526`), AI-tutor paused (admins, `fn/handlers/ai_tutor_voice.js:261-286`), quiz pushes (`user_type=='student'` only, `fn/handlers/quiz_review.js:240-254`, `fn/handlers/quiz_competition.js:935-948`).

### 6.5 Notification settings a parent can change

- **C-636 — Parent WEB Settings has no notification setting.**
  - **Parent sees/does:** Settings (sidebar index 5) shows header, Language, Change Password, Version. Nothing about notifications.
  - **Source:** `lib/features/settings/screens/role_settings_screen.dart:27-33`; wired at `lib/features/parent/screens/parent_dashboard_layout.dart:100-102`.
  - **Next.js:** no parent settings page. Teacher has one with a Notifications dialog (`apps/web/src/components/TeacherSettingsPage.tsx:117,135-156`).
  - **Platform:** web-only.

- **C-637 — Native: Settings → Notifications opens the preferences screen (same screen for every role).**
  - **Parent sees/does:** avatar → Settings → "Notifications / Manage notification preferences". Screen has four cards (C-638…C-641) and a Save button. Loading spinner while reading.
  - **Source:** `lib/features/dashboard/screens/mobile_dashboard_screen.dart:377-413`; `lib/features/settings/screens/mobile_settings_screen.dart:1108-1120`; `lib/features/settings/screens/notification_preferences_screen.dart` (load `:38-66`, no role check anywhere in the file).
  - **Platform:** mobile-only.

- **C-638 — "Shift reminders" switch + minutes (10/15/20/30).**
  - **Parent sees/does:** sees it and can change it; it has no effect for a parent (only the teacher reminder reads it).
  - **Source:** screen card `:172-292` (switch `:233-235`); service `lib/core/services/notification_preferences_service.dart:42-134`; server reader `fn/handlers/shifts.js:1181,3031-3032`.
  - **Data:** callable `updateNotificationPreferences({shiftEnabled})`, `({shiftMinutes})` → `users/{uid}.notificationPreferences.{shiftEnabled, shiftMinutes, lastUpdated}` (`fn/handlers/timezone.js:102-174`, export `fn/index.js:291-292`); local keys `shift_notification_enabled`, `shift_notification_time_minutes`.
  - **Platform:** mobile-only.

- **C-639 — "Task reminders" switch + days before due (1/2/3/5/7).**
  - **Parent sees/does:** can change it; nothing reads it (no push or e-mail consults `taskEnabled`/`taskDays`; the only task reminder is the fixed 2-day e-mail for recurring tasks).
  - **Source:** screen card `:293-412` (day chips `:389-393`); service `:138-232`; server writes only (`fn/handlers/timezone.js:133-139`); `grep taskEnabled|taskDays fn/handlers fn/services` = that file only.
  - **Data:** `updateNotificationPreferences({taskEnabled})`, `({taskDays})`; local keys `task_notification_enabled`, `task_notification_time_days`.
  - **Platform:** mobile-only.

- **C-640 — "Chat messages" switch — the one setting that really works for a parent.**
  - **Parent sees/does:** off = no chat pushes (C-618/C-619) on any device.
  - **Source:** screen card `:413-485` (switch `:471-473`); service `:338-384`; callable `fn/handlers/chat.js:267-302` (export `fn/index.js:316-317`); reader `fn/handlers/chat.js:118-124`.
  - **Data:** `updateChatNotificationPreference({chatEnabled: bool})` → `users/{uid}.notificationPreferences.{chatEnabled, chatUpdatedAt}`; local key `chat_notification_enabled`.
  - **Next.js:** teacher dialog writes `notificationPreferences.chatEnabled` directly to Firestore (`TeacherSettingsPage.tsx:146-151`); nothing for parents.
  - **Platform:** mobile-only (setting); effect is account-wide.

- **C-641 — "PRAYER TIMES (ADHAN)" switch.**
  - **Parent sees/does:** on = five daily local notifications at prayer times computed from GPS location, today and tomorrow; off = all cancelled. Hard-coded English labels. Stored on the device only.
  - **Source:** screen card `:486-592` (switch `:547-549`); `lib/core/services/prayer_notification_service.dart:61-84,123-166,228-238`; scheduled at every launch `lib/main.dart:259-264`.
  - **Data:** SharedPreferences `prayer_notification_enabled` (default true). No Firestore.
  - **Next.js:** teacher dialog keeps the same flag in `localStorage` (`TeacherSettingsPage.tsx:86,153`) but schedules nothing.
  - **Platform:** mobile-only.

- **C-642 — Save button always reports success.**
  - **Parent sees/does:** Save writes all six values then shows "notification preferences saved"; the failure snackbar can effectively never appear for server errors because each setter catches and only logs its own error.
  - **Source:** screen `:68-110`; setters' `catch` blocks e.g. `notification_preferences_service.dart:74-88,370-384`.
  - **Platform:** mobile-only.

- **C-643 — Preferences are read device-first.**
  - **Parent sees/does:** a value changed on another device (or by the Next.js teacher dialog) is not reflected once this phone has a cached value; Firestore is consulted only when the local key is absent.
  - **Source:** `notification_preferences_service.dart:42-72,338-368`. `clearPreferences()` `:414` has no caller.
  - **Platform:** mobile-only.

- **C-644 — No opt-out exists for billing, linking or announcement pushes/e-mails.**
  - **Source:** none of `fn/handlers/payments.js:550-626`, `finance_billing.js:1110-1171`, `finance_invoices.js:47-90`, `enrollments.js:1232-1258`, `notifications.js:126-290` read `notificationPreferences`. `classEnabled`/`classMinutes` exist in the service (`:238-334`) and callable but the screen has no control for them.
  - **Platform:** both.

### 6.6 Device-local notifications (native only)

- **C-645 — Prayer-time notifications are scheduled for every native user, parents included, from first launch (default on).** Source/Data: C-641. Platform: mobile-only.
- **C-646 — Daily Quran goal reminder** ("Quran time 📖" / "Today's goal: N ayah(s)…") is a local notification set inside the Quran reader; native only (`lib/features/quran_reader/services/goal_reminder_service.dart:20,40-70`; UI `lib/features/quran_reader/screens/quran_reader_screen.dart:230-238,603-604`). Whether a parent reaches the Quran reader is for the Quran/navigation part. Platform: mobile-only.

- **C-649 — Help text promises class reminders.**
  - **Parent sees/does:** native Settings → "Help & Support" opens a sheet (same for every role) with an item "Getting Notifications — Enable notifications in Settings to get reminders before your classes." A parent gets no class reminders (C-629). The "Help & Support" row in the avatar sheet on the dashboard only closes the sheet.
  - **Source:** `lib/features/settings/screens/mobile_settings_screen.dart:452,496-500,1240-1244`; text `lib/l10n/app_en.arb:2187,4590`; dead row `lib/features/dashboard/screens/mobile_dashboard_screen.dart:428-443`.
  - **Next.js:** none. **Platform:** mobile-only.

### 6.7 Next.js today

- **C-647 — What exists in `apps/web` and what a parent version would lack.**
  - Exists: a non-clickable bell in the student header whose count is never set (`apps/web/src/components/StudentDashboardHome.tsx:573,842-855`; `setNotificationCount` is never called); per-chat unread pills in student chat (`StudentChatPage.tsx:649,1107-1109`); teacher notification-preferences dialog (`TeacherSettingsPage.tsx:135-156`); admin announcement composer (`NotificationsAdmin.tsx:126-134`).
  - Missing for a parent: any parent route/shell; browser push (no messaging SDK use, no service worker, no VAPID key, no token write); any notification list; any settings page. To match Flutter WEB exactly, nothing notification-related needs to exist (C-600, C-601, C-636).
  - **Platform:** web.

- **C-648 — Links inside parent e-mails point at the Flutter app.**
  - **Source:** parent-linked e-mail hard-codes `https://alluwaleducationhub.org/app/` (`fn/handlers/enrollments.js:1219`); invoice and receipt e-mails pass `appUrl: _appUrl()` (`fn/handlers/payments.js:467,732`), which is `APP_URL` / `PUBLIC_APP_URL` env or `https://alluwaleducationhub.org` (`fn/handlers/payments.js:312-317`); how the template turns that into a link is in `fn/services/email/senders.js:11-34,94-115` (exact path UNVERIFIED — not read line by line). The pay-now link is the separate payment-link URL (billing part).
  - **Platform:** both.

### Summary table

| Notification type | Sender (file:line) | Recipient resolution | Channel | Tap target for a parent |
|---|---|---|---|---|
| Chat message `chat_message` | `fn/handlers/chat.js:28` trigger on `chats/{id}/messages` | chat `participants` minus sender; `chatEnabled !== false` | FCM push | Native: opens that chat (`notification_service.dart:432-532`); cold start → Home. Web: none |
| Admin Support reply `chat_message` | `fn/handlers/chat.js:79-93` | the member of `[member,'admin_support']` | FCM push | Native: Admin Support thread |
| New invoice `invoice_created` | `fn/handlers/payments.js:1213` trigger on `invoices/{id}` | `parent_id|payer_id`, else `student_id`; engine invoices need `parent_messages_enabled` | FCM push + e-mail (PDF + pay link) | None (app just opens) |
| Invoice due reminder `invoice_reminder` | `fn/handlers/finance_billing.js:1248` daily 09:00 NY | `parent_id`, else `student_id`; needs `parent_messages_enabled` | FCM push + e-mail | None |
| Manual reminder (re-sent as `invoice_created`) | `fn/handlers/finance_invoices.js:520` admin callable | as New invoice | FCM push + e-mail | None |
| Invoice updated `invoice_updated` | `fn/handlers/finance_invoices.js:384` | `parent_id` only; needs `parent_messages_enabled` | FCM push | None |
| Invoice cancelled `invoice_cancelled` | `fn/handlers/finance_invoices.js:500` | `parent_id` only; needs `parent_messages_enabled` | FCM push | None |
| Payment received `payment_completed` (history only) | `fn/handlers/payments.js:390` | `parent_id`, else `student_id` | E-mail only | n/a |
| Payment failed | — | — | none | n/a |
| Child linked `parent_linked` | `fn/handlers/enrollments.js:1232` admin callable | the parent uid being linked (`guardian_ids`) | FCM push + e-mail | None |
| Admin announcement `admin_notification` | `fn/handlers/notifications.js:15` callable | ids, or `user_type==role && is_active==true` | FCM push + optional e-mail | None |
| Class reminder / updated / teacher changed | `fn/handlers/shifts.js:3056, 955, 1564` | `student_ids` only — never guardians | FCM push (to students) | Parent receives nothing |
| Access suspended / restored | `fn/handlers/invoice_access.js` | — | none | n/a |
| Circle (tontine) `circle_*` | `fn/handlers/circles.js:65` | circle member uids | FCM push (+SMS/e-mail invites) | None |
| Incoming call `incoming_call` | `fn/handlers/direct_calls.js:101` | `recipientId`, legacy `fcmToken` only | FCM push (dead) | None |
| Payment-proof reply | `fn/handlers/finance_bank.js:388` | sender's WhatsApp number; needs `parent_messages_enabled` | WhatsApp | n/a |
| Prayer times | device, `prayer_notification_service.dart:123` | this device | local notification | None |

### Broken / dead / hard-coded today (notifications)

- **B-1 Cold-start tap never navigates on phones.** `notification_service.dart:392-402` stores the tap; only `dashboard.dart:163-166` consumes it, and phones never show that screen (`role_based_dashboard.dart:323-328`). `getPendingNavigation` (`:569-573`) and `_navigateBasedOnMessage` (`:596-635`) are dead.
- **B-2 Token is not registered at sign-in.** The only save calls are app launch (`main.dart:266-267`, user must already be signed in) and token refresh (`notification_service.dart:576-593`). A parent who installs the app and signs in gets no pushes until the app is next cold-started while signed in. (Comment in `fcm_token_ownership.js:7` says "on sign-in"; no such code exists — grep `saveTokenToFirestore` = `main.dart:105` only.)
- **B-3 `sendAdminNotification` never checks who is calling.** The handler takes one argument and never reads the caller's auth (`fn/handlers/notifications.js:15-30`); the admin test runs only `if (adminId)` on an id supplied in the request body (`:52-67`); registered with a bare `functions.https.onCall` (`fn/index.js:96-98`, `firebase-functions ^6.4.0`). A request that omits `adminId`, or passes any admin's uid, can push/e-mail any user or a whole role. Not exercised live (read-only task).
- **B-4 Sign-out leaves the phone registered** (C-609).
- **B-5 Role broadcast misses parents** without `is_active == true` or who are parents via `secondary_roles` (`fn/handlers/notifications.js:87-92`).
- **B-6 Incoming-call push is dead** — reads `recipientData.fcmToken` (`fn/handlers/direct_calls.js:102`); app writes only `fcmTokens[]`; channel `calls` never created.
- **B-7 Preference switches with no effect:** task reminders (C-639); shift reminders for a parent (C-638); class reminder prefs unreachable from the UI (C-644). Save always says "saved" (C-642).
- **B-8 Manual reminder is worded as a new invoice** (`finance_invoices.js:538` → `payments.js:562-563`, e-mail subject `senders.js:34`).
- **B-9 Every non-chat push has no tap target** (C-616), although the payload carries `invoiceId` / `studentUid`.
- **B-10 `notification_history.results` for a parent with no phone records `fcmFailed: 1`** even though nothing was attempted (`payments.js:782-783`, `finance_invoices.js:83-84`).
- **B-11 Hard-coded English** in all server push/e-mail texts (parent language is ignored), and in the Adhan card (`notification_preferences_screen.dart:525,535,574-575`).
- **B-12 Admin history panel reads `admin_notifications`** (`send_notification_screen.dart:857,997`) while sends are logged to `notification_history` (`notifications.js:293`) — admin-side, noted because it is the only "history" UI.
- **B-13 Adhan sound resource:** `android/app/src/main/res/raw/` is absent or empty in the repo (`ls` returns nothing) and no `adhan.*` is in `ios/Runner/`, while the channel references `RawResourceAndroidNotificationSound('adhan')` / `adhan.aiff` (`prayer_notification_service.dart:108,193,206`). Runtime effect UNVERIFIED (not run on a device).
- **B-14 Unused rule/collection:** `/notifications/{id}` (`firestore.rules:763-771`) has no reader or writer.

### Questions for the owner (notifications)

1. Parent web today shows no notifications at all. Is "exactly the same" the goal for the new parent web (nothing), or do you expect a bell / browser push there? (Anything added is new scope, not parity.)
2. Are parent messages (`finance_settings/main.parent_messages_enabled`) ON in production right now? It decides whether parents get monthly-invoice e-mails/pushes, reminders, updated/cancelled pushes and WhatsApp replies.
3. Parents get no class reminders and no "class changed / teacher changed" pushes (students only), and the parent class e-mail is switched off. Intended?
4. Parents are not told when access is suspended or restored. Intended?
5. No push for "payment received" and nothing at all for "payment failed". Intended?
6. E-mail buttons send parents to `/app/`. After the move, should they open the new parent pages?
7. `sendAdminNotification` can be called without an admin check (B-3). Fix now, separately from the migration?
8. Should the phone app keep showing parents the Shift and Task reminder switches that do nothing for them?

---

## 7. The Next.js side and how the existing cut-overs work

### 7.1 What exists for students, screen by screen, and how a parent version differs

| Parent screen (Flutter) | Student page on Next.js | What a parent version must do differently |
|---|---|---|
| Classes (C-001…C-030) | `/student/classes/` → `StudentClassesPage.tsx` | Resolve children first (C-003), one class query per child, sibling grouping (C-008), no 2-day floor and no cancelled filter (C-007, C-016), full History instead of 24 h (C-012), Flutter status wording (C-014), date on the card (C-015), participant chip/panel (C-017), details sheet (C-018), "no children" state (C-005), role gate for parents instead of `isStudent`. |
| Class join (C-019…C-027) | `/student/classroom/?shiftId=` → `StudentClassroomPage.tsx` | Same callables. Send `activeRole: "parent"` (C-021). Return link must point at the parent classes page, not `/student/classes/` (`StudentClassroomPage.tsx:262`, `:304`, `:320`, `:452`). Role gate (`:87`). Meeting page isolation differs from Flutter web (C-024). |
| Recordings (C-200…C-226) | `/student/recordings/` → `StudentRecordingsPage.tsx` | Send `activeRole: "parent"` instead of the hard-coded `"student"` (`StudentRecordingsPage.tsx:437`, `:564`); per-child grouping level. Server parent branch already exists. See section 2. |
| Curriculum Books (C-300…C-310) | `/student/curriculum-books/` → `StudentCurriculumBooksPage.tsx` | Same hard-coded list. See section 3a. |
| Quran (C-330…C-356) | `/student/quran/` → `StudentQuranPage.tsx` + `QuranReaderPage.tsx` | Dead on Flutter web today (C-330); works on phones. Owner decision whether a parent web page exists at all. See section 3b. |
| Chat (C-400…C-484) | `/student/chat/` → `StudentChatPage.tsx` | Contact resolution through children, leader types, composer lock, and the feature gaps listed in section 4.11. |
| Circles (C-500…C-503) | none | Nothing to build to match today's web. |
| Notifications (C-600…C-649) | none (no bell, no web push in either app) | Nothing to build to match today's web. |

Shared student plumbing a parent area would copy or generalise:

**C-700 — Student pages guard themselves; there is no `/student/` layout guard**
- **What happens:** `apps/web/src/app/student/` has no `layout.tsx`. Every page calls `resolveStudentSession(user)` and renders `StudentAccessPrompt` unless `isStudent` is true. A signed-in parent opening any `/student/…` URL today gets a card "Student access required — Sign in with a student account to open the student dashboard." with a "Go to login" link to `/student/login/`; signed-out visitors get "Student sign-in required".
- **Source:** `apps/web/src/lib/studentSession.ts:99-120` (`isStudent: roles.has("student")`); `apps/web/src/components/StudentClassesPage.tsx:65-93`, `:149`; `apps/web/src/components/StudentDashboardHome.tsx:1069-1127`.
- **Parent version:** needs the same per-page gate keyed on the parent role (`user_type == 'parent'` or `'parent'` in `secondary_roles`, the definition `firestore.rules:140-146` uses).

**C-701 — The student session is cached in memory and in localStorage**
- **What happens:** the resolved session (uid, isStudent, isAdultStudent, accessSuspended, language, name/initials/photo) is kept at module scope and under localStorage key `alluwal-student-session-v1`, reused on reload for the uid Firebase has persisted, and cleared on sign-out.
- **Source:** `apps/web/src/lib/studentSession.ts:33-97`; `StudentDashboardHome.tsx:680-685`.
- **Parent version:** a parent session cache needs its own key, and must not reuse a student session for a parent+student account.

**C-702 — Student shell: menu, role switch, sign-out**
- **What happens:** `StudentShell` draws the sidebar (Dashboard; Finance for adult students; Classes, Recordings, Tasks, Quiz, Progress, Quran, AI Tutor, Surah Podcasts, Curriculum Books; Chat, Forms). An account with other roles gets a "Switch to" menu: choosing a role writes `flutter.active_user_role` into localStorage and navigates to `/app/`, which is exactly what the Flutter role switcher stores. Sign-out clears the cached session, signs out and goes to `/student/login/`.
- **Source:** `StudentDashboardHome.tsx:76-109` (menu), `:530-537` (`switchToRole`), `:804-830` (menu UI), `:680-685` (logout).
- **Parent version:** today "Switch to Parent" from the student shell lands in Flutter. After a parent cut-over that hop would bounce `/app/` → parent pages, or the link must go straight there. The Flutter parent sign-out ends on the public site root (`lib/features/parent/screens/parent_dashboard_layout.dart:359-372`, `lib/core/utils/post_sign_out.dart`).

**C-703 — Language**
- **What happens:** student pages translate through `useT()` (`apps/web/src/lib/i18n`), seeded from `users.language_preference`.
- **Source:** `StudentClassesPage.tsx:10`, `:61`; `studentSession.ts:117-120`.
- **Parent version:** production has `language_preference` on 1 of 118 parent accounts (section 8); the Flutter parent screens in this inventory mix localized and English-only text (lists under each section).

### 7.2 The student cut-over (Flutter → `/student/`)

**C-710 — Web students are bounced from Flutter to `/student/` unconditionally**
- **What happens:** after sign-in the Flutter shell resolves the active role; on native phones it always returns the mobile dashboard; on the web, role `student` renders `_StudentWebRedirect`, which calls `window.location.replace('/student/')` and shows a spinner. There is no flag, allowlist or kill switch: undoing it needs a Flutter web build.
- **Source:** `lib/features/dashboard/screens/role_based_dashboard.dart:22-26` (`_isNativeMobile`), `:321-328`, `:349-356`, `:706-726`; `lib/core/utils/web_redirect_web.dart:11-16`; `lib/core/utils/web_redirect_stub.dart:4-8` (no-ops off the web); conditional import `role_based_dashboard.dart:19-20`.
- **Why no second login:** same origin, same Firebase project and API key, and the session record is shared (C-730).
- **Parent today:** `case 'parent'` returns the Flutter parent shell (`role_based_dashboard.dart:357-362`, `:632-640`).

**C-711 — The decision uses the ACTIVE role, not the account type**
- **What happens:** the role comes from `UserRoleService.getCurrentUserRole()`: the stored `active_user_role` preference when the account still holds that role, else `users.user_type`. The parent shell has a role switcher in its top bar; switching reloads this routing.
- **Source:** `role_based_dashboard.dart:198-221`, `:293-301`; `lib/core/services/user_role_service.dart:14`, `:77-98`; `lib/features/parent/screens/parent_dashboard_layout.dart:189-192`, `:212-215`.
- **Consequence for parents:** a parent+student account that switches to Student is sent to `/student/`; coming back relies on the Next "Switch to" menu (C-702). Production has 2 such accounts (section 8).

### 7.3 The staged teacher cut-over (the pattern with a rollback switch)

**C-720 — One Firestore document decides who moves**
- **What happens:** `settings/teacher_web_cutover` holds `mode: 'off' | 'allowlist' | 'all'`, `teacherIds: [uid…]` (used only in `allowlist`), `hold: bool`, plus `note`, `updatedAt`, `updatedBy`. Editing it moves teachers either way with no deploy.
- **Source:** `lib/core/services/teacher_web_cutover.dart:6-24`; live document read on 2026-11-14: `mode: "all"`, `hold: false`, 38 ids in `teacherIds`. No `settings/parent_web_cutover` or `settings/student_web_cutover` document exists.
- **Rules:** `firestore.rules:397-400` (`settings`: read for any signed-in user, write for admins).

**C-721 — Flutter side fails closed**
- **What happens:** `TeacherWebCutover.shouldUseWebConsole(uid)` returns false off the web, for an empty uid, when the document is missing, on any error, and for any mode other than `all` or an `allowlist` that contains the uid. It reads from the server (`Source.server`), never the cache, and remembers the answer for the life of the page.
- **Source:** `teacher_web_cutover.dart:33-58`.
- **Trap:** `TeacherWebCutover.reset()` (`:61`) is never called anywhere in `lib/` (grep), so the remembered answer is not cleared when a different person signs in within the same page session.

**C-722 — Where Flutter applies it, and the admin exception**
- **What happens:** for active role `teacher` on the web, `_TeacherDashboardOrWebRedirect` first keeps anyone whose available roles include `admin` or `super_admin` on Flutter (the admin console forwards `/admin/` back to `/app/`, so they would loop), then asks the cut-over; yes → `window.location.replace('/teacher/')`, no → the Flutter teacher dashboard. A spinner shows while deciding so the wrong dashboard never flashes.
- **Source:** `role_based_dashboard.dart:340-348`, `:644-704`; `web_redirect_web.dart:18-19`.
- **Parent version:** the same shape fits `case 'parent'`. The equivalent of the admin exception to settle is the multi-role parent (parent+student today; parent+teacher/admin none in production).

**C-723 — Next.js side reads the same document and fails OPEN**
- **What happens:** `teacherUsesWebConsole(uid)` mirrors the Flutter logic but returns true when the document is missing or unreadable, on purpose (someone already on the console should not be thrown back). Cached per page; cleared on teacher sign-out.
- **Source:** `apps/web/src/lib/teacherCutover.ts:11-44`; `apps/web/src/components/TeacherDashboardHome.tsx:489-491`; `TeacherSettingsPage.tsx:126`.

**C-724 — Operating the switch**
- **What happens:** a GitHub workflow reports every weekday (11:30 UTC) and on Fridays promotes `allowlist` → `all` unless `hold` is set or a moved teacher's pay disagrees with their clocked hours. Manual modes: `report`, `allowlist-this-week`, `all`, `hold`, `resume`, `off` (`off` returns everyone to Flutter immediately).
- **Source:** `.github/workflows/teacher-web-cutover.yml:1-27`; `scripts/teacher_web_cutover.mjs:126-197`.
- **Parent version:** the pay check is teacher-specific; a parent equivalent would need its own health signal (owner question).

**C-725 — `dashboardPathForUser`: where the Next.js login sends each account**
- **What happens:** used by the Next login form (`/login/`, `/student/login/`) after sign-in and for the "already signed in" link. No user record → `/app/`. Student and not admin/super_admin/teacher → `/student/`. Teacher and not admin, when the cut-over says so → `/teacher/`. Everyone else → `/app/`. Roles = `user_type` + `secondary_roles` (+ `teacher` for admins, + `admin` for admin-teachers). The user record is found by uid, then by doc id = email, then by `email` / `e-mail` field, then by `phone_number`.
- **Source:** `apps/web/src/lib/userRoles.ts:35-55`, `:65-101`; `apps/web/src/components/LoginForm.tsx:13-15`, `:32-39`, `:44-49`, `:84`.
- **Parent today:** parent-only → `/app/`. A parent who also holds the student role → `/student/` (the test does not look at `parent`), whatever their active role in Flutter.
- **Parent version:** needs a parent branch here, with a stated order for parent+student accounts.

### 7.4 Route guards in `apps/web/src/app/*/layout.tsx`

**C-726 — `/admin/*`**
- **What happens:** `AdminRouteGate` renders only `/admin/shifts`, `/admin/student-applicants`, `/admin/finance` natively; every other `/admin/…` path renders `FlutterRedirect` (`window.location.replace('/app/')`, text "Taking you to the app…").
- **Source:** `apps/web/src/app/admin/layout.tsx:13-15`; `apps/web/src/components/AdminRouteGate.tsx:12-19`; `apps/web/src/components/FlutterRedirect.tsx:13-26`.

**C-727 — `/teacher/*`**
- **What happens:** `TeacherRouteGate` renders its children unchanged; each teacher page checks the teacher role itself. The comment in `teacher/layout.tsx:8-11` ("The teacher console lives in the Flutter app…forwards the rest to /app/") is out of date.
- **Source:** `apps/web/src/app/teacher/layout.tsx:8-14`; `apps/web/src/components/TeacherRouteGate.tsx:5-16`; `TeacherDashboardHome.tsx:197`.

**C-728 — `/student/*` and a future `/parent/*`**
- **What happens:** no layout file under `apps/web/src/app/student/`; guarding is per page (C-700). There is no `apps/web/src/app/parent/` directory. The site is a static export (`apps/web/out`, copied by `package-hostinger.mjs:21-51`), so all guards run in the browser after load.
- **Source:** directory listing of `apps/web/src/app/`.

### 7.5 Constraints every Next.js page on this origin must respect

**C-730 — Shared session: pin `browserLocalPersistence`**
- **What happens:** `apps/web/src/lib/firebase.ts` creates auth with `initializeAuth(app, { persistence: browserLocalPersistence, popupRedirectResolver: browserPopupRedirectResolver })`, falling back to `getAuth` only when already initialised; `ensureAuthPersistence()` sets the same persistence before sign-in. The comment explains why: Flutter web keeps the session in localStorage, and the default (IndexedDB) would migrate the record and sign Flutter out.
- **Source:** `apps/web/src/lib/firebase.ts:60-79`, `:84-90`.
- **Parent version:** import `auth` from this module only; never call `getAuth()` first. This matters more for parents than it did for students because parents will keep using Flutter for anything not yet moved.

**C-731 — COEP header for pages framed inside Flutter**
- **What happens:** `/app/` is cross-origin isolated (`COOP: same-origin`, `COEP: credentialless`; live check 2026-11-14). A page shown in an iframe inside Flutter must send COEP itself, so the packaging script writes an `.htaccess` with `Cross-Origin-Embedder-Policy "credentialless"` into each embedded route: `admin/shifts`, `admin/student-applicants`, `admin/finance`, `teacher/job-board`.
- **Source:** `apps/web/scripts/package-hostinger.mjs:53-73`; `web/.htaccess:6-13`.
- **Parent version:** only relevant if a parent page were embedded in the Flutter shell rather than reached by redirect. A full redirect (the student/teacher pattern) needs no entry.

**C-732 — Packaging facts that affect a parent area**
- **What happens:** the script refuses to package a bundle that references the dev Firebase project; writes a root `.htaccess` (no-cache for html/txt/json; no cross-origin headers); copies the Flutter build to `/app/` and rewrites its base href and `.htaccess`. The meeting pages exist twice: `/zoom_meeting.html` and `/realtimekit_meeting.html` at the root (from `apps/web/public/`) and under `/app/` (from `web/`). `zoom_meeting.html` is identical in both; `realtimekit_meeting.html` differs between them.
- **Source:** `package-hostinger.mjs:25-47`, `:86-101`, `:115-154`; `diff` of the two pairs.

### Memory notes checked against the code

| Note | Claim | Status |
|---|---|---|
| `project_alluwal_student_cutover.md` | Student web redirect via `_StudentWebRedirect` / `redirectToStudentWebApp`, conditional import, `kIsWeb` discriminator | Correct (`role_based_dashboard.dart:349-356`, `:706-726`). |
| same | "`/admin/` and `/teacher/` layouts render `FlutterRedirect`" | Stale. `/teacher/` renders its pages (C-727); `/admin/` renders three native prefixes and forwards the rest (C-726). |
| same | "`dashboardPathForUser`: only a student-only account goes to `/student/`; everyone else → `/app/`" | Stale. Teachers without admin now go to `/teacher/` when the cut-over says so (`userRoles.ts:49-53`). "Student-only" still ignores the parent role, so parent+student → `/student/`. |
| `project_alluwal_teacher_cutover.md` | Document shape, modes, fail-closed on Flutter | Correct. Body text "mode: off … redirect NOT yet flipped" is superseded by its own last paragraph; live mode is `all`. |
| same | "Admin-teachers (`is_admin_teacher`) are kept on Flutter" | Broader in code: anyone whose available roles include `admin` or `super_admin` stays (`role_based_dashboard.dart:677-683`). |
| same | not mentioned | Next side fails OPEN (C-723); `TeacherWebCutover.reset()` is never called (C-721). |
| `project_alluwal_auth_persistence.md` | `initializeAuth` with `browserLocalPersistence` in `firebase.ts` | Correct (C-730). |
| same | "`package-hostinger.mjs` writes the COEP `.htaccess` into `admin/shifts/`" | Stale: four routes now (C-731). |
| `project_alluwal_admin_support_chat.md` | see "Memory-note staleness (chat)" in section 4 | — |

---

## 8. Production numbers

Counts read from production on 2026-11-14 are kept out of this public repository (the migration working folder holds them). The hosting checks below are public facts.

### 8.5 Live hosting checks (HEAD requests, 2026-11-14)

| URL | Result |
|---|---|
| `/app/` | 200, `COOP: same-origin`, `COEP: credentialless` |
| `/app/zoom_meeting.html` | 200, `COOP: same-origin`, `COEP: require-corp` |
| `/zoom_meeting.html` (used by `/student/classroom/`) | 200, no COOP / COEP header |
| `/student/classroom/` | 200, no COOP / COEP header |
| `/parent/` | 404 |
| `/app/version.json` | version 1.2.2, build 12200; `web/index.html` asset tag `v=332` |

---

## 9. Top risks and surprises (across this inventory)

1. **Zoom page isolation differs between the two apps (C-024, section 8.5).** Flutter web parents join on a cross-origin-isolated page; the Next.js classroom page is not isolated, which switches the Zoom SDK to its reduced mode. Web students already run that way.
2. **The student Classes page is not a parent Classes page (section 1, 7.1).** It filters to the last 2 days, hides cancelled classes, shows 24 hours of history, has different status words, no date on the card, no sibling grouping, no participant panel and no details sheet.
3. **Two child-link fields that disagree (N-20).** `guardian_ids` drives Classes, the dashboard and the server's join permission; `children_ids` drives chat contacts first. 3 parents are inconsistent today.
4. **Parents joining are never counted as attendance (C-022).** A child who attends through the parent's login is not marked present, in either app.
5. **Recordings is empty in production (N-27)** and unreachable for parents on phones (C-201); the list is capped at 100 with no "load more" (C-204).
6. **Chat rules are wider than the screens (section 4).** Message locks exist only in the Flutter UI; several actions are broken today (clear chat, block, leave group, forward to Admin Support); web parents cannot send voice notes; 48 parents are in group chats.
7. **Web parents get no notifications of any kind (section 6),** and parents get no class reminders or class-change pushes on phones either. `sendAdminNotification` does not check the caller unless an `adminId` is supplied (section 6, broken list).
8. **Multi-role and stale-cache traps in the cut-over code (section 7).** `dashboardPathForUser` sends parent+student accounts to `/student/`; the routing follows the active role stored in the browser; `TeacherWebCutover.reset()` is never called; the Next.js side of the teacher switch fails open while Flutter fails closed; the student redirect has no rollback switch.

## 10. Questions only the owner can answer

Already answered by production data: parents ARE in group chats (48 parents, N-24/N-25); `parent_messages_enabled` is ON (N-32).

**Cut-over**
1. Should parent+student accounts (2 today) land on the parent area or the student area after login, and is the active-role switcher expected to keep working across the two apps?
2. Staged roll-out like teachers (allowlist first, then everyone, with an off switch)? If yes, what is the health signal that allows promotion (teachers used a pay check)?
3. About 24 parents are active in a month and at most 9 of them are web-only. Is a first allowlist of named families acceptable, and who picks them?
4. Should links in parent e-mails that open `/app/` point to the new parent pages after the move?

**Classes and joining**
5. The Next.js classroom page is not cross-origin isolated while the Flutter one is (C-024). Do you want parents moved onto the page students already use as it is, or is this something you want changed first? (No change will be made without your explicit request.)
6. Keep showing cancelled classes, and the full history back to about 60 days, on the parent page?
7. Keep the live participant list and the "Assigned Students" list, which show other families' children's names to a parent (C-017, C-018)?
8. A started class whose teacher has not clocked in reads "Missed" while the Join button shows (C-014). Reproduce exactly, or correct the wording?
9. Should a parent's join ever count as the child's attendance (C-022)? Today it does not.
10. Should the parent Classes page show anything when a child's access is suspended (C-023)? Today it shows nothing and the parent can still join.
11. Several Classes texts are English only. Translate on the new page, or keep as is?

**Recordings, Books, Quran**
12. Quran on parent web: include it (phone parity) or leave it out (what web parents really have today)? If included, the parent's own progress, as on phones?
13. Recordings: build the page although there are no recordings in production? Keep the 100 cap? May parents download? Keep search by teacher e-mail/phone?
14. Books: open in a new tab (Flutter web) or in the in-page reader (student web)?
15. Fix the web reader's daily-goal count before another role uses it (section 3b broken list)?

**Chat**
16. Which field is the truth for "my children": `guardian_ids` or `children_ids`? (3 parents disagree.)
17. Which leader types are personal contacts for a parent (Flutter lists five kinds; student web lists two)?
18. Voice notes on web for parents (Flutter web refuses; student web sends WebM)?
19. Clear chat, Block, Leave group, forward to Admin Support are broken today: reproduce, fix, or leave out?
20. Keep the composer lock for teachers not related to the family? Keep the 50-message cap? Delete-for-everyone window: 2 days (Flutter) or unlimited (student web)?
21. Admin replies in the support thread: right side in teal (Flutter today) or left (student web)?

**Circles and notifications**
22. Confirm no Circles page for parents on the web (hidden today; 1 parent has it on the phone).
23. Is "no bell, no browser push, no unread badge" the target for the new parent web, or is something expected there (new scope)?
24. Parents get no class reminders, no class-change notices, no suspension notice, no payment-failed notice. Intended?
25. `sendAdminNotification` has no caller check unless `adminId` is passed. Fix now, separately from this move?
