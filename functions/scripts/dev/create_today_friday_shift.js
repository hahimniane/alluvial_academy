#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

async function createTodayShift() {
  const NYC_TZ = 'America/New_York';
  const now = DateTime.now().setZone(NYC_TZ);
  
  console.log(`Current NYC time: ${now.toFormat('fff')}\n`);
  
  // Get the template for Friday 4:00 PM - 5:30 PM with 2boubacar.diallo
  const templateId = 'tpl_7dc1184ff85e28ba';
  
  const templateDoc = await db.collection('shift_templates').doc(templateId).get();
  
  if (!templateDoc.exists) {
    console.log('❌ Template not found!');
    return;
  }
  
  const template = templateDoc.data();
  console.log('Template found:');
  console.log(`  Time: ${template.start_time} - ${template.end_time}`);
  console.log(`  Students: ${template.student_names?.join(', ')}`);
  console.log('');
  
  // Create today's shift
  const today = now.startOf('day');
  const [startHour, startMin] = template.start_time.split(':').map(Number);
  const [endHour, endMin] = template.end_time.split(':').map(Number);
  
  const shiftStart = today.set({ hour: startHour, minute: startMin, second: 0 });
  const shiftEnd = today.set({ hour: endHour, minute: endMin, second: 0 });
  
  const shiftId = `tpl_${templateId}_${Math.floor(shiftStart.toMillis() / 1000)}`;
  
  // Check if shift already exists
  const existingShift = await db.collection('teaching_shifts').doc(shiftId).get();
  
  if (existingShift.exists) {
    console.log('⚠️ Shift already exists!');
    console.log(`  ID: ${shiftId}`);
    return;
  }
  
  // Get teacher info
  const teacherDoc = await db.collection('users').doc(template.teacher_id).get();
  const teacher = teacherDoc.data();
  const teacherName = `${teacher.first_name} ${teacher.last_name}`;
  
  const shiftData = {
    id: shiftId,
    template_id: templateId,
    teacher_id: template.teacher_id,
    teacher_name: teacherName,
    student_ids: template.student_ids,
    student_names: template.student_names,
    shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toUTC().toJSDate()),
    shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toUTC().toJSDate()),
    duration_minutes: template.duration_minutes,
    status: 'scheduled',
    video_provider: 'livekit',
    livekit_room_name: `shift_${shiftId}`,
    subject: template.subject,
    subject_display_name: template.subject_display_name,
    hourly_rate: template.hourly_rate,
    notes: template.notes,
    admin_timezone: NYC_TZ,
    teacher_timezone: teacher.timezone || NYC_TZ,
    shift_category: 'teaching',
    auto_generated_name: `${teacherName} - ${template.subject_display_name || template.subject} - ${template.student_names.join(', ')}`,
    recurrence: 'weekly',
    recurrence_series_id: templateId,
    enhanced_recurrence: template.enhanced_recurrence,
    generated_from_template: true,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
    last_modified: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  await db.collection('teaching_shifts').doc(shiftId).set(shiftData);
  
  console.log('✅ Created today\'s Friday shift:');
  console.log(`  ID: ${shiftId}`);
  console.log(`  Time: ${shiftStart.toFormat('h:mm a')} - ${shiftEnd.toFormat('h:mm a')} NYC`);
  console.log(`  Teacher: ${teacherName}`);
  console.log(`  Student: ${template.student_names.join(', ')}`);
}

createTodayShift()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
