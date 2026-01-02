#!/bin/bash

# Cache Busting Version Incrementer for Flutter Web
# This script automatically increments the version numbers in index.html

echo "🚀 Incrementing cache busting version..."

# File to modify
INDEX_FILE="web/index.html"

# Check if file exists
if [ ! -f "$INDEX_FILE" ]; then
    echo "❌ Error: $INDEX_FILE not found!"
    exit 1
fi

# Get current version from flutter_bootstrap.js line
CURRENT_VERSION=$(grep -o 'flutter_bootstrap\.js?v=[0-9]*' "$INDEX_FILE" | grep -o '[0-9]*$')

if [ -z "$CURRENT_VERSION" ]; then
    echo "❌ Error: Could not find current version in $INDEX_FILE"
    exit 1
fi

# Calculate new version
NEW_VERSION=$((CURRENT_VERSION + 1))

echo "📈 Current version: $CURRENT_VERSION"
echo "📈 New version: $NEW_VERSION"

# Update flutter_bootstrap.js version
sed -i.bak "s/flutter_bootstrap\.js?v=$CURRENT_VERSION/flutter_bootstrap.js?v=$NEW_VERSION/g" "$INDEX_FILE"

# Update manifest.json version
sed -i.bak "s/manifest\.json?v=$CURRENT_VERSION/manifest.json?v=$NEW_VERSION/g" "$INDEX_FILE"

# Update version check script CURRENT_VERSION (match any number)
sed -i.bak "s/var CURRENT_VERSION = [0-9]*;/var CURRENT_VERSION = $NEW_VERSION;/g" "$INDEX_FILE"

# Remove backup file
rm "${INDEX_FILE}.bak"

echo "✅ Successfully updated version to $NEW_VERSION"
echo "📝 Modified files:"
echo "   - $INDEX_FILE"
echo ""
echo "🔄 Now run: flutter build web --release --pwa-strategy=none"
echo "📤 Then upload to Hostinger" 
