/**
 * Script to deploy Firestore indexes using Firebase CLI
 * 
 * This script:
 * 1. Validates firestore.indexes.json
 * 2. Deploys indexes via Firebase CLI
 * 3. Monitors deployment status
 * 
 * Prerequisites:
 * - Firebase CLI installed: npm install -g firebase-tools
 * - Logged in: firebase login
 * - Project configured: firebase use alluwal-academy
 * 
 * Run: node scripts/deploy_firestore_indexes.js
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('🔥 Firestore Index Deployment Script\n');
console.log('═══════════════════════════════════════════════════════════════\n');

// Check if firebase CLI is installed
function checkFirebaseCLI() {
  try {
    const version = execSync('firebase --version', { encoding: 'utf-8' }).trim();
    console.log(`✅ Firebase CLI found: ${version}`);
    return true;
  } catch (error) {
    console.error('❌ Firebase CLI not found!');
    console.log('\n📦 Install it with:');
    console.log('   npm install -g firebase-tools');
    console.log('   firebase login');
    return false;
  }
}

// Check if firestore.indexes.json exists
function checkIndexesFile() {
  const indexesPath = path.join(__dirname, '..', 'firestore.indexes.json');
  if (!fs.existsSync(indexesPath)) {
    console.error('❌ firestore.indexes.json not found!');
    console.log('   Run: node scripts/create_firestore_indexes.js');
    return false;
  }
  
  try {
    const content = JSON.parse(fs.readFileSync(indexesPath, 'utf-8'));
    console.log(`✅ firestore.indexes.json found with ${content.indexes?.length || 0} indexes`);
    return true;
  } catch (error) {
    console.error('❌ Error reading firestore.indexes.json:', error.message);
    return false;
  }
}

// Check if logged in to Firebase
function checkFirebaseLogin() {
  try {
    const projects = execSync('firebase projects:list', { encoding: 'utf-8' });
    if (projects.includes('alluwal-academy')) {
      console.log('✅ Firebase login verified');
      return true;
    }
    console.warn('⚠️  Project alluwal-academy not found in projects list');
    return false;
  } catch (error) {
    console.error('❌ Not logged in to Firebase!');
    console.log('\n🔐 Login with:');
    console.log('   firebase login');
    return false;
  }
}

// Deploy indexes
function deployIndexes() {
  try {
    console.log('\n📤 Deploying Firestore indexes...\n');
    const output = execSync('firebase deploy --only firestore:indexes', {
      encoding: 'utf-8',
      stdio: 'inherit'
    });
    console.log('\n✅ Deployment completed!');
    return true;
  } catch (error) {
    console.error('\n❌ Deployment failed!');
    console.error('   Check the error message above for details.');
    return false;
  }
}

// Main execution
async function main() {
  // Pre-flight checks
  if (!checkFirebaseCLI()) {
    process.exit(1);
  }
  
  if (!checkFirebaseLogin()) {
    console.log('\n💡 Try: firebase login');
    process.exit(1);
  }
  
  if (!checkIndexesFile()) {
    process.exit(1);
  }
  
  console.log('\n═══════════════════════════════════════════════════════════════\n');
  
  // Deploy
  const success = deployIndexes();
  
  if (success) {
    console.log('\n═══════════════════════════════════════════════════════════════\n');
    console.log('✅ Indexes deployed successfully!');
    console.log('\n⏳ Next steps:');
    console.log('   1. Wait 1-5 minutes for indexes to build');
    console.log('   2. Check status: https://console.firebase.google.com/project/alluwal-academy/firestore/indexes');
    console.log('   3. Look for "Enabled" status (green checkmark)');
    console.log('   4. Test your app once indexes are ready\n');
  } else {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('\n❌ Unexpected error:', error);
  process.exit(1);
});
