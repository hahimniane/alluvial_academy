#!/usr/bin/env node
/**
 * Repair helper for recurring shift series in `teaching_shifts`.
 *
 * Supports:
 *  - Shifting `shift_start`/`shift_end` by N minutes for all (optionally future) shifts in a series.
 *  - Deleting shifts in a series that fall on specific weekdays (in a given IANA timezone).
 *  - (Optional) re-scheduling Cloud Tasks for updated shifts (start/end tasks).
 *
 * Default is DRY-RUN (no writes). To apply, pass: --apply --yes
 *
 * Examples:
 *  # Shift a series by +3 hours and reschedule tasks
 *  node functions/scripts/repair_shift_series_schedule.js \
 *    --project alluwal-academy \
 *    --seriesId <recurrence_series_id> \
 *    --shiftMinutes 180 \
 *    --onlyFuture true \
 *    --scheduleTasks true \
 *    --backup ./series_fix.jsonl \
 *    --apply --yes
 *
 *  # Delete Sunday occurrences (weekday=7) in Asia/Riyadh for future shifts
 *  node functions/scripts/repair_shift_series_schedule.js \
 *    --project alluwal-academy \
 *    --seriesId <recurrence_series_id> \
 *    --deleteWeekdays 7 \
 *    --timezone Asia/Riyadh \
 *    --onlyFuture true \
 *    --backup ./series_delete.jsonl \
 *    --apply --yes
 */

const admin = require('firebase-admin');
const {CloudTasksClient} = require('@google-cloud/tasks');
const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const raw = argv[i];
    if (!raw.startsWith('--')) continue;
    const key = raw.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
      continue;
    }
    args[key] = next;
    i += 1;
  }
  return args;
}

function usage(exitCode = 1) {
  console.log(
    [
      'Usage:',
      '  node functions/scripts/repair_shift_series_schedule.js --project <projectId> --seriesId <id> [--studentUid <uid>] [--teacherUid <uid>] \\',
      '    [--shiftMinutes <int>] [--deleteWeekdays <csv>] [--timezone <IANA>] [--onlyFuture true|false] \\',
      '    [--scheduleTasks true|false] [--tasksOnly true|false] [--cleanupOldTasks true|false] [--backup <path>] [--apply --yes]',
      '',
      'Notes:',
      '  - DRY-RUN by default (no writes).',
      '  - `--deleteWeekdays` uses 1=Mon … 7=Sun in the provided `--timezone` (or each doc admin_timezone).',
      '  - `--scheduleTasks` creates Cloud Tasks start/end tasks like `scheduleShiftLifecycle`.',
      '  - `--tasksOnly` schedules tasks using current Firestore times (no Firestore writes).',
    ].join('\n'),
  );
  process.exit(exitCode);
}

async function initAdmin(projectId) {
  try {
    const serviceAccount = require(path.join(__dirname, '../../serviceAccountKey.json'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId,
    });
  } catch (error) {
    admin.initializeApp({projectId});
  }
}

function boolArg(value, fallback = false) {
  if (value === undefined || value === null) return fallback;
  if (value === true) return true;
  const normalized = String(value).trim().toLowerCase();
  if (['true', '1', 'yes', 'y'].includes(normalized)) return true;
  if (['false', '0', 'no', 'n'].includes(normalized)) return false;
  return fallback;
}

function parseCsvInts(value) {
  if (!value) return [];
  return String(value)
    .split(',')
    .map((v) => v.trim())
    .filter(Boolean)
    .map((v) => Number(v))
    .filter((n) => Number.isFinite(n));
}

function getTimestampDate(value) {
  if (!value) return null;
  if (value.toDate && typeof value.toDate === 'function') return value.toDate();
  return null;
}

function getWeekdayNumberInTimezone(date, timezoneId) {
  // Use a stable English locale so weekday tokens are predictable.
  const day = new Intl.DateTimeFormat('en-US', {
    timeZone: timezoneId,
    weekday: 'short',
  }).format(date);
  switch (day) {
    case 'Mon':
      return 1;
    case 'Tue':
      return 2;
    case 'Wed':
      return 3;
    case 'Thu':
      return 4;
    case 'Fri':
      return 5;
    case 'Sat':
      return 6;
    case 'Sun':
      return 7;
    default:
      return null;
  }
}

function overlaps(aStart, aEnd, bStart, bEnd) {
  return aStart < bEnd && aEnd > bStart;
}

function ensureFutureDate(date) {
  if (date.getTime() <= Date.now()) {
    return new Date(Date.now() + 2000);
  }
  return date;
}

function taskPath(client, projectId, location, queue, shiftId, phase, suffix) {
  const base = `shift-${shiftId}-${phase}`;
  const safeSuffix = suffix != null ? String(suffix).trim().replace(/[^a-zA-Z0-9-_]/g, '_') : null;
  const taskId = safeSuffix ? `${base}-${safeSuffix}` : base;
  return client.taskPath(projectId, location, queue, taskId);
}

function buildHttpTask({url, serviceAccountEmail, payload, scheduleAt, name}) {
  return {
    httpRequest: {
      httpMethod: 'POST',
      url,
      oidcToken: {
        serviceAccountEmail,
      },
      headers: {'Content-Type': 'application/json'},
      body: Buffer.from(JSON.stringify(payload)).toString('base64'),
    },
    scheduleTime: {
      seconds: Math.floor(scheduleAt.getTime() / 1000),
    },
    name,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const projectId = (args.project || 'alluwal-academy').toString();
  const seriesId = (args.seriesId || '').toString().trim();
  const studentUid = (args.studentUid || '').toString().trim();
  const teacherUid = (args.teacherUid || '').toString().trim();
  const shiftMinutes = args.shiftMinutes ? Number(args.shiftMinutes) : 0;
  const deleteWeekdays = parseCsvInts(args.deleteWeekdays);
  const timezoneOverride = args.timezone ? args.timezone.toString().trim() : '';
  const onlyFuture = boolArg(args.onlyFuture, true);
  const apply = boolArg(args.apply, false);
  const yes = boolArg(args.yes, false);
  const backupPath = args.backup ? args.backup.toString().trim() : '';

  const tasksOnly = boolArg(args.tasksOnly, false);
  const scheduleTasks = boolArg(args.scheduleTasks, tasksOnly);
  const cleanupOldTasks = boolArg(args.cleanupOldTasks, true);
  const tasksLocation = (args.tasksLocation || 'northamerica-northeast1').toString().trim();
  const tasksQueue = (args.tasksQueue || 'shift-lifecycle-queue').toString().trim();
  const functionRegion = (args.functionRegion || 'us-central1').toString().trim();
  const tasksServiceAccountEmail = (args.tasksServiceAccount ||
    '554077757249-compute@developer.gserviceaccount.com').toString().trim();

  if (!seriesId) usage(1);
  if (apply && !yes) {
    console.log('Refusing to apply without --yes.');
    process.exit(1);
  }
  if (!tasksOnly && !deleteWeekdays.length && (!Number.isFinite(shiftMinutes) || shiftMinutes === 0)) {
    console.log('Nothing to do: provide --shiftMinutes or --deleteWeekdays.');
    process.exit(1);
  }

  await initAdmin(projectId);
  const db = admin.firestore();
  const now = new Date();

  console.log(
    `Project=${projectId} | seriesId=${seriesId} | mode=${apply ? 'APPLY' : 'DRY-RUN'} | onlyFuture=${onlyFuture}`,
  );

  const snap = await db
    .collection('teaching_shifts')
    .where('recurrence_series_id', '==', seriesId)
    .get();

  console.log(`Fetched ${snap.size} shift(s) in series.`);

  const operations = [];
  const updatesById = new Map();
  const taskTargets = [];

  for (const doc of snap.docs) {
    const data = doc.data() || {};

    if (teacherUid) {
      const docTeacherId = String(data.teacher_id || '').trim();
      if (docTeacherId !== teacherUid) continue;
    }

    if (studentUid) {
      const ids = Array.isArray(data.student_ids) ? data.student_ids.map(String) : [];
      if (!ids.includes(studentUid)) continue;
    }

    const start = getTimestampDate(data.shift_start);
    const end = getTimestampDate(data.shift_end);
    if (!start || !end) continue;

    if (onlyFuture && start < now) continue;

    const tzId = timezoneOverride || String(data.admin_timezone || 'UTC').trim() || 'UTC';
    const weekday = deleteWeekdays.length ? getWeekdayNumberInTimezone(start, tzId) : null;

    if (deleteWeekdays.length && weekday != null && deleteWeekdays.includes(weekday)) {
      operations.push({
        action: 'delete',
        ref: doc.ref,
        id: doc.id,
        teacherId: String(data.teacher_id || '').trim(),
        start,
        end,
        tzId,
        weekday,
      });
      continue;
    }

    if (tasksOnly) {
      taskTargets.push({
        id: doc.id,
        start,
        end,
      });
      continue;
    }

    if (Number.isFinite(shiftMinutes) && shiftMinutes !== 0) {
      const newStart = new Date(start.getTime() + shiftMinutes * 60 * 1000);
      const newEnd = new Date(end.getTime() + shiftMinutes * 60 * 1000);
      if (newEnd <= newStart) {
        console.log(`Skipping ${doc.id}: invalid shifted duration.`);
        continue;
      }
      operations.push({
        action: 'update',
        ref: doc.ref,
        id: doc.id,
        teacherId: String(data.teacher_id || '').trim(),
        start,
        end,
        newStart,
        newEnd,
        tzId,
      });
      updatesById.set(doc.id, {newStart, newEnd});
    }
  }

  const updateOps = operations.filter((o) => o.action === 'update');
  const deleteOps = operations.filter((o) => o.action === 'delete');

  console.log(`Planned: ${updateOps.length} update(s), ${deleteOps.length} delete(s).`);

  if (operations.length === 0 && !tasksOnly) {
    console.log('No matching shifts to modify.');
    return;
  }

  if (tasksOnly) {
    console.log(`Planned: ${taskTargets.length} task re-schedule target(s).`);
    if (taskTargets.length === 0) {
      console.log('No matching shifts to schedule tasks for.');
      return;
    }
  }

  // Conflict check (teacher schedule) for time-shifts.
  if (updateOps.length > 0) {
    const teacherIds = Array.from(new Set(updateOps.map((o) => o.teacherId).filter(Boolean)));
    for (const tId of teacherIds) {
      const teacherSnap = await db.collection('teaching_shifts').where('teacher_id', '==', tId).get();
      const teacherShifts = teacherSnap.docs.map((d) => {
        const v = d.data() || {};
        const s = getTimestampDate(v.shift_start);
        const e = getTimestampDate(v.shift_end);
        return s && e ? {id: d.id, start: s, end: e} : null;
      }).filter(Boolean);

      const conflicts = [];
      for (const op of updateOps.filter((o) => o.teacherId === tId)) {
        for (const other of teacherShifts) {
          if (other.id === op.id) continue;
          const otherTimes = updatesById.get(other.id);
          const otherStart = otherTimes ? otherTimes.newStart : other.start;
          const otherEnd = otherTimes ? otherTimes.newEnd : other.end;
          if (overlaps(op.newStart, op.newEnd, otherStart, otherEnd)) {
            conflicts.push({
              shiftId: op.id,
              conflictsWith: other.id,
              newStart: op.newStart.toISOString(),
              newEnd: op.newEnd.toISOString(),
              otherStart: otherStart.toISOString(),
              otherEnd: otherEnd.toISOString(),
            });
            break;
          }
        }
      }

      if (conflicts.length > 0) {
        console.log(`Conflict check failed for teacher ${tId}: ${conflicts.length} conflict(s).`);
        console.log(JSON.stringify(conflicts.slice(0, 5), null, 2));
        process.exit(1);
      }
    }
  }

  // Write backup JSONL report.
  if (backupPath) {
    const source = tasksOnly
      ? taskTargets.map((t) => ({
          id: t.id,
          action: 'tasksOnly',
          start: t.start,
          end: t.end,
        }))
      : operations;
    const lines = source.map((op) => {
      const base = {
        id: op.id,
        action: op.action,
        teacherId: op.teacherId,
        tzId: op.tzId,
      };
      if (op.action === 'tasksOnly') {
        return JSON.stringify({
          ...base,
          before: {shift_start: op.start.toISOString(), shift_end: op.end.toISOString()},
        });
      }
      if (op.action === 'delete') {
        return JSON.stringify({
          ...base,
          before: {shift_start: op.start.toISOString(), shift_end: op.end.toISOString()},
        });
      }
      return JSON.stringify({
        ...base,
        before: {shift_start: op.start.toISOString(), shift_end: op.end.toISOString()},
        after: {shift_start: op.newStart.toISOString(), shift_end: op.newEnd.toISOString()},
      });
    });
    fs.writeFileSync(backupPath, lines.join('\n') + '\n', 'utf8');
    console.log(`Backup written: ${backupPath}`);
  }

  if (!apply) {
    // Print a small preview.
    const preview = (tasksOnly ? taskTargets : operations).slice(0, 8).map((op) => {
      if (tasksOnly) {
        return `TASKS ${op.id} start=${op.start.toISOString()}`;
      }
      if (op.action === 'delete') {
        return `DELETE ${op.id} start=${op.start.toISOString()} (weekday=${op.weekday ?? '?'}, tz=${op.tzId})`;
      }
      return `UPDATE ${op.id} ${op.start.toISOString()} -> ${op.newStart.toISOString()}`;
    });
    console.log(preview.join('\n'));
    return;
  }

  if (!tasksOnly) {
    // Apply Firestore writes.
    const batch = db.batch();
    for (const op of operations) {
      if (op.action === 'delete') {
        batch.delete(op.ref);
      } else {
        batch.update(op.ref, {
          shift_start: admin.firestore.Timestamp.fromDate(op.newStart),
          shift_end: admin.firestore.Timestamp.fromDate(op.newEnd),
          last_modified: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
    console.log('Firestore updates committed.');
  }

  const tasksSource = tasksOnly
    ? taskTargets.map((t) => ({id: t.id, start: t.start, end: t.end, newStart: t.start, newEnd: t.end}))
    : updateOps;

  if (scheduleTasks && tasksSource.length > 0) {
    const tasksClient = new CloudTasksClient();
    const queuePath = tasksClient.queuePath(projectId, tasksLocation, tasksQueue);
    const startUrl = `https://${functionRegion}-${projectId}.cloudfunctions.net/handleShiftStartTask`;
    const endUrl = `https://${functionRegion}-${projectId}.cloudfunctions.net/handleShiftEndTask`;
    const maxFutureMs = 720 * 60 * 60 * 1000; // 30 days
    const maxScheduleTimeMs = Date.now() + maxFutureMs;

    let created = 0;
    let skippedExists = 0;
    let skippedTooFar = 0;
    let deletedOld = 0;

    const cleanupOldTasksEffective = tasksOnly ? false : cleanupOldTasks;
    const sortedTargets = tasksSource
      .slice()
      .sort((a, b) => a.newStart.getTime() - b.newStart.getTime());

    for (const op of sortedTargets) {
      const scheduledStart = ensureFutureDate(op.newStart);
      const scheduledEnd = ensureFutureDate(op.newEnd);

      if (scheduledStart.getTime() > maxScheduleTimeMs || scheduledEnd.getTime() > maxScheduleTimeMs) {
        skippedTooFar += 1;
        continue;
      }

      const oldStartEpoch = Math.floor(op.start.getTime() / 1000);
      const oldEndEpoch = Math.floor(op.end.getTime() / 1000);
      const newStartEpoch = Math.floor(scheduledStart.getTime() / 1000);
      const newEndEpoch = Math.floor(scheduledEnd.getTime() / 1000);

      const oldStartTaskName = taskPath(tasksClient, projectId, tasksLocation, tasksQueue, op.id, 'start', oldStartEpoch);
      const oldEndTaskName = taskPath(tasksClient, projectId, tasksLocation, tasksQueue, op.id, 'end', oldEndEpoch);
      const newStartTaskName = taskPath(tasksClient, projectId, tasksLocation, tasksQueue, op.id, 'start', newStartEpoch);
      const newEndTaskName = taskPath(tasksClient, projectId, tasksLocation, tasksQueue, op.id, 'end', newEndEpoch);

      if (cleanupOldTasksEffective) {
        try {
          await tasksClient.deleteTask({name: oldStartTaskName});
          deletedOld += 1;
        } catch (e) {
          if (e.code !== 5) throw e;
        }
        try {
          await tasksClient.deleteTask({name: oldEndTaskName});
          deletedOld += 1;
        } catch (e) {
          if (e.code !== 5) throw e;
        }
      }

      const payload = {
        shiftId: op.id,
        shiftStart: op.newStart.toISOString(),
        shiftEnd: op.newEnd.toISOString(),
      };

      const startTask = buildHttpTask({
        url: startUrl,
        serviceAccountEmail: tasksServiceAccountEmail,
        payload,
        scheduleAt: scheduledStart,
        name: newStartTaskName,
      });

      const endTask = buildHttpTask({
        url: endUrl,
        serviceAccountEmail: tasksServiceAccountEmail,
        payload,
        scheduleAt: scheduledEnd,
        name: newEndTaskName,
      });

      try {
        await tasksClient.createTask({parent: queuePath, task: startTask});
        created += 1;
      } catch (e) {
        if (e.code === 6) skippedExists += 1;
        else throw e;
      }

      try {
        await tasksClient.createTask({parent: queuePath, task: endTask});
        created += 1;
      } catch (e) {
        if (e.code === 6) skippedExists += 1;
        else throw e;
      }
    }

    console.log(
      `Cloud Tasks: created=${created}, alreadyExists=${skippedExists}, skippedTooFar=${skippedTooFar}, deletedOld=${deletedOld} (queue=${queuePath})`,
    );
  }
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
