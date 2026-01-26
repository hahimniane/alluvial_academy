#!/usr/bin/env node
'use strict';

/**
 * Test script for the daily shift generation report email.
 * Run with: node functions/scripts/test_shift_report_email.js
 */

const {DateTime} = require('luxon');

// Set up environment for email
process.env.EMAIL_USER = process.env.EMAIL_USER || 'support@alluwaleducationhub.org';
// Note: EMAIL_PASS needs to be set in environment or .env

const {sendDailyShiftGenerationReport} = require('../services/email/senders');

async function testEmail() {
  console.log('Testing Daily Shift Generation Report Email...\n');
  
  const testData = {
    totalTemplates: 160,
    totalShiftsCreated: 45,
    totalSkipped: 12,
    teachersAffected: [
      { name: 'Abdoullahi Yaya', shiftsCreated: 8 },
      { name: 'Ibrahim Baldee', shiftsCreated: 6 },
      { name: 'Asma Mugtiu', shiftsCreated: 5 },
      { name: 'Rahmatullaah Balde', shiftsCreated: 4 },
      { name: 'Thierno Aliou Diallo', shiftsCreated: 4 },
      { name: 'Abdullah Baldee', shiftsCreated: 3 },
    ],
    runDate: DateTime.now().setZone('America/New_York').toFormat('cccc, LLLL d, yyyy'),
  };
  
  console.log('Test Data:');
  console.log(`  Total Templates: ${testData.totalTemplates}`);
  console.log(`  Shifts Created: ${testData.totalShiftsCreated}`);
  console.log(`  Skipped: ${testData.totalSkipped}`);
  console.log(`  Teachers Affected: ${testData.teachersAffected.length}`);
  console.log(`  Run Date: ${testData.runDate}`);
  console.log('');
  
  try {
    const result = await sendDailyShiftGenerationReport(testData);
    
    if (result) {
      console.log('✅ Email sent successfully to support@alluwaleducationhub.org');
    } else {
      console.log('⚠️ Email function returned false (check logs for details)');
    }
  } catch (error) {
    console.error('❌ Failed to send email:', error.message);
    if (error.message.includes('Missing credentials')) {
      console.log('\nNote: Make sure EMAIL_PASS environment variable is set.');
      console.log('You can set it by running: export EMAIL_PASS="your_email_password"');
    }
  }
}

testEmail()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  });
