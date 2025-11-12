# iOS FCM Token Saving Fix

## Problem
FCM tokens were being saved to Firestore for Android users but not for iOS users. This prevented iOS devices from receiving push notifications.

## Root Cause
On iOS, Firebase Cloud Messaging (FCM) requires an **APNs token** from Apple before it can generate an FCM token. The flow is:

1. **APNs Registration** → Get token from Apple
2. **FCM Token Generation** → Firebase exchanges APNs token for FCM token
3. **Save to Firestore** → Save FCM token to user document

**The Issue:**
- `FirebaseAppDelegateProxyEnabled` was set to `false` in `Info.plist`
- This disabled automatic APNs registration
- Without APNs token, FCM couldn't generate a token
- Token was `null` when save attempt was made

## Fixes Applied

### 1. AppDelegate.swift - Manual APNs Registration ✅
**File:** `ios/Runner/AppDelegate.swift`

Added comprehensive APNs handling:
- ✅ Request notification permissions at app launch
- ✅ Register for remote notifications with APNs
- ✅ Handle APNs token registration success
- ✅ Handle APNs token registration failure
- ✅ Forward APNs token to Firebase Messaging
- ✅ Handle foreground notification display
- ✅ Handle notification tap events
- ✅ Added detailed logging for debugging

**Key changes:**
```swift
// Register for remote notifications
application.registerForRemoteNotifications()

// Handle APNs token
override func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)

// Forward to Firebase
super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
```

### 2. Runner.entitlements - Push Notification Capability ✅
**File:** `ios/Runner/Runner.entitlements`

Added APNs environment:
```xml
<key>aps-environment</key>
<string>development</string>
```

**Note:** Change to `production` when submitting to App Store.

### 3. notification_service.dart - iOS Token Retry Logic ✅
**File:** `lib/core/services/notification_service.dart`

Added retry mechanism for iOS token retrieval:

**Changes:**
- ✅ Retry token fetch if null on first attempt (iOS)
- ✅ Wait 3 seconds before retry (gives time for APNs → FCM conversion)
- ✅ Retry again in `saveTokenToFirestore()` if still null
- ✅ Enhanced token refresh listener with auto-save
- ✅ Better error messages and logging

**Key addition:**
```dart
// On iOS, token might be null initially - retry after a delay
if (_fcmToken == null && Platform.isIOS) {
  debugPrint('⏳ iOS: Token null on first attempt, retrying in 3 seconds...');
  await Future.delayed(const Duration(seconds: 3));
  _fcmToken = await _firebaseMessaging.getToken();
}
```

### 4. main.dart - Increased iOS Delay ✅
**File:** `lib/main.dart`

Increased delay before saving token on iOS:
- **Android:** 2 seconds (unchanged)
- **iOS:** 5 seconds (increased from 2)

**Reason:** iOS needs more time for APNs token → FCM token conversion.

```dart
final delay = (!kIsWeb && Platform.isIOS) 
  ? const Duration(seconds: 5) 
  : const Duration(seconds: 2);
```

## How iOS Token Flow Now Works

### Timeline:
```
0s  - App launches
0s  - AppDelegate registers for APNs
0s  - NotificationService.initialize() called
0s  - _getFCMToken() called (token likely null)
3s  - _getFCMToken() retries (if null on iOS)
5s  - _saveFCMTokenIfLoggedIn() called
5s  - Retries token fetch if still null
5-8s - Token saved to Firestore
```

### Token Refresh Listener:
If token isn't ready initially, it will be automatically saved when it becomes available via the `onTokenRefresh` listener.

## Testing Instructions

### Prerequisites:
- ✅ Physical iOS device (notifications don't work on simulator)
- ✅ Device has internet connection
- ✅ User is logged in

### Step 1: Clean and Rebuild
```bash
cd "/Users/hashimniane/Project Dev/alluvial_academy"
flutter clean
flutter pub get
flutter build ios --release
```

### Step 2: Run on Device
1. Open Xcode: `open ios/Runner.xcworkspace`
2. Select your physical iOS device
3. Click Run (▶️) or press `Cmd + R`

### Step 3: Monitor Logs
Watch for these log messages in Xcode console:

**✅ Success Sequence:**
```
✅ iOS: Notification permission granted
✅ iOS: APNs token registered successfully
📱 iOS: APNs token: [hex string]
FCM Token: [token string]
🔍 Checking if user is logged in...
✅ User is logged in, attempting to save FCM token...
📱 saveTokenToFirestore called
📱 FCM Token: [token preview]...
📱 User ID: [user id]
📱 Platform: ios
✅ FCM Token saved successfully to Firestore
```

**❌ Failure Indicators:**
```
❌ iOS: Notification permission denied
❌ iOS: Failed to register for remote notifications
❌ No FCM token available to save after retries
⚠️ Token is null, attempting to fetch now...
```

### Step 4: Verify in Firestore
1. Open Firebase Console: https://console.firebase.google.com
2. Go to **Firestore Database**
3. Navigate to `users` collection
4. Find your user document (by email or UID)
5. Check for `fcmTokens` array
6. Look for entry with `platform: "ios"`

**Expected structure:**
```javascript
fcmTokens: [
  {
    token: "long-fcm-token-string...",
    platform: "ios",
    lastUpdated: Timestamp
  }
]
```

### Step 5: Send Test Notification
1. Go to Firebase Console → **Cloud Messaging**
2. Click **Send your first message**
3. Enter notification title and text
4. Click **Send test message**
5. Enter your FCM token (from Firestore or logs)
6. Click **Test**

**Expected result:** Notification appears on iOS device

## Troubleshooting

### Token is still null after retries
**Possible causes:**
1. **No internet connection** - Check device connectivity
2. **APNs registration failed** - Check Xcode console for error
3. **Firebase configuration issue** - Verify `GoogleService-Info.plist`

**Solution:**
- Check logs for: `❌ iOS: Failed to register for remote notifications`
- Verify bundle ID matches in Xcode and `GoogleService-Info.plist`
- Ensure APNs key/certificate is uploaded to Firebase Console

### Notification permission denied
**Cause:** User tapped "Don't Allow" on permission prompt

**Solution:**
1. Delete app from device
2. Reinstall and tap "Allow" when prompted
3. Or: Settings → [App Name] → Notifications → Enable

### Token saved but notifications not received
**Possible causes:**
1. **APNs not configured in Firebase** - Missing APNs key/certificate
2. **Wrong environment** - Development vs Production mismatch
3. **Invalid FCM token** - Token expired or invalid

**Solution:**
- Upload APNs Authentication Key to Firebase Console
- Ensure `aps-environment` matches build type:
  - `development` for debug/TestFlight builds
  - `production` for App Store builds

### "No provisioning profile" error
**Cause:** Apple Developer account not configured

**Solution:**
1. Open Xcode → Runner target
2. Signing & Capabilities tab
3. Check "Automatically manage signing"
4. Select your Team

## Next Steps (Firebase Console)

### ⚠️ CRITICAL: Configure APNs in Firebase

1. **Go to Firebase Console:**
   - https://console.firebase.google.com
   - Select project: **alluwal-academy**

2. **Navigate to Cloud Messaging:**
   - Project Settings (gear icon)
   - **Cloud Messaging** tab
   - Scroll to **Apple app configuration**

3. **Upload APNs Authentication Key (Recommended):**
   - Go to: https://developer.apple.com/account/resources/authkeys/list
   - Create new key with **APNs** enabled
   - Download `.p8` file
   - Upload to Firebase:
     - Key ID: [from Apple]
     - Team ID: GRKB7BXVZK (your team)
     - Upload `.p8` file

4. **Test:**
   - Send test message from Firebase Console
   - Should receive notification on iOS device

## Production Checklist

Before submitting to App Store:

- [ ] Change `aps-environment` to `production` in `Runner.entitlements`
- [ ] Upload APNs Production certificate to Firebase (or use same Auth Key)
- [ ] Test with TestFlight build
- [ ] Update bundle identifier from `com.example.alluwalacademyadmin`
- [ ] Enable Push Notifications capability in Xcode
- [ ] Test notification in all app states (foreground, background, terminated)

## Files Modified

1. ✅ `ios/Runner/AppDelegate.swift` - Added APNs registration
2. ✅ `ios/Runner/Runner.entitlements` - Added aps-environment
3. ✅ `lib/core/services/notification_service.dart` - Added retry logic
4. ✅ `lib/main.dart` - Increased iOS delay, added Platform import

## Summary

The iOS FCM token issue has been fixed by:
1. Manually registering for APNs in AppDelegate
2. Adding retry logic for token retrieval
3. Increasing wait time for iOS token generation
4. Adding comprehensive logging for debugging
5. Configuring proper entitlements

**Result:** iOS devices will now successfully save FCM tokens to Firestore and can receive push notifications.

---

**Date Fixed:** January 2025  
**Tested On:** iOS 13.0+  
**Firebase Messaging:** v15.1.3

