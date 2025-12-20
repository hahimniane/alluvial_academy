/**
 * Test Script: Verify Breakout Room Creation for Shifts
 *
 * This script:
 * 1. Finds the teacher by email
 * 2. Finds students in the database
 * 3. Creates a test shift
 * 4. Runs the hub scheduler
 * 5. Verifies breakout room was created
 */

const admin = require('firebase-admin');
const { DateTime } = require('luxon');

// Initialize Firebase Admin with project ID
if (admin.apps.length === 0) {
  admin.initializeApp({
    projectId: 'alluwal-academy',
  });
}

const db = admin.firestore();

async function main() {
  console.log('=== Breakout Room Creation Test ===\n');

  // Step 1: Find teacher by email
  console.log('Step 1: Finding teacher nenenane2@gmail.com...');
  const teacherQuery = await db.collection('users')
    .where('email', '==', 'nenenane2@gmail.com')
    .limit(1)
    .get();

  if (teacherQuery.empty) {
    // Try alternative email field
    const altQuery = await db.collection('users')
      .where('e-mail', '==', 'nenenane2@gmail.com')
      .limit(1)
      .get();

    if (altQuery.empty) {
      console.log('ERROR: Teacher not found with email nenenane2@gmail.com');
      console.log('\nLet me search for all users to see what\'s available...\n');

      const allUsers = await db.collection('users').limit(10).get();
      console.log('Sample users in database:');
      allUsers.forEach(doc => {
        const data = doc.data();
        console.log(`  - ID: ${doc.id}, Email: ${data.email || data['e-mail']}, Role: ${data.user_type || data.role}`);
      });
      return;
    }
  }

  const teacherDoc = teacherQuery.docs[0] || (await db.collection('users')
    .where('e-mail', '==', 'nenenane2@gmail.com')
    .limit(1)
    .get()).docs[0];

  if (!teacherDoc) {
    console.log('ERROR: Teacher not found');
    return;
  }

  const teacherData = teacherDoc.data();
  const teacherId = teacherDoc.id;
  const teacherName = `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim() || 'Teacher';

  console.log(`  Found: ${teacherName} (ID: ${teacherId})`);
  console.log(`  Email: ${teacherData.email || teacherData['e-mail']}`);
  console.log(`  Role: ${teacherData.user_type || teacherData.role}`);

  // Step 2: Find students
  console.log('\nStep 2: Finding students...');
  const studentsQuery = await db.collection('users')
    .where('user_type', '==', 'student')
    .limit(3)
    .get();

  const students = [];
  studentsQuery.forEach(doc => {
    const data = doc.data();
    students.push({
      id: doc.id,
      name: `${data.first_name || ''} ${data.last_name || ''}`.trim() || 'Student',
      email: data.email || data['e-mail']
    });
  });

  if (students.length === 0) {
    console.log('  No students found. Will create shift with teacher only.');
  } else {
    console.log(`  Found ${students.length} students:`);
    students.forEach(s => console.log(`    - ${s.name} (${s.email})`));
  }

  // Step 3: Create a test shift
  console.log('\nStep 3: Creating test shift...');

  // Schedule for 2 hours from now (within 24h window for hub scheduler)
  const shiftStart = DateTime.utc().plus({ hours: 2 }).set({ minute: 0, second: 0, millisecond: 0 });
  const shiftEnd = shiftStart.plus({ minutes: 50 });

  const shiftRef = db.collection('teaching_shifts').doc();
  const shiftData = {
    id: shiftRef.id,
    teacher_id: teacherId,
    teacher_name: teacherName,
    student_ids: students.map(s => s.id),
    student_names: students.map(s => s.name),
    shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toJSDate()),
    shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toJSDate()),
    status: 'scheduled',
    subject: 'quranStudies',
    hourly_rate: 15,
    admin_timezone: 'UTC',
    teacher_timezone: 'UTC',
    auto_generated_name: `${teacherName} - Quran - ${students.map(s => s.name).join(', ') || 'No students'}`,
    created_by_admin_id: 'test_script',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    // Important: No hubMeetingId so it gets picked up by scheduler
    hubMeetingId: null,
    is_test_data: true, // Flag for cleanup
  };

  await shiftRef.set(shiftData);
  console.log(`  Created shift: ${shiftRef.id}`);
  console.log(`  Time: ${shiftStart.toFormat('MMM dd, yyyy h:mm a')} - ${shiftEnd.toFormat('h:mm a')} UTC`);
  console.log(`  Teacher: ${teacherName}`);
  console.log(`  Students: ${students.length > 0 ? students.map(s => s.name).join(', ') : 'None'}`);

  // Step 4: Run hub scheduler
  console.log('\nStep 4: Running hub scheduler...');
  try {
    const { scheduleHubMeetings } = require('./services/shifts/schedule_hubs');
    await scheduleHubMeetings();
    console.log('  Hub scheduler completed.');
  } catch (e) {
    console.log(`  Hub scheduler error: ${e.message}`);
    console.log('  (This may be expected if Zoom credentials are not configured)');
  }

  // Step 5: Verify breakout room creation
  console.log('\nStep 5: Verifying breakout room creation...');

  // Re-fetch the shift to see if it was updated
  const updatedShift = await db.collection('teaching_shifts').doc(shiftRef.id).get();
  const updatedData = updatedShift.data();

  console.log('\n=== RESULTS ===');
  console.log(`Shift ID: ${shiftRef.id}`);
  console.log(`Hub Meeting ID: ${updatedData.hubMeetingId || 'NOT ASSIGNED'}`);
  console.log(`Breakout Room Name: ${updatedData.breakoutRoomName || 'NOT ASSIGNED'}`);
  console.log(`Breakout Room Key: ${updatedData.breakoutRoomKey || 'NOT ASSIGNED'}`);
  console.log(`Zoom Routing Mode: ${updatedData.zoomRoutingMode || 'NOT SET'}`);
  console.log(`Has Routing Risk: ${updatedData.hasRoutingRisk || false}`);
  console.log(`Routing Risk Participants: ${JSON.stringify(updatedData.routingRiskParticipants || [])}`);
  console.log(`Pre-Assigned Participants: ${JSON.stringify(updatedData.preAssignedParticipants || [])}`);

  if (updatedData.hubMeetingId) {
    // Fetch hub meeting details
    const hubDoc = await db.collection('hub_meetings').doc(updatedData.hubMeetingId).get();
    if (hubDoc.exists) {
      const hubData = hubDoc.data();
      console.log('\n=== HUB MEETING DETAILS ===');
      console.log(`Hub ID: ${hubDoc.id}`);
      console.log(`Zoom Meeting ID: ${hubData.meetingId}`);
      console.log(`Status: ${hubData.status}`);
      console.log(`Total Expected Participants: ${hubData.totalExpectedParticipants}`);
      console.log(`Shifts in Hub: ${hubData.shifts?.length || 0}`);
    }
  }

  // Cleanup option
  console.log('\n=== CLEANUP ===');
  console.log(`To delete test shift, run:`);
  console.log(`  firebase firestore:delete teaching_shifts/${shiftRef.id}`);
}

main().catch(console.error);
