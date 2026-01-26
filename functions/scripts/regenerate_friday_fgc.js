#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const TEMPLATE_ID = 'tpl_27c00dc8e6b6f766';
const MAX_DAYS_AHEAD = 70;

async function regenerateShifts() {
  console.log('Regenerating Friday shifts for Rasheed + Fatimah FGC...\n');
  
  const templateDoc = await db.collection('shift_templates').doc(TEMPLATE_ID).get();
  if (!templateDoc.exists) {
    console.log('Template not found!');
    return;
  }
  
  const template = templateDoc.data();
  const selectedWeekdays = template.enhanced_recurrence?.selectedWeekdays || [];
  console.log(`Template: ${TEMPLATE_ID}`);
  console.log(`Days: ${selectedWeekdays} (5 = Friday)`);
  console.log(`Time: ${template.start_time} - ${template.end_time}`);
  console.log(`Admin timezone: ${template.admin_timezone}\n`);
  
  const nowLocal = DateTime.now().setZone(template.admin_timezone);
  const endDate = nowLocal.plus({ days: MAX_DAYS_AHEAD });
  
  let createdCount = 0;
  let currentDate = nowLocal.startOf('day');
  
  while (currentDate <= endDate) {
    const jsDay = currentDate.weekday === 7 ? 0 : currentDate.weekday; // luxon 1-7 (Mon-Sun), JS 0-6 (Sun-Sat)
    const luxonDay = currentDate.weekday; // 1=Mon, 2=Tue, ..., 5=Fri, 6=Sat, 7=Sun
    
    // Check if this day is Friday (5 in the template means Friday: 1=Mon, 5=Fri, 7=Sun)
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
      
      const shiftId = `tpl_${TEMPLATE_ID}_${Math.floor(shiftStart.toMillis() / 1000)}`;
      
      // Check if shift already exists
      const existingShift = await db.collection('teaching_shifts').doc(shiftId).get();
      if (existingShift.exists) {
        currentDate = currentDate.plus({ days: 1 });
        continue;
      }
      
      const shiftData = {
        id: shiftId,
        template_id: TEMPLATE_ID,
        teacher_id: template.teacher_id,
        student_ids: template.student_ids,
        shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toUTC().toJSDate()),
        shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toUTC().toJSDate()),
        duration_minutes: template.duration_minutes,
        status: 'scheduled',
        video_provider: 'livekit',
        subject: template.subject,
        subject_id: template.subject_id,
        subject_display_name: template.subject_display_name,
        hourly_rate: template.hourly_rate,
        notes: template.notes,
        admin_timezone: template.admin_timezone,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        generated_from_template: true,
      };
      
      await db.collection('teaching_shifts').doc(shiftId).set(shiftData);
      console.log(`✅ Created: ${shiftStart.toFormat('EEE, MMM dd yyyy')} ${template.start_time} - ${template.end_time}`);
      createdCount++;
    }
    
    currentDate = currentDate.plus({ days: 1 });
  }
  
  console.log(`\nTotal shifts created: ${createdCount}`);
}

regenerateShifts()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
