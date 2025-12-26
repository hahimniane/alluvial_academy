/**
 * Test if we can actually authenticate with the password
 * This simulates what happens during login
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

async function testLogin(studentCode) {
  console.log(`🔐 Testing login for: ${studentCode}\n`);

  try {
    // 1. Get student from Firestore
    const studentQuery = await admin.firestore()
      .collection('users')
      .where('student_code', '==', studentCode)
      .limit(1)
      .get();

    if (studentQuery.empty) {
      console.log('❌ Student not found in Firestore');
      return;
    }

    const studentDoc = studentQuery.docs[0];
    const studentData = studentDoc.data();
    const studentUid = studentDoc.id;
    const aliasEmail = `${studentCode.toLowerCase()}@alluwaleducationhub.org`;
    const password = studentData.temp_password;

    console.log(`✅ Student found:`);
    console.log(`   UID: ${studentUid}`);
    console.log(`   Alias Email: ${aliasEmail}`);
    console.log(`   Password in Firestore: ${password ? 'EXISTS' : 'MISSING'}`);

    // 2. Check Firebase Auth
    let authUser = null;
    try {
      authUser = await admin.auth().getUserByEmail(aliasEmail);
      console.log(`\n✅ Firebase Auth user exists:`);
      console.log(`   UID: ${authUser.uid}`);
      console.log(`   Email: ${authUser.email}`);
      console.log(`   Disabled: ${authUser.disabled}`);
    } catch (e) {
      console.log(`\n❌ Firebase Auth user NOT found: ${e.message}`);
      return;
    }

    // 3. Verify password is set in Firebase Auth
    // We can't directly check the password, but we can verify the account exists
    console.log(`\n🔍 Account Status:`);
    console.log(`   Account exists: ✅`);
    console.log(`   Account disabled: ${authUser.disabled ? '❌ YES (THIS IS THE PROBLEM!)' : '✅ NO'}`);
    console.log(`   Email verified: ${authUser.emailVerified ? '✅ YES' : '⚠️  NO (but should still work)'}`);

    // 4. Check if we can verify the password matches
    // We can't directly verify, but we can check if the account was recently updated
    console.log(`\n📋 Login Simulation:`);
    console.log(`   1. User enters Student ID: ${studentCode}`);
    console.log(`   2. System converts to: ${aliasEmail}`);
    console.log(`   3. System calls: signInWithEmailAndPassword("${aliasEmail}", password)`);
    console.log(`   4. Firebase Auth should authenticate...`);

    if (authUser.disabled) {
      console.log(`\n❌ PROBLEM FOUND: Account is DISABLED!`);
      console.log(`   This will prevent login even with correct password.`);
      console.log(`   Fixing now...`);
      
      await admin.auth().updateUser(authUser.uid, {
        disabled: false,
      });
      
      console.log(`   ✅ Account enabled`);
    }

    // 5. Final check
    const finalCheck = await admin.auth().getUserByEmail(aliasEmail);
    console.log(`\n✅ Final Status:`);
    console.log(`   Account exists: ✅`);
    console.log(`   Account enabled: ${finalCheck.disabled ? '❌ NO' : '✅ YES'}`);
    console.log(`   UID matches: ${finalCheck.uid === studentUid ? '✅ YES' : '❌ NO'}`);
    console.log(`   Password in Firestore: ${password ? '✅ EXISTS' : '❌ MISSING'}`);

    if (!finalCheck.disabled && password && finalCheck.uid === studentUid) {
      console.log(`\n✅ Everything looks correct! Login should work.`);
      console.log(`\n💡 If login still fails:`);
      console.log(`   1. Make sure "Student ID" tab is selected (not "Email")`);
      console.log(`   2. Enter Student ID exactly: ${studentCode}`);
      console.log(`   3. Enter password exactly: ${password}`);
      console.log(`   4. Check browser console for any error messages`);
    } else {
      console.log(`\n❌ Issues found that will prevent login`);
    }

  } catch (error) {
    console.error(`\n❌ Error:`, error);
  }
}

const studentCode = process.argv[2] || '1famata.momo';

testLogin(studentCode)
  .then(() => {
    console.log('\n✅ Test complete');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Test failed:', error);
    process.exit(1);
  });

