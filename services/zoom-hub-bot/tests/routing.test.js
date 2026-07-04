const { normalizeRooms, normalizeUnassigned, whoNeedsToMoveWhere } = require('../routing');

describe('zoom hub bot routing diff', () => {
  const assignments = {
    rooms: [
      { shiftId: 'shift_a', name: 'Room A' },
      { shiftId: 'shift_b', name: 'Room B' },
    ],
    members: [
      { uid: 'teacher_a', shiftId: 'shift_a' },
      { uid: 'student_a', shiftId: 'shift_a' },
      { uid: 'teacher_b', shiftId: 'shift_b' },
    ],
  };

  test('assigns mapped main-session users to their target rooms', () => {
    const actions = whoNeedsToMoveWhere(assignments, {
      rooms: [
        { boId: 'bo_a', name: 'Room A', participants: [] },
        { boId: 'bo_b', name: 'Room B', participants: [] },
      ],
      unassigned: [
        { userId: 10, customerKey: 'teacher_a' },
        { userId: 11, customerKey: 'student_a' },
        { userId: 12, customerKey: 'unknown_user' },
      ],
    });

    expect(actions).toEqual([
      {
        action: 'assign',
        uid: 'teacher_a',
        userId: 10,
        fromRoomName: '',
        targetRoomName: 'Room A',
        targetRoomId: 'bo_a',
      },
      {
        action: 'assign',
        uid: 'student_a',
        userId: 11,
        fromRoomName: '',
        targetRoomName: 'Room A',
        targetRoomId: 'bo_a',
      },
    ]);
  });

  test('moves users who are sitting in the wrong private room', () => {
    const actions = whoNeedsToMoveWhere(assignments, {
      rooms: [
        {
          boId: 'bo_a',
          name: 'Room A',
          participants: [{ userId: 20, customerKey: 'teacher_b' }],
        },
        { boId: 'bo_b', name: 'Room B', participants: [] },
      ],
      unassigned: [],
    });

    expect(actions).toEqual([
      {
        action: 'move',
        uid: 'teacher_b',
        userId: 20,
        fromRoomName: 'Room A',
        targetRoomName: 'Room B',
        targetRoomId: 'bo_b',
      },
    ]);
  });

  test('does nothing for users already in the correct room', () => {
    const actions = whoNeedsToMoveWhere(assignments, {
      rooms: [
        {
          boId: 'bo_a',
          name: 'Room A',
          participants: [
            { userId: 30, customerKey: 'teacher_a' },
            { userId: 31, customerKey: 'student_a' },
          ],
        },
        { boId: 'bo_b', name: 'Room B', participants: [] },
      ],
      unassigned: [],
    });

    expect(actions).toEqual([]);
  });

  test('does not re-move a room participant only repeated by the attendee list', () => {
    const actions = whoNeedsToMoveWhere(assignments, {
      rooms: [
        {
          boId: 'bo_a',
          name: 'Room A',
          participants: [{ userId: 30, customerKey: 'teacher_a' }],
        },
      ],
      attendees: [{ userId: 30, customerKey: 'teacher_a' }],
    });

    expect(actions).toEqual([]);
  });

  test('routes a rejoined participant even when the same uid is already in the room', () => {
    const actions = whoNeedsToMoveWhere(assignments, {
      rooms: [
        {
          boId: 'bo_a',
          name: 'Room A',
          participants: [{ userId: 30, customerKey: 'teacher_a' }],
        },
      ],
      unassigned: [{ userId: 31, customerKey: 'teacher_a' }],
    });

    expect(actions).toEqual([
      {
        action: 'assign',
        uid: 'teacher_a',
        userId: 31,
        fromRoomName: '',
        targetRoomName: 'Room A',
        targetRoomId: 'bo_a',
      },
    ]);
  });

  test('ignores users until Zoom exposes customerKey and target room ids', () => {
    const actions = whoNeedsToMoveWhere(assignments, {
      rooms: [
        { name: 'Room A', participants: [] },
        { boId: 'bo_b', name: 'Room B', participants: [{ userId: 40 }] },
      ],
      unassigned: [{ userId: 41, userName: 'Teacher A' }],
    });

    expect(actions).toEqual([]);
  });

  test('assigns users by unique display name when Zoom omits customerKey', () => {
    const actions = whoNeedsToMoveWhere({
      rooms: [{ shiftId: 'shift_a', name: 'Room A' }],
      members: [{ uid: 'teacher_a', shiftId: 'shift_a', displayName: 'Teacher A' }],
    }, {
      rooms: [{ boId: 'bo_a', name: 'Room A', participants: [] }],
      unassigned: [{ userId: 41, userName: 'Teacher A' }],
    });

    expect(actions).toEqual([
      {
        action: 'assign',
        uid: 'Teacher A',
        userId: 41,
        fromRoomName: '',
        targetRoomName: 'Room A',
        targetRoomId: 'bo_a',
      },
    ]);
  });

  test('does not route by display name when the name maps to multiple rooms', () => {
    const actions = whoNeedsToMoveWhere({
      rooms: [
        { shiftId: 'shift_a', name: 'Room A' },
        { shiftId: 'shift_b', name: 'Room B' },
      ],
      members: [
        { uid: 'teacher_a', shiftId: 'shift_a', displayName: 'Shared Name' },
        { uid: 'teacher_b', shiftId: 'shift_b', displayName: 'Shared Name' },
      ],
    }, {
      rooms: [
        { boId: 'bo_a', name: 'Room A', participants: [] },
        { boId: 'bo_b', name: 'Room B', participants: [] },
      ],
      unassigned: [{ userId: 42, userName: 'Shared Name' }],
    });

    expect(actions).toEqual([]);
  });

  test('assigns users from Zoom attendee payload wrappers', () => {
    const actions = whoNeedsToMoveWhere(assignments, {
      rooms: [
        { boId: 'bo_a', name: 'Room A', participants: [] },
        { boId: 'bo_b', name: 'Room B', participants: [] },
      ],
      result: {
        attendeesList: [
          { user_id: 50, customer_key: 'teacher_a' },
          { participant_id: 51, customerKey: 'student_a' },
        ],
      },
    });

    expect(actions).toEqual([
      {
        action: 'assign',
        uid: 'teacher_a',
        userId: 50,
        fromRoomName: '',
        targetRoomName: 'Room A',
        targetRoomId: 'bo_a',
      },
      {
        action: 'assign',
        uid: 'student_a',
        userId: 51,
        fromRoomName: '',
        targetRoomName: 'Room A',
        targetRoomId: 'bo_a',
      },
    ]);
  });

  test('normalizes common attendee list wrappers', () => {
    expect(normalizeUnassigned({
      result: {
        userList: [{ user_id: 60, customer_key: 'teacher_a' }],
      },
    })).toEqual([{ user_id: 60, customer_key: 'teacher_a' }]);
  });

  test('normalizes common breakout room list wrappers', () => {
    expect(normalizeRooms({
      result: {
        data: {
          roomList: [{ bo_id: 'spare_1', room_name: 'Spare 1' }],
        },
      },
    })).toEqual([{ bo_id: 'spare_1', room_name: 'Spare 1' }]);
  });
});
