# Alluvial Academy

A comprehensive educational platform built with Flutter and Firebase. Supports web, Android, and iOS with role-based access for admins, teachers, students, and parents.

## Project Structure

```
lib/
  main.dart                     # App entry point
  firebase_options.dart         # Production Firebase config
  firebase_options_dev.dart     # Dev Firebase config

  core/                         # Shared code used across 3+ features
    constants/                  # App-wide constants
    enums/                      # App-wide enums
    models/                     # Shared models (user, employee)
    services/                   # Shared services (~16: auth, theme, etc.)
    theme/                      # App theme
    utils/                      # Generic utilities
    widgets/                    # Generic reusable widgets

  features/                     # All feature code lives here
    audit/                      # Teacher audits, coach evaluations
    auth/                       # Login, authentication
    chat/                       # In-app messaging
    dashboard/                  # Main dashboard, sidebar, navigation
    enrollment_management/      # Student/teacher enrollment
    forms/                      # Form builder, submissions, templates
    livekit/                    # Video calls (LiveKit), guest join
    notifications/              # Push notifications
    onboarding/                 # New user onboarding
    parent/                     # Parent dashboard, invoicing, payments
    profile/                    # User profile management
    quran/                      # Quran studies
    quiz/                       # Quizzes and assessments
    recordings/                 # Class recordings
    settings/                   # System settings, debug tools
    shift_management/           # Shift scheduling, calendar, recurrence
    student/                    # Student-specific views
    surah_podcast/              # Surah podcast player
    tasks/                      # Task management
    teacher_applications/       # Teacher application review
    time_clock/                 # Clock in/out, timesheets
    tutor/                      # AI tutor
    user_management/            # Admin user list, role management
    website/                    # Public landing pages, program pages
    website_management/         # CMS, content management
    zoom/                       # Legacy Zoom integration

  l10n/                         # Localization (English, French, Arabic)

functions/                      # Firebase Cloud Functions (Node.js)
  index.js                      # Function exports
  handlers/                     # Production function handlers
  services/                     # Shared backend services
  utils/                        # Backend utilities
  tests/                        # Test files
  scripts/dev/                  # Dev/debug/migration scripts
```

### Feature Directory Structure

Each feature follows this pattern:

```
features/<feature>/
  screens/        # Full-page widgets
  widgets/        # UI components for this feature
  services/       # Business logic, Firestore queries
  models/         # Data classes
  config/         # Feature-specific config (if needed)
  enums/          # Feature-specific enums (if needed)
  constants/      # Feature-specific constants (if needed)
```

### Architecture Rules

- **Feature-first**: All new code goes in `lib/features/<feature>/`
- **Thin core**: `core/` only contains code shared across 3+ features
- **No root files**: Never add screens/services/models to `lib/` root
- **Self-contained features**: Each feature owns its screens, widgets, services, and models

See [CLAUDE.md](CLAUDE.md) for the full set of development rules.

## Getting Started

### Prerequisites

- Flutter SDK
- Firebase CLI
- Node.js 20+ (for Cloud Functions)

### Setup

```bash
# Install Flutter dependencies
flutter pub get

# Install Cloud Functions dependencies
cd functions && npm install && cd ..

# Run on Chrome
flutter run -d chrome

# Run on device
flutter run
```

### Firebase

```bash
# Deploy all functions
firebase deploy --only functions --project alluwal-academy

# Deploy a specific function
firebase deploy --only functions:functionName --project alluwal-academy
```

## Tech Stack

- **Frontend**: Flutter (Dart), Provider for state management
- **Backend**: Firebase (Firestore, Auth, Cloud Functions, Storage, Messaging)
- **Video**: LiveKit (self-hosted on VPS)
- **Localization**: 3 languages (English, French, Arabic)
- **Platforms**: Web, Android, iOS
