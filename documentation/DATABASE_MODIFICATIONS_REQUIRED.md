# Database Modifications Required
## Alluvial Academy - Firebase/Firestore Changes

**Created:** November 28, 2025  
**Purpose:** Document all database changes needed for the new features

---

## 📊 Current Firestore Collections Summary

| Collection | Purpose | Document Count |
|------------|---------|----------------|
| `teaching_shifts` | Teacher/class schedules | Active |
| `timesheet_entries` | Clock-in/out records | Active |
| `tasks` | Task management | Active |
| `users` | User profiles | Active |
| `job_board` | Job opportunities | Active |
| `enrollments` | Student enrollments | Active |

---

## 🔴 Required Database Modifications

### 1. `teaching_shifts` Collection - ADD FIELDS

#### New Fields Required:

| Field Name | Type | Default | Purpose |
|------------|------|---------|---------|
| `shift_category` | string | `'teaching'` | Distinguish teacher vs leader schedules |
| `leader_role` | string | `null` | Role type for leader shifts |

#### Field Values for `shift_category`:
- `'teaching'` - Regular teacher-student class (default)
- `'leadership'` - Admin/leader duties
- `'meeting'` - Scheduled meetings
- `'training'` - Staff training sessions

#### Field Values for `leader_role` (when category is not 'teaching'):
- `'admin'` - Administrative duties
- `'coordination'` - Team coordination
- `'meeting'` - Meetings
- `'training'` - Staff training
- `'planning'` - Curriculum planning
- `'outreach'` - Community outreach

**No migration needed** - New fields will be added to new documents. Existing documents without these fields will be treated as `teaching` category.

---

### 2. `timesheet_entries` Collection - ADD FIELDS

#### Current Fields (for reference):
```javascript
{
  teacher_id: string,
  teacher_email: string,
  teacher_name: string,
  shift_id: string,           // ✅ Already exists
  date: string,
  student_name: string,
  start_time: string,
  end_time: string,
  total_hours: string,
  hourly_rate: number,
  description: string,
  status: string,
  source: string,
  clock_in_timestamp: Timestamp,
  clock_in_platform: string,  // ✅ Already exists
  clock_in_latitude: number,
  clock_in_longitude: number,
  clock_in_address: string,
  clock_in_neighborhood: string,
  clock_out_latitude: number,
  clock_out_longitude: number,
  clock_out_address: string,
  clock_out_neighborhood: string,
  created_at: Timestamp,
  updated_at: Timestamp,
}
```

#### NEW Fields Required:

| Field Name | Type | Default | Purpose |
|------------|------|---------|---------|
| `shift_title` | string | `''` | **CRITICAL** - Cached shift display name for export |
| `shift_type` | string | `''` | Formatted type string (e.g., "Stu - John - Teacher (1hr)") |
| `clock_out_platform` | string | `null` | Device used for clock-out |
| `scheduled_start` | Timestamp | `null` | Original scheduled start time |
| `scheduled_end` | Timestamp | `null` | Original scheduled end time |
| `scheduled_duration_minutes` | number | `null` | Scheduled duration |
| `employee_notes` | string | `''` | Notes from teacher |
| `manager_notes` | string | `''` | Notes from admin |

**Migration Note:** These are additive fields. Existing documents will work without them, but exports will show empty values for old records.

---

### 3. `tasks` Collection - ADD FIELDS

#### Current Fields (for reference):
```javascript
{
  id: string,
  title: string,
  description: string,
  createdBy: string,
  assignedTo: [string],
  dueDate: Timestamp,
  priority: string,
  status: string,
  isRecurring: boolean,
  recurrenceType: string,
  enhancedRecurrence: object,
  createdAt: Timestamp,
  attachments: [object],
  completedAt: Timestamp,
  overdueDaysAtCompletion: number,
}
```

#### NEW Fields Required:

| Field Name | Type | Default | Purpose |
|------------|------|---------|---------|
| `isArchived` | boolean | `false` | For "Archived" tab |
| `archivedAt` | Timestamp | `null` | When task was archived |
| `startDate` | Timestamp | `null` | Start date for ConnectTeam-style display |

**Migration Note:** Existing tasks will show as not archived. No data migration needed.

---

## 📝 Firestore Security Rules Updates

If you have security rules, you may need to add rules for the new fields:

```javascript
// firestore.rules additions
match /teaching_shifts/{shiftId} {
  allow read, write: if request.auth != null;
  // New fields: shift_category, leader_role
}

match /timesheet_entries/{entryId} {
  allow read, write: if request.auth != null;
  // New fields: shift_title, shift_type, clock_out_platform, 
  //             scheduled_start, scheduled_end, scheduled_duration_minutes,
  //             employee_notes, manager_notes
}

match /tasks/{taskId} {
  allow read, write: if request.auth != null;
  // New fields: isArchived, archivedAt, startDate
}
```

---

## 🔧 Firestore Indexes Required

You may need to create composite indexes for queries:

### teaching_shifts indexes:
```
Collection: teaching_shifts
Fields: shift_category ASC, shift_start ASC
```

### tasks indexes:
```
Collection: tasks
Fields: isArchived ASC, createdAt DESC

Collection: tasks
Fields: createdBy ASC, isArchived ASC, createdAt DESC
```

---

## 🚀 Migration Scripts (Optional)

### Backfill shift_title for existing timesheet_entries:

If you want to populate `shift_title` for existing records:

```javascript
// Run in Firebase Console > Cloud Shell or as a Cloud Function

const admin = require('firebase-admin');
admin.initializeApp();

async function backfillShiftTitles() {
  const db = admin.firestore();
  const batch = db.batch();
  
  const entries = await db.collection('timesheet_entries').get();
  let count = 0;
  
  for (const entryDoc of entries.docs) {
    const data = entryDoc.data();
    
    // Skip if already has shift_title
    if (data.shift_title) continue;
    
    // Get shift details if shift_id exists
    if (data.shift_id) {
      try {
        const shiftDoc = await db.collection('teaching_shifts').doc(data.shift_id).get();
        if (shiftDoc.exists) {
          const shift = shiftDoc.data();
          batch.update(entryDoc.ref, {
            shift_title: shift.auto_generated_name || shift.custom_name || '',
            shift_type: buildShiftType(shift),
            scheduled_start: shift.shift_start,
            scheduled_end: shift.shift_end,
            scheduled_duration_minutes: calculateDuration(shift),
          });
          count++;
        }
      } catch (e) {
        console.error(`Error processing entry ${entryDoc.id}:`, e);
      }
    }
    
    // Commit batch every 400 operations
    if (count >= 400) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  
  // Commit remaining
  if (count > 0) {
    await batch.commit();
  }
  
  console.log('Backfill complete');
}

function buildShiftType(shift) {
  const parts = [];
  if (shift.student_names && shift.student_names.length > 0) {
    parts.push(`Stu - ${shift.student_names[0]}`);
  }
  parts.push(shift.teacher_name);
  
  // Calculate duration
  const start = shift.shift_start.toDate();
  const end = shift.shift_end.toDate();
  const durationHours = (end - start) / (1000 * 60 * 60);
  parts.push(`(${durationHours.toFixed(0)}hr)`);
  
  return parts.join(' - ');
}

function calculateDuration(shift) {
  const start = shift.shift_start.toDate();
  const end = shift.shift_end.toDate();
  return Math.round((end - start) / (1000 * 60));
}
```

---

## ✅ Pre-Implementation Checklist

Before starting code changes, verify:

- [ ] Firebase Console access confirmed
- [ ] Current data backed up (export collections)
- [ ] Security rules reviewed
- [ ] No breaking changes to existing queries
- [ ] Test environment available (or test on production with caution)

---

## 📋 Questions for You Before Proceeding

1. **Do you want to run the backfill migration** for existing timesheet entries to populate `shift_title`? (Recommended for accurate historical exports)

2. **Do you want me to create a Firestore index** for the new queries? (Can be done via Firebase Console)

3. **Are there any other fields** in your current data that you want to include in exports that I might have missed?

4. **For Leader schedules**, do you have specific roles/duties you want to add beyond the ones I listed?

---

*This document outlines all database changes. No actual modifications have been made yet.*

