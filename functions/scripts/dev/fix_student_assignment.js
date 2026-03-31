#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

// Wrong student
const WRONG_STUDENT_ID = 'ty7ZqjKpNUMec93cX27fG62qrke2';
const WRONG_STUDENT_NAME = 'Mariam Diallo';

// Correct student
const CORRECT_STUDENT_ID = 'RQTQQc9P5wYsuwAkTFNEYYSzyfT2';
const CORRECT_STUDENT_NAME = 'Mariame Bah';

async function fix() {
  console.log('='.repeat(80));
  console.log('Fixing student assignment for Nasrullah Jalloh');
  console.log(`  Wrong: ${WRONG_STUDENT_NAME} (${WRONG_STUDENT_ID})`);
  console.log(`  Correct: ${CORRECT_STUDENT_NAME} (${CORRECT_STUDENT_ID})\n`);
  
  const now = DateTime.now().setZone(NYC_TZ);
  
  // Find all templates for Nasrullah Jalloh with the wrong student
  console.log('Searching templates...\n');
  
  const templatesSnap = await db.collection('shift_templates').get();
  
  const affectedTemplates = [];
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const tName = (data.teacher_name || '').toLowerCase();
    
    if (tName.includes('nasrullah') && (data.student_ids || []).includes(WRONG_STUDENT_ID)) {
      console.log(`Found template: ${doc.id}`);
      console.log(`  Teacher: ${data.teacher_name}`);
      console.log(`  Current students: ${(data.student_names || []).join(', ')}`);
      affectedTemplates.push({ id: doc.id, data });
    }
  }
  
  console.log(`\nTotal affected templates: ${affectedTemplates.length}`);
  
  if (affectedTemplates.length === 0) {
    console.log('\nNo templates need fixing.');
    return;
  }
  
  // Fix templates and shifts
  console.log('\n' + '='.repeat(80));
  console.log('APPLYING FIXES...\n');
  
  for (const { id: templateId, data: templateData } of affectedTemplates) {
    console.log(`Fixing template: ${templateId}`);
    
    // Update student_ids array
    const newStudentIds = (templateData.student_ids || []).map(id => 
      id === WRONG_STUDENT_ID ? CORRECT_STUDENT_ID : id
    );
    
    // Update student_names array
    const newStudentNames = (templateData.student_names || []).map(name => 
      name === WRONG_STUDENT_NAME || name === 'Mariam Diallo' ? CORRECT_STUDENT_NAME : name
    );
    
    await db.collection('shift_templates').doc(templateId).update({
      student_ids: newStudentIds,
      student_names: newStudentNames,
      last_modified: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`  ✅ Template updated: ${newStudentNames.join(', ')}`);
    
    // Find and update shifts for this template
    const shiftsSnap = await db.collection('teaching_shifts')
      .where('template_id', '==', templateId)
      .get();
    
    console.log(`  Found ${shiftsSnap.size} shifts`);
    
    let updatedCount = 0;
    for (const shiftDoc of shiftsSnap.docs) {
      const shiftData = shiftDoc.data();
      
      // Check if this shift has the wrong student
      if (!(shiftData.student_ids || []).includes(WRONG_STUDENT_ID)) {
        continue;
      }
      
      // Check if future
      const startField = shiftData.shift_start || shiftData.start_time;
      if (startField && startField.toDate) {
        const shiftStart = DateTime.fromJSDate(startField.toDate()).setZone(NYC_TZ);
        if (shiftStart < now) {
          continue; // Skip past shifts
        }
      }
      
      const newShiftStudentIds = (shiftData.student_ids || []).map(id => 
        id === WRONG_STUDENT_ID ? CORRECT_STUDENT_ID : id
      );
      
      const newShiftStudentNames = (shiftData.student_names || []).map(name => 
        name === WRONG_STUDENT_NAME || name === 'Mariam Diallo' ? CORRECT_STUDENT_NAME : name
      );
      
      // Update auto_generated_name if it contains the wrong name
      let autoName = shiftData.auto_generated_name || '';
      if (autoName.includes('Mariam Diallo')) {
        autoName = autoName.replace('Mariam Diallo', CORRECT_STUDENT_NAME);
      }
      
      await db.collection('teaching_shifts').doc(shiftDoc.id).update({
        student_ids: newShiftStudentIds,
        student_names: newShiftStudentNames,
        auto_generated_name: autoName,
      });
      
      updatedCount++;
    }
    
    console.log(`  ✅ Updated ${updatedCount} future shifts\n`);
  }
  
  console.log('='.repeat(80));
  console.log('✅ ALL FIXES APPLIED!');
  console.log(`Changed student from 2mariam.diallo to mariame.bah for Nasrullah Jalloh`);
}

fix()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
