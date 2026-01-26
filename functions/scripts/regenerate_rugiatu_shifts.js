#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const TEMPLATE_IDS = [
  'tpl_874363d2afe65f70', // Saturday
  'tpl_f3a686a6393e8c3a', // Sunday
];

const MAX_DAYS_AHEAD = 70;

async function regenerateShifts() {
  console.log('Regenerating Rugiatu Saturday/Sunday shifts...\n');
  
  let totalCreated = 0;
  
  for (const templateId of TEMPLATE_IDS) {
    const templateDoc = await db.collection('shift_templates').doc(templateId).get();
    if (!templateDoc.exists) {
      console.log(`Template ${templateId} not found!`);
      continue;
    }
    
    const template = templateDoc.data();
    const selectedWeekdays = template.enhanced_recurrence?.selectedWeekdays || [];
    
    console.log(`Template: ${templateId}`);
    console.log(`  Days: ${selectedWeekdays}`);
    console.log(`  Time: ${template.start_time} - ${template.end_time} (${template.admin_timezone})`);
    
    // Get student names for the shift data
    const studentNames = [];
    for (const sid of (template.student_ids || [])) {
      const studentDoc = await db.collection('users').doc(sid).get();
      if (studentDoc.exists) {
        const data = studentDoc.data();
        studentNames.push(`${data.first_name || ''} ${data.last_name || ''}`.trim());
      }
    }
    
    // Get teacher name
    const teacherDoc = await db.collection('users').doc(template.teacher_id).get();
    const teacherData = teacherDoc.exists ? teacherDoc.data() : {};
    const teacherName = `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim();
    
    const nowLocal = DateTime.now().setZone(template.admin_timezone);
    const endDate = nowLocal.plus({ days: MAX_DAYS_AHEAD });
    
    let createdCount = 0;
    let currentDate = nowLocal.startOf('day');
    
    while (currentDate <= endDate) {
      const luxonDay = currentDate.weekday; // 1=Mon, 2=Tue, ..., 5=Fri, 6=Sat, 7=Sun
      
      if (selectedWeekdays.includes(luxonDay)) {
        const [startHour, startMin] = template.start_time.split(':').map(Number);
        const [endHour, endMin] = template.end_time.split(':').map(Number);
        
        const shiftStart = currentDate.set({ hour: startHour, minute: startMin, second: 0, millisecond: 0 });
        const shiftEnd = currentDate.set({ hour: endHour, minute: endMin, second: 0, millisecond: 0 });
        
        // Skip if shift is in the past
        if (shiftStart < DateTime.now().setZone(template.admin_timezone)) {
          currentDate = currentDate.plus({ days: 1 });
          continue;
        }
        
        const shiftId = `tpl_${templateId}_${Math.floor(shiftStart.toMillis() / 1000)}`;
        
        // Check if shift already exists
        const existingShift = await db.collection('teaching_shifts').doc(shiftId).get();
        if (existingShift.exists) {
          currentDate = currentDate.plus({ days: 1 });
          continue;
        }
        
        const shiftData = {
          id: shiftId,
          template_id: templateId,
          teacher_id: template.teacher_id,
          teacher_name: teacherName,
          student_ids: template.student_ids,
          student_names: studentNames,
          shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toUTC().toJSDate()),
          shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toUTC().toJSDate()),
          duration_minutes: template.duration_minutes,
          status: 'scheduled',
          video_provider: 'livekit',
          livekit_room_name: `shift_${shiftId}`,
          subject: template.subject,
          subject_id: template.subject_id,
          subject_display_name: template.subject_display_name,
          hourly_rate: template.hourly_rate,
          notes: template.notes,
          admin_timezone: template.admin_timezone,
          teacher_timezone: teacherData.timezone || template.admin_timezone,
          shift_category: 'teaching',
          auto_generated_name: `${teacherName} - ${template.subject_display_name || template.subject} - ${studentNames.join(', ')}`,
          recurrence: 'weekly',
          recurrence_series_id: templateId,
          enhanced_recurrence: template.enhanced_recurrence,
          series_created_at: template.created_at,
          generated_from_template: true,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
          last_modified: admin.firestore.FieldValue.serverTimestamp(),
        };
        
        await db.collection('teaching_shifts').doc(shiftId).set(shiftData);
        console.log(`  ✅ Created: ${shiftStart.toFormat('EEE, MMM dd yyyy')} ${template.start_time} - ${template.end_time}`);
        createdCount++;
      }
      
      currentDate = currentDate.plus({ days: 1 });
    }
    
    console.log(`  Total created: ${createdCount}\n`);
    totalCreated += createdCount;
  }
  
  console.log('='.repeat(80));
  console.log(`Total shifts created: ${totalCreated}`);
}

regenerateShifts()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
