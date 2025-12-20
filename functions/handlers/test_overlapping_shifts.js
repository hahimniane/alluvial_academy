const { onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { ensureZoomMeetingAndEmailTeacher } = require('../services/zoom/shift_zoom');
const { getZoomConfig } = require('../services/zoom/config');

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
 * Delete a Zoom meeting by ID
 */
async function deleteZoomMeeting(token, meetingId) {
  const resp = await fetch(
    `https://api.zoom.us/v2/meetings/${meetingId}`,
    {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` }
    }
  );
  return resp.status === 204 || resp.status === 404;
}

/**
 * Clear all Zoom meetings and create overlapping test shifts
 */
exports.testCreateOverlappingShifts = onCall({ timeoutSeconds: 300 }, async (request) => {
  const db = admin.firestore();
  const results = {
    zoomCleanup: [],
    teachers: [],
    shifts: [],
    errors: []
  };

  try {
    const config = getZoomConfig();
    const token = await getZoomToken();

    // ==========================================
    // STEP 1: Get all unique Zoom meeting IDs from shifts and delete them
    // ==========================================
    console.log('[Test] Step 1: Finding and deleting all Zoom meetings from shifts...');

    const allShifts = await db.collection('teaching_shifts')
      .where('status', 'in', ['scheduled', 'active'])
      .get();

    // Collect unique meeting IDs
    const meetingIds = new Set();
    allShifts.docs.forEach(doc => {
      const zoomId = doc.data().zoom_meeting_id;
      if (zoomId) meetingIds.add(zoomId);
    });

    results.zoomCleanup.push(`Found ${meetingIds.size} unique Zoom meetings to delete`);

    // Delete each meeting
    for (const meetingId of meetingIds) {
      try {
        const deleted = await deleteZoomMeeting(token, meetingId);
        if (deleted) {
          results.zoomCleanup.push(`Deleted meeting ${meetingId}`);
        } else {
          results.zoomCleanup.push(`Could not delete meeting ${meetingId}`);
        }
      } catch (e) {
        results.zoomCleanup.push(`Error deleting ${meetingId}: ${e.message}`);
      }
    }

    // Clear zoom fields from all shifts (but keep the shifts!)
    console.log('[Test] Clearing Zoom data from shifts (keeping shifts intact)...');
    const batch = db.batch();
    allShifts.docs.forEach(doc => {
      if (doc.data().zoom_meeting_id) {
        batch.update(doc.ref, {
          zoom_meeting_id: null,
          zoom_encrypted_join_url: null,
          zoom_encrypted_meeting_passcode: null,
          zoom_meeting_created_at: null,
          zoom_invite_sent_at: null,
          zoom_host_email: null,
          breakoutRoomName: null
        });
      }
    });
    await batch.commit();
    results.zoomCleanup.push(`Cleared Zoom data from ${allShifts.size} shifts`);

    // ==========================================
    // STEP 2: Find the two specific teachers
    // ==========================================
    console.log('[Test] Step 2: Finding teachers nenenane2@gmail.com and Aliou Diallo...');

    // Find nenenane2@gmail.com
    let teacher1 = null;
    const neneQuery = await db.collection('users')
      .where('e-mail', '==', 'nenenane2@gmail.com')
      .limit(1)
      .get();

    if (neneQuery.empty === false) {
      const doc = neneQuery.docs[0];
      const data = doc.data();
      teacher1 = {
        id: doc.id,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        email: data['e-mail'] || data.email,
        timezone: data.timezone || 'UTC'
      };
      results.teachers.push(`Found teacher1: ${teacher1.name} (${teacher1.email})`);
    }

    // Find Aliou Diallo
    let teacher2 = null;
    const teacherQuery = await db.collection('users')
      .where('user_type', '==', 'teacher')
      .get();

    for (const doc of teacherQuery.docs) {
      const data = doc.data();
      const fullName = `${data.first_name || ''} ${data.last_name || ''}`.toLowerCase();
      if (fullName.includes('aliou') && fullName.includes('diallo')) {
        teacher2 = {
          id: doc.id,
          name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
          email: data['e-mail'] || data.email,
          timezone: data.timezone || 'UTC'
        };
        results.teachers.push(`Found teacher2: ${teacher2.name} (${teacher2.email})`);
        break;
      }
    }

    if (!teacher1 || !teacher2) {
      throw new Error(`Could not find teachers. Teacher1: ${teacher1 ? 'found' : 'missing'}, Teacher2: ${teacher2 ? 'found' : 'missing'}`);
    }

    // Get students
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
    // STEP 3: Create overlapping shifts
    // ==========================================
    console.log('[Test] Step 3: Creating overlapping shifts...');

    const now = new Date();
    const shiftStart = new Date(now.getTime() + 20 * 60 * 1000); // 20 mins from now
    const shiftEnd = new Date(shiftStart.getTime() + 60 * 60 * 1000); // 1 hour

    // Create shift 1 for nenenane2@gmail.com
    const shift1Ref = db.collection('teaching_shifts').doc();
    const shift1Data = {
      teacher_id: teacher1.id,
      teacher_name: teacher1.name,
      student_ids: [students[0].id],
      student_names: [students[0].name],
      shift_start: admin.firestore.Timestamp.fromDate(shiftStart),
      shift_end: admin.firestore.Timestamp.fromDate(shiftEnd),
      admin_timezone: 'America/New_York',
      teacher_timezone: teacher1.timezone,
      subject: 'quranStudies',
      subject_display_name: 'Quran Studies',
      auto_generated_name: `${teacher1.name} - Quran - ${students[0].name}`,
      hourly_rate: 4,
      status: 'scheduled',
      created_by_admin_id: request.auth?.uid || 'test-script',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      recurrence: 'none',
      shift_category: 'teaching',
    };

    await shift1Ref.set(shift1Data);
    console.log(`[Test] Created shift1: ${shift1Ref.id} for ${teacher1.name}`);

    // Wait for Firestore consistency
    await new Promise(resolve => setTimeout(resolve, 1500));

    // Create Zoom meeting for shift 1
    const zoom1Result = await ensureZoomMeetingAndEmailTeacher({
      shiftId: shift1Ref.id,
      shiftData: { ...shift1Data, shift_start: shiftStart, shift_end: shiftEnd }
    });

    const shift1Updated = await shift1Ref.get();
    results.shifts.push({
      name: `Shift 1: ${teacher1.name}`,
      shiftId: shift1Ref.id,
      zoomMeetingId: shift1Updated.data()?.zoom_meeting_id,
      breakoutRoom: shift1Updated.data()?.breakoutRoomName,
      zoomResult: zoom1Result
    });

    // Wait before creating second shift
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Create shift 2 for Aliou Diallo (SAME TIME = OVERLAP)
    const shift2Ref = db.collection('teaching_shifts').doc();
    const shift2Data = {
      teacher_id: teacher2.id,
      teacher_name: teacher2.name,
      student_ids: [students[1].id],
      student_names: [students[1].name],
      shift_start: admin.firestore.Timestamp.fromDate(shiftStart), // SAME TIME!
      shift_end: admin.firestore.Timestamp.fromDate(shiftEnd),
      admin_timezone: 'America/New_York',
      teacher_timezone: teacher2.timezone,
      subject: 'arabicLanguage',
      subject_display_name: 'Arabic Language',
      auto_generated_name: `${teacher2.name} - Arabic - ${students[1].name}`,
      hourly_rate: 4,
      status: 'scheduled',
      created_by_admin_id: request.auth?.uid || 'test-script',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      recurrence: 'none',
      shift_category: 'teaching',
    };

    await shift2Ref.set(shift2Data);
    console.log(`[Test] Created shift2: ${shift2Ref.id} for ${teacher2.name}`);

    await new Promise(resolve => setTimeout(resolve, 1500));

    // Create Zoom meeting for shift 2 - should detect overlap!
    const zoom2Result = await ensureZoomMeetingAndEmailTeacher({
      shiftId: shift2Ref.id,
      shiftData: { ...shift2Data, shift_start: shiftStart, shift_end: shiftEnd }
    });

    const shift2Updated = await shift2Ref.get();
    results.shifts.push({
      name: `Shift 2: ${teacher2.name}`,
      shiftId: shift2Ref.id,
      zoomMeetingId: shift2Updated.data()?.zoom_meeting_id,
      breakoutRoom: shift2Updated.data()?.breakoutRoomName,
      zoomResult: zoom2Result
    });

    // ==========================================
    // STEP 4: Verify both shifts share the same meeting
    // ==========================================
    console.log('[Test] Step 4: Verification...');

    // Re-read to get final state
    const shift1Final = await shift1Ref.get();
    const shift2Final = await shift2Ref.get();

    const meeting1 = shift1Final.data()?.zoom_meeting_id;
    const meeting2 = shift2Final.data()?.zoom_meeting_id;

    results.verification = {
      teacher1_meeting: meeting1,
      teacher2_meeting: meeting2,
      same_meeting: meeting1 === meeting2,
      teacher1_breakout: shift1Final.data()?.breakoutRoomName,
      teacher2_breakout: shift2Final.data()?.breakoutRoomName,
    };

    // Get breakout rooms from Zoom
    if (meeting2) {
      try {
        const meetingResp = await fetch(
          `https://api.zoom.us/v2/meetings/${meeting2}`,
          { headers: { Authorization: `Bearer ${token}` } }
        );
        const meetingData = await meetingResp.json();
        results.verification.breakout_rooms = meetingData.settings?.breakout_room?.rooms?.map(r => ({
          name: r.name,
          participants: r.participants
        })) || [];
      } catch (e) {
        results.verification.error = e.message;
      }
    }

    console.log('[Test] Complete!');
    return { success: true, results };

  } catch (error) {
    console.error('[Test] Error:', error);
    results.errors.push(error.message);
    return { success: false, error: error.message, results };
  }
});
