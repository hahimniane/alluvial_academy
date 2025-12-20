# iOS Development Build Guide
## Build an App That Runs for 7 Days Without Debug Mode

This guide will help you create an iOS build that runs on your device for 7 days without needing to be connected to your computer.

---

## Quick Method: Build Directly to Device (7 Days)

### Step 1: Open Xcode Workspace
```bash
cd /Users/hashimniane/Project\ Dev/alluvial_academy
open ios/Runner.xcworkspace
```

### Step 2: Select Your Device
1. At the top of Xcode, click the device dropdown (next to "Runner")
2. Select your physical iPhone (e.g., "Hashim's iPhone 12 Pro Max")
3. Make sure it's NOT "Any iOS Device (arm64)"

### Step 3: Select "Release" Configuration
1. Go to menu: **Product** → **Scheme** → **Edit Scheme...**
2. On the left sidebar, click **Run**
3. In the **Info** tab, change **Build Configuration** from "Debug" to "Release"
4. Click **Close**

### Step 4: Build and Run
1. Click the **Play** button (▶️) at the top left, or press `Cmd + R`
2. Wait for the build to complete (this will take a few minutes)
3. The app will install and launch on your device

### Step 5: Trust the App on Your Device
1. On your iPhone, go to **Settings** → **General** → **VPN & Device Management**
2. Find your Apple ID / Development Team
3. Tap it and click **Trust**
4. The app will now run for **7 days** without needing to be connected

---

## Better Method: Archive Build (90 Days via TestFlight or 1 Year via Ad Hoc)

This requires proper signing certificates. Since you're getting signing errors, you need to set this up first.

### Prerequisites: Fix Apple Developer Account Setup

#### Issue 1: Bundle Identifier
Your app is using the default `com.example.alluwalacademyadmin`. You should change this:

1. In Xcode, click **Runner** (blue icon at top of file tree)
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Change **Bundle Identifier** to: `org.alluwaleducationhub.academy`
   (This matches your organization name)

#### Issue 2: Team Permissions
The error says: *Team "Hassimiou Niane" does not have permission to create "iOS App Store" provisioning profiles.*

This is because you're using a **free Apple Developer account**, which has limitations:
- ✅ Can build to device for 7 days
- ❌ Cannot create Distribution builds
- ❌ Cannot publish to App Store
- ❌ Cannot use TestFlight

**To fix this, you need to:**
1. **Enroll in Apple Developer Program** ($99/year)
   - Go to: https://developer.apple.com/programs/enroll/
   - This gives you:
     - Distribution certificates
     - TestFlight (90 days per build)
     - App Store publishing
     - Push notifications
     - Advanced features

#### Issue 3: Multiple Teams Detected
I see you have two team IDs in your project:
- `A988XAB3D3` (in one error)
- `GRKB7BXVZK` (in another error)

You should use only one team. To fix this:

1. In Xcode, click **Runner** (blue icon at top)
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Under **Debug** section, select your team
5. Under **Release** section, select the **same** team
6. Check **Automatically manage signing**

---

## Option A: Quick 7-Day Build (Free Account)

**What you get:**
- ✅ Runs for 7 days
- ✅ No computer needed after install
- ✅ Release mode (better performance)
- ❌ Need to rebuild every 7 days

**Steps:**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select your device
3. Edit Scheme → Run → Build Configuration → **Release**
4. Click Play (▶️) to build and run
5. Done! App runs for 7 days

---

## Option B: TestFlight Build (Paid Account - 90 Days)

**What you get:**
- ✅ Runs for 90 days per build
- ✅ Can distribute to up to 10,000 testers
- ✅ Professional testing platform
- ✅ Automatic updates
- 💰 Requires $99/year Apple Developer Program

**Steps:**

### 1. Enroll in Apple Developer Program
Visit: https://developer.apple.com/programs/enroll/

### 2. Create App Store Connect Record
1. Go to: https://appstoreconnect.apple.com/
2. Click **My Apps** → **+** → **New App**
3. Fill in details:
   - Platform: iOS
   - Name: Alluvial Academy
   - Bundle ID: org.alluwaleducationhub.academy (create new)
   - SKU: alluvial-academy-001
   - User Access: Full Access

### 3. Archive in Xcode
```bash
# In Xcode:
# 1. Select "Any iOS Device (arm64)" as target
# 2. Product → Archive
# 3. Wait for build to complete (5-10 minutes)
# 4. Window will open showing your archive
```

### 4. Distribute to TestFlight
1. Click **Distribute App**
2. Select **TestFlight & App Store**
3. Click **Next** through the steps
4. Upload will begin (10-15 minutes)
5. Wait for Apple to process (30 minutes - 2 hours)

### 5. Add Testers
1. Go to App Store Connect → TestFlight
2. Add yourself as an internal tester
3. Install TestFlight app on your iPhone
4. Accept invitation and download

---

## Option C: Ad Hoc Distribution (Paid Account - 1 Year)

**What you get:**
- ✅ Runs for 1 year
- ✅ Can install on up to 100 registered devices
- ✅ No TestFlight app needed
- ✅ Install via cable or over-the-air
- 💰 Requires $99/year Apple Developer Program

**Steps:**

### 1. Register Your Device
1. Go to: https://developer.apple.com/account/resources/devices/list
2. Click **+** button
3. Enter device name and UDID
   - To get UDID: Connect iPhone → Xcode → Window → Devices and Simulators → Copy identifier

### 2. Create Ad Hoc Provisioning Profile
1. Go to: https://developer.apple.com/account/resources/profiles/list
2. Click **+** button
3. Select **Ad Hoc** → Continue
4. Select your App ID → Continue
5. Select your certificate → Continue
6. Select your device(s) → Continue
7. Name it: "Alluvial Academy Ad Hoc"
8. Download and double-click to install

### 3. Build Ad Hoc IPA in Xcode
1. In Xcode, select **Any iOS Device (arm64)**
2. **Product** → **Archive**
3. When done, click **Distribute App**
4. Select **Ad Hoc** → Next
5. Follow through the steps
6. Click **Export** and save the IPA file

### 4. Install on Device
**Method 1: Via Xcode**
1. **Window** → **Devices and Simulators**
2. Select your device
3. Click **+** under "Installed Apps"
4. Select the exported IPA file

**Method 2: Via Finder (macOS Catalina+)**
1. Connect iPhone to Mac
2. Open **Finder**
3. Select your iPhone in sidebar
4. Drag the IPA file to the device

---

## Recommended Path

For your situation, I recommend:

### Immediate (Today):
**Use Option A (7-Day Build)** - It's free and quick
1. Open Xcode workspace
2. Change to Release configuration
3. Build and run to your device
4. App works for 7 days

### Long Term (Within a week):
**Enroll in Apple Developer Program ($99/year)**
1. Get proper distribution certificates
2. Use TestFlight for testing (90 days)
3. Publish to App Store when ready

This gives you:
- Professional testing platform
- Longer testing periods
- Ability to distribute to other users
- Push notifications and advanced features
- Pathway to App Store

---

## Troubleshooting

### "Untrusted Developer" Error
**Solution:** Settings → General → VPN & Device Management → Trust your developer account

### "Unable to Verify App"
**Solution:** Check your device has internet connection when first launching

### Build Expires in 7 Days
**Solution:** Either:
- Rebuild and reinstall every 7 days (free)
- Enroll in Apple Developer Program for longer durations ($99/year)

### "No Signing Certificate"
**Solution:** 
1. Make sure you're signed into Xcode with your Apple ID
2. Xcode → Preferences → Accounts → Add Account
3. Enable "Automatically manage signing" in project settings

---

## Summary

| Method | Duration | Cost | Best For |
|--------|----------|------|----------|
| **Development Build** | 7 days | Free | Quick testing |
| **TestFlight** | 90 days | $99/year | Beta testing |
| **Ad Hoc** | 1 year | $99/year | Internal distribution |
| **App Store** | Forever | $99/year | Public release |

For running the app for a week, **Development Build** is perfect and free!


