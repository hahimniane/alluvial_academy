# Android Release Build Guide
## Successfully Created Release App Bundle

✅ **Release AAB Created Successfully!**

## Build Details

**File Location:**
```
/Users/hashimniane/Project Dev/alluvial_academy/build/app/outputs/bundle/release/app-release.aab
```

**File Size:** 61 MB

**Signing Certificate:**
- **Signer:** CN=Alluvial Education Hub, OU=Development, O=Alluvial Academy, L=Maine, ST=Maine, C=US
- **Algorithm:** SHA384withRSA, 2048-bit key
- **Valid From:** October 11, 2025
- **Valid Until:** February 26, 2053
- **Status:** ✅ jar verified

---

## Important Files (KEEP SECURE!)

### 1. Keystore File
**Location:** `/Users/hashimniane/Project Dev/alluvial_academy/android/app/upload-keystore.jks`

**CRITICAL:** This file is used to sign all future updates of your app. If you lose it, you cannot update your app on Google Play Store!

### 2. Key Properties File
**Location:** `/Users/hashimniane/Project Dev/alluvial_academy/android/key.properties`

**Contents:**
```properties
storePassword=alluvial2024
keyPassword=alluvial2024
keyAlias=upload
storeFile=upload-keystore.jks
```

### ⚠️ IMPORTANT: Backup These Files!

**Backup these files NOW to multiple secure locations:**
- External hard drive
- Cloud storage (encrypted)
- USB drive in safe location

**These files are in .gitignore and will NOT be pushed to GitHub (for security).**

---

## Upload to Google Play Console

### Step 1: Go to Google Play Console
1. Visit: https://play.google.com/console
2. Sign in with your Google account
3. Select your app (or create new app if first time)

### Step 2: Create a Release
1. Go to **Release** → **Production** (or **Internal testing** / **Closed testing**)
2. Click **Create new release**
3. Upload the AAB file:
   ```
   build/app/outputs/bundle/release/app-release.aab
   ```

### Step 3: Fill in Release Details
1. **Release name:** Version 1.0.0 (or your version)
2. **Release notes:** Describe what's new in this version
3. **Review and rollout**

### Step 4: Complete Store Listing
Make sure you've filled in:
- [ ] App name
- [ ] Short description
- [ ] Full description
- [ ] Screenshots (phone, tablet, etc.)
- [ ] Feature graphic
- [ ] Icon (512x512px)
- [ ] **Privacy Policy URL:** https://alluvaleducationhub.org/privacy-policy.html
- [ ] Content rating questionnaire
- [ ] App category
- [ ] Contact details

---

## Future Builds

### To create a new release build:

```bash
cd /Users/hashimniane/Project\ Dev/alluvial_academy

# Increment version in pubspec.yaml first!
# Update version: 1.0.0+1 -> 1.0.1+2 (for example)

# Clean previous build
flutter clean

# Build new release AAB
flutter build appbundle --release
```

### Important: Version Management

Update `pubspec.yaml` before each new release:

```yaml
version: 1.0.1+2  # Format: versionName+versionCode
```

- **versionName** (1.0.1): User-visible version
- **versionCode** (+2): Internal version number (must increment)

---

## Troubleshooting

### "You uploaded an APK signed in debug mode"
✅ **Fixed!** Your AAB is now properly signed with release certificate.

### "Invalid certificate chain" warning during verification
This is **NORMAL** for self-signed certificates. Google Play accepts self-signed certificates.

### Lost keystore file?
If you lose `upload-keystore.jks`, you **cannot** update your app. You would need to:
1. Create a new app with a new package name
2. Publish as a completely new app

That's why backing up is critical!

### Build fails with "strip debug symbols" error
This is just a warning and can be ignored. The AAB is still created successfully.

---

## Security Notes

### Passwords
Your keystore passwords are:
- **Store Password:** alluvial2024
- **Key Password:** alluvial2024

**For production apps, you should:**
1. Use strong, unique passwords
2. Store passwords in a password manager
3. Never commit passwords to version control
4. Share passwords only with authorized team members via secure channels

### Key Alias
Your key alias is: **upload**

This is used to identify which key in the keystore to use for signing.

---

## Build Configuration Files

### android/app/build.gradle
Configured with:
- Release signing configuration
- ProGuard disabled (minifyEnabled: false)
- Resource shrinking disabled
- Multi-dex enabled

### android/key.properties
Contains signing credentials (not in version control)

### .gitignore
Protects sensitive files:
- `/android/key.properties`
- `/android/app/upload-keystore.jks`
- `*.jks`
- `*.keystore`

---

## App Bundle vs APK

### App Bundle (AAB) - **Recommended**
- ✅ Smaller download size for users
- ✅ Google Play optimizes for each device
- ✅ Required for new apps on Google Play (since 2021)
- ✅ Your current build format

### APK - **For direct installation only**
- Use for testing on devices without Play Store
- Use for distribution outside of Play Store
- Build command: `flutter build apk --release`

---

## Additional Resources

### Google Play Console
- **URL:** https://play.google.com/console
- **Help Center:** https://support.google.com/googleplay/android-developer

### Flutter Documentation
- **Android deployment:** https://docs.flutter.dev/deployment/android
- **App signing:** https://docs.flutter.dev/deployment/android#signing-the-app

### Firebase
- Make sure Firebase is properly configured for production
- Test push notifications in production mode
- Verify all Firebase services work in release build

---

## Checklist Before Uploading

- [ ] Tested app in release mode on physical device
- [ ] Verified all Firebase services work
- [ ] Updated version number in pubspec.yaml
- [ ] Backed up keystore and key.properties files
- [ ] Completed privacy policy and uploaded to website
- [ ] Prepared screenshots and app store graphics
- [ ] Tested critical user flows (login, clock-in, forms, etc.)
- [ ] Verified app runs without debug console
- [ ] Tested on multiple devices/screen sizes if possible

---

## Contact Information to Update in Store Listing

Update these in your Google Play Console Store Listing:
- **Developer name:** Alluvial Education Hub
- **Email:** info@alluvaleducationhub.org
- **Website:** https://alluvaleducationhub.org
- **Privacy Policy:** https://alluvaleducationhub.org/privacy-policy.html

---

## Success! 🎉

Your release app bundle is ready for upload to Google Play Store!

**Next Steps:**
1. Backup keystore and key.properties files
2. Log in to Google Play Console
3. Upload the AAB file
4. Complete store listing details
5. Submit for review

**Good luck with your app launch!**

