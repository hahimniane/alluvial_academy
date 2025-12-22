// Simple script to check Firebase database
const { exec } = require('child_process');

console.log('🔍 Checking Firebase database...\n');

// Use Firebase CLI to get database info
exec('firebase firestore:databases:list --project alluwal-academy', (error, stdout, stderr) => {
  if (error) {
    console.error(`Error: ${error.message}`);
    return;
  }
  if (stderr) {
    console.error(`Stderr: ${stderr}`);
    return;
  }
  console.log('Database info:', stdout);
});
