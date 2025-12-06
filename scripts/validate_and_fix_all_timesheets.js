#!/usr/bin/env node
/**
 * Comprehensive Timesheet Validation and Fix Script
 * 
 * This script performs complete validation and fixes for all timesheet entries:
 * 1. Verifies duration matches scheduled duration (capped to scheduled)
 * 2. Verifies payment amount is correctly calculated (not exceeding scheduled * rate)
 * 3. Ensures coherence between status, payment, duration, and shift data
 * 4. Fixes all inconsistencies found
 * 5. Deletes orphaned entries (not linked to any shift)
 * 6. Works for ALL statuses: draft, pending, approved, rejected
 * 
 * Usage:
 *   node scripts/validate_and_fix_all_timesheets.js [--dry-run] [--delete-orphans]
 * 
 * Options:
 *   --dry-run: Preview changes without applying them
 *   --delete-orphans: Delete timesheets not linked to shifts (default: false in dry-run, true otherwise)
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
      console.error('   Options:');
      console.error('   1. Run: firebase login');
      console.error('   2. Or place serviceAccountKey.json in project root');
      console.error('   Error details:', error.message);
      process.exit(1);
    }
  }
}

const db = admin.firestore();
const DRY_RUN = process.argv.includes('--dry-run');
const DELETE_ORPHANS = process.argv.includes('--delete-orphans') || (!DRY_RUN);

// Helper function to parse time string (HH:MM or HH:MM:SS)
function parseTimeString(timeStr) {
  if (!timeStr || typeof timeStr !== 'string') return null;
  
  const parts = timeStr.split(':').map(p => parseInt(p, 10));
  if (parts.length < 2) return null;
  
  const hours = parts[0] || 0;
  const minutes = parts[1] || 0;
  const seconds = parts[2] || 0;
  
  return hours * 3600 + minutes * 60 + seconds; // Return total seconds
}

// Helper function to format duration in seconds to HH:MM:SS
function formatDuration(seconds) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}

// Calculate correct payment based on shift constraints
function calculateCorrectPayment(clockIn, clockOut, shiftStart, shiftEnd, hourlyRate) {
  // Cap start time to shift start (no payment for early clock-ins)
  const effectiveStartTime = clockIn < shiftStart ? shiftStart : clockIn;
  
  // Cap end time to shift end (no payment for late clock-outs)
  const effectiveEndTime = clockOut && clockOut > shiftEnd ? shiftEnd : (clockOut || shiftEnd);
  
  // Calculate raw duration in seconds
  const rawDurationSeconds = Math.floor((effectiveEndTime - effectiveStartTime) / 1000);
  const scheduledDurationSeconds = Math.floor((shiftEnd - shiftStart) / 1000);
  
  // Cap total duration to scheduled duration (prevent overpayment)
  const billableSeconds = Math.min(Math.max(0, rawDurationSeconds), scheduledDurationSeconds);
  const hoursWorked = billableSeconds / 3600.0;
  const payment = Math.round(hoursWorked * hourlyRate * 100) / 100; // Round to 2 decimals
  
  return {
    billableSeconds,
    billableHours: hoursWorked,
    payment,
    rawDurationSeconds,
    scheduledDurationSeconds
  };
}

async function validateAndFixAllTimesheets() {
  console.log('🔍 Comprehensive Timesheet Validation & Fix Script');
  console.log('====================================================\n');
  
  if (DRY_RUN) {
    console.log('⚠️  DRY RUN MODE - No changes will be applied\n');
  }
  
  if (DELETE_ORPHANS) {
    console.log('🗑️  Orphaned entries will be deleted\n');
  } else {
    console.log('⚠️  Orphaned entries will be reported but NOT deleted\n');
  }

  const stats = {
    totalChecked: 0,
    valid: 0,
    fixed: 0,
    orphaned: 0,
    deleted: 0,
    issues: {
      zeroPayment: 0,
      overpaid: 0,
      wrongDuration: 0,
      incoherentStatus: 0,
      missingFields: 0,
      other: 0
    },
    errors: []
  };

  const issues = [];

  try {
    // Get all timesheet entries
    console.log('📋 Loading all timesheet entries...');
    const timesheetsSnapshot = await db.collection('timesheet_entries').get();
    stats.totalChecked = timesheetsSnapshot.docs.length;
    console.log(`   Found ${stats.totalChecked} timesheet entries\n`);

    // Cache shift data to avoid repeated queries
    const shiftCache = new Map();
    
    let updateBatch = db.batch();
    let deleteBatch = db.batch();
    let updateBatchCount = 0;
    let deleteBatchCount = 0;
    const batchSize = 500;

    console.log('🔍 Validating each timesheet entry...\n');

    for (const timesheetDoc of timesheetsSnapshot.docs) {
      const timesheetData = timesheetDoc.data();
      const timesheetId = timesheetDoc.id;
      const shiftId = timesheetData.shift_id || timesheetData.shiftId;
      
      // Check if orphaned (no shift_id)
      if (!shiftId) {
        stats.orphaned++;
        issues.push({
          id: timesheetId,
          type: 'orphaned',
          message: 'No shift_id - orphaned entry',
          teacher: timesheetData.teacher_name || 'Unknown',
          date: timesheetData.date || 'Unknown'
        });
        
        if (DELETE_ORPHANS && !DRY_RUN) {
          deleteBatch.delete(timesheetDoc.ref);
          deleteBatchCount++;
          
          if (deleteBatchCount >= batchSize) {
            await deleteBatch.commit();
            console.log(`   Committed batch of ${deleteBatchCount} deletions...`);
            deleteBatch = db.batch();
            deleteBatchCount = 0;
          }
        }
        continue;
      }

      // Get shift data (with caching)
      let shiftData;
      if (shiftCache.has(shiftId)) {
        shiftData = shiftCache.get(shiftId);
      } else {
        const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
        if (!shiftDoc.exists) {
          stats.orphaned++;
          issues.push({
            id: timesheetId,
            type: 'orphaned',
            message: `Shift ${shiftId} does not exist`,
            teacher: timesheetData.teacher_name || 'Unknown',
            date: timesheetData.date || 'Unknown'
          });
          
          if (DELETE_ORPHANS && !DRY_RUN) {
            deleteBatch.delete(timesheetDoc.ref);
            deleteBatchCount++;
            
            if (deleteBatchCount >= batchSize) {
              await deleteBatch.commit();
              console.log(`   Committed batch of ${deleteBatchCount} deletions...`);
              deleteBatch = db.batch();
              deleteBatchCount = 0;
            }
          }
          continue;
        }
        shiftData = shiftDoc.data();
        shiftCache.set(shiftId, shiftData);
      }

      const shiftStart = shiftData.shift_start?.toDate();
      const shiftEnd = shiftData.shift_end?.toDate();
      const hourlyRate = shiftData.hourly_rate || timesheetData.hourly_rate || 0;

      if (!shiftStart || !shiftEnd || hourlyRate <= 0) {
        stats.issues.missingFields++;
        issues.push({
          id: timesheetId,
          type: 'missingFields',
          message: 'Missing shift_start, shift_end, or hourly_rate',
          teacher: timesheetData.teacher_name || 'Unknown',
          date: timesheetData.date || 'Unknown'
        });
        continue;
      }

      // Get clock-in and clock-out times
      const clockIn = timesheetData.clock_in_timestamp?.toDate();
      const clockOut = timesheetData.clock_out_timestamp?.toDate();
      
      if (!clockIn) {
        // No clock-in, skip validation (might be draft)
        continue;
      }

      // Calculate correct values
      const correct = calculateCorrectPayment(clockIn, clockOut, shiftStart, shiftEnd, hourlyRate);
      
      // Get current values
      const currentPayment = timesheetData.payment_amount || timesheetData.total_pay || 0;
      const currentTotalHours = timesheetData.total_hours || '00:00:00';
      const currentDurationSeconds = parseTimeString(currentTotalHours) || 0;
      const status = timesheetData.status || 'draft';
      
      // Validate and collect issues
      const updateData = {};
      let hasIssues = false;
      const entryIssues = [];

      // 1. Check payment
      const maxPayment = (correct.scheduledDurationSeconds / 3600.0) * hourlyRate;
      const paymentTolerance = 0.01; // Allow small rounding differences
      
      if (currentPayment === 0 && correct.billableSeconds > 0) {
        // Zero payment when there should be payment
        updateData.payment_amount = correct.payment;
        updateData.total_pay = correct.payment;
        updateData.hourly_rate = hourlyRate;
        hasIssues = true;
        stats.issues.zeroPayment++;
        entryIssues.push(`Zero payment (should be $${correct.payment.toFixed(2)})`);
      } else if (currentPayment > maxPayment + paymentTolerance) {
        // Overpaid
        updateData.payment_amount = correct.payment;
        updateData.total_pay = correct.payment;
        updateData.hourly_rate = hourlyRate;
        hasIssues = true;
        stats.issues.overpaid++;
        entryIssues.push(`Overpaid: $${currentPayment.toFixed(2)} → $${correct.payment.toFixed(2)}`);
      } else if (!timesheetData.payment_amount && currentPayment > 0) {
        // Missing payment_amount field but has total_pay
        updateData.payment_amount = correct.payment;
        hasIssues = true;
      }

      // 2. Check duration
      const correctDurationFormatted = formatDuration(correct.billableSeconds);
      const durationTolerance = 60; // 1 minute tolerance
      
      if (Math.abs(currentDurationSeconds - correct.billableSeconds) > durationTolerance) {
        updateData.total_hours = correctDurationFormatted;
        hasIssues = true;
        stats.issues.wrongDuration++;
        entryIssues.push(`Wrong duration: ${currentTotalHours} → ${correctDurationFormatted}`);
      }

      // 3. Check coherence
      // If status is approved/rejected but payment is 0, that's incoherent
      if ((status === 'approved' || status === 'pending') && currentPayment === 0 && correct.billableSeconds > 0) {
        // This will be fixed by payment fix above, but log it
        stats.issues.incoherentStatus++;
        entryIssues.push(`Incoherent: ${status} status but $0 payment`);
      }

      // 4. Ensure all required fields are present
      if (!timesheetData.hourly_rate && hourlyRate > 0) {
        updateData.hourly_rate = hourlyRate;
        hasIssues = true;
      }

      // Apply fixes if needed
      if (hasIssues) {
        updateData.updated_at = admin.firestore.FieldValue.serverTimestamp();
        updateData.validation_fixed_at = admin.firestore.FieldValue.serverTimestamp();
        
        if (!DRY_RUN) {
          updateBatch.update(timesheetDoc.ref, updateData);
          updateBatchCount++;
          
          if (updateBatchCount >= batchSize) {
            await updateBatch.commit();
            console.log(`   Committed batch of ${updateBatchCount} updates...`);
            updateBatch = db.batch();
            updateBatchCount = 0;
          }
        }
        
        stats.fixed++;
        issues.push({
          id: timesheetId,
          type: 'fixed',
          message: entryIssues.join(', '),
          teacher: timesheetData.teacher_name || 'Unknown',
          date: timesheetData.date || 'Unknown',
          shiftId: shiftId,
          fixes: updateData
        });
        
        console.log(`   ✓ Fixed: ${timesheetId} (${timesheetData.teacher_name || 'Unknown'}) - ${entryIssues.join(', ')}`);
      } else {
        stats.valid++;
      }
    }

    // Commit remaining batches
    if (!DRY_RUN) {
      if (updateBatchCount > 0) {
        await updateBatch.commit();
        console.log(`   Committed final batch of ${updateBatchCount} updates...`);
      }
      
      if (deleteBatchCount > 0) {
        await deleteBatch.commit();
        console.log(`   Committed final batch of ${deleteBatchCount} deletions...`);
        stats.deleted = deleteBatchCount;
      }
    } else {
      stats.deleted = deleteBatchCount; // Count what would be deleted
    }

    // Detailed Summary
    console.log('\n📊 Validation Summary');
    console.log('=====================');
    console.log(`   Total checked: ${stats.totalChecked}`);
    console.log(`   Valid entries: ${stats.valid}`);
    console.log(`   Fixed entries: ${stats.fixed}`);
    console.log(`   Orphaned entries: ${stats.orphaned}`);
    console.log(`   Deleted entries: ${stats.deleted}`);
    console.log('\n   Issues Found:');
    console.log(`     - Zero payment: ${stats.issues.zeroPayment}`);
    console.log(`     - Overpaid: ${stats.issues.overpaid}`);
    console.log(`     - Wrong duration: ${stats.issues.wrongDuration}`);
    console.log(`     - Incoherent status: ${stats.issues.incoherentStatus}`);
    console.log(`     - Missing fields: ${stats.issues.missingFields}`);
    console.log(`     - Other: ${stats.issues.other}`);

    // Show sample issues
    if (issues.length > 0) {
      console.log('\n📋 Sample Issues Found:');
      console.log('========================');
      const sampleSize = Math.min(10, issues.length);
      for (let i = 0; i < sampleSize; i++) {
        const issue = issues[i];
        console.log(`\n   ${i + 1}. ${issue.type.toUpperCase()}: ${issue.id}`);
        console.log(`      Teacher: ${issue.teacher}`);
        console.log(`      Date: ${issue.date}`);
        console.log(`      Issue: ${issue.message}`);
        if (issue.fixes) {
          console.log(`      Fixes applied:`, JSON.stringify(issue.fixes, null, 2));
        }
      }
      
      if (issues.length > sampleSize) {
        console.log(`\n   ... and ${issues.length - sampleSize} more issues`);
      }
    }

    if (stats.errors.length > 0) {
      console.log(`\n⚠️  Errors encountered: ${stats.errors.length}`);
      stats.errors.forEach(err => console.log(`   - ${err}`));
    }

    if (DRY_RUN) {
      console.log('\n⚠️  This was a DRY RUN - no changes were applied');
      console.log('   Run without --dry-run to apply changes');
    } else {
      console.log('\n✅ Validation and fixes completed successfully!');
      console.log(`   ${stats.fixed} entries fixed, ${stats.deleted} orphaned entries deleted`);
    }

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error during validation:', error);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  }
}

// Run the validation
validateAndFixAllTimesheets();

