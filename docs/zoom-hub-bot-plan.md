# Zoom Hub Routing — VPS Controller Bot Implementation Plan

**Status:** approved design, ready to implement.
**Written:** 2026-07-03. Implementing agent: read this whole file before touching code.
**Reviewer:** a separate agent/session will check the work against the acceptance protocol at the end.

---

## 1. Product invariants (the result the owner wants — every one is testable)

1. Only **2 licensed Zoom accounts** exist (`billing@alluwaleducationhub.org`, `support@alluwaleducationhub.org`). All concurrent classes (peak ≈ 14) share them.
2. A **teacher clicks Join and lands directly in their own private classroom** with only their students. They never see breakout-room UI, the hub, or other classes. No teacher action is ever required for routing.
3. **Two teachers must never be in the same room.** Classes are fully isolated from each other.
4. A **parent of a student in a class** and any **admin** can click Join on that class and land in that same room.
5. **Nobody ever sees the hub main session.** If routing is not confirmed, they see the black "Connecting to class…" layer — which must also **re-appear** if they ever land back in the main session.
6. **Nobody can end anyone else's class.** No human ever holds Zoom host/co-host power. The custom red Leave button only removes that person. **The current button layout/styling and control-suppression behavior in `web/zoom_meeting.html` must not change** (leave button, hidden native Leave/End controls, allowed media/More/whiteboard controls).

## 2. Verified platform constraints (do not re-litigate; verified against `zoom/meetingsdk-web` typings for the pinned 6.2.0 client view)

- `getBreakoutRooms`, `assignUserToBreakoutRoom`, `moveUserToBreakoutRoom`, `createBreakoutRoom`, `openBreakoutRooms`, `closeBreakoutRooms` — **host/co-host only**.
- `getCurrentBreakoutRoom`, `getUserStatus`, `getBreakoutRoomStatus`, `getAttendeeslist` — callable by **any participant**.
- The only breakout event is **`onRoomStatusChange`** (`{status: 2|3|4}` = InProgress/Closing/Closed). `onBreakoutRoomChange` **does not exist** — the current listener never fires; remove it.
- `createBreakoutRoom` returns `INVALID_OPERATION` **once rooms have been opened**. All rooms a hub will ever need must be created **before** `openBreakoutRooms`. Room renames/deletes are also blocked while open.
- Max **50 breakout rooms** per meeting (100 only with big-rooms add-on). Max meeting duration **30 h**.
- `openBreakoutRooms` options we require: `isAutoJoinRoom: true` (assigned users get pulled in with no click) and **`isBackToMainSessionEnabled: false`** (participants cannot return to the hub; this replaces a CSS-only defense with a Zoom-enforced one).
- `assignUserToBreakoutRoom` is for users in the **main session (unassigned)**; `moveUserToBreakoutRoom` is for users **already inside some room**. `userId` is the numeric in-meeting id from `getAttendeeslist` / `getBreakoutRooms`, not our uid; the bridge is `customerKey` (we pass Firebase uid as `customerKey` at join).
- REST breakout pre-assignment (`breakout_room` meeting settings) does **not** work for web-SDK guests. Ignore it for routing (keep `enable: true` so the feature is on).

## 3. Architecture

```
Firestore (teaching_shifts, hub_meetings)
        ▲  ▼
Cloud Functions (getZoomJoinInfo, zoomHubBot* endpoints, prepareZoomHubs scheduler)
        ▲  ▼                                   ▲
Flutter app ── zoom_meeting.html (role 0,      │ HTTPS + bot secret
   everyone: teacher/student/parent/admin)     ▼
                                    VPS: 2 × headless Chromium bots
                                    (one per licensed account = "lane")
                                    join hub as HOST, pre-create rooms,
                                    open once, route people all block long
```

- **Lane** = one licensed account. Lane assignment: unchanged hash of `teacher_id` (`_hubMetaForShift`).
- **Block** = time slice of a lane's day. One hub meeting per `(day, block, lane)`. Hub doc id: `zoom_hub_<dayKey>_<blockIndex>_<lane>`.
- **Bot** = headless Chromium page joining as host (role 1 + ZAK). The bot **never enters a breakout room**; it stays in the main session forever and only routes. No human ever gets role 1.

## 4. Phase 0 — verification spikes (blocking gates; do these first, ~half a day)

Run a throwaway meeting on one licensed account with 2–3 browser participants:

- **G1:** Confirm `getAttendeeslist` and `getBreakoutRooms().unassigned` items expose the `customerKey` passed at join. Log raw payloads. If absent, STOP and escalate — the fallback (matching by display name) must be explicitly approved.
- **G2:** Confirm `assignUserToBreakoutRoom` on a main-session participant with `isAutoJoinRoom: true` pulls them in with **no prompt**, and `moveUserToBreakoutRoom` relocates an in-room participant.
- **G3:** Confirm participant-side `getCurrentBreakoutRoom` returns the room name once inside, while `getBreakoutRooms` correctly errors for role-0 users.
- **G4:** Confirm behavior with `isBackToMainSessionEnabled: false`: participant's only exit is leaving the meeting.
- **G5:** Zoom account check via REST (`GET /users/{id}` plan type): determine whether the licensed users may host **2 concurrent meetings** (Business/Education) or only 1 (Pro). This decides block-boundary strictness (§5.2).
- **G6:** Host disconnect test: kill the host tab while rooms are open with participants inside. Record what Zoom does (rooms stay open? host auto-reassigned?). The bot's rejoin logic (§6) must be validated against the observed behavior.

Record all findings in `docs/zoom-hub-bot-plan.md` (append a "Phase 0 results" section).

## 5. Phase 1 — backend (`functions/`)

### 5.1 Remove the teacher-controller machinery
In `functions/handlers/zoom.js`:
- Delete `_claimZoomHubController`, `_hubControllerValidUntil`, lease/heartbeat constants, and controller fields on hub docs.
- In `getZoomJoinInfo`: `sdkRole` is **always 0**. Never return `zak`. `hubController`/`autoOpenBreakoutRooms` are always false (keep keys for client compat during rollout, hardcoded false). Drop the role-1 `participantSignature` dance (participant signature == signature).
- Delete dead `_findStartedZoomHostConflict` or wire it back for single-mode only. Add validation in `setTeacherZoomEnabled`: reject `zoom_host_account` ∈ classroom host accounts (billing@/support@) for single-mode teachers — those two licenses belong to the hubs now.

### 5.2 Blocks
- New helper `_blockForShift(shiftData)` → `{blockIndex, blockStart, blockEnd}` from a config doc `system_settings/zoom_hub_blocks` (fallback env `ZOOM_HUB_BLOCK_BOUNDARIES`, default boundaries `05:00,12:00,17:00` in `America/New_York`). A shift belongs to the block containing its **start** time.
- A hub's Zoom meeting window = `firstShiftStart − 15 min` → `lastShiftEnd + 15 min` (computed from the shifts assigned to it), so a class that crosses a boundary stays in its start block and the hub simply stays open until it ends.
- If G5 says **Pro (1 concurrent meeting/user)**: adjacent hubs on the same lane may not overlap → the scheduler must verify `prevHub.lastEnd + 15 < nextHub.firstStart − 15`; when violated, merge the two blocks for that day/lane (log a warning). If **Business (2 concurrent)**: overlap is fine, bots run both briefly.
- **Room cap guard:** a hub gets rooms for its shifts **plus 5 spare rooms** (`Spare 1`…`Spare 5`, see §5.4). If total would exceed **48**, spill the overflow shifts to the other lane's same-block hub; if both are full, alert admins (reuse the no-show admin email path) and fall back to `single` mode for the overflow class.

### 5.3 Hub preparation ahead of time (bots need rooms BEFORE anyone joins)
- New scheduled function `prepareZoomHubs` (Cloud Scheduler, every 10 min, both projects): scan `teaching_shifts` with `video_provider == 'zoom'` and hub routing enabled starting in the next 60 min; for each `(day, block, lane)`: create the Zoom meeting if missing (reuse the existing transactional create in `ensureZoomHubMeeting`), compute the **full room list for the entire block** (all shifts in that block, not just ones someone tried to join), write the hub doc.
- `ensureZoomHubMeeting` stays as the lazy fallback for joins that beat the scheduler but must also seed the **whole block's** rooms, not just the joining shift's room.

### 5.4 Ad-hoc shifts created after the hub opened
- Rooms can't be added after open. If a shift is created/moved into an already-`open` hub: assign it one of the 5 pre-created **spare rooms** (first unused, tracked on the hub doc: `spares: {"Spare 1": shiftId|null, ...}`) and store that spare name as the shift's `breakoutRoomName`. Room display name is cosmetic (breakout UI is suppressed client-side). If spares are exhausted → `single` mode fallback + admin alert.

### 5.5 Fix the visitor race
- Replace read-modify-write of `hub_meetings/{id}.rooms[].visitorIds` with per-member docs: `hub_meetings/{hubId}/members/{uid}` = `{shiftId, role: teacher|student|parent|admin, displayName, addedAt}`. `getZoomJoinInfo` writes the caller's member doc (idempotent `set`). The parent/admin-as-visitor semantics from the current local changes are kept.
- Assignment reads (bot) join `rooms` (shift→room name) with `members` (uid→shiftId).

### 5.6 Bot endpoints (new file `functions/handlers/zoom_hub_bot.js`, export via `functions/index.js`)
All `onRequest`, authenticated by header `x-bot-key` == Secret Manager secret `ZOOM_HUB_BOT_KEY` (constant-time compare). No user tokens.
- `GET zoomHubBotDirectives?lane=1|2` → hubs the lane's bot should be in *now* (window active): `[{hubDocId, meetingNumber, password, hostAccount, sdkKey, signatureRole1, zak, rooms: [names…], windowStart, windowEnd}]`. ZAK fetched server-side per request (ZAKs expire; bot re-fetches on join failure).
- `GET zoomHubBotAssignments?hubDocId=…` → `{rooms: [{shiftId, name}], members: [{uid, shiftId}]}`.
- `POST zoomHubBotState` → bot writes `{hubDocId, status: joined|roomsOpen|error, boIdByRoomName, heartbeatAt, stats}` onto the hub doc.
- Repurpose/retire the current public `zoomHubAssignments`: participants no longer need it (fixes the roster-disclosure issue). Remove `assignmentToken` from the join payload and from `zoom_meeting.html` / `zoom_meeting_screen_web.dart` / `class_video_service.dart`.
- New scheduled `watchZoomHubBots` (every 5 min): any hub inside its window with `status != roomsOpen` or heartbeat older than 2 min → admin alert email/push (reuse no-show notification plumbing).

### 5.7 Config
- `functions/.env` / secrets: `ZOOM_HUB_BOT_KEY`. Existing S2S creds unchanged. Never hardcode the functions URL in client pages with a project id — pass it as a parameter (the current hardcoded prod URL in `zoom_meeting.html` goes away with `refreshHubAssignments`).

## 6. Phase 2 — the VPS bot (new top-level dir `services/zoom-hub-bot/`; document the new dir in AGENTS.md §2 in the same PR)

Node 20 + Playwright (bundled Chromium), two systemd units (`zoom-hub-bot@1`, `zoom-hub-bot@2` — one per lane).

- **`bot.js` loop (per lane):** every 30 s call `zoomHubBotDirectives`. For each active hub not already handled: open a Chromium page at `bot_controller.html` (served from the same VPS via `file://` or localhost static server — it is NOT deployed to Hostinger web root).
- **`bot_controller.html`** (lives in `services/zoom-hub-bot/`, not `web/`): minimal page, Zoom client-view SDK 6.2.0 (same pinned CDN), joins with role-1 signature + ZAK, then:
  1. `getBreakoutRooms()`; create all missing rooms **in one** `createBreakoutRoom({data: allNames, pattern: 2})` call. If it returns `INVALID_OPERATION` (already open — e.g. bot restarted), skip creation.
  2. `openBreakoutRooms({options: {isAutoJoinRoom: true, isBackToMainSessionEnabled: false, isTimerEnabled: false, needCountDown: false}})` (skip if status already InProgress via `getBreakoutRoomStatus`).
  3. `POST zoomHubBotState` with the `name→boId` map.
  4. **Routing loop forever (every 3 s)** — this replaces the current 3-minute `moveAssignedParticipants`:
     - refresh assignments (uid→room name via members+rooms),
     - `getBreakoutRooms()` for `unassigned` + per-room participants, `getAttendeeslist()` for main-session users,
     - for each user whose `customerKey` has a target room: `assignUserToBreakoutRoom` if unassigned/main-session, `moveUserToBreakoutRoom` if sitting in the wrong room. **Never move a user who is already in their correct room.** Users with no mapping stay in the main session (their client shows the black layer).
     - heartbeat via `zoomHubBotState`.
  5. At `windowEnd`: leave; backend `endMeeting` via REST cleans up.
- **Crash/restart:** systemd `Restart=always`. On rejoin, same Zoom user replaces its own ghost session; steps 1–2 are idempotent per the guards above. Validate against G6 findings.
- **Media hygiene:** bot joins with camera/mic off, never joins audio; renders at 640×480 to keep CPU low.
- **Host machine (PROVISIONED 2026-07-03):** Hostinger VPS, Ubuntu 24.04 LTS, 1 vCPU / 4 GB RAM / 48 GB disk. Keep host/IP/SSH details in the ops vault or local deploy environment, not in source control. ⚠️ Single core: during acceptance testing, monitor CPU with both bots in live meetings; if saturated, resize to KVM 2 in hPanel (no reinstall) before go-live. Do NOT install anything else on this box.
- Unit-test the pure routing diff (`whoNeedsToMoveWhere(assignments, zoomState)`) with Jest inside `services/zoom-hub-bot/`.

## 7. Phase 3 — participant page (`web/zoom_meeting.html`)

**Do not touch:** the leave button markup/CSS, `suppressBreakoutManagementUi`, `blockBreakoutManagementEvent`, `hideControlsUnderLeaveButton`, media/utility allow-lists, the session-claim (BroadcastChannel) logic. (Invariant 6.)

Changes:
- Remove all host-side branches: `autoOpenBreakoutRooms`, ZAK handling, `reloadAsParticipantFallback`, `createBreakoutRoom`/`openBreakoutRooms`/`moveAssignedParticipants`, `refreshHubAssignments`, `assignmentToken`. Everyone is role 0.
- Replace the nonexistent `onBreakoutRoomChange` listener with `onRoomStatusChange`; on status 3/4 (Closing/Closed) **re-arm** `setPrivateRoutingPending(true)` immediately.
- Arrival detection = poll `getCurrentBreakoutRoom` (+ `getUserStatus` for `InRoom`) every 1–2 s; clear the layer only when the current room name matches `breakoutRoomName` (normalized, same helper as now). Keep the DOM render monitor as a fallback only. **Also keep polling after arrival (every ~5 s):** if the user is ever detected outside their room again, re-arm the layer.
- Remove the participant `getBreakoutRooms` loop entirely (host-only API; it is why Ibrahim saw "neither host nor cohost").
- Waiting UX: black layer stays indefinitely; at 60 s swap to a "still connecting" localized message; at 3 min show a localized "ask your administrator / leave and rejoin" message **behind the layer** with the Leave button still available. No hardcoded English — all strings arrive via URL params like the existing `connectingText` (new ARB keys in `lib/l10n/app_en.arb`/`app_fr.arb`/`app_ar.arb`, then `flutter gen-l10n`, passed through `lib/core/widgets/zoom_meeting_screen_web.dart`).

## 8. Phase 4 — Flutter plumbing

- `lib/core/services/class_video_service.dart` + `lib/core/widgets/zoom_meeting_screen_web.dart` (`_io.dart` too): drop `assignmentToken`, `zak`, `participantSignature`, `hubBreakoutRooms` params; add the new localized status strings. No visual/UI changes anywhere else.
- `flutter test` + update `functions/tests/zoom_handler.test.js`, `zoom_meeting_html.test.js` (assert: no `onBreakoutRoomChange`, `isBackToMainSessionEnabled: false` appears only in bot page, role always 0 in join payload, spare-room allocation, block assignment, member-doc writes, bot endpoint auth 401 without key).

## 9. Rollout & PR breakdown (repo rules: small PRs, issue first)

1. **Issue:** open a GitHub issue describing this migration (multi-agent protocol §6 of AGENTS.md).
2. **PR 1:** backend — blocks, `prepareZoomHubs`, member docs, bot endpoints, role-0-always, tests. Deploy to `alluwal-dev` first (`npm run deploy:dev`).
3. **PR 2:** `services/zoom-hub-bot/` + AGENTS.md dir-table update + VPS setup doc.
4. **PR 3:** web page + Flutter params + l10n (run `flutter gen-l10n`; deploy web only via `./build_release.sh` → `./scripts/deploy_hostinger_web.sh`).
5. **Pilot:** enable hub routing for the existing 2 pilot teachers' shifts only (`zoomRoutingMode: 'hub'` on their shifts; everyone else stays as-is), run the acceptance protocol below off-hours, then widen.
6. Keep the per-class escape hatch `zoom_disable_hub_routing: true` working at every step.

## 10. Acceptance protocol (the reviewing agent must see evidence of each)

Set up one hub with two test shifts (Teacher A + Student A1; Teacher B + Student B1) in the same lane/block, plus a parent of A1 and one admin.

| # | Test | Pass condition |
|---|------|----------------|
| 1 | Teacher A joins before bot opened rooms | Black layer until routed; lands in Room A; no breakout UI ever visible |
| 2 | Teacher B joins 5 min later | Lands in Room B; at no point can A see/hear B or vice versa (check participant lists in both rooms) |
| 3 | Student A1 joins 20 min after class start | Routed to Room A (proves routing loop outlives 3 min) |
| 4 | Parent of A1 joins | Lands in Room A |
| 5 | Admin joins class B | Lands in Room B |
| 6 | Kill the bot process mid-class, restart after 60 s | Existing rooms/participants undisturbed; a NEW joiner during the outage waits on the black layer, then gets routed after restart; admin alert fired |
| 7 | Devtools check on any participant | `getBreakoutRooms` errors (role 0); no End-Meeting capability exists in their session |
| 8 | Press the red Leave button in Room A | Only that user leaves; Room A continues; hub continues |
| 9 | Simulate rooms closing (bot `closeBreakoutRooms` manually) | Every participant page re-arms the black layer instantly; nobody sees the hub |
| 10 | Ad-hoc shift created after rooms opened | Gets a Spare room and routes correctly |
| 11 | Visual diff of the in-class UI vs before | Leave button + suppressed controls byte-identical behavior (Invariant 6) |

## 11. Known pitfall found during implementation (2026-07-03, reviewer diagnosis — read before debugging routing)

Symptom: host assign/move "succeeds", Zoom shows participant as assigned, but web participants never leave the main session; participant `joinBreakoutRoom` errors "room id is not correct".

Root causes (both must be fixed):
1. **Breakout options freeze at the FIRST `openBreakoutRooms` and cannot change while open.** A hub reused across test runs keeps whatever options the very first open used (likely `isAutoJoinRoom: false`, `needCountDown: true` → invitation mode: assigned web users get a "Join Breakout Room" dialog instead of being pulled). The bot MUST verify `getBreakoutRoomOptions()` after joining; on mismatch (and only when safe — block start/empty rooms/test), `closeBreakoutRooms` → recreate → reopen with the §6 options. Also fix `ensureRoomsOpen`: an `INVALID_OPERATION` from `createBreakoutRoom` must NOT skip the open step (rooms can exist yet be unopened).
2. **The participant page's dialog suppression eats the breakout invitation.** `isBreakoutManagementDialog` matches "Breakout Room" + "Join" — i.e. the invite dialog — and the guard hides it and blocks its clicks, while the black layer sets `pointer-events: none`. Change the guard: while `privateRoutingPending`, dialogs matching /join breakout room|has invited you/i are **auto-accepted** (programmatically click their Join/Yes button; the black layer keeps the user from seeing any of it). Management controls (Leave Room, Close All Rooms, …) stay suppressed as before.
3. Participant `joinBreakoutRoom` only works once the client holds the room token (`getUserStatus` = Invited). If used as fallback, take the roomId from the participant's own `getCurrentBreakoutRoom`, never from the bot-published boId map.
4. Numeric in-meeting `userId`s change on every participant reload — the bot must re-resolve userId via `customerKey` at assign time, never cache it.

Debug instrumentation (participant console, every 2 s): `getBreakoutRoomStatus` + `getUserStatus` + `getCurrentBreakoutRoom`. Initial→assign never landed (stale userId); Invited→invitation mode (fixes 1/2); InRoom but black screen→arrival-detection name mismatch.

## 12. Explicit out-of-scope

- No changes to timesheets/attendance logic (presence ≠ pay per existing design).
- No RealtimeKit/LiveKit changes.
- No redesign of any Flutter screens or the meeting page's visible controls.

## 12. Implementation Notes — 2026-07-03

- VPS details from §6 were used for the service packaging and systemd layout.
- Added the VPS-only bot service under `services/zoom-hub-bot/`.
- Backend/unit coverage now verifies role-0 join payloads, block hub room preparation, spare rooms, member-doc writes, bot endpoint auth, and bot-only role-1/ZAK access.
- Public `web/zoom_meeting.html` tests now verify that participant pages do not expose `zoomHubAssignments` or host-only breakout APIs.
- Room-cap handling now spills an overflowing class to the other licensed lane when possible. If both lanes are full, the class falls back to single Zoom mode when the teacher has a non-hub Zoom host account, and admins receive a critical Zoom hub alert.
- `watchZoomHubBots` and hub overflow/fallback paths write `system_alerts` and send best-effort admin email/push notifications using the same admin-recipient pattern as no-show reporting.
- The bot `left` state now asks the backend to end the hub Zoom meeting by REST after the hub window ends.
- Participant routing now checks `getCurrentBreakoutRoom` and `getUserStatus` before clearing the black routing layer.
- The VPS bot controller disables audio/video support and join-audio controls for media hygiene.
- Open hubs now treat the already-created breakout rooms as immutable. A late-added same-block class is assigned to the first unused spare room and persisted back to its shift; if all spare rooms are consumed, it falls back to single Zoom mode and alerts admins.
- Deployed 2026-07-03: Zoom functions were deployed to `alluwal-dev` and `alluwal-academy` (`getZoomJoinInfo`, `setTeacherZoomEnabled`, `zoomWebhook`, `prepareZoomHubs`, `watchZoomHubBots`, `zoomHubBotDirectives`, `zoomHubBotAssignments`, `zoomHubBotState`).
- Deployed 2026-07-03: Hostinger web build `v129` was built through `./build_release.sh` via `./scripts/deploy_hostinger_web.sh` and verified on `https://alluwaleducationhub.org/`.
- VPS status 2026-07-03: Node 20, Playwright Chromium, bot code, and systemd units are installed on the provisioned Hostinger VPS; `zoom-hub-bot@1` and `zoom-hub-bot@2` are enabled and running. Production bot endpoint smoke check returned `success: true` with zero active directives; unauthenticated access returns `401`.
- Production scheduler jobs are enabled: `firebase-schedule-prepareZoomHubs-us-central1` (`every 10 minutes`) and `firebase-schedule-watchZoomHubBots-us-central1` (`every 5 minutes`).
- Phase 0 live gates are partially complete in production. Remaining broad gate: run the full 20-class acceptance load only in an isolated no-real-hub window or a dev/local-bot window.

## 13. Phase 0 Live Results — 2026-07-04

- Zoom's current support article "Understanding time limits for Zoom Meetings" still documents the licensed-user meeting lifetime as 30 hours. The hub implementation keeps shared hub windows below that with `ZOOM_HUB_SAFE_MAX_MEETING_MINUTES = 28 * 60` and falls back to single Zoom when a hub window would exceed that safe lifetime.
- Focused tests passed locally after the safety fixes:
  - `cd functions && npx jest tests/zoom_handler.test.js tests/zoom_signature.test.js tests/zoom_meeting_html.test.js --runInBand` — 46 passed.
  - `cd functions && npx jest tests/shift_templates_recurrence.test.js --runInBand` — 8 passed.
  - `cd functions && npx jest tests/attendance_reports.test.js tests/no_show_reporting.test.js tests/realtimekit_access.test.js --runInBand` — 38 passed.
  - `cd services/zoom-hub-bot && npm test` — 13 passed.
  - `flutter test test/features/no_show/no_show_service_test.dart` — 8 passed.
- Production deploy completed on 2026-07-04 for the Zoom join/watch functions (`getZoomJoinInfo`, `setTeacherZoomEnabled`, `prepareZoomHubs`, `watchZoomHubBots`, `zoomWebhook`) and bot endpoints (`zoomHubBotDirectives`, `zoomHubBotAssignments`, `zoomHubBotState`). `gcloud functions describe --gen2` showed all deployed functions `ACTIVE`.
- VPS bot code was rsynced to `/opt/alluwal/zoom-hub-bot`, remote Jest passed, and both `zoom-hub-bot@1` / `zoom-hub-bot@2` restarted active.
- Live production spare-room smoke:
  - Created one temporary teacher/student/shift in active lane 2.
  - `getZoomJoinInfo` returned `routingMode: hub`, `hubMeetingId: zoom_hub_2026-07-03_3_2`, `breakoutRoomName: Spare 1`, `autoJoinBreakoutRoom: true`.
  - First browser run joined the hub but stayed in the main session; root cause was that Zoom's host-side payload can show the participant name before reliably exposing the custom key.
  - Fixed routing to use `customerKey` first and exact display-name fallback only when the display name maps to one room; duplicate display names are intentionally ignored unless Zoom provides the UID/custom key.
  - Second browser run passed: the temp teacher was routed into `Spare 1`; bot stats showed `targetMemberCount: 1`, `routedCount: 1`.
  - Cleanup verified zero temp users, shifts, rooms, and members remained.
- Focused two-class production acceptance slice in active lane 2:
  - Created temporary Teacher A / Student A / Parent A and Teacher B / Admin B.
  - Join info assigned Teacher A, Student A, and Parent A to `Spare 1`; Teacher B and Admin B to `Spare 2`.
  - Browser run passed 5/5: every participant landed in the expected spare room, role-0 `getBreakoutRooms` was blocked, breakout-management UI was not visible, and native leave/end room controls were not visible.
  - Cleanup verified zero temp users, shifts, hub rooms, and hub members remained.
- Lane-2 bot restart production gate:
  - Routed a temporary teacher into `Spare 1`.
  - Stopped only `zoom-hub-bot@2`; a temporary student joined during the outage and remained on the black `Connecting To Class` layer in the main session.
  - Existing teacher stayed in `Spare 1` during the outage.
  - Restarted `zoom-hub-bot@2`; both teacher and student were routed/confirmed in `Spare 1`.
  - Cleanup verified zero temp users, shifts, hub rooms, and hub members remained, and `zoom-hub-bot@2` ended active.
- Added focused unit coverage for `watchZoomHubBots`: a stale live hub heartbeat writes a critical `system_alerts` doc and sends admin email/push notifications.
- Hardened `functions/dev-scripts/live-zoom-hub-acceptance.js`:
  - Default browser batch size is now 2 to avoid local RAM pressure.
  - Supports `FIREBASE_PROJECT=alluwal-dev` by reading `lib/firebase_options_dev.dart` and also supports `FIREBASE_WEB_API_KEY`.
  - Supports `--force-lane-index=0|1` so full dev/local-bot acceptance can target a known lane without touching an active production lane.
  - Refuses full production acceptance while active hubs exist unless `--allow-active-hubs` is explicitly passed.
- Full 20-class dev/local-bot acceptance:
  - Ran against `alluwal-dev` with local lane-1 bot and `--classes=20 --batch-size=2 --force-lane-index=0`.
  - Run `codex_1783138473292` created/opened 25 rooms (20 class rooms + 5 spares).
  - Browser acceptance passed 45/45 attempted participants with 0 failures, covering every teacher/student, parent class 1, admin class 1, duplicate rejoin, and student drop/rejoin.
  - Cleanup verified zero temp users, shifts, hub rooms, hub members, and active dev hubs remained.
- Parent/admin dashboard click verification:
  - Ran local Flutter profile web bundle against `alluwal-dev` with fixture `codex_ui_1783138984`.
  - Parent dashboard showed the linked child class, enabled `Join Class`, redirected to `zoom_meeting.html`, and routed the parent into the target class breakout room.
  - Admin dashboard Classes page showed the classroom, enabled `Join`, redirected to `zoom_meeting.html`, and resolved `getCurrentBreakoutRoom` to the target class room. `getUserStatus` briefly lagged at `joining`, but routing was not pending and bot assignments showed the admin in the target room.
  - Cleanup verified zero temp users, shifts, hub rooms, hub members, and active dev hubs remained.
- Admin-created recurring/template shifts:
  - Browser-tested the admin Shifts → Create Shift dialog against `alluwal-dev` with fixture `codex_admin_shift_1783140362210`.
  - Created a weekly teaching class from the dashboard. The base shift, shift template, and generated future weekly shifts all had `video_provider: zoom`.
  - Moved one generated fixture shift into the join window and called deployed dev `getZoomJoinInfo`; it returned `provider: zoom`, `routingMode: hub`, a target breakout room, `autoJoinBreakoutRoom: true`, and a meeting number.
  - Cleanup verified zero temp users, shifts, templates, subjects, hub rooms, hub members, and active dev hubs remained.
- No-show and live roster verification:
  - Added backend scheduled `detectClassAttendanceNoShows` so no-show detection no longer depends on the old LiveKit meeting client prompt. The detector scans recent teaching shifts after a 5-minute grace period, reads `livekit_sessions`, and writes `class_attendance_alerts/{shiftId}` with `missing: teacher|students|both`.
  - Added Firestore rules for admin read/update/delete on `class_attendance_alerts`.
  - Dev smoke `codex_noshow_1783141040101`: two Zoom shifts scanned; the no-presence shift wrote one pending `missing: both` alert, the teacher/student-present shift wrote no alert, and cleanup left zero docs.
  - Dev roster smoke `codex_presence_1783141080334`: deployed dev `getRealtimeKitRoomPresence` returned 3 current Zoom participants with names from `livekit_sessions`; cleanup left zero docs. This exposed that the deployed dev function was older than source for admin role labels.
  - Dev deploy completed 2026-07-04 for Firestore rules/indexes plus `detectClassAttendanceNoShows` and `getRealtimeKitRoomPresence`. `gcloud functions describe --gen2` showed both functions `ACTIVE`, and Cloud Scheduler showed `firebase-schedule-detectClassAttendanceNoShows-us-central1` `ENABLED` every 5 minutes UTC.
  - Deployed dev smoke `codex_deploy_1783141668197`: `getRealtimeKitRoomPresence` returned 3 current Zoom participants with roles `teacher`, `student`, and `admin` when the admin Zoom session row had fallback role `participant`. A manual scheduler run wrote one pending `missing: both` alert for the no-presence fixture shift and wrote no alert for the present fixture shift. Cleanup verified zero fixture docs in `users`, `teaching_shifts`, `livekit_sessions`, and `class_attendance_alerts`.
  - Production deploy completed 2026-07-04 for Firestore rules/indexes plus `detectClassAttendanceNoShows` and `getRealtimeKitRoomPresence`. `gcloud functions describe --gen2` showed both functions `ACTIVE`, Cloud Scheduler showed `firebase-schedule-detectClassAttendanceNoShows-us-central1` `ENABLED` every 5 minutes UTC, and the parent `teaching_shifts.student_ids + shift_start` index was `READY`.
  - Production roster smoke `codex_prod_presence_1783141900214`: a temporary Zoom shift with open `livekit_sessions` returned 3 current participants with roles `teacher`, `student`, and `admin`; cleanup verified zero fixture docs in `users`, `teaching_shifts`, `livekit_sessions`, and `class_attendance_alerts`. The production no-show scheduler was not manually fired to avoid scanning and writing alerts for real recent production classes.
  - Hostinger web deploy completed 2026-07-04 through `./scripts/deploy_hostinger_web.sh`. The script ran `./build_release.sh`, bumped cache-busting to `v131`, uploaded `build/web/`, and verified the public site as build `v131`.
  - GitHub publish completed on branch `codex/zoom-hub-production-readiness`; draft PR: https://github.com/hahimniane/alluvial_academy/pull/24.
- Parent class history/index fix:
  - During parent dashboard testing, the current/joinable class rendered and joined successfully, but a dev console warning showed the parent history query needed a composite index on `teaching_shifts.student_ids` + `shift_start`.
  - Added that index to `firestore.indexes.json`; deploy Firestore indexes before/with the web release.
- A 20-class live production load was not run inside the current active real hubs because that would intentionally consume/exhaust the limited late-add spare rooms in live production meetings. Run that load only in an isolated off-hours block or dev/prod test window where no real hub is active.
