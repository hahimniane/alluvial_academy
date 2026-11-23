# Zoom Hub Bot

Headless Zoom host controller for the classroom hub architecture. This service
runs on the Hostinger VPS and is not deployed to the public web root.

## VPS

- OS: Ubuntu 24.04 LTS
- Size: 1 vCPU / 4 GB RAM / 48 GB disk
- Host/IP/SSH details live in the ops vault or local deploy environment.

The VPS is single-core. During live acceptance testing, monitor CPU while both
lanes are in active Zoom meetings. If it saturates, resize to the next
Hostinger VPS tier in hPanel.
Do not install other workloads on this box.

## Required Environment

```bash
export ZOOM_HUB_FUNCTION_BASE_URL="https://us-central1-alluwal-academy.cloudfunctions.net"
export ZOOM_HUB_BOT_KEY="secret-manager-value"
export ZOOM_HUB_LANE="1"
```

Optional tuning (defaults in brackets):

- `ZOOM_HUB_BOT_SDK_VERSION` [6.10.0, the default in `bot_controller.html`] — the
  Zoom Web Meeting SDK the hub pages load from `source.zoom.us`. Changing or
  rolling it back is an env change plus a lane restart.
- `ZOOM_HUB_BOT_GHOST_MIN_MS` [10000] — least wait before rejoining a recycled
  hub. The rejoined page then keeps its rooms shut until it holds the host role
  (it reclaims it from the dead session), up to `ZOOM_HUB_BOT_GHOST_CLEAR_MS`
  [150000].
- `ZOOM_HUB_BOT_JOIN_RETRY_MS` [10000] — retry spacing for a join Zoom refused
  (errorCode 3000) during the first 150s; the poll interval after that.

How a dead page is noticed, fastest first: the page's own verdict on its Zoom
calls (`sdk_health.js`: an unanswered read, or reads failing with a lost-host
error for 15s), an unanswered probe from node on two polls in a row, 60 SDK
socket errors in 10 minutes, and the 3-minute routing silence in `liveness.js`.

`playwright` is required because the bot must run the Zoom Meeting SDK in a real
Chromium page. `jest` is used for the pure routing-diff tests.

## Local Commands

```bash
npm install
npm test
ZOOM_HUB_LANE=1 npm start
ZOOM_HUB_LANE=2 npm start
```

## Systemd

Install dependencies, then copy `systemd/zoom-hub-bot@.service` to
`/etc/systemd/system/zoom-hub-bot@.service`. Create
`/etc/alluwal/zoom-hub-bot.env` with the required environment values except
`ZOOM_HUB_LANE`; systemd supplies the lane from the instance number.

```bash
systemctl daemon-reload
systemctl enable --now zoom-hub-bot@1
systemctl enable --now zoom-hub-bot@2
journalctl -u zoom-hub-bot@1 -f
```
