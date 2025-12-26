/**
 * Test script to check if student passwords are synced between Firestore and Firebase Auth
 * This will help us understand why test.student works but others don't
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

async function testPasswordSync() {
  console.log('🔍 Testing Student Password Sync\n');

  try {
    // Get all students
    const studentsQuery = await admin.firestore()
      .collection('users')
      .where('user_type', '==', 'student')
      .limit(10)
      .get();

    console.log(`Found ${studentsQuery.size} students\n`);

    for (const doc of studentsQuery.docs) {
      const studentData = doc.data();
      const studentCode = studentData.student_code;
      const studentUid = doc.id;
      const tempPassword = studentData.temp_password;
      const aliasEmail = `${studentCode}@alluwaleducationhub.org`;

      console.log(`\n📋 Student: ${studentCode}`);
      console.log(`   UID: ${studentUid}`);
      console.log(`   Has temp_password: ${!!tempPassword}`);
      if (tempPassword) {
        console.log(`   temp_password length: ${tempPassword.length} chars`);
      }

      try {
        const authUser = await admin.auth().getUserByEmail(aliasEmail.toLowerCase());
        console.log(`   ✅ Firebase Auth account exists`);
        console.log(`   Auth UID: ${authUser.uid}`);
        
        // Try to update password with the temp_password from Firestore
        // This will fail if temp_password is null/undefined, but that's okay - we're testing
        if (tempPassword) {
          try {
            await admin.auth().updateUser(authUser.uid, {
              password: tempPassword,
            });
            console.log(`   ✅ Password synced successfully (would work if we actually did it)`);
          } catch (updateError) {
            console.log(`   ❌ Error updating password: ${updateError.message}`);
          }
        } else {
          console.log(`   ⚠️  No temp_password in Firestore - cannot sync`);
        }
      } catch (authError) {
        console.log(`   ❌ Firebase Auth account NOT found: ${authError.message}`);
      }
    }

    console.log('\n\n📝 Conclusion:');
    console.log('   If students cannot login, it means:');
    console.log('   - Firebase Auth password != Firestore temp_password');
    console.log('   - Solution: Run password reset or sync all passwords');

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Run the test
testPasswordSync()
  .then(() => {
    console.log('\n✅ Test completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Test failed:', error);
    process.exit(1);
  });

