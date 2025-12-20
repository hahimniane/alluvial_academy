# Package Name Update Guide

## ✅ Package Name Changed

**Old:** `com.example.alluwalacademyadmin`  
**New:** `org.alluvaleducationhub.academy`

## What's Been Updated

✅ `android/app/build.gradle` - applicationId and namespace  
✅ `android/app/src/main/kotlin/.../MainActivity.kt` - package declaration and location  
✅ Build configuration

## ⚠️ Firebase Configuration Required

The build is failing because Firebase's `google-services.json` file is still configured for the old package name. You need to add the new package name to your Firebase project.

### Step 1: Go to Firebase Console

1. Visit: https://console.firebase.google.com/
2. Select project: **alluwal-academy**
3. Click the gear icon ⚙️ (Settings) → **Project settings**

### Step 2: Add New Android App

#### Option A: Add as New App (Recommended)
1. Scroll down to **Your apps** section
2. Click **Add app** button
3. Select **Android** icon
4. Enter details:
   - **Android package name:** `org.alluvaleducationhub.academy`
   - **App nickname:** Alluvial Academy (or any name)
   - **Debug signing certificate SHA-1:** (optional, skip for now)
5. Click **Register app**
6. **Download** the new `google-services.json` file
7. **Replace** the file at: `android/app/google-services.json`
8. Click **Next** → **Next** → **Continue to console**

#### Option B: Update Existing App (Alternative)
1. In **Your apps** section, find the existing Android app
2. Click on it to expand
3. Unfortunately, **you cannot change the package name** of an existing app
4. You must use **Option A** to add a new app with the new package name

### Step 3: Replace google-services.json

After downloading from Firebase Console:

```bash
# Replace the file
cp ~/Downloads/google-services.json /Users/hashimniane/Project\ Dev/alluvial_academy/android/app/google-services.json
```

Or manually:
1. Open the downloaded `google-services.json` file
2. Copy its contents
3. Paste into `android/app/google-services.json`

### Step 4: Verify the File

The new `google-services.json` should contain:

```json
{
  "client": [
    {
      "client_info": {
        "android_client_info": {
          "package_name": "org.alluvaleducationhub.academy"
        }
      }
    }
  ]
}
```

### Step 5: Rebuild the App

After updating the file:

```bash
cd /Users/hashimniane/Project\ Dev/alluvial_academy
flutter clean
flutter build appbundle --release
```

---

## Alternative: Keep Old Package Name (Not Recommended)

If you want to keep using `com.example.alluwalacademyadmin` temporarily (NOT recommended for production):

### Revert Changes

1. Change back in `android/app/build.gradle`:
   ```gradle
   namespace = "com.example.alluwalacademyadmin"
   applicationId = "com.example.alluwalacademyadmin"
   ```

2. Move MainActivity back:
   ```bash
   mkdir -p android/app/src/main/kotlin/com/example/alluwalacademyadmin
   # Update package in MainActivity.kt
   ```

**BUT** you'll still get rejected by Google Play Store because `com.example` is restricted!

---

## Why This Change is Necessary

### Google Play Store Restrictions

- ❌ **`com.example.*`** - Reserved for examples and testing
- ❌ **`com.test.*`** - Reserved for testing
- ❌ **`com.android.*`** - Reserved by Google

### Proper Package Naming

✅ Use reverse domain notation: `org.alluvaleducationhub.academy`
- **org** - Organization (non-profit)
- **alluvaleducationhub** - Your organization name
- **academy** - App/product name

---

## After Firebase Configuration

Once you've updated Firebase and rebuilt:

### Test the App

1. Install on a test device
2. Verify Firebase features work:
   - [ ] User authentication
   - [ ] Firestore database access
   - [ ] Cloud Storage
   - [ ] Cloud Functions
   - [ ] Push notifications

### Google Play Console

When uploading to Google Play:
- The package name will be: `org.alluvaleducationhub.academy`
- This will be **permanent** - you cannot change it later
- Make sure this is the name you want!

---

## Troubleshooting

### Build still fails after updating google-services.json

```bash
# Clean thoroughly
flutter clean
cd android && ./gradlew clean && cd ..
rm -rf build/
rm -rf android/.gradle/

# Rebuild
flutter build appbundle --release
```

### Firebase features not working

1. Wait 5-10 minutes after adding the app in Firebase Console
2. Make sure you downloaded the correct `google-services.json`
3. Verify the package name matches exactly: `org.alluvaleducationhub.academy`

### Want to test with old package name first

You can temporarily add BOTH apps to Firebase:
1. Keep the old `com.example.alluwalacademyadmin` entry
2. Add new `org.alluvaleducationhub.academy` entry
3. Download new `google-services.json` (it will include both)

---

## Current Status

✅ Code updated for new package name  
⏸️ **Waiting:** Firebase configuration update  
⏸️ **Waiting:** Rebuild after Firebase update

## Next Steps

1. **Go to Firebase Console** and add the new Android app
2. **Download** new `google-services.json`
3. **Replace** the file in your project
4. **Rebuild:** `flutter build appbundle --release`
5. **Upload** to Google Play Store

---

## Important Notes

### Package Name is Permanent

Once you upload to Google Play Store with a package name, you **CANNOT** change it. Ever. The only way is to:
- Create a completely new app listing
- Lose all reviews, ratings, and downloads
- Start from scratch

So make sure `org.alluvaleducationhub.academy` is the name you want!

### Keep Both Apps in Firebase

It's safe to keep both package names in your Firebase project:
- Old: `com.example.alluwalacademyadmin` (for testing/development)
- New: `org.alluvaleducationhub.academy` (for production)

This allows backward compatibility with any test builds.

---

**Ready to proceed?** Update Firebase Console and rebuild! 🚀

