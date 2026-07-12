const mockTaskData = {};
const mockUpdate = jest.fn();

jest.mock('firebase-admin', () => ({
  firestore: Object.assign(
    jest.fn(() => ({
      collection: () => ({doc: (id) => ({id})}),
      runTransaction: async (callback) => callback({
        get: async (ref) => ({exists: Boolean(mockTaskData[ref.id]), data: () => mockTaskData[ref.id]}),
        update: mockUpdate,
      }),
    })),
    {
      Timestamp: {now: jest.fn(() => ({toDate: () => new Date('2026-07-11T12:00:00Z')}))},
      FieldValue: {delete: jest.fn(() => '__delete__')},
    },
  ),
}));

jest.mock('../services/email/senders', () => ({sendTaskAssignmentEmail: jest.fn()}));
jest.mock('../services/email/transporter', () => ({createTransporter: jest.fn()}));

const {updateAssignedTaskStatus} = require('../handlers/tasks');

describe('assigned task status updates', () => {
  beforeEach(() => {
    Object.keys(mockTaskData).forEach((key) => delete mockTaskData[key]);
    mockUpdate.mockClear();
  });

  test('assigned user can complete a task with completion metadata', async () => {
    mockTaskData.task_1 = {
      assignedTo: ['teacher_1'],
      dueDate: {toDate: () => new Date('2026-07-09T12:00:00Z')},
    };

    const result = await updateAssignedTaskStatus({
      auth: {uid: 'teacher_1'},
      data: {taskId: 'task_1', status: 'done'},
    });

    expect(result).toEqual({success: true, taskId: 'task_1', status: 'done'});
    expect(mockUpdate).toHaveBeenCalledWith(
      {id: 'task_1'},
      expect.objectContaining({
        status: 'TaskStatus.done',
        updatedBy: 'teacher_1',
        overdueDaysAtCompletion: 2,
      }),
    );
  });

  test('unassigned user cannot change task status', async () => {
    mockTaskData.task_1 = {assignedTo: ['teacher_2']};
    await expect(updateAssignedTaskStatus({
      auth: {uid: 'teacher_1'},
      data: {taskId: 'task_1', status: 'inProgress'},
    })).rejects.toMatchObject({code: 'permission-denied'});
    expect(mockUpdate).not.toHaveBeenCalled();
  });

  test('rejects invalid statuses', async () => {
    await expect(updateAssignedTaskStatus({
      auth: {uid: 'teacher_1'},
      data: {taskId: 'task_1', status: 'archived'},
    })).rejects.toMatchObject({code: 'invalid-argument'});
  });
});
