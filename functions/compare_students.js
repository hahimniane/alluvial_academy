/**
 * Compare test.student with 1famata.momo to find the difference
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

async function compareStudents() {
  console.log('🔍 Comparing test.student vs 1famata.momo\n');

  const students = ['test.student', '1famata.momo'];

  for (const studentCode of students) {
    console.log(`\n${'='.repeat(60)}`);
    console.log(`Student: ${studentCode}`);
    console.log('='.repeat(60));

    try {
      // 1. Firestore
      const studentQuery = await admin.firestore()
        .collection('users')
        .where('student_code', '==', studentCode)
        .limit(1)
        .get();

      if (studentQuery.empty) {
        console.log('❌ NOT FOUND IN FIRESTORE');
        continue;
      }

      const studentDoc = studentQuery.docs[0];
      const studentData = studentDoc.data();
      const firestoreUid = studentDoc.id;
      const aliasEmail = `${studentCode.toLowerCase()}@alluwaleducationhub.org`;

      console.log(`✅ Firestore:`);
      console.log(`   Document ID (UID): ${firestoreUid}`);
      console.log(`   Student Code: ${studentData.student_code}`);
      console.log(`   Email field: ${studentData['e-mail'] || 'MISSING'}`);
      console.log(`   User Type: ${studentData.user_type}`);
      console.log(`   Has temp_password: ${!!studentData.temp_password}`);
      console.log(`   temp_password length: ${studentData.temp_password?.length || 0}`);

      // 2. Firebase Auth - by email
      console.log(`\n🔐 Firebase Auth (by email: ${aliasEmail}):`);
      try {
        const authUserByEmail = await admin.auth().getUserByEmail(aliasEmail);
        console.log(`   ✅ EXISTS`);
        console.log(`   UID: ${authUserByEmail.uid}`);
        console.log(`   Email: ${authUserByEmail.email}`);
        console.log(`   Disabled: ${authUserByEmail.disabled}`);
        console.log(`   Email Verified: ${authUserByEmail.emailVerified}`);
        console.log(`   UID matches Firestore: ${authUserByEmail.uid === firestoreUid ? '✅ YES' : '❌ NO'}`);
      } catch (e) {
        console.log(`   ❌ NOT FOUND: ${e.message}`);
      }

      // 3. Firebase Auth - by UID
      console.log(`\n🔐 Firebase Auth (by UID: ${firestoreUid}):`);
      try {
        const authUserByUid = await admin.auth().getUser(firestoreUid);
        console.log(`   ✅ EXISTS`);
        console.log(`   UID: ${authUserByUid.uid}`);
        console.log(`   Email: ${authUserByUid.email}`);
        console.log(`   Disabled: ${authUserByUid.disabled}`);
        console.log(`   Email matches expected: ${authUserByUid.email === aliasEmail ? '✅ YES' : '❌ NO'}`);
      } catch (e) {
        console.log(`   ❌ NOT FOUND: ${e.message}`);
      }

      // 4. Check all Firebase Auth users with similar emails
      console.log(`\n🔍 Searching Firebase Auth for similar emails...`);
      // Can't list all users, but we can try variations
      const variations = [
        aliasEmail,
        aliasEmail.toUpperCase(),
        `${studentCode}@alluwaleducationhub.org`,
      ];
      for (const variant of variations) {
        try {
          const user = await admin.auth().getUserByEmail(variant);
          console.log(`   ✅ Found: ${variant} (UID: ${user.uid})`);
        } catch (e) {
          // Not found, that's okay
        }
      }

    } catch (error) {
      console.error(`❌ Error checking ${studentCode}:`, error);
    }
  }

  console.log(`\n\n📊 SUMMARY:`);
  console.log(`If test.student works but 1famata.momo doesn't:`);
  console.log(`1. Check if Firebase Auth account exists`);
  console.log(`2. Check if UIDs match between Firestore and Firebase Auth`);
  console.log(`3. Check if email format matches exactly`);
}

compareStudents()
  .then(() => {
    console.log('\n✅ Comparison complete');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Error:', error);
    process.exit(1);
  });

