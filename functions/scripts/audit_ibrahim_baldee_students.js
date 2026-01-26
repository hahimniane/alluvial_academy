#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const {DateTime} = require('luxon');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'alluwal-academy';
const OUTPUT_DIR = process.env.OUTPUT_DIR || '/tmp';
const DAYS_AHEAD = Number(process.env.DAYS_AHEAD || 90);
const DAYS_BACK = Number(process.env.DAYS_BACK || 1);

const TEACHER_ID = process.env.IBRAHIM_BALDEE_ID || 'zfMLKTXNFQdlPsVomdmYkSdNVqk2';
const TEACHER_NAME = 'Ibrahim Baldee';

const STATUS_SET = new Set(['scheduled', 'active', 'in_progress', 'pending']);
const STATUS_ALIASES = new Map([
  ['inprogress', 'in_progress'],
  ['in-progress', 'in_progress'],
  ['partiallycompleted', 'partiallycompleted'],
  ['fullycompleted', 'fullycompleted'],
]);

const normalizeStatus = (value) => {
  const raw = (value || '').toString().trim().toLowerCase();
  return STATUS_ALIASES.get(raw) || raw;
};

const toIso = (value) => {
  if (!value) return '';
  if (typeof value.toDate === 'function') {
    const dt = value.toDate();
    return dt ? dt.toISOString() : '';
  }
  if (value instanceof Date) return value.toISOString();
  return '';
};

const toMillis = (value) => {
  if (!value) return null;
  if (typeof value.toDate === 'function') {
    const dt = value.toDate();
    return dt ? dt.getTime() : null;
  }
  if (value instanceof Date) return value.getTime();
  return null;
};

const writeCsv = (filePath, headers, rows) => {
  const escapeCell = (value) => {
    if (value === null || value === undefined) return '';
    const raw = String(value);
    if (raw.includes('"')) return `"${raw.replace(/"/g, '""')}"`;
    if (/[,\n]/.test(raw)) return `"${raw}"`;
    return raw;
  };

  const lines = [headers.join(',')];
  rows.forEach((row) => {
    lines.push(headers.map((header) => escapeCell(row[header])).join(','));
  });
  fs.writeFileSync(filePath, `${lines.join('\n')}\n`, 'utf8');
};

const parseTimeToMinutes = (value) => {
  if (!value) return null;
  const [hourRaw, minuteRaw] = value.split(':');
  const hour = Number(hourRaw);
  const minute = Number(minuteRaw ?? '0');
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
  return hour * 60 + minute;
};

const countWeeklyOccurrences = (startDate, endDate, weekday) => {
  if (endDate <= startDate) return 0;
  let count = 0;
  let cursor = startDate.startOf('day');
  while (cursor.weekday !== weekday) {
    cursor = cursor.plus({days: 1});
  }
  while (cursor <= endDate) {
    if (cursor >= startDate.startOf('day')) count += 1;
    cursor = cursor.plus({weeks: 1});
  }
  return count;
};

const rangesOverlap = (aStart, aEnd, bStart, bEnd) => aStart < bEnd && aEnd > bStart;

const main = async () => {
  if (!admin.apps.length) {
    admin.initializeApp({projectId: PROJECT_ID});
  }
  const db = admin.firestore();

  const templatesSnap = await db.collection('shift_templates').where('teacher_id', '==', TEACHER_ID).get();
  const templates = [];
  templatesSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    if (data.active === false) return;
    const studentIds = Array.isArray(data.student_ids) ? data.student_ids : [];
    const studentNames = Array.isArray(data.student_names) ? data.student_names : [];
    const weekdays = Array.isArray(data.enhanced_recurrence?.selectedWeekdays)
      ? data.enhanced_recurrence.selectedWeekdays
      : [];
    templates.push({
      id: doc.id,
      teacher_id: data.teacher_id || '',
      teacher_name: data.teacher_name || '',
      student_ids: studentIds,
      student_names: studentNames,
      weekdays,
      start_time: data.start_time || '',
      end_time: data.end_time || '',
      duration_minutes: Number(data.duration_minutes || 0),
      max_days_ahead: Number(data.max_days_ahead || 0),
      admin_timezone: data.admin_timezone || 'UTC',
      subject_display_name: data.subject_display_name || '',
    });
  });

  if (templates.length === 0) {
    console.log(`No active templates found for ${TEACHER_NAME} (${TEACHER_ID}).`);
    return;
  }

  const studentIds = new Set();
  const studentNamesById = new Map();
  templates.forEach((template) => {
    template.student_ids.forEach((studentId, index) => {
      if (!studentId) return;
      studentIds.add(studentId);
      const name = template.student_names[index] || '';
      if (name && !studentNamesById.has(studentId)) {
        studentNamesById.set(studentId, name);
      }
    });
  });

  const nowUtc = DateTime.utc();
  const rangeStart = nowUtc.minus({days: DAYS_BACK}).toJSDate();
  const rangeEnd = nowUtc.plus({days: DAYS_AHEAD}).toJSDate();

  const shiftsSnap = await db
    .collection('teaching_shifts')
    .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(rangeStart))
    .where('shift_start', '<', admin.firestore.Timestamp.fromDate(rangeEnd))
    .get();

  const shifts = shiftsSnap.docs.map((doc) => {
    const data = doc.data() || {};
    const status = normalizeStatus(data.status);
    const studentIdsList = Array.isArray(data.student_ids) ? data.student_ids.map(String) : [];
    const studentNames = Array.isArray(data.student_names) ? data.student_names.map(String) : [];
    return {
      id: doc.id,
      status,
      shiftStartMs: toMillis(data.shift_start),
      shiftEndMs: toMillis(data.shift_end),
      shift_start: toIso(data.shift_start),
      shift_end: toIso(data.shift_end),
      teacher_id: data.teacher_id || '',
      teacher_name: data.teacher_name || '',
      student_ids: studentIdsList,
      student_names: studentNames,
      template_id: data.template_id || '',
      generated_from_template: data.generated_from_template === true,
    };
  }).filter((shift) => shift.shiftStartMs && shift.shiftEndMs);

  const shiftsByTemplate = new Map();
  shifts.forEach((shift) => {
    if (!shift.template_id) return;
    if (!shiftsByTemplate.has(shift.template_id)) {
      shiftsByTemplate.set(shift.template_id, []);
    }
    shiftsByTemplate.get(shift.template_id).push(shift);
  });

  const templateRows = [];
  templates.forEach((template) => {
    const horizonDays = template.max_days_ahead || DAYS_AHEAD;
    const horizon = DateTime.now().setZone(template.admin_timezone).plus({days: horizonDays});
    const startDate = DateTime.now().setZone(template.admin_timezone);
    const occurrences = template.weekdays.reduce(
      (sum, weekday) => sum + countWeeklyOccurrences(startDate, horizon, weekday),
      0,
    );

    const shiftsForTemplate = (shiftsByTemplate.get(template.id) || []).filter((shift) =>
      STATUS_SET.has(shift.status),
    );

    templateRows.push({
      template_id: template.id,
      student_names: template.student_names.join('|'),
      weekdays: template.weekdays.join('|'),
      start_time: template.start_time,
      duration_minutes: template.duration_minutes || '',
      max_days_ahead: template.max_days_ahead || '',
      expected_occurrences: occurrences,
      actual_shifts: shiftsForTemplate.length,
      missing_shifts: Math.max(0, occurrences - shiftsForTemplate.length),
    });
  });

  const templateIdSet = new Set(templates.map((template) => template.id));
  const groupTemplatesByStudent = new Map();
  templates.forEach((template) => {
    if (template.student_ids.length <= 1) return;
    const startMinutes = parseTimeToMinutes(template.start_time);
    const endMinutes =
      parseTimeToMinutes(template.end_time) ??
      (template.duration_minutes > 0 && startMinutes !== null ? startMinutes + template.duration_minutes : null);
    if (startMinutes === null || endMinutes === null) return;
    template.student_ids.forEach((studentId) => {
      if (!studentId) return;
      if (!groupTemplatesByStudent.has(studentId)) {
        groupTemplatesByStudent.set(studentId, []);
      }
      groupTemplatesByStudent.get(studentId).push({
        template_id: template.id,
        startMinutes,
        endMinutes,
        weekdays: template.weekdays,
      });
    });
  });

  const discrepancyRows = [];
  const summaryByStudent = new Map();

  const studentShifts = shifts.filter((shift) =>
    shift.student_ids.some((studentId) => studentIds.has(studentId)),
  );

  const studentShiftMap = new Map();
  studentShifts.forEach((shift) => {
    shift.student_ids.forEach((studentId, index) => {
      if (!studentIds.has(studentId)) return;
      if (!studentShiftMap.has(studentId)) studentShiftMap.set(studentId, []);
      studentShiftMap.get(studentId).push({
        shift,
        student_name: shift.student_names[index] || studentNamesById.get(studentId) || '',
      });
    });
  });

  for (const [studentId, entries] of studentShiftMap.entries()) {
    const studentName = studentNamesById.get(studentId) || entries[0]?.student_name || '';
    const summary = {
      student_id: studentId,
      student_name: studentName,
      total_shifts: 0,
      ibrahim_shifts: 0,
      other_teacher_shifts: 0,
      overlapping_shifts: 0,
      single_overlaps_group_template: 0,
      unknown_template_shifts: 0,
    };

    const shiftsForStudent = entries.map((entry) => entry.shift);
    summary.total_shifts = shiftsForStudent.length;

    shiftsForStudent.forEach((shift) => {
      if (shift.teacher_id === TEACHER_ID) {
        summary.ibrahim_shifts += 1;
        if (shift.template_id && !templateIdSet.has(shift.template_id)) {
          summary.unknown_template_shifts += 1;
          discrepancyRows.push({
            issue_type: 'unknown_template',
            student_id: studentId,
            student_name: studentName,
            shift_id: shift.id,
            status: shift.status,
            shift_start: shift.shift_start,
            shift_end: shift.shift_end,
            teacher_name: shift.teacher_name,
            template_id: shift.template_id,
          });
        }
      } else {
        summary.other_teacher_shifts += 1;
      }
    });

    const sorted = shiftsForStudent.slice().sort((a, b) => a.shiftStartMs - b.shiftStartMs);
    for (let i = 0; i < sorted.length; i += 1) {
      for (let j = i + 1; j < sorted.length; j += 1) {
        const a = sorted[i];
        const b = sorted[j];
        if (!rangesOverlap(a.shiftStartMs, a.shiftEndMs, b.shiftStartMs, b.shiftEndMs)) continue;
        summary.overlapping_shifts += 1;
        discrepancyRows.push({
          issue_type: 'overlap',
          student_id: studentId,
          student_name: studentName,
          shift_id: a.id,
          status: a.status,
          shift_start: a.shift_start,
          shift_end: a.shift_end,
          teacher_name: a.teacher_name,
          template_id: a.template_id,
        });
        discrepancyRows.push({
          issue_type: 'overlap',
          student_id: studentId,
          student_name: studentName,
          shift_id: b.id,
          status: b.status,
          shift_start: b.shift_start,
          shift_end: b.shift_end,
          teacher_name: b.teacher_name,
          template_id: b.template_id,
        });
      }
    }

    const groupTemplates = groupTemplatesByStudent.get(studentId) || [];
    if (groupTemplates.length > 0) {
      shiftsForStudent.forEach((shift) => {
        if (shift.student_ids.length !== 1) return;
        const shiftStart = DateTime.fromMillis(shift.shiftStartMs, {zone: 'America/New_York'});
        const shiftEnd = DateTime.fromMillis(shift.shiftEndMs, {zone: 'America/New_York'});
        const shiftStartMinutes = shiftStart.hour * 60 + shiftStart.minute;
        const shiftEndMinutes = shiftEnd.hour * 60 + shiftEnd.minute;
        const weekday = shiftStart.weekday;
        const shiftEndAdjusted =
          shiftEndMinutes < shiftStartMinutes ? shiftEndMinutes + 24 * 60 : shiftEndMinutes;

        const overlapsGroup = groupTemplates.some((template) => {
          if (!template.weekdays.includes(weekday)) return false;
          const templateEnd =
            template.endMinutes < template.startMinutes ? template.endMinutes + 24 * 60 : template.endMinutes;
          return rangesOverlap(shiftStartMinutes, shiftEndAdjusted, template.startMinutes, templateEnd);
        });

        if (overlapsGroup) {
          summary.single_overlaps_group_template += 1;
          discrepancyRows.push({
            issue_type: 'single_overlaps_group_template',
            student_id: studentId,
            student_name: studentName,
            shift_id: shift.id,
            status: shift.status,
            shift_start: shift.shift_start,
            shift_end: shift.shift_end,
            teacher_name: shift.teacher_name,
            template_id: shift.template_id,
          });
        }
      });
    }

    summaryByStudent.set(studentId, summary);
  }

  const summaryRows = Array.from(summaryByStudent.values()).sort((a, b) =>
    a.student_name.localeCompare(b.student_name),
  );

  const timestamp = DateTime.now().toFormat('yyyyLLdd_HHmmss');
  const summaryPath = path.join(OUTPUT_DIR, `prod_ibrahim_baldee_students_summary_${timestamp}.csv`);
  const discrepancyPath = path.join(OUTPUT_DIR, `prod_ibrahim_baldee_student_discrepancies_${timestamp}.csv`);
  const templatePath = path.join(OUTPUT_DIR, `prod_ibrahim_baldee_template_generation_${timestamp}.csv`);

  writeCsv(
    summaryPath,
    [
      'student_id',
      'student_name',
      'total_shifts',
      'ibrahim_shifts',
      'other_teacher_shifts',
      'overlapping_shifts',
      'single_overlaps_group_template',
      'unknown_template_shifts',
    ],
    summaryRows,
  );

  writeCsv(
    discrepancyPath,
    [
      'issue_type',
      'student_id',
      'student_name',
      'shift_id',
      'status',
      'shift_start',
      'shift_end',
      'teacher_name',
      'template_id',
    ],
    discrepancyRows,
  );

  writeCsv(
    templatePath,
    [
      'template_id',
      'student_names',
      'weekdays',
      'start_time',
      'duration_minutes',
      'max_days_ahead',
      'expected_occurrences',
      'actual_shifts',
      'missing_shifts',
    ],
    templateRows,
  );

  console.log(`Students in Ibrahim templates: ${studentIds.size}`);
  console.log(`Summary report: ${summaryPath}`);
  console.log(`Discrepancies report: ${discrepancyPath}`);
  console.log(`Template generation report: ${templatePath}`);
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
