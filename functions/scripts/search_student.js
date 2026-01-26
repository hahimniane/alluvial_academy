#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const searchTerm = process.argv[2] || 'ahmed';

async function searchStudent() {
  console.log(`Searching for students matching: "${searchTerm}"\n`);
  
  const studentsSnap = await db.collection('users')
    .where('user_type', '==', 'student')
    .get();
  
  const matches = [];
  
  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const code = data.student_code || data.studentId || data.student_id || '';
    const name = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    
    if (code.toLowerCase().includes(searchTerm.toLowerCase()) || 
        name.toLowerCase().includes(searchTerm.toLowerCase())) {
      matches.push({
        code: code,
        name: name,
        uid: doc.id,
      });
    }
  }
  
  if (matches.length === 0) {
    console.log('No matches found.');
  } else {
    console.log(`Found ${matches.length} matches:\n`);
    for (const m of matches) {
      console.log(`  ${m.name} (${m.code})`);
      console.log(`    UID: ${m.uid}\n`);
    }
  }
}

searchStudent()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
