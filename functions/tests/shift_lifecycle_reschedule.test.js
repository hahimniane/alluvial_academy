/**
 * Tests for shift lifecycle Cloud Tasks scheduling + reschedule safety.
 *
 * What we verify:
 * - `scheduleShiftLifecycle` schedules tasks with names derived from the scheduled epoch seconds.
 *   Re-scheduling after a time change creates NEW task names (so tasks can coexist without de-dupe errors).
 * - Task handlers (`handleShiftStartTask`/`handleShiftEndTask`) ignore stale tasks whose payload time
 *   no longer matches the shift document (prevents incorrect status changes after edits).
 */

// firebase-functions v2 wrappers are replaced with identity functions so handlers are directly invokable.
jest.mock('firebase-functions/v2/https', () => ({
  onCall: (fn) => fn,
  onRequest: (fn) => fn,
}));
jest.mock('firebase-functions/v2/firestore', () => ({
  onDocumentCreated: (_path, fn) => fn,
  onDocumentUpdated: (_path, fn) => fn,
  onDocumentDeleted: (_path, fn) => fn,
}));
jest.mock('firebase-functions/v2/scheduler', () => ({
  onSchedule: (_schedule, fn) => fn,
}));

// Mock Cloud Tasks helpers used by shifts handler.
const mockCreateTask = jest.fn(() => Promise.resolve());
const mockDeleteTask = jest.fn(() => Promise.resolve());
const mockGetQueue = jest.fn(() => Promise.resolve({}));

const mockEnsureTasksConfig = jest.fn(() => Promise.resolve());
const mockQueuePath = jest.fn(() => 'queue/path');
const mockTaskName = jest.fn(
  (shiftId, phase, suffix) => `task/${shiftId}/${phase}/${suffix || 'legacy'}`,
);
const mockEnsureFutureDate = jest.fn((d) => d);
const mockDeleteTaskIfExists = jest.fn(() => Promise.resolve());
const mockGetTasksServiceAccount = jest.fn(async () => 'tasks@test.invalid');

jest.mock('../services/tasks/config', () => ({
  ensureTasksConfig: (...args) => mockEnsureTasksConfig(...args),
  queuePath: (...args) => mockQueuePath(...args),
  taskName: (...args) => mockTaskName(...args),
  ensureFutureDate: (...args) => mockEnsureFutureDate(...args),
  deleteTaskIfExists: (...args) => mockDeleteTaskIfExists(...args),
  getTasksServiceAccount: (...args) => mockGetTasksServiceAccount(...args),
  tasksClient: {
    createTask: (...args) => mockCreateTask(...args),
    deleteTask: (...args) => mockDeleteTask(...args),
    getQueue: (...args) => mockGetQueue(...args),
  },
  FUNCTION_REGION: 'us-central1',
  PROJECT_ID: 'test-project',
}));

// Minimal in-memory Firestore mock for this suite.
let mockStore;
let mockFirestore;

const ts = (date) => ({ toDate: () => date });

jest.mock('firebase-admin', () => {
  const firestoreFn = jest.fn(() => mockFirestore);
  firestoreFn.FieldValue = {
    serverTimestamp: jest.fn(() => ({ __op: 'serverTimestamp' })),
  };

  return {
    apps: [],
    initializeApp: jest.fn(),
    firestore: firestoreFn,
  };
});

const buildFirestore = () => ({
  collection: (name) => {
    if (name !== 'teaching_shifts') {
      throw new Error(`Unexpected collection in test: ${name}`);
    }
    return {
      doc: (id) => ({
        get: async () => {
          const data = mockStore.teaching_shifts.get(id);
          return {
            exists: data !== undefined,
            id,
            data: () => data,
          };
        },
        update: async (updates) => {
          const current = mockStore.teaching_shifts.get(id);
          if (!current) throw new Error(`Missing shift doc in test: ${id}`);
          mockStore.teaching_shifts.set(id, { ...current, ...updates });
        },
      }),
    };
  },
});

// Import after mocks.
const {
  scheduleShiftLifecycle,
  handleShiftStartTask,
  handleShiftEndTask,
} = require('../handlers/shifts');

describe('Shift lifecycle scheduling + reschedule safety', () => {
  beforeEach(() => {
    mockStore = {
      teaching_shifts: new Map(),
    };
    mockFirestore = buildFirestore();

    jest.clearAllMocks();
  });

  test('scheduleShiftLifecycle schedules unique task names; reschedule creates new names', async () => {
    const shiftId = 'shift_123';

    const start1 = new Date('2026-01-10T12:00:00.000Z');
    const end1 = new Date('2026-01-10T13:00:00.000Z');
    mockStore.teaching_shifts.set(shiftId, {
      shift_start: ts(start1),
      shift_end: ts(end1),
      status: 'scheduled',
    });

    await scheduleShiftLifecycle({
      data: { shiftId },
      auth: { uid: 'admin_1' },
    });

    // 2 tasks scheduled (start + end), with epoch suffix.
    expect(mockCreateTask).toHaveBeenCalledTimes(2);
    const firstNames = mockCreateTask.mock.calls.map((call) => call[0].task.name);
    expect(firstNames[0]).toContain(`/start/${Math.floor(start1.getTime() / 1000)}`);
    expect(firstNames[1]).toContain(`/end/${Math.floor(end1.getTime() / 1000)}`);

    // Update shift times to simulate edit.
    const start2 = new Date('2026-01-10T14:00:00.000Z');
    const end2 = new Date('2026-01-10T15:00:00.000Z');
    mockStore.teaching_shifts.set(shiftId, {
      shift_start: ts(start2),
      shift_end: ts(end2),
      status: 'scheduled',
    });

    await scheduleShiftLifecycle({
      data: { shiftId },
      auth: { uid: 'admin_1' },
    });

    expect(mockCreateTask).toHaveBeenCalledTimes(4);
    const allNames = mockCreateTask.mock.calls.map((call) => call[0].task.name);

    expect(allNames).toContain(`task/${shiftId}/start/${Math.floor(start1.getTime() / 1000)}`);
    expect(allNames).toContain(`task/${shiftId}/end/${Math.floor(end1.getTime() / 1000)}`);
    expect(allNames).toContain(`task/${shiftId}/start/${Math.floor(start2.getTime() / 1000)}`);
    expect(allNames).toContain(`task/${shiftId}/end/${Math.floor(end2.getTime() / 1000)}`);
  });

  test('handleShiftStartTask ignores stale tasks after a reschedule', async () => {
    const shiftId = 'shift_456';

    const currentStart = new Date('2026-01-10T12:00:00.000Z');
    mockStore.teaching_shifts.set(shiftId, {
      shift_start: ts(currentStart),
      shift_end: ts(new Date('2026-01-10T13:00:00.000Z')),
      status: 'scheduled',
    });

    const staleStart = new Date(currentStart.getTime() - 5 * 60 * 1000); // -5 minutes

    const req = {
      method: 'POST',
      body: { shiftId, shiftStart: staleStart.toISOString() },
    };
    const res = {
      status: jest.fn(() => res),
      json: jest.fn(() => res),
      send: jest.fn(() => res),
    };

    await handleShiftStartTask(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    const payload = res.json.mock.calls[0][0];
    expect(payload.success).toBe(true);
    expect(payload.message).toMatch(/stale task/i);

    // Ensure we did not change the shift status.
    expect(mockStore.teaching_shifts.get(shiftId).status).toBe('scheduled');
  });

  test('handleShiftEndTask ignores stale tasks after a reschedule', async () => {
    const shiftId = 'shift_789';

    const currentEnd = new Date('2026-01-10T13:00:00.000Z');
    mockStore.teaching_shifts.set(shiftId, {
      shift_start: ts(new Date('2026-01-10T12:00:00.000Z')),
      shift_end: ts(currentEnd),
      status: 'scheduled',
    });

    const staleEnd = new Date(currentEnd.getTime() - 10 * 60 * 1000); // -10 minutes

    const req = {
      method: 'POST',
      body: {
        shiftId,
        shiftStart: new Date('2026-01-10T12:00:00.000Z').toISOString(),
        shiftEnd: staleEnd.toISOString(),
      },
    };
    const res = {
      status: jest.fn(() => res),
      json: jest.fn(() => res),
      send: jest.fn(() => res),
    };

    await handleShiftEndTask(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    const payload = res.json.mock.calls[0][0];
    expect(payload.success).toBe(true);
    expect(payload.message).toMatch(/stale task/i);

    // Ensure we did not change the shift status.
    expect(mockStore.teaching_shifts.get(shiftId).status).toBe('scheduled');
  });
});
