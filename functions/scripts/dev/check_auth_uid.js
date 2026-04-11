const admin = require('firebase-admin');

try {
  const serviceAccount = require('../../serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (e) {
  try {
    admin.initializeApp({ projectId: 'alluwal-academy' });
  } catch (err) {
    console.log("Failed to initialize:", err.message);
    process.exit(1);
  }
}

const db = admin.firestore();

async function checkStudentAuthEmails() {
  const studentsSnapshot = await db.collection('users').where('user_type', '==', 'student').get();
  
  console.log(`Found ${studentsSnapshot.size} students`);
  
  let matchCount = 0;
  let mismatchCount = 0;
  
  for (const doc of studentsSnapshot.docs) {
    const data = doc.data();
    
    // Some students might not have an auth account yet.
    try {
      const authUser = await admin.auth().getUser(doc.id);
      matchCount++;
    } catch (e) {
      mismatchCount++;
      // Let's check if there is an auth account by email
      const studentCode = data.student_code || data.studentCode;
      if (studentCode) {
        const alias = `${studentCode.toLowerCase().trim()}@alluwaleducationhub.org`;
        try {
          const u = await admin.auth().getUserByEmail(alias);
          // console.log(`Student ${doc.id} (${data.first_name} ${data.last_name}) has Auth UID ${u.uid} (Mismatch!)`);
        } catch (e) {}
      }
    }
  }
  
  console.log(`Students with Document ID == Auth UID: ${matchCount}`);
  console.log(`Students with Document ID != Auth UID (or no auth): ${mismatchCount}`);
}

checkStudentAuthEmails();