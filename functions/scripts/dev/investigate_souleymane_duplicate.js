#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function investigate() {
  console.log('Investigating Souleymane Diallo duplicates...\n');
  console.log('='.repeat(80));
  
  // 1. Search for all teachers with "Souleymane" in their name
  const usersSnap = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();
  
  const souleymanTeachers = [];
  
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    
    if (fullName.toLowerCase().includes('souleymane')) {
      souleymanTeachers.push({
        uid: doc.id,
        firstName: data.first_name,
        lastName: data.last_name,
        fullName: fullName,
        email: data['e-mail'] || data.email,
        timezone: data.timezone || data.time_zone,
        createdAt: data.created_at,
        isActive: data.is_active,
      });
    }
  }
  
  console.log(`Found ${souleymanTeachers.length} teacher(s) with "Souleymane" in name:\n`);
  
  for (const teacher of souleymanTeachers) {
    console.log(`Teacher UID: ${teacher.uid}`);
    console.log(`  Name: ${teacher.fullName}`);
    console.log(`  Email: ${teacher.email}`);
    console.log(`  Timezone: ${teacher.timezone}`);
    console.log(`  Is Active: ${teacher.isActive}`);
    console.log(`  Created: ${teacher.createdAt ? new Date(teacher.createdAt._seconds * 1000).toISOString() : 'N/A'}`);
    console.log('');
  }
  
  // 2. Check templates for each Souleymane teacher
  console.log('='.repeat(80));
  console.log('SHIFT TEMPLATES:\n');
  
  for (const teacher of souleymanTeachers) {
    const templatesSnap = await db.collection('shift_templates')
      .where('teacher_id', '==', teacher.uid)
      .get();
    
    console.log(`\nTeacher: ${teacher.fullName} (${teacher.uid})`);
    console.log(`Total templates: ${templatesSnap.size}`);
    
    const activeTemplates = templatesSnap.docs.filter(doc => doc.data().is_active === true);
    const inactiveTemplates = templatesSnap.docs.filter(doc => doc.data().is_active !== true);
    
    console.log(`  Active: ${activeTemplates.length}`);
    console.log(`  Inactive: ${inactiveTemplates.length}`);
    
    if (activeTemplates.length > 0) {
      console.log('\n  Active Templates:');
      for (const doc of activeTemplates) {
        const data = doc.data();
        const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
        console.log(`    - ${doc.id}`);
        console.log(`      Days: ${weekdays}`);
        console.log(`      Time: ${data.start_time} - ${data.end_time}`);
        console.log(`      Students: ${data.student_ids?.length || 0}`);
        console.log(`      Created: ${data.created_at ? new Date(data.created_at._seconds * 1000).toISOString() : 'N/A'}`);
      }
    }
    
    if (inactiveTemplates.length > 0) {
      console.log('\n  Inactive Templates:');
      for (const doc of inactiveTemplates) {
        const data = doc.data();
        const weekdays = data.enhanced_recurrence?.selectedWeekdays || [];
        console.log(`    - ${doc.id}`);
        console.log(`      Days: ${weekdays}`);
        console.log(`      Time: ${data.start_time} - ${data.end_time}`);
        console.log(`      Students: ${data.student_ids?.length || 0}`);
        console.log(`      Created: ${data.created_at ? new Date(data.created_at._seconds * 1000).toISOString() : 'N/A'}`);
      }
    }
  }
  
  // 3. Summary
  console.log('\n' + '='.repeat(80));
  console.log('ANALYSIS:\n');
  
  if (souleymanTeachers.length > 1) {
    console.log('⚠️ MULTIPLE TEACHER ACCOUNTS FOUND!');
    console.log('\nThis could be causing duplicate entries in the UI.');
    console.log('\nAccounts:');
    for (const teacher of souleymanTeachers) {
      const templatesSnap = await db.collection('shift_templates')
        .where('teacher_id', '==', teacher.uid)
        .where('is_active', '==', true)
        .get();
      
      console.log(`  - ${teacher.fullName} (${teacher.email}): ${templatesSnap.size} active templates`);
    }
  } else if (souleymanTeachers.length === 1) {
    console.log('✅ Only one teacher account found.');
    console.log('\nIf you\'re seeing duplicates in the UI, it might be:');
    console.log('1. Duplicate shift templates');
    console.log('2. UI rendering issue');
    console.log('3. Multiple shifts on the same day');
  } else {
    console.log('❌ No teacher found with "Souleymane" in name.');
  }
  
  // 4. Check shifts in calendar
  console.log('\n' + '='.repeat(80));
  console.log('CHECKING SHIFTS IN CALENDAR:\n');
  
  for (const teacher of souleymanTeachers) {
    const now = new Date();
    const weekFromNow = new Date(now);
    weekFromNow.setDate(weekFromNow.getDate() + 7);
    
    const shiftsSnap = await db.collection('teaching_shifts')
      .where('teacher_id', '==', teacher.uid)
      .where('status', '==', 'scheduled')
      .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(now))
      .where('shift_start', '<', admin.firestore.Timestamp.fromDate(weekFromNow))
      .get();
    
    console.log(`Teacher: ${teacher.fullName} (${teacher.uid})`);
    console.log(`  Shifts next 7 days: ${shiftsSnap.size}`);
  }
}

investigate()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
