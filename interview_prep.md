# Alluvial Academy — Technical Interview Prep

## Project Elevator Pitch

Alluvial Academy is a full-stack education platform I built with Flutter and Firebase. It powers an online Quran academy with live video classes (self-hosted LiveKit), shift scheduling, multi-role dashboards (admin, teacher, student, parent), time tracking, chat, recordings, and a public website — all from one codebase targeting web, Android, and iOS.

---

## Section 1: Architecture & Design Decisions

### Q: Walk me through the architecture of this project.

It's a **Flutter + Firebase** app using **feature-first architecture**. The frontend is organized into ~25 self-contained feature modules under `lib/features/` (auth, chat, shift_management, livekit, recordings, etc.), each with their own `screens/`, `widgets/`, `services/`, and `models/` folders. Shared code used by 3+ features lives in `lib/core/` — things like auth, theme, and role management.

The backend is **Firebase Cloud Functions** (Node.js) in `functions/handlers/`, organized by domain (livekit.js, shifts.js, shift_templates.js). Firestore is the primary database. We also use Firebase Auth, Cloud Storage (for recordings), and Cloud Messaging (for push notifications).

### Q: Why feature-first instead of layer-first?

Layer-first (all screens in one folder, all services in another) breaks down at scale. With 25+ features, a flat `screens/` folder becomes unnavigable and everything becomes implicitly coupled. Feature-first keeps related code co-located — adding or modifying a feature only touches one directory. It also makes dependencies explicit: features don't import from each other's internals, only from `core/`.

### Q: How do you decide what goes in `core/` vs a feature folder?

Simple rule: if it's used by 3 or more features, it goes in `core/`. If it's used by 1-2 features, it stays in the feature folder. For example, `AuthService` is in `core/` because every feature needs auth. But `ShiftService` is in `features/shift_management/services/` because only shift-related screens use it.

### Q: What design patterns did you use?

- **Provider + ChangeNotifier** for state management — sufficient for our Firestore-driven data model without the boilerplate of Bloc
- **Index-based navigation** — the main dashboard holds a `_screens` list (27 entries), and the sidebar sets the selected index to swap the visible screen
- **Service layer pattern** — business logic lives in service classes, not in widgets. Widgets call services, services call Firestore/Cloud Functions
- **Callable Cloud Functions** for secure server-side operations (token generation, recording management, role validation)

---

## Section 2: State Management

### Q: What state management did you use and why not Bloc/Riverpod?

Provider with `ChangeNotifier`. The app's data is mostly Firestore-driven, which maps naturally to `StreamProvider` or `ChangeNotifierProvider`. We didn't need Bloc's event/state separation or Riverpod's compile-time safety — Provider was already in use and gets the job done without extra abstraction layers. The real complexity is in the backend logic and data model, not in widget state.

### Q: How does navigation work?

The main dashboard (`DashboardPage`) maintains a `_selectedIndex` and a `_screens` list with 27 screen widgets (indices 0-26). The sidebar config maps menu items to screen indices by role. When a user taps a sidebar item, we update `_selectedIndex` and the corresponding screen renders. Parents have a separate `ParentDashboardLayout` with their own screen router (indices 0-7) since their navigation structure is different enough to warrant it.

### Q: How do you persist user preferences?

`SharedPreferences` for lightweight local state like the active role, collapsed sidebar state, and language preference. Firestore for anything that needs to sync across devices — user settings, notification preferences, profile data.

---

## Section 3: Multi-Role System

### Q: How does the role system work?

Users have a `user_type` field (primary role: admin, teacher, student, parent) plus a `secondary_roles: List<String>` for additional roles. The `UserRoleService` resolves all available roles by combining:

1. The primary `user_type`
2. Business rules (any admin can switch to teacher mode)
3. Legacy flag (`is_admin_teacher` for teachers promoted to admin)
4. The `secondary_roles` array (e.g., a parent who is also a student)

The active role is cached in `SharedPreferences`. The sidebar dynamically reconfigures — an admin sees user management, shift management, audits; a teacher sees their shifts, time clock, chat; a parent sees student progress and invoicing.

### Q: How do you prevent unauthorized access when a user switches roles?

Two layers. On the frontend, the sidebar only shows menu items for the active role, so users can't navigate to screens they shouldn't see. On the backend, every Cloud Function independently validates the caller's role by looking up their Firestore document — it doesn't trust anything from the client. For example, the LiveKit join function checks if you're the assigned teacher, an enrolled student, a guardian of an enrolled student, or an admin before issuing a token.

### Q: What was the challenge with the legacy `is_admin_teacher` flag?

Early on, the app used a simple boolean `is_admin_teacher` to handle teachers who were also admins. When we needed parents who are also students, or teachers who are also parents, a boolean didn't scale. We introduced `secondary_roles: List<String>` as the general solution but had to keep supporting `is_admin_teacher` for existing users who hadn't been migrated. The `UserRoleService` checks both.

---

## Section 4: LiveKit Video Integration

### Q: Why did you move from Zoom to self-hosted LiveKit?

Four reasons:
1. **Cost** — Zoom charges per-participant fees; LiveKit on our own VPS has a fixed infrastructure cost
2. **Control** — we own the server and data, no third-party dependency for a core feature
3. **Customization** — LiveKit's SDK let us embed an in-call whiteboard and Quran reader directly in the video UI, which Zoom's SDK doesn't support
4. **Recording flexibility** — we can do room composite or per-track recordings stored in our own GCS bucket with custom retention policies

### Q: Describe the LiveKit flow end-to-end.

**Infrastructure:**
- Self-hosted LiveKit server on a VPS (4 CPU, 16GB RAM) at `live.alluwaleducationhub.org`, accessed via WSS (WebSocket Secure)

**Joining a class:**
1. User taps "Join Class" in the Flutter app
2. The app calls the `getLiveKitJoinToken` Cloud Function with the shift ID and the user's active role
3. The function validates Firebase Auth, loads the shift document, checks the user is authorized (teacher, enrolled student, parent, or admin)
4. It generates a short-lived JWT using `livekit-server-sdk` with role-specific permissions (teachers get `roomAdmin: true` for mute/kick controls; students get publish-only)
5. The function returns the token + LiveKit URL to the client
6. The Flutter app connects using `livekit_client`, establishing a WebRTC session
7. The in-call UI shows video tiles, a whiteboard, and a Quran reader

**Recording:**
1. When a class starts, `ensureLiveKitShiftRecording` creates an egress via LiveKit's `EgressClient`
2. Video is recorded and uploaded to Google Cloud Storage at a structured path: `recordings/{year}/{month}/{day}/{shiftId}/{roomName}_{timestamp}`
3. A Firestore document in `class_recordings` tracks metadata (shift ID, participants, file path, status)

**Playback:**
1. The `getClassRecordingPlaybackUrl` function generates a time-limited signed URL from GCS
2. Authorization checks ensure only the teacher, enrolled students, their parents, or admins can access the recording

**Cleanup:**
- A scheduled function (`cleanupExpiredClassRecordings`) deletes recordings older than 2 months

### Q: How do you handle the Zoom-to-LiveKit migration without breaking existing shifts?

I built a **provider inference system** in the backend. When a shift is loaded, the function:
1. Checks for an explicit `video_provider` field
2. If absent, looks for Zoom-specific fields (`zoom_meeting_id`, `hub_meeting_id`, `zoom_encrypted_join_url`)
3. If Zoom data exists, treats it as a Zoom shift
4. Otherwise, defaults to LiveKit for teaching shifts

This let us deploy LiveKit for all new shifts while existing Zoom shifts continued working. In the Dart model, Zoom fields are marked `@Deprecated` so the codebase gradually moves away from them.

### Q: What is room composite vs track composite recording?

**Room composite** merges all participants into a single video file server-side — one combined output. Simpler, less storage, but you can't isolate individual participants afterward.

**Track composite** records each participant's audio and video as separate files. This allows post-processing like isolating a student's recitation audio for review. It requires more storage and server resources — we support both modes, selected via environment variable.

### Q: How do you handle guest access to LiveKit rooms?

There's a separate `getLiveKitGuestJoin` endpoint exposed as an HTTP request (not a callable function), so it doesn't require Firebase Auth. It validates the guest's identity through other means (e.g., a shared link with a shift ID) and generates a limited-permission token. Guests can view but have restricted capabilities compared to authenticated users.

---

## Section 5: Shift Management & Scheduling

### Q: How does the scheduling system work?

The `TeachingShift` model is the core entity with ~40 fields covering:
- **Who**: teacher ID, student IDs, created-by admin
- **When**: start/end time, admin timezone, teacher timezone
- **What**: subject (supports both legacy enum and dynamic subject IDs), custom name
- **Recurrence**: pattern, end date, series ID linking all shifts in a recurring series, enhanced recurrence settings
- **Time tracking**: clock-in/out times, platform used, auto-clock-out with reason, worked minutes
- **Video**: provider inference, LiveKit room name, legacy Zoom fields
- **Publishing**: teachers can publish shifts for substitutes to claim, tracking original teacher

### Q: How does recurrence work?

Shifts support an `EnhancedRecurrence` model for patterns like daily, weekly on specific days, or custom intervals. A `recurrenceSeriesId` links all shifts in the same series so bulk operations (edit all future shifts, cancel series) work correctly. There's also a **shift template** system — templates define a recurring schedule pattern, and a backend process materializes them into concrete shift documents.

### Q: What are shift categories?

A `ShiftCategory` enum distinguishes **teaching** shifts (classroom time with students) from **leadership** shifts (admin work, coordination meetings, planning). Leadership shifts use a `leaderRole` field to specify the type. This lets the same scheduling infrastructure serve both classroom and administrative scheduling without separate systems.

---

## Section 6: Firestore & Data Design

### Q: How do you structure your Firestore data?

Top-level collections: `users`, `teaching_shifts`, `class_recordings`, `forms`, `chat_rooms`, etc. We chose flat collections over deep nesting because Firestore queries work best on top-level collections, and it avoids the 1MB document size limit for subcollections.

Relationships are by reference: shifts store `teacher_id` and `student_ids` array, recordings store `shift_id`. We don't use Firestore references (DocumentReference) — just string IDs, which are more portable and easier to serialize.

### Q: How do you handle schema evolution?

We normalize on read rather than running bulk migrations. The backend checks both `snake_case` and `camelCase` variants of fields (e.g., `user_type` and `userType`, `video_provider` and `videoProvider`). New code writes the canonical field name, but reads tolerate both. The Dart model uses `@Deprecated` annotations on legacy fields. This is pragmatic for a live system where you can't take the database offline, though ideally I'd run a one-time migration to standardize everything.

### Q: How do you handle Firestore security?

Defense-in-depth:
1. **Firestore security rules** for direct client access — users can only read/write their own data
2. **Cloud Function validation** for server-side operations — every callable function verifies the caller's auth and role
3. **Parent-student traversal** — for features like recording access, the function walks the `guardian_ids` relationship to verify a parent is authorized to see their child's data

---

## Section 7: Cross-Platform & Web

### Q: What platforms does this target and what challenges did you face?

Web, Android, and iOS from a single Flutter codebase.

**WebRTC on web:** `flutter_webrtc` behaves differently on web vs mobile. We use Dart conditional imports (`if (dart.library.io)`) to swap implementations — for example, picture-in-picture uses different APIs on web vs native.

**Permissions:** Camera/microphone permissions differ between platforms. On mobile we use `permission_handler`; on web we rely on browser-native permission prompts.

**Firestore web SDK quirks:** The web Firestore SDK occasionally throws internal assertion errors (`FIRESTORE INTERNAL ASSERTION FAILED: Unexpected state`). We detect these with `_looksLikeFirestoreWebInternalError()` and handle them gracefully rather than crashing.

**Responsive layout:** The dashboard uses a collapsible sidebar on desktop/web and a different layout on mobile. The sidebar hover-to-expand behavior only activates on non-touch platforms.

---

## Section 8: Security

### Q: How do you handle authentication and authorization?

**Authentication:** Firebase Auth handles login (email/password). The app checks auth state on startup and routes to login or dashboard.

**Authorization — frontend:** Role-based sidebar filtering — users only see menu items for their active role. But we never trust the frontend for security.

**Authorization — backend:** Every Cloud Function validates independently:
- Extracts the Firebase Auth UID from the request context
- Looks up the user document in Firestore to verify role
- For shift-specific operations, checks the user is the assigned teacher, enrolled student, parent, or admin
- For LiveKit tokens, encodes role-specific permissions into the JWT

**Input validation:** All Cloud Function inputs are sanitized. `_normalizeUidList()` deduplicates and trims user IDs. `_safePathSegment()` strips special characters from file paths to prevent path traversal. Recording file paths are constructed server-side, never from client input.

### Q: How are LiveKit tokens secured?

Tokens are short-lived JWTs generated server-side only after full authorization. They encode:
- The user's identity and display name
- Room-specific permissions (publish, subscribe, manage)
- Expiration time
- Role metadata

The LiveKit server validates these tokens on connection. Even if someone intercepts a token, it's scoped to one room and expires quickly.

---

## Section 9: Testing & Code Quality

### Q: How do you ensure code quality?

- **Feature-first structure** enforces separation — features can't reach into each other's internals
- **Localization enforcement** — all user-facing strings must use `AppLocalizations` via ARB files (English, French, Arabic)
- **Defensive backend code** — every Cloud Function normalizes inputs, checks auth, and handles edge cases (room not found, egress already exists, etc.)
- **Structured logging** — `AppLogger` utility with categorized log levels, plus error reporting to Firestore with user/session tracing for production debugging
- **Security rules** — Firestore rules + Cloud Function validation as defense-in-depth

---

## Section 10: Real-Time Features

### Q: What real-time capabilities does the app have?

- **Live video classes** via LiveKit/WebRTC with in-call whiteboard and Quran reader
- **Real-time room presence** — `getLiveKitRoomPresence` function returns current participants with join times and publisher status
- **Teacher controls** — mute individual (`muteLiveKitParticipant`), mute all (`muteAllLiveKitParticipants`), kick participant (`kickLiveKitParticipant`), lock/unlock room (`setLiveKitRoomLock`)
- **Chat** with voice messages
- **Time clock** for real-time teacher clock-in/out tracking
- **Firestore listeners** for live dashboard updates, shift status changes, notification badges

---

## Section 11: Behavioral / Soft-Skill Questions

### Q: What's the most challenging technical problem you solved?

Migrating from Zoom to self-hosted LiveKit while keeping the app running. The challenge was threefold: (1) existing shifts had Zoom data that couldn't be migrated overnight, (2) the LiveKit server needed to be provisioned and secured, (3) the Flutter client needed to handle both providers. I solved it with a provider inference system on the backend, deprecated Zoom fields in the Dart model, and deployed LiveKit for new shifts while old Zoom shifts kept working. The rollout was zero-downtime.

### Q: What would you redesign if you could start over?

**Schema normalization.** We read both `snake_case` and `camelCase` variants of many Firestore fields because of early inconsistencies. Every handler has redundant field checks. I'd standardize on one convention from day one and run a migration script for the existing data, then simplify all the reading code.

### Q: How do you handle a feature request you disagree with?

I frame it in terms of trade-offs. For example, when we discussed adding track composite recording, I explained the server resource requirements and suggested we keep room composite as default while preparing the infrastructure for track composite. We agreed to deploy the code but gate it behind an environment variable until the VPS was upgraded.

### Q: How do you prioritize work on a project this large?

By user impact and system risk. Core flows (joining a class, shift scheduling) get priority over nice-to-haves (podcast player, tontine feature). Security issues are always top priority. I also maintain a strict architecture — the feature-first structure means I can work on one feature without risking regressions in others.

### Q: Tell me about a time you had to maintain backward compatibility.

The multi-role system evolution. We went from a simple `user_type` string, to an `is_admin_teacher` boolean for dual-role users, to a full `secondary_roles` array. Each step had to support all previous data shapes. The `UserRoleService` and backend role extraction functions check all three formats and produce a unified role list. No existing user was broken during any transition.

---

## Section 12: System Design / Scale Questions

### Q: How would you scale this system?

- **Firestore** scales automatically, but I'd add composite indexes for complex queries and denormalize data where read performance matters
- **LiveKit** — add more VPS instances behind a load balancer; LiveKit supports multi-node clusters
- **Cloud Functions** — already serverless and auto-scaling; I'd move to Cloud Run for long-running operations like batch recording processing
- **Recordings** — GCS scales indefinitely; the scheduled cleanup function prevents unbounded storage growth

### Q: How do you monitor this in production?

- **Error reporting** — errors are logged to a Firestore `error_reports` collection with user ID, session ID, stack trace, and platform info
- **Structured logging** — `AppLogger` categorizes logs by severity; Cloud Functions use `functions.logger`
- **LiveKit monitoring** — the self-hosted server exposes metrics; `checkLiveKitAvailability` is a health check function the app can call

---

## Quick Reference: Key Technologies

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart), Provider, Google Fonts |
| Backend | Firebase Cloud Functions (Node.js) |
| Database | Cloud Firestore |
| Auth | Firebase Authentication |
| Video | LiveKit (self-hosted), WebRTC, livekit_client SDK |
| Storage | Google Cloud Storage (recordings) |
| Notifications | Firebase Cloud Messaging |
| Localization | Flutter ARB files (EN, FR, AR) |
| Hosting | Firebase Hosting (web), Hostinger VPS (LiveKit) |
