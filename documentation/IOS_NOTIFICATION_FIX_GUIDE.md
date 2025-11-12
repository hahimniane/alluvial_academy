# iOS Notification & Shift Reminder Fix Guide

## 1. iOS Push Notification Setup

### Step 1: Configure Apple Push Notification Service (APNs)

1. **Go to Apple Developer Console**
   - Visit https://developer.apple.com
   - Sign in with your Apple Developer account

2. **Create APNs Authentication Key**
   - Navigate to Certificates, Identifiers & Profiles → Keys
   - Click "+" to create a new key
   - Check "Apple Push Notifications service (APNs)"
   - Name your key (e.g., "Alluvial Academy Push Key")
   - Download the `.p8` file and save it securely
   - Note the Key ID (shown on the page)

3. **Configure Firebase with APNs Key**
   - Go to Firebase Console: https://console.firebase.google.com
   - Select your project
   - Go to Project Settings → Cloud Messaging
   - Under "Apple app configuration", find your iOS app
   - Click "Upload" under "APNs Authentication Key"
   - Upload your `.p8` file
   - Enter your Key ID
   - Enter your Team ID (found in Apple Developer account)
   - Click "Upload"

### Step 2: Verify Xcode Configuration

1. **Open Xcode**
   ```bash
   cd "/Users/hashimniane/Project Dev/alluvial_academy"
   open ios/Runner.xcworkspace
   ```

2. **Enable Push Notifications Capability**
   - Select "Runner" project in navigator
   - Select "Runner" target
   - Go to "Signing & Capabilities" tab
   - Click "+ Capability"
   - Add "Push Notifications"
   - Ensure "Background Modes" is enabled with:
     - ✓ Remote notifications
     - ✓ Background fetch

3. **Verify Bundle Identifier**
   - Should match: `org.alluvaleducationhub.academy`
   - Must match the one in Firebase project settings

### Step 3: Update Info.plist for Production

**IMPORTANT**: Before App Store submission, change APNs environment:

Edit `/ios/Runner/Runner.entitlements`:
```xml
<key>aps-environment</key>
<string>production</string>  <!-- Change from 'development' -->
```

### Step 4: Test iOS Notifications

1. **Physical Device Required** (Simulator doesn't support push notifications)

2. **Build and Run on Device**
   ```bash
   flutter clean
   flutter pub get
   flutter build ios --release
   ```

3. **Install on Device via Xcode**
   - Connect iPhone to Mac
   - In Xcode, select your device
   - Click Run button

4. **Verify FCM Token Registration**
   - Check console logs for:
     ```
     ✅ iOS: Notification permission granted
     ✅ iOS: APNs token registered successfully
     FCM Token: [token string]
     ✅ FCM Token saved successfully to Firestore
     ```

5. **Check Firestore**
   - Firebase Console → Firestore
   - Navigate to `users/{userId}`
   - Verify `fcmTokens` array contains:
     ```json
     {
       "token": "...",
       "platform": "ios",
       "lastUpdated": "..."
     }
     ```

## 2. Shift Notification Timing Fix

### Issue: Pre-shift Reminders Not Being Sent

The Cloud Function `sendScheduledShiftReminders` needs to be deployed and properly configured.

### Step 1: Deploy Cloud Functions

```bash
cd "/Users/hashimniane/Project Dev/alluvial_academy"
firebase deploy --only functions:sendScheduledShiftReminders,functions:sendAdminNotification
```

### Step 2: Verify Function Deployment

1. **Check Firebase Console**
   - Go to Functions section
   - Verify `sendScheduledShiftReminders` is listed
   - Should show "Scheduled (every 5 minutes)"

2. **Monitor Function Logs**
   - Click on the function name
   - Go to "Logs" tab
   - Look for:
     ```
     🔔 Running scheduled shift reminders check...
     Found X upcoming shifts in next hour
     ✅ Reminder sent for shift [shiftId]
     ```

### Step 3: Fix Notification Preferences

Ensure teachers have notification preferences set in Firestore:

```javascript
// Firestore structure for each teacher
users/{teacherId}/
  notificationPreferences: {
    shiftEnabled: true,        // Must be true
    shiftMinutes: 15           // Minutes before shift (default: 15)
  }
```

To manually set preferences via Firebase Console:
1. Go to Firestore
2. Find teacher's document in `users` collection
3. Add/Edit `notificationPreferences` field with above structure

### Step 4: Test Shift Notifications

1. **Create Test Shift**
   - As admin, create a shift starting in 20 minutes
   - Assign to a teacher with FCM token

2. **Wait for Notification**
   - Should receive notification ~15 minutes before shift
   - Check function logs for execution

3. **Debug if Not Working**
   ```bash
   # Check function logs
   firebase functions:log --only sendScheduledShiftReminders

   # Test function locally
   firebase functions:shell
   > sendScheduledShiftReminders()
   ```

## 3. Testing Manual Notifications (Admin Feature)

### Mobile App Testing

1. **Login as Admin on Mobile**
2. **Navigate to Notify Tab** (second tab in bottom navigation)
3. **Test Different Recipients:**
   - **Everyone**: Sends to all active users
   - **By Role**: Select teachers/students/parents/admins
   - **Individual**: Select specific user

4. **Verify Delivery**
   - Check recipient devices
   - Monitor Firebase Console → Cloud Messaging
   - Check function logs for `sendAdminNotification`

### Troubleshooting

#### Issue: iOS Not Receiving Notifications

**Check:**
1. ✓ APNs key uploaded to Firebase
2. ✓ Push Notifications capability in Xcode
3. ✓ Physical device (not simulator)
4. ✓ Notification permissions granted on device
5. ✓ FCM token in Firestore with platform: "ios"
6. ✓ No VPN blocking APNs connections

**Debug Steps:**
```bash
# Check device logs
flutter run --verbose

# Look for:
# - APNs registration errors
# - FCM token generation failures
# - Permission issues
```

#### Issue: Shift Reminders Not Sending

**Check:**
1. ✓ Function deployed successfully
2. ✓ Function running every 5 minutes
3. ✓ Teacher has `shiftEnabled: true` in preferences
4. ✓ Shift status is "scheduled" (not "completed")
5. ✓ Shift start time within 1 hour window
6. ✓ Teacher has valid FCM tokens

**Debug Query in Firestore:**
```javascript
// Shifts that should trigger notifications
teaching_shifts
  .where('shift_start', '>', now)
  .where('shift_start', '<=', oneHourFromNow)
  .where('status', '==', 'scheduled')
```

## 4. Production Checklist

Before releasing to App Store/Google Play:

### iOS
- [ ] Change `aps-environment` to "production" in Runner.entitlements
- [ ] Upload production APNs certificate/key to Firebase
- [ ] Test with TestFlight build
- [ ] Verify notifications work in production environment

### Android
- [ ] Ensure google-services.json is up to date
- [ ] Test on multiple Android versions (especially Android 13+)
- [ ] Verify notification channels configured

### Cloud Functions
- [ ] Deploy all functions to production
- [ ] Set appropriate function memory/timeout limits
- [ ] Enable function monitoring alerts
- [ ] Test function error handling

### General
- [ ] Test notification delivery across time zones
- [ ] Verify shift reminders with different preferences (5, 10, 15, 30 min)
- [ ] Test admin notifications to large user groups
- [ ] Monitor FCM quotas and limits

## 5. Monitoring & Maintenance

### Daily Checks
- Function execution logs
- FCM delivery statistics
- User complaints about missing notifications

### Weekly Checks
- Review function error rates
- Check for stale FCM tokens
- Verify shift reminder accuracy

### Monthly Maintenance
- Clean up old/invalid FCM tokens
- Review notification delivery rates
- Update APNs certificates if needed (yearly renewal)

## Support Resources

- **Firebase Cloud Messaging Docs**: https://firebase.google.com/docs/cloud-messaging
- **APNs Documentation**: https://developer.apple.com/documentation/usernotifications
- **Flutter FCM Plugin**: https://pub.dev/packages/firebase_messaging
- **Cloud Functions**: https://firebase.google.com/docs/functions

## Contact for Issues

If notifications still don't work after following this guide:
1. Check Firebase Console for quota limits
2. Review function logs for specific errors
3. Test with Firebase Console's test message feature
4. Contact Firebase Support with error logs