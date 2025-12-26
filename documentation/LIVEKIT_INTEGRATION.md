# LiveKit Video Integration

LiveKit is implemented as a **beta** alternative video provider alongside Zoom. It allows testing video calls with a subset of classes before potentially broader rollout.

## Overview

- **Zoom**: Default, unchanged video provider
- **LiveKit**: Beta alternative, opt-in per shift

## Configuration

### Environment Variables (Firebase Functions)

Add these secrets to your Firebase Functions environment:

```bash
# From LiveKit Cloud Dashboard (https://cloud.livekit.io)
firebase functions:secrets:set LIVEKIT_URL
firebase functions:secrets:set LIVEKIT_API_KEY
firebase functions:secrets:set LIVEKIT_API_SECRET
```

Required variables:
- `LIVEKIT_URL`: WebSocket URL (e.g., `wss://your-app.livekit.cloud`)
- `LIVEKIT_API_KEY`: API key from LiveKit Cloud
- `LIVEKIT_API_SECRET`: API secret from LiveKit Cloud

### Flutter Dependencies

LiveKit Flutter SDK is added in `pubspec.yaml`:
```yaml
livekit_client: ^2.3.6
```

Run `flutter pub get` after updating.

## Data Model

### TeachingShift Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `video_provider` | `"zoom"` \| `"livekit"` | `"zoom"` | Which video platform to use |
| `livekit_room_name` | string | `null` | Room name (auto-generated as `shift_<shiftId>`) |
| `livekit_last_token_issued_at` | timestamp | `null` | Tracking last token generation |

## Cloud Functions

### `getLiveKitJoinToken`

Callable function that returns join credentials.

**Input:**
```json
{
  "shiftId": "abc123"
}
```

**Authorization:**
- User must be Firebase authenticated
- User must be: assigned teacher, enrolled student, or admin

**Output:**
```json
{
  "success": true,
  "livekitUrl": "wss://your-app.livekit.cloud",
  "token": "eyJ...",
  "roomName": "shift_abc123",
  "userRole": "teacher",
  "displayName": "John Doe",
  "expiresInSeconds": 600
}
```

### `checkLiveKitAvailability`

Checks if LiveKit is configured and available for a shift.

## Flutter Services

### VideoCallService

Unified entry point for joining video calls:

```dart
// Automatically routes to Zoom or LiveKit based on shift.videoProvider
await VideoCallService.joinClass(context, shift);
```

### LiveKitService

Direct LiveKit operations:

```dart
// Get join token
final result = await LiveKitService.getJoinToken(shiftId);

// Join a class (opens LiveKit call UI)
await LiveKitService.joinClass(context, shift);
```

## User Permissions by Role

| Permission | Teacher | Student | Admin |
|------------|---------|---------|-------|
| Publish Camera | ✅ | ✅ | ✅ |
| Publish Microphone | ✅ | ✅ | ✅ |
| Screen Share | ✅ | ❌ | ✅ |
| Publish Data | ✅ | ✅ | ✅ |
| Subscribe | ✅ | ✅ | ✅ |

## Admin: Creating LiveKit Shifts

1. Open Create/Edit Shift dialog
2. Scroll to "Video Provider" section
3. Select "LiveKit" (shows BETA badge)
4. Save shift

The shift will use LiveKit instead of Zoom.

## UI Features

### Call Screen
- Participant video grid
- Mute/unmute microphone
- Toggle camera on/off
- Screen share (teacher only)
- Leave call button
- Speaking indicators
- Connection status

### Shift Card Badge
LiveKit shifts display a purple "Beta" badge in the meetings list.

## Testing Checklist

1. [ ] Create a shift with `video_provider=livekit`
2. [ ] Teacher joins from Flutter app → sees call UI
3. [ ] Student joins → both see/hear each other
4. [ ] Teacher can screen share → student sees shared screen
5. [ ] Leaving ends connection cleanly
6. [ ] A Zoom shift still joins exactly like before (no regression)

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         Flutter App                          │
├──────────────────────────────────────────────────────────────┤
│  VideoCallService  ──────────┬───────────────────────────────│
│       │                      │                               │
│  ┌────▼────┐            ┌────▼────┐                         │
│  │ZoomService│           │LiveKitService│                    │
│  └────┬────┘            └────┬────┘                         │
│       │                      │                               │
│       │                 ┌────▼─────────────┐                │
│       │                 │LiveKitCallScreen │                │
│       │                 │(livekit_client)  │                │
└───────┼─────────────────┴──────────────────┴─────────────────┘
        │                      │
        ▼                      ▼
┌───────────────────┐  ┌───────────────────────────────────────┐
│ Firebase Functions │  │ Firebase Functions                    │
├───────────────────┤  ├───────────────────────────────────────┤
│ Zoom API calls     │  │ getLiveKitJoinToken                   │
│ Hub meetings       │  │ ├─ Auth check                         │
│ Breakout rooms     │  │ ├─ Load shift                         │
└───────────────────┘  │ ├─ Check video_provider == "livekit"  │
                       │ ├─ Determine role (teacher/student)   │
                       │ └─ Generate JWT token                 │
                       └───────────────────────────────────────┘
                                      │
                                      ▼
                       ┌───────────────────────────────────────┐
                       │          LiveKit Cloud                 │
                       │  ├─ WebSocket connection              │
                       │  ├─ Media routing                     │
                       │  └─ SFU (Selective Forwarding Unit)   │
                       └───────────────────────────────────────┘
```

## Troubleshooting

### "LiveKit video is not configured"
→ Set the `LIVEKIT_*` environment variables in Firebase Functions

### "This shift does not use LiveKit video"
→ The shift's `video_provider` is set to `"zoom"`, not `"livekit"`

### Teacher can't share screen
→ Screen share is restricted to teachers and admins only

### Black video/no audio
→ Check device permissions for camera and microphone

## Platform-Specific Setup

### Android
All required permissions and the foreground service for screen sharing are already configured in `AndroidManifest.xml`:
- Camera, microphone, network permissions
- Bluetooth permissions for headset support
- `IsolateHolderService` for screen sharing (`mediaProjection`)

### iOS
Camera, microphone, and background audio are already configured in `Info.plist`.

**For iOS Screen Sharing (Teacher):**
iOS requires a "Broadcast Extension" to capture screen content from other apps. This is an advanced setup requiring Xcode configuration. See the [LiveKit iOS screen sharing setup guide](https://docs.livekit.io/reference/client-sdk-flutter/) for instructions.

Without the broadcast extension, teachers can only share content within the app (not other apps).

### Web
The web platform works out of the box with standard browser permissions.

## Future Improvements

- [ ] iOS broadcast extension for full screen sharing
- [ ] Webhook integration for attendance tracking
- [ ] Recording support
- [ ] Chat/messaging in calls
- [ ] Participant admin controls (mute all, etc.)
- [ ] Call quality indicators

