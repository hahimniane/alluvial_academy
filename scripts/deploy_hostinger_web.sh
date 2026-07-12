#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$REPO_ROOT/.hostinger-deploy.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$REPO_ROOT/.hostinger-deploy.env"
  set +a
fi

: "${HOSTINGER_HOST:?Set HOSTINGER_HOST or create .hostinger-deploy.env}"
: "${HOSTINGER_PORT:?Set HOSTINGER_PORT or create .hostinger-deploy.env}"
: "${HOSTINGER_USER:?Set HOSTINGER_USER or create .hostinger-deploy.env}"
: "${HOSTINGER_KEY:?Set HOSTINGER_KEY or create .hostinger-deploy.env}"
: "${REMOTE_DOMAIN_ROOT:?Set REMOTE_DOMAIN_ROOT or create .hostinger-deploy.env}"
REMOTE_WEB_ROOT="$REMOTE_DOMAIN_ROOT/public_html"
SITE_URL="${SITE_URL:-https://alluwaleducationhub.org}"

if [ ! -f "$HOSTINGER_KEY" ]; then
  echo "Missing SSH key: $HOSTINGER_KEY" >&2
  exit 1
fi

cd "$REPO_ROOT"

echo "Building Flutter web release with ./build_release.sh"
./build_release.sh

VERSION="$(grep -o 'flutter_bootstrap\.js?v=[0-9]*' web/index.html | grep -o '[0-9]*$' | head -n 1)"
if [ -z "$VERSION" ]; then
  echo "Could not detect web build version from web/index.html" >&2
  exit 1
fi

SSH_COMMAND="ssh -i $HOSTINGER_KEY -p $HOSTINGER_PORT -o StrictHostKeyChecking=accept-new"
REMOTE="$HOSTINGER_USER@$HOSTINGER_HOST"
BACKUP_NAME="public_html_before_v${VERSION}_$(date +%Y%m%d_%H%M%S)"

echo "Backing up Hostinger web root to $BACKUP_NAME"
$SSH_COMMAND "$REMOTE" "set -e; cd '$REMOTE_DOMAIN_ROOT'; cp -a public_html '$BACKUP_NAME'; du -sh public_html '$BACKUP_NAME'"

echo "Uploading build/web/ to $REMOTE:$REMOTE_WEB_ROOT/"
rsync -az --delete \
  --exclude '/live/***' \
  --exclude '/ops/***' \
  --progress --stats -e "$SSH_COMMAND" build/web/ "$REMOTE:$REMOTE_WEB_ROOT/"

echo "Verifying remote files"
$SSH_COMMAND "$REMOTE" "set -e; cd '$REMOTE_WEB_ROOT'; grep -q 'flutter_bootstrap.js?v=$VERSION' index.html; grep -q 'manifest.json?v=$VERSION' index.html; grep -q 'main.dart.js?v=$VERSION' flutter_bootstrap.js"

echo "Verifying public site"
curl -fsSL "$SITE_URL/?verify=$VERSION" | grep -q "flutter_bootstrap.js?v=$VERSION"

echo "Deployed Hostinger web build v$VERSION"
