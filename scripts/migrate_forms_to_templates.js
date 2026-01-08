/**
 * Form Migration Script
 * Migrates forms from 'form' collection to 'form_templates' collection
 * 
 * Run in Firebase Console's Cloud Shell or via Node.js with firebase-admin
 * 
 * Usage:
 *   node scripts/migrate_forms_to_templates.js
 * 
 * Or run directly in Firebase Console:
 *   1. Go to Firebase Console > Project Settings > Service Accounts
 *   2. Generate new private key
 *   3. Run this script with the service account
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
// Try to use serviceAccountKey.json if it exists, otherwise use default credentials
try {
  const serviceAccount = require('../serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('✅ Initialized with service account key');
} catch (error) {
  // Fallback to default credentials (for Cloud Functions or when running in Firebase environment)
  try {
    admin.initializeApp();
    console.log('✅ Initialized with default credentials');
  } catch (initError) {
    console.error('❌ Failed to initialize Firebase Admin:', initError.message);
    console.error('Make sure either:');
    console.error('1. serviceAccountKey.json exists in the project root, or');
    console.error('2. You are running in a Firebase environment with default credentials');
    process.exit(1);
  }
}

const db = admin.firestore();

// ============================================================
// FORM ANALYSIS AND CATEGORIZATION
// ============================================================

/**
 * Analyze form title and content to determine category
 */
function categorizeForm(formData) {
  const title = (formData.title || '').toLowerCase();
  const description = (formData.description || '').toLowerCase();
  
  // PayCheck / Payout forms -> DELETE (replaced by audit system)
  if (title.includes('paycheck') || title.includes('payout') || title.includes('payment')) {
    return { action: 'DELETE', reason: 'Replaced by Audit System' };
  }
  
  // Zoom-related forms -> DELETE (Zoom no longer used)
  if (title.includes('zoom') || title.includes('meeting link') || description.includes('zoom')) {
    return { action: 'DELETE', reason: 'Zoom no longer used' };
  }
  
  // Readiness forms -> SKIP (already migrated)
  if (title.includes('readiness') || title.includes('préparation') || 
      title.includes('class readiness') || title.includes('formulaire de préparation')) {
    return { action: 'SKIP', reason: 'Already migrated to Daily Class Report' };
  }
  
  // Feedback forms -> MIGRATE
  if (title.includes('feedback') || title.includes('complaint') || 
      title.includes('commentaire') || title.includes('leader')) {
    return { 
      action: 'MIGRATE', 
      category: 'feedback',
      frequency: 'onDemand'
    };
  }
  
  // Student Assessment / Survey forms -> MIGRATE
  if (title.includes('assessment') || title.includes('survey') || 
      title.includes('student') || title.includes('evaluation') ||
      title.includes('semester') || title.includes('progress')) {
    return { 
      action: 'MIGRATE', 
      category: 'studentAssessment',
      frequency: 'onDemand'
    };
  }
  
  // Excuse / Leave forms -> CONVERT TO TASK (but keep for reference)
  if (title.includes('excuse') || title.includes('leave') || 
      title.includes('absence')) {
    return { 
      action: 'MIGRATE', 
      category: 'administrative',
      frequency: 'onDemand',
      note: 'Consider converting to Task-based workflow'
    };
  }
  
  // Fact Finding / Investigation forms -> CONVERT TO TASK
  if (title.includes('fact finding') || title.includes('investigation') ||
      title.includes('incident')) {
    return { 
      action: 'MIGRATE', 
      category: 'administrative',
      frequency: 'onDemand',
      note: 'Consider converting to Task-based workflow'
    };
  }
  
  // Default: migrate to 'other' category
  return { 
    action: 'MIGRATE', 
    category: 'other',
    frequency: 'onDemand'
  };
}

/**
 * Convert old field format to new format
 */
function convertFields(oldFields) {
  if (!oldFields) return {};
  
  const newFields = {};
  
  // Handle both Map and Array formats
  if (Array.isArray(oldFields)) {
    oldFields.forEach((field, index) => {
      const fieldId = field.id || `field_${index}`;
      newFields[fieldId] = convertField(field, index);
    });
  } else {
    Object.entries(oldFields).forEach(([fieldId, field], index) => {
      newFields[fieldId] = convertField(field, field.order || index);
    });
  }
  
  return newFields;
}

/**
 * Convert a single field to new format
 */
function convertField(field, order) {
  // Map old field types to new types
  const typeMap = {
    'text': 'text',
    'openEnded': 'text',
    'long_text': 'long_text',
    'longAnswer': 'long_text',
    'textarea': 'long_text',
    'number': 'number',
    'dropdown': 'dropdown',
    'select': 'dropdown',
    'radio': 'radio',
    'multipleChoice': 'radio',
    'checkbox': 'multi_select',
    'multi_select': 'multi_select',
    'date': 'date',
    'time': 'time',
    'file': 'file_upload',
    'image': 'file_upload',
  };
  
  // Generate a unique ID if field.id is undefined
  const fieldId = field.id || `field_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

  return {
    id: fieldId,
    label: field.label || field.question || '',
    type: typeMap[field.type] || 'text',
    placeholder: field.placeholder || '',
    required: field.required || false,
    order: field.order ?? order,
    options: field.options || null,
    validation: field.validation || null,
  };
}

/**
 * Generate migration report
 */
async function generateReport() {
  console.log('\n========================================');
  console.log('FORM MIGRATION ANALYSIS REPORT');
  console.log('========================================\n');
  
  const formsSnapshot = await db.collection('form').get();
  
  const report = {
    total: formsSnapshot.docs.length,
    toMigrate: [],
    toDelete: [],
    toSkip: [],
  };
  
  formsSnapshot.docs.forEach(doc => {
    const data = doc.data();
    const analysis = categorizeForm(data);
    
    const entry = {
      id: doc.id,
      title: data.title || 'Untitled',
      status: data.status || 'unknown',
      fieldCount: data.fieldCount || Object.keys(data.fields || {}).length,
      responseCount: data.responseCount || 0,
      ...analysis
    };
    
    switch (analysis.action) {
      case 'MIGRATE':
        report.toMigrate.push(entry);
        break;
      case 'DELETE':
        report.toDelete.push(entry);
        break;
      case 'SKIP':
        report.toSkip.push(entry);
        break;
    }
  });
  
  // Print report
  console.log(`Total forms: ${report.total}\n`);
  
  console.log('--- FORMS TO MIGRATE ---');
  report.toMigrate.forEach(f => {
    console.log(`  [${f.category}] ${f.title} (${f.fieldCount} fields, ${f.responseCount} responses)`);
    if (f.note) console.log(`         ⚠️  ${f.note}`);
  });
  console.log(`  Total: ${report.toMigrate.length}\n`);
  
  console.log('--- FORMS TO DELETE ---');
  report.toDelete.forEach(f => {
    console.log(`  ❌ ${f.title} - ${f.reason}`);
  });
  console.log(`  Total: ${report.toDelete.length}\n`);
  
  console.log('--- FORMS TO SKIP ---');
  report.toSkip.forEach(f => {
    console.log(`  ⏭️  ${f.title} - ${f.reason}`);
  });
  console.log(`  Total: ${report.toSkip.length}\n`);
  
  return report;
}

/**
 * Execute migration
 */
async function executeMigration(dryRun = true) {
  console.log(`\n${dryRun ? '🧪 DRY RUN' : '🚀 EXECUTING'} MIGRATION...\n`);
  
  const formsSnapshot = await db.collection('form').get();
  const batch = db.batch();
  let migratedCount = 0;
  let deprecatedCount = 0;
  
  for (const doc of formsSnapshot.docs) {
    const data = doc.data();
    const analysis = categorizeForm(data);
    
    if (analysis.action === 'MIGRATE') {
      // Create new template document
      const templateData = {
        name: data.title || 'Untitled Form',
        description: data.description || '',
        frequency: analysis.frequency,
        category: analysis.category,
        version: 1,
        fields: convertFields(data.fields),
        autoFillRules: [],
        isActive: data.status === 'active',
        createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: data.createdBy || null,
        migratedFrom: doc.id, // Reference to original form
        allowedRoles: extractAllowedRoles(data.permissions),
      };
      
      if (!dryRun) {
        const templateRef = db.collection('form_templates').doc();
        batch.set(templateRef, templateData);
      }
      
      console.log(`  ✅ Migrating: ${data.title} -> form_templates`);
      migratedCount++;
    }
    
    if (analysis.action === 'DELETE' || analysis.action === 'SKIP') {
      // Mark old form as deprecated (don't actually delete)
      if (!dryRun) {
        batch.update(doc.ref, {
          status: 'deprecated',
          deprecatedAt: admin.firestore.FieldValue.serverTimestamp(),
          deprecationReason: analysis.reason,
        });
      }
      
      console.log(`  🗄️  Deprecating: ${data.title}`);
      deprecatedCount++;
    }
  }
  
  if (!dryRun) {
    await batch.commit();
    console.log('\n✅ Migration committed to Firestore');
  }
  
  console.log(`\nSummary: ${migratedCount} migrated, ${deprecatedCount} deprecated`);
}

/**
 * Extract allowed roles from permissions object
 */
function extractAllowedRoles(permissions) {
  if (!permissions) return null;
  
  if (permissions.type === 'public') return null; // All roles
  
  if (permissions.role === 'teachers' || permissions.role === 'teacher') {
    return ['teacher'];
  }
  
  if (permissions.role === 'admins' || permissions.role === 'admin') {
    return ['admin', 'coach'];
  }
  
  return null;
}

// ============================================================
// MAIN EXECUTION
// ============================================================

async function main() {
  console.log('🚀 Form Migration Tool\n');
  console.log('This script will analyze and migrate forms from');
  console.log("'form' collection to 'form_templates' collection.\n");

  try {
    // Step 1: Generate report
    console.log('📊 Step 1: Analyzing existing forms...');
    const report = await generateReport();
    console.log('✅ Analysis complete\n');

    // Step 2: Dry run first
    console.log('🧪 Step 2: Running dry-run migration...');
    await executeMigration(true);
    console.log('✅ Dry-run complete\n');

    // Step 3: Real migration
    console.log('⚠️  Step 3: Executing REAL migration...');
    console.log('This will modify your Firestore database!');
    console.log('Press Ctrl+C within 5 seconds to cancel...');

    // Wait 5 seconds
    await new Promise(resolve => setTimeout(resolve, 5000));

    console.log('🔄 Starting migration...');
    await executeMigration(false);
    console.log('✅ Migration complete!');

    // Final report
    console.log('\n📈 Final Report:');
    console.log(report);

  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

// Run if executed directly
main().catch(console.error);

module.exports = {
  generateReport,
  executeMigration,
  categorizeForm,
  convertFields,
};
