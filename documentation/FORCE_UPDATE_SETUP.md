# Force Update Setup Guide

This guide explains how to set up and manage the force update system for Android and iOS apps.

## Overview

The force update system checks the app version on startup and requires users to update if their version is below the minimum required version. This only applies to Android and iOS apps (not web).

## How It Works

1. **On App Startup**: The app checks Firebase Remote Config for minimum required versions
2. **Version Comparison**: Compares the installed version with the required version
3. **Force Update**: If the version is too old, shows a non-dismissible update dialog
4. **App Store Redirect**: Users are directed to Google Play Store or Apple App Store to update

## Firebase Remote Config Setup

### Step 1: Enable Remote Config in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **Alluvial Academy**
3. Navigate to **Remote Config** in the left sidebar
4. Click **Create configuration** if this is your first time

### Step 2: Add Required Parameters

Add these three parameters in Firebase Remote Config:

#### 1. `minimum_android_version`
- **Parameter key**: `minimum_android_version`
- **Default value**: `1.0.0`
- **Data type**: String
- **Description**: Minimum required version for Android app

#### 2. `minimum_ios_version`
- **Parameter key**: `minimum_ios_version`
- **Default value**: `1.0.0`
- **Data type**: String
- **Description**: Minimum required version for iOS app

#### 3. `force_update_enabled`
- **Parameter key**: `force_update_enabled`
- **Default value**: `true`
- **Data type**: Boolean
- **Description**: Enable or disable force update feature globally

### Step 3: Publish Changes

After adding the parameters, click **Publish changes** in Firebase Remote Config.

## App Store Configuration

### Android (Google Play Store)

1. Open `/Users/hashimniane/Project Dev/alluvial_academy/lib/core/services/version_service.dart`
2. Find the `getAppStoreUrl()` method
3. The Android URL is already configured:
   ```dart
   return 'https://play.google.com/store/apps/details?id=com.alluvaleducationhub.alluwalacademyadmin';
   ```
4. Verify this matches your actual Google Play Store package name

### iOS (Apple App Store)

1. Open `/Users/hashimniane/Project Dev/alluvial_academy/lib/core/services/version_service.dart`
2. Find the `getAppStoreUrl()` method
3. Replace `<YOUR_APP_STORE_ID>` with your actual App Store ID:
   ```dart
   return 'https://apps.apple.com/app/id<YOUR_APP_STORE_ID>';
   ```
4. You can find your App Store ID in App Store Connect

## Version Format

Versions must follow semantic versioning: `MAJOR.MINOR.PATCH`

Examples:
- `1.0.0` - Initial release
- `1.0.1` - Bug fix
- `1.1.0` - New features
- `2.0.0` - Major update

## How to Force an Update

### Example: Releasing Version 1.2.0

1. **Build and release** your app version `1.2.0` to the app stores
2. **Wait** until the update is live on Google Play and App Store (can take hours)
3. **Update Firebase Remote Config**:
   - Set `minimum_android_version` to `1.2.0`
   - Set `minimum_ios_version` to `1.2.0`
   - Click **Publish changes**
4. **Users with older versions** will now see the force update dialog

### To Temporarily Disable Force Update

1. Go to Firebase Remote Config
2. Set `force_update_enabled` to `false`
3. Click **Publish changes**

## Testing

### Test on Android

1. Build app with version `1.0.0`
2. Install on device
3. In Firebase Remote Config, set `minimum_android_version` to `1.1.0`
4. Close and reopen the app
5. You should see the force update dialog

### Test on iOS

Same steps as Android, but use `minimum_ios_version`

## Current App Version

To check your current app version:
- Open `pubspec.yaml`
- Look for the `version` field (e.g., `version: 1.0.0+1`)
- Format is `version+buildNumber`

## Updating App Version

Before releasing a new version:

1. **Update pubspec.yaml**:
   ```yaml
   version: 1.1.0+2
   ```
   (First number is version, second is build number)

2. **Build for Android**:
   ```bash
   flutter build appbundle --release
   ```

3. **Build for iOS**:
   ```bash
   flutter build ios --release
   ```

4. **Upload to stores**

5. **Update Remote Config** once live

## Troubleshooting

### Update dialog not showing

- Check that `force_update_enabled` is `true` in Remote Config
- Verify the minimum version is higher than the installed version
- Make sure Remote Config changes are published
- Try clearing app data and restarting

### Wrong app store URL

- Verify package name matches Google Play Store listing
- Verify App Store ID is correct for iOS
- Test the URLs directly in a browser

### Remote Config not updating

- Remote Config caches for 1 hour by default
- Use Firebase Console to verify the values
- Check app logs for any errors during fetch

## Firebase Remote Config Console Link

[Firebase Remote Config Dashboard](https://console.firebase.google.com/project/alluvial-academy/remoteconfig)

## Support

If you have issues:
1. Check Firebase Console for Remote Config status
2. Review app logs for errors
3. Verify app store URLs are correct
4. Test with a clean install of the app

