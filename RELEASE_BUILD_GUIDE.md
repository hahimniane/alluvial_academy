# Building Release APK - Step by Step Guide

## Step 1: Generate a Keystore

Run this command in your project root (replace with your own details):

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**You'll be prompted for:**
- **Keystore password**: Choose a strong password (remember this!)
- **Key password**: Can be same as keystore password
- **Your name**: Your name or organization
- **Organizational Unit**: e.g., "Development"
- **Organization**: e.g., "Alluwal Academy"
- **City**: Your city
- **State**: Your state/province
- **Country code**: e.g., "US" or "CA"

**Important:** Save these passwords securely! You'll need them for future builds.

## Step 2: Create key.properties File

Create `android/key.properties` with this content (replace with your actual values):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

**Security Note:** The `key.properties` file is already in `.gitignore`, so it won't be committed to GitHub.

## Step 3: Build Release APK

Once the keystore and key.properties are set up:

```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Step 4: Build App Bundle (For Play Store)

For Google Play Store, you need an App Bundle instead of APK:

```bash
flutter build appbundle --release
```

The AAB will be at: `build/app/outputs/bundle/release/app-release.aab`

## Troubleshooting

### "SigningConfig 'release' is missing required property 'storeFile'"
- Make sure `android/key.properties` exists and has correct paths
- Make sure `upload-keystore.jks` exists in `android/app/` directory

### "Keystore was tampered with, or password was incorrect"
- Double-check your passwords in `key.properties`
- Make sure there are no extra spaces or quotes

### Forgot your keystore password?
- Unfortunately, you cannot recover it. You'll need to create a new keystore.
- **Important:** If you already published to Play Store with an old keystore, you MUST use the same one. Contact Google Play support if you lost it.

