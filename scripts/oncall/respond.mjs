#!/usr/bin/env node
/**
 * Zoom hub on-call responder.
 *
 * Runs on a schedule (and on demand). It looks at the same evidence a person
 * would — open alerts, hub heartbeats, who is inside rooms — and when
 * something is wrong it asks Claude to say what the fault is and propose ONE
 * action from a fixed allow-list. `actions.mjs` decides whether that action is
 * permitted; this file carries it out and reports what happened.
 *
 * It deliberately does not touch code or deploy anything. Faults it cannot act
 * on are written up in plain English and pushed to the admins' phones.
 *
 *   node scripts/oncall/respond.mjs            # act if allowed
 *   node scripts/oncall/respond.mjs --dry-run  # decide, change nothing
 */

import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import admin from 'firebase-admin';
import { askModel } from './model.mjs';
import {
  GuardrailError,
  HEARTBEAT_STALE_MS,
  assertActionAllowed,
  isHubInWindow,
  isHubUnhealthy,
  occupantsInHub,
  parseProposedAction,
  silenceMs,
  toMs,
  unhealthyHubIds,
} from './actions.mjs';

const execFileAsync = promisify(execFile);

const DRY_RUN = process.argv.includes('--dry-run');
const VPS_HOST = process.env.ZOOM_BOT_VPS_HOST || '';
const VPS_USER = process.env.ZOOM_BOT_VPS_USER || 'root';
const SSH_KEY_PATH = process.env.ZOOM_BOT_SSH_KEY_PATH || '';
const ALERT_LOOKBACK_MS = 6 * 60 * 60 * 1000;

const log = (...args) => console.log('[oncall]', ...args);

function initFirebase() {
  if (admin.apps.length) return admin.app();
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (raw) {
    return admin.initializeApp({ credential: admin.credential.cert(JSON.parse(raw)) });
  }
  // Local runs use whatever gcloud is logged in as, so the responder can be
  // rehearsed against production without minting a service-account key.
  return admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: process.env.GOOGLE_CLOUD_PROJECT || 'alluwal-academy',
  });
}

/** Everything the responder is allowed to look at, gathered once. */
async function gatherEvidence(db, now) {
  const hubSnap = await db.collection('hub_meetings').get();
  const hubsById = {};
  const hubSummaries = [];
  for (const doc of hubSnap.docs) {
    const data = doc.data() || {};
    if (!isHubInWindow(data, now)) continue;
    hubsById[doc.id] = data;
    const silent = silenceMs(data, now);
    hubSummaries.push({
      hubDocId: doc.id,
      lane: data.lane ?? null,
      status: data.status || data.bot_status || null,
      secondsSinceHeartbeat: silent === null ? null : Math.round(silent / 1000),
      // Decided here, not by the model. It reads this field and does not get to
      // form its own opinion from the seconds above.
      healthy: !isHubUnhealthy(data, now),
      occupants: occupantsInHub(data),
      roomCount: data.room_count ?? null,
      botUnavailable: data.bot_unavailable === true,
      spareHolders: data.spares && typeof data.spares === 'object' ? data.spares : {},
    });
  }

  const alertSnap = await db
    .collection('system_alerts')
    .where('acknowledged', '==', false)
    .get();
  const alerts = alertSnap.docs
    .map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
    .filter((alert) => {
      if (alert.resolved === true) return false;
      const created = toMs(alert.created_at) ?? 0;
      return now - created <= ALERT_LOOKBACK_MS;
    })
    .map((alert) => ({
      id: alert.id,
      reason: alert.reason || null,
      title: alert.title || null,
      body: alert.body || null,
      severity: alert.severity || null,
      createdMinutesAgo: Math.round((now - (toMs(alert.created_at) ?? now)) / 60000),
      notificationError: alert.notification_error || null,
    }));

  const historySnap = await db
    .collection('oncall_actions')
    .orderBy('at', 'desc')
    .limit(20)
    .get()
    .catch(() => ({ docs: [] }));
  const recentActions = historySnap.docs.map((doc) => {
    const data = doc.data() || {};
    return { ...data, atMs: toMs(data.at) ?? 0 };
  });

  return { hubsById, hubSummaries, alerts, recentActions };
}

/**
 * Nothing to do unless a hub in its window looks wrong, or an alert is open.
 * This keeps the model out of the loop (and the bill at zero) on quiet runs.
 */
function needsAttention({ hubSummaries, alerts }) {
  return hubSummaries.some((hub) => !hub.healthy) || alerts.length > 0;
}

const SYSTEM_PROMPT = `You are the on-call engineer for Alluwal Education Hub's Zoom classroom system.

Classes run inside shared Zoom "hub" meetings. A bot per lane (1 and 2) joins as
host and opens one breakout room per class. Each hub document records a
heartbeat the bot writes while it is healthy.

Two faults account for every incident so far, and they look identical to
teachers but need opposite responses:

1. ZOMBIE BOT — the bot process is alive but its Zoom session died, so the
   heartbeat stops while status still says roomsOpen. Teachers get HTTP 503
   "Your class is reconnecting". Fix: force the bot to rejoin, and if that has
   already been tried and failed, restart that lane.

   You do NOT decide whether a hub is healthy. Each hub carries a "healthy"
   field that has already been computed for you. A hub with healthy=true is
   working — never propose an action for it, whatever its heartbeat number
   looks like. secondsSinceHeartbeat is context only: a bot reports constantly,
   so values of a few seconds or tens of seconds are entirely normal.

2. SPARE STARVATION — the bots are healthy but the hub has run out of rooms,
   so late-added classes cannot be placed. Teachers get HTTP 429 "This Zoom hub
   is full". Restarting a bot does NOT help and would eject live classes. This
   needs a human or a code change: report only.

You may propose exactly ONE action, from this list and nothing else:
  {"kind":"report_only"}
  {"kind":"force_rejoin_hub","hubDocId":"<id>"}
  {"kind":"restart_bot_lane","lane":1|2}

Rules you must follow:
- Only ever propose an action for a hub whose "healthy" field is false. If every
  hub is healthy, the answer is report_only, even when alerts are open — an open
  alert about an event that already resolved itself is not a fault.
- Prefer the least disruptive action that could work. force_rejoin_hub before
  restart_bot_lane, always.
- Never propose restart_bot_lane if any hub on that lane reports occupants > 0.
- Never propose an action for a fault you cannot identify. Say so instead.
- If everything looks healthy, use report_only and say it is healthy.

Reply with ONLY a JSON object:
{
  "faultType": "zombie_bot" | "spare_starvation" | "healthy" | "unknown",
  "assessment": "<what the evidence shows, 1-3 sentences>",
  "action": { ... },
  "confidence": <0..1>,
  "humanSummary": "<one sentence a non-engineer can act on>"
}`;

async function askClaude(evidence) {
  // Rehearsal hook: feed a verdict in instead of calling the model, so the
  // decision path and the guardrails can be exercised against real production
  // data without spending a token or needing a key.
  //   ONCALL_FAKE_VERDICT='{"faultType":"zombie_bot","action":{"kind":"restart_bot_lane","lane":1}}'
  const fake = process.env.ONCALL_FAKE_VERDICT;
  if (fake) {
    log('using ONCALL_FAKE_VERDICT (no model call)');
    return { verdict: JSON.parse(fake), model: 'fake', provider: 'fake' };
  }
  const user = `Current evidence (UTC ${new Date().toISOString()}):\n\n` +
    JSON.stringify({
      hubs: evidence.hubSummaries,
      openAlerts: evidence.alerts,
      recentResponderActions: evidence.recentActions.map((entry) => ({
        kind: entry.kind,
        lane: entry.lane ?? null,
        hubDocId: entry.hubDocId ?? null,
        minutesAgo: Math.round((Date.now() - entry.atMs) / 60000),
      })),
    }, null, 2);
  return askModel({ system: SYSTEM_PROMPT, user });
}

async function runForceRejoin(db, hubDocId) {
  await db.collection('hub_meetings').doc(hubDocId).set({
    force_rejoin_at: admin.firestore.FieldValue.serverTimestamp(),
    force_rejoin_by: 'oncall_responder',
  }, { merge: true });
  return `Asked the bot for ${hubDocId} to rejoin.`;
}

async function runLaneRestart(lane) {
  if (!VPS_HOST || !SSH_KEY_PATH) {
    throw new Error('ZOOM_BOT_VPS_HOST / ZOOM_BOT_SSH_KEY_PATH are not configured.');
  }
  // The documented clean cycle: a plain restart leaves a ghost host session in
  // Zoom for 1-2 minutes and the two hosts then fight over the breakout rooms.
  const remote = `systemctl stop zoom-hub-bot@${lane} && sleep 150 && ` +
    `systemctl start zoom-hub-bot@${lane} && sleep 30 && ` +
    `systemctl is-active zoom-hub-bot@${lane}`;
  const { stdout } = await execFileAsync('ssh', [
    '-i', SSH_KEY_PATH,
    '-o', 'StrictHostKeyChecking=accept-new',
    '-o', 'ConnectTimeout=20',
    `${VPS_USER}@${VPS_HOST}`,
    remote,
  ], { timeout: 5 * 60 * 1000 });
  return `Restarted zoom-hub-bot@${lane} (now ${stdout.trim() || 'unknown'}).`;
}

async function notifyAdmins(db, { title, body }) {
  const [byRole, byUserType] = await Promise.all([
    db.collection('users').where('role', '==', 'admin').get(),
    db.collection('users').where('user_type', '==', 'admin').get(),
  ]);
  const tokens = new Set();
  const seen = new Set();
  for (const doc of [...byRole.docs, ...byUserType.docs]) {
    if (seen.has(doc.id)) continue;
    seen.add(doc.id);
    const data = doc.data() || {};
    for (const entry of Array.isArray(data.fcmTokens) ? data.fcmTokens : []) {
      const value = String(entry?.token || '').trim();
      if (value) tokens.add(value);
    }
    const legacy = String(data.fcmToken || data.fcm_token || '').trim();
    if (legacy) tokens.add(legacy);
  }
  if (tokens.size === 0) {
    log('no admin device tokens; report stays in Firestore only');
    return 0;
  }
  await admin.messaging().sendEachForMulticast({
    notification: { title, body: body.slice(0, 240) },
    data: { type: 'zoom_hub_oncall' },
    tokens: Array.from(tokens),
  });
  return tokens.size;
}

async function main() {
  initFirebase();
  const db = admin.firestore();
  const now = Date.now();

  const evidence = await gatherEvidence(db, now);
  log(`hubs in window: ${evidence.hubSummaries.length}, open alerts: ${evidence.alerts.length}`);

  if (!needsAttention(evidence)) {
    log('everything healthy — not calling the model');
    return;
  }

  const { verdict, model: modelUsed, provider } = await askClaude(evidence);
  log(`asked ${provider}/${modelUsed}`);
  log(`fault: ${verdict.faultType} (confidence ${verdict.confidence})`);
  log(`assessment: ${verdict.assessment}`);

  let outcome;
  let action = { kind: 'report_only' };
  try {
    action = parseProposedAction(verdict.action);
    assertActionAllowed(action, { hubsById: evidence.hubsById, recentActions: evidence.recentActions, now });
    if (action.kind === 'report_only') {
      outcome = 'Reported only; no automatic action applies.';
    } else if (DRY_RUN) {
      outcome = `DRY RUN — would have run ${action.kind}.`;
    } else if (action.kind === 'force_rejoin_hub') {
      outcome = await runForceRejoin(db, action.hubDocId);
    } else {
      outcome = await runLaneRestart(action.lane);
    }
  } catch (err) {
    // A refused action is a normal outcome, not a crash: the responder falls
    // back to telling a human exactly what it saw.
    outcome = err instanceof GuardrailError
      ? `Action refused by guardrail: ${err.message}`
      : `Action failed: ${err.message || err}`;
    log(outcome);
  }

  const record = {
    at: admin.firestore.FieldValue.serverTimestamp(),
    kind: action.kind,
    lane: action.lane ?? null,
    hubDocId: action.hubDocId ?? null,
    faultType: verdict.faultType || 'unknown',
    assessment: verdict.assessment || '',
    humanSummary: verdict.humanSummary || '',
    confidence: Number(verdict.confidence) || 0,
    outcome,
    dryRun: DRY_RUN,
    model: modelUsed,
    provider,
  };
  if (!DRY_RUN) await db.collection('oncall_actions').add(record);

  const title = action.kind === 'report_only'
    ? 'Zoom hub needs a human'
    : `Zoom hub: ${action.kind.replace(/_/g, ' ')}`;
  const body = `${verdict.humanSummary || verdict.assessment}\n${outcome}`;
  if (!DRY_RUN) await notifyAdmins(db, { title, body });

  log(`outcome: ${outcome}`);
}

main().catch((err) => {
  console.error('[oncall] run failed:', err);
  process.exitCode = 1;
});
