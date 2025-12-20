# Task Database Changes Summary

## Overview
This document outlines the database changes needed for the new ConnectTeam-style task features.

## New Fields Added to Tasks Collection

The following fields have been added to the `tasks` collection:

1. **`isDraft`** (boolean)
   - Default: `false`
   - Purpose: Indicates if a task is saved as a draft
   - Backward compatible: Existing tasks default to `false`

2. **`publishedAt`** (Timestamp, nullable)
   - Purpose: Records when a task was published
   - Backward compatible: Existing tasks will have `null` for this field

3. **`location`** (String, nullable)
   - Purpose: Optional location field for tasks
   - Backward compatible: Existing tasks will have `null` for this field

4. **`startTime`** (String, nullable)
   - Format: `HH:mm` (e.g., "09:30", "14:00")
   - Purpose: Start time for the task
   - Backward compatible: Existing tasks will have `null` for this field

5. **`endTime`** (String, nullable)
   - Format: `HH:mm` (e.g., "10:30", "15:00")
   - Purpose: End time for the task
   - Backward compatible: Existing tasks will have `null` for this field

## Security Rules

**No changes required.** The existing security rules already allow:
- Admins to write (create/update/delete) all tasks
- Users to read tasks assigned to them
- The new fields are automatically allowed under these rules

## Firestore Indexes

### Required Indexes
**None required immediately.** The current implementation filters tasks client-side, so no new indexes are needed for basic functionality.

### Optional Performance Index (Recommended)
An index has been added to `firestore.indexes.json` for better performance when querying drafts:

```json
{
  "collectionGroup": "tasks",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "isDraft", "order": "ASCENDING"},
    {"fieldPath": "createdBy", "order": "ASCENDING"},
    {"fieldPath": "isArchived", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
}
```

**To deploy this index:**
1. Run: `firebase deploy --only firestore:indexes`
2. Or wait for Firestore to auto-create it when you first query with these fields

## Migration Notes

### Automatic Handling
- The Task model (`lib/features/tasks/models/task.dart`) handles missing fields automatically:
  - `isDraft` defaults to `false` if not present
  - All other new fields are nullable and default to `null`
- Existing tasks will continue to work without any migration

### No Backfill Required
- Old tasks don't need to be updated
- New tasks will automatically include the new fields
- The UI filters out drafts from main views by default

## Testing Checklist

- [x] New tasks can be created with draft status
- [x] New tasks can be published
- [x] Draft tasks appear in the "Drafts" tab
- [x] Published tasks appear in other tabs
- [x] Location field saves and displays correctly
- [x] Start/end times save and display correctly
- [x] Existing tasks continue to work without errors
- [x] Bulk operations work with new fields

## Deployment Steps

1. **Deploy Firestore Indexes (Optional but Recommended)**
   ```bash
   firebase deploy --only firestore:indexes
   ```

2. **Deploy Security Rules (No changes needed, but verify)**
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Deploy Application Code**
   - All code changes are already in place
   - No additional deployment steps needed

## Notes

- The index is optional and only improves performance for draft queries
- If you don't deploy the index, Firestore will auto-create it when first needed (with a warning)
- All new fields are optional/nullable, ensuring backward compatibility
- The application will work correctly even if the index hasn't been deployed yet

