const {
  DEAD_MARKER,
  DEFAULT_CALL_TIMEOUT_MS,
  callTimeoutMs,
  createTracker,
  looksLikeLostConnection,
} = require('../sdk_health');

const LOST_HOST = {
  method: 'getBreakoutRoomList',
  status: false,
  errorCode: 1,
  errorMessage: 'Current user is neither host nor cohost',
  result: null,
};

function armed() {
  const tracker = createTracker();
  tracker.arm();
  return tracker;
}

describe('call deadlines', () => {
  test('ordinary calls get ~20s, room-building calls more', () => {
    expect(callTimeoutMs('getBreakoutRooms')).toBe(DEFAULT_CALL_TIMEOUT_MS);
    expect(DEFAULT_CALL_TIMEOUT_MS).toBe(20000);
    expect(callTimeoutMs('createBreakoutRoom')).toBeGreaterThan(DEFAULT_CALL_TIMEOUT_MS);
    expect(callTimeoutMs('openBreakoutRooms')).toBeGreaterThan(DEFAULT_CALL_TIMEOUT_MS);
    expect(callTimeoutMs('closeBreakoutRooms')).toBeGreaterThan(DEFAULT_CALL_TIMEOUT_MS);
  });

  test('the marker bot.js watches for is the one the page prints', () => {
    expect(DEAD_MARKER).toBe('Zoom connection dead:');
  });
});

describe('a hung SDK (2026-11-20: calls never answered, routing stalled)', () => {
  test('one read with no answer and nothing else succeeding is a dead connection', () => {
    const tracker = armed();
    tracker.record('getAssignments-is-not-zoom', 'ok', { at: 0 });
    const verdict = tracker.record('getBreakoutRooms', 'timeout', { startedAt: 1000, at: 21000 });
    expect(verdict.dead).toBe(true);
    expect(verdict.reason).toMatch(/getBreakoutRooms got no answer in 20s/);
  });

  test('with people in rooms one read timeout is not enough; two in a row are', () => {
    const tracker = armed();
    tracker.setOccupied(true);
    expect(tracker.record('getBreakoutRooms', 'timeout', { startedAt: 1000, at: 21000 }).dead).toBe(false);
    expect(tracker.record('getBreakoutRooms', 'timeout', { startedAt: 24000, at: 44000 }).dead).toBe(true);
  });

  test('a slow read is forgiven when another call got an answer meanwhile', () => {
    const tracker = armed();
    tracker.record('assignUserToBreakoutRoom', 'ok', { startedAt: 5000, at: 6000 });
    expect(tracker.record('getBreakoutRooms', 'timeout', { startedAt: 1000, at: 21000 }).dead).toBe(false);
  });

  test('one slow write while calls otherwise succeed never recycles', () => {
    const tracker = armed();
    tracker.setOccupied(true);
    expect(tracker.record('createBreakoutRoom', 'timeout', { startedAt: 0, at: 60000 }).dead).toBe(false);
    tracker.record('getBreakoutRooms', 'ok', { startedAt: 60000, at: 60010 });
    expect(tracker.record('openBreakoutRooms', 'timeout', { startedAt: 61000, at: 121000 }).dead).toBe(false);
    tracker.record('getBreakoutRooms', 'ok', { startedAt: 121000, at: 121010 });
    expect(tracker.verdict()).toBe(null);
  });

  test('three timeouts in a row of any kind are a dead connection', () => {
    const tracker = armed();
    tracker.setOccupied(true);
    tracker.record('getBreakoutRooms', 'ok', { at: 0 });
    tracker.record('createBreakoutRoom', 'timeout', { startedAt: 10, at: 60010 });
    tracker.record('openBreakoutRooms', 'timeout', { startedAt: 60020, at: 120020 });
    const verdict = tracker.record('getBreakoutRoomOptions', 'timeout', { startedAt: 120030, at: 140030 });
    expect(verdict.dead).toBe(true);
    expect(verdict.reason).toMatch(/3 Zoom calls in a row got no answer \(last: getBreakoutRoomOptions\)/);
  });

  test('with socket errors just printed, one unanswered read is enough even with people in rooms', () => {
    const tracker = armed();
    tracker.setOccupied(true);
    tracker.noteSocketError(5000);
    const verdict = tracker.record('getBreakoutRooms', 'timeout', { startedAt: 6000, at: 26000 });
    expect(verdict.dead).toBe(true);
  });

  test('two unanswered calls in a row right after socket errors are a dead connection', () => {
    const tracker = armed();
    tracker.setOccupied(true);
    tracker.noteSocketError(5000);
    expect(tracker.record('getBreakoutRoomOptions', 'timeout', { startedAt: 6000, at: 26000 }).dead).toBe(false);
    const verdict = tracker.record('getBreakoutRoomOptions', 'timeout', { startedAt: 26000, at: 46000 });
    expect(verdict.dead).toBe(true);
    expect(verdict.reason).toMatch(/lost its socket/);
  });

  test('moves and assigns that never call back are never evidence (6.2.0 does this on a working move)', () => {
    const tracker = armed();
    tracker.noteSocketError(0);
    for (let i = 0; i < 10; i += 1) {
      expect(tracker.record('moveUserToBreakoutRoom', 'timeout', { startedAt: i * 10000, at: i * 10000 + 10000 }).dead).toBe(false);
      expect(tracker.record('assignUserToBreakoutRoom', 'timeout', { startedAt: i * 10000, at: i * 10000 + 10000 }).dead).toBe(false);
    }
    expect(tracker.verdict()).toBe(null);
    expect(callTimeoutMs('moveUserToBreakoutRoom')).toBe(10000);
  });

  test('socket errors alone decide nothing (healthy hubs print bursts of them)', () => {
    const tracker = armed();
    for (let i = 0; i < 20; i += 1) tracker.noteSocketError(i * 100);
    tracker.record('getBreakoutRooms', 'ok', { at: 3000 });
    expect(tracker.verdict()).toBe(null);
  });
});

describe('a lost meeting (2026-11-23 repro: Zoom traffic cut, reads fail)', () => {
  test('the SDK message is recognised', () => {
    expect(looksLikeLostConnection(LOST_HOST)).toBe(true);
    expect(looksLikeLostConnection(new TypeError("Cannot read properties of null (reading 'sendSocket')"))).toBe(true);
    expect(looksLikeLostConnection({ errorMessage: 'Breakout room has started!' })).toBe(false);
  });

  test('reads failing that way for 15s straight are a dead connection', () => {
    const tracker = armed();
    let verdict;
    for (let i = 0; i < 6; i += 1) {
      verdict = tracker.record('getBreakoutRooms', 'error', { startedAt: i * 3300, at: i * 3300 + 5, error: LOST_HOST });
    }
    expect(verdict.dead).toBe(true);
    expect(verdict.reason).toBe('breakout rooms unreadable for 17s (Current user is neither host nor cohost)');
  });

  test('a short run of failures that recovers is forgiven', () => {
    const tracker = armed();
    for (let i = 0; i < 3; i += 1) {
      tracker.record('getBreakoutRooms', 'error', { startedAt: i * 3300, at: i * 3300 + 5, error: LOST_HOST });
    }
    tracker.record('getBreakoutRooms', 'ok', { at: 10000 });
    for (let i = 0; i < 3; i += 1) {
      tracker.record('getBreakoutRooms', 'error', { startedAt: 11000 + i * 3300, at: 11005 + i * 3300, error: LOST_HOST });
    }
    expect(tracker.verdict()).toBe(null);
  });

  test('other errors are left to the routing-silence backstop', () => {
    const tracker = armed();
    for (let i = 0; i < 10; i += 1) {
      tracker.record('getBreakoutRooms', 'error', { startedAt: i * 3300, at: i * 3300 + 5, error: { errorMessage: 'something else' } });
    }
    expect(tracker.verdict()).toBe(null);
  });
});

describe('before the join', () => {
  test('nothing is judged until the tracker is armed', () => {
    const tracker = createTracker();
    expect(tracker.record('getBreakoutRooms', 'timeout', { startedAt: 0, at: 20000 }).dead).toBe(false);
    for (let i = 0; i < 6; i += 1) {
      tracker.record('getBreakoutRooms', 'error', { startedAt: i * 3300, at: i * 3300, error: LOST_HOST });
    }
    expect(tracker.verdict()).toBe(null);
  });

  test('once dead, the verdict stands', () => {
    const tracker = armed();
    tracker.record('getBreakoutRooms', 'timeout', { startedAt: 0, at: 20000 });
    expect(tracker.record('getBreakoutRooms', 'ok', { at: 21000 }).dead).toBe(true);
  });
});
