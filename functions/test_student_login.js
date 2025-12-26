/**
 * Test script to understand how student login works
 * This will help us see how test.student is configured vs other students
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

async function testStudentLogin() {
  console.log('🔍 Testing Student Login Setup\n');

  try {
    // 1. Find test.student in Firestore
    console.log('1. Checking Firestore for test.student...');
    const testStudentQuery = await admin.firestore()
      .collection('users')
      .where('student_code', '==', 'test.student')
      .limit(1)
      .get();

    if (testStudentQuery.empty) {
      console.log('   ❌ test.student not found in Firestore');
    } else {
      const testStudentDoc = testStudentQuery.docs[0];
      const testStudentData = testStudentDoc.data();
      const testStudentUid = testStudentDoc.id;
      
      console.log(`   ✅ Found test.student in Firestore`);
      console.log(`   Document ID (UID): ${testStudentUid}`);
      console.log(`   Student Code: ${testStudentData.student_code}`);
      console.log(`   Email in Firestore: ${testStudentData['e-mail'] || 'N/A'}`);
      console.log(`   Has temp_password: ${!!testStudentData.temp_password}`);
      console.log(`   User Type: ${testStudentData.user_type}`);
      
      // 2. Check Firebase Auth
      const aliasEmail = 'test.student@alluwaleducationhub.org';
      console.log(`\n2. Checking Firebase Auth for ${aliasEmail}...`);
      
      try {
        const authUser = await admin.auth().getUserByEmail(aliasEmail.toLowerCase());
        console.log(`   ✅ Firebase Auth user exists`);
        console.log(`   Auth UID: ${authUser.uid}`);
        console.log(`   Email: ${authUser.email}`);
        console.log(`   Email Verified: ${authUser.emailVerified}`);
        console.log(`   Disabled: ${authUser.disabled}`);
        console.log(`   UID matches Firestore: ${authUser.uid === testStudentUid ? '✅ YES' : '❌ NO'}`);
        
        // Check if we can get user by UID
        try {
          const authUserByUid = await admin.auth().getUser(testStudentUid);
          console.log(`   ✅ Can also get user by UID ${testStudentUid}`);
          console.log(`   Email from UID lookup: ${authUserByUid.email}`);
        } catch (uidError) {
          console.log(`   ❌ Cannot get user by UID ${testStudentUid}: ${uidError.message}`);
        }
      } catch (authError) {
        console.log(`   ❌ Firebase Auth user NOT found: ${authError.message}`);
      }
    }

    // 3. Check a few other students
    console.log('\n3. Checking other students...');
    const allStudentsQuery = await admin.firestore()
      .collection('users')
      .where('user_type', '==', 'student')
      .limit(5)
      .get();

    console.log(`   Found ${allStudentsQuery.size} students (showing first 5)`);
    
    for (const doc of allStudentsQuery.docs) {
      const studentData = doc.data();
      const studentCode = studentData.student_code;
      const studentUid = doc.id;
      const aliasEmail = `${studentCode}@alluwaleducationhub.org`;
      
      console.log(`\n   Student: ${studentCode}`);
      console.log(`   Firestore UID: ${studentUid}`);
      console.log(`   Expected Auth Email: ${aliasEmail.toLowerCase()}`);
      console.log(`   Has temp_password: ${!!studentData.temp_password}`);
      
      try {
        const authUser = await admin.auth().getUserByEmail(aliasEmail.toLowerCase());
        console.log(`   ✅ Firebase Auth exists (UID: ${authUser.uid})`);
        if (authUser.uid !== studentUid) {
          console.log(`   ⚠️  UID mismatch! Firestore: ${studentUid}, Auth: ${authUser.uid}`);
        }
      } catch (authError) {
        console.log(`   ❌ Firebase Auth NOT found: ${authError.message}`);
        
        // Try to get by UID
        try {
          const authUserByUid = await admin.auth().getUser(studentUid);
          console.log(`   ⚠️  But user exists by UID ${studentUid} with email: ${authUserByUid.email}`);
        } catch (uidError) {
          console.log(`   ❌ No Firebase Auth account exists for this student`);
        }
      }
    }

    // 4. Summary
    console.log('\n📊 Summary:');
    console.log('   Login process:');
    console.log('   1. Student enters Student ID (e.g., "test.student")');
    console.log('   2. Convert to lowercase: "test.student"');
    console.log('   3. Add domain: "test.student@alluwaleducationhub.org"');
    console.log('   4. Call Firebase Auth signInWithEmailAndPassword(email, password)');
    console.log('\n   Requirements for login to work:');
    console.log('   ✅ Firebase Auth account must exist with the alias email');
    console.log('   ✅ Password in Firebase Auth must match what user enters');
    console.log('   ✅ Firestore document with student_code must exist');

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Run the test
testStudentLogin()
  .then(() => {
    console.log('\n✅ Test completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Test failed:', error);
    process.exit(1);
  });

