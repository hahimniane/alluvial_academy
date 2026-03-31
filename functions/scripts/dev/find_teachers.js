const admin = require('firebase-admin');

// Initialize with project ID
admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function findTeachers() {
  // Find nenenane2@gmail.com
  const neneQuery = await db.collection('users')
    .where('e-mail', '==', 'nenenane2@gmail.com')
    .limit(1)
    .get();

  if (neneQuery.empty === false) {
    const doc = neneQuery.docs[0];
    console.log('Found nenenane2@gmail.com:');
    console.log('  UID:', doc.id);
    console.log('  Name:', doc.data().first_name, doc.data().last_name);
  } else {
    // Try alternate email field
    const neneQuery2 = await db.collection('users')
      .where('email', '==', 'nenenane2@gmail.com')
      .limit(1)
      .get();
    if (neneQuery2.empty === false) {
      const doc = neneQuery2.docs[0];
      console.log('Found nenenane2@gmail.com (email field):');
      console.log('  UID:', doc.id);
      console.log('  Name:', doc.data().first_name, doc.data().last_name);
    } else {
      console.log('nenenane2@gmail.com not found');
    }
  }

  // Find all teachers
  const teacherQuery = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();

  console.log('\nAll Teachers:');
  teacherQuery.docs.forEach(doc => {
    const data = doc.data();
    const name = ((data.first_name || '') + ' ' + (data.last_name || '')).toLowerCase();
    console.log('  UID:', doc.id);
    console.log('  Name:', data.first_name, data.last_name);
    console.log('  Email:', data['e-mail'] || data.email);
    console.log('');
  });
}

findTeachers().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
