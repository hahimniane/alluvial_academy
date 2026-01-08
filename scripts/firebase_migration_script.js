/**
 * Firebase Migration Script for Alluvial Academy
 * 
 * This script migrates and updates the following collections:
 * 1. form_templates - User-friendly form templates (Daily, Weekly, Monthly)
 * 2. form_responses - Migrate old responses to new format
 * 3. form (legacy) - Map old form fields to new structure
 * 
 * Run with: node firebase_migration_script.js
 * 
 * Prerequisites:
 * - npm install firebase-admin
 * - Set GOOGLE_APPLICATION_CREDENTIALS to your service account key
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin (same pattern as other scripts)
if (!admin.apps.length) {
  const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  
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
    // Try to use application default credentials (from firebase login)
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

// ============================================================================
// NEW FORM TEMPLATES - User-Friendly English Fields
// ============================================================================

const NEW_FORM_TEMPLATES = {
  // Daily Class Report (perSession) - SHIFT-BASED
  daily_class_report: {
    name: 'Daily Class Report',
    description: 'Post-class report linked to a specific shift',
    frequency: 'perSession',
    isActive: true,
    version: 3,
    requiresShift: true, // NEW: Form must be linked to a shift
    autoFillRules: [
      { fieldId: '_shift_id', sourceField: 'shiftId', editable: false },
      { fieldId: '_shift_subject', sourceField: 'shift.subjectDisplayName', editable: false },
      { fieldId: '_shift_students', sourceField: 'shift.studentNames', editable: false },
      { fieldId: '_shift_duration', sourceField: 'shift.duration', editable: false },
      { fieldId: '_shift_class_type', sourceField: 'shift.classType', editable: false },
      { fieldId: '_clock_in_time', sourceField: 'shift.clockInTime', editable: false },
      { fieldId: '_clock_out_time', sourceField: 'shift.clockOutTime', editable: false },
    ],
    fields: [
      {
        id: 'actual_duration',
        label: 'Actual class duration (hours)',
        type: 'number',
        order: 1,
        required: true,
        placeholder: 'Actual time spent (may differ from scheduled)',
        validation: { min: 0.25, max: 4 },
        defaultFromShift: 'duration',
      },
      {
        id: 'students_attended',
        label: 'Which students attended?',
        type: 'multi_select',
        order: 2,
        required: true,
        optionsFromShift: 'studentNames',
        placeholder: 'Select students who attended',
      },
      {
        id: 'lesson_covered',
        label: 'What lesson/topic did you teach?',
        type: 'text',
        order: 3,
        required: true,
        placeholder: 'e.g., Surah Al-Fatiha verses 1-3',
      },
      {
        id: 'used_curriculum',
        label: 'Did you use the official curriculum?',
        type: 'radio',
        order: 4,
        required: true,
        options: ['Yes, Used Official Curriculum', 'No, Used Own Content', 'Partially Used', 'Not Sure'],
      },
      {
        id: 'session_quality',
        label: 'How did the session go?',
        type: 'radio',
        order: 5,
        required: true,
        options: ['Excellent', 'Good', 'Average', 'Challenging'],
      },
      {
        id: 'teacher_notes',
        label: 'Additional notes or observations',
        type: 'long_text',
        order: 6,
        required: false,
        placeholder: 'Any important observations, student progress, or concerns',
      },
    ],
  },

  // Weekly Summary
  weekly_summary: {
    name: 'Weekly Summary',
    description: 'End of week teaching summary and reflection',
    frequency: 'weekly',
    isActive: true,
    version: 3,
    requiresShift: false, // Weekly summary is not tied to a specific shift
    autoFillRules: [
      { fieldId: '_teacher_name', sourceField: 'teacherName', editable: false },
      { fieldId: '_week_ending', sourceField: 'weekEndingDate', editable: false },
      { fieldId: '_week_shifts_count', sourceField: 'weekShiftsCount', editable: false },
      { fieldId: '_week_completed_classes', sourceField: 'weekCompletedClasses', editable: false },
    ],
    fields: [
      {
        id: 'weekly_rating',
        label: 'How would you rate this week overall?',
        type: 'radio',
        order: 1,
        required: true,
        options: ['Excellent', 'Good', 'Average', 'Challenging'],
      },
      {
        id: 'classes_taught',
        label: 'How many classes did you teach this week?',
        type: 'number',
        order: 2,
        required: true,
        validation: { min: 0, max: 50 },
      },
      {
        id: 'absences_this_week',
        label: 'How many classes did you miss this week?',
        type: 'radio',
        order: 3,
        required: true,
        options: ['0 (None)', '1 class', '2 classes', '3 classes', '4+ classes'],
      },
      {
        id: 'video_recording_done',
        label: 'Did you complete your weekly post-class video recording?',
        type: 'radio',
        order: 4,
        required: true,
        options: ['Yes', 'No', 'N/A'],
      },
      {
        id: 'achievements',
        label: 'Key achievements this week',
        type: 'long_text',
        order: 5,
        required: true,
        placeholder: 'Summarize student progress, milestones reached, etc.',
      },
      {
        id: 'challenges',
        label: 'Any challenges or support needed?',
        type: 'long_text',
        order: 6,
        required: false,
        placeholder: 'Leave empty if none',
      },
      {
        id: 'coach_helpfulness',
        label: 'How helpful was your coach this week?',
        type: 'radio',
        order: 7,
        required: true,
        options: ['Very Helpful', 'Somewhat Helpful', 'Not Helpful', 'Please Change My Coach', 'N/A'],
      },
    ],
  },

  // Monthly Review
  monthly_review: {
    name: 'Monthly Review',
    description: 'End of month teaching review and student attendance summary',
    frequency: 'monthly',
    isActive: true,
    version: 3,
    requiresShift: false, // Monthly review is not tied to a specific shift
    autoFillRules: [
      { fieldId: '_teacher_name', sourceField: 'teacherName', editable: false },
      { fieldId: '_month', sourceField: 'monthDate', editable: false },
      { fieldId: '_month_total_classes', sourceField: 'monthTotalClasses', editable: false },
      { fieldId: '_month_completed', sourceField: 'monthCompletedClasses', editable: false },
    ],
    fields: [
      {
        id: 'month_rating',
        label: 'How would you rate this month?',
        type: 'radio',
        order: 1,
        required: true,
        options: ['Excellent', 'Good', 'Average', 'Challenging'],
      },
      {
        id: 'goals_met',
        label: 'Were your teaching goals met?',
        type: 'radio',
        order: 2,
        required: true,
        options: ['Yes, All Goals', 'Most Goals', 'Some Goals', 'Few Goals'],
      },
      {
        id: 'bayana_completed',
        label: 'Did you have Group Bayana with students this month?',
        type: 'radio',
        order: 3,
        required: true,
        options: ['Yes', 'No', 'N/A'],
      },
      {
        id: 'student_attendance_summary',
        label: 'Student attendance issues this month',
        type: 'long_text',
        order: 4,
        required: false,
        placeholder: 'List students who were frequently absent or late, or who missed Bayana',
      },
      {
        id: 'monthly_achievements',
        label: 'Key achievements this month',
        type: 'long_text',
        order: 5,
        required: true,
        placeholder: 'Summarize progress, student improvements, etc.',
      },
      {
        id: 'comments_for_admin',
        label: 'Comments for admin',
        type: 'long_text',
        order: 6,
        required: false,
        placeholder: 'Any feedback, requests, or concerns',
      },
    ],
  },
};

// ============================================================================
// FIELD MAPPING: Old bilingual fields -> New English fields
// ============================================================================

const FIELD_MAPPING = {
  // Device used
  '1754405971187': 'device_used',
  // Class type
  '1754406115874': 'class_type',
  // Class day
  '1754406288023': 'class_day',
  // Duration
  '1754406414139': 'class_duration',
  // Students present
  '1754406457284': 'students_present',
  // Students absent
  '1754406487572': 'students_absent',
  // Students late
  '1754406512129': 'students_late',
  // Video recording done
  '1754406537658': 'video_recording_done',
  // Teacher arrival
  '1754406625835': 'teacher_arrival',
  // Absences this week
  '1754406729715': 'absences_this_week',
  // Clock in time
  '1754406826688': 'clock_in_time',
  // Clock out time
  '1754406914911': 'clock_out_time',
  // Bayana completed
  '1754407016623': 'bayana_completed',
  // Outside schedule
  '1754407079872': 'outside_schedule',
  // Outside schedule reason
  '1754407111959': 'outside_schedule_reason',
  // Missed bayana students
  '1754407141413': 'students_missed_bayana',
  // Lesson covered
  '1754407184691': 'lesson_covered',
  // Student submissions
  '1754407218568': 'student_submissions',
  // Used curriculum
  '1754407297953': 'used_curriculum',
  // Coach helpfulness
  '1754407417507': 'coach_helpfulness',
  // Teacher notes
  '1754407509366': 'teacher_notes',
  // Class type dropdown
  '1756564707506': 'subject_taught',
  // Teacher name dropdown
  '1762629945642': 'teacher_name_selection',
  // Host name
  '1764288691217': 'host_name',
};

// ============================================================================
// MIGRATION FUNCTIONS
// ============================================================================

/**
 * Create new user-friendly form templates
 */
async function createNewFormTemplates() {
  console.log('📝 Creating new form templates...');
  
  const batch = db.batch();
  
  for (const [key, template] of Object.entries(NEW_FORM_TEMPLATES)) {
    const docRef = db.collection('form_templates').doc(key);
    batch.set(docRef, {
      ...template,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log(`  ✅ Created template: ${template.name}`);
  }
  
  await batch.commit();
  console.log('✅ Form templates created successfully!\n');
}

/**
 * Migrate old form responses to new field structure
 */
async function migrateFormResponses(limit = 100) {
  console.log('📄 Migrating form responses...');
  
  const snapshot = await db.collection('form_responses')
    .orderBy('submittedAt', 'desc')
    .limit(limit)
    .get();
  
  console.log(`  Found ${snapshot.docs.length} responses to migrate`);
  
  let migratedCount = 0;
  const batch = db.batch();
  
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const responses = data.responses || {};
    
    // Check if already migrated
    if (data.migrated_v2) {
      continue;
    }
    
    // Create new responses with mapped field names
    const newResponses = {};
    const fieldLabels = {};
    
    for (const [oldFieldId, value] of Object.entries(responses)) {
      const newFieldId = FIELD_MAPPING[oldFieldId] || oldFieldId;
      newResponses[newFieldId] = value;
      
      // Store original field ID for reference
      if (FIELD_MAPPING[oldFieldId]) {
        fieldLabels[newFieldId] = oldFieldId;
      }
    }
    
    // Determine form type based on frequency
    let formType = 'daily';
    if (data.frequency === 'weekly') formType = 'weekly';
    else if (data.frequency === 'monthly') formType = 'monthly';
    
    batch.update(doc.ref, {
      responses_v2: newResponses,
      field_mapping: fieldLabels,
      formType: formType,
      migrated_v2: true,
      migrated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    migratedCount++;
  }
  
  if (migratedCount > 0) {
    await batch.commit();
  }
  
  console.log(`✅ Migrated ${migratedCount} form responses!\n`);
}

/**
 * Update app version metadata to trigger form refresh
 */
async function updateAppVersion() {
  console.log('🔄 Updating app version metadata...');
  
  await db.collection('app_config').doc('version').set({
    formTemplateVersion: 2,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    forceRefresh: true,
    changes: [
      'New user-friendly form templates',
      'English-only field labels',
      'Simplified field structure',
      'Support for daily/weekly/monthly forms',
    ],
  }, { merge: true });
  
  console.log('✅ App version updated!\n');
}

/**
 * Create audit schema documentation
 */
async function createAuditSchemaDoc() {
  console.log('📚 Creating audit schema documentation...');
  
  await db.collection('app_config').doc('audit_schema').set({
    version: 2,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    collections: {
      form_templates: {
        description: 'Form templates for daily/weekly/monthly reports',
        fields: {
          name: 'Template name',
          description: 'Template description',
          frequency: 'perSession | weekly | monthly',
          isActive: 'Whether template is active',
          fields: 'Array of field definitions',
          autoFillRules: 'Auto-fill rules for fields',
        },
      },
      form_responses: {
        description: 'Teacher form submissions',
        fields: {
          formId: 'Legacy form ID',
          templateId: 'New template ID',
          responses: 'Original responses (old field IDs)',
          responses_v2: 'Migrated responses (new field IDs)',
          formType: 'daily | weekly | monthly',
          teacherId: 'Teacher user ID',
          shiftId: 'Linked shift ID',
        },
      },
      teacher_audits: {
        description: 'Monthly teacher audits',
        fields: {
          teacherId: 'Teacher user ID',
          yearMonth: 'Audit period (YYYY-MM)',
          paymentSummary: 'Payment calculation details',
          auditFactors: '16 evaluation factors',
          reviewChain: 'Coach/CEO/Founder reviews',
          detailedForms: 'All form responses for period',
        },
      },
    },
    formTypes: {
      daily: 'Daily Class Report - submitted after each class',
      weekly: 'Weekly Summary - submitted at end of week',
      monthly: 'Monthly Review - submitted at end of month',
    },
  });
  
  console.log('✅ Audit schema documentation created!\n');
}

/**
 * Main migration function
 */
async function runMigration() {
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  ALLUVIAL ACADEMY - FIREBASE MIGRATION SCRIPT');
  console.log('═══════════════════════════════════════════════════════════\n');
  
  try {
    // Step 1: Create new form templates
    await createNewFormTemplates();
    
    // Step 2: Migrate existing form responses
    await migrateFormResponses(500);
    
    // Step 3: Update app version to trigger refresh
    await updateAppVersion();
    
    // Step 4: Create schema documentation
    await createAuditSchemaDoc();
    
    console.log('═══════════════════════════════════════════════════════════');
    console.log('  ✅ MIGRATION COMPLETED SUCCESSFULLY!');
    console.log('═══════════════════════════════════════════════════════════\n');
    
    console.log('Next steps:');
    console.log('1. Deploy the updated Flutter app');
    console.log('2. Users will automatically see new forms on app refresh');
    console.log('3. Old form responses are preserved with field mapping');
    console.log('4. Audit system will handle both old and new formats');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

// Run the migration
runMigration().then(() => {
  process.exit(0);
});

