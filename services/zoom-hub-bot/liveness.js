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
 * the meeting (runbook docs/zoom-hub-bot-plan.md §20).
 */

const DEFAULT_PAGE_SILENCE_MS = 3 * 60 * 1000;
const DEFAULT_GHOST_HOST_CLEAR_MS = 150 * 1000;
const DEFAULT_PROBE_TIMEOUT_MS = 10 * 1000;

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
  DEFAULT_PAGE_SILENCE_MS,
  DEFAULT_GHOST_HOST_CLEAR_MS,
  DEFAULT_PROBE_TIMEOUT_MS,
  positiveNumber,
  isPageSilent,
  pageResponds,
  blockRejoin,
  isRejoinBlocked,
};
