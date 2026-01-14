/**
 * Fix Missing yearMonth Script
 * 
 * Backfills yearMonth field for form responses that are missing it
 * Uses shift date to determine the correct yearMonth
 * 
 * Usage:
 *   node scripts/fix_missing_yearmonth.js [teacherId] [yearMonth]
 * 
 * Examples:
 *   node scripts/fix_missing_yearmonth.js                                    # All teachers, all months
 *   node scripts/fix_missing_yearmonth.js Thz8PIVUGpS5cjlIYBJAemjoQxw1       # Aliou Diallo, all months
 *   node scripts/fix_missing_yearmonth.js Thz8PIVUGpS5cjlIYBJAemjoQxw1 2026-01  # Aliou Diallo, January 2026
 * 
 * Requirements:
 *   - Firebase Admin SDK credentials:
 *     * Option 1: Place serviceAccountKey.json in project root
 *     * Option 2: Run: gcloud auth application-default login
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  
  if (fs.existsSync(serviceAccountPath)) {
    try {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: serviceAccount.project_id || 'alluwal-academy'
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
        projectId: process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'alluwal-academy'
      });
      console.log('✅ Initialized Firebase Admin with application default credentials\n');
    } catch (err) {
      console.error('❌ Error initializing Firebase Admin:');
      console.error('   Please ensure you have either:');
      console.error('   1. A serviceAccountKey.json file in the project root, OR');
      console.error('   2. Application Default Credentials configured (gcloud auth application-default login)');
      console.error('   Error details:', err.message);
      process.exit(1);
    }
  }
}

const db = admin.firestore();

// Get teacher ID from args (optional)
function getTeacherId() {
  return process.argv[2] || null;
}

// Get yearMonth from args (optional)
function getYearMonth() {
  return process.argv[3] || null;
}

// Format date for display
function formatDate(timestamp) {
  if (!timestamp) return 'N/A';
  if (timestamp.toDate) {
    return timestamp.toDate().toLocaleString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  }
  return timestamp.toString();
}

async function fixMissingYearMonth() {
  const teacherId = getTeacherId();
  const yearMonth = getYearMonth();
  
  console.log('='.repeat(80));
  console.log('FIX MISSING YEARMONTH SCRIPT');
  console.log('='.repeat(80));
  console.log(`Started at: ${new Date().toISOString()}`);
  if (teacherId) {
    console.log(`Teacher ID: ${teacherId}`);
  } else {
    console.log(`Teacher ID: ALL TEACHERS`);
  }
  if (yearMonth) {
    console.log(`YearMonth Filter: ${yearMonth}`);
  } else {
    console.log(`YearMonth Filter: ALL MONTHS`);
  }
  console.log('');

  try {
    // Query form_responses missing yearMonth
    let query = db.collection('form_responses');
    
    // Filter by teacher if specified
    if (teacherId) {
      query = query.where('userId', '==', teacherId);
    }
    
    // Get all responses (we'll filter for missing yearMonth in memory)
    const snapshot = await query.get();
    
    console.log(`Found ${snapshot.size} total form responses`);
    if (teacherId) {
      console.log(`  (Filtered by teacher: ${teacherId})`);
    }
    console.log('');

    const formsToFix = [];
    const formsWithYearMonth = [];
    const formsWithoutShift = [];
    const formsWithInvalidShift = [];
    
    // Process each form response
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Skip if already has yearMonth
      if (data.yearMonth) {
        formsWithYearMonth.push({
          id: doc.id,
          yearMonth: data.yearMonth,
        });
        continue;
      }
      
      // Try to determine yearMonth from shift
      let calculatedYearMonth = null;
      let source = 'unknown';
      
      // Method 1: Get from shiftId (preferred - most accurate)
      if (data.shiftId) {
        try {
          const shiftDoc = await db.collection('teaching_shifts').doc(data.shiftId).get();
          if (shiftDoc.exists) {
            const shiftData = shiftDoc.data();
            const shiftStart = shiftData.shift_start;
            if (shiftStart && shiftStart.toDate) {
              const shiftDate = shiftStart.toDate();
              const year = shiftDate.getFullYear();
              const month = String(shiftDate.getMonth() + 1).padStart(2, '0');
              calculatedYearMonth = `${year}-${month}`;
              source = 'shift_start';
            }
          } else {
            formsWithInvalidShift.push({
              id: doc.id,
              shiftId: data.shiftId,
              reason: 'Shift document not found',
            });
          }
        } catch (err) {
          formsWithInvalidShift.push({
            id: doc.id,
            shiftId: data.shiftId,
            reason: `Error reading shift: ${err.message}`,
          });
        }
      }
      
      // Method 2: Get from timesheetId (fallback)
      if (!calculatedYearMonth && data.timesheetId) {
        try {
          const timesheetDoc = await db.collection('timesheet_entries').doc(data.timesheetId).get();
          if (timesheetDoc.exists) {
            const timesheetData = timesheetDoc.data();
            const shiftId = timesheetData.shift_id || timesheetData.shiftId;
            if (shiftId) {
              const shiftDoc = await db.collection('teaching_shifts').doc(shiftId).get();
              if (shiftDoc.exists) {
                const shiftData = shiftDoc.data();
                const shiftStart = shiftData.shift_start;
                if (shiftStart && shiftStart.toDate) {
                  const shiftDate = shiftStart.toDate();
                  const year = shiftDate.getFullYear();
                  const month = String(shiftDate.getMonth() + 1).padStart(2, '0');
                  calculatedYearMonth = `${year}-${month}`;
                  source = 'timesheet->shift_start';
                }
              }
            }
            // Fallback to timesheet created_at if shift not found
            if (!calculatedYearMonth) {
              const createdAt = timesheetData.created_at || timesheetData.createdAt;
              if (createdAt && createdAt.toDate) {
                const timesheetDate = createdAt.toDate();
                const year = timesheetDate.getFullYear();
                const month = String(timesheetDate.getMonth() + 1).padStart(2, '0');
                calculatedYearMonth = `${year}-${month}`;
                source = 'timesheet_created_at';
              }
            }
          }
        } catch (err) {
          // Continue to next method
        }
      }
      
      // Method 3: Get from submittedAt (last resort - less accurate)
      if (!calculatedYearMonth && data.submittedAt) {
        try {
          const submittedDate = data.submittedAt.toDate();
          const year = submittedDate.getFullYear();
          const month = String(submittedDate.getMonth() + 1).padStart(2, '0');
          calculatedYearMonth = `${year}-${month}`;
          source = 'submittedAt';
        } catch (err) {
          // Cannot determine yearMonth
        }
      }
      
      // Check if we should process this form
      if (calculatedYearMonth) {
        // If yearMonth filter is specified, only process matching forms
        if (yearMonth && calculatedYearMonth !== yearMonth) {
          continue;
        }
        
        formsToFix.push({
          id: doc.id,
          userId: data.userId || data.submitted_by || 'unknown',
          formId: data.formId || 'unknown',
          shiftId: data.shiftId || null,
          timesheetId: data.timesheetId || null,
          submittedAt: formatDate(data.submittedAt),
          calculatedYearMonth: calculatedYearMonth,
          source: source,
        });
      } else {
        formsWithoutShift.push({
          id: doc.id,
          userId: data.userId || data.submitted_by || 'unknown',
          formId: data.formId || 'unknown',
          shiftId: data.shiftId || null,
          timesheetId: data.timesheetId || null,
          submittedAt: formatDate(data.submittedAt),
        });
      }
    }
    
    console.log('='.repeat(80));
    console.log('ANALYSIS RESULTS');
    console.log('='.repeat(80));
    console.log(`Forms WITH yearMonth: ${formsWithYearMonth.length}`);
    console.log(`Forms TO FIX: ${formsToFix.length}`);
    console.log(`Forms WITHOUT shift/timesheet (cannot fix): ${formsWithoutShift.length}`);
    console.log(`Forms WITH invalid shift: ${formsWithInvalidShift.length}`);
    console.log('');
    
    if (formsToFix.length === 0) {
      console.log('✅ No forms need fixing!');
      if (yearMonth) {
        console.log(`   (All forms for ${yearMonth} already have yearMonth)`);
      } else {
        console.log(`   (All forms already have yearMonth)`);
      }
      return;
    }
    
    // Group by yearMonth
    const groupedByMonth = {};
    for (const form of formsToFix) {
      const month = form.calculatedYearMonth;
      if (!groupedByMonth[month]) {
        groupedByMonth[month] = [];
      }
      groupedByMonth[month].push(form);
    }
    
    console.log('Forms to fix by month:');
    for (const [month, forms] of Object.entries(groupedByMonth)) {
      console.log(`  ${month}: ${forms.length} form(s)`);
    }
    console.log('');
    
    // Show sample forms to fix
    console.log('Sample forms to fix (first 10):');
    formsToFix.slice(0, 10).forEach((form, index) => {
      console.log(`  ${index + 1}. ${form.id}:`);
      console.log(`      User: ${form.userId}`);
      console.log(`      Form: ${form.formId}`);
      console.log(`      Submitted: ${form.submittedAt}`);
      console.log(`      Will set yearMonth: ${form.calculatedYearMonth} (from ${form.source})`);
      console.log(`      shiftId: ${form.shiftId || 'MISSING'}`);
      console.log(`      timesheetId: ${form.timesheetId || 'MISSING'}`);
    });
    if (formsToFix.length > 10) {
      console.log(`  ... and ${formsToFix.length - 10} more`);
    }
    console.log('');
    
    // Ask for confirmation
    console.log('='.repeat(80));
    console.log('READY TO UPDATE');
    console.log('='.repeat(80));
    console.log(`This will update ${formsToFix.length} form response(s) with yearMonth field.`);
    console.log('');
    
    // Process in batches
    const batchSize = 500;
    let batch = db.batch();
    let batchCount = 0;
    let totalUpdated = 0;
    
    for (const form of formsToFix) {
      const docRef = db.collection('form_responses').doc(form.id);
      batch.update(docRef, {
        yearMonth: form.calculatedYearMonth,
        yearMonth_fixed_at: admin.firestore.FieldValue.serverTimestamp(),
        yearMonth_source: form.source,
      });
      batchCount++;
      totalUpdated++;
      
      // Commit batch when full
      if (batchCount >= batchSize) {
        await batch.commit();
        console.log(`✅ Committed batch of ${batchCount} updates`);
        batch = db.batch();
        batchCount = 0;
      }
    }
    
    // Commit remaining batch
    if (batchCount > 0) {
      await batch.commit();
      console.log(`✅ Committed final batch of ${batchCount} updates`);
    }
    
    console.log('');
    console.log('='.repeat(80));
    console.log('SUMMARY');
    console.log('='.repeat(80));
    console.log(`Total forms processed: ${snapshot.size}`);
    console.log(`Forms already had yearMonth: ${formsWithYearMonth.length}`);
    console.log(`Forms updated: ${totalUpdated}`);
    console.log(`Forms cannot be fixed (no shift/timesheet): ${formsWithoutShift.length}`);
    console.log(`Forms with invalid shift: ${formsWithInvalidShift.length}`);
    console.log('');
    
    if (formsWithoutShift.length > 0) {
      console.log('⚠️  Forms that cannot be automatically fixed (need manual review):');
      formsWithoutShift.slice(0, 10).forEach(form => {
        console.log(`  - ${form.id}: userId=${form.userId}, formId=${form.formId}, submitted=${form.submittedAt}`);
      });
      if (formsWithoutShift.length > 10) {
        console.log(`  ... and ${formsWithoutShift.length - 10} more`);
      }
    }
    
    console.log('');
    console.log(`✅ Completed at: ${new Date().toISOString()}`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error('\n❌ Fatal error during fix:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the fix
fixMissingYearMonth()
  .then(() => {
    console.log('\n✅ Fix completed successfully');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Fix failed:', error);
    process.exit(1);
  });
