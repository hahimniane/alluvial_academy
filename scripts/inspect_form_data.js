/**
 * Form Data Inspection Script
 * 
 * Inspects all form-related collections in Firestore to debug audit issues
 * 
 * Usage:
 *   node scripts/inspect_form_data.js [teacherId] [yearMonth]
 * 
 * Examples:
 *   node scripts/inspect_form_data.js                                    # All teachers, current month
 *   node scripts/inspect_form_data.js Thz8PIVUGpS5cjlIYBJAemjoQxw1       # Aliou Diallo, current month
 *   node scripts/inspect_form_data.js Thz8PIVUGpS5cjlIYBJAemjoQxw1 2026-01  # Aliou Diallo, January 2026
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

// Get teacher ID from args
function getTeacherId() {
  return process.argv[2] || null;
}

// Get yearMonth from args or use current
function getYearMonth() {
  if (process.argv[3] && /^\d{4}-\d{2}$/.test(process.argv[3])) {
    return process.argv[3];
  }
  const now = new Date();
  return `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}`;
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

// Print separator
function printSeparator(char = '═', length = 80) {
  console.log(char.repeat(length));
}

// Print section header
function printSection(title) {
  console.log('');
  printSeparator('═');
  console.log(`  ${title}`);
  printSeparator('═');
}

// Print subsection
function printSubsection(title) {
  console.log('');
  console.log(`  ${title}`);
  console.log('  ' + '─'.repeat(78));
}

async function inspectFormData() {
  const teacherId = getTeacherId();
  const yearMonth = getYearMonth();
  
  console.log('='.repeat(80));
  console.log('FORM DATA INSPECTION TOOL');
  console.log('='.repeat(80));
  console.log(`Started at: ${new Date().toISOString()}`);
  console.log(`YearMonth: ${yearMonth}`);
  if (teacherId) {
    console.log(`Teacher ID: ${teacherId}`);
  } else {
    console.log(`Teacher ID: ALL TEACHERS`);
  }
  console.log('');

  try {
    // ============================================================
    // 1. INSPECT FORM_TEMPLATES COLLECTION
    // ============================================================
    printSection('1. FORM_TEMPLATES COLLECTION');
    
    const templatesSnapshot = await db.collection('form_templates').get();
    console.log(`Total templates: ${templatesSnapshot.size}`);
    
    const templatesByFrequency = {};
    const activeTemplates = [];
    const inactiveTemplates = [];
    
    for (const doc of templatesSnapshot.docs) {
      const data = doc.data();
      const frequency = data.frequency || 'unknown';
      const isActive = data.isActive !== false;
      
      if (!templatesByFrequency[frequency]) {
        templatesByFrequency[frequency] = [];
      }
      templatesByFrequency[frequency].push({
        id: doc.id,
        name: data.name || 'Untitled',
        version: data.version || 1,
        isActive: isActive,
        createdAt: formatDate(data.createdAt),
        updatedAt: formatDate(data.updatedAt),
      });
      
      if (isActive) {
        activeTemplates.push({
          id: doc.id,
          name: data.name || 'Untitled',
          version: data.version || 1,
          frequency: frequency,
        });
      } else {
        inactiveTemplates.push({
          id: doc.id,
          name: data.name || 'Untitled',
          version: data.version || 1,
        });
      }
    }
    
    console.log(`Active templates: ${activeTemplates.length}`);
    console.log(`Inactive templates: ${inactiveTemplates.length}`);
    
    printSubsection('Templates by Frequency:');
    for (const [freq, templates] of Object.entries(templatesByFrequency)) {
      console.log(`  ${freq}: ${templates.length} template(s)`);
      templates.forEach(t => {
        console.log(`    - ${t.name} (v${t.version}) [${t.isActive ? 'ACTIVE' : 'INACTIVE'}] - ID: ${t.id}`);
      });
    }
    
    // Find "Daily Class Report" templates
    const dailyTemplates = activeTemplates.filter(t => 
      t.name.toLowerCase().includes('daily') && 
      (t.name.toLowerCase().includes('class') || t.name.toLowerCase().includes('report'))
    );
    
    if (dailyTemplates.length > 0) {
      printSubsection('Daily Class Report Templates (Active):');
      dailyTemplates.forEach(t => {
        console.log(`  - ${t.name} (v${t.version}) - ID: ${t.id}`);
      });
    }

    // ============================================================
    // 2. INSPECT FORM COLLECTION (OLD SYSTEM)
    // ============================================================
    printSection('2. FORM COLLECTION (OLD SYSTEM)');
    
    const formsSnapshot = await db.collection('form').get();
    console.log(`Total forms (old system): ${formsSnapshot.size}`);
    
    const oldFormsByStatus = {};
    for (const doc of formsSnapshot.docs) {
      const data = doc.data();
      const status = data.status || 'unknown';
      if (!oldFormsByStatus[status]) {
        oldFormsByStatus[status] = [];
      }
      oldFormsByStatus[status].push({
        id: doc.id,
        title: data.title || 'Untitled',
        status: status,
      });
    }
    
    for (const [status, forms] of Object.entries(oldFormsByStatus)) {
      console.log(`  ${status}: ${forms.length} form(s)`);
      if (forms.length <= 5) {
        forms.forEach(f => {
          console.log(`    - ${f.title} - ID: ${f.id}`);
        });
      }
    }

    // ============================================================
    // 3. INSPECT FORM_RESPONSES COLLECTION
    // ============================================================
    printSection('3. FORM_RESPONSES COLLECTION');
    
    let responsesQuery = db.collection('form_responses');
    
    // Filter by teacher if specified
    if (teacherId) {
      responsesQuery = responsesQuery.where('userId', '==', teacherId);
    }
    
    // Filter by yearMonth if specified
    responsesQuery = responsesQuery.where('yearMonth', '==', yearMonth);
    
    const responsesSnapshot = await responsesQuery.get();
    console.log(`Total form responses for ${yearMonth}: ${responsesSnapshot.size}`);
    
    if (teacherId) {
      console.log(`  (Filtered by teacher: ${teacherId})`);
    }
    
    // Group by formId/templateId
    const responsesByForm = {};
    const responsesWithoutShiftId = [];
    const responsesWithoutYearMonth = [];
    const responsesWithMissingData = [];
    
    for (const doc of responsesSnapshot.docs) {
      const data = doc.data();
      const formId = data.formId || 'unknown';
      const templateId = data.templateId || null;
      const shiftId = data.shiftId || null;
      const timesheetId = data.timesheetId || null;
      const userId = data.userId || data.submitted_by || 'unknown';
      const yearMonthValue = data.yearMonth || null;
      
      // Track issues
      if (!shiftId && !timesheetId) {
        responsesWithoutShiftId.push({
          id: doc.id,
          formId: formId,
          userId: userId,
          submittedAt: formatDate(data.submittedAt),
        });
      }
      
      if (!yearMonthValue) {
        responsesWithoutYearMonth.push({
          id: doc.id,
          formId: formId,
          userId: userId,
        });
      }
      
      // Check for missing critical fields
      if (!data.submittedAt || !userId || !formId) {
        responsesWithMissingData.push({
          id: doc.id,
          hasSubmittedAt: !!data.submittedAt,
          hasUserId: !!userId,
          hasFormId: !!formId,
        });
      }
      
      const key = templateId ? `template:${templateId}` : `form:${formId}`;
      if (!responsesByForm[key]) {
        responsesByForm[key] = {
          formId: formId,
          templateId: templateId,
          formName: data.formName || 'Unknown',
          formType: data.formType || 'legacy',
          frequency: data.frequency || null,
          count: 0,
          responses: [],
        };
      }
      
      responsesByForm[key].count++;
      responsesByForm[key].responses.push({
        id: doc.id,
        shiftId: shiftId,
        timesheetId: timesheetId,
        userId: userId,
        submittedAt: formatDate(data.submittedAt),
        yearMonth: yearMonthValue,
        hasShiftId: !!shiftId,
        hasTimesheetId: !!timesheetId,
      });
    }
    
    printSubsection('Responses by Form/Template:');
    for (const [key, info] of Object.entries(responsesByForm)) {
      console.log(`  ${key}:`);
      console.log(`    Form Name: ${info.formName}`);
      console.log(`    Form Type: ${info.formType}`);
      if (info.frequency) console.log(`    Frequency: ${info.frequency}`);
      console.log(`    Total Responses: ${info.count}`);
      console.log(`    With shiftId: ${info.responses.filter(r => r.hasShiftId).length}`);
      console.log(`    With timesheetId: ${info.responses.filter(r => r.hasTimesheetId).length}`);
      console.log(`    Without linkage: ${info.responses.filter(r => !r.hasShiftId && !r.hasTimesheetId).length}`);
      
      // Show sample responses
      if (info.responses.length <= 3) {
        info.responses.forEach(r => {
          console.log(`      - Response ${r.id}:`);
          console.log(`          Submitted: ${r.submittedAt}`);
          console.log(`          shiftId: ${r.shiftId || 'MISSING'}`);
          console.log(`          timesheetId: ${r.timesheetId || 'MISSING'}`);
          console.log(`          yearMonth: ${r.yearMonth || 'MISSING'}`);
        });
      } else {
        console.log(`      Sample (first 3 of ${info.responses.length}):`);
        info.responses.slice(0, 3).forEach(r => {
          console.log(`        - ${r.id}: shiftId=${r.shiftId || 'MISSING'}, timesheetId=${r.timesheetId || 'MISSING'}, submitted=${r.submittedAt}`);
        });
      }
    }
    
    // Show issues
    if (responsesWithoutShiftId.length > 0) {
      printSubsection(`⚠️  Responses WITHOUT shiftId or timesheetId (${responsesWithoutShiftId.length}):`);
      responsesWithoutShiftId.slice(0, 10).forEach(r => {
        console.log(`    - ${r.id}: formId=${r.formId}, userId=${r.userId}, submitted=${r.submittedAt}`);
      });
      if (responsesWithoutShiftId.length > 10) {
        console.log(`    ... and ${responsesWithoutShiftId.length - 10} more`);
      }
    }
    
    if (responsesWithoutYearMonth.length > 0) {
      printSubsection(`⚠️  Responses WITHOUT yearMonth (${responsesWithoutYearMonth.length}):`);
      responsesWithoutYearMonth.slice(0, 10).forEach(r => {
        console.log(`    - ${r.id}: formId=${r.formId}, userId=${r.userId}`);
      });
    }
    
    if (responsesWithMissingData.length > 0) {
      printSubsection(`⚠️  Responses WITH missing critical data (${responsesWithMissingData.length}):`);
      responsesWithMissingData.slice(0, 10).forEach(r => {
        console.log(`    - ${r.id}: hasSubmittedAt=${r.hasSubmittedAt}, hasUserId=${r.hasUserId}, hasFormId=${r.hasFormId}`);
      });
    }

    // ============================================================
    // 4. DETAILED INSPECTION FOR SPECIFIC TEACHER
    // ============================================================
    if (teacherId) {
      printSection(`4. DETAILED INSPECTION FOR TEACHER: ${teacherId}`);
      
      // Get teacher info
      const teacherDoc = await db.collection('users').doc(teacherId).get();
      if (teacherDoc.exists) {
        const teacherData = teacherDoc.data();
        console.log(`Teacher Name: ${teacherData.first_name || ''} ${teacherData.last_name || ''}`);
        console.log(`Teacher Email: ${teacherData.email || teacherData['e-mail'] || 'N/A'}`);
        console.log(`Teacher Role: ${teacherData.user_type || teacherData.role || 'N/A'}`);
      } else {
        console.log(`⚠️  Teacher document not found in users collection`);
      }
      
      // Get ALL responses for this teacher (not filtered by yearMonth)
      const allResponsesQuery = await db.collection('form_responses')
        .where('userId', '==', teacherId)
        .orderBy('submittedAt', 'desc')
        .limit(50)
        .get();
      
      console.log(`\nTotal responses for this teacher (last 50): ${allResponsesQuery.size}`);
      
      // Group by yearMonth
      const responsesByMonth = {};
      for (const doc of allResponsesQuery.docs) {
        const data = doc.data();
        const month = data.yearMonth || 'NO_YEARMONTH';
        if (!responsesByMonth[month]) {
          responsesByMonth[month] = [];
        }
        responsesByMonth[month].push({
          id: doc.id,
          formId: data.formId || 'unknown',
          templateId: data.templateId || null,
          formName: data.formName || 'Unknown',
          shiftId: data.shiftId || null,
          timesheetId: data.timesheetId || null,
          submittedAt: formatDate(data.submittedAt),
          yearMonth: data.yearMonth || null,
        });
      }
      
      printSubsection('Responses by Month:');
      for (const [month, responses] of Object.entries(responsesByMonth)) {
        console.log(`  ${month}: ${responses.length} response(s)`);
        responses.forEach(r => {
          console.log(`    - ${r.formName} (${r.formId})`);
          console.log(`        Submitted: ${r.submittedAt}`);
          console.log(`        shiftId: ${r.shiftId || 'MISSING'}`);
          console.log(`        timesheetId: ${r.timesheetId || 'MISSING'}`);
          console.log(`        templateId: ${r.templateId || 'N/A (old form)'}`);
        });
      }
      
      // Check shifts for this teacher in the month
      const { startDate, endDate } = parseYearMonth(yearMonth);
      const shiftsQuery = await db.collection('teaching_shifts')
        .where('teacher_id', '==', teacherId)
        .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(startDate))
        .where('shift_start', '<=', admin.firestore.Timestamp.fromDate(endDate))
        .get();
      
      console.log(`\nShifts for this teacher in ${yearMonth}: ${shiftsQuery.size}`);
      
      // Check timesheets for this teacher in the month
      const timesheetsQuery = await db.collection('timesheet_entries')
        .where('teacher_id', '==', teacherId)
        .where('created_at', '>=', admin.firestore.Timestamp.fromDate(startDate))
        .where('created_at', '<=', admin.firestore.Timestamp.fromDate(endDate))
        .get();
      
      console.log(`Timesheets for this teacher in ${yearMonth}: ${timesheetsQuery.size}`);
      
      // Check which shifts have forms
      const shiftsWithForms = new Set();
      const shiftsWithoutForms = [];
      
      for (const shiftDoc of shiftsQuery.docs) {
        const shiftId = shiftDoc.id;
        const shiftData = shiftDoc.data();
        const status = shiftData.status || 'scheduled';
        
        // Check if form exists for this shift
        const formQuery = await db.collection('form_responses')
          .where('shiftId', '==', shiftId)
          .where('userId', '==', teacherId)
          .limit(1)
          .get();
        
        if (formQuery.size > 0) {
          shiftsWithForms.add(shiftId);
        } else {
          // Also check via timesheet
          const timesheetQuery = await db.collection('timesheet_entries')
            .where('shift_id', '==', shiftId)
            .where('teacher_id', '==', teacherId)
            .limit(1)
            .get();
          
          if (timesheetQuery.size > 0) {
            const tsDoc = timesheetQuery.docs[0];
            const tsData = tsDoc.data();
            if (tsData.form_completed || tsData.form_response_id) {
              shiftsWithForms.add(shiftId);
            } else {
              shiftsWithoutForms.push({
                shiftId: shiftId,
                status: status,
                hasTimesheet: true,
                timesheetId: tsDoc.id,
              });
            }
          } else {
            shiftsWithoutForms.push({
              shiftId: shiftId,
              status: status,
              hasTimesheet: false,
            });
          }
        }
      }
      
      console.log(`\nShifts WITH forms: ${shiftsWithForms.size}`);
      console.log(`Shifts WITHOUT forms: ${shiftsWithoutForms.length}`);
      
      if (shiftsWithoutForms.length > 0) {
        printSubsection('Shifts Missing Forms:');
        shiftsWithoutForms.slice(0, 10).forEach(s => {
          console.log(`  - Shift ${s.shiftId}: status=${s.status}, hasTimesheet=${s.hasTimesheet}`);
        });
        if (shiftsWithoutForms.length > 10) {
          console.log(`  ... and ${shiftsWithoutForms.length - 10} more`);
        }
      }
    }

    // ============================================================
    // 5. SAMPLE FORM RESPONSE STRUCTURE
    // ============================================================
    if (responsesSnapshot.size > 0) {
      printSection('5. SAMPLE FORM RESPONSE STRUCTURE');
      
      const sampleDoc = responsesSnapshot.docs[0];
      const sampleData = sampleDoc.data();
      
      console.log(`Sample Response ID: ${sampleDoc.id}`);
      console.log(`\nFull Document Structure:`);
      console.log(JSON.stringify(sampleData, null, 2));
      
      // Show autofilled fields
      if (sampleData.responses) {
        printSubsection('Autofilled Fields (fields starting with _):');
        const autofilledFields = Object.keys(sampleData.responses).filter(k => k.startsWith('_'));
        if (autofilledFields.length > 0) {
          autofilledFields.forEach(field => {
            console.log(`  - ${field}: ${JSON.stringify(sampleData.responses[field])}`);
          });
        } else {
          console.log(`  ⚠️  No autofilled fields found (fields starting with _)`);
        }
      }
    }

    // ============================================================
    // 6. SUMMARY AND RECOMMENDATIONS
    // ============================================================
    printSection('6. SUMMARY AND RECOMMENDATIONS');
    
    console.log(`\nTotal Form Templates: ${templatesSnapshot.size}`);
    console.log(`Total Old Forms: ${formsSnapshot.size}`);
    console.log(`Total Form Responses (${yearMonth}): ${responsesSnapshot.size}`);
    
    if (teacherId) {
      const teacherResponses = responsesSnapshot.size;
      console.log(`\nFor Teacher ${teacherId}:`);
      console.log(`  - Responses found: ${teacherResponses}`);
      console.log(`  - Responses without shiftId: ${responsesWithoutShiftId.length}`);
      console.log(`  - Responses without yearMonth: ${responsesWithoutYearMonth.length}`);
      
      if (teacherResponses === 0) {
        console.log(`\n⚠️  ISSUE: No responses found for this teacher in ${yearMonth}`);
        console.log(`  Possible causes:`);
        console.log(`  1. Forms were submitted with wrong yearMonth`);
        console.log(`  2. Forms were submitted without shiftId/timesheetId context`);
        console.log(`  3. Forms are in a different month`);
        console.log(`  4. Forms are using different userId field`);
      } else if (responsesWithoutShiftId.length > 0) {
        console.log(`\n⚠️  ISSUE: ${responsesWithoutShiftId.length} responses are missing shiftId/timesheetId`);
        console.log(`  These forms cannot be linked to specific shifts for audit purposes`);
      }
    }
    
    console.log('\n' + '='.repeat(80));
    console.log(`Completed at: ${new Date().toISOString()}`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error('\n❌ Fatal error during inspection:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Parse yearMonth to date range
function parseYearMonth(yearMonth) {
  const [year, month] = yearMonth.split('-').map(Number);
  const startDate = new Date(year, month - 1, 1, 0, 0, 0);
  const endDate = new Date(year, month, 0, 23, 59, 59);
  return { startDate, endDate };
}

// Run the inspection
inspectFormData()
  .then(() => {
    console.log('\n✅ Inspection completed successfully');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Inspection failed:', error);
    process.exit(1);
  });
