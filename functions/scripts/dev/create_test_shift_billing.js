#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';
const TEACHER_EMAIL = 'billing@alluwaleducationhub.org';

async function createTestShift() {
  console.log('='.repeat(80));
  console.log('Creating test shift for billing teacher\n');
  
  // Find teacher
  const usersSnap = await db.collection('users').get();
  
  let teacherId = null;
  let teacherName = null;
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const email = (data.email || data['e-mail'] || '').toLowerCase();
    if (email === TEACHER_EMAIL.toLowerCase()) {
      teacherId = doc.id;
      teacherName = `${data.first_name || data.firstName || ''} ${data.last_name || data.lastName || ''}`.trim();
      console.log(`Found teacher: ${teacherName} | ID: ${teacherId}`);
      break;
    }
  }
  
  if (!teacherId) {
    console.log('Teacher not found!');
    return;
  }
  
  // Delete existing shifts and templates for this teacher
  console.log('\n' + '='.repeat(80));
  console.log('Deleting existing shifts and templates...\n');
  
  // Delete templates
  const templatesSnap = await db.collection('shift_templates')
    .where('teacher_id', '==', teacherId)
    .get();
  
  console.log(`Found ${templatesSnap.size} templates to delete`);
  for (const doc of templatesSnap.docs) {
    await doc.ref.delete();
  }
  console.log('✅ Templates deleted');
  
  // Delete shifts
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('teacher_id', '==', teacherId)
    .get();
  
  console.log(`Found ${shiftsSnap.size} shifts to delete`);
  for (const doc of shiftsSnap.docs) {
    await doc.ref.delete();
  }
  console.log('✅ Shifts deleted');
  
  // Create a new shift for today at 10:45 AM NYC
  console.log('\n' + '='.repeat(80));
  console.log('Creating new test shift...\n');
  
  const now = DateTime.now().setZone(NYC_TZ);
  const shiftDate = now.startOf('day');
  
  // Set shift time to 10:45 AM NYC
  const shiftStart = shiftDate.set({ hour: 10, minute: 45, second: 0, millisecond: 0 });
  const shiftEnd = shiftStart.plus({ hours: 1 }); // 1 hour shift
  
  console.log(`Shift Date: ${shiftStart.toFormat('ccc, MMM d, yyyy')}`);
  console.log(`Start Time: ${shiftStart.toFormat('h:mm a')} NYC`);
  console.log(`End Time: ${shiftEnd.toFormat('h:mm a')} NYC`);
  
  // Find a test student
  let studentId = null;
  let studentName = 'Test Student';
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const code = (data.student_code || '').toLowerCase();
    if (code === 'test.student') {
      studentId = doc.id;
      studentName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
      console.log(`Using student: ${studentName} | ID: ${studentId}`);
      break;
    }
  }
  
  const shiftId = `test_billing_${Math.floor(Date.now() / 1000)}`;
  
  const shiftData = {
    id: shiftId,
    teacher_id: teacherId,
    teacher_name: teacherName || 'Billing Teacher',
    student_ids: studentId ? [studentId] : [],
    student_names: studentId ? [studentName] : [],
    shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toJSDate()),
    shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toJSDate()),
    duration_minutes: 60,
    status: 'scheduled',
    subject: 'quranStudies',
    subject_display_name: 'Quran Studies',
    subject_id: 'Xeuwcc5kb3MVkPzg4mU2',
    hourly_rate: 4,
    admin_timezone: NYC_TZ,
    teacher_timezone: NYC_TZ,
    auto_generated_name: `${teacherName} - Quran - ${studentName}`,
    video_provider: 'livekit',
    recurrence: 'none',
    shift_category: 'teaching',
    original_local_start: shiftStart.toFormat("yyyy-MM-dd'T'HH:mm:ss"),
    original_local_end: shiftEnd.toFormat("yyyy-MM-dd'T'HH:mm:ss"),
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
    last_modified: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  await db.collection('teaching_shifts').doc(shiftId).set(shiftData);
  
  console.log(`\n✅ Created shift: ${shiftId}`);
  console.log(`   Time: ${shiftStart.toFormat('h:mm a')} - ${shiftEnd.toFormat('h:mm a')} NYC`);
  
  // Schedule lifecycle tasks
  console.log('\nScheduling lifecycle tasks...');
  
  const functions = require('firebase-functions');
  const { CloudTasksClient } = require('@google-cloud/tasks');
  
  try {
    const tasksClient = new CloudTasksClient();
    const project = 'alluwal-academy';
    const location = 'us-central1';
    const queue = 'shift-lifecycle';
    const parent = tasksClient.queuePath(project, location, queue);
    
    const startEpoch = Math.floor(shiftStart.toMillis() / 1000);
    const endEpoch = Math.floor(shiftEnd.toMillis() / 1000);
    
    // Schedule start task
    const startTaskName = `${parent}/tasks/${shiftId}/start/${startEpoch}`;
    const startPayload = {
      shiftId,
      teacherId,
      shiftStart: shiftStart.toUTC().toISO(),
      shiftEnd: shiftEnd.toUTC().toISO(),
    };
    
    try {
      await tasksClient.createTask({
        parent,
        task: {
          name: startTaskName,
          httpRequest: {
            httpMethod: 'POST',
            url: 'https://handleshiftstarttask-tbbm4lh74q-uc.a.run.app',
            body: Buffer.from(JSON.stringify(startPayload)).toString('base64'),
            headers: { 'Content-Type': 'application/json' },
          },
          scheduleTime: { seconds: startEpoch },
        },
      });
      console.log(`✅ Start task scheduled for ${shiftStart.toFormat('h:mm a')}`);
    } catch (e) {
      if (e.code === 6) {
        console.log('Start task already exists');
      } else {
        console.log(`Start task error: ${e.message}`);
      }
    }
    
    // Schedule end task
    const endTaskName = `${parent}/tasks/${shiftId}/end/${endEpoch}`;
    const endPayload = {
      shiftId,
      teacherId,
      shiftStart: shiftStart.toUTC().toISO(),
      shiftEnd: shiftEnd.toUTC().toISO(),
    };
    
    try {
      await tasksClient.createTask({
        parent,
        task: {
          name: endTaskName,
          httpRequest: {
            httpMethod: 'POST',
            url: 'https://handleshiftendtask-tbbm4lh74q-uc.a.run.app',
            body: Buffer.from(JSON.stringify(endPayload)).toString('base64'),
            headers: { 'Content-Type': 'application/json' },
          },
          scheduleTime: { seconds: endEpoch },
        },
      });
      console.log(`✅ End task scheduled for ${shiftEnd.toFormat('h:mm a')}`);
    } catch (e) {
      if (e.code === 6) {
        console.log('End task already exists');
      } else {
        console.log(`End task error: ${e.message}`);
      }
    }
  } catch (e) {
    console.log(`Task scheduling error: ${e.message}`);
    console.log('You may need to schedule lifecycle tasks manually via the app.');
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('✅ TEST SHIFT CREATED!');
  console.log(`\nShift ID: ${shiftId}`);
  console.log(`Teacher: ${teacherName}`);
  console.log(`Time: ${shiftStart.toFormat('h:mm a')} - ${shiftEnd.toFormat('h:mm a')} NYC (today)`);
  console.log('\nNow you can:');
  console.log('1. Open the app and find this shift');
  console.log('2. Change the time (e.g., to 11:30 AM)');
  console.log('3. Wait for the ORIGINAL time (10:45 AM) to pass');
  console.log('4. Verify the shift is NOT marked as missed');
}

createTestShift()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
