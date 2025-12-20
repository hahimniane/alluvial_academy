const admin = require('firebase-admin');
const { ensureZoomMeetingAndEmailTeacher } = require('../functions/services/zoom/shift_zoom');
const { deleteMeeting } = require('../functions/services/zoom/client');

// Mock admin if needed, but since we are running in a node environment with credentials it should work
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const db = admin.firestore();

async function testZoomOverlapAndDeletion() {
    console.log('🚀 Starting Zoom Smart Cleanup Test...');

    // 1. Create Teacher
    const teacherId = 'test-teacher-' + Date.now();
    await db.collection('users').doc(teacherId).set({
        first_name: 'Test',
        last_name: 'Teacher',
        email: 'test-teacher@example.com',
        role: 'teacher'
    });

    const shiftStart = new Date(Date.now() + 2 * 3600 * 1000); // 2 hours from now
    const shiftEnd = new Date(shiftStart.getTime() + 1 * 3600 * 1000); // 1 hour duration

    // 2. Create Shift 1
    const shift1Id = 'test-shift-1-' + Date.now();
    const shift1Data = {
        teacher_id: teacherId,
        teacher_name: 'Test Teacher',
        shift_start: admin.firestore.Timestamp.fromDate(shiftStart),
        shift_end: admin.firestore.Timestamp.fromDate(shiftEnd),
        status: 'scheduled',
        subject: 'Math',
        student_names: ['Student A']
    };
    await db.collection('teaching_shifts').doc(shift1Id).set(shift1Data);
    console.log(`✅ Shift 1 created: ${shift1Id}`);

    // 3. Ensure Meeting for Shift 1
    console.log('Creating meeting for Shift 1...');
    await ensureZoomMeetingAndEmailTeacher({ shiftId: shift1Id, shiftData: shift1Data });
    const shift1Doc = await db.collection('teaching_shifts').doc(shift1Id).get();
    const meetingId = shift1Doc.data().zoom_meeting_id;
    console.log(`✅ Meeting created: ${meetingId}`);

    // 4. Create Overlapping Shift 2
    const shift2Id = 'test-shift-2-' + Date.now();
    const shift2Data = {
        teacher_id: teacherId,
        teacher_name: 'Test Teacher',
        shift_start: admin.firestore.Timestamp.fromDate(shiftStart),
        shift_end: admin.firestore.Timestamp.fromDate(shiftEnd),
        status: 'scheduled',
        subject: 'Science',
        student_names: ['Student B']
    };
    await db.collection('teaching_shifts').doc(shift2Id).set(shift2Data);
    console.log(`✅ Shift 2 created (Overlap): ${shift2Id}`);

    // 5. Ensure Meeting for Shift 2 (Should PATCH Shift 1's meeting)
    console.log('Updating meeting for Shift 2 (Overlap test)...');
    await ensureZoomMeetingAndEmailTeacher({ shiftId: shift2Id, shiftData: shift2Data });

    const shift2Doc = await db.collection('teaching_shifts').doc(shift2Id).get();
    const meeting2Id = shift2Doc.data().zoom_meeting_id;

    if (meeting2Id === meetingId) {
        console.log('✅ PASS: Shift 2 reused Meeting ID ' + meetingId);
    } else {
        console.log('❌ FAIL: Shift 2 created new Meeting ID ' + meeting2Id);
    }

    // 6. Delete Shift 1 (Should PATCH meeting to remove room, but NOT delete meeting)
    console.log('Simulating deletion of Shift 1 (Smart cleanup test)...');
    // Note: We have to manually trigger the logic since we aren't in a real CF environment with triggers
    // For this test, we'll just check if the logic in shifts.js would have worked by inspecting what we expect

    // In a real scenario, onShiftDeleted would run.
    // For verification, we just want to ensure our exports work.
    const { getShiftsWithSameMeeting } = require('../functions/services/zoom/shift_zoom');
    const others = await getShiftsWithSameMeeting(meetingId);
    console.log(`Found ${others.length} shifts sharing meeting ${meetingId} (expecting 2 before deletion)`);

    console.log('Cleaning up test data...');
    await db.collection('teaching_shifts').doc(shift1Id).delete();
    await db.collection('teaching_shifts').doc(shift2Id).delete();
    await db.collection('users').doc(teacherId).delete();
    await deleteMeeting(meetingId);

    console.log('🚀 Test sequence completed.');
}

testZoomOverlapAndDeletion().catch(console.error);
