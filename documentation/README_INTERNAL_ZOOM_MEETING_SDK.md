# Zoom Meeting SDK Integration (Internal Documentation)

## Overview

This document describes how to set up and maintain the Zoom Meeting SDK integration for in-app Zoom meeting join functionality in the Alluwal Education Hub app.

**IMPORTANT**: The Zoom Meeting SDK binaries are NOT committed to the repository. You must download them from the Zoom Marketplace and run the setup script.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Zoom Marketplace Setup](#zoom-marketplace-setup)
3. [SDK Download](#sdk-download)
4. [Running the Setup Script](#running-the-setup-script)
5. [Environment Variables](#environment-variables)
6. [Android Configuration](#android-configuration)
7. [iOS Configuration](#ios-configuration)
8. [Common Build Errors](#common-build-errors)
9. [Version Compatibility](#version-compatibility)
10. [Security Considerations](#security-considerations)

---

## Prerequisites

- Flutter SDK 3.4.3+
- Xcode 15+ (for iOS)
- Android Studio / Android SDK
- A Zoom account with developer access
- Access to Zoom Marketplace

---

## Zoom Marketplace Setup

### 1. Create a General App

1. Go to [Zoom Marketplace](https://marketplace.zoom.us/)
2. Click **Develop** → **Build App**
3. Choose **General App** (NOT OAuth App or Webhook Only)
4. Fill in the app details

### 2. Enable Meeting SDK

1. In your app settings, go to **Features** → **Embed**
2. Toggle **Meeting SDK** to ON
3. Save changes

### 3. Get Credentials

You need TWO sets of credentials:

#### Zoom API Credentials (for creating meetings)
- Found in: **App Credentials** tab
- Values needed:
  - Account ID
  - Client ID
  - Client Secret

#### Meeting SDK Credentials (for joining meetings in-app)
- Found in: **Embed** → **Meeting SDK** section
- Values needed:
  - SDK Key (also called Client ID)
  - SDK Secret (also called Client Secret)

**IMPORTANT**: The Meeting SDK credentials may be different from the API credentials!

---

## SDK Download

### 1. Download SDK Packages

From the Zoom Marketplace app page, download:

- **Android SDK**: `zoom-sdk-android-6.6.9.35200` (or latest)
- **iOS SDK**: `zoom-sdk-ios-6.6.9.29800` (or latest)

### 2. Extract to Downloads

Extract both packages to `/Users/hashimniane/Downloads/` (or set `ZOOM_SDK_SRC` environment variable to your location).

Expected structure:
```
/Users/hashimniane/Downloads/
├── zoom-sdk-android-6.6.9.35200/
│   ├── mobilertc-android-studio/
│   │   └── mobilertc/
│   │       └── mobilertc.aar
│   └── proguard.cfg
└── zoom-sdk-ios-6.6.9.29800/
    └── lib/
        ├── MobileRTC.xcframework/
        ├── MobileRTCResources.bundle/
        ├── MobileRTCScreenShare.xcframework/
        └── zoomcml.xcframework/
```

---

## Running the Setup Script

```bash
# From project root
./tools/setup_zoom_meeting_sdk.sh

# Or with custom SDK location
ZOOM_SDK_SRC=/path/to/sdks ./tools/setup_zoom_meeting_sdk.sh
```

The script will:
1. Validate SDK packages exist
2. Copy Android AARs to `android/app/libs/zoom/`
3. Copy iOS frameworks to `ios/ZoomSDK/`
4. Update `.gitignore`
5. Print manual configuration steps

---

## Environment Variables

### Firebase Functions (.env)

Add these to `functions/.env`:

```env
# Existing Zoom API credentials
ZOOM_ACCOUNT_ID=your_account_id
ZOOM_CLIENT_ID=your_api_client_id
ZOOM_CLIENT_SECRET=your_api_client_secret
ZOOM_HOST_USER=your_host_email@example.com
ZOOM_JOIN_TOKEN_SECRET=random_secret_for_tokens
ZOOM_ENCRYPTION_KEY_B64=base64_encoded_32_byte_key

# NEW: Meeting SDK credentials
ZOOM_MEETING_SDK_KEY=your_sdk_key
ZOOM_MEETING_SDK_SECRET=your_sdk_secret
```

### Generate Encryption Key

```bash
# Generate a random 32-byte key
openssl rand -base64 32
```

---

## Android Configuration

### 1. Update build.gradle

In `android/app/build.gradle`:

```gradle
android {
    // ... existing config ...

    repositories {
        flatDir {
            dirs 'libs/zoom'
        }
    }
}

dependencies {
    // ... existing dependencies ...
    
    // Zoom Meeting SDK
    implementation(name: 'mobilertc', ext: 'aar')
}
```

### 2. ProGuard Rules (if using minification)

In `android/app/build.gradle`:

```gradle
buildTypes {
    release {
        proguardFiles getDefaultProguardFile('proguard-android.txt'), 
                      'proguard-rules.pro', 
                      'proguard-zoom.pro'
    }
}
```

### 3. AndroidManifest.xml Permissions

Ensure these permissions exist in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

---

## iOS Configuration

### 1. Info.plist Privacy Descriptions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to enable video during Zoom meetings.</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access to enable audio during Zoom meetings.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>We need Bluetooth access for audio devices during Zoom meetings.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>We need Bluetooth access for audio devices during Zoom meetings.</string>
```

### 2. Pod Install

```bash
cd ios
pod install
cd ..
```

### 3. Xcode Framework Configuration

If the flutter_zoom_meeting_sdk plugin doesn't automatically link the frameworks, you may need to:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Go to Runner target → General → Frameworks, Libraries, and Embedded Content
3. Add `MobileRTC.xcframework` from `ios/ZoomSDK/`
4. Set to "Embed & Sign"

---

## Common Build Errors

### Android: "Could not find mobilertc.aar"

**Cause**: AAR not copied or build.gradle not configured.

**Fix**:
1. Run setup script: `./tools/setup_zoom_meeting_sdk.sh`
2. Verify `android/app/libs/zoom/mobilertc.aar` exists
3. Check `flatDir` configuration in build.gradle

### iOS: "MobileRTC.framework not found"

**Cause**: Framework not copied or not linked.

**Fix**:
1. Run setup script
2. Verify `ios/ZoomSDK/MobileRTC.xcframework/` exists
3. Run `cd ios && pod install`
4. Clean build: `flutter clean && flutter build ios`

### iOS: "Undefined symbol: _OBJC_CLASS_$_MobileRTC"

**Cause**: Framework not properly linked.

**Fix**:
1. Open Xcode workspace
2. Verify framework is in "Embed & Sign"
3. Clean and rebuild

### Flutter: "flutter_zoom_meeting_sdk not working with SDK 6.6.9"

**Cause**: The plugin was tested with SDK 6.4.3, API may have changed.

**Fix Options**:
1. Check plugin documentation for SDK compatibility
2. Downgrade to SDK 6.4.3 if needed
3. Update plugin integration code

---

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| Flutter SDK | 3.4.3+ | Required |
| flutter_zoom_meeting_sdk | 0.0.11 | Tested with 6.4.3 |
| Zoom Android SDK | 6.6.9.35200 | Current |
| Zoom iOS SDK | 6.6.9.29800 | Current |

If build issues occur with SDK 6.6.9, consider downloading SDK 6.4.3 from Zoom's release archive.

---

## Security Considerations

### DO NOT:
- Commit SDK binaries to version control
- Log meeting passcodes or JWT tokens
- Store Meeting SDK secrets in client code
- Share `.env` files publicly

### DO:
- Keep SDK binaries in `.gitignore`
- Generate JWT on server only
- Use encrypted storage for passcodes
- Rotate secrets periodically

### JWT Security

Meeting SDK JWTs are:
- Generated on the server only
- Valid for minimum 30 minutes, maximum 48 hours
- Scoped to app key only (not meeting-specific)
- Should be fetched fresh for each join attempt

---

## Troubleshooting

### Checking SDK Integration

```bash
# Verify Android
ls -la android/app/libs/zoom/

# Verify iOS
ls -la ios/ZoomSDK/
```

### Testing Join Flow

1. Create a test shift with Zoom meeting
2. Set shift time to current time (within join window)
3. Tap "Join" in the app
4. Check logs for state transitions:
   - preflight → fetchingPayload → sdkInitializing → sdkAuthenticating → joining → inMeeting

### Log Locations

- Flutter: `flutter run` console output
- Android: `adb logcat | grep ZoomSDK`
- iOS: Xcode console
- Firebase Functions: Firebase Console → Functions → Logs

---

## Rollback to WebView Join

If Meeting SDK join has issues, you can temporarily revert to the legacy WebView join:

1. Set Remote Config `useLegacyZoomJoin` to `true`
2. The app will use the old `getZoomJoinUrl` → WebView flow

---

## Support

For SDK-specific issues:
- [Zoom Developer Documentation](https://developers.zoom.us/docs/meeting-sdk/)
- [Zoom Developer Forum](https://devforum.zoom.us/)

For app integration issues:
- Check the Flutter console for detailed errors
- Review Firebase Functions logs for backend errors
