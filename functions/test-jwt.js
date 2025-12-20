/**
 * Test script to validate Zoom Meeting SDK JWT generation
 * Run with: node test-jwt.js
 */

require('dotenv').config();
const jwt = require('jsonwebtoken');

// Get credentials from environment
const sdkKey = process.env.ZOOM_MEETING_SDK_KEY;
const sdkSecret = process.env.ZOOM_MEETING_SDK_SECRET;

console.log('\n=== Zoom Meeting SDK JWT Test ===\n');

// Check if credentials exist
if (!sdkKey) {
    console.error('❌ ERROR: ZOOM_MEETING_SDK_KEY is not set in .env');
    process.exit(1);
}
if (!sdkSecret) {
    console.error('❌ ERROR: ZOOM_MEETING_SDK_SECRET is not set in .env');
    process.exit(1);
}

console.log('✅ ZOOM_MEETING_SDK_KEY is set:', sdkKey.substring(0, 8) + '...');
console.log('✅ ZOOM_MEETING_SDK_SECRET is set:', sdkSecret.substring(0, 8) + '...');

// Generate JWT using the same logic as the Cloud Function
const ttlSeconds = 3600; // 1 hour
const clampedTtl = Math.max(1800, Math.min(172800, ttlSeconds));

const nowUnix = Math.floor(Date.now() / 1000);
const iat = nowUnix - 60; // Clock drift tolerance
const exp = iat + clampedTtl;

const payload = {
    appKey: sdkKey,
    iat,
    exp,
    tokenExp: exp,
};

console.log('\n--- JWT Payload ---');
console.log(JSON.stringify(payload, null, 2));

// Sign the token
const token = jwt.sign(payload, sdkSecret, {
    algorithm: 'HS256',
    header: { typ: 'JWT' }
});

console.log('\n--- Generated JWT ---');
console.log(token);

// Decode and verify
console.log('\n--- Decoded JWT (Header) ---');
const decoded = jwt.decode(token, { complete: true });
console.log(JSON.stringify(decoded.header, null, 2));

console.log('\n--- Decoded JWT (Payload) ---');
console.log(JSON.stringify(decoded.payload, null, 2));

// Verify the signature
try {
    const verified = jwt.verify(token, sdkSecret, { algorithms: ['HS256'] });
    console.log('\n✅ JWT signature is VALID');
    console.log('   Expires at:', new Date(verified.exp * 1000).toISOString());
} catch (e) {
    console.error('\n❌ JWT signature is INVALID:', e.message);
}

console.log('\n=== Test Complete ===\n');
console.log('If the JWT looks correct, paste it at https://jwt.io to verify.');
console.log('Make sure the "sdkKey" in the payload matches your Zoom Client ID exactly.\n');
