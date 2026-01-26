#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function listAllTeachers() {
  console.log('Listing all teachers...\n');
  console.log('='.repeat(80));
  
  const usersSnap = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();
  
  const teachers = [];
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    
    teachers.push({
      uid: doc.id,
      fullName: fullName,
      email: data['e-mail'] || data.email,
    });
  }
  
  // Sort by name
  teachers.sort((a, b) => a.fullName.localeCompare(b.fullName));
  
  console.log(`Total teachers: ${teachers.length}\n`);
  
  for (const teacher of teachers) {
    console.log(`${teacher.fullName.padEnd(40)} | ${teacher.email || 'No email'}`);
  }
  
  // Search for names that might match "Souleymane"
  console.log('\n' + '='.repeat(80));
  console.log('Searching for similar names to "Souleymane":\n');
  
  const similar = teachers.filter(t => {
    const name = t.fullName.toLowerCase();
    return name.includes('soul') || name.includes('diallo') && name.includes('s');
  });
  
  if (similar.length > 0) {
    console.log('Possible matches:');
    for (const teacher of similar) {
      console.log(`  - ${teacher.fullName} (${teacher.email})`);
    }
  } else {
    console.log('No similar names found.');
  }
}

listAllTeachers()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
