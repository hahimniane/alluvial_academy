#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const TEMPLATE_ID = 'tpl_27c00dc8e6b6f766';

async function checkShifts() {
  // Get all shifts for this template
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('template_id', '==', TEMPLATE_ID)
    .get();
  
  console.log(`Found ${shiftsSnap.size} shifts for template ${TEMPLATE_ID}\n`);
  
  // Get a working shift for comparison (Saturday FGC)
  const workingSnap = await db.collection('teaching_shifts')
    .where('template_id', '==', 'tpl_3efd2b29f4ad9e60') // Saturday FGC
    .limit(1)
    .get();
  
  if (workingSnap.size > 0) {
    console.log('=== WORKING SHIFT (Saturday FGC) FIELDS ===');
    const workingData = workingSnap.docs[0].data();
    console.log(JSON.stringify(workingData, null, 2));
  }
  
  console.log('\n=== FRIDAY SHIFT FIELDS ===');
  if (shiftsSnap.size > 0) {
    const fridayData = shiftsSnap.docs[0].data();
    console.log(JSON.stringify(fridayData, null, 2));
  }
  
  // Compare field differences
  if (workingSnap.size > 0 && shiftsSnap.size > 0) {
    const workingKeys = Object.keys(workingSnap.docs[0].data()).sort();
    const fridayKeys = Object.keys(shiftsSnap.docs[0].data()).sort();
    
    console.log('\n=== FIELD COMPARISON ===');
    console.log('Missing in Friday shifts:');
    workingKeys.forEach(key => {
      if (!fridayKeys.includes(key)) {
        console.log(`  - ${key}: ${JSON.stringify(workingSnap.docs[0].data()[key])}`);
      }
    });
    
    console.log('\nExtra in Friday shifts:');
    fridayKeys.forEach(key => {
      if (!workingKeys.includes(key)) {
        console.log(`  + ${key}`);
      }
    });
  }
}

checkShifts()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
