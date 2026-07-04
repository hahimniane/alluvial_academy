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
