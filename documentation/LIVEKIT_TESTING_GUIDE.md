# LiveKit Testing Guide

This guide covers everything you need to set up and test the LiveKit video integration.

## Prerequisites

### 1. LiveKit Cloud Account

You need a LiveKit Cloud account to get credentials:

1. Sign up at https://cloud.livekit.io (or use an existing account)
2. Create a new project (or use existing)
3. Get your credentials from the dashboard:
   - **URL**: WebSocket URL (e.g., `wss://your-project.livekit.cloud`)
   - **API Key**: Found in Project Settings → API Keys
   - **API Secret**: Found in Project Settings → API Keys (shown once when created)

**Note:** For testing, the free tier works, but if you need more concurrent connections, consider the "Ship" plan ($50/mo).

### 2. Firebase Functions Environment Variables

Set up the LiveKit credentials in Firebase Functions:

```bash
cd functions

# Set each secret (Firebase will prompt for the value)
firebase functions:secrets:set LIVEKIT_URL
# When prompted, paste: wss://your-project.livekit.cloud

firebase functions:secrets:set LIVEKIT_API_KEY
# When prompted, paste your API key

firebase functions:secrets:set LIVEKIT_API_SECRET
# When prompted, paste your API secret
```

**Alternative (for local testing):**

If you want to test locally with the emulator, create a `.env` file in the `functions/` directory:

```bash
cd functions
cat > .env << EOF
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your-api-key-here
LIVEKIT_API_SECRET=your-api-secret-here
EOF
```

Make sure `.env` is in `.gitignore` (it should be already).

### 3. Install Flutter Dependencies

```bash
# From project root
flutter pub get
```

This installs `livekit_client: ^2.3.6` and any other new dependencies.

### 4. Deploy Cloud Functions

```bash
# From project root
cd functions
firebase deploy --only functions:getLiveKitJoinToken,functions:checkLiveKitAvailability
```

Or deploy all functions:

```bash
firebase deploy --only functions
```

### 5. Build Flutter App

```bash
# From project root

# For web
./increment_version.sh && flutter build web --release --pwa-strategy=none

# For iOS
flutter build ios

# For Android
flutter build apk --release
```

## Testing Checklist

### Step 1: Create a Test Shift with LiveKit

1. **Log in as admin** to your Flutter app
2. **Create a new shift** (or edit an existing one)
3. In the shift creation/edit dialog:
   - Scroll to "Video Provider" section
   - Select **"LiveKit (Beta)"** (you'll see a purple BETA badge)
   - Notice the warning: "LiveKit is in beta testing. Only use for test classes."
4. **Fill in other required fields** (teacher, students, time, etc.)
5. **Save the shift**

### Step 2: Verify Shift Configuration

Check that the shift document in Firestore has:

```javascript
{
  video_provider: "livekit",
  livekit_room_name: "shift_<shiftId>",  // Auto-generated
  // ... other shift fields
}
```

### Step 3: Test Teacher Joining

1. **Log in as the teacher** assigned to the shift
2. Navigate to **Zoom Meetings** screen (or wherever shifts are listed)
3. Find your test shift (it should show a "Beta" badge)
4. **Click "Join"** button (active 10 minutes before shift start)
5. **Expected behavior:**
   - Loading dialog: "Connecting to class..."
   - Permission request (first time): Camera and microphone
   - LiveKit call screen opens with:
     - Your video preview
     - Controls: Mute, Camera, Share Screen, Leave
     - Status indicator showing "Live"

### Step 4: Test Student Joining

1. **Log in as a student** enrolled in the shift (or use a different device/browser)
2. Navigate to the shift/meeting
3. **Click "Join"** button
4. **Expected behavior:**
   - Same as teacher, but **no "Share Screen" button** (students can't share)
   - Both participants should see and hear each other

### Step 5: Test Screen Sharing (Teacher Only)

1. **As the teacher**, in the LiveKit call screen
2. **Click "Share Screen"** button
3. **Expected behavior:**
   - System screen share permission dialog (first time)
   - Screen share starts
   - Student sees the shared screen
   - "Stop Share" button appears
4. **Click "Stop Share"** to stop

### Step 6: Test Leaving

1. **Click "Leave"** button (red button in controls)
2. **Expected behavior:**
   - Confirmation dialog: "Leave Class? Are you sure you want to leave this class?"
   - On confirm: Returns to previous screen
   - Connection closes cleanly

### Step 7: Regression Test - Zoom Still Works

1. **Create a new shift** with **"Zoom (default)"** as video provider
2. **Join the shift** (as teacher or student)
3. **Expected behavior:**
   - Should join via Zoom (existing behavior)
   - No changes to Zoom functionality

## Troubleshooting

### "LiveKit video is not configured"

**Cause:** Environment variables not set or functions not deployed.

**Fix:**
```bash
# Check if secrets are set
cd functions
firebase functions:secrets:access LIVEKIT_URL

# Redeploy functions
firebase deploy --only functions:getLiveKitJoinToken
```

### "This shift does not use LiveKit video"

**Cause:** Shift's `video_provider` is set to `"zoom"`.

**Fix:** Edit the shift and select "LiveKit (Beta)" as video provider.

### No video/black screen

**Possible causes:**
1. Camera permission denied → Check device settings
2. Camera already in use by another app → Close other apps
3. iOS Simulator doesn't support camera → Use real device
4. Browser blocked camera → Check browser permissions

### No audio

**Possible causes:**
1. Microphone permission denied → Check device settings
2. Device muted → Check device volume
3. Browser blocked microphone → Check browser permissions

### "Failed to connect to class"

**Check:**
1. Is LiveKit Cloud project active?
2. Are API credentials correct?
3. Is the shift time window valid? (10 min before to 10 min after)
4. Check Firebase Functions logs:
   ```bash
   firebase functions:log --only getLiveKitJoinToken
   ```

### Screen share not working (Android)

**Check:** Is the foreground service configured?

The `IsolateHolderService` should be in `AndroidManifest.xml`. If you removed it, add it back:

```xml
<service
    android:name="de.julianassmann.flutter_background.IsolateHolderService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="mediaProjection" />
```

### Permission errors on Android

The app needs to request Bluetooth permissions for headset support. This is handled automatically, but if issues occur:

```bash
# Check if permission_handler is in pubspec.yaml (it should be)
# If not, add it:
# permission_handler: ^12.0.1

flutter pub get
```

## Testing on Different Platforms

### Web

1. Build: `./increment_version.sh && flutter build web --release --pwa-strategy=none`
2. Serve locally: `cd build/web && python3 -m http.server 8080`
3. Open: `http://localhost:8080`
4. Browser permissions: Chrome/Firefox will prompt for camera/mic

### iOS

1. Build: `flutter build ios`
2. Open in Xcode: `open ios/Runner.xcworkspace`
3. Run on device (simulator doesn't support camera)
4. First launch: iOS will prompt for camera/mic permissions

### Android

1. Build: `flutter build apk --release`
2. Install: `adb install build/app/outputs/flutter-apk/app-release.apk`
3. First launch: Android will prompt for camera/mic/Bluetooth permissions

## Quick Test Script

For rapid iteration, you can test the backend function directly:

```bash
# Using Firebase CLI (requires authentication)
firebase functions:shell

# Then in the shell:
getLiveKitJoinToken({shiftId: 'your-test-shift-id'})
```

Or test via HTTP (if you enable HTTP triggers):

```bash
curl -X POST \
  https://us-central1-your-project.cloudfunctions.net/getLiveKitJoinToken \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_ID_TOKEN' \
  -d '{"data":{"shiftId":"your-test-shift-id"}}'
```

## Next Steps After Testing

If tests pass:

1. ✅ **Document any issues** found during testing
2. ✅ **Update documentation** with any platform-specific notes
3. ✅ **Consider enabling for more shifts** (still in beta)
4. ✅ **Monitor LiveKit Cloud dashboard** for usage/metrics
5. ✅ **Gather feedback** from teachers and students

If tests fail:

1. ✅ **Check logs** (Firebase Functions logs, Flutter console)
2. ✅ **Verify configuration** (credentials, permissions)
3. ✅ **Test on different platforms** (web, iOS, Android)
4. ✅ **Compare with Zoom flow** (to isolate issues)
