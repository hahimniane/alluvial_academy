#!/usr/bin/env node
'use strict';

/**
 * Generic Shift Creation Script
 * 
 * Creates shift templates and individual shifts for any teacher/student combination.
 * 
 * Usage:
 *   node create_shifts.js --teacher "First Last" --students "student.code1,student.code2" --days "Mon,Wed,Fri" --start "09:00" --end "10:00" [--apply]
 * 
 * Options:
 *   --teacher     Teacher name (partial match works, e.g., "Abdoullahi" or "Abdoullahi Yaya")
 *   --students    Comma-separated student codes (e.g., "john.doe,jane.doe")
 *   --days        Comma-separated days (Mon,Tue,Wed,Thu,Fri,Sat,Sun)
 *   --start       Start time in 24h format (e.g., "09:00", "14:30")
 *   --end         End time in 24h format (e.g., "10:00", "16:00")
 *   --class-type  Optional: IC (Individual Class) or FGC (Family Group Class). Default: auto-detected
 *   --subject     Optional: Subject name. Default: "quran_studies"
 *   --weeks       Optional: Number of weeks to generate shifts for. Default: 10
 *   --apply       Actually create the shifts (without this flag, it's a dry run)
 * 
 * Examples:
 *   # Preview shifts for a teacher with 2 students on Mon/Wed at 9-10am
 *   node create_shifts.js --teacher "John Smith" --students "alice.jones,bob.jones" --days "Mon,Wed" --start "09:00" --end "10:00"
 * 
 *   # Create shifts for real
 *   node create_shifts.js --teacher "John Smith" --students "alice.jones" --days "Sat,Sun" --start "14:00" --end "15:30" --apply
 */

const admin = require('firebase-admin');
const { DateTime } = require('luxon');
const crypto = require('crypto');

admin.initializeApp({ projectId: 'alluwal-academy' });
const db = admin.firestore();

const NYC_TZ = 'America/New_York';

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const parsed = {
    teacher: null,
    students: [],
    days: [],
    startTime: null,
    endTime: null,
    classType: null,
    subject: 'quran_studies',
    weeks: 10,
    apply: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const nextArg = args[i + 1];

    switch (arg) {
      case '--teacher':
        parsed.teacher = nextArg;
        i++;
        break;
      case '--students':
        parsed.students = nextArg.split(',').map(s => s.trim());
        i++;
        break;
      case '--days':
        parsed.days = nextArg.split(',').map(d => d.trim());
        i++;
        break;
      case '--start':
        parsed.startTime = nextArg;
        i++;
        break;
      case '--end':
        parsed.endTime = nextArg;
        i++;
        break;
      case '--class-type':
        parsed.classType = nextArg.toUpperCase();
        i++;
        break;
      case '--subject':
        parsed.subject = nextArg;
        i++;
        break;
      case '--weeks':
        parsed.weeks = parseInt(nextArg, 10);
        i++;
        break;
      case '--apply':
        parsed.apply = true;
        break;
    }
  }

  return parsed;
}

// Convert day names to Luxon weekday numbers (1=Monday, 7=Sunday)
function parseDays(dayNames) {
  const dayMap = {
    'mon': 1, 'monday': 1,
    'tue': 2, 'tuesday': 2,
    'wed': 3, 'wednesday': 3,
    'thu': 4, 'thursday': 4,
    'fri': 5, 'friday': 5,
    'sat': 6, 'saturday': 6,
    'sun': 7, 'sunday': 7,
  };

  return dayNames.map(name => {
    const num = dayMap[name.toLowerCase()];
    if (!num) {
      console.error(`❌ Invalid day: ${name}`);
      console.error('   Valid days: Mon, Tue, Wed, Thu, Fri, Sat, Sun');
      process.exit(1);
    }
    return num;
  });
}

const DAY_NAMES = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

function printUsage() {
  console.log(`
Usage:
  node create_shifts.js --teacher "Name" --students "code1,code2" --days "Mon,Wed" --start "09:00" --end "10:00" [--apply]

Required Arguments:
  --teacher     Teacher name (partial match works)
  --students    Comma-separated student codes
  --days        Comma-separated days (Mon,Tue,Wed,Thu,Fri,Sat,Sun)
  --start       Start time in 24h format (e.g., "09:00")
  --end         End time in 24h format (e.g., "10:00")

Optional Arguments:
  --class-type  IC (Individual) or FGC (Family Group). Default: auto-detected
  --subject     Subject name. Default: "quran_studies"
  --weeks       Weeks to generate. Default: 10
  --apply       Actually create (without this, it's a dry run)

Examples:
  # Preview mode
  node create_shifts.js --teacher "Abdoullahi Yaya" --students "john.doe" --days "Mon,Wed,Fri" --start "18:00" --end "19:00"

  # Create for real
  node create_shifts.js --teacher "Abdoullahi Yaya" --students "john.doe,jane.doe" --days "Sat,Sun" --start "14:00" --end "15:30" --apply
`);
}

async function findTeacher(searchTerm) {
  const teachersSnap = await db.collection('users')
    .where('user_type', '==', 'teacher')
    .get();

  const searchLower = searchTerm.toLowerCase();
  const matches = [];

  for (const doc of teachersSnap.docs) {
    const data = doc.data();
    const fullName = `${data.first_name || ''} ${data.last_name || ''}`.trim();
    const fullNameLower = fullName.toLowerCase();
    const email = (data.email || '').toLowerCase();
    const uid = doc.id.toLowerCase();

    // Check if search term matches name, email, or UID
    const matchesName = fullNameLower.includes(searchLower) || 
                        searchLower.split(' ').every(part => fullNameLower.includes(part));
    const matchesEmail = email === searchLower || email.includes(searchLower);
    const matchesUid = uid === searchLower;

    if (matchesName || matchesEmail || matchesUid) {
      matches.push({
        uid: doc.id,
        name: fullName,
        email: data.email,
        firstName: data.first_name,
        lastName: data.last_name,
        timezone: data.timezone || NYC_TZ,
      });
    }
  }

  return matches;
}

async function findStudents(studentCodes) {
  const studentsSnap = await db.collection('users')
    .where('user_type', '==', 'student')
    .get();

  const studentMap = new Map();

  for (const doc of studentsSnap.docs) {
    const data = doc.data();
    const code = data.student_code || data.studentId || data.student_id;
    if (code) {
      studentMap.set(code.toLowerCase(), {
        uid: doc.id,
        name: `${data.first_name || ''} ${data.last_name || ''}`.trim(),
        code: code,
      });
    }
  }

  const found = [];
  const notFound = [];

  for (const code of studentCodes) {
    const student = studentMap.get(code.toLowerCase());
    if (student) {
      found.push(student);
    } else {
      notFound.push(code);
    }
  }

  return { found, notFound, allStudents: studentMap };
}

async function findSubject(subjectName) {
  const subjectsSnap = await db.collection('subjects')
    .where('isActive', '==', true)
    .get();

  for (const doc of subjectsSnap.docs) {
    const data = doc.data();
    if (data.name === subjectName || data.name?.toLowerCase() === subjectName.toLowerCase()) {
      return {
        id: doc.id,
        name: data.name,
        displayName: data.displayName,
        hourlyRate: data.defaultWage || 4,
      };
    }
  }

  // Default fallback
  return {
    id: 'quran_studies',
    name: 'quran_studies',
    displayName: 'Quran Studies',
    hourlyRate: 4,
  };
}

function calculateDuration(startTime, endTime) {
  const [startH, startM] = startTime.split(':').map(Number);
  const [endH, endM] = endTime.split(':').map(Number);
  return (endH * 60 + endM) - (startH * 60 + startM);
}

async function createShifts(config) {
  const { teacher, students, days, startTime, endTime, classType, subject, weeks, apply } = config;

  const durationMinutes = calculateDuration(startTime, endTime);
  const maxDaysAhead = weeks * 7;
  const effectiveClassType = classType || (students.length > 1 ? 'FGC' : 'IC');

  console.log('\n' + '='.repeat(80));
  console.log('SHIFT CREATION SUMMARY');
  console.log('='.repeat(80));
  console.log(`\nMode: ${apply ? '🔴 LIVE - CREATING SHIFTS' : '🟡 DRY RUN (use --apply to create)'}`);
  console.log(`\nTeacher:    ${teacher.name} (${teacher.uid})`);
  console.log(`Students:   ${students.map(s => s.name).join(', ')}`);
  console.log(`Days:       ${days.map(d => DAY_NAMES[d]).join(', ')}`);
  console.log(`Time:       ${startTime} - ${endTime} (${durationMinutes} min)`);
  console.log(`Class Type: ${effectiveClassType}`);
  console.log(`Subject:    ${subject.displayName} ($${subject.hourlyRate}/hr)`);
  console.log(`Duration:   ${weeks} weeks (${maxDaysAhead} days)`);

  if (!apply) {
    // Estimate shifts
    const nowLocal = DateTime.now().setZone(NYC_TZ);
    const endDate = nowLocal.plus({ days: maxDaysAhead });
    let currentDate = nowLocal.startOf('day');
    let estimatedShifts = 0;

    while (currentDate <= endDate) {
      if (days.includes(currentDate.weekday)) {
        const [startH, startM] = startTime.split(':').map(Number);
        const shiftStart = currentDate.set({ hour: startH, minute: startM });
        if (shiftStart > nowLocal) {
          estimatedShifts++;
        }
      }
      currentDate = currentDate.plus({ days: 1 });
    }

    console.log(`\n📊 Would create: 1 template, ~${estimatedShifts} shifts`);
    console.log('\n💡 Run with --apply to create these shifts\n');
    return { templates: 0, shifts: 0 };
  }

  // Create template
  console.log('\n' + '='.repeat(80));
  console.log('CREATING TEMPLATE AND SHIFTS...');
  console.log('='.repeat(80));

  const templateId = `tpl_${crypto.randomBytes(8).toString('hex')}`;
  const studentIds = students.map(s => s.uid);
  const studentNames = students.map(s => s.name);

  const templateData = {
    id: templateId,
    teacher_id: teacher.uid,
    teacher_name: teacher.name,
    student_ids: studentIds,
    student_names: studentNames,
    subject: subject.name,
    subject_display_name: subject.displayName,
    hourly_rate: subject.hourlyRate,
    start_time: startTime,
    end_time: endTime,
    duration_minutes: durationMinutes,
    admin_timezone: NYC_TZ,
    teacher_timezone: teacher.timezone,
    recurrence: 'weekly',
    enhanced_recurrence: {
      type: 'weekly',
      selectedWeekdays: days,
    },
    max_days_ahead: maxDaysAhead,
    is_active: true,
    video_provider: 'livekit',
    shift_category: 'teaching',
    notes: `${effectiveClassType} - Created via script`,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('shift_templates').doc(templateId).set(templateData);
  console.log(`\n✅ Template created: ${templateId}`);

  // Generate shifts
  const nowLocal = DateTime.now().setZone(NYC_TZ);
  const endDate = nowLocal.plus({ days: maxDaysAhead });
  let currentDate = nowLocal.startOf('day');
  let shiftsCreated = 0;

  while (currentDate <= endDate) {
    if (days.includes(currentDate.weekday)) {
      const [startH, startM] = startTime.split(':').map(Number);
      const [endH, endM] = endTime.split(':').map(Number);

      const shiftStart = currentDate.set({ hour: startH, minute: startM, second: 0 });
      const shiftEnd = currentDate.set({ hour: endH, minute: endM, second: 0 });

      // Only create future shifts
      if (shiftStart > nowLocal) {
        const shiftId = `tpl_${templateId}_${Math.floor(shiftStart.toMillis() / 1000)}`;

        const shiftData = {
          id: shiftId,
          template_id: templateId,
          teacher_id: teacher.uid,
          teacher_name: teacher.name,
          student_ids: studentIds,
          student_names: studentNames,
          shift_start: admin.firestore.Timestamp.fromDate(shiftStart.toUTC().toJSDate()),
          shift_end: admin.firestore.Timestamp.fromDate(shiftEnd.toUTC().toJSDate()),
          duration_minutes: durationMinutes,
          status: 'scheduled',
          video_provider: 'livekit',
          livekit_room_name: `shift_${shiftId}`,
          subject: subject.name,
          subject_display_name: subject.displayName,
          hourly_rate: subject.hourlyRate,
          notes: `${effectiveClassType} - Created via script`,
          admin_timezone: NYC_TZ,
          teacher_timezone: teacher.timezone,
          shift_category: 'teaching',
          auto_generated_name: `${teacher.name} - ${subject.displayName} - ${studentNames.join(', ')}`,
          recurrence: 'weekly',
          recurrence_series_id: templateId,
          enhanced_recurrence: templateData.enhanced_recurrence,
          generated_from_template: true,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
          last_modified: admin.firestore.FieldValue.serverTimestamp(),
        };

        await db.collection('teaching_shifts').doc(shiftId).set(shiftData);
        shiftsCreated++;

        if (shiftsCreated <= 5 || shiftsCreated % 10 === 0) {
          console.log(`   📅 ${shiftStart.toFormat('EEE, MMM dd yyyy')} ${startTime}-${endTime}`);
        }
      }
    }

    currentDate = currentDate.plus({ days: 1 });
  }

  console.log(`\n✅ Created ${shiftsCreated} shifts`);

  return { templates: 1, shifts: shiftsCreated };
}

async function main() {
  const args = parseArgs();

  // Validate required arguments
  if (!args.teacher || args.students.length === 0 || args.days.length === 0 || !args.startTime || !args.endTime) {
    console.error('❌ Missing required arguments\n');
    printUsage();
    process.exit(1);
  }

  // Validate time format
  const timeRegex = /^\d{2}:\d{2}$/;
  if (!timeRegex.test(args.startTime) || !timeRegex.test(args.endTime)) {
    console.error('❌ Invalid time format. Use 24h format like "09:00" or "14:30"');
    process.exit(1);
  }

  console.log('\n' + '='.repeat(80));
  console.log('SHIFT CREATION SCRIPT');
  console.log('='.repeat(80));

  // Find teacher
  console.log(`\n1. Finding teacher: "${args.teacher}"...`);
  const teacherMatches = await findTeacher(args.teacher);

  if (teacherMatches.length === 0) {
    console.error(`\n❌ No teacher found matching "${args.teacher}"`);
    console.log('\nTip: Try a partial name like "Abdoul" or "Yaya"');
    process.exit(1);
  }

  if (teacherMatches.length > 1) {
    console.log(`\n⚠️  Multiple teachers found matching "${args.teacher}":`);
    teacherMatches.forEach((t, i) => {
      console.log(`   ${i + 1}. ${t.name} (${t.uid})`);
    });
    console.log('\nPlease use a more specific name to match exactly one teacher.');
    process.exit(1);
  }

  const teacher = teacherMatches[0];
  console.log(`   ✅ Found: ${teacher.name}`);
  console.log(`      Email: ${teacher.email || 'N/A'}`);
  console.log(`      UID: ${teacher.uid}`);

  // Find students
  console.log(`\n2. Finding students: ${args.students.join(', ')}...`);
  const { found: students, notFound, allStudents } = await findStudents(args.students);

  if (notFound.length > 0) {
    console.error(`\n❌ Students not found: ${notFound.join(', ')}`);
    console.log('\nAvailable student codes (sample):');
    const sampleCodes = Array.from(allStudents.entries()).slice(0, 20);
    sampleCodes.forEach(([code, student]) => {
      console.log(`   ${code} → ${student.name}`);
    });
    if (allStudents.size > 20) {
      console.log(`   ... and ${allStudents.size - 20} more`);
    }
    process.exit(1);
  }

  students.forEach(s => {
    console.log(`   ✅ ${s.name} (${s.code})`);
  });

  // Parse days
  console.log(`\n3. Parsing days: ${args.days.join(', ')}...`);
  const days = parseDays(args.days);
  console.log(`   ✅ ${days.map(d => DAY_NAMES[d]).join(', ')}`);

  // Find subject
  console.log(`\n4. Finding subject: ${args.subject}...`);
  const subject = await findSubject(args.subject);
  console.log(`   ✅ ${subject.displayName} ($${subject.hourlyRate}/hr)`);

  // Create shifts
  const result = await createShifts({
    teacher,
    students,
    days,
    startTime: args.startTime,
    endTime: args.endTime,
    classType: args.classType,
    subject,
    weeks: args.weeks,
    apply: args.apply,
  });

  if (args.apply) {
    console.log('\n' + '='.repeat(80));
    console.log('✅ DONE!');
    console.log('='.repeat(80));
    console.log(`   Templates created: ${result.templates}`);
    console.log(`   Shifts created: ${result.shifts}`);
    console.log('');
  }
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('\n❌ Error:', e.message);
    console.error(e.stack);
    process.exit(1);
  });
