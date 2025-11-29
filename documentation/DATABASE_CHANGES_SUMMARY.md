# Database Changes Summary
## Quick Reference for Database Setup

**Status:** ✅ Ready to Deploy  
**Date:** Based on DATABASE_MODIFICATIONS_REQUIRED.md

---

## ✅ What's Already Done

1. **Firestore Indexes Added** - `firestore.indexes.json` has been updated with 3 new indexes:
   - Teaching shifts by category
   - Tasks by archive status
   - Tasks by creator and archive status

2. **Security Rules** - No changes needed! Your existing rules already allow the new fields.

3. **Documentation Created** - `DATABASE_SETUP_GUIDE.md` with step-by-step instructions

---

## 🚀 What You Need to Do

### Step 1: Deploy Indexes (REQUIRED)

**Option A: Via Firebase Console (Easiest)**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project → **Firestore Database** → **Indexes**
3. You should see 3 new indexes listed (they may already be building)
4. Wait for them to finish building (can take a few minutes)

**Option B: Via Firebase CLI**
```bash
firebase deploy --only firestore:indexes
```

**⚠️ Important:** Queries using these indexes will fail until indexes are built!

---

### Step 2: Verify Field Names Match

The Flutter code writes these fields to Firestore. Verify they match your models:

| Collection | Field Name | Type | Notes |
|------------|------------|------|-------|
| `teaching_shifts` | `shift_category` | string | Values: 'teaching', 'leadership', 'meeting', 'training' |
| `teaching_shifts` | `leader_role` | string (nullable) | Values: 'admin', 'coordination', 'meeting', 'training', 'planning', 'outreach' |
| `timesheet_entries` | `shift_title` | string (nullable) | Cached shift display name |
| `timesheet_entries` | `shift_type` | string (nullable) | Formatted type string |
| `timesheet_entries` | `clock_out_platform` | string (nullable) | 'web', 'android', 'ios', etc. |
| `timesheet_entries` | `scheduled_start` | Timestamp (nullable) | Original scheduled start |
| `timesheet_entries` | `scheduled_end` | Timestamp (nullable) | Original scheduled end |
| `timesheet_entries` | `scheduled_duration_minutes` | number (nullable) | Duration in minutes |
| `timesheet_entries` | `employee_notes` | string (nullable) | Notes from teacher |
| `timesheet_entries` | `manager_notes` | string (nullable) | Notes from admin |
| `tasks` | `isArchived` | boolean | Default: false |
| `tasks` | `archivedAt` | Timestamp (nullable) | When archived |
| `tasks` | `startDate` | Timestamp (nullable) | Start date for display |

---

### Step 3: Optional - Backfill Historical Data

**When:** Only if you want existing timesheet entries to show shift titles in exports

**How:** See `DATABASE_SETUP_GUIDE.md` Step 5 for the backfill script

**Note:** This is optional. New entries will automatically have all fields populated.

---

## 📊 Index Details

### Index 1: Teaching Shifts by Category
```
Collection: teaching_shifts
Fields: shift_category (ASC), shift_start (ASC)
Purpose: Filter shifts by category (teaching/leadership/meeting/training)
```

### Index 2: Tasks by Archive Status
```
Collection: tasks
Fields: isArchived (ASC), createdAt (DESC)
Purpose: Filter tasks for "Archived" tab
```

### Index 3: Tasks by Creator and Archive
```
Collection: tasks
Fields: createdBy (ASC), isArchived (ASC), createdAt (DESC)
Purpose: Filter "Tasks Created By Me" tab efficiently
```

---

## 🔒 Security Rules Status

**✅ No Changes Needed**

Your existing rules already allow:
- Admins to read/write all documents
- Teachers to read/write their own timesheet entries
- Users to read tasks assigned to them

The new fields follow the same access patterns, so they're automatically allowed.

---

## ✅ Verification Checklist

After deploying indexes, test:

- [ ] Create a leader shift → Check Firestore has `shift_category: "leadership"`
- [ ] Clock in to a shift → Check timesheet entry has `shift_title` and `scheduled_start`
- [ ] Clock out → Check timesheet entry has `clock_out_platform`
- [ ] Archive a task → Check task has `isArchived: true` and `archivedAt` timestamp
- [ ] Filter shifts by category → Should work (requires index)
- [ ] View "Archived" tab → Should work (requires index)

---

## 🚨 Common Issues

### "The query requires an index"
**Solution:** Click the error link in Firebase Console to auto-create, or wait for indexes to finish building.

### Fields not saving
**Check:**
1. Verify `toFirestore()` method includes new fields
2. Check browser console for errors
3. Verify user has write permissions

### Index build taking too long
**Normal:** Indexes can take 5-30 minutes depending on data size. Check status in Firebase Console.

---

## 📞 Next Steps

1. **Deploy indexes** (Step 1 above)
2. **Test new features** (Verification checklist)
3. **Optional backfill** (if needed for historical data)
4. **Monitor** index build status in Firebase Console

---

*All database changes are backward-compatible. Existing data will continue to work.*

