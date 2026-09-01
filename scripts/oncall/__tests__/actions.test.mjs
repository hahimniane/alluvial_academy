import test from 'node:test';
import assert from 'node:assert/strict';
import {
  GuardrailError,
  LANE_RESTART_COOLDOWN_MS,
  MAX_ACTIONS_PER_HUB_PER_DAY,
  MAX_ACTIONS_PER_RUN,
  assertActionAllowed,
  isHubUnhealthy,
  occupantsInHub,
  parseProposedAction,
  unhealthyHubIds,
} from '../actions.mjs';

const NOW = Date.UTC(2026, 8, 1, 12, 0, 0);
const ago = (min) => new Date(NOW - min * 60_000).toISOString();

/** A hub inside its window whose bot went quiet 30 minutes ago. */
const brokenHub = (over = {}) => ({
  lane: 1,
  status: 'roomsOpen',
  window_start: ago(120),
  window_end: new Date(NOW + 120 * 60_000).toISOString(),
  heartbeat_at: ago(30),
  stats: { inRoomOccupants: 0 },
  ...over,
});

/** The same hub, reporting normally. */
const healthyHub = (over = {}) => brokenHub({ heartbeat_at: ago(0.5), ...over });

test('only whitelisted actions survive parsing', () => {
  assert.deepEqual(parseProposedAction({ kind: 'report_only' }), { kind: 'report_only' });
  for (const bad of [
    null,
    'restart everything',
    { kind: 'deploy_functions' },
    { kind: 'delete_collection', path: 'users' },
    { kind: 'restart_bot_lane', lane: 9 },
    { kind: 'restart_bot_lane', lane: '1; rm -rf /' },
    { kind: 'force_rejoin_hub' },
    { kind: 'force_rejoin_hub', hubDocId: '   ' },
  ]) {
    assert.throws(() => parseProposedAction(bad), GuardrailError);
  }
});

test('health is decided here, not by the model', () => {
  // The exact 2026-09-01 misreading: a 35-second heartbeat is a working bot.
  assert.equal(isHubUnhealthy(healthyHub({ heartbeat_at: ago(35 / 60) }), NOW), false);
  assert.equal(isHubUnhealthy(brokenHub(), NOW), true);
  // Flagged dead by the backend watcher counts even if a beat slipped in.
  assert.equal(isHubUnhealthy(healthyHub({ bot_unavailable: true }), NOW), true);
  // Outside its window it is not ours to touch.
  assert.equal(isHubUnhealthy(brokenHub({ window_end: ago(10) }), NOW), false);
  // Never reported at all: the backend's assigned-not-joined path owns that.
  assert.equal(isHubUnhealthy(brokenHub({ heartbeat_at: null }), NOW), false);
});

test('nothing may be touched while every hub is reporting normally', () => {
  const ctx = { hubsById: { h1: healthyHub() }, now: NOW };
  for (const action of [
    { kind: 'force_rejoin_hub', hubDocId: 'h1' },
    { kind: 'restart_bot_lane', lane: 1 },
  ]) {
    assert.throws(() => assertActionAllowed(action, ctx), /nothing to fix/);
  }
  // Reporting is always allowed.
  assert.equal(assertActionAllowed({ kind: 'report_only' }, ctx), true);
});

test('a healthy hub is never rejoined even when another hub is broken', () => {
  // This is the loophole that let a rejoin through on 2026-09-01.
  assert.throws(
    () => assertActionAllowed({ kind: 'force_rejoin_hub', hubDocId: 'fine' }, {
      hubsById: { fine: healthyHub({ heartbeat_at: ago(35 / 60) }), broken: brokenHub({ lane: 2 }) },
      now: NOW,
    }),
    /is healthy — its bot reported 35s ago/,
  );
});

test('a rejoin is refused for a hub that does not exist or is out of window', () => {
  const hubsById = { broken: brokenHub() };
  assert.throws(
    () => assertActionAllowed({ kind: 'force_rejoin_hub', hubDocId: 'ghost' }, { hubsById, now: NOW }),
    /does not exist/,
  );
  assert.throws(
    () => assertActionAllowed({ kind: 'force_rejoin_hub', hubDocId: 'old' }, {
      hubsById: { ...hubsById, old: brokenHub({ window_end: ago(30) }) },
      now: NOW,
    }),
    /outside its class window/,
  );
});

test('a rejoin is allowed for a genuinely broken hub', () => {
  assert.equal(
    assertActionAllowed({ kind: 'force_rejoin_hub', hubDocId: 'broken' }, {
      hubsById: { broken: brokenHub() },
      now: NOW,
    }),
    true,
  );
});

test('unknown occupancy blocks a restart — no report is not "empty"', () => {
  const noReport = brokenHub({ stats: undefined });
  assert.equal(occupantsInHub(noReport), null);
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: noReport },
      now: NOW,
    }),
    /not reporting occupancy; refusing to restart blind/,
  );
});

test('a lane restart is refused while anyone is inside a room', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: brokenHub({ stats: { inRoomOccupants: 2 } }) },
      now: NOW,
    }),
    /still reports 2 person/,
  );
});

test('a lane restart is refused when the bot was heard from recently', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: brokenHub({ bot_unavailable: true, heartbeat_at: ago(1) }) },
      now: NOW,
    }),
    /too soon to restart/,
  );
});

test('one healthy hub on a lane protects the whole lane from restart', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { dead: brokenHub(), alive: healthyHub({ lane: 1 }) },
      now: NOW,
    }),
    /too soon to restart/,
  );
});

test('a lane restart is allowed for an empty lane whose bot has been silent', () => {
  assert.equal(
    assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: brokenHub() },
      now: NOW,
    }),
    true,
  );
});

test('lanes are matched by laneIndex too, so a hub cannot hide from the checks', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 2 }, {
      hubsById: {
        broken: brokenHub({ lane: 2 }),
        occupied: brokenHub({ lane: undefined, laneIndex: 1, stats: { inRoomOccupants: 3 } }),
      },
      now: NOW,
    }),
    /still reports 3 person/,
  );
});

test('cooldowns stop the same fix being applied over and over', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: brokenHub() },
      recentActions: [{ kind: 'restart_bot_lane', lane: 1, atMs: NOW - LANE_RESTART_COOLDOWN_MS + 60_000 }],
      now: NOW,
    }),
    /a second restart means something a human needs to look at/,
  );
  assert.throws(
    () => assertActionAllowed({ kind: 'force_rejoin_hub', hubDocId: 'broken' }, {
      hubsById: { broken: brokenHub() },
      recentActions: [{ kind: 'force_rejoin_hub', hubDocId: 'broken', atMs: NOW - 60_000 }],
      now: NOW,
    }),
    /Already asked broken to rejoin/,
  );
});

test('a hub that keeps needing help all day is handed to a human', () => {
  const recentActions = Array.from({ length: MAX_ACTIONS_PER_HUB_PER_DAY }, (_, i) => ({
    kind: 'force_rejoin_hub', hubDocId: 'broken', atMs: NOW - (i + 1) * 60 * 60_000,
  }));
  assert.throws(
    () => assertActionAllowed({ kind: 'force_rejoin_hub', hubDocId: 'broken' }, {
      hubsById: { broken: brokenHub() },
      recentActions,
      now: NOW,
    }),
    /times today; a human should look instead/,
  );
});

test('one run cannot take unlimited actions', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'force_rejoin_hub', hubDocId: 'broken' }, {
      hubsById: { broken: brokenHub() },
      now: NOW,
      actionsTakenThisRun: MAX_ACTIONS_PER_RUN,
    }),
    /the rest is for a human/,
  );
});

test('unhealthyHubIds reports exactly the broken hubs', () => {
  const ids = unhealthyHubIds({
    a: healthyHub(), b: brokenHub(), c: brokenHub({ window_end: ago(1) }),
  }, NOW);
  assert.deepEqual([...ids], ['b']);
});
