# Firebase Cloud Messaging (FCM) - Usage Guide

## Overview
Firebase Cloud Messaging has been configured for both Android and iOS. The `NotificationService` handles all notification-related functionality.

## Features
- ✅ Push notifications (foreground, background, and terminated states)
- ✅ Local notifications
- ✅ Notification permissions handling
- ✅ FCM token management
- ✅ Topic subscriptions
- ✅ Deep linking/navigation from notifications

## How to Use

### 1. Get FCM Token
```dart
import 'package:alluwalacademyadmin/core/services/notification_service.dart';

// Get the current device's FCM token
final token = NotificationService().fcmToken;
print('FCM Token: $token');

// Save this token to Firestore for the logged-in user
// This allows you to send targeted notifications
```

### 2. Subscribe to Topics
```dart
// Subscribe to a role-based topic (e.g., all teachers)
await NotificationService().subscribeToTopic('teachers');

// Subscribe to announcement topics
await NotificationService().subscribeToTopic('announcements');

// Unsubscribe when needed
await NotificationService().unsubscribeFromTopic('teachers');
```

### 3. Show Local Notifications
```dart
// Show a notification manually (useful for reminders, etc.)
await NotificationService().showLocalNotification(
  id: 1,
  title: 'Shift Reminder',
  body: 'Your shift starts in 30 minutes',
  payload: '{"type": "shift", "shiftId": "123"}',
);
```

### 4. Cancel Notifications
```dart
// Cancel a specific notification
await NotificationService().cancelNotification(1);

// Cancel all notifications
await NotificationService().cancelAllNotifications();
```

## Sending Notifications

### Option 1: From Firebase Console
1. Go to Firebase Console → Cloud Messaging
2. Click "Send your first message"
3. Fill in notification details
4. Select target: All users, specific topics, or specific tokens

### Option 2: From Cloud Functions (Server-Side)
```javascript
// Example Cloud Function to send notification
const admin = require('firebase-admin');

async function sendNotificationToUser(userId, title, body, data) {
  // Get user's FCM token from Firestore
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(userId)
    .get();
  
  const fcmTokens = userDoc.data().fcmTokens || [];
  
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: data, // Custom data for navigation
    tokens: fcmTokens,
  };
  
  const response = await admin.messaging().sendMulticast(message);
  console.log('Successfully sent message:', response);
}

// Send to a topic
async function sendNotificationToTopic(topic, title, body, data) {
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: data,
    topic: topic,
  };
  
  const response = await admin.messaging().send(message);
  console.log('Successfully sent message:', response);
}
```

### Option 3: Using HTTP API
```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "USER_FCM_TOKEN",
    "notification": {
      "title": "Hello!",
      "body": "This is a test notification"
    },
    "data": {
      "type": "test",
      "action": "open_chat"
    }
  }'
```

## Notification Data Structure

When sending notifications with custom data for navigation:

```json
{
  "notification": {
    "title": "New Message",
    "body": "You have a new message from John"
  },
  "data": {
    "type": "chat",
    "chatId": "abc123",
    "senderId": "user456"
  }
}
```

The `type` field in `data` determines navigation behavior. Update `_navigateBasedOnMessage()` in `notification_service.dart` to handle your app's navigation logic.

## Saving FCM Tokens to Firestore

To send targeted notifications, save the FCM token when a user logs in:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alluwalacademyadmin/core/services/notification_service.dart';

Future<void> saveFCMToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  final token = NotificationService().fcmToken;
  if (token == null) return;
  
  await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    });
}
```

## Testing Notifications

### Test on Physical Device
1. Run the app on a physical device (notifications don't work on simulators)
2. Check the logs for the FCM token: `FCM Token: xxxxxx`
3. Copy the token
4. Go to Firebase Console → Cloud Messaging
5. Click "Send test message"
6. Paste the token and send

### Test Different States
- **Foreground**: App is open and active
- **Background**: App is minimized but still running
- **Terminated**: App is completely closed

## Common Use Cases

### 1. New Shift Assignment
```dart
// When assigning a shift to a teacher
await sendNotification(
  teacherId,
  'New Shift Assigned',
  'You have been assigned to Monday 9:00 AM',
  {'type': 'shift', 'shiftId': shiftId},
);
```

### 2. Chat Message
```dart
// When a new chat message arrives
await sendNotification(
  recipientId,
  'New Message from ${senderName}',
  message,
  {'type': 'chat', 'chatId': chatId, 'senderId': senderId},
);
```

### 3. Timesheet Approval
```dart
// When timesheet is approved
await sendNotification(
  employeeId,
  'Timesheet Approved',
  'Your timesheet for this week has been approved',
  {'type': 'timesheet', 'timesheetId': timesheetId},
);
```

### 4. Broadcast to All Teachers
```dart
// Send to topic
await admin.messaging().send({
  notification: {
    title: 'School Closure',
    body: 'School will be closed tomorrow due to weather',
  },
  topic: 'teachers',
});
```

## iOS Specific Setup

For iOS, you need to:
1. Enable Push Notifications capability in Xcode
2. Upload APNs authentication key to Firebase Console
3. Test on a physical iOS device (not simulator)

### Enable Push Notifications in Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" and check "Remote notifications"

## Troubleshooting

### Notifications Not Received
1. Check if FCM token is generated (check logs)
2. Verify device has internet connection
3. Ensure notification permissions are granted
4. For iOS: Check APNs certificate in Firebase Console
5. For Android: Check google-services.json is present

### Token Not Generated
1. Ensure Firebase is initialized before NotificationService
2. Check internet connection
3. Verify google-services.json (Android) or GoogleService-Info.plist (iOS) is correctly placed

### Navigation Not Working
1. Implement navigation logic in `_navigateBasedOnMessage()` in `notification_service.dart`
2. Ensure you're using a global navigator key or proper navigation context

## Next Steps

1. Uncomment and implement `_saveTokenToFirestore()` in `notification_service.dart`
2. Set up Cloud Functions to send notifications based on events
3. Implement navigation logic in `_navigateBasedOnMessage()`
4. Subscribe users to appropriate topics based on their roles
5. Test thoroughly on both Android and iOS devices

