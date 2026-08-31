import test from 'node:test';
import assert from 'node:assert/strict';
import {
  GuardrailError,
  LANE_RESTART_COOLDOWN_MS,
  MAX_ACTIONS_PER_RUN,
  assertActionAllowed,
  occupantsInHub,
  parseProposedAction,
} from '../actions.mjs';

const NOW = Date.UTC(2026, 7, 31, 12, 0, 0);
const minutesAgo = (n) => new Date(NOW - n * 60_000).toISOString();

const hub = (over = {}) => ({
  lane: 1,
  status: 'roomsOpen',
  window_start: new Date(NOW - 2 * 60 * 60_000).toISOString(),
  window_end: new Date(NOW + 2 * 60 * 60_000).toISOString(),
  heartbeat_at: minutesAgo(30),
  stats: { inRoomOccupants: 0 },
  ...over,
});

test('only whitelisted actions survive parsing', () => {
  assert.deepEqual(parseProposedAction({ kind: 'report_only' }), { kind: 'report_only' });
  assert.deepEqual(
    parseProposedAction({ kind: 'restart_bot_lane', lane: 2 }),
    { kind: 'restart_bot_lane', lane: 2 },
  );
  for (const bad of [
    null,
    { kind: 'deploy_functions' },
    { kind: 'delete_collection', path: 'users' },
    { kind: 'restart_bot_lane', lane: 9 },
    { kind: 'force_rejoin_hub' },
  ]) {
    assert.throws(() => parseProposedAction(bad), GuardrailError);
  }
});

test('a lane restart is refused while anyone is inside a room', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: hub({ stats: { inRoomOccupants: 2 } }) },
      now: NOW,
    }),
    /still reports 2 person/,
  );
});

test('an unknown occupancy counts as occupied, not empty', () => {
  // A silent hub reports no stats at all; that must never read as "empty".
  const silent = hub({ stats: undefined, live_participants_by_shift: { s1: [{ id: 'a' }] } });
  assert.equal(occupantsInHub(silent), 1);
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: silent },
      now: NOW,
    }),
    /still reports 1 person/,
  );
});

test('a lane restart is refused when the bot was heard from recently', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: hub({ heartbeat_at: minutesAgo(1) }) },
      now: NOW,
    }),
    /too soon to restart/,
  );
});

test('a lane restart is allowed for an empty hub whose bot has been silent', () => {
  assert.equal(
    assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: hub() },
      now: NOW,
    }),
    true,
  );
});

test('the same lane is never restarted twice inside the cooldown', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: hub() },
      recentActions: [{ kind: 'restart_bot_lane', lane: 1, atMs: NOW - LANE_RESTART_COOLDOWN_MS + 60_000 }],
      now: NOW,
    }),
    /a second restart means something a human needs to look at/,
  );
});

test('a rejoin is not repeated before it has had time to land', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'force_rejoin_hub', hubDocId: 'h1' }, {
      hubsById: { h1: hub() },
      recentActions: [{ kind: 'force_rejoin_hub', hubDocId: 'h1', atMs: NOW - 60_000 }],
      now: NOW,
    }),
    /Already asked h1 to rejoin/,
  );
});

test('one run cannot take unlimited actions', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'force_rejoin_hub', hubDocId: 'h1' }, {
      hubsById: { h1: hub() },
      now: NOW,
      actionsTakenThisRun: MAX_ACTIONS_PER_RUN,
    }),
    /the rest is for a human/,
  );
});

test('a hub outside its window is never restarted', () => {
  assert.throws(
    () => assertActionAllowed({ kind: 'restart_bot_lane', lane: 1 }, {
      hubsById: { h1: hub({ window_end: new Date(NOW - 60 * 60_000).toISOString() }) },
      now: NOW,
    }),
    /no hub in its window/,
  );
});

test('report_only is always permitted', () => {
  assert.equal(assertActionAllowed({ kind: 'report_only' }, { now: NOW }), true);
});
