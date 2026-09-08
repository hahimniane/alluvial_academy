# Teacher console parity status

One row per teacher sidebar entry in the Flutter web app, against the rule in
`teacher-web-parity-rule.md`. "Flutter" is the screen `dashboard.dart` opens for
that sidebar index; "Next" is what `/teacher/...` renders.

| # | Sidebar (section / label) | Flutter screen | Next route | State |
|---|---|---|---|---|
| 0 | Overview / Dashboard | `TeacherHomeScreen` | `/teacher/` | Ported |
| 4 | Work / My Shifts | `TeacherShiftScreen` | `/teacher/shifts/` | Ported |
| 6 | Work / Time Clock | `TimeClockScreen` | `/teacher/time-clock/` | Ported |
| 11 | Work / Tasks | `QuickTasksScreen` | `/teacher/tasks/` | Ported |
| 23 | Work / Job Board | Next.js in an iframe | `/teacher/job-board/` | Ported, now also standalone |
| 5 | Communication / Chat | `ChatPage` | `/teacher/chat/` | Ported |
| 12 | Communication / Classes | `ZoomScreen` | `/teacher/classes/` | Ported |
| 26 | Communication / Recordings | `ClassRecordingsScreen` | `/teacher/recordings/` | Ported |
| 27 | Communication / Surah Podcasts | `SurahPodcastScreen` | `/teacher/surah-podcasts/` | Ported |
| 39 | Communication / Quran | `QuranReaderScreen` | `/teacher/quran/` | **Added 2026-09-08** |
| 30 | Communication / Curriculum Books | `CurriculumBooksScreen` | `/teacher/curriculum-books/` | Ported (both are the same four static books) |
| 35 | Communication / Quiz Review | `AdminQuizReviewScreen` | `/teacher/quiz-review/` | **Added 2026-09-08** |
| 22 | Forms / Submit Form | `TeacherFormsScreen` | `/teacher/submit-form/` | Ported |
| 28 | Savings / Circles | `PublicSiteCmsScreen` | `/teacher/circles/` | Hidden on both sides (`showCircles = false` / `tontine_enabled`) |
| 20 | Reports / My Report | `TeacherAuditDetailScreen` | `/teacher/report/` | Ported |

Reached outside the sidebar, and present on both sides: Profile, Settings,
Assignments, My Form Submissions, Classroom, AI tutor.

## Deliberate differences

- **Job Board** renders bare inside the Flutter iframe and with the teacher
  shell when opened directly. One page, two hosts.
- **Quran** shares one reader with the student page (`QuranReaderPage`), because
  the Flutter app also uses one screen for every role. Duplicating it per role
  would guarantee drift.
- **Quiz Review's** generate / send-batch / reviewers controls appear only when
  `getQuizReviewQueue` returns `canManageReviewers`, exactly as in the app, so a
  teacher who is not a designated reviewer sees the same refusal.

## Exercised against production (8 Sep 2026)

With a throwaway teacher account, a seeded student and a seeded class, all
since deleted:

| Screen | What was done | Result |
|---|---|---|
| Dashboard | Loaded for a real teacher | Stats, next class, quick access all render |
| My Shifts | Clocked in from the shift card | `timesheet_entries` row written with location, shift set to `active` |
| Time Clock | Clocked out | Entry closed with hours and pay, `clock_out_platform: web` |
| Submit Form | Picked the ended shift, filled and submitted the class report | `form_responses` written and linked to the shift **and** the timesheet, which flipped to `form_completed` |
| Job Board | Loaded real postings as a Conakry teacher, then a Tokyo teacher | Family hours converted into the teacher's own hours both times |
| Quiz Review | Loaded as a non-reviewer | Same refusal the app shows; admin-only controls hidden |
| Quran | Loaded | Reader and reciter list live |
| Chat / Classes / Recordings / Tasks / My Report | Loaded | Correct empty states, no errors |
| French | Set `language_preference: fr` | Whole sidebar and chrome in French |

## Fixed while verifying

- **Job Board showed family hours as if they were the teacher's.** The app
  converts them; the web page did not. It now converts, and says which zone
  each time is in. The slot picker shows the family's hour with the teacher's
  own underneath, and still stores the family's — the value admin schedules on.
- **The teacher console had no French at all**, and its language selector wrote
  a key nothing read. It now uses the shared dictionary and the same
  `language_preference` field as Flutter and the student dashboard.
- **My Report called a missing report an error.** A teacher with no report yet
  saw "Missing or insufficient permissions"; they now see the empty state, as
  in the app.

## The switch is on (8 Sep 2026)

`settings/teacher_web_cutover` is set to **`mode: "all"`**: every teacher who
signs in on the web now lands on `/teacher/`. The native store apps are
unaffected — the redirect is web-only.

Proved end to end before the flip, with a throwaway teacher account since
deleted: signed in at the Flutter login on `/app/`, watched the app resolve the
role, read the cutover document and replace the location with `/teacher/`, and
saw the Next.js console render signed in with the full teacher sidebar. No
second login.

Rolling it back needs no deploy. Run the **Teacher web cutover** workflow with
mode `off`, or set `mode: "off"` on that document by hand, and every teacher is
back on the Flutter dashboard on their next load. `hold: true` only pauses the
automatic promotion; it does not move anyone back.

The weekday workflow still reports who is on the console and compares clocked
hours against each audit, so a pay gap opened by this move shows up the next
morning rather than at the end of the month.

## Exercised by hand, second pass (8 Sep 2026)

Every remaining screen, with a throwaway teacher and student since deleted.

| Screen | What was done | Result |
|---|---|---|
| Surah Podcasts | Opened the library, opened Al-Fatiha, played the audio card, opened the share picker | Audio, video, PDF and text all render; the picker's refusal matches the Flutter string exactly |
| Curriculum Books | Requested all eight linked files | 4 PDFs and 4 PPTX, every one HTTP 200 with the right content type |
| Assignments | Created, edited and deleted an assignment against a seeded student | All three write paths work; edit prefills the selected student |
| Profile | Saved every field, reloaded | Persisted. The empty "Full name" on first open matches Flutter, which also seeds only from `teacher_profiles` |
| Classroom | Loaded a future, a past and a live class | All three gates correct; the live one fetched a real join token and connected to the room |
| Circles | Loaded disabled, enabled `tontine_enabled`, created a circle | Both states correct; circle created with payout order and activate/invite actions |
| AI Tutor | Started a text session | Page, token and room all fine — but no agent ever joins (see below) |

## Known broken, and not from this port

**The AI Tutor never gets an agent.** `getAITutorToken` creates the room and
dispatches the agent successfully — the LiveKit room shows a dispatch for agent
`Alluwal` with only the teacher in it, so the agent worker in `livekit-agent/`
is not answering on LiveKit Cloud. The Flutter screen calls the same callable
and joins the same room, so this is broken in both clients, and was before the
move.

**Assignments offers every student in the school.** A teacher with no assigned
students is shown all 269. `_loadMyStudents` in the Flutter screen queries
every `user_type == "student"` document despite its name, so the web page is at
parity with a pre-existing bug rather than introducing one. Worth fixing in
both, together.

## French

The first pass translated the shell only; every page body was still English,
including the dashboard. Now translated: 436 strings wrapped from JSX, 113 from
expressions, 29 error messages, plus breadcrumbs, metric tiles, timesheet
columns, and the visible template-literal text. Dates and times follow the
language too — French renders 24-hour times and French month and day names.

Two mechanics worth knowing:

- `tr()` in `lib/i18n.ts` translates outside a component, so nested render
  helpers need no hook. It holds English until `markLocaleHydrated()` fires,
  because the site is a static export built in English and a translated first
  render would not match the served markup.
- A key may carry a context after a pipe — `"End|timesheet"` — when one English
  word needs two French ones. Only the part before the pipe is ever shown.

Not translated, deliberately: brand and product names, currency codes, and the
outside sites in Islamic Resources. Still English: aria-labels built from
template literals (`Close ${label}` and similar), which screen readers will
read in English.

## Signing out never returns a teacher to Flutter (8 Sep 2026)

Both sign-out buttons used to send teachers to `/login/`, which forwards
straight into the Flutter app — the dashboard they had just been moved off.
Worse, `dashboardPathForUser` still routed every teacher to `/app/`, so signing
back in landed them there too.

Now:

- `/teacher/login/` is the teacher's login, inside this app. Sign-out from the
  account menu and from Settings both go there, as does the "Go to login" link
  on the signed-out gate.
- `dashboardPathForUser` sends a teacher to `/teacher/` whenever the cutover
  document says they belong there, so signing in from any Next login form lands
  on the console.
- `lib/teacherCutover.ts` reads the same `settings/teacher_web_cutover`
  document as the Flutter service, so one edit still moves everyone either way.
  It fails **open** — the opposite of the Flutter side, on purpose: Flutter
  keeps a teacher where they already are, while an unreadable document here
  should leave them on the console rather than throw them back.
- Flutter's own sign-out already left to the public site root, so that path was
  already safe.

Verified by hand: signed in at `/teacher/login/` and landed on `/teacher/`;
signed out from the account menu and landed on `/teacher/login/`. A grep of the
built teacher pages finds exactly one link into Flutter left.

**The one remaining doorway** is "Sign in with Phone" on the login page, which
is mobile-only (`md:hidden`) and points at the Flutter login because phone auth
exists only there. It is a doorway rather than a destination: after signing in,
the Flutter shell resolves the role, reads the cutover and redirects to
`/teacher/`. Removing it would leave any teacher who signs in by phone without
a way in, so it stays until phone auth exists here.
