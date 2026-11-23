'use strict';

/**
 * Deciding when a hub page has stopped working, and when it may be rejoined.
 *
 * The bot drives each hub from a Chromium page. That page can freeze or its
 * renderer can die while the page object stays open, and when that happens the
 * node process is still running, so systemd reports the unit healthy and
 * restarts nothing. The page's own recovery — reloading when the backend stamps
 * forceRejoinAt — runs inside the frozen page, so it never fires either.
 *
 * On 2026-09-11 lane 2 went silent at 18:24:45 UTC and stayed dark for 44
 * minutes, through four live classes, until a person restarted the unit. The
 * only signal node receives from a page is its console output, which a healthy
 * page produces every ~17 seconds, so a long silence is where to look — and a
 * direct probe decides, so a page that is merely quiet is never torn down.
 *
 * Rejoining is held back for a while after a page is recycled: the old host
 * session can linger in Zoom, and joining again straight away puts two hosts in
 * the meeting (runbook docs/zoom-hub-bot-plan.md §20). The hold used to be a
 * fixed 150s. Now it is a short minimum, and the rejoined page itself keeps its
 * rooms shut until the old session has left, up to the same 150s cap
 * (waitForOldHostSession in bot_controller.html).
 */

const DEFAULT_PAGE_SILENCE_MS = 3 * 60 * 1000;
const DEFAULT_GHOST_HOST_CLEAR_MS = 150 * 1000;
// The least time a recycled hub waits before joining again. The rejoined page
// waits on its own for the old session to leave, so this only has to keep the
// join from racing the teardown of the page it replaces.
const DEFAULT_GHOST_HOST_MIN_MS = 10 * 1000;
// A join that did not complete (Zoom refused it, or the page died while
// joining) is retried this soon while the lane is recovering, instead of on the
// next 30s directive poll. Nothing is opened until a join succeeds, so a retry
// costs a page load and nothing else.
const DEFAULT_JOIN_RETRY_MS = 10 * 1000;
const DEFAULT_PROBE_TIMEOUT_MS = 10 * 1000;
// A joined page is probed on every poll; this many unanswered in a row means
// its renderer has stopped. One can be a busy moment on a one-vCPU host.
const UNANSWERED_PROBES_LIMIT = 2;

// What the Zoom Web SDK prints when its connection to the meeting is gone:
// every action it tries fails on a null socket. On 2026-11-13 lane 3 lost its
// socket at 17:45 UTC and printed this ~120 times every 10 minutes for 2h25m
// while its routing loop kept logging snapshots and its heartbeat kept saying
// roomsOpen, so every other check saw a healthy hub and teachers sat in the
// lobby with no host to admit them. A healthy hub prints it now and then while
// rooms open or people move (at most 20 in any 10 minutes over the 10 days
// before), so it takes a sustained burst to count.
const SDK_SOCKET_LOST_MARKER = "reading 'sendSocket'";
const DEFAULT_SDK_SOCKET_LOST_WINDOW_MS = 10 * 60 * 1000;
const DEFAULT_SDK_SOCKET_LOST_THRESHOLD = 60;

function positiveNumber(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

/** True once a page has produced no output for longer than `silenceMs`. */
function isPageSilent(lastActivityAt, now, silenceMs = DEFAULT_PAGE_SILENCE_MS) {
  // No timestamp means we cannot tell, and "cannot tell" never tears a page down.
  if (!Number.isFinite(lastActivityAt)) return false;
  return now - lastActivityAt > silenceMs;
}

/**
 * How a session looks against the only output that proves it is working.
 *
 * A hub page prints a routing snapshot every ~17s while it is doing its job.
 * Judging it on console output alone is too generous: on 2026-09-11 lane 1 kept
 * logging SDK errors for half an hour after its routing loop had died, so
 * anything watching mere output saw a healthy page hosting nobody.
 *
 * Before the first snapshot the page is still joining and creating its rooms
 * and has no routing to show, so until then its plain output is all there is.
 *
 * Returns whether the page has ever routed (`established`), whether it has now
 * been quiet too long, and for how long.
 */
function routingHealth(session = {}, now = Date.now(), silenceMs = DEFAULT_PAGE_SILENCE_MS) {
  const established = Number.isFinite(session.lastRoutingAt);
  const since = established ? session.lastRoutingAt : session.lastPageActivityAt;
  if (!Number.isFinite(since)) {
    return { established, silent: false, silentForMs: 0 };
  }
  return {
    established,
    silent: now - since > silenceMs,
    silentForMs: Math.max(0, now - since),
  };
}

/**
 * Note one socket failure and say whether the page has lost its meeting: at
 * least `threshold` failures within the last `windowMs`. `failures` is the
 * session's own list of timestamps and is trimmed in place.
 */
function recordSdkSocketFailure(
  failures,
  now,
  windowMs = DEFAULT_SDK_SOCKET_LOST_WINDOW_MS,
  threshold = DEFAULT_SDK_SOCKET_LOST_THRESHOLD,
) {
  failures.push(now);
  while (failures.length && failures[0] <= now - windowMs) failures.shift();
  return failures.length >= threshold;
}

/**
 * Whether the page's main thread still answers. A frozen renderer never settles
 * the evaluation, so it is raced against a timer; a throw counts as no answer.
 */
async function pageResponds(evaluate, timeoutMs = DEFAULT_PROBE_TIMEOUT_MS) {
  let timer;
  const timedOut = new Promise((resolve) => {
    timer = setTimeout(() => resolve(false), timeoutMs);
  });
  try {
    const answered = Promise.resolve()
      .then(evaluate)
      .then(() => true, () => false);
    return await Promise.race([answered, timedOut]);
  } finally {
    clearTimeout(timer);
  }
}

/** Hold a hub back from rejoining until its old host session has cleared. */
function blockRejoin(blockedUntil, hubDocId, now, clearMs = DEFAULT_GHOST_HOST_CLEAR_MS) {
  blockedUntil.set(hubDocId, now + clearMs);
}

/**
 * How long to wait before retrying a join that did not complete: soon while the
 * lane is still inside its recovery window (the first failure plus `capMs`),
 * and at the ordinary poll cadence after that, so a join Zoom keeps refusing
 * does not reload a page every few seconds forever.
 */
function joinRetryDelay(firstFailureAt, now, capMs = DEFAULT_GHOST_HOST_CLEAR_MS,
  retryMs = DEFAULT_JOIN_RETRY_MS, pollMs = 30 * 1000) {
  if (!Number.isFinite(firstFailureAt)) return retryMs;
  return now - firstFailureAt < capMs ? retryMs : pollMs;
}

/**
 * How long the main loop sleeps: its poll interval, or less when a held-back
 * hub becomes free to rejoin sooner than that.
 */
function nextPollDelay(blockedUntil, now, pollMs) {
  let delay = pollMs;
  for (const until of blockedUntil.values()) {
    if (!Number.isFinite(until)) continue;
    delay = Math.min(delay, Math.max(1000, until - now + 250));
  }
  return delay;
}

function isRejoinBlocked(blockedUntil, hubDocId, now) {
  const until = blockedUntil.get(hubDocId);
  if (!until) return false;
  if (until <= now) {
    blockedUntil.delete(hubDocId);
    return false;
  }
  return true;
}

module.exports = {
  SDK_SOCKET_LOST_MARKER,
  DEFAULT_SDK_SOCKET_LOST_WINDOW_MS,
  DEFAULT_SDK_SOCKET_LOST_THRESHOLD,
  recordSdkSocketFailure,
  DEFAULT_PAGE_SILENCE_MS,
  DEFAULT_GHOST_HOST_CLEAR_MS,
  DEFAULT_GHOST_HOST_MIN_MS,
  DEFAULT_JOIN_RETRY_MS,
  DEFAULT_PROBE_TIMEOUT_MS,
  UNANSWERED_PROBES_LIMIT,
  joinRetryDelay,
  nextPollDelay,
  positiveNumber,
  isPageSilent,
  routingHealth,
  pageResponds,
  blockRejoin,
  isRejoinBlocked,
};
