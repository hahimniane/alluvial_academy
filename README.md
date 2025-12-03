# Alluvial Academy

A comprehensive Islamic education management platform that connects teachers, students, and administrators in a seamless digital learning environment.

## What We Do

Alluvial Academy is designed to make Islamic education accessible and well-organized. We help teachers manage their schedules, track their classes, and connect with students. Administrators can oversee operations, manage shifts, review timesheets, and ensure everything runs smoothly.

## Key Features

### For Teachers
- **Smart Home Dashboard**: Get a quick view of your next class, recent tasks, and weekly stats at a glance
- **Shift Management**: View your full schedule, claim available shifts, and see detailed information about each class
- **Time Tracking**: Clock in and out for your classes with automatic location tracking
- **Class Reports**: Submit post-class reports to document what was taught and how students performed
- **Timesheet Editing**: If you forgot to clock in on time, you can edit your timesheet with notes for admin approval
- **Task Management**: View and manage tasks assigned by administrators
- **Profile Management**: Update your profile information and upload your profile picture
- **Islamic Resources**: Quick access to trusted Islamic learning resources

### For Administrators
- **Comprehensive Dashboard**: Full control over shifts, teachers, students, and schedules
- **Timesheet Review**: Review, approve, or reject teacher timesheets with detailed comparison views
- **Advanced Filtering**: Filter timesheets by teacher, status, date range, and more with color-coded status indicators
- **Export Functionality**: Export timesheet data to Excel with detailed breakdowns by day, week, and month
- **Shift Creation**: Create teaching shifts with flexible scheduling, recurrence options, and subject-based hourly rates
- **Payment Management**: Automatic payment calculation based on hours worked and hourly rates (configurable per subject)
- **Edit Approval System**: Review and approve timesheet edits with side-by-side comparison of original vs. edited data

## Technical Stack

- **Framework**: Flutter (cross-platform mobile and web)
- **Backend**: Firebase (Firestore, Authentication, Storage, Cloud Functions)
- **State Management**: Built-in Flutter state management
- **UI**: Material Design with custom styling

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Firebase account and project setup
- Android Studio / Xcode (for mobile builds)
- Node.js (for Firebase Functions)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd alluvial_academy
```

2. Install dependencies:
```bash
flutter pub get
```

3. Set up Firebase:
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files
   - Configure Firebase in your project

4. Run the app:
```bash
# For web
flutter run -d chrome

# For Android
flutter run -d <android-device-id>

# For iOS (Mac only)
flutter run -d <ios-device-id>
```

## Building for Production

### Android APK

To build a release APK:
```bash
flutter build apk --release
```

The APK will be located at: `build/app/outputs/flutter-apk/app-release.apk`

For a split APK (smaller file sizes):
```bash
flutter build apk --split-per-abi --release
```

### Android App Bundle (for Play Store)

To build an AAB file for Google Play Store:
```bash
flutter build appbundle --release
```

The AAB will be at: `build/app/outputs/bundle/release/app-release.aab`

### iOS (Mac Required)

To build for iOS:
```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode and archive the app.

## Publishing to Google Play Store

### Step 1: Prepare Your App

1. **Create a Google Play Console Account**
   - Go to [Google Play Console](https://play.google.com/console)
   - Pay the one-time $25 registration fee
   - Complete your developer profile

2. **Prepare App Assets**
   - App icon (512x512 PNG)
   - Feature graphic (1024x500 PNG)
   - Screenshots (at least 2, up to 8)
   - Short description (80 characters max)
   - Full description (4000 characters max)

3. **Build Your App Bundle**
   ```bash
   flutter build appbundle --release
   ```

### Step 2: Create Your App Listing

1. In Google Play Console, click "Create app"
2. Fill in:
   - App name: "Alluvial Academy"
   - Default language: English
   - App or game: App
   - Free or paid: Choose based on your model
   - Declarations: Complete all required sections

### Step 3: Upload Your App Bundle

1. Go to "Production" → "Create new release"
2. Upload your `app-release.aab` file
3. Add release notes
4. Review and roll out

### Step 4: Complete Store Listing

- Add screenshots
- Write app description
- Add graphics
- Set up content rating
- Complete privacy policy

### Step 5: Submit for Review

Once all sections show green checkmarks, click "Submit for review". Google typically reviews within 1-3 days.

## Publishing to Apple App Store

### Prerequisites
- Apple Developer Account ($99/year)
- Mac computer
- Xcode installed

### Steps

1. **Build iOS App**
   ```bash
   flutter build ios --release
   ```

2. **Open in Xcode**
   ```bash
   open ios/Runner.xcworkspace
   ```

3. **Configure Signing**
   - Select your team in Xcode
   - Set bundle identifier
   - Configure provisioning profiles

4. **Archive**
   - Product → Archive
   - Wait for archive to complete

5. **Distribute**
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Follow the upload wizard

6. **Submit in App Store Connect**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Create your app listing
   - Submit for review

## Project Structure

```
lib/
├── core/                 # Core services and models
│   ├── models/          # Data models
│   ├── services/        # Business logic services
│   └── enums/           # Enumerations
├── features/            # Feature modules
│   ├── dashboard/      # Dashboard screens
│   ├── shift_management/ # Shift management
│   ├── time_clock/      # Timesheet and clock-in/out
│   ├── tasks/           # Task management
│   ├── profile/         # User profiles
│   └── zoom/            # Zoom integration
└── main.dart           # App entry point
```

## Important Notes

### Cache Busting for Web
Before deploying web updates, always run:
```bash
./increment_version.sh && flutter build web --release
```

This ensures users get the latest version without needing to clear their browser cache.

### Timesheet Edit Approval
When teachers edit their timesheets, admins must approve the edits before the timesheet can be approved. The system shows a side-by-side comparison of original vs. edited data.

### Subject-Based Hourly Rates
Hourly rates can be configured per subject. When creating a shift, the system will:
1. Use the custom rate if provided
2. Fall back to the subject's default wage
3. Fall back to the teacher's wage override
4. Finally use the global default wage

## Contributing

This is a private project. For questions or issues, please contact the development team.

## License

Proprietary - All rights reserved

