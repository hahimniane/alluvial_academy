#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';
const TEMPLATE_ID = 'uzRUXJD57dgFuwswdmoJ';

async function fix() {
  console.log('='.repeat(80));
  console.log('FIXING excludedWeekdays bug\n');
  
  const templateDoc = await db.collection('shift_templates').doc(TEMPLATE_ID).get();
  
  if (!templateDoc.exists) {
    console.log('Template not found!');
    return;
  }
  
  const data = templateDoc.data();
  console.log(`Template: ${TEMPLATE_ID}`);
  console.log(`  Current excludedWeekdays: ${JSON.stringify(data.enhanced_recurrence?.excludedWeekdays)}`);
  console.log(`  Current selectedWeekdays: ${JSON.stringify(data.enhanced_recurrence?.selectedWeekdays)}`);
  
  // Fix the enhanced_recurrence
  const fixedRecurrence = {
    ...data.enhanced_recurrence,
    excludedWeekdays: [], // Clear the excludedWeekdays!
  };
  
  console.log(`\nFixing: Setting excludedWeekdays to []`);
  
  await db.collection('shift_templates').doc(TEMPLATE_ID).update({
    'enhanced_recurrence': fixedRecurrence,
    'last_modified': admin.firestore.FieldValue.serverTimestamp(),
  });
  
  console.log('✅ Template fixed!');
  
  // Now verify
  const verifyDoc = await db.collection('shift_templates').doc(TEMPLATE_ID).get();
  console.log(`\nVerified excludedWeekdays: ${JSON.stringify(verifyDoc.data().enhanced_recurrence?.excludedWeekdays)}`);
  
  // Check how many shifts exist
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('template_id', '==', TEMPLATE_ID)
    .get();
  
  console.log(`\nCurrent shifts for this template: ${shiftsSnap.size}`);
  
  if (shiftsSnap.size > 50) {
    console.log('Shifts already regenerated, no need to regenerate again.');
    return;
  }
  
  console.log('\nNote: The daily scheduler will now be able to generate shifts.');
  console.log('Or you can manually trigger regeneration by running the regenerate script.');
}

fix()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
