#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const SHIFT_ID = 'test_billing_1769355572';
const NYC_TZ = 'America/New_York';

async function check() {
  console.log('='.repeat(80));
  console.log('Checking shift:', SHIFT_ID);
  console.log('='.repeat(80));
  
  const shiftDoc = await db.collection('teaching_shifts').doc(SHIFT_ID).get();
  
  if (!shiftDoc.exists) {
    console.log('Shift not found!');
    return;
  }
  
  const data = shiftDoc.data();
  
  const shiftStart = data.shift_start?.toDate ? DateTime.fromJSDate(data.shift_start.toDate()).setZone(NYC_TZ) : null;
  const shiftEnd = data.shift_end?.toDate ? DateTime.fromJSDate(data.shift_end.toDate()).setZone(NYC_TZ) : null;
  
  console.log('\nCurrent Shift Data:');
  console.log(`  Status: ${data.status}`);
  console.log(`  Start: ${shiftStart?.toFormat('h:mm a')} NYC`);
  console.log(`  End: ${shiftEnd?.toFormat('h:mm a')} NYC`);
  console.log(`  Teacher: ${data.teacher_name}`);
  console.log(`  Duration: ${data.duration_minutes} minutes`);
  
  console.log('\nTimestamps:');
  console.log(`  shift_start: ${data.shift_start?.toDate?.().toISOString()}`);
  console.log(`  shift_end: ${data.shift_end?.toDate?.().toISOString()}`);
  console.log(`  last_modified: ${data.last_modified?.toDate?.().toISOString()}`);
  console.log(`  updated_at: ${data.updated_at?.toDate?.().toISOString()}`);
  
  console.log('\nOriginal Local Times:');
  console.log(`  original_local_start: ${data.original_local_start}`);
  console.log(`  original_local_end: ${data.original_local_end}`);
  
  console.log('\nTemplate Info:');
  console.log(`  template_id: ${data.template_id || 'none'}`);
  console.log(`  generated_from_template: ${data.generated_from_template}`);
  
  console.log('\nMissed Info:');
  console.log(`  missed_reason: ${data.missed_reason || 'none'}`);
  console.log(`  missed_at: ${data.missed_at?.toDate?.().toISOString() || 'none'}`);
  console.log(`  missed_notification_sent: ${data.missed_notification_sent}`);
  
  // Check Cloud Tasks queue
  console.log('\n' + '='.repeat(80));
  console.log('Checking for any related Cloud Tasks...\n');
  
  try {
    const { CloudTasksClient } = require('@google-cloud/tasks');
    const tasksClient = new CloudTasksClient();
    const parent = tasksClient.queuePath('alluwal-academy', 'us-central1', 'shift-lifecycle');
    
    const [tasks] = await tasksClient.listTasks({ parent, pageSize: 100 });
    
    const relevantTasks = tasks.filter(t => t.name.includes(SHIFT_ID) || t.name.includes('billing'));
    
    if (relevantTasks.length > 0) {
      console.log(`Found ${relevantTasks.length} relevant tasks:`);
      for (const task of relevantTasks) {
        console.log(`  ${task.name}`);
        console.log(`    Schedule: ${task.scheduleTime?.seconds ? new Date(task.scheduleTime.seconds * 1000).toISOString() : 'N/A'}`);
      }
    } else {
      console.log('No relevant tasks found in queue');
    }
  } catch (e) {
    console.log(`Could not check Cloud Tasks: ${e.message}`);
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('Summary:');
  console.log(`  Shift is currently: ${data.status}`);
  console.log(`  Current time: ${shiftStart?.toFormat('h:mm a')} - ${shiftEnd?.toFormat('h:mm a')} NYC`);
  
  // Check what the original time was
  if (data.original_local_start && !data.original_local_start.includes('10:45')) {
    console.log(`\n✅ Time was successfully changed from 10:45 AM!`);
  }
}

check()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
