/**
 * Script to update the daily_class_report template for data consistency
 * 
 * Changes:
 * 1. Remove "students_attended" multi-select field (redundant - shift already has student list)
 * 2. Make duration field read-only with shift duration pre-filled
 * 3. Keep only user-input fields: lesson_covered, used_curriculum, session_quality, teacher_notes
 * 4. Ensure all shift data is auto-filled and non-editable
 * 
 * Run: node scripts/update_daily_class_report_template.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('✅ Initialized with service account key');
} catch (error) {
  console.error('❌ Error initializing Firebase Admin:', error.message);
  process.exit(1);
}

const db = admin.firestore();

async function updateDailyClassReportTemplate() {
  try {
    console.log('\n📋 Starting daily_class_report template update...\n');

    const templateRef = db.collection('form_templates').doc('daily_class_report');
    const templateDoc = await templateRef.get();

    if (!templateDoc.exists) {
      console.error('❌ daily_class_report template not found!');
      return;
    }

    console.log('✅ Template found, updating...\n');

    // New optimized fields structure
    const newFields = [
      {
        id: 'actual_duration',
        label: 'Actual class duration (hours)',
        type: 'number',
        placeholder: 'Auto-filled from shift (editable if needed)',
        required: true,
        order: 1,
        validation: {
          min: 0.25,
          max: 4
        }
      },
      {
        id: 'lesson_covered',
        label: 'What lesson/topic did you teach?',
        type: 'text',
        placeholder: 'e.g., Surah Al-Fatiha verses 1-3',
        required: true,
        order: 2
      },
      {
        id: 'used_curriculum',
        label: 'Did you use the official curriculum?',
        type: 'radio',
        options: [
          'Yes, Used Official Curriculum',
          'No, Used Own Content',
          'Partially Used',
          'Not Sure'
        ],
        required: true,
        order: 3
      },
      {
        id: 'session_quality',
        label: 'How did the session go?',
        type: 'radio',
        options: [
          'Excellent',
          'Good',
          'Average',
          'Challenging'
        ],
        required: true,
        order: 4
      },
      {
        id: 'teacher_notes',
        label: 'Additional notes or observations',
        type: 'long_text',
        placeholder: 'Any important observations, student progress, or concerns',
        required: false,
        order: 5
      }
    ];

    // Auto-fill rules - all shift data is auto-filled and NON-editable except duration
    const newAutoFillRules = [
      {
        fieldId: '_shift_id',
        sourceField: 'shiftId',
        editable: false
      },
      {
        fieldId: '_shift_subject',
        sourceField: 'shift.subjectDisplayName',
        editable: false
      },
      {
        fieldId: '_shift_students',
        sourceField: 'shift.studentNames',
        editable: false
      },
      {
        fieldId: 'actual_duration',
        sourceField: 'shift.duration',
        editable: true // Allow teacher to correct if needed
      },
      {
        fieldId: '_shift_class_type',
        sourceField: 'shift.classType',
        editable: false
      },
      {
        fieldId: '_clock_in_time',
        sourceField: 'shift.clockInTime',
        editable: false
      },
      {
        fieldId: '_clock_out_time',
        sourceField: 'shift.clockOutTime',
        editable: false
      }
    ];

    // Update the template
    await templateRef.update({
      fields: newFields,
      autoFillRules: newAutoFillRules,
      description: 'Post-class report - automatically filled with shift data. Teachers only need to add lesson content and notes.',
      version: 4, // Increment version
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      requiresShift: true, // Explicitly mark that this form REQUIRES a shift context
      _migrationNote: 'Updated for data consistency - removed redundant student attendance field, shift data is now auto-filled'
    });

    console.log('✅ Template updated successfully!');
    console.log('\n📊 Changes made:');
    console.log('   - Removed students_attended field (now auto-filled from shift)');
    console.log('   - Duration is auto-filled but editable');
    console.log('   - All other shift data is auto-filled and read-only');
    console.log('   - Only 5 fields remain: duration, lesson, curriculum, quality, notes');
    console.log('   - Version bumped to 4');
    console.log('\n✅ Migration complete!');

  } catch (error) {
    console.error('❌ Error updating template:', error);
    throw error;
  }
}

// Run the migration
updateDailyClassReportTemplate()
  .then(() => {
    console.log('\n✨ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  });
