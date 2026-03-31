#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });

async function check() {
  console.log('Checking Firebase Auth for test.student...\n');
  
  const email = 'test.student@alluwaleducationhub.org';
  
  try {
    const user = await admin.auth().getUserByEmail(email);
    console.log('Firebase Auth User:');
    console.log(`  UID: ${user.uid}`);
    console.log(`  Email: ${user.email}`);
    console.log(`  Disabled: ${user.disabled}`);
    console.log(`  Last Sign In: ${user.metadata?.lastSignInTime || 'Never'}`);
    console.log(`  Password Updated: ${user.metadata?.lastRefreshTime || 'Unknown'}`);
    
    // Try to update password to test if current password is 000000
    // We'll set it to what we think it should be and see
    console.log('\nNote: Firebase Auth does not expose the actual password.');
    console.log('The student must have changed it in Firebase Auth, but');
    console.log('the Firestore update requires a hot restart of the debug app.');
    
  } catch (e) {
    console.error('Error:', e.message);
  }
}

check()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
