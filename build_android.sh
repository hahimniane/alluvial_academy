#!/bin/bash

# Automated Flutter Android Release Build
# This script automatically increments version and builds APK for production

echo "🚀 Starting automated Flutter Android release build..."
echo ""

# Get current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
echo "📱 Current version: $CURRENT_VERSION"

# Extract version and build number
VERSION_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

# Calculate new build number
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="${VERSION_NUMBER}+${NEW_BUILD_NUMBER}"

echo "📈 New version: $NEW_VERSION"
echo ""

# Step 1: Update version in pubspec.yaml
echo "📝 Step 1: Updating version in pubspec.yaml..."
sed -i.bak "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to update version"
    mv pubspec.yaml.bak pubspec.yaml  # Restore backup on failure
    exit 1
fi

# Remove backup file
rm pubspec.yaml.bak
echo "✅ Version updated to $NEW_VERSION"
echo ""

# Step 2: Clean previous builds
echo "🧹 Step 2: Cleaning previous builds..."
flutter clean

if [ $? -ne 0 ]; then
    echo "❌ Error: Flutter clean failed"
    exit 1
fi

echo "✅ Clean completed"
echo ""

# Step 3: Get dependencies
echo "📦 Step 3: Getting dependencies..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to get dependencies"
    exit 1
fi

echo "✅ Dependencies updated"
echo ""

# Step 4: Build Android APK for release
echo "🔨 Step 4: Building Android APK for release..."
flutter build apk --release

if [ $? -ne 0 ]; then
    echo "❌ Error: Flutter build failed"
    exit 1
fi

echo ""
echo "✅ Build completed successfully!"
echo ""
echo "📁 APK Location: build/app/outputs/flutter-apk/app-release.apk"
echo "📊 APK Details:"
ls -lh build/app/outputs/flutter-apk/app-release.apk
echo ""
echo "🎉 Your Android APK is ready for distribution!"
echo "📤 You can now install it on Android devices or distribute it."
