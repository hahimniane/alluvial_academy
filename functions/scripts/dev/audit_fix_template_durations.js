#!/usr/bin/env node
'use strict';

const path = require('path');
const fs = require('fs');
const Excel = require('exceljs');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'alluwal-academy';
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp';
const APPLY = process.argv.includes('--apply');
const PREFER_DURATION_COLUMN = process.argv.includes('--prefer-duration-column');

const STUDENT_OVERRIDES_PATH =
  process.env.STUDENT_OVERRIDES || path.resolve(__dirname, 'prod_student_overrides.json');
const TEACHER_OVERRIDES_PATH =
  process.env.TEACHER_OVERRIDES || path.resolve(__dirname, 'prod_teacher_overrides.json');

const SCHEDULE_VARIANTS = [
  {label: 'salima', names: ['salima_teachers.csv']},
  {label: 'kadijah', names: ['kadijah_teachers.csv', 'kadija_teachers.csv']},
  {label: 'mr_bah', names: ['mr_bah_teachers.csv']},
];
const SCHEDULE_ROOT = path.resolve(__dirname, '../..');

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

const DAY_MAP = new Map([
  ['monday', 1],
  ['tuesday', 2],
  ['wednesday', 3],
  ['thursday', 4],
  ['friday', 5],
  ['saturday', 6],
  ['sunday', 7],
]);

const resolveScheduleFiles = () => {
  const entries = fs.readdirSync(SCHEDULE_ROOT);
  const lowerMap = new Map(entries.map((name) => [name.toLowerCase(), name]));
  return SCHEDULE_VARIANTS.map((variant) => {
    const match = variant.names.find((name) => lowerMap.has(name));
    const actual = match ? lowerMap.get(match) : variant.names[0];
    return path.resolve(SCHEDULE_ROOT, actual);
  });
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
  const raw = (value || '').toString().replace(/nyc/gi, '').replace(/est/gi, '').trim();
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
      const teacherNameRaw = row.getCell(teacherIdx).text.trim();
      const studentNameRaw = row.getCell(studentIdx).text.trim();
      const studentCodeRaw = row.getCell(studentCodeIdx).text.trim();
      const dayRaw = row.getCell(dayIdx).text.trim();
      const timeRaw = row.getCell(timeIdx).text.trim();
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
          program: current.program,
          classType: current.classType,
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

const computeDurationMinutes = (timeRange) => {
  const startMinutes = timeRange.startHour * 60 + timeRange.startMinute;
  const endMinutes = timeRange.endHour * 60 + timeRange.endMinute;
  const delta = endMinutes - startMinutes;
  return delta > 0 ? delta : delta + 24 * 60;
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

const main = async () => {
  if (!admin.apps.length) {
    admin.initializeApp({projectId: PROJECT_ID});
  }
  const db = admin.firestore();
  const studentOverrides = loadStudentOverrides();
  const teacherOverrides = loadTeacherOverrides();

  const scheduleRows = await loadScheduleRows(resolveScheduleFiles(), studentOverrides);
  const teachersSnap = await db.collection('users').where('user_type', '==', 'teacher').get();
  const teachers = teachersSnap.docs.map((doc) => {
    const data = doc.data() || {};
    return {
      uid: doc.id,
      firstName: data.first_name || '',
      lastName: data.last_name || '',
    };
  });
  const teachersById = new Map(teachers.map((teacher) => [teacher.uid, teacher]));
  const teacherMaps = buildTeacherMaps(teachers);

  const grouped = new Map();
  const unresolved = [];

  for (const row of scheduleRows) {
    const teacher = pickTeacher(row.teacherName, teacherMaps, teacherOverrides, teachersById);
    if (!teacher) {
      unresolved.push(`Missing teacher: ${row.teacherName}`);
      continue;
    }

    const timeRange = parseTimeRange(row.time);
    if (!timeRange) {
      unresolved.push(`Bad time: ${row.teacherName} ${row.day} ${row.time}`);
      continue;
    }

    const weekday = Number.isInteger(row.weekday)
      ? row.weekday
      : DAY_MAP.get(normalizeName(row.day));
    if (!weekday) {
      unresolved.push(`Bad day: ${row.teacherName} ${row.day}`);
      continue;
    }

    const durationFromColumn = parseDurationMinutes(row.duration);
    const timeRangeDuration = computeDurationMinutes(timeRange);
    const expectedDuration =
      PREFER_DURATION_COLUMN && durationFromColumn ? durationFromColumn : timeRangeDuration;

    const key = [teacher.uid, weekday, timeRange.startTime].join('|');
    const existing = grouped.get(key) || {
      teacherId: teacher.uid,
      teacherName: `${teacher.firstName} ${teacher.lastName}`.trim(),
      weekday,
      startTime: timeRange.startTime,
      endTime: timeRange.endTime,
      timeRangeDuration,
      expectedDuration,
      durationColumnValues: new Set(),
      studentCodes: new Set(),
      studentNames: new Set(),
    };

    if (durationFromColumn) {
      existing.durationColumnValues.add(durationFromColumn);
    }
    existing.studentCodes.add(row.studentCode);
    existing.studentNames.add(row.studentName);
    grouped.set(key, existing);
  }

  const templatesSnap = await db.collection('shift_templates').get();
  const updates = [];
  const reportRows = [];
  let unmatchedTemplates = 0;
  let ambiguousTemplates = 0;

  for (const doc of templatesSnap.docs) {
    const data = doc.data() || {};
    const teacherId = data.teacher_id;
    const startTime = data.start_time;
    const selectedWeekdays = data?.enhanced_recurrence?.selectedWeekdays || [];
    const weekday = Array.isArray(selectedWeekdays) && selectedWeekdays.length === 1 ? selectedWeekdays[0] : null;
    if (!teacherId || !startTime || !weekday) {
      continue;
    }

    const key = [teacherId, weekday, startTime].join('|');
    const group = grouped.get(key);
    if (!group) {
      unmatchedTemplates += 1;
      continue;
    }

    const durationColumnValues = Array.from(group.durationColumnValues);
    if (durationColumnValues.length > 1) {
      ambiguousTemplates += 1;
    }

    const expectedDuration = group.expectedDuration;
    const templateDuration = Number(data.duration_minutes || 0);
    const templateEndTime = data.end_time || '';
    const expectedEndTime = group.endTime;

    const durationMismatch = Math.abs(templateDuration - expectedDuration) > 0;
    const endTimeMismatch = templateEndTime !== expectedEndTime;

    if (durationMismatch || endTimeMismatch) {
      reportRows.push({
        template_id: doc.id,
        teacher_name: data.teacher_name || group.teacherName,
        weekday,
        start_time: startTime,
        template_end_time: templateEndTime,
        template_duration: templateDuration,
        expected_end_time: expectedEndTime,
        expected_duration: expectedDuration,
        duration_column_values: durationColumnValues.join('|'),
        time_range_duration: group.timeRangeDuration,
        mismatch: durationMismatch || endTimeMismatch ? 'yes' : 'no',
        student_names: Array.from(group.studentNames).join('|'),
      });

      updates.push({
        ref: doc.ref,
        updates: {
          end_time: expectedEndTime,
          duration_minutes: expectedDuration,
          last_modified: admin.firestore.FieldValue.serverTimestamp(),
        },
        templateId: doc.id,
        template: {...data, end_time: expectedEndTime, duration_minutes: expectedDuration},
      });
    }
  }

  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const reportPath = path.join(OUTPUT_DIR, `prod_template_duration_mismatches_${timestamp}.csv`);
  writeCsv(
    reportPath,
    [
      'template_id',
      'teacher_name',
      'weekday',
      'start_time',
      'template_end_time',
      'template_duration',
      'expected_end_time',
      'expected_duration',
      'duration_column_values',
      'time_range_duration',
      'mismatch',
      'student_names',
    ],
    reportRows,
  );

  console.log(`Templates checked: ${templatesSnap.size}`);
  console.log(`Mismatches found: ${reportRows.length}`);
  console.log(`Report: ${reportPath}`);
  if (unmatchedTemplates > 0) {
    console.log(`Templates without schedule match: ${unmatchedTemplates}`);
  }
  if (ambiguousTemplates > 0) {
    console.log(`Templates with conflicting duration entries: ${ambiguousTemplates}`);
  }
  if (unresolved.length) {
    console.log(`Unresolved schedule rows: ${unresolved.length}`);
  }

  if (!APPLY || updates.length === 0) return;

  console.log(`Applying ${updates.length} template updates...`);
  let batch = db.batch();
  let opCount = 0;
  const flush = async () => {
    if (opCount === 0) return;
    await batch.commit();
    batch = db.batch();
    opCount = 0;
  };

  for (const update of updates) {
    batch.update(update.ref, update.updates);
    opCount += 1;
    if (opCount >= 450) {
      await flush();
    }
  }
  await flush();

  const shiftTemplateHandlers = require('../handlers/shift_templates');
  for (const update of updates) {
    await shiftTemplateHandlers._generateShiftsForTemplate({
      templateId: update.templateId,
      template: update.template,
    });
  }

  console.log('Template durations updated and shifts regenerated.');
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
