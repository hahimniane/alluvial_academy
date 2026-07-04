# Zoom Classroom Pilot Setup

This pilot routes selected teachers from RealtimeKit to the Zoom Meeting SDK
without changing the default provider for other teachers.

## Zoom account prerequisites

1. Keep at least two licensed Zoom users available for pilot hosts.
2. Create a Zoom Meeting SDK app and copy its SDK key and secret.
3. Create a Server-to-Server OAuth app with:
   - `meeting:write:admin`
   - `meeting:read:admin`
   - `user:read:admin`
   - the Zoom user token/ZAK scope required by the account
4. Enable event subscriptions on the Server-to-Server app for:
   - `meeting.participant_joined`
   - `meeting.participant_left`
   - `meeting.ended`
5. Set the webhook endpoint to:
   - dev: `https://us-central1-alluwal-dev.cloudfunctions.net/zoomWebhook`
   - prod: `https://us-central1-alluwal-academy.cloudfunctions.net/zoomWebhook`

## Firebase secrets

Set these before deploying the functions:

```bash
firebase functions:secrets:set ZOOM_SDK_KEY --project alluwal-dev
firebase functions:secrets:set ZOOM_SDK_SECRET --project alluwal-dev
firebase functions:secrets:set ZOOM_S2S_ACCOUNT_ID --project alluwal-dev
firebase functions:secrets:set ZOOM_S2S_CLIENT_ID --project alluwal-dev
firebase functions:secrets:set ZOOM_S2S_CLIENT_SECRET --project alluwal-dev
firebase functions:secrets:set ZOOM_WEBHOOK_SECRET_TOKEN --project alluwal-dev
```

Repeat the same commands for `alluwal-academy` before production deployment.

## Teacher host assignment

Before toggling a teacher on in the admin user list, set
`users/{teacherId}.zoom_host_account` to that teacher's licensed Zoom host user
ID or email. The toggle will fail until this field exists.

For the pilot, assign each overlapping Zoom teacher a different licensed host
account, then use the admin Zoom icon to set `use_zoom=true`. The callable will
propagate `video_provider=zoom` to that teacher's upcoming teaching shifts.

## Clients

- **Web** uses `web/zoom_meeting.html` (Zoom Meeting SDK for Web, Client View).
  No extra setup beyond the secrets above.
- **Mobile (Android/iOS)** uses the `flutter_zoom_meeting_wrapper` package.
  The native Zoom Meeting SDK binaries are **not** bundled and must be
  downloaded from the Zoom Marketplace (Meeting SDK app → Download) and placed
  manually. Use the **latest** Meeting SDK version so Zoom's minimum-version
  rule does not block joins.
  - Android: place the SDK `libs/` folder under
    `~/.pub-cache/hosted/pub.dev/flutter_zoom_meeting_wrapper-0.0.2/android/`.
  - iOS: place `MobileRTC.xcframework`, `MobileRTCResources.bundle`,
    `MobileRTCScreenShare.xcframework`, and `zoomcml.xcframework` under
    `ios/Frameworks/`. (Podfile is already `platform :ios, '15.0'`, and the
    camera/microphone/photo `Info.plist` keys already exist.)

  Pilot limitations on mobile: the teacher joins as a participant (the meeting
  runs because `join_before_host` is enabled) rather than as ZAK host, so
  host-only controls are not available yet. Participant identity is best-effort
  (by name), which only affects admin **absence notifications**, not pay —
  timesheets come from clock-in, not class presence.

## Verify after setup (dev)

1. `cd functions && npm run deploy:dev`
2. Assign `zoom_host_account`, toggle a test teacher on, confirm their upcoming
   teaching shifts flip to `video_provider=zoom` and a non-teaching shift stays
   `realtimekit`.
3. Join a Zoom class on web and on a device; leave; confirm a
   `livekit_sessions` doc with `presence_windows` was written and the teacher
   is not flagged absent.
4. Confirm a non-Zoom teacher still opens RealtimeKit.
