# Cache Busting Version Management

## How It Works
To prevent users from having to manually clear their cache when you update the website, we use:

- URL versioning in `web/index.html` (query params for `flutter_bootstrap.js` and `manifest.json`)
- Server cache headers via `web/.htaccess` (critical for Hostinger/LiteSpeed)
- No PWA caching (`flutter build web --pwa-strategy=none`)

## Additional Cache Busting Methods Implemented:
- Cache-Control meta tags in HTML head
- HTTP headers for different file types (via Hostinger `.htaccess`)
- Temporary one-time service worker cleanup snippet (see below)

## How to Update Versions:

### Every time you make changes that affect the user experience:

1. **Update the version number in `web/index.html`:**
   ```html
   <!-- Change from -->
   <script src="flutter_bootstrap.js?v=1" async></script>
   
   <!-- To -->
   <script src="flutter_bootstrap.js?v=2" async></script>
   ```

2. **When to increment the version:**
   - UI changes
   - Bug fixes
   - New features
   - Any Dart code changes
   - Asset updates (images, fonts, etc.)

3. **Version History:**
   - v1: Initial cache busting implementation

## Quick Version Update Methods:

### Method 1: Automated Script (Recommended)
Use the provided script to automatically increment versions:
```bash
./increment_version.sh
```

### Method 2: Manual Process
1. Open `web/index.html`
2. Find the line with `flutter_bootstrap.js?v=X`
3. Increment the version number (X)
4. Also update `manifest.json?v=X` to the same version
5. Build and deploy

## Complete Deployment Workflow:

1. **Make your code changes**
2. **Increment version** (choose one):
   - Run: `./increment_version.sh` (automated)
   - Or manually edit `web/index.html` version numbers
3. **Build the Flutter web app**:
   ```bash
   ./build_release.sh
   ```
4. **Upload to Hostinger**:
   - Upload the entire `build/web/` folder contents
   - Confirm `.htaccess` exists in the Hostinger web root (`public_html/.htaccess`)
     - Some upload tools skip dotfiles; `build_release.sh` copies `web/.htaccess` into `build/web/.htaccess` to help prevent this.

## One-time Service Worker Cleanup (Temporary)

To unstick existing users that still have an old Flutter service worker registered, `web/index.html` contains a temporary snippet that:

- unregisters service workers for this origin
- clears Cache Storage
- reloads the page once

Remove that snippet after 1–2 days (or after confirming most users have refreshed).

## Server Configuration (Hostinger):
- Upload the `.htaccess` file to your web root
- This ensures proper cache headers at the server level
- Hostinger supports .htaccess files by default

After deploy, verify key headers:
```bash
curl -I https://<domain>/main.dart.js | head
curl -I https://<domain>/flutter_bootstrap.js | head
curl -I https://<domain>/index.html | head
```
You should see `Cache-Control: no-cache, no-store, must-revalidate` on those files.

## How This Solves Your Problem:
- ✅ Users won't need to manually clear cache
- ✅ Browser automatically detects new versions
- ✅ Static assets are cached efficiently  
- ✅ HTML and critical files are never cached
- ✅ Works on Hostinger hosting

## Alternative: Automated Versioning
For automatic versioning, you could also use the build number from pubspec.yaml or timestamp-based versioning in a CI/CD pipeline.
