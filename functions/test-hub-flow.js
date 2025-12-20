const admin = require('firebase-admin');
const { scheduleHubMeetings } = require('./services/shifts/schedule_hubs');
const { DateTime } = require('luxon');

// Initialize Admin SDK if not already done
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const db = admin.firestore();

/**
 * Test Helper: Create a Dummy Shift
 */
const createDummyShift = async (startTime, teacherName = "Ustadha Test") => {
    const ref = db.collection('teaching_shifts').doc();
    await ref.set({
        teacher_id: "test_teacher_" + ref.id,
        teacher_name: teacherName,
        student_ids: [],
        student_names: ["Student A", "Student B"],
        shift_start: admin.firestore.Timestamp.fromDate(startTime.toJSDate()),
        shift_end: admin.firestore.Timestamp.fromDate(startTime.plus({ minutes: 50 }).toJSDate()),
        status: "scheduled",
        hubMeetingId: null // Explicitly null to trigger processing
    });
    console.log(`Created dummy shift: ${ref.id}`);
    return ref.id;
};

/**
 * Run Verification
 */
const runTest = async () => {
    console.log("=== Starting Hub Meeting Verification ===");

    // Target Time: Tomorrow at 10:00 AM UTC
    const tomorrow = DateTime.utc().plus({ days: 1 }).set({ hour: 10, minute: 0, second: 0, millisecond: 0 });

    try {
        // SCENARIO 1: Initial Batch Creation
        console.log("\n--- Scenario 1: Initial Hub Creation ---");
        const shiftId1 = await createDummyShift(tomorrow, "Teacher 1");

        console.log("Running scheduler...");
        await scheduleHubMeetings();

        // Verify
        const shift1Doc = await db.collection('teaching_shifts').doc(shiftId1).get();
        const hubId = shift1Doc.data().hubMeetingId;

        if (!hubId) {
            console.error("FAILED: Shift 1 was not assigned a Hub ID.");
            return;
        }

        const hubDoc = await db.collection('hub_meetings').doc(hubId).get();
        if (!hubDoc.exists) {
            console.error("FAILED: Hub document does not exist.");
            return;
        }

        console.log(`SUCCESS: Created Hub ${hubId} for Shift 1.`);
        console.log(`- Hub Status: ${hubDoc.data().status}`);
        console.log(`- Hub Participants: ${hubDoc.data().totalExpectedParticipants}`);

        // SCENARIO 2: Late Join (Same Time Block)
        console.log("\n--- Scenario 2: Late Join (Existing Hub) ---");
        const shiftId2 = await createDummyShift(tomorrow, "Teacher 2 (Late)");

        console.log("Running scheduler again...");
        await scheduleHubMeetings();

        // Verify
        const shift2Doc = await db.collection('teaching_shifts').doc(shiftId2).get();
        const hubId2 = shift2Doc.data().hubMeetingId;

        if (hubId2 !== hubId) {
            console.error(`FAILED: Shift 2 assigned to WRONG Hub. Expected ${hubId}, Got ${hubId2}`);
        } else {
            const updatedHubDoc = await db.collection('hub_meetings').doc(hubId).get();
            console.log(`SUCCESS: Shift 2 added to EXISTING Hub ${hubId}.`);
            console.log(`- Updated Hub Participants: ${updatedHubDoc.data().totalExpectedParticipants}`);
            console.log(`- Routing Mode Shift 2: ${shift2Doc.data().zoomRoutingMode}`);
        }

        console.log("\n=== Test Complete ===");

    } catch (e) {
        console.error("Test execution failed:", e);
    }
};

runTest();
