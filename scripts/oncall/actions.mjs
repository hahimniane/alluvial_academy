/**
 * The complete list of things the on-call responder may do without a human,
 * and the guardrails that decide whether it may do them right now.
 *
 * Everything here is deliberately plain code rather than model judgment: the
 * model chooses WHICH action to propose, this file decides whether the action
 * is allowed to happen. A model that misreads a situation can only ever pick a
 * wrong item from this list — it can never invent a new one.
 */

/** Actions the responder is allowed to take on its own. */
export const ALLOWED_ACTIONS = Object.freeze([
  'report_only',
  'force_rejoin_hub',
  'restart_bot_lane',
]);

/** Most actions one run may take, however many faults it sees. */
export const MAX_ACTIONS_PER_RUN = 2;

/** A lane restart drops its Zoom session, so never do it repeatedly. */
export const LANE_RESTART_COOLDOWN_MS = 30 * 60 * 1000;

/** A rejoin needs time to land before asking again. */
export const FORCE_REJOIN_COOLDOWN_MS = 5 * 60 * 1000;

/** A bot must have been silent this long before we touch its lane. */
export const LANE_RESTART_MIN_SILENCE_MS = 6 * 60 * 1000;

export class GuardrailError extends Error {
  constructor(message) {
    super(message);
    this.name = 'GuardrailError';
  }
}

const isNonEmptyString = (value) => typeof value === 'string' && value.trim().length > 0;

/**
 * Reject anything that is not a well-formed, whitelisted action before any of
 * it reaches production. Shape errors are treated exactly like a refusal.
 */
export function parseProposedAction(raw) {
  if (!raw || typeof raw !== 'object') {
    throw new GuardrailError('No action object was proposed.');
  }
  const kind = String(raw.kind || '').trim();
  if (!ALLOWED_ACTIONS.includes(kind)) {
    throw new GuardrailError(`Action "${kind || '(missing)'}" is not on the allow-list.`);
  }
  if (kind === 'restart_bot_lane') {
    const lane = Number(raw.lane);
    if (!Number.isInteger(lane) || lane < 1 || lane > 2) {
      throw new GuardrailError(`restart_bot_lane needs lane 1 or 2, got "${raw.lane}".`);
    }
    return { kind, lane };
  }
  if (kind === 'force_rejoin_hub') {
    if (!isNonEmptyString(raw.hubDocId)) {
      throw new GuardrailError('force_rejoin_hub needs a hubDocId.');
    }
    return { kind, hubDocId: raw.hubDocId.trim() };
  }
  return { kind: 'report_only' };
}

/**
 * Count the people the hub last reported inside its rooms. A hub that has gone
 * silent reports nothing, which is NOT the same as "empty" — the caller must
 * decide what to do with an unknown, and every destructive guardrail below
 * treats unknown as occupied.
 */
export function occupantsInHub(hubData = {}) {
  const stats = hubData.stats && typeof hubData.stats === 'object' ? hubData.stats : {};
  const reported = Number(stats.inRoomOccupants);
  if (Number.isFinite(reported)) return reported;
  const live = hubData.live_participants_by_shift || hubData.liveParticipantsByShift || {};
  let total = 0;
  for (const value of Object.values(live || {})) {
    if (Array.isArray(value)) total += value.length;
  }
  return total;
}

/**
 * The last word on whether an action may run. `context` carries only facts:
 * hub documents, the recent action history, and the clock.
 */
export function assertActionAllowed(action, context = {}) {
  const {
    hubsById = {},
    recentActions = [],
    now = Date.now(),
    actionsTakenThisRun = 0,
  } = context;

  if (actionsTakenThisRun >= MAX_ACTIONS_PER_RUN) {
    throw new GuardrailError(
      `Already took ${actionsTakenThisRun} action(s) this run; the rest is for a human.`,
    );
  }

  if (action.kind === 'report_only') return true;

  if (action.kind === 'force_rejoin_hub') {
    const hub = hubsById[action.hubDocId];
    if (!hub) {
      throw new GuardrailError(`Hub ${action.hubDocId} does not exist.`);
    }
    const last = recentActions.find(
      (entry) => entry.kind === 'force_rejoin_hub' && entry.hubDocId === action.hubDocId,
    );
    if (last && now - last.atMs < FORCE_REJOIN_COOLDOWN_MS) {
      throw new GuardrailError(
        `Already asked ${action.hubDocId} to rejoin ${Math.round((now - last.atMs) / 1000)}s ago.`,
      );
    }
    return true;
  }

  // restart_bot_lane — the only genuinely disruptive action.
  const laneHubs = Object.entries(hubsById)
    .filter(([, hub]) => Number(hub.lane ?? hub.laneIndex + 1) === action.lane)
    .filter(([, hub]) => isHubInWindow(hub, now));

  if (laneHubs.length === 0) {
    throw new GuardrailError(`Lane ${action.lane} has no hub in its window; nothing to restart.`);
  }

  for (const [hubDocId, hub] of laneHubs) {
    // Restarting ejects everyone the bot is hosting. If we cannot prove the
    // rooms are empty, we do not restart — a stuck class is better than a
    // class thrown out mid-lesson.
    const occupants = occupantsInHub(hub);
    if (occupants > 0) {
      throw new GuardrailError(
        `Lane ${action.lane} hub ${hubDocId} still reports ${occupants} person(s) inside.`,
      );
    }
    const silentMs = silenceMs(hub, now);
    if (silentMs === null) {
      throw new GuardrailError(`Hub ${hubDocId} has never reported; leave it to the watcher.`);
    }
    if (silentMs < LANE_RESTART_MIN_SILENCE_MS) {
      throw new GuardrailError(
        `Lane ${action.lane} was heard from ${Math.round(silentMs / 1000)}s ago; too soon to restart.`,
      );
    }
  }

  const lastRestart = recentActions.find(
    (entry) => entry.kind === 'restart_bot_lane' && Number(entry.lane) === action.lane,
  );
  if (lastRestart && now - lastRestart.atMs < LANE_RESTART_COOLDOWN_MS) {
    throw new GuardrailError(
      `Lane ${action.lane} was restarted ${Math.round((now - lastRestart.atMs) / 60000)} min ago; ` +
      'a second restart means something a human needs to look at.',
    );
  }

  return true;
}

export function toMs(value) {
  if (!value) return null;
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  if (typeof value.toDate === 'function') return value.toDate().getTime();
  if (typeof value._seconds === 'number') return value._seconds * 1000;
  if (typeof value.seconds === 'number') return value.seconds * 1000;
  return null;
}

/** Milliseconds since the hub's bot last reported, or null if it never has. */
export function silenceMs(hubData = {}, now = Date.now()) {
  const beat = toMs(hubData.heartbeat_at || hubData.heartbeatAt);
  if (beat === null) return null;
  return now - beat;
}

export function isHubInWindow(hubData = {}, now = Date.now()) {
  const start = toMs(hubData.window_start || hubData.windowStart);
  const end = toMs(hubData.window_end || hubData.windowEnd);
  if (start === null || end === null) return false;
  return start <= now && now <= end;
}
