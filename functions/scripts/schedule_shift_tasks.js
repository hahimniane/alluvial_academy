#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const { CloudTasksClient } = require('@google-cloud/tasks');

admin.initializeApp({ projectId: 'alluwal-academy' });

const SHIFT_ID = 'test_billing_1769355572';

async function scheduleTasks() {
  console.log('Scheduling lifecycle tasks for shift:', SHIFT_ID);
  
  // Get shift data
  const shiftDoc = await admin.firestore().collection('teaching_shifts').doc(SHIFT_ID).get();
  
  if (!shiftDoc.exists) {
    console.log('Shift not found!');
    return;
  }
  
  const data = shiftDoc.data();
  const shiftStart = data.shift_start.toDate();
  const shiftEnd = data.shift_end.toDate();
  const teacherId = data.teacher_id;
  
  console.log(`Shift: ${shiftStart.toISOString()} - ${shiftEnd.toISOString()}`);
  
  const tasksClient = new CloudTasksClient();
  const project = 'alluwal-academy';
  const location = 'us-central1';
  const queue = 'shift-lifecycle';
  const parent = tasksClient.queuePath(project, location, queue);
  
  const startEpoch = Math.floor(shiftStart.getTime() / 1000);
  const endEpoch = Math.floor(shiftEnd.getTime() / 1000);
  
  const payload = {
    shiftId: SHIFT_ID,
    teacherId,
    shiftStart: shiftStart.toISOString(),
    shiftEnd: shiftEnd.toISOString(),
  };
  
  // Schedule start task
  try {
    await tasksClient.createTask({
      parent,
      task: {
        name: `${parent}/tasks/start_${SHIFT_ID}_${startEpoch}`,
        httpRequest: {
          httpMethod: 'POST',
          url: 'https://handleshiftstarttask-tbbm4lh74q-uc.a.run.app',
          body: Buffer.from(JSON.stringify(payload)).toString('base64'),
          headers: { 'Content-Type': 'application/json' },
        },
        scheduleTime: { seconds: startEpoch },
      },
    });
    console.log(`✅ Start task scheduled for ${shiftStart.toLocaleString()}`);
  } catch (e) {
    if (e.code === 6) {
      console.log('Start task already exists (OK)');
    } else {
      console.log(`Start task error: ${e.message}`);
    }
  }
  
  // Schedule end task
  try {
    await tasksClient.createTask({
      parent,
      task: {
        name: `${parent}/tasks/end_${SHIFT_ID}_${endEpoch}`,
        httpRequest: {
          httpMethod: 'POST',
          url: 'https://handleshiftendtask-tbbm4lh74q-uc.a.run.app',
          body: Buffer.from(JSON.stringify(payload)).toString('base64'),
          headers: { 'Content-Type': 'application/json' },
        },
        scheduleTime: { seconds: endEpoch },
      },
    });
    console.log(`✅ End task scheduled for ${shiftEnd.toLocaleString()}`);
  } catch (e) {
    if (e.code === 6) {
      console.log('End task already exists (OK)');
    } else {
      console.log(`End task error: ${e.message}`);
    }
  }
  
  console.log('\nDone!');
}

scheduleTasks()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
