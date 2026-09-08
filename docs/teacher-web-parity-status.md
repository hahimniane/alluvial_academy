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

## Not yet done

The Flutter redirect has **not** been flipped: teachers still land on `/app/`
after sign-in, and reach this console only by URL. Per the rule, the flip is
the last step and is the owner's call once they have looked at it.

Not yet exercised by hand: Surah Podcasts, Curriculum Books, Assignments,
Profile, Classroom, the AI tutor and Circles. They load, and their code is the
same shape as the screens above, but "loads" is not "works".
