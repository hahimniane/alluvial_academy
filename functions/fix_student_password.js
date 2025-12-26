/**
 * Fix password for a specific student and verify it works
 */

const admin = require('firebase-admin');
const { generateRandomPassword } = require('./utils/password');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

async function fixStudentPassword(studentCode) {
  console.log(`🔧 Fixing password for student: ${studentCode}\n`);

  try {
    // 1. Find student in Firestore
    console.log('1. Finding student in Firestore...');
    const studentQuery = await admin.firestore()
      .collection('users')
      .where('student_code', '==', studentCode)
      .limit(1)
      .get();

    if (studentQuery.empty) {
      console.log(`❌ Student ${studentCode} not found in Firestore`);
      return;
    }

    const studentDoc = studentQuery.docs[0];
    const studentData = studentDoc.data();
    const studentUid = studentDoc.id;
    const aliasEmail = `${studentCode.toLowerCase()}@alluwaleducationhub.org`;

    console.log(`✅ Found student in Firestore`);
    console.log(`   UID: ${studentUid}`);
    console.log(`   Alias Email: ${aliasEmail}`);
    console.log(`   Current temp_password: ${studentData.temp_password ? 'EXISTS' : 'MISSING'}`);

    // 2. Generate new password
    const newPassword = generateRandomPassword();
    console.log(`\n2. Generated new password: ${newPassword}`);

    // 3. Check Firebase Auth
    console.log(`\n3. Checking Firebase Auth...`);
    let authUser = null;
    let authUserExists = false;

    try {
      authUser = await admin.auth().getUserByEmail(aliasEmail);
      authUserExists = true;
      console.log(`✅ Firebase Auth user exists (UID: ${authUser.uid})`);
      if (authUser.uid !== studentUid) {
        console.log(`⚠️  UID mismatch! Firestore: ${studentUid}, Auth: ${authUser.uid}`);
      }
    } catch (authError) {
      if (authError.code === 'auth/user-not-found') {
        console.log(`❌ Firebase Auth user NOT found, will create it`);
        authUserExists = false;
      } else {
        throw authError;
      }
    }

    // 4. Update or create Firebase Auth user
    console.log(`\n4. Updating Firebase Auth...`);
    if (authUserExists) {
      try {
        await admin.auth().updateUser(authUser.uid, {
          password: newPassword,
        });
        console.log(`✅ Updated Firebase Auth password for UID ${authUser.uid}`);
      } catch (updateError) {
        console.log(`❌ Error updating password: ${updateError.message}`);
        throw updateError;
      }
    } else {
      try {
        const userRecord = await admin.auth().createUser({
          uid: studentUid, // Use Firestore document ID as UID
          email: aliasEmail,
          password: newPassword,
          displayName: `${studentData.first_name || ''} ${studentData.last_name || ''}`.trim(),
          emailVerified: false,
        });
        console.log(`✅ Created Firebase Auth user with UID ${userRecord.uid}`);
      } catch (createError) {
        if (createError.code === 'auth/email-already-exists') {
          // Try to get by email and update
          try {
            const userByEmail = await admin.auth().getUserByEmail(aliasEmail);
            await admin.auth().updateUser(userByEmail.uid, {
              password: newPassword,
            });
            console.log(`✅ Found user by email, updated password for UID ${userByEmail.uid}`);
          } catch (emailError) {
            throw new Error(`Failed to create or update: ${createError.message}`);
          }
        } else if (createError.code === 'auth/uid-already-exists') {
          // UID exists, try to update
          try {
            await admin.auth().updateUser(studentUid, {
              password: newPassword,
            });
            console.log(`✅ UID exists, updated password`);
          } catch (uidError) {
            throw new Error(`Failed to update existing UID: ${uidError.message}`);
          }
        } else {
          throw createError;
        }
      }
    }

    // 5. Update Firestore
    console.log(`\n5. Updating Firestore...`);
    await admin.firestore()
      .collection('users')
      .doc(studentUid)
      .update({
        temp_password: newPassword,
        password_reset_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    console.log(`✅ Updated Firestore temp_password`);

    // 6. Verify the update
    console.log(`\n6. Verifying update...`);
    const updatedDoc = await admin.firestore()
      .collection('users')
      .doc(studentUid)
      .get();
    const updatedData = updatedDoc.data();
    
    const verifyAuth = await admin.auth().getUserByEmail(aliasEmail);
    
    console.log(`✅ Verification:`);
    console.log(`   Firestore temp_password: ${updatedData.temp_password === newPassword ? '✅ MATCHES' : '❌ MISMATCH'}`);
    console.log(`   Firebase Auth user exists: ✅`);
    console.log(`   Auth UID: ${verifyAuth.uid}`);

    // 7. Summary
    console.log(`\n📋 LOGIN CREDENTIALS FOR ${studentCode.toUpperCase()}:`);
    console.log(`   Student ID: ${studentCode}`);
    console.log(`   Email (for login): ${aliasEmail}`);
    console.log(`   Password: ${newPassword}`);
    console.log(`\n✅ Password reset complete! Student should now be able to login.`);

    return {
      success: true,
      studentCode,
      email: aliasEmail,
      password: newPassword,
      uid: studentUid,
    };

  } catch (error) {
    console.error(`\n❌ Error fixing password:`, error);
    throw error;
  }
}

// Get student code from command line or use default
const studentCode = process.argv[2] || '1famata.momo';

// Run the fix
fixStudentPassword(studentCode)
  .then((result) => {
    if (result) {
      console.log(`\n✅ Success! Student ${result.studentCode} can now login with:`);
      console.log(`   Student ID: ${result.studentCode}`);
      console.log(`   Password: ${result.password}`);
    }
    process.exit(0);
  })
  .catch((error) => {
    console.error(`\n❌ Failed:`, error);
    process.exit(1);
  });

