#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function check() {
  console.log('='.repeat(80));
  console.log('Checking test.student document...\n');
  
  // Find by student_code
  const usersSnap = await db.collection('users')
    .where('student_code', '==', 'test.student')
    .limit(1)
    .get();
  
  if (usersSnap.empty) {
    console.log('test.student not found!');
    return;
  }
  
  const doc = usersSnap.docs[0];
  const data = doc.data();
  
  console.log(`Document ID: ${doc.id}`);
  console.log('\nAll fields:');
  
  for (const [key, value] of Object.entries(data)) {
    if (value && typeof value === 'object' && value.toDate) {
      console.log(`  ${key}: ${value.toDate().toISOString()}`);
    } else if (typeof value === 'object') {
      console.log(`  ${key}: ${JSON.stringify(value)}`);
    } else {
      console.log(`  ${key}: ${value}`);
    }
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('KEY FIELDS FOR PASSWORD CHECK:');
  console.log(`  user_type: "${data.user_type}"`);
  console.log(`  role: "${data.role}"`);
  console.log(`  temp_password: "${data.temp_password}"`);
  console.log(`  password_changed_at: ${data.password_changed_at}`);
  console.log(`  password_changed_by_self: ${data.password_changed_by_self}`);
}

check()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
