#!/bin/bash

# Automated Flutter Web Release Build with Cache Busting
# This script automatically increments version and builds for production

echo "🚀 Starting automated Flutter web release build..."
echo ""

# Step 1: Increment cache busting version
echo "📈 Step 1: Incrementing cache busting version..."
./increment_version.sh

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to increment version"
    exit 1
fi

echo ""

# Step 1.5: Read the updated cache-busting version for build metadata
INDEX_FILE="web/index.html"
VERSION=$(grep -o 'flutter_bootstrap\.js?v=[0-9]*' "$INDEX_FILE" | grep -o '[0-9]*$' | head -n 1)
if [ -z "$VERSION" ]; then
    echo "❌ Error: Could not detect cache busting version from $INDEX_FILE"
    exit 1
fi
echo "🏷️  Web build version: $VERSION"
echo ""

# Step 2: Build Flutter web app for release
echo "🔨 Step 2: Building Flutter web app for release..."
flutter build web --release --pwa-strategy=none --no-tree-shake-icons --dart-define=WEB_BUILD_VERSION=$VERSION

if [ $? -ne 0 ]; then
    echo "❌ Error: Flutter build failed"
    exit 1
fi

# Step 3: Ensure Hostinger config files are included in build output
echo ""
echo "🧩 Step 3: Copying Hostinger web root files (.htaccess)..."
cp web/.htaccess build/web/.htaccess

# Step 4: Ensure main.dart.js is cache-busted (helps unstick users with long-lived HTTP cache)
echo ""
echo "🔁 Step 4: Ensuring main.dart.js is cache-busted..."
BUILD_BOOTSTRAP="build/web/flutter_bootstrap.js"

if [ -n "$VERSION" ] && [ -f "$BUILD_BOOTSTRAP" ]; then
    # Try multiple patterns to match the minified format
    # Pattern 1: "mainJsPath":"main.dart.js"
    perl -pi -e "s/\"mainJsPath\":\"main\\.dart\\.js(\?v=\\d+)?\"/\"mainJsPath\":\"main.dart.js?v=$VERSION\"/g" "$BUILD_BOOTSTRAP"
    
    # Pattern 2: 'mainJsPath':'main.dart.js' (single quotes)
    perl -pi -e "s/'mainJsPath':'main\\.dart\\.js(\?v=\\d+)?'/'mainJsPath':'main.dart.js?v=$VERSION'/g" "$BUILD_BOOTSTRAP"
    
    # Pattern 3: mainJsPath:"main.dart.js" (no quotes on key)
    perl -pi -e "s/mainJsPath:\"main\\.dart\\.js(\?v=\\d+)?\"/mainJsPath:\"main.dart.js?v=$VERSION\"/g" "$BUILD_BOOTSTRAP"
    
    # Pattern 4: mainJsPath??"main.dart.js" (nullish coalescing in minified code)
    perl -pi -e "s/mainJsPath\?\?\"main\\.dart\\.js(\?v=\\d+)?\"/mainJsPath??\"main.dart.js?v=$VERSION\"/g" "$BUILD_BOOTSTRAP"
    
    # Verify the change was applied
    if grep -q "main.dart.js?v=$VERSION" "$BUILD_BOOTSTRAP"; then
        echo "   ✅ Patched flutter_bootstrap.js to load main.dart.js?v=$VERSION"
    else
        echo "   ⚠️  Warning: Could not verify version was added to main.dart.js"
        echo "   📝 Checking current content..."
        grep -o '"mainJsPath":"[^"]*"' "$BUILD_BOOTSTRAP" | head -1 || echo "   Pattern not found"
    fi
else
    echo "   - Skipped (could not detect version or bootstrap missing)"
fi

echo ""
echo "✅ Build completed successfully!"
echo ""
echo "📁 Output directory: build/web/"
echo "📤 Next steps:"
echo "   1. Upload the contents of 'build/web/' to your Hostinger hosting"
echo "🎉 Your website is ready for deployment with automatic cache busting!"
