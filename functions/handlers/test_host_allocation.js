/**
 * Zoom Host Allocation Test - Cloud Function Version
 * 
 * Deploy and call via HTTP to test host allocation in production.
 * 
 * Deploy: firebase deploy --only functions:testHostAllocation
 * Call: curl https://us-central1-alluwal-academy.cloudfunctions.net/testHostAllocation
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');

// Lazy-load Firestore to avoid initialization order issues
const getDb = () => admin.firestore();

// Import the functions we're testing
const {
    findAvailableHost,
    ZOOM_HOSTS_COLLECTION
} = require('../services/zoom/hosts');

const TEST_PREFIX = 'TEST_CF_ALLOCATION_';
const TEST_TEACHER_IDS = [
    `${TEST_PREFIX}teacher_1`,
    `${TEST_PREFIX}teacher_2`,
    `${TEST_PREFIX}teacher_3`,
];

// Helper functions
async function createTestHost(email, priority, maxConcurrentMeetings, displayName) {
    const db = getDb();
    const hostData = {
        email: email.toLowerCase(),
        display_name: displayName,
        max_concurrent_meetings: maxConcurrentMeetings,
        priority: priority,
        is_active: true,
        notes: 'CF Test host',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        created_by: 'test-cf',
    };
    const docRef = await db.collection(ZOOM_HOSTS_COLLECTION).add(hostData);
    return { id: docRef.id, ...hostData };
}

async function createTestShift(teacherId, startTime, endTime, hostEmail) {
    const db = getDb();
    const shiftData = {
        teacher_id: teacherId,
        shift_start: admin.firestore.Timestamp.fromDate(startTime),
        shift_end: admin.firestore.Timestamp.fromDate(endTime),
        status: 'scheduled',
        shift_category: 'teaching',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        zoom_meeting_id: `${TEST_PREFIX}meeting_${Date.now()}`,
        zoom_encrypted_join_url: 'test_encrypted_url',
        zoom_host_email: hostEmail,
    };
    const docRef = await db.collection('teaching_shifts').add(shiftData);
    return docRef.id;
}

async function cleanupTestData() {
    const db = getDb();
    const hostsSnap = await db.collection(ZOOM_HOSTS_COLLECTION)
        .where('created_by', '==', 'test-cf').get();
    const hostDeletes = hostsSnap.docs.map(d => d.ref.delete());

    const shiftsSnap = await db.collection('teaching_shifts')
        .where('teacher_id', 'in', TEST_TEACHER_IDS).get();
    const shiftDeletes = shiftsSnap.docs.map(d => d.ref.delete());

    await Promise.all([...hostDeletes, ...shiftDeletes]);
    return { hostsDeleted: hostsSnap.size, shiftsDeleted: shiftsSnap.size };
}

function getTimeSlot(hoursFromNow, durationMinutes = 60) {
    const start = new Date();
    start.setHours(start.getHours() + hoursFromNow, 0, 0, 0);
    const end = new Date(start.getTime() + durationMinutes * 60 * 1000);
    return { start, end };
}

// Test Scenarios
async function runTests() {
    const results = {
        passed: 0,
        failed: 0,
        tests: [],
        shiftAssignments: [],
        availableHosts: [],
    };

    const db = getDb();
    const hostsSnap = await db.collection(ZOOM_HOSTS_COLLECTION)
        .where('is_active', '==', true)
        .orderBy('priority', 'asc')
        .get();

    results.availableHosts = hostsSnap.docs.map(doc => {
        const data = doc.data();
        return {
            email: data.email,
            maxConcurrentMeetings: data.max_concurrent_meetings || 1,
            priority: data.priority,
        };
    });

    const totalSystemCapacity = results.availableHosts.reduce((sum, h) => sum + h.maxConcurrentMeetings, 0);

    function record(name, passed, details) {
        results.tests.push({ name, passed, details });
        passed ? results.passed++ : results.failed++;
    }

    function logShiftAssignment(shiftNum, scenario, startTime, endTime, hostEmail, status) {
        results.shiftAssignments.push({
            shift: shiftNum,
            scenario,
            timeSlot: `${startTime.toISOString().slice(11, 16)} - ${endTime.toISOString().slice(11, 16)}`,
            date: startTime.toISOString().slice(0, 10),
            assignedHost: hostEmail || 'NONE',
            status: status,
        });
    }

    // --- Scenario 1: Saturation & Priority ---
    // Verify we can fill all available slots and they are assigned in priority order
    try {
        const baseSlot = getTimeSlot(48); // Use 48h from now to avoid conflicts with previous runs if any
        const assignments = [];

        for (let i = 0; i < totalSystemCapacity; i++) {
            // All shifts perfectly overlap
            const slot = { start: baseSlot.start, end: baseSlot.end };

            const result = await findAvailableHost(slot.start, slot.end);

            if (result.host) {
                await createTestShift(TEST_TEACHER_IDS[i % 3], slot.start, slot.end, result.host.email);
                logShiftAssignment(i + 1, 'Saturation (Fill System)', slot.start, slot.end, result.host.email, 'ASSIGNED');
                assignments.push(result.host.email);
            } else {
                logShiftAssignment(i + 1, 'Saturation (Fill System)', slot.start, slot.end, null, `UNEXPECTED FAILURE: ${result.error?.code}`);
            }
        }

        // Verify unique hosts were used roughly according to capacity
        const uniqueHosts = new Set(assignments);
        record('System Saturation',
            assignments.length === totalSystemCapacity && uniqueHosts.size > 0,
            `Assigned ${assignments.length}/${totalSystemCapacity} shifts. Used ${uniqueHosts.size} hosts.`);

        // Verify Priority (First assignment should be to highest priority host)
        if (assignments.length > 0 && results.availableHosts.length > 0) {
            const firstHost = results.availableHosts[0].email;
            const wasFirstHostUsed = assignments.includes(firstHost);
            record('Priority Check', wasFirstHostUsed, `Highest priority host (${firstHost}) was ${wasFirstHostUsed ? '' : 'NOT '}used.`);
        }

    } catch (e) {
        record('Saturation Test', false, e.message);
    }

    // --- Scenario 2: Capacity Exhaustion (Overflow) ---
    // Verify that one more overlapping shift is rejected
    try {
        const baseSlot = getTimeSlot(48); // Same slot as Scenario 1
        const result = await findAvailableHost(baseSlot.start, baseSlot.end);

        if (!result.host) {
            logShiftAssignment('Overflow', 'Capacity Exhaustion', baseSlot.start, baseSlot.end, null, `REJECTED: ${result.error?.code}`);
            record('Capacity Limit', true, 'Correctly rejected assignment after system saturation.');
        } else {
            logShiftAssignment('Overflow', 'Capacity Exhaustion', baseSlot.start, baseSlot.end, result.host.email, 'ASSIGNED (UNEXPECTED)');
            record('Capacity Limit', false, `Unexpectedly assigned to ${result.host.email} despite saturation.`);
        }
    } catch (e) {
        record('Capacity Test', false, e.message);
    }

    // --- Scenario 3: Non-Overlapping Reuse ---
    // Verify that a shift at a different time works and uses the primary host again
    try {
        // 3 hours after base slot (completely clear of previous shifts)
        const cleanSlot = {
            start: new Date(getTimeSlot(48).end.getTime() + 3 * 60 * 60 * 1000),
            end: new Date(getTimeSlot(48).end.getTime() + 4 * 60 * 60 * 1000)
        };

        const result = await findAvailableHost(cleanSlot.start, cleanSlot.end);

        if (result.host) {
            await createTestShift(TEST_TEACHER_IDS[0], cleanSlot.start, cleanSlot.end, result.host.email);
            logShiftAssignment('Reuse', 'Non-Overlapping', cleanSlot.start, cleanSlot.end, result.host.email, 'ASSIGNED');

            // Should be the highest priority host ideally
            const bestHost = results.availableHosts[0].email;
            record('Host Reuse',
                result.host.email === bestHost,
                `Assigned to ${result.host.email} (Expected high priority: ${bestHost})`);
        } else {
            logShiftAssignment('Reuse', 'Non-Overlapping', cleanSlot.start, cleanSlot.end, null, `REJECTED: ${result.error?.code}`);
            record('Host Reuse', false, 'Failed to assign non-overlapping shift.');
        }
    } catch (e) {
        record('Reuse Test', false, e.message);
    }

    return results;
}

// HTTP endpoint
const testHostAllocation = onRequest({ cors: true }, async (req, res) => {
    console.log('[Test] Starting host allocation tests...');

    try {
        // Initial cleanup
        const preCleanup = await cleanupTestData();
        console.log(`[Test] Pre-cleanup: ${JSON.stringify(preCleanup)}`);

        // Run tests
        const results = await runTests();

        // Final cleanup
        const postCleanup = await cleanupTestData();
        console.log(`[Test] Post-cleanup: ${JSON.stringify(postCleanup)}`);

        res.json({
            success: true,
            summary: `${results.passed}/${results.passed + results.failed} tests passed`,
            results: results,
        });

    } catch (error) {
        console.error('[Test] Error:', error);

        // Try cleanup on error
        try { await cleanupTestData(); } catch (e) { /* ignore */ }

        res.status(500).json({
            success: false,
            error: error.message,
        });
    }
});

// Debug Endpoint
const debugShifts = onRequest({ cors: true }, async (req, res) => {
    try {
        const db = getDb();
        const shiftIds = ['Til6da36gRut3jgJPdzT', 's0YEHzBlLYDbs7Hh7RW8', 'XaFXFxm4Wx2b8TfZ4ibU'];
        const results = [];

        for (const id of shiftIds) {
            const doc = await db.collection('teaching_shifts').doc(id).get();
            if (!doc.exists) {
                results.push({ id, status: 'NOT FOUND' });
                continue;
            }
            const data = doc.data();
            results.push({
                id: doc.id,
                data: doc.data() // Return everything to check fields
            });
        }

        res.json({ success: true, results });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

module.exports = { testHostAllocation, debugShifts };
