# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Alluvial Academy**, a multi-platform Flutter application for Islamic education management. The app provides role-based dashboards for administrators, teachers, students, and parents with comprehensive educational management features.

**Platform Support:**
- **Web** (Primary admin interface, hosted on Hostinger/Firebase Hosting)
- **Android** (Mobile app via Google Play Store)
- **iOS** (Mobile app via Apple App Store)

**Core Features:**
- User management and role-based access control
- Time clock and shift management with geolocation
- Form builder and response collection
- Chat system and messaging
- Task management
- Website content management
- Islamic calendar integration with prayer times
- Push notifications (mobile only)
- Force update mechanism (mobile only)
- Wage management system

**Technology Stack:**
- Flutter 3.4.3+ (Multi-platform: Web, Android, iOS)
- Firebase (Auth, Firestore, Storage, Functions, Cloud Messaging, Remote Config)
- Syncfusion widgets for data grids and date pickers
- Google Fonts and Material Design 3
- Node.js Cloud Functions for backend logic

## Common Development Commands

### Building and Development

**Development build:**
```bash
# Web (Chrome)
flutter run -d chrome

# Android emulator/device
flutter run -d android

# iOS simulator/device
flutter run -d ios
```

**Production Web build (CRITICAL - must use automated script):**
```bash
./build_release.sh
```
OR manually:
```bash
./increment_version.sh && flutter build web --release --pwa-strategy=none
```
**⚠️ NEVER run `flutter build web --release` without incrementing the version first!**

**Production Mobile builds:**
```bash
# Android APK
flutter clean && flutter pub get && flutter build apk --release

# Android App Bundle (for Play Store)
flutter clean && flutter pub get && flutter build appbundle --release

# iOS (requires macOS)
flutter clean && flutter pub get && flutter build ios --release
# Then open Xcode to archive: open ios/Runner.xcworkspace
```

**Dependencies and package management:**
```bash
flutter pub get
flutter pub upgrade
flutter pub outdated  # Check for package updates
flutter clean         # Clean build cache (use when debugging build issues)
```

### Cache Busting System (Web Only)

The project uses an automated cache busting system to prevent browser cache issues:

- `./increment_version.sh` - Increments version numbers in `web/index.html`
- `./build_release.sh` - Complete automated build process (web)
- Version numbers are added as `?v=X` parameters to critical files

### Testing and Linting

```bash
flutter test
flutter analyze
```

### Deployment Workflow

**Web Deployment:**
1. Make code changes and test locally
2. Run `./build_release.sh` (never skip version increment)
3. Upload `build/web/` contents to Hostinger
4. Include `web/.htaccess` file for proper caching headers

**Mobile Deployment:**
1. Update version in `pubspec.yaml` (e.g., `version: 1.0.1+2`)
2. Build release APK/AAB or iOS archive
3. Upload to Google Play Console or App Store Connect
4. Submit for review

**Firebase Functions deployment:**
```bash
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only hosting  # Alternative to manual Hostinger upload
```

**Important Build Artifacts:**
- Web: `build/web/` directory
- Android APK: `build/app/outputs/flutter-apk/app-release.apk`
- Android AAB: `build/app/outputs/bundle/release/app-release.aab`
- iOS: Archive via Xcode after `flutter build ios --release`

## Architecture Overview

### Platform-Specific Entry Points

**Critical Path Differences:**

**Web Flow:**
```
main.dart → LandingPage (marketing) → EmployeeHubApp (login) → RoleBasedDashboard → DashboardPage
```

**Mobile Flow (Android/iOS):**
```
main.dart → MobileLoginScreen → MobileDashboardScreen (bottom nav) → Role-specific screens
```

**Platform Detection:**
- `kIsWeb` - Identifies web platform
- `Platform.isAndroid` / `Platform.isIOS` - Identifies mobile platforms
- Used throughout app for conditional features (notifications, location, orientation)

### Authentication Flow Architecture

**Critical Path: `main.dart` → Firebase Init → Auth Wrapper → Role Router → Dashboard**

1. **App Initialization (`main.dart:59-100`)**:
   - Zone error assertions disabled for web debug mode (`kIsWeb && kDebugMode`)
   - **Mobile-only**: Portrait orientation lock (lines 68-73)
   - **Mobile-only**: FCM initialization and background handler (lines 81-94)
   - **Mobile-only**: Version service for force updates (lines 97-99)
   - Timezone initialization for all platforms

2. **Firebase Initialization (`main.dart:76-78`)**:
   - Uses `DefaultFirebaseOptions.currentPlatform` for multi-platform support
   - Platform-specific configuration via `firebase.json` and FlutterFire CLI

3. **Authentication Wrapper**:
   - `StreamBuilder<User?>` on `FirebaseAuth.authStateChanges()`
   - Routes authenticated users to `RoleBasedDashboard` (web) or `MobileDashboardScreen` (mobile)

4. **Role-Based Dashboard (`role_based_dashboard.dart:76-88`)**:
   - Determines role via `UserRoleService.getCurrentUserRole()`
   - Routes: admin → `DashboardPage`, teacher/student/parent → role-specific dashboards
   - **Note**: Currently all roles use `DashboardPage` with feature filtering (see TODOs at lines 288-309)

### Core Services Architecture (`lib/core/services/`)

**UserRoleService** - Critical for all role-based functionality:
- **Dual-role system**: Admins can switch to teacher mode; admin-teachers can switch back
- **Local storage**: Active role cached with key `active_user_role`
- **5-minute cache**: In-memory user data caching to reduce Firestore calls
- **Key methods**: `getAvailableRoles()`, `switchActiveRole()`, `hasDualRoles()`

**AuthService** - Enhanced authentication:
- User activation checking before sign-in
- Background location/prayer time initialization for teachers
- Custom password reset emails via Cloud Functions

**Other Core Services:**
- `auth_service.dart` - Enhanced authentication with activation checking
- `chat_service.dart` - Real-time messaging with presence tracking
- `location_service.dart` - Geolocation for shift tracking (platform-aware)
- `prayer_time_service.dart` - Islamic prayer time calculations
- `shift_service.dart` - Employee shift management with geofencing
- `notification_service.dart` - FCM and local notifications (mobile-only)
- `version_service.dart` - Force update mechanism via Remote Config (mobile-only)
- `theme_service.dart` - Dark mode support with persistence
- `timezone_service.dart` - User timezone management for accurate scheduling
- `wage_management_service.dart` - Global, role-based, and individual wage calculations

### Feature-Based Modular Architecture (`lib/features/`)

**Standardized Structure per Feature:**
```
feature_name/
├── models/     # Data models
├── screens/    # UI screens  
├── services/   # Business logic
└── widgets/    # Reusable components
```

**Key Features:**
- `dashboard/` - Role-aware statistics and Islamic calendar integration
  - `mobile_dashboard_screen.dart` - Mobile version with bottom navigation
  - `admin_dashboard_screen.dart` - Web desktop version
- `user_management/` - Syncfusion DataGrid with export functionality
  - `mobile_user_management_screen.dart` - Mobile admin interface
- `chat/` - Real-time messaging with group and individual chats
- `time_clock/` - Location-based attendance tracking with geofencing
- `forms/` - Dynamic form builder with draft system
- `shift_management/` - Employee scheduling with monitoring and wage tracking
- `notifications/` - Push notification management (mobile-only)
  - `mobile_notification_screen.dart` - Send notifications to users/roles
- `auth/` - Authentication screens
  - `mobile_login_screen.dart` - Animated mobile login
- `settings/` - App settings and preferences
  - `mobile_settings_screen.dart` - Mobile settings interface
  - `notification_preferences_screen.dart` - Per-user notification settings

### Key Architectural Patterns

**Role-Based Access Control:**
- **Roles**: admin, teacher, student, parent with dynamic switching capability
- **Dual-role system**: Admins can act as teachers; admin-teachers can switch back
- **Permission checking**: Always use `UserRoleService.getCurrentUserRole()` before displaying features
- **Local storage**: Active role persisted in SharedPreferences

**State Management Patterns:**
- **Provider pattern**: Used across components for state management
- **SharedPreferences**: Local storage for sidebar state (`sidebar_collapsed`), active role
- **Stream subscriptions**: Firestore real-time updates with proper disposal
- **Refresh triggers**: Integer counters (`_refreshTrigger`) to force widget rebuilds
- **In-memory caching**: 5-minute TTL cache in UserRoleService

**Navigation Architecture:**
- **Web**: IndexedStack with sidebar navigation
  - All dashboard screens kept in memory for fast switching
  - Role-aware sidebar: Dynamic menu generation based on current user role
  - Persistent state: Sidebar collapse state maintained across sessions
- **Mobile**: Bottom navigation bar with tab-based routing
  - 5 tabs for admin: Home, Notify, Users, Chat, Tasks
  - Simplified navigation for teacher/student/parent roles
  - Native iOS/Android navigation patterns

**Platform-Specific Conditional Compilation:**
- Use `if (!kIsWeb)` for mobile-only features (notifications, orientation, version checks)
- Use `if (kIsWeb)` for web-only features (landing page, web-specific UI)
- Location services work on both but with different permission handling

## Important Implementation Notes

### Firebase Integration Architecture

**Authentication:**
- Email/password with Student ID alias support (format: `studentid@alluwaleducationhub.org`)
- User activation checking before sign-in via `auth_service.dart:22-32`
- Custom branded password reset emails via Cloud Functions
- Last login time tracking in Firestore

**Firestore Patterns:**
- **Users Collection**: Indexed by `e-mail` field (lowercase)
- **Real-time subscriptions**: Extensive use of snapshots for live data
- **Batch operations**: Optimized queries for performance
- **5-minute caching**: UserRoleService reduces Firestore calls

**Cloud Functions (`functions/index.js`):**
- Custom branded password reset emails via Hostinger SMTP
- User account deletion with admin privilege verification
- Scheduled shift reminders (cron job via Firebase Scheduler)
- Background task processing
- Email notifications using `nodemailer`

**Firebase Remote Config (Mobile Only):**
- Force update mechanism via `VersionService`
- Minimum required version enforcement
- Update messages and configurations

### Error Handling & Platform Compatibility

**Web-Specific Handling:**
- Zone error assertions disabled for debug mode (`kIsWeb && kDebugMode`)
- No device orientation restrictions
- Browser-based geolocation API

**Mobile-Specific Handling:**
- Portrait orientation lock enforced
- iOS-specific FCM token delays (5 seconds for APNs conversion)
- Platform permission handling for location, notifications, camera
- Force update checks on app startup

**Firebase Error Patterns:**
- Comprehensive `FirebaseAuthException` handling with user-friendly messages
- Network failure detection with retry mechanisms
- Graceful degradation when background services fail

**Platform-Specific Error Patterns:**
```dart
// Example: Location service handles web gracefully
if (!kIsWeb && !serviceEnabled) {
  throw Exception('Location services disabled');
}
// Web uses browser API without strict checks
```

### Development and Debugging

**Debug Mode Features** (only when `kDebugMode` is true):
- Test Role System screen (`lib/test_role_system.dart`)
- Firestore Debug screen (`lib/firestore_debug_screen.dart`)
- Console logging with structured debug messages

**Performance Optimizations:**
- In-memory caching for user data (5-minute TTL)
- Stream subscription management with proper disposal
- Debounced search in user management screens
- IndexedStack for instant screen switching

## Critical File Locations and Line References

**Authentication Flow:**
- App initialization: `lib/main.dart:59-100`
- Firebase setup: `lib/main.dart:76-78`
- Mobile login: `lib/features/auth/screens/mobile_login_screen.dart`
- Web landing: `lib/screens/landing_page.dart`
- Role routing: `lib/role_based_dashboard.dart:76-88`

**Platform-Specific Entry Points:**
- Web: `lib/screens/landing_page.dart` (public marketing site)
- Mobile: `lib/features/auth/screens/mobile_login_screen.dart`
- Platform detection: Throughout codebase using `kIsWeb` and `Platform.isX`

**Role Management:**
- Core service: `lib/core/services/user_role_service.dart`
- Role switching: `lib/shared/widgets/role_switcher.dart`
- Admin-teacher logic: `user_role_service.dart:44-52`

**Dashboard Architecture:**
- Web dashboard: `lib/dashboard.dart`
  - Navigation sidebar: around line 969
  - User profile UI: around line 805
  - IndexedStack screens: screen array
- Mobile dashboard: `lib/features/dashboard/screens/mobile_dashboard_screen.dart`
- Admin mobile: `lib/features/dashboard/screens/admin_dashboard_screen.dart`

**Key Features:**
- Form builder: `lib/admin/form_builder.dart`
- User management (web): `lib/features/user_management/screens/user_management_screen.dart`
- User management (mobile): `lib/features/user_management/screens/mobile_user_management_screen.dart`
- Notifications (mobile): `lib/features/notifications/screens/mobile_notification_screen.dart`
- Chat system: `lib/features/chat/`
- Time clock: `lib/features/time_clock/`
- Shift management: `lib/features/shift_management/`
- Settings (mobile): `lib/features/settings/screens/mobile_settings_screen.dart`

**Core Services:**
- All services: `lib/core/services/`
- Notification service: `lib/core/services/notification_service.dart`
- Version service: `lib/core/services/version_service.dart`
- Theme service: `lib/core/services/theme_service.dart`

**Firebase Backend:**
- Cloud Functions: `functions/index.js`
- Firebase config: `firebase.json`
- Firestore rules: `firestore.rules`

## Production Deployment Notes

### Web Deployment

**Primary Hosting:** Deployed on Hostinger with custom caching rules
**Alternative Hosting:** Firebase Hosting configured in `firebase.json`
**Website URL:** https://alluvaleducationhub.org

**Cache Strategy:**
- HTML files: never cached (`no-cache, no-store, must-revalidate`)
- Static assets (JS/CSS): cached for 1 year (`max-age=31536000, immutable`)
- Images/fonts: cached for 1 year with immutable headers

**Version Management:**
- Automated via `increment_version.sh` script
- **CRITICAL**: Always increment before web builds
- Version parameters (`?v=X`) added to critical files automatically

**Build Output:** Upload entire `build/web/` directory contents

**Cache Headers Configuration:**
- Configured in `firebase.json` for Firebase Hosting
- Use `web/.htaccess` for Hostinger deployment

### Mobile Deployment

**Android:**
- **Package Name:** `org.alluvaleducationhub.academy` (permanent)
- **Distribution:** Google Play Store
- **Signing:** Release keystore at `android/app/upload-keystore.jks`
- **⚠️ CRITICAL**: Backup keystore files - cannot update app if lost!
- **Build Output:** `build/app/outputs/bundle/release/app-release.aab`

**iOS:**
- **Bundle ID:** `org.alluvaleducationhub.academy`
- **Distribution:** Apple App Store
- **Signing:** Managed via Xcode
- **Requirements:** macOS with Xcode, Apple Developer account
- **APNs:** Required for push notifications

**Version Management (Mobile):**
- Update `pubspec.yaml` version before each release
- Format: `version: 1.0.1+2` (name+code)
- Version code MUST increment with each release

### Firebase Backend Deployment

**Cloud Functions:**
```bash
firebase deploy --only functions
```

**Firestore Rules:**
```bash
firebase deploy --only firestore:rules
```

**All Firebase Services:**
```bash
firebase deploy
```

**Function Logs:**
```bash
firebase functions:log
```

## Development Guidelines

### Critical Patterns to Follow

**Role-Based Development:**
- **Always** use `UserRoleService.getCurrentUserRole()` before showing admin features
- Check `hasDualRoles()` for users who can switch between admin/teacher modes
- Test with different role combinations (admin, teacher, admin-teacher)
- Use `getAvailableRoles()` for role switcher UI

**State Management:**
- Use refresh trigger patterns: `_refreshTrigger++` to force rebuilds
- Cancel stream subscriptions in `dispose()` methods
- Cache user data when possible, respect 5-minute TTL
- Persist UI state (sidebar collapse) in SharedPreferences

**Firebase Integration:**
- Wrap all Firebase operations in try-catch blocks
- Use streams for real-time data, snapshots for static queries
- Query users by `e-mail` field (lowercase) for consistency
- Handle network errors gracefully with user-friendly messages

**UI/UX Standards:**
- Use `GoogleFonts.inter()` for consistent typography
- Follow color scheme: primary `Color(0xff0386FF)`, secondary `Color(0xff0693e3)`
- Implement loading states for all async operations
- Use Syncfusion widgets for data grids and date pickers

**Platform-Specific Development:**
- **Always** use `if (!kIsWeb)` before mobile-only code (notifications, orientation, FCM)
- **Always** use `if (kIsWeb)` before web-only code (landing page, web analytics)
- Test on all platforms when making architectural changes
- Location services: Use platform-aware permission handling
- iOS: Account for APNs token conversion delays (5 seconds)

**Performance Guidelines:**
- Use IndexedStack for dashboard screens to maintain state (web)
- Use bottom navigation for mobile screens (native feel)
- Implement debounced search in data-heavy screens
- Cache frequently accessed data with appropriate TTL
- Dispose of controllers and streams properly
- Test release builds on actual devices, not just emulators

## Key Dependencies & Packages

**Core Flutter & Firebase:**
- `firebase_core` - Firebase initialization (all platforms)
- `cloud_firestore` - Real-time database
- `firebase_auth` - Authentication
- `firebase_storage` - File storage
- `cloud_functions` - Backend server-side logic
- `firebase_messaging` - Push notifications (mobile only)
- `firebase_remote_config` - Force updates (mobile only)

**UI & Design:**
- `google_fonts` - Typography (Inter font family)
- `syncfusion_flutter_datagrid` - Data tables with export
- `syncfusion_flutter_datepicker` - Date selection
- `syncfusion_flutter_calendar` - Shift scheduling calendar view
- `font_awesome_flutter` - Icon library

**Mobile-Specific:**
- `flutter_local_notifications` - Local notification display
- `package_info_plus` - App version info
- `device_preview` - Debug UI preview (dev mode only)
- `image_picker` - Camera and gallery access

**Functionality:**
- `provider` - State management pattern
- `geolocator` & `geocoding` - Location services (platform-aware)
- `shared_preferences` - Local persistent storage
- `file_picker` - File upload handling
- `url_launcher` - External link handling
- `emoji_picker_flutter` - Chat emoji support
- `timezone` - Timezone calculations
- `uuid` - Unique ID generation

**Backend (Cloud Functions):**
- `nodemailer` - Email sending (via Hostinger SMTP)
- `firebase-admin` - Admin SDK for backend
- `firebase-functions` - Cloud Functions framework

## Important Notes for Development

### Mobile Notification Setup
- **Android**: Requires `google-services.json` in `android/app/`
- **iOS**: Requires APNs key uploaded to Firebase Console
- **iOS**: Push Notifications capability must be enabled in Xcode
- **Testing**: Must test on real devices, simulators don't support notifications reliably

### Platform-Specific Files
- **Web**: `web/index.html`, `web/.htaccess`, `firebase.json`
- **Android**: `android/app/build.gradle`, `android/app/google-services.json`
- **iOS**: `ios/Runner/Info.plist`, `ios/Runner/GoogleService-Info.plist`, `ios/Runner/Runner.entitlements`

### Common Issues & Solutions

**"Notifications not working on iOS":**
- Upload APNs key (.p8 file) to Firebase Console
- Enable Push Notifications in Xcode capabilities
- Test on real device (not simulator)
- Wait 5 seconds for APNs token conversion (see `main.dart:36`)

**"Location services failing":**
- Check platform-specific permission handling
- Web: Browser must allow location access
- Mobile: Requires location permissions in app settings

**"Build fails after dependency update":**
```bash
flutter clean
flutter pub get
# iOS only:
cd ios && pod install && cd ..
```

**"Web cache not updating":**
- Always run `./build_release.sh` (includes version increment)
- Check browser cache settings
- Verify `.htaccess` file uploaded to Hostinger

### Reference Documentation
For detailed platform-specific guides, see:
- `QUICK_START_ADMIN_MOBILE.md` - Mobile admin features
- `IOS_NOTIFICATION_FIX_GUIDE.md` - iOS notification setup
- `ANDROID_RELEASE_GUIDE.md` - Android release process
- `IOS_DEVELOPMENT_BUILD_GUIDE.md` - iOS development setup
- `RELEASE_READY.md` - Complete Play Store submission guide
- `FORCE_UPDATE_SETUP.md` - Force update mechanism
