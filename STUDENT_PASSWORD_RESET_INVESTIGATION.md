# Student Password Reset Investigation

## Problem
- Only "test.student" can log in
- Other students cannot log in even after password reset
- Students have fake/alias emails (e.g., `studentcode@alluwaleducationhub.org`)

## Root Causes Found

### 1. **Code Bug: Missing HttpsError Import**
**Issue:** The password reset function was using `functions.https.HttpsError` but `functions` was not imported. The function uses v2 `onCall` which requires `HttpsError` to be imported directly.

**Fix:** Changed all `functions.https.HttpsError` to `HttpsError` and added proper import.

### 2. **Missing Firebase Auth Accounts for Old Students**
**Issue:** Old students might have Firestore documents but no Firebase Auth accounts. When password reset tries to update a non-existent user, it fails.

**Fix:** Added logic to:
- Check if Firebase Auth user exists by UID
- If not, check if it exists by email
- If neither exists, create a new Firebase Auth account with the same UID as the Firestore document

### 3. **Email Case Consistency**
**Issue:** Email format must be consistent. Login converts student ID to lowercase before creating alias email.

**Fix:** Ensured password reset also uses lowercase for the alias email.

## How Student Login Works

1. **Student Creation:**
   - Student code generated (e.g., "test.student")
   - Alias email created: `test.student@alluwaleducationhub.org`
   - Firebase Auth account created with this email
   - Firestore document created with document ID = Firebase Auth UID
   - Password stored in both Firebase Auth and Firestore `temp_password` field

2. **Student Login:**
   - Student enters Student ID (e.g., "test.student")
   - System converts to lowercase: "test.student"
   - Adds domain: "test.student@alluwaleducationhub.org"
   - Attempts Firebase Auth login with this email and password

3. **Password Reset:**
   - Admin calls `resetStudentPassword` with `studentId` (Firestore document ID/UID)
   - Generates new random password
   - Updates Firebase Auth password (creates account if missing)
   - Updates Firestore `temp_password` field
   - Optionally emails parent

## Files Modified

1. `functions/handlers/password.js`
   - Fixed HttpsError import and usage
   - Added Firebase Auth user existence check
   - Added logic to create Firebase Auth account if missing
   - Ensured email is lowercase for consistency

## Testing Recommendations

1. **Test password reset for existing students:**
   - Reset password for a student that has a Firebase Auth account
   - Verify login works with new password

2. **Test password reset for old students (no Firebase Auth account):**
   - Reset password for an old student
   - Verify Firebase Auth account is created
   - Verify login works with new password

3. **Test login with various student IDs:**
   - Test with uppercase student ID
   - Test with mixed case student ID
   - Verify all convert correctly to lowercase alias email

## Next Steps

1. Deploy the updated Cloud Function
2. Test password reset for a few students
3. If issues persist, check Cloud Function logs for specific errors
4. Consider running `syncAllStudentPasswords` to sync all existing students

