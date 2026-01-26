#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

// Templates to fix
const TEMPLATE_IDS = [
  'tpl_4f4f466eeddd70e0',
  'tpl_9b7cda14c778a3fa',
];

// New times (NYC timezone)
const NEW_START_HOUR = 13;
const NEW_START_MINUTE = 15;
const NEW_END_HOUR = 14;
const NEW_END_MINUTE = 15;
const NEW_START_TIME = '13:15'; // 1:15 PM
const NEW_END_TIME = '14:15';   // 2:15 PM
const NEW_DURATION = 60;        // minutes

async function fix() {
  console.log('='.repeat(80));
  console.log('FIXING Mariam Diallo schedule\n');
  console.log(`New time: ${NEW_START_TIME} - ${NEW_END_TIME} (1:15 PM - 2:15 PM NYC)\n`);
  
  const now = DateTime.now().setZone(NYC_TZ);
  
  for (const templateId of TEMPLATE_IDS) {
    console.log('='.repeat(80));
    console.log(`Processing template: ${templateId}\n`);
    
    const templateDoc = await db.collection('shift_templates').doc(templateId).get();
    
    if (!templateDoc.exists) {
      console.log('  Template not found, skipping...');
      continue;
    }
    
    const templateData = templateDoc.data();
    console.log(`  Current: ${templateData.start_time} - ${templateData.end_time}`);
    console.log(`  Teacher: ${templateData.teacher_name}`);
    console.log(`  Students: ${(templateData.student_names || []).join(', ')}`);
    console.log(`  Weekdays: ${JSON.stringify(templateData.enhanced_recurrence?.selectedWeekdays)}`);
    
    // Update template (if not already updated)
    if (templateData.start_time !== NEW_START_TIME || templateData.end_time !== NEW_END_TIME) {
      console.log('\n  Updating template...');
      await db.collection('shift_templates').doc(templateId).update({
        start_time: NEW_START_TIME,
        end_time: NEW_END_TIME,
        duration_minutes: NEW_DURATION,
        last_modified: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log('  ✅ Template updated');
    } else {
      console.log('\n  Template already updated');
    }
    
    // Find all shifts for this template
    const shiftsSnap = await db.collection('teaching_shifts')
      .where('template_id', '==', templateId)
      .get();
    
    console.log(`\n  Found ${shiftsSnap.size} total shifts for this template`);
    
    let updatedCount = 0;
    for (const shiftDoc of shiftsSnap.docs) {
      const shiftData = shiftDoc.data();
      
      // Try shift_start first, then start_time
      const startField = shiftData.shift_start || shiftData.start_time;
      if (!startField || !startField.toDate) {
        console.log(`    ⚠️ ${shiftDoc.id}: No valid start time found`);
        continue;
      }
      
      const shiftStart = DateTime.fromJSDate(startField.toDate()).setZone(NYC_TZ);
      
      // Only update future shifts
      if (shiftStart < now) {
        continue;
      }
      
      // Create new start/end times on the same date
      const newStart = shiftStart.set({ hour: NEW_START_HOUR, minute: NEW_START_MINUTE, second: 0, millisecond: 0 });
      const newEnd = shiftStart.set({ hour: NEW_END_HOUR, minute: NEW_END_MINUTE, second: 0, millisecond: 0 });
      
      // Update both field naming conventions
      await db.collection('teaching_shifts').doc(shiftDoc.id).update({
        shift_start: admin.firestore.Timestamp.fromDate(newStart.toJSDate()),
        shift_end: admin.firestore.Timestamp.fromDate(newEnd.toJSDate()),
        start_time: admin.firestore.Timestamp.fromDate(newStart.toJSDate()),
        end_time: admin.firestore.Timestamp.fromDate(newEnd.toJSDate()),
        duration_minutes: NEW_DURATION,
      });
      
      console.log(`    ✅ ${shiftDoc.id}: ${shiftStart.toFormat('ccc MMM d')} → ${newStart.toFormat('h:mm a')} - ${newEnd.toFormat('h:mm a')}`);
      updatedCount++;
    }
    
    console.log(`\n  Updated ${updatedCount} future shifts`);
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('✅ ALL CHANGES APPLIED!');
  console.log('Mariam Diallo classes are now 1:15 PM - 2:15 PM NYC time');
}

fix()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
