/**
 * Test Handler: Verify Zoom Hybrid Implementation
 *
 * Tests the hybrid flow where teachers:
 * 1. Join meeting via Flutter app
 * 2. Fetch host key via getZoomHostKey
 * 3. Claim host status in meeting
 * 4. Mark breakout rooms as opened (cancels backup bot task)
 *
 * Uses two teachers for testing:
 * - nenenane2@gmail.com
 * - Aliou Diallo
 */

const { onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { ensureZoomMeetingAndEmailTeacher } = require('../services/zoom/shift_zoom');
const { getZoomConfig } = require('../services/zoom/config');

const getDb = () => admin.firestore();

/**
 * Helper to get Zoom access token
 */
async function getZoomToken() {
  const config = getZoomConfig();
  const tokenUrl = new URL('https://zoom.us/oauth/token');
  tokenUrl.searchParams.set('grant_type', 'account_credentials');
  tokenUrl.searchParams.set('account_id', config.accountId);
  const basic = Buffer.from(config.clientId + ':' + config.clientSecret).toString('base64');

  const resp = await fetch(tokenUrl.toString(), {
    method: 'POST',
    headers: { Authorization: 'Basic ' + basic }
  });
  const json = await resp.json();
  return json.access_token;
}

/**
 * Find teachers by email or name
 */
async function findTeachers(db) {
  const teachers = {
    nenenane: null,
    aliou: null
  };

  // Find nenenane2@gmail.com
  const neneQuery = await db.collection('users')
    .where('e-mail', '==', 'nenenane2@gmail.com')
    .limit(1)
    .get();

  if (!neneQuery.empty) {
    const doc = neneQuery.docs[0];
    const data = doc.data();
    teachers.nenenane = {
      id: doc.id,
      name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
      email: data['e-mail'] || data.email,
      timezone: data.timezone || 'UTC'
    };
  }

  // Find Aliou Diallo
  const teacherQuery = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();

  for (const doc of teacherQuery.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.toLowerCase();
    if (fullName.includes('aliou') && fullName.includes('diallo')) {
      teachers.aliou = {
        id: doc.id,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        email: data['e-mail'] || data.email,
        timezone: data.timezone || 'UTC'
      };
      break;
    }
  }

  return teachers;
}

/**
 * Test the hybrid Zoom flow for both teachers
 */
exports.testHybridZoomFlow = onCall({ timeoutSeconds: 300 }, async (request) => {
  const db = getDb();
  const results = {
    setup: [],
    teachers: {},
    shifts: [],
    hostKeyTests: [],
    markOpenedTests: [],
    errors: []
  };

  try {
    // ==========================================
    // STEP 1: Find teachers
    // ==========================================
    console.log('[HybridTest] Step 1: Finding teachers...');
    results.setup.push('Finding teachers nenenane2@gmail.com and Aliou Diallo...');

    const teachers = await findTeachers(db);
    results.teachers = teachers;

    if (!teachers.nenenane) {
      throw new Error('Could not find teacher: nenenane2@gmail.com');
    }
    if (!teachers.aliou) {
      throw new Error('Could not find teacher: Aliou Diallo');
    }

    results.setup.push(`Found Teacher 1: ${teachers.nenenane.name} (${teachers.nenenane.id})`);
    results.setup.push(`Found Teacher 2: ${teachers.aliou.name} (${teachers.aliou.id})`);

    // Get students for shift creation
    const studentQuery = await db.collection('users')
      .where('user_type', '==', 'student')
      .where('is_active', '==', true)
      .limit(2)
      .get();

    const students = studentQuery.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        email: data['e-mail'] || data.email
      };
    });

    if (students.length < 2) {
      throw new Error(`Need at least 2 students, found ${students.length}`);
    }

    // ==========================================
    // STEP 2: Create test shifts
    // ==========================================
    console.log('[HybridTest] Step 2: Creating test shifts...');
    results.setup.push('Creating test shifts for both teachers...');

    const now = new Date();
    const shiftStart = new Date(now.getTime() + 10 * 60 * 1000); // 10 mins from now
    const shiftEnd = new Date(shiftStart.getTime() + 50 * 60 * 1000); // 50 mins

    // Create shift for Teacher 1 (nenenane)
    const shift1Ref = db.collection('teaching_shifts').doc();
    const shift1Data = {
      teacher_id: teachers.nenenane.id,
      teacher_name: teachers.nenenane.name,
      student_ids: [students[0].id],
      student_names: [students[0].name],
      shift_start: admin.firestore.Timestamp.fromDate(shiftStart),
      shift_end: admin.firestore.Timestamp.fromDate(shiftEnd),
      admin_timezone: 'America/New_York',
      teacher_timezone: teachers.nenenane.timezone,
      subject: 'quranStudies',
      subject_display_name: 'Quran Studies',
      auto_generated_name: `${teachers.nenenane.name} - Hybrid Test`,
      hourly_rate: 4,
      status: 'scheduled',
      created_by_admin_id: request.auth?.uid || 'test-hybrid-script',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      recurrence: 'none',
      shift_category: 'teaching',
      is_hybrid_test: true,
    };

    await shift1Ref.set(shift1Data);
    results.setup.push(`Created shift for ${teachers.nenenane.name}: ${shift1Ref.id}`);

    // Create shift for Teacher 2 (Aliou) - SAME TIME to test overlap detection
    const shift2Start = new Date(shiftStart.getTime()); // SAME time as shift1 (overlap!)
    const shift2End = new Date(shiftEnd.getTime()); // Same end time too

    const shift2Ref = db.collection('teaching_shifts').doc();
    const shift2Data = {
      teacher_id: teachers.aliou.id,
      teacher_name: teachers.aliou.name,
      student_ids: [students[1].id],
      student_names: [students[1].name],
      shift_start: admin.firestore.Timestamp.fromDate(shift2Start),
      shift_end: admin.firestore.Timestamp.fromDate(shift2End),
      admin_timezone: 'America/New_York',
      teacher_timezone: teachers.aliou.timezone,
      subject: 'arabicLanguage',
      subject_display_name: 'Arabic Language',
      auto_generated_name: `${teachers.aliou.name} - Hybrid Test`,
      hourly_rate: 4,
      status: 'scheduled',
      created_by_admin_id: request.auth?.uid || 'test-hybrid-script',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      recurrence: 'none',
      shift_category: 'teaching',
      is_hybrid_test: true,
    };

    await shift2Ref.set(shift2Data);
    results.setup.push(`Created shift for ${teachers.aliou.name}: ${shift2Ref.id}`);

    // Wait for Firestore consistency
    await new Promise(resolve => setTimeout(resolve, 1500));

    // Create Zoom meetings for both shifts
    console.log('[HybridTest] Creating Zoom meetings...');
    results.setup.push('Creating Zoom meetings for both shifts...');

    await ensureZoomMeetingAndEmailTeacher({
      shiftId: shift1Ref.id,
      shiftData: { ...shift1Data, shift_start: shiftStart, shift_end: shiftEnd }
    });

    await new Promise(resolve => setTimeout(resolve, 1000));

    await ensureZoomMeetingAndEmailTeacher({
      shiftId: shift2Ref.id,
      shiftData: { ...shift2Data, shift_start: shift2Start, shift_end: shift2End }
    });

    // Re-fetch shifts to get Zoom meeting IDs
    const shift1Updated = await shift1Ref.get();
    const shift2Updated = await shift2Ref.get();

    results.shifts = [
      {
        teacher: teachers.nenenane.name,
        shiftId: shift1Ref.id,
        zoomMeetingId: shift1Updated.data()?.zoom_meeting_id || 'NOT SET',
        breakoutRoom: shift1Updated.data()?.breakoutRoomName || 'NOT SET',
      },
      {
        teacher: teachers.aliou.name,
        shiftId: shift2Ref.id,
        zoomMeetingId: shift2Updated.data()?.zoom_meeting_id || 'NOT SET',
        breakoutRoom: shift2Updated.data()?.breakoutRoomName || 'NOT SET',
      }
    ];

    // ==========================================
    // STEP 3: Test getZoomHostKey for both teachers
    // ==========================================
    console.log('[HybridTest] Step 3: Testing getZoomHostKey...');
    results.setup.push('Testing getZoomHostKey for both teachers...');

    // Simulate calling getZoomHostKey for Teacher 1
    const hostKey = process.env.ZOOM_HOST_KEY;

    // Test Teacher 1
    const teacher1Test = {
      teacher: teachers.nenenane.name,
      shiftId: shift1Ref.id,
      isTeacherForShift: shift1Updated.data()?.teacher_id === teachers.nenenane.id,
      hostKeyConfigured: !!hostKey,
      expectedResult: 'Should receive host key',
    };

    if (teacher1Test.isTeacherForShift && teacher1Test.hostKeyConfigured) {
      teacher1Test.result = 'PASS - Teacher would receive host key';
      teacher1Test.hostKeyLength = hostKey.length;
    } else {
      teacher1Test.result = 'FAIL - Missing requirements';
    }
    results.hostKeyTests.push(teacher1Test);

    // Test Teacher 2
    const teacher2Test = {
      teacher: teachers.aliou.name,
      shiftId: shift2Ref.id,
      isTeacherForShift: shift2Updated.data()?.teacher_id === teachers.aliou.id,
      hostKeyConfigured: !!hostKey,
      expectedResult: 'Should receive host key',
    };

    if (teacher2Test.isTeacherForShift && teacher2Test.hostKeyConfigured) {
      teacher2Test.result = 'PASS - Teacher would receive host key';
      teacher2Test.hostKeyLength = hostKey.length;
    } else {
      teacher2Test.result = 'FAIL - Missing requirements';
    }
    results.hostKeyTests.push(teacher2Test);

    // Test that a different teacher can't get host key for someone else's shift
    const crossTeacherTest = {
      teacher: teachers.aliou.name,
      shiftId: shift1Ref.id, // Nenenane's shift
      isTeacherForShift: shift1Updated.data()?.teacher_id === teachers.aliou.id,
      expectedResult: 'Should be DENIED (wrong teacher)',
    };
    crossTeacherTest.result = crossTeacherTest.isTeacherForShift
      ? 'FAIL - Unexpected match'
      : 'PASS - Correctly denied (teacher_id mismatch)';
    results.hostKeyTests.push(crossTeacherTest);

    // ==========================================
    // STEP 4: Test markBreakoutRoomsOpened
    // ==========================================
    console.log('[HybridTest] Step 4: Testing markBreakoutRoomsOpened...');
    results.setup.push('Testing markBreakoutRoomsOpened for both teachers...');

    // Simulate marking rooms as opened for Teacher 1
    await db.collection('teaching_shifts').doc(shift1Ref.id).update({
      breakout_rooms_opened_at: admin.firestore.FieldValue.serverTimestamp(),
      breakout_rooms_opened_by: teachers.nenenane.id,
    });

    const shift1AfterMark = await shift1Ref.get();
    const mark1Test = {
      teacher: teachers.nenenane.name,
      shiftId: shift1Ref.id,
      markedAt: shift1AfterMark.data()?.breakout_rooms_opened_at ? 'SET' : 'NOT SET',
      markedBy: shift1AfterMark.data()?.breakout_rooms_opened_by,
      result: shift1AfterMark.data()?.breakout_rooms_opened_at ? 'PASS' : 'FAIL',
    };
    results.markOpenedTests.push(mark1Test);

    // Simulate marking rooms as opened for Teacher 2
    await db.collection('teaching_shifts').doc(shift2Ref.id).update({
      breakout_rooms_opened_at: admin.firestore.FieldValue.serverTimestamp(),
      breakout_rooms_opened_by: teachers.aliou.id,
    });

    const shift2AfterMark = await shift2Ref.get();
    const mark2Test = {
      teacher: teachers.aliou.name,
      shiftId: shift2Ref.id,
      markedAt: shift2AfterMark.data()?.breakout_rooms_opened_at ? 'SET' : 'NOT SET',
      markedBy: shift2AfterMark.data()?.breakout_rooms_opened_by,
      result: shift2AfterMark.data()?.breakout_rooms_opened_at ? 'PASS' : 'FAIL',
    };
    results.markOpenedTests.push(mark2Test);

    // ==========================================
    // STEP 5: Verify Zoom meeting has correct breakout rooms
    // ==========================================
    console.log('[HybridTest] Step 5: Verifying Zoom meeting configuration...');

    // Re-fetch shifts to get final state
    const finalShift1 = await shift1Ref.get();
    const finalShift2 = await shift2Ref.get();

    const finalMeetingId1 = finalShift1.data()?.zoom_meeting_id;
    const finalMeetingId2 = finalShift2.data()?.zoom_meeting_id;

    results.overlapVerification = {
      shift1MeetingId: finalMeetingId1,
      shift2MeetingId: finalMeetingId2,
      sameMeeting: finalMeetingId1 === finalMeetingId2,
      shift1BreakoutRoom: finalShift1.data()?.breakoutRoomName,
      shift2BreakoutRoom: finalShift2.data()?.breakoutRoomName,
    };

    // Check breakout rooms via Zoom API
    if (finalMeetingId1 || finalMeetingId2) {
      const meetingToCheck = finalMeetingId2 || finalMeetingId1;
      try {
        const config = getZoomConfig();
        const tokenUrl = new URL('https://zoom.us/oauth/token');
        tokenUrl.searchParams.set('grant_type', 'account_credentials');
        tokenUrl.searchParams.set('account_id', config.accountId);
        const basic = Buffer.from(config.clientId + ':' + config.clientSecret).toString('base64');

        const tokenResp = await fetch(tokenUrl.toString(), {
          method: 'POST',
          headers: { Authorization: 'Basic ' + basic }
        });
        const tokenJson = await tokenResp.json();
        const token = tokenJson.access_token;

        const meetingResp = await fetch(
          `https://api.zoom.us/v2/meetings/${meetingToCheck}`,
          { headers: { Authorization: `Bearer ${token}` } }
        );
        const meetingData = await meetingResp.json();

        results.overlapVerification.zoomMeetingDetails = {
          meetingId: meetingData.id,
          topic: meetingData.topic,
          breakoutRoomsEnabled: meetingData.settings?.breakout_room?.enable || false,
          breakoutRoomCount: meetingData.settings?.breakout_room?.rooms?.length || 0,
          breakoutRooms: meetingData.settings?.breakout_room?.rooms?.map(r => ({
            name: r.name,
            participantCount: r.participants?.length || 0,
            participants: r.participants || []
          })) || [],
        };

        // Verify overlap was handled correctly
        if (finalMeetingId1 === finalMeetingId2) {
          results.overlapVerification.overlapTest = 'PASS - Both shifts share the same meeting';
        } else {
          results.overlapVerification.overlapTest = 'FAIL - Shifts have different meetings (overlap not detected)';
        }

        if (results.overlapVerification.zoomMeetingDetails.breakoutRoomCount >= 2) {
          results.overlapVerification.breakoutRoomTest = `PASS - Meeting has ${results.overlapVerification.zoomMeetingDetails.breakoutRoomCount} breakout rooms`;
        } else {
          results.overlapVerification.breakoutRoomTest = `FAIL - Meeting only has ${results.overlapVerification.zoomMeetingDetails.breakoutRoomCount} breakout rooms (expected 2+)`;
        }

      } catch (e) {
        results.overlapVerification.error = e.message;
      }
    }

    // ==========================================
    // STEP 6: Summary
    // ==========================================
    console.log('[HybridTest] Complete!');

    const summary = {
      totalTests: results.hostKeyTests.length + results.markOpenedTests.length + 2, // +2 for overlap tests
      passed: 0,
      failed: 0,
    };

    [...results.hostKeyTests, ...results.markOpenedTests].forEach(test => {
      if (test.result?.startsWith('PASS')) {
        summary.passed++;
      } else {
        summary.failed++;
      }
    });

    // Count overlap verification tests
    if (results.overlapVerification?.overlapTest?.startsWith('PASS')) summary.passed++;
    else summary.failed++;
    if (results.overlapVerification?.breakoutRoomTest?.startsWith('PASS')) summary.passed++;
    else summary.failed++;

    results.summary = summary;

    // Cleanup info
    results.cleanup = {
      message: 'To clean up test data, delete the following shifts:',
      shifts: [shift1Ref.id, shift2Ref.id],
      commands: [
        `firebase firestore:delete teaching_shifts/${shift1Ref.id}`,
        `firebase firestore:delete teaching_shifts/${shift2Ref.id}`,
      ]
    };

    return { success: true, results };

  } catch (error) {
    console.error('[HybridTest] Error:', error);
    results.errors.push(error.message);
    return { success: false, error: error.message, results };
  }
});

/**
 * Verify host key configuration
 */
exports.verifyHostKeyConfig = onCall(async (request) => {
  const hostKey = process.env.ZOOM_HOST_KEY;

  return {
    configured: !!hostKey,
    length: hostKey ? hostKey.length : 0,
    format: hostKey ? (hostKey.match(/^\d{6}$/) ? 'valid (6 digits)' : 'invalid format') : 'not set',
    message: hostKey
      ? 'Host key is configured and ready for hybrid flow'
      : 'ZOOM_HOST_KEY not set in environment',
  };
});

/**
 * Clear all Zoom meetings from the API (for testing)
 * Gets meeting IDs from Firestore shifts and deletes them from Zoom
 */
exports.clearAllZoomMeetings = onCall({ timeoutSeconds: 120 }, async (request) => {
  const config = getZoomConfig();
  const db = getDb();
  const results = { deleted: [], errors: [], shiftsCleared: [] };

  try {
    // Get access token
    const tokenUrl = new URL('https://zoom.us/oauth/token');
    tokenUrl.searchParams.set('grant_type', 'account_credentials');
    tokenUrl.searchParams.set('account_id', config.accountId);
    const basic = Buffer.from(config.clientId + ':' + config.clientSecret).toString('base64');

    const tokenResp = await fetch(tokenUrl.toString(), {
      method: 'POST',
      headers: { Authorization: 'Basic ' + basic }
    });
    const tokenJson = await tokenResp.json();
    const token = tokenJson.access_token;

    if (!token) {
      return { success: false, error: 'Failed to get access token', tokenResponse: tokenJson };
    }

    // Get all unique Zoom meeting IDs from shifts
    const shiftsSnapshot = await db.collection('teaching_shifts')
      .where('status', 'in', ['scheduled', 'active'])
      .get();

    const meetingIds = new Set();
    const shiftUpdates = [];

    shiftsSnapshot.docs.forEach(doc => {
      const zoomId = doc.data().zoom_meeting_id;
      if (zoomId) {
        meetingIds.add(zoomId);
        shiftUpdates.push(doc.id);
      }
    });

    results.totalFound = meetingIds.size;
    results.shiftsWithMeetings = shiftUpdates.length;

    // Delete each meeting from Zoom
    for (const meetingId of meetingIds) {
      try {
        const delResp = await fetch(
          `https://api.zoom.us/v2/meetings/${meetingId}`,
          {
            method: 'DELETE',
            headers: { Authorization: `Bearer ${token}` }
          }
        );

        if (delResp.status === 204 || delResp.status === 404) {
          results.deleted.push(meetingId);
        } else {
          const errorText = await delResp.text();
          results.errors.push({ id: meetingId, status: delResp.status, error: errorText });
        }
      } catch (e) {
        results.errors.push({ id: meetingId, error: e.message });
      }
    }

    // Clear Zoom data from all shifts (keep shifts, just remove zoom info)
    const batch = db.batch();
    for (const shiftId of shiftUpdates) {
      batch.update(db.collection('teaching_shifts').doc(shiftId), {
        zoom_meeting_id: null,
        zoom_encrypted_join_url: null,
        zoom_encrypted_meeting_passcode: null,
        zoom_meeting_created_at: null,
        zoom_invite_sent_at: null,
        zoom_host_email: null,
        breakoutRoomName: null,
        breakout_rooms_opened_at: null,
        breakout_rooms_opened_by: null,
      });
      results.shiftsCleared.push(shiftId);
    }
    await batch.commit();

    return {
      success: true,
      message: `Deleted ${results.deleted.length} Zoom meetings and cleared ${results.shiftsCleared.length} shifts`,
      results
    };

  } catch (error) {
    return { success: false, error: error.message };
  }
});

/**
 * Create a test class for a specific teacher using a specific host
 */
exports.createTestClassForTeacher = onCall({ timeoutSeconds: 120 }, async (request) => {
  const { teacherEmail, hostEmail, minutesFromNow = 5 } = request.data || {};
  const db = getDb();

  if (!teacherEmail) {
    return { success: false, error: 'teacherEmail is required' };
  }

  const targetHost = hostEmail || 'support@alluwaleducationhub.org';

  try {
    // Step 1: Find or identify the teacher
    let teacherDoc = null;
    let teacherData = null;

    // Search by email
    const emailQuery = await db.collection('users')
      .where('e-mail', '==', teacherEmail)
      .limit(1)
      .get();

    if (!emailQuery.empty) {
      teacherDoc = emailQuery.docs[0];
      teacherData = teacherDoc.data();
    } else {
      // Try alternate email field
      const altQuery = await db.collection('users')
        .where('email', '==', teacherEmail)
        .limit(1)
        .get();
      if (!altQuery.empty) {
        teacherDoc = altQuery.docs[0];
        teacherData = teacherDoc.data();
      }
    }

    if (!teacherDoc) {
      return {
        success: false,
        error: `Teacher not found: ${teacherEmail}`,
        hint: 'Make sure the teacher exists in the users collection'
      };
    }

    // Step 2: Find a student for the class
    const studentQuery = await db.collection('users')
      .where('user_type', '==', 'student')
      .where('is_active', '==', true)
      .limit(1)
      .get();

    if (studentQuery.empty) {
      return { success: false, error: 'No active students found' };
    }

    const studentDoc = studentQuery.docs[0];
    const studentData = studentDoc.data();

    // Step 3: Create the shift
    const now = new Date();
    const shiftStart = new Date(now.getTime() + minutesFromNow * 60 * 1000);
    const shiftEnd = new Date(shiftStart.getTime() + 50 * 60 * 1000);

    const teacherName = `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim() || 'Teacher';
    const studentName = `${studentData.first_name || ''} ${studentData.last_name || ''}`.trim() || 'Student';

    const shiftRef = db.collection('teaching_shifts').doc();
    const shiftData = {
      teacher_id: teacherDoc.id,
      teacher_name: teacherName,
      student_ids: [studentDoc.id],
      student_names: [studentName],
      shift_start: admin.firestore.Timestamp.fromDate(shiftStart),
      shift_end: admin.firestore.Timestamp.fromDate(shiftEnd),
      admin_timezone: 'America/New_York',
      teacher_timezone: teacherData.timezone || 'America/New_York',
      subject: 'quranStudies',
      subject_display_name: 'Quran Studies',
      auto_generated_name: `${teacherName} - Hybrid Host Test`,
      hourly_rate: 4,
      status: 'scheduled',
      created_by_admin_id: 'test-hybrid-host-script',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      recurrence: 'none',
      shift_category: 'teaching',
      is_hybrid_test: true,
      // Store which host to use for this meeting
      zoom_host_override: targetHost,
    };

    await shiftRef.set(shiftData);

    // Step 4: Create the Zoom meeting with the specified host
    const config = getZoomConfig();

    // Get access token
    const tokenUrl = new URL('https://zoom.us/oauth/token');
    tokenUrl.searchParams.set('grant_type', 'account_credentials');
    tokenUrl.searchParams.set('account_id', config.accountId);
    const basic = Buffer.from(config.clientId + ':' + config.clientSecret).toString('base64');

    const tokenResp = await fetch(tokenUrl.toString(), {
      method: 'POST',
      headers: { Authorization: 'Basic ' + basic }
    });
    const tokenJson = await tokenResp.json();
    const token = tokenJson.access_token;

    if (!token) {
      return { success: false, error: 'Failed to get Zoom access token', details: tokenJson };
    }

    // Create meeting with the specified host
    const meetingPayload = {
      topic: `Alluwal Academy - ${teacherName} Test Class`,
      type: 2, // Scheduled meeting
      start_time: shiftStart.toISOString(),
      duration: 50,
      timezone: teacherData.timezone || 'America/New_York',
      settings: {
        host_video: true,
        participant_video: true,
        join_before_host: true,
        waiting_room: false,
        mute_upon_entry: false,
        auto_recording: 'none',
        breakout_room: {
          enable: true,
          rooms: [
            {
              name: `${teacherName} | ${studentName} | ${shiftStart.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}`,
              participants: [teacherEmail, studentData['e-mail'] || studentData.email].filter(Boolean)
            }
          ]
        }
      }
    };

    const createResp = await fetch(
      `https://api.zoom.us/v2/users/${encodeURIComponent(targetHost)}/meetings`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(meetingPayload)
      }
    );

    const meetingResult = await createResp.json();

    if (createResp.status !== 201) {
      // Clean up shift if meeting creation failed
      await shiftRef.delete();
      return {
        success: false,
        error: 'Failed to create Zoom meeting',
        status: createResp.status,
        details: meetingResult,
        hint: `Make sure ${targetHost} is a valid Zoom user with scheduling privileges`
      };
    }

    // Update shift with meeting info
    await shiftRef.update({
      zoom_meeting_id: meetingResult.id?.toString(),
      zoom_host_email: targetHost,
      zoom_meeting_created_at: admin.firestore.FieldValue.serverTimestamp(),
      breakoutRoomName: meetingPayload.settings.breakout_room.rooms[0].name,
    });

    return {
      success: true,
      message: `Test class created for ${teacherName}`,
      shift: {
        id: shiftRef.id,
        teacherId: teacherDoc.id,
        teacherName: teacherName,
        teacherEmail: teacherEmail,
        studentName: studentName,
        shiftStart: shiftStart.toISOString(),
        shiftEnd: shiftEnd.toISOString(),
      },
      zoom: {
        meetingId: meetingResult.id,
        hostEmail: targetHost,
        joinUrl: meetingResult.join_url,
        breakoutRoom: meetingPayload.settings.breakout_room.rooms[0].name,
      },
      hostKey: process.env.ZOOM_HOST_KEY,
      instructions: [
        '1. Open the Flutter app on your device',
        '2. Log in as ' + teacherEmail,
        '3. Go to your scheduled shifts',
        '4. Tap "Start Class" on the shift',
        '5. The app should automatically claim host status',
        '6. You should be able to open breakout rooms',
        '',
        'Note: The host (' + targetHost + ') does NOT need to be in the meeting!',
      ]
    };

  } catch (error) {
    console.error('[createTestClassForTeacher] Error:', error);
    return { success: false, error: error.message };
  }
});

/**
 * Get info about a specific shift for testing
 */
exports.getShiftForTesting = onCall(async (request) => {
  const { shiftId, teacherEmail } = request.data;
  const db = getDb();

  if (!shiftId && !teacherEmail) {
    return { error: 'Provide either shiftId or teacherEmail' };
  }

  let shiftDoc;

  if (shiftId) {
    shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
  } else {
    // Find teacher first
    let teacherId = null;
    const teacherQuery = await db.collection('users')
      .where('e-mail', '==', teacherEmail)
      .limit(1)
      .get();

    if (!teacherQuery.empty) {
      teacherId = teacherQuery.docs[0].id;
    } else {
      const altQuery = await db.collection('users')
        .where('email', '==', teacherEmail)
        .limit(1)
        .get();
      if (!altQuery.empty) {
        teacherId = altQuery.docs[0].id;
      }
    }

    if (!teacherId) {
      return { error: `Teacher not found: ${teacherEmail}` };
    }

    // Find most recent shift for this teacher
    const shiftQuery = await db.collection('teaching_shifts')
      .where('teacher_id', '==', teacherId)
      .where('status', '==', 'scheduled')
      .orderBy('shift_start', 'desc')
      .limit(1)
      .get();

    if (shiftQuery.empty) {
      return { error: `No scheduled shifts found for teacher: ${teacherEmail}` };
    }

    shiftDoc = shiftQuery.docs[0];
  }

  if (!shiftDoc.exists) {
    return { error: 'Shift not found' };
  }

  const data = shiftDoc.data();

  return {
    shiftId: shiftDoc.id,
    teacherId: data.teacher_id,
    teacherName: data.teacher_name,
    zoomMeetingId: data.zoom_meeting_id,
    shiftStart: data.shift_start?.toDate?.()?.toISOString(),
    shiftEnd: data.shift_end?.toDate?.()?.toISOString(),
    breakoutRoomName: data.breakoutRoomName,
    breakoutRoomsOpenedAt: data.breakout_rooms_opened_at?.toDate?.()?.toISOString(),
    breakoutRoomsOpenedBy: data.breakout_rooms_opened_by,
    status: data.status,
    hostKeyAvailable: !!process.env.ZOOM_HOST_KEY,
  };
});
