# Complete Zoom Meeting System Breakdown

## Overview

This document provides a comprehensive breakdown of how the Zoom meeting system works in the Alluvial Academy application, from meeting creation through user joining. The system supports two meeting architectures: **standalone meetings** (one meeting per shift with breakout rooms) and **hub meetings** (multiple shifts share one meeting in 2-hour time blocks).

---

## Table of Contents

1. [Core Architecture](#core-architecture)
2. [Phase 1: Meeting Creation Flow](#phase-1-meeting-creation-flow)
3. [Phase 2: Hub Meetings](#phase-2-hub-meetings)
4. [Phase 3: Joining Meetings](#phase-3-joining-meetings)
5. [Phase 4: Active Meeting Conflict Resolution](#phase-4-active-meeting-conflict-resolution)
6. [Configuration Requirements](#configuration-requirements)
7. [Current State & Potential Issues](#current-state--potential-issues)
8. [Key Files Reference](#key-files-reference)

---

## Core Architecture

### Meeting Types

1. **Standalone Meetings (Legacy System)**
   - One Zoom meeting per shift
   - Uses breakout rooms to handle overlapping shifts
   - Created via `ensureZoomMeetingAndEmailTeacher()`

2. **Hub Meetings (Newer System)**
   - Multiple shifts share one meeting in 2-hour time blocks
   - Each shift gets its own breakout room
   - Scheduled via `scheduleHubMeetings()`
   - Capacity limit: 100 participants per hub

### Core Principle

**The system assumes Zoom host accounts can only host ONE meeting at a time.** When shifts overlap in time, they must ALL be in the SAME Zoom meeting as breakout rooms.

```
Flow:
1. Admin creates Shift A at 10:00 AM → Create new Zoom meeting with breakout room "Shift A"
2. Admin creates Shift B at 10:00 AM (overlaps) → Add breakout room "Shift B" to existing meeting
3. Teacher A clicks "Start Class" → Joins meeting → Auto-routed to their breakout room
4. Teacher B clicks "Start Class" → Joins SAME meeting → Auto-routed to their breakout room
```

---

## Phase 1: Meeting Creation Flow

### 1.1 Shift Creation Trigger

When an admin creates or updates a teaching shift:

**File:** `lib/core/services/shift_service.dart`

1. Flutter app calls `scheduleShiftLifecycle` Cloud Function
2. Cloud Function schedules start/end tasks via Cloud Tasks
3. **Non-blocking**: Calls `ensureZoomMeetingAndEmailTeacher()` function

**File:** `functions/handlers/shifts.js` (line ~183)

```javascript
try {
  await ensureZoomMeetingAndEmailTeacher({shiftId, shiftData});
} catch (zoomError) {
  // Logs error but doesn't fail shift creation
  await shiftRef.update({ zoom_error: String(zoomError.message) });
}
```

### 1.2 Zoom Meeting Creation Logic

**File:** `functions/services/zoom/shift_zoom.js`

**Function:** `ensureZoomMeetingAndEmailTeacher({ shiftId, shiftData, selectedHost })`

#### Pre-conditions for Zoom Meeting Creation

- Shift category must be `'teaching'` (not leadership)
- Shift must not be cancelled
- Shift must have a `teacher_id`
- Teacher must have an email address
- Zoom must be configured (environment variables)
- Shift doesn't already have a meeting AND invites sent

#### Decision Logic: Overlap Detection

The system checks for overlapping shifts:

**File:** `functions/services/zoom/shift_zoom.js` (line ~88)

```javascript
const findOverlappingShift = async (shiftStart, shiftEnd, excludeShiftId) => {
  // Query shifts that could potentially overlap
  // Two shifts overlap if: shiftA.start < shiftB.end AND shiftA.end > shiftB.start
  const snapshot = await db.collection('teaching_shifts')
    .where('status', 'in', ['scheduled', 'active'])
    .where('shift_start', '<', admin.firestore.Timestamp.fromDate(shiftEnd))
    .get();
  
  // Check actual overlap and return if found
}
```

#### Path A: No Overlap Detected → Create New Standalone Meeting

**Process:**

1. **Find Available Host**
   - Calls `findAvailableHost()` to check host capacity
   - Uses "fill-first" strategy (exhaust Host 1 before using Host 2)
   - Falls back to `ZOOM_HOST_USER` env var if no hosts configured

2. **Build Breakout Room Configuration**
   ```javascript
   const breakoutRoom = await buildBreakoutRoom({ id: shiftId, ...shiftData });
   // Format: "Teacher Name | Student1, Student2 | 10:00 AM"
   // Pre-assigns teacher and student emails to the breakout room
   ```

3. **Create Zoom Meeting via API**
   ```javascript
   const meeting = await createMeeting({
     topic: `Alwal Academy Classes - ${DateTime.fromJSDate(shiftStart).toFormat('MMM d, h:mm a')}`,
     startTimeIso: shiftStart.toISOString(),
     durationMinutes: Math.max(durationMinutes, 120), // At least 2 hours
     timezone: 'UTC',
     hostUser: hostUser,
     breakoutRooms: [breakoutRoom],
     alternativeHosts: alternativeHostEmails
   });
   ```

4. **Encrypt and Store Data**
   ```javascript
   const updateData = {
     zoom_meeting_id: meeting.id,
     zoom_encrypted_join_url: encryptString(joinUrl, zoomConfig.encryptionKeyB64),
     zoom_meeting_created_at: admin.firestore.FieldValue.serverTimestamp(),
     zoom_host_email: meetingHostEmail,
     breakoutRoomName: breakoutRoomName,
   };
   if (passcode) {
     updateData.zoom_encrypted_meeting_passcode = encryptString(passcode, zoomConfig.encryptionKeyB64);
   }
   await shiftRef.update(updateData);
   ```

5. **Schedule Breakout Room Auto-Opener**
   - Scheduled task to open breakout rooms 3 minutes after shift start
   - Backup mechanism if teacher doesn't manually open rooms

#### Path B: Overlap Detected → Update Existing Meeting

**Process:**

1. **Find Overlapping Shift**
   - Queries for shifts with overlapping time ranges that already have Zoom meetings

2. **Collect All Shifts in Meeting**
   ```javascript
   const existingMeetingId = overlappingShift.zoom_meeting_id;
   const allShiftsInMeeting = await getShiftsWithSameMeeting(existingMeetingId);
   const allShifts = [...allShiftsInMeeting, currentShiftForBreakout];
   ```

3. **Build Breakout Rooms for ALL Shifts**
   ```javascript
   const breakoutRooms = await Promise.all(
     allShifts.map(async (s) => await buildBreakoutRoom(s))
   );
   ```

4. **Update Existing Zoom Meeting**
   ```javascript
   await updateMeeting(existingMeetingId, {
     topic: `Alwal Academy Classes - ${DateTime.fromJSDate(shiftStart).toFormat('MMM d, h:mm a')}`,
     breakoutRooms: breakoutRooms,
     alternativeHosts: alternativeHostEmails
   });
   ```

5. **Update ALL Affected Shifts**
   - Batch update all shifts to use the same `zoom_meeting_id`
   - Store encrypted join URL on each shift document

### 1.3 Host Allocation System

**File:** `functions/services/zoom/hosts.js`

The system supports multiple Zoom host accounts with intelligent allocation:

**Function:** `findAvailableHost(requestedStart, requestedEnd, excludeShiftId)`

**Strategy: Fill-First**
- Checks hosts in priority order (lowest priority number first)
- Counts overlapping meetings for each host
- Returns first host with available capacity
- Falls back to `ZOOM_HOST_USER` env var if no hosts configured in Firestore

**Host Configuration (Firestore Collection: `zoom_hosts`)**
```javascript
{
  email: string,                    // Zoom host email/user ID
  is_active: boolean,               // Default: true
  max_concurrent_meetings: number,  // Default: 1
  priority: number,                 // Lower = used first
  display_name: string,             // Optional
  notes: string,                    // Optional
}
```

### 1.4 Breakout Room Configuration

**File:** `functions/services/zoom/shift_zoom.js` (line ~135)

**Function:** `buildBreakoutRoom(shift)`

**Breakout Room Name Format:**
```
"Teacher Name | Student1, Student2 | 10:00 AM"
```

**Participant Pre-assignment:**
- Collects teacher email from user document
- Collects all student emails from user documents
- Pre-assigns these emails to the breakout room via Zoom API
- Enables automatic routing when participants join

**Important:** Breakout room routing relies on **email matching**. Participants must join Zoom using the same email address that was pre-assigned, otherwise they won't be auto-routed.

### 1.5 Data Storage

**Firestore Collection:** `teaching_shifts/{shiftId}`

**Fields Stored:**
```javascript
{
  zoom_meeting_id: string,                          // Zoom meeting ID
  zoom_encrypted_join_url: string,                  // AES-encrypted join URL
  zoom_encrypted_meeting_passcode: string,          // AES-encrypted passcode
  zoom_host_email: string,                          // Which host account owns this meeting
  zoom_meeting_created_at: Timestamp,               // When meeting was created
  zoom_invite_sent_at: Timestamp,                   // When teacher invite was sent
  zoom_student_invites_sent_at: Timestamp,          // When student invites were sent
  breakoutRoomName: string,                         // Name of this shift's breakout room
  hubMeetingId: string,                             // Optional: if part of hub meeting
  zoom_error: string,                               // Error message if meeting creation failed
  zoom_error_at: Timestamp                          // When error occurred
}
```

**Security:** Join URLs and passcodes are **never stored in plain text**. They are encrypted using AES encryption with a base64 key stored in environment variables.

### 1.6 Email Notifications

**File:** `functions/services/zoom/shift_zoom.js` (line ~424)

After creating the meeting, the system sends two types of emails:

#### Teacher Email
- **Recipient:** Teacher's email address
- **Content:** 
  - Shift details (subject, time, students)
  - Meeting password (if applicable)
  - **Signed join link** (time-gated, secure token)
  - Instructions for joining via app
- **Security:** Uses signed JWT token that expires 10 minutes after shift ends

#### Student/Guardian Email
- **Recipients:** All students and their guardians
- **Content:**
  - Class details
  - **Direct Zoom URL** (simpler, for non-app users)
  - Meeting password
  - Warning about using registered email for breakout room routing

**Email Service:** Uses Nodemailer (`functions/services/email/transporter.js`)

---

## Phase 2: Hub Meetings (Alternative System)

**File:** `functions/services/shifts/schedule_hubs.js`

### Overview

Hub meetings are an alternative scheduling system that groups multiple shifts into 2-hour time blocks.

### Strategy

1. Find all scheduled shifts in next 7 days needing a hub (`hubMeetingId == null`)
2. Group them by 2-hour overlapping windows (e.g., 8:00-10:00, 10:00-12:00)
3. For each group:
   - Check capacity (split if > 100 participants)
   - Create Zoom Meeting with Breakout Rooms
   - Save Hub Meeting document
   - Update Shifts with hub details

### Hub Meeting Constants

```javascript
const HUB_DURATION_MINUTES = 120;        // 2 hour blocks
const MAX_PARTICIPANTS_PER_HUB = 100;    // Capacity limit
const BUFFER_MINUTES = 15;               // Start meeting 15 mins before first shift
```

### Hub Meeting Document

**Firestore Collection:** `hub_meetings/{hubId}`

```javascript
{
  id: string,
  startTime: Timestamp,
  endTime: Timestamp,
  status: 'scheduled' | 'started' | 'ended',
  hostZoomUserId: string,
  meetingId: string,                     // Zoom meeting ID
  meetingPasscode: string,
  joinUrl: string,
  totalExpectedParticipants: number,
  shifts: [string],                      // Array of shift IDs
  createdAt: Timestamp
}
```

### Shift Updates for Hub Meetings

When a shift is assigned to a hub:

```javascript
{
  hubMeetingId: string,                  // Reference to hub_meetings doc
  breakoutRoomName: string,
  breakoutRoomKey: string,               // Shift ID as stable key
  zoomRoutingMode: 'preassign' | 'hybrid',
  routingRiskParticipants: [string],     // Emails that may not auto-route
  preAssignedParticipants: [string],     // Valid emails for pre-assignment
  hasRoutingRisk: boolean
}
```

### Current State

**Note:** Both systems (standalone and hub) currently exist in parallel. Standalone meetings are created via `ensureZoomMeetingAndEmailTeacher`, while hub meetings are scheduled separately. There may be conflicts if both systems try to create meetings for the same shift.

---

## Phase 3: Joining Meetings

### 3.1 Teacher Clicks "Start Class"

**File:** `lib/core/services/zoom_service.dart`

**Function:** `joinClass(BuildContext context, TeachingShift shift)`

#### Step 1: Validation Checks

1. **Check if shift has Zoom meeting**
   ```dart
   if (!shift.hasZoomMeeting) {
     _showError(context, 'This class does not have a meeting configured yet');
     return;
   }
   ```

2. **Check time window**
   - Allowed: 10 minutes before shift start to 10 minutes after shift end
   - Shows appropriate error if too early or too late

3. **Check for active meetings (NEW FEATURE)**
   - For teachers only
   - Calls `checkActiveMeetings()` Cloud Function
   - If active meetings found, shows dialog to end them
   - User can confirm to end previous meetings before joining

#### Step 2: Get Join Credentials

**Function:** `getZoomMeetingSdkJoinPayload` Cloud Function

**File:** `functions/handlers/zoom.js` (line ~340)

**Process:**

1. **Authentication & Authorization**
   - Requires authenticated user
   - Verifies user is teacher, student, or admin for this shift

2. **Check for Hub Meeting**
   ```javascript
   if (shiftData.hubMeetingId) {
     // Fetch hub meeting details
     const hubDoc = await db.collection('hub_meetings').doc(shiftData.hubMeetingId).get();
     meetingId = hubData.meetingId;
     passcode = hubData.meetingPasscode;
   }
   ```

3. **Decrypt Join Credentials**
   - Decrypts stored `zoom_encrypted_join_url` and `zoom_encrypted_meeting_passcode`
   - If missing, fetches from Zoom API

4. **Generate Meeting SDK JWT**
   ```javascript
   const meetingSdkJwt = generateMeetingSdkJwt(
     meetingSdkConfig.sdkKey,
     meetingSdkConfig.sdkSecret,
     meetingId,
     isAdmin || isTeacher ? 1 : 0,  // Role: 1 = host, 0 = participant
     ttlSeconds
   );
   ```

5. **Return Payload**
   ```javascript
   return {
     success: true,
     shiftId,
     meetingNumber: String(meetingId),
     meetingPasscode: passcode || '',
     meetingSdkJwt,
     sdkKey: meetingSdkConfig.sdkKey,
     displayName,
     userEmail,
     authEmail,
     joinWindow: {
       allowedStartIso: new Date(allowedStartMs).toISOString(),
       allowedEndIso: new Date(allowedEndMs).toISOString(),
     },
   };
   ```

#### Step 3: Platform-Specific Join

**Web Platform:**
- Uses Zoom Web SDK (`web/zoom_integration.js`)
- Initializes SDK, authenticates with JWT, joins meeting

**Mobile Platform:**
- Uses Zoom Meeting SDK (native)
- Initializes SDK, authenticates with JWT, joins meeting
- Shows progress dialog during join process

### 3.2 Breakout Room Auto-Routing

**How It Works:**

1. **Pre-assignment During Meeting Creation**
   - When meeting is created, participant emails are pre-assigned to breakout rooms via Zoom API
   - Teacher email → assigned to their breakout room
   - Student emails → assigned to same breakout room

2. **Email Matching on Join**
   - When participant joins, Zoom checks their email
   - If email matches pre-assigned email, automatically routes to correct breakout room
   - If email doesn't match, participant stays in main meeting room

3. **Manual Room Opening**
   - Teachers need to manually open breakout rooms after joining
   - Backup: Scheduled Cloud Task opens rooms 3 minutes after shift start
   - File: `functions/services/zoom/breakout_scheduler.js`

**Important Notes:**
- Routing depends on email matching - users must join with registered email
- If user's Firebase Auth email differs from profile email, routing may fail
- System shows warning dialog if email mismatch detected (web platform)

### 3.3 Join Methods

#### Method 1: In-App Join (Meeting SDK)

**Platform:** Mobile (iOS/Android) and Web

**Flow:**
1. User clicks "Start Class" in app
2. App calls `getZoomMeetingSdkJoinPayload` Cloud Function
3. Receives JWT token and meeting details
4. Initializes Zoom SDK
5. Authenticates with JWT
6. Joins meeting via SDK

**Files:**
- Mobile: `lib/core/services/zoom_meeting_sdk_join_service.dart`
- Web: `lib/core/services/zoom_web_sdk_service.dart`

#### Method 2: Browser Join (Legacy)

**Platform:** Web only (fallback)

**Flow:**
1. Teacher receives email with signed join link
2. Link contains JWT token: `joinZoomMeeting?token=...`
3. Cloud Function verifies token and redirects to Zoom URL
4. Opens in browser (Zoom web client)

**File:** `functions/handlers/zoom.js` → `joinZoomMeeting` HTTP function

---

## Phase 4: Active Meeting Conflict Resolution

### Problem

Zoom host accounts can only host **one meeting at a time**. If a teacher tries to join their class while another meeting is still active on the same host account, they get an error: "You are hosting another meeting."

### Solution

**New Feature Added:** Automatic detection and ending of conflicting meetings.

### Implementation

#### Backend Functions

**File:** `functions/services/zoom/client.js`

1. **`endMeeting(meetingId)`**
   - Ends a specific active Zoom meeting
   - Uses Zoom API: `PUT /meetings/{meetingId}/status` with `action: 'end'`

2. **`getLiveMeetings(hostUser)`**
   - Gets all currently running/live meetings for a host
   - Uses Zoom API: `GET /users/{userId}/meetings?type=live`

3. **`endAllActiveMeetingsForHost(hostUser)`**
   - Ends all active meetings for a host at once
   - Returns list of ended meetings and any errors

#### Cloud Functions

**File:** `functions/handlers/zoom.js`

1. **`checkActiveZoomMeetings`** (Callable)
   - Checks if there are any active meetings for the host
   - Returns meeting count and details
   - No side effects

2. **`endActiveZoomMeetings`** (Callable)
   - Ends all active meetings for the host
   - Requires authentication and authorization (teacher/admin)
   - Returns success status and list of ended meetings

#### Frontend Integration

**File:** `lib/core/services/zoom_service.dart`

**New Methods:**
- `checkActiveMeetings({shiftId})` - Checks for active meetings
- `endActiveMeetings({shiftId})` - Ends active meetings

**Updated Flow in `joinClass()`:**

```dart
// For teachers: Check for active meetings
if (isTeacherForShift && context.mounted) {
  final activeMeetings = await checkActiveMeetings(shiftId: shift.id);
  
  if (activeMeetings.hasActiveMeetings && context.mounted) {
    // Show dialog asking if they want to end the active meeting
    final shouldEndMeetings = await showDialog<bool>(...);
    
    if (shouldEndMeetings) {
      // End the active meetings
      final endResult = await endActiveMeetings(shiftId: shift.id);
      
      // Brief pause to allow Zoom to release the host
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}
```

### User Experience

1. Teacher clicks "Start Class"
2. System checks for active meetings
3. If found, shows dialog:
   - Title: "Another meeting is active"
   - Lists active meeting(s)
   - Options: "Cancel" or "End & Start My Class"
4. If user confirms:
   - System ends previous meeting(s) via Zoom API
   - Shows "Ending previous meeting..." message
   - Waits 2 seconds for Zoom to release host
   - Proceeds to join new meeting

---

## Configuration Requirements

### Environment Variables

**File:** `functions/.env` or Firebase Functions config

```bash
# Zoom OAuth (Server-to-Server)
ZOOM_ACCOUNT_ID=...
ZOOM_CLIENT_ID=...
ZOOM_CLIENT_SECRET=...

# Zoom Host (fallback if no hosts in Firestore)
ZOOM_HOST_USER=host@example.com

# Security
ZOOM_JOIN_TOKEN_SECRET=...          # Secret for signing join tokens
ZOOM_ENCRYPTION_KEY_B64=...         # Base64 AES key for encrypting URLs/passcodes

# Meeting SDK (optional, for in-app join)
ZOOM_MEETING_SDK_KEY=...
ZOOM_MEETING_SDK_SECRET=...

# Host Keys (for breakout room opening)
ZOOM_HOST_KEYS_JSON={...}           # JSON object mapping hosts to keys
ZOOM_HOST_KEY=...                   # Default host key
```

### Firestore Collections

1. **`zoom_hosts`** - Multi-host configuration
   ```javascript
   {
     email: string,
     is_active: boolean,
     max_concurrent_meetings: number,
     priority: number,
     display_name?: string,
     notes?: string
   }
   ```

2. **`teaching_shifts`** - Shift documents with Zoom meeting data

3. **`hub_meetings`** - Hub meeting documents (if using hub system)

### Zoom API Permissions Required

The Zoom OAuth app needs the following scopes:

- `meeting:write` - Create and update meetings
- `meeting:write:admin` - Administrative meeting operations
- `user:read` - Read user information
- `user:read:admin` - Administrative user operations

---

## Current State & Potential Issues

### Known Issues

1. **Two Parallel Systems**
   - Standalone meetings (via `ensureZoomMeetingAndEmailTeacher`)
   - Hub meetings (via `scheduleHubMeetings`)
   - **Risk:** Both systems may try to create meetings for the same shift, causing conflicts
   - **Recommendation:** Standardize on one system or add coordination logic

2. **Breakout Room Auto-Open Reliability**
   - Teachers must manually open breakout rooms after joining
   - Backup scheduled task may not always work reliably
   - **Impact:** Students may stay in main room if rooms aren't opened

3. **Email-Based Routing Limitations**
   - Breakout room routing depends on exact email matching
   - If Firebase Auth email differs from profile email, routing fails
   - **Impact:** Users may not be auto-routed to correct breakout room

4. **Single Host Constraint**
   - System assumes one host can only run one meeting at a time
   - New feature addresses this but requires user confirmation to end previous meetings
   - **Recommendation:** Consider upgrading to Zoom plan that supports concurrent meetings

5. **Hub Meeting Capacity**
   - Limited to 100 participants per hub
   - May need to split into multiple hubs
   - **Current behavior:** Basic chunking logic, may not be optimal

### Best Practices

1. **Always use registered email** for Zoom account when joining
2. **Manually open breakout rooms** after joining (don't rely on auto-open)
3. **End previous meetings** before starting new ones (if prompted)
4. **Monitor host capacity** - add more hosts if frequently hitting limits
5. **Test email routing** - ensure user emails match between system and Zoom

---

## Key Files Reference

### Backend (Cloud Functions)

- `functions/services/zoom/shift_zoom.js` - Main meeting creation logic
- `functions/services/zoom/client.js` - Zoom API client
- `functions/services/zoom/hosts.js` - Host allocation logic
- `functions/services/zoom/config.js` - Configuration loader
- `functions/services/zoom/crypto.js` - Encryption utilities
- `functions/services/zoom/breakout_scheduler.js` - Breakout room auto-opener
- `functions/services/shifts/schedule_hubs.js` - Hub meeting scheduler
- `functions/handlers/zoom.js` - Join endpoints and active meeting functions
- `functions/handlers/shifts.js` - Shift lifecycle and meeting creation triggers

### Frontend (Flutter)

- `lib/core/services/zoom_service.dart` - Main Zoom service for joining
- `lib/core/services/zoom_meeting_sdk_join_service.dart` - Native SDK join service
- `lib/core/services/zoom_web_sdk_service.dart` - Web SDK join service
- `lib/core/models/teaching_shift.dart` - Shift model with Zoom fields
- `lib/features/zoom/screens/zoom_screen.dart` - Teacher Zoom meeting list UI
- `lib/features/zoom/screens/admin_zoom_screen.dart` - Admin Zoom management UI

### Web Assets

- `web/zoom_integration.js` - Zoom Web SDK integration
- `web/index.html` - Loads Zoom Web SDK

---

## Summary Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    ADMIN CREATES SHIFT                          │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
            ┌──────────────────────────────┐
            │ scheduleShiftLifecycle()     │
            │ Cloud Function               │
            └──────────────┬───────────────┘
                           │
                           ├─→ Cloud Task: Start (scheduled for shiftStart)
                           ├─→ Cloud Task: End (scheduled for shiftEnd)
                           │
                           ▼
            ┌──────────────────────────────┐
            │ ensureZoomMeetingAndEmail    │
            │ Teacher()                    │
            └──────────────┬───────────────┘
                           │
                           ├─→ Find Available Host (check capacity)
                           │
                           ├─→ Check for Overlapping Shifts
                           │   ├─→ NO OVERLAP: Create NEW meeting + 1 breakout room
                           │   └─→ OVERLAP: Update EXISTING meeting, add breakout room
                           │
                           ├─→ Zoom API: createMeeting() or updateMeeting()
                           │
                           ├─→ Encrypt & Store: zoom_meeting_id, zoom_encrypted_join_url
                           │
                           ├─→ Send Email: Teacher + Students/Guardians
                           │
                           └─→ Schedule Breakout Opener (3 min after start)

┌─────────────────────────────────────────────────────────────────┐
│         [TIME PASSES UNTIL 10 MIN BEFORE SHIFT]                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│              TEACHER CLICKS "START CLASS"                       │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
            ┌──────────────────────────────┐
            │ ZoomService.joinClass()      │
            └──────────────┬───────────────┘
                           │
                           ├─→ Check Time Window (10 min before to 10 min after)
                           │
                           ├─→ [NEW] checkActiveMeetings()
                           │   └─→ If active, show dialog → endActiveMeetings()
                           │
                           ▼
            ┌──────────────────────────────┐
            │ getZoomMeetingSdkJoinPayload │
            │ Cloud Function               │
            └──────────────┬───────────────┘
                           │
                           ├─→ Decrypt join URL & passcode
                           ├─→ Generate Meeting SDK JWT
                           └─→ Return: meetingNumber, passcode, JWT, sdkKey
                           │
                           ▼
            ┌──────────────────────────────┐
            │ Initialize Zoom SDK          │
            │ (Mobile: Native SDK)         │
            │ (Web: Web SDK)               │
            └──────────────┬───────────────┘
                           │
                           ▼
            ┌──────────────────────────────┐
            │ Join Meeting                 │
            │ → Auto-routed to breakout    │
            │   room via email pre-assign  │
            └──────────────────────────────┘
```

---

## Troubleshooting Guide

### Issue: "You are hosting another meeting" Error

**Cause:** Another meeting is still active on the same Zoom host account.

**Solution:**
1. System now automatically detects this and shows dialog
2. Click "End & Start My Class" to end previous meeting
3. If dialog doesn't appear, manually call `endActiveZoomMeetings` Cloud Function

### Issue: Not Auto-Routed to Breakout Room

**Cause:** Email mismatch - user's Zoom email doesn't match pre-assigned email.

**Solution:**
1. Verify user's email in system matches their Zoom account email
2. Join Zoom with the same email that was registered in the system
3. If mismatch, user can manually join breakout room from main meeting

### Issue: Breakout Rooms Not Opening

**Cause:** Teacher didn't manually open rooms and scheduled task failed.

**Solution:**
1. Teacher should manually open rooms: "Breakout Rooms" → "Open All Rooms"
2. Check Cloud Task logs for breakout opener task
3. Verify `ZOOM_HOST_KEY` configuration is correct

### Issue: Meeting Creation Fails

**Cause:** Various - host capacity, API errors, missing config.

**Solution:**
1. Check shift document for `zoom_error` field
2. Verify Zoom environment variables are set
3. Check host capacity in `zoom_hosts` collection
4. Verify Zoom API credentials and permissions

### Issue: Multiple Meetings Created for Same Shift

**Cause:** Both standalone and hub systems running, or duplicate calls.

**Solution:**
1. Check if shift has both `zoom_meeting_id` and `hubMeetingId`
2. Standardize on one system (prefer hub for multiple shifts)
3. Add idempotency checks to prevent duplicate creation

---

## Future Improvements

1. **Unified Meeting System**
   - Consolidate standalone and hub systems
   - Single code path for all meeting creation

2. **Better Breakout Room Management**
   - More reliable auto-opening mechanism
   - Better handling of late joins

3. **Enhanced Routing**
   - Support for multiple email addresses
   - Fallback routing mechanisms

4. **Concurrent Meeting Support**
   - Upgrade Zoom plan or implement better host distribution
   - Remove need to end previous meetings

5. **Monitoring & Analytics**
   - Track meeting creation success rates
   - Monitor host capacity utilization
   - Alert on routing failures

---

**Last Updated:** 2024-12-20
**Author:** System Documentation
**Version:** 1.0

