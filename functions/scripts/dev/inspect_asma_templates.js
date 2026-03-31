#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const TEACHER_ID = 'eBtOThyk0rOwCXYey4kPfEpNxdT2'; // Asma Mugtiu

async function inspectTemplates() {
  // Get all templates for Asma
  const templatesSnap = await db.collection('shift_templates')
    .where('teacher_id', '==', TEACHER_ID)
    .where('is_active', '==', true)
    .get();
  
  console.log(`Found ${templatesSnap.size} active templates\n`);
  
  // Get student info for mapping
  const studentIds = new Set();
  templatesSnap.docs.forEach(doc => {
    const data = doc.data();
    (data.student_ids || []).forEach(id => studentIds.add(id));
  });
  
  console.log('All student IDs in templates:');
  console.log([...studentIds].join('\n'));
  console.log('\n' + '='.repeat(80));
  
  // Get student details
  const studentMap = new Map();
  for (const sid of studentIds) {
    const studentDoc = await db.collection('users').doc(sid).get();
    if (studentDoc.exists) {
      const data = studentDoc.data();
      studentMap.set(sid, {
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        studentCode: data.student_code || data.studentId || data.student_id,
      });
    }
  }
  
  console.log('\nStudent ID -> Name mapping:');
  for (const [id, info] of studentMap) {
    console.log(`${id} -> ${info.name} (code: ${info.studentCode})`);
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('ALL TEMPLATES DETAIL:\n');
  
  const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  
  for (const doc of templatesSnap.docs) {
    const data = doc.data();
    const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
    const dayNames = weekdays.map(d => DAY_NAMES[d]).join(', ');
    const studentNames = (data.student_ids || []).map(sid => {
      const info = studentMap.get(sid);
      return info ? `${info.name} (${info.studentCode})` : sid;
    }).join(', ');
    
    console.log(`Template: ${doc.id}`);
    console.log(`  Days: [${weekdays}] = ${dayNames}`);
    console.log(`  Time: ${data.start_time} - ${data.end_time}`);
    console.log(`  Students: ${studentNames}`);
    console.log(`  Student IDs raw: ${(data.student_ids || []).join(', ')}`);
    console.log(`  Notes: ${data.notes || 'N/A'}`);
    console.log('');
  }
}

inspectTemplates()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
