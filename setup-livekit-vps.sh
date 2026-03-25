#!/bin/bash
set -e

#############################################
# LiveKit Self-Hosted Setup Script
# VPS: Hostinger Ubuntu 24.04 + Docker
# Domain: live.alluwaleducationhub.org
# IP: 187.77.221.13
#############################################

DOMAIN="live.alluwaleducationhub.org"
VPS_IP="187.77.221.13"
API_KEY="alluvial_lk_key"
API_SECRET="3flMDYx45dna6tbTjPG1zFmygpbh5EehOaVeovf37jo="
INSTALL_DIR="/opt/livekit"

echo "============================================"
echo "  LiveKit Self-Hosted Setup"
echo "  Domain: $DOMAIN"
echo "  IP: $VPS_IP"
echo "============================================"

# Step 1: Verify DNS is pointing to this server
echo ""
echo "[1/6] Checking DNS resolution..."
RESOLVED_IP=$(dig +short "$DOMAIN" 2>/dev/null || true)
if [ "$RESOLVED_IP" != "$VPS_IP" ]; then
  echo "WARNING: $DOMAIN resolves to '$RESOLVED_IP' instead of '$VPS_IP'"
  echo "Make sure you've created the DNS A record:"
  echo "  $DOMAIN -> $VPS_IP"
  echo ""
  read -p "Continue anyway? (y/N): " CONTINUE
  if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
    echo "Exiting. Set up DNS first, then re-run this script."
    exit 1
  fi
else
  echo "DNS OK: $DOMAIN -> $RESOLVED_IP"
fi

# Step 2: Install dependencies
echo ""
echo "[2/6] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq dnsutils curl > /dev/null 2>&1
# Docker should already be installed on this VPS

# Step 3: Open firewall ports
echo ""
echo "[3/6] Configuring firewall..."
ufw allow 22/tcp    > /dev/null 2>&1 || true  # SSH (keep access!)
ufw allow 80/tcp    > /dev/null 2>&1 || true  # HTTP (Caddy ACME)
ufw allow 443/tcp   > /dev/null 2>&1 || true  # HTTPS (WebSocket + API)
ufw allow 443/udp   > /dev/null 2>&1 || true  # HTTPS UDP (WebRTC via TURN)
ufw allow 7881/tcp  > /dev/null 2>&1 || true  # WebRTC TCP fallback
ufw allow 3478/udp  > /dev/null 2>&1 || true  # TURN server
ufw allow 50000:60000/udp > /dev/null 2>&1 || true  # WebRTC media
echo "y" | ufw enable > /dev/null 2>&1 || true
echo "Firewall configured."

# Step 4: Create config directory
echo ""
echo "[4/6] Creating config files in $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# livekit.yaml
cat > livekit.yaml << 'LKEOF'
port: 7880
bind_addresses:
  - "0.0.0.0"
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
redis:
  address: redis:6379
keys:
  APIKEY_PLACEHOLDER: APISECRET_PLACEHOLDER
turn:
  enabled: true
  domain: DOMAIN_PLACEHOLDER
  tls_port: 5349
  udp_port: 3478
  external_tls: true
logging:
  level: info
LKEOF

sed -i "s|APIKEY_PLACEHOLDER|$API_KEY|g" livekit.yaml
sed -i "s|APISECRET_PLACEHOLDER|$API_SECRET|g" livekit.yaml
sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" livekit.yaml

# egress.yaml
cat > egress.yaml << 'EGEOF'
api_key: APIKEY_PLACEHOLDER
api_secret: APISECRET_PLACEHOLDER
ws_url: ws://livekit:7880
redis:
  address: redis:6379
health_port: 8080
EGEOF

sed -i "s|APIKEY_PLACEHOLDER|$API_KEY|g" egress.yaml
sed -i "s|APISECRET_PLACEHOLDER|$API_SECRET|g" egress.yaml

# Caddyfile
cat > Caddyfile << CADEOF
$DOMAIN {
    reverse_proxy livekit:7880
}
CADEOF

# docker-compose.yaml
cat > docker-compose.yaml << 'DCEOF'
version: "3.9"

services:
  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - redis_data:/data

  livekit:
    image: livekit/livekit-server:latest
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./livekit.yaml:/etc/livekit.yaml
    command: --config /etc/livekit.yaml --node-ip=VPSIP_PLACEHOLDER

  egress:
    image: livekit/egress:latest
    restart: unless-stopped
    environment:
      - EGRESS_CONFIG_FILE=/etc/egress.yaml
    volumes:
      - ./egress.yaml:/etc/egress.yaml
    cap_add:
      - SYS_ADMIN
    extra_hosts:
      - "livekit:host-gateway"

volumes:
  caddy_data:
  caddy_config:
  redis_data:
DCEOF

sed -i "s|VPSIP_PLACEHOLDER|$VPS_IP|g" docker-compose.yaml

# Secure config files
chmod 600 livekit.yaml egress.yaml

echo "Config files created."

# Step 5: Start services
echo ""
echo "[5/6] Pulling Docker images and starting services..."
docker compose pull
docker compose up -d

echo ""
echo "[6/6] Waiting for services to start..."
sleep 10

# Check status
echo ""
echo "============================================"
echo "  Service Status"
echo "============================================"
docker compose ps

echo ""
echo "============================================"
echo "  Testing HTTPS endpoint..."
echo "============================================"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null || echo "FAILED")
if [ "$HTTP_CODE" = "000" ] || [ "$HTTP_CODE" = "FAILED" ]; then
  echo "WARNING: https://$DOMAIN is not reachable yet."
  echo "This might be because:"
  echo "  - DNS hasn't propagated yet (wait a few minutes)"
  echo "  - Caddy is still provisioning the SSL certificate"
  echo ""
  echo "Check logs with: docker compose -f $INSTALL_DIR/docker-compose.yaml logs -f"
else
  echo "https://$DOMAIN returned HTTP $HTTP_CODE - OK!"
fi

echo ""
echo "============================================"
echo "  SETUP COMPLETE!"
echo "============================================"
echo ""
echo "LiveKit server: wss://$DOMAIN"
echo "API Key:        $API_KEY"
echo "API Secret:     $API_SECRET"
echo ""
echo "Next steps:"
echo "  1. Verify DNS: dig $DOMAIN"
echo "  2. Check logs: cd $INSTALL_DIR && docker compose logs -f"
echo "  3. Update Firebase dev secrets:"
echo "     firebase functions:secrets:set LIVEKIT_URL --project alluwal-dev"
echo "     → Enter: wss://$DOMAIN"
echo "     firebase functions:secrets:set LIVEKIT_API_KEY --project alluwal-dev"
echo "     → Enter: $API_KEY"
echo "     firebase functions:secrets:set LIVEKIT_API_SECRET --project alluwal-dev"
echo "     → Enter: $API_SECRET"
echo "  4. Redeploy dev functions:"
echo "     firebase deploy --only functions --project alluwal-dev"
echo "  5. Test with dev app!"
echo ""
