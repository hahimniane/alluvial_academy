# Cache Busting Version Management

## How It Works
To prevent users from having to manually clear their cache when you update your website, we've implemented cache busting using URL versioning.

## Current Version: 1

## Files with Versioning:
- `flutter_bootstrap.js?v=1` - Main Flutter bootstrap loader
- `manifest.json?v=1` - Web app manifest

## Additional Cache Busting Methods Implemented:
- Cache-Control meta tags in HTML head
- HTTP headers for different file types (via Hostinger .htaccess if needed)

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
   flutter build web
   ```
4. **Upload to Hostinger**:
   - Upload the entire `build/web/` folder contents
   - Make sure to include the `.htaccess` file for optimal caching

## Server Configuration (Hostinger):
- Upload the `.htaccess` file to your web root
- This ensures proper cache headers at the server level
- Hostinger supports .htaccess files by default

## How This Solves Your Problem:
- ✅ Users won't need to manually clear cache
- ✅ Browser automatically detects new versions
- ✅ Static assets are cached efficiently  
- ✅ HTML and critical files are never cached
- ✅ Works on Hostinger hosting

## Alternative: Automated Versioning
For automatic versioning, you could also use the build number from pubspec.yaml or timestamp-based versioning in a CI/CD pipeline.