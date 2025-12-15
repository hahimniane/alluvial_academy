#!/bin/bash

# =============================================================================
# Zoom Meeting SDK Setup Script
# =============================================================================
# This script sets up the Zoom Meeting SDK binaries for the Flutter project.
# 
# PREREQUISITES:
# 1. Download the Zoom Meeting SDK from the Zoom Marketplace
#    - Go to: https://developers.zoom.us/docs/meeting-sdk/create/
#    - Create a "General App" with Meeting SDK enabled
#    - Download the Android and iOS SDK packages
#
# 2. Set the ZOOM_SDK_SRC environment variable to the location of the SDKs
#    Default: /Users/hashimniane/Downloads
#
# USAGE:
#   ./tools/setup_zoom_meeting_sdk.sh
#
# =============================================================================

set -e

# Configuration
ZOOM_SDK_SRC="${ZOOM_SDK_SRC:-/Users/hashimniane/Downloads}"
ANDROID_SDK_VERSION="6.6.9.35200"
IOS_SDK_VERSION="6.6.9.29800"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Zoom Meeting SDK Setup Script"
echo "=========================================="
echo ""

# Get project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "Project root: $PROJECT_ROOT"
echo "SDK source: $ZOOM_SDK_SRC"
echo ""

# =============================================================================
# Validate SDK Source Directories
# =============================================================================

ANDROID_SDK_PATH="$ZOOM_SDK_SRC/zoom-sdk-android-$ANDROID_SDK_VERSION"
IOS_SDK_PATH="$ZOOM_SDK_SRC/zoom-sdk-ios-$IOS_SDK_VERSION"

echo "Checking for SDK packages..."

if [ ! -d "$ANDROID_SDK_PATH" ]; then
    echo -e "${RED}ERROR: Android SDK not found at:${NC}"
    echo "  $ANDROID_SDK_PATH"
    echo ""
    echo "Please download the Zoom Meeting SDK for Android from:"
    echo "  https://developers.zoom.us/docs/meeting-sdk/android/"
    echo ""
    echo "Or set ZOOM_SDK_SRC to the correct location:"
    echo "  export ZOOM_SDK_SRC=/path/to/sdk/downloads"
    exit 1
fi

if [ ! -d "$IOS_SDK_PATH" ]; then
    echo -e "${RED}ERROR: iOS SDK not found at:${NC}"
    echo "  $IOS_SDK_PATH"
    echo ""
    echo "Please download the Zoom Meeting SDK for iOS from:"
    echo "  https://developers.zoom.us/docs/meeting-sdk/ios/"
    echo ""
    echo "Or set ZOOM_SDK_SRC to the correct location:"
    echo "  export ZOOM_SDK_SRC=/path/to/sdk/downloads"
    exit 1
fi

echo -e "${GREEN}✓ SDK packages found${NC}"
echo ""

# =============================================================================
# Android Setup
# =============================================================================

echo "Setting up Android SDK..."

ANDROID_LIBS_DIR="$PROJECT_ROOT/android/app/libs/zoom"
mkdir -p "$ANDROID_LIBS_DIR"

# Find and copy AAR files
ANDROID_AAR_SOURCE="$ANDROID_SDK_PATH/mobilertc-android-studio/mobilertc/mobilertc.aar"

if [ -f "$ANDROID_AAR_SOURCE" ]; then
    cp "$ANDROID_AAR_SOURCE" "$ANDROID_LIBS_DIR/"
    echo -e "${GREEN}✓ Copied mobilertc.aar${NC}"
else
    echo -e "${RED}ERROR: mobilertc.aar not found at:${NC}"
    echo "  $ANDROID_AAR_SOURCE"
    exit 1
fi

# Check for additional AARs (commonlib, etc.)
DYNAMIC_BASE_AAR="$ANDROID_SDK_PATH/mobilertc-android-studio/dynamic_sample/libs/dynamic_base.aar"
if [ -f "$DYNAMIC_BASE_AAR" ]; then
    cp "$DYNAMIC_BASE_AAR" "$ANDROID_LIBS_DIR/"
    echo -e "${GREEN}✓ Copied dynamic_base.aar${NC}"
fi

# Copy proguard rules if available
PROGUARD_FILE="$ANDROID_SDK_PATH/proguard.cfg"
if [ -f "$PROGUARD_FILE" ]; then
    cp "$PROGUARD_FILE" "$PROJECT_ROOT/android/app/proguard-zoom.pro"
    echo -e "${GREEN}✓ Copied proguard rules${NC}"
fi

echo ""

# =============================================================================
# iOS Setup
# =============================================================================

echo "Setting up iOS SDK..."

IOS_ZOOM_DIR="$PROJECT_ROOT/ios/ZoomSDK"
mkdir -p "$IOS_ZOOM_DIR"

# Copy xcframeworks
IOS_LIB_DIR="$IOS_SDK_PATH/lib"

if [ -d "$IOS_LIB_DIR/MobileRTC.xcframework" ]; then
    cp -R "$IOS_LIB_DIR/MobileRTC.xcframework" "$IOS_ZOOM_DIR/"
    echo -e "${GREEN}✓ Copied MobileRTC.xcframework${NC}"
else
    echo -e "${RED}ERROR: MobileRTC.xcframework not found${NC}"
    exit 1
fi

if [ -d "$IOS_LIB_DIR/MobileRTCResources.bundle" ]; then
    cp -R "$IOS_LIB_DIR/MobileRTCResources.bundle" "$IOS_ZOOM_DIR/"
    echo -e "${GREEN}✓ Copied MobileRTCResources.bundle${NC}"
fi

if [ -d "$IOS_LIB_DIR/MobileRTCScreenShare.xcframework" ]; then
    cp -R "$IOS_LIB_DIR/MobileRTCScreenShare.xcframework" "$IOS_ZOOM_DIR/"
    echo -e "${GREEN}✓ Copied MobileRTCScreenShare.xcframework${NC}"
fi

if [ -d "$IOS_LIB_DIR/zoomcml.xcframework" ]; then
    cp -R "$IOS_LIB_DIR/zoomcml.xcframework" "$IOS_ZOOM_DIR/"
    echo -e "${GREEN}✓ Copied zoomcml.xcframework${NC}"
fi

echo ""

# =============================================================================
# Update Android build.gradle
# =============================================================================

echo "Updating Android build.gradle..."

ANDROID_BUILD_GRADLE="$PROJECT_ROOT/android/app/build.gradle"

# Check if flatDir is already configured
if ! grep -q "libs/zoom" "$ANDROID_BUILD_GRADLE"; then
    echo -e "${YELLOW}NOTE: You need to manually add the following to android/app/build.gradle:${NC}"
    echo ""
    echo "In the 'android' block, add:"
    echo ""
    echo "  repositories {"
    echo "      flatDir {"
    echo "          dirs 'libs/zoom'"
    echo "      }"
    echo "  }"
    echo ""
    echo "In the 'dependencies' block, add:"
    echo ""
    echo "  implementation(name: 'mobilertc', ext: 'aar')"
    echo ""
    echo "If using ProGuard, add to proguardFiles:"
    echo "  proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro', 'proguard-zoom.pro'"
    echo ""
else
    echo -e "${GREEN}✓ Android build.gradle already configured${NC}"
fi

# =============================================================================
# Update iOS Podfile
# =============================================================================

echo ""
echo "Checking iOS Podfile..."

IOS_PODFILE="$PROJECT_ROOT/ios/Podfile"

if ! grep -q "ZoomSDK" "$IOS_PODFILE"; then
    echo -e "${YELLOW}NOTE: You may need to update ios/Podfile to link the Zoom SDK frameworks.${NC}"
    echo ""
    echo "The flutter_zoom_meeting_sdk plugin should handle this automatically."
    echo "If you encounter build errors, see README_INTERNAL_ZOOM_MEETING_SDK.md"
    echo ""
else
    echo -e "${GREEN}✓ iOS Podfile appears configured${NC}"
fi

# =============================================================================
# Update iOS Info.plist
# =============================================================================

echo ""
echo "Checking iOS Info.plist..."

IOS_INFO_PLIST="$PROJECT_ROOT/ios/Runner/Info.plist"

if ! grep -q "NSCameraUsageDescription" "$IOS_INFO_PLIST"; then
    echo -e "${YELLOW}NOTE: Add the following to ios/Runner/Info.plist:${NC}"
    echo ""
    echo "  <key>NSCameraUsageDescription</key>"
    echo "  <string>We need camera access to enable video during Zoom meetings.</string>"
    echo "  <key>NSMicrophoneUsageDescription</key>"
    echo "  <string>We need microphone access to enable audio during Zoom meetings.</string>"
    echo ""
else
    echo -e "${GREEN}✓ iOS Info.plist has privacy descriptions${NC}"
fi

# =============================================================================
# Create .gitignore entries
# =============================================================================

echo ""
echo "Updating .gitignore..."

GITIGNORE_FILE="$PROJECT_ROOT/.gitignore"

# Add entries if not present
ENTRIES_TO_ADD=(
    "# Zoom SDK binaries (download from Zoom Marketplace)"
    "android/app/libs/zoom/"
    "ios/ZoomSDK/"
)

for entry in "${ENTRIES_TO_ADD[@]}"; do
    if ! grep -qF "$entry" "$GITIGNORE_FILE" 2>/dev/null; then
        echo "$entry" >> "$GITIGNORE_FILE"
    fi
done

echo -e "${GREEN}✓ Updated .gitignore${NC}"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "SDK files have been copied to:"
echo "  - Android: android/app/libs/zoom/"
echo "  - iOS: ios/ZoomSDK/"
echo ""
echo "Next steps:"
echo "  1. Review the manual configuration notes above"
echo "  2. Run 'flutter pub get' to install dependencies"
echo "  3. For iOS: Run 'cd ios && pod install'"
echo "  4. Build and test the app"
echo ""
echo "For troubleshooting, see:"
echo "  documentation/README_INTERNAL_ZOOM_MEETING_SDK.md"
echo ""
