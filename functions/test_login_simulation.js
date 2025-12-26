/**
 * Simulate the exact login process to find any issues
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

async function simulateLogin(studentCode, password) {
  console.log(`🔐 Simulating login for: ${studentCode}\n`);

  // Step 1: Convert Student ID to email (exactly as login screen does)
  const normalized = studentCode.toLowerCase();
  const aliasEmail = `${normalized}@alluwaleducationhub.org`;
  
  console.log(`1. Student enters Student ID: "${studentCode}"`);
  console.log(`2. System converts to lowercase: "${normalized}"`);
  console.log(`3. System adds domain: "${aliasEmail}"`);
  console.log(`4. System calls: signInWithEmailAndPassword("${aliasEmail}", password)\n`);

  // Check if this email exists in Firebase Auth
  try {
    const authUser = await admin.auth().getUserByEmail(aliasEmail);
    console.log(`✅ Firebase Auth user found:`);
    console.log(`   UID: ${authUser.uid}`);
    console.log(`   Email: ${authUser.email}`);
    console.log(`   Disabled: ${authUser.disabled}`);
    
    if (authUser.disabled) {
      console.log(`\n❌ PROBLEM FOUND: Account is DISABLED!`);
      console.log(`   This will prevent login even with correct password.`);
      return false;
    }

    // Check Firestore
    const studentQuery = await admin.firestore()
      .collection('users')
      .where('student_code', '==', studentCode)
      .limit(1)
      .get();

    if (studentQuery.empty) {
      console.log(`❌ PROBLEM FOUND: Student not found in Firestore`);
      return false;
    }

    const studentDoc = studentQuery.docs[0];
    const studentData = studentDoc.data();
    const firestorePassword = studentData.temp_password;

    console.log(`\n✅ Firestore student found:`);
    console.log(`   UID: ${studentDoc.id}`);
    console.log(`   Student Code: ${studentData.student_code}`);
    console.log(`   Has temp_password: ${!!firestorePassword}`);
    
    if (authUser.uid !== studentDoc.id) {
      console.log(`\n⚠️  WARNING: UID mismatch!`);
      console.log(`   Firestore UID: ${studentDoc.id}`);
      console.log(`   Auth UID: ${authUser.uid}`);
      console.log(`   This might cause data access issues.`);
    }

    // Test different email case variations
    console.log(`\n5. Testing email case variations...`);
    const testEmails = [
      `${studentCode.toLowerCase()}@alluwaleducationhub.org`,
      `${studentCode.toUpperCase()}@alluwaleducationhub.org`,
      `${studentCode}@alluwaleducationhub.org`,
    ];

    for (const testEmail of testEmails) {
      try {
        const testUser = await admin.auth().getUserByEmail(testEmail);
        console.log(`   "${testEmail}": ✅ Found (UID: ${testUser.uid})`);
      } catch (e) {
        console.log(`   "${testEmail}": ❌ Not found`);
      }
    }

    console.log(`\n✅ Login simulation complete`);
    console.log(`\n📋 SUMMARY:`);
    console.log(`   Student ID: ${studentCode}`);
    console.log(`   Login Email: ${aliasEmail}`);
    console.log(`   Password: ${password}`);
    console.log(`   Firebase Auth: ✅ EXISTS`);
    console.log(`   Account Status: ${authUser.disabled ? '❌ DISABLED' : '✅ ENABLED'}`);
    console.log(`   Firestore: ✅ EXISTS`);
    
    if (!authUser.disabled && firestorePassword) {
      console.log(`\n✅ Everything looks correct! Login should work.`);
      console.log(`\n💡 If login still fails, possible causes:`);
      console.log(`   1. Password entered incorrectly (check for typos, spaces)`);
      console.log(`   2. Using "Email" mode instead of "Student ID" mode`);
      console.log(`   3. Browser/app caching old credentials`);
      console.log(`   4. Network/Firebase connection issues`);
      return true;
    } else {
      console.log(`\n❌ Issues found that will prevent login`);
      return false;
    }

  } catch (error) {
    console.log(`\n❌ ERROR: ${error.message}`);
    if (error.code === 'auth/user-not-found') {
      console.log(`   Firebase Auth user does not exist with email: ${aliasEmail}`);
      console.log(`   This means login will fail with "user-not-found" error`);
    }
    return false;
  }
}

const studentCode = process.argv[2] || '1famata.momo';
const password = process.argv[3] || 'C^$vrFV!O%H0';

simulateLogin(studentCode, password)
  .then((success) => {
    process.exit(success ? 0 : 1);
  })
  .catch((error) => {
    console.error(`\n❌ Failed:`, error);
    process.exit(1);
  });

