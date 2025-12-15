#!/usr/bin/env node
/**
 * Stats Consistency Verification Script
 * 
 * This script verifies that all shift, timesheet, and stats data is in sync.
 * It checks:
 * 1. Shift times match scheduled times
 * 2. Timesheet worked hours match actual clock-in/out times
 * 3. Week stats match sum of individual shift stats
 * 4. Payout amounts are correctly calculated
 * 5. Form responses are properly linked
 * 
 * Usage:
 *   node scripts/verify_stats_consistency.js [--fix] [--teacher=ID]
 * 
 * Options:
 *   --fix: Automatically fix inconsistencies (otherwise just reports)
 *   --teacher=ID: Only check a specific teacher
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  const fs = require('fs');
  
  if (fs.existsSync(serviceAccountPath)) {
    try {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'alluwal-academy'
      });
      console.log('✅ Initialized Firebase Admin with service account key\n');
    } catch (err) {
      console.error('❌ Error initializing Firebase Admin with service account:');
      console.error('   Error details:', err.message);
      process.exit(1);
    }
  } else {
    try {
      admin.initializeApp({
        projectId: 'alluwal-academy'
      });
      console.log('✅ Initialized Firebase Admin with application default credentials\n');
    } catch (error) {
      console.error('❌ Error initializing Firebase Admin:');
      console.error('   Could not find serviceAccountKey.json and application default credentials failed');
      process.exit(1);
    }
  }
}

const db = admin.firestore();

// Parse command line arguments
const args = process.argv.slice(2);
const FIX_MODE = args.includes('--fix');
const teacherArg = args.find(a => a.startsWith('--teacher='));
const TEACHER_ID = teacherArg ? teacherArg.split('=')[1] : null;

// Stats object
const stats = {
  shiftsChecked: 0,
  timesheetsChecked: 0,
  issues: [],
  fixed: [],
  
  // Specific issue counts
  timeMismatch: 0,
  paymentMismatch: 0,
  statusMismatch: 0,
  orphanedTimesheet: 0,
  missingFormLink: 0,
  weekStatsMismatch: 0,
};

/**
 * Calculate the correct payment for a timesheet entry based on shift times
 */
function calculateCorrectPayment(timesheet, shift) {
  const clockIn = timesheet.clock_in_timestamp?.toDate();
  const clockOut = timesheet.clock_out_timestamp?.toDate();
  
  if (!clockIn || !clockOut) return null;
  
  const shiftStart = shift.shift_start.toDate();
  const shiftEnd = shift.shift_end.toDate();
  
  // Cap to shift window
  const effectiveStart = clockIn < shiftStart ? shiftStart : clockIn;
  const effectiveEnd = clockOut > shiftEnd ? shiftEnd : clockOut;
  
  // Calculate billable duration
  const rawDurationMs = effectiveEnd - effectiveStart;
  const scheduledDurationMs = shiftEnd - shiftStart;
  const billableDurationMs = Math.min(Math.max(0, rawDurationMs), scheduledDurationMs);
  
  const hoursWorked = billableDurationMs / 3600000;
  const hourlyRate = shift.hourly_rate || timesheet.hourly_rate || 0;
  
  return Math.round(hoursWorked * hourlyRate * 100) / 100;
}

/**
 * Verify a single shift and its related timesheet entries
 */
async function verifyShift(shiftDoc) {
  const shiftId = shiftDoc.id;
  const shiftData = shiftDoc.data();
  const shiftStart = shiftData.shift_start?.toDate();
  const shiftEnd = shiftData.shift_end?.toDate();
  
  if (!shiftStart || !shiftEnd) {
    stats.issues.push({
      type: 'invalid_shift',
      shiftId,
      message: 'Shift missing start or end time'
    });
    return;
  }
  
  stats.shiftsChecked++;
  
  // Get timesheet entries for this shift
  const timesheetQuery = await db.collection('timesheet_entries')
    .where('shift_id', '==', shiftId)
    .get();
  
  // Also check camelCase field
  const timesheetQueryCamel = await db.collection('timesheet_entries')
    .where('shiftId', '==', shiftId)
    .get();
  
  const allTimesheets = [...timesheetQuery.docs, ...timesheetQueryCamel.docs];
  const uniqueTimesheets = [...new Map(allTimesheets.map(d => [d.id, d])).values()];
  
  for (const timesheetDoc of uniqueTimesheets) {
    stats.timesheetsChecked++;
    const timesheetData = timesheetDoc.data();
    const timesheetId = timesheetDoc.id;
    
    // Check 1: Payment calculation
    const correctPayment = calculateCorrectPayment(timesheetData, shiftData);
    const currentPayment = timesheetData.payment_amount || timesheetData.total_pay || 0;
    
    if (correctPayment !== null && Math.abs(currentPayment - correctPayment) > 0.01) {
      stats.paymentMismatch++;
      stats.issues.push({
        type: 'payment_mismatch',
        shiftId,
        timesheetId,
        message: `Payment mismatch: current $${currentPayment.toFixed(2)}, should be $${correctPayment.toFixed(2)}`,
        currentPayment,
        correctPayment
      });
      
      if (FIX_MODE) {
        await db.collection('timesheet_entries').doc(timesheetId).update({
          payment_amount: correctPayment,
          total_pay: correctPayment,
          payment_recalculated_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        });
        stats.fixed.push({ type: 'payment', timesheetId, oldValue: currentPayment, newValue: correctPayment });
      }
    }
    
    // Check 2: Scheduled times match shift
    const scheduledStart = timesheetData.scheduled_start?.toDate();
    const scheduledEnd = timesheetData.scheduled_end?.toDate();
    
    if (scheduledStart && scheduledEnd) {
      const startMismatch = Math.abs(scheduledStart - shiftStart) > 60000; // 1 minute tolerance
      const endMismatch = Math.abs(scheduledEnd - shiftEnd) > 60000;
      
      if (startMismatch || endMismatch) {
        stats.timeMismatch++;
        stats.issues.push({
          type: 'time_mismatch',
          shiftId,
          timesheetId,
          message: `Scheduled times don't match shift: timesheet shows ${scheduledStart?.toISOString()} - ${scheduledEnd?.toISOString()}, shift is ${shiftStart.toISOString()} - ${shiftEnd.toISOString()}`
        });
        
        if (FIX_MODE) {
          await db.collection('timesheet_entries').doc(timesheetId).update({
            scheduled_start: admin.firestore.Timestamp.fromDate(shiftStart),
            scheduled_end: admin.firestore.Timestamp.fromDate(shiftEnd),
            scheduled_duration_minutes: Math.round((shiftEnd - shiftStart) / 60000),
            updated_at: admin.firestore.FieldValue.serverTimestamp()
          });
          stats.fixed.push({ type: 'scheduled_times', timesheetId });
        }
      }
    }
    
    // Check 3: Form linkage
    const hasFormLink = timesheetData.form_response_id || timesheetData.form_completed;
    const hasClockOut = timesheetData.clock_out_timestamp != null;
    
    if (hasClockOut && !hasFormLink) {
      // Check if form exists but link is missing
      const formQuery = await db.collection('form_responses')
        .where('shiftId', '==', shiftId)
        .limit(1)
        .get();
      
      const formQuerySnake = await db.collection('form_responses')
        .where('shift_id', '==', shiftId)
        .limit(1)
        .get();
      
      const formQueryTimesheet = await db.collection('form_responses')
        .where('timesheetId', '==', timesheetId)
        .limit(1)
        .get();
      
      const hasUnlinkedForm = formQuery.docs.length > 0 || 
                              formQuerySnake.docs.length > 0 || 
                              formQueryTimesheet.docs.length > 0;
      
      if (hasUnlinkedForm) {
        stats.missingFormLink++;
        const formDoc = formQuery.docs[0] || formQuerySnake.docs[0] || formQueryTimesheet.docs[0];
        stats.issues.push({
          type: 'missing_form_link',
          shiftId,
          timesheetId,
          formId: formDoc.id,
          message: `Form exists but not linked to timesheet`
        });
        
        if (FIX_MODE) {
          await db.collection('timesheet_entries').doc(timesheetId).update({
            form_response_id: formDoc.id,
            form_completed: true,
            updated_at: admin.firestore.FieldValue.serverTimestamp()
          });
          stats.fixed.push({ type: 'form_link', timesheetId, formId: formDoc.id });
        }
      }
    }
  }
  
  // Check 4: Shift status consistency
  const now = new Date();
  const shiftPassed = shiftEnd < now;
  const hasTimesheets = uniqueTimesheets.length > 0;
  const hasClockInOnShift = shiftData.clock_in_time != null;
  
  if (shiftPassed) {
    const currentStatus = shiftData.status;
    
    // Determine correct status
    let correctStatus;
    if (!hasTimesheets && !hasClockInOnShift) {
      correctStatus = 'missed';
    } else if (currentStatus === 'active' || currentStatus === 'scheduled') {
      // Should be completed
      const workedMinutes = shiftData.worked_minutes || 0;
      const scheduledMinutes = Math.round((shiftEnd - shiftStart) / 60000);
      
      if (workedMinutes === 0) {
        correctStatus = 'missed';
      } else if (workedMinutes >= scheduledMinutes - 1) {
        correctStatus = 'fullyCompleted';
      } else {
        correctStatus = 'partiallyCompleted';
      }
      
      if (currentStatus !== correctStatus) {
        stats.statusMismatch++;
        stats.issues.push({
          type: 'status_mismatch',
          shiftId,
          message: `Shift status is '${currentStatus}' but should be '${correctStatus}'`,
          currentStatus,
          correctStatus
        });
        
        if (FIX_MODE) {
          await db.collection('teaching_shifts').doc(shiftId).update({
            status: correctStatus,
            last_modified: admin.firestore.FieldValue.serverTimestamp()
          });
          stats.fixed.push({ type: 'status', shiftId, oldValue: currentStatus, newValue: correctStatus });
        }
      }
    }
  }
}

/**
 * Check for orphaned timesheet entries (shift deleted)
 */
async function checkOrphanedTimesheets() {
  console.log('\n📋 Checking for orphaned timesheet entries...');
  
  let query = db.collection('timesheet_entries');
  if (TEACHER_ID) {
    query = query.where('teacher_id', '==', TEACHER_ID);
  }
  
  const timesheetSnapshot = await query.get();
  
  for (const doc of timesheetSnapshot.docs) {
    const data = doc.data();
    const shiftId = data.shift_id || data.shiftId;
    
    if (!shiftId) {
      stats.orphanedTimesheet++;
      stats.issues.push({
        type: 'orphaned_timesheet',
        timesheetId: doc.id,
        message: 'Timesheet has no shift_id'
      });
      continue;
    }
    
    const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
    if (!shiftDoc.exists) {
      stats.orphanedTimesheet++;
      stats.issues.push({
        type: 'orphaned_timesheet',
        timesheetId: doc.id,
        shiftId,
        message: `Timesheet references non-existent shift ${shiftId}`
      });
      
      if (FIX_MODE) {
        // Optionally delete orphaned timesheets
        // await doc.ref.delete();
        // stats.fixed.push({ type: 'deleted_orphan', timesheetId: doc.id });
      }
    }
  }
}

/**
 * Verify weekly stats for each teacher
 */
async function verifyWeeklyStats() {
  console.log('\n📊 Verifying weekly stats...');
  
  // Get all unique teachers
  let teachersQuery = db.collection('users').where('user_type', '==', 'teacher');
  if (TEACHER_ID) {
    teachersQuery = db.collection('users').where(admin.firestore.FieldPath.documentId(), '==', TEACHER_ID);
  }
  
  const teachersSnapshot = await teachersQuery.get();
  
  for (const teacherDoc of teachersSnapshot.docs) {
    const teacherId = teacherDoc.id;
    const teacherName = `${teacherDoc.data().first_name || ''} ${teacherDoc.data().last_name || ''}`.trim();
    
    // Get this week's start and end
    const now = new Date();
    const dayOfWeek = now.getDay();
    const weekStart = new Date(now);
    weekStart.setDate(now.getDate() - dayOfWeek);
    weekStart.setHours(0, 0, 0, 0);
    
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekStart.getDate() + 7);
    
    // Get all shifts for this teacher this week
    const shiftsSnapshot = await db.collection('teaching_shifts')
      .where('teacher_id', '==', teacherId)
      .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(weekStart))
      .where('shift_start', '<', admin.firestore.Timestamp.fromDate(weekEnd))
      .get();
    
    // Calculate totals from shifts
    let totalScheduledMinutes = 0;
    let totalWorkedMinutes = 0;
    let totalPayout = 0;
    
    for (const shiftDoc of shiftsSnapshot.docs) {
      const shift = shiftDoc.data();
      const shiftStart = shift.shift_start?.toDate();
      const shiftEnd = shift.shift_end?.toDate();
      
      if (shiftStart && shiftEnd) {
        totalScheduledMinutes += Math.round((shiftEnd - shiftStart) / 60000);
      }
      
      totalWorkedMinutes += shift.worked_minutes || 0;
      
      // Get timesheet payment
      const timesheetQuery = await db.collection('timesheet_entries')
        .where('shift_id', '==', shiftDoc.id)
        .get();
      
      for (const ts of timesheetQuery.docs) {
        const payment = ts.data().payment_amount || ts.data().total_pay || 0;
        totalPayout += payment;
      }
    }
    
    // Check if teacher has weekly stats stored
    const weekKey = `${weekStart.getFullYear()}-W${Math.ceil((weekStart.getDate() + 1) / 7)}`;
    const weekStatsDoc = await db.collection('weekly_stats')
      .doc(`${teacherId}_${weekKey}`)
      .get();
    
    if (weekStatsDoc.exists) {
      const storedStats = weekStatsDoc.data();
      const storedScheduled = storedStats.scheduled_minutes || 0;
      const storedWorked = storedStats.worked_minutes || 0;
      const storedPayout = storedStats.total_payout || 0;
      
      const scheduledMismatch = Math.abs(storedScheduled - totalScheduledMinutes) > 1;
      const workedMismatch = Math.abs(storedWorked - totalWorkedMinutes) > 1;
      const payoutMismatch = Math.abs(storedPayout - totalPayout) > 0.01;
      
      if (scheduledMismatch || workedMismatch || payoutMismatch) {
        stats.weekStatsMismatch++;
        stats.issues.push({
          type: 'week_stats_mismatch',
          teacherId,
          teacherName,
          weekKey,
          message: `Week stats mismatch: stored (${storedScheduled}min/${storedWorked}min/$${storedPayout.toFixed(2)}) vs calculated (${totalScheduledMinutes}min/${totalWorkedMinutes}min/$${totalPayout.toFixed(2)})`
        });
        
        if (FIX_MODE) {
          await weekStatsDoc.ref.update({
            scheduled_minutes: totalScheduledMinutes,
            worked_minutes: totalWorkedMinutes,
            total_payout: totalPayout,
            verified_at: admin.firestore.FieldValue.serverTimestamp()
          });
          stats.fixed.push({ type: 'week_stats', teacherId, weekKey });
        }
      }
    }
    
    console.log(`   ${teacherName}: ${shiftsSnapshot.docs.length} shifts, ${totalScheduledMinutes}min scheduled, ${totalWorkedMinutes}min worked, $${totalPayout.toFixed(2)} payout`);
  }
}

/**
 * Main verification function
 */
async function runVerification() {
  console.log('🔍 Stats Consistency Verification Script');
  console.log('========================================\n');
  
  if (FIX_MODE) {
    console.log('⚠️  FIX MODE ENABLED - Will automatically fix issues\n');
  } else {
    console.log('📝 REPORT MODE - Will only report issues (use --fix to auto-fix)\n');
  }
  
  if (TEACHER_ID) {
    console.log(`🎯 Filtering by teacher: ${TEACHER_ID}\n`);
  }
  
  try {
    // Step 1: Verify all shifts
    console.log('📋 Step 1: Verifying shifts and timesheets...');
    
    let shiftsQuery = db.collection('teaching_shifts');
    if (TEACHER_ID) {
      shiftsQuery = shiftsQuery.where('teacher_id', '==', TEACHER_ID);
    }
    
    const shiftsSnapshot = await shiftsQuery.get();
    console.log(`   Found ${shiftsSnapshot.docs.length} shifts to verify\n`);
    
    let processed = 0;
    for (const shiftDoc of shiftsSnapshot.docs) {
      await verifyShift(shiftDoc);
      processed++;
      if (processed % 50 === 0) {
        console.log(`   Processed ${processed}/${shiftsSnapshot.docs.length} shifts...`);
      }
    }
    
    // Step 2: Check for orphaned timesheets
    await checkOrphanedTimesheets();
    
    // Step 3: Verify weekly stats
    await verifyWeeklyStats();
    
    // Print summary
    console.log('\n📊 Verification Summary');
    console.log('========================');
    console.log(`   Shifts checked: ${stats.shiftsChecked}`);
    console.log(`   Timesheets checked: ${stats.timesheetsChecked}`);
    console.log('');
    console.log('   Issues Found:');
    console.log(`   - Payment mismatches: ${stats.paymentMismatch}`);
    console.log(`   - Time mismatches: ${stats.timeMismatch}`);
    console.log(`   - Status mismatches: ${stats.statusMismatch}`);
    console.log(`   - Orphaned timesheets: ${stats.orphanedTimesheet}`);
    console.log(`   - Missing form links: ${stats.missingFormLink}`);
    console.log(`   - Week stats mismatches: ${stats.weekStatsMismatch}`);
    console.log(`   - Total issues: ${stats.issues.length}`);
    
    if (FIX_MODE) {
      console.log(`\n   Fixed: ${stats.fixed.length} issues`);
    }
    
    // Print detailed issues
    if (stats.issues.length > 0) {
      console.log('\n📝 Detailed Issues:');
      console.log('-------------------');
      
      const issuesByType = {};
      for (const issue of stats.issues) {
        if (!issuesByType[issue.type]) {
          issuesByType[issue.type] = [];
        }
        issuesByType[issue.type].push(issue);
      }
      
      for (const [type, issues] of Object.entries(issuesByType)) {
        console.log(`\n   ${type.toUpperCase()} (${issues.length}):`);
        // Show first 5 of each type
        for (const issue of issues.slice(0, 5)) {
          console.log(`   - ${issue.message}`);
          if (issue.shiftId) console.log(`     Shift: ${issue.shiftId}`);
          if (issue.timesheetId) console.log(`     Timesheet: ${issue.timesheetId}`);
        }
        if (issues.length > 5) {
          console.log(`   ... and ${issues.length - 5} more`);
        }
      }
    }
    
    if (!FIX_MODE && stats.issues.length > 0) {
      console.log('\n💡 Run with --fix to automatically correct these issues');
    }
    
    console.log('\n✅ Verification complete!');
    process.exit(stats.issues.length > 0 ? 1 : 0);
    
  } catch (error) {
    console.error('\n❌ Error during verification:', error);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  }
}

// Run the verification
runVerification();

