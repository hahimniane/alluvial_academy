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

## Architecture Overview

### Core Structure

**Entry Points:**
- `lib/main.dart` - App initialization with Firebase setup and error handling
- `lib/role_based_dashboard.dart` - Role-based routing after authentication
- `lib/dashboard.dart` - Main dashboard UI with navigation

**Core Services (`lib/core/services/`):**
- `auth_service.dart` - Firebase authentication with role checking
- `user_role_service.dart` - Role management and permissions
- `location_service.dart` - Geolocation for shift tracking
- `prayer_time_service.dart` - Islamic prayer time calculations
- `form_draft_service.dart` - Form builder draft management

**Feature Modules (`lib/features/`):**
Each feature is organized in its own directory with:
- `screens/` - UI screens
- `widgets/` - Reusable components  
- `services/` - Feature-specific business logic
- `models/` - Data models

### Key Architectural Patterns

**Role-Based Access Control:**
- Users have roles: admin, teacher, student, parent
- Dashboard content dynamically changes based on user role
- Admins see full management interface, others see limited views

**State Management:**
- Uses provider pattern for state management
- SharedPreferences for local settings (sidebar collapse state)
- Firebase Firestore for real-time data synchronization

**Authentication Flow:**
1. `LandingPage` → Login screen for unauthenticated users
2. `AuthenticationWrapper` → Firebase auth state listener
3. `RoleBasedDashboard` → Role determination and routing
4. `DashboardPage` → Main app interface

## Important Implementation Notes

### Firebase Configuration
- Uses `firebase_options.dart` for platform-specific config
- Includes web-specific initialization delays and error handling
- Firestore security rules in `firestore.rules`

### Form System
- Dynamic form builder in `admin/form_builder.dart`
- Form responses handled in `features/forms/`
- Draft system allows saving incomplete forms

### Time Clock System
- Location-based attendance tracking
- Geolocation verification for shift check-ins
- Admin timesheet review capabilities

### Development Debugging
When `kDebugMode` is true, additional debug screens are available:
- Test Role System screen
- Firestore Debug screen

## File Locations for Common Tasks

**Authentication:** `lib/core/services/auth_service.dart`
**Role Management:** `lib/core/services/user_role_service.dart`
**Main Navigation:** `lib/dashboard.dart:969` (side menu)
**User Profile UI:** `lib/dashboard.dart:805` (app bar)
**Form Builder:** `lib/admin/form_builder.dart`
**Chat System:** `lib/features/chat/`
**Time Clock:** `lib/features/time_clock/`

## Production Deployment Notes

**Hosting:** Deployed on Hostinger with custom caching rules
**Cache Strategy:** HTML never cached, static assets cached for 1 year
**Version Management:** Automated via `increment_version.sh` script
**Build Output:** Upload entire `build/web/` directory contents

## Development Guidelines

- Always check user role before displaying admin features
- Use `UserRoleService.getCurrentUserRole()` for role checks
- Firebase operations should have try-catch error handling
- Use `GoogleFonts.inter()` for consistent typography
- Follow existing color scheme: primary `Color(0xff0386FF)`
- Test role-based features with different user types