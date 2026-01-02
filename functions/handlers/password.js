const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { generateRandomPassword } = require('../utils/password');
const { sendStudentNotificationEmail } = require('../services/email/senders');

/**
 * Reset a student's password
 * - Uses provided custom password (optional) or generates a new random password
 * - Updates Firebase Auth
 * - Updates Firestore temp_password
 * - Optionally emails parent
 */
exports.resetStudentPassword = onCall(async (request) => {
  // Check authentication
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Must be authenticated to reset passwords'
    );
  }

  const {
    studentId,
    sendEmailToParent = true,
    customPassword,
    newPassword: newPasswordOverride,
  } = request.data || {};

  if (!studentId) {
    throw new HttpsError(
      'invalid-argument',
      'studentId is required'
    );
  }

  try {
    // Check if caller is admin
    const callerDoc = await admin.firestore()
      .collection('users')
      .doc(request.auth.uid)
      .get();

    if (!callerDoc.exists) {
      throw new HttpsError(
        'permission-denied',
        'User not found'
      );
    }

    const callerData = callerDoc.data();
    const isAdmin = callerData.user_type === 'admin' || callerData.is_admin_teacher === true;

    if (!isAdmin) {
      throw new HttpsError(
        'permission-denied',
        'Only admins can reset passwords'
      );
    }

    // Get student document
    const studentDoc = await admin.firestore()
      .collection('users')
      .doc(studentId)
      .get();

    if (!studentDoc.exists) {
      throw new HttpsError(
        'not-found',
        'Student not found'
      );
    }

    const studentData = studentDoc.data();

    if (studentData.user_type !== 'student') {
      throw new HttpsError(
        'failed-precondition',
        'Can only reset passwords for students'
      );
    }

    const providedPassword = typeof customPassword === 'string'
      ? customPassword
      : (typeof newPasswordOverride === 'string' ? newPasswordOverride : '');

    let newPassword;
    if (providedPassword.trim().length > 0) {
      if (providedPassword !== providedPassword.trim()) {
        throw new HttpsError(
          'invalid-argument',
          'Password cannot start or end with spaces'
        );
      }
      if (providedPassword.length < 6) {
        throw new HttpsError(
          'invalid-argument',
          'Password must be at least 6 characters'
        );
      }
      if (providedPassword.length > 128) {
        throw new HttpsError(
          'invalid-argument',
          'Password must be 128 characters or less'
        );
      }
      newPassword = providedPassword;
    } else {
      // Generate new password
      newPassword = generateRandomPassword();
    }

    // Get the alias email for this student (must match login format - lowercase)
    const studentCode = studentData.student_code;
    const aliasEmail = `${studentCode.toLowerCase()}@alluwaleducationhub.org`;
    
    console.log(`Resetting password for student ${studentCode} (UID: ${studentId}, Email: ${aliasEmail})`);

    // Check if Firebase Auth user exists, create if it doesn't
    let authUserExists = false;
    try {
      await admin.auth().getUser(studentId);
      authUserExists = true;
      console.log(`Firebase Auth user exists for UID ${studentId}`);
    } catch (authError) {
      if (authError.code === 'auth/user-not-found') {
        console.log(`Firebase Auth user not found for UID ${studentId}, creating new user...`);
        authUserExists = false;
      } else {
        console.error(`Error checking Firebase Auth user: ${authError}`);
        throw new HttpsError('internal', `Failed to check Firebase Auth user: ${authError.message}`);
      }
    }

    // Create or update Firebase Auth user
    if (!authUserExists) {
      // Create new Firebase Auth user
      try {
        const userRecord = await admin.auth().createUser({
          uid: studentId, // Use the Firestore document ID as the UID
          email: aliasEmail.toLowerCase(),
          password: newPassword,
          displayName: `${studentData.first_name || ''} ${studentData.last_name || ''}`.trim(),
          emailVerified: false,
        });
        console.log(`✅ Created Firebase Auth user for student ${studentCode} with UID ${userRecord.uid}`);
      } catch (createError) {
        console.error(`Error creating Firebase Auth user with UID ${studentId}:`, createError);
        
        // If email already exists, try to get user by email and update password
        if (createError.code === 'auth/email-already-exists' || createError.message?.includes('email')) {
          try {
            const userByEmail = await admin.auth().getUserByEmail(aliasEmail.toLowerCase());
            console.log(`Found existing Firebase Auth user by email with UID ${userByEmail.uid} (different from Firestore UID ${studentId})`);
            // Update the existing user's password
            await admin.auth().updateUser(userByEmail.uid, {
              password: newPassword,
            });
            console.log(`Updated password for existing Firebase Auth user ${userByEmail.uid}`);
            // Note: UID mismatch between Firestore and Firebase Auth exists, but password reset will still work
          } catch (emailError) {
            console.error(`Error getting user by email: ${emailError}`);
            throw new HttpsError('internal', `Failed to create or find Firebase Auth user: ${createError.message}`);
          }
        } else if (createError.code === 'auth/uid-already-exists') {
          // UID exists but getUser failed earlier - try update instead
          console.log(`UID ${studentId} already exists in Firebase Auth, updating password...`);
          try {
            await admin.auth().updateUser(studentId, {
              password: newPassword,
            });
            console.log(`Updated password for existing Firebase Auth user ${studentId}`);
          } catch (updateError) {
            throw new HttpsError('internal', `Failed to update Firebase Auth password: ${updateError.message}`);
          }
        } else {
          throw new HttpsError('internal', `Failed to create Firebase Auth user: ${createError.message}`);
        }
      }
    } else {
      // Update existing Firebase Auth user password
      try {
        await admin.auth().updateUser(studentId, {
          password: newPassword,
        });
        console.log(`Updated password for Firebase Auth user ${studentId}`);
      } catch (updateError) {
        console.error(`Error updating Firebase Auth password: ${updateError}`);
        throw new HttpsError('internal', `Failed to update Firebase Auth password: ${updateError.message}`);
      }
    }

    // Update Firestore
    await admin.firestore()
      .collection('users')
      .doc(studentId)
      .update({
        temp_password: newPassword,
        password_reset_at: admin.firestore.FieldValue.serverTimestamp(),
        password_reset_by: request.auth.uid,
      });

    console.log(`Password reset completed for student ${studentData.student_code} by ${request.auth.uid}`);

    // Optionally email parent
    let emailSent = false;
    if (sendEmailToParent && studentData.guardian_ids && studentData.guardian_ids.length > 0) {
      try {
        for (const guardianId of studentData.guardian_ids) {
          const guardianDoc = await admin.firestore()
            .collection('users')
            .doc(guardianId)
            .get();

          if (guardianDoc.exists) {
            const guardianData = guardianDoc.data();
            const guardianEmail = guardianData['e-mail'] || guardianData.email;
            const guardianName = `${guardianData.first_name || ''} ${guardianData.last_name || ''}`.trim();

            if (guardianEmail) {
              const studentEmailData = {
                firstName: studentData.first_name,
                lastName: studentData.last_name,
                studentCode: studentData.student_code,
                email: `${studentData.student_code}@alluwaleducationhub.org`,
                isAdultStudent: studentData.is_adult_student,
              };

              const credentials = {
                email: `${studentData.student_code}@alluwaleducationhub.org`,
                tempPassword: newPassword,
              };

              await sendStudentNotificationEmail(
                guardianEmail,
                guardianName,
                studentEmailData,
                credentials
              );
              emailSent = true;
              console.log(`Password reset email sent to ${guardianEmail}`);
            }
          }
        }
      } catch (emailError) {
        console.error('Error sending email:', emailError);
        // Don't fail the whole operation if email fails
      }
    }

    return {
      success: true,
      message: 'Password reset successfully',
      newPassword,
      studentCode: studentData.student_code,
      emailSent,
    };

  } catch (error) {
    console.error('Error resetting password:', error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError(
      'internal',
      error.message || 'Failed to reset password'
    );
  }
});

/**
 * Sync all student passwords from Firestore to Firebase Auth
 * Use this to fix any password mismatches
 */
exports.syncAllStudentPasswords = onCall(async (request) => {
  // Check authentication
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Must be authenticated'
    );
  }

  // Check if caller is admin
  const callerDoc = await admin.firestore()
    .collection('users')
    .doc(request.auth.uid)
    .get();

  if (!callerDoc.exists || callerDoc.data().user_type !== 'admin') {
    throw new HttpsError(
      'permission-denied',
      'Only admins can sync passwords'
    );
  }

  const dryRun = request.data?.dryRun ?? true;

  try {
    const studentsSnapshot = await admin.firestore()
      .collection('users')
      .where('user_type', '==', 'student')
      .get();

    let synced = 0;
    let skipped = 0;
    let errors = [];

    for (const doc of studentsSnapshot.docs) {
      const data = doc.data();

      if (!data.student_code || !data.temp_password) {
        skipped++;
        continue;
      }

      try {
        if (!dryRun) {
          await admin.auth().updateUser(doc.id, {
            password: data.temp_password,
          });
        }
        synced++;
      } catch (e) {
        errors.push({
          studentCode: data.student_code,
          error: e.message,
        });
      }
    }

    return {
      success: true,
      message: dryRun ? 'DRY RUN - No changes made' : 'Passwords synced',
      totalStudents: studentsSnapshot.size,
      synced,
      skipped,
      errorCount: errors.length,
      errors: errors.slice(0, 10),
    };

  } catch (error) {
    console.error('Error syncing passwords:', error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError(
      'internal',
      error.message || 'Failed to sync passwords'
    );
  }
});
