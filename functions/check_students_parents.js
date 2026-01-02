#!/usr/bin/env node
/**
 * Script to check students and parents relationships in Firestore
 * Lists:
 * - Students with parents
 * - Students without parents
 * - Parents with children
 * - Parents without children
 * 
 * Usage:
 *   cd functions
 *   node ../scripts/check_students_parents.js
 */

/**
 * Script to check students and parents relationships in Firestore
 * Lists:
 * - Students with parents
 * - Students without parents
 * - Parents with children
 * - Parents without children
 * 
 * Usage:
 *   cd functions
 *   node check_students_parents.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  try {
    // Try to get project ID from environment or Firebase config
    const projectId = process.env.GCLOUD_PROJECT || 
                      process.env.GCP_PROJECT || 
                      process.env.FIREBASE_PROJECT_ID ||
                      'alluwal-academy'; // Default project ID
    
    admin.initializeApp({
      projectId: projectId,
    });
    console.log(`✅ Initialized Firebase Admin with project: ${projectId}\n`);
  } catch (e) {
    console.error('❌ Failed to initialize Firebase Admin.');
    console.error('   Please run: firebase login');
    console.error('   Or set GCLOUD_PROJECT environment variable');
    console.error('   Error:', e.message);
    process.exit(1);
  }
}

const db = admin.firestore();

async function checkStudentsAndParents() {
  console.log('🔍 Querying database...\n');

  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    const allUsers = [];
    
    usersSnapshot.forEach(doc => {
      const data = doc.data();
      const guardianIds = data.guardian_ids || data.guardianIds || [];
      const kioskCode = data.kiosk_code || data.kiosque_code || data.family_code || 'N/A';
      const studentCode = data.student_code || data.studentCode || data.student_id || 'N/A';
      allUsers.push({
        id: doc.id,
        email: data['e-mail'] || data.email || 'N/A',
        firstName: data.first_name || 'N/A',
        lastName: data.last_name || 'N/A',
        role: data.role || data.user_type || 'N/A',
        guardianIds: Array.isArray(guardianIds) ? guardianIds : (guardianIds ? [guardianIds] : []),
        kioskCode: kioskCode,
        studentCode: studentCode,
      });
    });

    // Separate students and parents
    const students = allUsers.filter(u => 
      u.role === 'student' || u.role === 'Student'
    );
    
    const parents = allUsers.filter(u => 
      u.role === 'parent' || u.role === 'Parent'
    );

    console.log(`📊 Total Users: ${allUsers.length}`);
    console.log(`👨‍🎓 Total Students: ${students.length}`);
    console.log(`👨‍👩‍👧 Total Parents: ${parents.length}\n`);

    // Find students with parents (have guardian_ids array with at least one parent)
    const studentsWithParents = students.filter(s => 
      s.guardianIds && Array.isArray(s.guardianIds) && s.guardianIds.length > 0
    );

    // Find students without parents
    const studentsWithoutParents = students.filter(s => 
      !s.guardianIds || !Array.isArray(s.guardianIds) || s.guardianIds.length === 0
    );

    console.log('='.repeat(80));
    console.log('📋 STUDENTS WITH PARENTS');
    console.log('='.repeat(80));
    if (studentsWithParents.length === 0) {
      console.log('None found.\n');
    } else {
      console.log(`Total: ${studentsWithParents.length}\n`);
      studentsWithParents.forEach((student, index) => {
        console.log(`${index + 1}. ${student.firstName} ${student.lastName}`);
        console.log(`   ID: ${student.id}`);
        console.log(`   Email: ${student.email}`);
        console.log(`   Guardian IDs: ${student.guardianIds.join(', ')}`);
        console.log(`   Parents:`);
        student.guardianIds.forEach((guardianId, gIndex) => {
          const parentUser = allUsers.find(u => u.id === guardianId);
          if (parentUser) {
            console.log(`     ${gIndex + 1}. ${parentUser.firstName} ${parentUser.lastName} (${parentUser.email})`);
          } else {
            console.log(`     ${gIndex + 1}. ID: ${guardianId} - NOT FOUND in users collection`);
          }
        });
        console.log('');
      });
    }

    console.log('='.repeat(80));
    console.log('📋 STUDENTS WITHOUT PARENTS');
    console.log('='.repeat(80));
    if (studentsWithoutParents.length === 0) {
      console.log('None found.\n');
    } else {
      console.log(`Total: ${studentsWithoutParents.length}\n`);
      studentsWithoutParents.forEach((student, index) => {
        console.log(`${index + 1}. ${student.firstName} ${student.lastName}`);
        console.log(`   ID: ${student.id}`);
        console.log(`   Email: ${student.email}`);
        console.log(`   Student Code: ${student.studentCode}`);
        console.log(`   Kiosk Code: ${student.kioskCode}`);
        console.log('');
      });
    }

    // Check parents for children
    // A parent has children if there are students with parent_id pointing to them
    const parentsWithChildren = [];
    const parentsWithoutChildren = [];

    for (const parent of parents) {
      // Check if any student has this parent in their guardian_ids array
      const children = students.filter(s => 
        s.guardianIds && Array.isArray(s.guardianIds) && s.guardianIds.includes(parent.id)
      );
      
      if (children.length > 0) {
        parentsWithChildren.push({
          parent,
          childrenCount: children.length,
          children,
        });
      } else {
        parentsWithoutChildren.push(parent);
      }
    }

    console.log('='.repeat(80));
    console.log('📋 PARENTS WITH CHILDREN');
    console.log('='.repeat(80));
    if (parentsWithChildren.length === 0) {
      console.log('None found.\n');
    } else {
      console.log(`Total: ${parentsWithChildren.length}\n`);
      parentsWithChildren.forEach((entry, index) => {
        const { parent, childrenCount, children } = entry;
        console.log(`${index + 1}. ${parent.firstName} ${parent.lastName}`);
        console.log(`   ID: ${parent.id}`);
        console.log(`   Email: ${parent.email}`);
        console.log(`   Children Count: ${childrenCount}`);
        console.log(`   Children:`);
        children.forEach((child, childIndex) => {
          console.log(`     ${childIndex + 1}. ${child.firstName} ${child.lastName} (${child.email})`);
        });
        console.log('');
      });
    }

    console.log('='.repeat(80));
    console.log('📋 PARENTS WITHOUT CHILDREN');
    console.log('='.repeat(80));
    if (parentsWithoutChildren.length === 0) {
      console.log('None found.\n');
    } else {
      console.log(`Total: ${parentsWithoutChildren.length}\n`);
      parentsWithoutChildren.forEach((parent, index) => {
        console.log(`${index + 1}. ${parent.firstName} ${parent.lastName}`);
        console.log(`   ID: ${parent.id}`);
        console.log(`   Email: ${parent.email}`);
        console.log(`   Kiosk Code: ${parent.kioskCode}`);
        console.log('');
      });
    }

    // Summary
    console.log('='.repeat(80));
    console.log('📊 SUMMARY');
    console.log('='.repeat(80));
    console.log(`Students with parents: ${studentsWithParents.length}`);
    console.log(`Students without parents: ${studentsWithoutParents.length}`);
    console.log(`Parents with children: ${parentsWithChildren.length}`);
    console.log(`Parents without children: ${parentsWithoutChildren.length}`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

// Run the script
checkStudentsAndParents()
  .then(() => {
    console.log('\n✅ Done!');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });

