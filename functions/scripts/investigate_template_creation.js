#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';
const TEMPLATE_ID = 'uzRUXJD57dgFuwswdmoJ';

async function investigate() {
  console.log('='.repeat(80));
  console.log('FULL TEMPLATE DATA:\n');
  
  const templateDoc = await db.collection('shift_templates').doc(TEMPLATE_ID).get();
  
  if (!templateDoc.exists) {
    console.log('Template not found!');
    return;
  }
  
  const data = templateDoc.data();
  
  // Print all fields
  for (const [key, value] of Object.entries(data)) {
    if (value && typeof value === 'object' && value.toDate) {
      console.log(`${key}: ${value.toDate().toISOString()}`);
    } else if (typeof value === 'object') {
      console.log(`${key}: ${JSON.stringify(value, null, 2)}`);
    } else {
      console.log(`${key}: ${value}`);
    }
  }
  
  // Check what the Cloud Function would see
  console.log('\n' + '='.repeat(80));
  console.log('ANALYSIS:\n');
  
  const maxDaysAhead = data.max_days_ahead;
  console.log(`max_days_ahead: ${maxDaysAhead}`);
  
  const recurrence = data.enhanced_recurrence || {};
  console.log(`recurrence type: ${recurrence.type}`);
  console.log(`selectedWeekdays: ${JSON.stringify(recurrence.selectedWeekdays)}`);
  console.log(`endDate: ${recurrence.endDate ? (recurrence.endDate.toDate ? recurrence.endDate.toDate().toISOString() : recurrence.endDate) : 'null'}`);
  
  const recurrenceEndDate = data.recurrence_end_date;
  console.log(`recurrence_end_date: ${recurrenceEndDate ? (recurrenceEndDate.toDate ? recurrenceEndDate.toDate().toISOString() : recurrenceEndDate) : 'null'}`);
  
  // Simulate what the Cloud Function would generate
  console.log('\n' + '='.repeat(80));
  console.log('SIMULATING CLOUD FUNCTION GENERATION:\n');
  
  const now = DateTime.now().setZone(NYC_TZ);
  const horizon = now.plus({ days: maxDaysAhead });
  
  console.log(`Now: ${now.toFormat('fff')}`);
  console.log(`Horizon (now + ${maxDaysAhead} days): ${horizon.toFormat('fff')}`);
  
  const selectedWeekdays = recurrence.selectedWeekdays || [];
  
  let count = 0;
  for (let cursor = now.startOf('day'); cursor < horizon; cursor = cursor.plus({ days: 1 })) {
    const luxonDay = cursor.weekday;
    if (selectedWeekdays.includes(luxonDay)) {
      count++;
      if (count <= 5) {
        console.log(`  Would generate: ${cursor.toFormat('ccc MMM d')}`);
      }
    }
  }
  
  console.log(`  ... total: ${count} shifts would be generated`);
  
  // Check the base shift
  console.log('\n' + '='.repeat(80));
  console.log('BASE SHIFT:\n');
  
  const baseShiftId = data.base_shift_id;
  if (baseShiftId) {
    const baseShiftDoc = await db.collection('teaching_shifts').doc(baseShiftId).get();
    if (baseShiftDoc.exists) {
      const baseData = baseShiftDoc.data();
      console.log(`ID: ${baseShiftId}`);
      console.log(`Teacher: ${baseData.teacher_name}`);
      console.log(`Students: ${(baseData.student_names || []).join(', ')}`);
      console.log(`Status: ${baseData.status}`);
      console.log(`Recurrence: ${baseData.recurrence}`);
      console.log(`template_id: ${baseData.template_id}`);
      console.log(`generated_from_template: ${baseData.generated_from_template}`);
    }
  }
}

investigate()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
