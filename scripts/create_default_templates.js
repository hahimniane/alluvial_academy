/**
 * Script to create default form templates in Firestore
 * Run this once to initialize the new template system
 * 
 * Usage: node scripts/create_default_templates.js
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

async function createDefaultTemplates() {
  console.log('============================================================');
  console.log('CREATE DEFAULT FORM TEMPLATES');
  console.log('============================================================');
  console.log('Started at:', new Date().toISOString());
  console.log('');

  try {
    // Check if templates already exist
    const existingTemplates = await db.collection('form_templates').get();
    if (!existingTemplates.empty) {
      console.log('⚠️  Templates already exist. Skipping creation.');
      console.log(`   Found ${existingTemplates.size} existing templates.`);
      console.log('   To recreate, delete existing templates first.');
      return;
    }

    // Daily Class Report Template
    const dailyTemplate = {
      name: 'Daily Class Report',
      description: 'Quick report after each teaching session',
      frequency: 'perSession',
      version: 1,
      fields: {
        'lesson_completed': {
          id: 'lesson_completed',
          label: 'What lesson/topic did you cover today?',
          type: 'text',
          placeholder: 'e.g., Surah Al-Fatiha verses 1-3',
          required: true,
          order: 1,
        },
        'students_present': {
          id: 'students_present',
          label: 'How many students attended?',
          type: 'number',
          placeholder: 'Number of students present',
          required: true,
          order: 2,
          validation: { min: 0, max: 100 },
        },
        'session_quality': {
          id: 'session_quality',
          label: 'How did the session go?',
          type: 'radio',
          required: true,
          order: 3,
          options: ['Excellent', 'Good', 'Average', 'Challenging'],
        },
        'issues': {
          id: 'issues',
          label: 'Any issues or concerns?',
          type: 'long_text',
          placeholder: 'Leave empty if none',
          required: false,
          order: 4,
        },
        'next_plan': {
          id: 'next_plan',
          label: 'Plan for next session',
          type: 'text',
          placeholder: 'What will you cover next?',
          required: false,
          order: 5,
        },
      },
      autoFillRules: [
        { fieldId: '_teacher_name', sourceField: 'teacherName', editable: false },
        { fieldId: '_session_date', sourceField: 'sessionDate', editable: false },
        { fieldId: '_class_name', sourceField: 'className', editable: false },
        { fieldId: '_actual_duration', sourceField: 'actualDuration', editable: false },
      ],
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const dailyRef = await db.collection('form_templates').add(dailyTemplate);
    console.log(`✅ Created Daily Class Report template: ${dailyRef.id}`);

    // Weekly Summary Template
    const weeklyTemplate = {
      name: 'Weekly Summary',
      description: 'End of week teaching summary',
      frequency: 'weekly',
      version: 1,
      fields: {
        'weekly_progress': {
          id: 'weekly_progress',
          label: 'How would you rate this week overall?',
          type: 'radio',
          required: true,
          order: 1,
          options: ['Excellent', 'Good', 'Needs Improvement'],
        },
        'achievements': {
          id: 'achievements',
          label: 'What were the key achievements this week?',
          type: 'long_text',
          placeholder: 'Summarize student progress, milestones reached, etc.',
          required: true,
          order: 2,
        },
        'challenges': {
          id: 'challenges',
          label: 'Any challenges or support needed?',
          type: 'long_text',
          placeholder: 'Leave empty if none',
          required: false,
          order: 3,
        },
      },
      autoFillRules: [
        { fieldId: '_teacher_name', sourceField: 'teacherName', editable: false },
        { fieldId: '_week_ending', sourceField: 'sessionDate', editable: false },
      ],
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const weeklyRef = await db.collection('form_templates').add(weeklyTemplate);
    console.log(`✅ Created Weekly Summary template: ${weeklyRef.id}`);

    // Monthly Review Template
    const monthlyTemplate = {
      name: 'Monthly Review',
      description: 'End of month teaching review',
      frequency: 'monthly',
      version: 1,
      fields: {
        'month_rating': {
          id: 'month_rating',
          label: 'How would you rate this month?',
          type: 'radio',
          required: true,
          order: 1,
          options: ['Excellent', 'Good', 'Average', 'Challenging'],
        },
        'goals_met': {
          id: 'goals_met',
          label: 'Were your teaching goals met?',
          type: 'radio',
          required: true,
          order: 2,
          options: ['Yes, all goals', 'Most goals', 'Some goals', 'Few goals'],
        },
        'comments': {
          id: 'comments',
          label: 'Additional comments for admin',
          type: 'long_text',
          placeholder: 'Any feedback, requests, or concerns',
          required: false,
          order: 3,
        },
      },
      autoFillRules: [
        { fieldId: '_teacher_name', sourceField: 'teacherName', editable: false },
        { fieldId: '_month', sourceField: 'sessionDate', editable: false },
      ],
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const monthlyRef = await db.collection('form_templates').add(monthlyTemplate);
    console.log(`✅ Created Monthly Review template: ${monthlyRef.id}`);

    // Set daily template as active in config
    await db.collection('settings').doc('form_config').set(
      {
        dailyTemplateId: dailyRef.id,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    console.log(`✅ Set Daily Class Report as active template`);

    console.log('');
    console.log('============================================================');
    console.log('SUMMARY');
    console.log('============================================================');
    console.log('✅ All default templates created successfully!');
    console.log(`   Daily Template ID: ${dailyRef.id}`);
    console.log(`   Weekly Template ID: ${weeklyRef.id}`);
    console.log(`   Monthly Template ID: ${monthlyRef.id}`);
    console.log('');
    console.log('⚠️  IMPORTANT: The new templates are created but NOT yet');
    console.log('   connected to the teacher forms. You need to:');
    console.log('   1. Update ShiftFormService to use new templates, OR');
    console.log('   2. Migrate the existing readiness form to match new structure');
    console.log('');
    console.log('Completed at:', new Date().toISOString());
  } catch (error) {
    console.error('❌ Error creating templates:', error);
    process.exit(1);
  }
}

createDefaultTemplates().catch(console.error);

