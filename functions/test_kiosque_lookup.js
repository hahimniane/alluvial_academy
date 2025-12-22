// Test script to debug kiosque code lookup
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

async function testKiosqueLookup() {
  const db = admin.firestore();

  console.log('🔍 Testing kiosque code lookup...\n');

  // Test with the user's code
  const testCode = 'YKPR49182773';
  console.log(`Looking for kiosque code: ${testCode}`);

  try {
    // Check kiosque_code field
    const kiosqueSnapshot = await db.collection('users')
      .where('kiosque_code', '==', testCode)
      .limit(5)
      .get();

    console.log(`Found ${kiosqueSnapshot.docs.length} users with kiosque_code = '${testCode}'`);
    kiosqueSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`  [${index + 1}] User ${doc.id}: ${data.first_name} ${data.last_name} (${data.user_type})`);
    });

    // Check student_code field
    const studentSnapshot = await db.collection('users')
      .where('student_code', '==', testCode)
      .limit(5)
      .get();

    console.log(`Found ${studentSnapshot.docs.length} users with student_code = '${testCode}'`);
    studentSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`  [${index + 1}] User ${doc.id}: ${data.first_name} ${data.last_name} (${data.user_type})`);
    });

    // Check family_code field (legacy)
    const familySnapshot = await db.collection('users')
      .where('family_code', '==', testCode)
      .limit(5)
      .get();

    console.log(`Found ${familyCodeSnapshot.docs.length} users with family_code = '${testCode}'`);
    familySnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`  [${index + 1}] User ${doc.id}: ${data.first_name} ${data.last_name} (${data.user_type})`);
    });

    // List all parents with kiosque codes
    console.log('\n📋 All parents with kiosque codes:');
    const parentsSnapshot = await db.collection('users')
      .where('user_type', '==', 'parent')
      .where('kiosque_code', '!=', null)
      .limit(10)
      .get();

    console.log(`Found ${parentsSnapshot.docs.length} parents with kiosque codes:`);
    parentsSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`  [${index + 1}] ${data.first_name} ${data.last_name}: kiosque_code = '${data.kiosque_code}'`);
    });

    if (parentsSnapshot.docs.length === 0) {
      console.log('  ⚠️ No parents found with kiosque codes. Migration may be needed.');
    }

  } catch (error) {
    console.error('❌ Error during lookup:', error);
  }
}

// Run the test
testKiosqueLookup()
  .then(() => {
    console.log('\n✅ Test completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Test failed:', error);
    process.exit(1);
  });
