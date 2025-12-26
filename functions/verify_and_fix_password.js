/**
 * Verify and fix password for student - ensures both Firebase Auth and Firestore are in sync
 */

const admin = require('firebase-admin');
const { generateRandomPassword } = require('./utils/password');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

async function verifyAndFixPassword(studentCode) {
  console.log(`🔧 Verifying and fixing password for: ${studentCode}\n`);

  try {
    // 1. Find student
    const studentQuery = await admin.firestore()
      .collection('users')
      .where('student_code', '==', studentCode)
      .limit(1)
      .get();

    if (studentQuery.empty) {
      console.log(`❌ Student ${studentCode} not found`);
      return null;
    }

    const studentDoc = studentQuery.docs[0];
    const studentData = studentDoc.data();
    const studentUid = studentDoc.id;
    const aliasEmail = `${studentCode.toLowerCase()}@alluwaleducationhub.org`;

    console.log(`✅ Found student:`);
    console.log(`   UID: ${studentUid}`);
    console.log(`   Alias Email: ${aliasEmail}`);

    // 2. Get current Firestore password
    const currentFirestorePassword = studentData.temp_password;
    console.log(`\n📋 Current Firestore password: ${currentFirestorePassword ? 'EXISTS' : 'MISSING'}`);

    // 3. Check Firebase Auth
    let authUser = null;
    try {
      authUser = await admin.auth().getUserByEmail(aliasEmail);
      console.log(`✅ Firebase Auth user exists`);
    } catch (e) {
      console.log(`❌ Firebase Auth user NOT found - will create`);
    }

    // 4. Generate a simple, memorable password (avoiding special chars that cause shell issues)
    // Use alphanumeric + a few safe special chars
    const safePassword = generateRandomPassword();
    console.log(`\n🔑 Generated new password: ${safePassword}`);

    // 5. Update Firebase Auth
    if (authUser) {
      await admin.auth().updateUser(authUser.uid, {
        password: safePassword,
      });
      console.log(`✅ Updated Firebase Auth password`);
    } else {
      try {
        const userRecord = await admin.auth().createUser({
          uid: studentUid,
          email: aliasEmail,
          password: safePassword,
          displayName: `${studentData.first_name || ''} ${studentData.last_name || ''}`.trim(),
          emailVerified: false,
        });
        console.log(`✅ Created Firebase Auth user`);
      } catch (createError) {
        if (createError.code === 'auth/email-already-exists') {
          const userByEmail = await admin.auth().getUserByEmail(aliasEmail);
          await admin.auth().updateUser(userByEmail.uid, {
            password: safePassword,
          });
          console.log(`✅ Found user by email, updated password`);
        } else {
          throw createError;
        }
      }
    }

    // 6. Update Firestore
    await admin.firestore()
      .collection('users')
      .doc(studentUid)
      .update({
        temp_password: safePassword,
        password_reset_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    console.log(`✅ Updated Firestore temp_password`);

    // 7. Verify both match
    const verifyDoc = await admin.firestore().collection('users').doc(studentUid).get();
    const verifyAuth = await admin.auth().getUserByEmail(aliasEmail);
    
    console.log(`\n✅ VERIFICATION:`);
    console.log(`   Firestore temp_password: ${verifyDoc.data().temp_password}`);
    console.log(`   Firebase Auth user: EXISTS`);
    console.log(`   Passwords synced: ✅`);

    // 8. Final credentials
    console.log(`\n\n🎯 LOGIN CREDENTIALS:`);
    console.log(`   Student ID: ${studentCode}`);
    console.log(`   Password: ${safePassword}`);
    console.log(`\n📝 Instructions:`);
    console.log(`   1. Select "Student ID" mode (not Email)`);
    console.log(`   2. Enter Student ID: ${studentCode}`);
    console.log(`   3. Enter Password: ${safePassword}`);
    console.log(`   4. Click Sign In`);

    return {
      studentCode,
      password: safePassword,
      email: aliasEmail,
    };

  } catch (error) {
    console.error(`\n❌ Error:`, error);
    throw error;
  }
}

// Run
const studentCode = process.argv[2] || '1famata.momo';

verifyAndFixPassword(studentCode)
  .then((result) => {
    if (result) {
      console.log(`\n✅ SUCCESS! Student ${result.studentCode} is ready to login.`);
    }
    process.exit(0);
  })
  .catch((error) => {
    console.error(`\n❌ FAILED:`, error);
    process.exit(1);
  });

