# Alluvial Academy Admin – Developer Onboarding

Welcome aboard! This document gives new contributors a guided tour of the
codebase, how the platform is put together, and the day‑to‑day workflows you will
use while building features.

---

## 1. Platform Overview

- **Client**: Flutter 3.x (see `pubspec.yaml` – current Dart SDK is `^3.4.3`). We ship
  for **web** (primary) and can run on mobile for testing/admin use.
- **Backend**: Firebase (Auth, Firestore, Storage, Cloud Functions, Remote Config,
  Messaging). Configuration lives in `firebase_options.dart` and the `firebase/`
  directories for each platform.
- **Architecture**: Feature-first modular structure with a shared `core/` layer.
  State is handled with `Provider` / `ChangeNotifier` plus local widget state.
- **Primary modules**:
  - Time clock / shift management (clock in/out, schedules, wage reporting).
  - Form builder and submissions.
  - User and role administration.
  - Messaging / tasks / Zoom integrations.

---

## 2. Repository Layout (high level)

```
lib/
  main.dart                // App bootstrap + platform setup
  core/                    // Cross-cutting services, models, utils, widgets
  features/<domain>/       // Feature-specific screens, services, widgets
  shared/                  // Common UI components
  utility_functions/       // Standalone helpers (CSV/Excel, etc.)
android/, ios/, web/, ...  // Flutter platform scaffolding
functions/                 // Firebase Cloud Functions
docs/                      // Published admin/teacher documentation
*.md                       // Playbooks & implementation notes
```

### Core layer (`lib/core/`)

- **models/**: Base data classes (`TeachingShift`, `TimesheetEntry`, enhanced
  recurrence, wages, etc.) with Firestore serialization and convenience getters.
- **services/**: Reusable business logic and Firebase wrappers. Key files:
  - `auth_service.dart` – Auth flows and role fetching.
  - `shift_timesheet_service.dart` – Clock-in/out, validation, and data sync.
  - `shift_monitoring_service.dart` – Auto clock-out + missed shift handling.
  - `location_service.dart` – Geolocation + reverse geocoding wrappers.
  - `notification_service.dart` / `version_service.dart` / `timezone_utils.dart`
    – Push, forced updates, timezone conversions.
- **utils/**: Low-level helpers (formatting, validation, timezone conversions).
- **widgets/**: Shared dialogs and overlays (loading, confirmation, version update).
- **migrations/**: One-off scripts. *Note*: `shift_wage_migration.dart` is **disabled**
  in `main.dart`; run it manually only if you know what you’re doing.

### Feature folders (`lib/features/`)

Each domain owns its own `screens/`, `widgets/`, `services/`, and sometimes
`models/`. Notable examples:

- **time_clock/** – Teacher punch clock UI, admin timesheet review/export, shift
  monitoring widgets.
- **shift_management/** – Scheduling UI, publishing workflow, teacher assignment.
- **forms/** – Form builder, response viewer, export.
- **user_management/** – Admin user directory and role assignment.
- **dashboard/** – Admin/teacher dashboards, analytics cards.
- Additional subfolders (`chat`, `zoom`, `tasks`, etc.) provide supporting workflows.

### Shared UI & utilities

- `lib/shared/` – Reusable UI elements (buttons, cards, theming).
- `lib/utility_functions/export_helpers.dart` – CSV/Excel export dialog and blob
  download logic (used by timesheet review, forms, etc.).

### Top-level admin tools

- `system_settings_screen.dart` – Global configuration panel (wages, feature flags).
- `form_screen.dart` – Form builder editor.
- `user_management_screen.dart` – Standalone user directory.
- `role_based_dashboard.dart` – Routes signed-in users to the right dashboard.
- `dashboard.dart` – Shared legacy dashboard shell.

---

## 3. Application Bootstrap (`lib/main.dart`)

- Initializes Flutter bindings, Firebase, FCM (mobile only), timezone data, and
  Remote Config.
- Uses `kIsWeb` checks to split web vs. mobile behavior (e.g., orientation locking,
  push notifications, landing page vs. auth flow).
- Launches `MyApp`, which wraps the widget tree with `DevicePreview` (debug only)
  and `ThemeService` (`Provider`) for dark/light modes.
- **Shift wage migration is intentionally disabled**; a debug log reminds you. Run
  it manually via a maintenance script if ever required.

---

## 4. Development Environment & Tooling

| Requirement | Notes |
|-------------|-------|
| Flutter SDK | 3.22+ (Dart SDK `^3.4.3`). Use `flutter doctor` to verify. |
| Firebase CLI | Useful for emulators / deploys (`npm i -g firebase-tools`). |
| Node.js      | Needed for `functions/` testing/deploys. |

### Setup steps
1. Clone repo & fetch packages  
   ```bash
   flutter pub get
   ```
2. Configure Firebase if needed (`flutterfire configure`). Current options are
   committed (`firebase_options.dart`, `google-services.json`, etc.).
3. For dev:
   - Web: `flutter run -d chrome`
   - Android: `flutter run -d <device>`
   - iOS: open `ios/Runner.xcworkspace` or use `flutter run -d ios`
4. Enable the FlutterFire emulators if you need local Firestore/Auth emulation.

### Useful scripts & docs
- `increment_version.sh` – Bumps web cache-busting version before release builds.
- Release guides: `ANDROID_RELEASE_GUIDE.md`, `IOS_DEVELOPMENT_BUILD_GUIDE.md`, `RELEASE_READY.md`.
- Feature-specific design notes: look under `*.md` files (e.g., `TIMEZONE_IMPLEMENTATION.md`, `SHIFT_PUBLISHING_IMPLEMENTATION.md`, etc.).

---

## 5. Running, Building, Deploying

| Task | Command / Notes |
|------|-----------------|
| Web dev server | `flutter run -d chrome` |
| Mobile dev | `flutter run` (after device selection) |
| Analyze | `flutter analyze` |
| Tests | `flutter test` (currently minimal; add as you build) |
| Web release build | `./increment_version.sh && flutter build web --release --pwa-strategy=none` |
| Deploy web | Upload `build/web/` output and ensure `.htaccess` is present in the Hostinger web root (`public_html`). |

Platform-specific docs in repo detail release steps for Android/iOS.

---

## 6. Data & Configuration

- **Firestore structure** (high level):
  - `teaching_shifts` – Schedules, teacher assignments, hourly rates.
  - `timesheet_entries` – Stored clock-in/out records.
  - `users` – User profiles with `user_type`, role metadata, and timezone.
  - Settings collections (see `system_settings_screen.dart`).
  - Debug logs (`debug_logs/time_clock_logs/…`) for time clock instrumentation.
- **Security rules** are in `firestore.rules`.
- **Cloud Functions** live under `functions/` (Node.js). Currently used mainly for
  scheduled jobs or ancillary tasks.
- **Remote Config** – Managed via `VersionService` (force updates, feature flags).

---

## 7. Major Subsystems

### Time Clock & Timesheets
- `features/time_clock/screens/time_clock_screen.dart` – Teacher UX for starting
  sessions, capturing location, and showing elapsed time.
- `features/time_clock/screens/admin_timesheet_review.dart` – Review UI with export
  logic (weekly/monthly rollups, duplicate detection, corrupted data safeguards).
- Services: `shift_timesheet_service.dart`, `shift_monitoring_service.dart`,
  `location_service.dart`.

### Shift Scheduling
- `features/shift_management/...` – Creating, publishing, and editing teaching
  shifts. Integrates with Syncfusion calendar widgets for timeline views.

### Forms
- `form_screen.dart` + `features/forms/` – Create/edit forms, store templates and
  responses, export to CSV/Excel.

### User & Role Management
- `user_management_screen.dart` + `features/user_management/` – Manage user accounts,
  roles, and permissions; includes invite flows.

### Messaging/Tasks/Zoom
- Respective feature folders contain services/screens for chat, task assignment,
  and Zoom meeting integration.

---

## 8. Coding Guidelines

- Follow `analysis_options.yaml` (mostly Flutter defaults). Run `flutter analyze`
  before pushing.
- Prefer adding new components inside their feature folder rather than creating
  giant files. When adding shared mechanics, use `core/` or `shared/` instead.
- Reuse existing services/helpers rather than duplicating Firestore logic.
- Keep UI responsive—most screens branch between desktop/web and mobile layouts.
- For exports or background jobs, lean on the utilities in `utility_functions/`.

---

## 9. Common Tasks & Points of Contact

- **Adding a new admin workflow**: create a new folder under `lib/features/<new_feature>/`
  with `screens/`, `widgets/`, `services/`, and wire it into the admin navigation
  (`dashboard.dart` or `role_based_dashboard.dart`).
- **Working with shifts/time clock**: use `ShiftTimesheetService` for any data
  operations to ensure validation rules run. `ShiftMonitoringService` is the place
  for automated enforcement (missed shifts, auto clock-outs).
- **Debugging data issues**: check the debug logs printed in the console, or use
  `debug_firestore_screen.dart` for on-device inspection.
- **Push notifications**: look at `NotificationService` for registration & token
  storage; Firebase Cloud Messaging is configured in `main.dart`.
- **Theme/Design**: use helpers under `core/constants/` and `shared/` widgets for
  consistent styling.

---

## 10. Additional References

- `docs/admin_guide.md` & `docs/teacher_guide.md` – End-user manuals.
- `DEVICE_PREVIEW_GUIDE.md`, `DARK_MODE_GUIDE.md`, `TIMEZONE_IMPLEMENTATION.md` –
  Deep dives into their respective subsystems.
- The repo contains numerous retrospective notes (e.g., `CLOCK_IN_COOLDOWN_FIX.md`)
  that capture why certain changes were made—search the root for relevant topics.

---

### Need help?
Reach out in the engineering channel or mention the last person who touched the
area (check `git blame`). Welcome to the team—happy shipping! 🚀

