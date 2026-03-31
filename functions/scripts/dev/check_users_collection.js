#!/usr/bin/env node
'use strict';

/**
 * Debug script to check what's in the users collection
 */

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function checkUsers() {
  console.log('Checking users collection...\n');
  
  // Get first 10 users to see structure
  const usersSnap = await db.collection('users').limit(10).get();
  
  console.log(`Found ${usersSnap.docs.length} users (limit 10)\n`);
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    console.log('User ID:', doc.id);
    console.log('Fields:', Object.keys(data).join(', '));
    console.log('Role:', data.role);
    console.log('Name:', data.displayName || data.name || data.firstName);
    console.log('Email:', data.email);
    console.log('---');
  }
  
  // Count by role
  console.log('\n\nCounting by role...');
  const allUsers = await db.collection('users').get();
  
  const roleCounts = {};
  for (const doc of allUsers.docs) {
    const role = doc.data().role || 'no role';
    roleCounts[role] = (roleCounts[role] || 0) + 1;
  }
  
  console.log('Role distribution:');
  for (const [role, count] of Object.entries(roleCounts)) {
    console.log(`  ${role}: ${count}`);
  }
  
  // Check teaching_shifts collection
  console.log('\n\nChecking teaching_shifts collection...');
  const shiftsSnap = await db.collection('teaching_shifts').limit(5).get();
  console.log(`Found ${shiftsSnap.docs.length} shifts (limit 5)`);
  
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    console.log('\nShift ID:', doc.id);
    console.log('Teacher:', data.teacherName, '(', data.teacherId, ')');
    console.log('Students:', data.studentNames?.join(', ') || 'none');
    console.log('Start:', data.shiftStart?.toDate());
  }
}

checkUsers()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
