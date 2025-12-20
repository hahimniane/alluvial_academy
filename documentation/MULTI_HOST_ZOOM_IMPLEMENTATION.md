# Multi-Host Zoom Meeting System - Implementation Guide

## Overview

This document describes the implementation of a multi-host Zoom meeting system that allows the application to distribute meetings across multiple Zoom licensed accounts. The system prevents shift creation when all hosts are busy and provides admin tools to manage Zoom host accounts dynamically.

**Status:** To Be Implemented  
**Priority:** High  
**Date:** 2025

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Requirements](#requirements)
3. [Architecture](#architecture)
4. [Firestore Schema](#firestore-schema)
5. [Backend Implementation](#backend-implementation)
6. [Frontend Implementation](#frontend-implementation)
7. [Error Handling](#error-handling)
8. [Testing Scenarios](#testing-scenarios)
9. [Migration Strategy](#migration-strategy)

---

## Problem Statement

### Current State

- All Zoom meetings are created under a single `ZOOM_HOST_USER` (from environment variable)
- When multiple meetings occur at the same time, they all try to use the same host
- Zoom limits: **1 concurrent meeting per licensed user** (Basic/Pro accounts)
- No mechanism to distribute meetings across multiple licensed accounts
- No way to add new licensed accounts without code changes

### Desired State

- Support multiple Zoom licensed accounts (hosts)
- Automatically assign meetings to available hosts
- **Fill-first strategy**: Use Host 1 until busy, then Host 2, etc.
- Block shift creation when all hosts are busy
- Provide clear error messages with alternative times
- Admin dashboard to add/manage hosts dynamically
- Validate new hosts before adding them

---

## Requirements

### Functional Requirements

1. **Host Management**
   - Store hosts in Firestore (not environment variables)
   - Each host has: email, active status, max concurrent meetings (default: 1)
   - Admin can add new hosts via dashboard
   - Validate host email via Zoom API before saving

2. **Host Selection (Fill-First Strategy)**
   - Check hosts in order (by creation date or priority)
   - Use first host that has available capacity
   - Only move to next host if current is at capacity
   - This leaves other hosts free for future shifts

3. **Pre-Creation Validation**
   - Before creating shift, check if any host is available
   - If all hosts busy, block shift creation
   - Return error with alternative time suggestions
   - Suggest purchasing more licenses

4. **Capacity Management**
   - Default: 1 concurrent meeting per host
   - Configurable per host (for Business/Enterprise accounts with add-ons)
   - Track current usage per host during time slot

### Non-Functional Requirements

1. **Backward Compatibility**
   - Existing `ZOOM_HOST_USER` env var should work as fallback
   - Migrate existing single host to Firestore on first run
   - Existing meetings without `zoom_host_user` field handled gracefully

2. **Error Handling**
   - Graceful degradation if host selection fails
   - Clear error messages for admins and users
   - Logging for debugging

3. **Performance**
   - Efficient Firestore queries
   - Cache host list if needed
   - Minimize API calls to Zoom

---

## Architecture

### System Flow

```
┌─────────────────────────────────────────────────┐
│  Admin: Add New Host                            │
│  - Enter email in Settings                      │
│  - System validates via Zoom API                │
│  - Save to Firestore if valid                   │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│  Shift Creation Request                         │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│  Check Host Availability                        │
│  1. Get active hosts from Firestore             │
│  2. Query existing meetings in time slot        │
│  3. Count meetings per host                      │
│  4. Find first host with capacity               │
└─────────────────┬───────────────────────────────┘
                  │
         ┌────────┴────────┐
         │                 │
    Available?        All Busy?
         │                 │
         ▼                 ▼
┌──────────────┐  ┌──────────────────────┐
│ Create Shift │  │ Block Creation       │
│ Assign Host  │  │ Return Error:        │
│ Store Host   │  │ - Alternative times  │
│              │  │ - Suggest licenses    │
└──────────────┘  └──────────────────────┘
```

### Component Overview

1. **Firestore Collections**
   - `zoom_hosts` - Active Zoom host accounts
   - `teaching_shifts` - Existing shifts (already has Zoom meeting data)

2. **Backend Services (Firebase Functions)**
   - `host_selector.js` - Find available host for time slot
   - `host_validator.js` - Validate new host email via Zoom API
   - `config.js` - Updated to support Firestore hosts
   - `client.js` - Updated to accept host parameter
   - `shift_zoom.js` - Updated to use host selection
   - `admin.js` - New admin endpoints for host management

3. **Frontend (Flutter)**
   - Admin Settings page - Manage Zoom hosts
   - Shift creation - Handle "no available host" error
   - Error UI - Show alternative times and license suggestion

---

## Firestore Schema

### Collection: `zoom_hosts`

```javascript
{
  // Document ID: email address (e.g., "host1@example.com")
  email: "host1@example.com",                    // String (required, unique)
  is_active: true,                                // Boolean (required, default: true)
  max_concurrent_meetings: 1,                     // Number (required, default: 1)
  added_at: Timestamp,                            // Timestamp (required)
  added_by: "admin_user_id",                      // String (user ID who added)
  last_validated_at: Timestamp,                   // Timestamp (when last validated)
  priority: 1,                                    // Number (optional, for ordering)
  notes: "Primary host account"                    // String (optional)
}
```

**Indexes Required:**
- None (collection is small, can query all active hosts)

**Security Rules:**
- Only admins can read/write
- Validation: email must be valid format
- Validation: max_concurrent_meetings >= 1

### Collection: `teaching_shifts` (Update Existing)

**New Field:**
```javascript
{
  // ... existing fields ...
  zoom_host_user: "host1@example.com"  // String (email of assigned host)
}
```

**Migration:**
- Existing shifts may not have this field
- Default to first host in list when reading old shifts

---

## Backend Implementation

### 1. Update `functions/services/zoom/config.js`

**Add function to get hosts from Firestore:**

```javascript
const admin = require('firebase-admin');

/**
 * Get all active Zoom hosts from Firestore
 * Falls back to ZOOM_HOST_USER env var if no hosts in Firestore
 * @returns {Promise<Array<{email: string, max_concurrent_meetings: number}>>}
 */
const getZoomHosts = async () => {
  try {
    const hostsSnapshot = await admin.firestore()
      .collection('zoom_hosts')
      .where('is_active', '==', true)
      .orderBy('priority', 'asc')
      .orderBy('added_at', 'asc')
      .get();
    
    if (hostsSnapshot.empty) {
      // Fallback to environment variable for backward compatibility
      const hostUser = getConfigValue('ZOOM_HOST_USER');
      if (hostUser) {
        console.warn('[Zoom] No hosts in Firestore, using ZOOM_HOST_USER env var');
        return [{
          email: hostUser,
          max_concurrent_meetings: 1,
        }];
      }
      throw new Error('No Zoom hosts configured. Add hosts in admin settings.');
    }
    
    return hostsSnapshot.docs.map(doc => ({
      email: doc.data().email,
      max_concurrent_meetings: doc.data().max_concurrent_meetings || 1,
      priority: doc.data().priority || 999,
    }));
  } catch (error) {
    console.error('[Zoom] Error fetching hosts:', error);
    // Fallback to env var
    const hostUser = getConfigValue('ZOOM_HOST_USER');
    if (hostUser) {
      return [{
        email: hostUser,
        max_concurrent_meetings: 1,
      }];
    }
    throw error;
  }
};

module.exports = {
  getZoomConfig,
  getMeetingSdkConfig,
  isMeetingSdkConfigured,
  getZoomHosts, // NEW
};
```

### 2. Create `functions/services/zoom/host_validator.js`

**New file for validating host emails:**

```javascript
const admin = require('firebase-admin');
const {getZoomConfig} = require('./config');
const {getAccessToken} = require('./client');

/**
 * Validate a Zoom host email by testing API access
 * @param {string} email - Email address to validate
 * @returns {Promise<{valid: boolean, error?: string, accountType?: string}>}
 */
const validateHostEmail = async (email) => {
  if (!email || typeof email !== 'string' || !email.includes('@')) {
    return {
      valid: false,
      error: 'Invalid email format',
    };
  }
  
  try {
    const token = await getAccessToken();
    
    // Test by getting user info from Zoom API
    const resp = await fetch(`https://api.zoom.us/v2/users/${encodeURIComponent(email)}`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });
    
    if (!resp.ok) {
      const errorText = await resp.text().catch(() => '');
      if (resp.status === 404) {
        return {
          valid: false,
          error: 'User not found in Zoom account',
        };
      }
      if (resp.status === 403) {
        return {
          valid: false,
          error: 'Insufficient permissions to access this user',
        };
      }
      return {
        valid: false,
        error: `Zoom API error (${resp.status}): ${errorText || resp.statusText}`,
      };
    }
    
    const userData = await resp.json();
    
    // Check if user has a license (type 1 = Basic, 2 = Licensed, etc.)
    const userType = userData.type || 0;
    if (userType < 1) {
      return {
        valid: false,
        error: 'User does not have a Zoom license',
      };
    }
    
    // Determine max concurrent meetings based on account type
    // Basic/Pro: 1, Business/Enterprise: 2, with add-ons: 4 or 20
    let maxConcurrent = 1;
    if (userData.type === 2) {
      // Licensed user - check if Business/Enterprise
      maxConcurrent = 2; // Default for Business/Enterprise
    }
    
    return {
      valid: true,
      accountType: userData.type_name || 'Licensed',
      maxConcurrentMeetings: maxConcurrent,
    };
  } catch (error) {
    return {
      valid: false,
      error: `Validation failed: ${error.message}`,
    };
  }
};

module.exports = {
  validateHostEmail,
};
```

### 3. Create `functions/services/zoom/host_selector.js`

**New file for selecting available hosts:**

```javascript
const admin = require('firebase-admin');
const {getZoomHosts} = require('./config');

/**
 * Find an available Zoom host for a given time slot
 * Uses fill-first strategy: use first host with capacity
 * @param {Date} startTime - Meeting start time
 * @param {Date} endTime - Meeting end time
 * @returns {Promise<{host: string|null, reason?: string}>}
 */
const findAvailableHost = async (startTime, endTime) => {
  try {
    const hosts = await getZoomHosts();
    
    if (hosts.length === 0) {
      return {
        host: null,
        reason: 'No Zoom hosts configured',
      };
    }
    
    // Query all shifts with Zoom meetings that overlap the time slot
    const shiftsSnapshot = await admin.firestore()
      .collection('teaching_shifts')
      .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(startTime))
      .where('shift_start', '<', admin.firestore.Timestamp.fromDate(endTime))
      .where('zoom_meeting_id', '!=', null)
      .get();
    
    // Build map of host -> current meeting count
    const hostUsageMap = new Map();
    hosts.forEach(host => {
      hostUsageMap.set(host.email, {
        max: host.max_concurrent_meetings,
        current: 0,
      });
    });
    
    // Count meetings per host (check for overlaps)
    shiftsSnapshot.docs.forEach(doc => {
      const shift = doc.data();
      const assignedHost = shift.zoom_host_user || hosts[0].email; // Default to first if not assigned
      
      if (hostUsageMap.has(assignedHost)) {
        const shiftStart = shift.shift_start.toDate();
        const shiftEnd = shift.shift_end.toDate();
        
        // Check if this meeting overlaps with requested time
        const overlaps = startTime < shiftEnd && endTime > shiftStart;
        
        if (overlaps) {
          const usage = hostUsageMap.get(assignedHost);
          usage.current += 1;
        }
      }
    });
    
    // Find first host with available capacity (fill-first strategy)
    for (const host of hosts) {
      const usage = hostUsageMap.get(host.email);
      if (usage.current < usage.max) {
        return {
          host: host.email,
        };
      }
    }
    
    // All hosts are at capacity
    return {
      host: null,
      reason: 'All Zoom hosts are at capacity',
    };
  } catch (error) {
    console.error('[Zoom] Error finding available host:', error);
    return {
      host: null,
      reason: `Error checking host availability: ${error.message}`,
    };
  }
};

/**
 * Find alternative time slots when all hosts are busy
 * @param {Date} requestedStart - Original requested start time
 * @param {Date} requestedEnd - Original requested end time
 * @param {number} durationMinutes - Meeting duration
 * @param {number} maxSuggestions - Maximum number of suggestions
 * @returns {Promise<Array<{start: Date, end: Date}>>}
 */
const findAlternativeTimes = async (requestedStart, requestedEnd, durationMinutes, maxSuggestions = 5) => {
  try {
    const hosts = await getZoomHosts();
    if (hosts.length === 0) {
      return [];
    }
    
    const alternatives = [];
    const durationMs = durationMinutes * 60 * 1000;
    
    // Check next 7 days, every 30 minutes
    let checkTime = new Date(requestedStart);
    checkTime.setMinutes(0, 0, 0); // Round to hour
    
    const maxCheckTime = new Date(requestedStart);
    maxCheckTime.setDate(maxCheckTime.getDate() + 7);
    
    while (checkTime < maxCheckTime && alternatives.length < maxSuggestions) {
      const checkEnd = new Date(checkTime.getTime() + durationMs);
      
      const result = await findAvailableHost(checkTime, checkEnd);
      if (result.host) {
        alternatives.push({
          start: new Date(checkTime),
          end: new Date(checkEnd),
        });
      }
      
      // Check next 30 minutes
      checkTime = new Date(checkTime.getTime() + 30 * 60 * 1000);
    }
    
    return alternatives;
  } catch (error) {
    console.error('[Zoom] Error finding alternative times:', error);
    return [];
  }
};

module.exports = {
  findAvailableHost,
  findAlternativeTimes,
};
```

### 4. Update `functions/services/zoom/client.js`

**Modify `createMeeting` to accept host parameter:**

```javascript
/**
 * Create a new Zoom meeting
 * @param {Object} params
 * @param {string} params.topic - Meeting topic
 * @param {string} params.startTimeIso - Start time in ISO format
 * @param {number} params.durationMinutes - Duration in minutes
 * @param {string} params.agenda - Meeting agenda
 * @param {string} params.timezone - Timezone (default: 'UTC')
 * @param {string} params.hostUser - Host email (optional, uses config default if not provided)
 * @returns {Promise<{id: string, joinUrl: string, passcode: string|null}>}
 */
const createMeeting = async ({
  topic,
  startTimeIso,
  durationMinutes,
  agenda,
  timezone = 'UTC',
  hostUser, // NEW: Optional host parameter
}) => {
  // Use provided host or fall back to config default
  const {hostUser: defaultHost} = getZoomConfig();
  const selectedHost = hostUser || defaultHost;
  
  if (!selectedHost) {
    throw new Error('No Zoom host specified');
  }
  
  const token = await getAccessToken();
  
  const resp = await fetch(`https://api.zoom.us/v2/users/${encodeURIComponent(selectedHost)}/meetings`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      topic,
      type: 2,
      start_time: startTimeIso,
      duration: durationMinutes,
      timezone,
      agenda,
      settings: {
        join_before_host: true,
        waiting_room: false,
        host_video: true,
        participant_video: true,
        mute_upon_entry: false,
      },
    }),
  });
  
  // ... rest of existing code ...
};
```

### 5. Update `functions/services/zoom/shift_zoom.js`

**Add host selection before creating meeting:**

```javascript
const {findAvailableHost, findAlternativeTimes} = require('./host_selector');

const ensureZoomMeetingAndEmailTeacher = async ({shiftId, shiftData}) => {
  // ... existing validation code ...
  
  if (!hasExistingMeeting) {
    // NEW: Check host availability before creating meeting
    const availableHost = await findAvailableHost(shiftStart, shiftEnd);
    
    if (!availableHost.host) {
      // Find alternative times
      const durationMinutes = Math.max(1, Math.ceil((shiftEnd.getTime() - shiftStart.getTime()) / 60000));
      const alternatives = await findAlternativeTimes(shiftStart, shiftEnd, durationMinutes, 5);
      
      // Format alternative times for error message
      const formattedAlternatives = alternatives.map(alt => ({
        start: formatInZone(alt.start, teacherTimezone),
        end: formatInZone(alt.end, teacherTimezone),
        startIso: alt.start.toISOString(),
        endIso: alt.end.toISOString(),
      }));
      
      throw new Error(JSON.stringify({
        code: 'NO_AVAILABLE_HOST',
        message: 'All Zoom host accounts are currently at capacity for this time slot.',
        reason: availableHost.reason || 'All hosts busy',
        alternativeTimes: formattedAlternatives,
        suggestMoreLicenses: true,
      }));
    }
    
    const startTimeIso = shiftStart.toISOString();
    const meeting = await createMeeting({
      topic,
      startTimeIso,
      durationMinutes,
      agenda,
      timezone: 'UTC',
      hostUser: availableHost.host, // NEW: Pass selected host
    });
    
    // ... existing encryption code ...
    
    // NEW: Store host assignment
    const updateData = {
      zoom_meeting_id: meeting.id,
      zoom_encrypted_join_url: encryptedJoinUrl,
      zoom_meeting_created_at: admin.firestore.FieldValue.serverTimestamp(),
      zoom_host_user: availableHost.host, // NEW: Store which host was used
    };
    
    // ... rest of existing code ...
  } else {
    // Existing meeting - ensure host is stored (for migration)
    if (!shiftData.zoom_host_user) {
      const hosts = await getZoomHosts();
      if (hosts.length > 0) {
        await shiftRef.update({
          zoom_host_user: hosts[0].email, // Default to first host
        });
      }
    }
  }
  
  // ... rest of existing code ...
};
```

### 6. Create `functions/handlers/admin_zoom.js`

**New file for admin endpoints:**

```javascript
const admin = require('firebase-admin');
const {validateHostEmail} = require('../services/zoom/host_validator');
const {getZoomHosts} = require('../services/zoom/config');

/**
 * Check if user is admin
 */
const isUserAdmin = async (uid) => {
  if (!uid) return false;
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    const data = userDoc.data();
    return (
      data.role === 'admin' ||
      data.user_type === 'admin' ||
      data.userType === 'admin' ||
      data.is_admin === true ||
      data.isAdmin === true ||
      data.is_admin_teacher === true
    );
  } catch (_) {
    return false;
  }
};

/**
 * Add a new Zoom host
 * POST /addZoomHost
 */
const addZoomHost = onCall(async (request) => {
  const {email, maxConcurrentMeetings} = request.data;
  const uid = request.auth?.uid;
  
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  if (!(await isUserAdmin(uid))) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can add Zoom hosts');
  }
  
  if (!email || typeof email !== 'string' || !email.includes('@')) {
    throw new functions.https.HttpsError('invalid-argument', 'Valid email address required');
  }
  
  // Check if host already exists
  const existingDoc = await admin.firestore().collection('zoom_hosts').doc(email).get();
  if (existingDoc.exists) {
    const existing = existingDoc.data();
    if (existing.is_active) {
      throw new functions.https.HttpsError('already-exists', 'This host is already active');
    }
    // Reactivate existing host
    await existingDoc.ref.update({
      is_active: true,
      last_validated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {success: true, message: 'Host reactivated'};
  }
  
  // Validate host email via Zoom API
  const validation = await validateHostEmail(email);
  if (!validation.valid) {
    throw new functions.https.HttpsError('failed-precondition', validation.error || 'Host validation failed');
  }
  
  // Get max concurrent meetings (from validation or parameter)
  const maxConcurrent = maxConcurrentMeetings || validation.maxConcurrentMeetings || 1;
  
  // Get current priority (next in sequence)
  const hostsSnapshot = await admin.firestore()
    .collection('zoom_hosts')
    .orderBy('priority', 'desc')
    .limit(1)
    .get();
  
  const nextPriority = hostsSnapshot.empty 
    ? 1 
    : (hostsSnapshot.docs[0].data().priority || 0) + 1;
  
  // Save to Firestore
  await admin.firestore().collection('zoom_hosts').doc(email).set({
    email,
    is_active: true,
    max_concurrent_meetings: maxConcurrent,
    added_at: admin.firestore.FieldValue.serverTimestamp(),
    added_by: uid,
    last_validated_at: admin.firestore.FieldValue.serverTimestamp(),
    priority: nextPriority,
  });
  
  return {
    success: true,
    message: 'Host added successfully',
    host: {
      email,
      max_concurrent_meetings: maxConcurrent,
      account_type: validation.accountType,
    },
  };
});

/**
 * List all Zoom hosts with utilization
 * GET /listZoomHosts
 */
const listZoomHosts = onCall(async (request) => {
  const uid = request.auth?.uid;
  
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  if (!(await isUserAdmin(uid))) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can view Zoom hosts');
  }
  
  const hostsSnapshot = await admin.firestore()
    .collection('zoom_hosts')
    .orderBy('priority', 'asc')
    .orderBy('added_at', 'asc')
    .get();
  
  const now = new Date();
  const oneWeekFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  
  const hosts = await Promise.all(hostsSnapshot.docs.map(async (doc) => {
    const hostData = doc.data();
    
    // Count upcoming meetings for this host
    const upcomingMeetings = await admin.firestore()
      .collection('teaching_shifts')
      .where('zoom_host_user', '==', hostData.email)
      .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(now))
      .where('shift_start', '<=', admin.firestore.Timestamp.fromDate(oneWeekFromNow))
      .where('zoom_meeting_id', '!=', null)
      .get();
    
    return {
      email: hostData.email,
      is_active: hostData.is_active,
      max_concurrent_meetings: hostData.max_concurrent_meetings || 1,
      added_at: hostData.added_at?.toDate()?.toISOString(),
      added_by: hostData.added_by,
      priority: hostData.priority || 999,
      upcoming_meetings_count: upcomingMeetings.size,
      utilization: `${upcomingMeetings.size}/${hostData.max_concurrent_meetings || 1}`,
    };
  }));
  
  return {hosts};
});

/**
 * Remove/deactivate a Zoom host
 * DELETE /removeZoomHost
 */
const removeZoomHost = onCall(async (request) => {
  const {email} = request.data;
  const uid = request.auth?.uid;
  
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  if (!(await isUserAdmin(uid))) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can remove Zoom hosts');
  }
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email required');
  }
  
  const hostDoc = await admin.firestore().collection('zoom_hosts').doc(email).get();
  if (!hostDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Host not found');
  }
  
  // Check for upcoming meetings
  const now = new Date();
  const upcomingMeetings = await admin.firestore()
    .collection('teaching_shifts')
    .where('zoom_host_user', '==', email)
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(now))
    .where('zoom_meeting_id', '!=', null)
    .get();
  
  if (upcomingMeetings.size > 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Cannot remove host: ${upcomingMeetings.size} upcoming meeting(s) scheduled`
    );
  }
  
  // Deactivate instead of deleting (preserve history)
  await hostDoc.ref.update({
    is_active: false,
  });
  
  return {success: true, message: 'Host deactivated'};
});

module.exports = {
  addZoomHost,
  listZoomHosts,
  removeZoomHost,
};
```

### 7. Update `functions/index.js`

**Register new admin endpoints:**

```javascript
// ... existing imports ...
const {addZoomHost, listZoomHosts, removeZoomHost} = require('./handlers/admin_zoom');

// ... existing exports ...
exports.addZoomHost = addZoomHost;
exports.listZoomHosts = listZoomHosts;
exports.removeZoomHost = removeZoomHost;
```

---

## Frontend Implementation

### 1. Admin Settings Page - Zoom Hosts Section

**Location:** `lib/presentation/pages/admin/settings/zoom_hosts_settings.dart` (new file)

**UI Components:**
- List of active hosts with:
  - Email address
  - Status (Active/Inactive)
  - Utilization (e.g., "2/1 meetings" - shows if over capacity)
  - Remove button
- Add new host form:
  - Email input field
  - "Validate & Add" button
  - Loading state during validation
  - Success/error feedback

**Implementation:**

```dart
class ZoomHostsSettingsPage extends StatefulWidget {
  @override
  _ZoomHostsSettingsPageState createState() => _ZoomHostsSettingsPageState();
}

class _ZoomHostsSettingsPageState extends State<ZoomHostsSettingsPage> {
  List<ZoomHost> _hosts = [];
  bool _loading = true;
  final TextEditingController _emailController = TextEditingController();
  bool _addingHost = false;

  @override
  void initState() {
    super.initState();
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    setState(() => _loading = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('listZoomHosts')
          .call();
      
      setState(() {
        _hosts = (result.data['hosts'] as List)
            .map((h) => ZoomHost.fromMap(h))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      // Show error
    }
  }

  Future<void> _addHost() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      // Show validation error
      return;
    }

    setState(() => _addingHost = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('addZoomHost')
          .call({'email': email});
      
      _emailController.clear();
      await _loadHosts();
      // Show success message
    } catch (e) {
      // Show error message
    } finally {
      setState(() => _addingHost = false);
    }
  }

  Future<void> _removeHost(String email) async {
    // Show confirmation dialog
    try {
      await FirebaseFunctions.instance
          .httpsCallable('removeZoomHost')
          .call({'email': email});
      await _loadHosts();
    } catch (e) {
      // Show error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Zoom Host Accounts')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Add host form
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Host Email',
                            hintText: 'host@example.com',
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addingHost ? null : _addHost,
                        child: _addingHost
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('Add Host'),
                      ),
                    ],
                  ),
                ),
                // Hosts list
                Expanded(
                  child: ListView.builder(
                    itemCount: _hosts.length,
                    itemBuilder: (context, index) {
                      final host = _hosts[index];
                      return ListTile(
                        title: Text(host.email),
                        subtitle: Text(
                          'Utilization: ${host.utilization}\n'
                          'Max: ${host.maxConcurrentMeetings} meetings',
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _removeHost(host.email),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
```

### 2. Update Shift Creation Error Handling

**Location:** Wherever shift creation happens (likely in shift creation service/screen)

**Handle `NO_AVAILABLE_HOST` error:**

```dart
try {
  await createShift(...);
} catch (e) {
  if (e.toString().contains('NO_AVAILABLE_HOST')) {
    try {
      final errorData = jsonDecode(e.message);
      _showNoHostAvailableDialog(
        errorData['alternativeTimes'] ?? [],
        errorData['suggestMoreLicenses'] ?? false,
      );
    } catch (_) {
      _showGenericError('All Zoom hosts are busy. Please try a different time.');
    }
  } else {
    // Handle other errors
  }
}

void _showNoHostAvailableDialog(List alternativeTimes, bool suggestLicenses) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('No Available Zoom Host'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Zoom host accounts are currently at capacity for this time slot.'),
          if (alternativeTimes.isNotEmpty) ...[
            SizedBox(height: 16),
            Text('Alternative available times:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...alternativeTimes.take(5).map((alt) => 
              ListTile(
                title: Text('${alt['start']} - ${alt['end']}'),
                onTap: () {
                  // Pre-fill shift form with this time
                  Navigator.pop(context);
                  // Update shift start/end times
                },
              )
            ),
          ],
          if (suggestLicenses) ...[
            SizedBox(height: 16),
            Text(
              'Consider purchasing additional Zoom licenses to support more concurrent meetings.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

---

## Error Handling

### Error Codes

1. **`NO_AVAILABLE_HOST`**
   - **When:** All hosts are at capacity
   - **Response:** Block shift creation, show alternatives
   - **User Message:** "All Zoom hosts are busy. Here are alternative times..."

2. **`NO_HOSTS_CONFIGURED`**
   - **When:** No active hosts in Firestore and no env var
   - **Response:** Block shift creation
   - **User Message:** "No Zoom hosts configured. Contact administrator."

3. **`HOST_VALIDATION_FAILED`**
   - **When:** New host email validation fails
   - **Response:** Don't save host
   - **User Message:** Show specific validation error

### Logging

Log all host selection attempts:
```javascript
console.log(`[Zoom] Finding host for shift ${shiftId}: ${startTime} - ${endTime}`);
console.log(`[Zoom] Available hosts: ${hosts.length}`);
console.log(`[Zoom] Selected host: ${selectedHost}`);
console.warn(`[Zoom] All hosts busy for shift ${shiftId}`);
```

---

## Testing Scenarios

### Test Case 1: Single Host Available
- **Setup:** 1 active host, no existing meetings
- **Action:** Create shift at 2:00 PM
- **Expected:** Shift created, assigned to Host 1

### Test Case 2: Host at Capacity
- **Setup:** 1 active host, 1 meeting at 2:00 PM
- **Action:** Create shift at 2:00 PM
- **Expected:** Shift creation blocked, error with alternatives

### Test Case 3: Multiple Hosts - Fill First
- **Setup:** 2 active hosts, Host 1 has 0 meetings, Host 2 has 0 meetings
- **Action:** Create shift at 2:00 PM
- **Expected:** Shift created, assigned to Host 1

### Test Case 4: Multiple Hosts - Second Host Used
- **Setup:** 2 active hosts, Host 1 has 1 meeting at 2:00 PM, Host 2 has 0 meetings
- **Action:** Create shift at 2:00 PM
- **Expected:** Shift created, assigned to Host 2

### Test Case 5: All Hosts Busy
- **Setup:** 2 active hosts, both have 1 meeting at 2:00 PM
- **Action:** Create shift at 2:00 PM
- **Expected:** Shift creation blocked, error with alternatives and license suggestion

### Test Case 6: Add New Host
- **Action:** Admin adds new host email
- **Expected:** Email validated via Zoom API, saved to Firestore if valid

### Test Case 7: Remove Host with Upcoming Meetings
- **Setup:** Host has upcoming meetings
- **Action:** Admin tries to remove host
- **Expected:** Removal blocked with error message

### Test Case 8: Backward Compatibility
- **Setup:** No hosts in Firestore, `ZOOM_HOST_USER` env var set
- **Action:** Create shift
- **Expected:** Uses env var host, works as before

---

## Migration Strategy

### Phase 1: Backend Implementation
1. Create new files (`host_selector.js`, `host_validator.js`, `admin_zoom.js`)
2. Update existing files (`config.js`, `client.js`, `shift_zoom.js`)
3. Deploy functions
4. Test with existing single host (backward compatible)

### Phase 2: Firestore Migration
1. Create `zoom_hosts` collection
2. Migrate existing `ZOOM_HOST_USER` to Firestore:
   ```javascript
   // One-time migration script
   const hostUser = process.env.ZOOM_HOST_USER;
   if (hostUser) {
     await admin.firestore().collection('zoom_hosts').doc(hostUser).set({
       email: hostUser,
       is_active: true,
       max_concurrent_meetings: 1,
       added_at: admin.firestore.FieldValue.serverTimestamp(),
       added_by: 'system',
       priority: 1,
     });
   }
   ```

### Phase 3: Update Existing Shifts
1. Backfill `zoom_host_user` field for existing shifts:
   ```javascript
   // One-time backfill script
   const hosts = await getZoomHosts();
   if (hosts.length > 0) {
     const defaultHost = hosts[0].email;
     const shiftsSnapshot = await admin.firestore()
       .collection('teaching_shifts')
       .where('zoom_meeting_id', '!=', null)
       .where('zoom_host_user', '==', null)
       .get();
     
     const batch = admin.firestore().batch();
     shiftsSnapshot.docs.forEach(doc => {
       batch.update(doc.ref, {zoom_host_user: defaultHost});
     });
     await batch.commit();
   }
   ```

### Phase 4: Frontend Implementation
1. Create admin settings page for Zoom hosts
2. Update shift creation error handling
3. Test end-to-end flow

### Phase 5: Documentation
1. Update admin guide with host management instructions
2. Document error messages for users
3. Create troubleshooting guide

---

## Security Considerations

1. **Admin-Only Access**
   - Only admins can add/remove hosts
   - Validate admin status in all admin endpoints

2. **Host Validation**
   - Always validate new hosts via Zoom API
   - Don't trust user input

3. **Error Messages**
   - Don't expose internal host details to non-admins
   - Generic error messages for regular users

4. **Firestore Rules**
   ```javascript
   match /zoom_hosts/{hostId} {
     allow read: if request.auth != null && isAdmin();
     allow write: if request.auth != null && isAdmin();
   }
   ```

---

## Success Criteria

✅ Multiple hosts can be added via admin dashboard  
✅ Meetings are distributed across hosts using fill-first strategy  
✅ Shift creation is blocked when all hosts are busy  
✅ Clear error messages with alternative times  
✅ License purchase suggestion shown when appropriate  
✅ New hosts are validated before being saved  
✅ Backward compatibility maintained with single host setup  
✅ Existing shifts work without `zoom_host_user` field  

---

## Notes

- Default capacity is 1 meeting per host (Basic/Pro accounts)
- Can be configured to 2, 4, or 20 for Business/Enterprise with add-ons
- Fill-first strategy maximizes availability of other hosts
- All host management is done via Firestore (no code changes needed)
- System gracefully handles missing `zoom_host_user` field on old shifts

---

## Implementation Checklist

### Backend
- [ ] Create `host_selector.js`
- [ ] Create `host_validator.js`
- [ ] Create `admin_zoom.js`
- [ ] Update `config.js` with `getZoomHosts()`
- [ ] Update `client.js` to accept host parameter
- [ ] Update `shift_zoom.js` to use host selection
- [ ] Register admin endpoints in `index.js`
- [ ] Add error handling for `NO_AVAILABLE_HOST`

### Frontend
- [ ] Create `zoom_hosts_settings.dart` page
- [ ] Add to admin settings navigation
- [ ] Update shift creation error handling
- [ ] Create error dialog with alternatives
- [ ] Add license suggestion UI

### Migration
- [ ] Create migration script for existing host
- [ ] Backfill `zoom_host_user` for existing shifts
- [ ] Test backward compatibility

### Testing
- [ ] Test single host scenario
- [ ] Test multiple hosts with fill-first
- [ ] Test all hosts busy scenario
- [ ] Test host validation
- [ ] Test host removal with meetings
- [ ] Test error messages and alternatives

---

**End of Implementation Guide**

