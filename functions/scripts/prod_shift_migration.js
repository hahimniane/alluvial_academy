#!/usr/bin/env node
'use strict';

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const Excel = require('exceljs');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'alluwal-academy';
const APPLY = process.argv.includes('--apply');
const SKIP_RELATED = process.argv.includes('--skip-related');
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp';
const ADMIN_TIMEZONE = 'America/New_York';
const MAX_DAYS_AHEAD = 10;
const TEACHER_OVERRIDES_PATH =
  process.env.TEACHER_OVERRIDES || path.resolve(__dirname, 'prod_teacher_overrides.json');
const STUDENT_OVERRIDES_PATH =
  process.env.STUDENT_OVERRIDES || path.resolve(__dirname, 'prod_student_overrides.json');

const SCHEDULE_VARIANTS = [
  {label: 'salima', names: ['salima_teachers.csv']},
  {label: 'kadijah', names: ['kadijah_teachers.csv', 'kadija_teachers.csv']},
  {label: 'mr_bah', names: ['mr_bah_teachers.csv']},
];
const SCHEDULE_ROOT = path.resolve(__dirname, '../..');
const collectArgValues = (flag) => {
  const values = [];
  for (let i = 0; i < process.argv.length; i += 1) {
    const arg = process.argv[i];
    if (arg === flag && process.argv[i + 1]) {
      values.push(process.argv[i + 1]);
      i += 1;
      continue;
    }
    if (arg && arg.startsWith(`${flag}=`)) {
      values.push(arg.slice(flag.length + 1));
    }
  }
  return values;
};
const collectCsvInputs = () => {
  const cli = [
    ...collectArgValues('--csv'),
    ...collectArgValues('--schedule'),
    ...collectArgValues('--schedule-file'),
  ];
  const env = []
    .concat(process.env.SCHEDULE_FILES || '')
    .concat(process.env.SCHEDULE_FILE || '')
    .join(',')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  return [...cli, ...env];
};
const normalizeSchedulePath = (input) =>
  path.isAbsolute(input) ? input : path.resolve(SCHEDULE_ROOT, input);
const CUSTOM_SCHEDULE_FILES = Array.from(
  new Set(collectCsvInputs().map(normalizeSchedulePath).filter(Boolean)),
);
const resolveScheduleFiles = () => {
  if (CUSTOM_SCHEDULE_FILES.length) {
    const missing = CUSTOM_SCHEDULE_FILES.filter((file) => !fs.existsSync(file));
    if (missing.length) {
      throw new Error(`Missing schedule file(s): ${missing.join(', ')}`);
    }
    return CUSTOM_SCHEDULE_FILES;
  }
  const entries = fs.readdirSync(SCHEDULE_ROOT);
  const lowerMap = new Map(entries.map((name) => [name.toLowerCase(), name]));
  return SCHEDULE_VARIANTS.map((variant) => {
    const match = variant.names.find((name) => lowerMap.has(name));
    const actual = match ? lowerMap.get(match) : variant.names[0];
    return path.resolve(SCHEDULE_ROOT, actual);
  });
};

const STATUS_TO_DELETE = ['active', 'scheduled', 'in_progress', 'pending'];

const normalizeHeader = (value) =>
  (value || '')
    .toString()
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();

const normalizeName = (value) =>
  (value || '')
    .toString()
    .replace(/[^a-zA-Z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();

const normalizeCode = (value) => (value || '').toString().trim().toLowerCase();

const normalizeSubjectKey = (value) =>
  (value || '')
    .toString()
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');

const DAY_MAP = new Map([
  ['monday', 1],
  ['tuesday', 2],
  ['wednesday', 3],
  ['thursday', 4],
  ['friday', 5],
  ['saturday', 6],
  ['sunday', 7],
]);

const mapSubjectToLegacy = (subjectName) => {
  const normalized = (subjectName || '').toString().toLowerCase().replace(/\s+/g, '_');
  switch (normalized) {
    case 'quran_studies':
      return 'quranStudies';
    case 'hadith_studies':
      return 'hadithStudies';
    case 'fiqh':
      return 'fiqh';
    case 'arabic_language':
      return 'arabicLanguage';
    case 'islamic_history':
      return 'islamicHistory';
    case 'aqeedah':
      return 'aqeedah';
    case 'tafseer':
      return 'tafseer';
    case 'seerah':
      return 'seerah';
    default:
      return 'other';
  }
};

const parseDurationMinutes = (value) => {
  const raw = (value || '').toString().toLowerCase();
  if (!raw) return null;
  const hourMatch = raw.match(/(\d+)\s*hr/);
  const hourMatchAlt = raw.match(/(\d+)\s*hour/);
  const minuteMatch = raw.match(/(\d+)\s*min/);
  const hours = hourMatch ? Number(hourMatch[1]) : hourMatchAlt ? Number(hourMatchAlt[1]) : 0;
  const minutes = minuteMatch ? Number(minuteMatch[1]) : 0;
  if (!Number.isFinite(hours) || !Number.isFinite(minutes)) return null;
  const total = hours * 60 + minutes;
  return total > 0 ? total : null;
};

const parseTimeRange = (value) => {
  const raw = (value || '').toString().replace(/nyc/gi, '').trim();
  if (!raw) return null;
  const timeRegex = /(\d{1,2})\s*(?::\s*(\d{2}))?\s*(am|pm)?/gi;
  const matches = Array.from(raw.matchAll(timeRegex));
  if (matches.length < 2) return null;

  const startMatch = matches[0];
  const endMatch = matches[1];

  const startHourRaw = Number(startMatch[1]);
  const startMinuteRaw = startMatch[2] ? Number(startMatch[2]) : 0;
  const startMeridiem = startMatch[3] ? startMatch[3].toLowerCase() : null;
  const endHourRaw = Number(endMatch[1]);
  const endMinuteRaw = endMatch[2] ? Number(endMatch[2]) : 0;
  const endMeridiem = endMatch[3] ? endMatch[3].toLowerCase() : null;

  const resolvedStartMeridiem = startMeridiem || endMeridiem;
  const resolvedEndMeridiem = endMeridiem || startMeridiem;

  const to24h = (hour, meridiem) => {
    if (!meridiem) return hour;
    if (meridiem === 'am') return hour === 12 ? 0 : hour;
    return hour === 12 ? 12 : hour + 12;
  };

  const startHour = to24h(startHourRaw, resolvedStartMeridiem);
  const endHour = to24h(endHourRaw, resolvedEndMeridiem);

  if (!Number.isFinite(startHour) || !Number.isFinite(endHour)) return null;

  const pad = (n) => String(n).padStart(2, '0');
  return {
    startHour,
    startMinute: startMinuteRaw,
    endHour,
    endMinute: endMinuteRaw,
    startTime: `${pad(startHour)}:${pad(startMinuteRaw)}`,
    endTime: `${pad(endHour)}:${pad(endMinuteRaw)}`,
  };
};

const parseWeekdays = (value) => {
  const raw = (value || '').toString();
  if (!raw) return [];
  const replaced = raw
    .replace(/\band\b/gi, ',')
    .replace(/[&/]/g, ',')
    .replace(/;/g, ',');
  const parts = replaced
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);

  const dayAliases = new Map([
    ['mon', 1],
    ['monday', 1],
    ['tue', 2],
    ['tues', 2],
    ['tuesday', 2],
    ['wed', 3],
    ['wednesday', 3],
    ['thu', 4],
    ['thur', 4],
    ['thurs', 4],
    ['thursday', 4],
    ['fri', 5],
    ['friday', 5],
    ['sat', 6],
    ['saturday', 6],
    ['sun', 7],
    ['sunday', 7],
  ]);

  const results = [];
  for (const part of parts) {
    const key = part.toLowerCase().replace(/[^a-z]/g, '');
    if (!key) continue;
    const day = DAY_MAP.get(key) || dayAliases.get(key) || dayAliases.get(key.slice(0, 3));
    if (day) results.push(day);
  }
  return Array.from(new Set(results));
};

const loadStudentOverrides = () => {
  const overrides = new Map();
  if (!fs.existsSync(STUDENT_OVERRIDES_PATH)) {
    return overrides;
  }
  const raw = fs.readFileSync(STUDENT_OVERRIDES_PATH, 'utf8');
  const parsed = JSON.parse(raw);
  Object.entries(parsed).forEach(([key, value]) => {
    const normalized = normalizeCode(key);
    if (!normalized || !value) return;
    overrides.set(normalized, normalizeCode(value));
  });
  return overrides;
};

const loadTeacherOverrides = () => {
  const overrides = new Map();
  if (!fs.existsSync(TEACHER_OVERRIDES_PATH)) {
    return overrides;
  }
  const raw = fs.readFileSync(TEACHER_OVERRIDES_PATH, 'utf8');
  const parsed = JSON.parse(raw);
  Object.entries(parsed).forEach(([key, value]) => {
    const normalized = normalizeName(key);
    if (!normalized || !value) return;
    overrides.set(normalized, String(value));
  });
  return overrides;
};

const writeCsv = (filePath, headers, rows) => {
  const lines = [headers.join(',')];
  for (const row of rows) {
    const values = headers.map((key) => {
      const raw = row[key] == null ? '' : String(row[key]);
      if (raw.includes('"') || raw.includes(',') || raw.includes('\n')) {
        return `"${raw.replace(/"/g, '""')}"`;
      }
      return raw;
    });
    lines.push(values.join(','));
  }
  fs.writeFileSync(filePath, lines.join('\n'));
};

const loadScheduleRows = async (files, studentOverrides) => {
  const rows = [];
  for (const file of files) {
    const workbook = new Excel.Workbook();
    const sheet = await workbook.csv.readFile(file);
    const headerRow = sheet.getRow(1).values;
    const headerMap = new Map();

    headerRow.forEach((value, index) => {
      if (!value || index === 0) return;
      headerMap.set(normalizeHeader(value), index);
    });

    const headerKey = (candidates) => {
      for (const candidate of candidates) {
        const idx = headerMap.get(candidate);
        if (idx) return idx;
      }
      return null;
    };

    const teacherIdx = headerKey(['teacher name']);
    const studentIdx = headerKey(['student name']);
    const studentCodeIdx = headerKey(['student id (from the website)', 'student id']);
    const dayIdx = headerKey(['day']);
    const timeIdx = headerKey(['time']);
    const durationIdx = headerKey(['duration']);
    const programIdx = headerKey(['program']);
    const classTypeIdx = headerKey(['class type']);

    if (!teacherIdx || !studentIdx || !studentCodeIdx || !dayIdx || !timeIdx) {
      throw new Error(`Missing required headers in ${file}`);
    }

    let current = {
      teacherName: '',
      studentName: '',
      studentCode: '',
      day: '',
      time: '',
      duration: '',
      program: '',
      classType: '',
    };

    for (let rowIndex = 2; rowIndex <= sheet.rowCount; rowIndex += 1) {
      const row = sheet.getRow(rowIndex);
      const teacherNameRaw = teacherIdx ? row.getCell(teacherIdx).text.trim() : '';
      const studentNameRaw = studentIdx ? row.getCell(studentIdx).text.trim() : '';
      const studentCodeRaw = studentCodeIdx ? row.getCell(studentCodeIdx).text.trim() : '';
      const dayRaw = dayIdx ? row.getCell(dayIdx).text.trim() : '';
      const timeRaw = timeIdx ? row.getCell(timeIdx).text.trim() : '';
      const durationRaw = durationIdx ? row.getCell(durationIdx).text.trim() : '';
      const programRaw = programIdx ? row.getCell(programIdx).text.trim() : '';
      const classTypeRaw = classTypeIdx ? row.getCell(classTypeIdx).text.trim() : '';

      const rowHasValues = [
        teacherNameRaw,
        studentNameRaw,
        studentCodeRaw,
        dayRaw,
        timeRaw,
        durationRaw,
        programRaw,
        classTypeRaw,
      ].some((value) => value && value.trim().length > 0);

      if (!rowHasValues) {
        continue;
      }

      if (teacherNameRaw) current.teacherName = teacherNameRaw;
      if (dayRaw) current.day = dayRaw;
      if (timeRaw) current.time = timeRaw;
      if (durationRaw) current.duration = durationRaw;
      if (programRaw) current.program = programRaw;
      if (classTypeRaw) current.classType = classTypeRaw;

      if (studentNameRaw || studentCodeRaw) {
        current.studentName = studentNameRaw || '';
        current.studentCode = studentCodeRaw || '';
      }

      const teacherName = current.teacherName;
      const studentName = current.studentName;
      const studentCode = normalizeCode(current.studentCode);
      const dayValue = current.day;
      const timeValue = current.time;
      const durationValue = current.duration;
      const program = current.program;
      const classType = current.classType;

      if (!teacherName || !studentName || !studentCode || !dayValue || !timeValue) {
        continue;
      }

      const normalizedCode = normalizeCode(studentCode);
      const overrideCode = studentOverrides.get(normalizedCode) || normalizedCode;
      current.studentCode = overrideCode;

      const weekdays = parseWeekdays(dayValue);
      if (weekdays.length === 0) {
        continue;
      }

      for (const weekday of weekdays) {
        const dayLabel = Array.from(DAY_MAP.entries()).find(([, v]) => v === weekday)?.[0] || dayValue;
        rows.push({
          sourceFile: path.basename(file),
          teacherName,
          studentName,
          studentCode: overrideCode,
          day: dayLabel,
          weekday,
          time: timeValue,
          duration: durationValue,
          program,
          classType,
        });
      }
    }
  }
  return rows;
};

const buildTeacherMaps = (teachers) => {
  const byName = new Map();
  const byLastName = new Map();
  const byFirstName = new Map();
  const trackFirstKey = (key, teacher) => {
    if (!key) return;
    const existing = byFirstName.get(key);
    if (!existing) {
      byFirstName.set(key, teacher);
      return;
    }
    if (existing !== teacher) {
      byFirstName.set(key, null);
    }
  };

  for (const teacher of teachers) {
    const fullName = `${teacher.firstName} ${teacher.lastName}`.trim();
    const normalized = normalizeName(fullName);
    if (normalized) {
      byName.set(normalized, teacher);
    }

    const reversed = normalizeName(`${teacher.lastName} ${teacher.firstName}`);
    if (reversed) {
      byName.set(reversed, teacher);
    }

    const lastKey = normalizeName(teacher.lastName);
    if (lastKey) {
      const existing = byLastName.get(lastKey) || [];
      existing.push(teacher);
      byLastName.set(lastKey, existing);
    }

    const firstKey = normalizeName(teacher.firstName);
    trackFirstKey(firstKey, teacher);
    const firstToken = normalizeName((teacher.firstName || '').split(' ')[0]);
    if (firstToken && firstToken !== firstKey) {
      trackFirstKey(firstToken, teacher);
    }
  }

  return {byName, byLastName, byFirstName};
};

const pickTeacher = (teacherName, teacherMaps, teacherOverrides, teachersById) => {
  const normalized = normalizeName(teacherName);
  if (!normalized) return null;
  const overrideId = teacherOverrides.get(normalized);
  if (overrideId) {
    return teachersById.get(overrideId) || null;
  }
  const direct = teacherMaps.byName.get(normalized);
  if (direct) return direct;

  const tokens = normalized.split(' ').filter(Boolean);
  if (tokens.length >= 2) {
    const shortKey = `${tokens[0]} ${tokens[tokens.length - 1]}`;
    const shortMatch = teacherMaps.byName.get(shortKey);
    if (shortMatch) return shortMatch;
  }

  const lastToken = tokens[tokens.length - 1];
  if (lastToken) {
    const candidates = teacherMaps.byLastName.get(lastToken);
    if (candidates && candidates.length === 1) {
      return candidates[0];
    }
  }

  if (tokens.length === 1) {
    const candidate = teacherMaps.byFirstName.get(tokens[0]);
    if (candidate) return candidate;
  }

  return null;
};

const nextOccurrence = (weekday, hour, minute, zone) => {
  const now = DateTime.now().setZone(zone);
  const deltaDays = (weekday - now.weekday + 7) % 7;
  let candidate = now.plus({days: deltaDays}).set({
    hour,
    minute,
    second: 0,
    millisecond: 0,
  });
  if (candidate <= now) {
    candidate = candidate.plus({days: 7});
  }
  return candidate;
};

const main = async () => {
  if (!admin.apps.length) {
    admin.initializeApp({projectId: PROJECT_ID});
  }
  const db = admin.firestore();

  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Mode: ${APPLY ? 'APPLY' : 'AUDIT ONLY'}`);

  const studentOverrides = loadStudentOverrides();
  const scheduleRows = await loadScheduleRows(resolveScheduleFiles(), studentOverrides);
  console.log(`Loaded ${scheduleRows.length} schedule rows.`);

  const scheduleStudentCodes = new Set(scheduleRows.map((row) => row.studentCode));
  const scheduleTeacherNames = new Set(scheduleRows.map((row) => row.teacherName));

  const subjectsSnap = await db.collection('subjects').get();
  const subjects = subjectsSnap.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  const subjectByKey = new Map();
  for (const subject of subjects) {
    const nameKey = normalizeSubjectKey(subject.name);
    const displayKey = normalizeSubjectKey(subject.displayName || subject.display_name);
    if (nameKey) subjectByKey.set(nameKey, subject);
    if (displayKey) subjectByKey.set(displayKey, subject);
  }

  const students = [];
  try {
    const snap = await db.collection('users').where('user_type', 'in', ['student', 'Student']).get();
    snap.docs.forEach((doc) => {
      const data = doc.data() || {};
      const code = normalizeCode(data.student_code || data.studentCode || data.student_id);
      if (!code) return;
      students.push({
        uid: doc.id,
        studentCode: code,
        firstName: data.first_name || '',
        lastName: data.last_name || '',
        email: data['e-mail'] || data.email || '',
        isActive: data.is_active,
      });
    });
  } catch (err) {
    const snapA = await db.collection('users').where('user_type', '==', 'student').get();
    const snapB = await db.collection('users').where('user_type', '==', 'Student').get();
    [snapA, snapB].forEach((snap) => {
      snap.docs.forEach((doc) => {
        const data = doc.data() || {};
        const code = normalizeCode(data.student_code || data.studentCode || data.student_id);
        if (!code) return;
        students.push({
          uid: doc.id,
          studentCode: code,
          firstName: data.first_name || '',
          lastName: data.last_name || '',
          email: data['e-mail'] || data.email || '',
          isActive: data.is_active,
        });
      });
    });
  }

  const studentsByCode = new Map();
  for (const student of students) {
    studentsByCode.set(student.studentCode, student);
  }

  const teachersSnap = await db.collection('users').where('user_type', '==', 'teacher').get();
  const teachers = teachersSnap.docs.map((doc) => {
    const data = doc.data() || {};
    return {
      uid: doc.id,
      firstName: data.first_name || '',
      lastName: data.last_name || '',
      timezone: data.timezone || '',
    };
  });
  const teachersById = new Map(teachers.map((teacher) => [teacher.uid, teacher]));
  const teacherMaps = buildTeacherMaps(teachers);
  const teacherOverrides = loadTeacherOverrides();

  const studentsNotInSchedule = students.filter((student) => !scheduleStudentCodes.has(student.studentCode));
  const missingScheduleStudents = new Set();
  for (const code of scheduleStudentCodes) {
    if (!studentsByCode.has(code)) {
      missingScheduleStudents.add(code);
    }
  }

  const missingTeachers = new Set();
  const teacherIdsInSchedule = new Set();
  for (const name of scheduleTeacherNames) {
    const teacher = pickTeacher(name, teacherMaps, teacherOverrides, teachersById);
    if (!teacher) {
      missingTeachers.add(name);
      continue;
    }
    teacherIdsInSchedule.add(teacher.uid);
  }

  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const studentsNotInSchedulePath = path.join(OUTPUT_DIR, `prod_students_not_in_schedule_${timestamp}.csv`);
  writeCsv(
    studentsNotInSchedulePath,
    ['uid', 'student_code', 'first_name', 'last_name', 'email', 'is_active'],
    studentsNotInSchedule.map((student) => ({
      uid: student.uid,
      student_code: student.studentCode,
      first_name: student.firstName,
      last_name: student.lastName,
      email: student.email,
      is_active: student.isActive,
    })),
  );

  console.log(`Students not in schedule: ${studentsNotInSchedule.length}`);
  console.log(`Report: ${studentsNotInSchedulePath}`);
  console.log(`Schedule student codes missing in DB: ${missingScheduleStudents.size}`);
  console.log(`Schedule teacher names missing in DB: ${missingTeachers.size}`);

  if (missingScheduleStudents.size > 0) {
    console.log('Missing student codes:', Array.from(missingScheduleStudents).join(', '));
  }
  if (missingTeachers.size > 0) {
    console.log('Missing teachers:', Array.from(missingTeachers).join(', '));
  }

  if (!APPLY) return;

  if (missingScheduleStudents.size > 0 || missingTeachers.size > 0) {
    throw new Error('Aborting apply mode due to missing schedule mappings.');
  }

  console.log('Loading teacher defaults from existing shifts...');
  const teacherDefaults = new Map();
  for (const teacherId of teacherIdsInSchedule) {
    const teacher = teachersById.get(teacherId);
    if (!teacher) continue;
    let snapshot = null;
    try {
      snapshot = await db
        .collection('teaching_shifts')
        .where('teacher_id', '==', teacher.uid)
        .orderBy('shift_start', 'desc')
        .limit(1)
        .get();
    } catch (err) {
      const fallback = await db.collection('teaching_shifts').where('teacher_id', '==', teacher.uid).limit(1).get();
      snapshot = fallback;
    }
    if (snapshot && !snapshot.empty) {
      const data = snapshot.docs[0].data() || {};
      teacherDefaults.set(teacher.uid, {
        subjectId: data.subject_id || null,
        subjectDisplayName: data.subject_display_name || null,
        subjectLegacy: data.subject || 'other',
        hourlyRate: data.hourly_rate ?? null,
        category: data.shift_category || data.category || 'teaching',
        leaderRole: data.leader_role || null,
        videoProvider: (data.video_provider || 'zoom').toString().trim().toLowerCase(),
      });
    }
  }

  console.log('Exporting shift snapshot...');
  const snapshotRows = [];
  for (const status of STATUS_TO_DELETE) {
    const snap = await db.collection('teaching_shifts').where('status', '==', status).get();
    snap.docs.forEach((doc) => {
      const data = doc.data() || {};
      snapshotRows.push({
        shift_id: doc.id,
        status: data.status || '',
        shift_start: data.shift_start?.toDate?.().toISOString() || '',
        shift_end: data.shift_end?.toDate?.().toISOString() || '',
        teacher_id: data.teacher_id || '',
        teacher_name: data.teacher_name || '',
        student_ids: Array.isArray(data.student_ids) ? data.student_ids.join('|') : '',
        student_names: Array.isArray(data.student_names) ? data.student_names.join('|') : '',
        admin_timezone: data.admin_timezone || '',
        teacher_timezone: data.teacher_timezone || '',
        subject: data.subject || '',
        subject_id: data.subject_id || '',
        subject_display_name: data.subject_display_name || '',
        template_id: data.template_id || '',
        generated_from_template: data.generated_from_template === true ? 'true' : 'false',
      });
    });
  }

  const shiftsSnapshotPath = path.join(OUTPUT_DIR, `prod_shift_snapshot_${timestamp}.csv`);
  writeCsv(
    shiftsSnapshotPath,
    [
      'shift_id',
      'status',
      'shift_start',
      'shift_end',
      'teacher_id',
      'teacher_name',
      'student_ids',
      'student_names',
      'admin_timezone',
      'teacher_timezone',
      'subject',
      'subject_id',
      'subject_display_name',
      'template_id',
      'generated_from_template',
    ],
    snapshotRows,
  );
  console.log(`Shift snapshot saved: ${shiftsSnapshotPath}`);

  if (SKIP_RELATED) {
    console.log('Deleting shifts (skipping related documents)...');
  } else {
    console.log('Deleting shifts and related data...');
  }
  const allShiftIds = snapshotRows.map((row) => row.shift_id);
  let batch = db.batch();
  let opCount = 0;

  const flush = async () => {
    if (opCount === 0) return;
    await batch.commit();
    batch = db.batch();
    opCount = 0;
  };

  const queueDelete = async (ref) => {
    batch.delete(ref);
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  };

  for (const shiftId of allShiftIds) {
    if (!SKIP_RELATED) {
      for (const field of ['shift_id', 'shiftId']) {
        const timesheetSnap = await db.collection('timesheet_entries').where(field, '==', shiftId).get();
        for (const doc of timesheetSnap.docs) {
          await queueDelete(doc.ref);
          const timesheetId = doc.id;
          for (const formField of ['timesheetId', 'timesheet_id']) {
            const formByTimesheet = await db.collection('form_responses').where(formField, '==', timesheetId).get();
            for (const formDoc of formByTimesheet.docs) {
              await queueDelete(formDoc.ref);
            }
          }
        }
      }

      for (const field of ['shift_id', 'shiftId']) {
        const formSnap = await db.collection('form_responses').where(field, '==', shiftId).get();
        for (const doc of formSnap.docs) {
          await queueDelete(doc.ref);
        }
      }
    }

    await queueDelete(db.collection('teaching_shifts').doc(shiftId));
  }

  await flush();
  console.log(`Deleted ${allShiftIds.length} shifts.`);

  console.log('Clearing existing shift templates...');
  const templatesSnap = await db.collection('shift_templates').get();
  for (let i = 0; i < templatesSnap.docs.length; i += 450) {
    const chunk = templatesSnap.docs.slice(i, i + 450);
    const chunkBatch = db.batch();
    chunk.forEach((doc) => chunkBatch.delete(doc.ref));
    await chunkBatch.commit();
  }
  console.log(`Deleted ${templatesSnap.size} templates.`);

  console.log('Building new templates from schedule...');
  const grouped = new Map();
  const missingStudentCodes = new Set();

  for (const row of scheduleRows) {
    const teacher = pickTeacher(row.teacherName, teacherMaps, teacherOverrides, teachersById);
    if (!teacher) {
      missingTeachers.add(row.teacherName);
      continue;
    }

    const student = studentsByCode.get(row.studentCode);
    if (!student) {
      missingStudentCodes.add(row.studentCode);
      continue;
    }

    const weekday = Number.isInteger(row.weekday)
      ? row.weekday
      : DAY_MAP.get(normalizeName(row.day));
    if (!weekday) continue;

    const timeRange = parseTimeRange(row.time);
    if (!timeRange) continue;

    const durationMinutes =
      parseDurationMinutes(row.duration) ||
      (() => {
        const startMinutes = timeRange.startHour * 60 + timeRange.startMinute;
        const endMinutes = timeRange.endHour * 60 + timeRange.endMinute;
        const delta = endMinutes - startMinutes;
        return delta > 0 ? delta : delta + 24 * 60;
      })();

    const programKey = normalizeSubjectKey(row.program);
    const classTypeKey = normalizeSubjectKey(row.classType);

    const groupKey = [
      teacher.uid,
      weekday,
      timeRange.startTime,
      timeRange.endTime,
      programKey,
      classTypeKey,
    ].join('|');

    const group = grouped.get(groupKey) || {
      teacherId: teacher.uid,
      teacherName: `${teacher.firstName} ${teacher.lastName}`.trim(),
      teacherTimezone: teacher.timezone || ADMIN_TIMEZONE,
      weekday,
      startTime: timeRange.startTime,
      endTime: timeRange.endTime,
      durationMinutes,
      program: row.program,
      classType: row.classType,
      studentIds: [],
      studentNames: [],
    };

    if (!group.studentIds.includes(student.uid)) {
      group.studentIds.push(student.uid);
      const studentName =
        `${student.firstName} ${student.lastName}`.trim() || row.studentName;
      group.studentNames.push(studentName);
    }

    grouped.set(groupKey, group);
  }

  if (missingStudentCodes.size > 0 || missingTeachers.size > 0) {
    throw new Error('Aborting apply mode due to missing schedule mappings.');
  }

  const migrationAdmin = await db.collection('users').where('user_type', '==', 'admin').limit(1).get();
  const adminId = migrationAdmin.empty ? null : migrationAdmin.docs[0].id;

  const templatesCreated = [];

  for (const group of grouped.values()) {
    const sortedStudentIds = [...group.studentIds].sort();
    const hashInput = [
      group.teacherId,
      group.weekday,
      group.startTime,
      group.endTime,
      normalizeSubjectKey(group.program),
      normalizeSubjectKey(group.classType),
      sortedStudentIds.join(','),
    ].join('|');
    const hash = crypto.createHash('sha1').update(hashInput).digest('hex').slice(0, 16);
    const templateId = `tpl_${hash}`;

    const subjectCandidate =
      subjectByKey.get(normalizeSubjectKey(group.program)) ||
      subjectByKey.get(normalizeSubjectKey(group.classType));

    const teacherDefault = teacherDefaults.get(group.teacherId) || {};
    const subjectId = subjectCandidate?.id || teacherDefault.subjectId || null;
    const subjectDisplayName =
      subjectCandidate?.displayName ||
      subjectCandidate?.display_name ||
      teacherDefault.subjectDisplayName ||
      group.program ||
      group.classType ||
      null;
    const subjectLegacy = subjectCandidate
      ? mapSubjectToLegacy(subjectCandidate.name || subjectCandidate.displayName)
      : teacherDefault.subjectLegacy || mapSubjectToLegacy(subjectDisplayName);

    const now = DateTime.now().setZone(ADMIN_TIMEZONE);
    const baseStart = nextOccurrence(
      group.weekday,
      Number(group.startTime.split(':')[0]),
      Number(group.startTime.split(':')[1]),
      ADMIN_TIMEZONE,
    );
    const baseEnd = baseStart.plus({minutes: group.durationMinutes});
    const endDate = now.plus({days: 365});

    const subjectLabel = subjectDisplayName || 'Class';
    const studentLabel = group.studentNames.join(', ');
    const autoGeneratedName = `${group.teacherName} - ${subjectLabel} - ${studentLabel}`;
    const notes = [group.program, group.classType].filter(Boolean).join(' / ') || null;

    const templateDoc = {
      teacher_id: group.teacherId,
      teacher_name: group.teacherName,
      student_ids: group.studentIds,
      student_names: group.studentNames,
      start_time: group.startTime,
      end_time: group.endTime,
      duration_minutes: group.durationMinutes,
      admin_timezone: ADMIN_TIMEZONE,
      teacher_timezone: group.teacherTimezone,
      enhanced_recurrence: {
        type: 'weekly',
        endDate: admin.firestore.Timestamp.fromDate(endDate.toJSDate()),
        excludedDates: [],
        excludedWeekdays: [],
        selectedWeekdays: [group.weekday],
        selectedMonthDays: [],
        selectedMonths: [],
      },
      recurrence: 'weekly',
      recurrence_series_id: templateId,
      series_created_at: admin.firestore.Timestamp.fromDate(now.toJSDate()),
      recurrence_end_date: admin.firestore.Timestamp.fromDate(endDate.toJSDate()),
      recurrence_settings: null,
      subject: subjectLegacy,
      subject_id: subjectId,
      subject_display_name: subjectDisplayName,
      hourly_rate: teacherDefault.hourlyRate ?? null,
      auto_generated_name: autoGeneratedName,
      custom_name: null,
      notes,
      category: teacherDefault.category || 'teaching',
      leader_role: teacherDefault.leaderRole || null,
      video_provider: teacherDefault.videoProvider || 'zoom',
      created_by_admin_id: adminId,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      last_modified: admin.firestore.FieldValue.serverTimestamp(),
      is_active: true,
      last_generated_date: null,
      max_days_ahead: MAX_DAYS_AHEAD,
      base_shift_id: templateId,
      base_shift_start: admin.firestore.Timestamp.fromDate(baseStart.toJSDate()),
      base_shift_end: admin.firestore.Timestamp.fromDate(baseEnd.toJSDate()),
    };

    await db.collection('shift_templates').doc(templateId).set(templateDoc, {merge: true});
    templatesCreated.push({templateId, templateDoc});
  }

  console.log(`Created ${templatesCreated.length} templates. Generating shifts...`);
  const shiftTemplateHandlers = require('../handlers/shift_templates');
  let totalCreated = 0;
  for (const {templateId, templateDoc} of templatesCreated) {
    const result = await shiftTemplateHandlers._generateShiftsForTemplate({
      templateId,
      template: templateDoc,
    });
    totalCreated += result.created || 0;
  }

  console.log(`Generated ${totalCreated} shifts from templates.`);
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
