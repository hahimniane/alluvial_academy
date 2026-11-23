/**
 * Telling, from inside the hub page, that its Zoom connection is dead.
 *
 * The Zoom Web SDK can lose its connection to Zoom and never get it back. It
 * does not reconnect and it does not fail the calls already waiting on it: a
 * `ZoomMtg.getBreakoutRooms({success, error})` simply never calls back. On
 * 2026-11-20 that happened four times (lane 1 at 16:59 and 20:38 UTC, lane 3 at
 * 17:14 and 19:14). The routing loop waited on the call forever, stopped
 * printing routing snapshots, and only the three-minute silence check in
 * liveness.js noticed. With the 150s ghost-host hold after it, each lane was
 * dark for 6-7 minutes with teachers waiting in the lobby.
 *
 * So every Zoom call gets a deadline, and a call that misses it is evidence. A
 * read the routing loop makes every few seconds answers from the SDK's own
 * state in milliseconds when the SDK is alive, so one that hangs for 20s means
 * the SDK is gone. A slow write (creating rooms, moving a person) is weaker
 * evidence and takes repeats.
 *
 * The other way the connection dies was reproduced on 2026-11-23 by cutting a
 * lane's traffic to Zoom: about 30s later every read fails with "Current user
 * is neither host nor cohost" and keeps failing. Failing reads that carry that
 * kind of message, for 15s straight with no call succeeding in between, are the
 * same verdict.
 *
 * What this never does: recycle on one slow call while people are in rooms and
 * Zoom is otherwise answering. One success resets everything. With people in
 * rooms a single unanswered read is not enough — it takes two in a row, or one
 * while the SDK is printing that its socket is gone. Moves and assigns never
 * count: in 6.2.0 a room-to-room move works but never calls back.
 *
 * Shared by the page (window.ZoomHubSdkHealth) and the tests (module.exports).
 */
(function initSdkHealth(root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.ZoomHubSdkHealth = factory();
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function sdkHealthFactory() {
  const DEFAULT_CALL_TIMEOUT_MS = 20 * 1000;
  // Calls that legitimately take a while on a big hub: creating 40 rooms, or
  // opening/closing them, is a round trip per room inside the SDK.
  const SLOW_CALL_TIMEOUT_MS = {
    createBreakoutRoom: 60 * 1000,
    openBreakoutRooms: 60 * 1000,
    closeBreakoutRooms: 60 * 1000,
  };
  // Moving a person who is already in a room completes but its callback never
  // fires (Zoom Web SDK 6.2.0, measured 2026-11-23 on a throwaway meeting: the
  // person arrived in the target room, the call never answered). So these get
  // a short deadline, purely to keep the loop moving, and their silence is not
  // evidence of anything.
  const UNANSWERED_BY_DESIGN = new Set([
    'moveUserToBreakoutRoom',
    'assignUserToBreakoutRoom',
  ]);
  const UNANSWERED_BY_DESIGN_TIMEOUT_MS = 10 * 1000;
  // Reads the SDK answers from its own state. When one of these hangs the SDK
  // is not slow, it is gone.
  const BASIC_READS = new Set([
    'getBreakoutRooms',
    'getAttendeeslist',
    'getBreakoutRoomStatus',
    'getCurrentUser',
  ]);
  // What the SDK says once it has lost the meeting underneath the page.
  const LOST_CONNECTION_PATTERN = /neither host nor cohost|sendSocket|not in meeting|disconnect|reconnect/i;
  const SOCKET_ERROR_MARKER = "reading 'sendSocket'";

  const CONSECUTIVE_TIMEOUTS_LIMIT = 3;
  const LOST_READS_LIMIT = 4;
  const LOST_READS_MIN_SPAN_MS = 15 * 1000;
  const SOCKET_ERROR_RECENT_MS = 60 * 1000;

  // What the page prints when it gives up on its connection. bot.js watches the
  // console for it and recycles the page on the spot.
  const DEAD_MARKER = 'Zoom connection dead:';

  function callTimeoutMs(method) {
    if (UNANSWERED_BY_DESIGN.has(method)) return UNANSWERED_BY_DESIGN_TIMEOUT_MS;
    return SLOW_CALL_TIMEOUT_MS[method] || DEFAULT_CALL_TIMEOUT_MS;
  }

  function errorText(error) {
    if (!error) return '';
    if (typeof error === 'string') return error;
    const parts = [error.errorMessage, error.message, error.reason];
    try {
      parts.push(JSON.stringify(error));
    } catch (_) {}
    return parts.filter(Boolean).join(' ');
  }

  function looksLikeLostConnection(error) {
    return LOST_CONNECTION_PATTERN.test(errorText(error));
  }

  /**
   * One tracker per page. `record` takes each Zoom call's outcome and returns
   * the verdict: `{ dead: true, reason }` once the connection is judged gone.
   * Nothing is judged until `arm()` — a page still joining has its own failure
   * path (the join error), and its reads are expected to fail.
   */
  function createTracker() {
    const state = {
      armed: false,
      occupied: false,
      lastSuccessAt: -Infinity,
      consecutiveTimeouts: 0,
      readTimeoutStreak: 0,
      lostReads: 0,
      lostReadsSince: null,
      lastSocketErrorAt: 0,
      verdict: null,
    };

    function decide(reason) {
      state.verdict = { dead: true, reason };
      return state.verdict;
    }

    function record(method, outcome, detail = {}) {
      if (state.verdict) return state.verdict;
      const at = Number.isFinite(detail.at) ? detail.at : Date.now();
      const startedAt = Number.isFinite(detail.startedAt) ? detail.startedAt : at;
      if (outcome === 'ok') {
        state.lastSuccessAt = at;
        state.consecutiveTimeouts = 0;
        state.readTimeoutStreak = 0;
        state.lostReads = 0;
        state.lostReadsSince = null;
        return { dead: false };
      }
      if (!state.armed) return { dead: false };
      // Something else got an answer while this call was waiting: Zoom is
      // slow on this one call, not gone.
      const nothingSucceededMeanwhile = state.lastSuccessAt < startedAt;

      if (outcome === 'timeout') {
        if (UNANSWERED_BY_DESIGN.has(method)) return { dead: false };
        state.consecutiveTimeouts += 1;
        const seconds = Math.round((at - startedAt) / 1000);
        // The SDK printing that its socket is gone is the fast signal: with it,
        // one unanswered read is enough even with people in rooms.
        const socketRecentlyLost = state.lastSocketErrorAt > 0 &&
          at - state.lastSocketErrorAt <= SOCKET_ERROR_RECENT_MS;
        if (BASIC_READS.has(method) && nothingSucceededMeanwhile) {
          state.readTimeoutStreak += 1;
          const needed = state.occupied && !socketRecentlyLost ? 2 : 1;
          if (state.readTimeoutStreak >= needed) {
            return decide(`${method} got no answer in ${seconds}s (${state.readTimeoutStreak} in a row)`);
          }
        }
        if (state.consecutiveTimeouts >= CONSECUTIVE_TIMEOUTS_LIMIT) {
          return decide(`${state.consecutiveTimeouts} Zoom calls in a row got no answer (last: ${method})`);
        }
        if (socketRecentlyLost && nothingSucceededMeanwhile && state.consecutiveTimeouts >= 2) {
          return decide(`${method} got no answer in ${seconds}s right after the SDK lost its socket`);
        }
        return { dead: false };
      }

      // outcome === 'error'
      if (method === 'getBreakoutRooms' && looksLikeLostConnection(detail.error)) {
        if (state.lostReadsSince === null) state.lostReadsSince = startedAt;
        state.lostReads += 1;
        const spanMs = at - state.lostReadsSince;
        if (state.lostReads >= LOST_READS_LIMIT && spanMs >= LOST_READS_MIN_SPAN_MS) {
          const message = String((detail.error && detail.error.errorMessage) || errorText(detail.error)).slice(0, 120);
          return decide(`breakout rooms unreadable for ${Math.round(spanMs / 1000)}s (${message})`);
        }
      }
      return { dead: false };
    }

    return {
      arm() { state.armed = true; },
      setOccupied(occupied) { state.occupied = Boolean(occupied); },
      noteSocketError(at = Date.now()) { state.lastSocketErrorAt = at; },
      record,
      verdict() { return state.verdict; },
      snapshot() { return { ...state }; },
    };
  }

  return {
    DEFAULT_CALL_TIMEOUT_MS,
    SLOW_CALL_TIMEOUT_MS,
    BASIC_READS,
    UNANSWERED_BY_DESIGN,
    DEAD_MARKER,
    SOCKET_ERROR_MARKER,
    CONSECUTIVE_TIMEOUTS_LIMIT,
    LOST_READS_LIMIT,
    LOST_READS_MIN_SPAN_MS,
    SOCKET_ERROR_RECENT_MS,
    callTimeoutMs,
    createTracker,
    looksLikeLostConnection,
  };
});
