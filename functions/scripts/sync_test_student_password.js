#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const STUDENT_UID = 'EJD4pKhaEBSlQEBLPug3ffSEudy1';
const NEW_PASSWORD = '000000';

async function sync() {
  console.log('Syncing test.student password to Firestore...\n');
  
  await db.collection('users').doc(STUDENT_UID).update({
    temp_password: NEW_PASSWORD,
    password_changed_at: admin.firestore.FieldValue.serverTimestamp(),
    password_changed_by_self: true,
  });
  
  console.log('✅ Updated Firestore with new password');
  
  // Verify
  const doc = await db.collection('users').doc(STUDENT_UID).get();
  console.log(`\nVerified temp_password: ${doc.data().temp_password}`);
}

sync()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
