#!/usr/bin/env node
require('dotenv').config();
const { getZoomConfig } = require('./services/zoom/config');

async function getAccessToken() {
    const { accountId, clientId, clientSecret } = getZoomConfig();
    const tokenUrl = new URL('https://zoom.us/oauth/token');
    tokenUrl.searchParams.set('grant_type', 'account_credentials');
    tokenUrl.searchParams.set('account_id', accountId);

    const basic = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
    const resp = await fetch(tokenUrl.toString(), {
        method: 'POST',
        headers: {
            Authorization: `Basic ${basic}`,
        },
    });

    if (!resp.ok) {
        const text = await resp.text();
        throw new Error(`Zoom token request failed: ${text}`);
    }

    const json = await resp.json();
    return json.access_token;
}

async function runTest() {
    try {
        const token = await getAccessToken();
        const { hostUser } = getZoomConfig();
        const email = hostUser || 'nenenane2@gmail.com';

        console.log(`Starting Zoom scope verification for ${email}...`);

        // 1. Create a meeting
        console.log('1. Attempting to create a meeting...');
        const createResp = await fetch(`https://api.zoom.us/v2/users/${encodeURIComponent(email)}/meetings`, {
            method: 'POST',
            headers: {
                Authorization: `Bearer ${token}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                topic: 'Scope Verification Test',
                type: 2,
                start_time: new Date(Date.now() + 86400000).toISOString(), // Tomorrow
                duration: 30,
                settings: {
                    host_video: true,
                    participant_video: true,
                },
            }),
        });

        if (!createResp.ok) {
            const text = await createResp.text();
            throw new Error(`Create meeting failed: ${text}`);
        }

        const meeting = await createResp.json();
        const meetingId = meeting.id;
        console.log(`✅ Meeting created: ${meetingId}`);

        // 2. Update the meeting (this is what failed before)
        console.log('2. Attempting to update the meeting (testing new scopes)...');
        const updateResp = await fetch(`https://api.zoom.us/v2/meetings/${meetingId}`, {
            method: 'PATCH',
            headers: {
                Authorization: `Bearer ${token}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                topic: 'Scope Verification Test - UPDATED',
                settings: {
                    join_before_host: true,
                },
            }),
        });

        if (!updateResp.ok) {
            const text = await updateResp.text();
            console.error(`❌ Update meeting failed: ${text}`);
        } else {
            console.log('✅ Meeting updated successfully! Scopes are working.');
        }

        // 3. Cleanup
        console.log('3. Cleaning up test meeting...');
        await fetch(`https://api.zoom.us/v2/meetings/${meetingId}`, {
            method: 'DELETE',
            headers: {
                Authorization: `Bearer ${token}`,
            },
        });
        console.log('✅ Cleanup complete.');

    } catch (error) {
        console.error('❌ Test failed:', error.message);
    }
    process.exit(0);
}

runTest();
