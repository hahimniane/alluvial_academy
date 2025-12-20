#!/usr/bin/env node
/**
 * Comprehensive Zoom Host Allocation Test
 * 
 * Tests the fill-first host allocation strategy with various scenarios:
 * 1. Basic host selection with multiple hosts
 * 2. Fill-first strategy verification
 * 3. Capacity limit enforcement
 * 4. Non-overlapping shift handling
 * 
 * Run locally (requires gcloud auth):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json node test-host-allocation.js
 * 
 * Or deploy as Cloud Function and call via HTTP.
 */

require('dotenv').config();

const admin = require('firebase-admin');

// Check if we're running inside Cloud Functions (admin already initialized)
// or locally (need to initialize with credentials)
if (!admin.apps.length) {
    // Try to initialize - will use GOOGLE_APPLICATION_CREDENTIALS env var if set
    // or Application Default Credentials (from gcloud auth application-default login)
    try {
        admin.initializeApp({
            projectId: process.env.GCLOUD_PROJECT || 'alluwal-academy',
        });
        console.log('Firebase Admin initialized successfully');
    } catch (e) {
        console.error('Failed to initialize Firebase Admin:', e.message);
        console.error('\nTo run locally, either:');
        console.error('1. Run: gcloud auth application-default login');
        console.error('2. Set GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json');
        process.exit(1);
    }
}

const db = admin.firestore();

// Import the functions we're testing
const {
    findAvailableHost,
    getActiveHosts,
    countOverlappingMeetings,
    ZOOM_HOSTS_COLLECTION
} = require('./services/zoom/hosts');

// Test configuration
const TEST_PREFIX = 'TEST_HOST_ALLOCATION_';
const TEST_TEACHER_IDS = [
    `${TEST_PREFIX}teacher_1`,
    `${TEST_PREFIX}teacher_2`,
    `${TEST_PREFIX}teacher_3`,
];

// Colors for console output
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
};

const log = {
    info: (msg) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
    success: (msg) => console.log(`${colors.green}✅${colors.reset} ${msg}`),
    fail: (msg) => console.log(`${colors.red}❌${colors.reset} ${msg}`),
    warn: (msg) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
    header: (msg) => console.log(`\n${colors.bright}${colors.cyan}${'='.repeat(60)}${colors.reset}\n${colors.bright}${msg}${colors.reset}\n${colors.cyan}${'='.repeat(60)}${colors.reset}`),
    subheader: (msg) => console.log(`\n${colors.yellow}--- ${msg} ---${colors.reset}`),
};

// Test results tracking
const results = {
    passed: 0,
    failed: 0,
    tests: [],
};

function recordResult(name, passed, details = '') {
    results.tests.push({ name, passed, details });
    if (passed) {
        results.passed++;
        log.success(`${name}${details ? `: ${details}` : ''}`);
    } else {
        results.failed++;
        log.fail(`${name}${details ? `: ${details}` : ''}`);
    }
}

// Helper functions
async function createTestHost(email, priority, maxConcurrentMeetings, displayName) {
    const hostData = {
        email: email.toLowerCase(),
        display_name: displayName || `Test Host ${priority + 1}`,
        max_concurrent_meetings: maxConcurrentMeetings,
        priority: priority,
        is_active: true,
        notes: 'Test host - will be cleaned up',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        created_by: 'test-script',
    };

    const docRef = await db.collection(ZOOM_HOSTS_COLLECTION).add(hostData);
    log.info(`Created test host: ${email} (ID: ${docRef.id}, Priority: ${priority}, Max: ${maxConcurrentMeetings})`);
    return docRef.id;
}

async function createTestShift(teacherId, startTime, endTime, hostEmail = null, hasZoomMeeting = true) {
    const shiftData = {
        teacher_id: teacherId,
        shift_start: admin.firestore.Timestamp.fromDate(startTime),
        shift_end: admin.firestore.Timestamp.fromDate(endTime),
        status: 'scheduled',
        shift_category: 'teaching',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        // Mock Zoom meeting data
        zoom_meeting_id: hasZoomMeeting ? `${TEST_PREFIX}meeting_${Date.now()}` : null,
        zoom_encrypted_join_url: hasZoomMeeting ? 'encrypted_test_url' : null,
        zoom_host_email: hostEmail,
    };

    const docRef = await db.collection('teaching_shifts').add(shiftData);
    log.info(`Created test shift: ${docRef.id} (Teacher: ${teacherId.replace(TEST_PREFIX, '')}, Host: ${hostEmail || 'none'})`);
    return docRef.id;
}

async function cleanupTestData() {
    log.subheader('Cleaning up test data');

    // Delete test hosts
    const hostsSnapshot = await db.collection(ZOOM_HOSTS_COLLECTION)
        .where('created_by', '==', 'test-script')
        .get();

    for (const doc of hostsSnapshot.docs) {
        await doc.ref.delete();
    }
    log.info(`Deleted ${hostsSnapshot.size} test host(s)`);

    // Delete test shifts
    const shiftsSnapshot = await db.collection('teaching_shifts')
        .where('teacher_id', 'in', TEST_TEACHER_IDS)
        .get();

    for (const doc of shiftsSnapshot.docs) {
        await doc.ref.delete();
    }
    log.info(`Deleted ${shiftsSnapshot.size} test shift(s)`);
}

// Test time helpers
function getTestTimeSlot(hoursFromNow = 24, durationMinutes = 60) {
    const start = new Date();
    start.setHours(start.getHours() + hoursFromNow, 0, 0, 0);
    const end = new Date(start.getTime() + durationMinutes * 60 * 1000);
    return { start, end };
}

function getOverlappingTimeSlot(start, end) {
    // Returns a slot that overlaps with the given slot (shifted by 30 minutes)
    const newStart = new Date(start.getTime() + 30 * 60 * 1000);
    const newEnd = new Date(end.getTime() + 30 * 60 * 1000);
    return { start: newStart, end: newEnd };
}

function getNonOverlappingTimeSlot(end, gapMinutes = 30) {
    // Returns a slot that doesn't overlap (starts after gap)
    const newStart = new Date(end.getTime() + gapMinutes * 60 * 1000);
    const newEnd = new Date(newStart.getTime() + 60 * 60 * 1000);
    return { start: newStart, end: newEnd };
}

// ============================================================
// TEST SCENARIOS
// ============================================================

/**
 * Scenario 1: Basic Host Selection
 * - 2 hosts with max=1 each
 * - 2 overlapping shifts
 * Expected: Each shift gets a different host
 */
async function testBasicHostSelection() {
    log.header('Scenario 1: Basic Host Selection');
    log.info('Setup: 2 hosts (max=1 each), 2 overlapping shifts');

    // Create test hosts
    const hostA = await createTestHost(`${TEST_PREFIX}host_a@test.com`, 0, 1, 'Test Host A');
    const hostB = await createTestHost(`${TEST_PREFIX}host_b@test.com`, 1, 1, 'Test Host B');

    const slot1 = getTestTimeSlot(24);
    const slot2 = getOverlappingTimeSlot(slot1.start, slot1.end);

    // First shift - should get Host A (priority 0)
    const result1 = await findAvailableHost(slot1.start, slot1.end);

    if (!result1.host) {
        recordResult('First shift host assignment', false, 'No host returned');
        return;
    }

    recordResult('First shift host assignment', true, `Assigned to ${result1.host.email}`);

    // Simulate creating the shift with Host A
    await createTestShift(TEST_TEACHER_IDS[0], slot1.start, slot1.end, result1.host.email);

    // Second shift - should get Host B (since Host A is at capacity)
    const result2 = await findAvailableHost(slot2.start, slot2.end);

    if (!result2.host) {
        recordResult('Second shift host assignment', false, 'No host returned');
        return;
    }

    recordResult('Second shift host assignment', true, `Assigned to ${result2.host.email}`);

    // Verify different hosts were assigned
    const differentHosts = result1.host.email !== result2.host.email;
    recordResult('Different hosts for overlapping shifts', differentHosts,
        differentHosts ? 'Hosts correctly distributed' : `Both used ${result1.host.email}`);
}

/**
 * Scenario 2: Fill-First Strategy
 * - Host A (priority 0, max=2), Host B (priority 1, max=2)
 * - 3 overlapping shifts
 * Expected: First 2 → Host A, 3rd → Host B
 */
async function testFillFirstStrategy() {
    log.header('Scenario 2: Fill-First Strategy');
    log.info('Setup: Host A (priority=0, max=2), Host B (priority=1, max=2), 3 overlapping shifts');

    // Clean previous test data first
    await cleanupTestData();

    // Create test hosts
    await createTestHost(`${TEST_PREFIX}host_fill_a@test.com`, 0, 2, 'Fill-First Host A');
    await createTestHost(`${TEST_PREFIX}host_fill_b@test.com`, 1, 2, 'Fill-First Host B');

    const baseSlot = getTestTimeSlot(48);
    const assignedHosts = [];

    // Create 3 overlapping shifts
    for (let i = 0; i < 3; i++) {
        const slot = i === 0 ? baseSlot : getOverlappingTimeSlot(
            new Date(baseSlot.start.getTime() + i * 15 * 60 * 1000),
            new Date(baseSlot.end.getTime() + i * 15 * 60 * 1000)
        );

        const result = await findAvailableHost(slot.start, slot.end);

        if (!result.host) {
            recordResult(`Shift ${i + 1} host assignment`, false, 'No host returned');
            return;
        }

        assignedHosts.push(result.host.email);
        log.info(`Shift ${i + 1}: Assigned to ${result.host.email}`);

        // Create the shift
        await createTestShift(TEST_TEACHER_IDS[i % 3], slot.start, slot.end, result.host.email);
    }

    // Verify fill-first: first 2 should be Host A, 3rd should be Host B
    const hostACount = assignedHosts.filter(h => h.includes('host_fill_a')).length;
    const hostBCount = assignedHosts.filter(h => h.includes('host_fill_b')).length;

    recordResult('Fill-first: Host A used first', hostACount >= 2,
        `Host A used ${hostACount} times (expected 2)`);
    recordResult('Fill-first: Host B used for overflow', hostBCount >= 1,
        `Host B used ${hostBCount} times (expected 1)`);
    recordResult('Fill-first: Correct distribution', hostACount === 2 && hostBCount === 1,
        `Distribution: Host A=${hostACount}, Host B=${hostBCount}`);
}

/**
 * Scenario 3: Capacity Exhaustion
 * - 1 host with max=1
 * - Try to create 2 overlapping shifts
 * Expected: First succeeds, second fails with NO_AVAILABLE_HOST
 */
async function testCapacityExhaustion() {
    log.header('Scenario 3: Capacity Exhaustion');
    log.info('Setup: 1 host (max=1), 2 overlapping shifts');

    // Clean previous test data
    await cleanupTestData();

    // Create single test host
    await createTestHost(`${TEST_PREFIX}host_cap@test.com`, 0, 1, 'Capacity Test Host');

    const baseSlot = getTestTimeSlot(72);
    const overlapSlot = getOverlappingTimeSlot(baseSlot.start, baseSlot.end);

    // First shift - should succeed
    const result1 = await findAvailableHost(baseSlot.start, baseSlot.end);

    if (!result1.host) {
        recordResult('First shift (within capacity)', false, 'No host returned');
        return;
    }

    recordResult('First shift (within capacity)', true, `Assigned to ${result1.host.email}`);

    // Create the shift
    await createTestShift(TEST_TEACHER_IDS[0], baseSlot.start, baseSlot.end, result1.host.email);

    // Second shift - should fail with error
    const result2 = await findAvailableHost(overlapSlot.start, overlapSlot.end);

    const secondFailed = result2.host === null && result2.error?.code === 'NO_AVAILABLE_HOST';
    recordResult('Second shift (exceeds capacity)', secondFailed,
        secondFailed ? `Correctly rejected: ${result2.error?.message}` : 'Should have been rejected');

    if (result2.error?.alternatives) {
        log.info(`Alternative times suggested: ${result2.error.alternatives.length} options`);
    }
}

/**
 * Scenario 4: Non-Overlapping Shifts
 * - 1 host with max=1
 * - 2 non-overlapping shifts
 * Expected: Both succeed using the same host
 */
async function testNonOverlappingShifts() {
    log.header('Scenario 4: Non-Overlapping Shifts');
    log.info('Setup: 1 host (max=1), 2 sequential (non-overlapping) shifts');

    // Clean previous test data
    await cleanupTestData();

    // Create single test host
    await createTestHost(`${TEST_PREFIX}host_seq@test.com`, 0, 1, 'Sequential Test Host');

    const slot1 = getTestTimeSlot(96);
    const slot2 = getNonOverlappingTimeSlot(slot1.end, 60); // 1 hour gap

    // First shift
    const result1 = await findAvailableHost(slot1.start, slot1.end);

    if (!result1.host) {
        recordResult('First sequential shift', false, 'No host returned');
        return;
    }

    recordResult('First sequential shift', true, `Assigned to ${result1.host.email}`);
    await createTestShift(TEST_TEACHER_IDS[0], slot1.start, slot1.end, result1.host.email);

    // Second shift (non-overlapping)
    const result2 = await findAvailableHost(slot2.start, slot2.end);

    if (!result2.host) {
        recordResult('Second sequential shift', false, 'No host returned');
        return;
    }

    recordResult('Second sequential shift', true, `Assigned to ${result2.host.email}`);

    // Both should use the same host
    const sameHost = result1.host.email === result2.host.email;
    recordResult('Same host for non-overlapping shifts', sameHost,
        sameHost ? 'Both shifts correctly use same host' : 'Unexpected: different hosts used');
}

/**
 * Scenario 5: Concurrent Shift Creation (Stress Test)
 * - 2 hosts with max=2 each
 * - Create 4 shifts "concurrently" (as fast as possible)
 * Expected: All 4 succeed, distributed across hosts
 */
async function testConcurrentCreation() {
    log.header('Scenario 5: Concurrent Shift Creation (Stress Test)');
    log.info('Setup: 2 hosts (max=2 each), 4 overlapping shifts created rapidly');

    // Clean previous test data
    await cleanupTestData();

    // Create test hosts
    await createTestHost(`${TEST_PREFIX}host_conc_a@test.com`, 0, 2, 'Concurrent Host A');
    await createTestHost(`${TEST_PREFIX}host_conc_b@test.com`, 1, 2, 'Concurrent Host B');

    const baseSlot = getTestTimeSlot(120);

    // Create 4 overlapping time slots
    const slots = [];
    for (let i = 0; i < 4; i++) {
        slots.push({
            start: new Date(baseSlot.start.getTime() + i * 10 * 60 * 1000),
            end: new Date(baseSlot.end.getTime() + i * 10 * 60 * 1000),
        });
    }

    // Find hosts for all 4 shifts (simulating rapid requests)
    const hostAssignments = [];

    for (let i = 0; i < 4; i++) {
        const slot = slots[i];
        const result = await findAvailableHost(slot.start, slot.end);

        if (result.host) {
            hostAssignments.push(result.host.email);
            await createTestShift(TEST_TEACHER_IDS[i % 3], slot.start, slot.end, result.host.email);
            log.info(`Shift ${i + 1}: Assigned to ${result.host.email}`);
        } else {
            log.warn(`Shift ${i + 1}: No host available - ${result.error?.message}`);
            hostAssignments.push(null);
        }
    }

    // Count results
    const successCount = hostAssignments.filter(h => h !== null).length;
    const hostACnt = hostAssignments.filter(h => h && h.includes('host_conc_a')).length;
    const hostBCnt = hostAssignments.filter(h => h && h.includes('host_conc_b')).length;

    recordResult('All 4 shifts assigned', successCount === 4,
        `${successCount}/4 shifts assigned successfully`);
    recordResult('Load balanced across hosts', hostACnt === 2 && hostBCnt === 2,
        `Host A: ${hostACnt}, Host B: ${hostBCnt} (expected 2 each)`);
}

// ============================================================
// MAIN TEST RUNNER
// ============================================================

async function main() {
    console.log('\n');
    log.header('🧪 ZOOM HOST ALLOCATION TEST SUITE');
    console.log(`Started at: ${new Date().toISOString()}`);
    console.log(`Firebase Project: ${process.env.GCLOUD_PROJECT || 'alluwal-academy'}`);

    try {
        // Clean up any leftover test data from previous runs
        await cleanupTestData();

        // Run all test scenarios
        await testBasicHostSelection();
        await testFillFirstStrategy();
        await testCapacityExhaustion();
        await testNonOverlappingShifts();
        await testConcurrentCreation();

        // Final cleanup
        await cleanupTestData();

        // Print summary
        log.header('📊 TEST RESULTS SUMMARY');
        console.log(`\nTotal Tests: ${results.passed + results.failed}`);
        console.log(`${colors.green}Passed: ${results.passed}${colors.reset}`);
        console.log(`${colors.red}Failed: ${results.failed}${colors.reset}`);

        if (results.failed > 0) {
            console.log(`\n${colors.red}Failed tests:${colors.reset}`);
            results.tests.filter(t => !t.passed).forEach(t => {
                console.log(`  - ${t.name}: ${t.details}`);
            });
        }

        console.log(`\nCompleted at: ${new Date().toISOString()}\n`);

        process.exit(results.failed > 0 ? 1 : 0);

    } catch (error) {
        log.fail(`Test suite error: ${error.message}`);
        console.error(error.stack);

        // Try to clean up on error
        try {
            await cleanupTestData();
        } catch (cleanupError) {
            log.warn(`Cleanup failed: ${cleanupError.message}`);
        }

        process.exit(1);
    }
}

main();
