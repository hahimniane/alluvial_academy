# LiveKit Self-Hosted Migration Guide

## Goal
Move from LiveKit Cloud ($156/month) to self-hosted on Hostinger VPS ($0).

## Credentials
- **LiveKit URL**: `wss://live.alluwaleducationhub.org`
- **API Key**: `alluvial_lk_key`
- **API Secret**: `3flMDYx45dna6tbTjPG1zFmygpbh5EehOaVeovf37jo=`

---

## Step 1: Create DNS Records

Go to your DNS provider for `alluwaleducationhub.org` and add:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | live | 187.77.221.13 | 300 |
| A | turn | 187.77.221.13 | 300 |

Wait a few minutes for propagation. Verify with:
```bash
dig live.alluwaleducationhub.org
dig turn.alluwaleducationhub.org
```

---

## Step 2: Run Setup Script on VPS

```bash
# From your Mac, copy the script to the VPS:
scp ~/Downloads/alluvial_academy-main/setup-livekit-vps.sh root@187.77.221.13:/root/

# SSH into the VPS:
ssh root@187.77.221.13

# Run the script:
chmod +x /root/setup-livekit-vps.sh
/root/setup-livekit-vps.sh
```

The script automatically:
- Opens firewall ports
- Creates all config files in `/opt/livekit/`
- Starts LiveKit server, Egress, Redis, and Caddy layer-4 via Docker
- Uses `turn.alluwaleducationhub.org` for TURN/TLS and TURN/UDP fallback
- Verifies everything is running

---

## Step 3: Verify VPS is Working

```bash
# SSH into VPS and check:
ssh root@187.77.221.13

cd /opt/livekit
docker compose ps              # All 4 containers should be "running"
docker compose logs -f livekit # Check for errors (Ctrl+C to exit)
docker compose logs -f egress  # Check egress is ready

# From anywhere, test HTTPS:
curl -v https://live.alluwaleducationhub.org
```

---

## Step 4: Test on Dev Project

Update dev Firebase secrets (from your Mac):

```bash
# Set LiveKit URL
firebase functions:secrets:set LIVEKIT_URL --project alluwal-dev
# When prompted, enter: wss://live.alluwaleducationhub.org

# Set API Key
firebase functions:secrets:set LIVEKIT_API_KEY --project alluwal-dev
# When prompted, enter: alluvial_lk_key

# Set API Secret
firebase functions:secrets:set LIVEKIT_API_SECRET --project alluwal-dev
# When prompted, enter: 3flMDYx45dna6tbTjPG1zFmygpbh5EehOaVeovf37jo=

# Redeploy functions
firebase deploy --only functions --project alluwal-dev
```

### Test checklist:
- [ ] Teacher can join a room (video + audio)
- [ ] Teacher + student can see/hear each other
- [ ] Screen sharing works
- [ ] Recording starts and files appear in GCS bucket
- [ ] Recording playback works
- [ ] Mute / kick / lock room work
- [ ] Test from mobile data (verifies TURN server)
- [ ] 30+ minute session is stable

---

## Step 5: Migrate Production

**Only after dev testing passes.**

### 5a: Save current cloud credentials (for rollback)
```bash
firebase functions:secrets:access LIVEKIT_URL --project alluwal-academy
firebase functions:secrets:access LIVEKIT_API_KEY --project alluwal-academy
firebase functions:secrets:access LIVEKIT_API_SECRET --project alluwal-academy
```
**Save these values somewhere safe!**

### 5b: Pick a time when no classes are scheduled

### 5c: Update prod secrets
```bash
firebase functions:secrets:set LIVEKIT_URL --project alluwal-academy
# Enter: wss://live.alluwaleducationhub.org

firebase functions:secrets:set LIVEKIT_API_KEY --project alluwal-academy
# Enter: alluvial_lk_key

firebase functions:secrets:set LIVEKIT_API_SECRET --project alluwal-academy
# Enter: 3flMDYx45dna6tbTjPG1zFmygpbh5EehOaVeovf37jo=

firebase deploy --only functions --project alluwal-academy
```

### 5d: Run the same test checklist against prod

---

## Rollback (if something goes wrong)

Restore saved cloud credentials and redeploy (~5 minutes):

```bash
firebase functions:secrets:set LIVEKIT_URL --project alluwal-academy
# Enter: (saved cloud URL, e.g., wss://xxx.livekit.cloud)

firebase functions:secrets:set LIVEKIT_API_KEY --project alluwal-academy
# Enter: (saved cloud API key)

firebase functions:secrets:set LIVEKIT_API_SECRET --project alluwal-academy
# Enter: (saved cloud API secret)

firebase deploy --only functions --project alluwal-academy
```

**Keep LiveKit Cloud account active for 30 days after migration.**

---

## Post-Migration Maintenance

```bash
# Check VPS status anytime:
ssh root@187.77.221.13
cd /opt/livekit
docker compose ps
docker stats

# Update LiveKit to latest version:
docker compose pull
docker compose up -d

# View logs:
docker compose logs -f
```

---

## Useful VPS Commands

```bash
# Restart all services:
cd /opt/livekit && docker compose restart

# Restart just LiveKit server:
docker compose restart livekit

# Stop everything:
docker compose down

# Start everything:
docker compose up -d
```

---

## After 30 Days Stable: Cancel LiveKit Cloud

Go to https://cloud.livekit.io and cancel the subscription.

**Savings: $156/month → $0 ($1,872/year)**
