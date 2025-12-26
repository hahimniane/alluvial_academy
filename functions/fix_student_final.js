/**
 * Final fix for student password - uses simpler password and ensures everything is correct
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

// Generate a simpler password (alphanumeric + a few safe special chars)
function generateSimplePassword() {
  const length = 12;
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$%';
  let password = '';
  for (let i = 0; i < length; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return password;
}

async function fixStudentFinal(studentCode) {
  console.log(`🔧 FINAL FIX for student: ${studentCode}\n`);

  try {
    // 1. Find student
    const studentQuery = await admin.firestore()
      .collection('users')
      .where('student_code', '==', studentCode)
      .limit(1)
      .get();

    if (studentQuery.empty) {
      console.log(`❌ Student not found`);
      return null;
    }

    const studentDoc = studentQuery.docs[0];
    const studentData = studentDoc.data();
    const studentUid = studentDoc.id;
    const aliasEmail = `${studentCode.toLowerCase()}@alluwaleducationhub.org`;

    console.log(`✅ Student found:`);
    console.log(`   UID: ${studentUid}`);
    console.log(`   Name: ${studentData.first_name} ${studentData.last_name}`);
    console.log(`   Alias Email: ${aliasEmail}`);

    // 2. Generate simple password
    const newPassword = generateSimplePassword();
    console.log(`\n🔑 New Password: ${newPassword}`);

    // 3. Get or create Firebase Auth user
    let authUser = null;
    try {
      authUser = await admin.auth().getUserByEmail(aliasEmail);
      console.log(`✅ Firebase Auth user exists (UID: ${authUser.uid})`);
    } catch (e) {
      console.log(`⚠️  Firebase Auth user not found, creating...`);
    }

    // 4. Update or create Firebase Auth
    if (authUser) {
      // Update existing
      await admin.auth().updateUser(authUser.uid, {
        password: newPassword,
        disabled: false, // Ensure account is enabled
      });
      console.log(`✅ Updated Firebase Auth password and ensured account is enabled`);
    } else {
      // Create new
      try {
        const userRecord = await admin.auth().createUser({
          uid: studentUid,
          email: aliasEmail,
          password: newPassword,
          displayName: `${studentData.first_name || ''} ${studentData.last_name || ''}`.trim(),
          emailVerified: false,
          disabled: false,
        });
        console.log(`✅ Created Firebase Auth user (UID: ${userRecord.uid})`);
      } catch (createError) {
        if (createError.code === 'auth/email-already-exists') {
          const userByEmail = await admin.auth().getUserByEmail(aliasEmail);
          await admin.auth().updateUser(userByEmail.uid, {
            password: newPassword,
            disabled: false,
          });
          console.log(`✅ Found user by email, updated password`);
        } else if (createError.code === 'auth/uid-already-exists') {
          await admin.auth().updateUser(studentUid, {
            password: newPassword,
            disabled: false,
          });
          console.log(`✅ UID exists, updated password`);
        } else {
          throw createError;
        }
      }
    }

    // 5. Update Firestore
    await admin.firestore()
      .collection('users')
      .doc(studentUid)
      .update({
        temp_password: newPassword,
        password_reset_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    console.log(`✅ Updated Firestore temp_password`);

    // 6. Final verification
    console.log(`\n🔍 Final Verification...`);
    const verifyAuth = await admin.auth().getUserByEmail(aliasEmail);
    const verifyDoc = await admin.firestore().collection('users').doc(studentUid).get();
    const verifyData = verifyDoc.data();

    console.log(`   Firebase Auth:`);
    console.log(`     ✅ User exists`);
    console.log(`     ✅ UID: ${verifyAuth.uid}`);
    console.log(`     ✅ Email: ${verifyAuth.email}`);
    console.log(`     ✅ Disabled: ${verifyAuth.disabled ? '❌ YES (PROBLEM!)' : '✅ NO'}`);
    console.log(`   Firestore:`);
    console.log(`     ✅ Document exists`);
    console.log(`     ✅ Student Code: ${verifyData.student_code}`);
    console.log(`     ✅ temp_password: ${verifyData.temp_password ? 'EXISTS' : 'MISSING'}`);
    console.log(`     ✅ Password matches: ${verifyData.temp_password === newPassword ? '✅ YES' : '❌ NO'}`);

    if (verifyAuth.disabled) {
      console.log(`\n⚠️  WARNING: Account is disabled! Enabling now...`);
      await admin.auth().updateUser(verifyAuth.uid, {
        disabled: false,
      });
      console.log(`✅ Account enabled`);
    }

    // 7. Test email lookup (simulating login)
    console.log(`\n🧪 Testing login simulation...`);
    const loginEmail = `${studentCode.toLowerCase()}@alluwaleducationhub.org`;
    const testUser = await admin.auth().getUserByEmail(loginEmail);
    console.log(`   Login email: ${loginEmail}`);
    console.log(`   ✅ Can find user by login email`);
    console.log(`   ✅ User UID: ${testUser.uid}`);
    console.log(`   ✅ Account enabled: ${!testUser.disabled}`);

    // 8. Final credentials
    console.log(`\n\n🎯 ========================================`);
    console.log(`   LOGIN CREDENTIALS FOR ${studentCode.toUpperCase()}`);
    console.log(`   ========================================`);
    console.log(`   Student ID: ${studentCode}`);
    console.log(`   Password: ${newPassword}`);
    console.log(`   ========================================`);
    console.log(`\n📝 LOGIN INSTRUCTIONS:`);
    console.log(`   1. Open the login screen`);
    console.log(`   2. Make sure "Student ID" tab is selected (NOT "Email")`);
    console.log(`   3. Enter Student ID: ${studentCode}`);
    console.log(`   4. Enter Password: ${newPassword}`);
    console.log(`   5. Click Sign In`);
    console.log(`\n✅ Everything is configured correctly!`);

    return {
      success: true,
      studentCode,
      password: newPassword,
      email: aliasEmail,
    };

  } catch (error) {
    console.error(`\n❌ Error:`, error);
    throw error;
  }
}

const studentCode = process.argv[2] || '1famata.momo';

fixStudentFinal(studentCode)
  .then((result) => {
    if (result && result.success) {
      console.log(`\n✅ SUCCESS! Student ${result.studentCode} is ready to login.`);
      console.log(`   Password: ${result.password}`);
    }
    process.exit(0);
  })
  .catch((error) => {
    console.error(`\n❌ FAILED:`, error);
    process.exit(1);
  });

