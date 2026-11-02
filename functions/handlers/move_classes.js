/**
 * Move classes earlier or later by a fixed amount — for a teacher, a student,
 * or one teacher's classes with one student. Built for daylight-saving
 * changes: a family or teacher whose clock did not change asks for their
 * classes to move back by an hour.
 *
 * One callable, four actions:
 *   preview — what would move, and what it would land on top of
 *   apply   — move it (weekly schedules and the single classes)
 *   list    — recent moves, newest first
 *   undo    — move a recorded change back
 *
 * Runs on the server on purpose: classes of a weekly schedule are rebuilt at
 * the new time, and a class removed by a person (not by the server) is read
 * as "skip this date", which would cancel it for good.
 */
const admin = require('firebase-admin');
const functions = require('firebase-functions');
const {DateTime} = require('luxon');
const templates = require('./shift_templates');
const move = require('../utils/class_time_move');

const MOVES = 'class_time_moves';
const SHIFTS = 'teaching_shifts';
const TEMPLATES = 'shift_templates';
const ALLOWED_MINUTES = new Set([-120, -90, -60, -30, 30, 60, 90, 120]);
const MAX_STUDENT_CHECKS = 40;

const fail = (code, message) => new functions.https.HttpsError(code, message);
const ts = (date) => admin.firestore.Timestamp.fromDate(date);
const status = (s) => String(s.status || '').trim().toLowerCase();
const isModified = (s) => Boolean(s.admin_modified || s.admin_modified_at || s.teacher_modified || s.teacher_modified_at);
const titleOf = (s) => s.custom_name || s.auto_generated_name || `${s.teacher_name || 'Class'}`;
/** Short name for a class in a message: its students, else its title. */
const whoseClass = (s) => ((s.student_names || s.studentNames || []).filter(Boolean).join(', ') || titleOf(s));
const zoneOf = (doc) => templates.__test._normalizeTimezone(doc.admin_timezone || 'America/New_York');
const when = (date, zone) => DateTime.fromJSDate(date, {zone}).toFormat('ccc d LLL, h:mm a ZZZZ');
const isLive = (s) => !['cancelled', 'deleted'].includes(status(s));

const chunk = (list, size) => {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
};

const readMinutes = (value) => {
  const minutes = Number(value);
  if (!ALLOWED_MINUTES.has(minutes)) throw fail('invalid-argument', 'Pick 30 minutes, 1 hour, 90 minutes or 2 hours, earlier or later.');
  return minutes;
};

// --- loading ---------------------------------------------------------------

/** Active weekly schedules + single classes for the chosen teacher/student. */
const loadScope = async (db, {teacherId, studentId, nowMs}) => {
  const tq = teacherId
    ? db.collection(TEMPLATES).where('teacher_id', '==', teacherId)
    : db.collection(TEMPLATES).where('student_ids', 'array-contains', studentId);
  const templateDocs = (await tq.get()).docs.filter((d) => {
    const t = d.data() || {};
    if (t.is_active === false) return false;
    if (teacherId && studentId && !(t.student_ids || []).includes(studentId)) return false;
    const end = move.toDate((t.enhanced_recurrence || {}).endDate || t.recurrence_end_date);
    return !(end && end.getTime() < nowMs);
  });

  const sq = teacherId
    ? db.collection(SHIFTS).where('teacher_id', '==', teacherId).where('shift_start', '>', ts(new Date(nowMs)))
    : db.collection(SHIFTS).where('student_ids', 'array-contains', studentId).where('shift_start', '>', ts(new Date(nowMs)));
  const inScope = new Set(templateDocs.map((d) => d.id));
  const oneOffDocs = (await sq.get()).docs.filter((d) => {
    const s = d.data() || {};
    if (status(s) !== 'scheduled') return false;
    if (teacherId && studentId && !(s.student_ids || []).includes(studentId)) return false;
    // Classes of a schedule that moves are rebuilt with it.
    return !(s.generated_from_template === true && inScope.has(String(s.template_id || '')));
  });
  return {templateDocs, oneOffDocs};
};

/** Every class of these schedules from a day ago on (so today's are known too). */
const loadTemplateShifts = async (db, templateIds, nowMs) => {
  const byTemplate = new Map();
  await Promise.all(templateIds.map(async (id) => {
    const snap = await db.collection(SHIFTS)
      .where('template_id', '==', id)
      .where('shift_start', '>=', ts(new Date(nowMs - 24 * 3600 * 1000)))
      .get();
    byTemplate.set(id, snap.docs);
  }));
  return byTemplate;
};

const loadFutureFor = async (db, field, id, nowMs) => {
  const q = field === 'teacher'
    ? db.collection(SHIFTS).where('teacher_id', '==', id)
    : db.collection(SHIFTS).where('student_ids', 'array-contains', id);
  const snap = await q.where('shift_start', '>=', ts(new Date(nowMs - 4 * 3600 * 1000))).get();
  return snap.docs;
};

// --- planning --------------------------------------------------------------

/**
 * What moves and what it would collide with. `pick` limits the move to some
 * of the schedules / single classes in scope (null = all of them).
 */
const buildPlan = async (db, {templateDocs, oneOffDocs, minutes, nowMs, pick}) => {
  const delta = minutes * 60000;
  const pickedT = pick && Array.isArray(pick.templateIds) ? new Set(pick.templateIds) : null;
  const pickedS = pick && Array.isArray(pick.shiftIds) ? new Set(pick.shiftIds) : null;
  const shiftsByTemplate = await loadTemplateShifts(db, templateDocs.map((d) => d.id), nowMs);

  const moving = []; // every class that changes time
  const schedules = [];
  for (const doc of templateDocs) {
    const t = doc.data() || {};
    const zone = zoneOf(t);
    let planned;
    try {
      planned = move.movedTemplatePatch(t, minutes, zone);
    } catch (e) {
      continue; // a schedule with no start time cannot be moved; it is simply not listed
    }
    const selected = !pickedT || pickedT.has(doc.id);
    const upcoming = [];
    let tooSoon = 0;
    for (const sd of shiftsByTemplate.get(doc.id) || []) {
      const s = sd.data() || {};
      const start = move.toDate(s.shift_start);
      const end = move.toDate(s.shift_end);
      if (status(s) !== 'scheduled' || !start || !end || start.getTime() <= nowMs) continue;
      if (start.getTime() + delta <= nowMs) {
        tooSoon += 1;
        continue;
      }
      upcoming.push({
        id: sd.id, templateId: doc.id, kind: isModified(s) ? 'inPlace' : 'rebuild',
        teacherId: s.teacher_id, teacherName: s.teacher_name || t.teacher_name || '',
        studentIds: s.student_ids || [], studentNames: s.student_names || [],
        title: titleOf(s), zone, start, end,
        newStart: new Date(start.getTime() + delta), newEnd: new Date(end.getTime() + delta),
      });
    }
    if (selected) moving.push(...upcoming);
    schedules.push({
      id: doc.id,
      selected,
      teacherName: t.teacher_name || '',
      studentNames: t.student_names || [],
      title: titleOf(t),
      zone,
      before: move.describeSchedule(t),
      after: move.describeSchedule({...t, ...planned.patch}),
      dayChanges: planned.dayShift !== 0,
      upcoming: upcoming.length,
      tooSoon,
      next: upcoming.length ? when(upcoming[0].newStart, zone) : null,
      patch: planned.patch,
    });
  }

  // The first class of a weekly schedule is saved under the schedule's own id
  // and is not marked as generated; it belongs with its schedule, not in the
  // single classes.
  const scheduleById = new Map(schedules.map((x) => [x.id, x]));
  const singles = [];
  for (const sd of oneOffDocs) {
    const s = sd.data() || {};
    const start = move.toDate(s.shift_start);
    const end = move.toDate(s.shift_end);
    if (!start || !end) continue;
    const zone = zoneOf(s);
    const newStart = new Date(start.getTime() + delta);
    const tooSoon = newStart.getTime() <= nowMs;
    const schedule = scheduleById.get(sd.id) || null;
    const chosen = schedule ? schedule.selected : !pickedS || pickedS.has(sd.id);
    const selected = !tooSoon && chosen;
    const item = {
      id: sd.id, templateId: null, kind: 'inPlace',
      teacherId: s.teacher_id, teacherName: s.teacher_name || '',
      studentIds: s.student_ids || [], studentNames: s.student_names || [],
      title: titleOf(s), zone, start, end, newStart, newEnd: new Date(end.getTime() + delta),
    };
    if (selected) moving.push(item);
    if (schedule) {
      if (tooSoon) schedule.tooSoon += 1;
      else schedule.upcoming += 1;
      continue;
    }
    singles.push({
      id: sd.id, selected, tooSoon, teacherName: item.teacherName, studentNames: item.studentNames,
      title: item.title, before: when(start, zone), after: when(newStart, zone), at: start.getTime(),
    });
  }
  singles.sort((a, b) => a.at - b.at);
  for (const x of singles) delete x.at;

  // Collisions: a moved class on top of one that is not moving. For the
  // teacher it blocks the move (the rebuilt class would silently not be
  // made); for a student it is a warning.
  const movingIds = new Set(moving.map((m) => m.id));
  const teacherConflicts = [];
  const studentOverlaps = [];
  const teacherIds = [...new Set(moving.map((m) => m.teacherId).filter(Boolean))];
  for (const teacherId of teacherIds) {
    const others = (await loadFutureFor(db, 'teacher', teacherId, nowMs))
      .filter((d) => !movingIds.has(d.id) && isLive(d.data() || {}))
      .map((d) => ({id: d.id, data: d.data(), start: move.toDate(d.data().shift_start), end: move.toDate(d.data().shift_end)}))
      .filter((o) => o.start && o.end);
    const mine = moving.filter((m) => m.teacherId === teacherId).map((m) => ({...m, start: m.newStart, end: m.newEnd}));
    for (const {moved, other} of move.findOverlaps(mine, others)) {
      teacherConflicts.push({
        who: moved.teacherName,
        moved: `${whoseClass(moved)} at ${when(moved.newStart, moved.zone)}`,
        other: `${whoseClass(other.data)} (${when(other.start, moved.zone)})`,
      });
    }
  }
  const studentIds = [...new Set(moving.flatMap((m) => m.studentIds))].slice(0, MAX_STUDENT_CHECKS);
  for (const studentId of studentIds) {
    const others = (await loadFutureFor(db, 'student', studentId, nowMs))
      .filter((d) => !movingIds.has(d.id) && isLive(d.data() || {}))
      .map((d) => ({id: d.id, data: d.data(), start: move.toDate(d.data().shift_start), end: move.toDate(d.data().shift_end)}))
      .filter((o) => o.start && o.end);
    const mine = moving.filter((m) => m.studentIds.includes(studentId)).map((m) => ({...m, start: m.newStart, end: m.newEnd}));
    for (const {moved, other} of move.findOverlaps(mine, others)) {
      const name = moved.studentNames[moved.studentIds.indexOf(studentId)] || 'A student';
      studentOverlaps.push({
        who: name,
        moved: `${moved.teacherName || 'class'} at ${when(moved.newStart, moved.zone)}`,
        other: `${(other.data.teacher_name || titleOf(other.data))} (${when(other.start, moved.zone)})`,
      });
    }
  }

  return {minutes, schedules, singles, moving, teacherConflicts, studentOverlaps, shiftsByTemplate};
};

/** The plan as the dialog shows it (no internal fields). */
const publicPlan = (plan) => ({
  minutes: plan.minutes,
  schedules: plan.schedules.map(({patch, ...rest}) => rest),
  singles: plan.singles,
  movingCount: plan.moving.length,
  teacherConflicts: plan.teacherConflicts.slice(0, 30),
  studentOverlaps: plan.studentOverlaps.slice(0, 30),
});

// --- applying --------------------------------------------------------------

const writeTemplatePatch = (patch) => {
  const out = {start_time: patch.start_time, enhanced_recurrence: {...patch.enhanced_recurrence}};
  if (patch.end_time) out.end_time = patch.end_time;
  if (patch.base_shift_start) out.base_shift_start = ts(patch.base_shift_start);
  if (patch.base_shift_end) out.base_shift_end = ts(patch.base_shift_end);
  if (Array.isArray(out.enhanced_recurrence.excludedDates)) {
    out.enhanced_recurrence.excludedDates = out.enhanced_recurrence.excludedDates.map((d) => (d instanceof Date ? ts(d) : d));
  }
  return out;
};

const applyPlan = async (db, {plan, minutes, actor, moveRef, nowMs}) => {
  if (plan.teacherConflicts.length) {
    const first = plan.teacherConflicts[0];
    throw fail('failed-precondition',
      `${first.who} would have two classes at once: ${first.moved} overlaps ${first.other}. ` +
      'Move that class too, or untick the one that collides.');
  }
  const selectedSchedules = plan.schedules.filter((s) => s.selected);
  const moveInfo = {move_id: moveRef.id, minutes, by: actor.uid, by_name: actor.name, at: admin.firestore.FieldValue.serverTimestamp()};

  // 1. Schedules get their new times.
  for (const s of selectedSchedules) {
    await db.collection(TEMPLATES).doc(s.id).update({
      ...writeTemplatePatch(s.patch),
      last_time_move: moveInfo,
      last_modified: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // 2. Their upcoming classes are cleared (server-side, so no date is skipped)
  //    and every single or hand-edited class moves in place.
  const rebuild = plan.moving.filter((m) => m.kind === 'rebuild');
  const inPlace = plan.moving.filter((m) => m.kind === 'inPlace');
  for (const part of chunk(rebuild, 400)) {
    const batch = db.batch();
    for (const m of part) batch.delete(db.collection(SHIFTS).doc(m.id));
    await batch.commit();
  }
  for (const part of chunk(inPlace, 400)) {
    const batch = db.batch();
    for (const m of part) {
      batch.update(db.collection(SHIFTS).doc(m.id), {
        shift_start: ts(m.newStart),
        shift_end: ts(m.newEnd),
        admin_modified: true,
        admin_modified_at: admin.firestore.FieldValue.serverTimestamp(),
        last_modified: admin.firestore.FieldValue.serverTimestamp(),
        time_moved: moveInfo,
      });
    }
    await batch.commit();
  }

  // 3. Rebuild each schedule's classes at the new time.
  let created = 0;
  let skippedConflicts = 0;
  let removedPast = 0;
  for (const s of selectedSchedules) {
    const ref = db.collection(TEMPLATES).doc(s.id);
    const fresh = (await ref.get()).data();
    const result = await templates._generateShiftsForTemplate({templateId: s.id, template: fresh});
    created += result.created || 0;
    skippedConflicts += result.skippedConflicts || 0;

    // The generator starts at today's date; a class moved earlier into a time
    // that already passed today would be made (and then marked missed).
    const before = new Set((plan.shiftsByTemplate.get(s.id) || []).map((d) => d.id));
    const today = await db.collection(SHIFTS)
      .where('template_id', '==', s.id)
      .where('shift_start', '>=', ts(new Date(nowMs - 24 * 3600 * 1000)))
      .where('shift_start', '<=', ts(new Date(Date.now())))
      .get();
    for (const d of today.docs) {
      if (before.has(d.id) || status(d.data() || {}) !== 'scheduled') continue;
      await d.ref.delete();
      removedPast += 1;
    }
  }

  const oneOffIds = inPlace.filter((m) => !m.templateId).map((m) => m.id);
  return {
    schedules: selectedSchedules.length,
    classesRebuilt: created,
    classesMovedInPlace: inPlace.length,
    oneOffIds,
    skippedConflicts,
    removedPast,
  };
};

// --- callable --------------------------------------------------------------

const describeActor = async (db, uid) => {
  const snap = await db.collection('users').doc(uid).get();
  const u = snap.exists ? snap.data() : {};
  const name = [u.first_name || u.firstName, u.last_name || u.lastName].filter(Boolean).join(' ') || u.email || uid;
  return {uid, name};
};

const scopeLabel = (plan, {teacherId, studentId}) => {
  const first = plan.moving[0] || {};
  const teacher = teacherId ? (first.teacherName || plan.schedules[0]?.teacherName || 'Teacher') : null;
  let student = null;
  if (studentId) {
    const withStudent = plan.moving.find((m) => m.studentIds.includes(studentId));
    student = withStudent ? withStudent.studentNames[withStudent.studentIds.indexOf(studentId)] : 'Student';
  }
  if (teacher && student) return `${teacher} with ${student}`;
  return teacher || `${student} (every teacher)`;
};

const moveClassTimes = async (request) => {
  if (!request.auth) throw fail('unauthenticated', 'Sign in first.');
  if (!(await templates._isAdminUid(request.auth.uid))) throw fail('permission-denied', 'Only admins can move classes.');
  const db = admin.firestore();
  const data = request.data || {};
  const action = String(data.action || 'preview');
  const nowMs = Date.now();

  if (action === 'list') {
    const snap = await db.collection(MOVES).orderBy('created_at', 'desc').limit(10).get();
    return {
      moves: snap.docs.map((d) => {
        const m = d.data() || {};
        return {
          id: d.id,
          label: m.label || '',
          minutes: m.minutes,
          byName: m.by_name || '',
          at: m.created_at && m.created_at.toDate ? m.created_at.toDate().toISOString() : null,
          schedules: (m.template_ids || []).length,
          singles: (m.one_off_ids || []).length,
          undoneAt: m.undone_at && m.undone_at.toDate ? m.undone_at.toDate().toISOString() : null,
        };
      }),
    };
  }

  if (action === 'undo') {
    const moveId = String(data.move_id || '').trim();
    if (!moveId) throw fail('invalid-argument', 'Which move should be undone?');
    const recordRef = db.collection(MOVES).doc(moveId);
    const record = await recordRef.get();
    if (!record.exists) throw fail('not-found', 'That move is not on record.');
    const r = record.data() || {};
    if (r.undone_at) throw fail('failed-precondition', 'That move was already undone.');
    const minutes = -Number(r.minutes);
    const templateDocs = (await Promise.all((r.template_ids || []).map((id) => db.collection(TEMPLATES).doc(id).get())))
      .filter((d) => d.exists && (d.data() || {}).is_active !== false);
    const oneOffDocs = (await Promise.all((r.one_off_ids || []).map((id) => db.collection(SHIFTS).doc(id).get())))
      .filter((d) => d.exists && status(d.data() || {}) === 'scheduled' && move.toDate(d.data().shift_start)?.getTime() > nowMs);
    const plan = await buildPlan(db, {templateDocs, oneOffDocs, minutes, nowMs, pick: null});
    const actor = await describeActor(db, request.auth.uid);
    const undoRef = db.collection(MOVES).doc();
    const result = await applyPlan(db, {plan, minutes, actor, moveRef: undoRef, nowMs});
    await recordRef.update({
      undone_at: admin.firestore.FieldValue.serverTimestamp(),
      undone_by: actor.uid,
      undone_by_name: actor.name,
      undo_result: {schedules: result.schedules, classesRebuilt: result.classesRebuilt, classesMovedInPlace: result.classesMovedInPlace},
    });
    return {undone: true, ...result};
  }

  const teacherId = String(data.teacher_id || '').trim() || null;
  const studentId = String(data.student_id || '').trim() || null;
  if (!teacherId && !studentId) throw fail('invalid-argument', 'Pick a teacher, a student, or both.');
  const minutes = readMinutes(data.minutes);
  const pick = data.template_ids || data.shift_ids
    ? {templateIds: data.template_ids || [], shiftIds: data.shift_ids || []}
    : null;

  const {templateDocs, oneOffDocs} = await loadScope(db, {teacherId, studentId, nowMs});
  const plan = await buildPlan(db, {templateDocs, oneOffDocs, minutes, nowMs, pick});
  if (action === 'preview') return publicPlan(plan);
  if (action !== 'apply') throw fail('invalid-argument', `Unknown action "${action}".`);
  if (!plan.moving.length && !plan.schedules.some((s) => s.selected)) throw fail('failed-precondition', 'Nothing is selected to move.');

  const actor = await describeActor(db, request.auth.uid);
  const moveRef = db.collection(MOVES).doc();
  const result = await applyPlan(db, {plan, minutes, actor, moveRef, nowMs});
  const label = scopeLabel(plan, {teacherId, studentId});
  await moveRef.set({
    label,
    minutes,
    teacher_id: teacherId,
    student_id: studentId,
    template_ids: plan.schedules.filter((s) => s.selected).map((s) => s.id),
    one_off_ids: result.oneOffIds,
    result: {schedules: result.schedules, classesRebuilt: result.classesRebuilt, classesMovedInPlace: result.classesMovedInPlace, skippedConflicts: result.skippedConflicts},
    by: actor.uid,
    by_name: actor.name,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log(`[move_classes] ${actor.name} moved ${label} by ${minutes} min: ${JSON.stringify(result)}`);
  return {moveId: moveRef.id, label, ...result};
};

module.exports = {moveClassTimes, __test: {buildPlan, loadScope, applyPlan, publicPlan, readMinutes}};
