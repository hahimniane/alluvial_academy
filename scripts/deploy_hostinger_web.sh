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
# The Flutter app is mounted under /app/ — the domain root now serves the
# Next.js site. Deploying Flutter to the root would delete that site, so this
# targets the bridge directory. Build it with apps/web `npm run package:hostinger`,
# which rewrites Flutter's <base href> and .htaccess for the /app/ prefix.
REMOTE_WEB_ROOT="$REMOTE_DOMAIN_ROOT/public_html/app"
SITE_URL="${SITE_URL:-https://alluwaleducationhub.org/app}"
FLUTTER_DIST="${FLUTTER_DIST:-build/hostinger-web/app}"

if [ ! -f "$HOSTINGER_KEY" ]; then
  echo "Missing SSH key: $HOSTINGER_KEY" >&2
  exit 1
fi

cd "$REPO_ROOT"

echo "Building Flutter web release with ./build_release.sh"
./build_release.sh

echo "Packaging the Next site with the Flutter bridge at /app/"
(cd apps/web && npm run package:hostinger)

VERSION="$(grep -o 'flutter_bootstrap\.js?v=[0-9]*' web/index.html | grep -o '[0-9]*$' | head -n 1)"
if [ -z "$VERSION" ]; then
  echo "Could not detect web build version from web/index.html" >&2
  exit 1
fi

SSH_COMMAND="ssh -i $HOSTINGER_KEY -p $HOSTINGER_PORT -o StrictHostKeyChecking=accept-new"
REMOTE="$HOSTINGER_USER@$HOSTINGER_HOST"
BACKUP_NAME="app_before_v${VERSION}_$(date +%Y%m%d_%H%M%S)"

echo "Backing up Hostinger web root to ~/$BACKUP_NAME"
# Kept in the home directory, not public_html: deploying the Next site to the
# domain root uses rsync --delete, which would otherwise wipe the backup (and
# did once). Home is outside the web root, so it also isn't publicly served.
$SSH_COMMAND "$REMOTE" "set -e; cd '$REMOTE_DOMAIN_ROOT/public_html'; cp -a app ~/'$BACKUP_NAME'; du -sh app ~/'$BACKUP_NAME'"

if [ ! -f "$FLUTTER_DIST/index.html" ]; then
  echo "Missing $FLUTTER_DIST — run 'cd apps/web && npm run package:hostinger' first" >&2
  exit 1
fi

if ! grep -q '<base href="/app/">' "$FLUTTER_DIST/index.html"; then
  echo "$FLUTTER_DIST is not prefixed for /app/ — package:hostinger must rewrite the base href" >&2
  exit 1
fi

echo "Uploading $FLUTTER_DIST/ to $REMOTE:$REMOTE_WEB_ROOT/"
rsync -az --delete \
  --progress --stats -e "$SSH_COMMAND" "$FLUTTER_DIST/" "$REMOTE:$REMOTE_WEB_ROOT/"

echo "Verifying remote files"
$SSH_COMMAND "$REMOTE" "set -e; cd '$REMOTE_WEB_ROOT'; grep -q 'flutter_bootstrap.js?v=$VERSION' index.html; grep -q 'manifest.json?v=$VERSION' index.html; grep -q 'main.dart.js?v=$VERSION' flutter_bootstrap.js"

echo "Verifying public site"
# The CDN can lag a few seconds behind the upload; retry before declaring failure.
for attempt in 1 2 3 4 5; do
  if curl -fsSL "$SITE_URL/?verify=$VERSION-$attempt" | grep -q "flutter_bootstrap.js?v=$VERSION"; then
    break
  fi
  if [ "$attempt" = 5 ]; then
    echo "Public site still serving an older build after $attempt checks" >&2
    exit 1
  fi
  sleep 10
done

echo "Deployed Hostinger web build v$VERSION"
