#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function search() {
  console.log('='.repeat(80));
  console.log('Searching for mariame.bah in ALL users...\n');
  
  const usersSnap = await db.collection('users').get();
  
  console.log(`Total users: ${usersSnap.size}\n`);
  
  console.log('Users matching "mariame" or "bah":');
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const firstName = (data.first_name || data.firstName || '').toLowerCase();
    const lastName = (data.last_name || data.lastName || '').toLowerCase();
    const code = (data.student_code || data.studentCode || '').toLowerCase();
    const email = (data.email || data['e-mail'] || '').toLowerCase();
    
    if (firstName.includes('mariame') || lastName.includes('bah') || 
        code.includes('mariame') || code.includes('bah') ||
        email.includes('mariame') || email.includes('bah')) {
      console.log(`  Name: ${data.first_name || data.firstName} ${data.last_name || data.lastName}`);
      console.log(`  Code: ${data.student_code || data.studentCode}`);
      console.log(`  Email: ${data.email || data['e-mail']}`);
      console.log(`  Type: ${data.user_type || data.role}`);
      console.log(`  ID: ${doc.id}`);
      console.log('');
    }
  }
  
  // Also search by email pattern
  console.log('='.repeat(80));
  console.log('Users with email containing "mariame.bah":\n');
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const email = (data.email || data['e-mail'] || '').toLowerCase();
    const code = (data.student_code || data.studentCode || '').toLowerCase();
    
    if (email.includes('mariame.bah') || code === 'mariame.bah') {
      console.log(`  FOUND: ${data.first_name || data.firstName} ${data.last_name || data.lastName}`);
      console.log(`  Code: ${data.student_code || data.studentCode}`);
      console.log(`  Email: ${data.email || data['e-mail']}`);
      console.log(`  ID: ${doc.id}`);
    }
  }
}

search()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
