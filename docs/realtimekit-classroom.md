# RealtimeKit Classroom Setup

RealtimeKit class joins use Cloudflare's meeting UI so teachers and students
get the provider's built-in controls for audio, video, screen sharing, chat,
plugins, and whiteboard.

- iOS and Android use Cloudflare's official Flutter UI Kit package,
  `realtimekit_ui` (the same native screen serves both via the conditional
  import in `realtimekit_meeting_screen.dart`). The app pins `realtimekit_ui`
  to `0.3.0` for compatibility and overrides `realtimekit_core_ios` to `0.1.5`
  because `0.1.6` points Xcode at an internal Cloudflare GitLab SPM URL that
  this project cannot resolve. Android pulls `realtimekit_core_android`
  transitively and needs `minSdk` 26 (already set).
- Flutter web embeds the Cloudflare Web Components via an `<iframe>` pointed at
  the same-origin page `web/realtimekit_meeting.html` (NOT `srcdoc`). A real
  origin is required: plugins such as the whiteboard resolve their plugin
  iframe URL from `window.location` and will not initialize inside an
  `about:srcdoc` document. The participant auth token is passed in the iframe
  URL hash so it is never sent to a server.
- The setup/preview screen is skipped on every platform (`show-setup-screen`
  off on web, `skipSetupPage: true` on native) so Join drops users straight
  into the room. Devices can still be changed via in-room settings.

## Required Function Secrets

Configure these in Firebase/Cloud Functions before deploying the RealtimeKit
functions:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_REALTIME_API_TOKEN`
- `REALTIMEKIT_APP_ID`

Optional preset overrides. These are preset names, not credentials, so configure
them as normal environment/config values rather than Secret Manager secrets
unless you also bind them intentionally:

- `REALTIMEKIT_TEACHER_PRESET`
- `REALTIMEKIT_ADMIN_PRESET`
- `REALTIMEKIT_STUDENT_PRESET`
- `REALTIMEKIT_PARENT_PRESET`
- `REALTIMEKIT_GUEST_PRESET`

## Presets

In Cloudflare RealtimeKit, the selected presets must allow the classroom tools
we expect:

- Teacher/admin preset: camera, microphone, screen share, chat, polls/plugins,
  whiteboard, document sharing, participant controls, and the host-only ability
  to end the meeting for everyone.
- Student/parent/guest preset: camera, microphone, chat, view screen share,
  view whiteboard, and draw on whiteboard. These presets must not include
  host controls such as ending the meeting for everyone, kicking participants,
  room lock controls, or recording controls.

The Cloud Function config rejects attendee preset names that are identical to
the teacher/admin/recorder preset names, but it cannot inspect the Cloudflare
dashboard permissions inside a preset. If a student sees "end meeting for all",
fix the `REALTIMEKIT_STUDENT_PRESET` preset permissions in Cloudflare first.

If whiteboard or screen share does not appear in class, check the preset first;
the Flutter app intentionally renders the full RealtimeKit UI and does not hide
those controls.

Backend teacher/admin kick calls use Cloudflare's active-session kick endpoint
with the app user ID as `custom_participant_id`, so it disconnects the live
participant rather than only deleting their stored meeting authorization.

## Native SDK

The iOS project already declares camera and microphone permissions. The native
RealtimeKit screen uses Cloudflare's `realtimekit_ui` Flutter package, which
depends on `realtimekit_core` for media/network handling. The package depends
on Riverpod internally; the app still uses Provider for app state management.
During smoke testing, verify that the first iOS join prompts for mic/camera and
that toggling mic/camera inside RealtimeKit works after accepting.

The iOS package uses Swift Package Manager. Native iOS builds need network
access to the SPM dependency used by `realtimekit_core_ios`; if Xcode fails
while resolving packages, verify that the build machine can reach
`https://github.com/dyte-in/mobile-core-bridge-spm.git`.

## Manual Smoke Test

Run this against the dev Firebase project and a dev Cloudflare RealtimeKit app:

1. Join the same active teaching shift as a teacher and student in two browsers.
2. Confirm both users can hear each other continuously for at least 10 minutes.
3. Toggle microphone/camera from both sides.
4. Have the teacher share a screen and confirm the student sees it.
5. Open RealtimeKit whiteboard from the teacher preset and draw.
6. Confirm the student sees the whiteboard and can draw on it.
7. Copy a guest class link, join as guest, and confirm the guest gets the guest
   preset permissions.
8. Confirm students can leave the class but cannot end the meeting for everyone.
9. Lock the room, then confirm student/guest joins are blocked.
10. Leave and rejoin both users to confirm the stored `realtimekit_meeting_id`
    is reused.

## Recordings

RealtimeKit recording is intentionally not enabled in this migration pass.
Existing LiveKit recording code remains in the repository for rollback/history,
but the RealtimeKit classroom join flow does not start or export recordings.
