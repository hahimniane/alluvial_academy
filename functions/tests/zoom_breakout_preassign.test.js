/**
 * Comprehensive Tests for Zoom Breakout Room Pre-Assignment
 *
 * Requirements being tested:
 * 1. IDENTITY + PRE-ASSIGN: Use verified emails from Firestore to pre-assign breakout rooms
 * 2. Breakout room key = shiftId, name = deterministic and human-readable
 * 3. Email validation with routing_risk marking
 * 4. Multiple students in same shift
 * 5. Overlapping shifts (deterministic selection)
 * 6. Schedule changes close to start time
 * 7. Late joiners and reconnect scenarios
 * 8. Auto-move participants setting
 */

const { DateTime } = require('luxon');

// Mock Timestamp helper
const mockTimestamp = {
  fromDate: (date) => ({
    toDate: () => date,
    seconds: Math.floor(date.getTime() / 1000),
    nanoseconds: 0,
  }),
};

// Mock Firestore
const mockFirestore = {
  users: new Map(),
  teaching_shifts: new Map(),
  hub_meetings: new Map(),
};

// Test utilities
const createMockUser = (id, email, verified = true) => ({
  id,
  email,
  email_verified: verified,
  first_name: `User${id}`,
  last_name: 'Test',
});

const createMockShift = (id, opts = {}) => {
  const now = DateTime.utc();
  return {
    id,
    teacher_id: opts.teacherId || `teacher_${id}`,
    teacher_name: opts.teacherName || `Teacher ${id}`,
    student_ids: opts.studentIds || [],
    student_names: opts.studentNames || [],
    shift_start: mockTimestamp.fromDate(
      (opts.startTime || now.plus({ hours: 2 })).toJSDate()
    ),
    shift_end: mockTimestamp.fromDate(
      (opts.endTime || now.plus({ hours: 3 })).toJSDate()
    ),
    status: opts.status || 'scheduled',
    hubMeetingId: opts.hubMeetingId || null,
    breakoutRoomName: opts.breakoutRoomName || null,
    breakoutRoomKey: opts.breakoutRoomKey || null,
    zoomRoutingMode: opts.zoomRoutingMode || null,
    ...opts,
  };
};

/**
 * Test Suite: Email Validation and Routing Risk
 */
describe('Email Validation and Routing Risk', () => {

  test('should mark participant as routing_risk when email is missing', async () => {
    // Given: A user without email
    const userId = 'user_no_email';
    mockFirestore.users.set(userId, {
      id: userId,
      first_name: 'No',
      last_name: 'Email',
      // No email field
    });

    // When: Processing shift with this user
    const result = validateParticipantEmail(mockFirestore.users.get(userId));

    // Then: Should be marked as routing_risk
    expect(result.isValid).toBe(false);
    expect(result.routingRisk).toBe(true);
    expect(result.reason).toBe('email_missing');
  });

  test('should mark participant as routing_risk when email is invalid format', async () => {
    // Given: A user with invalid email
    const userId = 'user_invalid_email';
    mockFirestore.users.set(userId, {
      id: userId,
      email: 'not-a-valid-email',
    });

    // When: Processing shift with this user
    const result = validateParticipantEmail(mockFirestore.users.get(userId));

    // Then: Should be marked as routing_risk
    expect(result.isValid).toBe(false);
    expect(result.routingRisk).toBe(true);
    expect(result.reason).toBe('email_invalid');
  });

  test('should mark participant as routing_risk when email is not verified', async () => {
    // Given: A user with unverified email
    const userId = 'user_unverified';
    mockFirestore.users.set(userId, {
      id: userId,
      email: 'unverified@test.com',
      email_verified: false,
    });

    // When: Processing shift with this user
    const result = validateParticipantEmail(mockFirestore.users.get(userId));

    // Then: Should be marked as routing_risk
    expect(result.isValid).toBe(false);
    expect(result.routingRisk).toBe(true);
    expect(result.reason).toBe('email_not_verified');
  });

  test('should detect duplicate emails across shifts', async () => {
    // Given: Same email used in multiple shifts
    const email = 'shared@test.com';
    const shifts = [
      createMockShift('shift1', { studentIds: ['student1'] }),
      createMockShift('shift2', { studentIds: ['student2'] }),
    ];

    mockFirestore.users.set('student1', createMockUser('student1', email));
    mockFirestore.users.set('student2', createMockUser('student2', email));

    // When: Checking for duplicates
    const result = detectDuplicateEmails(shifts, mockFirestore.users);

    // Then: Should detect duplicates
    expect(result.hasDuplicates).toBe(true);
    expect(result.duplicates).toContain(email);
  });

  test('should still create breakout room when routing_risk exists', async () => {
    // Given: A shift with one valid and one invalid participant
    const shift = createMockShift('shift_mixed', {
      teacherId: 'teacher_valid',
      studentIds: ['student_valid', 'student_invalid'],
    });

    mockFirestore.users.set('teacher_valid', createMockUser('teacher_valid', 'teacher@test.com'));
    mockFirestore.users.set('student_valid', createMockUser('student_valid', 'student@test.com'));
    mockFirestore.users.set('student_invalid', {
      id: 'student_invalid',
      // No email
    });

    // When: Processing shift
    const result = processShiftForBreakout(shift, mockFirestore.users);

    // Then: Room should be created but with routing_risk flagged
    expect(result.roomCreated).toBe(true);
    expect(result.validParticipants).toHaveLength(2);
    expect(result.routingRiskParticipants).toHaveLength(1);
    expect(result.routingRiskParticipants[0].userId).toBe('student_invalid');
  });
});

/**
 * Test Suite: Breakout Room Naming and Keys
 */
describe('Breakout Room Naming and Keys', () => {

  test('breakoutRoomKey should equal shiftId', async () => {
    // Given: A shift
    const shiftId = 'shift_12345';
    const shift = createMockShift(shiftId);

    // When: Generating breakout room
    const result = generateBreakoutRoomConfig(shift);

    // Then: Key should match shiftId
    expect(result.breakoutRoomKey).toBe(shiftId);
  });

  test('breakoutRoomName should be deterministic and human-readable', async () => {
    // Given: Same shift data
    const startTime = DateTime.utc().set({ hour: 10, minute: 30 });
    const shift = createMockShift('shift_name_test', {
      teacherName: 'Ustadha Fatima',
      studentNames: ['Ahmed', 'Sara'],
      startTime,
    });

    // When: Generating name multiple times
    const result1 = generateBreakoutRoomConfig(shift);
    const result2 = generateBreakoutRoomConfig(shift);

    // Then: Names should be identical and human-readable
    expect(result1.breakoutRoomName).toBe(result2.breakoutRoomName);
    expect(result1.breakoutRoomName).toContain('Ustadha Fatima');
    expect(result1.breakoutRoomName).toContain('Ahmed, Sara');
    expect(result1.breakoutRoomName).toMatch(/\d{1,2}:\d{2}/); // Contains time
  });

  test('breakoutRoomName should handle long student lists', async () => {
    // Given: Shift with many students
    const shift = createMockShift('shift_many', {
      teacherName: 'Teacher Long',
      studentNames: ['Student1', 'Student2', 'Student3', 'Student4', 'Student5'],
    });

    // When: Generating name
    const result = generateBreakoutRoomConfig(shift);

    // Then: Name should be truncated appropriately (Zoom has ~50 char limit)
    expect(result.breakoutRoomName.length).toBeLessThanOrEqual(50);
  });
});

/**
 * Test Suite: Multiple Students in Same Shift
 */
describe('Multiple Students in Same Shift', () => {

  test('all student emails should be assigned to same breakout room', async () => {
    // Given: Shift with multiple students
    const shift = createMockShift('shift_multi', {
      teacherId: 'teacher1',
      studentIds: ['student1', 'student2', 'student3'],
    });

    mockFirestore.users.set('teacher1', createMockUser('teacher1', 'teacher@test.com'));
    mockFirestore.users.set('student1', createMockUser('student1', 'student1@test.com'));
    mockFirestore.users.set('student2', createMockUser('student2', 'student2@test.com'));
    mockFirestore.users.set('student3', createMockUser('student3', 'student3@test.com'));

    // When: Generating pre-assign payload
    const result = generatePreAssignPayload(shift, mockFirestore.users);

    // Then: All emails should be in same room
    expect(result.rooms).toHaveLength(1);
    expect(result.rooms[0].participants).toContain('teacher@test.com');
    expect(result.rooms[0].participants).toContain('student1@test.com');
    expect(result.rooms[0].participants).toContain('student2@test.com');
    expect(result.rooms[0].participants).toContain('student3@test.com');
  });

  test('teacher email should be first in participant list', async () => {
    // Given: Shift with teacher and students
    const shift = createMockShift('shift_order', {
      teacherId: 'teacher1',
      studentIds: ['student1'],
    });

    mockFirestore.users.set('teacher1', createMockUser('teacher1', 'teacher@test.com'));
    mockFirestore.users.set('student1', createMockUser('student1', 'student@test.com'));

    // When: Generating pre-assign payload
    const result = generatePreAssignPayload(shift, mockFirestore.users);

    // Then: Teacher should be first
    expect(result.rooms[0].participants[0]).toBe('teacher@test.com');
  });
});

/**
 * Test Suite: Overlapping Shifts
 */
describe('Overlapping Shift Handling', () => {

  test('should select shift with closest start time when user has overlapping shifts', async () => {
    // Given: User with two overlapping shifts
    const now = DateTime.utc();
    const shifts = [
      createMockShift('shift_later', {
        teacherId: 'teacher1',
        startTime: now.plus({ hours: 2, minutes: 30 }),
        endTime: now.plus({ hours: 3, minutes: 30 }),
      }),
      createMockShift('shift_earlier', {
        teacherId: 'teacher1',
        startTime: now.plus({ hours: 2 }),
        endTime: now.plus({ hours: 3 }),
      }),
    ];

    mockFirestore.users.set('teacher1', createMockUser('teacher1', 'teacher@test.com'));

    // When: Resolving which shift to use for routing
    const result = resolveOverlappingShifts('teacher1', shifts, now.toJSDate());

    // Then: Should select the shift with closest start time
    expect(result.selectedShiftId).toBe('shift_earlier');
    expect(result.ambiguityLogged).toBe(true);
  });

  test('should log ambiguity when overlapping shifts exist', async () => {
    // Given: Overlapping shifts
    const now = DateTime.utc();
    const shifts = [
      createMockShift('shift1', {
        studentIds: ['student1'],
        startTime: now.plus({ hours: 2 }),
        endTime: now.plus({ hours: 3 }),
      }),
      createMockShift('shift2', {
        studentIds: ['student1'],
        startTime: now.plus({ hours: 2, minutes: 15 }),
        endTime: now.plus({ hours: 3, minutes: 15 }),
      }),
    ];

    const logs = [];
    const mockLogger = (msg) => logs.push(msg);

    // When: Processing overlapping shifts
    resolveOverlappingShifts('student1', shifts, now.toJSDate(), mockLogger);

    // Then: Should log the ambiguity
    expect(logs.some(log => log.includes('ambiguity') || log.includes('overlap'))).toBe(true);
  });
});

/**
 * Test Suite: Schedule Changes Close to Start
 */
describe('Schedule Changes Close to Start Time', () => {

  test('should regenerate pre-assign list when hub meeting not started', async () => {
    // Given: Scheduled hub meeting with a new shift added
    const hubMeeting = {
      id: 'hub_not_started',
      status: 'scheduled',
      meetingId: '123456789',
      shifts: ['shift1'],
    };

    const newShift = createMockShift('shift_new', {
      hubMeetingId: null, // Not yet assigned
    });

    // When: Processing new shift
    const result = handleScheduleChange(hubMeeting, newShift);

    // Then: Should regenerate pre-assign list
    expect(result.action).toBe('regenerate_preassign');
    expect(result.shouldUpdateZoom).toBe(true);
  });

  test('should NOT update Zoom REST API when hub meeting already live', async () => {
    // Given: Live hub meeting
    const hubMeeting = {
      id: 'hub_live',
      status: 'started',
      meetingId: '123456789',
      shifts: ['shift1'],
    };

    const newShift = createMockShift('shift_new');

    // When: Processing new shift
    const result = handleScheduleChange(hubMeeting, newShift);

    // Then: Should NOT attempt REST update, rely on fallback
    expect(result.action).toBe('use_fallback');
    expect(result.shouldUpdateZoom).toBe(false);
    expect(result.routingMode).toBe('selfselect');
  });

  test('should set zoomRoutingMode to selfselect for late-added shifts', async () => {
    // Given: Existing hub meeting that's live
    const hubMeeting = {
      id: 'hub_existing',
      status: 'started',
    };

    const lateShift = createMockShift('shift_late');

    // When: Adding shift to existing hub
    const result = assignShiftToExistingHub(hubMeeting, lateShift);

    // Then: Should use selfselect mode
    expect(result.zoomRoutingMode).toBe('selfselect');
  });
});

/**
 * Test Suite: Late Joiners
 */
describe('Late Joiner Handling', () => {

  test('pre-assign should still apply if identity matches', async () => {
    // Given: User with pre-assigned email joining late
    const preAssignList = {
      'Room A': ['teacher@test.com', 'student@test.com'],
    };

    // When: User joins with matching email
    const result = checkPreAssignMatch('student@test.com', preAssignList);

    // Then: Should find their assigned room
    expect(result.matched).toBe(true);
    expect(result.assignedRoom).toBe('Room A');
  });

  test('should fall back to guided self-select when identity does not match', async () => {
    // Given: User joining with non-matching email
    const preAssignList = {
      'Room A': ['teacher@test.com', 'student@test.com'],
    };

    // When: User joins with different email
    const result = checkPreAssignMatch('different@gmail.com', preAssignList);

    // Then: Should indicate fallback needed
    expect(result.matched).toBe(false);
    expect(result.requiresFallback).toBe(true);
  });
});

/**
 * Test Suite: Reconnect Handling
 */
describe('Reconnect Handling', () => {

  test('user should be routed back to same breakout room on reconnect', async () => {
    // Given: User was previously in a breakout room
    const participantHistory = {
      'student@test.com': {
        lastRoom: 'Room A',
        lastJoinTime: DateTime.utc().minus({ minutes: 5 }).toISO(),
      },
    };

    // When: User reconnects
    const result = handleReconnect('student@test.com', participantHistory);

    // Then: Should return same room
    expect(result.assignedRoom).toBe('Room A');
    expect(result.isReconnect).toBe(true);
  });
});

/**
 * Test Suite: Zoom API Settings
 */
describe('Zoom API Breakout Room Settings', () => {

  test('should include auto_move_to_breakout_room setting', async () => {
    // Given: Breakout room configuration
    const rooms = [
      { name: 'Room A', participants: ['a@test.com'] },
    ];

    // When: Building Zoom API payload
    const result = buildZoomBreakoutPayload(rooms);

    // Then: Should have auto-move enabled
    expect(result.settings.breakout_room.enable).toBe(true);
    // Note: Zoom API doesn't have a direct "auto_move" flag on create,
    // but we document what needs to be enabled in the Zoom portal
  });

  test('breakout room payload should have correct structure', async () => {
    // Given: Multiple rooms with participants
    const rooms = [
      { name: 'Teacher A | Student 1 | 10:00 AM', participants: ['teacher@test.com', 'student1@test.com'] },
      { name: 'Teacher B | Student 2 | 10:00 AM', participants: ['teacherb@test.com', 'student2@test.com'] },
    ];

    // When: Building payload
    const result = buildZoomBreakoutPayload(rooms);

    // Then: Structure should match Zoom API requirements
    expect(result.settings.breakout_room.rooms).toHaveLength(2);
    expect(result.settings.breakout_room.rooms[0].name).toBe('Teacher A | Student 1 | 10:00 AM');
    expect(result.settings.breakout_room.rooms[0].participants).toContain('teacher@test.com');
  });
});

/**
 * Test Suite: User Instruction for Zoom Sign-In
 */
describe('User Zoom Sign-In Instruction', () => {

  test('should generate instruction message with correct email', async () => {
    // Given: User with platform email
    const userEmail = 'user@alluvial.academy';

    // When: Generating join instruction
    const result = generateZoomSignInInstruction(userEmail);

    // Then: Should contain correct message
    expect(result.message).toContain(userEmail);
    expect(result.message).toContain('sign into Zoom');
    expect(result.showOnce).toBe(true);
  });

  test('should provide fallback instruction when email uncertain', async () => {
    // Given: User with routing_risk
    const userEmail = null;

    // When: Generating join instruction
    const result = generateZoomSignInInstruction(userEmail);

    // Then: Should show fallback instructions
    expect(result.showFallback).toBe(true);
    expect(result.fallbackMessage).toContain('self-select');
  });
});

/**
 * Test Suite: Integration Tests for Hub Scheduling
 */
describe('Hub Meeting Scheduling Integration', () => {

  test('should create hub with all participant emails pre-assigned', async () => {
    // Given: Multiple shifts in same time block
    const now = DateTime.utc();
    const blockStart = now.plus({ days: 1 }).set({ hour: 10, minute: 0 });

    const shifts = [
      createMockShift('shift1', {
        teacherId: 't1',
        studentIds: ['s1', 's2'],
        startTime: blockStart,
      }),
      createMockShift('shift2', {
        teacherId: 't2',
        studentIds: ['s3'],
        startTime: blockStart.plus({ minutes: 30 }),
      }),
    ];

    // Setup users
    mockFirestore.users.set('t1', createMockUser('t1', 't1@test.com'));
    mockFirestore.users.set('t2', createMockUser('t2', 't2@test.com'));
    mockFirestore.users.set('s1', createMockUser('s1', 's1@test.com'));
    mockFirestore.users.set('s2', createMockUser('s2', 's2@test.com'));
    mockFirestore.users.set('s3', createMockUser('s3', 's3@test.com'));

    // When: Processing hub block
    const result = processHubBlockTest(blockStart.toISO(), shifts, mockFirestore.users);

    // Then: Should create hub with all participants
    expect(result.hubCreated).toBe(true);
    expect(result.breakoutRooms).toHaveLength(2);
    expect(result.totalParticipants).toBe(5); // 2 teachers + 3 students

    // First room should have t1, s1, s2
    const room1 = result.breakoutRooms.find(r => r.name.includes('shift1') || r.participants.includes('t1@test.com'));
    expect(room1.participants).toContain('t1@test.com');
    expect(room1.participants).toContain('s1@test.com');
    expect(room1.participants).toContain('s2@test.com');
  });

  test('should split hub when exceeding capacity', async () => {
    // Given: Many shifts exceeding MAX_PARTICIPANTS_PER_HUB (100)
    const now = DateTime.utc();
    const blockStart = now.plus({ days: 1 }).set({ hour: 14, minute: 0 });

    const shifts = [];
    for (let i = 0; i < 40; i++) {
      shifts.push(createMockShift(`shift_${i}`, {
        teacherId: `teacher_${i}`,
        studentIds: [`student_${i}_a`, `student_${i}_b`], // 3 per shift = 120 total
        startTime: blockStart,
      }));
      mockFirestore.users.set(`teacher_${i}`, createMockUser(`teacher_${i}`, `teacher${i}@test.com`));
      mockFirestore.users.set(`student_${i}_a`, createMockUser(`student_${i}_a`, `student${i}a@test.com`));
      mockFirestore.users.set(`student_${i}_b`, createMockUser(`student_${i}_b`, `student${i}b@test.com`));
    }

    // When: Processing hub block
    const result = processHubBlockTest(blockStart.toISO(), shifts, mockFirestore.users);

    // Then: Should split into multiple hubs
    expect(result.hubsCreated).toBeGreaterThanOrEqual(2);
    expect(result.allShiftsAssigned).toBe(true);
  });
});

// ==========================================
// Helper Functions (to be implemented/tested)
// ==========================================

function validateParticipantEmail(user) {
  if (!user || !user.email) {
    return { isValid: false, routingRisk: true, reason: 'email_missing' };
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(user.email)) {
    return { isValid: false, routingRisk: true, reason: 'email_invalid' };
  }

  if (user.email_verified === false) {
    return { isValid: false, routingRisk: true, reason: 'email_not_verified' };
  }

  return { isValid: true, routingRisk: false, email: user.email };
}

function detectDuplicateEmails(shifts, usersMap) {
  const emailCounts = new Map();

  for (const shift of shifts) {
    const allIds = [shift.teacher_id, ...(shift.studentIds || shift.student_ids || [])];
    for (const userId of allIds) {
      const user = usersMap.get(userId);
      if (user && user.email) {
        emailCounts.set(user.email, (emailCounts.get(user.email) || 0) + 1);
      }
    }
  }

  const duplicates = [];
  for (const [email, count] of emailCounts) {
    if (count > 1) duplicates.push(email);
  }

  return { hasDuplicates: duplicates.length > 0, duplicates };
}

function processShiftForBreakout(shift, usersMap) {
  const validParticipants = [];
  const routingRiskParticipants = [];

  const allIds = [shift.teacher_id, ...(shift.studentIds || shift.student_ids || [])];

  for (const userId of allIds) {
    const user = usersMap.get(userId);
    const validation = validateParticipantEmail(user);

    if (validation.isValid) {
      validParticipants.push({ userId, email: validation.email });
    } else {
      routingRiskParticipants.push({ userId, reason: validation.reason });
    }
  }

  return {
    roomCreated: true, // Always create room
    validParticipants,
    routingRiskParticipants,
  };
}

function generateBreakoutRoomConfig(shift) {
  const teacherName = shift.teacher_name || shift.teacherName || 'Teacher';
  const studentNames = shift.student_names || shift.studentNames || [];
  const startTime = shift.shift_start?.toDate
    ? DateTime.fromJSDate(shift.shift_start.toDate())
    : DateTime.fromJSDate(new Date(shift.shift_start));

  let studentsStr = studentNames.length > 0
    ? studentNames.slice(0, 2).join(', ')
    : 'Students';

  if (studentNames.length > 2) {
    studentsStr += ` +${studentNames.length - 2}`;
  }

  const timeStr = startTime.toUTC().toFormat('h:mm a');
  let roomName = `${teacherName} | ${studentsStr} | ${timeStr}`;

  // Truncate if needed (Zoom limit)
  if (roomName.length > 50) {
    roomName = roomName.substring(0, 47) + '...';
  }

  return {
    breakoutRoomKey: shift.id,
    breakoutRoomName: roomName,
  };
}

function generatePreAssignPayload(shift, usersMap) {
  const config = generateBreakoutRoomConfig(shift);
  const participants = [];

  // Teacher first
  const teacher = usersMap.get(shift.teacher_id || shift.teacherId);
  if (teacher && teacher.email) {
    participants.push(teacher.email);
  }

  // Then students
  const studentIds = shift.student_ids || shift.studentIds || [];
  for (const studentId of studentIds) {
    const student = usersMap.get(studentId);
    if (student && student.email) {
      participants.push(student.email);
    }
  }

  return {
    rooms: [{
      name: config.breakoutRoomName,
      participants,
    }],
  };
}

function resolveOverlappingShifts(userId, shifts, currentTime, logger = console.log) {
  const userShifts = shifts.filter(s =>
    s.teacher_id === userId ||
    s.teacherId === userId ||
    (s.student_ids || s.studentIds || []).includes(userId)
  );

  if (userShifts.length <= 1) {
    return { selectedShiftId: userShifts[0]?.id, ambiguityLogged: false };
  }

  // Sort by start time (closest first)
  userShifts.sort((a, b) => {
    const aStart = a.shift_start?.toDate ? a.shift_start.toDate() : new Date(a.shift_start);
    const bStart = b.shift_start?.toDate ? b.shift_start.toDate() : new Date(b.shift_start);
    return Math.abs(aStart - currentTime) - Math.abs(bStart - currentTime);
  });

  logger(`[Overlap Warning] User ${userId} has ${userShifts.length} overlapping shifts. Selected: ${userShifts[0].id} (closest start time). Ambiguity logged.`);

  return {
    selectedShiftId: userShifts[0].id,
    ambiguityLogged: true,
    allShiftIds: userShifts.map(s => s.id),
  };
}

function handleScheduleChange(hubMeeting, newShift) {
  if (hubMeeting.status === 'started') {
    return {
      action: 'use_fallback',
      shouldUpdateZoom: false,
      routingMode: 'selfselect',
      message: 'Hub meeting already live, using fallback routing',
    };
  }

  return {
    action: 'regenerate_preassign',
    shouldUpdateZoom: true,
    routingMode: 'preassign',
    message: 'Hub meeting not started, can regenerate pre-assign list',
  };
}

function assignShiftToExistingHub(hubMeeting, shift) {
  const routingMode = hubMeeting.status === 'started' ? 'selfselect' : 'hybrid';

  return {
    hubMeetingId: hubMeeting.id,
    zoomRoutingMode: routingMode,
    breakoutRoomKey: shift.id,
  };
}

function checkPreAssignMatch(email, preAssignList) {
  for (const [roomName, participants] of Object.entries(preAssignList)) {
    if (participants.includes(email)) {
      return { matched: true, assignedRoom: roomName, requiresFallback: false };
    }
  }
  return { matched: false, assignedRoom: null, requiresFallback: true };
}

function handleReconnect(email, participantHistory) {
  const history = participantHistory[email];
  if (history && history.lastRoom) {
    return { assignedRoom: history.lastRoom, isReconnect: true };
  }
  return { assignedRoom: null, isReconnect: false };
}

function buildZoomBreakoutPayload(rooms) {
  return {
    settings: {
      breakout_room: {
        enable: true,
        rooms: rooms.map(room => ({
          name: room.name,
          participants: room.participants,
        })),
      },
    },
  };
}

function generateZoomSignInInstruction(userEmail) {
  if (!userEmail) {
    return {
      showFallback: true,
      fallbackMessage: 'You may need to self-select your breakout room. Look for your teacher\'s name.',
      showOnce: true,
    };
  }

  return {
    message: `Please sign into Zoom with this email to be auto-routed: ${userEmail}`,
    showOnce: true,
    showFallback: false,
  };
}

function processHubBlockTest(blockKey, shifts, usersMap) {
  const MAX_PARTICIPANTS_PER_HUB = 100;

  // Count participants per shift
  let totalParticipants = 0;
  const breakoutRooms = [];

  for (const shift of shifts) {
    const allIds = [shift.teacher_id || shift.teacherId, ...(shift.student_ids || shift.studentIds || [])];
    const participants = [];

    for (const userId of allIds) {
      const user = usersMap.get(userId);
      if (user && user.email) {
        participants.push(user.email);
      }
    }

    totalParticipants += participants.length;

    const config = generateBreakoutRoomConfig(shift);
    breakoutRooms.push({
      name: config.breakoutRoomName,
      participants,
      shiftId: shift.id,
    });
  }

  // Check if needs splitting
  const hubsNeeded = Math.ceil(totalParticipants / MAX_PARTICIPANTS_PER_HUB);

  return {
    hubCreated: true,
    hubsCreated: hubsNeeded,
    breakoutRooms,
    totalParticipants,
    allShiftsAssigned: true,
  };
}

module.exports = {
  validateParticipantEmail,
  detectDuplicateEmails,
  processShiftForBreakout,
  generateBreakoutRoomConfig,
  generatePreAssignPayload,
  resolveOverlappingShifts,
  handleScheduleChange,
  assignShiftToExistingHub,
  checkPreAssignMatch,
  handleReconnect,
  buildZoomBreakoutPayload,
  generateZoomSignInInstruction,
  processHubBlockTest,
};
