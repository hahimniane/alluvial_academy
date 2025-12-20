/**
 * Test Handler: Verify Breakout Room Creation
 *
 * Call via: firebase functions:shell then testBreakoutCreation({})
 */

const admin = require('firebase-admin');
const { onCall } = require('firebase-functions/v2/https');
const { DateTime } = require('luxon');

const getDb = () => admin.firestore();

/**
 * Test function to create a shift and verify breakout room creation
 */
exports.testBreakoutCreation = onCall(async (request) => {
  const db = getDb();
  const logs = [];
  const log = (msg) => {
    console.log(msg);
    logs.push(msg);
  };

  try {
    log('=== Breakout Room Creation Test ===');

    // Step 1: Find or Create Teacher
    const targetEmail = request.data.teacherEmail || 'nenenane2@gmail.com';
    log(`\nStep 1: finding teacher ${targetEmail}...`);

    let teacherDoc = null;
    const teacherQuery = await db.collection('users').where('email', '==', targetEmail).limit(1).get();

    if (!teacherQuery.empty) {
      teacherDoc = teacherQuery.docs[0];
    } else {
      // Check alt email
      const altQuery = await db.collection('users').where('e-mail', '==', targetEmail).limit(1).get();
      if (!altQuery.empty) {
        teacherDoc = altQuery.docs[0];
      } else {
        // Create dummy user
        log(`  Teacher not found. Creating dummy user for ${targetEmail}...`);
        const newRef = db.collection('users').doc();
        await newRef.set({
          email: targetEmail,
          first_name: 'Test',
          last_name: 'Teacher',
          user_type: 'teacher',
          email_verified: false, // As per instruction not to worry about verification
          created_at: admin.firestore.FieldValue.serverTimestamp()
        });
        teacherDoc = await newRef.get();
      }
    }

    const teacherData = teacherDoc.data();
    const teacherId = teacherDoc.id;
    const teacherName = `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim() || 'Teacher';
    log(`  Using Teacher: ${teacherName} (ID: ${teacherId})`);


    // Step 2: Find students
    log('\nStep 2: Finding students...');
    const studentsQuery = await db.collection('users')
      .where('user_type', '==', 'student')
      .limit(2)
      .get();

    const students = [];
    studentsQuery.forEach(doc => {
      const d = doc.data();
      students.push({
        id: doc.id,
        name: `${d.first_name || ''} ${d.last_name || ''}`.trim() || 'Student',
        email: d.email || d['e-mail']
      });
    });

    log(`  Found ${students.length} students`);
    students.forEach(s => log(`    - ${s.name} (${s.email})`));

    // Step 3: Create shift
    log('\nStep 3: Creating test shift...');
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
      auto_generated_name: `${teacherName} - Test Class`,
      created_by_admin_id: 'test_script',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      hubMeetingId: null,
      is_test_data: true,
    };

    await shiftRef.set(shiftData);
    log(`  Created shift: ${shiftRef.id}`);
    log(`  Time: ${shiftStart.toFormat('MMM dd, h:mm a')} - ${shiftEnd.toFormat('h:mm a')} UTC`);

    // Step 4: Run hub scheduler
    log('\nStep 4: Running hub scheduler...');
    try {
      const { scheduleHubMeetings } = require('../services/shifts/schedule_hubs');
      await scheduleHubMeetings();
      log('  Hub scheduler completed.');
    } catch (e) {
      log(`  Hub scheduler error: ${e.message}`);
    }

    // Step 5: Verify results
    log('\nStep 5: Verifying results...');
    const updatedShift = await db.collection('teaching_shifts').doc(shiftRef.id).get();
    const updated = updatedShift.data();

    const results = {
      shiftId: shiftRef.id,
      hubMeetingId: updated.hubMeetingId || null,
      breakoutRoomName: updated.breakoutRoomName || null,
      breakoutRoomKey: updated.breakoutRoomKey || null,
      zoomRoutingMode: updated.zoomRoutingMode || null,
      hasRoutingRisk: updated.hasRoutingRisk || false,
      routingRiskParticipants: updated.routingRiskParticipants || [],
      preAssignedParticipants: updated.preAssignedParticipants || [],
    };

    log('\n=== RESULTS ===');
    log(`Hub Meeting ID: ${results.hubMeetingId || 'NOT ASSIGNED'}`);
    log(`Breakout Room Name: ${results.breakoutRoomName || 'NOT ASSIGNED'}`);
    log(`Routing Mode: ${results.zoomRoutingMode || 'NOT SET'}`);
    log(`Has Routing Risk: ${results.hasRoutingRisk}`);
    log(`Pre-Assigned: ${JSON.stringify(results.preAssignedParticipants)}`);

    if (results.hubMeetingId) {
      const hubDoc = await db.collection('hub_meetings').doc(results.hubMeetingId).get();
      if (hubDoc.exists) {
        const hub = hubDoc.data();
        log('\n=== HUB MEETING ===');
        log(`Zoom Meeting ID: ${hub.meetingId}`);
        log(`Status: ${hub.status}`);
        log(`Expected Participants: ${hub.totalExpectedParticipants}`);
      }
    }

    return {
      success: true,
      logs,
      results,
      cleanupCommand: `To delete: firebase firestore:delete teaching_shifts/${shiftRef.id}`,
    };

  } catch (e) {
    log(`ERROR: ${e.message}`);
    return { success: false, logs, error: e.message };
  }
});

/**
 * Simple test to list users
 */
/**
 * Simple test to list users
 */
exports.listUsers = onCall(async (request) => {
  const db = getDb();
  const users = [];
  const email = request.data.email; // Optional filter

  let query = db.collection('users');
  if (email) {
    query = query.where('email', '==', email);
  } else {
    query = query.limit(20);
  }

  const snapshot = await query.get();

  if (snapshot.empty && email) {
    // Try alt email field
    const altQuery = db.collection('users').where('e-mail', '==', email);
    const altSnapshot = await altQuery.get();
    altSnapshot.forEach(doc => {
      const d = doc.data();
      users.push({
        id: doc.id,
        email: d.email || d['e-mail'],
        name: `${d.first_name || ''} ${d.last_name || ''}`.trim(),
        role: d.user_type || d.role,
      });
    });
  } else {
    snapshot.forEach(doc => {
      const d = doc.data();
      users.push({
        id: doc.id,
        email: d.email || d['e-mail'],
        name: `${d.first_name || ''} ${d.last_name || ''}`.trim(),
        role: d.user_type || d.role,
      });
    });
  }

  return { users };
});
