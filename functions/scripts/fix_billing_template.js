#!/usr/bin/env node
'use strict';

const admin = require('firebase-admin');
const {DateTime} = require('luxon');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';
const TEMPLATE_ID = 'uzRUXJD57dgFuwswdmoJ';
const MAX_DAYS_AHEAD = 70; // 10 weeks

const DRY_RUN = !process.argv.includes('--apply');

async function fix() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (use --apply to fix)' : 'APPLYING FIX'}\n`);
  console.log('='.repeat(80));
  
  const now = DateTime.now().setZone(NYC_TZ);
  console.log(`Current NYC time: ${now.toFormat('fff')}\n`);
  
  // Get the template
  const templateDoc = await db.collection('shift_templates').doc(TEMPLATE_ID).get();
  
  if (!templateDoc.exists) {
    console.log(`Template ${TEMPLATE_ID} not found!`);
    return;
  }
  
  const template = templateDoc.data();
  console.log(`Template: ${TEMPLATE_ID}`);
  console.log(`  Teacher: ${template.teacher_name}`);
  console.log(`  Students: ${(template.student_names || []).join(', ')}`);
  console.log(`  Time: ${template.start_time} - ${template.end_time}`);
  console.log(`  Current max_days_ahead: ${template.max_days_ahead}`);
  console.log(`  Days: ${JSON.stringify(template.enhanced_recurrence?.selectedWeekdays)}`);
  
  if (DRY_RUN) {
    console.log(`\nWould update max_days_ahead to ${MAX_DAYS_AHEAD} and regenerate shifts`);
    console.log('Run with --apply to fix');
    return;
  }
  
  // Update the template
  console.log(`\nUpdating max_days_ahead to ${MAX_DAYS_AHEAD}...`);
  
  await db.collection('shift_templates').doc(TEMPLATE_ID).update({
    max_days_ahead: MAX_DAYS_AHEAD,
    last_modified: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  console.log('✅ Template updated');
  
  // Delete existing future shifts
  console.log('\nDeleting existing future shifts...');
  
  const shiftsSnap = await db.collection('teaching_shifts')
    .where('template_id', '==', TEMPLATE_ID)
    .get();
  
  let deleted = 0;
  for (const doc of shiftsSnap.docs) {
    const data = doc.data();
    if (data.status === 'scheduled') {
      await db.collection('teaching_shifts').doc(doc.id).delete();
      deleted++;
    }
  }
  console.log(`✅ Deleted ${deleted} future shifts`);
  
  // Regenerate shifts
  console.log('\nRegenerating shifts...');
  
  const {hour: startHour, minute: startMinute} = parseTime(template.start_time);
  const durationMinutes = template.duration_minutes || 60;
  const recurrence = template.enhanced_recurrence || {type: 'none'};
  const selectedWeekdays = recurrence.selectedWeekdays || [];
  
  const endDate = now.plus({ days: MAX_DAYS_AHEAD });
  let created = 0;
  
  for (let cursor = now.startOf('day'); cursor <= endDate; cursor = cursor.plus({ days: 1 })) {
    const luxonDay = cursor.weekday;
    
    if (!selectedWeekdays.includes(luxonDay)) continue;
    
    const shiftStart = cursor.set({ hour: startHour, minute: startMinute, second: 0 });
    const shiftEnd = shiftStart.plus({ minutes: durationMinutes });
    
    if (shiftStart <= now) continue; // Skip past shifts
    
    const shiftId = `tpl_${TEMPLATE_ID}_${Math.floor(shiftStart.toMillis() / 1000)}`;
    
    const shiftData = {
      id: shiftId,
      template_id: TEMPLATE_ID,
      teacher_id: template.teacher_id,
      teacher_name: template.teacher_name,
      student_ids: template.student_ids || [],
      student_names: template.student_names || [],
      shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toUTC().toJSDate()),
      shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toUTC().toJSDate()),
      duration_minutes: durationMinutes,
      status: 'scheduled',
      video_provider: 'livekit',
      livekit_room_name: `shift_${shiftId}`,
      subject: template.subject || 'islamic',
      subject_display_name: template.subject_display_name || 'Islamic',
      hourly_rate: template.hourly_rate || 4,
      notes: template.notes,
      admin_timezone: template.admin_timezone || NYC_TZ,
      teacher_timezone: template.teacher_timezone || NYC_TZ,
      shift_category: template.category || 'teaching',
      auto_generated_name: template.auto_generated_name,
      recurrence: 'weekly',
      recurrence_series_id: TEMPLATE_ID,
      enhanced_recurrence: recurrence,
      generated_from_template: true,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      last_modified: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    await db.collection('teaching_shifts').doc(shiftId).set(shiftData);
    console.log(`  Created: ${shiftStart.toFormat('ccc MMM d, h:mm a')}`);
    created++;
  }
  
  console.log(`\n✅ Created ${created} shifts`);
}

function parseTime(timeStr) {
  const [hour, minute] = (timeStr || '00:00').split(':').map(Number);
  return { hour, minute };
}

fix()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('Error:', e);
    process.exit(1);
  });
