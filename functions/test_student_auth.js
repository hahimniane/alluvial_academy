/**
 * Test actual authentication for a student
 * This simulates the login process to verify it works
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

async function testStudentAuth(studentCode, password) {
  console.log(`🔐 Testing authentication for: ${studentCode}\n`);

  try {
    // 1. Find student in Firestore
    const studentQuery = await admin.firestore()
      .collection('users')
      .where('student_code', '==', studentCode)
      .limit(1)
      .get();

    if (studentQuery.empty) {
      console.log(`❌ Student not found`);
      return false;
    }

    const studentDoc = studentQuery.docs[0];
    const studentData = studentDoc.data();
    const studentUid = studentDoc.id;
    const aliasEmail = `${studentCode.toLowerCase()}@alluwaleducationhub.org`;

    console.log(`✅ Student found:`);
    console.log(`   UID: ${studentUid}`);
    console.log(`   Student Code: ${studentData.student_code}`);
    console.log(`   Alias Email: ${aliasEmail}`);

    // 2. Check Firebase Auth
    console.log(`\n2. Checking Firebase Auth...`);
    let authUser = null;
    try {
      authUser = await admin.auth().getUserByEmail(aliasEmail);
      console.log(`✅ Firebase Auth user found`);
      console.log(`   Auth UID: ${authUser.uid}`);
      console.log(`   Auth Email: ${authUser.email}`);
      console.log(`   Disabled: ${authUser.disabled}`);
      console.log(`   Email Verified: ${authUser.emailVerified}`);
    } catch (authError) {
      console.log(`❌ Firebase Auth user NOT found: ${authError.message}`);
      return false;
    }

    // 3. Check Firestore password
    console.log(`\n3. Checking Firestore password...`);
    const firestorePassword = studentData.temp_password;
    if (!firestorePassword) {
      console.log(`❌ No temp_password in Firestore`);
      return false;
    }
    console.log(`✅ Firestore has temp_password (${firestorePassword.length} chars)`);
    console.log(`   Password matches provided: ${firestorePassword === password ? '✅ YES' : '❌ NO'}`);

    // 4. Verify email format matches what login uses
    console.log(`\n4. Verifying email format...`);
    const loginEmail = `${studentCode.toLowerCase()}@alluwaleducationhub.org`;
    console.log(`   Login will use: ${loginEmail}`);
    console.log(`   Auth user email: ${authUser.email}`);
    console.log(`   Emails match: ${loginEmail === authUser.email ? '✅ YES' : '❌ NO'}`);

    // 5. Check if we can verify the password (we can't directly, but we can check if account is ready)
    console.log(`\n5. Account readiness check...`);
    if (authUser.disabled) {
      console.log(`❌ Account is DISABLED - this will prevent login`);
      return false;
    }
    console.log(`✅ Account is enabled`);

    // 6. Summary
    console.log(`\n📋 AUTHENTICATION SUMMARY:`);
    console.log(`   Student ID: ${studentCode}`);
    console.log(`   Login Email: ${loginEmail}`);
    console.log(`   Password: ${password}`);
    console.log(`   Firebase Auth: ✅ EXISTS`);
    console.log(`   Firestore Password: ✅ EXISTS`);
    console.log(`   Account Status: ${authUser.disabled ? '❌ DISABLED' : '✅ ENABLED'}`);
    console.log(`   UID Match: ${authUser.uid === studentUid ? '✅ YES' : '❌ NO'}`);

    // 7. Test different email variations
    console.log(`\n6. Testing email variations (case sensitivity)...`);
    const variations = [
      studentCode.toLowerCase(),
      studentCode.toUpperCase(),
      studentCode,
    ];
    
    for (const variation of variations) {
      const testEmail = `${variation}@alluwaleducationhub.org`;
      try {
        const testUser = await admin.auth().getUserByEmail(testEmail);
        console.log(`   ${testEmail}: ✅ Found (UID: ${testUser.uid})`);
      } catch (e) {
        console.log(`   ${testEmail}: ❌ Not found`);
      }
    }

    return true;

  } catch (error) {
    console.error(`❌ Error:`, error);
    return false;
  }
}

// Get parameters
const studentCode = process.argv[2] || '1famata.momo';
const password = process.argv[3] || 'j&V^H1*Huc!$';

console.log(`Testing authentication for: ${studentCode}`);
console.log(`Using password: ${password}\n`);

testStudentAuth(studentCode, password)
  .then((success) => {
    if (success) {
      console.log(`\n✅ Authentication setup looks correct`);
      console.log(`\n💡 If login still fails, check:`);
      console.log(`   1. Student is entering the password exactly as shown (case-sensitive)`);
      console.log(`   2. Student is using "Student ID" mode, not "Email" mode`);
      console.log(`   3. No extra spaces in Student ID or password`);
      console.log(`   4. Browser/app is not caching old credentials`);
    } else {
      console.log(`\n❌ Authentication setup has issues`);
    }
    process.exit(success ? 0 : 1);
  })
  .catch((error) => {
    console.error(`\n❌ Test failed:`, error);
    process.exit(1);
  });

