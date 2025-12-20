# Cloud Functions Architecture

This directory contains the Firebase Cloud Functions for Alluvial Academy, now modularized for better maintainability.

## Structure

```
functions/
├── index.js                    # Main entry point - exports all Cloud Functions
├── handlers/                   # Feature-specific Cloud Function handlers
│   ├── users.js               # User management (create, delete, batch operations)
│   ├── students.js            # Student account creation with guardian notifications
│   ├── tasks.js               # Task assignment, status updates, and comment notifications
│   ├── shifts.js              # Shift lifecycle automation and notifications
│   ├── emails.js              # Email-related callable functions (password reset, test emails)
│   └── notifications.js       # Admin notification sender
├── services/                  # Reusable service modules
│   ├── email/
│   │   ├── transporter.js    # Nodemailer SMTP configuration
│   │   └── senders.js        # Email sending functions (welcome, password reset, etc.)
│   ├── notifications/
│   │   └── fcm.js            # Firebase Cloud Messaging (push notifications)
│   └── tasks/
│       └── config.js         # Google Cloud Tasks configuration and utilities
└── utils/
    └── password.js           # Password generation utilities
```

## Deployed Cloud Functions

### User Management
- `createUserWithEmail` - Create staff/teacher accounts with auto-generated passwords
- `createMultipleUsers` - Batch user creation
- `createUser` - Legacy user creation (kept for backward compatibility)
- `deleteUserAccount` - Safely delete inactive user accounts

### Student Management
- `createStudentAccount` - Create student accounts with guardian notifications

### Task Management
- `sendTaskAssignmentNotification` - Notify users when assigned to tasks
- `sendTaskStatusUpdateNotification` - Notify task creators of status changes
- `sendTaskCommentNotification` - Notify relevant users of task comments
- `processTaskCommentEmail` - Firestore trigger for task comment email processing

### Shift Management
- `scheduleShiftLifecycle` - Schedule Cloud Tasks for shift start/end automation
- `handleShiftStartTask` - HTTP endpoint called by Cloud Tasks at shift start
- `handleShiftEndTask` - HTTP endpoint called by Cloud Tasks at shift end
- `onShiftCreated` - Firestore trigger when new shift is created
- `onShiftUpdated` - Firestore trigger when shift is modified
- `onShiftCancelled` - Firestore trigger when shift is cancelled
- `onShiftDeleted` - Firestore trigger when shift is deleted
- `sendScheduledShiftReminders` - Scheduled function (every 5 minutes) for shift reminders

### Email Functions
- `sendWelcomeEmail` - Send welcome email to new users
- `sendCustomPasswordResetEmail` - Send branded password reset emails
- `sendTestEmail` - Debug email testing

### Notifications
- `sendAdminNotification` - Send custom push/email notifications to users

### Public APIs
- `getLandingPageContent` - HTTP endpoint for landing page content (CORS enabled)

## Development

### Local Testing
```bash
cd functions
npm install
firebase emulators:start --only functions
```

### Deploy Functions
```bash
firebase deploy --only functions
```

### Deploy Specific Function
```bash
firebase deploy --only functions:scheduleShiftLifecycle
```

## Key Dependencies

- `firebase-admin` - Firebase Admin SDK for Firestore, Auth, Messaging
- `firebase-functions` - Cloud Functions SDK (v1 and v2 APIs)
- `nodemailer` - Email sending via Hostinger SMTP
- `@google-cloud/tasks` - Cloud Tasks scheduling for shift lifecycle automation

## Architecture Notes

### Why Modularize?

The original `index.js` was **3,300+ lines** mixing SMTP setup, email templates, user CRUD, task notifications, and shift scheduling. This refactor:

1. **Improves readability** - Each module has a single responsibility
2. **Eases maintenance** - Changes to email logic don't require scanning shift code
3. **Enables testing** - Service modules can be unit tested independently
4. **Reduces merge conflicts** - Team members can work on different handlers simultaneously
5. **Keeps deployment simple** - All exports still live in `index.js` as Firebase expects

### Export Pattern

- **Handlers** (`handlers/*.js`) export async functions that contain business logic
- **Services** (`services/*/*.js`) export helper functions and configurations
- **index.js** imports handlers and wraps them with appropriate Firebase function constructors:
  - v1 functions: `functions.https.onCall(handler)`
  - v2 functions: handlers already wrapped with `onCall`, `onRequest`, `onSchedule`, or Firestore triggers
  
This keeps all Cloud Functions discoverable in one place while keeping implementation details isolated.

## Email Configuration

Emails are sent via **Hostinger SMTP**:
- Host: `smtp.hostinger.com`
- Port: `465` (SSL)
- From: `support@alluwaleducationhub.org`

Email templates are defined in `services/email/senders.js`.

## Zoom Integration (Shift Meetings)

When `scheduleShiftLifecycle` runs for a newly-created teaching shift, Cloud Functions will:
- Create a Zoom meeting for the shift (server-to-server OAuth).
- Store `zoom_meeting_id` and an **encrypted** `zoom_encrypted_join_url` on the `teaching_shifts/{shiftId}` document.
- Email the teacher a **time-gated** join link that only redirects to Zoom from **10 minutes before** shift start until **10 minutes after** shift end.

### Required configuration

Set the following as **environment variables** (preferred) or as **Firebase functions config** (`functions.config().zoom.*`):
- `ZOOM_ACCOUNT_ID` (or `zoom.account_id`)
- `ZOOM_CLIENT_ID` (or `zoom.client_id`)
- `ZOOM_CLIENT_SECRET` (or `zoom.client_secret`)
- `ZOOM_HOST_USER` (or `zoom.host_user`) — the Zoom user/email to create meetings under
- `ZOOM_JOIN_TOKEN_SECRET` (or `zoom.join_token_secret`) — used to sign the emailed join link
- `ZOOM_ENCRYPTION_KEY_B64` (or `zoom.encryption_key_b64`) — base64 for 32 bytes (AES-256-GCM) used to encrypt the stored Zoom join URL

Generate an encryption key:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
```

### Deployed functions

- `joinZoomMeeting` (HTTP): validates the signed token and time window, then redirects to Zoom.

## Cloud Tasks Configuration

Shift lifecycle automation uses Google Cloud Tasks:
- Queue: `shift-lifecycle-queue` (in `northamerica-northeast1`)
- Service Account: Hardcoded for reliability
- Tasks schedule HTTP calls to `handleShiftStartTask` and `handleShiftEndTask`

Configuration is in `services/tasks/config.js`.

## Common Issues

### "Function not found" error
Ensure the function is exported in both the handler module AND `index.js`.

### Cloud Tasks permission errors
The service account `554077757249-compute@developer.gserviceaccount.com` needs:
- `Cloud Tasks Enqueuer` role
- Permission to invoke `handleShiftStartTask` and `handleShiftEndTask`

### Email not sending
Check:
1. Hostinger SMTP credentials in `services/email/transporter.js`
2. Recipient email exists in Firestore `users` collection with `e-mail` field
3. Firebase Functions logs for SMTP errors

### Shift creation fails
Common causes:
1. Cloud Tasks queue doesn't exist or has wrong permissions
2. `scheduleShiftLifecycle` callable returns error (check logs)
3. Shift overlaps with existing shift (conflict detection)

## Performance Considerations

- Email sending is synchronous within Cloud Functions - large batch operations may timeout
- Shift reminders run every 5 minutes and query Firestore - consider rate limiting for large teacher counts
- Task comment notifications query multiple Firestore documents - optimize with batch reads when possible

## Security

- All callable functions verify authentication via `context.auth` or `request.auth`
- Admin-only operations check `user_type === 'admin'` or `is_admin_teacher === true`
- User deletion requires the user to be archived (`is_active: false`) first
- Password reset links expire after 1 hour (Firebase default)

---

**Last Updated:** 2025-01-11  
**Refactored From:** Single `index.js` (3,372 lines) → Modular structure (11 files, ~300 lines each)
