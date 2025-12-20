#!/bin/bash

# Android App Bundle Build Script for Google Play Store
# Usage: ./scripts/publish_android.sh [version] [build_number]
# Example: ./scripts/publish_android.sh 1.0.1 8

set -e  # Exit on error

echo "🚀 Android App Bundle Build Script"
echo "===================================="
echo ""

# Get version from arguments or use current
VERSION_NAME=${1:-"1.0.0"}
VERSION_CODE=${2:-"7"}

echo "📦 Version: $VERSION_NAME+$VERSION_CODE"
echo ""

# Update version in pubspec.yaml
echo "📝 Updating version in pubspec.yaml..."
sed -i.bak "s/^version: .*/version: $VERSION_NAME+$VERSION_CODE/" pubspec.yaml
rm -f pubspec.yaml.bak
echo "✅ Version updated to $VERSION_NAME+$VERSION_CODE"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
echo "✅ Clean complete"
echo ""

# Get dependencies
echo "📥 Getting dependencies..."
flutter pub get
echo "✅ Dependencies installed"
echo ""

# Check keystore
if [ ! -f "android/key.properties" ]; then
    echo "⚠️  WARNING: android/key.properties not found!"
    echo "   Please create it with your keystore configuration."
    echo "   See RELEASE_BUILD_GUIDE.md for instructions."
    exit 1
fi

if [ ! -f "android/app/upload-keystore.jks" ]; then
    echo "⚠️  WARNING: android/app/upload-keystore.jks not found!"
    echo "   Please create your keystore first."
    echo "   Run: keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload"
    exit 1
fi

echo "✅ Keystore configuration verified"
echo ""

# Build App Bundle
echo "🔨 Building App Bundle (AAB)..."
flutter build appbundle --release
echo ""

# Check if build succeeded
if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    FILE_SIZE=$(du -h "build/app/outputs/bundle/release/app-release.aab" | cut -f1)
    echo "✅ Build successful!"
    echo ""
    echo "📦 App Bundle Location:"
    echo "   build/app/outputs/bundle/release/app-release.aab"
    echo "   Size: $FILE_SIZE"
    echo ""
    echo "📤 Next Steps:"
    echo "   1. Go to Google Play Console: https://play.google.com/console"
    echo "   2. Navigate to: Release → Production"
    echo "   3. Click 'Create new release'"
    echo "   4. Upload: build/app/outputs/bundle/release/app-release.aab"
    echo "   5. Add release notes and submit"
    echo ""
    echo "📖 Full guide: See PUBLISH_TO_STORES_GUIDE.md"
else
    echo "❌ Build failed! Check errors above."
    exit 1
fi

