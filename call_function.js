// Script to call the checkKiosqueCodes function
const https = require('https');

const PROJECT_ID = 'alluwal-academy';
const REGION = 'us-central1';
const FUNCTION_NAME = 'checkKiosqueCodes';

const url = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/${FUNCTION_NAME}`;

console.log('🔍 Calling checkKiosqueCodes function...');
console.log('URL:', url);

// For callable functions, we need to make a POST request with the data
const data = JSON.stringify({});

const options = {
  hostname: `${REGION}-${PROJECT_ID}.cloudfunctions.net`,
  port: 443,
  path: `/${FUNCTION_NAME}`,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length,
  }
};

const req = https.request(options, (res) => {
  console.log(`Status: ${res.statusCode}`);
  console.log(`Headers:`, res.headers);

  let body = '';
  res.on('data', (chunk) => {
    body += chunk;
  });

  res.on('end', () => {
    try {
      const result = JSON.parse(body);
      console.log('\n📋 Kiosque Codes Results:');
      console.log(JSON.stringify(result, null, 2));
    } catch (e) {
      console.log('Raw response:', body);
    }
  });
});

req.on('error', (e) => {
  console.error('❌ Error calling function:', e.message);
});

req.write(data);
req.end();
