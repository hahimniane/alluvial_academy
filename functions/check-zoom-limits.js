#!/usr/bin/env node
const admin = require('firebase-admin');
require('dotenv').config();

if (!admin.apps.length) {
    admin.initializeApp({
        projectId: process.env.GCLOUD_PROJECT || 'alluwal-academy'
    });
}

const db = admin.firestore();

async function checkFirestoreLimits() {
    console.log('='.repeat(60));
    console.log('Zoom Limit Check (via Firestore Proxy)');
    console.log('='.repeat(60));

    // Get start of today in UTC
    const now = new Date();
    const startOfToday = new Date(now);
    startOfToday.setUTCHours(0, 0, 0, 0);

    const hosts = [
        { email: 'nenenane2@gmail.com', name: 'Primary' },
        { email: 'support@alluwaleducationhub.org', name: 'Secondary' }
    ];

    for (const host of hosts) {
        console.log(`\nHost: ${host.name} (${host.email})`);
        console.log('-'.repeat(40));

        try {
            // Count total shifts with Zoom meetings created today
            const snapshot = await db.collection('teaching_shifts')
                .where('zoom_host_email', '==', host.email)
                .where('zoom_meeting_created_at', '>=', admin.firestore.Timestamp.fromDate(startOfToday))
                .get();

            const count = snapshot.size;
            console.log(`   Meetings created today: ${count}`);
            console.log(`   Estimated remaining: ${Math.max(0, 100 - count)} / 100`);

            if (count >= 100) {
                console.log(`   ⚠️  WARNING: Host has reached the 100 meetings/day limit!`);
            } else if (count >= 90) {
                console.log(`   ⚠️  CAUTION: Host is approaching the 100 meetings/day limit.`);
            } else {
                console.log(`   ✅  Limit status: OK`);
            }

            // Check for recent errors
            const errorSnapshot = await db.collection('teaching_shifts')
                .where('zoom_host_email', '==', host.email)
                .where('zoom_error_at', '>=', admin.firestore.Timestamp.fromDate(new Date(Date.now() - 4 * 60 * 60 * 1000))) // Last 4 hours
                .get();

            if (!errorSnapshot.empty) {
                console.log(`\n   Recent Errors (last 4 hours):`);
                errorSnapshot.docs.forEach(doc => {
                    const data = doc.data();
                    console.log(`   - [${data.zoom_error_at.toDate().toLocaleTimeString()}] ${data.zoom_error}`);
                });
            } else {
                console.log(`\n   No Zoom errors recorded in the last 4 hours.`);
            }

        } catch (error) {
            console.error(`   ❌ Error checking host ${host.email}: ${error.message}`);
        }
    }

    console.log('\n' + '='.repeat(60));
    console.log('Check complete!');
    console.log('='.repeat(60));
    process.exit(0);
}

checkFirestoreLimits();
