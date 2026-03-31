#!/usr/bin/env node
'use strict';

/**
 * Add missing templates for Rahmatullaah Balde's students
 * 
 * Missing schedules from CSV:
 * - Kadiatou Barry (kadiatou.barry): Saturday 15:00-16:00, Sunday 15:00-16:00
 * - Rugiatu Jalloh (rugiatu.jalloh): Friday 16:00-17:00, Saturday 22:00-23:00, Sunday 22:00-23:00
 * 
 * Usage:
 *   node functions/scripts/add_missing_rahmatullaah_templates.js [--apply]
 */

const crypto = require('crypto');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = 'alluwal-academy';
const APPLY = process.argv.includes('--apply');
const ADMIN_TIMEZONE = 'America/New_York';
const MAX_DAYS_AHEAD = 70; // 10 weeks = 10 occurrences for weekly classes

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

// Missing schedules to add
const MISSING_SCHEDULES = [
  {
    teacherName: 'Rahmatullaah Balde',
    studentCode: 'kadiatou.barry',
    schedules: [
      { weekday: 6, startTime: '15:00', endTime: '16:00' }, // Saturday 3-4 PM
      { weekday: 7, startTime: '15:00', endTime: '16:00' }, // Sunday 3-4 PM
    ]
  },
  {
    teacherName: 'Rahmatullaah Balde',
    studentCode: 'rugiatu.jalloh',
    schedules: [
      { weekday: 5, startTime: '16:00', endTime: '17:00' }, // Friday 4-5 PM
      { weekday: 6, startTime: '22:00', endTime: '23:00' }, // Saturday 10-11 PM
      { weekday: 7, startTime: '22:00', endTime: '23:00' }, // Sunday 10-11 PM
    ]
  }
];

const normalizeCode = (value) => (value || '').toString().trim().toLowerCase();

const nextOccurrence = (weekday, hour, minute, zone) => {
  const now = DateTime.now().setZone(zone);
  const deltaDays = (weekday - now.weekday + 7) % 7;
  let candidate = now.plus({ days: deltaDays }).set({
    hour, minute, second: 0, millisecond: 0
  });
  if (candidate <= now) {
    candidate = candidate.plus({ days: 7 });
  }
  return candidate;
};

const main = async () => {
  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Mode: ${APPLY ? 'APPLY' : 'DRY RUN'}\n`);

  // Rahmatullaah Balde's exact teacher ID
  const RAHMATULLAAH_BALDE_ID = 'ndmMY0LP4MaXhXGs4KdTjAfmgTm2';
  
  const teacherDoc = await db.collection('users').doc(RAHMATULLAAH_BALDE_ID).get();
  if (!teacherDoc.exists) {
    console.error('❌ Could not find Rahmatullaah Balde in teachers');
    process.exit(1);
  }
  
  const teacherId = teacherDoc.id;
  const teacherData = teacherDoc.data();
  console.log(`Found teacher: ${teacherData.first_name} ${teacherData.last_name} (${teacherId})`);

  // Find students
  const studentsSnap = await db.collection('users')
    .where('user_type', 'in', ['student', 'Student'])
    .get();
  
  const studentsByCode = new Map();
  studentsSnap.docs.forEach(doc => {
    const data = doc.data() || {};
    const code = normalizeCode(data.student_code || data.studentCode || data.student_id);
    if (code) {
      studentsByCode.set(code, {
        uid: doc.id,
        firstName: data.first_name || '',
        lastName: data.last_name || '',
        code
      });
    }
  });

  // Get teacher's existing shift for defaults (subject, hourly rate, etc.)
  let teacherDefaults = {
    subjectId: null,
    subjectDisplayName: 'Islamic Studies',
    subjectLegacy: 'other',
    hourlyRate: null,
    category: 'teaching',
    videoProvider: 'livekit',
  };

  try {
    const existingShift = await db.collection('teaching_shifts')
      .where('teacher_id', '==', teacherId)
      .orderBy('shift_start', 'desc')
      .limit(1)
      .get();
    
    if (!existingShift.empty) {
      const data = existingShift.docs[0].data() || {};
      teacherDefaults = {
        subjectId: data.subject_id || null,
        subjectDisplayName: data.subject_display_name || 'Islamic Studies',
        subjectLegacy: data.subject || 'other',
        hourlyRate: data.hourly_rate ?? null,
        category: data.shift_category || data.category || 'teaching',
        videoProvider: 'livekit', // Always use livekit now
      };
    }
  } catch (err) {
    console.log('Could not fetch teacher defaults, using fallback values');
  }

  console.log(`\nTeacher defaults: ${JSON.stringify(teacherDefaults, null, 2)}\n`);

  const templatesToCreate = [];
  const teacherName = `${teacherData.first_name || ''} ${teacherData.last_name || ''}`.trim();
  const teacherTimezone = teacherData.timezone || teacherData.time_zone || ADMIN_TIMEZONE;

  for (const entry of MISSING_SCHEDULES) {
    const student = studentsByCode.get(normalizeCode(entry.studentCode));
    if (!student) {
      console.error(`❌ Student not found: ${entry.studentCode}`);
      continue;
    }

    console.log(`\nStudent: ${student.firstName} ${student.lastName} (${student.code})`);

    for (const schedule of entry.schedules) {
      const { weekday, startTime, endTime } = schedule;
      const dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      
      // Calculate duration
      const [startHour, startMin] = startTime.split(':').map(Number);
      const [endHour, endMin] = endTime.split(':').map(Number);
      const durationMinutes = (endHour * 60 + endMin) - (startHour * 60 + startMin);

      // Generate template ID
      const hashInput = [
        teacherId,
        weekday,
        startTime,
        endTime,
        student.uid,
      ].join('|');
      const hash = crypto.createHash('sha1').update(hashInput).digest('hex').slice(0, 16);
      const templateId = `tpl_${hash}`;

      // Calculate base shift times
      const baseStart = nextOccurrence(weekday, startHour, startMin, ADMIN_TIMEZONE);
      const baseEnd = baseStart.plus({ minutes: durationMinutes });
      const endDate = DateTime.now().setZone(ADMIN_TIMEZONE).plus({ days: 365 });

      const studentName = `${student.firstName} ${student.lastName}`.trim();
      const autoGeneratedName = `${teacherName} - ${teacherDefaults.subjectDisplayName} - ${studentName}`;

      const templateDoc = {
        teacher_id: teacherId,
        teacher_name: teacherName,
        student_ids: [student.uid],
        student_names: [studentName],
        start_time: startTime,
        end_time: endTime,
        duration_minutes: durationMinutes,
        admin_timezone: ADMIN_TIMEZONE,
        teacher_timezone: teacherTimezone,
        enhanced_recurrence: {
          type: 'weekly',
          endDate: admin.firestore.Timestamp.fromDate(endDate.toJSDate()),
          excludedDates: [],
          excludedWeekdays: [],
          selectedWeekdays: [weekday],
          selectedMonthDays: [],
          selectedMonths: [],
        },
        recurrence: 'weekly',
        recurrence_series_id: templateId,
        recurrence_end_date: admin.firestore.Timestamp.fromDate(endDate.toJSDate()),
        recurrence_settings: null,
        subject: teacherDefaults.subjectLegacy,
        subject_id: teacherDefaults.subjectId,
        subject_display_name: teacherDefaults.subjectDisplayName,
        hourly_rate: teacherDefaults.hourlyRate,
        auto_generated_name: autoGeneratedName,
        custom_name: null,
        notes: 'IC / Islamic',
        category: teacherDefaults.category,
        leader_role: null,
        video_provider: 'livekit',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        last_modified: admin.firestore.FieldValue.serverTimestamp(),
        is_active: true,
        last_generated_date: null,
        max_days_ahead: MAX_DAYS_AHEAD,
        base_shift_id: templateId,
        base_shift_start: admin.firestore.Timestamp.fromDate(baseStart.toJSDate()),
        base_shift_end: admin.firestore.Timestamp.fromDate(baseEnd.toJSDate()),
      };

      templatesToCreate.push({ templateId, templateDoc, schedule, studentName });
      console.log(`  → ${dayNames[weekday]} ${startTime}-${endTime} (${templateId})`);
    }
  }

  console.log(`\n📋 Templates to create: ${templatesToCreate.length}`);

  if (!APPLY) {
    console.log('\n💡 Run with --apply to create templates and generate shifts');
    return;
  }

  // Create templates
  console.log('\n📝 Creating templates...');
  for (const { templateId, templateDoc } of templatesToCreate) {
    await db.collection('shift_templates').doc(templateId).set(templateDoc, { merge: true });
    console.log(`  ✅ Created template: ${templateId}`);
  }

  // Generate shifts using the existing handler
  console.log('\n🗓️  Generating shifts...');
  const shiftTemplateHandlers = require('../handlers/shift_templates');
  let totalCreated = 0;

  for (const { templateId, templateDoc, studentName, schedule } of templatesToCreate) {
    const result = await shiftTemplateHandlers._generateShiftsForTemplate({
      templateId,
      template: templateDoc,
    });
    const created = result.created || 0;
    totalCreated += created;
    console.log(`  ✅ Generated ${created} shifts for ${studentName} (${schedule.startTime}-${schedule.endTime})`);
  }

  console.log(`\n✅ Done! Created ${templatesToCreate.length} templates and ${totalCreated} shifts.`);
};

main().catch(err => {
  console.error(err);
  process.exit(1);
});
