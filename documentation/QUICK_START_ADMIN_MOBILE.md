# Quick Start Guide - Admin Mobile Features

## What's New for Admins on Mobile? 🚀

Your admin app now has **5 tabs** instead of 3:
1. **Home** - Dashboard (same as before)
2. **Notify** 🆕 - Send instant notifications
3. **Users** 🆕 - Manage all users
4. **Chat** - Messaging (same as before)
5. **Tasks** - Task management (same as before)

---

## 1. Send Instant Notifications 📢

### Quick Steps:
1. Open app → Tap **"Notify"** tab (notification icon)
2. Choose recipient:
   - **Everyone** → All active users instantly
   - **By Role** → All teachers/students/parents/admins
   - **Individual** → Select specific person
3. Enter title and message
4. Tap **"Send Notification"**
5. See results (success/failure count)

### Examples:
- **Emergency alert**: Select "Everyone", type message, send
- **Teacher announcement**: Select "By Role" → Teachers
- **Parent reminder**: Select "By Role" → Parents
- **Individual message**: Select "Individual", search name, send

---

## 2. Manage Users 👥

### Quick Steps:
1. Open app → Tap **"Users"** tab (people icon)
2. Search or filter users
3. Tap any user to see options:
   - **Activate/Deactivate** - Enable or disable account
   - **Promote to Admin** - Give admin access
   - **Edit User** - Change name, phone, role
   - **Delete User** - Permanently remove (careful!)

### Common Tasks:

**Deactivate a user**:
- Tap user → "Deactivate User" → Confirm

**Make someone an admin**:
- Tap user → "Promote to Admin" → Confirm

**Edit user info**:
- Tap user → "Edit User" → Change fields → Save

**Find users**:
- Use search bar at top
- Or tap filter icon → Select role/status

---

## 3. Fix iOS Notifications (If Not Working) 🍎

### Symptoms:
- Android receives notifications ✓
- iOS doesn't receive notifications ✗

### Quick Fix:
1. **Upload APNs key to Firebase**:
   - Go to https://console.firebase.google.com
   - Project Settings → Cloud Messaging
   - Upload your `.p8` file from Apple Developer

2. **Enable in Xcode**:
   ```bash
   open ios/Runner.xcworkspace
   ```
   - Runner → Signing & Capabilities
   - Add "Push Notifications"

3. **Test on real iPhone/iPad** (not simulator!)

📖 **Full Guide**: See `IOS_NOTIFICATION_FIX_GUIDE.md`

---

## 4. Fix Shift Reminders (If Not Working) ⏰

### Symptoms:
- Teachers not getting reminders before shifts

### Quick Fix:
1. **Deploy Cloud Functions**:
   ```bash
   firebase deploy --only functions:sendScheduledShiftReminders
   ```

2. **Check Firebase Console**:
   - Go to Functions section
   - Verify "sendScheduledShiftReminders" is running
   - Check logs for errors

3. **Set teacher preferences**:
   - Firestore → users → (teacher) → Add field:
     ```
     notificationPreferences: {
       shiftEnabled: true,
       shiftMinutes: 15
     }
     ```

📖 **Full Guide**: See `IOS_NOTIFICATION_FIX_GUIDE.md` Section 2

---

## Testing Checklist ✓

### Before Releasing:

**Android**:
- [ ] Build and install on Android phone
- [ ] Send notification to yourself
- [ ] Edit a user
- [ ] Check notification appears

**iOS**:
- [ ] Upload APNs key to Firebase
- [ ] Build and install on iPhone
- [ ] Send notification to yourself
- [ ] Check notification appears

**Cloud Functions**:
- [ ] Deploy all functions: `firebase deploy --only functions`
- [ ] Create test shift in 20 minutes
- [ ] Wait for reminder notification
- [ ] Check Firebase logs

---

## Troubleshooting 🔧

### "Notifications not received"
- ✓ Check internet connection
- ✓ Verify FCM token in Firestore
- ✓ For iOS: Follow iOS fix above
- ✓ Check Firebase Console for errors

### "User actions fail"
- ✓ Check admin role in Firestore
- ✓ Verify internet connection
- ✓ Check Firestore security rules

### "Shift reminders not working"
- ✓ Deploy Cloud Functions
- ✓ Check function logs
- ✓ Verify shift status is "scheduled"
- ✓ Check teacher has FCM token

---

## Build Commands 🛠️

### Android Release:
```bash
flutter clean
flutter pub get
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS Release:
```bash
flutter clean
flutter pub get
flutter build ios --release
```
Then open Xcode and archive.

### Deploy Cloud Functions:
```bash
firebase deploy --only functions
```

---

## Important Files 📁

- **Mobile Notification Screen**: `lib/features/notifications/screens/mobile_notification_screen.dart`
- **Mobile User Management**: `lib/features/user_management/screens/mobile_user_management_screen.dart`
- **Mobile Dashboard**: `lib/features/dashboard/screens/mobile_dashboard_screen.dart`
- **Cloud Functions**: `functions/index.js`

---

## Support Documentation 📖

1. **IOS_NOTIFICATION_FIX_GUIDE.md** - Complete iOS and shift notification setup
2. **ADMIN_MOBILE_FEATURES_SUMMARY.md** - Full technical documentation
3. **QUICK_START_ADMIN_MOBILE.md** - This file (quick reference)

---

## Summary 🎉

**Admin mobile app now has**:
- ✅ Instant notification sending (Everyone/Role/Individual)
- ✅ Full user management (View/Edit/Delete/Promote)
- ✅ Mobile-optimized UI with native patterns
- ✅ Works on Android and iOS
- ✅ Same powerful features as web, optimized for mobile

**Next Steps**:
1. Deploy Cloud Functions if needed
2. Fix iOS notifications if applicable
3. Test on devices
4. Train admins on new features

---

## Quick Reference Commands

```bash
# Run in development
flutter run -d chrome

# Build Android
./build_release.sh

# Deploy functions
firebase deploy --only functions

# Check function logs
firebase functions:log

# Analyze code
flutter analyze
```

---

**Questions?** Check the full documentation in `ADMIN_MOBILE_FEATURES_SUMMARY.md` or `IOS_NOTIFICATION_FIX_GUIDE.md`