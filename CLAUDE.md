# Alluvial Academy - AI Development Rules

## Project Structure (ENFORCED)

This is a Flutter + Firebase project using **feature-first architecture**. All code changes MUST follow these rules.

### Where to put NEW code

```
lib/
  core/           # ONLY truly shared, cross-feature code
  features/       # ALL feature code goes here
    <feature>/
      screens/    # Full-page widgets (StatefulWidget/StatelessWidget)
      widgets/    # Reusable UI components for this feature
      services/   # Business logic, Firestore queries, API calls
      models/     # Data classes, Firestore serialization
      config/     # Feature-specific constants, enums, config
```

### Rules for `lib/core/`

`core/` is for code used by 3+ features. It contains ONLY:
- `core/services/` — auth, connectivity, theme, language, timezone, notifications, user_role, settings, version, prayer_time, islamic_calendar, chat (~16 services MAX)
- `core/models/` — `user.dart`, `employee_model.dart` (truly shared user models ONLY)
- `core/utils/` — generic utilities (platform detection, timezone conversion, file export)
- `core/widgets/` — generic UI (responsive builder, role switcher, fade animations)
- `core/theme/` — app theme
- `core/constants/` — `app_constants.dart`, `build_info.dart`
- `core/enums/` — `app_enums.dart`, `ui_enums.dart`

**NEVER add feature-specific code to `core/`.** If a service, model, or widget is only used by 1-2 features, it belongs in that feature's folder.

### Rules for `lib/features/<feature>/`

- Every feature is self-contained: screens, widgets, services, models all live inside the feature folder
- Features should NOT import from other features' internal files. If two features need the same code, move it to `core/`
- New screens go in `features/<feature>/screens/`, NOT in `lib/` root
- New services go in `features/<feature>/services/`, NOT in `core/services/`
- New models go in `features/<feature>/models/`, NOT in `core/models/`

### NEVER do these things

1. **NEVER** create new files in `lib/` root (except `main.dart`)
2. **NEVER** add feature-specific services to `core/services/`
3. **NEVER** add feature-specific models to `core/models/`
4. **NEVER** create `lib/admin/`, `lib/screens/`, `lib/widgets/`, or `lib/utility_functions/` directories
5. **NEVER** put test/debug scripts in `functions/` root — use `functions/dev-scripts/`

### Feature directory reference

| Feature folder | What it covers |
|---|---|
| `audit/` | Teacher audits, admin audit review, coach evaluations, compliance |
| `auth/` | Login, password reset, authentication |
| `chat/` | In-app messaging, voice messages |
| `dashboard/` | Main dashboard, sidebar, navigation, role-based routing |
| `enrollment_management/` | Student/teacher enrollment, applications |
| `forms/` | Form builder, form submission, templates, drafts, responses |
| `livekit/` | Video calls, LiveKit rooms, guest join, recordings playback |
| `notifications/` | Push notifications, notification preferences |
| `onboarding/` | New user onboarding flow |
| `parent/` | Parent dashboard, invoicing, payments, student progress |
| `profile/` | User profile, profile pictures |
| `quran/` | Quran studies, recitation |
| `quiz/` | Quizzes, assessments |
| `recordings/` | Class recordings list, playback |
| `settings/` | System settings, debug tools, prayer times |
| `shift_management/` | Shift CRUD, scheduling, calendar, recurrence, wages, subjects |
| `student/` | Student-specific views |
| `surah_podcast/` | Surah podcast player, episodes |
| `tasks/` | Task management, assignments |
| `teacher_applications/` | Teacher application review |
| `time_clock/` | Clock in/out, timesheets, timesheet review |
| `tutor/` | AI tutor interface |
| `user_management/` | Admin user list, edit user, role management |
| `website/` | Public landing pages, program pages, team page, job board |
| `website_management/` | CMS, content management |

## Firebase Functions Structure

```
functions/
  index.js          # Exports only, no logic
  handlers/         # Production Cloud Function handlers
  services/         # Shared business logic
  utils/            # Shared utilities
  dev-scripts/      # Test, debug, fix, migration scripts (NOT production)
  tests/            # Test files
```

- New handlers go in `functions/handlers/`
- New one-off/debug scripts go in `functions/dev-scripts/`
- NEVER put test/debug scripts in `functions/` root

## Code Style

- State management: Provider (ChangeNotifier). Do not introduce new state management packages.
- Navigation: index-based `_screens` array in dashboard. Do not change the navigation pattern.
- Localization: ARB files in `lib/l10n/`. All user-facing strings must use `AppLocalizations`.
- Firebase: Use `cloud_firestore`, `firebase_auth`, `cloud_functions` packages.
