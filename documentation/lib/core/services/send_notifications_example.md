# Sending Notifications to Users on Multiple Devices

## Overview
The FCM token system now automatically tracks which devices (Android/iOS) each user is logged into. This allows you to send notifications to all their devices or specific platforms.

## Firestore Data Structure

Each user document now has an `fcmTokens` array that looks like this:

```json
{
  "users": {
    "userId123": {
      "email": "teacher@example.com",
      "name": "John Doe",
      "fcmTokens": [
        {
          "token": "dXcF1R...(long token string)",
          "platform": "android",
          "lastUpdated": "2025-10-02T10:30:00Z"
        },
        {
          "token": "eYdG2S...(another token string)",
          "platform": "ios",
          "lastUpdated": "2025-10-01T15:20:00Z"
        }
      ],
      "lastTokenUpdate": "2025-10-02T10:30:00Z"
    }
  }
}
```

## How It Works

### 1. **On Login** (Automatic)
- When a user logs in, their FCM token is automatically saved
- Platform is detected (android/ios)
- If the token already exists, only the timestamp is updated
- If it's a new device, the token is added to the array

### 2. **On Logout** (Automatic)
- When a user logs out, their token is removed from the array
- This prevents sending notifications to devices they're no longer using

### 3. **Token Refresh** (Automatic)
- FCM tokens can change periodically
- When a token refreshes, it's automatically updated in Firestore

## Sending Notifications

### Option 1: Send to All User's Devices (Recommended)

```javascript
// Cloud Function example
const admin = require('firebase-admin');

async function sendNotificationToUser(userId, title, body, data = {}) {
  try {
    // Get user's document
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (!userDoc.exists) {
      console.log('User not found');
      return;
    }
    
    const fcmTokens = userDoc.data().fcmTokens || [];
    
    if (fcmTokens.length === 0) {
      console.log('No FCM tokens found for user');
      return;
    }
    
    // Extract just the token strings
    const tokens = fcmTokens.map(t => t.token);
    
    // Create message
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data,
      tokens: tokens, // Send to all devices
    };
    
    // Send to multiple devices at once
    const response = await admin.messaging().sendEachForMulticast(message);
    
    console.log(`Successfully sent to ${response.successCount} devices`);
    console.log(`Failed to send to ${response.failureCount} devices`);
    
    // Clean up invalid tokens
    if (response.failureCount > 0) {
      await cleanupInvalidTokens(userId, response, fcmTokens);
    }
    
    return response;
  } catch (error) {
    console.error('Error sending notification:', error);
    throw error;
  }
}

// Clean up invalid/expired tokens
async function cleanupInvalidTokens(userId, response, fcmTokens) {
  const failedTokens = [];
  
  response.responses.forEach((resp, idx) => {
    if (!resp.success) {
      // Check if error is due to invalid token
      if (resp.error?.code === 'messaging/invalid-registration-token' ||
          resp.error?.code === 'messaging/registration-token-not-registered') {
        failedTokens.push(fcmTokens[idx].token);
      }
    }
  });
  
  if (failedTokens.length > 0) {
    // Remove invalid tokens from Firestore
    const validTokens = fcmTokens.filter(t => !failedTokens.includes(t.token));
    
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        fcmTokens: validTokens,
        lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    console.log(`Cleaned up ${failedTokens.length} invalid tokens`);
  }
}

// Usage example:
await sendNotificationToUser(
  'userId123',
  'New Shift Assigned',
  'You have a shift tomorrow at 9:00 AM',
  {
    type: 'shift',
    shiftId: 'shift789',
    action: 'view_shift'
  }
);
```

### Option 2: Send to Specific Platform Only

```javascript
async function sendNotificationToPlatform(userId, platform, title, body, data = {}) {
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(userId)
    .get();
  
  if (!userDoc.exists) return;
  
  const fcmTokens = userDoc.data().fcmTokens || [];
  
  // Filter tokens by platform
  const platformTokens = fcmTokens
    .filter(t => t.platform === platform)
    .map(t => t.token);
  
  if (platformTokens.length === 0) {
    console.log(`No ${platform} tokens found for user`);
    return;
  }
  
  const message = {
    notification: { title, body },
    data: data,
    tokens: platformTokens,
  };
  
  const response = await admin.messaging().sendEachForMulticast(message);
  console.log(`Sent to ${platform}: ${response.successCount} successful`);
  
  return response;
}

// Usage: Send only to iOS devices
await sendNotificationToPlatform(
  'userId123',
  'ios',
  'iOS Only Notification',
  'This only goes to your iPhone/iPad'
);

// Usage: Send only to Android devices
await sendNotificationToPlatform(
  'userId123',
  'android',
  'Android Only Notification',
  'This only goes to your Android phone'
);
```

### Option 3: Send to Multiple Users at Once

```javascript
async function sendNotificationToMultipleUsers(userIds, title, body, data = {}) {
  const allTokens = [];
  
  // Collect tokens from all users
  for (const userId of userIds) {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (userDoc.exists) {
      const fcmTokens = userDoc.data().fcmTokens || [];
      fcmTokens.forEach(t => allTokens.push(t.token));
    }
  }
  
  if (allTokens.length === 0) {
    console.log('No tokens found for any users');
    return;
  }
  
  // FCM has a limit of 500 tokens per request, so batch if needed
  const batchSize = 500;
  const batches = [];
  
  for (let i = 0; i < allTokens.length; i += batchSize) {
    batches.push(allTokens.slice(i, i + batchSize));
  }
  
  const message = {
    notification: { title, body },
    data: data,
  };
  
  let totalSuccess = 0;
  let totalFailure = 0;
  
  for (const batch of batches) {
    const response = await admin.messaging().sendEachForMulticast({
      ...message,
      tokens: batch,
    });
    
    totalSuccess += response.successCount;
    totalFailure += response.failureCount;
  }
  
  console.log(`Total sent: ${totalSuccess} successful, ${totalFailure} failed`);
  
  return { successCount: totalSuccess, failureCount: totalFailure };
}

// Usage: Send to all teachers
const teacherIds = ['teacher1', 'teacher2', 'teacher3'];
await sendNotificationToMultipleUsers(
  teacherIds,
  'Staff Meeting Tomorrow',
  'Don\'t forget about the 10 AM meeting'
);
```

## Common Use Cases

### 1. New Shift Assignment
```javascript
// When a shift is assigned to a teacher
await sendNotificationToUser(
  teacherId,
  'New Shift Assigned',
  `You have been assigned to ${shiftDate} at ${shiftTime}`,
  {
    type: 'shift',
    shiftId: shiftId,
    action: 'view_shift'
  }
);
```

### 2. Timesheet Reminder
```javascript
// Daily reminder to teachers who haven't clocked in
await sendNotificationToUser(
  teacherId,
  'Clock-In Reminder',
  'Don\'t forget to clock in for your shift!',
  {
    type: 'timesheet',
    action: 'clock_in'
  }
);
```

### 3. Chat Message
```javascript
// When someone sends a chat message
await sendNotificationToUser(
  recipientId,
  `New message from ${senderName}`,
  messagePreview,
  {
    type: 'chat',
    chatId: chatId,
    senderId: senderId,
    action: 'open_chat'
  }
);
```

### 4. Broadcast to Role
```javascript
// Send to all users with a specific role
async function sendToRole(role, title, body, data = {}) {
  const usersSnapshot = await admin.firestore()
    .collection('users')
    .where('role', '==', role)
    .get();
  
  const userIds = usersSnapshot.docs.map(doc => doc.id);
  
  return await sendNotificationToMultipleUsers(userIds, title, body, data);
}

// Usage:
await sendToRole(
  'teacher',
  'School Closure',
  'School will be closed tomorrow due to weather',
  { type: 'announcement' }
);
```

## Testing

### Test with Firebase Console
1. Go to Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Get a user's token from Firestore
4. Paste the token and send

### Test with Postman/curl
```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "registration_ids": ["token1", "token2"],
    "notification": {
      "title": "Test Notification",
      "body": "This is a test"
    },
    "data": {
      "type": "test",
      "action": "none"
    }
  }'
```

## Monitoring Token Health

Create a Cloud Function to periodically check token health:

```javascript
// Run daily to check for old/inactive tokens
exports.cleanupOldTokens = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
    );
    
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('lastTokenUpdate', '<', thirtyDaysAgo)
      .get();
    
    for (const userDoc of usersSnapshot.docs) {
      const tokens = userDoc.data().fcmTokens || [];
      
      // Test each token
      const validTokens = [];
      
      for (const tokenData of tokens) {
        try {
          // Try sending a data-only message (no notification)
          await admin.messaging().send({
            token: tokenData.token,
            data: { test: 'ping' },
          });
          
          validTokens.push(tokenData);
        } catch (error) {
          console.log(`Invalid token for user ${userDoc.id}: ${error.code}`);
        }
      }
      
      // Update user with only valid tokens
      if (validTokens.length !== tokens.length) {
        await userDoc.ref.update({
          fcmTokens: validTokens,
          lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        console.log(`Cleaned up ${tokens.length - validTokens.length} tokens for user ${userDoc.id}`);
      }
    }
    
    return null;
  });
```

## Platform-Specific Customization

You can customize notifications per platform:

```javascript
const message = {
  notification: {
    title: 'New Message',
    body: 'You have a new message',
  },
  android: {
    priority: 'high',
    notification: {
      icon: 'notification_icon',
      color: '#4CAF50',
      sound: 'default',
      channelId: 'high_importance_channel',
    },
  },
  apns: {
    payload: {
      aps: {
        badge: 1,
        sound: 'default',
        category: 'MESSAGE_CATEGORY',
      },
    },
  },
  data: {
    type: 'chat',
    chatId: 'chat123',
  },
  tokens: tokens,
};
```

## Best Practices

1. **Always clean up invalid tokens** - Remove tokens that fail to send
2. **Use data payloads** - Include navigation data so the app knows where to go
3. **Batch operations** - Send to multiple devices in one API call when possible
4. **Monitor delivery** - Check success/failure counts
5. **Rate limiting** - Don't spam users with too many notifications
6. **Time zones** - Consider user time zones before sending notifications
7. **Platform differences** - iOS and Android handle notifications differently
8. **Testing** - Always test on both platforms before production

## Troubleshooting

### Notification not received on iOS
- Check APNs certificate in Firebase Console
- Verify Push Notifications capability in Xcode
- Test on physical device (not simulator)

### Notification not received on Android
- Verify google-services.json is present
- Check notification permissions are granted
- Test on physical device for best results

### Token not saving
- Check user is logged in when token is generated
- Verify Firestore security rules allow token writes
- Check console logs for errors

