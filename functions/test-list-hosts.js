#!/usr/bin/env node
/**
 * Debug script to check Zoom hosts in Firestore directly
 */

require('dotenv').config();

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
    admin.initializeApp({
        projectId: process.env.GCLOUD_PROJECT || 'alluwal-academy',
    });
}

const db = admin.firestore();

async function main() {
    console.log('='.repeat(60));
    console.log('Zoom Hosts Firestore Debug');
    console.log('='.repeat(60));

    try {
        // Check ALL hosts (without filters)
        console.log('\n1. ALL zoom_hosts documents (no filters):');
        console.log('-'.repeat(40));
        const allHostsSnapshot = await db.collection('zoom_hosts').get();

        if (allHostsSnapshot.empty) {
            console.log('   ❌ No documents found in zoom_hosts collection!');
        } else {
            console.log(`   Found ${allHostsSnapshot.size} document(s):\n`);
            allHostsSnapshot.docs.forEach((doc, i) => {
                const data = doc.data();
                console.log(`   ${i + 1}. ID: ${doc.id}`);
                console.log(`      Email: ${data.email}`);
                console.log(`      Display Name: ${data.display_name}`);
                console.log(`      Is Active: ${data.is_active}`);
                console.log(`      Priority: ${data.priority}`);
                console.log(`      Created At: ${data.created_at?.toDate?.() || data.created_at}`);
                console.log('');
            });
        }

        // Check ACTIVE hosts only (what the API does)
        console.log('\n2. ACTIVE zoom_hosts (is_active == true):');
        console.log('-'.repeat(40));
        const activeHostsSnapshot = await db
            .collection('zoom_hosts')
            .where('is_active', '==', true)
            .orderBy('priority', 'asc')
            .get();

        if (activeHostsSnapshot.empty) {
            console.log('   ❌ No ACTIVE hosts found!');
            console.log('   This is why the list appears empty in the web app.');
            console.log('   Check if is_active field is set to true in your documents.');
        } else {
            console.log(`   Found ${activeHostsSnapshot.size} active host(s):\n`);
            activeHostsSnapshot.docs.forEach((doc, i) => {
                const data = doc.data();
                console.log(`   ${i + 1}. ${data.email} (Priority: ${data.priority})`);
            });
        }

        // Check using the getActiveHosts function
        console.log('\n3. Testing getActiveHosts() function:');
        console.log('-'.repeat(40));
        const { getActiveHosts } = require('./services/zoom/hosts');
        const hosts = await getActiveHosts();
        console.log(`   Returns ${hosts.length} host(s):`);
        hosts.forEach((host, i) => {
            console.log(`   ${i + 1}. ${host.email} (isEnvFallback: ${host.isEnvFallback})`);
        });

        console.log('\n' + '='.repeat(60));
        console.log('Debug complete!');
        console.log('='.repeat(60));

    } catch (error) {
        console.error('\n❌ Error:', error.message);
        console.error(error.stack);
    }

    process.exit(0);
}

main();
