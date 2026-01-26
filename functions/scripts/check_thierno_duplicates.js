#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const THIERNO_UID = 'Thz8PIVUGpS5cjlIYBJAemjoQxw1';

async function checkDuplicates() {
  console.log('Checking for overlapping shifts (old vs template-generated)...\n');
  console.log('='.repeat(80));
  
  const allShiftsSnap = await db.collection('teaching_shifts')
    .where('teacher_id', '==', THIERNO_UID)
    .where('status', '==', 'scheduled')
    .get();
  
  console.log(`Total scheduled shifts: ${allShiftsSnap.size}\n`);
  
  // Group shifts by start time
  const shiftsByStartTime = new Map();
  
  for (const doc of allShiftsSnap.docs) {
    const data = doc.data();
    const startTime = DateTime.fromJSDate(data.shift_start.toDate()).setZone('America/New_York');
    const key = startTime.toISO();
    
    if (!shiftsByStartTime.has(key)) {
      shiftsByStartTime.set(key, []);
    }
    shiftsByStartTime.get(key).push({
      id: doc.id,
      templateId: data.template_id || 'NO_TEMPLATE',
      startTime: startTime.toFormat('EEE, MMM dd h:mm a'),
      students: data.student_ids,
    });
  }
  
  // Find duplicates (same start time, multiple shifts)
  console.log('DUPLICATE SHIFTS (same start time):\n');
  
  let duplicateCount = 0;
  const duplicatesToDelete = [];
  
  for (const [key, shifts] of shiftsByStartTime) {
    if (shifts.length > 1) {
      duplicateCount++;
      console.log(`⚠️ ${shifts[0].startTime}:`);
      
      let hasTemplate = false;
      let noTemplateShift = null;
      
      for (const s of shifts) {
        const hasTemplateId = s.templateId !== 'NO_TEMPLATE';
        console.log(`   - ${s.id} (template: ${s.templateId})`);
        
        if (hasTemplateId) hasTemplate = true;
        if (!hasTemplateId) noTemplateShift = s.id;
      }
      
      // If one has a template and one doesn't, the one without template is likely the old duplicate
      if (hasTemplate && noTemplateShift) {
        duplicatesToDelete.push(noTemplateShift);
        console.log(`   → Should delete: ${noTemplateShift} (old shift without template)`);
      }
      
      console.log('');
    }
  }
  
  console.log('='.repeat(80));
  console.log(`\nTotal duplicate time slots: ${duplicateCount}`);
  console.log(`Shifts to delete (old without templates): ${duplicatesToDelete.length}`);
  
  // Summary of old shifts without templates
  console.log('\n' + '='.repeat(80));
  console.log('SUMMARY OF SHIFTS WITHOUT TEMPLATES:\n');
  
  const noTemplateShifts = allShiftsSnap.docs.filter(doc => !doc.data().template_id);
  console.log(`Total shifts without template_id: ${noTemplateShifts.length}`);
  
  // Check how many of these overlap with template shifts
  let overlappingCount = 0;
  for (const doc of noTemplateShifts) {
    const data = doc.data();
    const startTime = DateTime.fromJSDate(data.shift_start.toDate()).setZone('America/New_York');
    const key = startTime.toISO();
    
    const shiftsAtTime = shiftsByStartTime.get(key);
    if (shiftsAtTime && shiftsAtTime.length > 1) {
      overlappingCount++;
    }
  }
  
  console.log(`Shifts overlapping with template shifts: ${overlappingCount}`);
  console.log(`Non-overlapping old shifts: ${noTemplateShifts.length - overlappingCount}`);
  
  console.log('\n' + '='.repeat(80));
  console.log('RECOMMENDATION:\n');
  console.log('The duplicates are caused by OLD shifts (without template_id) that overlap');
  console.log('with NEW shifts generated from templates.');
  console.log('');
  console.log(`To fix: Delete the ${duplicatesToDelete.length} old duplicate shifts.`);
}

checkDuplicates()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
