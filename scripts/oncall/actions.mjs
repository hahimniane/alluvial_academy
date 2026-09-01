/**
 * The complete list of things the on-call responder may do without a human,
 * and the guardrails that decide whether it may do them right now.
 *
 * Everything here is plain code rather than model judgment. The model chooses
 * WHICH action to propose; this file decides whether that action is allowed to
 * happen at all.
 *
 * The rule that matters most: **the model never decides whether something is
 * wrong.** Health is computed here, from the hub documents. On 2026-09-01 the
 * model called a 35-second-old heartbeat a "zombie bot" three times running and
 * proposed acting on healthy hubs each time; two were blocked by other rules and
 * one rejoin got through because nothing checked that the hub was actually
 * unhealthy. Now nothing but `report_only` is permitted unless this file has
 * independently found a fault.
 */

/** Actions the responder is allowed to take on its own. */
export const ALLOWED_ACTIONS = Object.freeze([
  'report_only',
  'force_rejoin_hub',
  'restart_bot_lane',
]);

/**
 * A bot writes its heartbeat continuously. Anything fresher than this is a
 * working bot, whatever the model believes. Mirrors ZOOM_HUB_BOT_STALE_MS in
 * functions/handlers/zoom.js.
 */
export const HEARTBEAT_STALE_MS = 2 * 60 * 1000;

/** A bot must have been silent this long before its lane may be restarted. */
export const LANE_RESTART_MIN_SILENCE_MS = 6 * 60 * 1000;

/** Most actions one run may take, however many faults it sees. */
export const MAX_ACTIONS_PER_RUN = 2;

/** However bad a day gets, one hub may be poked this many times before a human. */
export const MAX_ACTIONS_PER_HUB_PER_DAY = 4;

/** A lane restart drops its Zoom session, so never do it repeatedly. */
export const LANE_RESTART_COOLDOWN_MS = 30 * 60 * 1000;

/** A rejoin needs time to land before asking again. */
export const FORCE_REJOIN_COOLDOWN_MS = 5 * 60 * 1000;

const DAY_MS = 24 * 60 * 60 * 1000;

export class GuardrailError extends Error {
  constructor(message) {
    super(message);
    this.name = 'GuardrailError';
  }
}

const isNonEmptyString = (value) => typeof value === 'string' && value.trim().length > 0;

export function toMs(value) {
  if (!value) return null;
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
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

/**
 * How many people the hub last reported inside its rooms, or **null when we do
 * not know**. A silent hub reports nothing, and "no report" is not "empty" —
 * every destructive guardrail below treats null as occupied.
 */
export function occupantsInHub(hubData = {}) {
  const stats = hubData.stats && typeof hubData.stats === 'object' ? hubData.stats : null;
  const reported = stats ? Number(stats.inRoomOccupants) : NaN;
  if (Number.isFinite(reported)) return reported;
  const live = hubData.live_participants_by_shift || hubData.liveParticipantsByShift;
  if (live && typeof live === 'object') {
    let total = 0;
    for (const value of Object.values(live)) {
      if (Array.isArray(value)) total += value.length;
    }
    return total;
  }
  return null; // unknown
}

/**
 * The single source of truth for "is this hub actually broken". Computed from
 * the hub's own documents, never from anything the model said.
 */
export function isHubUnhealthy(hubData = {}, now = Date.now()) {
  if (!isHubInWindow(hubData, now)) return false;
  if (hubData.bot_unavailable === true) return true;
  const silent = silenceMs(hubData, now);
  // Never reported at all: the bot has not joined yet, which the backend's
  // assigned-not-joined logic owns. Not ours to act on.
  if (silent === null) return false;
  return silent > HEARTBEAT_STALE_MS;
}

/** Ids of every hub this file independently considers broken right now. */
export function unhealthyHubIds(hubsById = {}, now = Date.now()) {
  return new Set(
    Object.entries(hubsById)
      .filter(([, hub]) => isHubUnhealthy(hub, now))
      .map(([id]) => id),
  );
}

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

const laneOf = (hub = {}) => {
  const lane = Number(hub.lane);
  if (Number.isInteger(lane)) return lane;
  const index = Number(hub.laneIndex);
  return Number.isInteger(index) ? index + 1 : NaN;
};

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

  if (action.kind === 'report_only') return true;

  if (actionsTakenThisRun >= MAX_ACTIONS_PER_RUN) {
    throw new GuardrailError(
      `Already took ${actionsTakenThisRun} action(s) this run; the rest is for a human.`,
    );
  }

  // Master brake: if nothing is independently broken, nothing may be touched,
  // whatever the model concluded.
  const broken = unhealthyHubIds(hubsById, now);
  if (broken.size === 0) {
    throw new GuardrailError(
      'Every hub in its window is reporting normally; there is nothing to fix.',
    );
  }

  const dayAgo = now - DAY_MS;

  if (action.kind === 'force_rejoin_hub') {
    const hub = hubsById[action.hubDocId];
    if (!hub) {
      throw new GuardrailError(`Hub ${action.hubDocId} does not exist.`);
    }
    if (!isHubInWindow(hub, now)) {
      throw new GuardrailError(`Hub ${action.hubDocId} is outside its class window.`);
    }
    // The loophole that let a healthy hub be poked on 2026-09-01.
    if (!broken.has(action.hubDocId)) {
      const silent = silenceMs(hub, now);
      throw new GuardrailError(
        `Hub ${action.hubDocId} is healthy` +
        (silent === null ? ' (no heartbeat recorded)' : ` — its bot reported ${Math.round(silent / 1000)}s ago`) +
        '; there is nothing to rejoin.',
      );
    }
    const last = recentActions.find(
      (entry) => entry.kind === 'force_rejoin_hub' && entry.hubDocId === action.hubDocId,
    );
    if (last && now - last.atMs < FORCE_REJOIN_COOLDOWN_MS) {
      throw new GuardrailError(
        `Already asked ${action.hubDocId} to rejoin ${Math.round((now - last.atMs) / 1000)}s ago.`,
      );
    }
    const today = recentActions.filter(
      (entry) => entry.hubDocId === action.hubDocId && entry.atMs >= dayAgo,
    ).length;
    if (today >= MAX_ACTIONS_PER_HUB_PER_DAY) {
      throw new GuardrailError(
        `${action.hubDocId} has been acted on ${today} times today; a human should look instead.`,
      );
    }
    return true;
  }

  // restart_bot_lane — the only genuinely disruptive action.
  const laneHubs = Object.entries(hubsById)
    .filter(([, hub]) => laneOf(hub) === action.lane)
    .filter(([, hub]) => isHubInWindow(hub, now));

  if (laneHubs.length === 0) {
    throw new GuardrailError(`Lane ${action.lane} has no hub in its window; nothing to restart.`);
  }

  for (const [hubDocId, hub] of laneHubs) {
    // Restarting ejects everyone the bot is hosting. Unknown occupancy counts
    // as occupied: a stuck class is better than a class thrown out mid-lesson.
    const occupants = occupantsInHub(hub);
    if (occupants === null) {
      throw new GuardrailError(
        `Lane ${action.lane} hub ${hubDocId} is not reporting occupancy; refusing to restart blind.`,
      );
    }
    if (occupants > 0) {
      throw new GuardrailError(
        `Lane ${action.lane} hub ${hubDocId} still reports ${occupants} person(s) inside.`,
      );
    }
    const silent = silenceMs(hub, now);
    if (silent === null) {
      throw new GuardrailError(`Hub ${hubDocId} has never reported; leave it to the watcher.`);
    }
    if (silent < LANE_RESTART_MIN_SILENCE_MS) {
      throw new GuardrailError(
        `Lane ${action.lane} was heard from ${Math.round(silent / 1000)}s ago; too soon to restart.`,
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
  const restartsToday = recentActions.filter(
    (entry) => entry.kind === 'restart_bot_lane' &&
      Number(entry.lane) === action.lane && entry.atMs >= dayAgo,
  ).length;
  if (restartsToday >= MAX_ACTIONS_PER_HUB_PER_DAY) {
    throw new GuardrailError(
      `Lane ${action.lane} has been restarted ${restartsToday} times today; a human should look instead.`,
    );
  }

  return true;
}
