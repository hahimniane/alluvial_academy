# Handoff: Zoom classroom pilot + No-Show Alerts + Live roster

**Audience:** the next AI/engineer picking this up. Read this fully before touching anything.
**Last updated:** 2026-07-02.
**Repo:** Flutter (web + Android + iOS) + Firebase. Prod project `alluwal-academy`, dev `alluwal-dev`.

> **State in one line:** Zoom Meeting SDK pilot is built, deployed to functions (dev+prod), and **proven working end-to-end on a live test class** (teacher hosts, students join, presence tracked, live roster shows who's in). The No-Show Alerts admin screen is built. **Nothing is shipped to real users yet** — all client code is uncommitted in the working tree, and the two pilot teachers' real shifts are NOT yet flipped to Zoom.

---

## 1. What we built

### A. Zoom Meeting SDK classroom (admin one-click "put a teacher on Zoom")
Goal: an admin flips a specific teacher onto **real Zoom** (embedded via Meeting SDK); every other teacher stays on the current **RealtimeKit** classroom. Motivation: some teachers have persistent audio/screen-share trouble on RealtimeKit and were escaping to their own Zoom (which also caused false "absent" flags).

- **Source of truth:** `use_zoom` (bool) + `zoom_host_account` (email) on the teacher's `users` doc. The shift's `video_provider` (`zoom`|`realtimekit`) is the routing field the client + backend key off.
- **Join flow:** client `ClassVideoService.joinClass` (`lib/core/services/class_video_service.dart`) branches on `shift.usesZoom` → calls `getZoomJoinInfo` → opens `ZoomMeetingScreen`. Teacher joins as **host** (SDK role 1 + ZAK), students as **participants** (role 0).
- **Attendance/presence:** a Zoom **webhook** (`zoomWebhook`) writes join/leave into `livekit_sessions` (the same collection `functions/handlers/attendance.js` and the live roster read) — this is what fixes the "marked absent on Zoom" problem.

### B. No-Show Alerts admin screen (client-only)
The live prod app had an "Operations → No-Show Alerts" screen that didn't exist in this codebase (only the `reportNoShow` backend + `no_show_reports` collection did). Rebuilt it + added search and a **repeat-absent-teacher patterns band**.

### C. Live roster ("who's in the class", auto-updating)
The existing "Live Participants" UI (polls every 10–15s) only worked for RealtimeKit. Made the presence backend provider-aware so it also returns the **Zoom** roster from `livekit_sessions`. Zero client changes.

---

## 2. Files changed / added

### Backend (`functions/`)
- `handlers/zoom.js` **(new)** — `getZoomJoinInfo`, `setTeacherZoomEnabled` (admin toggle; sets flag/host + flips upcoming teaching shifts), `zoomWebhook` (URL-validation handled before signature; writes presence to `livekit_sessions`). `ensureZoomMeeting` uses permissive settings (join_before_host, no waiting room, mute_upon_entry:false, meeting_authentication:false).
- `services/zoom/{config,oauth,client,signature}.js` **(new)** — S2S OAuth (account_credentials), REST client (createMeeting/getMeeting/getUserZak/deleteMeeting/listMeetingParticipants), Meeting SDK JWT signature.
- `handlers/realtimekit.js` **(modified)** — `getRealtimeKitRoomPresence` is now **provider-aware**: for a `zoom` shift it calls new `buildZoomRoomPresence(shiftId, shiftData)` which reads `livekit_sessions` open windows and returns the same shape. This is what makes the live roster work for Zoom with no client change.
- `index.js` — exports `getZoomJoinInfo`, `setTeacherZoomEnabled`, `zoomWebhook`.
- `tests/zoom_handler.test.js`, `tests/zoom_signature.test.js` **(new)** — passing. (Fixed a time-dependent test that used a hardcoded near-future date.)

### Client (`lib/`, `web/`)
- `core/services/class_video_service.dart` — Zoom join branch (~line 489). `getRoomPresence` unchanged (still calls `getRealtimeKitRoomPresence`, now Zoom-aware).
- `core/widgets/zoom_meeting_screen.dart` + `_web.dart` + `_io.dart` **(new)** — web loads `web/zoom_meeting.html` (Meeting SDK Client View, CDN 6.2.0, `disableCORP`, `#zmmtg-root` fix); io uses `flutter_zoom_meeting_wrapper` (native SDK binaries not bundled — see `docs/zoom-classroom-pilot.md`).
- `web/zoom_meeting.html` **(new)**.
- `features/shift_management/models/teaching_shift.dart` (`usesZoom` getter) + `enums/shift_enums.dart` (`zoom` un-deprecated).
- `features/shift_management/widgets/create_shift_dialog.dart` — teaching+`useZoom` → zoom; **non-teaching always realtimekit** (important fix).
- `core/models/employee_model.dart` (`useZoom`), `core/models/{user,admin}_employee_datasource.dart` (one-click Zoom toggle icon).
- `features/user_management/screens/user_management_screen.dart` — `_toggleZoom` + `_pickZoomHost` dialog (admin picks `support@`/`billing@`/custom host when enabling).
- `features/no_show/` **(new)** — `models/no_show_report.dart`, `services/no_show_service.dart` (fetch + `markReviewed` direct admin update + `computeTeacherPatterns`), `screens/no_show_alerts_screen.dart`.
- `features/dashboard/screens/dashboard.dart` — `case 32: NoShowAlertsScreen`. `config/sidebar_config.dart` — admin Operations "No-Show Alerts" (screenIndex 32).
- `l10n/app_{en,fr,ar}.arb` + regenerated `app_localizations*.dart`.
- `pubspec.yaml` — `flutter_zoom_meeting_wrapper`.
- `test/features/no_show/no_show_service_test.dart` **(new)** — passing.
- `docs/zoom-classroom-pilot.md` — setup runbook. `docs/zoom-and-noshow-handoff.md` — this file.

**Architecture note:** No-Show reuses its *own* small widgets (not audit's) because cross-feature imports are CI-banned (CLAUDE.md rule 5).

---

## 3. Live infra state (already done in the Zoom console + Firebase)

- **2 licensed Zoom hosts (same account, `us04` cluster), both active + ZAK verified:**
  - `support@alluwaleducationhub.org` → **Mama S Diallo** (uid `KTEcG1j2qocbLphNr1MisQSCKOS2`)
  - `billing@alluwaleducationhub.org` → **habibu barry** (uid `kjVbNRUjJoZRw3NTd3jIbREdYUu2`)
- **Zoom apps (activated):** a **General App** with Meeting SDK enabled (SDK key/secret) + a **Server-to-Server OAuth** app "Alluwal Classroom Backend". Scopes granted: `meeting:write:admin`, `meeting:read:admin`, `meeting:delete:meeting:admin`, `user:read:user:admin`, `user:read:token:admin`, `user:read:zak:admin`, `meeting:read:participant:admin`.
- **Webhook:** app-level secret token; **two** event subscriptions (both validated) → `https://us-central1-alluwal-academy.cloudfunctions.net/zoomWebhook` and `.../alluwal-dev.cloudfunctions.net/zoomWebhook`; events `meeting.participant_joined/left`, `meeting.ended`.
- **Firebase secrets (6) set in BOTH projects:** `ZOOM_SDK_KEY`, `ZOOM_SDK_SECRET`, `ZOOM_S2S_ACCOUNT_ID`, `ZOOM_S2S_CLIENT_ID`, `ZOOM_S2S_CLIENT_SECRET`, `ZOOM_WEBHOOK_SECRET_TOKEN`.
- **Functions deployed to BOTH `alluwal-dev` and `alluwal-academy`:** `getZoomJoinInfo`, `setTeacherZoomEnabled`, `zoomWebhook`, and the updated `getRealtimeKitRoomPresence`.
- **Firestore rules:** `no_show_reports` already allows admin read+update (`firestore.rules:622`) — no rules change needed.

### ⚠️ Gotchas
- **Firebase CLI must be logged in as `nenenane2@gmail.com`** (owner of both hyphenated projects). `hassimiou.niane@maine.edu` cannot see them. Use `firebase login:use nenenane2@gmail.com`.
- Firestore reads/writes from CLI: use `gcloud auth print-access-token` against the **Firestore REST API** (firebase-admin ADC gets PERMISSION_DENIED). Hyphenated field paths like `e-mail` must be backtick-escaped in structuredQuery.
- **Webhook secret token was pasted into a chat transcript** — consider regenerating it and re-syncing both projects' `ZOOM_WEBHOOK_SECRET_TOKEN`.
- Transient plaintext creds file: `/private/tmp/alluwal-zoom-secrets.env` (chmod 600). **Delete when fully done.**

---

## 4. What's verified (proven working on a REAL test class, prod, via a local build)
- Teacher joined Zoom **as host** on `billing@` — camera + full host controls (Share, Host tools, End).
- Webhook wrote presence to `livekit_sessions` with the **correct user identity** (mapped via `customerKey`), role, and join **and** leave windows. Both a teacher and a participant were tracked simultaneously.
- ZAK works for **both** host accounts. Meeting create → sign → delete round-trips all green.
- Live roster backend now returns the Zoom roster (auto-refresh 10–15s in the existing UI).

---

## 5. NOT done yet / pending (the important part)

1. **Ship the Flutter client build.** ALL client code is **uncommitted in the working tree** and only running in a local `flutter run`. Nothing is on Hostinger / in the mobile apps. Web release: `./increment_version.sh && flutter build web --release --pwa-strategy=none` → upload `build/web/` to Hostinger. The working tree also has unrelated in-progress changes — **isolate the Zoom + No-Show work on a clean branch before building** (user chose "hold the web build" specifically to avoid shipping everything).
2. **Flip the two pilot teachers' real shifts to Zoom.** Mama & habibu have `use_zoom=true` + `zoom_host_account`, but their existing `teaching_shifts` are still `realtimekit` (intentionally held). Flip them **at client-ship time** to avoid split rooms (some users on new build → Zoom, stale users → RealtimeKit for the same class). Use `setTeacherZoomEnabled` (re-toggle) or a direct `video_provider` update on upcoming teaching shifts.
3. **Student capabilities ("everyone can do everything").** Meeting settings are permissive in code, but **participant screen-share is an account-level Zoom setting** we can't set via API. In Zoom web: Settings → Meeting → In Meeting (Basic) → Screen sharing **Who can share = All Participants**, plus Annotation / Whiteboard / Chat / Reactions ON.
4. **Mobile native path.** `flutter_zoom_meeting_wrapper` is wired, but the native Zoom Meeting SDK **binaries must be downloaded and placed** (Android `libs/`, iOS `Frameworks/`) per `docs/zoom-classroom-pilot.md`, then tested on a device. `io` currently needs those binaries to build.
5. **Cleanup test artifacts:** delete test shift `ZOOM_TEST_BILLING_1783013737`; delete leftover Zoom meeting(s) created during testing (e.g. `89301705903` on `billing@`); delete `/private/tmp/alluwal-zoom-secrets.env`. (The admin account `7akU2aXPhshMPd5nrmrnqUqzvGH3` was already reverted — its temp `zoom_host_account` removed.)
6. **Optional UX:** the Zoom Client View takes over full-screen and confused the tester — consider an explicit "Leave class" button in `ZoomMeetingScreen`.

---

## 6. Recommended next steps (order)
1. Zoom account "Who can share = All Participants" toggle (#3) — quick, unblocks student sharing.
2. Isolate Zoom + No-Show changes on a clean branch → PR → review (respect CLAUDE.md: small PRs, tests green).
3. Ship the **web** build to Hostinger.
4. Flip Mama + habibu upcoming shifts to `zoom`.
5. Run a real pilot class; confirm audio quality (the original problem) + presence roster.
6. Mobile native SDK spike + on-device test.
7. Clean up test artifacts + rotate the webhook secret token.

## 7. Pilot sizing context (for decisions)
Whole-school schedule peaks at **14 concurrent classes** (daily ~2 PM ET). With 2 licensed hosts you can run **2 concurrent** Zoom classes — enough for the Mama + habibu pilot (they fit in 2). Per-class Zoom does **not** scale to the whole school on ≤5 licenses; that would need ~14 licenses or the (abandoned) hub+breakout model. Presence/attendance drives **admin absence notifications only** — pay comes from clock-in (`time_clock`), so participant-identity accuracy is a monitoring nicety, not payroll-critical.

## 8. Verification commands
- Functions tests: `cd functions && npm test` (or `npx jest tests/zoom_handler.test.js tests/zoom_signature.test.js`).
- Flutter: `flutter analyze lib/features/no_show/ lib/core/widgets/zoom_meeting_screen_io.dart`; `flutter test test/features/no_show/`.
- Deploy (dev first): `firebase deploy --only functions:getZoomJoinInfo,functions:zoomWebhook,functions:setTeacherZoomEnabled,functions:getRealtimeKitRoomPresence --project alluwal-dev` (repeat `--project alluwal-academy`).
- Live presence check (who's in a class): query `livekit_sessions where shift_id == <id>`; a participant is "currently in" if their last `presence_windows` entry has `leave_at == null`.
