# Alluvial Academy — Codebase Guide (for future developers)

This repository contains:
- A **Flutter** app that ships to **web** (public marketing site; authenticated portal widgets exist but are not the default web entry) and **mobile** (authenticated app).
- A **Firebase backend** (Firestore, Auth, Storage, Cloud Functions, Remote Config, FCM).
- A local **Zoom Meeting SDK Flutter plugin** and web Zoom integration glue.
- A set of **maintenance scripts** and a large collection of historical engineering notes (`*.md`).

The goal of this document is to give a new developer enough accurate context to navigate, run, and extend the system without guesswork.

---

## 1) Quick start (local dev)

### Flutter app
1. Install Flutter (Dart SDK is pinned by `pubspec.yaml` to `sdk: ^3.4.3`).
2. From repo root:
   - `flutter pub get`
   - Web: `flutter run -d chrome`
   - Mobile: `flutter run -d ios` / `flutter run -d android`

### Firebase Cloud Functions
1. `cd functions`
2. `npm install`
3. Local emulator: `npm run serve`
4. Tests: `npm test`

### Firebase project selection
- Default Firebase project is set in `.firebaserc` (`alluwal-academy`).
- Hosting / rules / functions wiring is in `firebase.json`.

---

## 2) Top-level repository layout

### Curated tree
```
.
├── lib/                      # Flutter app source (public site + authenticated portal widgets)
├── assets/                   # Images/icons used by Flutter UI
├── functions/                # Firebase Cloud Functions (Node.js)
├── packages/                 # Local Flutter packages (Zoom Meeting SDK plugin)
├── android/ ios/ web/ ...     # Flutter platform scaffolding
├── scripts/                  # One-off maintenance/migration scripts
├── tools/                    # Helper scripts (e.g., Zoom SDK setup)
├── test/                     # Flutter tests
├── firebase.json             # Firebase hosting/functions/rules config
├── firestore.rules           # Firestore rules (currently has merge-conflict markers)
├── firestore.indexes.json    # Firestore indexes
├── storage.rules             # Storage rules
├── pubspec.yaml              # Flutter dependencies and assets
└── README.md                 # High-level product overview
```

### Runtime code (what ships)
- `lib/` — Flutter app source (primary codebase).
- `assets/` — App assets (images/icons).
- `functions/` — Firebase Cloud Functions (Node.js).
- `packages/flutter_zoom_meeting_sdk/` — Local Flutter plugin for Zoom Meeting SDK (native Meeting SDK wrapper).
- Platform folders: `android/`, `ios/`, `web/`, `macos/`, `windows/`, `linux/` — Flutter platform scaffolding + platform-specific config.

### Tooling / ops
- `scripts/` — One-off maintenance and migration scripts (mostly Node; one Dart script).
- `tools/` — Helper scripts (notably Zoom SDK setup).
- `increment_version.sh` — Cache-busting for Flutter web by versioning `web/index.html`.
- `build_android.sh`, `build_release.sh`, `scripts/publish_android.sh`, `scripts/publish_ios.sh` — build/release helpers.

### Firebase config
- `firebase.json` — Hosting + functions + rules entry points; also contains FlutterFire config outputs.
- `firestore.rules` — Firestore security rules (**currently contains unresolved merge-conflict markers; fix before deploy**).
- `firestore.indexes.json` — Composite indexes used by the app/functions.
- `storage.rules` — Storage rules (profile pictures, assignment files, task attachments, form images).
- `lib/firebase_options.dart` — FlutterFire-generated Firebase config for platforms.

### Documentation and notes
- `README.md` — High-level product + build notes.
- `DEVELOPER_ONBOARDING.md` and `documentation/` — lots of historical implementation notes and guides.

### Generated / local-only folders (do not hand-edit)
- `.dart_tool/` — Dart/Flutter tool metadata.
- `build/` — Flutter build outputs.
- `.git/` — Git metadata.

---

## 3) Flutter app architecture (`lib/`)

### 3.1 Entry point and runtime “modes”

**Main entry:** `lib/main.dart`

At runtime the app behaves differently depending on platform:
- **Web:** `MyApp.home` is `LandingPage` (public marketing site). There is currently no built-in navigation from the landing pages into the authenticated portal UI.
- **Mobile (Android/iOS):** `MyApp.home` is `AuthenticationWrapper` → Firebase Auth state → login/dashboard.

Key bootstrap behaviors in `lib/main.dart`:
- Initializes Firebase (`Firebase.initializeApp`).
- Initializes timezone database via `TimezoneUtils.initializeTimezones()`.
- On mobile only:
  - Sets up Firebase Messaging background handler.
  - Initializes `NotificationService` (FCM + local notifications).
  - Initializes `VersionService` + wraps app in `VersionCheckWrapper` (force-update via Remote Config).
- Provides theming via `ChangeNotifierProvider(create: (_) => ThemeService())`.

Other notable (currently not-default) widgets in `lib/main.dart`:
- `EmployeeHubApp` — a web/desktop-style login form that navigates to `RoleBasedDashboard` after sign-in.
- `FirebaseInitializer` — a Firebase init/loading wrapper that returns `AuthenticationWrapper`.

These widgets are present for alternative entry flows, but `MyApp.home` on web currently starts at `LandingPage`.

### 3.2 State management and theming
- State management is primarily **Provider + ChangeNotifier** where needed (e.g., `ThemeService` in `lib/core/services/theme_service.dart`), plus extensive local `setState`.
- Global light/dark themes live in `lib/core/theme/app_theme.dart`.

### 3.3 Authentication and roles

Auth is Firebase Auth, wrapped by:
- `lib/core/services/auth_service.dart` — email/password login; checks active status; updates last login; background teacher initialization (location + prayer times).
- `lib/core/services/user_role_service.dart` — resolves “active role” for the user and supports dual-role switching (persisted in `SharedPreferences`).

Role routing (widgets present in the codebase):
- `lib/role_based_dashboard.dart` routes to dashboards for `admin`, `teacher`, `student`, `parent`.
- `AuthenticationWrapper` (used as the default mobile home) routes authenticated users to `lib/features/dashboard/screens/mobile_dashboard_screen.dart`.

Important: some login UIs also push `RoleBasedDashboard` directly after sign-in (e.g., `MobileLoginScreen`), so depending on navigation path you may see either `MobileDashboardScreen` or role-based dashboards.

Student ID login:
- Both the web login in `lib/main.dart` (`EmployeeHubApp`) and `lib/features/auth/screens/mobile_login_screen.dart` support a “Student ID” mode by converting an entered ID into an alias email of the form `<studentId>@alluwaleducationhub.org`.

### 3.4 Primary navigation surfaces

**Authenticated “portal shell” (not default on web):** `lib/dashboard.dart`
- Holds the main screen list (`_screens`) and sidebar wiring for the admin/portal experience.
- Sidebar structure is defined in `lib/features/dashboard/config/sidebar_config.dart` and persisted by `lib/features/dashboard/services/sidebar_service.dart`.

**Web public site:** `lib/screens/*`
- Pages like `lib/screens/landing_page.dart`, program pages, teachers page, etc.
- Some public pages write to Firestore (see “Public Collections” below).

**Mobile shell:** `lib/features/dashboard/screens/mobile_dashboard_screen.dart`
- Role-aware bottom navigation and profile menu, loads user data and profile picture.

---

## 4) Data model (Firestore + Storage)

### 4.1 Firestore collections (as referenced in code)

These collections are used by Flutter (`lib/`) and/or Cloud Functions (`functions/`). Names below are extracted from code (string literals + common constant indirections).

**Core / identity**
- `users` — primary user profiles (doc IDs are typically Firebase Auth UIDs; user creation in `functions/handlers/users.js` writes `users/{uid}`).
- `teacher_profiles` — teacher-specific profile data/editing.
- `students` — server-side student records (created/managed by functions).

**Scheduling and timekeeping**
- `teaching_shifts` — scheduled/active/completed shifts (`TeachingShift` model in `lib/core/models/teaching_shift.dart`).
- `timesheet_entries` — clock-in/out records, approval state, export fields, edit tracking, and readiness-form linkage (`TimesheetEntry` model in `lib/features/time_clock/models/timesheet_entry.dart`).
- `programmed_clock_ins` — scheduled “programmed clock-in” jobs created by the app and executed by a Cloud Function.
- `shift_modifications` — reschedule/shift change tracking (used by shift management widgets).
- `schedule_issue_reports` — reports of scheduling issues from teachers.

**Forms**
- `form` — form templates (admin-created; includes the “Readiness Form” template referenced by ID in `ShiftFormService`).
- `form_responses` — submitted form responses.
- `form_drafts` — drafts of forms (used by debug tooling and some workflows).

**Tasks and chat**
- `tasks` — task records and metadata (created/assigned in Flutter; notifications sent via Cloud Functions).
- `task_comments` — task comment threads.
- `chats` / `messages` — chat threads and chat messages.

**Enrollment / job board**
- `enrollments` — public enrollment submissions (created from the public site).
- `job_board` — job board entries derived from enrollments; teachers can accept jobs via callable functions.
- `teacher_applications` — public teacher application submissions.
- `contact_messages` — public contact form submissions.

**Zoom / meetings**
- `zoom_hosts` — pool of Zoom host accounts (multi-host distribution).
- `hub_meetings` — hub meeting grouping for overlapping shifts and breakout-room routing (Cloud Functions).

**Website content / settings**
- `landing_page_content` — intended CMS content for the landing page (edited by admins).
- `app_settings` — global app settings used by `SettingsService` (doc `global`).
- `wage_settings` — tracking docs for wage settings changes (e.g., `global_settings`, `role_wages`).
- `settings` — admin settings UI uses this collection for some configuration.
- `history` — used as a subcollection under `landing_page_content/main/history` to store backups.

**Operational logging**
- `debug_logs/{userId}/time_clock_logs` — time clock debugging/instrumentation logs written by `lib/features/time_clock/screens/time_clock_screen.dart`.
- `notification_history` / `admin_notifications` / `breakout_opener_logs` — functions-side operational logging.

**Experimental / legacy migrations**
- `shifts_new`, `time_entries_new`, `users_new` — collections referenced by `functions/new_implementation.js`.

### 4.2 Firestore indexes
- Defined in `firestore.indexes.json` (notable composite indexes include teacher shift queries, timesheet queries, tasks queries, zoom host sorting).

### 4.3 Storage paths (Firebase Storage)
Rules are in `storage.rules`. Storage is used for:
- `profile_pictures/**` — uploaded by `ProfilePictureService` (`lib/core/services/profile_picture_service.dart`).
- `assignment_files/{assignmentId}/{fileName}` — uploaded by `AssignmentFileService` (`lib/features/assignments/services/assignment_file_service.dart`).
- `task_attachments/{taskId}/{fileName}` — uploaded by `FileAttachmentService` (`lib/features/tasks/services/file_attachment_service.dart`).
- `form_images/{userId}/{fileName}` — used by form submissions (see storage rules; UI code depends on current form implementation).

---

## 5) Code map: `lib/` (folders and key files)

### 5.0 Curated `lib/` tree (orientation)
```
lib/
├── main.dart
├── dashboard.dart
├── role_based_dashboard.dart
├── firebase_options.dart
├── core/
│   ├── constants/ enums/ migrations/ models/ services/ theme/ utils/ widgets/
├── features/
│   ├── auth/ assignments/ chat/ dashboard/ enrollment_management/ forms/
│   ├── notifications/ profile/ settings/ shift_management/ tasks/
│   ├── teacher_applications/ time_clock/ user_management/ website_management/ zoom/
├── screens/                  # Public website pages
├── admin/                    # Admin tooling (form builder, drafts)
├── shared/                   # Shared UI components
├── widgets/                  # Website header/export widgets
└── utility_functions/        # Export helpers + web stubs
```

### 5.1 `lib/core/` (shared domain + services)

**Exports**
- `lib/core/core.dart` — convenience exports (constants, models, services).

**Constants**
- `lib/core/constants/app_constants.dart` — global colors/text styles/dimensions.
- `lib/core/constants/dashboard_constants.dart` — dashboard layout constants.
- `lib/core/constants/shift_colors.dart` — shift color definitions.

**Enums**
- `lib/core/enums/*.dart` — shift/task/timesheet/wage/UI enums.

**Models (Firestore-backed data structures)**
- `lib/core/models/teaching_shift.dart` — central “shift” object with scheduling, clock-in fields, zoom/hub fields, recurrence metadata.
- `lib/core/models/subject.dart` — dynamic subjects + default subjects bootstrap list.
- Other models: employee/user, chat message, enrollment request, teacher application, zoom host, landing page content, etc.

**Services (business logic + Firebase wrappers)**
- Auth/roles: `lib/core/services/auth_service.dart`, `lib/core/services/user_role_service.dart`
- Scheduling/timekeeping: `lib/core/services/shift_service.dart`, `lib/core/services/shift_timesheet_service.dart`, `lib/core/services/shift_form_service.dart`, `lib/core/services/wage_management_service.dart`, `lib/core/services/settings_service.dart`
- Notifications: `lib/core/services/notification_service.dart`, `lib/core/services/notification_preferences_service.dart`, `lib/core/services/version_service.dart`
- Website content: `lib/core/services/landing_page_service.dart` (note: currently returns *static* default content for reads)
- Connectivity/timezones/platform: `lib/core/services/connectivity_service.dart` (+ `lib/core/services/connectivity_service_io.dart` / `lib/core/services/connectivity_service_web.dart`), `lib/core/services/timezone_service.dart`, `lib/core/utils/timezone_utils.dart`, `lib/core/utils/platform_utils.dart`
- Zoom: `lib/core/services/zoom_service.dart`, `lib/core/services/zoom_meeting_sdk_join_service.dart`, `lib/core/services/zoom_web_sdk_service.dart` (+ `lib/core/services/zoom_web_sdk_stub.dart`)

**Theme / widgets / utils**
- `lib/core/theme/app_theme.dart` — Material theme definitions.
- `lib/core/widgets/version_check_wrapper.dart`, `lib/core/widgets/force_update_dialog.dart`
- `lib/core/utils/app_logger.dart` — centralized logging wrapper.
- Web-only helpers: `lib/core/utils/web_timezone_detector.dart` (+ stub).

**Migrations**
- `lib/core/migrations/shift_wage_migration.dart` — legacy migration code; **not run at startup** (see note in `lib/main.dart`).

### 5.2 `lib/features/` (feature-first modules)

Each feature typically contains `screens/`, `widgets/`, `services/`, and sometimes `models/`.

**auth/**
- `lib/features/auth/screens/mobile_login_screen.dart` — mobile login UI.

**dashboard/**
- `lib/features/dashboard/screens/admin_dashboard_screen.dart` — admin overview dashboard.
- `lib/features/dashboard/screens/teacher_home_screen.dart` — teacher home with realtime listeners and stats.
- `lib/features/dashboard/screens/mobile_dashboard_screen.dart` — mobile shell and navigation.
- Sidebar: `lib/features/dashboard/config/sidebar_config.dart`, `lib/features/dashboard/widgets/custom_sidebar.dart`, `lib/features/dashboard/services/sidebar_service.dart`.

**shift_management/**
- Scheduling UI and tooling:
  - Screens: `lib/features/shift_management/screens/shift_management_screen.dart`, `lib/features/shift_management/screens/teacher_shift_screen.dart`, `lib/features/shift_management/screens/available_shifts_screen.dart`, `lib/features/shift_management/screens/subject_management_screen.dart`
  - Dialogs/widgets: create/reschedule/details, weekly grid, calendar widgets.

**time_clock/**
- `lib/features/time_clock/screens/time_clock_screen.dart` — teacher clock-in/out UX (writes to `timesheet_entries`, logs to debug collections).
- `lib/features/time_clock/screens/admin_timesheet_review.dart` — admin review/export/approval UI.
- `lib/features/time_clock/models/timesheet_entry.dart` — timesheet DTO for UI/export.

**tasks/**
- `lib/features/tasks/models/task.dart`, `lib/features/tasks/models/task_comment.dart`
- `lib/features/tasks/services/task_service.dart` — CRUD + calls Cloud Functions for assignment/status/comment notifications.
- `lib/features/tasks/services/file_attachment_service.dart` — task attachments to Storage.

**chat/**
- Chat screens/widgets and `lib/features/chat/services/chat_service.dart` (Firestore-backed chat).

**forms/**
- Form submission viewing and “my submissions” screens (backed by `form` and `form_responses`).

**profile/**
- Teacher profile screen + edit dialog.

**settings/**
- Admin settings (`lib/features/settings/screens/admin_settings_screen.dart`) and mobile settings.
- Notification preferences screen.

**notifications/**
- Admin “send notification” UI and mobile notifications UI.

**user_management/**
- Admin user CRUD screens and tables (relies on Cloud Functions user creation).

**enrollment_management/**
- Admin view for `enrollments` and filled opportunities workflows.

**teacher_applications/**
- Admin view for public teacher applications.

**assignments/**
- Teacher assignments screen and storage upload service.

**website_management/**
- Admin CMS editor for landing-page content (`landing_page_content/main`).
  - Important: `LandingPageService.getLandingPageContent()` currently returns *static defaults*, not Firestore, so CMS edits may not reflect on the public `LandingPage` without further wiring.

**zoom/**
- `lib/features/zoom/screens/zoom_screen.dart` — teacher view of Zoom shifts; uses `ZoomService`.
- `lib/features/zoom/screens/admin_zoom_screen.dart` — admin view of all meetings (hub + standalone + pending).
- `lib/features/zoom/screens/in_app_zoom_meeting_screen.dart` — a WebView-based join experience (currently not referenced elsewhere; `ZoomService` uses Meeting SDK / Web SDK).

### 5.3 Other `lib/` folders

**Public website pages**
- `lib/screens/*.dart` — marketing/public pages (landing page, programs, teachers, contact, etc.). Some pages write to public Firestore collections.

**Admin-only / legacy top-level screens**
- `lib/dashboard.dart` — the main web shell used for admin navigation.
- `lib/login.dart` — legacy login UI using `flutter_login` (not part of the default startup flow).
- `lib/form_screen.dart` — large form builder/submission flow (legacy + feature-based forms coexist).
- `lib/admin/` — form builder tooling (`lib/admin/form_builder.dart`, `lib/admin/draft_management_screen.dart`).
- `lib/shared/` and `lib/widgets/` — reusable UI components (headers, responsive builders, recurrence picker).
- `lib/utility_functions/` — export helpers + web stubs.

---

## 6) Backend: Firebase Cloud Functions (`functions/`)

### 6.0 Curated `functions/` tree
```
functions/
├── index.js                  # Exports all functions
├── package.json              # Node engine + deps + scripts
├── handlers/                 # Function implementations by domain
├── services/                 # Shared services (email, zoom, tasks, hub scheduler, fcm)
├── utils/                    # Small helpers (password generation, etc.)
├── tests/                    # Jest tests
└── scripts/                  # Dev utilities (not deployed as functions)
```

### 6.1 Directory structure
- `functions/index.js` — exports all Cloud Functions.
- `functions/handlers/` — feature handlers (users, tasks, shifts, zoom, enrollments, etc.).
- `functions/services/` — shared services (email, zoom, tasks, hub scheduling, FCM).
- `functions/utils/` — shared small helpers (password generation).
- `functions/tests/` — Jest tests (mocks + a few integration-style logic tests).

### 6.2 Exported Cloud Functions (as of `functions/index.js`)
Commonly used by the Flutter app:
- User: `createUserWithEmail`, `createMultipleUsers`, `deleteUserAccount`, `findUserByEmailOrCode`, `createStudentAccount`
- Tasks: `sendTaskAssignmentNotification`, `sendTaskStatusUpdateNotification`, `sendTaskCommentNotification`, `sendRecurringTaskReminders`, etc.
- Shifts/time: `scheduleShiftLifecycle`, `handleShiftStartTask`, `handleShiftEndTask`, `sendScheduledShiftReminders`, `executeProgrammedClockIns`
- Zoom: `joinZoomMeeting`, `getZoomJoinUrl`, `getZoomMeetingSdkJoinPayload`, `getZoomHostKey`, plus admin/test endpoints
- Enrollment/job board: `onEnrollmentCreated`, `publishEnrollmentToJobBoard`, `acceptJob`
- Website: `getLandingPageContent`

For a full list, see `functions/index.js` (grep for `exports.*`).

### 6.3 Functions configuration / environment variables

**Zoom API + Meeting SDK**
The Zoom integration expects environment variables (see `functions/services/zoom/config.js`):
- `ZOOM_ACCOUNT_ID`, `ZOOM_CLIENT_ID`, `ZOOM_CLIENT_SECRET`
- `ZOOM_JOIN_TOKEN_SECRET`, `ZOOM_ENCRYPTION_KEY_B64`
- Optional / hybrid: `ZOOM_HOST_USER`
- Optional Meeting SDK JWT generation: `ZOOM_MEETING_SDK_KEY`, `ZOOM_MEETING_SDK_SECRET`

**Cloud Tasks**
Used for shift lifecycle automation (`functions/services/tasks/config.js`):
- `GCP_PROJECT` / `GCLOUD_PROJECT` / `PROJECT_ID` (project resolution)
- `TASKS_LOCATION` (default `northamerica-northeast1`)
- `FUNCTION_REGION` (default `us-central1`)
- `SHIFT_TASK_QUEUE` (default `shift-lifecycle-queue`)

**Host key / breakout tooling**
Used by breakout-room opener flows:
- `ZOOM_HOST_KEYS_JSON`, `ZOOM_HOST_KEY`, and per-host overrides such as `ZOOM_HOST_KEY_SUPPORT`, `ZOOM_HOST_KEY_NENENANE2`

### 6.4 Email sending
Email sending is implemented via Nodemailer in `functions/services/email/*`.
- Important: credentials are currently hardcoded in `functions/services/email/transporter.js`. Treat this as a security risk and migrate to environment variables / secrets management before broader collaboration or deployment changes.

---

## 7) Web build, hosting, and cache busting

### Flutter web
- Web bootstrap is `web/index.html`.
- Cache busting is handled by `increment_version.sh`, which increments `flutter_bootstrap.js?v=...` and `manifest.json?v=...` in `web/index.html`.
- Hostinger-specific cache headers and SPA routing are configured in `web/.htaccess`.
- Netlify is configured via `netlify.toml` to run `flutter build web --release --pwa-strategy=none` and publish `build/web`.
- Firebase Hosting is also configured in `firebase.json` (public: `build/web`).

### Zoom Web SDK (web builds)
`web/index.html` loads the Zoom Web SDK from `https://source.zoom.us/...` and then loads `web/zoom_integration.js`, which exposes JS functions used by Dart via `lib/core/services/zoom_web_sdk_service.dart`.

---

## 8) Scripts and one-off maintenance tooling

### Root scripts
- `build_android.sh` — bumps build number and builds a release APK.
- `build_release.sh` — web release build wrapper (includes `--pwa-strategy=none` and copies `web/.htaccess` into `build/web/`).
- `increment_version.sh` — web cache busting.

### `scripts/` folder
Contains “run carefully” maintenance scripts (generally require Firebase Admin credentials or `firebase login`). Examples include:
- `scripts/cleanup_orphaned_timesheets.js` / `.dart` — remove timesheets whose shifts no longer exist.
- `scripts/migrate_user_data.js`, `scripts/migrate_user_by_uid.js`, `scripts/migrate_kiosque_codes.js` — data migrations.
- `scripts/fix_active_shifts_status.js`, `scripts/fix_timesheets_pay_and_status.js`, `scripts/validate_and_fix_all_timesheets.js` — consistency fixes.
- `scripts/delete_all_enrollments.js`, `scripts/delete_all_jobs.js` — destructive cleanup scripts.
- `scripts/verify_stats_consistency.js` — auditing/fixing stats coherence.

Note: some scripts reference additional collections/fields that are not part of the main Flutter/runtime code paths (e.g., older `chat_messages` / `notifications` naming). Treat scripts as “source of truth for that migration only” and read them before running.

### `tools/`
- `tools/setup_zoom_meeting_sdk.sh` — copies Zoom Meeting SDK binaries into the right platform locations and prints additional manual steps.

---

## 9) Tests

### Flutter tests
- Located under `test/` (unit/integration-style tests for platform utils, recurrence, shift overlap, clock-in workflows, etc.).
- `test/widget_test.dart` is the default Flutter template test and may not reflect the current UI.

### Cloud Functions tests
- Jest config: `functions/jest.config.js`
- Tests: `functions/tests/*.test.js`

---

## 10) Known repo issues / gotchas (important for future devs)

1. **Unresolved merge-conflict markers exist**:
   - `firestore.rules`
   - `build_release.sh`
   These must be resolved before deploying rules or relying on the script.

2. **Hardcoded SMTP credentials**:
   - `functions/services/email/transporter.js` contains hardcoded SMTP auth. Move to environment variables/secrets.

3. **Landing page CMS is not fully wired**:
   - `WebsiteManagementScreen` saves to Firestore, but `LandingPageService.getLandingPageContent()` currently returns static defaults and the public `LandingPage` in `lib/screens/landing_page.dart` is not reading Firestore CMS content.

4. **`src/app/page.tsx` is not build-wired**:
   - The repo has a Next.js-style page file but no Next.js toolchain/config in the root `package.json`. Treat as experimental/stray until integrated.

5. **Backend dependencies in-repo**:
   - `functions/node_modules/` exists in the repo tree. If this is committed, it makes diffs heavy and is atypical; consider `.gitignore` + clean install approach.

---

## 11) Where to start when making changes

Common work paths:
- **Add/modify web portal navigation:** `lib/dashboard.dart` + `lib/features/dashboard/config/sidebar_config.dart`.
- **Fix/extend roles:** `lib/core/services/user_role_service.dart` and `lib/role_based_dashboard.dart`.
- **Shift scheduling logic:** `lib/core/services/shift_service.dart` (+ `lib/features/shift_management/*`).
- **Clock-in/out logic:** `lib/core/services/shift_timesheet_service.dart` (+ `lib/features/time_clock/*`).
- **Zoom join experience:** `lib/core/services/zoom_service.dart` plus:
  - mobile/native SDK: `lib/core/services/zoom_meeting_sdk_join_service.dart`
  - web SDK: `lib/core/services/zoom_web_sdk_service.dart` and `web/zoom_integration.js`
  - backend: `functions/handlers/zoom.js`, `functions/services/zoom/*`
- **Tasks:** `lib/features/tasks/services/task_service.dart` and `functions/handlers/tasks.js`.

---

If you want, I can also generate an “API surface” appendix (all public Dart services + Cloud Functions endpoints + Firestore collections with read/write call sites), but this document aims to stay readable while still being exhaustive about structure and entry points.
