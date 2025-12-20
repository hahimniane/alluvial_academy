# Form Submissions Security

## Overview
This document explains the security measures implemented to ensure teachers can **only view their own form submissions** and cannot access other users' responses.

## Security Layers

### 1. Client-Side Filtering (Application Layer)
**Location**: `lib/features/forms/screens/my_submissions_screen.dart`

The application filters form responses at the query level:

```dart
final snapshot = await FirebaseFirestore.instance
    .collection('form_responses')
    .where('userId', isEqualTo: user.uid)  // ✅ Only fetches current user's submissions
    .orderBy('submittedAt', descending: true)
    .get();
```

**What this does:**
- Queries Firestore with a filter that matches only the logged-in user's ID
- Never fetches other users' submissions to the client
- Efficient - only loads data the user is authorized to see

### 2. Server-Side Security Rules (Database Layer)
**Location**: `firestore.rules`

Firestore Security Rules enforce access control at the database level:

```javascript
match /form_responses/{responseId} {
  allow read: if isSignedIn() && 
                 (isOwner(resource.data.userId) || isAdmin());
  allow create: if isSignedIn() && 
                   request.resource.data.userId == request.auth.uid;
  allow update, delete: if isAdmin();
}
```

**What this does:**
- **Read**: Users can only read submissions where `userId` matches their authentication ID, OR they are an admin
- **Create**: Users can only create submissions with their own `userId`
- **Update/Delete**: Only admins can modify or delete submissions

### 3. Helper Functions in Security Rules

```javascript
// Check if user is authenticated
function isSignedIn() {
  return request.auth != null;
}

// Check if user owns the document
function isOwner(userId) {
  return isSignedIn() && request.auth.uid == userId;
}

// Check if user is an admin
// NOTE: This reads from the users collection, so it cannot be used 
// in the users collection rule itself (would create circular dependency)
function isAdmin() {
  return isSignedIn() && 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
```

**Important**: The `users` collection rule **does NOT use** the `isAdmin()` helper to avoid circular dependency. Instead, it explicitly checks the role in the rule itself.

## Security Guarantees

### ✅ Teachers Can:
1. View **only their own** form submissions
2. See the list of forms they've submitted
3. Read all responses they provided in each form
4. Search/filter through their own submissions

### ❌ Teachers Cannot:
1. View other teachers' form submissions
2. View students' or parents' form submissions
3. Edit or delete any submissions (read-only)
4. Modify the `userId` when creating a submission
5. Access form responses through direct Firestore queries

### ✅ Admins Can:
1. View **all** form submissions from all users
2. Edit or delete any submission
3. Access the "Form Responses" screen (separate admin feature)
4. Export all form data

## Data Structure Requirements

For the security rules to work correctly, each document in `form_responses` collection **must** have:

```javascript
{
  userId: "abc123...",        // ✅ REQUIRED: Firebase Auth UID of the submitter
  formId: "form_xyz",         // Form template ID
  formTitle: "Weekly Report", // Display name
  submittedAt: Timestamp,     // When it was submitted
  responses: {                // The actual form data
    "Question 1": "Answer 1",
    "Question 2": "Answer 2"
  },
  status: "completed",        // Submission status
  // ... other fields
}
```

**Critical**: The `userId` field is the security anchor that ties each submission to its owner.

## Testing Security Rules

### Test 1: Teacher viewing their own submissions ✅
```dart
// User A (teacher) is logged in
// Query: form_responses where userId == A
// Expected: Success - returns only User A's submissions
```

### Test 2: Teacher attempting to view other submissions ❌
```dart
// User A (teacher) is logged in
// Attempt: Directly access form_responses/documentBelongingToUserB
// Expected: Permission denied error
```

### Test 3: Admin viewing all submissions ✅
```dart
// Admin is logged in
// Query: form_responses (no userId filter)
// Expected: Success - returns all submissions
```

### Test 4: Unauthenticated access ❌
```dart
// No user logged in
// Attempt: Access any form_responses
// Expected: Permission denied error
```

## Deployment

The security rules have been deployed to Firebase:

```bash
firebase deploy --only firestore:rules
```

**Status**: ✅ Successfully deployed

**Verification**: Security rules are now active and enforced for all Firestore operations.

## Best Practices Followed

1. **Principle of Least Privilege**: Users can only access their own data by default
2. **Defense in Depth**: Security enforced at both application and database layers
3. **Read-Only Access**: Teachers cannot modify historical submissions
4. **Admin Override**: Admins have full access for management purposes
5. **Authentication Required**: All operations require a logged-in user
6. **Field-Level Validation**: userId must match authenticated user on creation

## Additional Security Measures

### Other Collections Protected

The security rules also protect:
- **Users**: Can only read their own profile (admins can read all)
- **Teaching Shifts**: Teachers can only see their assigned shifts
- **Timesheet Entries**: Teachers can only read/write their own entries
- **Tasks**: Users can only see tasks assigned to them
- **Notifications**: Users can only see their own notifications

### Public Collections
These remain publicly readable (but admin-only writable):
- `landing_page_content`
- `website_content`

### Shared Collections
These allow authenticated users to interact:
- `chat_messages` and `chat_rooms` (all authenticated users)

## Monitoring and Auditing

**Recommended**: Enable Firestore audit logging in Google Cloud Console to track:
- Who accesses form submissions
- Failed permission attempts
- Unusual access patterns

**How to enable**:
1. Go to Google Cloud Console
2. Navigate to IAM & Admin > Audit Logs
3. Enable "Data Read" and "Data Write" for Cloud Firestore

## Troubleshooting

### Issue: "Permission denied" when accessing own submissions
**Cause**: The `userId` field in the document doesn't match the authenticated user's UID
**Solution**: Verify that submissions are created with the correct `userId` value

### Issue: Admins cannot see all submissions
**Cause**: The user's role in `/users/{uid}` is not set to "admin"
**Solution**: Update the user document: `{ role: "admin" }`

### Issue: Query fails with "Missing index" error
**Cause**: Firestore needs a composite index for the query
**Solution**: Click the error link to auto-create the index, or run:
```bash
firebase deploy --only firestore:indexes
```

## Security Checklist

- [x] Client-side query filters by userId
- [x] Firestore rules prevent unauthorized reads
- [x] Firestore rules prevent unauthorized writes
- [x] Teachers can only create submissions with their own userId
- [x] Teachers cannot edit submissions (read-only)
- [x] Admins have full access
- [x] Unauthenticated users blocked
- [x] Security rules deployed to production
- [x] Other sensitive collections also protected

## Related Files

- `lib/features/forms/screens/my_submissions_screen.dart` - Client-side implementation
- `firestore.rules` - Server-side security rules
- `lib/features/forms/screens/form_responses_screen.dart` - Admin view (all submissions)
- `MY_SUBMISSIONS_FEATURE.md` - Feature documentation

## Notes

- Security rules are evaluated on **every** Firestore operation
- Rules are cached by Firebase SDKs for up to 5 minutes
- Changes to rules take effect immediately after deployment
- These rules work for both web and mobile platforms
- The same security rules protect both REST API and SDK access


