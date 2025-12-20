# 📱 Complete Guide: Publishing to Google Play Store & Apple App Store

## 📋 Prerequisites Checklist

### For Both Platforms:
- ✅ App version updated in `pubspec.yaml` (currently: `1.0.0+7`)
- ✅ All features tested and working
- ✅ Privacy policy URL ready
- ✅ App icons and screenshots prepared

### Android Specific:
- ✅ Package name: `org.alluvaleducationhub.academy` (PERMANENT - cannot change after first release)
- ✅ Keystore configured (`android/key.properties` exists)
- ✅ Google Play Console account ($25 one-time fee)

### iOS Specific:
- ✅ Apple Developer Account ($99/year)
- ✅ Mac computer with Xcode installed
- ✅ Bundle identifier configured

---

## 🤖 Part 1: Google Play Store (Android)

### Step 1: Update Version Number

**Current version:** `1.0.0+7`

Before building, update in `pubspec.yaml`:
```yaml
version: 1.0.1+8  # Format: versionName+versionCode
```

**Important:**
- `versionName` (1.0.1) = User-visible version
- `versionCode` (8) = Internal build number (must increment each release)

### Step 2: Build App Bundle (AAB)

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build App Bundle for Play Store
flutter build appbundle --release
```

**Output location:**
```
build/app/outputs/bundle/release/app-release.aab
```

**File size:** ~60-70 MB (expected)

### Step 3: Verify Keystore Configuration

Check that `android/key.properties` exists and contains:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

**If missing keystore:**
```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Step 4: Google Play Console Setup

#### 4.1 Create/Select App
1. Go to: https://play.google.com/console
2. Click **Create app** (or select existing)
3. Fill in:
   - **App name:** Alluvial Academy
   - **Default language:** English
   - **App or game:** App
   - **Free or paid:** Free (or Paid)
   - **Declarations:** Check all required boxes

#### 4.2 Upload App Bundle
1. Navigate to: **Release** → **Production** (or **Testing** for initial release)
2. Click **Create new release**
3. Click **Upload** button
4. Select: `build/app/outputs/bundle/release/app-release.aab`
5. Wait for upload (~2-5 minutes)
6. Google will validate the bundle

#### 4.3 Release Details
**Release name:** `1.0.1` (match your versionName)

**Release notes (What's new):**
```
Version 1.0.1

New Features:
• Shift rescheduling - Teachers can request schedule adjustments
• Schedule issue reporting - Report timezone or time issues
• Improved payment calculation - Accurate wage tracking
• Auto clock-out at scheduled end time
• Enhanced timesheet synchronization

Bug Fixes:
• Fixed payment display issues
• Improved shift status updates
• Better timezone handling
```

### Step 5: Complete Store Listing

#### Required Assets:
1. **App Icon:** 512×512 PNG (transparent background)
2. **Feature Graphic:** 1024×500 PNG
3. **Screenshots:** 
   - Phone: At least 2, up to 8 (min 320px, max 3840px)
   - Tablet (optional): 7" and 10" screenshots
4. **Short Description:** 80 characters max
   ```
   Islamic education management system for teachers, students, and administrators
   ```
5. **Full Description:** 4000 characters max
   ```
   Alluvial Academy is a comprehensive Islamic education management platform 
   designed for teachers, students, and administrators.
   
   Features:
   • Role-based dashboards for teachers, students, and admins
   • Teaching shift management and scheduling
   • Time clock with GPS location tracking
   • Timesheet review and wage calculation
   • Form builder and response collection
   • Real-time chat and messaging
   • Task management system
   • Islamic calendar with prayer times
   
   Perfect for Islamic schools, online academies, and educational institutions.
   ```

### Step 6: Content Rating & Privacy

1. **Content Rating:**
   - Complete questionnaire
   - Get rating certificate (usually "Everyone" or "Teen")

2. **Privacy Policy:**
   - URL required (e.g., `https://alluvaleducationhub.org/privacy-policy`)
   - Must be publicly accessible
   - Must cover data collection and usage

3. **Data Safety:**
   - Declare data collection practices
   - Location data: Yes (for clock-in/out)
   - Personal info: Yes (user accounts)
   - App activity: Yes (timesheet tracking)

### Step 7: Pricing & Distribution

1. **Pricing:**
   - Free or Paid (set your choice)
   - Countries: Select all or specific regions

2. **App Access:**
   - All users (public)
   - Or restricted access (if applicable)

### Step 8: Review & Submit

1. Check all sections show ✅ green checkmarks:
   - ☑️ App content
   - ☑️ Store listing
   - ☑️ Pricing & distribution
   - ☑️ Content rating
   - ☑️ Privacy policy
   - ☑️ Target audience
   - ☑️ App access

2. Click **Submit for review**

3. **Review Timeline:** 1-3 business days (usually 24-48 hours)

4. **Status Updates:**
   - You'll receive email notifications
   - Check Play Console for status updates

---

## 🍎 Part 2: Apple App Store (iOS)

### Step 1: Update Version Number

Same as Android - update in `pubspec.yaml`:
```yaml
version: 1.0.1+8
```

### Step 2: Configure iOS Bundle Identifier

1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select **Runner** in project navigator
3. Go to **Signing & Capabilities** tab
4. Set **Bundle Identifier:** `org.alluvaleducationhub.academy`
5. Select your **Team** (Apple Developer account)
6. Xcode will auto-generate provisioning profile

### Step 3: Build iOS App

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build iOS (release mode)
flutter build ios --release
```

### Step 4: Archive in Xcode

1. **Open Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Select Device:**
   - In top toolbar, select **Any iOS Device** (not simulator)

3. **Product → Archive:**
   - Wait for build to complete (~5-10 minutes)
   - Xcode Organizer will open automatically

4. **Verify Archive:**
   - Check version number matches
   - Verify signing certificate

### Step 5: Distribute to App Store Connect

1. In **Xcode Organizer**, select your archive
2. Click **Distribute App**
3. Choose **App Store Connect**
4. Click **Next**
5. Select **Upload**
6. Click **Next**
7. **Distribution Options:**
   - ☑️ Include bitcode for iOS content (if available)
   - ☑️ Upload your app's symbols (recommended)
8. Click **Next**
9. **App Thinning:**
   - Select **All compatible device variants**
10. Click **Upload**
11. Wait for upload (~10-20 minutes)

### Step 6: App Store Connect Setup

#### 6.1 Create App Record
1. Go to: https://appstoreconnect.apple.com
2. Click **My Apps** → **+** (Create App)
3. Fill in:
   - **Platform:** iOS
   - **Name:** Alluvial Academy
   - **Primary Language:** English
   - **Bundle ID:** `org.alluvaleducationhub.academy`
   - **SKU:** `alluvial-academy-ios` (unique identifier)
   - **User Access:** Full Access

#### 6.2 App Information
- **Category:** Education
- **Subcategory:** (optional)
- **Content Rights:** Check if you have rights to use content

#### 6.3 Pricing & Availability
- **Price:** Free (or set price)
- **Availability:** All countries (or select specific)

#### 6.4 Version Information
1. Click **+ Version** or **1.0.1 Prepare for Submission**
2. **What's New in This Version:**
   ```
   Version 1.0.1
   
   New Features:
   • Shift rescheduling - Teachers can request schedule adjustments
   • Schedule issue reporting - Report timezone or time issues
   • Improved payment calculation - Accurate wage tracking
   • Auto clock-out at scheduled end time
   • Enhanced timesheet synchronization
   
   Bug Fixes:
   • Fixed payment display issues
   • Improved shift status updates
   • Better timezone handling
   ```

#### 6.5 App Store Assets

**Required Screenshots:**
- **6.7" iPhone (iPhone 14 Pro Max):** 1290×2796 pixels
- **6.5" iPhone (iPhone 11 Pro Max):** 1242×2688 pixels
- **5.5" iPhone (iPhone 8 Plus):** 1242×2208 pixels
- **iPad Pro (12.9"):** 2048×2732 pixels (optional but recommended)

**App Icon:**
- 1024×1024 PNG (no transparency, no rounded corners)

**App Preview Video:** (Optional but recommended)
- 15-30 seconds
- Show key features

**Description:**
```
Alluvial Academy is a comprehensive Islamic education management platform 
designed for teachers, students, and administrators.

Features:
• Role-based dashboards for teachers, students, and admins
• Teaching shift management and scheduling
• Time clock with GPS location tracking
• Timesheet review and wage calculation
• Form builder and response collection
• Real-time chat and messaging
• Task management system
• Islamic calendar with prayer times

Perfect for Islamic schools, online academies, and educational institutions.
```

**Keywords:** (100 characters max, comma-separated)
```
islamic,education,academy,teacher,student,management,schedule,timesheet
```

**Support URL:** 
```
https://alluvaleducationhub.org/support
```

**Marketing URL:** (Optional)
```
https://alluvaleducationhub.org
```

#### 6.6 App Privacy

1. Click **App Privacy** section
2. **Data Collection:**
   - Location: Yes (for clock-in/out verification)
   - Personal Information: Yes (user accounts)
   - Usage Data: Yes (app analytics)
3. **Privacy Policy URL:** Required
   ```
   https://alluvaleducationhub.org/privacy-policy
   ```

#### 6.7 Age Rating

Complete questionnaire:
- **Violence:** None
- **Sexual Content:** None
- **Profanity:** None
- **Horror:** None
- **Gambling:** None
- **Drugs:** None
- **Mature/Suggestive Themes:** None
- **Contests:** None
- **Unrestricted Web Access:** No
- **Gambling/Contests:** No

**Expected Rating:** 4+ (Everyone)

### Step 7: Submit for Review

1. **Build Selection:**
   - Select the uploaded build (1.0.1)
   - If build doesn't appear, wait 10-15 minutes and refresh

2. **Export Compliance:**
   - Answer encryption questions
   - Usually: "No, app does not use encryption"

3. **Advertising Identifier:**
   - Select if you use advertising ID
   - Usually: "No"

4. **Content Rights:**
   - Confirm you have rights to all content

5. **Review Information:**
   - **Contact Information:** Your email/phone
   - **Demo Account:** (Optional) Provide test account if needed
   - **Notes:** Any special instructions for reviewers

6. **Version Release:**
   - **Automatically release:** After approval
   - **Manually release:** You control when to release

7. Click **Submit for Review**

### Step 8: Review Process

**Timeline:**
- Initial review: 24-48 hours
- If rejected: Fix issues and resubmit
- If approved: App goes live (or on your scheduled date)

**Status Updates:**
- You'll receive email notifications
- Check App Store Connect for status

---

## 🔄 Future Updates

### For Both Platforms:

1. **Update Version:**
   ```yaml
   # pubspec.yaml
   version: 1.0.2+9  # Increment both numbers
   ```

2. **Build & Upload:**
   - Android: `flutter build appbundle --release`
   - iOS: `flutter build ios --release` → Archive in Xcode

3. **Update Release Notes:**
   - Describe new features and bug fixes

4. **Submit:**
   - Android: Usually auto-approved for updates
   - iOS: May require review (usually faster than initial)

---

## 📝 Important Notes

### Android:
- ⚠️ **Package name is PERMANENT** - Cannot change after first release
- ⚠️ **Keep keystore safe** - Cannot update app if lost
- ✅ App Bundle (AAB) is required (not APK)
- ✅ Version code must increment each release

### iOS:
- ⚠️ **Bundle ID is PERMANENT** - Cannot change after first release
- ⚠️ **Apple Developer account required** - $99/year
- ✅ Requires Mac and Xcode
- ✅ Build number must increment each release

### Both:
- ✅ Test thoroughly before submitting
- ✅ Privacy policy URL must be accessible
- ✅ Screenshots must match actual app
- ✅ Follow platform guidelines strictly

---

## 🆘 Troubleshooting

### Android Build Issues:

**"SigningConfig 'release' is missing required property 'storeFile'"**
- Check `android/key.properties` exists
- Verify keystore path is correct

**"Keystore was tampered with, or password was incorrect"**
- Double-check passwords in `key.properties`
- No extra spaces or quotes

### iOS Build Issues:

**"No signing certificate found"**
- Open Xcode → Preferences → Accounts
- Add your Apple ID
- Download certificates

**"Provisioning profile not found"**
- In Xcode, select your team
- Xcode will auto-generate profile

**"Archive not appearing in App Store Connect"**
- Wait 10-15 minutes after upload
- Check email for processing status
- Verify bundle ID matches

---

## ✅ Final Checklist

### Before Submitting:

- [ ] Version number updated in `pubspec.yaml`
- [ ] App tested on real devices
- [ ] All features working correctly
- [ ] Privacy policy URL accessible
- [ ] Screenshots prepared (correct sizes)
- [ ] App icon ready (1024×1024)
- [ ] Release notes written
- [ ] Store listing descriptions complete
- [ ] Content rating completed
- [ ] Data safety/privacy information filled

### Android Specific:
- [ ] App Bundle (AAB) built successfully
- [ ] Keystore configured and backed up
- [ ] Package name verified: `org.alluvaleducationhub.academy`

### iOS Specific:
- [ ] Archive created successfully
- [ ] Uploaded to App Store Connect
- [ ] Bundle ID verified: `org.alluvaleducationhub.academy`
- [ ] Certificates and profiles configured

---

**Good luck with your app launch! 🚀**

For questions or issues, refer to:
- Android: https://support.google.com/googleplay/android-developer
- iOS: https://developer.apple.com/support/

