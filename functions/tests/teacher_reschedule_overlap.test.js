/**
 * Tests for the teacher-overlap guardrail on reschedules.
 *
 * What we verify:
 * - `_findOverlappingShiftForTeacher` detects overlaps, ignores cancelled
 *   shifts, and honors excluded shift ids (the shift being moved).
 * - `teacherRescheduleShift` rejects an overlapping reschedule with
 *   failed-precondition + details.code === 'shift_overlap' and writes nothing.
 * - `teacherRescheduleShift` still applies a non-overlapping reschedule.
 */

jest.mock('firebase-functions/v2/https', () => {
  const {HttpsError} = jest.requireActual('firebase-functions/v2/https');
  const unwrap = (...args) => (typeof args[0] === 'function' ? args[0] : args[1]);
  return {
    onCall: (...args) => unwrap(...args),
    onRequest: (...args) => unwrap(...args),
    HttpsError,
  };
});
jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: (_path, fn) => fn,
  onDocumentUpdated: (_path, fn) => fn,
  onDocumentDeleted: (_path, fn) => fn,
  onDocumentWritten: (_path, fn) => fn,
}));
jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (_schedule, fn) => fn,
}));

jest.mock('../services/tasks/config', () => ({
  ensureTasksConfig: jest.fn(() => Promise.resolve()),
  queuePath: jest.fn(() => 'queue/path'),
  taskName: jest.fn((...parts) => `task/${parts.join('/')}`),
  ensureFutureDate: jest.fn((d) => d),
  deleteTaskIfExists: jest.fn(() => Promise.resolve()),
  getTasksServiceAccount: jest.fn(async () => 'tasks@test.invalid'),
  buildFunctionUrl: jest.fn(() => 'https://test.invalid'),
  encodeTaskBody: jest.fn(() => ''),
  toScheduleTime: jest.fn((d) => ({seconds: Math.floor(d.getTime() / 1000)})),
  tasksClient: {
    createTask: jest.fn(() => Promise.resolve()),
    deleteTask: jest.fn(() => Promise.resolve()),
    getQueue: jest.fn(() => Promise.resolve({})),
  },
  FUNCTION_REGION: 'us-central1',
  PROJECT_ID: 'test-project',
}));

let mockStore;
let mockFirestore;

const ts = (date) => ({toDate: () => date});

jest.mock('firebase-admin', () => {
  const firestoreFn = jest.fn(() => mockFirestore);
  firestoreFn.FieldValue = {
    serverTimestamp: jest.fn(() => ({__op: 'serverTimestamp'})),
    increment: jest.fn((n) => ({__op: 'increment', n})),
  };
  firestoreFn.Timestamp = {
    fromDate: (date) => ({toDate: () => date, __ts: date.getTime()}),
  };
  return {
    apps: [],
    initializeApp: jest.fn(),
    firestore: firestoreFn,
  };
});

const shiftDocSnapshot = (id) => {
  const data = mockStore.teaching_shifts.get(id);
  return {exists: data !== undefined, id, data: () => data};
};

const buildFirestore = () => ({
  collection: (name) => {
    if (name === 'shift_modifications') {
      return {doc: () => ({__collection: 'shift_modifications'})};
    }
    if (name !== 'teaching_shifts') {
      throw new Error(`Unexpected collection in test: ${name}`);
    }
    const makeQuery = (filters) => ({
      where: (field, op, value) => makeQuery([...filters, {field, op, value}]),
      get: async () => {
        const docs = [];
        for (const [id, data] of mockStore.teaching_shifts.entries()) {
          const matches = filters.every(({field, op, value}) => {
            if (field === 'teacher_id') return data.teacher_id === value;
            if (field === 'shift_start') {
              const startMs = data.shift_start.toDate().getTime();
              const boundMs = value.toDate().getTime();
              if (op === '>=') return startMs >= boundMs;
              if (op === '<') return startMs < boundMs;
            }
            throw new Error(`Unexpected filter in test: ${field} ${op}`);
          });
          if (matches) docs.push(shiftDocSnapshot(id));
        }
        return {docs};
      },
    });
    return {
      doc: (id) => ({
        get: async () => shiftDocSnapshot(id),
      }),
      where: (field, op, value) => makeQuery([{field, op, value}]),
    };
  },
  batch: () => ({
    update: (ref, updates) => {
      mockStore.batchUpdates.push(updates);
    },
    set: () => {},
    commit: async () => {
      mockStore.commits += 1;
    },
  }),
});

const {
  teacherRescheduleShift,
  _findOverlappingShiftForTeacher,
} = require('../handlers/shifts');

const TEACHER = 'teacher_1';

const seedShift = (id, {start, end, status = 'scheduled', name = `Class ${id}`}) => {
  mockStore.teaching_shifts.set(id, {
    teacher_id: TEACHER,
    shift_name: name,
    student_names: ['Student A'],
    status,
    shift_start: ts(start),
    shift_end: ts(end),
    teacher_timezone: 'UTC',
  });
};

describe('Teacher reschedule overlap guardrail', () => {
  beforeEach(() => {
    mockStore = {
      teaching_shifts: new Map(),
      batchUpdates: [],
      commits: 0,
    };
    mockFirestore = buildFirestore();
    jest.clearAllMocks();
  });

  describe('_findOverlappingShiftForTeacher', () => {
    test('detects an overlapping shift', async () => {
      seedShift('existing', {
        start: new Date('2026-07-12T12:00:00Z'),
        end: new Date('2026-07-12T13:30:00Z'),
      });

      const conflict = await _findOverlappingShiftForTeacher({
        db: mockFirestore,
        teacherId: TEACHER,
        newStart: new Date('2026-07-12T11:00:00Z'),
        newEnd: new Date('2026-07-12T13:00:00Z'),
      });

      expect(conflict).not.toBeNull();
      expect(conflict.id).toBe('existing');
      expect(conflict.name).toBe('Class existing');
    });

    test('ignores cancelled shifts and excluded ids', async () => {
      seedShift('cancelled_one', {
        start: new Date('2026-07-12T12:00:00Z'),
        end: new Date('2026-07-12T13:00:00Z'),
        status: 'cancelled',
      });
      seedShift('moving', {
        start: new Date('2026-07-12T12:00:00Z'),
        end: new Date('2026-07-12T13:00:00Z'),
      });

      const conflict = await _findOverlappingShiftForTeacher({
        db: mockFirestore,
        teacherId: TEACHER,
        newStart: new Date('2026-07-12T12:00:00Z'),
        newEnd: new Date('2026-07-12T13:00:00Z'),
        excludeShiftIds: ['moving'],
      });

      expect(conflict).toBeNull();
    });

    test('allows back-to-back shifts (touching edges do not overlap)', async () => {
      seedShift('earlier', {
        start: new Date('2026-07-12T11:00:00Z'),
        end: new Date('2026-07-12T12:00:00Z'),
      });

      const conflict = await _findOverlappingShiftForTeacher({
        db: mockFirestore,
        teacherId: TEACHER,
        newStart: new Date('2026-07-12T12:00:00Z'),
        newEnd: new Date('2026-07-12T13:00:00Z'),
      });

      expect(conflict).toBeNull();
    });
  });

  describe('teacherRescheduleShift', () => {
    test('rejects a reschedule that overlaps another shift and writes nothing', async () => {
      seedShift('shift_moving', {
        start: new Date('2026-07-11T12:00:00Z'),
        end: new Date('2026-07-11T13:00:00Z'),
      });
      seedShift('shift_blocking', {
        start: new Date('2026-07-12T12:00:00Z'),
        end: new Date('2026-07-12T13:30:00Z'),
        name: 'Quran - Nafisatou',
      });

      let thrown;
      try {
        await teacherRescheduleShift({
          auth: {uid: TEACHER},
          data: {
            shiftId: 'shift_moving',
            newStartTime: '2026-07-12T11:30:00.000Z',
            newEndTime: '2026-07-12T12:30:00.000Z',
            timezone: 'UTC',
          },
        });
      } catch (err) {
        thrown = err;
      }

      expect(thrown).toBeDefined();
      expect(thrown.code).toContain('failed-precondition');
      expect(thrown.message).toContain('Quran - Nafisatou');
      expect(thrown.details).toMatchObject({
        code: 'shift_overlap',
        conflictShiftId: 'shift_blocking',
        conflictShiftName: 'Quran - Nafisatou',
      });
      expect(mockStore.commits).toBe(0);
      expect(mockStore.batchUpdates).toHaveLength(0);
    });

    test('applies a reschedule with no overlap', async () => {
      seedShift('shift_moving', {
        start: new Date('2026-07-11T12:00:00Z'),
        end: new Date('2026-07-11T13:00:00Z'),
      });
      seedShift('shift_other', {
        start: new Date('2026-07-12T12:00:00Z'),
        end: new Date('2026-07-12T13:30:00Z'),
      });

      const result = await teacherRescheduleShift({
        auth: {uid: TEACHER},
        data: {
          shiftId: 'shift_moving',
          newStartTime: '2026-07-12T14:00:00.000Z',
          newEndTime: '2026-07-12T15:00:00.000Z',
          timezone: 'UTC',
        },
      });

      expect(result.success).toBe(true);
      expect(mockStore.commits).toBe(1);
      expect(mockStore.batchUpdates).toHaveLength(1);
    });

    test('allows moving a shift within its own current window', async () => {
      seedShift('shift_moving', {
        start: new Date('2026-07-12T12:00:00Z'),
        end: new Date('2026-07-12T13:00:00Z'),
      });

      const result = await teacherRescheduleShift({
        auth: {uid: TEACHER},
        data: {
          shiftId: 'shift_moving',
          newStartTime: '2026-07-12T12:30:00.000Z',
          newEndTime: '2026-07-12T13:30:00.000Z',
          timezone: 'UTC',
        },
      });

      expect(result.success).toBe(true);
      expect(mockStore.commits).toBe(1);
    });
  });
});
