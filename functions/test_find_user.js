// Test the findUserByEmailOrCode function directly
const { findUserByEmailOrCode } = require('./handlers/users');

async function testFindUser() {
  console.log('🧪 Testing findUserByEmailOrCode function...\n');

  // Test with the user's code
  const testCode = 'YKPR49182773';
  console.log(`Testing with code: ${testCode}`);

  try {
    const result = await findUserByEmailOrCode({ identifier: testCode });
    console.log('Result:', JSON.stringify(result, null, 2));
  } catch (error) {
    console.log('Error:', error.message);
  }

  // Test with a shorter code (6 characters like generated codes)
  const shortCode = 'YKPR49';
  console.log(`\nTesting with 6-char code: ${shortCode}`);

  try {
    const result = await findUserByEmailOrCode({ identifier: shortCode });
    console.log('Result:', JSON.stringify(result, null, 2));
  } catch (error) {
    console.log('Error:', error.message);
  }

  // Test with empty identifier
  console.log(`\nTesting with empty identifier:`);

  try {
    const result = await findUserByEmailOrCode({ identifier: '' });
    console.log('Result:', JSON.stringify(result, null, 2));
  } catch (error) {
    console.log('Error:', error.message);
  }

  // Test with undefined identifier
  console.log(`\nTesting with undefined identifier:`);

  try {
    const result = await findUserByEmailOrCode({});
    console.log('Result:', JSON.stringify(result, null, 2));
  } catch (error) {
    console.log('Error:', error.message);
  }
}

// Run the test
testFindUser()
  .then(() => console.log('\n✅ Tests completed'))
  .catch(error => console.error('\n❌ Test failed:', error));
