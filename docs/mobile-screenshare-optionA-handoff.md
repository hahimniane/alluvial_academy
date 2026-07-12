# Mobile Screen Share on Zoom Classrooms — Technical Brief (Option A)

Purpose: enable **mobile users (iPhone + Android) to VIEW a shared screen** (and ideally to SHARE their screen) in the Zoom classroom, by moving the mobile client from the Zoom **Web** SDK to the Zoom **native** Meeting SDK inside the existing Flutter mobile app ("Option A"). This document is the full context to solve that. It states facts and constraints only.

---

## 1. Product & architecture

- Flutter app (web + Android + iOS) + Firebase (Auth, Firestore, Cloud Functions, Hosting). Web is deployed to Hostinger; mobile app is published on the App Store and Play Store.
- Zoom classrooms use a **hub / breakout-room model** to run many concurrent classes on only **2 licensed Zoom accounts** (`billing@alluwaleducationhub.org`, `support@alluwaleducationhub.org`):
  - Per time-block and per licensed account ("lane"), one **hub Zoom meeting** is created.
  - Two **headless Chromium "controller bots"** (one per licensed account) run on a VPS. Each bot joins its hub meeting as **host** (role 1 + ZAK), pre-creates one **breakout room per class**, opens rooms with `isAutoJoinRoom: true`, and then continuously **routes each participant into their class's breakout room**.
  - Every human (teacher, student, parent, admin) joins as a **participant (role 0)**. Only the bot is host.
- **How the bot routes a participant to the correct breakout room:** at join, each participant carries a **`customerKey`** = `zh_<sha256(uid:shiftId)>` (a per-class key). The backend writes a member doc `hub_meetings/{hubId}/members/{customerKey}` = `{shiftId, userId, role, displayName, realDisplayName}`. The bot reads live participants via `getAttendeeslist()` / `getBreakoutRooms()`, reads each participant's `customerKey`, looks up the member doc, and calls `assignUserToBreakoutRoom` / `moveUserToBreakoutRoom` to place them in the room whose name matches their `shiftId`.
  - **Fallback:** when a participant's `customerKey` is absent, the bot/webhook map the participant by **exact display-name match** against the member docs' `displayName`. For this to be unambiguous, that display name must be unique within the hub.

## 2. Current mobile behavior (the problem)

- On web (desktop browsers) everything works, including viewing shared screens.
- Mobile users currently join through the **web page** `web/zoom_meeting.html` (in a mobile browser, or a WebView), i.e. via the Zoom **Web** Meeting SDK (pinned CDN `https://source.zoom.us/6.2.0/...`, client view).
- **Confirmed problem:** on mobile browsers (iPhone Safari/Chrome AND Android), a participant **cannot see a screen that another participant is sharing**. Desktop viewers see it fine.

## 3. What has been tried and VERIFIED (do not re-investigate these)

- **Sharing FROM iOS via web is impossible**: iOS/WebKit does not implement `getDisplayMedia`; no web page can capture/share a screen on iOS. (Android Chrome web can share where the OS supports it.)
- **Viewing a shared screen on mobile web was hypothesized to need SharedArrayBuffer (cross-origin isolation).** This was tested and RULED OUT as the cause:
  - `web/zoom_meeting.html` was switched from `Cross-Origin-Embedder-Policy: credentialless` to `require-corp` (scoped only to that page via `.htaccess`), and `crossorigin="anonymous"` was added to the Zoom CDN `<script>`/`<link>` tags. Zoom's AV/media CDN resources send `Cross-Origin-Resource-Policy: cross-origin`, so `require-corp` does not block the SDK.
  - Verified on desktop: page loads, joins real meetings, `window.crossOriginIsolated === true`, `SharedArrayBuffer` available.
  - Verified on a real **iPhone**: after this change, an on-screen readout showed `COI:true SAB:true` (cross-origin isolated AND SharedArrayBuffer present) — **and the shared screen STILL did not render.**
  - Conclusion (verified): the Zoom **Web** SDK does not render a received screen share on iOS Safari even with SharedArrayBuffer. This is a Zoom-Web-SDK/WebKit limitation, not a header/config issue. (The `require-corp` change is currently still deployed on `web/zoom_meeting.html`; it can be kept or reverted independently.)

## 4. Option A definition

Move the mobile client off the Web SDK onto the **native Zoom Meeting SDK** (Android AAR / iOS xcframework) inside the Flutter app, because the native SDK fully supports mobile screen-share **receive and send**. The native client must still be **routed into the correct breakout room by the hub bot** so class isolation is preserved.

## 5. Historical Option A blocker and current routing state

Historical finding from the first Option A pass: the obvious native mobile
join-parameter classes did not expose the Web SDK `customerKey`, so the initial
native routing solution used a deterministic display-name suffix:
- iOS `MobileRTCMeetingJoinParam` fields: `noAudio, noVideo, participantID, vanityID, meetingNumber, userName, password, webinarToken, zak`. (No `customerKey`.) — https://zoom.github.io/zoom-sdk-ios/interface_mobile_r_t_c_meeting_join_param.html
- Android `JoinMeetingParams` fields: `meetingNo, displayName, password, vanityID, webinarToken`. (No `customerKey`.) — https://zoom.github.io/zoom-sdk-android/us/zoom/sdk/JoinMeetingParams.html
- `customerKey` is documented for the Web SDK `ZoomMtg.join` only. Zoom devforum confirms it is not settable from the mobile SDKs: https://devforum.zoom.us/t/retrieve-customerkey-property-in-mobile-sdks/51144

Current source state as of 2026-07-06: current native builds pass the hidden
routing key where the Meeting SDK exposes it outside the basic join-param class:
iOS sets `MobileRTCMeetingJoinParam.customerKey`, and Android sets
`JoinMeetingOptions.customer_key`. The backend therefore returns clean
`displayName` / `nativeDisplayName`; the old suffixed `routingDisplayName` remains
stored on hub member docs only as an old-build fallback.

## 6. Relevant code & assets

- Mobile Zoom screen (native path): `lib/core/widgets/zoom_meeting_screen_io.dart`.
  It forwards `meetingId`, `password`, clean display name, `customerKey`,
  `breakoutRoomName`, `breakoutRoomKey`, `autoJoinBreakoutRoom`, and
  `classEndsAt` into the native wrapper.
- Web Zoom screen (reference for all join params passed): `lib/core/widgets/zoom_meeting_screen_web.dart`.
- Join-info model + call site: `lib/core/services/class_video_service.dart` (`ZoomClassJoinInfo`, and the `ZoomMeetingScreen(...)` construction). `getZoomJoinInfo` returns: `meetingNumber, password, signature, sdkKey, displayName, realDisplayName, customerKey (zh_...), breakoutRoomName, breakoutRoomKey (=shiftId), autoJoinBreakoutRoom, routingMode ('hub'|'single'), hubMeetingId, classEndsAtIso`.
- Backend: `functions/handlers/zoom.js` (`getZoomJoinInfo`, `ensureZoomHubMeeting`, `_zoomHubCustomerKey`, `_writeZoomHubMember`, `_findHubMemberForRoutingKey`, `_findHubMemberForRoutingDisplayName`, `zoomWebhook`, `watchZoomHubBots`). Bot routing: `services/zoom-hub-bot/bot_controller.html` + `services/zoom-hub-bot/routing.js` (`whoNeedsToMoveWhere`, reads `customerKey` variants). Bot endpoints: `functions/handlers/zoom_hub_bot.js`.
- Living reference for the whole Zoom hub system: `docs/zoom-hub-bot-plan.md` (read it; §1 lists product invariants including "two teachers never in the same room" and "nobody sees the hub main session").
- Current mobile plugin: the vendored `packages/flutter_zoom_meeting_wrapper/`
  package. API: `initZoom(jwt)`, `joinMeeting({meetingId, meetingPassword,
  displayName, routingDisplayName, customerKey, breakoutRoomName,
  breakoutRoomKey, autoJoinBreakoutRoom, classEndsAtIso})`. Native mapping:
  - Android `android/src/main/kotlin/.../FlutterZoomMeetingWrapper.kt` → builds
    `us.zoom.sdk.JoinMeetingParams`, passes `customerKey` through
    `JoinMeetingOptions.customer_key`, keeps sharing enabled, and listens for
    BO attendee callbacks to call `IBOAttendee.joinBo()`.
  - iOS `ios/Classes/FlutterZoomMeetingWrapperPlugin.swift` → builds
    `MobileRTCMeetingJoinParam`, sets `customerKey`, handles BO attendee/switch
    callbacks, and uses the ReplayKit screen-share extension for outgoing share.
- Zoom SDK binaries are NOT in the repo. Android uses the official Maven Central
  artifact `us.zoom.meetingsdk:zoomsdk`; iOS still expects the SDK frameworks
  placed manually:
  - iOS: `MobileRTC.xcframework` (+ companion frameworks, `MobileRTCResources.bundle`) in the plugin's `ios/Frameworks/`.
  - Android fallback only: `mobilertc.aar` in the plugin's `libs/` if the Gradle
    dependency is intentionally reverted from Maven to a local AAR.

## 7. Constraints the solution must satisfy

- Preserve hub invariants: each participant must end up ONLY in their own class's breakout room; two classes never share a room; participants never remain in the hub main session.
- Auth: the SDK is authorized with the Meeting SDK **signature** (JWT embedding the SDK key) returned by `getZoomJoinInfo` (role 0). No user Zoom login.
- Breakout auto-join: the host bot opens rooms with `isAutoJoinRoom: true`; the native SDK is expected to auto-join the assigned breakout room once the bot assigns the participant.
- Build/release realities: requires the Zoom Meeting SDK binaries (Zoom Marketplace download), a native build (Xcode / Android), device testing, and App Store + Play Store releases.

## 8. The exact question to solve

Given that the native mobile Zoom Meeting SDK cannot send `customerKey`, define and implement how a native mobile app participant (role 0, SDK-signature auth) is reliably routed into the correct per-class breakout room by the existing hub bot — then extend `lib/core/widgets/zoom_meeting_screen_io.dart` and the (forked) native plugin accordingly, wire the Zoom SDK binaries, and produce a build/release path. Success = a mobile app user in a class can SEE a shared screen (and SHARE their screen), while remaining isolated in their own class's breakout room.

## 9. Implemented Option A routing solution — 2026-07-05

Chosen routing mechanism: **native mobile hub joins use a deterministic class-scoped Zoom display name** because Android/iOS Meeting SDK guest join params still do not expose Web SDK `customerKey`.

Implementation:
- `getZoomJoinInfo` accepts `clientPlatform: 'native_mobile'`.
- For hub-routed native mobile joins, it returns `displayName`/`nativeDisplayName` as `"<real name> #<8-char token>"`, derived from the existing `zh_<sha256(uid:shiftId)>` routing key.
- Hub member docs still use the `zh_...` doc id and clean `realDisplayName`, but now also store `routingDisplayName` and `displayNameAliases`.
- `zoomHubBotAssignments` sends those alias fields to the VPS bot.
- The bot routing helper maps exact display-name aliases only when the alias maps to a single target room, so duplicate clean names remain ignored while native class-scoped names route safely.
- `zoomWebhook` now treats display-name fallback as valid only when exactly one hub member matches that display name/alias.
- Flutter mobile calls `getZoomJoinInfo` with `clientPlatform: native_mobile`, passes `nativeDisplayName` into `ZoomMeetingScreen`, and the native wrapper joins using that exact name.
- The Zoom wrapper is vendored at `packages/flutter_zoom_meeting_wrapper/` and `pubspec.yaml` points at the local path.
- Native SDK binary placement and release gates are documented in `docs/zoom-native-mobile-sdk-runbook.md`.

Verification completed locally:
- `node --check functions/handlers/zoom.js && node --check functions/handlers/zoom_hub_bot.js && node --check services/zoom-hub-bot/routing.js`
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` — 50 passed.
- `cd services/zoom-hub-bot && npm test` — 20 passed.
- `cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` — 22 passed; added specifically to guard the working desktop/web classroom path.
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/services/class_video_service.dart lib/core/widgets/zoom_meeting_screen_io.dart lib/core/widgets/zoom_meeting_screen_web.dart packages/flutter_zoom_meeting_wrapper/lib` — passed.
- `flutter test packages/flutter_zoom_meeting_wrapper/test` — 5 passed.
- `git diff --check` — passed.

Not completed in this workstation/session:
- Zoom native SDK binaries are still not present. Required paths are in `docs/zoom-native-mobile-sdk-runbook.md`.
- No Android or iOS native build was run because `mobilertc.aar`, `MobileRTC.xcframework`, `MobileRTCScreenShare.xcframework`, `MobileRTCResources.bundle`, and companion iOS frameworks are not installed locally.
- No physical-device Zoom acceptance was run. Release remains blocked until Android and iOS devices prove native join, breakout routing, shared-screen receive, screen-share send, clean presence/no-show rows, and safe Leave behavior.

## 10. iPhone build attempt update — 2026-07-05

An iPhone physical-device build was attempted after locating a local Zoom iOS SDK download at `/Users/hashimniane/Downloads/zoom-sdk-ios-6.6.9.29800/lib`.

What changed for the attempt:
- The iOS SDK frameworks/bundle were symlinked into `packages/flutter_zoom_meeting_wrapper/ios/Frameworks/` instead of copied to conserve disk.
- `cd ios && pod install` was completed after seeding the missing Firebase 12.15.0 podspec into the local CocoaPods cache.
- Swift Package Manager was enabled because `realtimekit_core_ios` requires it.

Result:
- The first build reached the Xcode link step on the physical iPhone target, then failed with `Framework 'MobileRTC' not found`.
- The local `MobileRTC.xcframework` was missing its declared binary at `ios-arm64/MobileRTC.framework/MobileRTC`; only headers/resources were present. That SDK package could not produce an iOS app binary.

Follow-up:
- Downloaded Zoom's official GitHub release asset for v6.6.9: `https://github.com/zoom/meetingsdk-ios/releases/download/v6.6.9/zoom-meeting-sdk-iOS.zip`.
- Extracted it to `/Users/hashimniane/Downloads/zoom-sdk-ios-6.6.9-github/zoom-meeting-sdk-iOS`, removed the zip, and repointed the wrapper symlinks to that complete SDK copy.
- Verified `MobileRTC.xcframework/ios-arm64/MobileRTC.framework/MobileRTC` exists and is a Mach-O arm64 dynamic library.
- `cd ios && pod install` completed.
- `flutter run -d 00008150-000242E41191401C --debug --no-resident` built, installed, and launched on the physical iPhone after disabling LLDB attach with `flutter config --no-enable-lldb-debugging`.
- The iPhone app was then stopped so the owner can relaunch it manually.
- Production deploy completed for `getZoomJoinInfo`, `zoomWebhook`, and `zoomHubBotAssignments`.
- VPS `routing.js` was updated. Lane 2 was restarted because it had zero in-room occupants; lane 1 was not restarted because it had one participant inside a room.
- No Hostinger web deploy was run.

Remaining requirement:
- Run the actual native Zoom join acceptance on the iPhone: hub-routed class join, correct breakout-room move, shared-screen receive, screen-share send, clean Leave behavior, and clean presence/no-show rows. If testing a lane-1 class immediately, wait for a safe lane-1 bot reload/restart first.

## 11. Native mobile routing bug FIXED + shared-screen receive VERIFIED — 2026-07-05

Physical-iPhone acceptance run surfaced a routing bug that stranded native mobile
participants, root-caused and fixed the same session.

Symptom: a native-mobile student (real device, release build) joined the hub but
stayed in the **hub main session** with the controller bot instead of being moved
into their class breakout room. The web teacher in the same class routed fine.

Root cause (VERIFIED via live lane-2 bot logs): a participant who joins **after**
the breakout rooms are already open lands in Zoom's `breakoutUnassigned` pool,
which is separate from the main-session `unassigned` list. `whoNeedsToMoveWhere`
in `services/zoom-hub-bot/routing.js` only iterated room participants + the
`unassigned` list, so it never saw anyone in `breakoutUnassigned` and could not
route them. Native mobile clients hit this every time: they carry no `customerKey`
and typically join after rooms open, so they were never moved. The alias→room
mapping itself was correct (confirmed against `zoomHubBotAssignments`: member
`test student #wmCwjEzH` → shift `ebUnYUsKQdYFcqdl8VcH` → room `dl8VcH | Billing
Test`). The existing native-alias unit test passed only because it placed the user
in `unassigned`, which real Zoom does not do for late joiners.

Fix (`services/zoom-hub-bot/routing.js`):
- Added `normalizeBreakoutUnassigned()` (reads `breakoutUnassigned` and snake/`result.*`
  variants) and made `whoNeedsToMoveWhere` also process that bucket, routed by
  display-name alias exactly like main-session arrivals. Exported the new helper.
- Added a regression test in `services/zoom-hub-bot/tests/routing.test.js` that
  reproduces production: native student in `breakoutUnassigned`, bot alone in
  `unassigned`, asserts the student is assigned into the target room.
- `cd services/zoom-hub-bot && npm test` — 21 passed (was 20).

Deploy + live verification:
- Uploaded fixed `routing.js` to the VPS (backup `routing.js.bak_*_breakout`),
  `node --check` OK, restarted lane 2 (only the test class occupied it), then
  lane 1 (empty of humans) so both lanes run the fix.
- Live lane-2 logs after fix: bot assigned `test student #wmCwjEzH` into the
  class room via display-name alias; `dl8VcH | Billing Test` reached
  `participantCount:2` (web teacher + native mobile student together);
  `breakoutUnassigned` drained to empty.

Acceptance results this run:
- Native hub-routed class join: PASS.
- Correct breakout-room move (native mobile, no customerKey): PASS (after fix).
- Shared-screen **receive** on the mobile app (teacher shares from desktop/web,
  student sees it): PASS — the core Option A goal is proven on a real iPhone.

Still open (at the time of §11; screen-share send is now DONE — see §12):
- Screen-share **send** from iOS — implemented and verified in §12.
- The device build ran as a locally re-signed **release** app with its version
  bumped to `99.0.0` to clear the Remote Config force-update gate; not a store build.
- Clean Leave behavior and presence/no-show row checks for the native path still
  to be run.

## 12. Screen-share SEND from iOS — IMPLEMENTED & VERIFIED — 2026-07-05

Device screen sharing from the mobile app now works end to end: a mobile student
taps Share → Screen, broadcasts the whole device screen, and web/desktop
participants see it live — and it keeps streaming while the student navigates to
other apps. Verified on a physical iPhone (iOS 27) against a real class.

iOS requires a **Broadcast Upload Extension** (ReplayKit) for full-device
capture; the app process cannot capture the screen itself. The full setup:

### 12.1 New Xcode target: Broadcast Upload Extension "ScreenShare"
- Added target `ScreenShare` (product type `com.apple.product-type.app-extension`),
  bundle id `com.example.alluwalacademyadmin.ScreenShare`, Minimum Deployments
  iOS 15.0 (match Runner).
- `ios/ScreenShare/Info.plist`: `NSExtensionPointIdentifier =
  com.apple.broadcast-services-upload`, `NSExtensionPrincipalClass =
  $(PRODUCT_MODULE_NAME).SampleHandler`, `RPBroadcastProcessMode =
  RPBroadcastProcessModeSampleBuffer`.
- `ios/ScreenShare/SampleHandler.swift`: subclasses `RPBroadcastSampleHandler`,
  conforms to `MobileRTCScreenShareServiceDelegate`, forwards ReplayKit callbacks
  to a `MobileRTCScreenShareService` whose `appGroup` is the shared group id.

### 12.2 App Group (shared between app and extension)
- Group id `group.com.example.alluwalacademyadmin.screenshare` added as an App
  Groups capability on BOTH the Runner and ScreenShare targets. Written to
  `ios/Runner/Runner.entitlements` and `ios/ScreenShare/ScreenShare.entitlements`.
  The **same** string appears in the plugin (`screenShareAppGroupId`) and the
  extension's `SampleHandler`.

### 12.3 ScreenShare target build settings (`ios/Runner.xcodeproj/project.pbxproj`)
`MobileRTCScreenShare.xcframework` is Objective-C with **no Clang module map**, so
`import MobileRTCScreenShare` fails. Instead, on the ScreenShare target's Debug /
Release / Profile configs:
- `FRAMEWORK_SEARCH_PATHS += $(SRCROOT)/../packages/flutter_zoom_meeting_wrapper/ios/Frameworks/MobileRTCScreenShare.xcframework/ios-arm64`
- `SWIFT_OBJC_BRIDGING_HEADER = ScreenShare/ScreenShare-Bridging-Header.h`
  (`#import <MobileRTCScreenShare/MobileRTCScreenShareService.h>`)
- `OTHER_LDFLAGS += -framework VideoToolbox` (the encoder uses VideoToolbox;
  without it the extension fails to link with undefined `VT*` symbols).
- `MobileRTCScreenShare.xcframework` added to the ScreenShare target's Frameworks
  (Embed & Sign); `ReplayKit.framework` auto-added by Xcode.

Delegate/API note: on this SDK+toolchain Swift does NOT split "WithError", so the
delegate method is `mobileRTCScreenShareServiceFinishBroadcastWithError(_:)` and
ReplayKit's finish call is `finishBroadcastWithError(_:)` (both unlabeled) —
verified with `swiftc -typecheck`, not guessed.

### 12.4 Build-phase cycle fix (Runner target)
Adding the "Embed Foundation Extensions" phase created an Xcode dependency cycle
("Cycle inside Runner"). Fixed by moving Runner's **"Thin Binary"** run-script
phase to be the **last** build phase (after Embed Foundation Extensions).

### 12.5 Main-app plugin wiring (`packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`)
- On `MobileRTCSDKInitContext`: `appGroupId = group.com.example.alluwalacademyadmin.screenshare`
  and `replaykitBundleIdentifier = com.example.alluwalacademyadmin.ScreenShare`.
- Implemented the meeting delegate method `onClickShareScreen(_ parentVC:)` — this
  is what makes Zoom's default UI surface the "Screen" option; it presents an
  `RPSystemBroadcastPickerView` with `preferredExtension` = the extension bundle
  id and programmatically triggers it, so tapping "Screen" jumps straight to the
  broadcast sheet for our extension.

### 12.6 Background continuity fix
Symptom: broadcast dropped with "Live Broadcast to ScreenShare has stopped due
to: Connection failed" the moment the user left the Zoom app. Cause: iOS suspends
the app, breaking the broadcast relay. Fix: added `audio` to `UIBackgroundModes`
in all Runner Info plists (`Info.plist`, `Info-Release.plist`, `Info-Debug.plist`,
`Info-Profile.plist`). The active meeting audio keeps the app alive in the
background, so the screen share survives navigating to other apps. VERIFIED.

### 12.7 Build/release realities
- Everything above is a **native project change** now in the working tree; a real
  App Store build must include it (the extension target, entitlements, pbxproj
  settings, Info.plist background mode, and plugin code).
- Test builds used `flutter build ios --release`, then `xcrun devicectl device
  install app` over USB, with `pubspec.yaml` version temporarily bumped to
  `99.0.0` to clear the force-update gate (reverted to `1.1.1+22` after each build).
- The App Group and extension bundle id are provisioned under the personal Apple
  team `GRKB7BXVZK` (`nenenane2@gmail.com`) with automatic signing; a store build
  under the production team must register the same App Group + extension bundle id.

Remaining: clean Leave behavior + presence/no-show checks for the native path;
production store release under the org signing identity.

## 13. Leave-meeting return-to-app UX — 2026-07-06

Problem: with Zoom's default meeting UI (`setMobileRTCPresentationScene`), tapping
"Leave Meeting" left the user on a **black screen**, then (after fixes) on a stuck
Zoom **"Waiting..." HUD**, instead of returning to the app.

Implemented in `packages/flutter_zoom_meeting_wrapper` + `lib/core/widgets/zoom_meeting_screen_io.dart`:
- **Window restore**: the plugin captures the app's own (Flutter) `UIWindow`
  before Zoom presents its meeting UI, and on meeting end (`.ended`/`.idle`)
  re-keys it (`makeKeyAndVisible`). This alone fixed the black screen but exposed
  a leftover Zoom window.
- **onMeetingEnded → Navigator.pop**: added a native→Flutter callback. The Swift
  plugin retains the `FlutterMethodChannel` and calls `invokeMethod("onMeetingEnded")`
  on `.ended`/`.idle` (guarded by `meetingEndNotified`, reset on join). The Dart
  wrapper exposes `ZoomMeetingWrapper.onMeetingEnded` via a method-call handler;
  `ZoomMeetingScreen` sets it in `initState` and pops itself when it fires. This
  returned the user to the class Overview screen. VERIFIED working.
- **Hide Zoom's leftover window**: on meeting end, hide any window in the scene
  that isn't the app's own window (sparing keyboard/text-effects windows), to
  clear Zoom's orphaned meeting window.

STATUS: black screen fixed; user returns to the app. STILL OPEN: a Zoom
**"Waiting..." HUD** ("Waiting..." is a confirmed MobileRTC framework string) can
persist over the app after leaving — the single window-hide pass did not reliably
clear it. Suspected causes: the HUD window is created/re-shown by Zoom *after* the
synchronous hide runs (timing), or leaving mid-teardown makes Zoom attempt a
reconnect. Next steps to try: delayed + repeated cleanup passes after `.ended`
(e.g. 0 / 0.4 / 1.0s), dismissing any presented VC on the host root, and/or
confirming via the VPS bot logs whether the participant actually left (stuck HUD)
vs. is reconnecting (real waiting state).

## 14. Native Leave waiting-HUD cleanup build — 2026-07-06

Implemented the next cleanup step from §13 and installed it on the connected
physical iPhone.

Change:
- `packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`
  now schedules repeated post-leave cleanup passes after `.ended`/`.idle` instead
  of doing one synchronous pass.
- Each pass hides non-app, non-system windows, dismisses presented controllers on
  the Zoom/app windows, restores the Flutter host window, and sends
  `onMeetingEnded` once to Dart.
- Cleanup passes run at 0, 0.25, 0.75, 1.5, and 2.5 seconds so a Zoom
  `MobileRTC` "Waiting..." HUD created after the first teardown pass should also
  be removed.

Verification/build:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift` passed.
- Zoom iOS SDK symlinks were present and complete for `MobileRTC.xcframework`,
  `MobileRTCScreenShare.xcframework`, and `MobileRTCResources.bundle`.
- `flutter pub get && cd ios && pod install` passed.
- `flutter build ios --release --build-name=99.0.0 --build-number=9900` passed
  and produced `build/ios/iphoneos/Runner.app` (384.2 MB).
- Installed on `Hashim's iphone 17 pro max`
  (`00008150-000242E41191401C`) with `xcrun devicectl device install app`.
- Launched the installed app with `xcrun devicectl device process launch`.

Not verified:
- No live Zoom class was joined after this install, so the Leave waiting-HUD fix
  still needs a real tap-Leave check on the phone.
- No Firebase Functions, Hostinger web, or VPS bot deploy was run.

## 15. Stronger native Leave cleanup build — 2026-07-06

The first §14 install still left MobileRTC's "Waiting..." HUD visible after
tapping Leave on the phone.

Change:
- `FlutterZoomMeetingWrapperPlugin.swift` now calls `MobileRTC.shared().cleanup()`
  once after `.ended`/`.idle`, then keeps the repeated cleanup passes.
- Cleanup now also scans the restored app window/root view and removes residual
  Zoom/MobileRTC/HUD UIKit views, including views whose class names include
  `MobileRTC`, `Zoom`, `ZM`, `ZP`, or `MBProgressHUD`, plus any UIKit label/button
  or accessibility label containing `Waiting`.
- Cleanup pass timings are now 0, 0.15, 0.35, 0.75, 1.5, 2.5, 4.0, and 6.0
  seconds after meeting end.

Verification/build:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift` passed.
- `flutter build ios --release --build-name=99.0.0 --build-number=9901` passed
  and produced `build/ios/iphoneos/Runner.app` (384.2 MB).
- Installed and launched on `Hashim's iphone 17 pro max`
  (`00008150-000242E41191401C`) with `xcrun devicectl`.

Not verified:
- The user still needs to re-test the exact Leave flow on the phone after this
  `9901` install.
- No Firebase Functions, Hostinger web, or VPS bot deploy was run.

## 16. Native iOS breakout auto-join fix — 2026-07-06

Live lane-2 testing showed a different native failure after the bot-side
`breakoutUnassigned` fix: the bot correctly assigned the iOS native participant
to the target class room, but the client stayed in Zoom's assigned/not-joined
state. The host follow-up `moveUserToBreakoutRoom` then failed with `user not in
a room`, because the attendee had never accepted/joined the assigned BO.

Root cause:
- Zoom's iOS Meeting SDK exposes attendee-side breakout APIs in
  `MobileRTCBOAttendee`. The relevant SDK state is `BOUserStatusNotJoin`
  ("assigned but has not joined the breakout meeting").
- The Flutter wrapper was passing `autoJoinBreakoutRoom` and `breakoutRoomName`
  from Dart, but the Swift plugin ignored them and never called
  `MobileRTCBOAttendee.joinBO()`.
- Web clients are pulled by the Web SDK/host `isAutoJoinRoom` behavior; the
  native iOS client needs the attendee-side join path.

Change:
- `packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift`
  now reads `autoJoinBreakoutRoom` and `breakoutRoomName` from `joinMeeting`.
- On `.inMeeting`, `onHasAttendeeRightsNotification`, `onBOSwitchRequestReceived`,
  `onBOStatusChanged`, `onBOInfoUpdated`, and `onBOListInfoUpdated`, it schedules
  timed attempts to call `MobileRTCBOAttendee.joinBO()`.
- The join loop only runs when the backend requested breakout auto-join. If Zoom
  exposes the assigned room name, the wrapper verifies it matches the expected
  room before joining; if Zoom has not exposed a name yet, it still tries the
  attendee's assigned BO so the client does not remain in assigned/not-joined
  limbo.
- The retry schedule runs up to 45 seconds and is cancelled on join failure or
  meeting end.

Verification/build:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift` passed.
- `flutter test packages/flutter_zoom_meeting_wrapper/test` passed: 5 tests.
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/widgets/zoom_meeting_screen_io.dart packages/flutter_zoom_meeting_wrapper/lib` passed.
- `cd ios && pod install` passed.
- `flutter build ios --release --build-name=99.0.0 --build-number=9902` passed
  and produced `build/ios/iphoneos/Runner.app` (384.3 MB).
- Installed on paired physical iPhone `Hashim's iphone 17 pro max`
  (`E7C7C7F2-1872-5B15-B919-391158906FAD`) with `xcrun devicectl device install
  app`, then launched with `xcrun devicectl device process launch`.

Not verified:
- No live Zoom class was joined after the `9902` install. Required live check:
  join the hub-routed test class on the phone, watch iPhone device logs for
  `Alluwal Zoom: attendee joinBO result=true`, watch lane-2 bot logs to verify
  `breakoutUnassigned` drains, confirm the student lands in the target room and
  does not enter the kick/rejoin loop.
- No Firebase Functions, Hostinger web, or VPS bot deploy was run.

## 17. Native iOS breakout transfer cleanup guard — 2026-07-06

After the first native BO join patch, live lane-2 logs showed the native alias
could enter the target room, but the user still reported being kicked out. A
likely wrapper-side cause was the existing leave-cleanup path: it treated
`MobileRTCMeetingState.idle` the same as a real meeting end and called
`MobileRTC.shared().cleanup()`. Zoom's iOS SDK has explicit `JoinBO` / `LeaveBO`
states, so an `idle` transition during BO transfer must not be treated as a
completed leave.

Change:
- `FlutterZoomMeetingWrapperPlugin.swift` now logs every meeting-state change
  with BO status, whether BO is started, and whether the client is in BO.
- It tracks `meetingIsDisconnecting` and only runs the `.idle` cleanup path after
  a real `.disconnecting` state. A transient `.idle` during BO transfer no longer
  tears down MobileRTC.
- Added logs for BO attendee rights, BO status, BO switch requests, and BO data
  updates to make the next device-side diagnosis concrete.

Verification/build:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift` passed.
- `flutter build ios --release --build-name=99.0.0 --build-number=9903` passed
  and produced `build/ios/iphoneos/Runner.app` (384.3 MB).
- Installed and launched on paired physical iPhone `Hashim's iphone 17 pro max`
  (`E7C7C7F2-1872-5B15-B919-391158906FAD`) with `xcrun devicectl`.

Live lane-2 evidence after `9903` install:
- Native `test student #RpxOs2WG` joined, appeared in `breakoutUnassigned`, was
  assigned to `EV5fLi | Billing Test`, then `breakoutUnassigned` drained to empty
  and the target room stayed at `participantCount: 2`.
- A later native join as `nene nane #4dlaQ9Jo` followed the same pattern:
  assignment returned follow-up `user already in the target room`, then
  `breakoutUnassigned: []`.
- The bot no longer showed the old repeated `user not in a room` loop during
  those `9903` checks.

Still open:
- Device-side logs were not captured during the successful-looking `9903` live
  join, so if the phone UI still exits while the bot shows the participant in the
  room, the next step is to launch with `xcrun devicectl ... --console` or attach
  LLDB/log streaming and read the new `Alluwal Zoom: meeting state raw=...` lines.
- No Firebase Functions, Hostinger web, or VPS bot deploy was run.

## 18. Native iOS BO transfer deferred-end guard — 2026-07-06

Follow-up device logs from the paired iPhone showed two distinct failure shapes:

1. During BO transfer, MobileRTC can report `JoinBO -> Reconnecting -> Ended`.
   The wrapper must not immediately call `MobileRTC.shared().cleanup()` for that
   `.ended` state when a breakout transfer is in progress; that can tear down the
   SDK before it settles into the breakout meeting.
2. After stale hub testing, the phone later showed `Connecting -> WaitingForHost
   -> Disconnecting -> Ended` while the lane bot did not see the native alias in
   its attendee list. That was not the original assigned-not-joined bug; it was a
   stale meeting/lane state. Lane 2 was reset before the next test.

Change:
- `FlutterZoomMeetingWrapperPlugin.swift` now tracks `breakoutTransferInProgress`
  on `MobileRTCMeetingState.joinBO`.
- If `.ended` arrives during an active BO transfer while BO is still started and
  the user did not explicitly disconnect, cleanup is deferred and rechecked for
  up to 24 seconds.
- The wrapper logs `onMeetingEndedReason` and every skipped `joinBO()` attempt,
  including whether BO is disabled, not started, already joined, already
  transferring, or missing the attendee helper.

Verification/build:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift` passed.
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/widgets/zoom_meeting_screen_io.dart packages/flutter_zoom_meeting_wrapper/lib` passed.
- `flutter test packages/flutter_zoom_meeting_wrapper/test` passed: 5 tests.
- `flutter build ios --release --build-name=99.0.0 --build-number=9905` passed
  and produced `build/ios/iphoneos/Runner.app` (384.3 MB).
- Installed and launched build `9905` on paired physical iPhone
  `Hashim's iphone 17 pro max` (`E7C7C7F2-1872-5B15-B919-391158906FAD`).

Live lane cleanup before retest:
- Ended Zoom meeting `83942421689` via Zoom REST using the existing Functions
  Zoom client.
- Restarted `zoom-hub-bot@2` on the VPS.
- Lane 2 rejoined cleanly as host, created/opened 10 breakout rooms, and the
  latest routing snapshot showed only `Alluwal Hub Bot Lane 2`, with
  `breakoutUnassigned: []`.

Still open:
- A fresh native join after the clean lane reset was not captured before this
  handoff. The required next evidence is the iPhone log lines after build `9905`
  plus the lane-2 bot routing snapshot for the new native alias.
- No Firebase Functions, Hostinger web, or VPS bot code deploy was run.

## 19. Native iOS BO transfer app-pop guard — 2026-07-06

After build `9905`, the user confirmed the phone still exited Zoom completely and
returned to the Flutter app during the routing attempt. The wrapper cleanup path
was therefore made stricter around BO transfer states.

Change:
- During an active `JoinBO` transfer, `MobileRTCMeetingState.ended` and `.idle`
  are now treated as provisional for up to 65 seconds, even if MobileRTC
  temporarily reports BO status as invalid.
- If MobileRTC settles back into the main meeting instead of BO, the wrapper
  clears the transfer flag and retries the assigned BO join rather than popping
  the Flutter meeting screen.
- `onBOSwitchRequestReceived` now stores the BO room id/name and immediately
  attempts a join. If `getAssistantHelper()` is available, the wrapper tries
  `joinBO(boId)` before falling back to attendee `joinBO()`.
- The wrapper tracks BO data helper rights and logs the current BO user status
  so the next live run can distinguish unassigned, assigned-not-joined, and
  in-BO states.
- The wrapper tracks the Zoom Leave button separately so intentional user leaves
  still clean up.
- `customerKey` is now passed into `MobileRTCMeetingJoinParam` when Flutter
  provides it.

Verification/build:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift` passed.
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/widgets/zoom_meeting_screen_io.dart packages/flutter_zoom_meeting_wrapper/lib` passed.
- `flutter test packages/flutter_zoom_meeting_wrapper/test` passed: 5 tests
  after one Flutter startup-lock retry.
- First `9906` iOS build failed on Swift import-name differences; fixed
  `onClickedEndButton(_:end:)`, `getBOMeeting(byID:)`, `getUserList()`, and
  `getBOUserStatus(withUserID:)`.
- `flutter build ios --release --build-name=99.0.0 --build-number=9906` passed
  and produced `build/ios/iphoneos/Runner.app` (384.3 MB).
- Installed and launched build `9906` on paired physical iPhone
  `Hashim's iphone 17 pro max` (`E7C7C7F2-1872-5B15-B919-391158906FAD`). The
  first install attempt failed with a transient CoreDevice connection reset; the
  retry succeeded.

Still open:
- A fresh native join on build `9906` has not yet been captured. The required
  evidence is the `Alluwal Zoom:` device logs plus lane-2 bot routing snapshot
  for the new native alias.
- No Firebase Functions, Hostinger web, or VPS bot code deploy was run.

## 20. Native iOS clean display name after customerKey confirmation — 2026-07-06

After `9906`, native iOS routing worked, but Zoom displayed the deterministic
routing suffix in the participant name, e.g. `nene nane #9P49KaDa`.

Live lane-2 bot logs confirmed the native SDK now exposes the hidden
`customerKey` to the web bot:
- visible name: `nene nane #9P49KaDa`
- bot uid/customerKey: `zh_9P49KaDaPyFGnkuUdkNPYcJf`

Change:
- `getZoomJoinInfo` now returns the clean real name for both `displayName` and
  `nativeDisplayName`.
- The unique suffixed `routingDisplayName` is still written into the hub member
  doc and returned in the payload for old-build fallback, but current native
  builds no longer use it as the visible Zoom username.

Verification/deploy:
- `cd functions && npx jest tests/zoom_handler.test.js --runInBand` passed:
  50 tests.
- `cd functions && npm test -- --runInBand tests/zoom_handler.test.js tests/zoom_meeting_html.test.js` passed:
  72 tests.
- Deployed production `getZoomJoinInfo(us-central1)` with
  `env -u DEBUG firebase deploy --only functions:getZoomJoinInfo --project alluwal-academy`.

Still open:
- Retest native iOS on installed build `9906`. Expected: the join still routes
  successfully, but Zoom shows the clean display name without `#<token>`.

## 21. Native iOS direct Leave handling — 2026-07-06

User reported that after successfully entering the classroom, tapping Zoom's
native Leave control sometimes only made the Zoom controls/screen disappear, and
then another tap was needed before the leave button could be clicked reliably.

Change:
- `FlutterZoomMeetingWrapperPlugin.swift` now intercepts
  `onClickedEndButton(_:end:)`, marks an intentional user leave, cancels BO
  auto-join retries, clears BO transfer state, and directly calls
  `MobileRTCMeetingService.leaveMeeting(with: LeaveMeetingCmd(rawValue: 0)!)`.
- The delegate returns `true`, so Zoom does not run its default leave-button UI
  path. That avoids the flaky intermediate state where the native controls hide
  but the meeting has not left yet.
- Added `nativeLeaveInProgress` to ignore duplicate leave taps until the meeting
  finishes leaving.

Verification/build:
- `swiftc -parse packages/flutter_zoom_meeting_wrapper/ios/Classes/FlutterZoomMeetingWrapperPlugin.swift` passed.
- `flutter analyze --no-fatal-warnings --no-fatal-infos lib/core/widgets/zoom_meeting_screen_io.dart packages/flutter_zoom_meeting_wrapper/lib` passed.
- `flutter test packages/flutter_zoom_meeting_wrapper/test` passed after one
  Flutter ephemeral cleanup retry.
- `flutter build ios --release --build-name=99.0.0 --build-number=9907` passed
  and produced `build/ios/iphoneos/Runner.app` (384.3 MB).
- Installed and launched build `9907` on paired physical iPhone
  `Hashim's iphone 17 pro max` (`E7C7C7F2-1872-5B15-B919-391158906FAD`).

Still open:
- Retest native iOS on installed build `9907`. Expected: one tap on the native
  Zoom Leave button leaves the meeting and returns to the app without the
  controls disappearing/reappearing first.

## 22. Android native screen-share parity prep — 2026-07-06

Goal: give Android the same native Zoom path expected on iOS while avoiding
changes to the working web/iOS paths.

Change:
- Android native joins now pass Flutter's `customerKey` into
  `JoinMeetingOptions.customer_key` and keep the visible Zoom display name clean.
- Android Gradle now uses Zoom's official Maven Central SDK artifact
  `us.zoom.meetingsdk:zoomsdk:6.4.10`, avoiding the missing local `mobilertc.aar`
  requirement on this disk-constrained machine. `6.6.9` and `7.0.5` were tried
  first but require Android minSdk 28; the app currently stays at minSdk 26.
- Android join options explicitly keep sharing enabled (`no_share = false`) and
  the wrapper calls `setHideShareButtonInMeetingToolbar(false)` before joining.
- The app and Android plugin manifests now include Zoom's Android 14 foreground
  service permissions for microphone, media playback, media projection, and
  connected devices, in addition to the existing foreground service permission.
- The Android wrapper registers `MeetingServiceListener` and
  `InMeetingBOControllerListener`. When the SDK reports attendee BO rights or a
  BO switch request, it calls `IBOAttendee.joinBo()` with a bounded retry loop,
  validating the expected room name when Zoom exposes one.

Not verified on device yet:
- Acceptance still needs a real Android phone: hub-routed join, breakout-room
  entry, shared-screen receive, Android screen-share send, clean display name,
  and safe Leave behavior.

Release build produced:
- `flutter build appbundle --release --build-name=1.1.3 --build-number=11301`
  completed on 2026-07-06.
- Output copied to `releases/android/alluwal-1.1.3-11301.aab`.
- SHA-256:
  `1396c3dc2831b08fc50bf053b8f3f435c12a2d56e230355f883c782e1087020b`.
- `jarsigner` verified the bundle; the upload certificate expires on
  2053-06-19.

## 23. Presenter participant visibility during screen share — 2026-07-06

Problem: presenters need to keep seeing class participants while their own
screen share is active. This change only adjusts meeting-layout/share settings;
it does not change hub routing, bot assignment, class timing, or leave handling.

Change:
- Web SDK init now explicitly keeps picture-in-picture enabled with
  `disablePictureInPicture: false`, alongside the existing
  `showPureSharingContent: false`, draggable video tile, and gallery defaults.
- Android native setup now keeps video tiles on the shared screen
  (`setNoVideoTileOnShareScreenEnabled(false)`), keeps no-video users visible,
  keeps meeting controls visible, and leaves the Share button enabled. Newer
  Zoom SDK methods are invoked only by reflection when present so the current
  `us.zoom.meetingsdk:zoomsdk:6.4.10` release still compiles.
- iOS native setup now enables `thumbnailInShare`, keeps participant/video/share
  controls visible, keeps no-video users visible, and disables hiding self view
  before joining.
- Web HTML tests now assert `showPureSharingContent: false` and
  `disablePictureInPicture: false`.

Verified locally:
- `flutter test packages/flutter_zoom_meeting_wrapper/test` — 5 passed.
- `cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` —
  22 passed.
- `cd android && ./gradlew :flutter_zoom_meeting_wrapper:compileReleaseKotlin --no-daemon --max-workers=1`
  — passed.

Deploy/live status:
- Web was deployed to Hostinger with `./scripts/deploy_hostinger_web.sh` as
  cache-busting version `143`; backup:
  `public_html_before_v143_20260706_160256`.
- Public `zoom_meeting.html?verify=143` contains the presenter visibility
  settings: `screenShare: true`, `sharingMode: 'both'`,
  `showPureSharingContent: false`, and `disablePictureInPicture: false`.
- Native iOS/Android still need new app builds before the native settings reach
  users.
- Needs live presenter checks on web desktop, iOS native, and Android native.

Follow-up after web `v143`:
- User reported the web presenter behavior was still unchanged after deploy.
- `web/zoom_meeting.html` now wraps `navigator.mediaDevices.getDisplayMedia`
  and uses `CaptureController.setFocusBehavior('no-focus-change')` where
  supported so Chrome/Edge keep the classroom tab focused after the
  screen-share picker.
- Local Jest and Playwright harness checks passed.
- Deployed to Hostinger with `./scripts/deploy_hostinger_web.sh` as
  cache-busting version `144`; backup:
  `public_html_before_v144_20260706_161756`.
- Public `zoom_meeting.html?verify=144` contains
  `installScreenShareFocusGuard`,
  `setFocusBehavior('no-focus-change')`,
  `__alluwalFocusGuardInstalled`, `showPureSharingContent: false`, and
  `disablePictureInPicture: false`.

Follow-up after web `v144`:
- User reported Chrome PiP appears briefly after switching away during web screen
  share, then disappears. The deployed `v144` fallback was still refocusing the
  Zoom tab after screen-share capture, which can close automatic PiP.
- Local source now removes the `window.focus()` fallback, keeps the
  `CaptureController.setFocusBehavior('no-focus-change')` path, keeps Zoom video
  elements PiP-eligible, and registers the browser automatic PiP media-session
  handler.
- Local Jest and Playwright harness checks passed.
- Deployed to Hostinger with `./scripts/deploy_hostinger_web.sh` as
  cache-busting version `145`; backup:
  `public_html_before_v145_20260706_163047`.
- Public `zoom_meeting.html?verify=145` contains
  `installAutomaticPictureInPicture`,
  `__alluwalAutomaticPictureInPictureInstalled`,
  `setFocusBehavior('no-focus-change')`,
  `navigator.mediaSession.setActionHandler('enterpictureinpicture', ...)`,
  `requestPictureInPicture`, and `disablePictureInPicture: false`.

Follow-up after web presenter test:
- User showed the floating/selected surface was the shared Chrome tab/screen,
  not the participant camera tile.
- `web/zoom_meeting.html` now rejects the active screen-share stream by track id,
  penalizes large/shared-content canvases during sharing, and prefers
  participant-sized video/canvas elements whose DOM context looks like
  participant/gallery/video/camera/thumbnail.
- The `getDisplayMedia` wrapper now also attempts the owned PiP request
  immediately after Zoom starts the share flow, before Chrome moves focus to the
  shared tab.
- `cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` passed
  with 24 tests.
- Local Playwright harness verified a full-size shared-content canvas loses to a
  smaller participant canvas, and `bestZoomCanvasStream()` captures the
  participant canvas.
- Deployed to Hostinger with `./scripts/deploy_hostinger_web.sh` as
  cache-busting version `149`; backup:
  `public_html_before_v149_20260706_171714`.
  Public `zoom_meeting.html?verify=149` contains the v149 participant selector
  markers and the live page has no forced `window.focus()` fallback.

Follow-up after "participant video not ready yet":
- User reported the `Keep participants visible` button said the participant
  video was not ready. The issue was that v149 only fed the owned PiP element
  after sharing was already active; Zoom could already have hidden or rebuilt
  the participant media node by then.
- `web/zoom_meeting.html` now keeps a page-owned hidden `#alluwalPipCanvas`,
  captures it with `pipCanvas.captureStream(15)`, continuously draws the best
  participant drawable into it before and during sharing, and uses that owned
  canvas stream as `#alluwalPipVideo.srcObject`.
- The `getDisplayMedia` wrapper now calls `feedPipVideo()` before Zoom opens the
  share picker, then attempts PiP after the share flow starts.
- Local Playwright harness verified `feedPipVideo()` returns true, the owned PiP
  video has a stream, and the participant canvas wins over the shared-screen
  canvas.
- `cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` passed
  with 24 tests.
- Deployed to Hostinger with `./scripts/deploy_hostinger_web.sh` as
  cache-busting version `150`; backup:
  `public_html_before_v150_20260706_172753`.
  Public `zoom_meeting.html?verify=150` contains `alluwalPipCanvas`,
  `pipCanvas.captureStream(15)`, `drawPipCanvasFrame`,
  `bestZoomDrawableElement`, the pre-share `feedPipVideo()` call, and no forced
  `window.focus()` fallback.

Follow-up after dark/name tile in floating view:
- User showed the visible camera tile was smaller than a large dark participant
  name tile. The selector was still too size-biased and could choose the dark
  avatar/name canvas.
- `web/zoom_meeting.html` now samples each candidate video/canvas on a 32x18
  hidden canvas via `mediaFrameQuality()`. Real camera-like frames get a positive
  `cameraLikeScore`; mostly dark avatar/name tiles get a large
  `blankAvatarLike` penalty.
- Local Playwright harness simulated the screenshot layout and verified the
  camera tile wins over the larger dark/name tile and the shared-screen tile.
- `cd functions && npx jest tests/zoom_meeting_html.test.js --runInBand` passed
  with 24 tests.
- Deployed to Hostinger with `./scripts/deploy_hostinger_web.sh` as
  cache-busting version `151`; backup:
  `public_html_before_v151_20260706_191728`.
  Public `zoom_meeting.html?verify=151` contains `mediaFrameQuality`,
  `frameSampleCanvas`, `blankAvatarLike`, `cameraLikeScore`, and no forced
  `window.focus()` fallback.
