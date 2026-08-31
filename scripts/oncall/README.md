# Zoom hub on-call responder

Diagnoses live Zoom classroom faults and applies recovery actions from a fixed
allow-list. It runs on GitHub Actions every 10 minutes (`.github/workflows/zoom-hub-oncall.yml`),
so it is awake at 3am — which is when the outage it was built for happened.

## What it may do, and what it may never do

| May do on its own | Never does |
| --- | --- |
| Ask a hub's bot to rejoin (`force_rejoin_hub`) | Change code |
| Restart a bot lane on the VPS (`restart_bot_lane`) | Deploy anything |
| Report to admins' phones (`report_only`) | Touch class, timesheet or payment data |
|  | Anything not in `ALLOWED_ACTIONS` |

The model chooses *which* action to propose. `actions.mjs` decides whether it
is allowed to happen. A model that misreads a situation can only ever pick a
wrong item from a three-item list — it can never invent a new one.

### The brakes

- **Never restarts a lane with anyone inside a room.** Unknown occupancy counts
  as occupied: a silent hub reports nothing, which is not the same as empty.
- **Never restarts a bot heard from in the last 6 minutes.**
- **Never restarts the same lane twice in 30 minutes** — a second restart means
  something a human needs to see.
- **Never repeats a rejoin within 5 minutes** — it needs time to land.
- **At most 2 actions per run.** The rest is for a human.
- **Only one responder runs at a time** (workflow `concurrency`). Two bots
  restarting the same lane is the ghost-host situation that corrupts a meeting.
- The workflow **runs the guardrail tests before every run** and aborts if they
  fail. A responder with no working brakes is worse than no responder.

## Setup

Add these under **Settings → Secrets and variables → Actions**:

| Secret | What it is | Without it |
| --- | --- | --- |
| `FIREBASE_SERVICE_ACCOUNT_ALLUWAL` | Service-account JSON for `alluwal-academy`, one line | The responder cannot run |
| `ZOOM_BOT_VPS_HOST` | The bot VPS address | Lane restarts are reported instead of applied |
| `ZOOM_BOT_VPS_USER` | SSH user (`root`) | Defaults to `root` |
| `ZOOM_BOT_SSH_KEY` | Private key for that VPS | Lane restarts are reported instead of applied |
| `ANTHROPIC_API_KEY` | Optional | Falls back to Gemini |
| `GEMINI_API_KEY` | Optional | Read from Secret Manager instead |

**Only the first is required.** No AI key needs to be copied into GitHub: the
platform already pays for Gemini (`quiz_generation.js`, `bayanah.js`) and the
responder reads that same `GEMINI_API_KEY` straight out of Secret Manager using
the service account it already authenticates with. Give that account
`roles/secretmanager.secretAccessor` and there is nothing else to configure.
Set `ANTHROPIC_API_KEY` only if you want Claude instead; it wins when present.

The VPS secrets are optional on purpose: with no SSH key the responder still
diagnoses and still pushes to phones, it just cannot restart a lane. Start
there if you want to watch it for a few days before giving it the key.

## Running it by hand

**Actions → Zoom Hub On-Call Responder → Run workflow** defaults to *dry run*:
it decides and reports but changes nothing.

Locally, against production, using your own `gcloud` login:

```bash
cd scripts/oncall && npm install
GOOGLE_CLOUD_PROJECT=alluwal-academy node respond.mjs --dry-run
```

Rehearse a specific verdict without calling the model — this is how the
guardrails were verified against live data (no key, no tokens spent):

```bash
ONCALL_FAKE_VERDICT='{"faultType":"zombie_bot","action":{"kind":"restart_bot_lane","lane":1}}' \
GOOGLE_CLOUD_PROJECT=alluwal-academy node respond.mjs --dry-run
```

## Where its decisions go

Every run that acts writes to Firestore `oncall_actions`: the fault it
identified, the action, the outcome, its confidence, and the model used. That
is the audit trail — read it before trusting the responder with more.

## Faults it knows

| Fault | Teacher sees | Response |
| --- | --- | --- |
| Zombie bot (process alive, Zoom session dead) | HTTP 503 "Your class is reconnecting" | Rejoin, then restart the lane |
| Spare starvation (hub out of rooms) | HTTP 429 "This Zoom hub is full" | Report only — a restart would eject live classes and not help |
| Anything else | — | Report only |

When it diagnoses the same new fault twice, that fault should graduate into
`watchZoomHubBots` as deterministic auto-recovery. The responder is for what
the watchdog cannot handle yet, not a permanent home for known problems.

## Making it instant

The schedule gives up to 10 minutes of latency. To wake it the moment an alert
is written, have a Firestore trigger on `system_alerts` POST to GitHub:

```
POST https://api.github.com/repos/hahimniane/alluvial_academy/dispatches
{"event_type": "zoom_hub_alert"}
```

with a fine-grained PAT that can only dispatch workflows on this repository.
