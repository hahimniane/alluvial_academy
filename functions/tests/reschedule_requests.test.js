/**
 * reviewRescheduleRequest approves or declines a teacher's makeup request.
 *
 * Expected behavior:
 * - Admin-only; a refused caller writes nothing.
 * - Approval copies teacher, students, subject, rate, provider and timezones
 *   from the ORIGINAL shift, never from the teacher-written request; only the
 *   start comes from the request (or the admin's custom time), and the length
 *   is the original class's.
 * - Approving twice returns the first makeup and creates no second class.
 * - A missed class gets at most one makeup.
 * - Declining records the reason and creates no class.
 */

jest.mock('firebase-functions', () => {
  class MockHttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  return {https: {HttpsError: MockHttpsError}};
});

const {reviewRescheduleRequest} = require('../handlers/reschedule_requests');
const {__test__: shiftTest} = require('../handlers/shifts');

const FieldValue = {serverTimestamp: () => 'SERVER_TS'};
const Timestamp = {fromDate: (d) => ({iso: d.toISOString(), toDate: () => d})};
const ts = (iso) => ({toDate: () => new Date(iso)});

function makeDb(seed) {
  const store = seed;
  const writes = [];
  const ref = (collection, id) => ({
    id,
    path: `${collection}/${id}`,
    collection,
    get: async () => snap(collection, id),
  });
  const snap = (collection, id) => ({
    id,
    exists: Boolean(store[collection] && store[collection][id]),
    data: () => ({...store[collection][id]}),
  });
  return {
    store,
    writes,
    collection: (name) => ({doc: (id) => ref(name, id)}),
    runTransaction: async (fn) => {
      let wrote = false;
      const staged = [];
      const tx = {
        get: async (r) => {
          if (wrote) throw new Error('reads must come before writes');
          return snap(r.collection, r.id);
        },
        set: (r, data) => {
          wrote = true;
          staged.push(() => {
            store[r.collection] = store[r.collection] || {};
            store[r.collection][r.id] = {...data};
            writes.push({op: 'set', path: r.path});
          });
        },
        update: (r, data) => {
          wrote = true;
          staged.push(() => {
            store[r.collection][r.id] = {...store[r.collection][r.id], ...data};
            writes.push({op: 'update', path: r.path});
          });
        },
      };
      const result = await fn(tx);
      staged.forEach((apply) => apply());
      return result;
    },
  };
}

const NOW = new Date('2026-11-10T12:00:00Z');

const originalShift = (over = {}) => ({
  teacher_id: 'teacher_1',
  teacher_name: 'Mariama Bah',
  student_ids: ['student_1', 'student_2'],
  student_names: ['Amina Diallo', 'Ousmane Diallo'],
  shift_start: ts('2026-11-05T14:00:00Z'),
  shift_end: ts('2026-11-05T15:00:00Z'),
  admin_timezone: 'America/New_York',
  teacher_timezone: 'Africa/Conakry',
  subject: 'quranStudies',
  subject_id: 'subj_quran',
  subject_display_name: 'Quran',
  auto_generated_name: 'Mariama Bah - Quran - Amina Diallo, Ousmane Diallo',
  hourly_rate: 6,
  shift_category: 'teaching',
  video_provider: 'zoom',
  status: 'missed',
  ...over,
});

// The teacher wrote this document, so every class field in it is suspect.
const pendingRequest = (over = {}) => ({
  teacher_id: 'teacher_1',
  teacher_name: 'Mariama Bah',
  original_shift_id: 'shift_1',
  subject: 'Something else',
  student_ids: ['student_9'],
  student_names: ['Someone Else'],
  hourly_rate: 500,
  video_provider: 'livekit',
  proposed_start: ts('2026-11-12T16:00:00Z'),
  proposed_end: ts('2026-11-12T20:00:00Z'),
  proposed_timezone: 'Africa/Conakry',
  reason_category: 'internet',
  notes: 'Power cut in my area',
  status: 'pending',
  ...over,
});

const seed = (over = {}) => ({
  users: {admin_1: {first_name: 'Hawa', last_name: 'Admin', user_type: 'admin'}},
  teaching_shifts: {shift_1: originalShift(over.shift)},
  reschedule_requests: {req_1: pendingRequest(over.request)},
});

const depsFor = (db, over = {}) => ({
  db,
  FieldValue,
  Timestamp,
  verifyAdmin: async () => ({callerUid: 'admin_1', effectiveAdminEmail: 'hawa@example.com'}),
  now: () => NOW,
  loadTeacherShifts: async (teacherId) =>
    Object.entries(db.store.teaching_shifts)
      .filter(([, s]) => s.teacher_id === teacherId)
      .map(([id, s]) => ({
        id,
        startMs: s.shift_start.toDate().getTime(),
        endMs: s.shift_end.toDate().getTime(),
        status: s.status,
        name: s.auto_generated_name,
      })),
  findConflict: shiftTest.findClaimConflict,
  zoomGuardrail: jest.fn(async () => ({ok: true})),
  scheduleLifecycle: jest.fn(async () => ({success: true})),
  notifyTeacher: jest.fn(async () => ({success: true})),
  formatDate: (d) => d.toISOString(),
  ...over,
});

const call = (deps, data) => reviewRescheduleRequest({auth: {uid: 'admin_1'}, data}, deps);

describe('reviewRescheduleRequest', () => {
  test('rejects a non-admin caller and writes nothing', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db, {
      verifyAdmin: async () => {
        const error = new Error('Only administrators can perform this action');
        error.code = 'permission-denied';
        throw error;
      },
    });
    await expect(call(deps, {requestId: 'req_1', decision: 'approve'}))
      .rejects.toMatchObject({code: 'permission-denied'});
    expect(db.writes).toHaveLength(0);
    expect(db.store.reschedule_requests.req_1.status).toBe('pending');
  });

  test('approval copies the class from the original shift, not the request', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db);
    const result = await call(deps, {requestId: 'req_1', decision: 'approve'});

    expect(result).toMatchObject({success: true, status: 'approved', createdShiftId: 'makeup_shift_1'});
    const makeup = db.store.teaching_shifts.makeup_shift_1;
    expect(makeup.teacher_id).toBe('teacher_1');
    expect(makeup.hourly_rate).toBe(6);
    expect(makeup.student_ids).toEqual(['student_1', 'student_2']);
    expect(makeup.student_names).toEqual(['Amina Diallo', 'Ousmane Diallo']);
    expect(makeup.subject).toBe('quranStudies');
    expect(makeup.subject_id).toBe('subj_quran');
    expect(makeup.video_provider).toBe('zoom');
    expect(makeup.teacher_timezone).toBe('Africa/Conakry');
    expect(makeup.admin_timezone).toBe('America/New_York');
    expect(makeup.status).toBe('scheduled');
    expect(makeup.makeup_for_shift_id).toBe('shift_1');
    expect(makeup.reschedule_request_id).toBe('req_1');
    // The proposed end asked for four hours; the makeup keeps the original hour.
    expect(makeup.shift_start.iso).toBe('2026-11-12T16:00:00.000Z');
    expect(makeup.shift_end.iso).toBe('2026-11-12T17:00:00.000Z');

    const req = db.store.reschedule_requests.req_1;
    expect(req.status).toBe('approved');
    expect(req.created_shift_id).toBe('makeup_shift_1');
    expect(req.admin_id).toBe('admin_1');

    expect(deps.zoomGuardrail).toHaveBeenCalledTimes(1);
    expect(deps.scheduleLifecycle).toHaveBeenCalledWith('makeup_shift_1', 'admin_1');
    expect(deps.notifyTeacher).toHaveBeenCalledWith(
      'teacher_1',
      expect.objectContaining({title: 'Makeup class scheduled'}),
      expect.objectContaining({action: 'approved', shiftId: 'makeup_shift_1'}),
    );
  });

  test('an admin-chosen start replaces the proposed one', async () => {
    const db = makeDb(seed());
    await call(depsFor(db), {requestId: 'req_1', decision: 'approve', startTime: '2026-11-13T09:30:00.000Z'});
    const makeup = db.store.teaching_shifts.makeup_shift_1;
    expect(makeup.shift_start.iso).toBe('2026-11-13T09:30:00.000Z');
    expect(makeup.shift_end.iso).toBe('2026-11-13T10:30:00.000Z');
    expect(db.store.reschedule_requests.req_1.approved_start.iso).toBe('2026-11-13T09:30:00.000Z');
  });

  test('approving twice returns the first makeup and creates no second class', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db);
    const first = await call(deps, {requestId: 'req_1', decision: 'approve'});
    const setsAfterFirst = db.writes.filter((w) => w.op === 'set').length;
    const second = await call(deps, {requestId: 'req_1', decision: 'approve', startTime: '2026-11-14T09:00:00Z'});

    expect(second).toMatchObject({success: true, status: 'approved', createdShiftId: first.createdShiftId, alreadyReviewed: true});
    expect(db.writes.filter((w) => w.op === 'set').length).toBe(setsAfterFirst);
    expect(Object.keys(db.store.teaching_shifts).filter((id) => id.startsWith('makeup_'))).toEqual(['makeup_shift_1']);
    expect(db.store.teaching_shifts.makeup_shift_1.shift_start.iso).toBe('2026-11-12T16:00:00.000Z');
    expect(deps.notifyTeacher).toHaveBeenCalledTimes(1);
  });

  test('a second request for the same missed class cannot make a second makeup', async () => {
    const data = seed();
    data.reschedule_requests.req_2 = pendingRequest({proposed_start: ts('2026-11-15T16:00:00Z')});
    const db = makeDb(data);
    await call(depsFor(db), {requestId: 'req_1', decision: 'approve'});
    await expect(call(depsFor(db), {requestId: 'req_2', decision: 'approve'}))
      .rejects.toMatchObject({code: 'already-exists'});
    expect(db.store.reschedule_requests.req_2.status).toBe('pending');
  });

  test('refuses a time that overlaps another of the teacher\'s classes', async () => {
    const data = seed();
    data.teaching_shifts.other = originalShift({
      status: 'scheduled',
      shift_start: ts('2026-11-12T16:30:00Z'),
      shift_end: ts('2026-11-12T17:30:00Z'),
    });
    const db = makeDb(data);
    await expect(call(depsFor(db), {requestId: 'req_1', decision: 'approve'}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.store.teaching_shifts.makeup_shift_1).toBeUndefined();
  });

  test('refuses when Zoom has no room, with the guardrail message', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db, {zoomGuardrail: async () => ({ok: false, message: 'Zoom is full then.'})});
    await expect(call(deps, {requestId: 'req_1', decision: 'approve'}))
      .rejects.toMatchObject({code: 'failed-precondition', message: 'Zoom is full then.'});
    expect(db.writes).toHaveLength(0);
  });

  test('refuses a class that was not missed, or has no subject', async () => {
    const completed = makeDb(seed({shift: {status: 'completed'}}));
    await expect(call(depsFor(completed), {requestId: 'req_1', decision: 'approve'}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    const noSubject = makeDb(seed({shift: {subject: ''}}));
    await expect(call(depsFor(noSubject), {requestId: 'req_1', decision: 'approve'}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(completed.writes).toHaveLength(0);
    expect(noSubject.writes).toHaveLength(0);
  });

  test('refuses a request whose teacher is not the class\'s teacher', async () => {
    const db = makeDb(seed({request: {teacher_id: 'teacher_2'}}));
    await expect(call(depsFor(db), {requestId: 'req_1', decision: 'approve'}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.writes).toHaveLength(0);
  });

  test('refuses a time that has already passed', async () => {
    const db = makeDb(seed());
    await expect(call(depsFor(db), {requestId: 'req_1', decision: 'approve', startTime: '2026-11-09T09:00:00Z'}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(db.writes).toHaveLength(0);
  });

  test('decline records the reason, creates no class and notifies the teacher', async () => {
    const db = makeDb(seed());
    const deps = depsFor(db);
    const result = await call(deps, {requestId: 'req_1', decision: 'decline', reason: '  Students are away that week ' });
    expect(result).toMatchObject({success: true, status: 'declined'});
    const req = db.store.reschedule_requests.req_1;
    expect(req.status).toBe('declined');
    expect(req.decline_reason).toBe('Students are away that week');
    expect(req.admin_id).toBe('admin_1');
    expect(db.store.teaching_shifts.makeup_shift_1).toBeUndefined();
    expect(deps.notifyTeacher).toHaveBeenCalledWith(
      'teacher_1',
      expect.objectContaining({title: 'Makeup request declined', body: 'Students are away that week'}),
      expect.objectContaining({action: 'declined'}),
    );

    const again = await call(deps, {requestId: 'req_1', decision: 'decline'});
    expect(again).toMatchObject({status: 'declined', alreadyReviewed: true});
    expect(deps.notifyTeacher).toHaveBeenCalledTimes(1);
  });

  test('an approved request cannot be declined, nor a declined one approved', async () => {
    const db = makeDb(seed());
    await call(depsFor(db), {requestId: 'req_1', decision: 'approve'});
    await expect(call(depsFor(db), {requestId: 'req_1', decision: 'decline'}))
      .rejects.toMatchObject({code: 'failed-precondition'});

    const db2 = makeDb(seed());
    await call(depsFor(db2), {requestId: 'req_1', decision: 'decline'});
    await expect(call(depsFor(db2), {requestId: 'req_1', decision: 'approve'}))
      .rejects.toMatchObject({code: 'failed-precondition'});
    expect(db2.store.teaching_shifts.makeup_shift_1).toBeUndefined();
  });

  test('validates its input', async () => {
    const db = makeDb(seed());
    await expect(call(depsFor(db), {decision: 'approve'})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(depsFor(db), {requestId: 'req_1', decision: 'maybe'})).rejects.toMatchObject({code: 'invalid-argument'});
    await expect(call(depsFor(db), {requestId: 'nope', decision: 'approve'})).rejects.toMatchObject({code: 'not-found'});
  });
});
