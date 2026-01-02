# Web Build + Deploy (Hostinger/LiteSpeed)

This is the exact workflow to run every time you want a web release to show up immediately (no stale cached JS).

## Why old builds happen

Two common causes:

1. **Server HTTP cache headers** for Flutter entrypoints (e.g. `Cache-Control: public, max-age=604800` on `main.dart.js`/`flutter_bootstrap.js`) can keep a browser pinned to an old release for up to 7 days.
2. **Old Flutter PWA service workers** (e.g. `flutter_service_worker.js`) can keep serving a cached app shell until users clear site data.

## What this repo already does for you

### `./build_release.sh` (run this every time)

- Increments the cache-busting version in `web/index.html` (the `?v=...` query string).
- Builds with:
  - `--pwa-strategy=none` (no new PWA caching)
  - `--no-tree-shake-icons` (required for this codebase)
  - `--dart-define=WEB_BUILD_VERSION=<n>` (shows in Settings → About so you can confirm the deployed build)
- Copies `web/.htaccess` into `build/web/.htaccess`.
- Patches `build/web/flutter_bootstrap.js` so it loads `main.dart.js?v=<n>` (forces a new JS URL each release).

### `web/.htaccess`

Ensures **no caching** for Flutter entrypoints/manifests (so “no cache preview” and normal refresh both pick up changes).

### `web/index.html` (temporary)

Includes a one-time cleanup snippet that unregisters any existing service workers and clears Cache Storage, to unstick users who still have old PWA caches.

## Every-release checklist (do this each time)

### 1) Build

```bash
flutter pub get
./build_release.sh
```

The script prints a `Web build version: <n>` — keep that number.

### 2) Upload

Upload the **contents** of `build/web/` to your Hostinger web root (`public_html/`).

Important:
- Make sure dotfiles are uploaded (you need `public_html/.htaccess`).
- Upload the whole folder contents, not just `index.html` (otherwise you may mix old and new assets).

### 3) Purge server/CDN caches (if enabled)

- Hostinger hPanel: purge LiteSpeed/host cache (often under “Performance” / “Cache Manager”).
- If you use a CDN (Hostinger CDN / Cloudflare), purge it too.

## Post-deploy verification

### 1) Confirm the deployed version in the UI

Go to: **Admin Settings → About**

- `App Version`: from `pubspec.yaml`
- `Web Build`: should match the `Web build version: <n>` printed by `./build_release.sh`

If `Web Build` doesn’t match, you’re still viewing an old build.

### 2) Confirm server cache headers (recommended)

```bash
curl -I https://<domain>/index.html | head -n 20
curl -I https://<domain>/main.dart.js | head -n 20
curl -I https://<domain>/flutter_bootstrap.js | head -n 20
curl -I https://<domain>/flutter.js | head -n 20
```

Expected (at minimum):
- `index.html`, `main.dart.js`, `flutter_bootstrap.js`, `flutter.js` should **not** be long-lived cached.
- With our `.htaccess`, they should be `Cache-Control: no-cache, max-age=0, must-revalidate`.

If you still see `Cache-Control: public, max-age=604800`, your `.htaccess` is not being applied (wrong folder, not uploaded, or server not honoring it).

### 3) If you still see an old build locally

This is almost always a local browser cache issue:
- Hard reload: `Cmd+Shift+R`
- Chrome: DevTools → Application → Clear storage → “Clear site data”
- Chrome: DevTools → Application → Service Workers → “Unregister” (if any)

## After rollout (cleanup)

Once you’re confident users are no longer stuck on the old PWA cache, remove the temporary cleanup snippet from `web/index.html`:
- Search for: `flutter_sw_cleanup_done_2025_12_27`
