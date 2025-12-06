#!/bin/bash

# iOS Build Script for App Store
# Usage: ./scripts/publish_ios.sh [version] [build_number]
# Example: ./scripts/publish_ios.sh 1.0.1 8
# 
# NOTE: This script only builds the iOS app. You still need to:
# 1. Open Xcode: open ios/Runner.xcworkspace
# 2. Archive: Product → Archive
# 3. Distribute: Distribute App → App Store Connect

set -e  # Exit on error

echo "🍎 iOS Build Script for App Store"
echo "=================================="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: iOS builds require macOS and Xcode"
    echo "   Please run this script on a Mac."
    exit 1
fi

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

# Build iOS (release mode)
echo "🔨 Building iOS app (release mode)..."
flutter build ios --release
echo ""

echo "✅ Build complete!"
echo ""
echo "📤 Next Steps:"
echo "   1. Open Xcode:"
echo "      open ios/Runner.xcworkspace"
echo ""
echo "   2. In Xcode:"
echo "      - Select 'Any iOS Device' (not simulator)"
echo "      - Product → Archive"
echo "      - Wait for archive to complete"
echo ""
echo "   3. Distribute:"
echo "      - In Organizer, click 'Distribute App'"
echo "      - Choose 'App Store Connect'"
echo "      - Follow upload wizard"
echo ""
echo "   4. In App Store Connect:"
echo "      - Go to: https://appstoreconnect.apple.com"
echo "      - Select your app"
echo "      - Add new version"
echo "      - Select uploaded build"
echo "      - Complete store listing and submit"
echo ""
echo "📖 Full guide: See PUBLISH_TO_STORES_GUIDE.md"

