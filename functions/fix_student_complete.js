/**
 * Complete fix for student - ensures password works and adds debug info
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

// Generate password with only safe characters (no shell-special chars)
function generateSafePassword() {
  const length = 12;
  // Use only alphanumeric and a few safe special chars that won't cause shell issues
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$';
  let password = '';
  // Ensure mix of character types
  password += 'ABCDEFGHJKLMNPQRSTUVWXYZ'[Math.floor(Math.random() * 23)];
  password += 'abcdefghjkmnpqrstuvwxyz'[Math.floor(Math.random() * 23)];
  password += '23456789'[Math.floor(Math.random() * 8)];
  password += '!@#$'[Math.floor(Math.random() * 4)];
  // Fill rest
  for (let i = 4; i < length; i++) {
    password += chars[Math.floor(Math.random() * chars.length)];
  }
  // Shuffle
  return password.split('').sort(() => Math.random() - 0.5).join('');
}

async function fixStudentComplete(studentCode) {
  console.log(`\n🔧 COMPLETE FIX for student: ${studentCode}`);
  console.log(`========================================\n`);

  try {
    // 1. Find student
    const studentQuery = await admin.firestore()
      .collection('users')
      .where('student_code', '==', studentCode)
      .limit(1)
      .get();

    if (studentQuery.empty) {
      console.log(`❌ Student ${studentCode} not found in Firestore`);
      return null;
    }

    const studentDoc = studentQuery.docs[0];
    const studentData = studentDoc.data();
    const studentUid = studentDoc.id;
    const aliasEmail = `${studentCode.toLowerCase()}@alluwaleducationhub.org`;

    console.log(`✅ Student Found:`);
    console.log(`   Name: ${studentData.first_name} ${studentData.last_name}`);
    console.log(`   Student Code: ${studentData.student_code}`);
    console.log(`   Firestore UID: ${studentUid}`);
    console.log(`   Alias Email: ${aliasEmail}`);

    // 2. Generate safe password
    const newPassword = generateSafePassword();
    console.log(`\n🔑 Generated Password: ${newPassword}`);
    console.log(`   (Safe characters only - no shell-special chars)`);

    // 3. Get Firebase Auth user
    let authUser = null;
    try {
      authUser = await admin.auth().getUserByEmail(aliasEmail);
      console.log(`\n✅ Firebase Auth user exists`);
      console.log(`   Auth UID: ${authUser.uid}`);
      console.log(`   Current email: ${authUser.email}`);
      console.log(`   Disabled: ${authUser.disabled}`);
    } catch (e) {
      console.log(`\n⚠️  Firebase Auth user not found - will create`);
    }

    // 4. Update/Create Firebase Auth
    if (authUser) {
      await admin.auth().updateUser(authUser.uid, {
        password: newPassword,
        disabled: false,
      });
      console.log(`✅ Updated Firebase Auth password`);
    } else {
      try {
        const userRecord = await admin.auth().createUser({
          uid: studentUid,
          email: aliasEmail,
          password: newPassword,
          displayName: `${studentData.first_name || ''} ${studentData.last_name || ''}`.trim(),
          emailVerified: false,
          disabled: false,
        });
        console.log(`✅ Created Firebase Auth user`);
      } catch (createError) {
        if (createError.code === 'auth/email-already-exists') {
          const userByEmail = await admin.auth().getUserByEmail(aliasEmail);
          await admin.auth().updateUser(userByEmail.uid, {
            password: newPassword,
            disabled: false,
          });
          console.log(`✅ Found by email, updated password`);
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
    console.log(`\n🔍 Final Verification:`);
    const finalAuth = await admin.auth().getUserByEmail(aliasEmail);
    const finalDoc = await admin.firestore().collection('users').doc(studentUid).get();
    const finalData = finalDoc.data();

    const allGood = 
      !finalAuth.disabled &&
      finalData.temp_password === newPassword &&
      finalAuth.uid === studentUid;

    console.log(`   Firebase Auth exists: ✅`);
    console.log(`   Account enabled: ${finalAuth.disabled ? '❌ NO' : '✅ YES'}`);
    console.log(`   Passwords match: ${finalData.temp_password === newPassword ? '✅ YES' : '❌ NO'}`);
    console.log(`   UIDs match: ${finalAuth.uid === studentUid ? '✅ YES' : '❌ NO'}`);

    if (!allGood) {
      console.log(`\n⚠️  Some issues found - fixing...`);
      if (finalAuth.disabled) {
        await admin.auth().updateUser(finalAuth.uid, { disabled: false });
        console.log(`   ✅ Enabled account`);
      }
      if (finalData.temp_password !== newPassword) {
        await admin.firestore().collection('users').doc(studentUid).update({
          temp_password: newPassword,
        });
        console.log(`   ✅ Synced Firestore password`);
      }
    }

    // 7. Display credentials
    console.log(`\n\n🎯 =========================================`);
    console.log(`   LOGIN CREDENTIALS`);
    console.log(`   =========================================`);
    console.log(`   Student ID: ${studentCode}`);
    console.log(`   Password: ${newPassword}`);
    console.log(`   =========================================`);
    console.log(`\n📝 STEP-BY-STEP LOGIN INSTRUCTIONS:`);
    console.log(`   1. Open the app/login screen`);
    console.log(`   2. Look for two tabs at the top: "Email" and "Student ID"`);
    console.log(`   3. Click on the "Student ID" tab (IMPORTANT!)`);
    console.log(`   4. In the "Student ID" field, enter: ${studentCode}`);
    console.log(`   5. In the "Password" field, enter: ${newPassword}`);
    console.log(`   6. Click "Sign In" button`);
    console.log(`\n⚠️  CRITICAL: Make sure "Student ID" tab is selected!`);
    console.log(`   If "Email" tab is selected, login will fail.`);

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

fixStudentComplete(studentCode)
  .then((result) => {
    if (result && result.success) {
      console.log(`\n✅ COMPLETE! Student ${result.studentCode} is ready to login.`);
      console.log(`\n🔑 Password: ${result.password}`);
    }
    process.exit(0);
  })
  .catch((error) => {
    console.error(`\n❌ FAILED:`, error);
    process.exit(1);
  });

