# Building Mobile Apps - Instructions

## Summary

✅ **All three bugs have been fixed:**
1. ✅ Date mutation bug in `new_implementation.js` line 195
2. ✅ Null check added for `created_at_utc` in export function
3. ✅ Cloud Functions properly exported in `index.js`

✅ **Changes committed and pushed to GitHub branch:** `feature/connectteam-shift-tasks-redesign`

## Building Android APK

### Option 1: Build Debug APK (Easiest for Testing)

The build is currently failing due to:
1. Corrupted Gradle cache (needs complete cleanup)
2. Kotlin compilation errors in `emoji_picker_flutter` plugin

**To fix and build:**

```bash
# 1. Clean everything
flutter clean
cd android
./gradlew clean
cd ..

# 2. Delete Gradle cache completely (Windows PowerShell)
Remove-Item -Path "$env:USERPROFILE\.gradle\caches" -Recurse -Force -ErrorAction SilentlyContinue

# 3. Rebuild
flutter pub get
flutter build apk --debug
```

**If emoji_picker_flutter still fails**, temporarily comment it out in `pubspec.yaml`:
```yaml
# emoji_picker_flutter: ^1.6.4  # Temporarily disabled
```

### Option 2: Build Release APK (For Distribution)

**You need a signing key first:**

1. **Generate a keystore:**
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. **Create `android/key.properties`:**
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=<path-to-keystore>/upload-keystore.jks
```

3. **Build release APK:**
```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

### Option 3: Build App Bundle (For Play Store)

```bash
flutter build appbundle --release
```

The AAB will be at: `build/app/outputs/bundle/release/app-release.aab`

## Building iOS App (Mac Required)

```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode and:
1. Select your development team
2. Product → Archive
3. Distribute App → App Store Connect

## Current Issues

1. **Gradle Cache Corruption**: The transforms cache is corrupted. Full cleanup needed.
2. **emoji_picker_flutter Kotlin Errors**: Plugin has compatibility issues. Consider updating or removing temporarily.

## Next Steps

1. Clean Gradle cache completely
2. Try building debug APK again
3. If emoji_picker still fails, temporarily remove it from `pubspec.yaml`
4. Once debug build works, set up signing for release builds
5. For Play Store, create the keystore and build app bundle

## Publishing to Play Store

See the `README.md` file for detailed Play Store publishing instructions.

