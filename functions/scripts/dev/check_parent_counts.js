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

async function checkParents() {
  const studentsSnapshot = await db.collection('users').where('user_type', '==', 'student').get();
  
  const parentMap = {};
  
  studentsSnapshot.forEach(doc => {
    const data = doc.data();
    const gIds = [];
    if (Array.isArray(data.guardian_ids)) gIds.push(...data.guardian_ids);
    if (Array.isArray(data.guardianIds)) gIds.push(...data.guardianIds);
    
    // Deduplicate
    const uniqueGIds = [...new Set(gIds)];
    
    uniqueGIds.forEach(gid => {
      if (!parentMap[gid]) parentMap[gid] = [];
      parentMap[gid].push({ id: doc.id, name: `${data.first_name} ${data.last_name}` });
    });
  });

  const parentsToCheck = [
    { name: 'Nene Diallo', email: 'noumoukadija@yahoo.com' },
    { name: 'Fatoumata Barry', email: 'fbarry719@gmail.com' },
    { name: 'Abraham Bah', email: 'abrahambah08@gmail.com' }
  ];

  for (const p of parentsToCheck) {
    const parentSnap = await db.collection('users')
      .where('user_type', '==', 'parent')
      .where('e-mail', '==', p.email)
      .get();
      
    if (parentSnap.empty) {
      console.log(`Parent not found: ${p.name}`);
      continue;
    }
    
    const pDoc = parentSnap.docs[0];
    const children = parentMap[pDoc.id] || [];
    console.log(`\nParent: ${p.name} (ID: ${pDoc.id})`);
    console.log(`Actual children count in DB: ${children.length}`);
    children.forEach((c, i) => console.log(`  ${i+1}. ${c.name} (${c.id})`));
  }
}

checkParents();