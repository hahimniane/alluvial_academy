/**
 * Script to schedule Hub Meetings for all active/scheduled shifts
 * that don't have hubMeetingId assigned.
 * 
 * Run with: node trigger_hub_scheduler.js
 * 
 * Current Time: 2024-12-24 11:58 EST (UTC-5)
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, 'service-account.json');
try {
    admin.initializeApp({
        credential: admin.credential.cert(require(serviceAccountPath))
    });
} catch (e) {
    // Already initialized or using default credentials
    if (!admin.apps.length) {
        admin.initializeApp();
    }
}

const { scheduleHubMeetings } = require('./services/shifts/schedule_hubs');

async function main() {
    console.log('='.repeat(60));
    console.log('Hub Meeting Scheduler');
    console.log('='.repeat(60));
    console.log('');

    const now = new Date();
    console.log(`Current Time (Local): ${now.toLocaleString()}`);
    console.log(`Current Time (UTC): ${now.toUTCString()}`);
    console.log('');

    // First, let's see what shifts need hub meetings
    const db = admin.firestore();
    const nowTimestamp = admin.firestore.Timestamp.fromDate(now);

    console.log('Checking for shifts without hub meetings...');
    console.log('');

    const shiftsSnapshot = await db.collection('teaching_shifts')
        .where('status', 'in', ['scheduled', 'active'])
        .where('shift_start', '>=', nowTimestamp)
        .orderBy('shift_start', 'asc')
        .get();

    const shiftsNeedingHub = [];
    const shiftsWithHub = [];

    shiftsSnapshot.forEach(doc => {
        const data = doc.data();
        if (!data.hubMeetingId) {
            shiftsNeedingHub.push({ id: doc.id, ...data });
        } else {
            shiftsWithHub.push({ id: doc.id, ...data });
        }
    });

    console.log(`Total active/scheduled shifts (future): ${shiftsSnapshot.size}`);
    console.log(`  - Already have hub: ${shiftsWithHub.length}`);
    console.log(`  - Need hub assignment: ${shiftsNeedingHub.length}`);
    console.log('');

    if (shiftsNeedingHub.length === 0) {
        console.log('✓ All shifts already have hub meetings assigned!');
        process.exit(0);
    }

    console.log('Shifts needing hub assignment:');
    console.log('-'.repeat(60));

    for (const shift of shiftsNeedingHub) {
        const startDate = shift.shift_start.toDate();
        console.log(`  ${shift.teacher_name || 'Unknown Teacher'}`);
        console.log(`    ID: ${shift.id}`);
        console.log(`    Time: ${startDate.toLocaleString()}`);
        console.log(`    Students: ${(shift.student_names || []).join(', ') || 'None'}`);
        console.log('');
    }

    console.log('-'.repeat(60));
    console.log('');
    console.log('Running scheduleHubMeetings()...');
    console.log('');

    try {
        const result = await scheduleHubMeetings();
        console.log('');
        console.log('✓ Hub scheduling completed!');
        if (result) {
            console.log('Result:', JSON.stringify(result, null, 2));
        }
    } catch (error) {
        console.error('✗ Error running hub scheduler:', error);
        process.exit(1);
    }

    // Verify the results
    console.log('');
    console.log('Verifying results...');

    const verifySnapshot = await db.collection('teaching_shifts')
        .where('status', 'in', ['scheduled', 'active'])
        .where('shift_start', '>=', nowTimestamp)
        .get();

    let nowWithHub = 0;
    let stillWithoutHub = 0;

    verifySnapshot.forEach(doc => {
        const data = doc.data();
        if (data.hubMeetingId) {
            nowWithHub++;
        } else {
            stillWithoutHub++;
        }
    });

    console.log('');
    console.log('After scheduling:');
    console.log(`  - With hub: ${nowWithHub}`);
    console.log(`  - Without hub: ${stillWithoutHub}`);
    console.log('');
    console.log('='.repeat(60));
    console.log('Done!');

    process.exit(0);
}

main().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});
