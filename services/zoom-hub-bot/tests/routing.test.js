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

  test('assigns users when Zoom exposes the custom key as customerKeyValue', () => {
    const actions = whoNeedsToMoveWhere(assignments, {
      rooms: [
        { boId: 'bo_a', name: 'Room A', participants: [] },
        { boId: 'bo_b', name: 'Room B', participants: [] },
      ],
      unassigned: [
        { userId: 13, customerKeyValue: 'teacher_a' },
        { userId: 14, customer_key_value: 'student_a' },
      ],
    });

    expect(actions).toEqual([
      {
        action: 'assign',
        uid: 'teacher_a',
        userId: 13,
        fromRoomName: '',
        targetRoomName: 'Room A',
        targetRoomId: 'bo_a',
      },
      {
        action: 'assign',
        uid: 'student_a',
        userId: 14,
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

  test('assigns native users by routing display-name aliases', () => {
    const actions = whoNeedsToMoveWhere({
      rooms: [
        { shiftId: 'shift_a', name: 'Room A' },
        { shiftId: 'shift_b', name: 'Room B' },
      ],
      members: [
        {
          uid: 'zh_teacher_a',
          shiftId: 'shift_a',
          displayName: 'Shared Teacher',
          routingDisplayName: 'Shared Teacher #abc12345',
          displayNameAliases: ['Shared Teacher', 'Shared Teacher #abc12345'],
        },
        {
          uid: 'zh_teacher_b',
          shiftId: 'shift_b',
          displayName: 'Shared Teacher',
          routingDisplayName: 'Shared Teacher #def67890',
          displayNameAliases: ['Shared Teacher', 'Shared Teacher #def67890'],
        },
      ],
    }, {
      rooms: [
        { boId: 'bo_a', name: 'Room A', participants: [] },
        { boId: 'bo_b', name: 'Room B', participants: [] },
      ],
      unassigned: [{ userId: 43, userName: 'Shared Teacher #def67890' }],
    });

    expect(actions).toEqual([
      {
        action: 'assign',
        uid: 'Shared Teacher #def67890',
        userId: 43,
        fromRoomName: '',
        targetRoomName: 'Room B',
        targetRoomId: 'bo_b',
      },
    ]);
  });

  test('assigns native users sitting in the breakout-unassigned pool', () => {
    // Reproduces production: a native mobile client (no customerKey) that joins
    // after breakout rooms are open lands in `breakoutUnassigned`, while the
    // main-session `unassigned` list only holds the host bot.
    const actions = whoNeedsToMoveWhere({
      rooms: [{ shiftId: 'shift_a', name: 'Room A' }],
      members: [
        {
          uid: 'zh_student_a',
          shiftId: 'shift_a',
          displayName: 'Test Student',
          routingDisplayName: 'Test Student #wmCwjEzH',
          displayNameAliases: ['Test Student', 'Test Student #wmCwjEzH'],
        },
      ],
    }, {
      rooms: [{ boId: 'bo_a', name: 'Room A', participants: [] }],
      unassigned: [{ uid: 'zoom_hub_bot_lane_2', userId: 16778240 }],
      breakoutUnassigned: [
        { uid: '', userId: 33557504, name: 'Test Student #wmCwjEzH' },
      ],
    });

    expect(actions).toEqual([
      {
        action: 'assign',
        uid: 'Test Student #wmCwjEzH',
        userId: 33557504,
        fromRoomName: '',
        targetRoomName: 'Room A',
        targetRoomId: 'bo_a',
      },
    ]);
  });

  test('sweeps an unmatched participant out of the main session into a spare room', () => {
    // Invariant: nobody may sit in the hub main session. Someone the bot cannot
    // map to a class room must still be moved out of main — into a spare room.
    const actions = whoNeedsToMoveWhere({
      rooms: [{ shiftId: 'shift_a', name: 'Room A' }],
      members: [{ uid: 'zh_student_a', shiftId: 'shift_a', displayName: 'Student A' }],
    }, {
      rooms: [
        { boId: 'bo_a', name: 'Room A', participants: [] },
        { boId: 'bo_spare1', name: 'Spare 1', participants: [] },
      ],
      unassigned: [
        { uid: 'zoom_hub_bot_lane_1', userId: 1 },        // host bot — must stay
        { uid: '', userId: 99, name: 'Random Visitor' },  // unknown — must be swept
      ],
    });

    expect(actions).toEqual([
      {
        action: 'assign',
        uid: 'Random Visitor',
        userId: 99,
        fromRoomName: '',
        targetRoomName: 'Spare 1',
        targetRoomId: 'bo_spare1',
        fallback: 'spare',
      },
    ]);
  });

  test('never sweeps the host bot out of the main session', () => {
    const actions = whoNeedsToMoveWhere({
      rooms: [{ shiftId: 'shift_a', name: 'Room A' }],
      members: [{ uid: 'zh_student_a', shiftId: 'shift_a', displayName: 'Student A' }],
    }, {
      rooms: [
        { boId: 'bo_a', name: 'Room A', participants: [] },
        { boId: 'bo_spare1', name: 'Spare 1', participants: [] },
      ],
      // only the host bot is in main — by uid, and by host/name signals
      unassigned: [
        { uid: 'zoom_hub_bot_lane_2', userId: 16778240, userName: 'Alluwal Hub Bot Lane 2', isHost: true },
      ],
    });
    expect(actions).toEqual([]);
  });

  test('sweeps students waiting in main into their room the moment it exists', () => {
    // The "admin creates a room while people wait in main" case: once the class
    // room appears in the live state, waiting main-session students are moved in.
    const actions = whoNeedsToMoveWhere({
      rooms: [{ shiftId: 'shift_a', name: 'Room A' }],
      members: [
        { uid: 'zh_teacher', shiftId: 'shift_a', displayName: 'Teacher' },
        { uid: 'zh_student', shiftId: 'shift_a', displayName: 'Student' },
      ],
    }, {
      rooms: [{ boId: 'bo_a', name: 'Room A', participants: [] }],
      unassigned: [
        { uid: 'zh_teacher', userId: 10 },
        { uid: 'zh_student', userId: 11 },
      ],
    });
    expect(actions).toEqual([
      { action: 'assign', uid: 'zh_teacher', userId: 10, fromRoomName: '', targetRoomName: 'Room A', targetRoomId: 'bo_a' },
      { action: 'assign', uid: 'zh_student', userId: 11, fromRoomName: '', targetRoomName: 'Room A', targetRoomId: 'bo_a' },
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
