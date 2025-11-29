# Database Setup Guide
## Alluvial Academy - Firestore Configuration

**Created:** Based on DATABASE_MODIFICATIONS_REQUIRED.md  
**Purpose:** Step-by-step guide to configure Firestore for new features

---

## 📋 Pre-Setup Checklist

Before making any changes:

- [ ] **Backup your data** - Export all collections from Firebase Console
- [ ] **Test environment** - If available, test changes there first
- [ ] **Firebase Console access** - Ensure you have admin access
- [ ] **Review current rules** - Understand existing security rules

---

## 🔧 Step 1: Review Current Security Rules

Your current `firestore.rules` already has rules for:
- ✅ `teaching_shifts` - Teachers can read their own, admins can read/write all
- ✅ `timesheet_entries` - Teachers can read/write their own, admins can read/write all
- ✅ `tasks` - (Need to verify if rules exist)

**Action Required:** The new fields are **additive** and don't require rule changes. The existing rules will automatically allow the new fields since they follow the same access patterns.

---

## 📊 Step 2: Add Firestore Indexes

### Index 1: Teaching Shifts by Category

**Purpose:** Filter shifts by category (teaching/leadership/meeting/training)

**Add to `firestore.indexes.json`:**

```json
{
  "collectionGroup": "teaching_shifts",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "shift_category",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "shift_start",
      "order": "ASCENDING"
    }
  ]
}
```

### Index 2: Tasks by Archive Status

**Purpose:** Filter tasks by archive status for the "Archived" tab

**Add to `firestore.indexes.json`:**

```json
{
  "collectionGroup": "tasks",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "isArchived",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "createdAt",
      "order": "DESCENDING"
    }
  ]
}
```

### Index 3: Tasks by Creator and Archive Status

**Purpose:** Filter "Tasks Created By Me" tab efficiently

**Add to `firestore.indexes.json`:**

```json
{
  "collectionGroup": "tasks",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "createdBy",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "isArchived",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "createdAt",
      "order": "DESCENDING"
    }
  ]
}
```

---

## 🚀 Step 3: Deploy Indexes

### Option A: Via Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database** → **Indexes**
4. Click **"Create Index"**
5. For each index above:
   - Select collection group
   - Add fields in order
   - Set sort order (ASCENDING/DESCENDING)
   - Click **"Create"**

### Option B: Via Firebase CLI

```bash
# Deploy indexes
firebase deploy --only firestore:indexes
```

**Note:** Indexes can take a few minutes to build, especially if you have a lot of data.

---

## 📝 Step 4: Verify Field Names in Code

The Flutter code uses these field names when writing to Firestore:

### teaching_shifts:
- `shift_category` (string) - Maps to `ShiftCategory` enum
- `leader_role` (string, nullable) - Leader role type

### timesheet_entries:
- `shift_title` (string, nullable)
- `shift_type` (string, nullable)
- `clock_out_platform` (string, nullable)
- `scheduled_start` (Timestamp, nullable)
- `scheduled_end` (Timestamp, nullable)
- `scheduled_duration_minutes` (number, nullable)
- `employee_notes` (string, nullable)
- `manager_notes` (string, nullable)

### tasks:
- `isArchived` (boolean, default: false)
- `archivedAt` (Timestamp, nullable)
- `startDate` (Timestamp, nullable)

**Action Required:** Verify these field names match what's in your Flutter models.

---

## 🔄 Step 5: Optional - Backfill Existing Data

### Backfill shift_title for timesheet_entries

**When to do this:**
- If you want historical timesheet exports to show shift titles
- If you have existing timesheet entries linked to shifts

**How to do it:**

1. **Via Firebase Console Cloud Shell:**

```javascript
// Copy and paste this into Firebase Console > Cloud Shell

const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

async function backfillShiftTitles() {
  console.log('Starting backfill...');
  
  const entriesSnapshot = await db.collection('timesheet_entries')
    .where('shift_id', '!=', null)
    .get();
  
  console.log(`Found ${entriesSnapshot.size} entries with shift_id`);
  
  let batch = db.batch();
  let count = 0;
  let processed = 0;
  
  for (const entryDoc of entriesSnapshot.docs) {
    const entryData = entryDoc.data();
    
    // Skip if already has shift_title
    if (entryData.shift_title) {
      continue;
    }
    
    // Get shift details
    if (entryData.shift_id) {
      try {
        const shiftDoc = await db.collection('teaching_shifts')
          .doc(entryData.shift_id)
          .get();
        
        if (shiftDoc.exists) {
          const shiftData = shiftDoc.data();
          
          // Build shift title
          const shiftTitle = shiftData.auto_generated_name || 
                           shiftData.custom_name || 
                           shiftData.display_name || 
                           '';
          
          // Build shift type
          const studentNames = shiftData.student_names || [];
          const teacherName = shiftData.teacher_name || '';
          const parts = [];
          
          if (studentNames.length > 0) {
            parts.push(`Stu - ${studentNames[0]}`);
          }
          parts.push(teacherName);
          
          // Calculate duration
          if (shiftData.shift_start && shiftData.shift_end) {
            const start = shiftData.shift_start.toDate();
            const end = shiftData.shift_end.toDate();
            const durationHours = (end - start) / (1000 * 60 * 60);
            parts.push(`(${Math.round(durationHours)}hr)`);
          }
          
          const shiftType = parts.join(' - ');
          
          // Calculate duration in minutes
          let durationMinutes = null;
          if (shiftData.shift_start && shiftData.shift_end) {
            const start = shiftData.shift_start.toDate();
            const end = shiftData.shift_end.toDate();
            durationMinutes = Math.round((end - start) / (1000 * 60));
          }
          
          // Update entry
          batch.update(entryDoc.ref, {
            shift_title: shiftTitle,
            shift_type: shiftType,
            scheduled_start: shiftData.shift_start,
            scheduled_end: shiftData.shift_end,
            scheduled_duration_minutes: durationMinutes,
          });
          
          count++;
          processed++;
          
          // Commit batch every 400 operations
          if (count >= 400) {
            await batch.commit();
            batch = db.batch();
            count = 0;
            console.log(`Processed ${processed} entries...`);
          }
        }
      } catch (e) {
        console.error(`Error processing entry ${entryDoc.id}:`, e);
      }
    }
  }
  
  // Commit remaining
  if (count > 0) {
    await batch.commit();
  }
  
  console.log(`Backfill complete! Processed ${processed} entries.`);
}

// Run the backfill
backfillShiftTitles()
  .then(() => {
    console.log('✅ Backfill completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Backfill failed:', error);
    process.exit(1);
  });
```

2. **Or create a Cloud Function** (for production use):

Create a new Cloud Function file `functions/backfillShiftTitles.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.backfillShiftTitles = functions.https.onCall(async (data, context) => {
  // Only allow admins
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can run this');
  }
  
  // ... (same logic as above)
});
```

---

## ✅ Step 6: Verification

After setup, verify:

1. **Indexes are building:**
   - Go to Firebase Console → Firestore → Indexes
   - Check status is "Building" or "Enabled"

2. **New fields are being saved:**
   - Create a new shift with category "leadership"
   - Check Firestore console - should see `shift_category: "leadership"`
   - Create a new timesheet entry
   - Check Firestore console - should see new fields like `shift_title`, `scheduled_start`, etc.

3. **Archive functionality works:**
   - Archive a task
   - Check Firestore console - should see `isArchived: true` and `archivedAt: <timestamp>`

---

## 🚨 Important Notes

### Field Naming Convention

Your codebase uses **snake_case** for Firestore fields (e.g., `shift_category`, `shift_start`), but **camelCase** for Dart model properties (e.g., `shiftCategory`, `shiftStart`). The `toFirestore()` and `fromFirestore()` methods handle this conversion.

### No Breaking Changes

- ✅ All new fields are **optional** (nullable)
- ✅ Existing documents will continue to work
- ✅ Old queries will still function
- ✅ No data migration required (unless you want to backfill)

### Performance Considerations

- Indexes may take time to build (especially with large datasets)
- Queries using new indexes will fail until indexes are built
- Monitor index build status in Firebase Console

---

## 📞 Troubleshooting

### Index Build Failing

**Error:** "The query requires an index"

**Solution:**
1. Click the error link in Firebase Console to auto-create the index
2. Or manually create the index as shown in Step 2

### Fields Not Saving

**Check:**
1. Verify `toFirestore()` method includes new fields
2. Check Firestore rules allow writes
3. Check browser console for errors

### Backfill Script Errors

**Common issues:**
- Missing `shift_id` in some entries (skip these)
- Shift document deleted (skip these)
- Batch size too large (reduce to 200)

---

## 📚 Next Steps

After database setup:

1. ✅ Test creating a leader shift
2. ✅ Test clock-in/out with new fields
3. ✅ Test task archiving
4. ✅ Test timesheet export with new columns
5. ✅ Verify indexes are working

---

*This guide ensures your Firestore database is ready for all new features.*

