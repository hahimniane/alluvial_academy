# Alluvial Academy (Alluwal Education Hub)

An online Islamic education platform where teachers give live classes to students, and admins manage everything — scheduling, attendance, forms, payments, and more. Built with Flutter (frontend) and Firebase (backend). Runs on web, Android, and iOS.

> **👋 New developer? Start here:** [`docs/HOW_WE_WORK.md`](docs/HOW_WE_WORK.md) — friendly, example-heavy guide to our workflow.
> **AI agent reading this?** Your rules live in [`AGENTS.md`](AGENTS.md).

## What This App Does

There are **4 types of users**, each with their own dashboard:

| Role | What they do |
|------|-------------|
| **Admin** | Creates teacher schedules (shifts), manages users, reviews timesheets, builds forms, runs audits, handles enrollment |
| **Teacher** | Joins live video classes, clocks in/out, fills out forms, views their schedule, sees their audit reports |
| **Student** | Joins live classes, views their schedule, takes quizzes, listens to Surah podcasts, uses the AI tutor |
| **Parent** | Views their child's schedule and progress, sees invoices and payments |

A single user can have **multiple roles** (e.g., a teacher who is also an admin). The app detects this and shows a role switcher in the sidebar.

### Key Features

- **Shifts/Scheduling** — Admins create teaching shifts with teacher + student assignments. Supports recurring schedules (daily, weekly, custom). This is the core of the app — almost everything else connects to shifts.
- **Live Video Classes** — Teachers and students join classes via LiveKit video calls. Classes are recorded and can be replayed later.
- **Time Clock** — Teachers clock in/out of shifts. Admins review timesheets for payroll.
- **Forms** — Admins build custom forms (like Google Forms). Teachers submit them. Admins review submissions.
- **Audits** — Monthly teacher performance audits with evaluation rubrics, class logs, and coach reviews.
- **Chat** — In-app messaging between users.
- **Tasks** — Task management with assignments and deadlines.
- **Invoicing** — Auto-generated invoices for parents based on shift hours.
- **Quran/Podcast** — Quran study tools and Surah podcast player.
- **AI Tutor** — AI-powered tutoring assistant for students.

## How the App is Built

### Frontend (Flutter)

The app is a single Flutter codebase that runs on web, Android, and iOS. The code lives in `lib/`.

**Navigation works like this:**
1. User logs in → `main.dart` loads the app
2. `role_based_dashboard.dart` checks the user's role and picks the right dashboard
3. The main dashboard (`dashboard.dart`) has a sidebar with menu items and a `_screens` list (indexed 0–26) that maps sidebar items to screen widgets
4. Each role sees different sidebar items (configured in `sidebar_config.dart`)

### Backend (Firebase)

- **Firestore** — The database. Collections like `users`, `teaching_shifts`, `teaching_shift_templates`, `form_templates`, `form_responses`, `teacher_audits`, etc.
- **Cloud Functions** — Server-side logic in Node.js. Handles things like: creating Cloud Tasks for shift start/end automation, sending push notifications, generating invoices, managing LiveKit rooms, AI tutor responses.
- **Firebase Auth** — User login/signup.
- **Firebase Storage** — File uploads (profile pictures, form attachments, class recordings).
- **Firebase Messaging** — Push notifications.

### Video (LiveKit)

Live classes use LiveKit for video/audio. It's self-hosted on a VPS at `live.alluwaleducationhub.org`. When a shift starts, the app creates a LiveKit room and generates tokens for the teacher and students to join.

## Project Structure

The codebase uses **feature-first architecture** — code is organized by what it does, not by what type of file it is.

```
lib/
  main.dart                          # App entry point — Firebase init, routing
  firebase_options.dart              # Firebase config (production)
  firebase_options_dev.dart          # Firebase config (dev)

  core/                              # Code shared across the whole app
    services/                        # ~16 shared services
      auth_service.dart              #   Login, logout, session management
      user_role_service.dart         #   Which roles does this user have?
      notification_service.dart      #   Push notifications
      theme_service.dart             #   Light/dark mode
      language_service.dart          #   English/French/Arabic switching
      timezone_service.dart          #   Timezone conversion
      connectivity_service.dart      #   Online/offline detection
      ...
    models/                          # Shared data models
      user.dart                      #   User profile data
      employee_model.dart            #   Employee data (extends user with role info)
    utils/                           # Helper functions (logging, file export, etc.)
    widgets/                         # Reusable UI pieces (role switcher, headers)
    theme/                           # Colors, fonts, theme data
    constants/                       # App-wide constants
    enums/                           # App-wide enums

  features/                          # All feature code — one folder per feature
    shift_management/                # EXAMPLE: the shift scheduling feature
      screens/                       #   Full pages (shift list, shift calendar)
      widgets/                       #   UI pieces (shift card, create shift dialog)
      services/                      #   Business logic (create shift, check conflicts)
      models/                        #   Data classes (TeachingShift, Subject)
      enums/                         #   Shift-specific enums (ShiftStatus, etc.)
      constants/                     #   Shift colors, etc.
    chat/                            # Chat feature
      screens/                       #   Chat page
      widgets/                       #   Message bubble, voice player
      services/                      #   Send/receive messages
      models/                        #   ChatMessage, ChatUser
    audit/                           # Teacher audit feature
    forms/                           # Form builder + submissions
    livekit/                         # Video calls
    parent/                          # Parent dashboard + invoicing
    dashboard/                       # Main dashboard + sidebar
    time_clock/                      # Clock in/out + timesheets
    tasks/                           # Task management
    ... (27 features total)

  l10n/                              # Translations (English, French, Arabic)
    app_en.arb                       #   English strings
    app_fr.arb                       #   French strings
    app_ar.arb                       #   Arabic strings

functions/                           # Firebase Cloud Functions (Node.js backend)
  index.js                           # Exports all functions (entry point)
  handlers/                          # One file per feature area
    shifts.js                        #   Shift lifecycle, scheduling, Cloud Tasks
    livekit.js                       #   Video room management, token generation
    users.js                         #   User creation, deletion
    tasks.js                         #   Task CRUD + notifications
    payments.js                      #   Invoice generation
    chat.js                          #   Chat permissions + notifications
    notifications.js                 #   Push notification sending
    ...
  services/                          # Shared backend logic
    email/                           #   Email templates + sending
    livekit/                         #   LiveKit config + token generation
    tasks/                           #   Cloud Tasks config
  tests/                             # Backend tests
  scripts/dev/                       # One-off debug/migration scripts (not production)
```

### How Features are Organized

Every feature follows the same pattern. If you want to find code for a feature, go to `lib/features/<feature_name>/`:

```
features/<feature>/
  screens/      # The pages users see. One file per page.
  widgets/      # Smaller UI pieces used by the screens.
  services/     # Talks to Firestore, does calculations, business logic.
  models/       # Data classes — what a "shift" or "invoice" looks like in code.
```

**Example — if you need to fix a bug in shift creation:**
1. The UI is in `features/shift_management/screens/` and `features/shift_management/widgets/`
2. The Firestore logic is in `features/shift_management/services/shift_service.dart`
3. The data model is in `features/shift_management/models/teaching_shift.dart`

**Example — if you need to add a field to invoices:**
1. The model is in `features/parent/models/invoice.dart`
2. The service is in `features/parent/services/invoice_service.dart`
3. The UI is in `features/parent/screens/`

### What Goes Where

| I need to... | Put it in... |
|---|---|
| Add a new feature | `lib/features/<new_feature>/` with screens/, widgets/, services/ |
| Add a new screen | `lib/features/<feature>/screens/` |
| Add a new service | `lib/features/<feature>/services/` (NOT in core/) |
| Add a shared utility | `lib/core/utils/` (only if used by 3+ features) |
| Add a Cloud Function | `functions/handlers/` + export in `functions/index.js` |
| Add a translation | `lib/l10n/app_en.arb` (and app_fr.arb, app_ar.arb) |
| Write a debug script | `functions/scripts/dev/` |

### Rules

- **Never** put new files in `lib/` root — only `main.dart` lives there
- **Never** add feature-specific code to `core/` — if it's only used by one feature, it belongs in that feature
- **Always** use `package:alluwalacademyadmin/...` imports (not relative `../` paths) when importing across features
- See [CLAUDE.md](CLAUDE.md) for the full rules (these are also enforced when using AI coding assistants)

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (check with `flutter doctor`)
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- Node.js 20+ (for Cloud Functions)
- A Firebase project (the app uses `alluwal-academy`)

### Running the App

```bash
# 1. Install dependencies
flutter pub get

# 2. Run on Chrome (web)
flutter run -d chrome

# 3. Run on a connected phone/simulator
flutter run
```

### Working with Cloud Functions

```bash
# Install function dependencies
cd functions && npm install && cd ..

# Deploy all functions
firebase deploy --only functions --project alluwal-academy

# Deploy a single function
firebase deploy --only functions:scheduleShiftLifecycle --project alluwal-academy

# Read function logs
firebase functions:log --project alluwal-academy
```

### Running Tests

```bash
# Flutter tests
flutter test

# Functions tests
cd functions && npm test
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| State Management | Provider (ChangeNotifier) |
| Database | Cloud Firestore |
| Auth | Firebase Authentication |
| Backend Logic | Firebase Cloud Functions (Node.js) |
| File Storage | Firebase Storage |
| Push Notifications | Firebase Cloud Messaging |
| Video Calls | LiveKit (self-hosted) |
| Scheduled Tasks | Google Cloud Tasks |
| Languages | English, French, Arabic |
| Platforms | Web, Android, iOS |

## Firebase Project

- **Project ID:** `alluwal-academy`
- **Region:** `us-central1`
- **Cloud Tasks queue:** `shift-lifecycle-queue` in `northamerica-northeast1`
- **LiveKit server:** `live.alluwaleducationhub.org` (Hostinger VPS)
