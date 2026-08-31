# Zoom Hub Routing — VPS Controller Bot Implementation Plan

**Status:** living production reference and handoff log.
**Written:** 2026-07-03. Maintained continuously during Zoom hub rollout.
**Reviewer:** each agent/session must check its work against the acceptance protocol before handoff.

**Agent rule:** any agent touching Zoom classrooms, hub routing, class presence/rosters, no-show attendance, `web/zoom_meeting.html`, `functions/handlers/zoom*.js`, `functions/handlers/realtimekit.js`, `lib/core/services/class_video_service.dart`, `lib/features/zoom/`, or `services/zoom-hub-bot/` must read this file before changing code. Before ending work, update this file with the exact changes made, tests run, deploys attempted/completed, live-class findings, and any remaining blockers. Keep entries dated so the next agent can resume without guessing.

**Guardrail rule:** hub-routed Zoom teaching shifts must not exceed
`ZOOM_HUB_MAX_CLASS_DURATION_MINUTES` (default 180). The old
`05:00/12:00/17:00` block boundaries are now soft planning hints, not class
cutoffs. Connected same-lane classes whose padded windows touch or overlap are
merged into one rolling hub segment so no class is split or moved mid-session.
Do not reintroduce a hard block-boundary guard without updating this document,
the Functions/Dart tests, and the owner-facing handoff notes.

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
- Capacity note, rechecked against current Zoom Support docs on 2026-07-08:
  Zoom documents up to **100 breakout rooms** per meeting, but without a Large
  Meeting add-on, participants are limited by the host meeting capacity. The
  current `billing@` and `support@` lanes are normal licensed/Pro-style hosts
  with **100 meeting participants** and no Large Meeting add-on returned by the
  Zoom user settings API. Production keeps the more conservative
  `ZOOM_HUB_MAX_ROOM_COUNT = 48` operational guard (43 class rooms + 5 spares)
  until a controlled SDK/bot test proves 100 rooms reliably works in this
  hub-routing model. Forecasting reserves 1 seat for the host bot, so the
  scheduled human cap is 99 per lane. Max meeting duration **30 h**.
- Pricing/account reference, checked on 2026-07-10 from the owner's Zoom
  billing portal screenshot: production is **Zoom Workplace Pro**, billed
  monthly at **$16.99/license/month** before applicable taxes. The checkout
  screenshot showed adding 1 new license to the existing 2 Pro licenses, for a
  next monthly bill of **$50.97** before taxes. Zoom's official pricing page
  lists Pro limits as **30 hours** and **100 participants per meeting**.
  Business is a higher tier and lists **300 participants**, but do not assume
  Business unless the billing portal/API says so. Do not infer production
  capacity from price alone: keep using the Zoom API/user-settings result for
  the actual host capacity. If `billing@`/`support@` return
  `meetingCapacity: 100` and no Large Meeting add-on, keep the hub seat cap at
  99 scheduled humans per lane. Sources: owner Zoom billing portal screenshot
  from 2026-07-10, `https://zoom.us/pricing`,
  `https://support.zoom.com/hc/en/article?id=zm_kb&sysparm_article=KB0068002`.
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
- **Soft block** = configured time slice of a lane's day, used only as an
  anchor for hub planning.
- **Rolling segment** = the actual hub unit. Same-lane classes are sorted by
  time; if one class's padded window (`start - 15 min` through `end + 15 min`)
  touches or overlaps the next, they share one hub meeting. Hub doc id:
  `zoom_hub_<dayKey>_<anchorBlockIndex>_<segmentStartHHmm>_<lane>`.
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
- Production guardrail, updated after the Billing Test stale-hub incident:
  normal admin-created hub classes are blocked if they exceed 180 minutes or
  have invalid times. Direct Firestore/script writes are quarantined by Cloud
  Functions with `zoom_hub_guardrail_blocked: true`,
  `zoomRoutingMode: blocked`, and a `system_alerts` record for owner review.
- Because production is Zoom Workplace Pro (1 concurrent meeting/user), adjacent
  same-lane hubs may not overlap. `_hubMetaForShift` now computes a rolling hub
  segment by scanning nearby same-lane Zoom teaching classes and merging any
  class whose padded window touches or overlaps the previous one. A 4:00-5:30
  PM class and 5:00 PM classes therefore share one hub instead of creating two
  overlapping meetings on the same licensed account.
- **Room cap guard:** a hub gets rooms for its shifts **plus 5 spare rooms** (`Spare 1`…`Spare 5`, see §5.4). If total would exceed **48**, spill the overflow shifts to the other lane's same rolling segment when possible; if both are full, alert admins (reuse the no-show admin email path) and fall back to `single` mode for the overflow class.

### 5.3 Hub preparation ahead of time (bots need rooms BEFORE anyone joins)
- New scheduled function `prepareZoomHubs` (Cloud Scheduler, every 10 min, both projects): scan `teaching_shifts` with `video_provider == 'zoom'` and hub routing enabled starting in the next 60 min; for each rolling `(day, segment, lane)`: create the Zoom meeting if missing (reuse the existing transactional create in `ensureZoomHubMeeting`), compute the **full room list for the entire rolling segment** (all connected shifts in that segment, not just ones someone tried to join), write the hub doc.
- `ensureZoomHubMeeting` stays as the lazy fallback for joins that beat the scheduler but must also seed the **whole rolling segment's** rooms, not just the joining shift's room.

### 5.4 Ad-hoc shifts created after the hub opened
- Rooms can't be added after open. If a shift is created/moved into an already-`open` rolling segment hub: assign it one of the 5 pre-created **spare rooms** (first unused, tracked on the hub doc: `spares: {"Spare 1": shiftId|null, ...}`) and store that spare name as the shift's `breakoutRoomName`. Room display name is cosmetic (breakout UI is suppressed client-side). If spares are exhausted → `single` mode fallback + admin alert.

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
- Open hubs now treat the already-created breakout rooms as immutable. A late-added same-segment class is assigned to the first unused spare room and persisted back to its shift; if all spare rooms are consumed, it falls back to single Zoom mode and alerts admins.
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

## 14. Paused Mobile Follow-Up — 2026-07-04

Mobile Zoom implementation is intentionally paused until the web Zoom hub path is proven stable in production. Do not spend local disk on Android emulators, iOS simulators, or downloaded Zoom native SDK archives for this step without explicit approval; the workstation had about 15 GiB free when this was paused.

Current mobile state:
- `lib/core/widgets/zoom_meeting_screen_io.dart` still points at `flutter_zoom_meeting_wrapper`.
- The required native Meeting SDK binaries were not present locally (`mobilertc.aar`, `MobileRTC.xcframework`, companion Zoom frameworks/bundles), so the native-wrapper path is not production-verifiable yet.
- No mobile implementation changes should be merged until the web room-routing, parent/admin/student joins, no-show detection, and live roster behavior are confirmed under real production class conditions.

Recommended mobile direction after web is stable:
- Prefer a Flutter `webview_flutter` IO implementation that loads the same hosted `zoom_meeting.html` client-view page already used by web.
- Pass the same `sdkKey`, `signature`, `meetingNumber`, `password`, `displayName`, `customerKey`, `breakoutRoomName`, `breakoutRoomKey`, and localized status strings in the URL fragment.
- Use a custom return URL such as `alluwal://zoom-left` so the red Leave button can return to the Flutter dashboard.
- Grant WebView camera/microphone permission requests through the existing Android/iOS permission declarations.
- Keep the external Zoom app open button only as a fallback for single-room classes; hub-routed classes should stay in the controlled classroom page because the bot depends on `customerKey` and the black routing layer.

Native wrapper alternative:
- Download the latest Zoom Meeting SDK binaries for both Android and iOS from the Zoom Marketplace, wire them into the wrapper, and test on physical devices.
- This is heavier and riskier for this machine because it consumes more disk and adds platform binary/version-management work. Only choose it if the WebView path fails mobile camera/audio or Zoom client-view requirements.

Mobile acceptance gates before release:
- Teacher, student, parent, and admin each join from Android and iOS and land in the correct class breakout room.
- No participant sees the hub main session after routing; if they are moved back, the black connecting layer reappears.
- Red Leave exits only that participant and does not end the class.
- Permission-denied camera/microphone cases show a graceful path to retry or leave.
- Background/foreground resume does not strand a user in the hub.
- `livekit_sessions` still records Zoom join/leave presence so no-show alerts and the live roster work.
- The 30-hour Zoom host cap remains handled by backend hub-window guards; mobile should not create any longer-running meeting path.

## 15. Classes and In-Meeting Zoom Hotfix Checkpoint — 2026-07-04

Scope:
- Mobile Classes cards use compact fixed-size action buttons below 430px viewport width, so the copy class-link button remains visible beside the join action on phones. This is separate from the in-meeting Zoom screen-share fix.
- `web/zoom_meeting.html` now preserves Zoom's own `Share Screen` control on small screens: the Zoom footer is horizontally scrollable below 640px/coarse-pointer viewports, Share controls are explicitly kept visible/interactable, and the classroom guard continues hiding native Leave/End controls.
- The web meeting page does not add an external Zoom-app fallback for screen sharing. The small-screen fix stays inside the website by preserving Zoom's own web `Share Screen` control when the SDK renders it.
- Zoom and RealtimeKit join calls now send the user's active dashboard role to the backend. The backend treats that value as a preference only when the caller is actually eligible for that classroom role.
- Multi-role users are resolved as teacher/student/admin/parent based on assignment plus the active role. A suspended student flag is applied only when the effective class role is `student`, so an admin who is also listed as a student can still join as admin.
- Assigned teachers can be recognized by verified email when the Firebase auth UID differs from the assigned teacher document ID, covering admin/teacher alias accounts.
- Zoom webhook presence can map a teacher by exact display-name match when Zoom omits `customer_key`, so teacher joins are no longer silently dropped from the live roster in that case. Admin roster labels still resolve from the stored user record when the webhook/session has a user ID.

Verification:
- `node --check functions/handlers/zoom.js`
- `node --check functions/handlers/realtimekit.js`
- `cd functions && npm test -- --runInBand functions/tests/realtimekit_access.test.js functions/tests/zoom_handler.test.js functions/tests/zoom_meeting_html.test.js` passed: 82 tests.
- `flutter analyze lib/core/services/class_video_service.dart lib/features/zoom/screens/zoom_screen.dart` passed.
- `flutter analyze lib/core/widgets/zoom_meeting_screen_web.dart lib/core/services/class_video_service.dart lib/features/zoom/screens/zoom_screen.dart` passed.
- `flutter test test/core/models/teaching_shift_test.dart` passed: 38 tests.
- Playwright mobile-width stub verification passed at 390x844: Zoom footer `overflow-x` was `auto`, `Share Screen` display was `flex`, visibility was `visible`, opacity was `1`, it was not marked `alluwal-classroom-hidden`, no external Zoom-app share fallback was present, native Zoom Leave was hidden, and `screenShare: true` / `sharingMode: both` were present.
- Dev smoke verification created a temporary `alluwal-dev` shift and a multi-role admin/teacher auth user whose UID differed from the assigned teacher profile but shared a verified email. The local current-source join call returned `userRole: teacher`, `routingMode: single`, the multi-role UID as `customerKey`, and the phone-width meeting page joined with the same customer key. The test cleaned up the temporary auth user, user docs, and shift, then a cleanup scan found zero leftovers.
- Hostinger web deploy completed through `./scripts/deploy_hostinger_web.sh` as build `v132`. The script backed up `public_html` to `public_html_before_v132_20260704_110349`, uploaded `build/web/`, and verified the public index cache-busting query strings.
- Deployed `https://alluwaleducationhub.org/zoom_meeting.html?verify=132` passed the same phone-width Playwright stub check: no external share fallback, Share Screen visible/interactable, Zoom native Leave hidden, app Leave visible, `screenShare: true`, and `sharingMode: both`.
- Firebase Functions production deploy was run with `cd functions && npm run deploy:prod`. The first full pass updated 133 functions and failed 6 unrelated functions with transient `ECONNRESET`; no existing functions were deleted when Firebase prompted for deletion. A targeted retry for those 6 functions completed successfully, so the Zoom/RealtimeKit role and roster handler changes are deployed to `alluwal-academy`.
- `git diff --check` passed.

Not done in this checkpoint:
- No live production class was joined for this hotfix because classes were active; validation stayed in unit/analyzer coverage to avoid interrupting real classes.
- No GitHub merge was performed, per instruction.

## 16. Shift Management Production Loading Hotfix — 2026-07-04

Scope:
- Production symptom after the cache fallback deploy: Sajor's admin Shift Management screen recovered from the Firestore unavailable error, but the admin counters showed only the small web date-window slice instead of the full shift set.
- Admin web shift loading now removes the 90-day lookback / 120-day lookahead query window so administrator totals come from the full `teaching_shifts` collection.
- Teacher/non-admin web shift loading keeps the bounded date window to avoid unnecessary reads on narrower teacher views.
- Background actual-payment loading no longer runs across the entire admin shift collection. It now scopes to the current grid week, skips calendar/week views, and caps list-view payment hydration to a bounded visible/recent slice so a 5,000-shift admin load does not trigger hundreds of `timesheet_entries` queries.
- Switching list/grid view or list tabs refreshes the bounded payment scope without blocking the initial shift render.
- The previous `serverAndCache`/cache fallback from build `v133` remains in place so temporary Firestore server unavailability can still render cached shifts instead of leaving the dashboard blank.

Verification:
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/features/shift_management/services/shift_service.dart lib/features/shift_management/screens/shift_management_screen.dart` passed with only pre-existing warnings/infos.
- `flutter test test/core/models/teaching_shift_test.dart test/core/utils/shift_session_aggregator_test.dart test/features/shift_management/recurrence_test.dart test/features/shift_management/timezone_test.dart` passed: 62 tests.
- `git diff --check` passed.

Deployment:
- Hostinger web deploy completed through `./scripts/deploy_hostinger_web.sh` as build `v134`. The script backed up `public_html` to `public_html_before_v134_20260704_125430`, uploaded `build/web/`, and verified the public site.
- Public verification confirmed `https://alluwaleducationhub.org/?verify=134` serves `manifest.json?v=134` and `flutter_bootstrap.js?v=134`, and deployed `main.dart.js?v=134` contains the cache fallback and scoped payment-loading code.

## 17. Shift Management Slow Device Progressive Loading Hotfix — 2026-07-04

Scope:
- Sajor's Shifts screen eventually loaded after about 10 minutes, confirming the account was authorized and the production data was readable, but the full 5,000-shift admin fetch was too slow for her device/network and timed out at 25 seconds during the initial render.
- Admin web Shifts now loads the visible current week first, so the screen can render quickly instead of waiting on the full shift collection.
- The full admin shift history now hydrates in the background with Firestore pagination at 150 shifts per page, replacing the previous single large all-shifts fetch on the critical path.
- The background loader uses Firestore count aggregation when available and shows a localized progress chip with a percentage, such as `Loading full shift history: 40% (2000/5000)`. If count aggregation is unavailable, it still loads pages and shows how many shifts have loaded.
- The stats row is horizontally scrollable so the loading chip does not crowd mobile-width admin screens.
- Actual-payment lookups remain scoped to the visible/current view so the background shift hydration does not reintroduce hundreds of timesheet queries.

Verification before deploy:
- `flutter gen-l10n` completed after adding the loading progress strings.
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/features/shift_management/services/shift_service.dart lib/features/shift_management/screens/shift_management_screen.dart lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_fr.dart lib/l10n/app_localizations_ar.dart` passed with only pre-existing warnings/infos.
- `flutter test test/core/models/teaching_shift_test.dart test/core/utils/shift_session_aggregator_test.dart test/features/shift_management/recurrence_test.dart test/features/shift_management/timezone_test.dart` passed: 62 tests.
- `git diff --check` passed.

Deployment:
- Hostinger web deploy completed through `./scripts/deploy_hostinger_web.sh` as build `v135`. The script backed up `public_html` to `public_html_before_v135_20260704_131201`, uploaded `build/web/`, and verified the public site.
- Public verification confirmed `https://alluwaleducationhub.org/?verify=135` serves `manifest.json?v=135` and `flutter_bootstrap.js?v=135`.
- Public `main.dart.js?v=135` verification confirmed the deployed bundle contains `admin_visible_week_web`, `admin_full_hydration_page`, `Loading full shift history`, `serverAndCache`, and `payments_load_skipped`.
- Playwright smoke opened `https://alluwaleducationhub.org/?verify=135`; the deployed Flutter app started with zero console errors and zero console warnings. The authenticated Sajor admin session was not reproduced locally because her browser/session credentials are not available in the headless test.

## 18. Scheduled Zoom Class Routing Hotfix — 2026-07-04

Production symptom:
- Scheduled classes could enter the shared Zoom hub but remain behind the black `Still connecting to your private classroom...` guard.
- Mama S Diallo was the visible example, but the risk applied to any multi-role/admin user clicking multiple scheduled classes in the same shared hub.

Root cause found from live production data:
- The hub member document ID and Zoom `customerKey` were the bare Firebase UID.
- If the same user, especially an administrator with multiple roles, clicked more than one class in the same hub, the later click overwrote that user's previous target room in `hub_meetings/{hubId}/members/{uid}`.
- The bot then had only one target for that UID, while the web meeting page could still be waiting for the room from the currently clicked class.
- Hostinger was also still serving an older `zoom_meeting.html` that did not recognize Zoom participant key variants named `customerKeyValue`, `customUserId`, or `custom_user_id`. That could leave the private-room guard up after a participant was already routed.

Fixes applied:
- `getZoomJoinInfo` now uses a short class-scoped hub routing key, `zh_<sha256(uid:shiftId)>`, for hub-routed joins.
- Hub member docs are now stored by that class-scoped key and also keep the real Firebase UID in `userId` / `user_id`.
- `zoomWebhook` maps `zh_...` participant keys back through the hub member doc before writing `livekit_sessions`, so presence/no-show/live roster records land on the exact clicked shift instead of another simultaneous class.
- The local Zoom hub bot router now reads additional Zoom SDK key variants (`customerKeyValue`, `customUserId`, `custom_user_id`) in addition to the existing key fields.
- `web/zoom_meeting.html` now recognizes those same participant key variants, so the browser guard can confirm the user is in the correct private classroom.

Backend deployment:
- Production targeted deploy completed for `getZoomJoinInfo` and `zoomWebhook` on `alluwal-academy`.
- `gcloud functions describe` verified both functions `ACTIVE`; `getZoomJoinInfo` update time was `2026-07-04T17:52:47Z`, and `zoomWebhook` update time was `2026-07-04T17:52:52Z`.

Web deployment:
- Hostinger web deploy completed through `./scripts/deploy_hostinger_web.sh` as build `v136`.
- Public verification confirmed `https://alluwaleducationhub.org/?verify=136` serves `manifest.json?v=136` and `flutter_bootstrap.js?v=136`.
- Public verification confirmed `https://alluwaleducationhub.org/zoom_meeting.html?verify=136` contains `customerKeyValue`, `customUserId`, `custom_user_id`, `screenShare: true`, and `sharingMode: 'both'`.

Verification:
- `node --check functions/handlers/zoom.js`
- `node --check functions/handlers/realtimekit.js`
- `node --check services/zoom-hub-bot/routing.js`
- `cd functions && npm test -- --runInBand tests/zoom_handler.test.js tests/realtimekit_access.test.js tests/zoom_meeting_html.test.js` passed: 85 tests.
- `cd services/zoom-hub-bot && npm test` passed: 14 tests.
- `git diff --check` passed.
- Playwright phone-width check against deployed `zoom_meeting.html?verify=136` at 390x844 confirmed:
  - Zoom footer `overflow-x` computed as `auto`.
  - Share Screen display was `inline-flex`, visibility `visible`, opacity `1`, and it did not have `alluwal-classroom-hidden`.
  - Native Zoom Leave was hidden.
  - No external/native Zoom app share fallback was present.
  - The deployed page included `customerKeyValue` and `customUserId`.
- Live production Firestore after deploy showed new class-scoped hub member docs:
  - `zoom_hub_2026-07-04_2_1`: `zhMemberCount: 3`, `customerKeyCount: 5`, `routedCount: 4`.
  - `zoom_hub_2026-07-04_2_2`: `zhMemberCount: 1`, `customerKeyCount: 4`.
- Live production presence checks found `livekit_sessions` rows for the new class-scoped joins on their exact shift/user pairs, confirming the webhook mapping path is active.

Current live note:
- Mama S Diallo's 18:00 production shift had not yet rejoined through the v136 path when checked at about `2026-07-04T18:04Z`; it had zero `zh_...` members at that time.
- Anyone already stuck in an old black-screen tab must leave that tab and click Join again so the browser gets the v136 page and the backend returns a class-scoped `zh_...` key.
- Follow-up production poll at about `2026-07-04T18:09Z` still showed both active hubs heartbeating within seconds and recent `zh_...` joins on non-Mama classes. Mama still had only the older legacy member for the 17:00 shift and no member for the 18:00 shift.
- Production log checks from `2026-07-04T17:50Z` onward showed no `WARNING` or `ERROR` entries for `getZoomJoinInfo` or `zoomWebhook`.
- `system_alerts` still contained historical alert `zoom_hub_2026-07-04_2_1_rooms_not_open` from `2026-07-04T16:19Z`, but the same hub was later verified `roomsOpen` with fresh heartbeats and successful routing. Treat that alert as historical unless a newer watcher alert appears.
- Mama-specific production callable smoke at about `2026-07-04T18:12Z` used the exact 18:00 Mama shift (`tpl_tpl_a56717c73fc9a9b8_1783184400`) and admin UID `7akU2aXPhshMPd5nrmrnqUqzvGH3` through the current source path against production Firestore/Zoom config. It returned `routingMode: hub`, `hubMeetingId: zoom_hub_2026-07-04_2_1`, meeting `88038589279`, `userRole: admin`, a 27-character `zh_...` class-scoped customer key, `breakoutRoomKey` equal to the Mama shift ID, `breakoutRoomName: 184400 | Mama S Diallo | Am...`, and `autoJoinBreakoutRoom: true`.
- Firestore verification found the matching `hub_meetings/zoom_hub_2026-07-04_2_1/members/{zh...}` document with `shiftId` equal to the 18:00 Mama shift, `userId` equal to the real admin UID, `role: admin`, and display name `Hassimiou Niane`.
- A follow-up bot heartbeat poll at about `2026-07-04T18:13Z` showed lane 1 still heartbeating within seconds, `targetMemberCount: 11`, `zhMemberCount: 4`, and the new Mama 18:00 scoped member still present.
- Mama-specific synthetic Zoom presence mapping at about `2026-07-04T18:16Z` used the same `zh_...` member key and verified `handleZoomPresenceWebhook` writes `livekit_sessions/tpl_tpl_a56717c73fc9a9b8_1783184400_7akU2aXPhshMPd5nrmrnqUqzvGH3`, with `shift_id` equal to the 18:00 Mama shift and `user_id` equal to the admin UID. The synthetic row was immediately deleted.
- Mama-specific synthetic roster verification at about `2026-07-04T18:17Z` recreated that same short-lived session, called `getRealtimeKitRoomPresence` for the Mama shift as the admin, and verified the participant appears with identity `7akU2aXPhshMPd5nrmrnqUqzvGH3` and role `admin`. The synthetic row was immediately deleted.
- Cleanup verification after both synthetic checks showed `mamaPresenceRows: 0` for the 18:00 Mama shift and no remaining `livekit_sessions` admin row.
- This smoke did not open Zoom or create a live `livekit_sessions` presence row for Mama. A browser/user still needs to click Join after v136 to prove end-to-end Zoom routing for that specific class.

Still blocked:
- VPS access for deploying the local `services/zoom-hub-bot/routing.js` key-variant reader was not available from this workstation. The Hostinger web SSH account is reachable, but it is not the Zoom hub bot VPS and has no `/opt/alluwal/zoom-hub-bot`.
- Current live stats prove the running bot already reads the primary `customerKey` field and can route `zh_...` participants. Deploy the bot-side key-variant reader when the real VPS SSH host/user/port are available.

## 19. Follow-Up Live Probe and Backend Display-Name Fallback — 2026-07-04

Read this before continuing the Zoom routing work. This section is a handoff from the interrupted production-debugging session.

What was verified first:
- No local Playwright/Zoom hub bot processes were left running after the live probes.
- Live production hub docs were heartbeating:
  - `zoom_hub_2026-07-04_2_1` was `roomsOpen`, heartbeat within seconds, `boIdByRoomName` count 26.
  - `zoom_hub_2026-07-04_2_2` was `roomsOpen`, heartbeat within seconds, `boIdByRoomName` count 16.
- The repository/plan does **not** contain usable Zoom bot VPS SSH credentials. The plan still says host/IP/SSH details belong in the ops vault/local deploy environment, not source. Known old LiveKit/VPS references (`187.77.221.13`, `live.alluwaleducationhub.org`) were not reachable from this workstation for bot deploy/debug. Hostinger web SSH is separate and is not the Zoom bot VPS.

Live failure reproduced before the backend fallback:
- Used the admin account to request production `getZoomJoinInfo` for Mama S Diallo's active shift `tpl_tpl_a56717c73fc9a9b8_1783184400`.
- The callable returned correct hub routing data: `routingMode: hub`, `hubMeetingId: zoom_hub_2026-07-04_2_1`, `userRole: admin`, a `zh_...` customer key, `breakoutRoomName: 184400 | Mama S Diallo | Am...`, and `autoJoinBreakoutRoom: true`.
- A headless Chromium browser opened the deployed `zoom_meeting.html`, waited 3 minutes, then left the meeting.
- Result: still failed. Page stayed on the black guard with `pending: true`, status text `Still connecting to your private classroom...`, `getCurrentBreakoutRoom` returned empty room/name, and `getUserStatus` stayed `initial`.
- During that probe, the bot hub stats showed no route attempts: `routeActionCount: 0`, `routeAssignAttemptCount: 0`, `routeMoveAttemptCount: 0`.

Backend fix deployed in this session:
- `functions/handlers/zoom.js`
  - Hub-routed `getZoomJoinInfo` now returns a class-specific Zoom display name suffix derived from the existing `zh_...` routing key, e.g. `Hassimiou Niane #tUW6sR94`.
  - The real display name is preserved as `realDisplayName`.
  - Hub member docs now store both `displayName`/`display_name` for Zoom routing and `realDisplayName`/`real_display_name` for clean roster/presence display.
  - `zoomWebhook` now maps shared-hub webhook events by `customer_key` first, then by the exact routing display name when Zoom omits the custom key.
  - Presence records use the real display name, not the routing suffix.
- `functions/tests/zoom_handler.test.js`
  - Added/updated coverage for one admin clicking multiple classes in the same hub, proving the returned Zoom display names differ per class and a webhook without `customer_key` maps to the correct shift/user via the routing display name.

Validation before deploy:
- `node --check functions/handlers/zoom.js`
- `cd functions && npm test -- --runInBand tests/zoom_handler.test.js tests/realtimekit_access.test.js tests/zoom_meeting_html.test.js` passed: 87 tests.
- `cd services/zoom-hub-bot && npm test` passed: 18 tests.
- `git diff --check` passed.

Production deploy performed:
- Targeted Firebase Functions deploy only:
  - `cd functions && npx firebase-tools deploy --only functions:getZoomJoinInfo,functions:zoomWebhook --project alluwal-academy`
- Deploy completed with 2 functions updated, 0 errored.
- `gcloud functions describe --gen2` verified:
  - `getZoomJoinInfo` `ACTIVE`, update time `2026-07-04T19:23:55.909943163Z`.
  - `zoomWebhook` `ACTIVE`, update time `2026-07-04T19:24:05.782409029Z`.
- No Hostinger web deploy was needed or run in this follow-up, because the existing web page already consumes the returned `displayName`.
- No GitHub merge was performed.
- No Zoom bot VPS deploy was performed.

Post-deploy callable verification:
- Production `getZoomJoinInfo` for the Mama shift returned:
  - `displayName: Hassimiou Niane #tUW6sR94`
  - `realDisplayName: Hassimiou Niane`
  - `customerKey` still class-scoped and prefixed with `zh_`.
- Firestore member doc `hub_meetings/zoom_hub_2026-07-04_2_1/members/zh_tUW6sR94rEr1l83rnapa7zHE` had:
  - `displayName: Hassimiou Niane #tUW6sR94`
  - `realDisplayName: Hassimiou Niane`
  - `userId: 7akU2aXPhshMPd5nrmrnqUqzvGH3`
  - `role: admin`

Post-deploy live Zoom browser probe:
- Re-ran the same live Mama browser join after the backend deploy.
- The page still failed to enter the private breakout room after 3 minutes:
  - `pending: true`
  - status text `Still connecting to your private classroom...`
  - `getCurrentBreakoutRoom`: empty name/roomId, `attendeeStatus: initial`
  - `getUserStatus`: `status: initial`
- The webhook/presence side **did** improve:
  - `livekit_sessions/tpl_tpl_a56717c73fc9a9b8_1783184400_7akU2aXPhshMPd5nrmrnqUqzvGH3` recorded the join/leave.
  - `zoom_participant_name` was the clean `Hassimiou Niane`, not the suffixed routing display name.
- After the browser left, lane-1 bot stats returned to bot-only attendance (`customerKeyCount: 1`, `attendeeCount: 1`) and still had `routeActionCount: 0`.

Current conclusion:
- The backend/class-scoped join data is now correct and deployed.
- Webhook/live roster mapping is now better and deployed.
- The end-to-end Zoom breakout routing is **still not fixed** for the live Mama browser probe.
- The remaining problem is in the Zoom host/bot assignment path or the active hub's breakout state, not in `getZoomJoinInfo`.
- The bot is not recording route attempts for the stuck participant, so the next agent needs live bot console/log visibility or VPS access to see the raw `getBreakoutRooms()` / `getAttendeeslist()` payloads from the running host bot.

Important warning about local bot changes:
- There are local, unmerged edits in `services/zoom-hub-bot/bot.js`, `services/zoom-hub-bot/bot_controller.html`, and `services/zoom-hub-bot/tests/bot_controller_html.test.js`.
- Do **not** deploy those bot changes as-is without reviewing/testing them. They include experiments:
  - localhost controller serving instead of `file://`;
  - mouse movement to wake Zoom controls;
  - route diagnostics and wrapped/unwrapped room-id retries;
  - stored `boIdByRoomName` fallback;
  - a guarded close/reopen path for unreadable open rooms;
  - `breakoutAllocationPattern = 3` self-select experiment.
- Earlier local live tests showed the localhost controller and mouse wake did not fix `getBreakoutRooms()` returning no rooms; wrapped/unwrapped target room IDs also did not fix assignment. The self-select change was not validated before interruption.

Recommended next steps:
1. Get real Zoom bot VPS SSH access (`user@host`, port, key/path, and route). The plan document does not contain it.
2. On the VPS, inspect:
   - `journalctl -u zoom-hub-bot@1 -n 300 --no-pager`
   - `journalctl -u zoom-hub-bot@2 -n 300 --no-pager`
   - current `/opt/alluwal/zoom-hub-bot` code version and whether it includes the routing key variants.
3. Add a temporary safe diagnostic in bot state if logs are inaccessible: include sanitized `attendeeList`, `breakoutUnassigned`, and room count from the host bot, without secrets or signed URLs.
4. Reproduce with one controlled live admin join and confirm whether the bot sees:
   - the `customerKey`;
   - the suffixed display name;
   - the numeric Zoom userId;
   - the target room ID/name.
5. Only after seeing raw bot state, decide whether to:
   - deploy a bot routing fallback;
   - restart/recreate the active hub safely;
   - or move classes temporarily to single Zoom mode.

## 20. ROOT CAUSE FOUND + FIX SHIPPED — 2026-07-04 (VPS access obtained)

This session got onto the Zoom bot VPS (`srv1803683` / `2.25.77.226`, `ssh -i ~/.ssh/laawol_hostinger root@…`) — the exact access the previous section was blocked on — read the live bot logs, and found and fixed the "Connecting To Class" stuck-screen root cause. Backend and `web/zoom_meeting.html` were already correct; the failure was entirely on the VPS controller bot.

### Root cause
- The host bot's `getBreakoutRooms()` returns an **empty room list** for sustained periods on the affected lane. When empty, `assignUserToBreakoutRoom` fails `errorCode 1 "not find unassigned user or target Room Id"` (the SDK validates the target boId against its live, empty breakout store), so participants are never routed and sit on the black layer.
- **The deeper cause:** a hub is a *persistent scheduled Zoom meeting*. Its breakout state got **corrupted server-side** during a ~17:00Z reconnect storm (the licensed account hit its 1-concurrent-meeting limit — `errorCode 3000 "Already has other meetings in progress"` — while a bot restart's old host session lingered). After corruption the room list was unreadable **and** `closeBreakoutRooms` no longer took effect (`waitForRoomsClosed` timed out; `createBreakoutRoom`/`openBreakoutRooms` returned "Breakout room has started!"). Because every bot restart **rejoins the same persistent meeting instance**, it inherited the corruption every time — which is why no bot-only restart fixed it. Lane 2 (uncorrupted instance) stayed healthy the whole time.
- `systemctl restart` also leaves a **ghost host session** in Zoom for ~1–2 min → two "Alluwal Hub Bot Lane N" hosts → create/open conflicts. Clean cycle is `stop` → wait ~150s → `start`. But a **stuck participant keeps the meeting (and its corruption) alive**, so even stop→wait→start inherits it.

### The actual fix that worked (manual, this session)
Ended the corrupted meeting instance via Zoom REST (S2S creds in `functions/.env`): OAuth `account_credentials` → `PUT https://api.zoom.us/v2/meetings/{meetingNumber}/status {"action":"end"}` (HTTP 204). Restarted the lane bot → it joined a **fresh instance**, created 26 rooms cleanly, and `getBreakoutRooms()` has held at 26 ever since (matching healthy lane 2). Meeting numbers/host per lane come from `GET zoomHubBotDirectives?lane=N` with the bot key in `/etc/alluwal/zoom-hub-bot.env`.

### Durable fixes shipped
1. **Bot self-heal** (`services/zoom-hub-bot/bot_controller.html`, deployed to VPS `/opt/alluwal/zoom-hub-bot/bot_controller.html`; backups `*.bak_*` kept):
   - Runs the close+reopen recovery **inside the routing loop** (not only at join) when the live room list is empty while routing is needed.
   - New `isSafeToReopen()` gates on people **inside rooms** only (tracked via `lastKnownInRoomCount` from readable snapshots + `roomsCreatedFresh`), so a lone waiter in the main session is routed while a live class is never reopened out from under.
   - New `burstReadBreakoutRooms()` retries the read hard before any destructive reopen (catches transient empties, surfaces real occupancy).
   - Posts `stats.liveRoomCount` (real getBreakoutRooms count) and `stats.inRoomOccupants` for the watcher.
   - NOTE: this was based on the **clean VPS copy**, not the unreviewed experimental edits in the repo (§19). The repo `services/zoom-hub-bot/bot_controller.html` still needs reconciliation with what's on the VPS.
2. **Server-side auto-recovery** (`functions/handlers/zoom.js` → `watchZoomHubBots`, deployed to prod `alluwal-academy`): detects the poison signature (`status roomsOpen` + fresh heartbeat + `liveRoomCount === 0` + `targetMemberCount > 0` + `inRoomOccupants === 0`) and after `ZOOM_HUB_POISON_RESET_STREAK` (2) consecutive 5-min checks calls `zoomClient.endMeeting(meetingNumber)` so the bot rejoins a clean instance. Never resets when anyone is inside a room. Jest coverage added in `functions/tests/zoom_handler.test.js` (4 tests: resets poisoned, waits one cycle, protects occupied, clears streak on healthy). `tests/zoom_handler.test.js` = 40 passed.

### Verification
- `node --check` on `functions/handlers/zoom.js`, `functions/handlers/zoom_hub_bot.js`, and the extracted bot controller JS — all OK.
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` → 40 passed.
- Live: both lanes healthy after fix — lane 1 `liveRoomCount 26`, lane 2 `16`, `inRoomOccupants 0`; hub doc `hub_meetings/zoom_hub_2026-07-04_2_1.stats` confirmed carrying `liveRoomCount`/`inRoomOccupants`. `watchZoomHubBots` redeployed and ACTIVE.

### Still open / next
- **Per-class "which bot/lane controls this class" indicator** in the Flutter Classes screen (user-requested). Lane = `abs(javaStringHash(teacher_id)) % hostAccounts.length` + 1 (`_laneIndexForShift`/`_hashString` in `functions/handlers/zoom.js`); override `zoom_hub_lane_index`. Only hub-routed classes have a bot. Needs l10n + `flutter gen-l10n` + web build/deploy.
- Reconcile repo `services/zoom-hub-bot/*` (experimental edits) with the VPS-deployed controller.
- Consider preventing the original trigger: avoid overlapping host sessions on one licensed account during bot restarts (graceful leave on SIGTERM), which is what caused the 3000 storm → corruption.

### Follow-ups shipped after §20
- **Per-class controller-bot indicator** (v139, live): admin-only "Bot 1 / Bot 2" chip on each Zoom class card in `lib/features/zoom/screens/zoom_screen.dart` (`zoomHubControllerLane()` mirrors backend `_laneIndexForShift`). l10n key `classControllerBot`. Built via `./scripts/deploy_hostinger_web.sh` (created local `.hostinger-deploy.env`, gitignored).
- **Clean Zoom display names**: removed the per-class `#<token>` display-name suffix that §19 added (it was chasing the wrong root cause — routing/presence key off `customerKey`, not the visible name). `getZoomJoinInfo` now returns the real name as `displayName`; deployed to prod. Webhook still maps by `customer_key` first, real-name fallback second. Test `keeps one admin separately routed…` updated to assert clean names + `customer_key`-based webhook mapping. Users in a session before the deploy keep the old tagged name until they rejoin.

## 21. Reliability Hardening — defense-in-depth against class failures — 2026-07-04

Triggered by a 5 PM ET (17:00Z) **block-boundary failure**: JOIN_TIMEOUT for participants because both blocks' windows overlapped and each licensed account hosts only ONE meeting at a time (errorCode 3000 storm) — the same class of event that corrupted the Block-2 hub earlier in the day. Built layered defenses so a class self-recovers instead of hard-failing.

**Root failure modes catalogued (ranked):** (1) breakout-room state corruption on the shared hub meeting [most likely; inherent to bot-driven breakout rooms]; (2) block-boundary account contention [2-license ceiling]; (3) VPS single point of failure; (4) ZAK/signature expiry & pinned CDN SDK 6.2.0; (5) headless Chromium long-session drift. **True ~100% requires an architecture change — enough Zoom licenses to give each class its own meeting (retire the bot) or migrate to Zoom Video SDK. The bot/breakout model's fragility is the price of stretching 2 licenses across ~14 concurrent classes.**

**Shipped this session (all deployed to prod `alluwal-academy` + VPS + Hostinger v141):**
- `functions/handlers/zoom_hub_bot.js`:
  - `_selectPrimaryActiveHub` — directives now serve **one hub per lane**. During a boundary overlap: keep the block that still has a live class (oldest such block first, verified by fresh heartbeat + inRoomOccupants>0); if drained, move to the newest block. This is the primary defense against the 3000 storm (bot never tries to host two meetings on one account).
  - `zoomHubBotState` accepts new status `resetMeeting`: ends the corrupted meeting so the bot rejoins a clean instance; refuses if anyone is inside a room.
  - Helpers `_hubInRoomOccupants`, `_hubHeartbeatFresh`, `_msOf`; exported for tests.
- `functions/handlers/zoom.js` `watchZoomHubBots`: cadence 5min→**2min**; now also **ends expired-window hub meetings** (no occupants) to free the licensed account faster at boundaries. Poison auto-reset from §20 still present.
- `services/zoom-hub-bot/bot_controller.html`: self-heal now **escalates to `resetMeeting`** after `healFailuresBeforeReset` (2) consecutive failed in-place reopens (corruption that can't be fixed in place) → posts resetMeeting + leaves → directive poll rejoins fresh. Reports `stats.liveRoomCount` + `stats.inRoomOccupants` for the watcher. Also synced `routing.js` key variants to VPS.
- `web/zoom_meeting.html`: participant join failures/timeouts now **auto-retry with backoff indefinitely** (keeps the black "connecting" layer, status escalates connecting→still-connecting→help over 60s/180s) instead of showing a terminal JOIN_TIMEOUT. A class reconnects on its own the moment the hub is back (boundary handoff or meeting reset) — users never see a hard failure.

**Tests:** `functions` full suite 208 passed (7 skipped); `zoom_handler.test.js` +6 new (primary-hub selection, resetMeeting occupied/empty, expired-hub end occupied/empty); `zoom_meeting_html.test.js` updated (auto-retry assertions); `services/zoom-hub-bot` 18 passed (bot_controller tests rewritten to assert shipped self-heal/reset/occupancy behavior instead of the deleted §19 experimental WIP).

**Deploy verification:** functions `zoomHubBotDirectives`/`zoomHubBotState`/`watchZoomHubBots` updated ACTIVE; both bots restarted off-hours (directives empty for lane 1, lane 2 healthy roomCount 8) on new controller (grep confirmed self-heal/reset markers); Hostinger `v141` live, deployed `zoom_meeting.html` contains `scheduleJoinRetry`/`retryStatusForElapsed`/`Transient hub unavailability`.

**Still recommended (business/ops, not yet done):**
- VPS dead-man's-switch alert (SMS/push if heartbeats stop) — covers failure mode #3, the unmonitored single point of failure.
- License-count decision: enough seats to give each class its own meeting would retire the bot and remove failure modes #1/#2/#4/#5 — the only path to genuine ~100%.
- The block-boundary 2-license contention (#2) cannot be fully eliminated in code while a class can run past a boundary into the next block's start.

## 22. Chaos testing + zombie-meeting gap fix — 2026-07-04 (off-hours, empty hubs)

Ran live failure-injection against lane-2's empty hub (11 PM ET Sat, no real classes) to verify the §21 self-recovery actually works. Two tests passed; one **found a real gap** which is now fixed and re-verified.

- **Test 1 — hard bot crash** (`kill -9` the node process): systemd `Restart=always` relaunched the bot; it rejoined and its 8 rooms were readable again in ~45s. PASS.
- **Test 2 — meeting killed under the bot** (REST `PUT /meetings/{n}/status {action:end}`): **exposed a gap.** REST-end marked the meeting `waiting` server-side, but the bot's browser SDK kept running as a **zombie**, still reporting `roomCount:8`. Neither the poison check nor the heartbeat check caught it (both look for liveRoomCount==0; zombie reports 8). A participant joining then would hit a dead hub. Also revealed a latent bug: the bot's `resetMeeting` escalation called `leaveMeeting()` and relied on the launcher re-opening the page — which it won't (session still tracked), so it wouldn't have rejoined.

**Fix (deployed prod + VPS):**
- `watchZoomHubBots` now does a **REST liveness check** on any hub that looks healthy (roomsOpen + fresh heartbeat, no in-room occupants): `zoomClient.getMeeting(meetingNumber)`; if status != `started` (or 404/3001 = gone) it stamps `force_rejoin_at` + alerts (`zombie_meeting_forced_rejoin`). Throttled 3 min so it doesn't re-stamp before the bot reloads.
- `zoomHubBotAssignments` returns `forceRejoinAt` (ms).
- Bot controller: records `pageLoadedAt`; each routing loop, if `assignments.forceRejoinAt > pageLoadedAt` and no one is in a room, it **`window.location.reload()`** → clean rejoin into a fresh instance (self-contained, no launcher dependency). Reload capped at 5/session via `sessionStorage` (`alluwal_rejoin_count`, reset on healthy open); systemd + watcher remain backstops. The `resetMeeting` escalation now also uses `triggerRejoin('self_heal_exhausted')` (reload) instead of the broken leave+repoll.

**Re-test of the gap — PASS (proven end-to-end):** killed meeting 88420477032 at 03:30:21Z → watchdog stamped `force_rejoin_at` at 03:31:03Z → bot logged "Reloading to rejoin… reason: backend_force_rejoin" → rejoined + recreated 8 rooms by 03:31:10Z. **~40s fully automatic**, no human action. Firestore confirmed `force_rejoin_at: 2026-07-05T03:31:03Z`.

**Tests:** functions 211 passed (7 skipped) incl. new `zombie_meeting_forced_rejoin` + healthy-hub-liveness cases; bot service 19 passed incl. force-rejoin/reload-cap coverage.

**Not yet live-tested (lower priority / harder to inject safely):** block-boundary one-hub-per-lane (unit-tested; would require creating overlapping hubs to inject live). The empty-getBreakoutRooms poison self-heal reopen was witnessed live earlier today; its escalation now shares the proven `triggerRejoin` reload path.

## 23. 15-minute stay limit + class-ending countdown + forgot-to-leave fix — 2026-07-05 (v142)

Owner policy: a class may stay at most 15 minutes past its scheduled end, then everyone is removed; show a countdown in the final 5 minutes. Chosen granularity (owner-approved): **meeting-level** — one hub meeting hosts several classes as breakout rooms; a lingering participant sits in an isolated room (harms nothing) until the meeting's hard end. True per-class mid-meeting expel was rejected as too risky/unverified (no participant-removal API is used anywhere; the LiveKit `removeParticipant` is a different system; Zoom client-view SDK support is unverified).

**Forgot-to-leave gap found + fixed:** the earlier boundary logic protected any hub with occupants, so a straggler could keep an old block "primary" and starve the next block's account (and drift toward the 30h cap). Fixes:
- `_selectPrimaryActiveHub` (zoom_hub_bot.js) now protects a hub only while its REAL scheduled classes are running (`now <= window_end - 15min PAD`) AND someone is inside AND heartbeat fresh. Past the last class, a straggler no longer protects it → newer block wins.
- `watchZoomHubBots` (zoom.js) now ENDS a hub meeting — regardless of occupants — once `now >= window_end` (the 15-min limit; window_end = last class + 15) OR it is superseded by a newer active block whose classes are due and this block's real classes are over. Removed the old occupant gate and the +10min extra grace. Precomputes newest-active-block-per-lane for supersede detection. Writes a `stragglers_removed_at_time_limit` alert when it kicks people.

**Countdown (participant page, v142):**
- `getZoomJoinInfo` returns `classEndsAtIso` (hub window_end; null for single mode) via `ensureZoomHubMeeting` return.
- Threaded: `ZoomClassJoinInfo.classEndsAt` → `class_video_service` → `ZoomMeetingScreen(classEndsAt:)` (web + io) → URL params `classEndsAt`/`classEndingSoonText`/`classEndedText`.
- `web/zoom_meeting.html`: `#classCountdown` banner; `startClassCountdown()` (called on join success + UI-monitor) shows "This class ends in N min" when within 5 min of `classEndsAt`, "This class has ended." at 0. Ticks every 15s.
- l10n keys `zoomClassEndingSoon` ({minutes}) + `zoomClassEnded` in en/fr/ar; `flutter gen-l10n` run.

**Tests:** functions 215 passed (7 skipped) — added: `getZoomJoinInfo` returns valid `classEndsAtIso`; watcher removes stragglers at 15-min limit; watcher does NOT remove before the limit; superseded old block ended even with stragglers; expired empty ended. `zoom_meeting_html.test.js` — countdown assertions. bot suite 19 passed. `flutter analyze` on touched Dart clean; `git diff --check` clean.

**Deployed:** `getZoomJoinInfo`, `watchZoomHubBots`, `zoomHubBotDirectives`, `zoomHubBotAssignments`, `zoomHubBotState` to `alluwal-academy`; Hostinger web `v142` (verified `classEndsAt`/`startClassCountdown`/`scheduleJoinRetry` present in deployed `zoom_meeting.html`); bot controller + routing.js on VPS; both bots restarted on the new controller.

**Live tests this session (off-hours, empty lane-2 hub):**
- Bot hard crash (`kill -9`) → systemd restart + rejoin ~45s. PASS.
- Meeting killed under bot (zombie) → watchdog REST-liveness detected + `force_rejoin_at` → bot reloaded + rejoined fresh ~40s. PASS (this found + fixed the zombie gap).
- Participant auto-retry: real browser at deployed page, join to nonexistent meeting timed out twice while staying on the connecting layer (never hard-failed). PASS.
- Class-ending countdown: real browser join to the live lane-2 hub with classEndsAt 4 min out showed the orange "This class ends in 4 min" banner. PASS. Phantom participant left cleanly.

**Still recommended (not done):** VPS dead-man's-switch alert (owner considers VPS-down low-probability on Hostinger); license-count decision for true per-class isolation / retiring the bot (the only path to genuine ~100%).

## 24. Screen-share "button missing" investigation — 2026-07-05

Two distinct causes, one per platform:

**iPhone/iPad (unfixable via web):** iOS browsers (all use WebKit) do NOT support `getDisplayMedia`, so no web page can screen-share on iOS. Zoom correctly hides Share Screen there. The only iOS screen-share path is the native Zoom app (breaks hub routing). Not our bug; verified via caniuse/Twilio/BBB. Our config/guard already preserve Share everywhere the platform supports it (`screenShare:true, sharingMode:'both'`, share allow-list in the classroom guard, §15 small-screen CSS).

**Desktop/Android teachers intermittently missing the button:** In the hub model every human is a participant (role 0; only the bot is host). Checked both licensed accounts via REST:
- `who_can_share_screen: all` (NOT locked) → participants CAN share when nobody else is sharing. ✓
- `who_can_share_screen_when_someone_is_sharing: host` and **LOCKED at the account level** → while someone is already sharing in a room, other participants' Share button is suppressed (only "host" — the bot, not in the room — could grab it). This is the most likely cause of "some teachers couldn't share" (a student was already presenting), while teachers in idle rooms (like the owner's test) saw it fine. Secondary factor: on narrow desktop windows Share lives under the "More" overflow menu (discoverability).

Fixes:
- `ensureZoomHostClassroomSettings` now enforces `screen_sharing:true, who_can_share_screen:'all', who_can_share_screen_when_someone_is_sharing:'all'` (+ existing disable flags false), and is now called BEFORE hub-meeting creation in `ensureZoomHubMeeting` (Zoom applies these at meeting start, so join-time-only was too late for long-running hubs). Deployed `getZoomJoinInfo` + `prepareZoomHubs`. Test updated (49 passed).
- `who_can_share_screen_when_someone_is_sharing:'all'` is currently **rejected because the setting is locked at the account level** — a user-level PATCH returns 204 but the value stays `host`; the account-level PATCH needs scope `account:update:settings:admin` which the S2S app lacks.

**ACTION REQUIRED (owner, one-time):** In Zoom admin console → Account Management → Account Settings → Meeting → In Meeting (Basic) → "Who can share when someone else is sharing?" → set **All Participants** and ensure it is **not locked** (or unlock). Alternatively add the `account:update:settings:admin` scope to the S2S OAuth app and the deployed code will enforce it automatically. Takes effect for meetings started AFTER the change; active hubs pick it up at their next reset (block boundary / 15-min limit / bot restart).

## 25. Native mobile Option A routing implementation — 2026-07-05

Problem solved in source: Android/iOS native Zoom Meeting SDK joins cannot send the Web SDK `customerKey`, but hub routing depends on a stable per-class key. The chosen solution is a native-only deterministic routing display name.

Shipped in source:
- `getZoomJoinInfo` accepts `clientPlatform: 'native_mobile'`. Web/desktop callers do not send this flag and keep the current clean display name + `customerKey` path.
- Hub-routed native mobile callers receive `nativeDisplayName`/`displayName` as `"<real name> #<8-char token>"`, derived from the existing `zh_<sha256(uid:shiftId)>` routing key.
- Hub member docs keep `uid = zh_...`, `userId = Firebase uid`, clean `realDisplayName`, plus `routingDisplayName` and `displayNameAliases`.
- `zoomHubBotAssignments` now returns `routingDisplayName` and `displayNameAliases` to the VPS bot.
- `services/zoom-hub-bot/routing.js` routes by exact display-name aliases only when that alias maps to a single room. Duplicate clean names still do not route by fallback.
- `zoomWebhook` display-name fallback now also requires exactly one matching hub member, so ambiguous visible names do not write presence to the wrong class.
- Flutter mobile sets `clientPlatform: native_mobile`, threads `nativeDisplayName` into `zoom_meeting_screen_io.dart`, and the native wrapper joins using that exact display name.
- `flutter_zoom_meeting_wrapper` is vendored at `packages/flutter_zoom_meeting_wrapper/`; app `pubspec.yaml` now points to the local path.
- Zoom native SDK binary placement and mobile release gates are documented in `docs/zoom-native-mobile-sdk-runbook.md`.
- Proprietary Zoom native binaries are ignored under the vendored wrapper paths.

Verification:
- `node --check functions/handlers/zoom.js && node --check functions/handlers/zoom_hub_bot.js && node --check services/zoom-hub-bot/routing.js`
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` — 50 passed.
- `cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` — 22 passed, explicitly guarding the already-working desktop/web Meeting SDK path.
- `cd services/zoom-hub-bot && npm test` — 20 passed.
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/services/class_video_service.dart lib/core/widgets/zoom_meeting_screen_io.dart lib/core/widgets/zoom_meeting_screen_web.dart packages/flutter_zoom_meeting_wrapper/lib` — passed.
- `flutter test packages/flutter_zoom_meeting_wrapper/test` — 5 passed.
- `git diff --check` — passed.

Not deployed / not live-tested:
- No Firebase Functions, Hostinger web, VPS bot, Android, or iOS deploy was run in this session.
- Native Zoom SDK binaries are still absent locally, so native Android/iOS builds were not run.
- Physical-device acceptance remains required before release: Android and iOS native joins, correct breakout routing, shared-screen receive, screen-share send, clean roster/no-show presence, and safe Leave behavior.

## 26. iPhone native-build attempt — 2026-07-05

Goal: start the lowest-cost iOS physical-device test without disturbing the working desktop/web Zoom classroom path and without unnecessary clean/rebuild churn on the storage-constrained Mac.

Device/build context:
- Physical test device was available: `Hashim's iphone 17 pro max (wireless)` on iOS 27.0.
- Xcode was available and automatic signing selected team `GRKB7BXVZK`.
- The machine had limited free space, so only generated caches were removed before the first run (`build`, `.dart_tool`, and Xcode `DerivedData`), then `flutter pub get` was rerun. No Hostinger web build/deploy, Firebase deploy, or VPS deploy was attempted.
- The local iOS Zoom SDK download found at `/Users/hashimniane/Downloads/zoom-sdk-ios-6.6.9.29800/lib` was symlinked into `packages/flutter_zoom_meeting_wrapper/ios/Frameworks/` instead of copied, to avoid duplicating the SDK on disk.

iOS dependency setup:
- `cd ios && pod install` first failed because the local CocoaPods trunk cache did not have `Firebase/CoreOnly (= 12.15.0)`.
- `pod install --repo-update` then hit a CocoaPods CDN HTTP/2 framing error.
- The specific Firebase podspec was fetched with HTTP/1.1 into the local CocoaPods cache, after which `cd ios && pod install` completed successfully.
- `flutter config --enable-swift-package-manager` was required because `realtimekit_core_ios` is Swift Package Manager-only. The retry progressed through SPM resolution, Pods, signing, and the Xcode build.

Blocking result:
- The first `flutter run -d 00008150-000242E41191401C --debug --no-resident` failed at the iOS link step with `Framework 'MobileRTC' not found`.
- Inspection showed the local Zoom SDK package was incomplete/corrupt for `MobileRTC.xcframework`: `Info.plist` declared `BinaryPath = MobileRTC.framework/MobileRTC`, but `/Users/hashimniane/Downloads/zoom-sdk-ios-6.6.9.29800/lib/MobileRTC.xcframework/ios-arm64/MobileRTC.framework/` contained headers/resources and no `MobileRTC` binary. `MobileRTCScreenShare.xcframework` and `zoomcml.xcframework` did contain binaries.
- This was not a Flutter routing-code failure and not a desktop/web regression.

Follow-up in the same session:
- Downloaded the official Zoom GitHub release asset that matches the local SDK version: `https://github.com/zoom/meetingsdk-ios/releases/download/v6.6.9/zoom-meeting-sdk-iOS.zip`.
- Extracted it to `/Users/hashimniane/Downloads/zoom-sdk-ios-6.6.9-github/zoom-meeting-sdk-iOS` and removed the zip to conserve disk.
- Verified the replacement SDK contains the missing binary: `MobileRTC.xcframework/ios-arm64/MobileRTC.framework/MobileRTC` is a Mach-O arm64 dynamic library.
- Repointed the wrapper symlinks for `MobileRTC.xcframework`, `MobileRTCScreenShare.xcframework`, `MobileRTCResources.bundle`, and `zoomcml.xcframework` to the official GitHub release extraction.
- `cd ios && pod install` completed against the corrected SDK.
- `flutter run -d 00008150-000242E41191401C --debug --no-resident` then built successfully: Xcode build completed in about 94 seconds and installed/launched on the physical iPhone.
- LLDB attach was slow on wireless debugging, so `flutter config --no-enable-lldb-debugging` was set before the successful launch retry. Re-enable with `flutter config --enable-lldb-debugging` only if native debugger attachment is needed.
- Runtime console showed noisy pre-existing errors from old `codex_...` shift test documents missing timestamp fields; no Zoom native join conclusion was drawn from those logs.
- At the user's request, the iPhone app process was stopped after launch verification. `devicectl` was used to terminate the visible process, then a suspended replacement process was killed by PID. The user can relaunch the installed app manually from the iPhone.
- Production function deploy completed for the native routing backend pieces only:
  - `getZoomJoinInfo`
  - `zoomWebhook`
  - `zoomHubBotAssignments`
- No Hostinger web deploy was run, so the already-working desktop/web classroom page was not changed.
- VPS `/opt/alluwal/zoom-hub-bot/routing.js` was backed up and replaced with the native display-alias routing helper. Verification on the VPS found `routingDisplayName` and `displayNameAliases` in the live file.
- Both VPS bot services were active after the update check. Lane 2 had `inRoomOccupants: 0`, so only `zoom-hub-bot@2` was restarted to load the new routing helper. Lane 2 came back active and rejoined `zoom_hub_2026-07-05_1_2`.
- Lane 1 had `inRoomOccupants: 1`, so `zoom-hub-bot@1` was intentionally not restarted to avoid interrupting a live participant. Native alias routing on lane 1 will take effect after that bot naturally reloads or after a safe restart when no one is inside rooms.
- Local storage cleanup removed `build` and almost all Xcode `DerivedData` after the app was installed, recovering space on the constrained Mac. The installed iPhone app remains on the device.

Next retry:
- Continue from the already-installed iPhone app and test a real hub-routed Zoom class. If the selected class is on lane 2, the VPS bot has already loaded the native routing helper. If the selected class is on lane 1 before its next safe reload, native display-name routing may not work until `zoom-hub-bot@1` is restarted with no in-room occupants.
- Confirm native Zoom opens, the participant display name includes the class-scoped `#<token>`, the bot moves the phone into the correct breakout room, shared-screen receive works, native screen share works, Leave exits only the participant, and presence/no-show rows use the clean real name.
- If disk drops below a safe margin before another rebuild, remove only `build/ios` or `~/Library/Developer/Xcode/DerivedData`; avoid a broad clean unless required.

## 27. iPhone native launch debugger fix — 2026-07-05

Goal: fix the physical iPhone launch that appeared stuck on the splash screen while preserving the working desktop/web Zoom classroom path.

Findings:
- The app was not hanging in Flutter. Xcode had paused the native process at `libsystem_kernel.dylib __abort_with_payload`.
- The useful launch console showed a native pre-Flutter failure path:
  - `FBLPromise` was implemented by both `MobileRTC.framework` and `Runner.debug.dylib`.
  - The abort followed `-[OS_dispatch_mach_msg _setContext:]: unrecognized selector`.
- This matches a native Zoom Meeting SDK + Firebase/Google Promises collision exposed during Xcode's debug launch. The prior Xcode launch also injected debugger/diagnostic dylibs such as Main Thread Checker and View Debugger support.

Changes made:
- Removed a stale generated `CONFIGURATION_BUILD_DIR` override from local generated Flutter iOS files so Xcode and Flutter agree on DerivedData build output. The local generated files are not source-controlled.
- Updated `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` Run action to launch with `Xcode.IDEFoundation.Launcher.PosixSpawn` instead of LLDB and to set `disableMainThreadChecker = YES`.
- No Dart, web, Firebase Functions, Hostinger, or VPS bot behavior was changed in this fix.

Verification:
- `xmllint --noout ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` passed.
- Local `xcodeproj` parsing confirmed the Run action now has `selectedDebuggerIdentifier = ""`, `selectedLauncherIdentifier = Xcode.IDEFoundation.Launcher.PosixSpawn`, and `disableMainThreadChecker = YES`.
- Incremental Xcode build passed:
  - `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- The paused iPhone Runner process was terminated by PID.
- A no-debug device launch through `devicectl` timed out at the CoreDevice command layer, but the app did start on the phone. Device screenshot capture then showed the native Zoom meeting UI, not the splash screen, with participant UI visible. This verifies the app got past the splash into native Zoom after the scheme/debugger fix.

Not deployed / remaining checks:
- No Hostinger web build/deploy was run.
- No Firebase Functions deploy was run.
- The `FBLPromise` duplicate warning remains a native binary compatibility risk between Zoom's bundled Objective-C classes and Firebase/Google Promises. The current fix avoids the Xcode debugger-diagnostic abort path for physical-device testing, but release acceptance still needs a clean physical-device pass through join, breakout routing, shared-screen receive, native screen share, Leave, and presence/no-show behavior.
- If native release builds still crash outside Xcode, the next fix should address the underlying binary collision directly rather than further scheme settings.

## 19. Native Mobile breakoutUnassigned Routing Fix — 2026-07-05

Live physical-iPhone acceptance found native mobile participants stranded in the
hub main session (not routed to their class breakout room). See
`docs/mobile-screenshare-optionA-handoff.md` §11 for the full write-up.

Root cause: participants who join after breakout rooms are already open land in
Zoom's `breakoutUnassigned` pool, separate from the main-session `unassigned`
list. `whoNeedsToMoveWhere` in `services/zoom-hub-bot/routing.js` only scanned
room participants + `unassigned`, so `breakoutUnassigned` occupants (always the
case for native mobile: no `customerKey`, join after rooms open) were never
considered for routing.

Fix: added `normalizeBreakoutUnassigned()` and made `whoNeedsToMoveWhere` process
that bucket via display-name alias. Added a regression test reproducing the
production case. `cd services/zoom-hub-bot && npm test` — 21 passed.

Deploy: uploaded `routing.js` to the VPS (timestamped backup kept), restarted
`zoom-hub-bot@2` then `zoom-hub-bot@1` (both empty of humans at the time) so both
lanes run the fix. Verified live on lane 2: native `test student #wmCwjEzH` was
assigned into `dl8VcH | Billing Test` (room reached participantCount 2 with the
web teacher; `breakoutUnassigned` drained). Shared-screen receive on the mobile
app confirmed working.

Not deployed / remaining:
- No Firebase Functions or Hostinger web deploy (routing.js is VPS-only).
- Screen-share SEND from iOS still needs a Broadcast Upload Extension + App Group
  (framework `MobileRTCScreenShare.xcframework` is vendored but unwired).
- Clean Leave + presence/no-show acceptance for the native path still to run.

## 28. Web Zoom Leave Return URL Hotfix — 2026-07-06

Symptom:
- After clicking the custom red Leave button in the web Zoom classroom, the user
  could return to an app URL that still contained a class join parameter. On a
  full Flutter web reload, `JoinLinkService.initFromUri(Uri.base)` consumed that
  link again and reopened Zoom, so the user saw the connecting/waiting state
  loop instead of landing back in the app.

Change:
- Added `JoinLinkService.removeJoinParameters(Uri)` to strip `joinShift` and
  `guestShift` from both normal query strings and hash-route query strings.
- Updated `lib/core/widgets/zoom_meeting_screen_web.dart` so `returnUrl` passed
  into `web/zoom_meeting.html` uses the cleaned app URL instead of the raw
  current browser URL.
- Added `test/core/services/join_link_service_test.dart` coverage for direct
  join URLs, guest join URLs, and hash-route join URLs.

Verification:
- `flutter test test/core/services/join_link_service_test.dart` passed.
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/services/join_link_service.dart lib/core/widgets/zoom_meeting_screen_web.dart` passed.
- `git diff --check -- lib/core/services/join_link_service.dart lib/core/widgets/zoom_meeting_screen_web.dart test/core/services/join_link_service_test.dart` passed.

Not deployed / remaining:
- No Hostinger web build/deploy was run in this session.
- No Firebase Functions or VPS bot deploy was needed.
- No live class was joined for this small leave-return fix.

## 29. Native iPhone Leave Waiting-HUD Cleanup Build — 2026-07-06

Follow-up to `docs/mobile-screenshare-optionA-handoff.md` §13.

Change:
- Updated `packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`
  so native iOS Zoom meeting end cleanup runs repeatedly after `.ended`/`.idle`
  rather than once.
- Each cleanup pass hides leftover non-app Zoom windows, dismisses presented
  controllers, restores the Flutter host window, and emits `onMeetingEnded` only
  once. Passes are scheduled at 0, 0.25, 0.75, 1.5, and 2.5 seconds to catch the
  delayed native MobileRTC "Waiting..." HUD seen after tapping Leave.

Verification/build:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift` passed.
- `flutter pub get && cd ios && pod install` passed.
- `flutter build ios --release --build-name=99.0.0 --build-number=9900` passed
  and produced `build/ios/iphoneos/Runner.app`.
- Installed and launched on `Hashim's iphone 17 pro max`
  (`00008150-000242E41191401C`) via `xcrun devicectl`.

Not deployed / remaining:
- No Firebase Functions, Hostinger web, or VPS bot deploy was run.
- No live Zoom leave test was run after this install; verify on the phone by
  joining a class, tapping Zoom Leave, and confirming the "Waiting..." HUD clears
  and the app returns to the class screen.

## 30. Stronger Native iPhone Waiting-HUD Cleanup Build — 2026-07-06

Follow-up after the §29 install still left MobileRTC's "Waiting..." HUD visible
on the phone after tapping Leave.

Change:
- `packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`
  now calls `MobileRTC.shared().cleanup()` once after meeting `.ended`/`.idle`.
- The repeated cleanup pass now also scans/removes residual Zoom/MobileRTC/HUD
  UIKit views from the restored app window/root view, including class names
  containing `MobileRTC`, `Zoom`, `ZM`, `ZP`, `MBProgressHUD`, and UIKit
  label/button/accessibility text containing `Waiting`.
- Cleanup pass timings are 0, 0.15, 0.35, 0.75, 1.5, 2.5, 4.0, and 6.0 seconds.

Verification/build:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift` passed.
- `flutter build ios --release --build-name=99.0.0 --build-number=9901` passed
  and produced `build/ios/iphoneos/Runner.app`.
- Installed and launched on `Hashim's iphone 17 pro max`
  (`00008150-000242E41191401C`) via `xcrun devicectl`.

Not deployed / remaining:
- No Firebase Functions, Hostinger web, or VPS bot deploy was run.
- Re-test the Leave flow on the phone with the `9901` build.

## 20. "Nobody in the main session" hardening — 2026-07-06

Invariant reinforced: a participant the bot cannot map to a class room used to be
left sitting in the hub main session (routing.js `whoNeedsToMoveWhere` did
`if (!targetRoomName) continue;`). Fix: any NON-host participant lingering in the
main session (or breakoutUnassigned pool) with no resolvable class room is now
swept into a **Spare room** instead of being left in main. The host controller
bot is explicitly excluded (`isHostBot`: reserved uid `zoom_hub_bot*`, host/bot
flags, or "hub bot" display name). Matched participants are unaffected — including
the "admin creates a room while students wait in main" case, which already swept
them into their room the moment it appears (now covered by a regression test).

Tests: `services/zoom-hub-bot` — 24 passed (added: unmatched→spare, host-bot-never-
swept, students-waiting-in-main→room-on-create). Deployed routing.js to the VPS
(both lanes, backup kept) and restarted both idle bots.

IMPORTANT limitation (separate lifecycle issue, NOT fixed here): this only applies
while the bot is actively looping IN the meeting. A hub Zoom meeting is persistent;
after a block ends the bot leaves, but the meeting stays joinable. A user rejoining
that stale meeting off-block lands in the main session with NO bot present to sweep
them. Observed 2026-07-06: lane-2 bot last routed at 00:13 ET, yet a web client
rejoined "Billing Test" and sat in main. Options to close this: (a) end hub meetings
when the block ends; (b) keep/rejoin the bot whenever any participant is present
(presence-driven via webhook); (c) gate off-block joins in getZoomJoinInfo so a
stale hub meeting is never handed out. Needs an owner decision.

## 21. Eager hub provisioning on shift write — 2026-07-06

Requirement: creating a Zoom class (shift) — even ad-hoc, seconds before it
starts — must guarantee the joiner lands in the right breakout room, not the
main session.

Gap before: hubs were provisioned only by `getZoomJoinInfo` on first join and by
`prepareZoomHubs` every 10 min. An ad-hoc shift that created a brand-new hub had a
window where the bot had not joined it yet, so an early joiner sat in main.

Added: `onTeachingShiftWritten` — a `teaching_shifts` `onDocumentWritten` trigger
(functions/handlers/zoom.js, exported in index.js). On create or on a
provisioning-relevant edit, if the shift is Zoom hub-routed and starts within
`[now − 15 min, now + 60 min]` (the same window `prepareZoomHubs` uses), it calls
`_prepareZoomHubForShiftDoc` → `ensureZoomHubMeeting`, writing the hub + this
shift's room immediately. The bot then joins the freshly-written hub on its next
poll, so the room exists before anyone joins.

Loop safety: `ensureZoomHubMeeting` writes hub metadata (hub_meeting_id,
zoom_meeting_id, zoom_hub_lane_index, zoom_join_url, …) back onto the shift doc,
which would re-fire the trigger. Guarded by `_provisioningRelevantChange`, which
compares ONLY fields the ensure never writes (`shift_start`, `teacher_id`,
`video_provider`, `zoom_enabled`, `student_ids`); the fallback-to-single path also
flips the shift out of hub routing, so `_usesHubRouting` short-circuits re-fires.

Verified: `functions` — 50 zoom tests pass, `node --check` clean. Deployed
`onTeachingShiftWritten` to `alluwal-academy`. Complements §20 (spare-room sweep so
nobody is ever left in main while the bot is present). Still open: the
persistent-meeting-off-block case (a stale hub the bot has left) — see §20.

## 22. Bot-presence gate on join (close the last gap) — 2026-07-06

Closes the "persistent meeting the bot has left" case: a user joining a hub whose
bot is gone would land in a bot-less main session. `getZoomJoinInfo` already
rejects joins after the class window ends (`assertJoinWindowOrThrow`), and §21's
eager provisioning + §20's spare sweep cover in-window joins. This adds the final
guard: after resolving hub routing, read the hub doc; if its bot `heartbeat_at`
EXISTS but is stale by > `2 × ZOOM_HUB_BOT_STALE_MS` (i.e. > 4 min — bot definitely
gone, watchdog not yet recovered), throw `unavailable` ("Your class is
reconnecting. Please tap Join again in a moment.") and alert admins, instead of
handing out the abandoned hub. A hub with NO heartbeat yet is freshly provisioned
(bot inbound) and is deliberately left alone, so healthy/new classes are never
false-positived. watchZoomHubBots restores the bot within ~2 min, so a retry
succeeds.

Verified: 50 zoom tests pass, node --check clean. Deployed getZoomJoinInfo to
alluwal-academy. Full routing guarantee now: shift write → hub+room provisioned
(§21); join → hub+room+member ensured on demand; bot present or join is bounced
(§22); anyone unmatched swept out of main to a spare room while bot present (§20).

## 23. Native iOS assigned-but-not-joined breakout fix — 2026-07-06

Live symptom: a native iOS student joined lane 2, the bot correctly resolved the
class alias and assigned the user to the target room, but Zoom kept the user in
`breakoutUnassigned` / assigned-not-joined limbo. Repeated host-side follow-up
`moveUserToBreakoutRoom` calls failed with `user not in a room`, then the native
client dropped and rejoined.

Fix is client-side, not bot-side: `MobileRTCBOAttendee.joinBO()` must be called by
the iOS Meeting SDK participant after assignment. The Swift wrapper now consumes
the existing `autoJoinBreakoutRoom` and `breakoutRoomName` method-channel values,
listens for MobileRTC BO attendee/status/switch/update callbacks, and retries
`joinBO()` up to 45 seconds while validating the expected room name whenever Zoom
exposes it.

Verified locally:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`
- `flutter test packages/flutter_zoom_meeting_wrapper/test` — 5 passed.
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/widgets/zoom_meeting_screen_io.dart packages/flutter_zoom_meeting_wrapper/lib`
- `cd ios && pod install`
- `flutter build ios --release --build-name=99.0.0 --build-number=9902`

Installed the resulting `Runner.app` on paired physical iPhone
`Hashim's iphone 17 pro max` (`E7C7C7F2-1872-5B15-B919-391158906FAD`) and launched
it. No Firebase Functions, Hostinger web, or VPS bot deploy was run.

Still required: run a live native join after the `9902` install. Passing evidence
should show the iPhone device log `Alluwal Zoom: attendee joinBO result=true`,
the lane bot log showing the participant leaving `breakoutUnassigned`, and the
native participant entering the target class room without the kick/rejoin
ghost-session loop.

Follow-up `9903` build: the native wrapper no longer treats every
`MobileRTCMeetingState.idle` callback as a completed leave. It now only uses the
idle cleanup path after a real `.disconnecting` state, preventing a transient BO
transfer state from calling `MobileRTC.shared().cleanup()` and tearing down the
meeting. The wrapper also logs MobileRTC meeting/BO state transitions for the
next device-side diagnosis.

Verified locally:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`
- `flutter build ios --release --build-name=99.0.0 --build-number=9903`
- Installed/launched on paired physical iPhone
  `Hashim's iphone 17 pro max` (`E7C7C7F2-1872-5B15-B919-391158906FAD`).

Live lane-2 evidence after `9903` install:
- Native `test student #RpxOs2WG` entered `breakoutUnassigned`, was assigned to
  `EV5fLi | Billing Test`, then `breakoutUnassigned` drained and the room stayed
  at `participantCount: 2`.
- Native `nene nane #4dlaQ9Jo` followed the same pattern; the host follow-up move
  returned `user already in the target room`, then `breakoutUnassigned: []`.
- The old repeated `user not in a room` loop did not recur in those checks.

Still open: if the phone UI still exits while the bot shows the participant in
the room, capture device-side logs for the new `Alluwal Zoom: meeting state
raw=...` lines. No Firebase Functions, Hostinger web, or VPS bot deploy was run.

Follow-up `9905` build: the native wrapper now also treats
`MobileRTCMeetingState.ended` during a `JoinBO` transfer as provisional instead
of immediately cleaning up MobileRTC. It tracks `breakoutTransferInProgress`,
defers cleanup for up to 24 seconds when BO is still active and the user did not
explicitly disconnect, and logs `onMeetingEndedReason` plus every skipped or
called `joinBO()` attempt. This is intended to cover the observed native device
sequence `JoinBO -> Reconnecting -> Ended` while the host-side bot already sees
the participant in the target room.

Verified locally:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/widgets/zoom_meeting_screen_io.dart packages/flutter_zoom_meeting_wrapper/lib`
- `flutter test packages/flutter_zoom_meeting_wrapper/test` — 5 passed.
- `flutter build ios --release --build-name=99.0.0 --build-number=9905`
- Installed/launched on paired physical iPhone
  `Hashim's iphone 17 pro max` (`E7C7C7F2-1872-5B15-B919-391158906FAD`).

Live lane cleanup before next native retest:
- A subsequent `9904`/pre-reset phone attempt showed `Connecting ->
  WaitingForHost -> Disconnecting -> Ended`, and lane-2 bot logs did not show the
  native alias in the attendee list. That was a stale meeting/lane-state problem,
  not the original assigned-not-joined BO symptom.
- Confirmed lane 2 had only the hub bot present, ended Zoom meeting
  `83942421689` via Zoom REST, restarted `zoom-hub-bot@2`, and confirmed the bot
  rejoined as host, created/opened 10 breakout rooms, and had only the lane bot in
  the latest routing snapshots with `breakoutUnassigned: []`.

Still open after `9905`: run one fresh native iOS join against the reset lane and
capture both sides. Passing evidence should show the device no longer cleans up
on the `JoinBO` transfer, the bot routes the new native alias to
`EV5fLi | Billing Test`, `breakoutUnassigned` drains, and the phone remains in
the target breakout room.

Follow-up `9906` build: after the phone still returned all the way to the app
instead of staying in Zoom, the native wrapper now treats `Ended`/`Idle` during a
breakout transfer as recoverable even when MobileRTC temporarily reports BO
status as invalid. Cleanup is deferred for up to 65 seconds while a `JoinBO`
transfer is active, and if the SDK settles back into the main meeting the wrapper
retries the BO join instead of popping the Flutter screen. The wrapper also
stores the BO switch request room id/name, attempts the assistant `joinBO(boId)`
fallback when available, logs the current BO user status through the data helper,
tracks user-tapped Leave separately, and passes the native `customerKey` into
`MobileRTCMeetingJoinParam`.

Verified locally:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/widgets/zoom_meeting_screen_io.dart packages/flutter_zoom_meeting_wrapper/lib`
- `flutter test packages/flutter_zoom_meeting_wrapper/test` — 5 passed after one
  Flutter startup-lock retry.
- `flutter build ios --release --build-name=99.0.0 --build-number=9906`

Installed and launched build `9906` on paired physical iPhone
`Hashim's iphone 17 pro max` (`E7C7C7F2-1872-5B15-B919-391158906FAD`). The first
install attempt failed with a transient CoreDevice connection reset; the retry
succeeded. No Firebase Functions, Hostinger web, or VPS bot deploy was run.

Still open after `9906`: run one fresh native join and capture the `Alluwal Zoom:`
device logs plus lane-2 bot snapshot. The key line to confirm is whether
`Ended`/`Idle` during `JoinBO` is now deferred instead of invoking
`onMeetingEnded` and returning the user to the Flutter app.

Follow-up clean-name deploy: after build `9906` routed successfully, the native
Zoom UI still showed the deterministic routing suffix, for example
`nene nane #9P49KaDa`. Live lane-2 bot logs confirmed the iOS Meeting SDK now
exposes the hidden `customerKey` to the web bot (`uid:
zh_9P49KaDaPyFGnkuUdkNPYcJf`), so the visible suffix is no longer required for
current native builds. `getZoomJoinInfo` now returns the clean real display name
for `displayName` and `nativeDisplayName`, while continuing to write the unique
`routingDisplayName` and aliases to the hub member doc for old-build fallback.

Verified locally:
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` — 50 passed.
- `cd functions && npm test -- --runInBand tests/zoom_handler.test.js tests/zoom_meeting_html.test.js` — 72 passed.

Deployed to production:
- `env -u DEBUG firebase deploy --only functions:getZoomJoinInfo --project alluwal-academy`
- Deploy completed successfully for `getZoomJoinInfo(us-central1)`.

Still open after clean-name deploy: retest native iOS join on installed build
`9906`. Expected result: the phone remains routed successfully and Zoom shows the
clean participant name without the `#<token>` suffix.

Follow-up `9907` build: native iOS Leave handling was changed after the user
reported that tapping Zoom's native Leave control sometimes only hid/dismissed
the controls before the button could be activated reliably. The wrapper now
intercepts `onClickedEndButton(_:end:)`, marks an intentional user leave, cancels
BO auto-join retries, clears BO transfer state, calls
`MobileRTCMeetingService.leaveMeeting(with: LeaveMeetingCmd(rawValue: 0)!)`
directly, and returns `true` so Zoom does not run the flaky default leave-button
UI path.

Verified locally:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/widgets/zoom_meeting_screen_io.dart packages/flutter_zoom_meeting_wrapper/lib`
- `flutter test packages/flutter_zoom_meeting_wrapper/test` — 5 passed after one
  Flutter ephemeral cleanup retry.
- `flutter build ios --release --build-name=99.0.0 --build-number=9907`

Installed and launched build `9907` on paired physical iPhone
`Hashim's iphone 17 pro max` (`E7C7C7F2-1872-5B15-B919-391158906FAD`). No
Firebase Functions, Hostinger web, or VPS bot deploy was run for this native
leave fix.

Still open after `9907`: retest native iOS Leave from inside a breakout room.
Expected result: one tap on the native Zoom Leave button leaves the meeting and
returns to the app without the controls disappearing/reappearing first.

## 34. Admin Routing Control Status Page — 2026-07-06

Problem: the Claude artifact/mock "Routing Control" screen was displaying
demo/replay-style numbers, not live routing state. There was no existing admin
page in the codebase with that title, and browser clients could not safely call
the VPS bot endpoints because those endpoints expose host-only credentials and
require the bot secret.

Change made in source:
- Added admin-only callable `getZoomHubRoutingStatus` in
  `functions/handlers/zoom.js`, exported from `functions/index.js`.
- The callable reads `hub_meetings`, each hub's `members` subcollection,
  associated `teaching_shifts`, and recent `system_alerts` with
  `type == zoom_hub`, then returns a sanitized snapshot only: hub id, lane,
  host account, meeting number, bot status, heartbeat freshness, room/member
  counts, scheduled-now classes, and recent incidents. It intentionally does
  **not** return ZAK, SDK signatures, passcodes, or the bot key.
- Added Next admin page `/admin/routing-control/` via
  `apps/web/src/components/RoutingControlAdmin.tsx` and navigation entry
  "Routing Control" in the admin shell.
- The page labels the available live counters as what they actually are:
  in breakout rooms, scheduled now, rooms open, last routing-loop actions,
  target members, and open incidents. It does not show fake "24h routed" or
  "demo replay" data.

Verified locally:
- `node --check functions/handlers/zoom.js && node --check functions/index.js`
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` — 52 passed.
- `cd apps/web && npm run typecheck`
- `cd apps/web && npm run build` — succeeded; generated static route
  `/admin/routing-control`.

Deploy status:
- `env -u DEBUG firebase deploy --only functions:getZoomHubRoutingStatus --project alluwal-academy`
  completed successfully and created
  `getZoomHubRoutingStatus(us-central1)`.
- The Next web page was not deployed to Hostinger. To expose
  `/admin/routing-control/` publicly, deploy the Next web app through the
  repository's Hostinger web packaging/deploy path.

Follow-up — 2026-07-07:
- `apps/web/src/components/RoutingControlAdmin.tsx` was refreshed for mobile
  operations use: sticky compact status header, swipeable metric cards on phone
  widths, clearer lane/hub cards, and phone-friendly class/incident lists.
- Added `apps/web/src/components/OpsSubdomainRedirect.tsx` and wired it into the
  Next home page so `ops.alluwaleducationhub.org/` (also `live.`, `routing.`,
  or `control.`) redirects to `/admin/routing-control/` when the exported Next
  app is served on that subdomain.
- Verification: `cd apps/web && npm run typecheck` and
  `cd apps/web && NEXT_PUBLIC_FIREBASE_ENV=prod npm run build` passed; a
  phone-width static-export screenshot of the signed-out access state was
  captured and reviewed locally. The production static export is in
  `apps/web/out/`.
- Hostinger ops-subdomain deploy completed to
  `/home/u161013520/domains/alluwaleducationhub.org/public_html/ops/`.
  Backup created:
  `public_html/ops_public_html_before_20260707_143331`. Remote verification
  found `index.html`, `_next/`, and `admin/routing-control/index.html`, and an
  origin HTTP check with forced host resolution returned the deployed
  routing-control HTML.
- Public DNS for `ops.alluwaleducationhub.org` was not resolving at deploy
  time. The apex domain uses Cloudflare nameservers (`connie.ns.cloudflare.com`
  and `ram.ns.cloudflare.com`), so the ops phone URL still needs a Cloudflare
  DNS record before it will load publicly.
- After confirming `live.alluwaleducationhub.org` is retired from LiveKit use,
  the same production export was also deployed to Hostinger's live folders:
  `/home/u161013520/domains/alluwaleducationhub.org/public_html/live/` and the
  legacy `/home/u161013520/domains/alluwaleducationhub.org/public_html_77/live/`.
  Backups created:
  `public_html/live_public_html_before_20260707_210813`,
  `public_html/ops_public_html_before_20260707_210718`, and
  `public_html_77/live_public_html_before_20260707_210718`.
- Forced-origin verification for `live.alluwaleducationhub.org` against
  Hostinger returned HTTP 200 for `/admin/routing-control/`, but public
  Cloudflare verification still returned 522. The existing Cloudflare `live`
  record still points at the old/unreachable origin and must be edited to the
  Hostinger IP before phones can load the live subdomain.
- Added `apps/web/public/.htaccess` so root visits on `live.`, `ops.`,
  `routing.`, and `control.` redirect server-side to `/admin/routing-control/`.
  Rebuilt with `NEXT_PUBLIC_FIREBASE_ENV=prod npm run build` and redeployed to
  the Hostinger `ops`, current `live`, and legacy `live` folders. Backups:
  `ops_public_html_before_20260707_211642`,
  `live_public_html_before_20260707_211642`, and
  `public_html_77/live_public_html_before_20260707_211642`.
- After the Cloudflare `live` DNS record was changed to the Hostinger IP,
  public verification passed: `https://live.alluwaleducationhub.org/` returned
  HTTP 302 to `/admin/routing-control/`, and
  `https://live.alluwaleducationhub.org/admin/routing-control/` returned HTTP
  200.
- Added admin-only `getZoomHubCapacityForecast` callable and a mobile forecast
  card on the routing-control page. The forecast reads upcoming Zoom teaching
  shifts, applies the same hub routing/lane/block rules as `getZoomJoinInfo`,
  and reports daily shift totals, busiest hub blocks, lane room pressure,
  peak concurrent classes, estimated participant-seat pressure, warning date,
  and hard "add another Zoom account before this block" date.
- Current production forecast at deploy time: no additional Zoom account is
  needed in the generated schedule through `2026-09-15`. Busiest block:
  `2026-07-12 12:00-17:00`, 35 class rooms total, lane 1 = 23 rooms, lane 2 =
  12 rooms, peak concurrent classes = 14, lane 1 peak seats = 27, lane 2 peak
  seats = 9.
- Verification/deploy: `node --check functions/handlers/zoom.js &&
  node --check functions/index.js`, production read-only forecast helper smoke,
  `cd apps/web && npm run typecheck`,
  `cd functions && npm test -- --runInBand tests/zoom_handler.test.js` (52
  passed), `cd apps/web && NEXT_PUBLIC_FIREBASE_ENV=prod npm run build`.
  Deployed `getZoomHubCapacityForecast` to `alluwal-academy`, redeployed the
  Next export to Hostinger `ops`, current `live`, and legacy `live` folders.
  Backups: `ops_public_html_before_20260708_133149`,
  `live_public_html_before_20260708_133149`, and
  `public_html_77/live_public_html_before_20260708_133149`. Public verification
  passed for `https://live.alluwaleducationhub.org/` and
  `/admin/routing-control/`; deployed JS contains `getZoomHubCapacityForecast`.
- Zoom capacity verification update, 2026-07-08: official Zoom Support now
  documents Pro/default meeting capacity as 100 participants, Large Meeting
  add-ons as separate 500+ participant capacity purchases, and meeting breakout
  rooms as up to 100 rooms with participants still limited by the host meeting
  capacity when no Large Meeting add-on exists. The Zoom API check for
  `billing@alluwaleducationhub.org` and `support@alluwaleducationhub.org`
  returned licensed users with `meetingCapacity: 100` and no Large Meeting
  add-on value, so the operational forecast should treat each lane as 99
  scheduled human seats after reserving one seat for the host bot. The room
  forecast remains on the existing production guard of 43 class rooms per lane
  plus 5 spare rooms, not the theoretical 100-room Zoom maximum.
- Follow-up deploy, 2026-07-08: `getZoomHubCapacityForecast` was updated and
  redeployed to `alluwal-academy`, the ops Next export was rebuilt with
  `NEXT_PUBLIC_FIREBASE_ENV=prod npm run build`, and the export was uploaded to
  Hostinger `ops`, current `live`, and legacy `live` folders. Backups:
  `ops_public_html_before_20260708_135550`,
  `live_public_html_before_20260708_135550`, and
  `public_html_77/live_public_html_before_20260708_135550`. Verification:
  `node --check functions/handlers/zoom.js && node --check functions/index.js`,
  Zoom API account-capacity smoke (`meetingCapacity: 100`, `largeMeeting:
  null` for both lane hosts), production read-only forecast helper smoke,
  `cd apps/web && npm run typecheck`, `cd functions && npm test --
  --runInBand tests/zoom_handler.test.js` (52 passed), public HTTP 200 for
  `https://live.alluwaleducationhub.org/admin/routing-control/`, deployed JS
  contains `humanParticipantCapPerLane`, and local `.next` cache was removed.
- Follow-up deploy intent, 2026-07-09: `live.alluwaleducationhub.org` is now the
  public Next website host rather than a routing-control shortcut. The root
  redirect remains only for `ops.`, `routing.`, and `control.`.

## 35. Android Native Zoom Screen-Share Parity Prep — 2026-07-06

Goal: prepare Android native Meeting SDK joins for the same classroom behavior
as current iOS native builds without changing the working web/iOS paths.

Source changes:
- `packages/flutter_zoom_meeting_wrapper/android/.../FlutterZoomMeetingWrapper.kt`
  now passes Flutter's `customerKey` into `JoinMeetingOptions.customer_key`
  (trimmed to Zoom's documented 35-character limit; current `zh_...` hub keys
  are 27 characters), while joining with the clean display name.
- Android join options explicitly keep sharing enabled (`no_share = false`) and
  call `setHideShareButtonInMeetingToolbar(false)` before join, so Zoom's
  default native Share control can be used.
- Android Gradle now uses Zoom's official Maven Central SDK artifact
  `us.zoom.meetingsdk:zoomsdk:6.4.10`, avoiding a local `mobilertc.aar` copy on
  the disk-constrained release machine. Zoom Android SDK `6.6.9` and `7.0.5`
  were tried first but require minSdk 28; the app currently stays on minSdk 26.
- The Android wrapper now registers Zoom meeting/BO listeners and calls
  `IBOAttendee.joinBo()` when the SDK reports attendee BO rights or a BO switch
  request. The retry loop is bounded and validates the expected breakout room
  name whenever Zoom exposes it.
- `android/app/src/main/AndroidManifest.xml` and the Android plugin manifest now
  include Zoom's Android 14 foreground-service permissions for microphone, media
  playback, media projection, and connected devices.
- The app manifest now removes the colliding merged default `FileProvider` and
  declares app-owned subclasses for Zoom and RealtimeKit, preserving
  `${applicationId}.fileprovider` for Zoom and `${applicationId}.rtkfileprovider`
  for RealtimeKit.

Docs/tests:
- Updated `docs/zoom-native-mobile-sdk-runbook.md` and
  `docs/mobile-screenshare-optionA-handoff.md` so native routing is documented
  as current customer-key-first behavior, with display-name aliasing only as an
  old-build fallback.
- Added Dart method-channel coverage that asserts the native join payload
  includes `customerKey`, breakout room fields, and `autoJoinBreakoutRoom`.

Verified locally:
- `flutter test packages/flutter_zoom_meeting_wrapper/test` — 5 passed.
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/widgets/zoom_meeting_screen_io.dart packages/flutter_zoom_meeting_wrapper/lib`
  — no issues found.
- `git diff --check -- android/app/src/main/AndroidManifest.xml docs/zoom-hub-bot-plan.md docs/zoom-native-mobile-sdk-runbook.md docs/mobile-screenshare-optionA-handoff.md packages/flutter_zoom_meeting_wrapper/test/flutter_zoom_meeting_wrapper_method_channel_test.dart`
  — passed.
- Targeted trailing-whitespace scan on the touched Android wrapper/docs/test
  files — no matches.
- `flutter build appbundle --release --build-name=1.1.3 --build-number=11301`
  — built `build/app/outputs/bundle/release/app-release.aab`.
- Copied release artifact to `releases/android/alluwal-1.1.3-11301.aab`
  (436M), SHA-256
  `1396c3dc2831b08fc50bf053b8f3f435c12a2d56e230355f883c782e1087020b`.
- `jarsigner -verify -verbose -certs releases/android/alluwal-1.1.3-11301.aab`
  — exit code 0; signer certificate expires on 2053-06-19.

Not deployed / not live-tested:
- No Firebase Functions, Hostinger web, VPS bot, iOS code, or existing web Zoom
  classroom path was changed for this Android prep.
- Physical Android acceptance remains required before wider rollout:
  hub-routed role-0 join, clean display name, bot sees `customerKey`, BO entry
  succeeds, received screen share renders, Android screen share can start from
  Zoom's native Share control, and Leave does not end the hub.

## 36. Presenter Participant Visibility During Screen Share — 2026-07-06

Problem: when a user is actively sharing their screen, the presenter needs to
keep participant video/controls visible instead of losing sight of the class.
This is a meeting-layout issue only; routing, breakout assignment, bot behavior,
and class timing were not changed.

Source changes:
- `web/zoom_meeting.html` now explicitly keeps Web SDK picture-in-picture
  enabled (`disablePictureInPicture: false`) alongside the existing
  participant-friendly share settings (`showPureSharingContent: false`,
  `videoDrag: true`, `videoHeader: true`, `defaultView: 'gallery'`).
- Android native Meeting SDK setup now disables "no video tile on shared
  screen", keeps no-video users visible, keeps meeting controls visible, and
  leaves the Share button enabled. It also attempts newer Zoom settings
  (`setLargeShareVideoSceneEnabled`, `setVideoOnWhenMyShare`) by reflection when
  a future SDK exposes them, while compiling against the current minSdk-26-safe
  `us.zoom.meetingsdk:zoomsdk:6.4.10`.
- iOS native Meeting SDK setup now sets `thumbnailInShare = true`, keeps the
  video/participant/share/more controls and bars visible, keeps no-video users
  visible, and disables hiding self view before joining.
- `functions/tests/zoom_meeting_html.test.js` now asserts the web page keeps
  `showPureSharingContent: false` and `disablePictureInPicture: false`.

Verified locally:
- `flutter test packages/flutter_zoom_meeting_wrapper/test` — 5 passed.
- `cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` —
  22 passed.
- `cd android && ./gradlew :flutter_zoom_meeting_wrapper:compileReleaseKotlin --no-daemon --max-workers=1`
  — passed. The first compile attempt caught that Zoom Android SDK 6.4.10 lacks
  two newer methods; those calls are now reflection-only and the wrapper
  compiles.
- `git diff --check -- web/zoom_meeting.html functions/tests/zoom_meeting_html.test.js packages/flutter_zoom_meeting_wrapper/android/src/main/kotlin/com/example/flutter_zoom_meeting_wrapper/FlutterZoomMeetingWrapper.kt packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`
  — passed.

Deploy status:
- Ran `./scripts/deploy_hostinger_web.sh`; it built Flutter web release
  cache-busting version `143`, backed up Hostinger
  `public_html_before_v143_20260706_160256`, uploaded `build/web/`, verified
  remote cache-busting references, and verified the public site.
- Extra public verification:
  `https://alluwaleducationhub.org/zoom_meeting.html?verify=143` contains
  `screenShare: true`, `sharingMode: 'both'`, `showPureSharingContent: false`,
  and `disablePictureInPicture: false`.

Not deployed / not live-tested:
- No Firebase deploy, App Store build, Play build, VPS bot restart, or live Zoom
  class test was run for this narrow layout fix.
- Native iOS/Android still need new app builds before their native share-layout
  settings reach users.
- Physical acceptance still needs one presenter per surface: web desktop, iOS
  native, and Android native. Expected result: the presenter can still see
  participant video/meeting controls while their screen share is active, and
  classroom routing/Leave behavior remains unchanged.

## 37. Web Presenter Focus Guard Follow-Up — 2026-07-06

Live finding after Hostinger `v143`: the Web SDK init options alone did not fix
the presenter experience on web. The web classroom still lost the presenter’s
view of participants when sharing began.

Deployed `v144` source change, superseded by §38:
- `web/zoom_meeting.html` wrapped `navigator.mediaDevices.getDisplayMedia`
  before Zoom starts sharing. When the browser supports the Screen Capture
  Conditional Focus API, the wrapper injects a `CaptureController` and calls
  `setFocusBehavior('no-focus-change')`, which asks Chrome/Edge to keep the
  classroom tab focused after the screen-share picker instead of switching
  focus to the captured tab/window. The deployed `v144` version also called
  `window.focus()` on the success/error path as a fallback.
- `functions/tests/zoom_meeting_html.test.js` now asserts this focus guard is
  present.

Verified locally:
- `cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` —
  23 passed.
- `git diff --check -- web/zoom_meeting.html functions/tests/zoom_meeting_html.test.js`
  — passed.
- Local Playwright browser harness served `web/zoom_meeting.html` from
  `http://127.0.0.1:8787`, stubbed `getDisplayMedia`, and verified the page:
  installed the guard, injected a controller, called
  `setFocusBehavior('no-focus-change')`, and refocused the classroom after the
  capture path.
- Local Playwright browser support check confirmed `CaptureController` and
  `CaptureController.prototype.setFocusBehavior` are available in the test
  browser on a secure localhost context.

Deploy status:
- Owner approved deployment after local testing. Ran
  `./scripts/deploy_hostinger_web.sh`; it built Flutter web release
  cache-busting version `144`, backed up Hostinger
  `public_html_before_v144_20260706_161756`, uploaded `build/web/`, verified
  remote cache-busting references, and verified the public site.
- Extra public verification:
  `https://alluwaleducationhub.org/zoom_meeting.html?verify=144` contains
  `installScreenShareFocusGuard`,
  `setFocusBehavior('no-focus-change')`,
  `__alluwalFocusGuardInstalled`, `showPureSharingContent: false`, and
  `disablePictureInPicture: false`.

Still open:
- Full live Zoom acceptance still needs a real presenter sharing from web with
  another participant in the same breakout room.

## 38. Web Presenter PiP Flash Follow-Up — 2026-07-06

Live finding after Hostinger `v144`: the presenter saw Chrome picture-in-picture
appear briefly after switching away during screen share, then disappear quickly.
That matches the `v144` fallback path pulling the Zoom tab back into focus after
`getDisplayMedia`; Chrome closes automatic PiP when the original page becomes
visible again.

Source change:
- `web/zoom_meeting.html` still installs the `getDisplayMedia` focus guard and
  still uses `CaptureController.setFocusBehavior('no-focus-change')` where the
  browser supports it.
- The fallback `window.focus()` refocus call was removed so the classroom tab no
  longer immediately cancels PiP when the presenter switches to another tab.
- Zoom video elements are kept eligible for browser PiP by clearing
  `disablePictureInPicture` and `disablepictureinpicture`.
- The page registers
  `navigator.mediaSession.setActionHandler('enterpictureinpicture', ...)` and
  requests PiP for the best visible Zoom video when Chrome asks for automatic
  PiP or when the document becomes hidden.

Verified locally:
- `cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` —
  24 passed.
- Local Playwright browser harness served `web/zoom_meeting.html` from
  `http://127.0.0.1:8788`, stubbed `mediaSession`, a Zoom video element,
  `requestPictureInPicture`, and `window.focus`, then verified: the automatic
  PiP action was installed, the video remained PiP-eligible, the action called
  `requestPictureInPicture()`, and no `window.focus()` call occurred.

Deploy status:
- Owner approved deployment after local testing. Ran
  `./scripts/deploy_hostinger_web.sh`; it built Flutter web release
  cache-busting version `145`, backed up Hostinger
  `public_html_before_v145_20260706_163047`, uploaded `build/web/`, verified
  remote cache-busting references, and verified the public site.
- Extra public verification:
  `https://alluwaleducationhub.org/?verify=145` contains
  `flutter_bootstrap.js?v=145` and `manifest.json?v=145`.
- Extra public verification:
  `https://alluwaleducationhub.org/zoom_meeting.html?verify=145` contains
  `installAutomaticPictureInPicture`,
  `__alluwalAutomaticPictureInPictureInstalled`,
  `setFocusBehavior('no-focus-change')`,
  `navigator.mediaSession.setActionHandler('enterpictureinpicture', ...)`,
  `requestPictureInPicture`, and `disablePictureInPicture: false`.

## 23. Sharer PiP survives tab switches (web) — 2026-07-06

Problem: a web sharer switching tabs saw the Chrome PiP window flash and close,
losing the participant view. Root cause of v144/v145 failures: they called
requestPictureInPicture() on a ZOOM-OWNED <video>; when the tab hides, the Zoom
SDK pauses/detaches/re-renders its own elements, and Chrome closes a PiP window
the instant its element leaves the DOM. (v144 additionally forced window.focus(),
also fatal to PiP.)

Fix in web/zoom_meeting.html: PiP a page-owned, never-detached hidden <video>
(#alluwalPipVideo, autoPictureInPicture=true, muted/autoplay/playsinline). It is
fed from Zoom's live media — prefers the largest live video srcObject, falls back
to canvas.captureStream(15) of Zoom's rendering canvas (worker-painted under
cross-origin isolation, so frames can continue while hidden) — and a 1s watchdog
hot-swaps srcObject if Zoom tears a stream down; swapping srcObject does not
close the PiP window. Entry: mediaSession 'enterpictureinpicture' (Chrome
auto-PiP, gesture-exempt) + a visibilitychange attempt gated by isScreenSharing()
(tracked via the getDisplayMedia wrapper). Returning to the tab exits our PiP.
The no-focus-change CaptureController guard is retained; window.focus() remains
banned by test.

Tests: functions/tests/zoom_meeting_html.test.js — replaced the stale PiP test
with one pinning the owned-element invariant (bans video.requestPictureInPicture()
on Zoom elements); 24 passed. Deployed zoom_meeting.html directly to Hostinger
public_html (remote .bak kept) and verified the live page serves the new markers.

§23 addendum (same day, v146): owning the PiP element was not sufficient — two
other actors could still steal/kill PiP. (a) Chrome auto-PiP may pick any
eligible playing video, including a doomed Zoom-owned one, so Zoom videos are now
PiP-DISABLED (disablePictureInPicture = true — the inverse of v145) leaving the
owned element as the only candidate. (b) The Zoom SDK loads after our script and
can replace the 'enterpictureinpicture' mediaSession handler (last registration
wins), so ours is re-asserted every 1.5s, which also pre-warms the owned element
with live frames while sharing and re-feeds it while PiP is open. Added
leavepictureinpicture re-entry while hidden + sharing. Deployed as web build
v146 through ./scripts/deploy_hostinger_web.sh (per repo rule — no more direct
scp of the file); live page verified. Tests: 24 passed.

§23 addendum 2 (v147): auto-PiP proved unreliable on the tested machine — with
all code-level killers fixed (v146), Chrome simply never opened the window,
consistent with its auto-PiP eligibility rules (requires active mic/camera
capture + granted auto-PiP permission; screen-share-only sessions may never
qualify). Added the deterministic path: a "Keep participants visible" button
(#alluwalPipButton) shown while isScreenSharing(); clicking is a real user
gesture, so requestPictureInPicture() on the owned element is guaranteed. The
page no longer auto-exits PiP when the tab becomes visible (one gesture keeps
the floating view for the whole share; Chrome-managed auto-PiP windows still
auto-close themselves). Auto-PiP remains wired as a bonus. Deployed v147 via
./scripts/deploy_hostinger_web.sh; live page verified; 24 tests pass.

§23 addendum 3 (v149): live testing showed the floating view could still select
the presenter's shared tab/screen surface instead of the participant camera tile.
Fix: the PiP source selector now rejects the active `getDisplayMedia` share
stream by track id, penalizes large/shared-content canvases while sharing, and
prefers participant-sized video/canvas elements whose DOM context looks like
participant/gallery/video/camera/thumbnail. The share-flow wrapper also attempts
to open the owned PiP element immediately after Zoom calls `getDisplayMedia`, so
the participant feed is prepared before Chrome moves focus to the shared tab.
Local Playwright harness verified a full-size shared-content canvas loses to a
smaller participant canvas, and `bestZoomCanvasStream()` captures the participant
canvas, not the shared surface. Tests: `cd functions && npx jest
tests/zoom_meeting_html.test.js --runInBand` — 24 passed; `git diff --check`
passed. Deployed v149 via `./scripts/deploy_hostinger_web.sh`; backup
`public_html_before_v149_20260706_171714`. Live verification confirmed
`?v=149`, `main.dart.js?v=149`, the participant selector markers, and no forced
`window.focus()` fallback. Live browser smoke check on `zoom_meeting.html?verify=149`
showed no page-script initialization error; the only terminal Zoom error was the
expected fake-signature rejection from the smoke-test URL.

§23 addendum 4 (v150): live test after v149 reported the button said
"Participant video not ready yet". Root cause: v149 still waited until sharing
was active to feed the owned PiP element; by then Zoom could already have hidden
or rebuilt the participant media node. Fix: add a page-owned hidden
`#alluwalPipCanvas`, capture it with `pipCanvas.captureStream(15)`, continuously
draw the best participant drawable into it even before sharing starts, and set
`#alluwalPipVideo.srcObject` to that owned canvas stream. The `getDisplayMedia`
wrapper now calls `feedPipVideo()` before invoking Zoom's original share flow,
then attempts PiP after the share picker starts. Local Playwright harness
verified `feedPipVideo()` returns true, the owned PiP video has a stream, and the
participant canvas wins over the shared-screen canvas. Tests:
`cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` — 24
passed; `git diff --check` passed. Deployed v150 via
`./scripts/deploy_hostinger_web.sh`; backup
`public_html_before_v150_20260706_172753`. Live verification confirmed `?v=150`,
`main.dart.js?v=150`, `alluwalPipCanvas`, `pipCanvas.captureStream(15)`,
`drawPipCanvasFrame`, `bestZoomDrawableElement`, the pre-share `feedPipVideo()`
call, and no forced `window.focus()` fallback.

§23 addendum 5 (v151): live test after v150 showed the floating view could be a
dark/name tile even though another user's camera tile was visible. Root cause:
the selector still gave too much weight to tile size and could choose a large
avatar/name canvas over a smaller real camera canvas. Fix: add
`mediaFrameQuality()` sampling on a 32x18 hidden canvas; candidates with real
camera-like frame content get a positive `cameraLikeScore`, while mostly dark
avatar/name tiles (`blankAvatarLike`) receive a large penalty. Local Playwright
harness simulated the screenshot layout (small camera tile, large dark/name
tile, shared-screen tile) and verified the camera tile won, the avatar/share
tiles lost, and `feedPipVideo()` returned true. Tests:
`cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` — 24
passed; `git diff --check` passed. Deployed v151 via
`./scripts/deploy_hostinger_web.sh`; backup
`public_html_before_v151_20260706_191728`. Live verification confirmed `?v=151`,
`main.dart.js?v=151`, `mediaFrameQuality`, `frameSampleCanvas`,
`blankAvatarLike`, `cameraLikeScore`, and no forced `window.focus()` fallback.

## 24. macOS Desktop Zoom App Path — 2026-07-07

After repeated web PiP failures for the screen-sharing presenter, the macOS
desktop app path now starts by launching the official Zoom desktop app instead
of trying to keep the Web Meeting SDK embedded view alive while Chrome changes
tabs. `lib/core/widgets/zoom_meeting_screen_io.dart` now uses the native Zoom
Meeting SDK only on Android/iOS. On macOS and other Flutter desktop targets, it
opens `zoommtg://zoom.us/join` with the meeting number, password, and
`routingDisplayName`, then falls back to the normal Zoom `joinUrl` if the custom
scheme cannot launch.

Routing note: the desktop Zoom app cannot send Web SDK `customerKey`, so the
desktop join path intentionally uses the backend-provided `routingDisplayName`
alias. The bot can already route by exact display-name alias through
`services/zoom-hub-bot/routing.js`. Web and Android/iOS behavior is unchanged:
web still uses `customerKey`; mobile still receives the clean native display
name and the existing native SDK breakout handling.

macOS build changes:
- Added `routingDisplayName` parsing/passing in
  `lib/core/services/class_video_service.dart`.
- Added the matching constructor parameters to
  `lib/core/widgets/zoom_meeting_screen_web.dart` for conditional-export
  compatibility.
- Added macOS network-client entitlements in
  `macos/Runner/DebugProfile.entitlements` and
  `macos/Runner/Release.entitlements`.
- Added macOS Keychain Sharing entitlements to the same files and configured
  the Runner target for automatic signing with team `GRKB7BXVZK`. Firebase Auth
  on macOS uses the app keychain; without a signed app/keychain access group,
  email sign-in can surface as credential failure or keychain access failure.
- Guarded Firebase Messaging, local notification setup, prayer notification
  scheduling, FCM token writes, and teacher background services to native
  Android/iOS only. The previous macOS debug run crashed during startup because
  `flutter_local_notifications` was initialized without macOS settings, and
  Firebase Messaging permission/token flows are not configured for desktop.
- Flutter 3.44 added Swift Package Manager integration for most macOS plugins
  during build. CocoaPods now remains for the non-SPM macOS plugins
  (`flutter_webrtc`, `livekit_client`, `printing`) and `WebRTC-SDK`.
- Updated the macOS `WebRTC-SDK` pod lock from `137.7151.04` to `144.7559.01`
  to match `flutter_webrtc 1.4.0`.

Verification:
- `flutter analyze lib/core/services/class_video_service.dart lib/core/widgets/zoom_meeting_screen_io.dart lib/core/widgets/zoom_meeting_screen_web.dart`
  — no issues found.
- First `flutter build macos --debug` failed because macOS CocoaPods still
  locked `WebRTC-SDK 137.7151.04` while `flutter_webrtc 1.4.0` requires
  `144.7559.01`.
- `cd macos && pod update WebRTC-SDK --repo-update` completed and regenerated
  the macOS pod lock.
- Second `flutter build macos --debug` passed and produced
  `build/macos/Build/Products/Debug/alluwalacademyadmin.app`.
- `xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build` created
  the Mac development provisioning profile for
  `com.example.alluwalacademyadmin`.
- Verified the built debug app entitlements include
  `GRKB7BXVZK.com.example.alluwalacademyadmin` as the application identifier
  and keychain access group.
- `flutter run -d macos` launched, sign-in succeeded on the tester account,
  and the original macOS notification crash did not recur. The debug log then
  emitted unrelated shift parsing errors for old `codex_...` / template
  documents with missing timestamp fields; those were not part of the macOS
  auth/Zoom path.

Remaining before real macOS distribution: decide the production app name and
bundle id. The current generated macOS target still uses
`PRODUCT_NAME = alluwalacademyadmin` and
`PRODUCT_BUNDLE_IDENTIFIER = com.example.alluwalacademyadmin`.

## 25. Web Desktop Staff Zoom App Launch — 2026-07-07

After the macOS desktop app path proved reliable, the Flutter web classroom
wrapper now supports the same Zoom desktop app launch for staff on desktop
browsers.

Scope:
- `getZoomJoinInfo` already returns `userRole` and `routingDisplayName`; no
  Firebase Functions or bot change was needed.
- `lib/core/services/class_video_service.dart` now parses `userRole` from the
  Zoom join payload and sets `preferDesktopZoomApp` only when all are true:
  desktop web target, hub-routed Zoom class, `autoJoinBreakoutRoom`, non-empty
  `routingDisplayName`, and backend role `teacher`/`admin`/`super_admin`.
- `lib/core/widgets/zoom_meeting_screen_web.dart` builds the existing
  `zoom_meeting.html` URL as before, but for those staff desktop joins it first
  opens `zoommtg://zoom.us/join` with the meeting number, password, and
  `routingDisplayName` as `uname`.
- After launching the Zoom desktop app, the Flutter web route automatically
  pops back to the app so the teacher/admin is not left on the intermediate
  "Connecting To Class" screen while the class continues in Zoom.
- The existing web Meeting SDK classroom remains available as an on-screen
  fallback button if the Zoom app is not installed or the browser blocks the
  custom protocol.
- Students, parents, mobile web, and non-hub/single-mode joins continue through
  the current web Meeting SDK path.

Verification:
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/services/class_video_service.dart lib/core/widgets/zoom_meeting_screen_web.dart lib/core/widgets/zoom_meeting_screen_io.dart`
  — no issues found.
- `git diff --check -- lib/core/services/class_video_service.dart lib/core/widgets/zoom_meeting_screen_web.dart lib/core/widgets/zoom_meeting_screen_io.dart`
  — passed.

Not deployed / remaining:
- No Hostinger web deploy was run in this session. Deploy with
  `./scripts/deploy_hostinger_web.sh` when ready to put this on the live
  website.

## 26. Stale Hub Handoff + Shift-Length Guardrails — 2026-07-10

Live incident:
- Users reported "Your class is reconnecting. Please try again in a moment" on
  web and iOS. Production logs showed `getZoomJoinInfo` returning 503s for one
  class, not a mobile-only issue.
- Firestore inspection found the problem isolated to the Billing Test class:
  shift `GJehlwnZn1e3nE7xWKmc`, assigned to stale hub
  `zoom_hub_2026-07-09_1_2` while the lane-2 bot had moved on. The shift was
  much longer than a normal class and stretched across hub routing blocks.

Backend hotfix:
- `getZoomJoinInfo` now detects a stale resolved hub heartbeat and first tries
  to hand the class to a healthy active hub spare room whose window covers the
  class. On success it rewrites the shift hub metadata, writes the joining
  member under the healthy hub, and logs a `stale_hub_handoff` warning in
  `system_alerts`. If no safe handoff exists, it preserves the reconnect error
  and logs `stale_hub_on_join`.
- Production deploy completed for `getZoomJoinInfo` on `alluwal-academy`.

Guardrails added:
- `functions/handlers/zoom.js` now blocks unsafe hub-routed Zoom teaching
  shifts before routing: duration over 180 minutes, invalid duration, or
  invalid time fields. Direct/script writes are quarantined with
  `zoom_hub_guardrail_blocked: true`, `zoomRoutingMode: blocked`,
  `zoom_disable_hub_routing: true`, and a `zoom_hub_shift_guardrail`
  `system_alerts` record for owner review.
- `functions/handlers/zoom.js` now treats block boundaries as soft routing
  hints. `_hubMetaForShift` computes a rolling same-lane segment and gives all
  connected classes the same hub id, so short classes like 11:00 AM-12:30 PM or
  4:00 PM-5:30 PM can route normally without needing admin reschedules.
- Zoom classroom routing now requires both `shift_category == teaching` and a
  non-empty normalized student list. Leader Duty, Meeting, Training,
  administrator clock-in shifts, and old no-student rows must not create or
  join Zoom hubs, even when the assigned user also has teacher permissions.
  Multi-role admins still route through Zoom when the shift was created as a
  real Teacher Class with students.
- `prepareZoomHubs` and hub room building also skip/mark unsafe legacy rows so
  one bad shift cannot stretch an otherwise healthy hub.
- `ShiftService` now stores `VideoProvider.zoom` only for real teaching shifts
  with students; admin/internal shifts are normalized to no-video
  `realtimekit` records. It also blocks normal admin create/update/quick-edit
  paths before writing unsafe Zoom teaching shifts, with an admin-facing
  warning. Recurring generated shifts skip any occurrence that violates the
  same guardrail.
- `TeachingShift.hasVideoCall` and `ClassVideoService.canJoinClass` now require
  the same real-class shape, so old no-student admin rows cannot show the Zoom
  join flow in the app.
- Admin create/update/quick-edit attempts that hit the app-side guardrail call
  `recordZoomHubGuardrailAttempt` before blocking. The callable requires admin
  auth and writes the attempted-by user plus the submitted shift fields to
  `system_alerts/{attemptId}` and `admin_notifications/{attemptId}` for review.
- The admin Notifications screen now shows a "Blocked Zoom shift attempts"
  review panel backed by `admin_notifications`. Selecting an attempt opens the
  attempted-by admin, warning message, and captured shift fields.

How to test this guardrail:
- Local backend: run `cd functions && npx jest tests/zoom_handler.test.js
  --runInBand`. Required cases: stale hub handoff succeeds, direct Firestore
  overlong shift gets `zoom_hub_guardrail_blocked`, app-side blocked attempts
  create `system_alerts` and `admin_notifications` records for review, unsafe
  join rejects with `failed-precondition`, and short cross-boundary classes are
  grouped into a rolling hub segment.
- Local app-side validation: run `flutter analyze --no-fatal-warnings
  --no-fatal-infos lib/features/shift_management/services/shift_service.dart
  lib/features/shift_management/widgets/create_shift_dialog.dart
  lib/features/shift_management/widgets/quick_edit_shift_popup.dart`, then use
  the admin shift form or quick edit to try a Zoom teaching class longer than 3
  hours. Expected: save is blocked, the warning explains that the class must be
  split, and an admin review record is written with the attempted teacher,
  students, times, subject, recurrence/rate/notes, and the admin who tried it.
- Production-safe check after Functions + Hostinger deploy: use the admin form
  or quick edit to attempt only a test class, never a real class. Use a shift
  longer than 180 minutes. Expected: the app blocks save, no bad
  shift document is created/updated, and `system_alerts/{attemptId}` plus
  `admin_notifications/{attemptId}` contain the attempted-by admin and entered
  shift fields.
- Direct Firestore/script-write check: create only a test document. Expected:
  the shift document is marked `zoom_hub_guardrail_blocked: true`,
  `zoomRoutingMode: blocked`, `zoom_disable_hub_routing: true`, and
  `system_alerts/{shiftId}_zoom_hub_guardrail` exists. Do not expect a hub
  meeting to be created for that shift.
- Admin clock-in regression check: create a Leader Duty, Meeting, Training, or
  no-student administrator clock-in shift for a user who also has teacher/admin
  roles. Expected: the saved record does not use Zoom for routing, the join
  button is not available, `prepareZoomHubs` ignores it, and
  `getZoomJoinInfo` rejects any stale direct call as
  `This shift is for clock-in/admin work, not a Zoom classroom.`
- Normal-class regression check: create a test Zoom teaching class inside one
  block and under 180 minutes. Expected: `getZoomJoinInfo` still returns hub
  routing, assigns a room/member, and no guardrail alert is written.
- Short classes that cross a current block boundary, such as 11:00 AM-12:30 PM
  with the 12:00 PM boundary or 4:00 PM-5:30 PM with the 5:00 PM boundary, are
  normal if they are 180 minutes or shorter. Expected: the backend groups them
  with the connected same-lane rolling segment, the hub window covers every
  connected class, and no `zoom_hub_guardrail_blocked` flag is written.

Verification:
- `node --check functions/handlers/zoom.js`
- `node --check functions/index.js`
- `node --check functions/tests/zoom_handler.test.js`
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` — 60
  passed.
- `dart format lib/features/shift_management/services/shift_service.dart
  lib/core/services/class_video_service.dart
  lib/features/shift_management/models/teaching_shift.dart
  lib/features/shift_management/widgets/create_shift_dialog.dart
  lib/features/shift_management/widgets/quick_edit_shift_popup.dart`
- `flutter analyze --no-fatal-warnings --no-fatal-infos
  lib/core/services/class_video_service.dart
  lib/features/shift_management/models/teaching_shift.dart
  lib/features/shift_management/services/shift_service.dart
  lib/features/shift_management/widgets/create_shift_dialog.dart
  lib/features/shift_management/widgets/quick_edit_shift_popup.dart
  lib/features/zoom/screens/zoom_screen.dart
  lib/features/shift_management/widgets/shift_details_dialog.dart
  lib/features/shift_management/screens/admin_classes_screen.dart
  lib/features/student/screens/student_classes_screen.dart` — completed; the
  same files still have pre-existing warnings/infos when run without the
  non-fatal flags.
- Production Functions deploy completed on `alluwal-academy` for
  `getZoomJoinInfo`, `prepareZoomHubs`, and `onTeachingShiftWritten`; all
  three were verified `ACTIVE` after the admin-clock-in/no-student routing
  update.
- Production Functions deploy completed on `alluwal-academy` for
  `recordZoomHubGuardrailAttempt`.
- Hostinger web deploy completed through `./scripts/deploy_hostinger_web.sh` as
  cache-busting build `v165`. Public verification confirmed
  `https://alluwaleducationhub.org/index.html` contains `v=165`,
  `flutter_bootstrap.js` loads `main.dart.js?v=165`, and the live bundle
  contains the Zoom guardrail/admin-review/no-video join strings.

Still required:
- No remaining deploy is required for the web/admin guardrail capture path or
  the admin-clock-in/no-student Zoom exclusion.

## 27. Rolling Hub Segments — 2026-07-10

Permanent boundary fix:
- The old hard `crosses_hub_block` failure was removed. A real Zoom teaching
  class is still blocked if it is over 180 minutes or has invalid times, but a
  normal 90-minute class may cross 12 PM or 5 PM.
- `_hubMetaForShift` now scans nearby same-lane Zoom teaching shifts and builds
  a rolling segment from classes whose padded windows touch/overlap. The hub id
  is stable from the anchor day/block plus the segment start time, so a later
  connected class added after rooms open can use an existing spare room instead
  of creating a second overlapping Pro meeting.
- `prepareZoomHubs` now proactively prepares overflow classes on the alternate
  licensed lane when a rolling segment would exceed the conservative 48-room
  hub cap, instead of waiting for the first person in the overflow class to
  click Join.
- Hub docs and shifts now store segment metadata:
  `rollingSegment`, `hubSegmentKey`, `segment_label`, `segment_start`,
  `segment_end`, and `segment_shift_ids`.
- Admin-side shift validation in `ShiftService` no longer blocks a normal Zoom
  teaching class only because it crosses a soft hub boundary. The app still
  blocks classes over 180 minutes and records the attempted fields for review.

Verification:
- `node --check functions/handlers/zoom.js`
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` — 60
  passed, including a rolling 4:00 PM-5:30 PM plus 5:00 PM class segment and
  proactive scheduler spillover to the alternate lane.
- `flutter analyze lib/features/shift_management/services/shift_service.dart`
  was run. It still exits with existing warnings/infos in that large service
  file; no syntax/build error was introduced by the boundary guard removal.
- Production read-only scan on 2026-07-10 12:55 AM ET:
  next 14 days contain 506 real Zoom teaching classes, 0 overlong real classes,
  and 16 normal short cross-boundary classes. Saturday 2026-07-11 has 65 real
  Zoom teaching classes across 5 rolling segments and no unsafe segment. Sunday
  2026-07-12 has one lane-1 rolling segment with 44 class rooms plus 5 spares;
  `prepareZoomHubs` will now proactively spill
  `tpl_07946574e2d73cb9_1783895400` (Mamadou Saidou Diallo, 6:30 PM-8:00 PM)
  to lane 2 when the segment enters the preparation window.

Still required:
- Production deploy completed on `alluwal-academy` for `getZoomJoinInfo`,
  `prepareZoomHubs`, and `onTeachingShiftWritten`; all three were verified
  `ACTIVE` after deploy at 2026-07-10T04:58Z.
- Hostinger web deploy completed through `./scripts/deploy_hostinger_web.sh`
  as cache-busting build `v166`, and the public site verification passed.

## 28. Owner Conversation + Weekend Stress Test — 2026-07-10

Saved owner context:
- Owner explicitly asked for a permanent fix, not manual reschedules or class
  splits. Students and parents are losing patience, so Zoom class routing must
  not fail again because a normal class crosses 12 PM or 5 PM.
- Current production decision: old hub boundaries are soft. Rolling same-lane
  segments handle normal cross-boundary classes; over-180-minute real teaching
  classes are blocked and logged; admin/no-student shifts do not route through
  Zoom; scheduler spillover prepares overflow rooms on the other licensed lane.
- Future agents must not reintroduce a hard `crosses_hub_block` guard or
  simplify hub routing without targeted tests and an update to this file.

Focused no-surprises test for Friday 2026-07-10 through Monday 2026-07-13:
- Production read-only scan at 2026-07-10 01:21 AM ET:
  211 shift docs scanned, 194 real Zoom teaching classes modeled,
  16 admin/no-student Zoom rows ignored, 0 invalid real Zoom classes, and
  0 overlong real Zoom classes.
- Current schedule is safe after rolling segmentation and scheduler spillover.
  Friday has 36 classes, Saturday 65, Sunday 66, and Monday 27. Sunday has
  1 known proactive spillover move; no unresolved hub-capacity issue remains.
- 1,000 realistic added-class trials per day were run. Added classes sampled
  that day's existing start/end pattern and used an approximately 50/50 lane
  split for new teachers. Results:
  - Friday 2026-07-10: +50 added classes passed 100% of trials; +60 passed 13%.
  - Saturday 2026-07-11: +25 passed 100%; +30 passed 96.7%; +40 passed 76.7%.
  - Sunday 2026-07-12: +20 passed 100%; +25 passed 99.7%; +30 passed 93.6%.
  - Monday 2026-07-13: +60 passed 100%.
- Deterministic same-window stress was also run. If many new multi-student
  classes are stacked into the same already-busy window, the first hard break
  can be the 99-person scheduled-human cap, not only room count. Friday's
  afternoon/evening window can hit the seat cap around the 31st same-window
  added class. Saturday/Sunday/Monday same-window room breaks were much higher
  after spillover, but realistic random additions still show weekend pressure.

Operational weekend rule until another scan is run:
- Safe without more analysis: up to 20 additional normal Zoom teaching classes
  on Saturday or Sunday, assuming they follow normal schedule patterns.
- Re-run the scan before adding more than 20 classes to either weekend day or
  before stacking many new classes into the same 7:45 AM-8:15 PM Sunday window.
- If additions are concentrated at one time with multi-student rosters, check
  the 99 scheduled-human cap, not just the 48-room cap.

Verification:
- `node --check functions/handlers/zoom.js`
- `node --check functions/tests/zoom_handler.test.js`
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` — 60
  passed.

## 29. Fast Admin Save-Time Capacity Guardrail — 2026-07-10

Production routing contract:
- Admins must not be allowed to save a real Zoom teaching class if that class
  would make the hub system exceed safe capacity. The admin should see the
  rejection before the shift is written, and the attempted details must be
  saved for review.
- This check must stay fast. The normal allowed path only validates the
  proposed shift's nearby routing window, using a bounded `teaching_shifts`
  query around that class's hub segment, then runs the room/seat/lifetime
  simulation in memory. Do not replace it with a full month or full schedule
  scan in the interactive admin save path.
- The guardrail runs only for real Zoom teaching classes with students.
  Admin duty, leader duty, meetings, no-student clock-in shifts, and other
  non-class shifts must remain outside Zoom routing and outside this preflight.
- The blocked path writes a review record to `system_alerts` and
  `admin_notifications`, includes the actor and attempted shift payload, and
  sends email/push alert targets including explicit CTO/Hassimiou Niane matches.
  Notification work happens only after a rejection, not on every successful
  admin save.

Implementation details:
- `validateZoomShiftCapacity` is a new admin-only callable in
  `functions/handlers/zoom.js`, exported from `functions/index.js`.
- `ShiftService.createShift`, `ShiftService.updateShift`, and
  `ShiftService.updateShiftDirect` call the callable before writing a real Zoom
  teaching class. A failed preflight throws `ShiftGuardrailException` with the
  Cloud Function message so the admin sees the reason.
- `_zoomHubCapacityGuardrailDecision` models the proposed class plus nearby
  existing hub-routed classes, applies existing spillover behavior across
  licensed lanes, and blocks unresolved segments that exceed:
  - 48 total rooms including the 5 spare rooms,
  - 99 scheduled humans per lane after reserving one bot seat,
  - 28 hours of safe hub lifetime.
- `onTeachingShiftWritten` now has the same capacity guardrail as a backstop for
  scripts, imports, or stale clients that bypass the admin callable. A breaking
  direct write is quarantined with `zoomRoutingMode: blocked` and
  `zoom_disable_hub_routing: true`; it does not provision a Zoom hub.

How to test this guardrail:
- Admin preflight test: fill both licensed lanes to the class-room cap, call
  `validateZoomShiftCapacity` with one more overlapping real Zoom class, and
  expect `failed-precondition`, a `zoom_hub_shift_guardrail` review record, and
  CTO email/push notification calls.
- Direct write backstop test: write the same breaking class to Firestore and
  invoke `onTeachingShiftWritten`; expect the shift to be marked blocked and
  `createMeeting` not to run.
- Fast allowed-path test expectation: a normal safe class should return
  `{ ok: true }` from `validateZoomShiftCapacity` without creating a guardrail
  alert.

Verification before deploy:
- `node --check functions/handlers/zoom.js`
- `node --check functions/index.js`
- `node --check functions/tests/zoom_handler.test.js`
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` — 62
  passed.
- `cd functions && npm test -- --runInBand` — 23 suites passed, 241 tests
  passed, 7 existing skipped tests unchanged.
- `flutter analyze --no-fatal-warnings --no-fatal-infos
  lib/features/shift_management/services/shift_service.dart` — exited 0 with
  the same existing warnings/infos in that large service file.

Deploy completed:
- Production Functions deploy completed on `alluwal-academy` for
  `validateZoomShiftCapacity` and `onTeachingShiftWritten`. Both were verified
  `ACTIVE` in `us-central1` at 2026-07-10T05:43Z.
- Hostinger web deploy completed through `./scripts/deploy_hostinger_web.sh`
  as cache-busting build `v167`. Public verification confirmed
  `index.html` references `flutter_bootstrap.js?v=167` and
  `manifest.json?v=167`, `flutter_bootstrap.js?v=167` loads
  `main.dart.js?v=167`, and the live bundle contains
  `validateZoomShiftCapacity` plus the Zoom capacity warning strings.

Production validation:
- Logged into the live Hostinger app as the CTO/admin account and opened
  Operations → Shifts → Create Shift.
- Attempted to create a real Zoom Teacher Class for Ibrahim Bah with one
  selected student from 2026-07-11 2:00 PM-8:00 PM America/New_York. Expected
  and observed: the dialog stayed open, `recordZoomHubGuardrailAttempt`
  returned `200`, and a read-only Firestore check found 0 matching
  `teaching_shifts` records for 2026-07-11T18:00:00Z-2026-07-12T00:00:00Z.
- The latest `system_alerts` review record captured attempted-by Hassimiou
  Niane, operation `create_shift`, teacher Ibrahim Bah, 1 student, category
  `teaching`, video provider `zoom`, and the warning:
  `This class is too long for Zoom routing (6 hours). Zoom classes must be 3
  hours or shorter. Split it into shorter classes before saving.`
- Opened Communication → Notifications and verified the "Blocked Zoom shift
  attempts" panel shows the new attempt. Opening the card shows the actor,
  email, operation, warning, and entered shift information.
- Direct production callable speed test for `validateZoomShiftCapacity` with a
  normal one-hour no-write Zoom teaching class returned `{ ok: true }`. The
  first call took 3603 ms and checked 49 nearby records; the warm call took
  558 ms and checked the same 49 nearby records. This confirms the interactive
  path is bounded to the proposed shift window, not a month-long scan.

## 30. Daily Future Capacity Forecast Notification — 2026-07-10

Production routing contract:
- Admin save-time validation must stay fast and local to the proposed class
  window. Full future schedule checks run outside the admin save path.
- `watchZoomHubCapacityForecast` runs daily at 3:15 AM America/New_York. It
  scans the future Zoom hub schedule over the configured forecast horizon
  (`ZOOM_HUB_DAILY_CAPACITY_FORECAST_DAYS`, default 90 days), builds the same
  rolling hub segments used by routing, simulates spillover across licensed
  lanes, and reports only hard unresolved problems:
  room cap, scheduled-human seat cap, unsafe hub lifetime, or future hub-routed
  Zoom shifts that still violate the timing guardrail.
- If no problem is found, it marks
  `admin_notifications/zoom_hub_daily_capacity_forecast` resolved/open false,
  so the Notifications page stays quiet.
- If a problem is found, it writes
  `admin_notifications/zoom_hub_daily_capacity_forecast` with type
  `zoom_hub_capacity_forecast`, `open: true`, `action_required: true`, summary
  counts, and the problem details. The Notifications page shows a "Zoom
  schedule risks" panel only when that open record exists.
- Email/push alerts are fingerprinted by problem set through
  `system_alerts/zoom_hub_daily_capacity_forecast_<fingerprint>`. The same
  unchanged risk does not spam admins daily, but a changed/new risk creates a
  new alert.

Verification:
- `node --check functions/handlers/zoom.js`
- `node --check functions/index.js`
- `node --check functions/tests/zoom_handler.test.js`
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` — 64
  passed, including safe daily forecast hidden/resolved and overloaded future
  schedule notification cases.
- `cd functions && npm test -- --runInBand` — 23 suites passed, 243 tests
  passed, 7 existing skipped tests unchanged.
- `dart format lib/features/notifications/screens/send_notification_screen.dart`
- `flutter analyze --no-fatal-warnings --no-fatal-infos
  lib/features/notifications/screens/send_notification_screen.dart` — exited 0
  with existing non-fatal deprecation infos.

Deploy completed:
- Production Functions deploy completed on `alluwal-academy` for
  `watchZoomHubCapacityForecast`. The Gen 2 function was verified `ACTIVE` in
  `us-central1` at 2026-07-10T13:36:43Z.
- Cloud Scheduler job
  `firebase-schedule-watchZoomHubCapacityForecast-us-central1` is `ENABLED`
  with schedule `15 3 * * *` in `America/New_York`.
- Hostinger web deploy completed through `./scripts/deploy_hostinger_web.sh`
  as cache-busting build `v168`. Public verification confirmed
  `index.html` references `flutter_bootstrap.js?v=168` and
  `manifest.json?v=168`, `flutter_bootstrap.js?v=168` loads
  `main.dart.js?v=168`, and the live bundle contains the
  `zoom_hub_capacity_forecast` notification UI.
- Production read-only forecast on 2026-07-10 scanned through 2026-10-07:
  2,469 future shift documents scanned, 2,219 hub-routed Zoom classes checked,
  30 non-Zoom shifts skipped, 220 non-hub Zoom shifts skipped, 1 proactive
  spillover move modeled, and 0 unresolved problems. The daily notification
  should therefore stay hidden until a real future risk appears.
- Manual production scheduler trigger on 2026-07-10 completed successfully with
  log line: `[ZoomHub] Daily capacity forecast OK through 2026-10-07; 2219
  hub-routed Zoom classes checked.`

## 31. Auto-Resolve Recovered Hub Incident Alerts — 2026-07-10

Production routing contract:
- Transient hub incident alerts must not stay open forever after the hub has
  recovered or the hub window has ended. Open incident counts are used for live
  operational confidence, so old `rooms_not_open`, `heartbeat_stale`,
  `zombie_meeting_forced_rejoin`, `breakout_unreadable_poisoned`,
  `stale_hub_on_join`, `stale_hub_handoff`, and
  `stragglers_removed_at_time_limit` records are auto-resolved once they are no
  longer the current state.
- This cleanup does not change join routing, hub assignment, room creation, or
  meeting lifetimes. It only updates alert records with `resolved: true`,
  `status: resolved`, `auto_resolved: true`, and
  `auto_resolved_reason: hub_recovered_or_window_closed`.
- Shift guardrail/review records are not counted as live hub incidents in
  `getZoomHubRoutingStatus`. They remain reviewable through the admin
  Notifications guardrail panel.
- `watchZoomHubBots` runs the cleanup automatically every 2 minutes before it
  writes any new current hub alerts. `getZoomHubRoutingStatus` also runs the
  cleanup before returning counts, so the admin view reflects current risk.

Verification:
- `node --check functions/handlers/zoom.js`
- `node --check functions/tests/zoom_handler.test.js`
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` — 66
  passed, including recovered alert auto-resolution and current unhealthy hub
  alert retention.
- `cd functions && npm test -- --runInBand` — 23 suites passed, 245 tests
  passed, 7 existing skipped tests unchanged.

Deploy completed:
- Production Functions deploy completed on `alluwal-academy` for
  `watchZoomHubBots` and `getZoomHubRoutingStatus`.
- Cloud Scheduler job `firebase-schedule-watchZoomHubBots-us-central1` is
  `ENABLED` with schedule `every 2 minutes`.
- Manual production scheduler trigger on 2026-07-10 auto-resolved 48 stale hub
  alerts.
- Production routing status after cleanup: 2 active hubs, 2 rooms-open hubs, 2
  online bots, 0 stale bots, 3 scheduled classes right now, and 0 open
  incidents.

## 32. Hostinger `live.` Subdomain Restore — 2026-07-10

Incident:
- `https://live.alluwaleducationhub.org/` returned Hostinger's default 404 page
  after a Flutter Hostinger deploy. The main app deploy uploaded to
  `public_html/` with `rsync --delete`, which removed the Hostinger subdomain
  folder `public_html/live/`.
- The main app at `https://alluwaleducationhub.org/` was healthy; the break was
  limited to the `live.` subdomain folder.

Fix:
- Restored `public_html/live/` from the existing legacy live copy
  `public_html_77/live/`.
- Restored `public_html/ops/` from backup
  `public_html_before_v153_20260708_234526/ops/`; public `ops.` DNS still did
  not resolve at the time of verification, but the Hostinger folder is present.
- Updated `scripts/deploy_hostinger_web.sh` so future Flutter root deploys
  preserve `/live/***` and `/ops/***` while still using `--delete` for the
  Flutter root files.
- Updated `docs/hostinger-web-deploy.md` with the same preservation rule.

Verification:
- `bash -n scripts/deploy_hostinger_web.sh`
- Public `https://live.alluwaleducationhub.org/` returned HTTP 200 and the
  Alluwal Education Hub page title/content.
- Public `https://live.alluwaleducationhub.org/admin/routing-control/`
  returned HTTP 200.

## 33. Zoom Hub Live Presence Display Source — 2026-07-10

Incident:
- Admin class cards were undercounting live Zoom participants. Example:
  Sheikh Ahmad Jalloh and student Kadiatou Barry were together in the correct
  breakout room, but the website showed only the teacher.
- Production bot logs for hub `zoom_hub_2026-07-10_2_1400_1` showed the room
  `720800 | Sheikh Ahmad Jallo...` with participant count 2 and attendee list
  including Kadiatou Barry. Routing was healthy.
- Firestore `livekit_sessions` for shift
  `tpl_ZSStwV2uLJjFTFUMiP33_1783720800` had Kadiatou Barry closed at
  `2026-07-10T22:00:58Z`, so `getRealtimeKitRoomPresence` had no open student
  presence window to display. This was a display/source-of-truth issue, not a
  room-routing issue.

Fix:
- `services/zoom-hub-bot/bot_controller.html` now reports
  `liveParticipantsByShift` in `zoomHubBotState`, derived from the bot's
  current breakout-room view. This is read-only reporting; it does not change
  routing decisions, room creation, joins, or meeting lifetime.
- `functions/handlers/zoom_hub_bot.js` now validates/sanitizes that live roster
  and stores it on the hub doc as both `liveParticipantsByShift` and
  `live_participants_by_shift`, with a server timestamp.
- `functions/handlers/realtimekit.js` now prefers the fresh bot roster for Zoom
  hub class presence and falls back to the old `livekit_sessions` webhook
  windows when the bot roster is missing or stale.

Safety:
- No routing logic, join payloads, room assignment logic, Zoom meeting reset
  paths, or Hostinger web bundle were changed.
- The bot file was copied to the VPS, but `zoom-hub-bot@1` and
  `zoom-hub-bot@2` were not restarted because both lanes had live occupants
  (`lane 1: 5`, `lane 2: 3` at 2026-07-10T22:16Z). Existing bot pages will
  keep using the old reporting code until they naturally reload or are safely
  restarted with zero in-room occupants.

Verification:
- `node --check functions/handlers/realtimekit.js`
- `node --check functions/handlers/zoom_hub_bot.js`
- Bot controller inline scripts parse with `new Function(...)`.
- `cd functions && npm test -- --runTestsByPath tests/realtimekit_access.test.js tests/zoom_handler.test.js --runInBand`
  — 98 passed.
- `cd services/zoom-hub-bot && npm install && npm test -- --runInBand` — 25
  passed.

Deploy completed:
- Production Functions deploy completed on `alluwal-academy` for
  `getRealtimeKitRoomPresence`, `zoomHubBotAssignments`, and
  `zoomHubBotState`.
- VPS `/opt/alluwal/zoom-hub-bot/bot_controller.html` was backed up and
  replaced with the reporting-only version. `grep` verified
  `buildLiveParticipantsByShift` and `liveParticipantsByShift` are present.
- Both VPS services remained active after the file copy. No restart was run.

Remaining operational note:
- Current live hubs at the time of deployment did not yet have
  `liveParticipantsByShift` because their bot pages were already loaded. The
  admin display remains on the old fallback for those in-progress hubs until a
  safe bot reload occurs. Do not force-restart a bot while `stats.inRoomOccupants`
  is greater than 0.

## 34. Safe Bot Restart After Empty Evening Window — 2026-07-10

Operational follow-up to §33:
- At `2026-07-11T02:33Z` (`2026-07-10 10:33 PM ET`), production Firestore
  showed zero active `hub_meetings` and zero nearby teaching shifts.
- Both VPS services were restarted with the existing VPS key:
  `zoom-hub-bot@1.service` and `zoom-hub-bot@2.service`.
- Post-restart verification showed both services `active/running`, with new
  main PIDs, and the VPS controller file still contains
  `buildLiveParticipantsByShift` / `liveParticipantsByShift`.
- A follow-up Firestore check at `2026-07-11T02:34:59Z` still showed zero
  active hub meetings.
- Follow-up tests at about `2026-07-11T02:36Z`:
  - `node --check functions/handlers/realtimekit.js &&
    node --check functions/handlers/zoom_hub_bot.js`
  - `cd functions && npm test -- --runTestsByPath
    tests/realtimekit_access.test.js tests/zoom_handler.test.js --runInBand`
    — 98 passed.
  - `cd services/zoom-hub-bot && npm test -- --runInBand` — 25 passed.
  - Production `zoomHubBotDirectives` smoke via the VPS bot env returned
    `success: true` and zero active directives for lanes 1 and 2.
  - Production `zoomHubBotState` smoke posted a temporary
    `codex_roster_smoke_*` hub state with `liveParticipantsByShift`, verified
    both camel/snake roster fields and timestamp were stored, then deleted the
    temporary hub doc.

No Firebase Functions, Hostinger web, Flutter, routing logic, or Zoom meeting
lifetime behavior changed in this follow-up. The next hub pages opened by the
bot should use the bot-roster display source from §33.

## 35. Billing Test Live Roster Regression — 2026-07-10

Live test:
- Created production test teaching shift
  `codex_billing_test_20260711024400` for teacher Billing Test and student
  test student, scheduled `2026-07-10 10:44 PM-11:14 PM ET`.
- Hub `zoom_hub_2026-07-10_3_2244_2` was prepared on lane 2 with meeting
  `88477028256`, one class room, and five spare rooms.
- Hassimiou Niane joined as an administrator. Zoom routing moved the participant
  into the Billing Test breakout room during the first live check, but the
  Classes page still showed `In class now: 0`.

Root cause:
- The bot controller was building `liveParticipantsByShift`, but
  `postState(status, extra)` only serialized `stats` and `error`.
- As a result, the backend `zoomHubBotState` handler never received the live
  roster from a real bot page, even though the backend smoke test could store
  the field when it was posted directly.
- This was a display/reporting bug. No room assignment, join payload, bot lane
  selection, hub scheduling, or Zoom meeting lifetime logic was changed.

Fix:
- `services/zoom-hub-bot/bot_controller.html` now includes
  `extra.liveParticipantsByShift` in the `/zoomHubBotState` request body when
  the routing loop provides it.
- `services/zoom-hub-bot/tests/bot_controller_html.test.js` now asserts that
  `postState` preserves the roster field. This is a guardrail against future
  agents accidentally dropping the production-critical display payload again.
- VPS `/opt/alluwal/zoom-hub-bot/bot_controller.html` was backed up to
  `bot_controller.html.bak-20260711024636` and replaced with the patched file.

Verification:
- `cd services/zoom-hub-bot && npm test -- --runInBand` — 25 passed.
- `node --check functions/handlers/zoom_hub_bot.js &&
  node --check functions/handlers/realtimekit.js`
- VPS `grep` verified the patched `postState` body includes
  `liveParticipantsByShift`.
- After a safe lane-2 restart while `inRoomOccupants` was 0, Firestore hub
  `zoom_hub_2026-07-10_3_2244_2` started receiving
  `liveParticipantsUpdatedAt`, confirming the patched bot page is posting the
  roster field.

Operational note:
- Do not restart a bot inside an active test hub unless the whole Zoom meeting
  is truly empty and the old host instance has had time to leave. In this test,
  restarting lane 2 caused a temporary duplicate "Alluwal Hub Bot Lane 2" in
  the same Zoom meeting, and the test participant then remained in the main
  session with Zoom returning `user not in a room` on repeated assignment
  attempts.
- Current guidance is conservative: no further restarts, resets, deploys, or
  routing changes without explicit owner approval. For the next live roster
  verification, use a fresh test hub/meeting or wait until this test hub ends
  naturally.

## 36. Next.js Teacher Provider Parity — 2026-07-11

- The Next.js teacher classroom previously requested a RealtimeKit token for
  every shift, including shifts whose `video_provider` is `zoom`. Provider-aware
  joining now calls `getZoomJoinInfo` for Zoom-backed shifts and hands the
  returned role-0 routing payload to the unchanged canonical
  `web/zoom_meeting.html` page.
- `apps/web/scripts/prepare-assets.mjs` copies the canonical Zoom meeting page
  into the Next static export. No Zoom handler, hub-routing rule, meeting
  lifetime, bot lane, room assignment, or visible Zoom meeting control was
  changed.
- Verification completed: Next TypeScript check, production-style static build,
  Hostinger package generation, cross-browser focused tests confirming the
  packaged page contains the routing host, and authenticated teacher navigation
  coverage. No Firebase, Hostinger, VPS, or production deployment was performed.
- Remaining gate: authenticated `alluwal-dev` teacher join through an active
  Zoom hub fixture, including routing to the expected private room and return to
  `/teacher/classes/` after leaving.

## 37. Next.js RealtimeKit Live Controls Acceptance — 2026-07-12

- This pass was limited to RealtimeKit-backed classes. It did not change Zoom
  hub routing, join payloads, bot lanes, room assignment, meeting lifetimes, or
  the canonical Flutter Zoom host.
- A disposable `alluwal-dev` teaching shift was joined in a headed browser by
  the authenticated teacher and a public guest. Live evidence confirmed two
  peers in the same RealtimeKit room, active roster display, teacher lock and
  unlock, locked-guest denial, teacher removal of the existing guest, the
  guest-side removed message, and teacher reconnect.
- The Next-only `realtimekit_meeting.html` now retries initialization with
  audio/video disabled when normal media initialization stalls. This fixed a
  real no-device/permission path where Cloudflare API calls succeeded but the
  meeting object was never assigned and the parent timed out.
- `kickRealtimeKitParticipant` now sends Cloudflare `participant_ids` after
  resolving the participant UUID. The previous `custom_participant_ids` body
  failed live because the meeting uses `idType: userId`.
- `getRealtimeKitRoomPresence` now reads the current active session and filters
  departed peers instead of counting every participant provisioned on the
  meeting. The post-removal badge and Cloudflare UI both returned to one active
  teacher.
- Focused RealtimeKit Jest passed (37 tests). Targeted deploys were made only to
  `alluwal-dev` for `kickRealtimeKitParticipant` and
  `getRealtimeKitRoomPresence`. The disposable Firestore shift was deleted and
  the browser sessions were closed.
- Remaining classroom gate is unchanged: verify an authenticated Next teacher
  join through a real dev Zoom hub, private-room routing, and return to
  `/teacher/classes/` after Leave. Do not modify production routing to create
  that fixture.

## 38. Web Text Selection Boundary — 2026-07-14

- The Flutter desktop Dashboard → Classes destination is
  `lib/features/zoom/screens/zoom_screen.dart`. Its class list, including the
  student-facing class cards, did not receive the dashboard's existing text
  selection boundary.
- Added only a local `ScrollNotificationObserver` and `SelectionArea` around
  the screen body. No Zoom join payload, routing mode, hub/bot lane, room
  assignment, class filtering, meeting lifetime, or control behavior changed.
- Verification: `dart analyze lib/features/zoom/screens/zoom_screen.dart`,
  `./scripts/ci/check_architecture.sh`, and `git diff --check` passed.
- Deployed through the required Hostinger release script as web version 200.
  Production browser testing as the designated student account confirmed that
  a continuous mouse drag visibly selects the `Your classes` card text. No
  joins, messages, or production data mutations were performed.

## 39. Corrected-Class Stale Guardrail Recovery — 2026-07-18

Production incident:
- Chernor Ahmadu Jalloh / Elias Kouyateh on Friday 2026-07-17 was displayed as
  a normal 7:00-8:00 PM one-hour class, but Join returned the old
  `780 minutes` guardrail error.
- The shift modification history showed that the occurrence was first changed
  to 7:00 PM-8:00 AM on 2026-07-10 and correctly blocked. It was corrected to
  7:00-8:00 PM on 2026-07-16, but the stored
  `zoom_hub_guardrail_blocked` fields and `zoomRoutingMode: blocked` remained.
- `onTeachingShiftWritten` returned immediately whenever it found a stored
  guardrail, so it never revalidated the corrected duration.
  `getZoomJoinInfo` also returned the stored message before evaluating the
  current one-hour schedule.
- The teacher clocked in and completed the timesheet/form, but the shift had no
  hub/room and no `livekit_sessions` Zoom presence. The scheduled presence
  detector recorded `missing: both`. The original guardrail alert email also
  recorded an hPanel-disabled delivery failure.

Targeted fix:
- Stored Zoom guardrails are now revalidated against both the current duration
  rules and current two-lane capacity before any block can be removed.
- A corrected safe class clears only its guardrail fields, restores hub routing,
  and resolves the matching system alert. An imminent corrected class is then
  eagerly provisioned using a fresh shift snapshot.
- `getZoomJoinInfo` has the same revalidation as a last-resort self-heal, so a
  corrected safe class cannot remain stuck solely because its earlier edit
  trigger was missed.
- A class that is still unsafe remains blocked. If the current unsafe reason or
  message changed, the stored guardrail is refreshed instead of cleared.
- No bot lane selection, rolling segment calculation, room assignment,
  breakout routing, join payload, meeting lifetime, participant UI, or web
  meeting behavior changed.

Verification:
- `node --check functions/handlers/zoom.js` and
  `node --check functions/tests/zoom_handler.test.js` passed.
- `git diff --check -- functions/handlers/zoom.js
  functions/tests/zoom_handler.test.js` passed.
- `./scripts/ci/check_architecture.sh` passed.
- Focused Jest passed:
  `npx jest tests/zoom_handler.test.js tests/zoom_signature.test.js
  tests/zoom_meeting_html.test.js --runInBand` — 94 passed.
- New regressions cover: 780-minute block corrected to 60 minutes and eagerly
  provisioned; participant Join self-heals the same stale block; and a class
  corrected only to 240 minutes remains blocked with no meeting creation.
- Full Functions Jest reached 290 passed and 7 existing skipped tests, but the
  run remains red on 23 unrelated failures in the uncommitted quiz competition
  work (`tests/quiz_competition.test.js`, missing helper exports and changed
  ranking/eligibility behavior). No quiz files were changed for this fix.

Deploy and live evidence:
- Targeted development deploy completed for only `getZoomJoinInfo` and
  `onTeachingShiftWritten`.
- A far-future `alluwal-dev` fixture with a safe one-hour schedule plus a stale
  780-minute stored block auto-cleared to `zoomRoutingMode: hub`, resolved its
  alert with `class_schedule_corrected`, and did not create a hub meeting. The
  fixture shift and alert were deleted; cleanup confirmed neither remained.
- Targeted production deploy completed for only `getZoomJoinInfo` and
  `onTeachingShiftWritten`; both reported `ACTIVE` with update time
  2026-07-18T12:27Z. Their latest Cloud Run revisions reported Ready, and
  neither service had an error-severity log after the rollout.
- Post-deploy production checks found the active lane hub still `roomsOpen`,
  heartbeat age two seconds, no bot error, and zero future
  `zoom_hub_guardrail_blocked` shifts. The unauthenticated Join endpoint probe
  returned the expected `401 Authentication required`.
- No Hostinger web deploy, VPS bot restart, live class join, synthetic
  production shift, or production hub mutation was performed. The ended
  Chernor/Elias shift was left unchanged as historical incident evidence.

## 40. Admin Classes Roster Contact Display — 2026-07-18

Production finding:
- The admin screenshot showed that Communication → Classes is rendered by
  `lib/features/zoom/screens/zoom_screen.dart`, not the older
  `admin_classes_screen.dart`. The first roster-contact implementation had
  therefore been added to a screen that was not the production destination.
- The unused-screen additions were removed and the resolver was relocated
  inside the Zoom feature so the production card is the only changed display
  path.

Source change:
- Admin and super-admin class cards now show each assigned student's visible
  student ID, linked parent/guardian name, and phone number below the existing
  student-name row.
- Student ID resolution prefers `student_code`, `studentCode`, `student_id`,
  or `studentId`, then falls back to the user's Firestore document ID.
- Parent links support `guardian_ids`, `guardianIds`, scalar legacy
  guardian/parent fields, and reverse `children_ids` / `childrenIds` links.
  Multiple linked parents are displayed. Missing links, missing phone numbers,
  and failed lookups have distinct localized fallback messages.
- Contact futures are cached per roster while the Classes screen is open to
  avoid repeating the same user reads on the ten-second UI tick.
- The contact block is not constructed for teacher or student role views, so
  parent contact information remains admin-only.

Routing safety:
- No Join button logic, class timing/join window, presence polling, Bot lane
  badge, Zoom join payload, hub/lane selection, room assignment, bot service,
  meeting lifetime, Functions handler, or `web/zoom_meeting.html` behavior was
  changed.
- No Firebase Functions deploy or VPS bot restart was needed or performed.

Verification:
- Focused resolver and widget tests passed: 7 tests. Widget coverage asserts
  the exact student ID, parent name, and phone text plus missing-parent
  fallback behavior.
- Full Flutter suite passed: 282 tests, with the existing one skipped smoke
  test unchanged.
- Targeted Flutter analysis with non-fatal warnings/infos enabled completed
  with `No issues found`.
- `./scripts/ci/check_architecture.sh` and targeted `git diff --check` passed.

Deploy:
- Hostinger release deployed through `./scripts/deploy_hostinger_web.sh` as
  cache-busting build `v249`.
- Backup created:
  `public_html_before_v249_20260718_101941`.
- Public verification returned HTTP 200, the index references
  `flutter_bootstrap.js?v=249`, the bootstrap loads `main.dart.js?v=249`, and
  the public bundle contains the roster fallback/Student ID strings.

Remaining live check:
- No class was joined and no production class data was mutated for this
  display-only change.
- Automated inspection of the owner's existing signed-in Chrome tab was not
  available because the Chrome extension connection was unavailable. The
  owner should hard-refresh Communication → Classes and visually confirm the
  new admin-only roster block on an assigned class.

## 41. Lane-2 Assigned-But-Not-Joined Incident — 2026-07-22

Production symptom:
- Students stayed behind the black connecting layer while teachers could see
  themselves in the hub with the host bot instead of entering the private
  classroom.
- The incident was isolated to hub `zoom_hub_2026-07-22_2_1300_2` on lane 2.
  Lane 1 continued routing participants into private rooms normally.

Live findings:
- Both systemd bot services were active with zero automatic restarts.
- Lane 2 had a healthy heartbeat and a readable ten-room breakout list, so this
  was not the earlier empty-room-list poison signature.
- From 1:02 PM through 2:14 PM America/New_York, multiple lane-2 web and native
  participants remained in Zoom's `breakoutUnassigned` pool. The bot resolved
  the correct target room and issued `assignUserToBreakoutRoom`, but the
  follow-up move repeatedly returned `user not in a room`. Individual affected
  joins accumulated between 54 and 188 failed retries.
- Lane 1 provided the control case: the same assign flow returned `user already
  in the target room`, `breakoutUnassigned` drained, and the room participant
  counts increased.
- The affected lane-2 meeting had therefore opened with ineffective auto-join
  behavior even though the bot requested `isAutoJoinRoom: true`. The current
  controller verifies room options for inherited/already-open rooms, but does
  not verify `getBreakoutRoomOptions()` after a successful fresh open.
- Monitoring did not reset the meeting because `liveRoomCount` stayed healthy
  and `routedCount` counts planned actions rather than confirmed arrivals. A
  growing `breakoutUnassigned` pool with repeated `user not in a room` errors is
  currently a watchdog blind spot.

Recovery performed:
- Immediately before recovery at 2:21 PM ET, a fresh routing snapshot confirmed
  ten readable rooms, zero private-room occupants, no waiting participant still
  connected, and only the lane-2 host bot in the meeting.
- Posted the authenticated `resetMeeting` state for only the affected hub, which
  ended the bad Zoom meeting instance. The controller remained as a Zoom zombie
  after the REST end, so only `zoom-hub-bot@2` was restarted. Lane 1 and its live
  classes were not touched.
- Lane 2 rejoined at 2:22 PM ET, created and opened ten rooms with new room IDs,
  and resumed fresh heartbeats.
- Live recovery proof at 2:23 PM ET: the next participant retry was assigned to
  the expected class room, the host-side follow-up returned `user already in the
  target room`, `breakoutUnassigned` drained, and the room remained at one
  participant in subsequent snapshots. No one remained beside the bot.

Deploys and verification:
- No Firebase Functions, Hostinger web, Flutter, or VPS code deployment was
  performed. The only production mutations were the guarded empty-lane meeting
  reset and restart of `zoom-hub-bot@2`.
- No source tests were run because no application or bot source changed.

Durable follow-up:
- Verify `getBreakoutRoomOptions()` after every fresh successful room open and
  safely close/reopen immediately when auto-join is not effective and occupancy
  is zero.
- Report attempted and confirmed routing separately. Add a watcher signature
  for a non-empty `breakoutUnassigned` pool or repeated assigned-not-joined
  failures so this condition self-recovers without waiting for a report.

### Root-cause conclusion and hardening deployed — 2026-07-22

Root-cause conclusion:
- The evidence supports a Zoom per-meeting breakout-state failure: the affected
  instance accepted `openBreakoutRooms`, exposed all ten expected rooms, and
  accepted the correct participant/room assignment, but did not perform the
  requested automatic move. Resetting only that meeting instance made the same
  deployed code work immediately with new room IDs.
- This was not a room mapping error, a bot outage, a participant timing race,
  the empty-room-list failure, or a web-only/native-only problem. The bad
  meeting had been open for minutes before the first failed join; both web and
  native users failed; lane 1 routed normally; and the lane-2 bot consistently
  selected the correct target.
- Zoom does not expose enough server-side diagnostics to name the internal
  defect more narrowly. The conclusion above is therefore a high-confidence
  inference from the controlled before/after meeting reset, not a claim about
  Zoom's private backend implementation.
- The VPS still uses the older `file://` launcher and logs SDK cache/socket
  warnings. Those warnings also occur on healthy lane 1, so they were not the
  incident trigger. Reconcile the launcher during a separate empty-lane
  maintenance window rather than mixing it into this live routing repair.

Safeguards implemented:
- `bot_controller.html` now reads back the effective breakout options after
  every first open, including a successful fresh open. A mismatch or unreadable
  option response causes one guarded close/reopen only when rooms are empty.
- The routing loop tracks users who remain in Zoom's `breakoutUnassigned` pool
  after a valid assignment. At 20 seconds it performs one empty-room
  close/reopen. If the same failure persists for another 20 seconds, it posts
  `resetMeeting` and reloads into a clean meeting instance. Tracking uses the
  per-meeting Zoom participant ID, so it also covers native clients that do not
  expose a customer key. A close that remains stuck for 15 seconds skips
  directly to the clean-meeting reset instead of delaying a class for the
  general 90-second close timeout.
- Every destructive recovery is gated by both the current room snapshot and the
  last known occupancy. If anyone is inside a private room, the bot refuses to
  reset and reports the error instead.
- Bot stats now distinguish `routeAttemptCount`, `confirmedInRoomCount`,
  `breakoutUnassignedCount`, `assignedNotJoinedCount`, and
  `oldestAssignedNotJoinedMs`. The legacy `routedCount` action field remains for
  dashboard compatibility and is no longer the only health signal. Heartbeats
  also report controller version `2026-07-22-assigned-arrival-v1` for rollout
  verification.
- `watchZoomHubBots` now treats at least one assigned-but-not-joined participant
  aged 30 seconds as a poisoned empty meeting. It ends that meeting on the next
  two-minute watcher run so the bot rejoins cleanly. The watcher never performs
  this reset when `inRoomOccupants` is nonzero. This is the server-side backstop
  if the browser-side recovery stalls.

Tests and production rollout:
- Local bot tests: `tests/bot_controller_html.test.js` plus `tests/routing.test.js`
  passed, 27/27.
- Functions test: `tests/zoom_handler.test.js` passed, 71/71, including immediate
  assigned-not-joined recovery, brief-transition protection, occupied-room
  protection, and the existing empty-room poison cases. Total focused checks:
  98/98. `git diff --check` passed for the touched routing files.
- The full Functions Jest run passed 28 suites / 315 tests and failed only the
  unrelated, already-uncommitted `quiz_competition.test.js` work (23 failures
  for missing/in-progress quiz helper exports and expectations). The Zoom
  handler suite remained 71/71 green; no quiz files were changed for this
  incident.
- The controller was backed up on the VPS as
  `bot_controller.html.bak_20260722_assigned_not_joined`, installed with SHA-256
  `7bd14a6370f6fe4a1f3da2c98a1bbfc9d12038c3e0e84202e2edb50a6d10c8d5`, and
  passed the remote inline-script test.
- The production `watchZoomHubBots` revision became `ACTIVE` at
  `2026-07-22T18:35:16Z`; its Cloud Scheduler job remains `ENABLED` every two
  minutes.
- Lane 1 was confirmed empty, then its meeting was reset and only
  `zoom-hub-bot@1` was restarted. The fresh controller read back
  `isAutoJoinRoom: true` and `isBackToMainSessionEnabled: false`, opened twelve
  readable rooms, and reported zero waiting users. During final rollout
  verification, one fresh instance briefly retained the older empty-room poison
  signature. The deployed controller detected it, exhausted two guarded
  close/reopen attempts, posted `resetMeeting`, and reloaded itself without a
  systemd restart. The replacement instance stabilized at twelve readable
  rooms, zero occupants, zero waiters, and zero actions. This was live proof of
  the existing clean-instance recovery path, not only a unit test.
- Lane 2 had two people actively inside a classroom, so it was intentionally not
  restarted. It remained healthy with ten readable rooms, two in-room
  occupants, zero `breakoutUnassigned`, and zero routing actions. The new
  controller is already installed on disk and loads on its next normal page
  transition; no live participant was interrupted.
- No Flutter, Hostinger web, Zoom participant client, or unrelated Firebase
  Function was deployed for this repair.

## 42. Zoom "Webhook Endpoint Is Not Responsive" Warning — 2026-07-28

Zoom App Marketplace emailed support@alluwal that the `classroom presence`
subscription on the "Alluwal Classroom Backend" app had an unresponsive
notification URL,
`https://us-central1-alluwal-academy.cloudfunctions.net/zoomWebhook`.

Investigation findings:
- The endpoint itself was healthy. A live `endpoint.url_validation` POST returned
  `200` with a correct `plainToken`/`encryptedToken` pair in about 100 ms, and
  `gcloud functions describe` showed `zoomWebhook` `ACTIVE` (last updated
  `2026-07-14T13:01:01Z`).
- Cloud Logging had zero `4xx`/`5xx` responses across seven days. The webhook
  secret and signature verification were never the problem.
- The real cause was latency. Zoom marks any delivery it cannot get a response
  for within 3 seconds as failed. Over the last 2000 POST deliveries: p50
  `0.32s`, p90 `1.39s`, p95 `2.04s`, p99 `3.91s`, max `7.48s`, with 78 of 2000
  (`3.9%`) exceeding 3 seconds.
- Every slow response matched a `Default STARTUP TCP probe succeeded ... container
  "worker"` log within a few seconds, so all of them were cold starts. The
  service ran with no `minScale` annotation, 256Mi, and `maxScale: 20`, so idle
  gaps between classes let Cloud Run scale to zero.
- The rate was structural rather than a regression: 8–19 over-3s deliveries per
  day, every day from 2026-07-14 through 2026-07-28.

Class impact assessed at the time of the warning:
- No presence data was lost. The handler completes its Firestore write before
  responding, so Zoom giving up on the response does not roll back the write.
  Production `livekit_sessions` showed correct join/leave pairs for that day's
  classes.
- Zoom retries are safe. `_recordZoomParticipantJoin` does not open a second
  window while one is open, and a retried leave adds no presence seconds because
  the window is already closed. Only `leave_count` can inflate.
- The risk was forward-looking: if Zoom disabled the subscription,
  `livekit_sessions` would stop receiving presence, and
  `functions/handlers/attendance.js` (`loadSessionsByShift`) has no fallback, so
  attended classes would be reported absent. Live roster is partly insulated
  because `buildZoomRoomPresence` prefers the hub bot roster.

Fix applied:
- `functions/handlers/zoom.js` now declares `ZOOM_WEBHOOK_RUNTIME_OPTIONS` with
  `minInstances: 1` and passes it to `onRequest`, keeping one warm instance so
  cold starts stay out of the presence path. The constant is exported through
  `__test__` so the deploy setting is assertable.
- `functions/tests/zoom_handler.test.js` adds `keeps a warm webhook instance so
  Zoom never waits past its 3s deadline`.
- No routing, join payload, bot lane, room assignment, guardrail, or meeting
  lifetime behavior was touched.

## 43. Duplicate Same-Block Lane Hub — "The host has another meeting in progress" — 2026-07-28

Symptom reported live: joining habibu barry's 15:00–16:00 ET class (lane 2) showed
Zoom's "The host has another meeting in progress." with a spinner, on a meeting
titled `Alluwal Classrooms 2026-07-28 Segment 1…` and a nonsense `Scheduled:
5:45 PM`.

Diagnosis (production data at 19:14Z):
- Lane 2 had **two** hubs whose windows were both active, both owned by
  `support@alluwaleducationhub.org`:
  - `zoom_hub_2026-07-28_2_1200_2`, meeting `89359283138`, created 11:08 ET,
    window 11:45–17:15, `roomsOpen` with a fresh bot heartbeat. Zoom REST:
    `status=started`.
  - `zoom_hub_2026-07-28_2_1400_2`, meeting `86875289793`, created 13:08 ET,
    window 13:45–17:15, `status=scheduled`, no heartbeat, bot never joined.
    Zoom REST: `status=waiting`.
- The four afternoon lane-2 classes (both habibu classes, `teacher test`, and
  Ibrahim Bah 16:00) had already been reassigned to the `1400` hub, so their join
  payloads pointed at `86875289793`. A Zoom user can host only one meeting at a
  time, and the account was busy hosting `89359283138`, so `86875289793` could
  never start — every joiner sat on Zoom's host-busy screen. The odd
  `Scheduled: 5:45 PM` was that unstarted meeting's `start_time` (21:45Z).

Trigger: habibu's 13:00 class was rescheduled to 11:00. That class was the bridge
in the padded rolling chain, so `_rollingHubSegmentForShift` re-split the day into
`11:00–13:00` and `14:00–17:00`. The afternoon group's anchor moved from 12:00 to
14:00, producing a different `hubDocId`, and `prepareZoomHubs` created a brand-new
meeting on the lane's already-busy host account. This is the block-boundary
one-hub-per-lane gap listed as "not yet live-tested" in §22.

Why existing protection missed it: `watchZoomHubBots` already hands the shared
account from an older block to a newer one, but it ranked hubs by `blockIndex`
alone. Both hubs had `blockIndex: 2` — they differed only by rolling segment
start — so `superseded` was false. The older hub's `window_end` (17:15) also still
looked live because it had been built to cover classes that had since moved away,
making `classesOver` false.

Live recovery (no code deploy, nothing interrupted — verified `inRoomOccupants: 0`,
`attendeeCount: 1` bot-only, and zero open `livekit_sessions` presence windows
first):
1. Paused `firebase-schedule-prepareZoomHubs-us-central1` so it could not
   re-point shifts mid-repair.
2. Restored `zoom_hub_2026-07-28_2_1400_2` to `scheduled` with its real window and
   pointed the four classes at it (this is the hub the routing code derives, so
   the state is stable).
3. Closed `zoom_hub_2026-07-28_2_1200_2`'s window and set `status: left`, so the
   lane-2 bot stopped being directed into it.
4. `zoomClient.endMeeting('89359283138')` to free the host account.
5. Bot joined `86875289793` and opened 9 rooms within ~20s; all four classes
   verified `READY` with their room live. Resumed the scheduler.

Fix applied (`functions/handlers/zoom.js`):
- `_zoomHubLaneOrderKey` / `_zoomHubLaneOrderIsNewer` rank lane hubs by
  `(blockIndex, window_start)` so two hubs sharing a block index are separable.
- `_zoomHubShouldReleaseSharedHost` decides whether an outranked hub may release
  the shared host account. It requires **both** guards: `inRoomOccupants === 0`
  and no remaining assigned class, so a live class can never be cut off.
- `_hubHasRemainingAssignedClasses` queries `teaching_shifts` by
  `hub_meeting_id`/`hubMeetingId` with `shift_end >= now`; it only runs for hubs
  already outranked and empty, so it adds no cost in the normal case.
- `watchZoomHubBots` builds `laneNewestActiveOrderKey` alongside the existing
  block map and adds `releasesSharedHost` to `shouldEndMeeting`, emitting a
  `duplicate_lane_hub_released` alert (added to the auto-resolve reason list).
- Existing block-supersede and 15-minute-limit behavior is unchanged.

Tests (`functions/tests/zoom_handler.test.js`, 76 pass):
- `bot watcher frees the shared host from a duplicate same-block segment hub`
  reproduces this incident end to end.
- `bot watcher keeps a duplicate-segment hub that still has a class assigned`.
- `bot watcher never frees a duplicate-segment hub with someone inside a
  classroom`.
- `lane ordering separates two hubs that share a block index`.
- The 23 failures in `functions/tests/quiz_competition.test.js` are pre-existing
  and unrelated (they fail with these changes stashed).

Deployed `watchZoomHubBots` to `alluwal-academy`. Post-deploy production check:
lane 2 has exactly one active hub (`..._1400_2`, `zoom=started`, 9 rooms, fresh
heartbeat) serving habibu 15:00–16:00 and Ibrahim Bah 16:00–17:00.

Remaining consideration: the watchdog repairs the condition within one 2-minute
cycle but does not prevent the duplicate meeting from being created. Preventing it
would mean having `ensureZoomHubMeeting` adopt a lane's already-live hub instead
of provisioning a second meeting on a busy host account. That is a larger change
to the join path and needs an owner decision.

### 43.1 Deeper audit — the real invariant is "zombie hubs", not block ordering

Follow-up investigation on 2026-07-28 (183 hub docs scanned, 2026-07-04 onward)
found the §43 fix addresses only part of the problem. Findings:

**Every same-block window overlap in history is this bug.** Of 15 same-lane
overlapping window pairs, 12 are benign legacy cross-block overlaps (all show a
bot heartbeat and were ended by the existing supersede path). The 3 same-block
overlaps are all the duplicate-hub defect:
- `2026-07-15` lane 2: `..._1_1100_2` never got a heartbeat (1 class, later
  re-pointed to the live hub and attended).
- `2026-07-17` lane 1: `..._1_1030_1` never got a heartbeat (1 class, Abdullah
  Baldee / Nafisatou Bah, no-show; that shift still points at the dead hub).
- `2026-07-28` lane 2: this incident.
Only 2 hubs in the entire history never received a heartbeat, and both are the
July 15 / July 17 duplicates — "no heartbeat ever" is a reliable fingerprint.

**Today actually had three hubs on lane 2, not two.** The 13:00 → 11:00 reschedule
orphaned the hub created at 11:08:
| hub | blockIndex | window ET | classes still assigned |
| --- | --- | --- | --- |
| `..._1_1100_2` | 1 | 10:45–13:15 | habibu 11:00, Thierno ×2 12:00 |
| `..._2_1200_2` | 2 | 11:45–17:15 (stale) | **none — all migrated away** |
| `..._2_1400_2` | 2 | 13:45–17:15 | habibu ×2, teacher test, Ibrahim Bah |

`..._2_1200_2` was a **zombie**: every class had moved to the 1100 or 1400 hub,
but nothing shrinks or retires a hub whose classes leave, so it kept an active
window and kept the shared host account from 11:45 to 15:20 — starving both real
hubs. Five classes were unjoinable: Thierno ×2 at 12:00 (0 joiners), habibu
14:00 + teacher test 14:00 (0 joiners), habibu 15:00 (only the admin, who
reported it).

**Why the lane bot latched onto the zombie.**
`_selectPrimaryActiveHub` (`functions/handlers/zoom_hub_bot.js`) protects a hub
only when `inRoomOccupants > 0` with a fresh heartbeat inside its real class
window; otherwise it sorts by `blockIndex` **descending** and serves the single
highest one. Consequences:
- It never considers whether a hub owns a class that is *due*. At the start of a
  class nobody is inside yet, so a starting class cannot pull the bot — a
  chicken-and-egg: you cannot get in because the bot is absent, and the bot will
  not come because nobody is in.
- Equal `blockIndex` compares to 0, and `Array.sort` is stable, so ties resolve by
  Firestore document order (ascending doc id). Today `..._2_1200_2` beat
  `..._2_1400_2` purely because `1200` sorts before `1400`.
Reproduced against production: at 11:50 ET with the 1100 and 1200 hubs both
active, `_selectPrimaryActiveHub` returns only `..._2_1200_2`, abandoning the hub
that owned the noon classes.

**Honest limit of the §43 fix.** It requires the releasing hub to be *outranked*
on its lane. Between 11:45 and 13:45 the zombie was the highest-ranked active hub
on lane 2, so the watchdog would not have released it and the noon Thierno classes
would still have failed. It would have auto-recovered the 14:00 and 15:00 classes
within ~2 minutes of 13:45, when `..._1400_2` became the newest.

**Fix shipped (2026-07-28, `watchZoomHubBots` only).** The rank-based release from
§43 was replaced by a zombie rule, because rank is not the discriminator — the
zombie was the highest-ranked active hub on its lane between 11:45 and 13:45, so
the §43 rule would have left the noon classes broken.
`_zoomHubIsHostHoldingZombie` now releases the shared host account when **all** of
these hold, with no reference to lane rank:
- the bot occupies the hub (`status` is `joined` or `roomsOpen`) — only then can it
  be holding the account;
- `stats.inRoomOccupants === 0`, so no live class is ever interrupted;
- no class assigned to the hub still ends in the future
  (`_hubHasRemainingAssignedClasses`, checked on both `hub_meeting_id` and
  `hubMeetingId`);
- the hub is older than `ZOOM_HUB_ZOMBIE_MIN_AGE_MS` (10 min), so a hub that is
  still mid-provisioning is never mistaken for one whose classes left.
On release the hub's window is also closed (`status: 'left'`, `window_end = now`,
`retired_reason: 'zombie_hub_released_shared_host'`); without that the bot is
directed straight back in and the hub is re-ended every cycle.

Two defects found while implementing it, both fixed in the same change:
- `_hubHasRemainingAssignedClasses` (added in §43) used
  `where(field,'==',hub).where('shift_end','>=',now)`, which needs a composite
  index that does not exist in production — it would have thrown and taken down the
  whole watcher invocation the first time it ran. It is now an equality-only query
  with the end-time filter applied in memory (a hub holds at most
  `ZOOM_HUB_MAX_ROOM_COUNT` classes), so no index is required.
- The ending path was gated on `!data.ended_at`. Provisioning restarts a retired
  hub doc on a fresh Zoom meeting **without clearing `ended_at`** (observed live:
  `..._2_1200_2` was `started` with `ended_at` still set from 15:22), so that stale
  flag permanently disabled both the 15-minute straggler limit and the zombie
  release for any re-provisioned hub. The guard now compares
  `ended_meeting_number` against the current meeting number, and only honours a
  bare `ended_at` once the window is over — which keeps a full-collection scan from
  re-firing dead Zoom calls across all 183 historical hubs. Retirement also
  proceeds when Zoom rejects `endMeeting` (meeting already gone), or a zombie with
  an already-dead meeting could never be cleaned up.

Verified in production at 16:18 ET: the leftover `..._2_1400_2` (bot-occupied,
dead meeting, window to 17:15, owning no classes, carrying a stale `ended_at`) was
retired automatically, while `..._2_1200_2` — which owned 7 classes including a
live one — was left untouched and joinable. Lane 2 returned to exactly one active
hub.

**Not a bug: the afternoon re-merge.** At 15:53 an admin rescheduled habibu's class
from 11:00 back to 13:00 (`decision_audits` records `shift.rescheduled` by an admin
actor, and `admin_modified: true` was set correctly — the shift-revert fix works).
That re-merged the padded chain, moved the anchor back to 12:00, and
`prepareZoomHubs` re-provisioned `..._2_1200_2` and re-pointed all seven lane-2
classes at it. The system self-healed because the anchor returned to a hub doc that
already existed. It is worth noting how sensitive routing is to a single reschedule:
two admin edits to one class rewrote the hub assignment of seven classes.

**Still open (needs owner decision).**
1. *Residual exposure window.* The watcher runs every 2 minutes, so a zombie can
   still hold the account for up to ~2 minutes plus the bot's rejoin time before
   self-healing. Only prevention in the join/provisioning path removes that.
2. *Keep hub windows truthful.* When classes are reassigned away, recompute the
   losing hub's `window_end` from the classes that remain. Because rolling
   segments only split on gaps wider than `2 × ZOOM_HUB_WINDOW_PADDING_MS`,
   distinct segments can never overlap by construction — so truthful windows make
   "two active hubs on one lane" structurally impossible, and the bot's choice
   becomes unambiguous. Provisioning should also clear `ended_at` when it restarts a
   retired hub doc, rather than relying on the `ended_meeting_number` comparison
   above.
3. *Rank by work, not by block.* `_selectPrimaryActiveHub` should prefer the hub
   that owns a class due now (start − padding ≤ now ≤ end) before falling back to
   occupancy and block index, so a starting class can pull the bot.
4. *Never provision onto a busy host.* `ensureZoomHubMeeting` should adopt a
   lane's already-live hub rather than create a second meeting the account cannot
   start.

**Edge cases that mutate a hub id for already-provisioned classes.** `hubDocId` is
derived from the anchor (earliest) class of the padded chain, so it is
content-addressed on a mutable set. Any of these re-splits or re-merges the chain
and silently moves classes to a different hub id: rescheduling a class (this
incident), deleting a bridging class, adding a bridging class (merges chains and
moves the anchor *earlier*), a class becoming guardrail-blocked or capacity-blocked
(excluded at `_queryZoomHubSegmentCandidateDocs`), `video_provider` leaving `zoom`,
a teacher change or `zoom_hub_lane_index` override moving the class to another lane
(`_laneIndexForShift` hashes `teacher_id`), and overflow spill to the other lane.
Attendance context: daily attendance runs 42–68% normally, so a single broken
lane is not visible in the daily rate — today read 6/17 (35%) against a 50–60%
baseline. These incidents will not surface in aggregate metrics; the reliable
signals are "hub never received a heartbeat" and "two active hubs on one lane".

## 44. Lane 2 split hub — 8 PM class never started — 2026-08-21

Symptom reported live at 21:26 ET: Bot 2 classes were not joinable. Bot 2 itself
was running (`zoom-hub-bot@2` active since 2026-08-11) and had routed people
earlier in the evening (Fatumata Jalloh, Fatumata Binta Diallo, AL-Hassan Diallo).

Diagnosis (production at ~21:56 ET):
- Lane 2 had **three** overlapping evening hubs on `support@`:
  - `zoom_hub_2026-08-21_2_1400_2`, meeting `84776276787`, window 13:45–21:15.
    Bot left at 16:46 ET (`zombie_hub_released_shared_host`). Habibu 17:00 and
    Thierno 18:00 were still pointed at this dead hub.
  - `zoom_hub_2026-08-21_3_1700_2`, meeting `89113548395`, window 16:45–21:15.
    Bot stayed here until 21:15 with `inRoomOccupants: 1` (Fatumata Binta Diallo
    leftover from the 18:00 class). Zoom REST: later `waiting` after window end.
  - `zoom_hub_2026-08-21_3_2000_2`, meeting `82358203149`, window 19:45–21:15,
    `status: scheduled`, **never received a heartbeat**. Fatumata Jalloh's
    20:00–21:00 class with Mariam Billguissu Diallo pointed here. Zoom REST:
    `waiting`. The host account was busy in the 1700 meeting, so this meeting
    could never start — same "host has another meeting in progress" failure as
    §43.
- The 1700 hub already had a breakout room for that 20:00 class
  (`356800 | Fatumata Jalloh`). Join payloads ignored it and sent people to the
  unstarted 2000 meeting.
- `_selectPrimaryActiveHub` treated 1700 as protected because
  `inRoomOccupants > 0` and `window_end - 15 min` was 21:00. The window had not
  been shrunk after the 20:00 class was split onto its own hub, so a leftover
  student from a finished class held the shared account through the 8 PM class.
- Stale-hub join handoff only ran when a heartbeat had existed and then gone
  stale. A hub that **never** heartbeated (2000) was treated as "bot inbound"
  and was not handed off to the live 1700 hub. Handoff also required a free
  spare and ignored an already-created room for the same shift.

Fix applied (`functions/handlers/zoom.js`, `functions/handlers/zoom_hub_bot.js`):
- `ensureZoomHubMeeting` adopts a same-lane hub that is `roomsOpen` with a
  fresh heartbeat instead of creating/using a second meeting the Pro host
  cannot start. Uses the live hub's existing room for that shift if present,
  otherwise a spare.
- `getZoomJoinInfo` does the same on join when the resolved hub is not live,
  not only when a heartbeat has gone stale.
- Handoff accepts a hub that already has this class's room, not only a free
  spare.
- Hub docs now store `assigned_class_end`. `_selectPrimaryActiveHub` uses that
  (falling back to `window_end - padding`) so a leftover occupant cannot
  protect a hub whose own classes are over. When no hub is protected, the bot
  prefers the hub that still has a class due.

Tests (`functions/tests/zoom_handler.test.js`):
- `adopts a live same-lane hub when a split hub never got a bot (2026-08-21 lane 2)`
- `does not create a second Zoom meeting when the lane bot is already live`
- `adopts the live same-lane hub even when its window is shorter than the new class`
- `does not stretch a live hub past the 28-hour Zoom lifetime; spills to the other lane`
- `spills to the other lane when the live same-lane hub has no spare`
- `still creates a first hub meeting when the lane has no live bot`
- `does not put a lane 2 class into a live lane 1 hub`
- existing primary-hub selection plus assigned_class_end straggler case

Hard rule now: if this lane's bot is already in a live meeting, we never
create or hand out a second Zoom meeting on that host. The later class is
moved onto the live hub and that hub's `window_end` / `assigned_class_end`
are extended to cover it, **only if the combined window stays at or under
`ZOOM_HUB_SAFE_MAX_MEETING_MINUTES` (28 h)**. If the live hub has no spare
or the extension would exceed 28 h, follow the existing overflow chain:
spill to the other lane, else single Zoom on a *non-hub* teacher host.
Single-mode fallback refuses `billing@` / `support@` so it cannot open a
second meeting on the busy Pro license. Cross-lane recovery still exists
for a hub that had a meeting and then went stale; a brand-new lane 2 class
is not dumped into a live lane 1 hub.

Deployed to `alluwal-academy`: `getZoomJoinInfo`, `prepareZoomHubs`,
`onTeachingShiftWritten`, `zoomHubBotDirectives`.

Remaining (not required to stop tonight's failure mode): shrinking a losing
hub's `window_end` when classes are reassigned away, so two same-lane hub
docs cannot stay active at once. Adoption is the join-path defense when a
split has already happened.
