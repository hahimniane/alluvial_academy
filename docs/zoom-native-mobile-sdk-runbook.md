# Zoom Native Mobile SDK Runbook

Purpose: ship the native Zoom Meeting SDK path for Android and iOS so mobile
users can view and share screens while still being routed by the shared Zoom
hub bot.

## Routing contract

- Web joins keep using `customerKey = zh_<sha256(uid:shiftId)>`.
- Native mobile joins still call `getZoomJoinInfo` with
  `clientPlatform: native_mobile`, but current native builds now pass the hidden
  routing key where the Meeting SDK exposes one:
  - iOS sets `MobileRTCMeetingJoinParam.customerKey`.
  - Android sets `JoinMeetingOptions.customer_key` (Zoom documents a 35-character
    max; current hub keys are `zh_` plus 24 base64url characters).
- For hub-routed native joins, the backend returns clean `displayName` and
  `nativeDisplayName` values. The deterministic `routingDisplayName` like
  `Real Name #abc12345` is still stored on the hub member doc as
  `routingDisplayName` / `displayNameAliases` for old-build fallback.
- The native wrapper joins Zoom with the clean display name and passes
  `customerKey`. The bot routes by `customerKey` first, and only falls back to
  exact display-name alias routing when the visible name maps to one room.
- `realDisplayName` remains clean for presence, roster, and no-show records.

## Required local binaries

Download both native Meeting SDK packages from the Zoom Marketplace. Keep all
Zoom binaries out of git.

Android:

The Android wrapper uses Zoom's official Maven Central artifact
`us.zoom.meetingsdk:zoomsdk:6.4.10` in
`packages/flutter_zoom_meeting_wrapper/android/build.gradle`, so no local AAR is
needed for the normal Play release build.

Version note: `6.4.10` is the current Android build target because Zoom
Meeting SDK `6.6.9` and `7.0.5` require app minSdk 28, while the Alluwal
Android app remains minSdk 26. Raising minSdk is a separate product decision.

Fallback only: if you deliberately revert the Gradle dependency to a local
flatDir AAR, place it here and keep it out of git:

```text
packages/flutter_zoom_meeting_wrapper/android/libs/mobilertc.aar
```

iOS:

```text
packages/flutter_zoom_meeting_wrapper/ios/Frameworks/MobileRTC.xcframework
packages/flutter_zoom_meeting_wrapper/ios/Frameworks/MobileRTCScreenShare.xcframework
packages/flutter_zoom_meeting_wrapper/ios/Frameworks/MobileRTCResources.bundle
packages/flutter_zoom_meeting_wrapper/ios/Frameworks/<all companion frameworks from the same Zoom SDK zip>
```

The iOS companion frameworks must include `zoomcml` because the podspec fails
fast when it is missing. Include `MobileRTCScreenShare.xcframework` for iOS
screen-share sending; if Zoom's current Meeting SDK package also requires a
Broadcast Upload Extension/App Group for full-device sharing, add that native
target before release and record the exact setup here.

Before running Xcode, verify the iOS SDK package is complete:

```bash
test -f packages/flutter_zoom_meeting_wrapper/ios/Frameworks/MobileRTC.xcframework/ios-arm64/MobileRTC.framework/MobileRTC
test -f packages/flutter_zoom_meeting_wrapper/ios/Frameworks/MobileRTCScreenShare.xcframework/ios-arm64/MobileRTCScreenShare.framework/MobileRTCScreenShare
```

If disk space is tight, symlink the downloaded SDK contents into
`packages/flutter_zoom_meeting_wrapper/ios/Frameworks/` instead of copying them.
Do not proceed with an iOS build if `MobileRTC.framework/MobileRTC` is missing;
Xcode will fail at link time with `Framework 'MobileRTC' not found`.

Known-good iOS SDK source used for the first physical-device build:

```text
https://github.com/zoom/meetingsdk-ios/releases/download/v6.6.9/zoom-meeting-sdk-iOS.zip
```

That archive extracts the frameworks at the package root, not under `lib/`.
The verified local extraction path was
`/Users/hashimniane/Downloads/zoom-sdk-ios-6.6.9-github/zoom-meeting-sdk-iOS`.
After symlinking from that folder and rerunning `pod install`,
`flutter run -d 00008150-000242E41191401C --debug --no-resident` built and
launched on the physical iPhone. Wireless debugging stalled on LLDB attach, so
`flutter config --no-enable-lldb-debugging` was used for the launch retry.

## Build path

1. Confirm Android Gradle can resolve `us.zoom.meetingsdk:zoomsdk`; place the
   iOS Zoom SDK binaries in the paths above when building iOS.
2. Run `flutter pub get`.
3. Run `cd ios && pod install && cd ..`.
4. Build Android on a physical device first:
   `flutter build apk --debug` or `flutter run -d <android-device>`.
5. Build iOS from Xcode or with `flutter build ipa` after signing is configured.
6. Do not release until the acceptance gates below pass on real Android and iOS
   devices.

Known Android release build produced on 2026-07-06:

```text
flutter build appbundle --release --build-name=1.1.3 --build-number=11301
releases/android/alluwal-1.1.3-11301.aab
SHA-256: 1396c3dc2831b08fc50bf053b8f3f435c12a2d56e230355f883c782e1087020b
```

The bundle was signed successfully; the upload certificate reported by
`jarsigner` expires on 2053-06-19.

Android implementation notes:

- The Android wrapper keeps Zoom's default meeting UI. Received screen shares
  should render through that UI.
- Outgoing Android screen share uses Zoom's default Share control. The wrapper
  explicitly leaves the share button visible (`no_share = false` and
  `setHideShareButtonInMeetingToolbar(false)`), while the app/plugin manifests
  declare the Android foreground-service permissions Zoom requires for screen
  sharing on Android 14+.
- While sharing/viewing shared content, Android keeps meeting video tiles and
  controls visible where Zoom's default UI supports it:
  `setNoVideoTileOnShareScreenEnabled(false)`,
  `setHideNoVideoUsersEnabled(false)`, and
  `setAlwaysShowMeetingToolbarEnabled(true)`. Newer Zoom Android settings for
  large share video scenes and preserving the presenter's video are called only
  by reflection because the current minSdk-26-safe SDK (`6.4.10`) does not
  expose those methods at compile time.
- The wrapper also registers an `InMeetingBOControllerListener` and calls
  `IBOAttendee.joinBo()` when the SDK reports attendee BO rights or a switch
  request. This mirrors the iOS assigned-but-not-joined fix without replacing
  Zoom's native UI.
- If device testing shows Zoom's default Android Share control does not start
  capture reliably, the next fallback is a custom `MediaProjectionManager`
  request and `InMeetingShareController.startShareScreen(Intent data)`.

## Acceptance gates

- Teacher, student, parent, and admin join a hub-routed class from Android and
  land in the expected breakout room.
- Teacher, student, parent, and admin join a hub-routed class from iOS and land
  in the expected breakout room.
- A mobile user can view another participant's shared screen.
- Android screen share works where the OS grants media projection permission.
- iOS screen share works through the native Meeting SDK broadcast flow.
- The presenter can still see participant video/controls while their screen
  share is active on Android and iOS native builds.
- No mobile participant remains in the hub main session after the bot routes
  them.
- Presence rows use clean names and no-show/live roster behavior still works.
- Red Leave removes only the local participant and does not end the hub.
