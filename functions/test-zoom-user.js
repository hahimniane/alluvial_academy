#!/usr/bin/env node
/**
 * Test script to check if we can fetch Zoom user information
 * Usage: node test-zoom-user.js [email]
 * 
 * This script loads credentials from .env and tests the Zoom API
 */

require('dotenv').config();

const testEmail = process.argv[2] || 'nenenane2@gmail.com';

console.log('='.repeat(60));
console.log('Zoom User Info Test Script');
console.log('='.repeat(60));
console.log(`Testing email: ${testEmail}\n`);

// Check environment variables
const requiredEnvVars = ['ZOOM_ACCOUNT_ID', 'ZOOM_CLIENT_ID', 'ZOOM_CLIENT_SECRET'];
const missingVars = requiredEnvVars.filter(v => !process.env[v]);

if (missingVars.length > 0) {
    console.error('❌ Missing required environment variables:');
    missingVars.forEach(v => console.error(`   - ${v}`));
    console.error('\nMake sure .env file exists with these variables.');
    process.exit(1);
}

console.log('✅ Found Zoom credentials in environment\n');

/**
 * Get OAuth access token using Server-to-Server OAuth (account credentials)
 */
async function getAccessToken() {
    const { ZOOM_ACCOUNT_ID, ZOOM_CLIENT_ID, ZOOM_CLIENT_SECRET } = process.env;

    const tokenUrl = new URL('https://zoom.us/oauth/token');
    tokenUrl.searchParams.set('grant_type', 'account_credentials');
    tokenUrl.searchParams.set('account_id', ZOOM_ACCOUNT_ID);

    const basic = Buffer.from(`${ZOOM_CLIENT_ID}:${ZOOM_CLIENT_SECRET}`).toString('base64');

    console.log('📡 Requesting access token...');

    const resp = await fetch(tokenUrl.toString(), {
        method: 'POST',
        headers: {
            Authorization: `Basic ${basic}`,
        },
    });

    if (!resp.ok) {
        const text = await resp.text().catch(() => '');
        throw new Error(`Token request failed (${resp.status}): ${text || resp.statusText}`);
    }

    const json = await resp.json();
    if (!json.access_token) {
        throw new Error('Token response missing access_token');
    }

    console.log('✅ Got access token\n');
    return json.access_token;
}

/**
 * Get user information from Zoom API
 */
async function getUserInfo(token, email) {
    console.log(`📡 Fetching user info for: ${email}...`);

    const resp = await fetch(`https://api.zoom.us/v2/users/${encodeURIComponent(email)}`, {
        method: 'GET',
        headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
        },
    });

    const json = await resp.json().catch(() => null);

    return {
        status: resp.status,
        ok: resp.ok,
        data: json,
    };
}

/**
 * List all users in the Zoom account
 */
async function listUsers(token) {
    console.log('📡 Listing all users in Zoom account...');

    const resp = await fetch('https://api.zoom.us/v2/users?status=active&page_size=100', {
        method: 'GET',
        headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
        },
    });

    const json = await resp.json().catch(() => null);

    return {
        status: resp.status,
        ok: resp.ok,
        data: json,
    };
}

/**
 * Get OAuth app scopes (to check permissions)
 */
async function checkScopes(token) {
    // We can infer scopes from various API calls
    // Let's try to call the users endpoint and see what happens
    console.log('📡 Checking API permissions...\n');
}

async function main() {
    try {
        // Step 1: Get access token
        const token = await getAccessToken();

        // Step 2: Try to get user info for the specified email
        console.log('-'.repeat(60));
        console.log('TEST 1: Get User Info');
        console.log('-'.repeat(60));

        const userResult = await getUserInfo(token, testEmail);

        if (userResult.ok) {
            console.log('✅ SUCCESS! User found:\n');
            console.log(JSON.stringify(userResult.data, null, 2));
        } else {
            console.log(`❌ Failed with status ${userResult.status}`);
            if (userResult.data) {
                console.log('\nError response:');
                console.log(JSON.stringify(userResult.data, null, 2));
            }

            if (userResult.status === 400) {
                console.log('\n⚠️  400 Error usually means:');
                console.log('   - Missing "user:read:admin" scope on your OAuth app');
                console.log('   - Or the email format is invalid');
            } else if (userResult.status === 404) {
                console.log('\n⚠️  404 Error means:');
                console.log('   - User does not exist in your Zoom account');
                console.log("   - Or the email doesn't match any Zoom user");
            } else if (userResult.status === 403) {
                console.log('\n⚠️  403 Error means:');
                console.log('   - Your OAuth app lacks permission for this operation');
                console.log('   - Add "user:read:admin" scope in Zoom Marketplace');
            }
        }

        // Step 3: List all users to see what's available
        console.log('\n' + '-'.repeat(60));
        console.log('TEST 2: List All Users');
        console.log('-'.repeat(60));

        const listResult = await listUsers(token);

        if (listResult.ok && listResult.data?.users) {
            console.log(`✅ Found ${listResult.data.users.length} users in your Zoom account:\n`);
            listResult.data.users.forEach((user, i) => {
                console.log(`   ${i + 1}. ${user.email}`);
                console.log(`      - ID: ${user.id}`);
                console.log(`      - Name: ${user.first_name} ${user.last_name}`);
                console.log(`      - Type: ${user.type === 1 ? 'Basic' : user.type === 2 ? 'Licensed' : user.type}`);
                console.log(`      - Status: ${user.status}`);
                console.log('');
            });

            // Check if our test email is in the list
            const found = listResult.data.users.find(u => u.email?.toLowerCase() === testEmail.toLowerCase());
            if (found) {
                console.log(`\n🎉 "${testEmail}" IS in your Zoom account!`);
                console.log('   You can use this email for ZOOM_HOST_USER');
            } else {
                console.log(`\n⚠️  "${testEmail}" is NOT in your Zoom account users list`);
                console.log('   Available host emails:');
                listResult.data.users.forEach(u => {
                    if (u.type === 2) { // Licensed users can host meetings
                        console.log(`   ✓ ${u.email}`);
                    }
                });
            }
        } else {
            console.log(`❌ Failed to list users (status ${listResult.status})`);
            if (listResult.data) {
                console.log('\nError response:');
                console.log(JSON.stringify(listResult.data, null, 2));
            }

            if (listResult.status === 400 || listResult.status === 403) {
                console.log('\n⚠️  Your OAuth app needs the "user:read:admin" scope');
                console.log('   Go to Zoom Marketplace → Your App → Scopes → Add "user:read:admin"');
            }
        }

        // Step 4: Check current ZOOM_HOST_USER
        console.log('\n' + '-'.repeat(60));
        console.log('ENVIRONMENT CHECK');
        console.log('-'.repeat(60));

        const hostUser = process.env.ZOOM_HOST_USER;
        if (hostUser) {
            console.log(`Current ZOOM_HOST_USER: ${hostUser}`);

            // Try to verify this user
            const hostResult = await getUserInfo(token, hostUser);
            if (hostResult.ok) {
                console.log('✅ ZOOM_HOST_USER is valid!');
            } else {
                console.log(`⚠️  ZOOM_HOST_USER may not be valid (status ${hostResult.status})`);
            }
        } else {
            console.log('⚠️  ZOOM_HOST_USER is not set in .env');
        }

        console.log('\n' + '='.repeat(60));
        console.log('Test complete!');
        console.log('='.repeat(60));

    } catch (error) {
        console.error('\n❌ Error:', error.message);
        process.exit(1);
    }
}

main();
