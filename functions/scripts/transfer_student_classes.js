#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

async function transfer() {
  console.log('='.repeat(80));
  console.log('Transfer amadou.sam from Ahmed Korka Bah to Mama S Diallo\n');
  
  // Find all users
  const usersSnap = await db.collection('users').get();
  
  // Find student amadou.sam
  let studentId = null;
  let studentName = null;
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const code = (data.student_code || data.studentCode || '').toLowerCase();
    if (code === 'amadou.sam') {
      studentId = doc.id;
      studentName = `${data.first_name || data.firstName || ''} ${data.last_name || data.lastName || ''}`.trim();
      console.log(`Found student: ${studentName} | Code: ${code} | ID: ${studentId}`);
      break;
    }
  }
  
  if (!studentId) {
    console.log('Student amadou.sam not found!');
    return;
  }
  
  // Find old teacher (Ahmed Korka Bah)
  let oldTeacherId = null;
  let oldTeacherName = null;
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || data.firstName || ''} ${data.last_name || data.lastName || ''}`.toLowerCase();
    const userType = data.user_type || data.role;
    
    if (fullName.includes('ahmed') && fullName.includes('korka') && fullName.includes('bah') && userType === 'teacher') {
      oldTeacherId = doc.id;
      oldTeacherName = `${data.first_name || data.firstName || ''} ${data.last_name || data.lastName || ''}`.trim();
      console.log(`Found OLD teacher: ${oldTeacherName} | ID: ${oldTeacherId}`);
      break;
    }
  }
  
  if (!oldTeacherId) {
    // Try searching templates
    console.log('Old teacher not found by name, searching templates...');
    const templatesSnap = await db.collection('shift_templates').get();
    for (const doc of templatesSnap.docs) {
      const data = doc.data();
      const tName = (data.teacher_name || '').toLowerCase();
      if (tName.includes('ahmed') && tName.includes('korka') && tName.includes('bah')) {
        oldTeacherId = data.teacher_id;
        oldTeacherName = data.teacher_name;
        console.log(`Found OLD teacher from template: ${oldTeacherName} | ID: ${oldTeacherId}`);
        break;
      }
    }
  }
  
  // Find new teacher (Mama S Diallo)
  let newTeacherId = null;
  let newTeacherName = null;
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || data.firstName || ''} ${data.last_name || data.lastName || ''}`.toLowerCase();
    const userType = data.user_type || data.role;
    
    if (fullName.includes('mama') && fullName.includes('diallo') && userType === 'teacher') {
      newTeacherId = doc.id;
      newTeacherName = `${data.first_name || data.firstName || ''} ${data.last_name || data.lastName || ''}`.trim();
      console.log(`Found NEW teacher: ${newTeacherName} | ID: ${newTeacherId}`);
      break;
    }
  }
  
  if (!newTeacherId) {
    console.log('New teacher Mama S Diallo not found!');
    
    // List all teachers with "mama" or "diallo"
    console.log('\nTeachers matching "mama" or "diallo":');
    for (const doc of usersSnap.docs) {
      const data = doc.data();
      const fullName = `${data.first_name || data.firstName || ''} ${data.last_name || data.lastName || ''}`.toLowerCase();
      const userType = data.user_type || data.role;
      
      if ((fullName.includes('mama') || fullName.includes('diallo')) && userType === 'teacher') {
        console.log(`  ${data.first_name || data.firstName} ${data.last_name || data.lastName} | ID: ${doc.id}`);
      }
    }
    return;
  }
  
  if (!oldTeacherId) {
    console.log('Old teacher Ahmed Korka Bah not found!');
    return;
  }
  
  // Find templates with this student and old teacher
  console.log('\n' + '='.repeat(80));
  console.log('TEMPLATES to transfer:\n');
  
  const templatesSnap = await db.collection('shift_templates').get();
  const affectedTemplates = [];
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    
    if (data.teacher_id === oldTeacherId && (data.student_ids || []).includes(studentId)) {
      console.log(`Template: ${doc.id}`);
      console.log(`  Time: ${data.start_time} - ${data.end_time}`);
      console.log(`  Students: ${(data.student_names || []).join(', ')}`);
      console.log(`  Weekdays: ${JSON.stringify(data.enhanced_recurrence?.selectedWeekdays)}`);
      console.log(`  Active: ${data.is_active}`);
      console.log('');
      affectedTemplates.push({ id: doc.id, data });
    }
  }
  
  console.log(`Found ${affectedTemplates.length} templates to transfer`);
  
  if (affectedTemplates.length === 0) {
    console.log('\nNo templates to transfer.');
    return;
  }
  
  // Apply changes
  console.log('\n' + '='.repeat(80));
  console.log('APPLYING TRANSFER...\n');
  
  const now = DateTime.now().setZone(NYC_TZ);
  
  for (const { id: templateId, data: templateData } of affectedTemplates) {
    console.log(`Transferring template: ${templateId}`);
    
    // Update template with new teacher
    await db.collection('shift_templates').doc(templateId).update({
      teacher_id: newTeacherId,
      teacher_name: newTeacherName,
      last_modified: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`  ✅ Template transferred to ${newTeacherName}`);
    
    // Find and update future shifts
    const shiftsSnap = await db.collection('teaching_shifts')
      .where('template_id', '==', templateId)
      .get();
    
    let updatedCount = 0;
    for (const shiftDoc of shiftsSnap.docs) {
      const shiftData = shiftDoc.data();
      
      // Check if future
      const startField = shiftData.shift_start || shiftData.start_time;
      if (startField && startField.toDate) {
        const shiftStart = DateTime.fromJSDate(startField.toDate()).setZone(NYC_TZ);
        if (shiftStart < now) {
          continue; // Skip past shifts
        }
      }
      
      // Update auto_generated_name
      let autoName = shiftData.auto_generated_name || '';
      if (autoName.includes(oldTeacherName)) {
        autoName = autoName.replace(oldTeacherName, newTeacherName);
      }
      
      await db.collection('teaching_shifts').doc(shiftDoc.id).update({
        teacher_id: newTeacherId,
        teacher_name: newTeacherName,
        auto_generated_name: autoName,
      });
      
      updatedCount++;
    }
    
    console.log(`  ✅ Updated ${updatedCount} future shifts\n`);
  }
  
  console.log('='.repeat(80));
  console.log('✅ TRANSFER COMPLETE!');
  console.log(`Student: ${studentName} (amadou.sam)`);
  console.log(`From: ${oldTeacherName}`);
  console.log(`To: ${newTeacherName}`);
}

transfer()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
