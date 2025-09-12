# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Alluvial Academy Admin**, a Flutter web application for Islamic education management. The app provides role-based dashboards for administrators, teachers, and students with features including:

- User management and role-based access control
- Time clock and shift management 
- Form builder and response collection
- Chat system and messaging
- Task management
- Website content management
- Islamic calendar integration with prayer times

**Technology Stack:**
- Flutter 3.4.3+ (Web-focused)
- Firebase (Auth, Firestore, Storage, Functions)
- Syncfusion widgets for data grids and date pickers
- Google Fonts and Material Design 3

## Common Development Commands

### Building and Development

**Development build:**
```bash
flutter run -d chrome
```

**Production build (CRITICAL - must use automated script):**
```bash
./build_release.sh
```
OR manually:
```bash
./increment_version.sh && flutter build web --release
```

**⚠️ NEVER run `flutter build web --release` without incrementing the version first!**

**Dependencies and package management:**
```bash
flutter pub get
flutter pub upgrade
flutter pub outdated  # Check for package updates
```

### Cache Busting System

The project uses an automated cache busting system to prevent browser cache issues:

- `./increment_version.sh` - Increments version numbers in `web/index.html`
- `./build_release.sh` - Complete automated build process
- Version numbers are added as `?v=X` parameters to critical files

### Testing and Linting

```bash
flutter test
flutter analyze
```

### Deployment Workflow

1. Make code changes and test locally
2. Run `./build_release.sh` (never skip version increment)
3. Upload `build/web/` contents to Hostinger
4. Include `web/.htaccess` file for proper caching headers

**Firebase Functions deployment:**
```bash
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only hosting  # Alternative to manual Hostinger upload
```

## Architecture Overview

### Authentication Flow Architecture

**Critical Path: `main.dart` → Firebase Init → Auth Wrapper → Role Router → Dashboard**

1. **App Initialization (`main.dart:15-65`)**:
   - Special web compatibility with `runWidget()` fallback to `runApp()`
   - Trackpad gesture assertion errors silently ignored (lines 24-39)
   - Zone error assertions disabled for web debug mode

2. **Firebase Initialization (`main.dart:115-284`)**:
   - Web-specific delays: 100ms + 500ms for proper initialization
   - Network connectivity testing for Firestore
   - Comprehensive error handling with retry mechanism

3. **Authentication Wrapper (`main.dart:285-395`)**:
   - `StreamBuilder<User?>` on `FirebaseAuth.authStateChanges()`
   - Routes authenticated users to `RoleBasedDashboard`

4. **Role-Based Dashboard (`role_based_dashboard.dart:7-88`)**:
   - Determines role via `UserRoleService.getCurrentUserRole()`
   - Routes: admin → full dashboard, others → role-specific dashboards

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
- `chat_service.dart` - Real-time messaging with presence tracking
- `location_service.dart` - Geolocation for shift tracking
- `prayer_time_service.dart` - Islamic prayer time calculations
- `shift_service.dart` - Employee shift management with geofencing

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
- `user_management/` - Syncfusion DataGrid with export functionality
- `chat/` - Real-time messaging with group and individual chats
- `time_clock/` - Location-based attendance tracking
- `forms/` - Dynamic form builder with draft system
- `shift_management/` - Employee scheduling with monitoring

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
- **IndexedStack**: All dashboard screens kept in memory for fast switching
- **Role-aware sidebar**: Dynamic menu generation based on current user role
- **Persistent state**: Sidebar collapse state maintained across sessions

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

**Cloud Functions:**
- Password reset email customization
- User account deletion with admin privilege verification
- Background task processing

### Error Handling & Web Compatibility

**Web-Specific Handling:**
- Trackpad gesture assertions silently ignored (`main.dart:26-30`)
- Zone error assertions disabled for debug mode (`main.dart:16-19`)
- Multi-view compatibility with `runWidget()` fallback

**Firebase Error Patterns:**
- Comprehensive `FirebaseAuthException` handling with user-friendly messages
- Network failure detection with retry mechanisms
- Graceful degradation when background services fail

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
- App initialization: `lib/main.dart:15-65`
- Firebase setup: `lib/main.dart:132-168`  
- Auth wrapper: `lib/main.dart:285-395`
- Role routing: `lib/role_based_dashboard.dart:76-88`

**Role Management:**
- Core service: `lib/core/services/user_role_service.dart`
- Role switching: `lib/shared/widgets/role_switcher.dart`
- Admin-teacher logic: `user_role_service.dart:44-52`

**Dashboard Architecture:**
- Main dashboard: `lib/dashboard.dart`
- Navigation sidebar: `lib/dashboard.dart` (around line 969)
- User profile UI: `lib/dashboard.dart` (around line 805)
- IndexedStack screens: `lib/dashboard.dart` (screen array)

**Key Features:**
- Form builder: `lib/admin/form_builder.dart`
- User management: `lib/features/user_management/screens/user_management_screen.dart`
- Chat system: `lib/features/chat/`
- Time clock: `lib/features/time_clock/`
- Shift management: `lib/features/shift_management/`

## Production Deployment Notes

**Primary Hosting:** Deployed on Hostinger with custom caching rules
**Alternative Hosting:** Firebase Hosting configured in `firebase.json`
**Cache Strategy:** 
- HTML files: never cached (`no-cache, no-store, must-revalidate`)
- Static assets (JS/CSS): cached for 1 year (`max-age=31536000, immutable`)
- Images/fonts: cached for 1 year with immutable headers
**Version Management:** Automated via `increment_version.sh` script
**Build Output:** Upload entire `build/web/` directory contents

**Cache Headers Configuration:**
- Configured in `firebase.json` for Firebase Hosting
- Use `web/.htaccess` for Hostinger deployment
- Version parameters (`?v=X`) added to critical files automatically

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

**Performance Guidelines:**
- Use IndexedStack for dashboard screens to maintain state
- Implement debounced search in data-heavy screens
- Cache frequently accessed data with appropriate TTL
- Dispose of controllers and streams properly

## Key Dependencies & Packages

**Core Flutter & Firebase:**
- `firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_storage`
- `cloud_functions` for server-side logic

**UI & Design:**
- `google_fonts` for typography (Inter font family)
- `syncfusion_flutter_datagrid` for data tables
- `syncfusion_flutter_datepicker` for date selection
- `font_awesome_flutter` for icons

**Functionality:**
- `provider` for state management
- `geolocator` & `geocoding` for location services
- `shared_preferences` for local storage
- `file_picker` for file uploads
- `url_launcher` for external links
- `emoji_picker_flutter` for chat features